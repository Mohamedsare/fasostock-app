import 'dart:async';

import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/sale.dart';

/// Offline-first sales: UI reads from Drift; sync writes from Supabase.
class SalesOfflineRepository {
  SalesOfflineRepository(this._db);

  final AppDatabase _db;

  /// Upsert une vente en local (après création en ligne) — liste des ventes à jour immédiatement.
  Future<void> upsertSale(Sale s) async {
    await _db.upsertLocalSale(LocalSalesCompanion.insert(
      id: s.id,
      companyId: s.companyId,
      storeId: s.storeId,
      customerId: Value(s.customerId),
      saleNumber: s.saleNumber,
      status: s.status.value,
      subtotal: Value(s.subtotal),
      discount: Value(s.discount),
      tax: Value(s.tax),
      total: s.total,
      createdBy: s.createdBy,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      saleMode: Value(s.saleMode?.value),
      documentType: Value(s.documentType?.value),
      creditDueAt: Value(s.creditDueAt),
      creditInternalNote: Value(s.creditInternalNote),
    ));
    final items = s.saleItems;
    if (items != null && items.isNotEmpty) {
      final now = s.createdAt;
      await _db.upsertLocalSaleItems(items.map((i) => LocalSaleItemsCompanion.insert(
        id: i.id,
        saleId: i.saleId,
        productId: i.productId,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        total: i.total,
        createdAt: now,
      )));
    }
  }

  Stream<List<Sale>> watchSales(String companyId, {String? storeId}) {
    if (companyId.isEmpty) return Stream.value([]);
    final controller = StreamController<List<Sale>>();
    StreamSubscription<dynamic>? subSales;
    StreamSubscription<List<LocalSalePayment>>? subPay;
    Future<void> pump() async {
      try {
        final list = await _buildSalesSnapshot(companyId, storeId: storeId);
        if (!controller.isClosed) controller.add(list);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller.onListen = () {
      subSales = _db.watchLocalSales(companyId, storeId: storeId).listen((_) => pump());
      subPay = _db.watchAllLocalSalePayments().listen((_) => pump());
      pump();
    };
    controller.onCancel = () async {
      await subSales?.cancel();
      await subPay?.cancel();
    };
    return controller.stream;
  }

  Future<List<Sale>> _buildSalesSnapshot(String companyId, {String? storeId}) async {
    final localSales = await _db.listLocalSalesForCompany(companyId, storeId: storeId);
    if (localSales.isEmpty) return [];
    final ids = localSales.map((s) => s.id).toList();
    final allItems = await _db.getLocalSaleItemsForSales(ids);
    final allPayments = await _db.getLocalSalePaymentsForSales(ids);
    final bySaleId = <String, List<LocalSaleItem>>{};
    for (final it in allItems) {
      bySaleId.putIfAbsent(it.saleId, () => []).add(it);
    }
    final payBySaleId = <String, List<LocalSalePayment>>{};
    for (final p in allPayments) {
      payBySaleId.putIfAbsent(p.saleId, () => []).add(p);
    }
    final stores = await _db.getLocalStores(companyId);
    final storeNameById = {for (final st in stores) st.id: st.name};
    final customers = await _db.getLocalCustomersByCompany(companyId);
    final customerById = {for (final c in customers) c.id: c};
    final members = await _db.getLocalCompanyMembersByCompany(companyId);
    final sellerLabelByUserId = <String, String>{};
    for (final m in members) {
      final name = m.profileFullName?.trim();
      final email = m.email?.trim();
      if (name != null && name.isNotEmpty) {
        sellerLabelByUserId[m.userId] = name;
      } else if (email != null && email.isNotEmpty) {
        sellerLabelByUserId[m.userId] = email;
      }
    }
    return [
      for (final ls in localSales)
        _toSale(
          ls,
          bySaleId[ls.id] ?? const [],
          payments: payBySaleId[ls.id] ?? const [],
          storeNameById: storeNameById,
          customerById: customerById,
          sellerLabelByUserId: sellerLabelByUserId,
        ),
    ];
  }

  /// Détail crédit depuis Drift (lignes, produits catalogue local, paiements).
  Future<Sale?> getCreditSaleDetailOffline(String saleId, String companyId) async {
    final row = await _db.getLocalSaleById(saleId);
    if (row == null || row.companyId != companyId) return null;
    final items = await _db.getLocalSaleItems(saleId);
    final pays = await _db.getLocalSalePaymentsForSales([saleId]);
    final stores = await _db.getLocalStores(companyId);
    final storeNameById = {for (final st in stores) st.id: st.name};
    final customers = await _db.getLocalCustomersByCompany(companyId);
    final customerById = {for (final c in customers) c.id: c};
    final members = await _db.getLocalCompanyMembersByCompany(companyId);
    final sellerLabelByUserId = <String, String>{};
    for (final m in members) {
      final name = m.profileFullName?.trim();
      final email = m.email?.trim();
      if (name != null && name.isNotEmpty) {
        sellerLabelByUserId[m.userId] = name;
      } else if (email != null && email.isNotEmpty) {
        sellerLabelByUserId[m.userId] = email;
      }
    }
    final productIds = items.map((i) => i.productId).toSet();
    final products = productIds.isEmpty ? <LocalProduct>[] : await _db.getLocalProductsByIds(productIds);
    final productById = {for (final p in products) p.id: p};
    final saleItems = items.map((i) {
      final lp = productById[i.productId];
      return SaleItem(
        id: i.id,
        saleId: i.saleId,
        productId: i.productId,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        discount: 0,
        total: i.total,
        product: lp != null
            ? ProductRef(
                id: lp.id,
                name: lp.name,
                sku: lp.sku,
                unit: lp.unit,
                imageUrl: lp.imageUrl,
              )
            : ProductRef(id: i.productId, name: 'Produit', sku: null, unit: 'pce'),
      );
    }).toList();
    final base = _toSale(
      row,
      items,
      payments: pays,
      storeNameById: storeNameById,
      customerById: customerById,
      sellerLabelByUserId: sellerLabelByUserId,
    );
    final cid = row.customerId;
    CustomerRef? customerRef = base.customer;
    if (cid != null && cid.isNotEmpty) {
      final lc = customerById[cid];
      customerRef = lc != null
          ? CustomerRef(id: lc.id, name: lc.name, phone: lc.phone, address: lc.address)
          : base.customer;
    }
    return Sale(
      id: base.id,
      companyId: base.companyId,
      storeId: base.storeId,
      customerId: base.customerId,
      saleNumber: base.saleNumber,
      status: base.status,
      subtotal: base.subtotal,
      discount: base.discount,
      tax: base.tax,
      total: base.total,
      createdBy: base.createdBy,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      store: base.store,
      customer: customerRef,
      saleItems: saleItems,
      salePayments: base.salePayments,
      saleMode: base.saleMode,
      documentType: base.documentType,
      createdByLabel: base.createdByLabel,
      creditDueAt: base.creditDueAt,
      creditInternalNote: base.creditInternalNote,
    );
  }

  static String _sellerDisplayLabel(String userId, Map<String, String> sellerLabelByUserId) {
    final label = sellerLabelByUserId[userId];
    if (label != null && label.isNotEmpty) return label;
    if (userId.length >= 8) return 'Utilisateur ${userId.substring(0, 8)}…';
    return 'Utilisateur';
  }

  static Sale _toSale(
    LocalSale row,
    List<LocalSaleItem> items, {
    List<LocalSalePayment> payments = const [],
    required Map<String, String> storeNameById,
    required Map<String, LocalCustomer> customerById,
    required Map<String, String> sellerLabelByUserId,
  }) {
    final storeName = storeNameById[row.storeId];
    final storeRef = StoreRef(id: row.storeId, name: storeName?.trim().isNotEmpty == true ? storeName!.trim() : 'Boutique');
    CustomerRef? customerRef;
    final cid = row.customerId;
    if (cid != null && cid.isNotEmpty) {
      final lc = customerById[cid];
      customerRef = lc != null
          ? CustomerRef(id: lc.id, name: lc.name, phone: lc.phone)
          : CustomerRef(id: cid, name: '—', phone: null);
    }
    return Sale(
      id: row.id,
      companyId: row.companyId,
      storeId: row.storeId,
      customerId: row.customerId,
      saleNumber: row.saleNumber,
      status: SaleStatusExt.fromString(row.status),
      subtotal: row.subtotal,
      discount: row.discount,
      tax: row.tax,
      total: row.total,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      store: storeRef,
      customer: customerRef,
      saleItems: items.map((i) => SaleItem(
        id: i.id,
        saleId: i.saleId,
        productId: i.productId,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        discount: 0,
        total: i.total,
        product: null,
      )).toList(),
      salePayments: payments.isEmpty
          ? null
          : payments
              .map(
                (p) => SalePayment(
                  id: p.id,
                  saleId: p.saleId,
                  method: PaymentMethodExt.fromString(p.method),
                  amount: p.amount,
                  reference: p.reference,
                  createdAt: p.createdAt,
                ),
              )
              .toList(),
      saleMode: row.saleMode != null && row.saleMode!.isNotEmpty ? SaleMode.fromString(row.saleMode!) : null,
      documentType: row.documentType != null && row.documentType!.isNotEmpty ? DocumentType.fromString(row.documentType!) : null,
      createdByLabel: _sellerDisplayLabel(row.createdBy, sellerLabelByUserId),
      creditDueAt: row.creditDueAt,
      creditInternalNote: row.creditInternalNote,
    );
  }
}

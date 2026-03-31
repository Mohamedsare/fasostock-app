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
    return _db.watchLocalSales(companyId, storeId: storeId).asyncMap((localSales) async {
      if (localSales.isEmpty) return [];
      final ids = localSales.map((s) => s.id).toList();
      final allItems = await _db.getLocalSaleItemsForSales(ids);
      final bySaleId = <String, List<LocalSaleItem>>{};
      for (final it in allItems) {
        bySaleId.putIfAbsent(it.saleId, () => []).add(it);
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
            storeNameById: storeNameById,
            customerById: customerById,
            sellerLabelByUserId: sellerLabelByUserId,
          ),
      ];
    });
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
      salePayments: null,
      saleMode: row.saleMode != null && row.saleMode!.isNotEmpty ? SaleMode.fromString(row.saleMode!) : null,
      documentType: row.documentType != null && row.documentType!.isNotEmpty ? DocumentType.fromString(row.documentType!) : null,
      createdByLabel: _sellerDisplayLabel(row.createdBy, sellerLabelByUserId),
    );
  }
}

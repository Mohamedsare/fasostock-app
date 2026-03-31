import 'dart:async';

import 'package:drift/drift.dart';
import '../../local/drift/app_database.dart';
import '../../models/purchase.dart';
import '../../models/sale.dart' show ProductRef;

/// Offline-first purchases: UI reads from Drift; sync writes from Supabase.
class PurchasesOfflineRepository {
  PurchasesOfflineRepository(this._db);

  final AppDatabase _db;

  /// Upsert un achat en local (après création/mise à jour en ligne) — UI instantanée.
  Future<void> upsertPurchase(Purchase p) async {
    await _db.upsertLocalPurchases([
      LocalPurchasesCompanion.insert(
        id: p.id,
        companyId: p.companyId,
        storeId: p.storeId,
        supplierId: p.supplierId,
        reference: Value(p.reference),
        status: p.status.value,
        total: p.total,
        createdBy: p.createdBy,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      ),
    ]);
    await _db.deleteLocalPurchaseItemsForPurchases([p.id]);
    final items = p.purchaseItems;
    if (items != null && items.isNotEmpty) {
      await _db.upsertLocalPurchaseItems(items.map((i) => LocalPurchaseItemsCompanion.insert(
            id: i.id,
            purchaseId: i.purchaseId,
            productId: i.productId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            total: i.total,
          )));
    }
  }

  /// Stream des achats avec filtres optionnels. Réémet quand les achats en local changent (sync upsert déclenche).
  Stream<List<Purchase>> watchPurchases(
    String companyId, {
    String? storeId,
    String? supplierId,
    PurchaseStatus? status,
    String? fromDate,
    String? toDate,
  }) {
    final statusStr = status?.value;
    return _db.watchLocalPurchases(
      companyId,
      storeId: storeId,
      supplierId: supplierId,
      status: statusStr,
      fromDate: fromDate,
      toDate: toDate,
    ).asyncMap((_) => _loadPurchasesWithDetails(
          companyId,
          storeId: storeId,
          supplierId: supplierId,
          status: statusStr,
          fromDate: fromDate,
          toDate: toDate,
        ));
  }

  Future<List<Purchase>> _loadPurchasesWithDetails(
    String companyId, {
    String? storeId,
    String? supplierId,
    String? status,
    String? fromDate,
    String? toDate,
  }) async {
    final purchases = await _db.getLocalPurchases(
      companyId,
      storeId: storeId,
      supplierId: supplierId,
      status: status,
      fromDate: fromDate,
      toDate: toDate,
    );
    if (purchases.isEmpty) return [];
    final ids = purchases.map((p) => p.id).toList();
    final items = await _db.getLocalPurchaseItemsForPurchases(ids);
    final stores = await _db.getLocalStores(companyId);
    final suppliers = await _db.getLocalSuppliers(companyId);
    final storeMap = {for (final s in stores) s.id: s};
    final supplierMap = {for (final s in suppliers) s.id: s};
    final itemsByPurchase = <String, List<LocalPurchaseItem>>{};
    for (final i in items) {
      itemsByPurchase.putIfAbsent(i.purchaseId, () => []).add(i);
    }
    final productIds = items.map((i) => i.productId).toSet();
    final localProductRows = await _db.getLocalProductsByIds(productIds);
    final productById = {for (final pr in localProductRows) pr.id: pr};
    return purchases
        .map((p) => _toPurchase(p, storeMap, supplierMap, itemsByPurchase, productById))
        .toList();
  }

  /// Supprime un achat du cache local (après suppression côté serveur).
  Future<void> deletePurchase(String purchaseId) async {
    await _db.deleteLocalPurchase(purchaseId);
  }

  static Purchase _toPurchase(
    LocalPurchase p,
    Map<String, LocalStore> storeMap,
    Map<String, LocalSupplier> supplierMap,
    Map<String, List<LocalPurchaseItem>> itemsByPurchase,
    Map<String, LocalProduct> productById,
  ) {
    final store = storeMap[p.storeId];
    final supplier = supplierMap[p.supplierId];
    final itemRows = itemsByPurchase[p.id] ?? [];
    return Purchase(
      id: p.id,
      companyId: p.companyId,
      storeId: p.storeId,
      supplierId: p.supplierId,
      reference: p.reference,
      status: PurchaseStatusExt.fromString(p.status),
      total: p.total,
      createdBy: p.createdBy,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      store: store != null ? StoreRef(id: store.id, name: store.name) : null,
      supplier: supplier != null ? SupplierRef(id: supplier.id, name: supplier.name, phone: supplier.phone) : null,
      purchaseItems: itemRows
          .map((i) {
            final lp = productById[i.productId];
            return PurchaseItem(
              id: i.id,
              purchaseId: i.purchaseId,
              productId: i.productId,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              total: i.total,
              product: lp != null
                  ? ProductRef(
                      id: lp.id,
                      name: lp.name,
                      sku: lp.sku,
                      unit: lp.unit,
                      imageUrl: lp.imageUrl?.isNotEmpty == true ? lp.imageUrl : null,
                    )
                  : null,
            );
          })
          .toList(),
      purchasePayments: null,
    );
  }
}

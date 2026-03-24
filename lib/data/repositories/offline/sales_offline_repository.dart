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
      final sales = <Sale>[];
      for (final ls in localSales) {
        final items = await _db.getLocalSaleItems(ls.id);
        sales.add(_toSale(ls, items));
      }
      return sales;
    });
  }

  static Sale _toSale(LocalSale row, List<LocalSaleItem> items) {
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
      store: null,
      customer: null,
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
    );
  }
}

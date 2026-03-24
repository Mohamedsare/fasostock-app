import '../../local/drift/app_database.dart';
import '../../models/warehouse_movement.dart';
import '../../models/warehouse_stock_line.dart';

/// Magasin : lecture Drift (sync pull) ; écritures via pending + RPC au push.
class WarehouseOfflineRepository {
  WarehouseOfflineRepository(this._db);

  final AppDatabase _db;

  /// Stream combiné inventaire + produits pour l’UI offline-first.
  Stream<List<WarehouseStockLine>> watchStockLines(String companyId) {
    if (companyId.isEmpty) return Stream.value([]);
    return _db.watchLocalWarehouseInventory(companyId).asyncMap((invRows) async {
      if (invRows.isEmpty) return <WarehouseStockLine>[];
      final products = await _db.getLocalProducts(companyId);
      final byId = {for (final p in products) p.id: p};
      return invRows.map((r) {
        final p = byId[r.productId];
        return WarehouseStockLine(
          productId: r.productId,
          quantity: r.quantity,
          productName: p?.name ?? '—',
          sku: p?.sku,
          unit: p?.unit ?? 'pce',
          avgUnitCost: r.avgUnitCost,
          purchasePrice: p?.purchasePrice ?? 0,
          salePrice: p?.salePrice ?? 0,
          stockMin: p?.stockMin ?? 0,
          stockMinWarehouse: r.stockMinWarehouse,
          updatedAt: r.updatedAt,
        );
      }).toList();
    });
  }

  Stream<List<WarehouseMovement>> watchMovements(String companyId, {int limit = 200}) {
    if (companyId.isEmpty) return Stream.value([]);
    return _db.watchLocalWarehouseMovements(companyId, limit: limit).asyncMap((rows) async {
      if (rows.isEmpty) return <WarehouseMovement>[];
      final products = await _db.getLocalProducts(companyId);
      final byId = {for (final p in products) p.id: p};
      return rows.map((m) {
        final p = byId[m.productId];
        return WarehouseMovement(
          id: m.id,
          productId: m.productId,
          movementKind: m.movementKind,
          quantity: m.quantity,
          unitCost: m.unitCost,
          packagingType: m.packagingType,
          packsQuantity: m.packsQuantity,
          referenceType: m.referenceType,
          referenceId: m.referenceId,
          notes: m.notes,
          createdAt: m.createdAt,
          productName: p?.name,
          productSku: p?.sku,
        );
      }).toList();
    });
  }
}

import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/stock_transfer.dart';

/// Offline-first transfers: UI reads from Drift; sync writes from Supabase.
class TransfersOfflineRepository {
  TransfersOfflineRepository(this._db);

  final AppDatabase _db;

  /// Enregistre ou met à jour un transfert en local (après création en ligne ou en attente de sync).
  Future<void> upsertTransfer(StockTransfer t) async {
    await _db.upsertLocalTransfers([
      LocalTransfersCompanion.insert(
        id: t.id,
        companyId: t.companyId,
        fromStoreId: t.fromStoreId,
        toStoreId: t.toStoreId,
        fromWarehouse: const Value(false),
        status: t.status.value,
        requestedBy: t.requestedBy,
        approvedBy: Value(t.approvedBy),
        shippedAt: Value(t.shippedAt),
        receivedAt: Value(t.receivedAt),
        receivedBy: Value(t.receivedBy),
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
      ),
    ]);
    await _db.deleteLocalTransferItemsForTransfers([t.id]);
    final items = t.items;
    if (items != null && items.isNotEmpty) {
      await _db.upsertLocalTransferItems(
        items.map(
          (i) => LocalTransferItemsCompanion.insert(
            id: i.id,
            transferId: i.transferId,
            productId: i.productId,
            quantityRequested: i.quantityRequested,
            quantityShipped: Value(i.quantityShipped),
            quantityReceived: Value(i.quantityReceived),
          ),
        ),
      );
    }
  }

  /// Stream des transferts (filtres optionnels). Réémet quand les transferts en local changent.
  Stream<List<StockTransfer>> watchTransfers(
    String companyId, {
    String? fromStoreId,
    String? toStoreId,
    TransferStatus? status,
    String? fromDate,
    String? toDate,
  }) {
    final statusStr = status?.value;
    return _db
        .watchLocalTransfers(
          companyId,
          fromStoreId: fromStoreId,
          toStoreId: toStoreId,
          status: statusStr,
          fromDate: fromDate,
          toDate: toDate,
        )
        .asyncMap(
          (_) => _loadTransfersWithDetails(
            companyId,
            fromStoreId: fromStoreId,
            toStoreId: toStoreId,
            status: statusStr,
            fromDate: fromDate,
            toDate: toDate,
          ),
        );
  }

  Future<List<StockTransfer>> _loadTransfersWithDetails(
    String companyId, {
    String? fromStoreId,
    String? toStoreId,
    String? status,
    String? fromDate,
    String? toDate,
  }) async {
    final transfers = await _db.getLocalTransfers(
      companyId,
      fromStoreId: fromStoreId,
      toStoreId: toStoreId,
      status: status,
      fromDate: fromDate,
      toDate: toDate,
    );
    if (transfers.isEmpty) return [];
    final ids = transfers.map((t) => t.id).toList();
    final items = await _db.getLocalTransferItemsForTransfers(ids);
    final itemsByTransfer = <String, List<LocalTransferItem>>{};
    for (final i in items) {
      itemsByTransfer.putIfAbsent(i.transferId, () => []).add(i);
    }
    return transfers
        .map((t) => _toStockTransfer(t, itemsByTransfer[t.id] ?? []))
        .toList();
  }

  static StockTransfer _toStockTransfer(
    LocalTransfer t,
    List<LocalTransferItem> itemRows,
  ) {
    return StockTransfer(
      id: t.id,
      companyId: t.companyId,
      fromStoreId: t.fromStoreId,
      toStoreId: t.toStoreId,
      fromWarehouse: false,
      status: TransferStatusExt.fromString(t.status),
      requestedBy: t.requestedBy,
      approvedBy: t.approvedBy,
      shippedAt: t.shippedAt,
      receivedAt: t.receivedAt,
      receivedBy: t.receivedBy,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
      items: itemRows
          .map(
            (i) => StockTransferItem(
              id: i.id,
              transferId: i.transferId,
              productId: i.productId,
              quantityRequested: i.quantityRequested,
              quantityShipped: i.quantityShipped,
              quantityReceived: i.quantityReceived,
              productName: null,
            ),
          )
          .toList(),
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock_transfer.dart';

/// Transferts de stock — aligné avec transfersApi (web).
class TransfersRepository {
  TransfersRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _transferSelect =
      'id, company_id, from_store_id, to_store_id, status, requested_by, approved_by, shipped_at, received_at, received_by, created_at, updated_at';

  Future<List<StockTransfer>> list(
    String companyId, {
    String? fromStoreId,
    String? toStoreId,
    TransferStatus? status,
    String? fromDate,
    String? toDate,
  }) async {
    var q = _client
        .from('stock_transfers')
        .select(_transferSelect)
        .eq('company_id', companyId);
    if (fromStoreId != null) q = q.eq('from_store_id', fromStoreId);
    if (toStoreId != null) q = q.eq('to_store_id', toStoreId);
    if (status != null) q = q.eq('status', status.value);
    if (fromDate != null) q = q.gte('created_at', fromDate);
    if (toDate != null) q = q.lte('created_at', '${toDate}T23:59:59.999Z');
    final data = await q.order('created_at', ascending: false);
    return (data as List)
        .map((e) => StockTransfer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<StockTransfer?> get(String id) async {
    final data = await _client
        .from('stock_transfers')
        .select(_transferSelect)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    final t = StockTransfer.fromJson(Map<String, dynamic>.from(data as Map));
    final items = await _getItems(id);
    return StockTransfer(
      id: t.id,
      companyId: t.companyId,
      fromStoreId: t.fromStoreId,
      toStoreId: t.toStoreId,
      status: t.status,
      requestedBy: t.requestedBy,
      approvedBy: t.approvedBy,
      shippedAt: t.shippedAt,
      receivedAt: t.receivedAt,
      receivedBy: t.receivedBy,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
      items: items,
    );
  }

  Future<List<StockTransferItem>> _getItems(String transferId) async {
    final data = await _client
        .from('stock_transfer_items')
        .select(
          'id, transfer_id, product_id, quantity_requested, quantity_shipped, quantity_received, product:products(id, name)',
        )
        .eq('transfer_id', transferId);
    return (data as List)
        .map(
          (e) =>
              StockTransferItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Récupère les lignes pour plusieurs transferts en une requête (sync offline).
  Future<List<StockTransferItem>> getItemsForTransferIds(
    List<String> transferIds,
  ) async {
    if (transferIds.isEmpty) return [];
    final data = await _client
        .from('stock_transfer_items')
        .select(
          'id, transfer_id, product_id, quantity_requested, quantity_shipped, quantity_received',
        )
        .inFilter('transfer_id', transferIds);
    return (data as List)
        .map(
          (e) =>
              StockTransferItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<StockTransfer> create(CreateTransferInput input, String userId) async {
    if (input.fromStoreId == null || input.fromStoreId!.isEmpty) {
      throw Exception('Choisissez la boutique d\'origine');
    }
    if (input.fromStoreId == input.toStoreId) {
      throw Exception('La boutique d\'origine et la destination doivent être différentes');
    }
    final validItems = input.items
        .where((i) => i.productId.isNotEmpty && i.quantityRequested > 0)
        .toList();
    if (validItems.isEmpty)
      throw Exception(
        'Ajoutez au moins une ligne avec produit et quantité > 0',
      );

    final row = <String, dynamic>{
      'company_id': input.companyId,
      'from_store_id': input.fromStoreId,
      'to_store_id': input.toStoreId,
      'status': 'draft',
      'requested_by': userId,
    };

    final transferData = await _client
        .from('stock_transfers')
        .insert(row)
        .select()
        .single();
    final transfer = StockTransfer.fromJson(
      Map<String, dynamic>.from(transferData as Map),
    );

    await _client
        .from('stock_transfer_items')
        .insert(
          validItems
              .map(
                (i) => {
                  'transfer_id': transfer.id,
                  'product_id': i.productId,
                  'quantity_requested': i.quantityRequested,
                },
              )
              .toList(),
        );

    final full = await get(transfer.id);
    return full ?? transfer;
  }

  Future<void> ship(String id, String userId) async {
    await _client.rpc(
      'ship_transfer',
      params: {'p_transfer_id': id, 'p_user_id': userId},
    );
  }

  Future<void> receive(String id, String userId) async {
    await _client.rpc(
      'receive_transfer',
      params: {'p_transfer_id': id, 'p_user_id': userId},
    );
  }

  Future<void> cancel(String id) async {
    final t = await get(id);
    if (t == null) throw Exception('Transfert non trouvé');
    if (t.status != TransferStatus.draft &&
        t.status != TransferStatus.pending) {
      throw Exception(
        'Seuls les brouillons ou en attente peuvent être annulés',
      );
    }
    await _client
        .from('stock_transfers')
        .update({'status': 'cancelled'})
        .eq('id', id);
  }
}

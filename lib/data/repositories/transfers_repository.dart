import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error_handler.dart';
import '../models/stock_transfer.dart';

/// Transferts de stock — aligné avec transfersApi (web).
class TransfersRepository {
  TransfersRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static String _toSafeMessage(Object? e) => ErrorMapper.toMessage(e);

  static const _transferSelect =
      'id, company_id, from_store_id, to_store_id, from_warehouse, status, requested_by, approved_by, shipped_at, received_at, received_by, created_at, updated_at';

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
      fromWarehouse: t.fromWarehouse,
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
    if (!input.fromWarehouse &&
        (input.fromStoreId == null || input.fromStoreId!.isEmpty)) {
      throw const UserFriendlyError('Choisissez la boutique d\'origine');
    }
    if (!input.fromWarehouse && input.fromStoreId == input.toStoreId) {
      throw const UserFriendlyError(
        'La boutique d\'origine et la destination doivent être différentes',
      );
    }
    final validItems = input.items
        .where((i) => i.productId.isNotEmpty && i.quantityRequested > 0)
        .toList();
    if (validItems.isEmpty) {
      throw const UserFriendlyError(
        'Ajoutez au moins une ligne avec produit et quantité > 0',
      );
    }

    final row = <String, dynamic>{
      'company_id': input.companyId,
      'from_store_id': input.fromWarehouse ? null : input.fromStoreId,
      'to_store_id': input.toStoreId,
      'from_warehouse': input.fromWarehouse,
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
    final current = await get(id);
    if (current == null) {
      throw const UserFriendlyError('Transfert introuvable.');
    }
    if (current.status == TransferStatus.shipped ||
        current.status == TransferStatus.received) {
      // Idempotent côté app: déjà expédié/réceptionné => pas d'erreur bloquante.
      return;
    }
    if (current.status != TransferStatus.draft &&
        current.status != TransferStatus.approved) {
      throw const UserFriendlyError(
        'Seuls les transferts en brouillon ou approuvés peuvent être expédiés.',
      );
    }
    try {
      await _client.rpc(
        'ship_transfer',
        params: {'p_transfer_id': id, 'p_user_id': userId},
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('statut actuel: shipped') ||
          msg.contains('cannot ship transfer in status') &&
              msg.contains('shipped')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> receive(String id, String userId) async {
    final current = await get(id);
    if (current == null) {
      throw const UserFriendlyError('Transfert introuvable.');
    }
    if (current.status == TransferStatus.received) {
      await _assertTransferFullyReceived(id);
      return;
    }
    if (current.status != TransferStatus.shipped) {
      throw const UserFriendlyError(
        'Le transfert doit être expédié avant la réception.',
      );
    }
    try {
      await _client.rpc(
        'receive_transfer',
        params: {'p_transfer_id': id, 'p_user_id': userId},
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('statut actuel: received') ||
          (msg.contains('cannot receive transfer in status') &&
              msg.contains('received'))) {
        await _assertTransferFullyReceived(id);
        return;
      }
      rethrow;
    }
    await _assertTransferFullyReceived(id);
  }

  /// Vérifie côté API que le transfert est bien en « reçu » et que les lignes sont créditées.
  Future<void> _assertTransferFullyReceived(String id) async {
    final verified = await get(id);
    if (verified == null || verified.status != TransferStatus.received) {
      throw const UserFriendlyError(
        'Réception non confirmée : le stock boutique n’a pas été mis à jour. Réessayez.',
      );
    }
    final items = verified.items;
    if (items == null || items.isEmpty) return;
    for (final line in items) {
      if (line.quantityShipped <= 0) continue;
      if (line.quantityReceived != line.quantityShipped) {
        throw const UserFriendlyError(
          'Réception incomplète sur une ou plusieurs lignes. Vérifiez le transfert.',
        );
      }
    }
  }

  /// Dépôt → boutique : le stock boutique n'est crédité qu'après receive_transfer.
  /// Enchaîne ship puis receive pour éviter l'oubli de la réception.
  Future<void> shipThenReceive(String id, String userId) async {
    await ship(id, userId);
    final afterShip = await get(id);
    if (afterShip == null) {
      throw const UserFriendlyError('Transfert introuvable après expédition.');
    }
    if (afterShip.status == TransferStatus.received) {
      await _assertTransferFullyReceived(id);
      return;
    }
    if (afterShip.status != TransferStatus.shipped) {
      throw const UserFriendlyError(
        'Réception impossible : le transfert n’est pas en statut expédié.',
      );
    }
    await receive(id, userId);
  }

  Future<void> cancel(String id) async {
    final t = await get(id);
    if (t == null) {
      throw const UserFriendlyError('Transfert non trouvé');
    }
    if (t.status != TransferStatus.draft &&
        t.status != TransferStatus.pending) {
      throw const UserFriendlyError(
        'Seuls les brouillons ou en attente peuvent être annulés',
      );
    }
    await _client
        .from('stock_transfers')
        .update({'status': 'cancelled'})
        .eq('id', id);
  }

  /// Supprime définitivement le transfert et ses lignes (CASCADE). Réservé aux brouillons ou annulés.
  Future<void> deletePermanently(String id) async {
    final t = await get(id);
    if (t == null) {
      throw const UserFriendlyError('Transfert introuvable.');
    }
    if (t.status != TransferStatus.draft &&
        t.status != TransferStatus.cancelled) {
      throw const UserFriendlyError(
        'Seuls les brouillons ou les transferts annulés peuvent être supprimés.',
      );
    }
    try {
      await _client.from('stock_transfers').delete().eq('id', id);
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }
}

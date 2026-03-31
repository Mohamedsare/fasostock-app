import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../local/drift/app_database.dart';

/// Pousse les changements `store_inventory` Supabase (Realtime + RLS) vers Drift,
/// pour que tous les appareils voient le stock à jour sans sync manuelle (annulation vente, transferts, etc.).
class StoreInventoryRealtimeSync {
  StoreInventoryRealtimeSync(this._db);

  final AppDatabase _db;
  RealtimeChannel? _channel;

  /// Canal **privé** requis pour que Realtime applique le JWT et les politiques RLS
  /// sur `postgres_changes` — avec `private: false` (défaut), les changements filtrés
  /// par boutique / société n’arrivent souvent pas aux autres appareils.
  static const RealtimeChannelConfig _channelConfig = RealtimeChannelConfig(
    private: true,
  );

  Future<void> start() async {
    if (_channel != null) return;
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final token = client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return;

    // Evite la course « souscription avant setAuth » au démarrage : sans JWT sur le socket,
    // le join Realtime n’autorise pas les lignes visibles via RLS.
    try {
      await client.realtime.setAuth(token);
    } catch (e, st) {
      AppErrorHandler.log('StoreInventoryRealtime.setAuth: $e', st);
      return;
    }

    if (_channel != null) return;

    _channel = client.channel(
      'fasostock-store-inventory-$uid',
      opts: _channelConfig,
    );
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'store_inventory',
          callback: _onPayload,
        )
        .subscribe((status, [error]) {
          if (kDebugMode) {
            debugPrint('[StoreInventoryRealtime] $status ${error ?? ''}');
          }
        });
  }

  Future<void> _onPayload(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          await _applyRow(payload.newRecord);
          break;
        case PostgresChangeEvent.delete:
          await _applyDelete(payload.oldRecord);
          break;
        default:
          break;
      }
    } catch (e, st) {
      AppErrorHandler.log('StoreInventoryRealtime: $e', st);
    }
  }

  static String? _uuid(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  Future<void> _applyRow(Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    final storeId = _uuid(row['store_id']);
    final productId = _uuid(row['product_id']);
    if (storeId == null || productId == null) return;
    final q = (row['quantity'] as num?)?.toInt() ?? 0;
    final r = (row['reserved_quantity'] as num?)?.toInt() ?? 0;
    final updatedAt =
        row['updated_at'] as String? ?? DateTime.now().toUtc().toIso8601String();
    await _db.upsertStoreInventoryFromRemote(
      storeId: storeId,
      productId: productId,
      quantity: q,
      reservedQuantity: r,
      updatedAt: updatedAt,
    );
  }

  Future<void> _applyDelete(Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    final storeId = _uuid(row['store_id']);
    final productId = _uuid(row['product_id']);
    if (storeId == null || productId == null) return;
    await _db.deleteStoreInventoryRow(storeId, productId);
  }

  Future<void> stop() async {
    final c = _channel;
    _channel = null;
    if (c != null) {
      try {
        await Supabase.instance.client.removeChannel(c);
      } catch (e, st) {
        AppErrorHandler.log('StoreInventoryRealtime.stop: $e', st);
      }
    }
  }
}

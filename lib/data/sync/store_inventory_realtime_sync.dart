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
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _stopped = true;
  static const int _maxReconnectBackoffSeconds = 30;

  /// `private: false` : filtrage via RLS sur `store_inventory` + `setAuth` (doc Supabase :
  /// l’option private ne s’applique pas aux postgres_changes ; `private: true` impose
  /// des policies sur `realtime.messages` et peut refuser le join).
  static const RealtimeChannelConfig _channelConfig = RealtimeChannelConfig(
    private: false,
  );

  Future<void> start() async {
    _stopped = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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
          final statusText = status.toString().toLowerCase();
          if (kDebugMode) {
            debugPrint('[StoreInventoryRealtime] $status ${error ?? ''}');
          }
          if (statusText.contains('subscribed')) {
            _reconnectAttempt = 0;
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
          }
          if (error != null) {
            AppErrorHandler.logWithContext(
              error,
              logSource: 'store_inventory_realtime',
              logContext: {'channel_status': status.toString()},
            );
            _scheduleReconnect('error');
            return;
          }
          if (statusText.contains('closed') ||
              statusText.contains('timedout') ||
              statusText.contains('channelerror')) {
            _scheduleReconnect(status.toString());
          }
        });
  }

  void _scheduleReconnect(String reason) {
    if (_stopped) return;
    if (_reconnectTimer != null) return;
    final attempt = _reconnectAttempt;
    final powSeconds = 1 << (attempt > 5 ? 5 : attempt);
    final seconds = powSeconds > _maxReconnectBackoffSeconds
        ? _maxReconnectBackoffSeconds
        : powSeconds;
    final jitterMs = DateTime.now().millisecond % 400;
    _reconnectTimer = Timer(
      Duration(seconds: seconds, milliseconds: jitterMs),
      () async {
        _reconnectTimer = null;
        if (_stopped) return;
        _reconnectAttempt = _reconnectAttempt + 1;
        final c = _channel;
        _channel = null;
        if (c != null) {
          try {
            await Supabase.instance.client.removeChannel(c);
          } catch (e, st) {
            AppErrorHandler.logWithContext(
              e,
              stackTrace: st,
              logSource: 'store_inventory_realtime',
              logContext: const {'op': 'removeChannel_reconnect'},
            );
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[StoreInventoryRealtime] reconnect attempt=$_reconnectAttempt reason=$reason',
          );
        }
        await start();
      },
    );
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
        row['updated_at'] as String? ??
        DateTime.now().toUtc().toIso8601String();
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
    _stopped = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../repositories/offline/products_offline_repository.dart';

/// Pousse les changements `public.products` (Realtime + RLS) vers Drift.
/// Complète [SyncServiceV2] / pull ; les images restent gérées par pull ou ligne locale conservée.
class ProductsRealtimeSync {
  ProductsRealtimeSync(this._productsOffline);

  final ProductsOfflineRepository _productsOffline;
  RealtimeChannel? _channel;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _stopped = true;
  static const int _maxReconnectBackoffSeconds = 30;

  static bool _isChannelPermissionError(Object? error) {
    if (error == null) return false;
    final s = error.toString().toLowerCase();
    return (s.contains('unauthorized') && s.contains('channel')) ||
        s.contains('permissions to read') ||
        s.contains('topic:');
  }

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

    try {
      await client.realtime.setAuth(token);
    } catch (e, st) {
      AppErrorHandler.log('ProductsRealtime.setAuth: $e', st);
      return;
    }

    if (_channel != null) return;

    _channel = client.channel(
      'fasostock-products-$uid',
      opts: _channelConfig,
    );
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: _onPayload,
        )
        .subscribe((status, [error]) {
          final statusText = status.toString().toLowerCase();
          if (kDebugMode) {
            debugPrint('[ProductsRealtime] $status ${error ?? ''}');
          }
          if (statusText.contains('subscribed')) {
            _reconnectAttempt = 0;
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
          }
          if (error != null) {
            if (_isChannelPermissionError(error)) {
              if (kDebugMode) {
                debugPrint(
                  '[ProductsRealtime] permission canal ignorée — vérifiez Realtime '
                  'pour les canaux privés (catalogue mis à jour par sync pull).',
                );
              }
              final c = _channel;
              _channel = null;
              if (c != null) {
                unawaited(Supabase.instance.client.removeChannel(c));
              }
              return;
            }
            AppErrorHandler.logWithContext(
              error,
              logSource: 'products_realtime',
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
    final seconds = powSeconds > _maxReconnectBackoffSeconds ? _maxReconnectBackoffSeconds : powSeconds;
    final jitterMs = DateTime.now().millisecond % 400;
    _reconnectTimer = Timer(Duration(seconds: seconds, milliseconds: jitterMs), () async {
      _reconnectTimer = null;
      if (_stopped) return;
      _reconnectAttempt = _reconnectAttempt + 1;
      final c = _channel;
      _channel = null;
      if (c != null) {
        try {
          await Supabase.instance.client.removeChannel(c);
        } catch (_) {}
      }
      if (kDebugMode) {
        debugPrint('[ProductsRealtime] reconnect attempt=$_reconnectAttempt reason=$reason');
      }
      await start();
    });
  }

  Future<void> _onPayload(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          await _productsOffline.applyRealtimeRow(
            Map<String, dynamic>.from(payload.newRecord),
          );
          break;
        case PostgresChangeEvent.delete:
          await _applyDelete(payload.oldRecord);
          break;
        default:
          break;
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'products_realtime',
        logContext: {'phase': 'payload'},
      );
    }
  }

  Future<void> _applyDelete(Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    await _productsOffline.removeLocalByProductId(id);
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
        AppErrorHandler.log('ProductsRealtime.stop: $e', st);
      }
    }
  }
}

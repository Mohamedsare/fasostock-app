import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../local/drift/app_database.dart';
import '../repositories/sales_repository.dart';

/// Realtime `sale_payments` → Drift (complète [SalesRealtimeSync] quand seuls les paiements changent).
class SalePaymentsRealtimeSync {
  SalePaymentsRealtimeSync(this._db);

  final AppDatabase _db;
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
      AppErrorHandler.log('SalePaymentsRealtime.setAuth: $e', st);
      return;
    }

    _channel = client.channel(
      'fasostock-sale-payments-$uid',
      opts: _channelConfig,
    );
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sale_payments',
          callback: _onPayload,
        )
        .subscribe((status, [error]) {
          final statusText = status.toString().toLowerCase();
          if (kDebugMode) {
            debugPrint('[SalePaymentsRealtime] $status ${error ?? ''}');
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
                  '[SalePaymentsRealtime] permission canal ignorée — sync crédit par pull inchangée.',
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
              logSource: 'sale_payments_realtime',
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
              logSource: 'sale_payments_realtime',
              logContext: const {'op': 'removeChannel_reconnect'},
            );
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[SalePaymentsRealtime] reconnect attempt=$_reconnectAttempt reason=$reason',
          );
        }
        await start();
      },
    );
  }

  static String? _saleIdFromRecord(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;
    final v = raw['sale_id'];
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  Future<void> _onPayload(PostgresChangePayload payload) async {
    try {
      final sid =
          _saleIdFromRecord(payload.newRecord) ??
          _saleIdFromRecord(payload.oldRecord);
      if (sid == null || sid.isEmpty || sid.startsWith('pending:')) return;
      final repo = SalesRepository();
      final pays = await repo.getPayments(sid);
      final now = DateTime.now().toUtc().toIso8601String();
      await _db.replaceLocalSalePaymentsFromModels(sid, pays, now);
    } catch (e, st) {
      AppErrorHandler.log('SalePaymentsRealtime: $e', st);
    }
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
        AppErrorHandler.log('SalePaymentsRealtime.stop: $e', st);
      }
    }
  }
}

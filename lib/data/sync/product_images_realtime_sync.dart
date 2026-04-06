import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../repositories/offline/products_offline_repository.dart';

/// Realtime sur `public.product_images` → re-fetch des images pour le produit concerné
/// et mise à jour de la vignette dans Drift (`local_products.image_url`).
class ProductImagesRealtimeSync {
  ProductImagesRealtimeSync(this._productsOffline);

  final ProductsOfflineRepository _productsOffline;
  RealtimeChannel? _channel;
  final Map<String, Timer> _debounceByProduct = {};
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _stopped = true;
  static const int _maxReconnectBackoffSeconds = 30;

  static const Duration _debounce = Duration(milliseconds: 280);

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
      AppErrorHandler.log('ProductImagesRealtime.setAuth: $e', st);
      return;
    }

    if (_channel != null) return;

    _channel = client.channel(
      'fasostock-product-images-$uid',
      opts: _channelConfig,
    );
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_images',
          callback: _onPayload,
        )
        .subscribe((status, [error]) {
          final statusText = status.toString().toLowerCase();
          if (kDebugMode) {
            debugPrint('[ProductImagesRealtime] $status ${error ?? ''}');
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
                  '[ProductImagesRealtime] permission canal ignorée — images via sync pull.',
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
              logSource: 'product_images_realtime',
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
        debugPrint('[ProductImagesRealtime] reconnect attempt=$_reconnectAttempt reason=$reason');
      }
      await start();
    });
  }

  void _scheduleRefreshForProduct(String? productId) {
    if (productId == null || productId.isEmpty) return;
    _debounceByProduct[productId]?.cancel();
    _debounceByProduct[productId] = Timer(_debounce, () {
      _debounceByProduct.remove(productId);
      unawaited(_productsOffline.refreshPrimaryImageFromRemote(productId));
    });
  }

  Future<void> _onPayload(PostgresChangePayload payload) async {
    try {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
        case PostgresChangeEvent.update:
          _scheduleRefreshForProduct(
            payload.newRecord['product_id']?.toString(),
          );
          break;
        case PostgresChangeEvent.delete:
          _scheduleRefreshForProduct(
            payload.oldRecord['product_id']?.toString(),
          );
          break;
        default:
          break;
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'product_images_realtime',
        logContext: const {'phase': 'payload'},
      );
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    for (final t in _debounceByProduct.values) {
      t.cancel();
    }
    _debounceByProduct.clear();
    final c = _channel;
    _channel = null;
    if (c != null) {
      try {
        await Supabase.instance.client.removeChannel(c);
      } catch (e, st) {
        AppErrorHandler.log('ProductImagesRealtime.stop: $e', st);
      }
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remontée des erreurs applicatives vers Supabase (visible côté super admin).
///
/// - Tolérant aux pannes réseau (ne lance jamais d'exception)
/// - Déduplication courte pour éviter le spam en boucle
class RemoteErrorLogger {
  RemoteErrorLogger._();

  static DateTime? _lastSentAt;
  static String? _lastFingerprint;
  static const Duration _dedupeWindow = Duration(seconds: 5);

  static Future<void> capture(
    Object? error, {
    StackTrace? stackTrace,
    String source = 'app',
    String level = 'error',
    Map<String, dynamic>? context,
  }) async {
    if (error == null) return;

    final message = error.toString();
    final firstStackLine = stackTrace
        ?.toString()
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .firstOrNull;
    final fingerprint = '${error.runtimeType}|$message|$firstStackLine|$source';
    final now = DateTime.now();

    if (_lastFingerprint == fingerprint &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < _dedupeWindow) {
      return;
    }

    _lastFingerprint = fingerprint;
    _lastSentAt = now;

    try {
      final client = Supabase.instance.client;
      await client.rpc(
        'log_app_error',
        params: {
          'p_source': source,
          'p_level': level,
          'p_message': message,
          'p_stack_trace': stackTrace?.toString(),
          'p_error_type': error.runtimeType.toString(),
          'p_platform': defaultTargetPlatform.name,
          'p_context': context,
        },
      );
    } catch (_) {
      // Silence: la remontée d'erreur ne doit jamais casser l'app.
    }
  }
}


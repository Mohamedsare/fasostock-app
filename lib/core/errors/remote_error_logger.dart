import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/sensitive_data_scrubber.dart';

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

    final message = SensitiveDataScrubber.scrub(error.toString());
    final stackStr = stackTrace != null
        ? SensitiveDataScrubber.scrub(stackTrace.toString())
        : null;
    final firstStackLine = stackStr
        ?.split('\n')
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

    final mergedContext = <String, dynamic>{
      'client_kind': 'flutter',
      if (context != null) ...context,
    };

    try {
      final client = Supabase.instance.client;
      await client.rpc(
        'log_app_error',
        params: {
          'p_source': source,
          'p_level': level,
          'p_message': message,
          'p_stack_trace': stackStr,
          'p_error_type': error.runtimeType.toString(),
          'p_platform': defaultTargetPlatform.name,
          'p_context': mergedContext,
        },
      );
    } catch (_) {
      // Silence: la remontée d'erreur ne doit jamais casser l'app.
    }
  }
}


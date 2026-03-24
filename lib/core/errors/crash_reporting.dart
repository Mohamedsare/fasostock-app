import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';
import '../config/env.dart';

/// Remontée d'erreurs en prod (Sentry). Désactivé si [Env.sentryDsn] est vide.
class CrashReporting {
  CrashReporting._();

  static bool _initialized = false;
  static bool get isEnabled => _initialized;

  /// Initialise Sentry si SENTRY_DSN est défini au build. À appeler une fois au démarrage.
  static Future<void> init() async {
    final dsn = Env.sentryDsn.trim();
    if (dsn.isEmpty) return;
    try {
      await Sentry.init(
        (options) {
          options.dsn = dsn;
          options.debug = kDebugMode;
          options.environment = kReleaseMode ? 'production' : 'debug';
        },
      );
      _initialized = true;
    } catch (_) {
      // Ne pas faire échouer le démarrage si Sentry échoue
    }
  }

  /// Envoie une erreur à Sentry (no-op si désactivé).
  static void captureException(Object? error, [StackTrace? stackTrace]) {
    if (!_initialized || error == null) return;
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );
  }
}

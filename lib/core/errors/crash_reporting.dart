import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';
import '../config/env.dart';
import '../security/sensitive_data_scrubber.dart';

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
          options.sendDefaultPii = false;
          options.beforeSend = (SentryEvent event, Hint hint) {
            if (_shouldDropSentryEvent(event)) {
              return null;
            }
            return _scrubSentryEvent(event);
          };
        },
      );
      _initialized = true;
    } catch (_) {
      // Ne pas faire échouer le démarrage si Sentry échoue
    }
  }

  static bool _shouldDropSentryEvent(SentryEvent event) {
    final t = event.throwable;
    if (t is AssertionError) {
      final st = t.stackTrace?.toString() ?? '';
      if (st.contains('hardware_keyboard.dart') &&
          st.contains('_assertEventIsRegular')) {
        return true;
      }
    }
    return false;
  }

  static SentryEvent _scrubSentryEvent(SentryEvent event) {
    final msg = event.message;
    if (msg == null) return event;
    final formatted = msg.formatted;
    if (formatted.isEmpty) return event;
    final scrubbed = SensitiveDataScrubber.scrub(formatted);
    if (scrubbed == formatted) return event;
    return event.copyWith(
      message: SentryMessage(scrubbed),
    );
  }

  /// Envoie une erreur à Sentry (no-op si désactivé).
  static void captureException(Object? error, [StackTrace? stackTrace]) {
    if (!_initialized || error == null) return;
    if (_shouldSkipCapture(error, stackTrace)) return;
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );
  }

  /// Ne pas polluer Sentry avec des erreurs de framework connues / non actionnables.
  static bool _shouldSkipCapture(Object error, StackTrace? stackTrace) {
    if (error is AssertionError) {
      final st = stackTrace?.toString() ?? '';
      if (st.contains('hardware_keyboard.dart') &&
          st.contains('_assertEventIsRegular')) {
        return true;
      }
    }
    final msg = error.toString();
    // Fermetures WebSocket Realtime (reconnexion automatique) — bruit sans action côté app.
    if (msg.contains('RealtimeCloseEvent')) return true;
    return false;
  }
}

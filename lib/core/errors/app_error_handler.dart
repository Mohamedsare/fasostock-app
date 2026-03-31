import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_messages.dart';
import 'remote_error_logger.dart';
import '../utils/app_toast.dart';

/// Message d'erreur destiné à l'utilisateur — jamais de détail technique.
class UserFriendlyError {
  const UserFriendlyError(this.message);
  final String message;
}

/// Transforme toute exception ou erreur en message utilisateur clair.
/// Aucun message technique (stack, code, API, Dart) n'est jamais retourné.
class ErrorMapper {
  ErrorMapper._();

  static const String _network = 'Connexion internet indisponible. Vérifiez votre connexion.';
  static const String _auth = 'Email ou mot de passe incorrect.';
  static const String _permission = "Vous n'avez pas l'autorisation d'effectuer cette action.";
  static const String _unexpected = "Une erreur inattendue s'est produite. Veuillez réessayer.";
  static const String _genericFallback = "Une erreur s'est produite.";

  /// Retourne un message lisible et professionnel. Ne jamais afficher [error] brut à l'utilisateur.
  static String toMessage(Object? error, {String? fallback}) {
    if (error == null) return fallback ?? _unexpected;
    // Message déjà rédigé pour l'utilisateur (ex. repository, validation).
    if (error is UserFriendlyError) return error.message;

    // PostgREST : le message PostgreSQL est dans [PostgrestException.message], pas dans toString().
    String str;
    if (error is PostgrestException) {
      final pe = error;
      str = pe.message.trim();
      if (str.isEmpty && pe.details != null) {
        str = pe.details.toString().trim();
      }
      if (str.isEmpty) {
        str = error.toString().trim();
      }
    } else {
      str = error.toString().trim();
    }
    final lower = str.toLowerCase();

    // Réseau
    if (_isNetworkError(error, str, lower)) return _network;

    // Timeout
    if (lower.contains('timeout') || lower.contains('timed out')) return _network;

    // Auth (Supabase AuthException)
    if (error is AuthException) {
      final translated = ErrorMessages.translate(error.message, code: error.statusCode);
      if (translated != _genericFallback) return translated;
      return _auth;
    }

    // Permission / RLS / Forbidden (ne pas utiliser « accès refusé » seul : les RPC français l’emploient avec un détail utile)
    if (lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        lower.contains('forbidden') ||
        lower.contains('policy') && lower.contains('violates')) {
      return _permission;
    }

    // Session expirée / JWT invalide (Edge Function 401, etc.)
    if (lower.contains('invalid jwt') || lower.contains('jwt expired') || str.contains('401') || lower.contains('unauthorized')) {
      return 'Session expirée. Reconnectez-vous.';
    }

    // Transfert (expédition) : message explicite renvoyé par ship_transfer (PostgreSQL)
    if (lower.contains('stock insuffisant')) {
      final start = lower.indexOf('stock insuffisant');
      var end = str.length;
      for (final sep in [', code:', '\n', 'Details:', 'details:', ' (see ']) {
        final i = str.indexOf(sep, start);
        if (i != -1 && i < end) end = i;
      }
      var msg = str.substring(start, end).trim();
      // Retire les références techniques entre parenthèses: "(référence: uuid)"
      msg = msg.replaceAll(RegExp(r'\s*\(référence:[^)]+\)', caseSensitive: false), '');
      if (msg.length > 320) msg = '${msg.substring(0, 317)}…';
      return msg;
    }

    // Messages connus déjà traduits ou en français
    final translated = ErrorMessages.translate(str, code: null);
    if (translated != _genericFallback) return translated;

    // Tout le reste : message générique (jamais le message technique)
    return fallback ?? _unexpected;
  }

  static bool _isNetworkError(Object error, String str, String lower) {
    if (str.contains('SocketException') ||
        str.contains('ClientException') ||
        str.contains('Connection refused') ||
        str.contains('Connection reset') ||
        str.contains('Failed host lookup') ||
        str.contains('Network is unreachable') ||
        str.contains('Connection timed out') ||
        lower.contains('no internet') ||
        lower.contains('connection')) {
      return true;
    }
    return error is TimeoutException;
  }

  /// Indique si l'erreur est due au réseau (connexion, timeout). Utilisable pour basculer en pending (ex. POS).
  static bool isNetworkError(Object? error) {
    if (error == null) return false;
    final str = error.toString().trim();
    final lower = str.toLowerCase();
    return _isNetworkError(error, str, lower);
  }
}

/// Gestionnaire central : affiche un message utilisateur et log les détails en dev uniquement.
class AppErrorHandler {
  AppErrorHandler._();

  /// Affiche l'erreur en Snackbar (message utilisateur) et log le détail technique.
  /// Passez [stackTrace] depuis `catch (e, st)` pour une remontée complète (debug + `log_app_error`).
  /// [logSource] / [logContext] : filtrage côté super admin (ex. `pos_quick`, `{ "op": "sale" }`).
  static void show(
    BuildContext context,
    Object? error, {
    String? fallback,
    StackTrace? stackTrace,
    String logSource = 'app_error_handler',
    Map<String, dynamic>? logContext,
  }) {
    final message = ErrorMapper.toMessage(error, fallback: fallback);
    _log(
      error,
      stackTrace: stackTrace,
      logSource: logSource,
      logContext: logContext,
    );
    if (context.mounted) AppToast.error(context, message);
  }

  /// Affiche un message d'erreur en Snackbar (déjà rédigé pour l'utilisateur).
  static void showMessage(
    BuildContext context,
    String userMessage, {
    String logSource = 'app_error_handler',
    Map<String, dynamic>? logContext,
  }) {
    _log(userMessage, logSource: logSource, logContext: logContext);
    if (context.mounted) AppToast.error(context, userMessage);
  }

  /// Affiche une boîte de dialogue pour les erreurs critiques (ex. échec de chargement initial).
  static void showErrorDialog(
    BuildContext context,
    Object? error, {
    String? fallback,
    StackTrace? stackTrace,
    VoidCallback? onClose,
    String logSource = 'app_error_handler',
    Map<String, dynamic>? logContext,
  }) {
    final message = ErrorMapper.toMessage(error, fallback: fallback);
    _log(
      error,
      stackTrace: stackTrace,
      logSource: logSource,
      logContext: logContext,
    );
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onClose?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Retourne le message utilisateur sans afficher ni log (pour état _error dans les pages).
  static String toUserMessage(Object? error, {String? fallback}) {
    return ErrorMapper.toMessage(error, fallback: fallback);
  }

  /// Log technique (debug + éventuelle remontée serveur) — jamais affiché tel quel à l'utilisateur.
  static void _log(
    Object? error, {
    StackTrace? stackTrace,
    String logSource = 'app_error_handler',
    Map<String, dynamic>? logContext,
  }) {
    if (kDebugMode && error != null) {
      if (error is PostgrestException) {
        debugPrint(
          '[AppError] Postgrest code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
        );
      } else {
        debugPrint('[AppError] $error');
      }
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
    if (error == null) return;
    if (!_shouldCaptureRemotely(error, stackTrace)) return;
    RemoteErrorLogger.capture(
      error,
      stackTrace: stackTrace,
      source: logSource,
      context: logContext,
    );
  }

  /// Log avec stack trace (ex. `catch (e, st)` → `log(e, st)`).
  static void log(Object? error, [StackTrace? stackTrace]) {
    _log(error, stackTrace: stackTrace);
  }

  /// Comme [log], avec source / contexte pour la table `log_app_error` (filtres super admin).
  static void logWithContext(
    Object? error, {
    StackTrace? stackTrace,
    String logSource = 'app_error_handler',
    Map<String, dynamic>? logContext,
  }) {
    _log(
      error,
      stackTrace: stackTrace,
      logSource: logSource,
      logContext: logContext,
    );
  }

  /// JWT expiré / 401 PostgREST — état d’auth attendu après veille longue ou refresh raté ;
  /// pas un « bug » à suivre comme incident applicatif (l’utilisateur doit se reconnecter).
  static bool _isSessionOrJwtExpired(Object? error) {
    if (error is PostgrestException) {
      final c = error.code?.toString().toUpperCase() ?? '';
      if (c == 'PGRST303') return true;
      final m = '${error.message} ${error.details ?? ''}'.toLowerCase();
      if (m.contains('jwt expired') || m.contains('invalid jwt')) return true;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('jwt expired') || text.contains('invalid jwt')) return true;
    if (text.contains('pgrst303')) return true;
    return false;
  }

  /// Évite de remonter comme "incident critique" les erreurs métier attendues
  /// (validation utilisateur, stock insuffisant, réseau intermittent, etc.).
  static bool _shouldCaptureRemotely(Object? error, [StackTrace? stackTrace]) {
    if (error == null) return false;
    if (error is UserFriendlyError) return false;
    if (ErrorMapper.isNetworkError(error)) return false;
    if (_isFrameworkKeyboardAssertion(error, stackTrace)) return false;
    if (_isSessionOrJwtExpired(error)) return false;
    final text = error.toString().toLowerCase();
    if (text.contains('stock insuffisant')) return false;
    // Double annulation ou liste locale désynchronisée (cancel_sale_restore_stock).
    if (error is PostgrestException) {
      final pe = error;
      if (pe.code?.toString().toUpperCase() == 'P0001' &&
          pe.message.contains('Vente déjà annulée')) {
        return false;
      }
    }
    if (text.contains("choisissez la boutique d'origine")) return false;
    if (text.contains('authretryablefetchexception')) return false;
    if (text.contains('code: 502')) return false;
    return true;
  }

  /// Erreur connue du moteur Flutter (clavier) — ne pas envoyer à la base « erreurs app ».
  static bool _isFrameworkKeyboardAssertion(Object? error, [StackTrace? stackTrace]) {
    if (error is! AssertionError) return false;
    final st = stackTrace?.toString() ?? '';
    return st.contains('hardware_keyboard.dart') &&
        st.contains('_assertEventIsRegular');
  }

  /// À appeler au démarrage (ex. main() ou initState du widget racine) pour capturer
  /// les erreurs Flutter et asynchrones non gérées. En release : log sans crasher.
  static void installFlutterErrorHandlers() {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      } else {
        debugPrint('[AppError] ${details.exception}');
        if (details.stack != null) debugPrint(details.stack.toString());
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('[AppError] $error');
        debugPrint(stack.toString());
      } else {
        debugPrint('[AppError] $error');
      }
      log(error, stack);
      return true; // empêche le crash
    };
  }
}


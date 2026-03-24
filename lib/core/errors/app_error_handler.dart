import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
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
    final str = error.toString().trim();
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

    // Permission / RLS / Forbidden
    if (lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        lower.contains('forbidden') ||
        lower.contains('policy') && lower.contains('violates') ||
        lower.contains('accès refusé')) {
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
  static void show(BuildContext context, Object? error, {String? fallback}) {
    final message = ErrorMapper.toMessage(error, fallback: fallback);
    _log(error);
    if (context.mounted) AppToast.error(context, message);
  }

  /// Affiche un message d'erreur en Snackbar (déjà rédigé pour l'utilisateur).
  static void showMessage(BuildContext context, String userMessage) {
    _log(userMessage);
    if (context.mounted) AppToast.error(context, userMessage);
  }

  /// Affiche une boîte de dialogue pour les erreurs critiques (ex. échec de chargement initial).
  static void showErrorDialog(BuildContext context, Object? error, {String? fallback, VoidCallback? onClose}) {
    final message = ErrorMapper.toMessage(error, fallback: fallback);
    _log(error);
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

  /// Log technique uniquement (développeur) — jamais affiché dans l'UI.
  static void _log(Object? error) {
    if (kDebugMode && error != null) {
      debugPrint('[AppError] $error');
    }
    RemoteErrorLogger.capture(error, source: 'app_error_handler');
  }

  /// Log avec stack trace (ex. dans un catch avec StackTrace).
  static void log(Object? error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      if (error != null) debugPrint('[AppError] $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
    RemoteErrorLogger.capture(
      error,
      stackTrace: stackTrace,
      source: 'app_error_handler',
    );
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
      return true; // empêche le crash
    };
  }
}


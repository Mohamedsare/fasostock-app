import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_toast.dart';
import 'error_messages.dart';
import 'remote_error_logger.dart';

/// Erreur avec message déjà lisible pour l’utilisateur (pas de traduction).
class UserFriendlyError implements Exception {
  const UserFriendlyError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Détection réseau + message court pour les logs métier.
abstract final class ErrorMapper {
  ErrorMapper._();

  static bool isNetworkError(Object? e) {
    if (e == null) return false;
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('clientexception') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('timed out') ||
        s.contains('network is unreachable') ||
        s.contains('handshake exception') ||
        e is TimeoutException;
  }

  static String toMessage(Object? e, {String? fallback}) {
    if (e is UserFriendlyError) return e.message;
    return AppErrorHandler.toUserMessage(e, fallback: fallback);
  }
}

/// Journalisation centralisée et messages utilisateur (sans fuite de détails techniques).
class AppErrorHandler {
  AppErrorHandler._();

  static bool _flutterHandlersInstalled = false;

  /// Peut être appelé une fois au démarrage UI ; les handlers racine restent dans [main.dart].
  static void installFlutterErrorHandlers() {
    if (_flutterHandlersInstalled) return;
    _flutterHandlersInstalled = true;
  }

  /// Log console (debug) + remontée tolérante [RemoteErrorLogger] hors debug.
  static void log(Object? error, [StackTrace? stackTrace]) {
    if (error == null) return;
    if (kDebugMode) {
      debugPrint('[AppError] $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
    if (!kDebugMode) {
      unawaited(
        RemoteErrorLogger.capture(
          error,
          stackTrace: stackTrace,
          source: 'app',
        ),
      );
    }
  }

  /// Erreur avec source / contexte structuré (sync, realtime, crédit…).
  static void logWithContext(
    Object? error, {
    StackTrace? stackTrace,
    String? logSource,
    Map<String, Object?>? logContext,
  }) {
    if (error == null) return;
    if (kDebugMode) {
      debugPrint('[AppError] $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
      if (logSource != null || logContext != null) {
        debugPrint('[AppError] source=$logSource context=$logContext');
      }
    } else {
      unawaited(
        RemoteErrorLogger.capture(
          error,
          stackTrace: stackTrace,
          source: logSource ?? 'app',
          context: logContext?.map((k, v) => MapEntry(k, v)),
        ),
      );
    }
  }

  /// Toast d’erreur + journalisation structurée (écrans métier).
  static void show(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    String? logSource,
    Map<String, Object?>? logContext,
    String? fallback,
  }) {
    logWithContext(error, stackTrace: stackTrace, logSource: logSource, logContext: logContext);
    final msg =
        error is UserFriendlyError ? error.message : toUserMessage(error, fallback: fallback);
    AppToast.error(context, msg);
  }

  /// Message affichable (toast / ligne UI) — jamais de stack ni d’URL brute.
  static String toUserMessage(Object? error, {String? fallback}) {
    if (error == null) return fallback ?? ErrorMessages.generic;
    if (error is UserFriendlyError) return error.message;
    if (error is AuthException) {
      return ErrorMessages.translate(error.message);
    }
    if (error is PostgrestException) {
      return ErrorMessages.translate(error.message, code: error.code);
    }
    if (error is FunctionException) {
      final details = error.details;
      if (details is String && details.isNotEmpty) {
        return ErrorMessages.translate(details);
      }
      return ErrorMessages.translate(error.reasonPhrase ?? '');
    }
    if (ErrorMapper.isNetworkError(error)) {
      return 'Connexion internet impossible ou instable. Réessayez.';
    }
    final translated = ErrorMessages.translate(error.toString());
    if (fallback != null && translated == ErrorMessages.generic) return fallback;
    return translated;
  }
}

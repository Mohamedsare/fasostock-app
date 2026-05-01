import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/profile.dart';
import '../errors/app_error_handler.dart';

/// Cache **non faisant foi** du profil pour accélérer le cold start : la vérité reste toujours le serveur.
///
/// - Une seule entrée par appareil (dernier utilisateur ayant un cache valide).
/// - Lecture uniquement si `userId` courant, schéma, TTL et cohérence `profile.id` sont OK.
/// - Jamais de cache pour un compte `is_active == false`.
/// - Effacement explicite à la déconnexion et si le serveur indique un compte inactif.
class ProfileSessionCache {
  ProfileSessionCache._();

  static const int _schemaVersion = 1;
  static const String _prefsKey = 'fs_profile_session_cache_v1';
  static const Duration _maxOptimisticAge = Duration(days: 14);

  static Future<void> save(Profile profile) async {
    if (!profile.isActive) {
      await clear();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'v': _schemaVersion,
        'userId': profile.id,
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'profile': profile.toJson(),
      });
      await prefs.setString(_prefsKey, payload);
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'profile_session_cache',
        logContext: const {'op': 'save'},
      );
    }
  }

  /// Profil utilisable **uniquement** pour débloquer l’UI en attendant la requête serveur.
  static Future<Profile?> loadOptimisticForUser(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final v = decoded['v'];
      if (v is! int || v != _schemaVersion) {
        await clear();
        return null;
      }
      final cachedUserId = decoded['userId'] as String?;
      if (cachedUserId == null || cachedUserId != userId) {
        return null;
      }
      final cachedAtStr = decoded['cachedAt'] as String?;
      if (cachedAtStr == null || cachedAtStr.isEmpty) {
        await clear();
        return null;
      }
      final cachedAt = DateTime.tryParse(cachedAtStr)?.toUtc();
      if (cachedAt == null) {
        await clear();
        return null;
      }
      if (DateTime.now().toUtc().difference(cachedAt) > _maxOptimisticAge) {
        return null;
      }
      final profileMap = decoded['profile'];
      if (profileMap is! Map<String, dynamic>) {
        await clear();
        return null;
      }
      final profile = Profile.fromJson(profileMap);
      if (profile.id != userId) {
        await clear();
        return null;
      }
      if (!profile.isActive) {
        await clear();
        return null;
      }
      return profile;
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'profile_session_cache',
        logContext: const {'op': 'loadOptimisticForUser'},
      );
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'profile_session_cache',
        logContext: const {'op': 'clear'},
      );
    }
  }
}

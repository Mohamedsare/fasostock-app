import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Config Supabase sur l’appareil — **clé anon** dans le stockage sécurisé (Keychain / Keystore / Windows DPAPI).
/// L’URL est aussi en stockage sécurisé. Migration automatique depuis [SharedPreferences] (anciennes installs).
class SupabaseConfigStorage {
  SupabaseConfigStorage._();

  static const _keyUrl = 'supabase_url';
  static const _keyAnonKey = 'supabase_anon_key';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static Future<({String url, String anonKey})?> get() async {
    var url = await _secure.read(key: _keyUrl);
    var anonKey = await _secure.read(key: _keyAnonKey);
    if (_isValidPair(url, anonKey)) {
      return (url: url!.trim(), anonKey: anonKey!.trim());
    }
    final prefs = await SharedPreferences.getInstance();
    final pUrl = prefs.getString(_keyUrl)?.trim() ?? '';
    final pKey = prefs.getString(_keyAnonKey)?.trim() ?? '';
    if (_isValidPair(pUrl, pKey)) {
      await set(url: pUrl, anonKey: pKey);
      await prefs.remove(_keyUrl);
      await prefs.remove(_keyAnonKey);
      return (url: pUrl, anonKey: pKey);
    }
    return null;
  }

  static bool _isValidPair(String? url, String? anonKey) {
    if (url == null || anonKey == null) return false;
    if (url.isEmpty || anonKey.isEmpty) return false;
    if (url.contains('placeholder') || anonKey.contains('placeholder')) {
      return false;
    }
    return true;
  }

  static Future<void> set({required String url, required String anonKey}) async {
    await _secure.write(key: _keyUrl, value: url.trim());
    await _secure.write(key: _keyAnonKey, value: anonKey.trim());
  }

  /// Efface la config enregistrée (ex. avant déconnexion complète).
  static Future<void> clear() async {
    await _secure.delete(key: _keyUrl);
    await _secure.delete(key: _keyAnonKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUrl);
    await prefs.remove(_keyAnonKey);
  }
}

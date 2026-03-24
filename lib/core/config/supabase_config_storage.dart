import 'package:shared_preferences/shared_preferences.dart';

/// Config Supabase stockée sur l'appareil (pour APK installé sans --dart-define).
class SupabaseConfigStorage {
  SupabaseConfigStorage._();

  static const _keyUrl = 'supabase_url';
  static const _keyAnonKey = 'supabase_anon_key';

  static Future<({String url, String anonKey})?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyUrl)?.trim() ?? '';
    final anonKey = prefs.getString(_keyAnonKey)?.trim() ?? '';
    if (url.isEmpty || anonKey.isEmpty || url.contains('placeholder') || anonKey.contains('placeholder')) {
      return null;
    }
    return (url: url, anonKey: anonKey);
  }

  static Future<void> set({required String url, required String anonKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url.trim());
    await prefs.setString(_keyAnonKey, anonKey.trim());
  }
}

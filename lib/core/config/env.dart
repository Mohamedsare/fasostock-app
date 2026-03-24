/// Configuration d'environnement — même URL et anon key que l'app web (VITE_SUPABASE_*).
/// Sur mobile : définir à la build via --dart-define (run_with_env.ps1 build) ou saisie in-app.
class Env {
  Env._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://placeholder.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1wbGFjZWhvbGRlciJ9.placeholder',
  );

  /// DSN Sentry pour la remontée d'erreurs en prod. Vide = désactivé (aucun impact).
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  /// Validation stricte : URL Supabase valide (https, .supabase.co, pas de placeholder).
  static bool get isSupabaseUrlWellFormed {
    final u = supabaseUrl.trim();
    if (u.isEmpty || u.length < 20 || u.length > 250) return false;
    if (u.contains('placeholder')) return false;
    if (!u.startsWith('https://')) return false;
    if (!u.contains('.supabase.co')) return false;
    return true;
  }

  /// Validation clé anon (non vide, format JWT plausible, pas de placeholder).
  static bool get isSupabaseAnonKeyWellFormed {
    final k = supabaseAnonKey.trim();
    if (k.isEmpty || k.length < 100 || k.length > 5000) return false;
    if (k.contains('placeholder')) return false;
    return true;
  }

  static bool get hasValidSupabase =>
      isSupabaseUrlWellFormed && isSupabaseAnonKeyWellFormed;

  /// Valide une paire (url, anonKey). Retourne null si OK, sinon un message d'erreur utilisateur.
  static String? validateSupabaseConfig(String url, String anonKey) {
    final u = url.trim();
    final k = anonKey.trim();
    if (u.isEmpty || k.isEmpty) return 'Renseignez l\'URL et la clé anon.';
    if (u.contains('placeholder') || k.contains('placeholder')) {
      return 'Configuration Supabase invalide.';
    }
    if (!u.startsWith('https://') || !u.contains('.supabase.co')) {
      return 'Configuration Supabase invalide. L\'URL doit être du type https://xxxxx.supabase.co';
    }
    if (u.length < 20 || u.length > 250) return 'Configuration Supabase invalide.';
    if (k.length < 100 || k.length > 5000) {
      return 'Configuration Supabase invalide. Vérifiez la clé anon.';
    }
    return null;
  }
}

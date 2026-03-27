/// Réduit le risque de fuite de secrets dans les logs distants (Sentry, RPC erreurs).
class SensitiveDataScrubber {
  SensitiveDataScrubber._();

  /// JWT / clés type Supabase anon (trois segments base64url).
  static final RegExp _jwtLike = RegExp(
    r'\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_.+-]+\b',
  );

  /// Paires clé=valeur sensibles (URL query, JSON, texte libre).
  static final RegExp _kvSensitive = RegExp(
    r'(password|passwd|secret|token|authorization|api[_-]?key|anon[_-]?key|bearer)\s*[:=]\s*[^\s,;}\]]+',
    caseSensitive: false,
  );

  /// Nettoie une chaîne destinée à être stockée ou envoyée (jamais l’UI utilisateur).
  static String scrub(String? input) {
    if (input == null || input.isEmpty) return '';
    var s = input.replaceAll(_jwtLike, '[REDACTED_JWT]');
    s = s.replaceAllMapped(_kvSensitive, (m) => '${m.group(1)}=[REDACTED]');
    return s;
  }
}

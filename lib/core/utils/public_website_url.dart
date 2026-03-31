/// Normalise une URL pour le QR du ticket (schéma https si absent, URI valide).
String? normalizePublicWebsiteUrlForQr(String? input) {
  if (input == null) return null;
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    s = 'https://$s';
  }
  final u = Uri.tryParse(s);
  if (u == null || !u.hasScheme || u.host.isEmpty) return null;
  if (u.scheme != 'http' && u.scheme != 'https') return null;
  return u.toString();
}

import 'package:timezone/timezone.dart' as tz;

/// Heure murale de l’appareil : [d] doit être **local** (typiquement [DateTime.now]).
String formatDeviceWallClockHm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Comme [formatDeviceWallClockHm] avec secondes.
String formatDeviceWallClockHms(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

/// Résout un identifiant IANA (ex. `Africa/Ouagadougou`) à partir du texte pays
/// saisi pour la boutique (nom, code ISO, etc.).
///
/// Retourne `null` si aucune correspondance : l’appelant utilisera l’heure locale appareil.
String? ianaTimezoneIdForCountry(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;

  // Codes ISO 3166-1 alpha-2 (souvent saisis en boutique).
  if (s.length == 2 && RegExp(r'^[a-z]{2}$').hasMatch(s)) {
    return _ianaFromIso2(s);
  }

  // Noms / variantes courantes (français + anglais).
  if (_hasAny(s, ['burkina', 'faso'])) return 'Africa/Ouagadougou';
  if (_hasAny(s, ['côte', 'cote', 'ivoire', 'ivory', "d'ivoire", 'd ivoire'])) {
    return 'Africa/Abidjan';
  }
  if (_hasAny(s, ['somali', 'somalia'])) return 'Africa/Mogadishu';
  if (s.contains('mali') && !s.contains('somal')) return 'Africa/Bamako';
  if (_hasAny(s, ['sénégal', 'senegal'])) return 'Africa/Dakar';
  if (_hasAny(s, ['nigeria'])) return 'Africa/Lagos';
  if (_hasAny(s, ['niger'])) return 'Africa/Niamey';
  if (_hasAny(s, ['togo'])) return 'Africa/Lome';
  if (_hasAny(s, ['bénin', 'benin'])) return 'Africa/Porto-Novo';
  if (_hasAny(s, ['ghana'])) return 'Africa/Accra';
  if (_hasAny(s, ['cameroun', 'cameroon'])) return 'Africa/Douala';
  if (_hasAny(s, ['france', 'français'])) return 'Europe/Paris';
  if (_hasAny(s, ['belgique', 'belgium', 'bruxelles'])) return 'Europe/Brussels';
  if (_hasAny(s, ['suisse', 'switzerland', 'genève', 'geneve'])) return 'Europe/Zurich';
  if (_hasAny(s, ['maroc', 'morocco', 'casablanca', 'rabat'])) return 'Africa/Casablanca';
  if (_hasAny(s, ['algérie', 'algerie', 'alger'])) return 'Africa/Algiers';
  if (_hasAny(s, ['tunisie', 'tunisia'])) return 'Africa/Tunis';
  if (_hasAny(s, ['canada', 'montréal', 'montreal', 'québec', 'quebec'])) {
    return 'America/Toronto';
  }
  if (s == 'us' || _hasAny(s, ['états-unis', 'etats-unis', 'usa', 'united states'])) {
    return 'America/New_York';
  }
  if (_hasAny(s, ['burundi'])) return 'Africa/Bujumbura';
  if (_hasAny(s, ['rwanda'])) return 'Africa/Kigali';
  if (_hasAny(s, ['rdc', 'congo kinshasa', 'kinshasa', 'république démocratique'])) {
    return 'Africa/Kinshasa';
  }
  if (_hasAny(s, ['congo brazzaville', 'brazzaville'])) return 'Africa/Brazzaville';
  if (_hasAny(s, ['gabon'])) return 'Africa/Libreville';
  if (_hasAny(s, ['guinée', 'guinee', 'conakry'])) return 'Africa/Conakry';

  return null;
}

bool _hasAny(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n)) return true;
  }
  return false;
}

String? _ianaFromIso2(String s) {
  switch (s) {
    case 'bf':
      return 'Africa/Ouagadougou';
    case 'ci':
      return 'Africa/Abidjan';
    case 'ml':
      return 'Africa/Bamako';
    case 'sn':
      return 'Africa/Dakar';
    case 'ne':
      return 'Africa/Niamey';
    case 'tg':
      return 'Africa/Lome';
    case 'bj':
      return 'Africa/Porto-Novo';
    case 'gh':
      return 'Africa/Accra';
    case 'ng':
      return 'Africa/Lagos';
    case 'cm':
      return 'Africa/Douala';
    case 'fr':
      return 'Europe/Paris';
    case 'be':
      return 'Europe/Brussels';
    case 'ch':
      return 'Europe/Zurich';
    case 'ma':
      return 'Africa/Casablanca';
    case 'dz':
      return 'Africa/Algiers';
    case 'tn':
      return 'Africa/Tunis';
    case 'ca':
      return 'America/Toronto';
    case 'us':
      return 'America/New_York';
    case 'bi':
      return 'Africa/Bujumbura';
    case 'rw':
      return 'Africa/Kigali';
    case 'cd':
      return 'Africa/Kinshasa';
    case 'cg':
      return 'Africa/Brazzaville';
    case 'ga':
      return 'Africa/Libreville';
    case 'gn':
      return 'Africa/Conakry';
    default:
      return null;
  }
}

/// Heure « locale » pour le pays indiqué (boutique), ou heure de l’appareil si inconnu.
///
/// Nécessite [tz.initializeTimeZones] (fait au démarrage dans [main]).
DateTime nowInUserCountry(String? countryHint) {
  final id = ianaTimezoneIdForCountry(countryHint);
  if (id == null) return DateTime.now();
  try {
    final loc = tz.getLocation(id);
    return tz.TZDateTime.now(loc);
  } catch (_) {
    return DateTime.now();
  }
}

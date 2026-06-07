import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Fuseau par défaut des opérations caisse / créances — aligné `operation-datetime.ts` (web).
const String defaultOperationsTimeZoneId = 'Africa/Ouagadougou';

tz.Location? _safeOperationsLocation() {
  try {
    return tz.getLocation(defaultOperationsTimeZoneId);
  } catch (_) {
    return null;
  }
}

/// Parse une date ISO (UTC ou locale) et retourne l’instant en UTC.
DateTime? _parseToUtc(Object input) {
  if (input is DateTime) {
    return input.isUtc ? input : input.toUtc();
  }
  final s = input.toString().trim();
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d?.toUtc();
}

/// Ex. `02/05/2026 15:30` — listes, tableaux (fuseau activité).
String formatOperationDateTime(Object? input) {
  if (input == null) return '—';
  final utc = _parseToUtc(input);
  if (utc == null) return '—';
  final loc = _safeOperationsLocation();
  if (loc == null) {
    // Fallback sûr si la base timezone n'est pas initialisée dans ce runtime.
    return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(utc.toLocal());
  }
  final z = tz.TZDateTime.from(utc, loc);
  return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(z);
}

/// Chaîne `yyyy-MM-dd` (filtre) affichée au calendrier du pays d’activité.
String formatOperationCalendarDayYmd(String ymd) {
  final d = DateTime.tryParse('${ymd}T12:00:00Z');
  if (d == null) return ymd;
  final loc = _safeOperationsLocation();
  if (loc == null) {
    return DateFormat('d MMM yyyy', 'fr_FR').format(d.toLocal());
  }
  final z = tz.TZDateTime.from(d.toUtc(), loc);
  return DateFormat('d MMM yyyy', 'fr_FR').format(z);
}

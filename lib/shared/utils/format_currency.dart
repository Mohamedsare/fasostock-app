import 'package:intl/intl.dart';

/// Format montant — équivalent formatCurrency côté web.
String formatCurrency(num value, {String locale = 'fr_FR'}) {
  return NumberFormat.currency(locale: locale, symbol: 'FCFA', decimalDigits: 0).format(value);
}

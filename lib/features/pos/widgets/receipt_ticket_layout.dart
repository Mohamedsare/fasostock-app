import 'package:intl/intl.dart';

/// Mise en page ticket thermique : séparateurs, libellés paiement, montants avec devise **CFA**.
class ReceiptTicketLayout {
  ReceiptTicketLayout._();

  static const String sepLong = '------------------------------------------';
  static const String sepMid = '--------------------------------';
  static const String sepTotal = '--------------------------------';

  static String stripTelPrefix(String? s) {
    if (s == null || s.trim().isEmpty) return '';
    return s.trim().replaceFirst(RegExp(r'^Tel\s*:\s*', caseSensitive: false), '').trim();
  }

  static String telLine(String? storePhone) {
    final p = stripTelPrefix(storePhone);
    if (p.isEmpty) return '';
    return 'Tel: $p';
  }

  /// Montant affiché avec devise (XOF / usage local « CFA »).
  static String intAmount(num n) => '${n.round()} CFA';

  static String paymentUppercase(String method) {
    final t = method.trim().toLowerCase();
    if (t.contains('esp')) return 'ESPECES';
    if (t.contains('carte') || t == 'card') return 'CARTE';
    if (t.contains('mobile') || t.contains('money')) return 'MOBILE MONEY';
    if (t.contains('virement') || t.contains('transfer')) return 'VIREMENT';
    return method.toUpperCase();
  }

  static String truncateName(String name, int maxLen) {
    if (name.length <= maxLen) return name;
    return '${name.substring(0, maxLen - 1)}.';
  }

  /// Partie droite d’une ligne article : `Qté` | `PU` | `Total` (montants entiers, sans « CFA »).
  static String productNumericLine(int qty, int pu, int lineTotal) {
    final q = qty.toString().padLeft(2);
    final p = '$pu'.padLeft(12);
    final t = '$lineTotal'.padLeft(12);
    return '$q $p $t';
  }

  /// Ligne article monospace sur une seule chaîne (impression / compat).
  static String productMonoLine(String name, int qty, int pu, int lineTotal, {int nameW = 13}) {
    final n = truncateName(name, nameW).padRight(nameW);
    return '$n ${productNumericLine(qty, pu, lineTotal)}';
  }

  /// Une ligne : `Produit` | `Qté` | `PU(CFA)` | `Total`.
  static String headerMonoLine() {
    final n = 'Produit'.padRight(13);
    final q = 'Qté'.padLeft(2);
    final p = 'PU(CFA)'.padLeft(12);
    final t = 'Total'.padLeft(12);
    return '$n $q $p $t';
  }

  static String dateStr(DateTime d) => DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
  static String timeStr(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);

  /// Une seule ligne : `Facture {n°} {jj/mm/aaaa} {HH:mm}` (centrée dans le ticket).
  static String metaFactureDateHeureLine(String saleNumber, DateTime d) =>
      'Facture $saleNumber ${dateStr(d)} ${timeStr(d)}';
}

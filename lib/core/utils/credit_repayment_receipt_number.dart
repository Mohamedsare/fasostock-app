/// Numéro de reçu court (10 caractères), aligné `credit-repayment-receipt-number.ts` (web).
/// Forme : `RC` + année 2 chiffres + 6 hex (uuid compact ou hachage si id non-hex).
String creditRepaymentReceiptNumberFromPaymentId(
  String paymentId,
  DateTime issuedAt,
) {
  final yy = (issuedAt.toUtc().year % 100).toString().padLeft(2, '0');
  final six = _receiptSixFromPaymentId(paymentId);
  return 'RC$yy$six';
}

String _receiptSixFromPaymentId(String paymentId) {
  final compact = paymentId.replaceAll('-', '').toUpperCase();
  if (compact.isEmpty) return '000000';
  final isHex = RegExp(r'^[0-9A-F]+$').hasMatch(compact);
  if (isHex && compact.length >= 6) {
    return compact.substring(0, 6);
  }
  var h = 0;
  for (final u in compact.runes) {
    h = 0x1fffffff & ((31 * h) + u);
  }
  return (h % 0x1000000).toRadixString(16).padLeft(6, '0').toUpperCase();
}

/// Fallback hors ligne / sans id serveur (même longueur 10).
String creditRepaymentReceiptNumberFallback(DateTime issuedAt) {
  final yy = (issuedAt.toUtc().year % 100).toString().padLeft(2, '0');
  final r = DateTime.now().microsecondsSinceEpoch % 0x1000000;
  return 'RC$yy${r.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Métadonnées renvoyées par `append_legacy_customer_credit_payment` / `append_sale_payment`.
class AppendPaymentResult {
  const AppendPaymentResult({
    required this.paymentId,
    required this.createdAt,
  });

  final String paymentId;
  final DateTime createdAt;

  static AppendPaymentResult fromRpc(dynamic raw) {
    if (raw is! Map) {
      throw FormatException('Réponse RPC encaissement invalide', raw);
    }
    final pid = raw['payment_id']?.toString().trim() ?? '';
    final createdRaw = raw['created_at']?.toString().trim() ?? '';
    final created = DateTime.tryParse(createdRaw);
    if (pid.isEmpty || created == null) {
      throw FormatException('Réponse RPC encaissement incomplète', raw);
    }
    return AppendPaymentResult(paymentId: pid, createdAt: created);
  }
}

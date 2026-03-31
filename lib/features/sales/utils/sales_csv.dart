import '../../../data/models/sale.dart';

const String _sep = ',';
const String _quote = '"';

String _escape(String v) {
  final s = v.toString();
  if (s.contains(_sep) || s.contains(_quote) || s.contains('\n')) {
    return '$_quote${s.replaceAll(_quote, '$_quote$_quote')}$_quote';
  }
  return s;
}

/// Export ventes en CSV (numéro, date, boutique, vente_par, client, statut, sous_total, remise, tva, total).
String salesToCsv(List<Sale> sales) {
  const headers = [
    'numero',
    'date',
    'boutique',
    'vente_par',
    'client',
    'statut',
    'sous_total',
    'remise',
    'tva',
    'total',
  ];
  final rows = sales.map((s) {
    final date = s.createdAt.length >= 19 ? s.createdAt.substring(0, 19) : s.createdAt;
    return [
      _escape(s.saleNumber),
      _escape(date),
      _escape(s.store?.name ?? 'Boutique'),
      _escape(s.createdByLabel ?? ''),
      _escape(s.customer?.name ?? ''),
      _escape(s.status.value),
      '${s.subtotal}',
      '${s.discount}',
      '${s.tax}',
      '${s.total}',
    ].join(_sep);
  }).toList();
  return [headers.join(_sep), ...rows].join('\n');
}

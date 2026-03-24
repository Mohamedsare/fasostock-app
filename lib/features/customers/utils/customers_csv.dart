import '../../../data/models/customer.dart';

const String _sep = ',';
const String _quote = '"';

String _escape(String v) {
  final s = v.toString();
  if (s.contains(_sep) || s.contains(_quote) || s.contains('\n')) {
    return '$_quote${s.replaceAll(_quote, '$_quote$_quote')}$_quote';
  }
  return s;
}

/// Export clients en CSV (nom, type, téléphone, email, adresse, notes).
String customersToCsv(List<Customer> customers) {
  const headers = ['nom', 'type', 'telephone', 'email', 'adresse', 'notes'];
  final rows = customers.map((c) {
    return [
      _escape(c.name),
      _escape(c.type.value),
      _escape(c.phone ?? ''),
      _escape(c.email ?? ''),
      _escape(c.address ?? ''),
      _escape(c.notes ?? ''),
    ].join(_sep);
  }).toList();
  return [headers.join(_sep), ...rows].join('\n');
}

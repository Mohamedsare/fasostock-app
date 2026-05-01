import '../../../data/models/sale.dart';
import '../../../shared/utils/csv_export.dart';
import 'package:intl/intl.dart';

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
  final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final rows = sales
      .map<List<CsvCell>>((s) {
        final created = DateTime.tryParse(s.createdAt);
        final date = created != null ? dateFmt.format(created.toLocal()) : s.createdAt;
        return [
          s.saleNumber,
          date,
          s.store?.name ?? 'Boutique',
          s.createdByLabel ?? '',
          s.customer?.name ?? '',
          s.status.value,
          formatCsvMoney(s.subtotal),
          formatCsvMoney(s.discount),
          formatCsvMoney(s.tax),
          formatCsvMoney(s.total),
        ];
      })
      .toList();
  return buildCsv(headers: headers, rows: rows, separator: ';');
}

import '../../../data/models/customer.dart';
import '../../../shared/utils/csv_export.dart';

/// Export clients en CSV (nom, type, téléphone, email, adresse, notes).
String customersToCsv(List<Customer> customers) {
  const headers = ['Nom', 'Type', 'Téléphone', 'Email', 'Adresse', 'Notes'];
  final rows = customers
      .map<List<CsvCell>>(
        (c) => [
          c.name,
          c.type == CustomerType.company ? 'Entreprise' : 'Particulier',
          c.phone ?? '',
          c.email ?? '',
          c.address ?? '',
          c.notes ?? '',
        ],
      )
      .toList();
  return buildCsv(headers: headers, rows: rows, separator: ';');
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

typedef CsvCell = Object?;
final NumberFormat _frMoneyFmt = NumberFormat('#,##0.00', 'fr_FR');

String escapeCsvCell(String value, {String separator = ','}) {
  final needsQuotes =
      value.contains(separator) ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

String stringifyCsvCell(CsvCell value) {
  if (value == null) return '';
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}

String buildCsv({
  required List<String> headers,
  required List<List<CsvCell>> rows,
  String separator = ',',
}) {
  final out = <String>[];
  out.add(headers.map((h) => escapeCsvCell(h, separator: separator)).join(separator));
  for (final row in rows) {
    out.add(
      row
          .map((cell) => escapeCsvCell(stringifyCsvCell(cell), separator: separator))
          .join(separator),
    );
  }
  return out.join('\r\n');
}

Uint8List encodeCsv(String csv, {bool includeBom = true}) {
  final body = utf8.encode(csv);
  if (!includeBom) return Uint8List.fromList(body);
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]);
}

String formatCsvMoney(num value) => _frMoneyFmt.format(value);

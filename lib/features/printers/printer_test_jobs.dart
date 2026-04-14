import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF minimal 80 mm pour tester le ticket thermique.
Future<Uint8List> buildThermalTestPdf() async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        80 * PdfPageFormat.mm,
        140 * PdfPageFormat.mm,
        marginAll: 4 * PdfPageFormat.mm,
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'FasoStock',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Test ticket thermique',
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            DateTime.now().toLocal().toString(),
            style: const pw.TextStyle(fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// PDF A4 minimal pour tester la facture.
Future<Uint8List> buildA4TestPdf() async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Test facture A4',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'FasoStock — si ce document sort sur la bonne imprimante, l’association est correcte.',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            DateTime.now().toLocal().toString(),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Envoie un PDF de test sur l’imprimante [printer] (déjà résolue).
Future<void> directPrintPdfBytes({
  required Printer printer,
  required String jobName,
  required Future<Uint8List> Function() buildBytes,
}) async {
  await Printing.directPrintPdf(
    printer: printer,
    name: jobName,
    onLayout: (_) async => buildBytes(),
  );
}

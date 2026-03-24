import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../shared/utils/format_currency.dart';
import '../widgets/receipt_ticket_dialog.dart';
import 'physical_printer_pdf.dart';

/// Ticket caisse rapide : PDF 80 mm + envoi vers imprimante réelle (évite « Print to PDF »).
class ReceiptThermalPrintService {
  ReceiptThermalPrintService._();

  static String _stripTel(String? s) {
    if (s == null || s.trim().isEmpty) return '';
    return s.trim().replaceFirst(RegExp(r'^Tel\s*:\s*', caseSensitive: false), '').trim();
  }

  static String _truncate(String name, int maxLen) {
    if (name.length <= maxLen) return name;
    return '${name.substring(0, maxLen - 1)}.';
  }

  static Future<Uint8List> _buildPdf(ReceiptTicketData data) async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(data.date);
    final timeStr = DateFormat('HH:mm', 'fr_FR').format(data.date);
    final phone = _stripTel(data.storePhone);
    final customerPhone = _stripTel(data.customerPhone);
    const maxNameLen = 22;
    final w = 80 * PdfPageFormat.mm;
    final margin = 2.5 * PdfPageFormat.mm;
    final baseStyle = pw.TextStyle(fontSize: 8);
    final small = pw.TextStyle(fontSize: 7);

    final children = <pw.Widget>[
      pw.Center(
        child: pw.Text(
          data.storeName.toUpperCase(),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      ),
      if (data.storeAddress != null && data.storeAddress!.trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(data.storeAddress!.trim(), style: small, textAlign: pw.TextAlign.center),
        ),
      if (phone.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(phone, style: small, textAlign: pw.TextAlign.center),
        ),
      pw.SizedBox(height: 4),
      pw.Text('— — — — — — — — — — — — —', style: small, textAlign: pw.TextAlign.center),
      pw.SizedBox(height: 4),
      pw.Text('N° ${data.saleNumber}    $dateStr  $timeStr', style: small, textAlign: pw.TextAlign.center),
      pw.SizedBox(height: 4),
      pw.Text('— — — — — — — — — — — — —', style: small, textAlign: pw.TextAlign.center),
    ];

    if (data.customerName != null && data.customerName!.trim().isNotEmpty) {
      children.add(pw.SizedBox(height: 4));
      children.add(pw.Text('Client: ${data.customerName!.trim()}', style: baseStyle));
      if (customerPhone.isNotEmpty) {
        children.add(pw.Text(customerPhone, style: small));
      }
      children.add(pw.SizedBox(height: 4));
      children.add(pw.Text('— — — — — — — — — — — — —', style: small, textAlign: pw.TextAlign.center));
    }

    for (final item in data.items) {
      final name = _truncate(item.name, maxNameLen);
      children.add(pw.SizedBox(height: 3));
      children.add(pw.Text(name, style: baseStyle));
      children.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('  ${item.quantity} x ${formatCurrency(item.unitPrice)}', style: small),
            pw.Text(formatCurrency(item.total), style: baseStyle),
          ],
        ),
      );
    }

    children.addAll([
      pw.SizedBox(height: 6),
      pw.Text('— — — — — — — — — — — — —', style: small, textAlign: pw.TextAlign.center),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Sous-total', style: baseStyle),
          pw.Text(formatCurrency(data.subtotal), style: baseStyle),
        ],
      ),
      if (data.discount > 0)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Remise', style: baseStyle),
            pw.Text('-${formatCurrency(data.discount)}', style: baseStyle),
          ],
        ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('TOTAL TTC', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text(formatCurrency(data.total), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Paiement', style: baseStyle),
          pw.Text(data.paymentMethod, style: baseStyle),
        ],
      ),
      if ((data.amountReceived ?? 0) > 0) ...[
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Montant reçu', style: baseStyle),
            pw.Text(formatCurrency(data.amountReceived ?? 0), style: baseStyle),
          ],
        ),
        if ((data.change ?? -1) >= 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Monnaie', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(formatCurrency(data.change ?? 0), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ],
          ),
      ],
      pw.SizedBox(height: 8),
      pw.Text('Merci et à bientôt', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
      pw.SizedBox(height: 2),
      pw.Text('--- FasoStock ---', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600), textAlign: pw.TextAlign.center),
    ]);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(w, 297 * PdfPageFormat.mm, marginAll: margin),
        build: (pw.Context context) => children,
      ),
    );

    return doc.save();
  }

  /// Depuis l’UI, appeler via `unawaited(printReceipt(...))` pour ne pas bloquer l’écran.
  static Future<void> printReceipt(ReceiptTicketData data) async {
    final safe = data.saleNumber.replaceAll(RegExp(r'[^\w\-.]'), '_');
    await printPdfToPhysicalPrinter(
      jobName: 'ticket_$safe.pdf',
      onLayout: (_) => _buildPdf(data),
    );
  }
}

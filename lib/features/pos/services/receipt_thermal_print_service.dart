import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/errors/app_error_handler.dart';
import '../widgets/receipt_ticket_dialog.dart';
import '../widgets/receipt_ticket_layout.dart';
import '../../../core/services/printer_association_storage.dart';
import 'physical_printer_pdf.dart';

/// Ticket caisse rapide : **papier 80 mm**, **zone imprimable ~72 mm** (marges ~4 mm par côté),
/// comme le rendu web (`html-to-pdf` thermique). Envoi vers imprimante réelle.
/// Noir & blanc uniquement, mise en page type ticket réel (colonnes alignées).
class ReceiptThermalPrintService {
  /// Largeur de page PDF = largeur du rouleau.
  static const double _thermalPaperWidthMm = 80;

  /// Zone utile horizontale ≈ 80 − 2×4 mm.
  static const double _thermalPrintableWidthMm = 72;

  /// `(papier − zone utile) / 2` — aligné web `THERMAL_SIDE_MARGIN_MM`.
  static const double _thermalMarginMm =
      (_thermalPaperWidthMm - _thermalPrintableWidthMm) / 2;
  ReceiptThermalPrintService._();

  static String _truncate(String name, int maxLen) {
    if (name.length <= maxLen) return name;
    return '${name.substring(0, maxLen - 1)}.';
  }

  static String _sanitizeForPdf(String s) {
    if (s.isEmpty) return s;
    return s
        .replaceAll('\uFFFD', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-');
  }

  static Future<File?> _logoCacheFile(String logoUrl) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final key = base64Url.encode(utf8.encode(logoUrl)).replaceAll('=', '');
      return File(p.join(dir.path, 'receipt_logo_$key.bin'));
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _loadCachedLogoBytes(String logoUrl) async {
    try {
      final f = await _logoCacheFile(logoUrl);
      if (f == null || !await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'receipt_thermal',
        logContext: const {'op': 'loadCachedLogoBytes'},
      );
      return null;
    }
  }

  static Future<void> _cacheLogoBytes(String logoUrl, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    try {
      final f = await _logoCacheFile(logoUrl);
      if (f == null) return;
      await f.writeAsBytes(bytes, flush: true);
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'receipt_thermal',
        logContext: const {'op': 'cacheLogoBytes'},
      );
    }
  }

  static Future<Uint8List> _buildPdf(ReceiptTicketData data) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final fontStoreTitle = pw.Font.ttf(
      await rootBundle.load('assets/fonts/ArchivoBlack-Regular.ttf'),
    );

    final doc = pw.Document();
    final tel = ReceiptTicketLayout.telLine(data.storePhone);
    final payU = ReceiptTicketLayout.paymentUppercase(data.paymentMethod);
    final isCash = payU == 'ESPECES';
    final qrPayload = _sanitizeForPdf(data.buildQrPayload());
    final saleNumber = _sanitizeForPdf(data.saleNumber);
    final storeName = _sanitizeForPdf(data.storeName);

    pw.MemoryImage? logoPdf;
    final logoUrl = data.storeLogoUrl?.trim();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final cached = await _loadCachedLogoBytes(logoUrl);
        if (cached != null && cached.isNotEmpty) {
          logoPdf = pw.MemoryImage(cached);
        }
        final res = await http
            .get(Uri.parse(logoUrl))
            .timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          logoPdf = pw.MemoryImage(res.bodyBytes);
          await _cacheLogoBytes(logoUrl, res.bodyBytes);
        }
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'receipt_thermal',
          logContext: const {'op': 'resolve_logo'},
        );
        // Ticket sans logo réseau; on conserve le cache local si présent.
      }
    }

    final w = _thermalPaperWidthMm * PdfPageFormat.mm;
    final margin = _thermalMarginMm * PdfPageFormat.mm;

    final base = pw.TextStyle(font: font, fontSize: 8, color: PdfColors.black);
    final bold = pw.TextStyle(
      font: fontBold,
      fontSize: 8,
      color: PdfColors.black,
    );
    final storeTitleStyle = pw.TextStyle(
      font: fontStoreTitle,
      fontSize: 25,
      letterSpacing: 0.65,
      color: PdfColors.black,
    );
    final totalBig = pw.TextStyle(
      font: fontBold,
      fontSize: 11,
      color: PdfColors.black,
    );
    final tiny = pw.TextStyle(
      font: font,
      fontSize: 7.5,
      color: PdfColors.black,
    );
    final metaCourier = pw.TextStyle(
      font: pw.Font.courier(),
      fontSize: 8.5,
      color: PdfColors.black,
    );

    pw.Widget hrLong() => pw.Text(
      ReceiptTicketLayout.sepLong,
      style: tiny,
      textAlign: pw.TextAlign.center,
    );
    pw.Widget hrMid() => pw.Text(
      ReceiptTicketLayout.sepMid,
      style: tiny,
      textAlign: pw.TextAlign.center,
    );
    pw.Widget hrTotal() => pw.Text(
      ReceiptTicketLayout.sepTotal,
      style: tiny,
      textAlign: pw.TextAlign.center,
    );

    final children = <pw.Widget>[
      if (logoPdf != null) ...[
        pw.Center(
          child: pw.Image(
            logoPdf,
            width: 52 * PdfPageFormat.mm,
            fit: pw.BoxFit.contain,
          ),
        ),
        pw.SizedBox(height: 4),
      ],
      pw.Center(
        child: pw.Text(
          storeName.toUpperCase(),
          style: storeTitleStyle,
          textAlign: pw.TextAlign.center,
        ),
      ),
      if (data.storeAddress != null && data.storeAddress!.trim().isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            _sanitizeForPdf(data.storeAddress!.trim()),
            style: base,
            textAlign: pw.TextAlign.center,
          ),
        ),
      if (tel.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            _sanitizeForPdf(tel),
            style: base,
            textAlign: pw.TextAlign.center,
          ),
        ),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Text(
          _sanitizeForPdf(
            ReceiptTicketLayout.metaFactureDateHeureLine(saleNumber, data.date),
          ),
          style: metaCourier,
          textAlign: pw.TextAlign.center,
        ),
      ),
      pw.SizedBox(height: 6),
      hrLong(),
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(2.2),
          1: const pw.FixedColumnWidth(18),
          2: const pw.FixedColumnWidth(32),
          3: const pw.FixedColumnWidth(32),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Text('Produit', style: bold),
              pw.Text('Qté', style: bold, textAlign: pw.TextAlign.center),
              pw.Text('PU(CFA)', style: bold, textAlign: pw.TextAlign.right),
              pw.Text('Total', style: bold, textAlign: pw.TextAlign.right),
            ],
          ),
        ],
      ),
      hrLong(),
      pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(2.2),
          1: const pw.FixedColumnWidth(18),
          2: const pw.FixedColumnWidth(32),
          3: const pw.FixedColumnWidth(32),
        },
        children: [
          for (final item in data.items)
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(
                    _truncate(_sanitizeForPdf(item.name), 22),
                    style: base,
                  ),
                ),
                pw.Text(
                  '${item.quantity}',
                  style: base,
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  '${item.unitPrice.round()}',
                  style: base,
                  textAlign: pw.TextAlign.right,
                ),
                pw.Text(
                  '${item.total.round()}',
                  style: base,
                  textAlign: pw.TextAlign.right,
                ),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 4),
      hrLong(),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Sous-total', style: base),
          pw.Text(ReceiptTicketLayout.intAmount(data.subtotal), style: base),
        ],
      ),
      if (data.discount > 0)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Remise', style: base),
            pw.Text(ReceiptTicketLayout.intAmount(data.discount), style: base),
          ],
        ),
      pw.SizedBox(height: 4),
      hrTotal(),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('TOTAL', style: totalBig),
          pw.Text(ReceiptTicketLayout.intAmount(data.total), style: totalBig),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text('Paiement : $payU', style: base),
      if (isCash) ...[
        pw.Text(
          'Reçu     : ${ReceiptTicketLayout.intAmount((data.amountReceived ?? data.total).round())}',
          style: base,
        ),
        pw.Text(
          'Rendu    : ${ReceiptTicketLayout.intAmount((data.change ?? 0).round())}',
          style: base,
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Center(
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrPayload,
          width: 72,
          height: 72,
          drawText: false,
          color: PdfColors.black,
          backgroundColor: PdfColors.white,
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.35),
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Merci pour votre achat !',
        style: bold,
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 6),
      hrMid(),
      pw.Text(
        'Powered by FasoStock POS',
        style: tiny,
        textAlign: pw.TextAlign.center,
      ),
      hrMid(),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(w, 297 * PdfPageFormat.mm, marginAll: margin),
        build: (pw.Context context) => children,
      ),
    );

    return doc.save();
  }

  /// Depuis l’UI, appeler via `unawaited(printReceipt(...))` pour ne pas bloquer l’écran.
  /// [userId] / [companyId] : si fournis, utilise l’imprimante ticket enregistrée (écran Imprimantes).
  static Future<PrintDispatchResult> printReceipt(
    ReceiptTicketData data, {
    String? userId,
    String? companyId,
  }) async {
    final safe = data.saleNumber.replaceAll(RegExp(r'[^\w\-.]'), '_');
    String? preferred;
    if (userId != null &&
        companyId != null &&
        userId.isNotEmpty &&
        companyId.isNotEmpty) {
      preferred = await PrinterAssociationStorage.getResolvedPrinterName(
        role: LocalPrinterRole.thermal,
        userId: userId,
        companyId: companyId,
      );
    }
    return printPdfToPhysicalPrinter(
      jobName: 'ticket_$safe.pdf',
      onLayout: (_) => _buildPdf(data),
      preferredPrinterName: preferred,
    );
  }
}

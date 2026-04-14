import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Détecte les pilotes « PDF / OneNote / XPS » qui ouvrent « Enregistrer sous » au lieu du papier.
bool looksLikeVirtualDocumentSink(Printer p) {
  final haystack = '${p.name} ${p.url}'.toLowerCase();
  const fragments = <String>[
    'microsoft print to pdf',
    'print to pdf',
    'save as pdf',
    'onenote',
    'xps document writer',
    'microsoft xps',
    'pdf24',
    'cutepdf',
    'foxit reader pdf',
    'adobe pdf',
    'nova pdf',
    'pdfcreator',
    'bullzip pdf',
    'soda pdf',
    'pdf-xchange',
    'primo pdf',
    'wondershare pdf',
    'image writer',
    'document writer',
  ];
  for (final s in fragments) {
    if (haystack.contains(s)) return true;
  }
  if (RegExp(r'\bfax\b').hasMatch(haystack) && !haystack.contains('laserjet')) {
    return true;
  }
  return false;
}

Printer? pickPhysicalPrinter(List<Printer> printers) {
  final physical = printers.where((p) => !looksLikeVirtualDocumentSink(p)).toList();
  if (physical.isEmpty) return null;
  for (final p in physical) {
    if (p.isDefault) return p;
  }
  return physical.first;
}

/// Trouve une imprimante par nom (insensible à la casse), sinon sous-chaîne.
Printer? findPrinterNamed(List<Printer> printers, String name) {
  final want = name.trim().toLowerCase();
  if (want.isEmpty) return null;
  for (final p in printers) {
    if (p.name.trim().toLowerCase() == want) return p;
  }
  for (final p in printers) {
    if (p.name.toLowerCase().contains(want)) return p;
  }
  return null;
}

/// Impression directe vers une imprimante physique ; sinon boîte de dialogue système.
///
/// [preferredPrinterName] : si renseigné et trouvé dans les imprimantes système,
/// envoi direct vers cette imprimante (écran Imprimantes).
///
/// **UI :** ne pas `await` depuis un handler d’écran — utiliser `unawaited(...)` + toast
/// pour ne pas bloquer l’interaction tant que le pilote / spooler travaille.
Future<void> printPdfToPhysicalPrinter({
  required String jobName,
  required Future<Uint8List> Function(PdfPageFormat format) onLayout,
  String? preferredPrinterName,
}) async {
  if (kIsWeb) {
    await Printing.layoutPdf(onLayout: onLayout);
    return;
  }

  final printers = await Printing.listPrinters();
  if (printers.isEmpty) {
    throw Exception('Aucune imprimante disponible.');
  }

  final preferred = preferredPrinterName?.trim();
  Printer? printer;
  if (preferred != null && preferred.isNotEmpty) {
    printer = findPrinterNamed(printers, preferred);
    if (printer != null && looksLikeVirtualDocumentSink(printer)) {
      printer = null;
    }
  }
  printer ??= pickPhysicalPrinter(printers);
  if (printer == null) {
    await Printing.layoutPdf(onLayout: onLayout);
    return;
  }

  await Printing.directPrintPdf(
    printer: printer,
    name: jobName,
    onLayout: onLayout,
  );
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/errors/app_error_handler.dart';

enum PrintDispatchMode { directPreferred, directAuto, systemDialog }

class PrintDispatchResult {
  const PrintDispatchResult({
    required this.mode,
    this.selectedPrinterName,
    this.preferredPrinterName,
  });

  final PrintDispatchMode mode;
  final String? selectedPrinterName;
  final String? preferredPrinterName;

  bool get usedSystemDialog => mode == PrintDispatchMode.systemDialog;
  bool get usedPreferredPrinter => mode == PrintDispatchMode.directPreferred;
}

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
  final physical = printers
      .where((p) => !looksLikeVirtualDocumentSink(p))
      .toList();
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
Future<PrintDispatchResult> printPdfToPhysicalPrinter({
  required String jobName,
  required Future<Uint8List> Function(PdfPageFormat format) onLayout,
  String? preferredPrinterName,
}) async {
  if (kIsWeb) {
    await Printing.layoutPdf(onLayout: onLayout);
    return PrintDispatchResult(
      mode: PrintDispatchMode.systemDialog,
      preferredPrinterName: preferredPrinterName?.trim(),
    );
  }

  List<Printer> printers;
  try {
    printers = await Printing.listPrinters();
  } catch (e, st) {
    // Offline-first: si le spooler / service d'énumération est indisponible,
    // on garde la possibilité d'imprimer via la boîte système.
    AppErrorHandler.logWithContext(
      e,
      stackTrace: st,
      logSource: 'physical_printer_pdf',
      logContext: const {'op': 'listPrinters'},
    );
    await Printing.layoutPdf(onLayout: onLayout);
    return PrintDispatchResult(
      mode: PrintDispatchMode.systemDialog,
      preferredPrinterName: preferredPrinterName?.trim(),
    );
  }
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
    return PrintDispatchResult(
      mode: PrintDispatchMode.systemDialog,
      preferredPrinterName: preferred,
    );
  }

  await Printing.directPrintPdf(
    printer: printer,
    name: jobName,
    onLayout: onLayout,
  );
  return PrintDispatchResult(
    mode:
        (preferred != null &&
            preferred.isNotEmpty &&
            printer.name.trim().toLowerCase() == preferred.toLowerCase())
        ? PrintDispatchMode.directPreferred
        : PrintDispatchMode.directAuto,
    selectedPrinterName: printer.name,
    preferredPrinterName: preferred,
  );
}

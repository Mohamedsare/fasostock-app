import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/services/printer_association_storage.dart';
import 'physical_printer_pdf.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/stores_repository.dart';
import '../../../shared/utils/format_currency.dart';

/// Données d'une ligne pour la facture A4.
class InvoiceLineData {
  const InvoiceLineData({
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.total,
  });
  final String description;
  final int quantity;
  final String unit;
  final double unitPrice;
  final double total;
}

/// Une ligne de règlement sur la facture (espèces, crédit, etc.).
class InvoicePaymentLineData {
  const InvoicePaymentLineData({
    required this.label,
    required this.amount,
    this.isImmediateEncaisse = true,
  });

  final String label;
  final double amount;
  /// Espèces, mobile money, carte, virement. `false` = montant porté au crédit client ([PaymentMethod.other]).
  final bool isImmediateEncaisse;
}

/// Données complètes pour générer une facture A4 PDF.
class InvoiceA4Data {
  const InvoiceA4Data({
    required this.store,
    required this.saleNumber,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.depositAmount,
    this.paymentLines,
    this.amountInWords,
    this.logoBytes,
  });

  final Store store;
  final String saleNumber;
  final DateTime date;
  final List<InvoiceLineData> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  /// Ancien mode : uniquement « encaissé » si [paymentLines] est vide (ex. brouillon sans détail).
  final double? depositAmount;
  /// Détail des paiements : permet encaisse partiel, total et crédit sans confondre « acompte » et créance.
  final List<InvoicePaymentLineData>? paymentLines;
  final String? amountInWords;
  /// Octets du logo entreprise (optionnel) — affiché en en-tête de la facture A4.
  final Uint8List? logoBytes;
}

/// Génère un PDF facture A4 à partir des paramètres boutique et des données de vente.
class InvoiceA4PdfService {
  static String paymentMethodLabelFr(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.mobile_money:
        return 'Mobile money';
      case PaymentMethod.card:
        return 'Carte bancaire';
      case PaymentMethod.transfer:
        return 'Virement';
      case PaymentMethod.other:
        return 'À crédit';
    }
  }

  static String _paymentLineLabel(PaymentMethod method, String? reference) {
    final base = paymentMethodLabelFr(method);
    final ref = reference?.trim();
    if (ref != null &&
        ref.isNotEmpty &&
        ref.toLowerCase() != base.toLowerCase()) {
      return '$base — $ref';
    }
    return base;
  }

  static List<InvoicePaymentLineData> paymentLinesFromSalePayments(
    List<SalePayment> payments,
  ) {
    final out = <InvoicePaymentLineData>[];
    for (final p in payments) {
      if (p.amount <= 0) continue;
      out.add(
        InvoicePaymentLineData(
          label: _paymentLineLabel(p.method, p.reference),
          amount: p.amount,
          isImmediateEncaisse: p.method != PaymentMethod.other,
        ),
      );
    }
    return out;
  }

  static List<InvoicePaymentLineData> paymentLinesFromCreateInputs(
    List<CreateSalePaymentInput> payments,
  ) {
    final out = <InvoicePaymentLineData>[];
    for (final p in payments) {
      if (p.amount <= 0) continue;
      out.add(
        InvoicePaymentLineData(
          label: _paymentLineLabel(p.method, p.reference),
          amount: p.amount,
          isImmediateEncaisse: p.method != PaymentMethod.other,
        ),
      );
    }
    return out;
  }

  static Future<File?> _logoCacheFile(String storeId) async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    final safe = storeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(p.join(dir.path, 'invoice_a4_logo_$safe.bin'));
  }

  static Future<Uint8List?> loadCachedLogoBytes(String storeId) async {
    try {
      final f = await _logoCacheFile(storeId);
      if (f == null) return null;
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheLogoBytes(String storeId, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    try {
      final f = await _logoCacheFile(storeId);
      if (f == null) return;
      await f.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  /// Retourne une boutique avec [invoice_template] résolu (depuis l'API si la boutique
  /// du cache n'a pas de modèle défini). À utiliser avant de construire [InvoiceA4Data]
  /// depuis la caisse facture A4 pour appliquer correctement le modèle Classique ou ELOF.
  static Future<Store> resolveStoreForInvoice(Store store, {bool allowNetwork = true}) async {
    final t = store.invoiceTemplate;
    if (t != null && t.trim().isNotEmpty) return store;
    if (!allowNetwork) return store;
    try {
      final fresh = await StoresRepository().getStore(store.id);
      if (fresh != null) return fresh;
    } catch (e, st) {
      AppErrorHandler.log(e, st);
    }
    return store;
  }

  /// Nettoie le texte pour éviter le caractère de remplacement (�) et les caractères qui s'affichent en carré dans le PDF.
  static String _sanitizeForPdf(String s) {
    if (s.isEmpty) return s;
    return s
        .replaceAll('\uFFFD', '') // caractère de remplacement Unicode (affiché comme carré avec X)
        .replaceAll('\u00A0', ' ') // espace insécable
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // caractères de contrôle
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '') // zero-width, BOM
        .replaceAll('\u2014', '-') // tiret long (em dash)
        .replaceAll('\u2013', '-'); // tiret moyen (en dash)
  }

  /// Retire le préfixe "Tel:" / "Tel :" du texte (saisie utilisateur ou ancienne mise en forme).
  static String _stripTelPrefix(String s) {
    if (s.isEmpty) return s;
    return s
        .trim()
        .replaceFirst(RegExp(r'^Tel\s*:\s*', caseSensitive: false), '')
        .trim();
  }

  static PdfColor _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return PdfColors.blue;
    String h = hex.startsWith('#') ? hex.substring(1) : hex;
    if (h.length == 6) {
      final r = int.tryParse(h.substring(0, 2), radix: 16) ?? 0;
      final g = int.tryParse(h.substring(2, 4), radix: 16) ?? 0;
      final b = int.tryParse(h.substring(4, 6), radix: 16) ?? 0;
      return PdfColor.fromInt((0xFF000000 | (r << 16) | (g << 8) | b));
    }
    return PdfColors.blue;
  }

  /// Retourne true si le modèle facture A4 choisi pour la boutique est ELOF (appliqué de façon fiable).
  static bool _isElofTemplate(Store store) {
    final t = store.invoiceTemplate;
    if (t == null || t.isEmpty) return false;
    return t.trim().toLowerCase() == 'elof';
  }

  /// Construit le document PDF (multi-pages si besoin).
  static Future<pw.Document> buildDocument(InvoiceA4Data data) async {
    final store = data.store;
    final primary = _hexToColor(store.primaryColor);
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm', 'fr_FR');
    final currency = store.currency ?? 'XOF';

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(store, primary, dateFormat, timeFormat, data),
        footer: (context) => _buildFooter(store),
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          // Air entre le trait d’en-tête (couleur boutique) et le logo / bloc société.
          pw.SizedBox(height: 16),
          _isElofTemplate(store)
              ? _buildStoreBlockElof(store, primary, logoBytes: data.logoBytes)
              : _buildStoreBlock(store, primary, logoBytes: data.logoBytes),
          pw.SizedBox(height: 16),
          _buildCustomerBlock(data),
          pw.SizedBox(height: 16),
          pw.Text('Facture n° ${_sanitizeForPdf(data.saleNumber)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Date : ${_sanitizeForPdf(dateFormat.format(data.date))} - ${_sanitizeForPdf(timeFormat.format(data.date))}', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),
          _buildTable(data, currency, primary),
          pw.SizedBox(height: 16),
          _buildTotals(data, currency, primary),
          if (data.amountInWords != null && data.amountInWords!.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Montant en lettres : ${_sanitizeForPdf(data.amountInWords!)}', style: const pw.TextStyle(fontSize: 11)),
          ],
          pw.SizedBox(height: 72),
          _buildSignatureBlock(store),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _buildHeader(Store store, PdfColor primary, DateFormat dateFormat, DateFormat timeFormat, InvoiceA4Data data) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: primary, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _sanitizeForPdf(store.commercialName ?? store.name),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primary),
          ),
          pw.Text(
            'Facture ${_sanitizeForPdf(data.saleNumber)} - ${_sanitizeForPdf(dateFormat.format(data.date))} ${_sanitizeForPdf(timeFormat.format(data.date))}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(Store store) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.black)),
      ),
      child: pw.Text(
        _sanitizeForPdf(store.footerText ?? 'Merci pour votre confiance.'),
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Pas de gris dans la facture A4 : tout en noir.
  static final PdfColor _textBlack = PdfColors.black;
  static final PdfColor _activityColor = PdfColors.black;

  static pw.Widget _buildStoreBlock(Store store, PdfColor primaryColor, {Uint8List? logoBytes}) {
    final hasLogo = logoBytes != null && logoBytes.isNotEmpty;
    // Bloc droit : titre/acronyme (bold, couleur personnalisable) → nom entreprise → secteur → adresse → tél
    final rightChildren = <pw.Widget>[];
    // Titre/acronyme et slogan : encore plus bold (couleur personnalisable pour titre/nom).
    final titleBold = pw.FontWeight.bold;
    final shortTitle = (store.invoiceShortTitle ?? store.description)?.trim();
    if (shortTitle != null && shortTitle.isNotEmpty) {
      rightChildren.add(pw.Text(
        _sanitizeForPdf(shortTitle).toUpperCase(),
        style: pw.TextStyle(fontSize: 24, fontWeight: titleBold, color: primaryColor, letterSpacing: 4),
        textAlign: pw.TextAlign.right,
      ));
      rightChildren.add(pw.SizedBox(height: 6));
    }
    rightChildren.add(pw.Text(
      _sanitizeForPdf(store.commercialName ?? store.name).toUpperCase(),
      style: pw.TextStyle(fontSize: 19, fontWeight: titleBold, color: primaryColor),
      textAlign: pw.TextAlign.right,
    ));
    if (store.slogan != null && store.slogan!.trim().isNotEmpty) {
      for (final line in store.slogan!.trim().split('\n')) {
        if (line.isEmpty) continue;
        rightChildren.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(_sanitizeForPdf(line).toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: titleBold, color: _textBlack), textAlign: pw.TextAlign.right)));
      }
    }
    // Secteur d'activité : affiché quand il est renseigné (une ou plusieurs lignes).
    final activityStr = (store.activity ?? '').trim();
    if (activityStr.isNotEmpty) {
      for (final line in activityStr.split(RegExp(r'[\r\n]+')).where((s) => s.isNotEmpty)) {
        rightChildren.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf(line).toUpperCase(),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _activityColor),
            textAlign: pw.TextAlign.right,
          ),
        ));
      }
    }
    // Téléphone (optionnel) — sans "Tel:" dans la facture.
    if (store.phone != null && store.phone!.trim().isNotEmpty) {
      final phone = _stripTelPrefix(store.phone!);
      if (phone.isNotEmpty) {
        rightChildren.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf(phone),
            style: pw.TextStyle(fontSize: 11, color: _textBlack),
            textAlign: pw.TextAlign.right,
          ),
        ));
      }
    }
    // Mobile money (optionnel) — sans "Tel:" dans la facture.
    if (store.mobileMoney != null && store.mobileMoney!.trim().isNotEmpty) {
      final mm = _stripTelPrefix(store.mobileMoney!);
      if (mm.isNotEmpty) {
        rightChildren.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            'Mobile money ${_sanitizeForPdf(mm)}',
            style: pw.TextStyle(fontSize: 11, color: _textBlack),
            textAlign: pw.TextAlign.right,
          ),
        ));
      }
    }
    if (store.address != null && store.address!.trim().isNotEmpty) {
      rightChildren.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(_sanitizeForPdf(store.address!.trim()), style: pw.TextStyle(fontSize: 11, color: _textBlack), textAlign: pw.TextAlign.right)));
    }
    final rightBlock = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisSize: pw.MainAxisSize.min,
      children: rightChildren,
    );
    if (hasLogo) {
      final leftBlock = pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Image(pw.MemoryImage(logoBytes), width: 80, height: 80),
          pw.SizedBox(height: 8),
          pw.Text(
            _sanitizeForPdf(store.name).toUpperCase(),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
            textAlign: pw.TextAlign.left,
          ),
        ],
      );
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          leftBlock,
          pw.SizedBox(width: 32),
          pw.Expanded(child: rightBlock),
        ],
      );
    }
    return pw.Align(alignment: pw.Alignment.centerRight, child: rightBlock);
  }

  /// Couleur orange pour la ligne "Orange money" (modèle ELOF).
  static final PdfColor _elofOrange = PdfColor.fromInt(0xFFE65100);

  /// En-tête facture A4 modèle ELOF : logo à gauche (toujours en place), puis E L O F → nom → activité (2 lignes) → adresse → Cel → Orange money (orange) au centre.
  static pw.Widget _buildStoreBlockElof(Store store, PdfColor primaryColor, {Uint8List? logoBytes}) {
    final hasLogo = logoBytes != null && logoBytes.isNotEmpty;
    final mainColor = primaryColor;
    final children = <pw.Widget>[];

    // 1. E L O F — lettres espacées (acronyme depuis invoice_short_title)
    final acronym = (store.invoiceShortTitle ?? 'ELOF').trim().toUpperCase().replaceAll(' ', '');
    if (acronym.isNotEmpty) {
      final letters = acronym.length >= 4 ? acronym.substring(0, 4).split('') : acronym.split('');
      children.add(
        pw.Text(
          letters.join('   '),
          style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: mainColor, letterSpacing: 6),
          textAlign: pw.TextAlign.center,
        ),
      );
      children.add(pw.SizedBox(height: 6));
    }

    // 2. Nom entreprise (ETS OUEDRAOGO & FRERES)
    children.add(
      pw.Text(
        _sanitizeForPdf(store.commercialName ?? store.name).toUpperCase(),
        style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: mainColor),
        textAlign: pw.TextAlign.center,
      ),
    );

    // 3. Slogan (optionnel, 2 lignes max)
    final sloganStr = (store.slogan ?? '').trim();
    if (sloganStr.isNotEmpty) {
      for (final line in sloganStr.split(RegExp(r'[\r\n]+')).where((s) => s.isNotEmpty).take(2)) {
        children.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf(line).toUpperCase(),
            style: pw.TextStyle(fontSize: 12, color: _textBlack),
            textAlign: pw.TextAlign.center,
          ),
        ));
      }
    }
    // 4. Activité — toujours affichée quand renseignée (2 lignes max)
    final activityStr = (store.activity ?? '').trim();
    if (activityStr.isNotEmpty) {
      for (final line in activityStr.split(RegExp(r'[\r\n]+')).where((s) => s.isNotEmpty).take(2)) {
        children.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf(line).toUpperCase(),
            style: pw.TextStyle(fontSize: 12, color: _textBlack),
            textAlign: pw.TextAlign.center,
          ),
        ));
      }
    }

    // 5. Adresse (Sis au marché...)
    if (store.address != null && store.address!.trim().isNotEmpty) {
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          _sanitizeForPdf(store.address!.trim()),
          style: pw.TextStyle(fontSize: 11, color: _textBlack),
          textAlign: pw.TextAlign.center,
        ),
      ));
    }

    // 6. Téléphone — sans "Tel:" ni "Cel:" dans la facture
    if (store.phone != null && store.phone!.trim().isNotEmpty) {
      final phone = _stripTelPrefix(store.phone!);
      if (phone.isNotEmpty) {
        children.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf(phone),
            style: pw.TextStyle(fontSize: 11, color: _textBlack),
            textAlign: pw.TextAlign.center,
          ),
        ));
      }
    }

    // 7. Orange money — en orange, sans "Tel:" dans la facture
    if (store.mobileMoney != null && store.mobileMoney!.trim().isNotEmpty) {
      final mm = _stripTelPrefix(store.mobileMoney!);
      if (mm.isNotEmpty) {
        children.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            'Orange money ${_sanitizeForPdf(mm)}',
            style: pw.TextStyle(fontSize: 11, color: _elofOrange),
            textAlign: pw.TextAlign.center,
          ),
        ));
      }
    }

    final centerBlock = pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: children,
    );

    // Modèle ELOF : toujours la même mise en page avec le logo à gauche (affiché si fourni).
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (hasLogo) pw.Image(pw.MemoryImage(logoBytes), width: 80, height: 80),
              if (hasLogo) pw.SizedBox(height: 8),
              pw.Text(
                _sanitizeForPdf(store.name).toUpperCase(),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
            ],
          ),
        ),
        pw.Expanded(child: pw.Center(child: centerBlock)),
      ],
    );
  }

  static pw.Widget _buildCustomerBlock(InvoiceA4Data data) {
    if (data.customerName == null && data.customerPhone == null && data.customerAddress == null) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Client', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          if (data.customerName != null) pw.Text(_sanitizeForPdf(data.customerName!), style: const pw.TextStyle(fontSize: 11)),
          if (data.customerPhone != null) pw.Text(_sanitizeForPdf(data.customerPhone!), style: const pw.TextStyle(fontSize: 11)),
          if (data.customerAddress != null) pw.Text(_sanitizeForPdf(data.customerAddress!), style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  /// Quantité formatée : 0–9 → 01, 02, … 09.
  static String _formatQuantity(int qty) {
    if (qty >= 0 && qty <= 9) return qty.toString().padLeft(2, '0');
    return qty.toString();
  }

  /// Bordures du tableau en noir (pas de gris dans la facture A4).
  static final PdfColor _tableBorderColor = PdfColors.black;

  static pw.Widget _buildTable(InvoiceA4Data data, String currency, PdfColor primary) {
    final headerBg = primary;
    return pw.Table(
      border: pw.TableBorder.all(color: _tableBorderColor, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: [
            _cellHeader('N°', headerBg, center: true),
            _cellHeader('Désignation', headerBg),
            _cellHeader('Quantité', headerBg, center: true),
            _cellHeader('Unité', headerBg, center: true),
            _cellHeader('Prix unit.', headerBg, alignRight: true),
            _cellHeader('Total', headerBg, alignRight: true),
          ],
        ),
        ...data.items.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final line = entry.value;
          return pw.TableRow(
            children: [
              _cell('$i', center: true),
              _cell(_sanitizeForPdf(line.description).toUpperCase()),
              _cell(_formatQuantity(line.quantity), center: true),
              _cell(line.unit, center: true),
              _cell(formatCurrency(line.unitPrice), alignRight: true),
              _cell(formatCurrency(line.total), alignRight: true),
            ],
          );
        }),
      ],
    );
  }

  /// Cellule en-tête : fond couleur boutique, texte blanc, bien lisible.
  static pw.Widget _cellHeader(String text, PdfColor headerBg, {bool center = false, bool alignRight = false}) {
    final alignment = alignRight
        ? pw.Alignment.centerRight
        : (center ? pw.Alignment.center : pw.Alignment.centerLeft);
    final textAlign = alignRight
        ? pw.TextAlign.right
        : (center ? pw.TextAlign.center : pw.TextAlign.left);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: alignment,
      child: pw.Text(
        _sanitizeForPdf(text),
        textAlign: textAlign,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, bool center = false, bool alignRight = false}) {
    final alignment = alignRight
        ? pw.Alignment.centerRight
        : (center ? pw.Alignment.center : pw.Alignment.centerLeft);
    final textAlign = alignRight
        ? pw.TextAlign.right
        : (center ? pw.TextAlign.center : pw.TextAlign.left);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.SizedBox(
        width: double.infinity,
        child: pw.Align(
          alignment: alignment,
          child: pw.Text(
            _sanitizeForPdf(text),
            textAlign: textAlign,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildTotals(InvoiceA4Data data, String currency, PdfColor primaryColor) {
    final linesList = data.paymentLines;
    var encaisseImmediate = 0.0;
    if (linesList != null) {
      for (final pl in linesList) {
        if (pl.isImmediateEncaisse) encaisseImmediate += pl.amount;
      }
    }
    final hasLines = linesList != null && linesList.isNotEmpty;

    double encaisseEffectif;
    if (hasLines) {
      encaisseEffectif = encaisseImmediate;
    } else if (data.depositAmount != null) {
      encaisseEffectif = data.depositAmount!.clamp(0.0, double.infinity);
    } else {
      encaisseEffectif = 0.0;
    }

    final resteDu = (data.total - encaisseEffectif).clamp(0.0, double.infinity);
    final totalPositive = data.total > 0.001;
    final showReglement =
        totalPositive &&
        (hasLines ||
            (data.depositAmount != null && data.depositAmount! > 0.001));

    pw.Widget? statutLigne;
    if (showReglement) {
      if (resteDu < 0.01) {
        statutLigne = pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf('Statut : facture intégralement réglée'),
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey800,
            ),
          ),
        );
      } else if (encaisseEffectif < 0.01) {
        statutLigne = pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf('Statut : paiement à crédit — solde à régler'),
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey800,
            ),
          ),
        );
      } else {
        statutLigne = pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            _sanitizeForPdf('Statut : règlement partiel — solde à régler'),
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey800,
            ),
          ),
        );
      }
    }

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 280,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (data.discount > 0) _totalRowSimple('Sous-total', data.subtotal),
            if (data.discount > 0) _totalRowSimple('Remise', -data.discount),
            if (data.tax > 0) _totalRowSimple('TVA', data.tax),
            pw.SizedBox(height: 8),
            _totalRowBlock(
              data.tax > 0 ? 'Montant total TTC' : 'Montant total',
              data.total,
              primaryColor,
            ),
            if (showReglement) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                _sanitizeForPdf('Règlement'),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              if (linesList != null && linesList.isNotEmpty)
                ...linesList.map(
                  (pl) => _totalRowSimple(pl.label, pl.amount),
                )
              else if (data.depositAmount != null)
                _totalRowSimple('Montant encaissé', encaisseEffectif),
              pw.SizedBox(height: 6),
              _totalRowBlock(
                'Total encaissé',
                encaisseEffectif,
                primaryColor,
              ),
              _totalRowBlock('Reste à payer', resteDu, primaryColor),
              ?statutLigne,
            ],
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRowSimple(String label, double amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_sanitizeForPdf(label), style: const pw.TextStyle(fontSize: 11)),
          pw.Text(_sanitizeForPdf(formatCurrency(amount)), style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  /// Ligne type facture : libellé fond bleu (couleur boutique, comme le slogan), valeur à droite.
  static pw.Widget _totalRowBlock(String label, double amount, PdfColor labelBg) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 120,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(color: labelBg),
            child: pw.Text(
              _sanitizeForPdf(label),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
              child: pw.Text(
                _sanitizeForPdf(formatCurrency(amount)),
                style: const pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bloc signataire en bas de la dernière page : titre (ex. DIRECTEUR GENERAL) puis nom (ex. M. MAHAMADI ELOF).
  /// L'utilisateur signe et cachette à la main au-dessus.
  static pw.Widget _buildSignatureBlock(Store store) {
    final hasSigner = (store.invoiceSignerTitle != null && store.invoiceSignerTitle!.trim().isNotEmpty) ||
        (store.invoiceSignerName != null && store.invoiceSignerName!.trim().isNotEmpty);
    if (!hasSigner) return pw.SizedBox(height: 32);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 48),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (store.invoiceSignerTitle != null && store.invoiceSignerTitle!.trim().isNotEmpty)
              pw.Text(
                _sanitizeForPdf(store.invoiceSignerTitle!.trim()).toUpperCase(),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.normal, color: _textBlack),
                textAlign: pw.TextAlign.right,
              ),
            if (store.invoiceSignerName != null && store.invoiceSignerName!.trim().isNotEmpty) ...[
              if (store.invoiceSignerTitle != null && store.invoiceSignerTitle!.trim().isNotEmpty) pw.SizedBox(height: 4),
              pw.Text(
                _sanitizeForPdf(store.invoiceSignerName!.trim()).toUpperCase(),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal, color: _textBlack),
                textAlign: pw.TextAlign.right,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Génère le PDF et retourne les octets.
  static Future<Uint8List> generatePdf(InvoiceA4Data data) async {
    final doc = await buildDocument(data);
    return doc.save();
  }

  /// Ouvre la prévisualisation et permet l'impression / partage.
  static Future<void> previewPdf(InvoiceA4Data data) async {
    await Printing.layoutPdf(onLayout: (_) async {
      final doc = await buildDocument(data);
      return doc.save();
    });
  }

  /// Prévisualise un PDF déjà généré (une seule construction du document).
  static Future<void> previewPdfBytes(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Impression directe à partir d’octets PDF — peut être lancée avec [unawaited]
  /// après [generatePdf] pour que l’UI ne reste pas figée pendant le spooler.
  static Future<void> printPdfBytesDirect(
    Uint8List bytes,
    String saleNumber, {
    String? userId,
    String? companyId,
  }) async {
    String? preferred;
    if (userId != null &&
        companyId != null &&
        userId.isNotEmpty &&
        companyId.isNotEmpty) {
      preferred = await PrinterAssociationStorage.getResolvedPrinterName(
        role: LocalPrinterRole.a4,
        userId: userId,
        companyId: companyId,
      );
    }
    await printPdfToPhysicalPrinter(
      jobName: _pdfFileName(saleNumber),
      onLayout: (_) async => bytes,
      preferredPrinterName: preferred,
    );
  }

  /// Partage la facture PDF (menu partager : envoi, autre app, etc.).
  static Future<void> sharePdf(InvoiceA4Data data) async {
    final bytes = await generatePdf(data);
    final name = _pdfFileName(data.saleNumber);
    final xfile = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: name,
    );
    await Share.shareXFiles([xfile], subject: 'Facture ${data.saleNumber}');
  }

  static String _pdfFileName(String saleNumber) {
    return 'facture_${saleNumber.replaceAll(RegExp(r'[^\w\-.]'), '_')}.pdf';
  }

  /// Télécharge réellement le PDF : enregistre le fichier (dialog d’enregistrement sur desktop, etc.).
  /// Sur le web, ouvre le partage / téléchargement selon la plateforme.
  static Future<String?> downloadPdf(InvoiceA4Data data) async {
    final bytes = await generatePdf(data);
    final name = _pdfFileName(data.saleNumber);

    if (kIsWeb) {
      try {
        await Share.shareXFiles(
          [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: name),
          ],
          subject: 'Facture ${data.saleNumber}',
        );
      } catch (_) {
        await previewPdf(data);
      }
      return name;
    }

    final path = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      fileName: name,
      dialogTitle: 'Enregistrer la facture PDF',
    );
    if (path == null || path.isEmpty) return null;

    var outPath = path.trim();
    if (!outPath.toLowerCase().endsWith('.pdf')) {
      outPath = outPath.endsWith('.') ? '${outPath}pdf' : '$outPath.pdf';
    }

    try {
      await File(outPath).writeAsBytes(bytes, flush: true);
      return outPath;
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      rethrow;
    }
  }

  /// Imprime la facture A4 sans étape de preview vers une imprimante **papier** si possible.
  ///
  /// **UI :** utiliser `unawaited(printPdfDirect(...))` + retour utilisateur (toast).
  static Future<void> printPdfDirect(
    InvoiceA4Data data, {
    String? userId,
    String? companyId,
  }) async {
    String? preferred;
    if (userId != null &&
        companyId != null &&
        userId.isNotEmpty &&
        companyId.isNotEmpty) {
      preferred = await PrinterAssociationStorage.getResolvedPrinterName(
        role: LocalPrinterRole.a4,
        userId: userId,
        companyId: companyId,
      );
    }
    await printPdfToPhysicalPrinter(
      jobName: _pdfFileName(data.saleNumber),
      onLayout: (_) async {
        final doc = await buildDocument(data);
        return doc.save();
      },
      preferredPrinterName: preferred,
    );
  }
}

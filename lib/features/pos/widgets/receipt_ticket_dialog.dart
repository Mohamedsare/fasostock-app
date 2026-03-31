import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/public_website_url.dart';
import 'receipt_ticket_layout.dart';

/// Données du ticket (aligné web ReceiptTicket).
class ReceiptTicketData {
  ReceiptTicketData({
    required this.storeName,
    this.storeLogoUrl,
    this.storeAddress,
    this.storePhone,
    required this.saleNumber,
    this.saleId,
    this.cashierName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.paymentMethod = 'Espèces',
    this.amountReceived,
    this.change,
    DateTime? date,
    this.customerName,
    this.customerPhone,
    this.qrCompanyWebsiteUrl,
  }) : date = date ?? DateTime.now();

  final String storeName;
  /// URL publique du logo boutique (Supabase `logo_url`) — affiché en haut du ticket, centré.
  final String? storeLogoUrl;
  final String? storeAddress;
  final String? storePhone;
  final String saleNumber;
  /// Identifiant vente (UUID serveur ou `pending:…`) — encodé dans le QR.
  final String? saleId;
  final String? cashierName;
  final String? customerName;
  final String? customerPhone;
  final List<ReceiptItemData> items;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentMethod;
  final double? amountReceived;
  final double? change;
  final DateTime date;
  /// Si renseigné (URL https), le QR du ticket ouvre ce lien ; sinon payload texte ticket (historique).
  final String? qrCompanyWebsiteUrl;
}

class ReceiptItemData {
  const ReceiptItemData({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;
}

/// Contenu du QR (même chaîne pour l’aperçu et le PDF thermique).
extension ReceiptTicketDataQr on ReceiptTicketData {
  String buildQrPayload() {
    final url = normalizePublicWebsiteUrlForQr(qrCompanyWebsiteUrl);
    if (url != null) return url;

    final buf = StringBuffer();
    buf.writeln('FASOSTOCK');
    buf.writeln('Ticket: $saleNumber');
    buf.writeln('Total: ${ReceiptTicketLayout.intAmount(total)}');
    buf.writeln(DateFormat('yyyy-MM-dd HH:mm').format(date));
    if (saleId != null && saleId!.trim().isNotEmpty) {
      buf.writeln('id:${saleId!.trim()}');
    }
    return buf.toString().trim();
  }
}

/// Aperçu écran — noir & blanc uniquement, colonnes monospace.
/// Largeur carte ≈ **72 mm** de zone utile (équivalent ~96 dpi) + marges latérales 12 px
/// (aligné PDF thermique : papier 80 mm, contenu ~72 mm).
const double _kReceiptWidth = 272 + 24;

const TextStyle _kMono = TextStyle(
  fontFamily: 'Courier New',
  fontFamilyFallback: ['monospace', 'Courier'],
  fontSize: 9.5,
  height: 1.22,
  color: Color(0xFF000000),
);

/// Titre boutique : police display ultra-grasse (Archivo Black), taille 25.
const TextStyle _kStoreTitle = TextStyle(
  fontFamily: 'Archivo Black',
  fontSize: 25,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.65,
  height: 1.05,
  color: Color(0xFF000000),
);

/// Ligne `---…` centrée : sans retour à la ligne (sinon les tirets peuvent se couper un par un — césure Unicode).
Widget _receiptSeparatorLine(String text, TextStyle style) {
  return Align(
    alignment: Alignment.center,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(
        text,
        style: style,
        textAlign: TextAlign.center,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    ),
  );
}

/// Ligne tableau ticket (Produit / Qté / PU / Total) : une seule ligne, sans retour à la ligne qui décale les colonnes.
Widget _receiptTableLine(String line, TextStyle style) {
  return Align(
    alignment: Alignment.centerLeft,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        line,
        style: style,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    ),
  );
}

/// Ligne article : nom du produit jusqu’à 2 lignes à gauche ; Qté / PU / Total alignés à droite (1re ligne).
Widget _receiptProductRow(ReceiptItemData item, TextStyle style) {
  final numeric = ReceiptTicketLayout.productNumericLine(
    item.quantity,
    item.unitPrice.round(),
    item.total.round(),
  );
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            item.name.trim(),
            style: style,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topRight,
          child: Text(
            numeric,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
      ],
    ),
  );
}

/// Libellé à gauche, montant à droite (même ligne — `Flexible` + `Spacer`, sans baseline qui casse la ligne).
Widget _receiptAmountRow(String label, String value, TextStyle valueStyle) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            label,
            style: valueStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Text(value, style: valueStyle, maxLines: 1, softWrap: false),
      ],
    ),
  );
}

class ReceiptTicketWidget extends StatelessWidget {
  const ReceiptTicketWidget({super.key, required this.data});

  final ReceiptTicketData data;

  @override
  Widget build(BuildContext context) {
    final tel = ReceiptTicketLayout.telLine(data.storePhone);
    final payU = ReceiptTicketLayout.paymentUppercase(data.paymentMethod);
    final isCashLike = payU == 'ESPECES';
    final qrData = data.buildQrPayload();

    return Container(
      width: _kReceiptWidth,
      constraints: const BoxConstraints(maxWidth: _kReceiptWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        border: Border.all(color: const Color(0xFFCCCCCC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: _kMono,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.storeLogoUrl != null && data.storeLogoUrl!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 248, maxHeight: 80),
                    child: Image.network(
                      data.storeLogoUrl!.trim(),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            Text(
              data.storeName.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 3,
              softWrap: true,
              style: _kStoreTitle,
            ),
            if (data.storeAddress != null && data.storeAddress!.trim().isNotEmpty)
              Text(
                data.storeAddress!.trim(),
                textAlign: TextAlign.center,
                style: _kMono.copyWith(fontSize: 9),
              ),
            if (tel.isNotEmpty)
              Text(
                tel,
                textAlign: TextAlign.center,
                style: _kMono.copyWith(fontSize: 9),
              ),
            const SizedBox(height: 8),
            Text(
              ReceiptTicketLayout.metaFactureDateHeureLine(data.saleNumber, data.date),
              textAlign: TextAlign.center,
              style: _kMono.copyWith(fontSize: 9.5),
            ),
            const SizedBox(height: 6),
            _receiptSeparatorLine(ReceiptTicketLayout.sepLong, _kMono.copyWith(fontSize: 9)),
            _receiptTableLine(
              ReceiptTicketLayout.headerMonoLine(),
              _kMono.copyWith(fontWeight: FontWeight.w700, fontSize: 9),
            ),
            _receiptSeparatorLine(ReceiptTicketLayout.sepLong, _kMono.copyWith(fontSize: 9)),
            ...data.items.map((item) {
              return _receiptProductRow(item, _kMono.copyWith(fontSize: 9));
            }),
            const SizedBox(height: 4),
            _receiptSeparatorLine(ReceiptTicketLayout.sepLong, _kMono.copyWith(fontSize: 9)),
            const SizedBox(height: 4),
            _receiptAmountRow(
              'Sous-total',
              ReceiptTicketLayout.intAmount(data.subtotal),
              _kMono.copyWith(fontSize: 9),
            ),
            if (data.discount > 0)
              _receiptAmountRow(
                'Remise',
                ReceiptTicketLayout.intAmount(data.discount),
                _kMono.copyWith(fontSize: 9),
              ),
            const SizedBox(height: 4),
            _receiptSeparatorLine(ReceiptTicketLayout.sepTotal, _kMono.copyWith(fontSize: 9)),
            const SizedBox(height: 4),
            _receiptAmountRow(
              'TOTAL',
              ReceiptTicketLayout.intAmount(data.total),
              _kMono.copyWith(fontSize: 12, fontWeight: FontWeight.w800, height: 1.0),
            ),
            const SizedBox(height: 8),
            _receiptAmountRow('Paiement', payU, _kMono.copyWith(fontSize: 9.5)),
            if (isCashLike) ...[
              _receiptAmountRow(
                'Reçu',
                ReceiptTicketLayout.intAmount((data.amountReceived ?? data.total).round()),
                _kMono.copyWith(fontSize: 9.5),
              ),
              _receiptAmountRow(
                'Rendu',
                ReceiptTicketLayout.intAmount((data.change ?? 0).round()),
                _kMono.copyWith(fontSize: 9.5),
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 108,
                padding: EdgeInsets.zero,
                gapless: true,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Merci pour votre achat !',
              textAlign: TextAlign.center,
              style: _kMono.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _receiptSeparatorLine(ReceiptTicketLayout.sepMid, _kMono.copyWith(fontSize: 9)),
            Text(
              'Powered by FasoStock POS',
              textAlign: TextAlign.center,
              style: _kMono.copyWith(fontSize: 8.5, color: const Color(0xFF333333)),
            ),
            _receiptSeparatorLine(ReceiptTicketLayout.sepMid, _kMono.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

/// Dialog affichant le ticket + boutons Fermer / Imprimer / Facture A4 PDF.
class ReceiptTicketDialog extends StatelessWidget {
  const ReceiptTicketDialog({super.key, required this.data, this.onPrint, this.onViewA4Pdf});

  final ReceiptTicketData data;
  /// Impression réelle du ticket (caisse rapide, etc.) — **ne pas** y faire d’`await` long ; lancer l’impression en arrière-plan.
  final VoidCallback? onPrint;
  /// Callback pour ouvrir la facture A4 PDF (POS Facture A4).
  final VoidCallback? onViewA4Pdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTicketHeight = MediaQuery.sizeOf(context).height * 0.58;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Vente enregistrée',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxTicketHeight),
                child: SingleChildScrollView(
                  child: ReceiptTicketWidget(data: data),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (onViewA4Pdf != null)
                    FilledButton.icon(
                      onPressed: onViewA4Pdf,
                      icon: const Icon(Icons.description_outlined, size: 20),
                      label: const Text('Facture A4 (PDF)'),
                    ),
                  if (onPrint != null)
                    FilledButton.tonalIcon(
                      onPressed: onPrint,
                      icon: const Icon(Icons.print_outlined, size: 20),
                      label: const Text('Imprimer'),
                    ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

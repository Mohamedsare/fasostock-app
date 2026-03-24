import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/format_currency.dart';

/// Données du ticket (aligné web ReceiptTicket).
class ReceiptTicketData {
  ReceiptTicketData({
    required this.storeName,
    this.storeAddress,
    this.storePhone,
    required this.saleNumber,
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
  }) : date = date ?? DateTime.now();

  final String storeName;
  final String? storeAddress;
  final String? storePhone;
  final String saleNumber;
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

/// Largeur type ticket thermique 80 mm (équivalent écran).
const double _kReceiptWidth = 280;

/// Couleur papier thermique (blanc cassé).
const Color _kReceiptPaper = Color(0xFFFDFBF7);

/// Ticket de caisse — style thermique ultra réaliste (58/80 mm).
class ReceiptTicketWidget extends StatelessWidget {
  const ReceiptTicketWidget({super.key, required this.data});

  final ReceiptTicketData data;

  static String _truncate(String name, int maxLen) {
    if (name.length <= maxLen) return name;
    return '${name.substring(0, maxLen - 1)}.';
  }

  static String _stripTel(String? s) {
    if (s == null || s.trim().isEmpty) return '';
    return s.trim().replaceFirst(RegExp(r'^Tel\s*:\s*', caseSensitive: false), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    const maxNameLen = 20;
    final dateStr = DateFormat('dd/MM/yyyy', 'fr_FR').format(data.date);
    final timeStr = DateFormat('HH:mm', 'fr_FR').format(data.date);
    final phone = _stripTel(data.storePhone);
    final customerPhone = _stripTel(data.customerPhone);

    return Container(
      width: _kReceiptWidth,
      constraints: const BoxConstraints(maxWidth: _kReceiptWidth),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: _kReceiptPaper,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300, width: 1),
          right: BorderSide(color: Colors.grey.shade300, width: 1),
          top: BorderSide(color: Colors.grey.shade300, width: 1),
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Color(0xFF1A1A1A),
          height: 1.2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----- Ligne pointillée type thermique -----
            _dashedLine(),
            const SizedBox(height: 10),
            // Nom de la boutique (centré, gras)
            Text(
              data.storeName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            if (data.storeAddress != null && data.storeAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                data.storeAddress!.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(phone, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
            ],
            const SizedBox(height: 8),
            _dashedLine(),
            // N° ticket + date + heure (une ligne compacte)
            Text(
              'N° ${data.saleNumber}    $dateStr  $timeStr',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
            const SizedBox(height: 6),
            _dashedLine(),
            // Client (si présent)
            if (data.customerName != null && data.customerName!.trim().isNotEmpty) ...[
              Text('Client: ${data.customerName!.trim()}', style: const TextStyle(fontSize: 10)),
              if (customerPhone.isNotEmpty) Text(customerPhone, style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 4),
              _dashedLine(),
            ],
            // Articles — style ticket réel : désignation puis qté x prix = total
            ...data.items.map((item) {
              final name = _truncate(item.name, maxNameLen);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 11)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '  ${item.quantity} x ${formatCurrency(item.unitPrice)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(formatCurrency(item.total), style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              );
            }),
            _dashedLine(),
            // Totaux
            _row('Sous-total', formatCurrency(data.subtotal)),
            if (data.discount > 0) _row('Remise', '-${formatCurrency(data.discount)}'),
            const SizedBox(height: 4),
            // Double ligne avant TOTAL (style thermique)
            _doubleLine(),
            _row('TOTAL TTC', formatCurrency(data.total), bold: true),
            const SizedBox(height: 6),
            _row('Paiement', data.paymentMethod),
            if ((data.amountReceived ?? 0) > 0) ...[
              _row('Montant reçu', formatCurrency(data.amountReceived ?? 0)),
              if ((data.change ?? -1) >= 0)
                _row('Monnaie', formatCurrency(data.change ?? 0), bold: true),
            ],
            const SizedBox(height: 10),
            _dashedLine(),
            const Text(
              'Merci et à bientôt',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              '--- FasoStock ---',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            _dashedLine(),
          ],
        ),
      ),
    );
  }

  Widget _dashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '- - - - - - - - - - - - - - - - - - - -',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
      ),
    );
  }

  Widget _doubleLine() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '==============================',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
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
    final maxTicketHeight = MediaQuery.sizeOf(context).height * 0.55;
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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/sale.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../../data/repositories/stores_repository.dart';
import '../../../shared/utils/format_currency.dart';
import '../../pos/services/invoice_a4_pdf_service.dart';
import '../../pos/services/receipt_thermal_print_service.dart';
import '../../pos/widgets/receipt_ticket_dialog.dart';

const _statusLabels = {
  SaleStatus.draft: 'Brouillon',
  SaleStatus.completed: 'Complétée',
  SaleStatus.cancelled: 'Annulée',
  SaleStatus.refunded: 'Remboursée',
};

Color _statusChipBackground(SaleStatus status, ColorScheme scheme) {
  switch (status) {
    case SaleStatus.completed:
      return scheme.primaryContainer;
    case SaleStatus.cancelled:
      return scheme.errorContainer;
    case SaleStatus.refunded:
      return scheme.tertiaryContainer;
    case SaleStatus.draft:
      return scheme.surfaceContainerHighest;
  }
}

Color _statusChipForeground(SaleStatus status, ColorScheme scheme) {
  switch (status) {
    case SaleStatus.completed:
      return scheme.onPrimaryContainer;
    case SaleStatus.cancelled:
      return scheme.onErrorContainer;
    case SaleStatus.refunded:
      return scheme.onTertiaryContainer;
    case SaleStatus.draft:
      return scheme.onSurface;
  }
}

const _paymentLabels = {
  PaymentMethod.cash: 'Espèces',
  PaymentMethod.mobile_money: 'Mobile money',
  PaymentMethod.card: 'Carte',
  PaymentMethod.transfer: 'Virement',
  PaymentMethod.other: 'Autre',
};

String _formatDateTime(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(d.toLocal());
  } catch (_) {
    return iso;
  }
}

/// Dialog détail d'une vente — articles, paiements, total (aligné SaleDetailDialog web).
class SaleDetailDialog extends StatefulWidget {
  const SaleDetailDialog({
    super.key,
    required this.saleId,
    required this.onClose,
  });

  final String saleId;
  final VoidCallback onClose;

  @override
  State<SaleDetailDialog> createState() => _SaleDetailDialogState();
}

class _SaleDetailDialogState extends State<SaleDetailDialog> {
  final SalesRepository _repo = SalesRepository();
  final StoresRepository _storesRepo = StoresRepository();
  Sale? _sale;
  String? _creatorName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sale = await _repo.get(widget.saleId);
      String? creatorName;
      if (sale != null && sale.createdBy.isNotEmpty) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name')
            .eq('id', sale.createdBy)
            .maybeSingle();
        if (profile != null && profile['full_name'] != null) {
          creatorName = profile['full_name'] as String?;
          if (creatorName != null && creatorName.trim().isEmpty) creatorName = null;
        }
      }
      if (mounted) {
        setState(() {
          _sale = sale;
          _creatorName = creatorName;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
    }
  }

  static Future<Uint8List?> _fetchLogoBytes(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) return response.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<InvoiceA4Data?> _buildInvoiceA4DataFromSale(Sale sale) async {
    if (sale.saleItems == null || sale.saleItems!.isEmpty) return null;
    final store = await _storesRepo.getStore(sale.storeId);
    if (store == null || !mounted) return null;
    final logoBytes = store.logoUrl != null && store.logoUrl!.isNotEmpty
        ? await _fetchLogoBytes(store.logoUrl)
        : null;
    final depositAmount = sale.salePayments != null && sale.salePayments!.isNotEmpty
        ? sale.salePayments!.fold<double>(0, (s, p) => s + p.amount)
        : null;
    return InvoiceA4Data(
      store: store,
      saleNumber: sale.saleNumber,
      date: DateTime.tryParse(sale.createdAt) ?? DateTime.now(),
      items: sale.saleItems!
          .map((i) => InvoiceLineData(
                description: i.product?.name ?? '—',
                quantity: i.quantity,
                unit: i.product?.unit ?? 'pce',
                unitPrice: i.unitPrice,
                total: i.total,
              ))
          .toList(),
      subtotal: sale.subtotal,
      discount: sale.discount,
      tax: sale.tax,
      total: sale.total,
      customerName: sale.customer?.name,
      customerPhone: sale.customer?.phone,
      depositAmount: depositAmount,
      logoBytes: logoBytes,
    );
  }

  void _showPdfViewer(BuildContext context, InvoiceA4Data data) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            appBar: AppBar(
              title: const Text('Facture A4'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: 'Fermer',
                ),
              ],
            ),
            body: PdfPreview(
              build: (_) async {
                try {
                  final doc = await InvoiceA4PdfService.buildDocument(data);
                  return doc.save();
                } catch (e) {
                  if (ctx.mounted) AppErrorHandler.show(ctx, e, fallback: 'Impossible d\'afficher la facture PDF.');
                  return Uint8List(0);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reprintReceipt() async {
    final sale = _sale;
    if (sale == null || sale.saleItems == null) return;
    final store = await _storesRepo.getStore(sale.storeId);
    if (!mounted) return;
    final payments = sale.salePayments ?? [];
    final paymentMethodLabel = payments.isEmpty
        ? '—'
        : payments.map((p) => _paymentLabels[p.method] ?? p.method.name).toSet().join(', ');
    final date = DateTime.tryParse(sale.createdAt);
    final receipt = ReceiptTicketData(
      storeName: store?.name ?? sale.store?.name ?? '',
      storeLogoUrl: store?.logoUrl,
      storeAddress: store?.address,
      storePhone: store?.phone,
      saleNumber: sale.saleNumber,
      saleId: sale.id,
      cashierName: '—',
      items: sale.saleItems!
          .map((i) => ReceiptItemData(
                name: i.product?.name ?? '—',
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                total: i.total,
              ))
          .toList(),
      subtotal: sale.subtotal,
      discount: sale.discount,
      total: sale.total,
      paymentMethod: paymentMethodLabel,
      amountReceived: null,
      change: null,
      date: date ?? DateTime.now(),
      customerName: sale.customer?.name,
      customerPhone: sale.customer?.phone,
    );
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => ReceiptTicketDialog(
        data: receipt,
        onPrint: () {
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (mounted) AppToast.info(context, 'Impression en cours...');
          unawaited(
            ReceiptThermalPrintService.printReceipt(receipt)
                .then((_) {
                  if (mounted) {
                    AppToast.success(context, 'Ticket envoyé à l\'imprimante.');
                  }
                })
                .catchError((Object e) {
                  if (mounted) {
                    AppErrorHandler.show(
                      context,
                      e,
                      fallback: 'Impossible d\'imprimer le ticket.',
                    );
                  }
                }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saleNo = _sale?.saleNumber;
    final hasItems = _sale?.saleItems != null && (_sale!.saleItems!.isNotEmpty);
    final canShowInvoiceActions = _sale != null &&
        (_sale!.documentType == DocumentType.a4Invoice || _sale!.saleMode == SaleMode.invoicePos);

    return Dialog(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              saleNo != null ? 'Détail vente $saleNo' : 'Détail vente',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _sale != null ? 'Résumé + articles' : 'Chargement…',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasItems)
                        Chip(
                          label: Text(
                            _statusLabels[_sale!.status] ?? _sale!.status.name,
                            style: TextStyle(
                              color: _statusChipForeground(_sale!.status, theme.colorScheme),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: _statusChipBackground(_sale!.status, theme.colorScheme),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Body
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _sale == null
                            ? const Center(child: Text('Vente introuvable.'))
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Meta row
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (_sale!.store != null) Text(_sale!.store!.name, style: theme.textTheme.bodyMedium),
                                        if (_sale!.customer != null)
                                          Text(
                                            _sale!.customer!.name,
                                            style: theme.textTheme.bodyMedium,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Text(_formatDateTime(_sale!.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                      ],
                                    ),

                                    if (_sale!.salePayments != null && _sale!.salePayments!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      _InfoRow(
                                        icon: Icons.payment_rounded,
                                        label: 'Mode de paiement',
                                        value: _sale!.salePayments!
                                            .map((p) => _paymentLabels[p.method] ?? p.method.name)
                                            .toSet()
                                            .join(', '),
                                      ),
                                    ],

                                    if (_creatorName != null && _creatorName!.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      _InfoRow(
                                        icon: Icons.person_outline_rounded,
                                        label: 'Vente par',
                                        value: _creatorName!,
                                      ),
                                    ],

                                    const SizedBox(height: 16),

                                    if (_sale!.saleItems != null && _sale!.saleItems!.isNotEmpty) ...[
                                      _SectionHeader(icon: Icons.list_alt_rounded, title: 'Articles'),
                                      const SizedBox(height: 8),
                                      ..._sale!.saleItems!.map((item) => _ArticleTile(item: item)),
                                      const SizedBox(height: 12),
                                    ],

                                    if (_sale!.salePayments != null && _sale!.salePayments!.isNotEmpty) ...[
                                      _SectionHeader(icon: Icons.receipt_long_rounded, title: 'Paiements'),
                                      const SizedBox(height: 8),
                                      ..._sale!.salePayments!.map((p) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(_paymentLabels[p.method] ?? p.method.name, style: theme.textTheme.bodySmall),
                                                Text(formatCurrency(p.amount), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          )),
                                      const SizedBox(height: 12),
                                    ],

                                    const Divider(),

                                    if (_sale!.discount > 0)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Remise', style: theme.textTheme.bodyMedium),
                                            Text('-${formatCurrency(_sale!.discount)}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),

                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                          Text(formatCurrency(_sale!.total), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
              ),

              // Footer actions
              const SizedBox(height: 12),
              if (hasItems) ...[
                if (canShowInvoiceActions) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          final data = await _buildInvoiceA4DataFromSale(_sale!);
                          if (!mounted) return;
                          if (data == null) {
                            AppErrorHandler.show(context, Exception('Impossible de charger les données de la facture.'));
                            return;
                          }
                          _showPdfViewer(context, data);
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                        label: const Text('Voir le PDF'),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          final data = await _buildInvoiceA4DataFromSale(_sale!);
                          if (!mounted) return;
                          if (data == null) {
                            AppErrorHandler.show(context, Exception('Impossible de charger les données de la facture.'));
                            return;
                          }
                          AppToast.info(context, 'Impression en cours...');
                          unawaited(
                            InvoiceA4PdfService.printPdfDirect(data)
                                .then((_) {
                                  if (mounted) {
                                    AppToast.success(context, 'Impression envoyée à l\'imprimante.');
                                  }
                                })
                                .catchError((Object e) {
                                  if (mounted) {
                                    AppErrorHandler.show(
                                      context,
                                      e,
                                      fallback: 'Impossible de lancer l\'impression.',
                                    );
                                  }
                                }),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 20),
                        label: const Text('Réimprimer'),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          final data = await _buildInvoiceA4DataFromSale(_sale!);
                          if (!mounted) return;
                          if (data == null) {
                            AppErrorHandler.show(context, Exception('Impossible de charger les données de la facture.'));
                            return;
                          }
                          try {
                            final path = await InvoiceA4PdfService.downloadPdf(data);
                            if (mounted && path != null && path.isNotEmpty) AppToast.success(context, 'Facture enregistrée.');
                          } catch (e) {
                            if (mounted) AppErrorHandler.show(context, e, fallback: 'Impossible de télécharger la facture.');
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text('Télécharger'),
                      ),
                    ],
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _reprintReceipt,
                    icon: const Icon(Icons.receipt_long_rounded, size: 20),
                    label: const Text('Réimprimer le reçu'),
                  ),
              ],

              const SizedBox(height: 10),
              TextButton(onPressed: widget.onClose, child: const Text('Fermer')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.inventory_2, size: 20, color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product?.name ?? '—',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} × ${formatCurrency(item.unitPrice)}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatCurrency(item.total),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

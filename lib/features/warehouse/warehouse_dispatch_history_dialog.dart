import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:provider/provider.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/errors/app_error_handler.dart'
    show AppErrorHandler, ErrorMapper;
import '../../data/models/store.dart';
import '../../core/utils/app_toast.dart';
import '../../data/repositories/stores_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/offline_providers.dart';
import '../../shared/utils/format_currency.dart';
import '../pos/services/invoice_a4_pdf_service.dart';
import 'warehouse_ui_helpers.dart';

enum _DispatchDialogInitialAction { none, previewA4, printA4 }

/// Liste des bons / factures de sortie dépôt — **offline-first** (Drift) + mise à jour au sync.
class WarehouseDispatchHistoryPanel extends ConsumerStatefulWidget {
  const WarehouseDispatchHistoryPanel({
    super.key,
    required this.companyId,
    required this.warehouseRepo,
  });

  final String companyId;
  final WarehouseRepository warehouseRepo;

  @override
  WarehouseDispatchHistoryPanelState createState() =>
      WarehouseDispatchHistoryPanelState();
}

class WarehouseDispatchHistoryPanelState
    extends ConsumerState<WarehouseDispatchHistoryPanel> {
  static const int _pageSize = 20;
  int _page = 0;
  final StoresRepository _storesRepo = StoresRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final Map<String, double> _totalsByInvoiceId = <String, double>{};
  final Set<String> _loadingTotals = <String>{};
  final Set<String> _printingIds = <String>{};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _paidAmountFromNotes(String? notes, double total) {
    if (notes == null || notes.trim().isEmpty) return 0;
    final text = notes.trim();
    if (!text.startsWith('__PAYMENT_INFO__:') &&
        !text.startsWith('__PAYMENT_INFO__::')) {
      return 0;
    }
    final payload = text
        .replaceFirst(RegExp(r'^__PAYMENT_INFO__::?'), '')
        .trim();
    if (payload.isEmpty) return 0;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return 0;
      final mode = (decoded['mode'] ?? '').toString().trim().toLowerCase();
      final paidRaw = decoded['paid_amount'];
      final paid = paidRaw is num ? paidRaw.toDouble() : 0.0;
      if (mode == 'cash') return paid.clamp(0, total);
      if (mode == 'mobile_money' || mode == 'card') return total;
      return 0;
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'warehouse_dispatch_history',
        logContext: const {'phase': 'parse_paid_amount_from_notes'},
      );
      return 0;
    }
  }

  void _ensureTotalsLoaded(List<WarehouseDispatchInvoiceSummary> rows) {
    for (final r in rows) {
      if (_totalsByInvoiceId.containsKey(r.id) ||
          _loadingTotals.contains(r.id)) {
        continue;
      }
      _loadingTotals.add(r.id);
      widget.warehouseRepo
          .getDispatchInvoiceDetails(r.id)
          .then((d) {
            if (!mounted) return;
            setState(() => _totalsByInvoiceId[r.id] = d.subtotal);
          })
          .catchError((e, st) {
            AppErrorHandler.logWithContext(
              e,
              stackTrace: st,
              logSource: 'warehouse_dispatch_history',
              logContext: {'phase': 'load_dispatch_total', 'invoice_id': r.id},
            );
          })
          .whenComplete(() {
            _loadingTotals.remove(r.id);
          });
    }
  }

  /// Pull-to-refresh / app bar : synchronise Supabase → Drift.
  Future<void> refresh() async {
    final uid = context.read<AuthProvider>().user?.id;
    final companyId = widget.companyId;
    if (companyId.isEmpty) return;
    if (uid == null) {
      if (!context.mounted) return;
      AppToast.info(context, 'Connectez-vous pour synchroniser les bons.');
      return;
    }
    try {
      await ref
          .read(syncServiceV2Provider)
          .sync(userId: uid, companyId: companyId, storeId: null);
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_history_sync', e, st);
      AppErrorHandler.log(e, st);
      if (ErrorMapper.isNetworkError(e)) {
        if (!mounted) return;
        if (!context.mounted) return;
        AppToast.info(
          context,
          'Hors ligne : la liste affichée correspond au dernier téléchargement.',
        );
        return;
      }
      if (!mounted) return;
      if (!context.mounted) return;
      AppErrorHandler.show(context, e);
    }
  }

  Future<void> _confirmAndVoidInvoice(
    BuildContext context,
    WarehouseDispatchInvoiceSummary r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce bon ?'),
        content: Text(
          'Le stock au dépôt sera réintégré pour « ${r.documentNumber} ». '
          'Le bon sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler le bon'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (ConnectivityService.instance.isOnline) {
        await widget.warehouseRepo.voidDispatchInvoice(
          companyId: widget.companyId,
          invoiceId: r.id,
        );
      } else {
        await ref
            .read(appDatabaseProvider)
            .enqueuePendingAction(
              'warehouse_dispatch_void',
              jsonEncode({'company_id': widget.companyId, 'invoice_id': r.id}),
            );
      }
      if (!mounted) return;
      try {
        await ref
            .read(appDatabaseProvider)
            .deleteLocalWarehouseDispatchInvoice(r.id);
      } catch (e, st) {
        WarehouseUi.logOp('dispatch_void_local_cache', e, st);
        AppErrorHandler.log(e, st);
      }
      if (!context.mounted) return;
      AppToast.success(
        context,
        ConnectivityService.instance.isOnline
            ? 'Bon annulé. Stock dépôt mis à jour.'
            : 'Annulation enregistrée hors ligne. Synchronisation à la reconnexion.',
      );
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_void', e, st);
      AppErrorHandler.log(e, st);
      if (context.mounted) AppErrorHandler.show(context, e);
    }
  }

  List<InvoicePaymentLineData> _paymentLinesFromDispatchNotes(
    String? notes, {
    required double total,
  }) {
    if (notes == null || notes.trim().isEmpty) return const [];
    final text = notes.trim();
    if (!text.startsWith('__PAYMENT_INFO__:') &&
        !text.startsWith('__PAYMENT_INFO__::')) {
      return const [];
    }
    final payload = text
        .replaceFirst(RegExp(r'^__PAYMENT_INFO__::?'), '')
        .trim();
    if (payload.isEmpty) return const [];
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return const [];
      final mode = (decoded['mode'] ?? '').toString().trim().toLowerCase();
      final paidRaw = decoded['paid_amount'];
      final paid = paidRaw is num ? paidRaw.toDouble() : 0.0;
      final provider = (decoded['mobile_provider'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      switch (mode) {
        case 'cash':
          return [
            InvoicePaymentLineData(
              label: 'Espèces',
              amount: paid.clamp(0, total).toDouble(),
              isImmediateEncaisse: true,
            ),
          ];
        case 'mobile_money':
          final providerLabel = switch (provider) {
            'orange_money' => 'Orange Money',
            'moov_money' => 'Moov Money',
            'wave' => 'Wave',
            _ => '',
          };
          return [
            InvoicePaymentLineData(
              label: providerLabel.isEmpty
                  ? 'Mobile money'
                  : 'Mobile money — $providerLabel',
              amount: total,
              isImmediateEncaisse: true,
            ),
          ];
        case 'card':
          return [
            InvoicePaymentLineData(
              label: 'Carte',
              amount: total,
              isImmediateEncaisse: true,
            ),
          ];
        case 'credit':
          return const [
            InvoicePaymentLineData(
              label: 'À crédit',
              amount: 0,
              isImmediateEncaisse: false,
            ),
          ];
        default:
          return const [];
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'warehouse_dispatch_history',
        logContext: const {'phase': 'build_payment_lines_from_notes'},
      );
      return const [];
    }
  }

  Future<Uint8List?> _fetchLogoBytesFromUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'warehouse_dispatch_history',
        logContext: {'phase': 'fetch_logo_bytes', 'has_url': true},
      );
    }
    return null;
  }

  Future<InvoiceA4Data?> _prepareA4DataForPrint(
    WarehouseDispatchInvoiceSummary row,
  ) async {
    final d = await widget.warehouseRepo.getDispatchInvoiceDetails(row.id);
    var stores = ref.read(storesStreamProvider(d.companyId)).valueOrNull ?? [];
    if (stores.isEmpty) {
      stores = await _storesRepo.getStoresByCompany(d.companyId);
    }
    if (stores.isEmpty) return null;
    final primaryList = stores.where((s) => s.isPrimary).toList();
    var store = primaryList.isNotEmpty ? primaryList.first : stores.first;
    store = await InvoiceA4PdfService.resolveStoreForInvoice(store);
    Uint8List? logoBytes;
    if (store.logoUrl != null && store.logoUrl!.trim().isNotEmpty) {
      logoBytes = await _fetchLogoBytesFromUrl(store.logoUrl);
      if (logoBytes != null && logoBytes.isNotEmpty) {
        await InvoiceA4PdfService.cacheLogoBytes(store.id, logoBytes);
      }
    }
    logoBytes ??= await InvoiceA4PdfService.loadCachedLogoBytes(store.id);
    final date = DateTime.tryParse(d.createdAt) ?? DateTime.now();
    return InvoiceA4Data(
      store: store,
      logoBytes: logoBytes,
      saleNumber: d.documentNumber,
      date: date,
      items: d.lines
          .map(
            (l) => InvoiceLineData(
              description:
                  '${l.productName}${l.productSku != null && l.productSku!.isNotEmpty ? ' (${l.productSku})' : ''}',
              quantity: l.quantity,
              unit: l.productUnit,
              unitPrice: l.unitPrice,
              total: l.total,
            ),
          )
          .toList(),
      subtotal: d.subtotal,
      discount: 0,
      tax: 0,
      total: d.subtotal,
      paymentLines: _paymentLinesFromDispatchNotes(d.notes, total: d.subtotal),
      customerName: d.customerName,
      customerPhone: d.customerPhone,
    );
  }

  void _startDirectPrint(WarehouseDispatchInvoiceSummary row) {
    if (_printingIds.contains(row.id)) return;
    setState(() => _printingIds.add(row.id));
    AppToast.info(context, 'Préparation de l’impression…');
    unawaited(() async {
      try {
        final data = await _prepareA4DataForPrint(row);
        if (data == null) {
          if (mounted) {
            AppToast.info(
              context,
              'Aucune boutique pour l’en-tête. Synchronisez ou vérifiez les boutiques.',
            );
          }
          return;
        }
        final bytes = await InvoiceA4PdfService.generatePdf(data);
        if (!mounted) return;
        AppToast.info(context, 'Envoi à l’imprimante…');
        final result = await InvoiceA4PdfService.printPdfBytesDirect(
          bytes,
          data.saleNumber,
          userId: context.read<AuthProvider>().user?.id,
          companyId: widget.companyId,
        );
        if (!mounted) return;
        if (result.usedSystemDialog) {
          AppToast.success(
            context,
            'Boîte d’impression système ouverte (fallback).',
          );
        } else if (!result.usedPreferredPrinter &&
            result.preferredPrinterName != null &&
            result.preferredPrinterName!.trim().isNotEmpty) {
          AppToast.success(
            context,
            'Imprimante préférée indisponible: impression envoyée à ${result.selectedPrinterName ?? 'une imprimante disponible'}.',
          );
        } else {
          AppToast.success(context, 'Impression A4 lancée.');
        }
      } catch (e, st) {
        WarehouseUi.logOp('dispatch_history_direct_print', e, st);
        if (mounted) AppErrorHandler.show(context, e);
      } finally {
        if (mounted) {
          setState(() => _printingIds.remove(row.id));
        }
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(warehouseDispatchInvoicesStreamProvider(widget.companyId), (
      prev,
      next,
    ) {
      if (next.hasError && prev?.hasError != true) {
        final e = next.error!;
        final st = next.stackTrace;
        WarehouseUi.logOp('dispatch_history_stream', e, st ?? StackTrace.empty);
        AppErrorHandler.log(e, st);
      }
    });

    final theme = Theme.of(context);
    final async = ref.watch(
      warehouseDispatchInvoicesStreamProvider(widget.companyId),
    );
    final rows = async.valueOrNull ?? [];
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? rows
        : rows.where((r) {
            final doc = r.documentNumber.toLowerCase();
            final customer = (r.customerName ?? '').toLowerCase();
            final created = r.createdAt.toLowerCase();
            return doc.contains(q) ||
                customer.contains(q) ||
                created.contains(q);
          }).toList();
    final totalPages = filtered.isEmpty
        ? 1
        : ((filtered.length - 1) ~/ _pageSize) + 1;
    final clampedPage = _page.clamp(0, totalPages - 1);
    final start = clampedPage * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pagedRows = filtered.sublist(start, end);
    _ensureTotalsLoaded(pagedRows);
    final loading = async.isLoading && rows.isEmpty && async.error == null;
    final err = async.error;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (err != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: WarehouseInlineErrorCard(
              title: 'Liste des bons indisponible',
              message: ErrorMapper.toMessage(err),
              icon: ErrorMapper.isNetworkError(err)
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              onRetry: () => refresh(),
            ),
          )
        else if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Aucun bon de sortie enregistré.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 8),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Rechercher n° bon, client, date',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (v) => setState(() {
                            _query = v;
                            _page = 0;
                          }),
                        ),
                        if (filtered.length != rows.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 2),
                            child: Text(
                              '${filtered.length} bon(s) sur ${rows.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowColor: WidgetStateProperty.all(
                          theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        columns: const [
                          DataColumn(label: Text('N° Bon')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Client')),
                          DataColumn(label: Text('Somme'), numeric: true),
                          DataColumn(
                            label: Text('Déjà encaissé'),
                            numeric: true,
                          ),
                          DataColumn(label: Text('Reste'), numeric: true),
                          DataColumn(label: Text('Action')),
                          DataColumn(label: Text('Annuler')),
                        ],
                        rows: pagedRows.map((r) {
                          final dt = DateTime.tryParse(r.createdAt);
                          final date = dt == null
                              ? '—'
                              : DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                  'fr_FR',
                                ).format(dt.toLocal());
                          final total = _totalsByInvoiceId[r.id];
                          final paid = total == null
                              ? 0.0
                              : _paidAmountFromNotes(r.notes, total);
                          final paidClamped = total == null
                              ? paid
                              : paid.clamp(0, total);
                          final remaining = total == null
                              ? null
                              : (total - paidClamped).clamp(0, double.infinity);
                          return DataRow(
                            cells: [
                              DataCell(Text(r.documentNumber)),
                              DataCell(Text(date)),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    r.customerName ?? 'Sans client',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  total == null ? '…' : formatCurrency(total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  formatCurrency(paidClamped),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  remaining == null
                                      ? '…'
                                      : formatCurrency(remaining),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF97316),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () async {
                                        final removed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) =>
                                              _WarehouseDispatchDetailDialog(
                                                invoiceId: r.id,
                                                warehouseRepo:
                                                    widget.warehouseRepo,
                                                initialAction:
                                                    _DispatchDialogInitialAction
                                                        .none,
                                              ),
                                        );
                                        if (removed == true && mounted) {
                                          await refresh();
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                      child: const Text(
                                        'Voir',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _printingIds.contains(r.id)
                                          ? null
                                          : () => _startDirectPrint(r),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                      child: Text(
                                        _printingIds.contains(r.id)
                                            ? 'Impression…'
                                            : 'Imprimer direct',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                FilledButton.tonal(
                                  onPressed: () =>
                                      _confirmAndVoidInvoice(context, r),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    foregroundColor: theme.colorScheme.error,
                                  ),
                                  child: const Text(
                                    'Annuler',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _DispatchPager(
                      page: clampedPage,
                      totalPages: totalPages,
                      start: start,
                      end: end,
                      totalItems: filtered.length,
                      onPrev: clampedPage > 0
                          ? () => setState(() => _page = clampedPage - 1)
                          : null,
                      onNext: clampedPage < totalPages - 1
                          ? () => setState(() => _page = clampedPage + 1)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DispatchPager extends StatelessWidget {
  const _DispatchPager({
    required this.page,
    required this.totalPages,
    required this.start,
    required this.end,
    required this.totalItems,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int start;
  final int end;
  final int totalItems;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    final startLabel = totalItems == 0 ? 0 : start + 1;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isNarrow)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$startLabel – $end sur $totalItems',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            IconButton.filled(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: onPrev != null
                    ? theme.colorScheme.primary
                    : null,
                foregroundColor: onPrev != null
                    ? theme.colorScheme.onPrimary
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Page ${page + 1} / $totalPages',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: onNext != null
                    ? theme.colorScheme.primary
                    : null,
                foregroundColor: onNext != null
                    ? theme.colorScheme.onPrimary
                    : null,
              ),
            ),
            if (isNarrow) ...[
              const SizedBox(width: 12),
              Text(
                '$startLabel – $end / $totalItems',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WarehouseDispatchDetailDialog extends ConsumerStatefulWidget {
  const _WarehouseDispatchDetailDialog({
    required this.invoiceId,
    required this.warehouseRepo,
    this.initialAction = _DispatchDialogInitialAction.none,
  });

  final String invoiceId;
  final WarehouseRepository warehouseRepo;
  final _DispatchDialogInitialAction initialAction;

  @override
  ConsumerState<_WarehouseDispatchDetailDialog> createState() =>
      _WarehouseDispatchDetailDialogState();
}

class _WarehouseDispatchDetailDialogState
    extends ConsumerState<_WarehouseDispatchDetailDialog> {
  final StoresRepository _storesRepo = StoresRepository();
  WarehouseDispatchInvoiceDetails? _detail;
  bool _loading = true;

  /// Génération du PDF (lourd) — pas l’envoi au spooler d’impression.
  bool _generatingPdf = false;
  bool _voiding = false;
  bool _initialActionDone = false;
  String? _error;

  String? _readableNote(String? raw, {required double total}) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    if (!text.startsWith('__PAYMENT_INFO__:') &&
        !text.startsWith('__PAYMENT_INFO__::')) {
      return text;
    }
    final payload = text
        .replaceFirst(RegExp(r'^__PAYMENT_INFO__::?'), '')
        .trim();
    if (payload.isEmpty) return 'Paiement enregistré.';
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return 'Paiement enregistré.';
      final modeRaw = (decoded['mode'] ?? '').toString().trim().toLowerCase();
      final paidRaw = decoded['paid_amount'];
      final paid = paidRaw is num ? paidRaw.toDouble() : 0.0;
      final provider = (decoded['mobile_provider'] ?? '').toString().trim();
      final mode = switch (modeRaw) {
        'credit' => 'A credit',
        'cash' => 'Especes',
        'mobile_money' => 'Mobile money',
        'card' => 'Carte',
        'transfer' => 'Virement',
        'other' => 'Autre',
        _ => 'Non precise',
      };
      final remains = (total - paid).clamp(0, double.infinity);
      final parts = <String>[
        'Paiement: $mode',
        'Paye: ${formatCurrency(paid)}',
      ];
      if (modeRaw == 'credit') {
        parts.add('Reste: ${formatCurrency(remains)}');
      }
      if (provider.isNotEmpty) {
        parts.add('Operateur: $provider');
      }
      return parts.join(' · ');
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'warehouse_dispatch_history',
        logContext: const {'phase': 'dispatch_payment_note_summary'},
      );
      return 'Paiement enregistre.';
    }
  }

  ({String mode, double paid, double remaining, String status}) _paymentSummary(
    String? notes, {
    required double total,
  }) {
    if (notes == null || notes.trim().isEmpty) {
      return (
        mode: 'Non renseigné',
        paid: 0.0,
        remaining: total,
        status: 'Statut : paiement non renseigné',
      );
    }
    final text = notes.trim();
    if (!text.startsWith('__PAYMENT_INFO__:') &&
        !text.startsWith('__PAYMENT_INFO__::')) {
      return (
        mode: 'Non renseigné',
        paid: 0.0,
        remaining: total,
        status: 'Statut : paiement non renseigné',
      );
    }
    try {
      final payload = text
          .replaceFirst(RegExp(r'^__PAYMENT_INFO__::?'), '')
          .trim();
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return (
          mode: 'Non renseigné',
          paid: 0.0,
          remaining: total,
          status: 'Statut : paiement non renseigné',
        );
      }
      final modeRaw = (decoded['mode'] ?? '').toString().trim().toLowerCase();
      final paidRaw = decoded['paid_amount'];
      final paidInput = paidRaw is num ? paidRaw.toDouble() : 0.0;
      final paid = switch (modeRaw) {
        'cash' => paidInput.clamp(0, total).toDouble(),
        'mobile_money' => total,
        'card' => total,
        'credit' => 0.0,
        _ => paidInput.clamp(0, total).toDouble(),
      };
      final remaining = (total - paid).clamp(0, double.infinity).toDouble();
      final mode = switch (modeRaw) {
        'cash' => 'Espèces',
        'mobile_money' => 'Mobile money',
        'card' => 'Carte',
        'credit' => 'À crédit',
        _ => 'Non précisé',
      };
      final status = remaining < 0.01
          ? 'Statut : facture intégralement réglée'
          : paid < 0.01
          ? 'Statut : paiement à crédit - solde à régler'
          : 'Statut : règlement partiel - solde à régler';
      return (mode: mode, paid: paid, remaining: remaining, status: status);
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'warehouse_dispatch_history',
        logContext: const {'phase': 'payment_summary_from_notes'},
      );
      return (
        mode: 'Non renseigné',
        paid: 0.0,
        remaining: total,
        status: 'Statut : paiement non renseigné',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.warehouseRepo.getDispatchInvoiceDetails(
        widget.invoiceId,
      );
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
      if (!_initialActionDone &&
          widget.initialAction != _DispatchDialogInitialAction.none) {
        _initialActionDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          if (widget.initialAction == _DispatchDialogInitialAction.previewA4) {
            await _previewA4();
          } else if (widget.initialAction ==
              _DispatchDialogInitialAction.printA4) {
            await _printA4Direct();
          }
        });
      }
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_history_detail', e, st);
      if (!mounted) return;
      setState(() {
        _error = ErrorMapper.toMessage(e);
        _loading = false;
      });
    }
  }

  /// Octets du logo depuis l’URL Supabase/storage (même logique que la caisse).
  Future<Uint8List?> _fetchLogoBytesFromUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_history_logo_fetch', e, st);
    }
    return null;
  }

  /// Logo facture A4 = celui de la **boutique principale** : URL si dispo, sinon cache disque.
  Future<Uint8List?> _logoBytesForPrimaryStore(Store store) async {
    if (store.logoUrl != null && store.logoUrl!.trim().isNotEmpty) {
      final bytes = await _fetchLogoBytesFromUrl(store.logoUrl);
      if (bytes != null && bytes.isNotEmpty) {
        await InvoiceA4PdfService.cacheLogoBytes(store.id, bytes);
        return bytes;
      }
    }
    return InvoiceA4PdfService.loadCachedLogoBytes(store.id);
  }

  /// Boutiques d’abord depuis Drift (hors ligne), puis API si besoin.
  /// En-tête / logo : toujours la **boutique principale** (`is_primary`).
  Future<InvoiceA4Data?> _prepareA4Data() async {
    final d = _detail;
    if (d == null) return null;
    var stores = ref.read(storesStreamProvider(d.companyId)).valueOrNull ?? [];
    if (stores.isEmpty) {
      try {
        final local = await ref
            .read(appDatabaseProvider)
            .getLocalStores(d.companyId);
        stores = local
            .map(
              (s) => Store(
                id: s.id,
                companyId: s.companyId,
                name: s.name,
                code: s.code,
                address: s.address,
                logoUrl: s.logoUrl,
                phone: s.phone,
                email: s.email,
                description: s.description,
                isActive: s.isActive,
                isPrimary: s.isPrimary,
                posDiscountEnabled: s.posDiscountEnabled,
                createdAt: s.updatedAt,
                currency: s.currency,
                primaryColor: s.primaryColor,
                secondaryColor: s.secondaryColor,
                invoicePrefix: s.invoicePrefix,
                footerText: s.footerText,
                legalInfo: s.legalInfo,
                signatureUrl: s.signatureUrl,
                stampUrl: s.stampUrl,
                paymentTerms: s.paymentTerms,
                taxLabel: s.taxLabel,
                taxNumber: s.taxNumber,
                city: s.city,
                country: s.country,
                commercialName: s.commercialName,
                slogan: s.slogan,
                activity: s.activity,
                mobileMoney: s.mobileMoney,
                invoiceShortTitle: s.invoiceShortTitle,
                invoiceSignerTitle: s.invoiceSignerTitle,
                invoiceSignerName: s.invoiceSignerName,
                invoiceTemplate: s.invoiceTemplate,
              ),
            )
            .toList();
      } catch (e, st) {
        WarehouseUi.logOp('dispatch_history_local_stores', e, st);
      }
    }
    if (stores.isEmpty) {
      try {
        stores = await _storesRepo.getStoresByCompany(d.companyId);
      } catch (e, st) {
        WarehouseUi.logOp('dispatch_history_stores', e, st);
      }
    }
    if (stores.isEmpty) return null;
    final primaryList = stores.where((s) => s.isPrimary).toList();
    var store = primaryList.isNotEmpty ? primaryList.first : stores.first;
    store = await InvoiceA4PdfService.resolveStoreForInvoice(store);
    final logoBytes = await _logoBytesForPrimaryStore(store);
    final date = DateTime.tryParse(d.createdAt) ?? DateTime.now();
    final paymentLines = _paymentLinesFromDispatchNotes(
      d.notes,
      total: d.subtotal,
    );
    return InvoiceA4Data(
      store: store,
      logoBytes: logoBytes,
      saleNumber: d.documentNumber,
      date: date,
      items: d.lines
          .map(
            (l) => InvoiceLineData(
              description:
                  '${l.productName}${l.productSku != null && l.productSku!.isNotEmpty ? ' (${l.productSku})' : ''}',
              quantity: l.quantity,
              unit: l.productUnit,
              unitPrice: l.unitPrice,
              total: l.total,
            ),
          )
          .toList(),
      subtotal: d.subtotal,
      discount: 0,
      tax: 0,
      total: d.subtotal,
      paymentLines: paymentLines,
      customerName: d.customerName,
      customerPhone: d.customerPhone,
    );
  }

  List<InvoicePaymentLineData> _paymentLinesFromDispatchNotes(
    String? notes, {
    required double total,
  }) {
    if (notes == null || notes.trim().isEmpty) return const [];
    final text = notes.trim();
    if (!text.startsWith('__PAYMENT_INFO__:') &&
        !text.startsWith('__PAYMENT_INFO__::')) {
      return const [];
    }
    final payload = text
        .replaceFirst(RegExp(r'^__PAYMENT_INFO__::?'), '')
        .trim();
    if (payload.isEmpty) return const [];
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return const [];
      final mode = (decoded['mode'] ?? '').toString().trim().toLowerCase();
      final paidRaw = decoded['paid_amount'];
      final paid = paidRaw is num ? paidRaw.toDouble() : 0.0;
      final provider = (decoded['mobile_provider'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      switch (mode) {
        case 'cash':
          return [
            InvoicePaymentLineData(
              label: 'Espèces',
              amount: paid.clamp(0, total),
              isImmediateEncaisse: true,
            ),
          ];
        case 'mobile_money':
          final providerLabel = switch (provider) {
            'orange_money' => 'Orange Money',
            'moov_money' => 'Moov Money',
            'wave' => 'Wave',
            _ => '',
          };
          return [
            InvoicePaymentLineData(
              label: providerLabel.isEmpty
                  ? 'Mobile money'
                  : 'Mobile money — $providerLabel',
              amount: total,
              isImmediateEncaisse: true,
            ),
          ];
        case 'card':
          return [
            InvoicePaymentLineData(
              label: 'Carte',
              amount: total,
              isImmediateEncaisse: true,
            ),
          ];
        case 'credit':
          return const [
            InvoicePaymentLineData(
              label: 'À crédit',
              amount: 0,
              isImmediateEncaisse: false,
            ),
          ];
        default:
          return const [];
      }
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'warehouse_dispatch_history',
        logContext: const {'phase': 'build_payment_lines_for_print'},
      );
      return const [];
    }
  }

  /// Aperçu **dans l’app** (PdfPreview) — pas `Printing.layoutPdf` qui ouvre la config Windows.
  void _showDispatchA4PdfPreview(BuildContext context, InvoiceA4Data data) {
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            appBar: AppBar(
              title: const Text('Aperçu A4'),
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
                } catch (e, st) {
                  WarehouseUi.logOp('dispatch_history_pdf_build', e, st);
                  if (ctx.mounted) {
                    AppErrorHandler.show(
                      ctx,
                      e,
                      fallback: 'Impossible d\'afficher le PDF.',
                    );
                  }
                  return Uint8List(0);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _previewA4() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final data = await _prepareA4Data();
      if (data == null) {
        if (mounted) {
          AppToast.info(
            context,
            'Aucune boutique pour l’en-tête. Synchronisez ou vérifiez les boutiques.',
          );
        }
        return;
      }
      if (!mounted) return;
      _showDispatchA4PdfPreview(context, data);
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_history_preview_a4', e, st);
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _voidInvoice() async {
    final d = _detail;
    if (d == null || _voiding) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce bon ?'),
        content: Text(
          'Le stock au dépôt sera réintégré pour « ${d.documentNumber} ». '
          'Le bon sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler le bon'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _voiding = true);
    try {
      if (ConnectivityService.instance.isOnline) {
        await widget.warehouseRepo.voidDispatchInvoice(
          companyId: d.companyId,
          invoiceId: d.id,
        );
      } else {
        await ref
            .read(appDatabaseProvider)
            .enqueuePendingAction(
              'warehouse_dispatch_void',
              jsonEncode({'company_id': d.companyId, 'invoice_id': d.id}),
            );
        await ref
            .read(appDatabaseProvider)
            .deleteLocalWarehouseDispatchInvoice(d.id);
      }
      if (!mounted) return;
      AppToast.success(
        context,
        ConnectivityService.instance.isOnline
            ? 'Bon annulé. Stock dépôt mis à jour.'
            : 'Annulation enregistrée hors ligne. Synchronisation à la reconnexion.',
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_void_detail', e, st);
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _voiding = false);
    }
  }

  Future<void> _printA4Direct() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final data = await _prepareA4Data();
      if (data == null) {
        if (mounted) {
          AppToast.info(
            context,
            'Aucune boutique pour l’en-tête. Synchronisez ou vérifiez les boutiques.',
          );
        }
        return;
      }
      final bytes = await InvoiceA4PdfService.generatePdf(data);
      if (!mounted) return;
      final docNumber = data.saleNumber;
      AppToast.info(context, 'Envoi à l’imprimante…');
      unawaited(() async {
        try {
          await InvoiceA4PdfService.printPdfBytesDirect(
            bytes,
            docNumber,
            userId: context.read<AuthProvider>().user?.id,
            companyId: _detail?.companyId,
          );
          if (mounted) AppToast.success(context, 'Impression A4 lancée.');
        } catch (e, st) {
          WarehouseUi.logOp('dispatch_history_print_spool', e, st);
          if (mounted) AppErrorHandler.show(context, e);
        }
      }());
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_history_print_a4', e, st);
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _detail;
    final maxH = MediaQuery.sizeOf(context).height * 0.82;
    return AlertDialog(
      title: Text(d?.documentNumber ?? 'Bon / facture dépôt'),
      content: SizedBox(
        width: 620,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : d == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${d.customerName ?? 'Sans client'}'
                        '${d.customerPhone != null && d.customerPhone!.isNotEmpty ? ' · ${d.customerPhone}' : ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_readableNote(d.notes, total: d.subtotal) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _readableNote(d.notes, total: d.subtotal)!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 12),
                      ...d.lines.map(
                        (l) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${l.quantity} ${l.productUnit} × ${formatCurrency(l.unitPrice)}',
                          ),
                          trailing: Text(
                            formatCurrency(l.total),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            formatCurrency(d.subtotal),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (_) {
                          final payment = _paymentSummary(
                            d.notes,
                            total: d.subtotal,
                          );
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Règlement',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _kvLine('Mode', payment.mode, theme),
                                _kvLine(
                                  'Total encaissé',
                                  formatCurrency(payment.paid),
                                  theme,
                                ),
                                _kvLine(
                                  'Reste à payer',
                                  formatCurrency(payment.remaining),
                                  theme,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  payment.status,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        TextButton(
          onPressed: _loading || _error != null || _detail == null || _voiding
              ? null
              : _voidInvoice,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: _voiding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Annuler ce bon'),
        ),
        OutlinedButton.icon(
          onPressed: _loading || _error != null || _generatingPdf || _voiding
              ? null
              : _previewA4,
          icon: _generatingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Aperçu A4'),
        ),
        FilledButton.icon(
          onPressed: _loading || _error != null || _generatingPdf || _voiding
              ? null
              : _printA4Direct,
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('Imprimer A4'),
        ),
      ],
    );
  }

  Widget _kvLine(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

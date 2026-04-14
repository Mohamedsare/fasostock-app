import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:provider/provider.dart';

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
      await ref.read(syncServiceV2Provider).sync(
            userId: uid,
            companyId: companyId,
            storeId: null,
          );
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
      await widget.warehouseRepo.voidDispatchInvoice(
        companyId: widget.companyId,
        invoiceId: r.id,
      );
      if (!mounted) return;
      try {
        await ref.read(appDatabaseProvider).deleteLocalWarehouseDispatchInvoice(r.id);
      } catch (e, st) {
        WarehouseUi.logOp('dispatch_void_local_cache', e, st);
        AppErrorHandler.log(e, st);
      }
      if (!context.mounted) return;
      AppToast.success(context, 'Bon annulé. Stock dépôt mis à jour.');
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_void', e, st);
      AppErrorHandler.log(e, st);
      if (context.mounted) AppErrorHandler.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(warehouseDispatchInvoicesStreamProvider(widget.companyId), (prev, next) {
      if (next.hasError && prev?.hasError != true) {
        final e = next.error!;
        final st = next.stackTrace;
        WarehouseUi.logOp('dispatch_history_stream', e, st ?? StackTrace.empty);
        AppErrorHandler.log(e, st);
      }
    });

    final theme = Theme.of(context);
    final async = ref.watch(warehouseDispatchInvoicesStreamProvider(widget.companyId));
    final rows = async.valueOrNull ?? [];
    final totalPages = rows.isEmpty ? 1 : ((rows.length - 1) ~/ _pageSize) + 1;
    final clampedPage = _page.clamp(0, totalPages - 1);
    final start = clampedPage * _pageSize;
    final end = (start + _pageSize).clamp(0, rows.length);
    final pagedRows = rows.sublist(start, end);
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
              icon: ErrorMapper.isNetworkError(err) ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
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
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final r = pagedRows[i];
                      final dt = DateTime.tryParse(r.createdAt);
                      final date = dt == null
                          ? '—'
                          : DateFormat(
                              'dd/MM/yyyy HH:mm',
                              'fr_FR',
                            ).format(dt.toLocal());
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i < pagedRows.length - 1 ? 6 : 0,
                        ),
                        child: ListTile(
                          tileColor: theme.colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          title: Text(
                            r.documentNumber,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${r.customerName ?? 'Sans client'} · $date',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Annuler ce bon',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: theme.colorScheme.error,
                                ),
                                onPressed: () =>
                                    _confirmAndVoidInvoice(context, r),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                          onTap: () async {
                            final removed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => _WarehouseDispatchDetailDialog(
                                invoiceId: r.id,
                                warehouseRepo: widget.warehouseRepo,
                              ),
                            );
                            if (removed == true && mounted) await refresh();
                          },
                        ),
                      );
                    },
                    childCount: pagedRows.length,
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
                      totalItems: rows.length,
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
                backgroundColor: onPrev != null ? theme.colorScheme.primary : null,
                foregroundColor: onPrev != null ? theme.colorScheme.onPrimary : null,
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
                backgroundColor: onNext != null ? theme.colorScheme.primary : null,
                foregroundColor: onNext != null ? theme.colorScheme.onPrimary : null,
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
  });

  final String invoiceId;
  final WarehouseRepository warehouseRepo;

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
  String? _error;

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
      customerName: d.customerName,
      customerPhone: d.customerPhone,
    );
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
      await widget.warehouseRepo.voidDispatchInvoice(
        companyId: d.companyId,
        invoiceId: d.id,
      );
      if (!mounted) return;
      AppToast.success(context, 'Bon annulé. Stock dépôt mis à jour.');
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
                              if (d.notes != null && d.notes!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    d.notes!,
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
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
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
}

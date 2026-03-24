import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/store.dart';
import '../../../data/models/supplier.dart';
import '../../../data/repositories/purchases_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../shared/utils/format_currency.dart';
import 'widgets/create_purchase_dialog.dart';

const int _purchasesPageSize = 20;

const _statusLabels = {
  PurchaseStatus.draft: 'Brouillon',
  PurchaseStatus.confirmed: 'Confirmé',
  PurchaseStatus.partially_received: 'Part. reçu',
  PurchaseStatus.received: 'Reçu',
  PurchaseStatus.cancelled: 'Annulé',
};

/// Page Achats — lecture Drift, sync en arrière-plan. Owner (ou droits) : voir, modifier, annuler, supprimer.
class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  String? _filterStoreId;
  String? _filterSupplierId;
  PurchaseStatus? _filterStatus;
  bool _syncTriggeredOnce = false;
  int _currentPurchasesPage = 0;
  String _lastPurchasesFilterKey = '';

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(d);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _refreshSync() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid != null) {
      try {
        await ref.read(syncServiceV2Provider).sync(
          userId: uid,
          companyId: company.currentCompanyId,
          storeId: null,
        );
      } catch (_) {}
    }
  }

  bool _canManagePurchases(PermissionsProvider permissions) {
    return permissions.isOwner ||
        permissions.hasPermission(Permissions.purchasesUpdate) ||
        permissions.hasPermission(Permissions.purchasesCancel) ||
        permissions.hasPermission(Permissions.purchasesDelete);
  }

  void _openCreatePurchase(String companyId, List<Store> stores, List<Supplier> suppliers) {
    final permissions = context.read<PermissionsProvider>();
    final canCreate = permissions.isOwner || permissions.hasPermission(Permissions.purchasesCreate);
    if (!canCreate) {
      AppToast.info(context, "Vous n'avez pas le droit de créer des achats.");
      return;
    }
    if (stores.isEmpty) {
      AppToast.info(context, 'Aucune boutique.');
      return;
    }
    final currentStoreId = context.read<CompanyProvider>().currentStoreId;
    showDialog<void>(
      context: context,
      builder: (ctx) => CreatePurchaseDialog(
        companyId: companyId,
        stores: stores,
        suppliers: suppliers,
        initialStoreId: currentStoreId,
        onSuccess: (purchase) async {
          await ref.read(purchasesOfflineRepositoryProvider).upsertPurchase(purchase);
          ref.invalidate(purchasesStreamProvider((
            companyId: companyId,
            storeId: _filterStoreId,
            supplierId: _filterSupplierId,
            status: _filterStatus,
            fromDate: null,
            toDate: null,
          )));
          _refreshSync();
        },
      ),
    );
  }

  void _openDetail(Purchase purchase) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PurchaseDetailDialog(
        purchase: purchase,
        canManage: _canManagePurchases(ctx.read<PermissionsProvider>()),
        onCancel: () async {
          Navigator.of(ctx).pop();
          await _doCancel(purchase);
        },
        onDelete: () async {
          Navigator.of(ctx).pop();
          await _doDelete(purchase);
        },
        onUpdated: () {
          Navigator.of(ctx).pop();
          ref.invalidate(purchasesStreamProvider((
            companyId: purchase.companyId,
            storeId: _filterStoreId,
            supplierId: _filterSupplierId,
            status: _filterStatus,
            fromDate: null,
            toDate: null,
          )));
          _refreshSync();
        },
      ),
    );
  }

  Future<void> _doCancel(Purchase purchase) async {
    if (purchase.status != PurchaseStatus.draft) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'achat'),
        content: Text('Annuler l\'achat ${purchase.reference ?? purchase.id} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Oui')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final repo = PurchasesRepository();
      await repo.cancel(purchase.id);
      if (!mounted) return;
      await ref.read(appDatabaseProvider).updateLocalPurchaseStatus(purchase.id, 'cancelled');
      ref.invalidate(purchasesStreamProvider((
        companyId: purchase.companyId,
        storeId: _filterStoreId,
        supplierId: _filterSupplierId,
        status: _filterStatus,
        fromDate: null,
        toDate: null,
      )));
      AppToast.success(context, 'Achat annulé');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _doDelete(Purchase purchase) async {
    if (purchase.status != PurchaseStatus.draft) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'achat'),
        content: Text(
          'Supprimer définitivement l\'achat ${purchase.reference ?? purchase.id} ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final repo = PurchasesRepository();
      await repo.delete(purchase.id);
      if (!mounted) return;
      await ref.read(purchasesOfflineRepositoryProvider).deletePurchase(purchase.id);
      ref.invalidate(purchasesStreamProvider((
        companyId: purchase.companyId,
        storeId: _filterStoreId,
        supplierId: _filterSupplierId,
        status: _filterStatus,
        fromDate: null,
        toDate: null,
      )));
      AppToast.success(context, 'Achat supprimé');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final canAccess = permissions.hasPermission(Permissions.purchasesView) ||
        permissions.hasPermission(Permissions.purchasesCreate) ||
        permissions.hasPermission(Permissions.purchasesCancel) ||
        permissions.isOwner;
    if (permissions.hasLoaded && !canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Achats')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                "Vous n'avez pas accès à cette page.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final stores = company.stores;
    final suppliersAsync = ref.watch(suppliersStreamProvider(companyId ?? ''));
    final suppliers = suppliersAsync.value ?? [];
    final purchasesAsync = ref.watch(purchasesStreamProvider((
      companyId: companyId ?? '',
      storeId: _filterStoreId,
      supplierId: _filterSupplierId,
      status: _filterStatus,
      fromDate: null,
      toDate: null,
    )));
    final purchases = purchasesAsync.value ?? [];
    final loading = purchasesAsync.isLoading;
    final error = purchasesAsync.hasError ? AppErrorHandler.toUserMessage(purchasesAsync.error!) : null;
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final totalCount = purchases.length;
    final pageCount = totalCount == 0 ? 0 : ((totalCount - 1) ~/ _purchasesPageSize) + 1;
    final filterKey = '$_filterStoreId|$_filterSupplierId|$_filterStatus';
    if (filterKey != _lastPurchasesFilterKey) {
      _lastPurchasesFilterKey = filterKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPurchasesPage = 0);
      });
    }
    final effectivePage = pageCount > 0 && _currentPurchasesPage >= pageCount ? pageCount - 1 : _currentPurchasesPage;
    if (effectivePage != _currentPurchasesPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPurchasesPage = effectivePage);
      });
    }
    final paginatedPurchases = purchases.skip(effectivePage * _purchasesPageSize).take(_purchasesPageSize).toList();

    if (!_syncTriggeredOnce && companyId != null && purchases.isEmpty && !purchasesAsync.isLoading) {
      _syncTriggeredOnce = true;
      Future.microtask(() => _refreshSync());
    }

    if (companyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Achats')),
        body: const Center(child: Text('Sélectionnez une entreprise.')),
      );
    }

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Achats')),
      body: RefreshIndicator(
        onRefresh: _refreshSync,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 20, vertical: isWide ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Achats',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (permissions.isOwner || permissions.hasPermission(Permissions.purchasesCreate))
                    FilledButton.icon(
                      onPressed: () => _openCreatePurchase(companyId, stores, suppliers),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Nouveau achat'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Voir, modifier, annuler ou supprimer les achats.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  DropdownButtonFormField<String>(
                    value: _filterStoreId,
                    decoration: const InputDecoration(
                      labelText: 'Boutique',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes')),
                      ...stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setState(() => _filterStoreId = v),
                  ),
                  DropdownButtonFormField<String>(
                    value: _filterSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'Fournisseur',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous')),
                      ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setState(() => _filterSupplierId = v),
                  ),
                  DropdownButtonFormField<PurchaseStatus?>(
                    value: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous')),
                      ...PurchaseStatus.values.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(_statusLabels[s] ?? s.name),
                          )),
                    ],
                    onChanged: (v) => setState(() => _filterStatus = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (error != null) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (purchases.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        'Aucun achat.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Réf.')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Boutique')),
                        DataColumn(label: Text('Fournisseur')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: paginatedPurchases.map<DataRow>((p) {
                        return DataRow(
                          cells: [
                            DataCell(Text(p.reference ?? '—', overflow: TextOverflow.ellipsis)),
                            DataCell(Text(_formatDate(p.createdAt))),
                            DataCell(Text(p.store?.name ?? '—', overflow: TextOverflow.ellipsis)),
                            DataCell(Text(p.supplier?.name ?? '—', overflow: TextOverflow.ellipsis)),
                            DataCell(Text(formatCurrency(p.total))),
                            DataCell(Text(_statusLabels[p.status] ?? p.status.name)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => _openDetail(p),
                                  child: const Text('Voir'),
                                ),
                                if (p.status == PurchaseStatus.draft && _canManagePurchases(permissions)) ...[
                                  TextButton(
                                    onPressed: () => _openDetail(p),
                                    child: const Text('Modifier'),
                                  ),
                                  TextButton(
                                    onPressed: () => _doCancel(p),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () => _doDelete(p),
                                    child: Text('Supprimer', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                  ),
                                ],
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (pageCount > 1) ...[
                  const SizedBox(height: 16),
                  _buildPurchasesPagination(context, totalCount, pageCount, effectivePage),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchasesPagination(BuildContext context, int totalCount, int pageCount, int currentPageIndex) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _purchasesPageSize + 1;
    final end = (currentPageIndex + 1) * _purchasesPageSize;
    final endClamped = end > totalCount ? totalCount : end;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
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
                  '$start – $endClamped sur $totalCount',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            IconButton.filled(
              onPressed: currentPageIndex > 0 ? () => setState(() => _currentPurchasesPage--) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex > 0 ? theme.colorScheme.primary : null,
                foregroundColor: currentPageIndex > 0 ? theme.colorScheme.onPrimary : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Page ${currentPageIndex + 1} / $pageCount',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: currentPageIndex < pageCount - 1 ? () => setState(() => _currentPurchasesPage++) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex < pageCount - 1 ? theme.colorScheme.primary : null,
                foregroundColor: currentPageIndex < pageCount - 1 ? theme.colorScheme.onPrimary : null,
              ),
            ),
            if (isNarrow) ...[
              const SizedBox(width: 12),
              Text(
                '$start – $endClamped / $totalCount',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PurchaseDetailDialog extends StatefulWidget {
  const _PurchaseDetailDialog({
    required this.purchase,
    required this.canManage,
    required this.onCancel,
    required this.onDelete,
    required this.onUpdated,
  });

  final Purchase purchase;
  final bool canManage;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onUpdated;

  @override
  State<_PurchaseDetailDialog> createState() => _PurchaseDetailDialogState();
}

class _PurchaseDetailDialogState extends State<_PurchaseDetailDialog> {
  late TextEditingController _refController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refController = TextEditingController(text: widget.purchase.reference ?? '');
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _saveReference() async {
    if (widget.purchase.status != PurchaseStatus.draft) return;
    final ref = _refController.text.trim();
    setState(() => _saving = true);
    try {
      final repo = PurchasesRepository();
      await repo.update(widget.purchase.id, reference: ref.isEmpty ? null : ref);
      if (mounted) widget.onUpdated();
      if (mounted) AppToast.success(context, 'Référence mise à jour');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final theme = Theme.of(context);
    const statusLabels = _statusLabels;
    return AlertDialog(
      title: Text('Achat ${p.reference ?? p.id}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(statusLabels[p.status] ?? p.status.name)),
                if (p.store != null) Text('Boutique: ${p.store!.name}'),
                if (p.supplier != null) Text('Fournisseur: ${p.supplier!.name}'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Date: ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(DateTime.parse(p.createdAt).toLocal())}'),
            Text('Total: ${formatCurrency(p.total)}'),
            if (p.purchaseItems != null && p.purchaseItems!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Articles', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...p.purchaseItems!.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('${i.quantity} × ${i.unitPrice}', overflow: TextOverflow.ellipsis)),
                        Text(formatCurrency(i.total)),
                      ],
                    ),
                  )),
            ],
            if (p.status == PurchaseStatus.draft && widget.canManage) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _refController,
                decoration: const InputDecoration(
                  labelText: 'Référence',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _saveReference,
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer la référence'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
        if (p.status == PurchaseStatus.draft && widget.canManage) ...[
          TextButton(onPressed: widget.onCancel, child: const Text('Annuler l\'achat')),
          TextButton(
            onPressed: widget.onDelete,
            child: Text('Supprimer', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ],
    );
  }
}

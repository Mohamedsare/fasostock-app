import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/breakpoints.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/stock_transfer.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/transfers_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import 'widgets/create_transfer_dialog.dart';
import 'widgets/transfer_detail_dialog.dart';

const int _transfersPageSize = 20;

const Map<TransferStatus, String> _statusLabels = {
  TransferStatus.draft: 'Brouillon',
  TransferStatus.pending: 'En attente',
  TransferStatus.approved: 'Approuvé',
  TransferStatus.shipped: 'Expédié',
  TransferStatus.received: 'Réceptionné',
  TransferStatus.rejected: 'Rejeté',
  TransferStatus.cancelled: 'Annulé',
};

/// Transferts — offline+sync : liste depuis Drift, sync push/pull en arrière-plan ; création possible hors ligne.
class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  int _currentTransfersPage = 0;
  TransferStatus? _filterStatus;
  String? _filterFromStoreId;
  String? _filterToStoreId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCompaniesIfNeeded();
    });
  }

  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null && company.companies.isEmpty && !company.loading) {
      company.loadCompanies(userId);
    }
  }

  Future<void> _refreshSync() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid != null && company.currentCompanyId != null) {
      try {
        await ref
            .read(syncServiceV2Provider)
            .sync(
          userId: uid,
          companyId: company.currentCompanyId,
          storeId: null,
        );
      } catch (e) {
        if (mounted)
          AppErrorHandler.show(
            context,
            e,
            fallback: 'Synchronisation échouée. Réessayez.',
          );
      }
    }
  }

  void _openCreateTransfer(String companyId, List<Store> stores) {
    if (stores.isEmpty) return;
    final company = context.read<CompanyProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => CreateTransferDialog(
        companyId: companyId,
        stores: stores,
        initialFromStoreId: company.currentStoreId,
        onSuccess: (transfer) {
          ref.read(transfersOfflineRepositoryProvider).upsertTransfer(transfer);
          ref.invalidate(transfersStreamProvider(companyId));
          _refreshSync();
        },
        onOfflineSave: (transfer, payload) async {
          await ref
              .read(appDatabaseProvider)
              .enqueuePendingAction('transfer', jsonEncode(payload));
          await ref
              .read(transfersOfflineRepositoryProvider)
              .upsertTransfer(transfer);
          if (!mounted) return;
          ref.invalidate(transfersStreamProvider(companyId));
          _refreshSync();
        },
      ),
    );
  }

  String _storeName(String? storeId, List<Store> stores) {
    if (storeId == null) return '—';
    for (final s in stores) {
      if (s.id == storeId) return s.name;
    }
    return '—';
  }

  Future<void> _removePendingTransferLocal(String transferId) async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteUnsyncedPendingTransferByLocalId(transferId);
    await db.deleteLocalTransfer(transferId);
  }

  Future<void> _cancelOrDeleteTransfer(
    BuildContext context,
    StockTransfer t,
    String companyId,
  ) async {
    final isLocalDraft = t.id.startsWith('pending:');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isLocalDraft ? 'Supprimer ce brouillon ?' : 'Annuler ce transfert ?',
        ),
        content: Text(
          isLocalDraft
              ? 'Ce transfert n\'a pas encore été synchronisé. Il sera définitivement supprimé.'
              : 'Le transfert passera au statut « Annulé ». Aucun stock ne sera modifié.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(isLocalDraft ? 'Supprimer' : 'Annuler'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (isLocalDraft) {
        await _removePendingTransferLocal(t.id);
      } else {
        await TransfersRepository().cancel(t.id);
        final now = DateTime.now().toUtc().toIso8601String();
        await ref
            .read(transfersOfflineRepositoryProvider)
            .upsertTransfer(
              StockTransfer(
                id: t.id,
                companyId: t.companyId,
                fromStoreId: t.fromStoreId,
                toStoreId: t.toStoreId,
                fromWarehouse: t.fromWarehouse,
                status: TransferStatus.cancelled,
                requestedBy: t.requestedBy,
                approvedBy: t.approvedBy,
                shippedAt: t.shippedAt,
                receivedAt: t.receivedAt,
                receivedBy: t.receivedBy,
                createdAt: t.createdAt,
                updatedAt: now,
                items: t.items,
              ),
            );
      }
      if (context.mounted) {
        ref.invalidate(transfersStreamProvider(companyId));
        AppToast.success(
          context,
          isLocalDraft ? 'Brouillon supprimé' : 'Transfert annulé',
        );
        _refreshSync();
      }
    } catch (e) {
      if (context.mounted) AppErrorHandler.show(context, e);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(d);
    } catch (_) {
      return iso.length >= 10 ? iso.substring(0, 10) : iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final permissions = context.watch<PermissionsProvider>();
    final canAccessTransfers =
        permissions.hasPermission(Permissions.stockTransfer) ||
        permissions.hasPermission(Permissions.transfersCreate) ||
        permissions.hasPermission(Permissions.transfersApprove);
    final canCreate = permissions.hasPermission(Permissions.stockTransfer);
    final w = MediaQuery.sizeOf(context).width;
    final isWide = Breakpoints.isTabletOrWider(w);
    final isMobile = Breakpoints.isMobile(w);
    final spaceL = isMobile ? AppTheme.spaceLgM : AppTheme.spaceLg;
    final spaceX = isMobile ? AppTheme.spaceXlM : AppTheme.spaceXl;
    final spaceM = isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd;

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!permissions.hasLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transferts')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!canAccessTransfers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transferts')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  "Vous n'avez pas accès à cette page.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (companyId == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Aucune entreprise. Sélectionnez une entreprise.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final stores = ref.watch(storesStreamProvider(companyId)).value ?? [];
    final transfersAsync = ref.watch(transfersStreamProvider(companyId));
    final allTransfers = (transfersAsync.value ?? [])
        // Défense supplémentaire: un transfert boutique->boutique doit avoir
        // une boutique d'origine renseignée.
        .where((t) => !t.fromWarehouse && t.fromStoreId.trim().isNotEmpty)
        .toList();
    var transfers = allTransfers.where((t) {
      if (_filterStatus != null && t.status != _filterStatus) return false;
      if (_filterFromStoreId != null && t.fromStoreId != _filterFromStoreId)
        return false;
      if (_filterToStoreId != null && t.toStoreId != _filterToStoreId)
        return false;
      return true;
    }).toList();
    transfers.sort((a, b) {
      final da = DateTime.tryParse(a.createdAt) ?? DateTime(1970);
      final db_ = DateTime.tryParse(b.createdAt) ?? DateTime(1970);
      return db_.compareTo(da);
    });
    final loading = transfersAsync.isLoading;
    final error = transfersAsync.error;
    final totalCount = transfers.length;
    final pageCount = totalCount == 0
        ? 0
        : ((totalCount - 1) ~/ _transfersPageSize) + 1;
    final effectivePage = pageCount > 0 && _currentTransfersPage >= pageCount
        ? pageCount - 1
        : _currentTransfersPage;
    if (effectivePage != _currentTransfersPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentTransfersPage = effectivePage);
      });
    }
    final paginatedTransfers = transfers
        .skip(effectivePage * _transfersPageSize)
        .take(_transfersPageSize)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshSync,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : spaceL,
                  isWide ? 28 : spaceX,
                  isWide ? 32 : spaceL,
                  spaceM,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: isMobile ? 22 : 28,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: spaceM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transferts',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                'Transferts de stock entre boutiques',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canCreate && stores.isNotEmpty)
                          FilledButton.icon(
                            onPressed: () =>
                                _openCreateTransfer(companyId, stores),
                            icon: Icon(
                              Icons.add_rounded,
                              size: isMobile ? 16 : 20,
                            ),
                            label: const Text('Nouveau transfert'),
                          ),
                      ],
                    ),
                    if (error != null) ...[
                      SizedBox(height: isMobile ? 10 : 16),
                      Container(
                        padding: EdgeInsets.all(
                          isMobile ? AppTheme.spaceMdM : 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(
                            0.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            isMobile ? AppTheme.radiusSmM : 10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.error,
                              size: isMobile ? 18 : 22,
                            ),
                            SizedBox(width: spaceM),
                            Expanded(
                              child: Text(
                                AppErrorHandler.toUserMessage(error),
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _refreshSync(),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!canCreate && stores.length < 2 && error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          stores.length < 2
                              ? 'Il faut au moins deux boutiques pour créer un transfert.'
                              : 'Vous n\'avez pas le droit de créer des transferts.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (allTransfers.isNotEmpty) ...[
                      SizedBox(height: isMobile ? 12 : 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.filter_list_rounded,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Filtres',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => setState(() {
                                      _filterStatus = null;
                                      _filterFromStoreId = null;
                                      _filterToStoreId = null;
                                      _currentTransfersPage = 0;
                                    }),
                                    icon: const Icon(
                                      Icons.clear_all_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Réinitialiser'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (ctx, c) {
                                  final narrow = c.maxWidth < 520;
                                  Widget statusDd() =>
                                      DropdownButtonFormField<TransferStatus?>(
                                        value: _filterStatus,
                                        decoration: InputDecoration(
                                          labelText: 'Statut',
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('Tous'),
                                          ),
                                          ...TransferStatus.values.map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                _statusLabels[s] ?? s.value,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) => setState(() {
                                          _filterStatus = v;
                                          _currentTransfersPage = 0;
                                        }),
                                      );
                                  Widget fromDd() =>
                                      DropdownButtonFormField<String?>(
                                        value: _filterFromStoreId,
                                        decoration: InputDecoration(
                                          labelText: 'Boutique origine',
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('Toutes'),
                                          ),
                                          ...stores.map(
                                            (s) => DropdownMenuItem(
                                              value: s.id,
                                              child: Text(
                                                s.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) => setState(() {
                                          _filterFromStoreId = v;
                                          _currentTransfersPage = 0;
                                        }),
                                      );
                                  Widget toDd() =>
                                      DropdownButtonFormField<String?>(
                                        value: _filterToStoreId,
                                        decoration: InputDecoration(
                                          labelText: 'Boutique destination',
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('Toutes'),
                                          ),
                                          ...stores.map(
                                            (s) => DropdownMenuItem(
                                              value: s.id,
                                              child: Text(
                                                s.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (v) => setState(() {
                                          _filterToStoreId = v;
                                          _currentTransfersPage = 0;
                                        }),
                                      );
                                  if (narrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        statusDd(),
                                        const SizedBox(height: 10),
                                        fromDd(),
                                        const SizedBox(height: 10),
                                        toDd(),
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: statusDd()),
                                      const SizedBox(width: 12),
                                      Expanded(child: fromDd()),
                                      const SizedBox(width: 12),
                                      Expanded(child: toDd()),
                                    ],
                                  );
                                },
                              ),
                              if (totalCount != allTransfers.length)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    '$totalCount transfert(s) sur ${allTransfers.length}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (loading && transfers.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (transfers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(spaceX),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: theme.colorScheme.outline.withOpacity(0.5),
                        ),
                        SizedBox(height: spaceL),
                        Text(
                          allTransfers.isEmpty
                              ? 'Aucun transfert'
                              : 'Aucun résultat',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        Text(
                          allTransfers.isEmpty
                              ? (canCreate && stores.isNotEmpty
                              ? 'Appuyez sur « Nouveau transfert » pour en créer un.'
                                    : 'Créez des transferts depuis l\'app web ou ajoutez une boutique.')
                              : 'Modifiez les filtres ou réinitialisez-les.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : spaceL,
                  vertical: spaceM,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                      final t = paginatedTransfers[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                        child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 16,
                          vertical: isMobile ? 6 : 8,
                        ),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            radius: isMobile ? 18 : 22,
                            child: Icon(
                              Icons.swap_horiz_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: isMobile ? 18 : 22,
                            ),
                          ),
                          title: Text(
                            '${_storeName(t.fromStoreId, stores)} → ${_storeName(t.toStoreId, stores)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                            '${_formatDate(t.createdAt)} · ${_statusLabels[t.status] ?? t.status.value}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                            if (t.id.startsWith('pending:'))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Non synchronisé',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.tertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (t.status == TransferStatus.draft ||
                                t.status == TransferStatus.pending)
                              IconButton(
                                tooltip: t.id.startsWith('pending:')
                                    ? 'Supprimer le brouillon'
                                    : 'Annuler le transfert',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: theme.colorScheme.error,
                                  size: 22,
                                ),
                                onPressed: () => _cancelOrDeleteTransfer(
                                  context,
                                  t,
                                  companyId,
                                ),
                              ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.outline,
                            ),
                          ],
                        ),
                          onTap: () {
                            final transfer = t;
                            final storeList = List<Store>.from(stores);
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => TransferDetailDialog(
                                transferId: transfer.id,
                                stores: storeList,
                                storeName: (id) => _storeName(id, storeList),
                                onTransferSettled: (t) {
                                  if (t.fromStoreId.isNotEmpty) {
                                    ref.invalidate(
                                      inventoryQuantitiesStreamProvider(
                                        t.fromStoreId,
                                      ),
                                    );
                                  }
                                  if (t.toStoreId.isNotEmpty) {
                                    ref.invalidate(
                                      inventoryQuantitiesStreamProvider(
                                        t.toStoreId,
                                      ),
                                    );
                                  }
                                },
                              onActionDone: () {
                                ref.invalidate(
                                  transfersStreamProvider(companyId),
                                );
                                _refreshSync();
                              },
                                initialTransfer: transfer,
                              onRemovePendingLocal: _removePendingTransferLocal,
                              ),
                            );
                          },
                        ),
                      );
                  }, childCount: paginatedTransfers.length),
                ),
              ),
              if (pageCount > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 32 : spaceL,
                      spaceM,
                      isWide ? 32 : spaceL,
                      spaceX,
                    ),
                    child: _buildTransfersPagination(
                      context,
                      totalCount,
                      pageCount,
                      effectivePage,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransfersPagination(
    BuildContext context,
    int totalCount,
    int pageCount,
    int currentPageIndex,
  ) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _transfersPageSize + 1;
    final end = (currentPageIndex + 1) * _transfersPageSize;
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            IconButton.filled(
              onPressed: currentPageIndex > 0
                  ? () => setState(() => _currentTransfersPage--)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex > 0
                    ? theme.colorScheme.primary
                    : null,
                foregroundColor: currentPageIndex > 0
                    ? theme.colorScheme.onPrimary
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Page ${currentPageIndex + 1} / $pageCount',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: currentPageIndex < pageCount - 1
                  ? () => setState(() => _currentTransfersPage++)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 26),
              style: IconButton.styleFrom(
                backgroundColor: currentPageIndex < pageCount - 1
                    ? theme.colorScheme.primary
                    : null,
                foregroundColor: currentPageIndex < pageCount - 1
                    ? theme.colorScheme.onPrimary
                    : null,
              ),
            ),
            if (isNarrow) ...[
              const SizedBox(width: 12),
              Text(
                '$start – $endClamped / $totalCount',
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

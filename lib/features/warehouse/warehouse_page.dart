import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/breakpoints.dart';
import '../../core/config/routes.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/stock_cache_recovery.dart';
import '../../data/models/category.dart';
import '../../data/models/product.dart';
import '../../data/models/sale.dart';
import '../../data/models/stock_transfer.dart';
import '../../data/models/store.dart';
import '../../data/models/warehouse_movement.dart';
import '../../data/models/warehouse_stock_line.dart';
import '../../data/repositories/products_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/transfers_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/offline_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../shared/utils/format_currency.dart';
import 'warehouse_adjustment_dialog.dart';
import 'warehouse_dispatch_invoice_dialog.dart';
import 'warehouse_dispatch_history_dialog.dart';
import 'warehouse_ui_helpers.dart';
import 'warehouse_pos_quick_widgets.dart';
import '../pos_quick/pos_quick_constants.dart';
import '../pos_quick/widgets/pos_quick_product_card.dart';
import '../transfers/widgets/create_transfer_dialog.dart';
import '../transfers/widgets/transfer_detail_dialog.dart';

/// Conditionnements enregistrés côté API (libellés FR pour l’UI).
const Map<String, String> kWarehousePackagingLabels = {
  'carton': 'Carton',
  'paquet': 'Paquet',
  'sachet': 'Sachet',
  'piece': 'Pièce',
  'lot': 'Lot',
  'unite': 'Unité',
  'autre': 'Autre',
};

/// Module **Magasin** — dépôt central par entreprise (owner). Stock **distinct** du stock de chaque boutique.
class WarehousePage extends ConsumerStatefulWidget {
  const WarehousePage({super.key});

  @override
  ConsumerState<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends ConsumerState<WarehousePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<WarehouseDispatchHistoryPanelState> _dispatchHistoryKey =
      GlobalKey<WarehouseDispatchHistoryPanelState>();
  final WarehouseRepository _repo = WarehouseRepository();
  final SalesRepository _salesRepo = SalesRepository();
  final TransfersRepository _transfersRepo = TransfersRepository();
  static final Map<String, int> _lastSyncMsByCompany = <String, int>{};
  static const int _autoSyncCooldownMs = 90000;

  bool _syncing = false;
  String? _error;
  String? _lastLoadedCompanyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// [silent] : sync en arrière-plan — pas de `_syncing` ni toast d’erreur (logs conservés).
  /// Par défaut : `silent == !force` (premier chargement = discret ; « Actualiser » = explicite).
  Future<void> _load({bool force = false, bool? silent}) async {
    final effectiveSilent = silent ?? !force;
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final uid = context.read<AuthProvider>().user?.id;
    if (companyId == null) {
      setState(() {
        _syncing = false;
        _error = 'Sélectionnez une entreprise.';
      });
      return;
    }
    if (!force) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastMs = _lastSyncMsByCompany[companyId];
      if (lastMs != null && (nowMs - lastMs) < _autoSyncCooldownMs) {
        return;
      }
    }
    if (!effectiveSilent) {
      setState(() {
        _syncing = true;
        _error = null;
      });
    }
    try {
      if (uid != null) {
        await ref
            .read(syncServiceV2Provider)
            .sync(userId: uid, companyId: companyId, storeId: null);
      }
      _lastSyncMsByCompany[companyId] = DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      if (!effectiveSilent) {
        setState(() => _syncing = false);
      }
    } catch (e, st) {
      WarehouseUi.logOp('sync_load', e, st);
      if (!mounted) return;
      if (!effectiveSilent) {
        setState(() {
          _syncing = false;
        });
        // Offline-first: garde l'écran local lisible même si la sync réseau échoue.
        AppToast.info(context, 'Mode hors ligne: affichage local. La synchronisation reprendra à la reconnexion.');
      }
    }
  }

  Future<void> _openEntryDialog() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _WarehouseEntryDialog(
        companyId: companyId,
        warehouseRepo: _repo,
        onSuccess: () => _load(force: true, silent: true),
        onOfflineEnqueue: (payload) async {
          await ref
              .read(appDatabaseProvider)
              .enqueuePendingAction(
                'warehouse_manual_entry',
                jsonEncode(payload),
              );
        },
      ),
    );
  }

  Future<void> _openDispatchDialog() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final products =
        ref.read(productsStreamProvider(companyId)).valueOrNull ?? [];
    final inv =
        ref.read(warehouseInventoryStreamProvider(companyId)).valueOrNull ?? [];
    final whQty = {for (final l in inv) l.productId: l.quantity};
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => WarehouseDispatchInvoiceDialog(
        companyId: companyId,
        products: products,
        warehouseQuantities: whQty,
        warehouseRepo: _repo,
        onSuccess: () => _load(force: true, silent: true),
        onOfflineEnqueue: (payload) async {
          await ref
              .read(appDatabaseProvider)
              .enqueuePendingAction(
                'warehouse_dispatch_invoice',
                jsonEncode(payload),
              );
        },
      ),
    );
  }

  Future<void> _showAdjustmentDialog(WarehouseStockLine line) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => WarehouseAdjustmentDialog(
        companyId: companyId,
        line: line,
        warehouseRepo: _repo,
        onSuccess: () => _load(force: true, silent: true),
        onOfflineEnqueue: (payload) async {
          await ref
              .read(appDatabaseProvider)
              .enqueuePendingAction(
                'warehouse_adjustment',
                jsonEncode(payload),
              );
        },
      ),
    );
  }

  Future<void> _openWarehouseTransferDialog() async {
    final company = context.read<CompanyProvider>();
    final companyId = company.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    var stores = ref.read(storesStreamProvider(companyId)).valueOrNull ?? [];
    if (stores.isEmpty && company.stores.isNotEmpty) {
      stores = company.stores;
    }
    if (stores.isEmpty) {
      await company.refreshStores();
      if (!mounted) return;
      stores = company.stores;
    }
    if (stores.isEmpty) {
      AppToast.info(context, 'Aucune boutique disponible pour recevoir le transfert.');
      return;
    }
    final inv = ref
            .read(warehouseInventoryStreamProvider(companyId))
            .valueOrNull ??
        [];
    final warehouseQty = {for (final l in inv) l.productId: l.quantity};
    final userId = context.read<AuthProvider>().user?.id;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => CreateTransferDialog(
        companyId: companyId,
        stores: stores,
        initialToStoreId: company.currentStoreId,
        fromWarehouseSource: true,
        warehouseQuantities: warehouseQty,
        onSuccess: (transfer) async {
          await ref
              .read(transfersOfflineRepositoryProvider)
              .upsertTransfer(transfer);
          ref.invalidate(transfersStreamProvider(companyId));
          await _load(force: true, silent: true);
        },
        onOfflineSave: (transfer, payload) async {
          await ref
              .read(appDatabaseProvider)
              .enqueuePendingAction('transfer', jsonEncode(payload));
          await ref
              .read(transfersOfflineRepositoryProvider)
              .upsertTransfer(transfer);
          ref.invalidate(transfersStreamProvider(companyId));
          if (userId != null && ConnectivityService.instance.isOnline) {
            unawaited(
              ref.read(syncServiceV2Provider).sync(
                    userId: userId,
                    companyId: companyId,
                    storeId: null,
                  ),
            );
          }
        },
      ),
    );
  }

  Future<void> _removePendingTransferLocal(String transferId) async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteUnsyncedPendingTransferByLocalId(transferId);
    await db.deleteLocalTransfer(transferId);
  }

  /// Brouillon non synchronisé, brouillon serveur ou transfert annulé uniquement.
  Future<void> _deleteWarehouseTransfer(StockTransfer t) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final isPendingLocal = t.id.startsWith('pending:');
    final canDelete = isPendingLocal ||
        t.status == TransferStatus.draft ||
        t.status == TransferStatus.cancelled;
    if (!canDelete) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPendingLocal ? 'Supprimer ce brouillon ?' : 'Supprimer ce transfert ?',
        ),
        content: Text(
          isPendingLocal
              ? 'Ce transfert n’a pas encore été synchronisé. Il sera définitivement retiré.'
              : t.status == TransferStatus.cancelled
                  ? 'Le transfert annulé sera définitivement supprimé de l’historique.'
                  : 'Le brouillon sera définitivement supprimé.',
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (isPendingLocal) {
        await _removePendingTransferLocal(t.id);
      } else {
        await _transfersRepo.deletePermanently(t.id);
        await ref.read(appDatabaseProvider).deleteLocalTransfer(t.id);
      }
      ref.invalidate(transfersStreamProvider(companyId));
      await _load(force: true, silent: true);
      if (mounted) {
        AppToast.success(
          context,
          isPendingLocal ? 'Brouillon supprimé' : 'Transfert supprimé',
        );
      }
    } catch (e, st) {
      WarehouseUi.logOp('warehouse_transfer_delete', e, st);
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  void _openWarehouseTransferDetail(StockTransfer t) {
    final company = context.read<CompanyProvider>();
    final companyId = company.currentCompanyId ?? '';
    if (companyId.isEmpty) return;
    var stores = ref.read(storesStreamProvider(companyId)).valueOrNull ?? <Store>[];
    if (stores.isEmpty && company.stores.isNotEmpty) {
      stores = company.stores;
    }
    if (stores.isEmpty) {
      AppToast.info(context, 'Aucune boutique chargée.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => TransferDetailDialog(
        companyId: companyId,
        transferId: t.id,
        stores: stores,
        storeName: (id) {
          if (id == null || id.isEmpty) return '—';
          for (final s in stores) {
            if (s.id == id) return s.name;
          }
          return '—';
        },
        initialTransfer: t,
        onTransferSettled: (t) {
          if (t.toStoreId.isNotEmpty) {
            ref.invalidate(inventoryQuantitiesStreamProvider(t.toStoreId));
          }
          if (t.fromWarehouse) {
            ref.invalidate(warehouseInventoryStreamProvider(companyId));
          }
        },
        onActionDone: () {
          ref.invalidate(transfersStreamProvider(companyId));
          _load(force: true, silent: true);
        },
        onRemovePendingLocal: _removePendingTransferLocal,
      ),
    );
  }

  Future<void> _openActionsMenu() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final actions = <({
      String id,
      IconData icon,
      String title,
      String subtitle,
      Color color,
    })>[
      (
        id: 'entry',
        icon: Icons.add_circle_outline_rounded,
        title: 'Réception au dépôt',
        subtitle: 'Arrivées, quantités, prix d’achat',
        color: WarehouseUi.accentEmerald,
      ),
      (
        id: 'products',
        icon: Icons.category_rounded,
        title: 'Catalogue produits',
        subtitle: 'Créer ou modifier des articles (dépôt et boutiques)',
        color: WarehouseUi.accentViolet,
      ),
      (
        id: 'transfer',
        icon: Icons.swap_horiz_rounded,
        title: 'Transfert vers une boutique',
        subtitle: 'Envoyer du stock du dépôt vers une boutique',
        color: WarehouseUi.accentBlue,
      ),
      (
        id: 'sales',
        icon: Icons.point_of_sale_rounded,
        title: 'Ventes en caisse',
        subtitle: 'Nouvelles ventes en boutique',
        color: WarehouseUi.accentOrange,
      ),
      (
        id: 'dispatch',
        icon: Icons.receipt_long_rounded,
        title: 'Facture / bon de sortie dépôt',
        subtitle: 'Sortie de produits avec document',
        color: WarehouseUi.accentTeal,
      ),
      (
        id: 'dispatch_history',
        icon: Icons.article_rounded,
        title: 'Historique des bons',
        subtitle: 'Voir les bons/factures et imprimer en A4',
        color: WarehouseUi.accentBlue,
      ),
      (
        id: 'exit',
        icon: Icons.link_rounded,
        title: 'Rattacher une vente déjà validée',
        subtitle: 'Cas exceptionnel : sortie dépôt après coup',
        color: WarehouseUi.accentRose,
      ),
    ];
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.48,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) {
          final theme = Theme.of(ctx);
          final scheme = theme.colorScheme;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                Text(
                  'Actions du dépôt',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choisissez une opération',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final a in actions) ...[
                  Material(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, a.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: a.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(a.icon, size: 20, color: a.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: scheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'transfer') {
      await _openWarehouseTransferDialog();
      return;
    }
    if (choice == 'products') {
      context.go(AppRoutes.products);
      return;
    }
    if (choice == 'sales') {
      context.go(AppRoutes.sales);
      return;
    }
    if (choice == 'entry') {
      await _openEntryDialog();
    } else if (choice == 'exit') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _WarehouseExitSaleDialog(
          companyId: companyId,
          salesRepo: _salesRepo,
          warehouseRepo: _repo,
          onSuccess: () => _load(force: true, silent: true),
          onStaleInventoryAfterError: () {
            final uid = context.read<AuthProvider>().user?.id;
            recoverWarehouseInventoryCacheAfterRpcError(
              ref,
              companyId,
              () async {
                if (uid == null) return;
                await ref.read(syncServiceV2Provider).sync(
                      userId: uid,
                      companyId: companyId,
                      storeId: null,
                    );
              },
            );
          },
          onOfflineEnqueue: (payload) async {
            await ref
                .read(appDatabaseProvider)
                .enqueuePendingAction(
                  'warehouse_exit_sale',
                  jsonEncode(payload),
                );
          },
        ),
      );
    } else if (choice == 'dispatch') {
      await _openDispatchDialog();
    } else if (choice == 'dispatch_history') {
      _tabController.animateTo(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final company = context.watch<CompanyProvider>();
    final warehouseModuleOn = company.currentCompany?.warehouseFeatureEnabled ?? true;
    if (permissions.hasLoaded && !permissions.canManageWarehouse) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Magasin'),
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Accès réservé',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ce module dépôt central est réservé au propriétaire ou aux utilisateurs avec le rôle Magasinier.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (permissions.hasLoaded && permissions.canManageWarehouse && !warehouseModuleOn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Magasin'),
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Module indisponible',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Le module Magasin a été désactivé pour votre entreprise. Contactez l’administrateur de la plateforme.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final companyId = company.currentCompanyId ?? '';
    final invAsync = ref.watch(warehouseInventoryStreamProvider(companyId));
    final movAsync = ref.watch(warehouseMovementsStreamProvider(companyId));
    final transfersAsync = ref.watch(transfersStreamProvider(companyId));
    final inventory = invAsync.valueOrNull ?? [];
    final movements = movAsync.valueOrNull ?? [];
    final warehouseTransfers = (transfersAsync.valueOrNull ?? [])
        .where((t) => t.fromWarehouse)
        .toList();
    final storeNamesById = {
      for (final s in company.stores) s.id: s.name,
    };
    final streamErr = invAsync.error ?? movAsync.error;
    final dashboard = companyId.isEmpty
        ? null
        : _repo.computeDashboardFromLists(inventory, movements);
    final listLoading =
        (invAsync.isLoading || movAsync.isLoading) &&
        inventory.isEmpty &&
        movements.isEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: const Text('Magasin'),
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF4A4643),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFFF97316),
              ),
              dividerHeight: 0,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              tabs: const [
                Tab(text: 'Tableau de bord'),
                Tab(text: 'Stock dépôt'),
                Tab(text: 'Mouvements'),
                Tab(text: 'Transfert'),
                Tab(text: 'Historiques des bons'),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _syncing ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: listLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? WarehouseErrorPanel(message: _error!, onRetry: _load)
                : streamErr != null
                ? WarehouseErrorPanel(
                    title: 'Données dépôt indisponibles',
                    message: ErrorMapper.toMessage(streamErr),
                    onRetry: _load,
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                                onRefresh: () => _load(force: true),
                        child: _DashboardTab(
                          summary: dashboard,
                          onOpenShortcuts: () =>
                              context.go(AppRoutes.purchases),
                          onOpenReception: () {
                            _openEntryDialog();
                          },
                          onOpenDispatch: () {
                            _openDispatchDialog();
                          },
                          onOpenProducts: () => _tabController.animateTo(1),
                          onOpenTransfers: _openWarehouseTransferDialog,
                        ),
                      ),
                      RefreshIndicator(
                                onRefresh: () => _load(force: true),
                        child: _StockTab(
                          lines: inventory,
                          onEditThreshold: companyId.isEmpty
                              ? null
                              : (line) => _showThresholdEditor(companyId, line),
                          onAdjustStock: companyId.isEmpty
                              ? null
                              : (line) => _showAdjustmentDialog(line),
                        ),
                      ),
                      RefreshIndicator(
                                onRefresh: () => _load(force: true),
                        child: _MovementsTab(
                          movements: movements,
                          companyId: companyId,
                          warehouseRepo: _repo,
                          onRefresh: () => _load(force: true),
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: () => _load(force: true),
                        child: _WarehouseTransfersTab(
                          transfers: warehouseTransfers,
                          storeNamesById: storeNamesById,
                          onCreateTransfer: _openWarehouseTransferDialog,
                          onOpenTransfer: _openWarehouseTransferDetail,
                          onDeleteTransfer: _deleteWarehouseTransfer,
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: () async {
                          await _dispatchHistoryKey.currentState?.refresh();
                        },
                        child: WarehouseDispatchHistoryPanel(
                          key: _dispatchHistoryKey,
                          companyId: companyId,
                          warehouseRepo: _repo,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton:
          permissions.isOwner &&
              !_syncing &&
              _error == null &&
              streamErr == null
          ? (MediaQuery.sizeOf(context).width < 900
              ? FloatingActionButton(
                  onPressed: _openActionsMenu,
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  highlightElevation: 8,
                  child: const Icon(Icons.add),
                )
              : FloatingActionButton.extended(
                  onPressed: _openActionsMenu,
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  highlightElevation: 8,
                  icon: const Icon(Icons.add),
                  label: const Text('Gérer le dépôt'),
                ))
          : null,
    );
  }

  Future<void> _showThresholdEditor(
    String companyId,
    WarehouseStockLine line,
  ) async {
    final ctrl = TextEditingController(
      text: line.stockMinWarehouse > 0 ? '${line.stockMinWarehouse}' : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Seuil magasin — ${line.productName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '0 = utiliser le seuil produit (${line.stockMin}). Sinon seuil dédié au dépôt.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Seuil magasin',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final v = int.tryParse(ctrl.text.trim()) ?? 0;
    if (v < 0) return;
    try {
      await _repo.setStockMinWarehouse(
        companyId: companyId,
        productId: line.productId,
        minValue: v,
      );
      if (mounted) AppToast.success(context, 'Seuil enregistré');
      await _load(force: true, silent: true);
    } catch (e, st) {
      WarehouseUi.logOp('set_stock_min_warehouse', e, st);
      if (ErrorMapper.isNetworkError(e) && mounted) {
        await ref
            .read(appDatabaseProvider)
            .enqueuePendingAction(
              'warehouse_set_threshold',
              jsonEncode({
                'company_id': companyId,
                'product_id': line.productId,
                'min': v,
              }),
            );
        if (!mounted) return;
        AppToast.success(
          context,
          'Enregistré. Il sera appliqué dès la prochaine connexion.',
        );
      } else if (mounted) {
        AppToast.error(context, ErrorMapper.toMessage(e));
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perms = context.watch<PermissionsProvider>();
    final cid = context.watch<CompanyProvider>().currentCompanyId;
    if (!perms.hasLoaded || !perms.isOwner) return;
    if (cid == null) return;
    if (cid != _lastLoadedCompanyId) {
      _lastLoadedCompanyId = cid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
          if (context.read<CompanyProvider>().currentCompanyId == cid) _load();
      });
    }
  }
}

class _WarehouseHubCard extends StatelessWidget {
  const _WarehouseHubCard({
    required this.onReception,
    required this.onInvoice,
    required this.onProducts,
    required this.onTransfers,
  });

  final VoidCallback onReception;
  final VoidCallback onInvoice;
  final VoidCallback onProducts;
  final VoidCallback onTransfers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarehouseUi.radiusMd),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tout gérer depuis le dépôt',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Réceptions, factures de sortie, catalogue, transferts vers les boutiques.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _WarehouseHubActionPill(
                  onPressed: onReception,
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Réception',
                  backgroundColor: PosQuickColors.orangePrincipal,
                  foregroundColor: Colors.white,
                ),
                _WarehouseHubActionPill(
                  onPressed: onInvoice,
                  icon: Icons.receipt_long_rounded,
                  label: 'Facture / sortie',
                  backgroundColor: PosQuickColors.orangePrincipal,
                  foregroundColor: Colors.white,
                ),
                _WarehouseHubActionPill(
                  onPressed: onProducts,
                  icon: Icons.category_rounded,
                  label: 'Produits',
                  backgroundColor: const Color(0xFFE6DDF6),
                  foregroundColor: const Color(0xFF7C3AED),
                ),
                _WarehouseHubActionPill(
                  onPressed: onTransfers,
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transferts',
                  backgroundColor: const Color(0xFFDCE5F3),
                  foregroundColor: const Color(0xFF2563EB),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseHubActionPill extends StatelessWidget {
  const _WarehouseHubActionPill({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: foregroundColor),
      label: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _WarehouseTransfersTab extends StatelessWidget {
  const _WarehouseTransfersTab({
    required this.transfers,
    required this.storeNamesById,
    required this.onCreateTransfer,
    required this.onOpenTransfer,
    required this.onDeleteTransfer,
  });

  final List<StockTransfer> transfers;
  final Map<String, String> storeNamesById;
  final VoidCallback onCreateTransfer;
  final void Function(StockTransfer transfer) onOpenTransfer;
  final void Function(StockTransfer transfer) onDeleteTransfer;

  static bool _canDeleteTransfer(StockTransfer t) {
    if (t.id.startsWith('pending:')) return true;
    return t.status == TransferStatus.draft ||
        t.status == TransferStatus.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transfert dépôt -> boutique',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun transfert enregistré pour le moment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onCreateTransfer,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Nouveau transfert'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final sorted = [...transfers]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: sorted.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onCreateTransfer,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau transfert'),
            ),
          );
        }
        final t = sorted[i - 1];
        final toName = storeNamesById[t.toStoreId] ?? 'Boutique';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text('Dépôt magasin → $toName'),
            subtitle: Text(
              _transferCardSubtitle(t),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusBadge(status: t.status),
                if (_canDeleteTransfer(t)) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => onDeleteTransfer(t),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
            onTap: () => onOpenTransfer(t),
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return '—';
    }
  }

  String _transferCardSubtitle(StockTransfer t) {
    final parts = <String>['Créé le ${_formatDate(t.createdAt)}'];
    final items = t.items;
    if (items != null && items.isNotEmpty) {
      final names = items
          .map((i) => i.productName?.trim())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        final shown = names.take(2).join(', ');
        final extra = items.length > 2 ? ' (+${items.length - 2})' : '';
        parts.add('$shown$extra');
      } else {
        parts.add('${items.length} article(s)');
      }
    }
    return parts.join(' · ');
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransferStatus.draft => ('Brouillon', Colors.blueGrey),
      TransferStatus.pending => ('En attente', Colors.orange),
      TransferStatus.approved => ('Approuvé', Colors.indigo),
      TransferStatus.shipped => ('Expédié', Colors.blue),
      TransferStatus.received => ('Reçu', Colors.green),
      TransferStatus.rejected => ('Rejeté', Colors.red),
      TransferStatus.cancelled => ('Annulé', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.summary,
    required this.onOpenShortcuts,
    required this.onOpenReception,
    required this.onOpenDispatch,
    required this.onOpenProducts,
    required this.onOpenTransfers,
  });

  final WarehouseDashboardSummary? summary;
  final VoidCallback onOpenShortcuts;
  final VoidCallback onOpenReception;
  final VoidCallback onOpenDispatch;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenTransfers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    if (s == null) {
      return const WarehouseEmptyState(
        icon: Icons.analytics_outlined,
        title: 'Aucune donnée agrégée',
        subtitle:
            'Synchronisez ou enregistrez des mouvements au dépôt pour voir les indicateurs.',
      );
    }

    final maxChart = [
      ...s.chartEntriesQty,
      ...s.chartExitsQty,
    ].fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxChart * 1.2).clamp(4.0, double.infinity);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _WarehouseHubCard(
          onReception: onOpenReception,
          onInvoice: onOpenDispatch,
          onProducts: onOpenProducts,
          onTransfers: onOpenTransfers,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cross = w > 640 ? 3 : (w > 340 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 10,
              // Ratio plus élevé = cellules moins hautes (cartes plus compactes).
              childAspectRatio: cross == 1 ? 2.75 : 1.85,
              children: [
                _KpiCard(
                  title: 'Valeur au prix d’achat',
                  value: formatCurrency(s.valueAtPurchasePrice),
                  icon: Icons.payments_rounded,
                  color: WarehouseUi.accentEmerald,
                ),
                _KpiCard(
                  title: 'Valeur au prix de vente',
                  value: formatCurrency(s.valueAtSalePrice),
                  icon: Icons.trending_up_rounded,
                  color: WarehouseUi.accentBlue,
                ),
                _KpiCard(
                  title: 'Références en stock',
                  value: '${s.skuCount}',
                  icon: Icons.category_rounded,
                  color: WarehouseUi.accentViolet,
                ),
                _KpiCard(
                  title: 'En alerte (≤ seuil)',
                  value: '${s.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  color: s.lowStockCount > 0
                      ? WarehouseUi.accentOrange
                      : theme.colorScheme.outline,
                ),
                _KpiCard(
                  title: 'Entrées (30 j.)',
                  value: '${s.movementsEntries30d}',
                  subtitle: 'lignes',
                  icon: Icons.south_west_rounded,
                  color: WarehouseUi.accentTeal,
                ),
                _KpiCard(
                  title: 'Sorties (30 j.)',
                  value: '${s.movementsExits30d}',
                  subtitle: 'lignes',
                  icon: Icons.north_east_rounded,
                  color: WarehouseUi.accentRose,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WarehouseUi.radiusMd),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Entrées / sorties (7 jours)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _LegendDot(
                      color: WarehouseUi.accentEmerald,
                      label: 'Entrées',
                    ),
                    _LegendDot(
                      color: WarehouseUi.accentOrange,
                      label: 'Sorties',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: s.chartDayLabels.isEmpty
                      ? Center(
                          child: Text(
                            'Pas encore de mouvements sur la période',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            barGroups: List.generate(s.chartDayLabels.length, (
                              i,
                            ) {
                              return BarChartGroupData(
                                x: i,
                                barsSpace: 4,
                                barRods: [
                                  BarChartRodData(
                                    toY: s.chartEntriesQty[i].toDouble(),
                                    color: WarehouseUi.accentEmerald,
                                    width: 10,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: s.chartExitsQty[i].toDouble(),
                                    color: WarehouseUi.accentOrange,
                                    width: 10,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i >= 0 && i < s.chartDayLabels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          s.chartDayLabels[i],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  getTitlesWidget: (v, _) => Text(
                                    v >= 1000
                                        ? '${(v / 1000).toStringAsFixed(0)}k'
                                        : v.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                            ),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onOpenShortcuts,
          icon: const Icon(Icons.local_shipping_rounded),
          label: const Text('Voir les achats fournisseurs'),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarehouseUi.radiusMd),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(subtitle!, style: theme.textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}

enum _StockFilter { all, lowOnly, okOnly }

class _StockTab extends StatefulWidget {
  const _StockTab({
    required this.lines,
    this.onEditThreshold,
    this.onAdjustStock,
  });

  final List<WarehouseStockLine> lines;
  final Future<void> Function(WarehouseStockLine line)? onEditThreshold;
  final Future<void> Function(WarehouseStockLine line)? onAdjustStock;

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  static const int _pageSize = 20;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _StockFilter _filter = _StockFilter.all;
  int _page = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const WarehouseEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Aucun stock au dépôt',
        subtitle:
            'Enregistrez une réception ou vérifiez la synchronisation. Ce stock est indépendant des boutiques.',
      );
    }
    final sorted = List<WarehouseStockLine>.from(widget.lines)
      ..sort((a, b) => a.productName.compareTo(b.productName));
    final q = _query.trim().toLowerCase();
    final filtered = sorted.where((l) {
      final keepByStatus = switch (_filter) {
        _StockFilter.all => true,
        _StockFilter.lowOnly => l.isLowStock,
        _StockFilter.okOnly => !l.isLowStock,
      };
      if (!keepByStatus) return false;
      if (q.isEmpty) return true;
      return l.productName.toLowerCase().contains(q) ||
          (l.sku ?? '').toLowerCase().contains(q);
    }).toList();
    final totalPages = filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _pageSize) + 1;
    final clampedPage = _page.clamp(0, totalPages - 1);
    final start = clampedPage * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final paged = filtered.sublist(start, end);

    final hasPagination = filtered.isNotEmpty;
    final itemCount = 1 + paged.length + (hasPagination ? 1 : 0);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Rechercher par nom ou SKU',
                ),
                onChanged: (v) => setState(() {
                  _query = v;
                  _page = 0;
                }),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tous'),
                    selected: _filter == _StockFilter.all,
                    onSelected: (_) => setState(() {
                      _filter = _StockFilter.all;
                      _page = 0;
                    }),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _filter == _StockFilter.all
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    side: BorderSide(
                      color: _filter == _StockFilter.all
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                  ),
                  ChoiceChip(
                    label: const Text('En alerte'),
                    selected: _filter == _StockFilter.lowOnly,
                    onSelected: (_) =>
                        setState(() {
                          _filter = _StockFilter.lowOnly;
                          _page = 0;
                        }),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _filter == _StockFilter.lowOnly
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer,
                    side: BorderSide(
                      color: _filter == _StockFilter.lowOnly
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    checkmarkColor: Theme.of(context).colorScheme.error,
                  ),
                  ChoiceChip(
                    label: const Text('Stock OK'),
                    selected: _filter == _StockFilter.okOnly,
                    onSelected: (_) =>
                        setState(() {
                          _filter = _StockFilter.okOnly;
                          _page = 0;
                        }),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _filter == _StockFilter.okOnly
                          ? Theme.of(context).colorScheme.onTertiaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer,
                    side: BorderSide(
                      color: _filter == _StockFilter.okOnly
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    checkmarkColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  if (_query.isNotEmpty || _filter != _StockFilter.all)
                    TextButton.icon(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _query = '';
                          _filter = _StockFilter.all;
                          _page = 0;
                        });
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Réinitialiser'),
                    ),
                ],
              ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Aucun produit ne correspond au filtre.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        }
        if (hasPagination && i == itemCount - 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _WarehousePager(
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
          );
        }
        final l = paged[i - 1];
        final threshold = l.stockMinWarehouse > 0
            ? l.stockMinWarehouse
            : l.stockMin;
        final th = l.stockMinWarehouse > 0
            ? 'Seuil magasin ${l.stockMinWarehouse}'
            : 'Seuil produit ${l.stockMin}';
        final theme = Theme.of(context);
        final sub =
            '${l.quantity} ${l.unit}${l.sku != null && l.sku!.isNotEmpty ? ' · SKU ${l.sku}' : ''} · $th';
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WarehouseUi.radiusMd),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WarehouseProductThumbnail(imageUrl: l.imageUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.productName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.2,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (widget.onAdjustStock != null)
                      IconButton(
                        tooltip: 'Ajuster le stock',
                        icon: const Icon(Icons.balance_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onAdjustStock!(l),
                      ),
                    if (widget.onEditThreshold != null)
                      IconButton(
                        tooltip: 'Seuil magasin',
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onEditThreshold!(l),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: l.isLowStock
                            ? const Color(0xFFFDECEC)
                            : const Color(0xFFEAF7EC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: l.isLowStock
                              ? const Color(0xFFF5B2B2)
                              : const Color(0xFFA8DBB0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            l.isLowStock
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                            size: 16,
                            color: l.isLowStock
                                ? const Color(0xFFB42318)
                                : const Color(0xFF1E7D34),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.isLowStock ? 'Alerte stock' : 'Stock OK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: l.isLowStock
                                  ? const Color(0xFF7A271A)
                                  : const Color(0xFF14532D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${l.quantity} / seuil ${threshold < 0 ? 0 : threshold}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: l.isLowStock
                                  ? const Color(0xFF9A3412)
                                  : const Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatCurrency(l.valueAtCost),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'PV ${formatCurrency(l.valueAtSale)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MovementsTab extends StatelessWidget {
  const _MovementsTab({
    required this.movements,
    required this.companyId,
    required this.warehouseRepo,
    required this.onRefresh,
  });

  final List<WarehouseMovement> movements;
  final String companyId;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => _MovementsTabPaged(
        movements: movements,
        companyId: companyId,
        warehouseRepo: warehouseRepo,
        onRefresh: onRefresh,
      );
}

class _MovementsTabPaged extends StatefulWidget {
  const _MovementsTabPaged({
    required this.movements,
    required this.companyId,
    required this.warehouseRepo,
    required this.onRefresh,
  });

  final List<WarehouseMovement> movements;
  final String companyId;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onRefresh;

  @override
  State<_MovementsTabPaged> createState() => _MovementsTabPagedState();
}

class _MovementsTabPagedState extends State<_MovementsTabPaged> {
  static const int _pageSize = 20;
  int _page = 0;
  /// Id du bon en cours d’annulation (un seul à la fois).
  String? _voidingInvoiceId;

  Future<void> _confirmVoidDispatchFromMovement(WarehouseMovement m) async {
    final invoiceId = m.referenceId;
    if (invoiceId == null || invoiceId.isEmpty || widget.companyId.isEmpty) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce bon de sortie ?'),
        content: const Text(
          'Le stock au dépôt sera réintégré et le bon sera supprimé. '
          'Cette action est définitive.',
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
    setState(() => _voidingInvoiceId = invoiceId);
    try {
      await widget.warehouseRepo.voidDispatchInvoice(
        companyId: widget.companyId,
        invoiceId: invoiceId,
      );
      if (!mounted) return;
      AppToast.success(context, 'Bon annulé. Stock dépôt mis à jour.');
      await widget.onRefresh();
    } catch (e, st) {
      WarehouseUi.logOp('dispatch_void_movement', e, st);
      if (mounted) AppErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _voidingInvoiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movements = widget.movements;
    if (movements.isEmpty) {
      return const WarehouseEmptyState(
        icon: Icons.sync_alt_rounded,
        title: 'Aucun mouvement',
        subtitle: 'Les entrées, sorties et ajustements apparaîtront ici.',
      );
    }
    final totalPages = ((movements.length - 1) ~/ _pageSize) + 1;
    final clampedPage = _page.clamp(0, totalPages - 1);
    final start = clampedPage * _pageSize;
    final end = (start + _pageSize).clamp(0, movements.length);
    final paged = movements.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: paged.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = paged[i];
        final dt = m.createdAt != null ? DateTime.tryParse(m.createdAt!) : null;
        final dateStr = dt != null
            ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dt.toLocal())
            : '—';
        final kindLabel = m.isEntry ? 'Entrée' : 'Sortie';
        final kindColor = m.isEntry
            ? WarehouseUi.accentEmerald
            : WarehouseUi.accentOrange;
        final refLabel = m.referenceType == 'sale'
            ? 'Vente POS'
            : m.referenceType == 'stock_transfer'
            ? 'Transfert boutique'
            : m.referenceType == 'warehouse_dispatch'
            ? 'Bon / facture dépôt'
            : m.referenceType == 'adjustment'
            ? 'Ajustement inventaire'
            : (m.referenceType == 'manual' ? 'Manuel' : m.referenceType);
        final pack =
            kWarehousePackagingLabels[m.packagingType] ?? m.packagingType;
        final unitExtra = m.unitCost != null
            ? (m.isEntry
                  ? ' · PA ${formatCurrency(m.unitCost!)}'
                  : m.referenceType == 'warehouse_dispatch'
                  ? ' · PU ${formatCurrency(m.unitCost!)}'
                  : '')
            : '';
        final line2 =
            '$dateStr · $kindLabel · ${m.quantity} u. · $pack${m.packsQuantity != 1 ? ' ×${m.packsQuantity}' : ''}';
        final line3 = '$refLabel$unitExtra';
        final canVoidBon = m.referenceType == 'warehouse_dispatch' &&
            m.referenceId != null &&
            m.referenceId!.isNotEmpty &&
            widget.companyId.isNotEmpty;
        final voidingThis = _voidingInvoiceId == m.referenceId;

              return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WarehouseUi.radiusMd),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kindColor.withValues(alpha: 0.14),
                  child: Icon(
                    m.isEntry
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: kindColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.productName ?? 'Produit',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        line2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        line3,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (canVoidBon)
                  IconButton(
                    tooltip: 'Annuler ce bon (réintègre le stock)',
                    onPressed: (_voidingInvoiceId != null && !voidingThis)
                        ? null
                        : () => _confirmVoidDispatchFromMovement(m),
                    icon: voidingThis
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.error,
                            ),
                          )
                        : Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                  ),
              ],
            ),
          ),
        );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _WarehousePager(
            page: clampedPage,
            totalPages: totalPages,
            start: start,
            end: end,
            totalItems: movements.length,
            onPrev: clampedPage > 0
                ? () => setState(() => _page = clampedPage - 1)
                : null,
            onNext: clampedPage < totalPages - 1
                ? () => setState(() => _page = clampedPage + 1)
                : null,
          ),
        ),
      ],
    );
  }
}

class _WarehousePager extends StatelessWidget {
  const _WarehousePager({
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

class _WarehouseEntryDialog extends ConsumerStatefulWidget {
  const _WarehouseEntryDialog({
    required this.companyId,
    required this.warehouseRepo,
    required this.onSuccess,
    this.onOfflineEnqueue,
  });

  final String companyId;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onSuccess;
  final Future<void> Function(Map<String, dynamic> payload)? onOfflineEnqueue;

  @override
  ConsumerState<_WarehouseEntryDialog> createState() =>
      _WarehouseEntryDialogState();
}

class _WarehouseEntryDialogState extends ConsumerState<_WarehouseEntryDialog> {
  final ProductsRepository _productsRepo = ProductsRepository();
  Product? _selected;
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _packsCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedCategoryId;
  String _packaging = 'unite';
  bool _saving = false;
  String _filter = '';
  Timer? _searchDebounce;
  bool _searching = false;

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _filter = _searchController.text.trim();
        _searching = false;
      });
    });
  }

  Future<void> _refreshProducts() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.id;
    if (uid == null) return;
    try {
      await ref.read(syncServiceV2Provider).sync(
            userId: uid,
            companyId: widget.companyId,
            storeId: null,
          );
    } catch (e, st) {
      WarehouseUi.logOp('warehouse_entry_refresh', e, st);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _packsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Prépare une nouvelle saisie sans fermer le dialogue.
  void _resetEntryForm() {
    _selected = null;
    _qtyCtrl.clear();
    _costCtrl.clear();
    _packsCtrl.text = '1';
    _notesCtrl.clear();
    _packaging = 'unite';
  }

  Future<void> _submit() async {
    final p = _selected;
    if (p == null) {
      AppToast.info(context, 'Choisissez un produit.');
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      AppToast.info(context, 'Quantité invalide (nombre entier > 0).');
      return;
    }
    final cost = double.tryParse(_costCtrl.text.trim().replaceAll(',', '.'));
    if (cost == null || cost < 0) {
      AppToast.info(context, 'Prix d’achat unitaire invalide.');
      return;
    }
    final packs =
        double.tryParse(_packsCtrl.text.trim().replaceAll(',', '.')) ?? 1;
    if (packs <= 0) {
      AppToast.info(context, 'Nombre de colis / lots invalide.');
      return;
    }
    setState(() => _saving = true);
    final shouldBackfillPurchasePrice = (p.purchasePrice <= 0) && cost > 0;
    try {
      await widget.warehouseRepo.registerManualEntry(
        companyId: widget.companyId,
        productId: p.id,
        quantity: qty,
        unitCost: cost,
        packagingType: _packaging,
        packsQuantity: packs,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (shouldBackfillPurchasePrice) {
        try {
          final updated = await _productsRepo.update(p.id, {
            'purchase_price': cost,
          });
          await ref
              .read(productsOfflineRepositoryProvider)
              .upsertProduct(updated);
        } catch (e, st) {
          WarehouseUi.logOp('manual_entry_backfill_purchase_price', e, st);
          if (mounted) {
            AppToast.info(
              context,
              "Réception enregistrée. Le prix d'achat du produit n'a pas pu être mis à jour.",
            );
          }
        }
      }
      if (!mounted) return;
      AppToast.success(context, 'Entrée enregistrée au dépôt.');
      await widget.onSuccess();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _resetEntryForm();
      });
    } catch (e, st) {
      WarehouseUi.logOp('manual_entry', e, st);
      if (widget.onOfflineEnqueue != null && ErrorMapper.isNetworkError(e)) {
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'product_id': p.id,
          'quantity': qty,
          'unit_cost': cost,
          'packaging_type': _packaging,
          'packs_quantity': packs,
          'notes': _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        });
        if (mounted) {
          AppToast.success(
            context,
            'Enregistré. Elle sera envoyée dès la prochaine connexion.',
          );
          await widget.onSuccess();
          if (!mounted) return;
          setState(() {
            _saving = false;
            _resetEntryForm();
          });
        }
      } else if (mounted) {
        AppToast.error(context, ErrorMapper.toMessage(e));
      }
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider(widget.companyId));
    final categories =
        ref.watch(categoriesStreamProvider(widget.companyId)).valueOrNull ?? [];
    final allProducts = productsAsync.valueOrNull ?? [];
    final products = allProducts
        .where((p) => p.isActive && p.isAvailableInWarehouse)
        .toList();
    final listLoading = productsAsync.isLoading && products.isEmpty;
    final listError = productsAsync.hasError ? productsAsync.error : null;

    final filtered = products
        .where((p) {
          if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
            return false;
          }
          if (_filter.isEmpty) return true;
          final q = _filter.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              (p.sku ?? '').toLowerCase().contains(q);
        })
        .take(400)
        .toList();
    final qtyPreview = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final costPreview =
        double.tryParse(_costCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final packsPreview =
        double.tryParse(_packsCtrl.text.trim().replaceAll(',', '.')) ?? 1;
    final unitPreview = _selected?.unit ?? 'unite';
    final productPreview = _selected?.name ?? 'Produit non selectionne';
    final packagingPreview =
        kWarehousePackagingLabels[_packaging] ?? _packaging;
    final estimatedTotal = qtyPreview * costPreview;

    final scheme = Theme.of(context).colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    final screenW = MediaQuery.sizeOf(context).width;
    final wide = screenW >= 900;
    final ultraMobileFooter = screenW < Breakpoints.tablet;

    Widget body;
    if (listLoading) {
      body = const Center(
        child: CircularProgressIndicator(color: PosQuickColors.orangePrincipal),
      );
    } else if (listError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            ErrorMapper.toMessage(listError),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (products.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Aucun produit pour le moment. Tirez pour actualiser ou attendez la connexion.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    } else if (wide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 65,
            child: _WarehouseEntryLeftPanel(
              searchController: _searchController,
              searching: _searching,
              categories: categories,
              selectedCategoryId: _selectedCategoryId,
              onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
              onSearchChanged: _onSearchChanged,
              filteredProducts: filtered,
              selected: _selected,
              onSelectProduct: (p) => setState(() {
                _selected = p;
                if (p.purchasePrice > 0) {
                  _costCtrl.text = p.purchasePrice.toString();
                } else {
                  _costCtrl.clear();
                }
              }),
              onRefresh: _refreshProducts,
            ),
          ),
          Expanded(
            flex: 35,
            child: _WarehouseEntryRightPanel(
              qtyCtrl: _qtyCtrl,
              costCtrl: _costCtrl,
              packsCtrl: _packsCtrl,
              notesCtrl: _notesCtrl,
              packaging: _packaging,
              onPackagingChanged: (v) => setState(() => _packaging = v ?? 'unite'),
              onFieldsChanged: () => setState(() {}),
              productPreview: productPreview,
              qtyPreview: qtyPreview,
              unitPreview: unitPreview,
              packagingPreview: packagingPreview,
              packsPreview: packsPreview,
              estimatedTotal: estimatedTotal,
            ),
          ),
        ],
      );
    } else {
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 380,
              child: _WarehouseEntryLeftPanel(
                searchController: _searchController,
                searching: _searching,
                categories: categories,
                selectedCategoryId: _selectedCategoryId,
                onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
                onSearchChanged: _onSearchChanged,
                filteredProducts: filtered,
                selected: _selected,
                onSelectProduct: (p) => setState(() {
                  _selected = p;
                  if (p.purchasePrice > 0) {
                    _costCtrl.text = p.purchasePrice.toString();
                  } else {
                    _costCtrl.clear();
                  }
                }),
                onRefresh: _refreshProducts,
                compactGrid: true,
              ),
            ),
            _WarehouseEntryRightPanel(
              qtyCtrl: _qtyCtrl,
              costCtrl: _costCtrl,
              packsCtrl: _packsCtrl,
              notesCtrl: _notesCtrl,
              packaging: _packaging,
              onPackagingChanged: (v) => setState(() => _packaging = v ?? 'unite'),
              onFieldsChanged: () => setState(() {}),
              productPreview: productPreview,
              qtyPreview: qtyPreview,
              unitPreview: unitPreview,
              packagingPreview: packagingPreview,
              packsPreview: packsPreview,
              estimatedTotal: estimatedTotal,
            ),
          ],
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 1100 : 560,
          maxHeight: maxH,
        ),
        child: SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WarehousePosQuickHeader(
                title: 'Réception au dépôt',
                subtitle: 'Comme la caisse rapide — choisissez un produit puis les quantités',
                closeEnabled: !_saving,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(child: body),
              SafeArea(
                top: false,
                child: Material(
                  color: PosQuickColors.fondSecondaire,
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: ultraMobileFooter
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                onPressed:
                                    _saving ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: PosQuickColors.bordure,
                                  ),
                                ),
                                child: const Text('Annuler'),
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: (listLoading ||
                                        listError != null ||
                                        products.isEmpty ||
                                        _saving)
                                    ? null
                                    : _submit,
                                style: FilledButton.styleFrom(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 12,
                                  ),
                                  backgroundColor:
                                      PosQuickColors.orangePrincipal,
                                  foregroundColor: Colors.white,
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Enregistrer la réception',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: PosQuickColors.bordure,
                                    ),
                                  ),
                                  child: const Text('Annuler'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: (listLoading ||
                                          listError != null ||
                                          products.isEmpty ||
                                          _saving)
                                      ? null
                                      : _submit,
                                  style: FilledButton.styleFrom(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor:
                                        PosQuickColors.orangePrincipal,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Enregistrer la réception',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zone gauche réception : recherche + chips + grille (style POS rapide).
class _WarehouseEntryLeftPanel extends StatelessWidget {
  const _WarehouseEntryLeftPanel({
    required this.searchController,
    required this.searching,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.filteredProducts,
    required this.selected,
    required this.onSelectProduct,
    required this.onRefresh,
    this.compactGrid = false,
  });

  final TextEditingController searchController;
  final bool searching;
  final List<Category> categories;
  final String? selectedCategoryId;
  final void Function(String? categoryId) onCategorySelected;
  final VoidCallback onSearchChanged;
  final List<Product> filteredProducts;
  final Product? selected;
  final void Function(Product p) onSelectProduct;
  final Future<void> Function() onRefresh;
  final bool compactGrid;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PosQuickColors.fondPrincipal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              height: 55,
              child: TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                textInputAction: TextInputAction.search,
                decoration: warehousePosQuickSearchDecoration(
                  hintText: 'Rechercher un produit (nom ou SKU)…',
                  suffixIcon: searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.search_rounded, color: PosQuickColors.orangePrincipal, size: 24),
                ),
              ),
            ),
          ),
          WarehousePosCategoryChips(
            categories: categories,
            selectedCategoryId: selectedCategoryId,
            onCategorySelected: onCategorySelected,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _WarehouseEntryProductGrid(
              products: filteredProducts,
              selected: selected,
              onSelectProduct: onSelectProduct,
              onRefresh: onRefresh,
              compact: compactGrid,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseEntryProductGrid extends StatelessWidget {
  const _WarehouseEntryProductGrid({
    required this.products,
    required this.selected,
    required this.onSelectProduct,
    required this.onRefresh,
    this.compact = false,
  });

  final List<Product> products;
  final Product? selected;
  final void Function(Product p) onSelectProduct;
  final Future<void> Function() onRefresh;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Aucun produit ne correspond à la recherche.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: PosQuickColors.textePrincipal.withValues(alpha: 0.65),
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossCount = w > 700 ? 4 : (w > 420 ? 3 : 2);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            // Grille dépôt mobile : cellules un peu plus hautes (carte image + 2 lignes de nom).
            childAspectRatio: compact ? 0.84 : 0.9,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            final sel = selected?.id == p.id;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel ? PosQuickColors.orangePrincipal : Colors.transparent,
                  width: sel ? 3 : 0,
                ),
              ),
              child: PosQuickProductCard(
                product: p,
                stock: -1,
                onTap: () => onSelectProduct(p),
              ),
            );
          },
        );
      },
    );

    if (compact) {
      return grid;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: grid,
    );
  }
}

/// Zone droite réception : formulaire sur fond gris (comme panier POS).
class _WarehouseEntryRightPanel extends StatelessWidget {
  const _WarehouseEntryRightPanel({
    required this.qtyCtrl,
    required this.costCtrl,
    required this.packsCtrl,
    required this.notesCtrl,
    required this.packaging,
    required this.onPackagingChanged,
    required this.onFieldsChanged,
    required this.productPreview,
    required this.qtyPreview,
    required this.unitPreview,
    required this.packagingPreview,
    required this.packsPreview,
    required this.estimatedTotal,
  });

  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;
  final TextEditingController packsCtrl;
  final TextEditingController notesCtrl;
  final String packaging;
  final void Function(String?) onPackagingChanged;
  final VoidCallback onFieldsChanged;
  final String productPreview;
  final int qtyPreview;
  final String unitPreview;
  final String packagingPreview;
  final double packsPreview;
  final double estimatedTotal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PosQuickColors.fondSecondaire,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Détail de la réception',
              style: TextStyle(
                color: PosQuickColors.textePrincipal,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Le prix d'achat saisi ici met aussi à jour le produit s'il était vide.",
              style: TextStyle(
                color: PosQuickColors.textePrincipal.withValues(alpha: 0.65),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    decoration: warehousePosFormFieldDecoration(
                      labelText: 'Quantité',
                      hintText: 'Ex. 120',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onFieldsChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: costCtrl,
                    decoration: warehousePosFormFieldDecoration(
                      labelText: "Prix d'achat unitaire",
                      suffixText: 'FCFA',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onFieldsChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('warehouse_entry_packaging_$packaging'),
                    initialValue: packaging,
                    decoration: warehousePosFormFieldDecoration(
                      labelText: 'Conditionnement',
                    ),
                    items: kWarehousePackagingLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      onPackagingChanged(v);
                      onFieldsChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: packsCtrl,
                    decoration: warehousePosFormFieldDecoration(
                      labelText: 'Colis / lots',
                      hintText: '1',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onFieldsChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: warehousePosFormFieldDecoration(
                labelText: 'Notes (optionnel)',
              ),
              maxLines: 2,
              onChanged: (_) => onFieldsChanged(),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PosQuickColors.fondPrincipal,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosQuickColors.bordure),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 16, color: PosQuickColors.orangePrincipal),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Résumé',
                          style: TextStyle(
                            color: PosQuickColors.textePrincipal,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    productPreview,
                    style: const TextStyle(
                      color: PosQuickColors.textePrincipal,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantité: $qtyPreview $unitPreview · Conditionnement: $packagingPreview · Colis/lots: $packsPreview',
                    style: TextStyle(
                      color: PosQuickColors.textePrincipal.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Coût total estimé : ${formatCurrency(estimatedTotal)}',
                    style: const TextStyle(
                      color: PosQuickColors.orangePrincipal,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseExitSaleDialog extends StatefulWidget {
  const _WarehouseExitSaleDialog({
    required this.companyId,
    required this.salesRepo,
    required this.warehouseRepo,
    required this.onSuccess,
    this.onStaleInventoryAfterError,
    this.onOfflineEnqueue,
  });

  final String companyId;
  final SalesRepository salesRepo;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onSuccess;
  final void Function()? onStaleInventoryAfterError;
  final Future<void> Function(Map<String, dynamic> payload)? onOfflineEnqueue;

  @override
  State<_WarehouseExitSaleDialog> createState() =>
      _WarehouseExitSaleDialogState();
}

class _WarehouseExitSaleDialogState extends State<_WarehouseExitSaleDialog> {
  List<Sale> _sales = [];
  Sale? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _loading = true;
    });
    try {
      final list = await widget.salesRepo.list(
        widget.companyId,
        status: SaleStatus.completed,
        limit: 60,
      );
      if (!mounted) return;
      setState(() {
        _sales = list;
        _loading = false;
      });
    } catch (e, st) {
      WarehouseUi.logOp('exit_sale_load_sales', e, st);
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = ErrorMapper.toMessage(e);
        });
      }
    }
  }

  Future<void> _submit() async {
    final s = _selected;
    if (s == null) {
      AppToast.info(context, 'Sélectionnez une vente.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.warehouseRepo.registerExitForSale(
        companyId: widget.companyId,
        saleId: s.id,
      );
      if (!mounted) return;
      AppToast.success(
        context,
        'Sortie magasin enregistrée pour la vente ${s.saleNumber}.',
      );
      Navigator.pop(context);
      await widget.onSuccess();
    } catch (e, st) {
      if (widget.onOfflineEnqueue != null && ErrorMapper.isNetworkError(e)) {
        AppErrorHandler.log(e, st);
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'sale_id': s.id,
        });
        if (mounted) {
          AppToast.success(
            context,
            'Enregistrée. Elle sera envoyée dès la prochaine connexion.',
          );
          Navigator.pop(context);
          await widget.onSuccess();
        }
      } else if (mounted) {
        if (shouldRecoverInventoryCachesFromRpcError(e)) {
          widget.onStaleInventoryAfterError?.call();
        }
        AppErrorHandler.show(context, e, stackTrace: st);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    return AlertDialog(
      title: const Text('Rattacher une vente au dépôt'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxH),
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : _loadError != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: scheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Flux habituel : ventes en caisse et transferts depuis ce dépôt. '
                      'Utilisez cette option seulement pour une vente déjà « complétée », si le dépôt doit couvrir les lignes. '
                      'Une vente ne peut être utilisée qu’une fois.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Sale>(
                      key: ValueKey('warehouse_exit_sale_${_selected?.id}'),
                      initialValue: _selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Vente complétée',
                        border: OutlineInputBorder(),
                      ),
                      items: _sales
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                '${s.saleNumber} · ${formatCurrency(s.total)} · ${s.store?.name ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selected = v),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving || _sales.isEmpty ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Valider la sortie'),
        ),
      ],
    );
  }
}

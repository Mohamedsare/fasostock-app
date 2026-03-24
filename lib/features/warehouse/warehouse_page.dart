import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/config/routes.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/product.dart';
import '../../data/models/sale.dart';
import '../../data/models/warehouse_movement.dart';
import '../../data/models/warehouse_stock_line.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/warehouse_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/offline_providers.dart';
import '../../providers/permissions_provider.dart';
import '../../shared/utils/format_currency.dart';
import 'warehouse_adjustment_dialog.dart';
import 'warehouse_dispatch_invoice_dialog.dart';

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

class _WarehousePageState extends ConsumerState<WarehousePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WarehouseRepository _repo = WarehouseRepository();
  final SalesRepository _salesRepo = SalesRepository();

  bool _loading = true;
  String? _error;
  String? _lastLoadedCompanyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final uid = context.read<AuthProvider>().user?.id;
    if (companyId == null) {
      setState(() {
        _loading = false;
        _error = 'Sélectionnez une entreprise.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (uid != null) {
        await ref.read(syncServiceV2Provider).sync(userId: uid, companyId: companyId, storeId: null);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (!mounted) return;
      setState(() {
        _error = ErrorMapper.toMessage(e);
        _loading = false;
      });
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
        onSuccess: _load,
        onOfflineEnqueue: (payload) async {
          await ref.read(appDatabaseProvider).enqueuePendingAction('warehouse_manual_entry', jsonEncode(payload));
        },
      ),
    );
  }

  Future<void> _openDispatchDialog() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final products = ref.read(productsStreamProvider(companyId)).valueOrNull ?? [];
    final customers = ref.read(customersStreamProvider(companyId)).valueOrNull ?? [];
    final inv = ref.read(warehouseInventoryStreamProvider(companyId)).valueOrNull ?? [];
    final whQty = {for (final l in inv) l.productId: l.quantity};
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => WarehouseDispatchInvoiceDialog(
        companyId: companyId,
        products: products,
        customers: customers,
        warehouseQuantities: whQty,
        warehouseRepo: _repo,
        onSuccess: _load,
        onOfflineEnqueue: (payload) async {
          await ref.read(appDatabaseProvider).enqueuePendingAction('warehouse_dispatch_invoice', jsonEncode(payload));
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
        onSuccess: _load,
        onOfflineEnqueue: (payload) async {
          await ref.read(appDatabaseProvider).enqueuePendingAction('warehouse_adjustment', jsonEncode(payload));
        },
      ),
    );
  }

  Future<void> _openActionsMenu() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Réception au dépôt'),
              subtitle: const Text('Arrivées, quantités, prix d’achat'),
              onTap: () => Navigator.pop(ctx, 'entry'),
            ),
            ListTile(
              leading: const Icon(Icons.category_rounded),
              title: const Text('Catalogue produits'),
              subtitle: const Text('Créer ou modifier des articles (dépôt et boutiques)'),
              onTap: () => Navigator.pop(ctx, 'products'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Transfert vers une boutique'),
              subtitle: const Text('Envoyer du stock du dépôt vers une boutique'),
              onTap: () => Navigator.pop(ctx, 'transfer'),
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale_rounded),
              title: const Text('Ventes en caisse'),
              subtitle: const Text('Nouvelles ventes en boutique'),
              onTap: () => Navigator.pop(ctx, 'sales'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Facture / bon de sortie dépôt'),
              subtitle: const Text('Sortie de produits avec document'),
              onTap: () => Navigator.pop(ctx, 'dispatch'),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Rattacher une vente déjà validée'),
              subtitle: const Text('Cas exceptionnel : sortie dépôt après coup'),
              onTap: () => Navigator.pop(ctx, 'exit'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'transfer') {
      context.go(AppRoutes.transfers);
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
          onSuccess: _load,
          onOfflineEnqueue: (payload) async {
            await ref.read(appDatabaseProvider).enqueuePendingAction('warehouse_exit_sale', jsonEncode(payload));
          },
        ),
      );
    } else if (choice == 'dispatch') {
      await _openDispatchDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    if (permissions.hasLoaded && !permissions.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Magasin')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ce module est réservé au propriétaire de l\'entreprise.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId ?? '';
    final invAsync = ref.watch(warehouseInventoryStreamProvider(companyId));
    final movAsync = ref.watch(warehouseMovementsStreamProvider(companyId));
    final inventory = invAsync.valueOrNull ?? [];
    final movements = movAsync.valueOrNull ?? [];
    final streamErr = invAsync.error ?? movAsync.error;
    final dashboard = companyId.isEmpty ? null : _repo.computeDashboardFromLists(inventory, movements);
    final listLoading = (invAsync.isLoading || movAsync.isLoading) && inventory.isEmpty && movements.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Magasin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tableau de bord', icon: Icon(Icons.dashboard_rounded)),
            Tab(text: 'Stock dépôt', icon: Icon(Icons.inventory_2_rounded)),
            Tab(text: 'Mouvements', icon: Icon(Icons.sync_alt_rounded)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (company.currentCompany != null)
            Material(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.business_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dépôt central — ${company.currentCompany!.name}',
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ce stock est celui du dépôt : il est différent du stock de chaque boutique.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading || listLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: _load, child: const Text('Réessayer')),
                            ],
                          ),
                        ),
                      )
                    : streamErr != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(ErrorMapper.toMessage(streamErr), textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  FilledButton(onPressed: _load, child: const Text('Synchroniser')),
                                ],
                              ),
                            ),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              RefreshIndicator(
                                onRefresh: _load,
                                child: _DashboardTab(
                                  summary: dashboard,
                                  onOpenShortcuts: () => context.go(AppRoutes.purchases),
                                  onOpenReception: () {
                                    _openEntryDialog();
                                  },
                                  onOpenDispatch: () {
                                    _openDispatchDialog();
                                  },
                                  onOpenProducts: () => context.go(AppRoutes.products),
                                  onOpenTransfers: () => context.go(AppRoutes.transfers),
                                ),
                              ),
                              RefreshIndicator(
                                onRefresh: _load,
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
                                onRefresh: _load,
                                child: _MovementsTab(movements: movements),
                              ),
                            ],
                          ),
          ),
        ],
      ),
      floatingActionButton: permissions.isOwner && !_loading && _error == null && streamErr == null
          ? FloatingActionButton.extended(
              onPressed: _openActionsMenu,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Gérer le dépôt'),
            )
          : null,
    );
  }

  Future<void> _showThresholdEditor(String companyId, WarehouseStockLine line) async {
    final ctrl = TextEditingController(text: line.stockMinWarehouse > 0 ? '${line.stockMinWarehouse}' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Seuil magasin — ${line.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '0 = utiliser le seuil produit (${line.stockMin}). Sinon seuil dédié au dépôt.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Seuil magasin'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final v = int.tryParse(ctrl.text.trim()) ?? 0;
    if (v < 0) return;
    try {
      await _repo.setStockMinWarehouse(companyId: companyId, productId: line.productId, minValue: v);
      if (mounted) AppToast.success(context, 'Seuil enregistré');
      await _load();
    } catch (e) {
      if (ErrorMapper.isNetworkError(e) && mounted) {
        await ref.read(appDatabaseProvider).enqueuePendingAction(
              'warehouse_set_threshold',
              jsonEncode({
                'company_id': companyId,
                'product_id': line.productId,
                'min': v,
              }),
            );
        if (!mounted) return;
        AppToast.success(context, 'Enregistré. Il sera appliqué dès la prochaine connexion.');
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tout gérer depuis le dépôt',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Réceptions, factures de sortie, catalogue, transferts vers les boutiques.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onReception,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Réception'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onInvoice,
                  icon: const Icon(Icons.receipt_long_rounded, size: 20),
                  label: const Text('Facture / sortie'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onProducts,
                  icon: const Icon(Icons.category_rounded, size: 20),
                  label: const Text('Produits'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onTransfers,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  label: const Text('Transferts'),
                ),
              ],
            ),
          ],
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
      return const Center(child: Text('Aucune donnée'));
    }

    final maxChart = [
      ...s.chartEntriesQty,
      ...s.chartExitsQty,
    ].fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxChart * 1.2).clamp(4.0, double.infinity);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text(
          'Pilotage du dépôt (à distance comme sur place)',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ici, seules les quantités du dépôt central — pas le stock des boutiques. '
          'Réapprovisionnez les boutiques par transfert ; les ventes en caisse utilisent le stock boutique.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 16),
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
            final cross = w > 560 ? 3 : 2;
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                _KpiCard(
                  title: 'Valeur au prix d’achat',
                  value: formatCurrency(s.valueAtPurchasePrice),
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF059669),
                ),
                _KpiCard(
                  title: 'Valeur au prix de vente',
                  value: formatCurrency(s.valueAtSalePrice),
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF2563EB),
                ),
                _KpiCard(
                  title: 'Références en stock',
                  value: '${s.skuCount}',
                  icon: Icons.category_rounded,
                  color: const Color(0xFF7C3AED),
                ),
                _KpiCard(
                  title: 'En alerte (≤ seuil)',
                  value: '${s.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  color: s.lowStockCount > 0 ? const Color(0xFFEA580C) : theme.colorScheme.outline,
                ),
                _KpiCard(
                  title: 'Entrées (30 j.)',
                  value: '${s.movementsEntries30d}',
                  subtitle: 'lignes',
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFF0D9488),
                ),
                _KpiCard(
                  title: 'Sorties (30 j.)',
                  value: '${s.movementsExits30d}',
                  subtitle: 'lignes',
                  icon: Icons.north_east_rounded,
                  color: const Color(0xFFDB2777),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Quantités entrées / sorties (7 derniers jours)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendDot(color: const Color(0xFF059669), label: 'Entrées'),
                    const SizedBox(width: 16),
                    _LegendDot(color: const Color(0xFFEA580C), label: 'Sorties'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: s.chartDayLabels.isEmpty
                      ? Center(
                          child: Text(
                            'Pas encore de mouvements sur la période',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            barGroups: List.generate(s.chartDayLabels.length, (i) {
                              return BarChartGroupData(
                                x: i,
                                barsSpace: 4,
                                barRods: [
                                  BarChartRodData(
                                    toY: s.chartEntriesQty[i].toDouble(),
                                    color: const Color(0xFF059669),
                                    width: 10,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                  BarChartRodData(
                                    toY: s.chartExitsQty[i].toDouble(),
                                    color: const Color(0xFFEA580C),
                                    width: 10,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
                                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
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
                                    v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toInt().toString(),
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(show: true, drawVerticalLine: false),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const Spacer(),
            Text(title, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) Text(subtitle!, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.lines, this.onEditThreshold, this.onAdjustStock});

  final List<WarehouseStockLine> lines;
  final Future<void> Function(WarehouseStockLine line)? onEditThreshold;
  final Future<void> Function(WarehouseStockLine line)? onAdjustStock;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Aucun stock au dépôt.\nCe décompte ne reflète pas le stock des boutiques.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    final sorted = List<WarehouseStockLine>.from(lines)..sort((a, b) => a.productName.compareTo(b.productName));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final l = sorted[i];
        final th = l.stockMinWarehouse > 0 ? 'Seuil magasin ${l.stockMinWarehouse}' : 'Seuil produit ${l.stockMin}';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(l.productName),
            subtitle: Text(
              '${l.quantity} ${l.unit}${l.sku != null && l.sku!.isNotEmpty ? ' · SKU ${l.sku}' : ''}\n$th',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onAdjustStock != null)
                  IconButton(
                    tooltip: 'Ajuster le stock',
                    icon: const Icon(Icons.balance_rounded),
                    onPressed: () => onAdjustStock!(l),
                  ),
                if (onEditThreshold != null)
                  IconButton(
                    tooltip: 'Seuil magasin',
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => onEditThreshold!(l),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (l.isLowStock)
                      Chip(
                        label: const Text('Alerte', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      ),
                    Text(formatCurrency(l.valueAtCost), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('PV ${formatCurrency(l.valueAtSale)}', style: Theme.of(context).textTheme.labelSmall),
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
  const _MovementsTab({required this.movements});

  final List<WarehouseMovement> movements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (movements.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Aucun mouvement enregistré.')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: movements.length,
      itemBuilder: (context, i) {
        final m = movements[i];
        final dt = m.createdAt != null ? DateTime.tryParse(m.createdAt!) : null;
        final dateStr = dt != null ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(dt.toLocal()) : '—';
        final kindLabel = m.isEntry ? 'Entrée' : 'Sortie';
        final kindColor = m.isEntry ? const Color(0xFF059669) : const Color(0xFFEA580C);
        final refLabel = m.referenceType == 'sale'
            ? 'Vente POS'
            : m.referenceType == 'stock_transfer'
                ? 'Transfert boutique'
                : m.referenceType == 'warehouse_dispatch'
                    ? 'Bon / facture dépôt'
                    : m.referenceType == 'adjustment'
                        ? 'Ajustement inventaire'
                        : (m.referenceType == 'manual' ? 'Manuel' : m.referenceType);
        final pack = kWarehousePackagingLabels[m.packagingType] ?? m.packagingType;
        final unitExtra = m.unitCost != null
            ? (m.isEntry
                ? ' · PA ${formatCurrency(m.unitCost!)}'
                : m.referenceType == 'warehouse_dispatch'
                    ? ' · PU ${formatCurrency(m.unitCost!)}'
                    : '')
            : '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: kindColor.withValues(alpha: 0.15),
              child: Icon(m.isEntry ? Icons.south_west_rounded : Icons.north_east_rounded, color: kindColor, size: 20),
            ),
            title: Text(m.productName ?? 'Produit'),
            subtitle: Text(
              '$dateStr · $kindLabel · ${m.quantity} u. · $pack'
              '${m.packsQuantity != 1 ? ' ×${m.packsQuantity}' : ''}'
              '\n$refLabel$unitExtra',
              style: theme.textTheme.bodySmall,
            ),
            isThreeLine: true,
          ),
        );
      },
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
  ConsumerState<_WarehouseEntryDialog> createState() => _WarehouseEntryDialogState();
}

class _WarehouseEntryDialogState extends ConsumerState<_WarehouseEntryDialog> {
  Product? _selected;
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _packsCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  String _packaging = 'unite';
  bool _saving = false;
  String _filter = '';

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _packsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
    final packs = double.tryParse(_packsCtrl.text.trim().replaceAll(',', '.')) ?? 1;
    if (packs <= 0) {
      AppToast.info(context, 'Nombre de colis / lots invalide.');
      return;
    }
    setState(() => _saving = true);
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
      if (!mounted) return;
      AppToast.success(context, 'Entrée enregistrée au dépôt.');
      Navigator.pop(context);
      await widget.onSuccess();
    } catch (e) {
      if (widget.onOfflineEnqueue != null && ErrorMapper.isNetworkError(e)) {
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'product_id': p.id,
          'quantity': qty,
          'unit_cost': cost,
          'packaging_type': _packaging,
          'packs_quantity': packs,
          'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        });
        if (mounted) {
          AppToast.success(context, 'Enregistré. Elle sera envoyée dès la prochaine connexion.');
          Navigator.pop(context);
          await widget.onSuccess();
        }
      } else if (mounted) {
        AppToast.error(context, ErrorMapper.toMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider(widget.companyId));
    final allProducts = productsAsync.valueOrNull ?? [];
    final products = allProducts.where((p) => p.isActive && p.isAvailableInWarehouse).toList();
    final listLoading = productsAsync.isLoading && products.isEmpty;
    final listError = productsAsync.hasError ? productsAsync.error : null;

    final filtered = products
        .where((p) {
          if (_filter.isEmpty) return true;
          final q = _filter.toLowerCase();
          return p.name.toLowerCase().contains(q) || (p.sku ?? '').toLowerCase().contains(q);
        })
        .take(400)
        .toList();

    return AlertDialog(
      title: const Text('Entrée au dépôt'),
      content: SizedBox(
        width: 420,
        child: listLoading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : listError != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      ErrorMapper.toMessage(listError),
                      textAlign: TextAlign.center,
                    ),
                  )
                : products.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucun produit pour l’instant. Touchez « Actualiser » sur cet écran lorsque la connexion est disponible.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                      decoration: const InputDecoration(
                        labelText: 'Rechercher un produit',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Aucun produit actif ne correspond à la recherche.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    else
                      DropdownButtonFormField<Product>(
                        value: _selected != null && filtered.contains(_selected!) ? _selected : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Produit'),
                        items: filtered
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p.name}${p.sku != null && p.sku!.isNotEmpty ? ' (${p.sku})' : ''}', overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selected = v;
                          if (v != null && _costCtrl.text.isEmpty) {
                            _costCtrl.text = v.purchasePrice.toString();
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantité (unités)',
                        hintText: 'Ex. 120',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _costCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prix d’achat unitaire',
                        suffixText: 'FCFA',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _packaging,
                      decoration: const InputDecoration(labelText: 'Conditionnement'),
                      items: kWarehousePackagingLabels.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _packaging = v ?? 'unite'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _packsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de colis / lots (info)',
                        hintText: '1',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 8),
                            TextField(
                              controller: _notesCtrl,
                              decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: (listLoading || listError != null || products.isEmpty || _saving) ? null : _submit,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _WarehouseExitSaleDialog extends StatefulWidget {
  const _WarehouseExitSaleDialog({
    required this.companyId,
    required this.salesRepo,
    required this.warehouseRepo,
    required this.onSuccess,
    this.onOfflineEnqueue,
  });

  final String companyId;
  final SalesRepository salesRepo;
  final WarehouseRepository warehouseRepo;
  final Future<void> Function() onSuccess;
  final Future<void> Function(Map<String, dynamic> payload)? onOfflineEnqueue;

  @override
  State<_WarehouseExitSaleDialog> createState() => _WarehouseExitSaleDialogState();
}

class _WarehouseExitSaleDialogState extends State<_WarehouseExitSaleDialog> {
  List<Sale> _sales = [];
  Sale? _selected;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      AppErrorHandler.log(e, st);
      if (mounted) setState(() => _loading = false);
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
      await widget.warehouseRepo.registerExitForSale(companyId: widget.companyId, saleId: s.id);
      if (!mounted) return;
      AppToast.success(context, 'Sortie magasin enregistrée pour la vente ${s.saleNumber}.');
      Navigator.pop(context);
      await widget.onSuccess();
    } catch (e) {
      if (widget.onOfflineEnqueue != null && ErrorMapper.isNetworkError(e)) {
        await widget.onOfflineEnqueue!({
          'company_id': widget.companyId,
          'sale_id': s.id,
        });
        if (mounted) {
          AppToast.success(context, 'Enregistrée. Elle sera envoyée dès la prochaine connexion.');
          Navigator.pop(context);
          await widget.onSuccess();
        }
      } else if (mounted) {
        AppToast.error(context, ErrorMapper.toMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rattacher le dépôt à une vente passée'),
      content: SizedBox(
        width: 400,
        child: _loading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Le flux habituel : les nouvelles ventes en caisse (boutique) et les transferts depuis ce dépôt. '
                    'Utilisez cette option seulement pour enregistrer une sortie dépôt sur une vente déjà au statut « complété », '
                    'si le stock dépôt doit couvrir les lignes de cette vente. Chaque vente ne peut être utilisée qu’une fois.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Sale>(
                    value: _selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Vente complétée'),
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
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _saving || _sales.isEmpty ? null : _submit, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Valider la sortie')),
      ],
    );
  }
}

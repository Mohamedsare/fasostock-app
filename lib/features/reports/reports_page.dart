import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/config/routes.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/constants/permissions.dart';
import '../../../data/models/reports.dart';
import '../../../data/models/company_member.dart';
import '../../../data/models/product.dart';
import '../../../data/models/category.dart';
import '../../../data/repositories/reports_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../../../shared/utils/share_csv.dart';
import '../../../shared/utils/save_bytes_file.dart';

/// Page Rapports — offline-first : lecture Drift (même source que dashboard), sync + Realtime via tables locales,
/// rafraîchissement comme le dashboard ([dashboardDataChangeTriggerStreamProvider]).
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String _period = 'week'; // today | week | month
  String? _cashierUserId;
  String? _productId;
  String? _categoryId;
  late String _fromDate;
  late String _toDate;

  SalesKpis? _salesKpis;
  StockAlerts? _stockAlerts;
  PurchasesSummary _purchasesSummary = const PurchasesSummary(); // conservé (déjà affiché)
  StockValue _stockValue = const StockValue(); // conservé (déjà affiché)
  bool _loading = true;
  String? _error;
  Timer? _reportsRefreshDebounce;

  @override
  void dispose() {
    _reportsRefreshDebounce?.cancel();
    super.dispose();
  }

  void _scheduleReportsRefresh() {
    _reportsRefreshDebounce?.cancel();
    _reportsRefreshDebounce = Timer(const Duration(milliseconds: 800), () {
      _reportsRefreshDebounce = null;
      if (mounted) _loadFromOffline(silent: true);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final range = getDefaultDateRange(_period);
      _fromDate = range.from;
      _toDate = range.to;
      _loadCompaniesIfNeeded();
      _loadFromOffline();
      _runSyncThenRefresh();
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

  Future<void> _runSyncThenRefresh() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid == null || company.currentCompanyId == null) return;
    try {
      final result = await ref.read(syncServiceV2Provider).sync(
        userId: uid,
        companyId: company.currentCompanyId,
        storeId: company.currentStoreId,
      );
      if (mounted && result.errors > 0) {
        AppToast.error(context, 'Certaines données n\'ont pas pu être synchronisées. Réessayez plus tard.');
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.show(context, e, fallback: 'Synchronisation échouée. Les données locales restent affichées.');
      }
    }
    if (mounted) _loadFromOffline();
  }

  /// **Flux filtres → données**
  /// - [getSalesKpis] : `_fromDate` / `_toDate`, `storeId`, `_cashierUserId`, `_productId`, `_categoryId`
  ///   → cartes **ventes** (hors achats/stock), **histogramme**, **camembert**, top produits.
  /// - [getDashboardData] : mêmes dates + boutique **sans** caissier/produit/catégorie
  ///   → cartes **Achats** et **Valeur stock** (vue globale période, pas filtrée comme les ventes).
  /// - [getStockAlerts] : boutique + dates → rapport stock / courbe mouvements (hors filtres vente).
  Future<void> _loadFromOffline({bool silent = false}) async {
    final company = context.read<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    if (companyId == null) {
      setState(() => _loading = false);
      return;
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final salesRepo = ref.read(reportsOfflineRepositoryProvider);
      final salesKpis = await salesRepo.getSalesKpis(
        companyId: companyId,
        storeId: storeId,
        cashierUserId: _cashierUserId,
        productId: _productId,
        categoryId: _categoryId,
        fromDate: _fromDate,
        toDate: _toDate,
        topLimit: 10,
      );

      // Reuse dashboard offline repo for purchases + stock value (déjà en place).
      final dashboardRepo = ref.read(dashboardOfflineRepositoryProvider);
      final dashboardData = await dashboardRepo.getDashboardData(
        companyId: companyId,
        storeId: storeId,
        fromDate: _fromDate,
        toDate: _toDate,
        selectedDay: _fromDate,
        topProductsLimit: 10,
      );

      // Stock report requires a store — if none selected, skip (UI will ask to pick a store).
      StockAlerts? stockAlerts;
      if (storeId != null && storeId.isNotEmpty) {
        stockAlerts = await salesRepo.getStockAlerts(
          companyId: companyId,
          storeId: storeId,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      }
      if (mounted) {
        setState(() {
          _salesKpis = salesKpis;
          _stockAlerts = stockAlerts;
          _purchasesSummary = dashboardData.purchasesSummary;
          _stockValue = dashboardData.stockValue;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final message = AppErrorHandler.toUserMessage(e, fallback: 'Impossible de charger les rapports. Réessayez.');
        setState(() {
          _error = message.isNotEmpty ? message : 'Une erreur s\'est produite.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Rapports')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Rapports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
                Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(company.loadError!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
      );
    }
    if (companyId == null) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Rapports')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Rapports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Sélectionnez une entreprise pour afficher les rapports.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!permissions.hasLoaded) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Rapports')) : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final canViewReports = permissions.hasPermission(Permissions.reportsViewGlobal) ||
        permissions.hasPermission(Permissions.reportsViewStore);
    if (!canViewReports) {
      return Scaffold(
        appBar: isWide ? AppBar(title: const Text('Rapports')) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isWide) ...[
                  Text(
                    'Rapports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildNoAccessCard(context),
              ],
            ),
          ),
        ),
      );
    }

    // Même scénario que le dashboard : entreprise OK mais pas encore de chargement terminé
    // → évite KPI/graphiques « vides » (tout à 0) sans feedback.
    if (_salesKpis == null && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _salesKpis == null && !_loading) _loadFromOffline();
      });
    }

    final fromFormatted = _formatDate(_fromDate);
    final toFormatted = _formatDate(_toDate);
    final currentCompany = company.currentCompany;
    final currentStore = company.currentStore;
    final description = currentCompany != null
        ? 'Tableau de bord — ${currentCompany.name}${currentStore != null ? ' · ${currentStore.name}' : ''}'
        : 'Rapports';

    ref.listen(dashboardDataChangeTriggerStreamProvider(companyId), (_, next) {
      next.whenOrNull(data: (_) => _scheduleReportsRefresh());
    });

    return Scaffold(
      appBar: null,
      body: RefreshIndicator(
        onRefresh: _runSyncThenRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 20,
            vertical: isWide ? 28 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isWide, description),
              const SizedBox(height: 24),
              if (_error != null) ...[
                _buildErrorCard(context),
                const SizedBox(height: 24),
              ],
              _buildFiltersCard(context, companyId, company, fromFormatted, toFormatted),
              const SizedBox(height: 24),
              if (_loading || (_salesKpis == null && _error == null))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                const SizedBox.shrink()
              else ...[
                _buildKpiGrid(context),
                const SizedBox(height: 24),
                _buildChartCard(context),
                const SizedBox(height: 24),
                _buildCategoriesPieCard(context),
                const SizedBox(height: 24),
                _buildTopProductsCard(context),
                const SizedBox(height: 24),
                _buildStockReportCard(context),
                const SizedBox(height: 24),
                _buildExportCard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccessCard(BuildContext context) {
    final theme = Theme.of(context);
    final permissions = context.watch<PermissionsProvider>();

    final requiredLabels = <String>[
      if (!permissions.hasPermission(Permissions.reportsViewGlobal))
        Permissions.labels[Permissions.reportsViewGlobal] ?? 'Voir les rapports (global)',
      if (!permissions.hasPermission(Permissions.reportsViewStore))
        Permissions.labels[Permissions.reportsViewStore] ?? 'Voir les rapports (boutique)',
    ];
    final requiredText = requiredLabels.isEmpty ? 'Voir les rapports' : requiredLabels.join(' + ');

    final fallbackRoute = () {
      final canSales = permissions.hasPermission(Permissions.salesView) ||
          permissions.hasPermission(Permissions.salesCreate) ||
          permissions.hasPermission(Permissions.salesInvoiceA4);
      if (canSales) return AppRoutes.sales;

      final canProducts = permissions.hasPermission(Permissions.productsView) ||
          permissions.hasPermission(Permissions.productsCreate) ||
          permissions.hasPermission(Permissions.productsUpdate) ||
          permissions.hasPermission(Permissions.productsDelete);
      if (canProducts) return AppRoutes.products;

      final canStock = permissions.hasPermission(Permissions.stockView) ||
          permissions.hasPermission(Permissions.stockAdjust) ||
          permissions.hasPermission(Permissions.stockTransfer);
      if (canStock) return permissions.isCashier ? AppRoutes.stockCashier : AppRoutes.inventory;

      final canCustomers = permissions.hasPermission(Permissions.customersView) ||
          permissions.hasPermission(Permissions.customersManage);
      if (canCustomers) return AppRoutes.customers;

      final canStores = permissions.hasPermission(Permissions.storesView) ||
          permissions.hasPermission(Permissions.storesCreate);
      if (canStores) return AppRoutes.stores;

      return AppRoutes.settings;
    }();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Icon(Icons.lock_person_rounded, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 14),
              Text(
              'Accès restreint',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Vous n\'avez pas les permissions nécessaires pour afficher les rapports.',
                textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Text(
              'Droit requis : $requiredText',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go(fallbackRoute);
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return DateFormat('dd MMM yyyy', 'fr_FR').format(d);
  }

  Widget _buildHeader(BuildContext context, bool isWide, String description) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rapports',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rapports',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error ?? '',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard(
    BuildContext context,
    String companyId,
    CompanyProvider company,
    String fromFormatted,
    String toFormatted,
  ) {
    final theme = Theme.of(context);
    final stores = company.stores;
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final membersAsync = ref.watch(companyMembersStreamProvider(companyId));
    final productsAsync = ref.watch(productsStreamProvider(companyId));
    final categoriesAsync = ref.watch(categoriesStreamProvider(companyId));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(
                          'Aujourd\'hui',
                          style: TextStyle(
                            color: _period == 'today' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: _period == 'today' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _period == 'today',
                        onSelected: (_) => setState(() {
                          _period = 'today';
                          final range = getDefaultDateRange(_period);
                          _fromDate = range.from;
                          _toDate = range.to;
                          _loadFromOffline();
                        }),
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: theme.colorScheme.primary,
                      ),
                      FilterChip(
                        label: Text(
                          'Cette semaine',
                          style: TextStyle(
                            color: _period == 'week' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: _period == 'week' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _period == 'week',
                        onSelected: (_) => setState(() {
                          _period = 'week';
                          final range = getDefaultDateRange(_period);
                          _fromDate = range.from;
                          _toDate = range.to;
                          _loadFromOffline();
                        }),
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: theme.colorScheme.primary,
                      ),
                      FilterChip(
                        label: Text(
                          'Ce mois',
                          style: TextStyle(
                            color: _period == 'month' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: _period == 'month' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _period == 'month',
                        onSelected: (_) => setState(() {
                          _period = 'month';
                          final range = getDefaultDateRange(_period);
                          _fromDate = range.from;
                          _toDate = range.to;
                          _loadFromOffline();
                        }),
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDateRangeRow(context, theme),
                  if (stores.length > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: company.currentStoreId != null && stores.any((s) => s.id == company.currentStoreId)
                          ? company.currentStoreId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Boutique',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Toutes les boutiques')),
                        ...stores.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (id) {
                        company.setCurrentStoreId(id);
                        _loadFromOffline();
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildUserProductCategoryFilters(theme, membersAsync, productsAsync, categoriesAsync),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        '$fromFormatted — $toFormatted',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ligne 1: période + dates + boutique (responsive via Wrap)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final dateWidth = w >= 1100 ? 520.0 : (w >= 900 ? 440.0 : 380.0);
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(
                          'Aujourd\'hui',
                          style: TextStyle(
                            color: _period == 'today' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: _period == 'today' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _period == 'today',
                        onSelected: (_) => setState(() {
                          _period = 'today';
                                  final range = getDefaultDateRange(_period);
                                  _fromDate = range.from;
                                  _toDate = range.to;
                          _loadFromOffline();
                        }),
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: theme.colorScheme.primary,
                      ),
                      FilterChip(
                        label: Text(
                          'Cette semaine',
                          style: TextStyle(
                            color: _period == 'week' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: _period == 'week' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _period == 'week',
                        onSelected: (_) => setState(() {
                          _period = 'week';
                                  final range = getDefaultDateRange(_period);
                                  _fromDate = range.from;
                                  _toDate = range.to;
                          _loadFromOffline();
                        }),
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: theme.colorScheme.primary,
                      ),
                      FilterChip(
                        label: Text(
                          'Ce mois',
                          style: TextStyle(
                            color: _period == 'month' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: _period == 'month' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _period == 'month',
                        onSelected: (_) => setState(() {
                          _period = 'month';
                                  final range = getDefaultDateRange(_period);
                                  _fromDate = range.from;
                                  _toDate = range.to;
                          _loadFromOffline();
                        }),
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                          SizedBox(
                            width: dateWidth,
                            child: _buildDateRangeRow(context, theme, compact: true),
                          ),
                  if (stores.length > 1)
                    SizedBox(
                              width: 220,
                      child: DropdownButtonFormField<String?>(
                        initialValue: company.currentStoreId != null && stores.any((s) => s.id == company.currentStoreId)
                            ? company.currentStoreId
                            : null,
                        decoration: InputDecoration(
                                  labelText: 'Boutique',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Toutes les boutiques')),
                          ...stores.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (id) {
                          company.setCurrentStoreId(id);
                          _loadFromOffline();
                        },
                      ),
                    ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Ligne 2: caissier / produit / catégorie + reset (wrap si besoin)
                  Row(
                    children: [
                      Expanded(
                        child: _buildUserProductCategoryFilters(
                          theme,
                          membersAsync,
                          productsAsync,
                          categoriesAsync,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDateRangeRow(BuildContext context, ThemeData theme, {bool compact = false}) {
    final fromParsed = DateTime.tryParse(_fromDate);
    final toParsed = DateTime.tryParse(_toDate);
    Future<void> pickFrom() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: fromParsed ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked == null || !mounted) return;
      setState(() {
        _fromDate = DateFormat('yyyy-MM-dd').format(picked);
        if (DateTime.tryParse(_toDate) != null && picked.isAfter(DateTime.parse(_toDate))) {
          _toDate = _fromDate;
        }
        _loadFromOffline();
      });
    }

    Future<void> pickTo() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: toParsed ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked == null || !mounted) return;
      setState(() {
        _toDate = DateFormat('yyyy-MM-dd').format(picked);
        if (DateTime.tryParse(_fromDate) != null && picked.isBefore(DateTime.parse(_fromDate))) {
          _fromDate = _toDate;
        }
        _loadFromOffline();
      });
    }

    final btnStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: pickFrom,
          style: btnStyle,
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text('Du $_fromDate'),
        ),
        OutlinedButton.icon(
          onPressed: pickTo,
          style: btnStyle,
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text('Au $_toDate'),
        ),
                  Text(
          '(${_formatDate(_fromDate)} — ${_formatDate(_toDate)})',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
    );
  }

  Widget _buildUserProductCategoryFilters(
    ThemeData theme,
    AsyncValue<List<CompanyMember>> membersAsync,
    AsyncValue<List<Product>> productsAsync,
    AsyncValue<List<Category>> categoriesAsync, {
    bool compact = false,
  }) {
    final members = membersAsync.valueOrNull ?? const [];
    final products = productsAsync.valueOrNull ?? const [];
    final categories = categoriesAsync.valueOrNull ?? const [];

    final decoration = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

    Widget drop<T>({
      required String hint,
      required T? value,
      required List<DropdownMenuItem<T?>> items,
      required void Function(T?) onChanged,
      double? width,
    }) {
      return SizedBox(
        width: width,
        child: DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          decoration: decoration.copyWith(hintText: hint),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(hint, overflow: TextOverflow.ellipsis)),
            ...items,
          ],
          onChanged: (v) => setState(() {
            onChanged(v);
            _loadFromOffline();
          }),
        ),
      );
    }

    final memberItems = members
        .map((m) => DropdownMenuItem<String?>(
              value: m.userId,
              child: Text(m.profile?.fullName ?? m.email ?? '—', overflow: TextOverflow.ellipsis),
            ))
        .toList();

    final productItems = products
        .map((p) => DropdownMenuItem<String?>(
              value: p.id,
              child: Text(p.name, overflow: TextOverflow.ellipsis),
            ))
        .toList();

    final categoryItems = categories
        .map((c) => DropdownMenuItem<String?>(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            ))
        .toList();

    if (compact) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          drop<String>(hint: 'Caissier (tous)', value: _cashierUserId, items: memberItems, onChanged: (v) => _cashierUserId = v, width: 220),
          drop<String>(hint: 'Produit (tous)', value: _productId, items: productItems, onChanged: (v) => _productId = v, width: 240),
          drop<String>(hint: 'Catégorie (toutes)', value: _categoryId, items: categoryItems, onChanged: (v) => _categoryId = v, width: 220),
          TextButton(
            onPressed: () => setState(() {
              _cashierUserId = null;
              _productId = null;
              _categoryId = null;
              _loadFromOffline();
            }),
            child: const Text('Réinitialiser'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        drop<String>(hint: 'Caissier (tous)', value: _cashierUserId, items: memberItems, onChanged: (v) => _cashierUserId = v),
        const SizedBox(height: 10),
        drop<String>(hint: 'Produit (tous)', value: _productId, items: productItems, onChanged: (v) => _productId = v),
        const SizedBox(height: 10),
        drop<String>(hint: 'Catégorie (toutes)', value: _categoryId, items: categoryItems, onChanged: (v) => _categoryId = v),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() {
              _cashierUserId = null;
              _productId = null;
              _categoryId = null;
              _loadFromOffline();
            }),
            child: const Text('Réinitialiser filtres'),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(BuildContext context) {
    final theme = Theme.of(context);
    final s = _salesKpis?.salesSummary ?? const SalesSummary();
    final ticketAverage = _salesKpis?.ticketAverage ?? 0.0;
    final marginRate = s.totalAmount > 0
        ? ((s.margin / s.totalAmount) * 100).toStringAsFixed(1)
        : '0';
    final storeId = context.read<CompanyProvider>().currentStoreId;
    final stockSubtitle = storeId != null
        ? '${_stockValue.productCount} produits'
        : '—';

    final kpis = [
      _KpiData('Chiffre d\'affaires', formatCurrency(s.totalAmount), Icons.trending_up_rounded, theme.colorScheme.primary, accentBorder: true),
      _KpiData('Ventes', '${s.count}', Icons.shopping_cart_rounded, const Color(0xFF059669)),
      _KpiData('Ticket moyen', formatCurrency(ticketAverage), Icons.receipt_long_rounded, const Color(0xFF0EA5E9)),
      _KpiData('Produits vendus', '${s.itemsSold}', Icons.inventory_2_rounded, const Color(0xFF2563EB)),
      _KpiData('Marge', formatCurrency(s.margin), Icons.percent_rounded, const Color(0xFF059669), subtitle: 'Taux: $marginRate%'),
      _KpiData('Achats', formatCurrency(_purchasesSummary.totalAmount), Icons.local_shipping_rounded, const Color(0xFFD97706), subtitle: '${_purchasesSummary.count} commandes'),
      _KpiData('Valeur stock', formatCurrency(_stockValue.totalValue), Icons.warehouse_rounded, const Color(0xFF7C3AED), subtitle: stockSubtitle),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossCount = w > 900 ? 3 : (w > 600 ? 2 : 2);
        final aspectRatio = w < 400 ? 1.1 : (w < 600 ? 1.2 : 1.35);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: aspectRatio,
          children: kpis.map((k) => _buildKpiCard(theme, k)).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(ThemeData theme, _KpiData k) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: k.accentBorder
            ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 2)
            : BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    k.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: k.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(k.icon, size: 20, color: k.color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                k.value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: k.color == const Color(0xFF059669) ? k.color : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (k.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                k.subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context) {
    final theme = Theme.of(context);
    final salesByDay = _salesKpis?.salesByDay ?? const <SalesByDay>[];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Chiffre d\'affaires par jour',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: salesByDay.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune vente sur la période',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (salesByDay.map((e) => e.total).reduce((a, b) => a > b ? a : b) * 1.15).clamp(1.0, double.infinity),
                        barGroups: salesByDay.asMap().entries.map((e) => BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.total,
                              color: theme.colorScheme.primary,
                              width: (salesByDay.length > 14 ? 6 : 12).toDouble(),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                          showingTooltipIndicators: [0],
                        )).toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: (salesByDay.length / 8).clamp(1.0, 31.0),
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i >= 0 && i < salesByDay.length) {
                                  final date = salesByDay[i].date;
                                  final parsed = DateTime.tryParse(date);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      parsed != null ? DateFormat('dd/MM', 'fr_FR').format(parsed) : date.length >= 10 ? date.substring(5) : date,
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
                              reservedSize: 44,
                              getTitlesWidget: (v, _) => Text(
                                v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(color: theme.dividerColor.withValues(alpha: 0.4), strokeWidth: 1),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
                            tooltipRoundedRadius: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final e = salesByDay[group.x];
                              final style = (theme.textTheme.bodySmall ?? theme.textTheme.bodyMedium)?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle();
                              return BarTooltipItem(formatCurrency(e.total), style);
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsCard(BuildContext context) {
    final theme = Theme.of(context);
    final topProducts = _salesKpis?.topProducts ?? const <TopProduct>[];
    final leastProducts = _salesKpis?.leastProducts ?? const <TopProduct>[];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Text(
                  'Top 10 produits vendus',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${topProducts.length} produits',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (topProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Aucune vente sur la période',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                columns: const [
                  DataColumn(label: Text('Produit')),
                  DataColumn(label: Text('Qté vendue'), numeric: true),
                  DataColumn(label: Text('CA'), numeric: true),
                  DataColumn(label: Text('Marge'), numeric: true),
                  DataColumn(label: Text('Rang')),
                ],
                rows: List.generate(topProducts.length, (i) {
                  final p = topProducts[i];
                  return DataRow(
                    cells: [
                      DataCell(Text(p.productName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DataCell(Text('${p.quantitySold}', textAlign: TextAlign.right)),
                      DataCell(Text(formatCurrency(p.revenue), textAlign: TextAlign.right)),
                      DataCell(Text(formatCurrency(p.margin), textAlign: TextAlign.right, style: TextStyle(color: Colors.green.shade700))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: i < 3 ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5) : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: i < 3 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )),
                    ],
                  );
                }),
              ),
            ),
          if (leastProducts.isNotEmpty) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Produits les moins vendus (période)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            ...leastProducts.take(5).map((p) => ListTile(
                  dense: true,
                  title: Text(p.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${p.quantitySold} vendu(s)'),
                  trailing: Text(formatCurrency(p.revenue), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesPieCard(BuildContext context) {
    final theme = Theme.of(context);
    final data = _salesKpis?.salesByCategory ?? const <CategorySales>[];
    final total = data.fold<double>(0, (s, e) => s + e.revenue);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Ventes par catégorie', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            if (data.isEmpty || total <= 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text('Aucune donnée sur la période', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 560;
                  final colors = [
                    theme.colorScheme.primary,
                    const Color(0xFF059669),
                    const Color(0xFF2563EB),
                    const Color(0xFFD97706),
                    const Color(0xFF7C3AED),
                    const Color(0xFFDC2626),
                    const Color(0xFF0EA5E9),
                    const Color(0xFF64748B),
                    const Color(0xFFEA580C),
                    const Color(0xFF16A34A),
                    const Color(0xFF1D4ED8),
                    const Color(0xFF9333EA),
                  ];
                  final sections = data.asMap().entries.map((e) {
                    final i = e.key;
                    final v = e.value;
                    final percent = total > 0 ? (v.revenue / total) * 100 : 0;
                    return PieChartSectionData(
                      value: v.revenue <= 0 ? 0 : v.revenue,
                      color: colors[i % colors.length],
                      radius: 56,
                      title: percent >= 12 ? '${percent.toStringAsFixed(0)}%' : '',
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    );
                  }).toList();

                  final legend = Column(
                    children: data.asMap().entries.map((e) {
                      final i = e.key;
                      final v = e.value;
                      final percent = total > 0 ? (v.revenue / total) * 100 : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(v.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('${percent.toStringAsFixed(1)}%', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(width: 10),
                            Text(formatCurrency(v.revenue), style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 220, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40))),
                        const SizedBox(height: 12),
                        legend,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 260, height: 220, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 45))),
                      const SizedBox(width: 20),
                      Expanded(child: legend),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockReportCard(BuildContext context) {
    final theme = Theme.of(context);
    final company = context.watch<CompanyProvider>();
    final storeName = company.currentStore?.name;
    final s = _stockAlerts;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warehouse_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rapport de stock${storeName != null ? ' — $storeName' : ''}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (company.currentStoreId == null || company.currentStoreId!.isEmpty)
              Text(
                'Sélectionnez une boutique pour voir le stock (filtres).',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else if (s == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: constraints.maxWidth < 420 ? 1.6 : 2.2,
                    children: [
                      _miniStat(theme, 'Produits en stock', '${s.currentStockCount}', Icons.inventory_2_rounded, const Color(0xFF2563EB)),
                      _miniStat(theme, 'Rupture', '${s.outOfStock.length}', Icons.close_rounded, const Color(0xFFDC2626)),
                      _miniStat(theme, 'Stock faible', '${s.lowStock.length}', Icons.warning_amber_rounded, const Color(0xFFD97706)),
                      _miniStat(theme, 'Entrées', '${s.entries}', Icons.arrow_downward_rounded, const Color(0xFF059669)),
                      _miniStat(theme, 'Sorties', '${s.exits}', Icons.arrow_upward_rounded, const Color(0xFFDC2626)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (s.byDayNet.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      titlesData: const FlTitlesData(show: false),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: theme.dividerColor.withValues(alpha: 0.4), strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: theme.colorScheme.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.12)),
                          spots: s.byDayNet.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.netQuantity.toDouble())).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              if (s.outOfStock.isNotEmpty || s.lowStock.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Alertes stock', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...s.outOfStock.take(5).map((p) => ListTile(
                      dense: true,
                      leading: Icon(Icons.close_rounded, color: theme.colorScheme.error),
                      title: Text(p.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Rupture · seuil ${p.threshold}'),
                      trailing: Text('${p.quantity}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    )),
                ...s.lowStock.take(5).map((p) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                      title: Text(p.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Stock faible · seuil ${p.threshold}'),
                      trailing: Text('${p.quantity}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = _loading || _salesKpis == null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Export', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: disabled ? null : () => _exportPdf(context),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Exporter PDF'),
                ),
                FilledButton.tonalIcon(
                  onPressed: disabled ? null : () => _exportExcel(context),
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('Exporter Excel'),
                ),
                OutlinedButton.icon(
                  onPressed: disabled ? null : () => _exportCsv(context),
                  icon: const Icon(Icons.description_rounded),
                  label: const Text('Enregistrer CSV'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Offline: les exports utilisent les données locales (Drift). La synchronisation met à jour ces chiffres dès que le réseau revient.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final sales = _salesKpis;
    if (sales == null) return;
    final company = context.read<CompanyProvider>();
    final storeName = company.currentStore?.name ?? '';
    final lines = <List<String>>[];

    lines.add(['Rapport FasoStock']);
    lines.add(['Période', _fromDate, _toDate]);
    if (storeName.isNotEmpty) lines.add(['Boutique', storeName]);
    lines.add([]);
    lines.add(['KPIs']);
    lines.add(['Chiffre d\'affaires', sales.salesSummary.totalAmount.toStringAsFixed(2)]);
    lines.add(['Nombre de ventes', '${sales.salesSummary.count}']);
    lines.add(['Ticket moyen', sales.ticketAverage.toStringAsFixed(2)]);
    lines.add(['Articles vendus', '${sales.salesSummary.itemsSold}']);
    lines.add(['Marge', sales.salesSummary.margin.toStringAsFixed(2)]);
    lines.add([]);

    lines.add(['Ventes par catégorie', 'CA', 'Qté']);
    for (final c in sales.salesByCategory) {
      lines.add([c.categoryName, c.revenue.toStringAsFixed(2), '${c.quantity}']);
    }
    lines.add([]);

    lines.add(['Top produits', 'Qté', 'CA', 'Marge']);
    for (final p in sales.topProducts) {
      lines.add([p.productName, '${p.quantitySold}', p.revenue.toStringAsFixed(2), p.margin.toStringAsFixed(2)]);
    }
    lines.add([]);

    if (_stockAlerts != null) {
      lines.add(['Stock - Ruptures', 'Qté', 'Seuil']);
      for (final p in _stockAlerts!.outOfStock) {
        lines.add([p.productName, '${p.quantity}', '${p.threshold}']);
      }
      lines.add([]);
      lines.add(['Stock - Faibles', 'Qté', 'Seuil']);
      for (final p in _stockAlerts!.lowStock) {
        lines.add([p.productName, '${p.quantity}', '${p.threshold}']);
      }
      lines.add([]);
    }

    final csv = lines.map((row) => row.map(_escapeCsv).join(',')).join('\n');
    final ok = await saveCsvFile(
      filename: 'rapport-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    if (ok && context.mounted) AppToast.success(context, 'CSV enregistré.');
  }

  String _escapeCsv(String v) {
    final needs = v.contains(',') || v.contains('"') || v.contains('\n');
    if (!needs) return v;
    return '"${v.replaceAll('"', '""')}"';
  }

  Future<void> _exportExcel(BuildContext context) async {
    final sales = _salesKpis;
    if (sales == null) return;
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final kpiSheet = excel['KPIs'];
    kpiSheet.appendRow([TextCellValue('Période'), TextCellValue(_fromDate), TextCellValue(_toDate)]);
    kpiSheet.appendRow([TextCellValue('Chiffre d\'affaires'), DoubleCellValue(sales.salesSummary.totalAmount)]);
    kpiSheet.appendRow([TextCellValue('Nombre de ventes'), IntCellValue(sales.salesSummary.count)]);
    kpiSheet.appendRow([TextCellValue('Ticket moyen'), DoubleCellValue(sales.ticketAverage)]);
    kpiSheet.appendRow([TextCellValue('Articles vendus'), IntCellValue(sales.salesSummary.itemsSold)]);
    kpiSheet.appendRow([TextCellValue('Marge'), DoubleCellValue(sales.salesSummary.margin)]);

    final catSheet = excel['Catégories'];
    catSheet.appendRow([TextCellValue('Catégorie'), TextCellValue('CA'), TextCellValue('Qté')]);
    for (final c in sales.salesByCategory) {
      catSheet.appendRow([TextCellValue(c.categoryName), DoubleCellValue(c.revenue), IntCellValue(c.quantity)]);
    }

    final prodSheet = excel['Produits'];
    prodSheet.appendRow([TextCellValue('Produit'), TextCellValue('Qté'), TextCellValue('CA'), TextCellValue('Marge')]);
    for (final p in sales.topProducts) {
      prodSheet.appendRow([TextCellValue(p.productName), IntCellValue(p.quantitySold), DoubleCellValue(p.revenue), DoubleCellValue(p.margin)]);
    }

    if (_stockAlerts != null) {
      final stockSheet = excel['Stock'];
      stockSheet.appendRow([TextCellValue('Ruptures')]);
      stockSheet.appendRow([TextCellValue('Produit'), TextCellValue('Qté'), TextCellValue('Seuil')]);
      for (final p in _stockAlerts!.outOfStock) {
        stockSheet.appendRow([TextCellValue(p.productName), IntCellValue(p.quantity), IntCellValue(p.threshold)]);
      }
      stockSheet.appendRow([TextCellValue('')]);
      stockSheet.appendRow([TextCellValue('Stock faible')]);
      stockSheet.appendRow([TextCellValue('Produit'), TextCellValue('Qté'), TextCellValue('Seuil')]);
      for (final p in _stockAlerts!.lowStock) {
        stockSheet.appendRow([TextCellValue(p.productName), IntCellValue(p.quantity), IntCellValue(p.threshold)]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final ok = await saveBytesFile(
      dialogTitle: 'Enregistrer le fichier Excel',
      filename: 'rapport-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx',
      bytes: Uint8List.fromList(bytes),
      allowedExtensions: const ['xlsx'],
    );
    if (ok && context.mounted) AppToast.success(context, 'Fichier Excel enregistré.');
  }

  Future<void> _exportPdf(BuildContext context) async {
    final sales = _salesKpis;
    if (sales == null) return;
    final company = context.read<CompanyProvider>();
    final storeName = company.currentStore?.name;
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text('Rapport FasoStock', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Période: $_fromDate — $_toDate'),
          if (storeName != null) pw.Text('Boutique: $storeName'),
          pw.SizedBox(height: 12),
          pw.Text('KPIs', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Indicateur', 'Valeur'],
            data: [
              ['Chiffre d\'affaires', sales.salesSummary.totalAmount.toStringAsFixed(2)],
              ['Nombre de ventes', '${sales.salesSummary.count}'],
              ['Ticket moyen', sales.ticketAverage.toStringAsFixed(2)],
              ['Articles vendus', '${sales.salesSummary.itemsSold}'],
              ['Marge', sales.salesSummary.margin.toStringAsFixed(2)],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Ventes par catégorie', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Catégorie', 'CA', 'Qté'],
            data: sales.salesByCategory
                .map((c) => [c.categoryName, c.revenue.toStringAsFixed(2), '${c.quantity}'])
                .toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Top produits', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.TableHelper.fromTextArray(
            headers: const ['Produit', 'Qté', 'CA', 'Marge'],
            data: sales.topProducts
                .map((p) => [p.productName, '${p.quantitySold}', p.revenue.toStringAsFixed(2), p.margin.toStringAsFixed(2)])
                .toList(),
          ),
          if (_stockAlerts != null) ...[
            pw.SizedBox(height: 12),
            pw.Text('Stock', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Ruptures: ${_stockAlerts!.outOfStock.length} · Stock faible: ${_stockAlerts!.lowStock.length}'),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final ok = await saveBytesFile(
      dialogTitle: 'Enregistrer le PDF',
      filename: 'rapport-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      bytes: Uint8List.fromList(bytes),
      allowedExtensions: const ['pdf'],
    );
    if (ok && context.mounted) AppToast.success(context, 'PDF enregistré.');
  }
}

class _KpiData {
  const _KpiData(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.subtitle,
    this.accentBorder = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool accentBorder;
}

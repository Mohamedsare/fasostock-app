import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../data/models/reports.dart';
import '../../../data/models/store.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../core/config/routes.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../providers/permissions_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../../../data/repositories/reports_repository.dart';

/// Tableau de bord — offline-first : lecture Drift, sync en arrière-plan, rafraîchissement après sync.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardData {
  const _DashboardData({
    required this.salesSummary,
    required this.ticketAverage,
    required this.salesByDay,
    required this.topProducts,
    required this.salesByCategory,
    required this.purchasesSummary,
    required this.stockValue,
    required this.lowStockCount,
    required this.daySalesSummary,
    required this.dayPurchasesSummary,
  });

  final SalesSummary salesSummary;
  final double ticketAverage;
  final List<SalesByDay> salesByDay;
  final List<TopProduct> topProducts;
  final List<CategorySales> salesByCategory;
  final PurchasesSummary purchasesSummary;
  final StockValue stockValue;
  final int lowStockCount;
  final SalesSummary daySalesSummary;
  final PurchasesSummary dayPurchasesSummary;
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _period = 'week';
  String _scope = 'company';
  String _selectedDay = DateFormat('yyyy-MM-dd').format(DateTime.now());
  _DashboardData? _data;
  bool _loading = true;
  String? _error;
  Timer? _dashboardRefreshDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCompaniesIfNeeded();
      if (!mounted) return;
      _loadDataFromOffline();
      _runSyncThenRefresh();
    });
  }

  @override
  void dispose() {
    _dashboardRefreshDebounce?.cancel();
    super.dispose();
  }

  /// Programme un rafraîchissement des KPIs après un court délai (évite de recharger à chaque émission du stream).
  void _scheduleDashboardRefresh() {
    _dashboardRefreshDebounce?.cancel();
    _dashboardRefreshDebounce = Timer(const Duration(milliseconds: 800), () {
      _dashboardRefreshDebounce = null;
      if (mounted) _loadDataFromOffline(silent: true);
    });
  }

  /// Lance le sync puis recharge les données locales (rafraîchit le dashboard).
  /// Affiche un toast si des erreurs de sync se produisent (sans bloquer l'UI).
  Future<void> _runSyncThenRefresh() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid == null || company.currentCompanyId == null) return;
    try {
      final result = await ref.read(syncServiceV2Provider).sync(
        userId: uid,
        companyId: company.currentCompanyId,
        storeId: _scope == 'store' ? company.currentStoreId : null,
      );
      if (mounted && result.errors > 0) {
        AppToast.error(context, 'Certaines données n\'ont pas pu être synchronisées. Réessayez plus tard.');
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.show(context, e, fallback: 'Synchronisation échouée. Les données locales restent affichées.');
      }
    }
    if (mounted) _loadDataFromOffline();
  }

  Future<void> _loadCompaniesIfNeeded() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null && company.companies.isEmpty && !company.loading) {
      await company.loadCompanies(userId);
    }
  }

  /// Charge les KPIs depuis le stock local Drift (offline-first).
  /// [silent] : true lors d'un rafraîchissement déclenché par le stream (pas de spinner, les chiffres se mettent à jour à l'écran).
  Future<void> _loadDataFromOffline({bool silent = false}) async {
    final company = context.read<CompanyProvider>();
    final companyId = company.currentCompanyId;
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
      final range = getDefaultDateRange(_period);
      final storeId = _scope == 'store' ? company.currentStoreId : null;
      final repo = ref.read(dashboardOfflineRepositoryProvider);
      final result = await repo.getDashboardData(
        companyId: companyId,
        storeId: storeId,
        fromDate: range.from,
        toDate: range.to,
        selectedDay: _selectedDay,
      );

      final reportsRepo = ref.read(reportsOfflineRepositoryProvider);
      final salesKpis = await reportsRepo.getSalesKpis(
        companyId: companyId,
        storeId: storeId,
        fromDate: range.from,
        toDate: range.to,
        topLimit: 5,
      );

      if (mounted) {
        setState(() {
          _data = _DashboardData(
            salesSummary: result.salesSummary,
            ticketAverage: salesKpis.ticketAverage,
            salesByDay: result.salesByDay,
            topProducts: result.topProducts,
            salesByCategory: salesKpis.salesByCategory,
            purchasesSummary: result.purchasesSummary,
            stockValue: result.stockValue,
            lowStockCount: result.lowStockCount,
            daySalesSummary: result.daySalesSummary,
            dayPurchasesSummary: result.dayPurchasesSummary,
          );
          if (!silent) _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final message = AppErrorHandler.toUserMessage(e, fallback: 'Impossible de charger le tableau de bord. Réessayez.');
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
    if (permissions.hasLoaded && !permissions.hasPermission(Permissions.dashboardView)) {
      final requiredLabel = Permissions.labels[Permissions.dashboardView] ?? 'Voir le tableau de bord';
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

        final canPurchases = permissions.hasPermission(Permissions.purchasesView) ||
            permissions.hasPermission(Permissions.purchasesCreate);
        if (canPurchases) return AppRoutes.purchases;

        final canStores = permissions.hasPermission(Permissions.storesView) ||
            permissions.hasPermission(Permissions.storesCreate);
        if (canStores) return AppRoutes.stores;

        return AppRoutes.settings;
      }();

      return Scaffold(
        appBar: AppBar(title: const Text('Tableau de bord')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_person_rounded, size: 56, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 14),
                      Text(
                        'Accès restreint',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Votre rôle ne dispose pas des permissions nécessaires pour afficher cette section.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Droit requis : $requiredLabel',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final company = context.watch<CompanyProvider>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    // Charger les données dès qu'une entreprise est disponible (ex. chargée ailleurs).
    if (company.currentCompanyId != null && _data == null && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _data == null && !_loading) _loadDataFromOffline();
      });
    }

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Tableau de bord')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(company.loadError!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
      );
    }
    if (company.currentCompanyId == null) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Tableau de bord')),
        body: const Center(child: Text('Aucune entreprise. Contactez l’administrateur.')),
      );
    }

    final companyId = company.currentCompanyId!;
    ref.listen(dashboardDataChangeTriggerStreamProvider(companyId), (_, next) {
      next.whenOrNull(data: (_) => _scheduleDashboardRefresh());
    });

    final range = getDefaultDateRange(_period);
    final companyName = company.currentCompany?.name ?? '';
    final storeName = company.currentStore?.name ?? '';
    final description = _scope == 'company'
        ? 'Vue Entreprise — $companyName'
        : 'Vue Boutique — $storeName';

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Tableau de bord')),
      body: RefreshIndicator(
        onRefresh: () async {
          await company.refreshCompanies(context.read<AuthProvider>().user?.id);
          await _runSyncThenRefresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 28 : 12,
            vertical: isWide ? 24 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, description),
              SizedBox(height: isWide ? 20 : 12),
              _buildFiltersCard(context, company),
              SizedBox(height: isWide ? 20 : 12),
              if (_loading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: isWide ? 48 : 32),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 20 : 14),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                )
              else ...[
                _buildDayStatsCard(context),
                SizedBox(height: isWide ? 20 : 12),
                _buildKpiGrid(context),
                SizedBox(height: isWide ? 20 : 12),
                _buildChartAndSidebar(
                  context,
                  isWide,
                  context.watch<PermissionsProvider>().hasPermission(Permissions.salesCreate),
                  context.watch<PermissionsProvider>().hasPermission(Permissions.salesInvoiceA4),
                ),
                SizedBox(height: isWide ? 20 : 12),
                _buildFooter(context, range),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String description) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tableau de bord',
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
        ),
      ],
    );
  }

  Widget _buildFiltersCard(BuildContext context, CompanyProvider company) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isWide ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vue & période', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            SizedBox(height: isWide ? 12 : 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  selected: _scope == 'company',
                  label: Text(
                    'Entreprise',
                    style: TextStyle(
                      color: _scope == 'company' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: _scope == 'company' ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  onSelected: (_) => setState(() {
                    _scope = 'company';
                    _loadDataFromOffline();
                  }),
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  checkmarkColor: theme.colorScheme.primary,
                  avatar: Icon(Icons.business_rounded, size: 18, color: _scope == 'company' ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                ),
                if (company.stores.isNotEmpty) ...[
                  FilterChip(
                    selected: _scope == 'store',
                    label: Text(
                      'Boutique',
                      style: TextStyle(
                        color: _scope == 'store' ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        fontWeight: _scope == 'store' ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    onSelected: (_) => setState(() {
                      _scope = 'store';
                      if (company.currentStoreId == null && company.stores.isNotEmpty) {
                        company.setCurrentStoreId(company.stores.first.id);
                      }
                      _loadDataFromOffline();
                    }),
                    selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: theme.colorScheme.primary,
                    avatar: Icon(Icons.store_rounded, size: 18, color: _scope == 'store' ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                  ),
                  if (_scope == 'store' && company.stores.length > 1)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180, minWidth: 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: company.currentStoreId != null && company.stores.any((s) => s.id == company.currentStoreId)
                            ? company.currentStoreId!
                            : defaultSelectedStoreId(company.stores)!,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: company.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (id) {
                          company.setCurrentStoreId(id);
                          _loadDataFromOffline();
                        },
                      ),
                    ),
                ],
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['today', 'week', 'month'].map((p) {
                    final labels = {'today': "Aujourd'hui", 'week': 'Semaine', 'month': 'Mois'};
                    final isSelected = _period == p;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(
                        labels[p] ?? p,
                        style: TextStyle(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() {
                        _period = p;
                        _loadDataFromOffline();
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDayLabel(DateTime day) {
    try {
      return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(day);
    } catch (_) {
      return DateFormat('EEEE d MMMM yyyy').format(day);
    }
  }

  Widget _buildDayStatsCard(BuildContext context) {
    final theme = Theme.of(context);
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final dayDate = DateTime.tryParse(_selectedDay);
    final dayLabel = dayDate != null ? _formatDayLabel(dayDate) : _selectedDay;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 600 ? 20 : 12, 12, MediaQuery.sizeOf(context).width >= 600 ? 20 : 12, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 380;
                final datePicker = InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dayDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _selectedDay = DateFormat('yyyy-MM-dd').format(picked);
                        _loadDataFromOffline();
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _selectedDay,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                final todayBtn = TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDay = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      _loadDataFromOffline();
                    });
                  },
                  child: const Text('Aujourd\'hui'),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 22, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Statistiques du jour',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: datePicker),
                          const SizedBox(width: 8),
                          todayBtn,
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 22, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Statistiques du jour',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(child: datePicker),
                          const SizedBox(width: 8),
                          todayBtn,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 600 ? 20 : 12, 0, MediaQuery.sizeOf(context).width >= 600 ? 20 : 12, 12),
            child: Text(dayLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width >= 600 ? 20 : 12, 0, MediaQuery.sizeOf(context).width >= 600 ? 20 : 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 600 ? 5 : 2;
                final w = constraints.maxWidth;
                final dayAspectRatio = w < 400 ? 1.5 : (w < 600 ? 1.75 : 2.2);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: dayAspectRatio,
                  children: [
                    _dayStat(theme, 'CA du jour', formatCurrency(d.daySalesSummary.totalAmount)),
                    _dayStat(theme, 'Ventes', '${d.daySalesSummary.count}'),
                    _dayStat(theme, 'Articles vendus', '${d.daySalesSummary.itemsSold}'),
                    _dayStat(theme, 'Marge du jour', formatCurrency(d.daySalesSummary.margin), isHighlight: true),
                    _dayStat(theme, 'Achats du jour', '${formatCurrency(d.dayPurchasesSummary.totalAmount)}\n${d.dayPurchasesSummary.count} commande(s)'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayStat(ThemeData theme, String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isHighlight ? const Color(0xFF059669) : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context) {
    final theme = Theme.of(context);
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final marginRate = d.salesSummary.totalAmount > 0
        ? ((d.salesSummary.margin / d.salesSummary.totalAmount) * 100).toStringAsFixed(1)
        : '0';

    final kpis = [
      _KpiDef('Chiffre d\'affaires', formatCurrency(d.salesSummary.totalAmount), Icons.trending_up_rounded, theme.colorScheme.primary, accentBorder: true),
      _KpiDef('Ventes', '${d.salesSummary.count}', Icons.shopping_cart_rounded, const Color(0xFF059669)),
      _KpiDef('Ticket moyen', formatCurrency(d.ticketAverage), Icons.receipt_long_rounded, const Color(0xFF0EA5E9)),
      _KpiDef('Produits vendus', '${d.salesSummary.itemsSold}', Icons.inventory_2_rounded, const Color(0xFF2563EB)),
      _KpiDef('Marge', formatCurrency(d.salesSummary.margin), Icons.percent_rounded, const Color(0xFF059669), subtitle: '$marginRate%'),
      _KpiDef('Achats', formatCurrency(d.purchasesSummary.totalAmount), Icons.local_shipping_rounded, const Color(0xFFD97706), subtitle: '${d.purchasesSummary.count} commandes'),
      _KpiDef('Valeur stock', formatCurrency(d.stockValue.totalValue), Icons.warehouse_rounded, const Color(0xFF7C3AED), subtitle: '${d.stockValue.productCount} produits'),
      _KpiDef('Alertes stock', '${d.lowStockCount}', Icons.warning_amber_rounded, const Color(0xFFD97706), linkToInventory: d.lowStockCount > 0),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossCount = w > 900 ? 4 : (w > 600 ? 3 : 2);
        final kpiAspectRatio = w < 400 ? 1.05 : (w < 600 ? 1.15 : (w < 900 ? 1.25 : 1.35));
        final spacing = w < 600 ? 8.0 : 16.0;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: kpiAspectRatio,
          children: kpis.map((k) => _buildKpiCard(theme, k)).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(ThemeData theme, _KpiDef k) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: k.accentBorder
            ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: k.linkToInventory ? () => context.go(AppRoutes.inventory) : null,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 400;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 8 : 12),
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
                        padding: EdgeInsets.all(compact ? 6 : 8),
                    decoration: BoxDecoration(
                      color: k.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(k.icon, size: 20, color: k.color),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return FittedBox(
                      alignment: Alignment.topLeft,
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              k.value,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: k.color == const Color(0xFF059669) ? k.color : theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (k.subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  k.subtitle!,
                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (k.linkToInventory)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Voir inventaire', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 14, color: theme.colorScheme.error),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
      ),
    );
  }

  Widget _buildChartAndSidebar(BuildContext context, bool isWide, bool canOpenPosQuick, bool canOpenInvoiceA4) {
    final theme = Theme.of(context);
    final d = _data;
    if (d == null) return const SizedBox.shrink();

    final isWideChart = MediaQuery.sizeOf(context).width >= 900;
    final chartSection = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isWideChart ? 20 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Chiffre d\'affaires par jour', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 20),
            if (d.salesByDay.isEmpty)
              SizedBox(
                height: 260,
                child: Center(child: Text('Aucune vente sur la période', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
              )
            else
              SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: d.salesByDay.map((e) => e.total).reduce((a, b) => a > b ? a : b) * 1.15,
                    barGroups: d.salesByDay.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.total,
                          color: const Color(0xFFEA580C),
                          width: (d.salesByDay.length > 14 ? 6 : 12).toDouble(),
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
                          interval: (d.salesByDay.length / 8).clamp(1, 31).toDouble(),
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i >= 0 && i < d.salesByDay.length) {
                              final date = d.salesByDay[i].date;
                              final parsed = DateTime.tryParse(date);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  parsed != null ? DateFormat('dd/MM').format(parsed) : date.substring(5),
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
                      horizontalInterval: null,
                      getDrawingHorizontalLine: (v) => FlLine(color: theme.dividerColor.withValues(alpha: 0.4), strokeWidth: 1),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final e = d.salesByDay[group.x];
                          return BarTooltipItem(formatCurrency(e.total), (theme.textTheme.bodySmall ?? theme.textTheme.bodyMedium)?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle());
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

    final topProductsSection = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isWideChart ? 20 : 12, 12, isWideChart ? 20 : 12, 8),
            child: Text('Top 5 produits', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (d.topProducts.isEmpty)
            Padding(
              padding: EdgeInsets.all(isWideChart ? 20 : 14),
              child: Center(child: Text('Aucune vente sur la période', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            )
          else
            ...List.generate(d.topProducts.length, (i) {
              final p = d.topProducts[i];
              return ListTile(
                dense: true,
                leading: SizedBox(
                  width: 40,
                  height: 40,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < 3 ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${i + 1}', style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: i < 3 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    )),
                  ),
                ),
                title: Text(p.productName, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                trailing: Text(formatCurrency(p.revenue), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              );
            }),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.reports),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Voir les rapports'),
          ),
        ],
      ),
    );

    final categories = d.salesByCategory;
    final totalCat = categories.fold<double>(0, (s, e) => s + e.revenue);

    /// Courbe d'évolution du CA (même période que le graphique principal).
    final lineChartHeight = isWide ? 260.0 : (isWideChart ? 220.0 : 200.0);
    final pieChartHeight = isWide ? 260.0 : 200.0;

    final evolutionLineSection = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isWideChart ? 14 : 10, isWideChart ? 14 : 10, isWideChart ? 14 : 10, isWideChart ? 10 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.show_chart_rounded, size: 22, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Évolution du CA',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            if (d.salesByDay.isEmpty)
              SizedBox(
                height: lineChartHeight,
                child: Center(
                  child: Text(
                    'Aucune donnée',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              SizedBox(
                height: lineChartHeight,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: (d.salesByDay.map((e) => e.total).reduce((a, b) => a > b ? a : b) * 1.12).clamp(1.0, double.infinity),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(color: theme.dividerColor.withValues(alpha: 0.35), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isWide ? 44 : 36,
                          getTitlesWidget: (v, _) => Text(
                            v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                            style: TextStyle(fontSize: isWide ? 11 : 9, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isWide ? 28 : 22,
                          interval: (d.salesByDay.length / 5).clamp(1.0, 31.0),
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= d.salesByDay.length) return const SizedBox.shrink();
                            final date = d.salesByDay[i].date;
                            final parsed = DateTime.tryParse(date);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                parsed != null ? DateFormat('dd/MM').format(parsed) : date.substring(5),
                                style: TextStyle(fontSize: isWide ? 11 : 8, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
                        getTooltipItems: (spots) {
                          return spots.map((s) {
                            final i = s.x.toInt();
                            if (i < 0 || i >= d.salesByDay.length) return null;
                            return LineTooltipItem(
                              formatCurrency(d.salesByDay[i].total),
                              (theme.textTheme.bodySmall ?? theme.textTheme.bodyMedium)?.copyWith(fontWeight: FontWeight.w600) ?? const TextStyle(),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: d.salesByDay.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.total)).toList(),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: theme.colorScheme.primary,
                        barWidth: 2.8,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: d.salesByDay.length <= 18),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final pieRadius = isWide ? 88.0 : 58.0;
    final pieCenter = isWide ? 52.0 : 40.0;

    final categoriesSection = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isWideChart ? 14 : 10, isWideChart ? 14 : 10, isWideChart ? 14 : 10, isWideChart ? 10 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                'Ventes par catégorie',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
              ),
            ),
            if (categories.isEmpty || totalCat <= 0)
              SizedBox(
                height: pieChartHeight * 0.5,
                child: Center(
                  child: Text('Aucune donnée', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              )
            else
              SizedBox(
                height: pieChartHeight,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: pieCenter,
                    sectionsSpace: 2,
                    sections: categories.take(6).toList().asMap().entries.map((e) {
                      final i = e.key;
                      final c = e.value;
                      final colors = [
                        theme.colorScheme.primary,
                        const Color(0xFF059669),
                        const Color(0xFF2563EB),
                        const Color(0xFFD97706),
                        const Color(0xFF7C3AED),
                        const Color(0xFFDC2626),
                      ];
                      final percent = (c.revenue / totalCat) * 100;
                      return PieChartSectionData(
                        value: c.revenue,
                        color: colors[i % colors.length],
                        radius: pieRadius,
                        title: percent >= 14 ? '${percent.toStringAsFixed(0)}%' : '',
                        titleStyle: TextStyle(fontSize: isWide ? 13 : 11, fontWeight: FontWeight.w700, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (categories.isNotEmpty && totalCat > 0) ...[
              const SizedBox(height: 10),
              ...categories.take(isWide ? 6 : 4).map((c) {
                final percent = (c.revenue / totalCat) * 100;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: isWide ? 5 : 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.categoryName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: isWide ? theme.textTheme.bodyMedium : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: (isWide ? theme.textTheme.bodyMedium : theme.textTheme.labelSmall)?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: isWide ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );

    /// Mobile / étroit : courbe puis catégories en colonne.
    final evolutionAndCategoriesNarrow = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        evolutionLineSection,
        const SizedBox(height: 20),
        categoriesSection,
      ],
    );

    final shortcutsSection = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isWideChart ? 16 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Raccourcis', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: isWideChart ? 12 : 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final crossCount = isWide ? 5 : (w >= 1000 ? 5 : (w >= 780 ? 4 : (w >= 560 ? 3 : 2)));
                final tiles = <Widget>[
                  if (canOpenPosQuick)
                    _ShortcutTile(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Caisse rapide',
                      color: theme.colorScheme.primary,
                      onTap: () {
                        final storeId = context.read<CompanyProvider>().currentStoreId;
                        if (storeId != null) {
                          context.go(AppRoutes.posQuick(storeId));
                        } else {
                          context.go(AppRoutes.stores);
                        }
                      },
                    ),
                  if (canOpenInvoiceA4)
                    _ShortcutTile(
                      icon: Icons.description_rounded,
                      label: 'Facture A4',
                      color: const Color(0xFF059669),
                      onTap: () {
                        final storeId = context.read<CompanyProvider>().currentStoreId;
                        if (storeId != null) {
                          context.go(AppRoutes.pos(storeId));
                        } else {
                          context.go(AppRoutes.stores);
                        }
                      },
                    ),
                  _ShortcutTile(icon: Icons.shopping_cart_rounded, label: 'Ventes', color: const Color(0xFF2563EB), onTap: () => context.go(AppRoutes.sales)),
                  _ShortcutTile(icon: Icons.warehouse_rounded, label: 'Inventaire', color: const Color(0xFF2563EB), onTap: () => context.go(AppRoutes.inventory)),
                  _ShortcutTile(icon: Icons.local_shipping_rounded, label: 'Achats', color: const Color(0xFFD97706), onTap: () => context.go(AppRoutes.purchases)),
                ];
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: isWide ? 3.8 : (w < 560 ? 2.8 : 3.4),
                  children: tiles,
                );
              },
            ),
          ],
        ),
      ),
    );

    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: chartSection),
              const SizedBox(width: 24),
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    topProductsSection,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          shortcutsSection,
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: evolutionLineSection),
              const SizedBox(width: 36),
              Expanded(child: categoriesSection),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chartSection,
        const SizedBox(height: 24),
        topProductsSection,
        const SizedBox(height: 24),
        evolutionAndCategoriesNarrow,
        const SizedBox(height: 24),
        shortcutsSection,
      ],
    );
  }

  static String _formatShortDate(DateTime d) {
    try {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(d);
    } catch (_) {
      return DateFormat('dd MMM yyyy').format(d);
    }
  }

  Widget _buildFooter(BuildContext context, ({String from, String to}) range) {
    final fromParsed = DateTime.tryParse(range.from);
    final toParsed = DateTime.tryParse(range.to);
    final fromStr = fromParsed != null ? _formatShortDate(fromParsed) : range.from;
    final toStr = toParsed != null ? _formatShortDate(toParsed) : range.to;
    return Center(
      child: Text(
        'Période : $fromStr — $toStr',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _KpiDef {
  const _KpiDef(this.label, this.value, this.icon, this.color, {this.subtitle, this.accentBorder = false, this.linkToInventory = false});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool accentBorder;
  final bool linkToInventory;
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 10 : 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

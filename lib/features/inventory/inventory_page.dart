import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/inventory.dart';
import '../../../data/models/product.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../../../shared/utils/share_csv.dart';
import 'widgets/adjust_stock_dialog.dart';
import 'widgets/stock_range_slider.dart';

const int _inventoryPageSize = 20;
const int _movementsPageSize = 20;

/// Labels des types de mouvement (aligné web MOVEMENT_LABEL).
const Map<String, String> _movementLabels = {
  'purchase_in': 'Entrée achat',
  'sale_out': 'Sortie vente',
  'adjustment': 'Ajustement',
  'transfer_out': 'Transfert sortie',
  'transfer_in': 'Transfert entrée',
  'return_in': 'Retour entrée',
  'return_out': 'Retour sortie',
  'loss': 'Perte',
  'inventory_correction': 'Correction inventaire',
};

/// Page Stock — lecture 100 % Drift (produits + stock + catégories), sync v2 en arrière-plan.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final SettingsRepository _settingsRepo = SettingsRepository();

  final TextEditingController _searchController = TextEditingController();

  String _filterCategory = '';
  String _filterStatus = 'all';
  bool _showStockSettings = false;
  final TextEditingController _defaultThresholdController =
      TextEditingController(text: '5');
  bool _showMovements = false;
  AdjustStockProduct? _adjustingItem;
  bool _syncTriggeredOnce = false;
  int _currentInventoryPage = 0;
  String _lastInventoryFilterKey = '';
  int _currentMovementsPage = 0;

  bool _settingsPanelJustOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCompaniesIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _defaultThresholdController.dispose();
    super.dispose();
  }

  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null && company.companies.isEmpty && !company.loading) {
      company.loadCompanies(userId);
    }
  }

  Future<void> _refreshSync({String? storeId}) async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid != null) {
      try {
        await ref
            .read(syncServiceV2Provider)
            .sync(
          userId: uid,
          companyId: company.currentCompanyId,
          storeId: storeId ?? company.currentStoreId,
        );
      } catch (_) {}
    }
  }

  static List<InventoryItem> _buildItemsFromProductsAndStock(
    List<Product> products,
    Map<String, int> stockByProductId,
    String storeId,
    String now,
  ) {
    final items = <InventoryItem>[];
    for (final p in products.where((p) => p.isAvailableInBoutiqueStock)) {
      final qty = stockByProductId[p.id] ?? 0;
      items.add(
        InventoryItem(
        id: '${storeId}_${p.id}',
        storeId: storeId,
        productId: p.id,
        quantity: qty,
        reservedQuantity: 0,
        updatedAt: now,
        product: InventoryProductRef(
          id: p.id,
          name: p.name,
          sku: p.sku,
          barcode: p.barcode,
          unit: p.unit,
          salePrice: p.salePrice,
          stockMin: p.stockMin,
            productImages: p.productImages
                ?.map((i) => ImageUrlRef(url: i.url))
                .toList(),
        ),
        ),
      );
    }
    items.sort(
      (a, b) => (a.product?.name ?? '').compareTo(b.product?.name ?? ''),
    );
    return items;
  }

  int _effectiveMin(
    InventoryItem i,
    Map<String, int?> overrides,
    int defaultThreshold,
  ) {
    final override = overrides[i.productId];
    final productMin = i.product?.stockMin ?? 0;
    final min = override ?? productMin;
    return min > 0 ? min : defaultThreshold;
  }

  List<InventoryItem> _filteredItems(
    List<InventoryItem> items,
    Map<String, int?> overrides,
    int defaultThreshold,
  ) {
    if (_filterStatus == 'all') return items;
    if (_filterStatus == 'out')
      return items.where((i) => i.quantity == 0).toList();
    return items.where((i) {
      final min = _effectiveMin(i, overrides, defaultThreshold);
      return min > 0 && i.quantity <= min;
    }).toList();
  }

  List<InventoryItem> _lowStock(
    List<InventoryItem> items,
    Map<String, int?> overrides,
    int defaultThreshold,
  ) => items
      .where(
        (i) =>
            _effectiveMin(i, overrides, defaultThreshold) > 0 &&
            i.quantity <= _effectiveMin(i, overrides, defaultThreshold),
      )
      .toList();
  List<InventoryItem> _outOfStock(List<InventoryItem> items) =>
      items.where((i) => i.quantity == 0).toList();
  double _totalValue(List<InventoryItem> items) =>
      items.fold(0.0, (s, i) => s + (i.product?.salePrice ?? 0) * i.quantity);

  Future<void> _exportCsv(
    List<InventoryItem> filteredItems,
    Map<String, int?> overrides,
    int defaultThreshold,
  ) async {
    if (filteredItems.isEmpty) return;
    final sb = StringBuffer();
    sb.writeln('Produit;SKU;Qté;Réservé;Min;Unité;Prix vente');
    for (final i in filteredItems) {
      final p = i.product;
      final min = _effectiveMin(i, overrides, defaultThreshold);
      sb.writeln(
        '${p?.name ?? "—"};${p?.sku ?? "—"};${i.quantity};${i.reservedQuantity};$min;${p?.unit ?? "pce"};${p?.salePrice ?? 0}',
      );
    }
    final csv = sb.toString();
    final filename =
        'stock-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final saved = await saveCsvFile(filename: filename, bytes: bytes);
    if (mounted && saved) AppToast.success(context, 'CSV enregistré');
  }

  Future<void> _saveDefaultThreshold() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) return;
    final n = int.tryParse(_defaultThresholdController.text);
    if (n == null || n < 0) {
      AppToast.info(context, 'Saisissez un nombre ≥ 0');
      return;
    }
    try {
      await _settingsRepo.setDefaultStockAlertThreshold(companyId, n);
      if (!mounted) return;
      await ref
          .read(appDatabaseProvider)
          .upsertDefaultStockAlertThreshold(companyId, n);
      if (!mounted) return;
      ref.invalidate(defaultStockAlertThresholdStreamProvider(companyId));
      await _refreshSync();
      if (mounted)
        setState(() {
        _showStockSettings = false;
      });
      if (mounted) AppToast.success(context, 'Seuil d\'alerte enregistré');
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  /// Après ajustement en ligne : met à jour le cache Drift et invalide le stream pour affichage immédiat.
  Future<void> _applyStockChange(
    String storeId,
    String productId,
    int newQuantity,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await ref
        .read(appDatabaseProvider)
        .upsertInventory(storeId, productId, newQuantity, now);
    if (!mounted) return;
    ref.invalidate(inventoryQuantitiesStreamProvider(storeId));
    Future.microtask(() => _refreshSync(storeId: storeId));
  }

  Widget _buildInventoryPagination(
    BuildContext context,
    int totalCount,
    int pageCount,
    int currentPageIndex,
  ) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _inventoryPageSize + 1;
    final end = (currentPageIndex + 1) * _inventoryPageSize;
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
                  ? () => setState(() => _currentInventoryPage--)
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
                  ? () => setState(() => _currentInventoryPage++)
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

  Widget _buildMovementsPagination(
    BuildContext context,
    int totalCount,
    int pageCount,
    int currentPageIndex,
  ) {
    final theme = Theme.of(context);
    final start = currentPageIndex * _movementsPageSize + 1;
    final end = (currentPageIndex + 1) * _movementsPageSize;
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
                  ? () => setState(() => _currentMovementsPage--)
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
                  ? () => setState(() => _currentMovementsPage++)
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

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final canAccessStock =
        permissions.hasPermission(Permissions.stockView) ||
        permissions.hasPermission(Permissions.stockAdjust) ||
        permissions.hasPermission(Permissions.stockTransfer);
    if (permissions.hasLoaded && !canAccessStock) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stock')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
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
    final theme = Theme.of(context);
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;

    final productsAsync = ref.watch(productsStreamProvider(companyId ?? ''));
    final stockAsync = ref.watch(
      inventoryQuantitiesStreamProvider(storeId ?? ''),
    );
    final storesAsync = ref.watch(storesStreamProvider(companyId ?? ''));
    final categoriesAsync = ref.watch(
      categoriesStreamProvider(companyId ?? ''),
    );

    final products = productsAsync.value ?? [];
    final stockByProductId = stockAsync.value ?? {};
    final stores = storesAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];
    Store? store;
    try {
      store = stores.firstWhere((s) => s.id == storeId);
    } catch (_) {}
    final effectiveStoreId = storeId;
    final storeName = store?.name;

    if (effectiveStoreId != null && _showMovements) {
      Future.microtask(() => _refreshSync(storeId: effectiveStoreId));
    }
    final thresholdAsync = ref.watch(
      defaultStockAlertThresholdStreamProvider(companyId ?? ''),
    );
    final overridesAsync = ref.watch(
      stockMinOverridesStreamProvider(effectiveStoreId ?? ''),
    );
    final defaultThreshold = thresholdAsync.value ?? 5;
    final overrides = overridesAsync.value ?? {};
    if (_showStockSettings &&
        thresholdAsync.hasValue &&
        _settingsPanelJustOpened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _defaultThresholdController.text = '$defaultThreshold';
          setState(() => _settingsPanelJustOpened = false);
        }
      });
    }
    final movementsAsync = ref.watch(
      stockMovementsStreamProvider(
        _showMovements && effectiveStoreId != null ? effectiveStoreId : '',
      ),
    );
    final movements = movementsAsync.value ?? [];
    final loadingMovements = movementsAsync.isLoading;
    final movementsTotalCount = movements.length;
    final movementsPageCount = movementsTotalCount == 0
        ? 0
        : ((movementsTotalCount - 1) ~/ _movementsPageSize) + 1;
    final movementsEffectivePage =
        movementsPageCount > 0 && _currentMovementsPage >= movementsPageCount
        ? movementsPageCount - 1
        : _currentMovementsPage;
    if (movementsEffectivePage != _currentMovementsPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          setState(() => _currentMovementsPage = movementsEffectivePage);
      });
    }
    final paginatedMovements = movements
        .skip(movementsEffectivePage * _movementsPageSize)
        .take(_movementsPageSize)
        .toList();
    final now = DateTime.now().toUtc().toIso8601String();
    var items = effectiveStoreId != null
        ? _buildItemsFromProductsAndStock(
            products,
            stockByProductId,
            effectiveStoreId,
            now,
          )
        : <InventoryItem>[];
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items.where((i) {
        final p = i.product;
        if (p == null) return false;
        if (p.name.toLowerCase().contains(search)) return true;
        if (p.sku?.toLowerCase().contains(search) ?? false) return true;
        if (p.barcode?.contains(search) ?? false) return true;
        return false;
      }).toList();
    }
    if (_filterCategory.isNotEmpty) {
      items = items.where((i) {
        final p = products.where((p) => p.id == i.productId).firstOrNull;
        return p?.categoryId == _filterCategory;
      }).toList();
    }

    if (!_syncTriggeredOnce &&
        companyId != null &&
        products.isEmpty &&
        !productsAsync.isLoading) {
      _syncTriggeredOnce = true;
      Future.microtask(() => _refreshSync());
    }

    final loading =
        productsAsync.isLoading ||
        stockAsync.isLoading ||
        (effectiveStoreId != null && storesAsync.isLoading && stores.isEmpty);
    final filteredItems = _filteredItems(items, overrides, defaultThreshold);
    final totalCount = filteredItems.length;
    final pageCount = totalCount == 0
        ? 0
        : ((totalCount - 1) ~/ _inventoryPageSize) + 1;
    final filterKey =
        '${_searchController.text}|$_filterCategory|$_filterStatus';
    if (filterKey != _lastInventoryFilterKey) {
      _lastInventoryFilterKey = filterKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentInventoryPage = 0);
      });
    }
    final effectivePage = pageCount > 0 && _currentInventoryPage >= pageCount
        ? pageCount - 1
        : _currentInventoryPage;
    if (effectivePage != _currentInventoryPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentInventoryPage = effectivePage);
      });
    }
    final paginatedItems = filteredItems
        .skip(effectivePage * _inventoryPageSize)
        .take(_inventoryPageSize)
        .toList();
    final lowStock = _lowStock(items, overrides, defaultThreshold);
    final outOfStock = _outOfStock(items);
    final totalValue = _totalValue(items);

    if (effectiveStoreId == null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Stock',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionnez une boutique dans le menu pour voir le stock et les mouvements.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 64,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Choisissez une boutique',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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

    final canAdjust = permissions.hasPermission(Permissions.stockAdjust);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 560;
                  return Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: narrow
                        ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                              Text(
                                'Stock',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                storeName != null
                                    ? 'Stock — $storeName'
                                    : 'Stock',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HeaderButton(
                                    icon: Icons.settings_rounded,
                                    label: 'Paramètres',
                                    onPressed: () {
                                      setState(() {
                                        _showStockSettings =
                                            !_showStockSettings;
                                        if (_showStockSettings) {
                                          _settingsPanelJustOpened = true;
                                          _defaultThresholdController.text =
                                              '$defaultThreshold';
                                        }
                                      });
                                    },
                                  ),
                                  _HeaderButton(
                                    icon: Icons.download_rounded,
                                    label: 'Enregistrer CSV',
                                    onPressed: filteredItems.isEmpty
                                        ? null
                                        : () => _exportCsv(
                                            filteredItems,
                                            overrides,
                                            defaultThreshold,
                                          ),
                                  ),
                                ],
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
                                      'Stock',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                              const SizedBox(height: 4),
                              Text(
                                      storeName != null
                                          ? 'Stock — $storeName'
                                          : 'Stock',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HeaderButton(
                              icon: Icons.settings_rounded,
                              label: 'Paramètres',
                              onPressed: () {
                                setState(() {
                                        _showStockSettings =
                                            !_showStockSettings;
                                  if (_showStockSettings) {
                                    _settingsPanelJustOpened = true;
                                          _defaultThresholdController.text =
                                              '$defaultThreshold';
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _HeaderButton(
                              icon: Icons.download_rounded,
                                    label: 'Enregistrer CSV',
                                    onPressed: filteredItems.isEmpty
                                        ? null
                                        : () => _exportCsv(
                                            filteredItems,
                                            overrides,
                                            defaultThreshold,
                                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final crossCount = w > 900 ? 4 : (w > 500 ? 2 : 1);
                    final aspectRatio = w < 400
                        ? 1.4
                        : (w < 500 ? 1.6 : (w < 600 ? 1.8 : 2.2));
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: aspectRatio,
                      children: [
                        _StatCard(
                          icon: Icons.inventory_2_rounded,
                          label: 'Produits en stock',
                          value: '${items.length}',
                          accentLeft: true,
                          color: theme.colorScheme.primary,
                        ),
                        _StatCard(
                          icon: Icons.trending_up_rounded,
                          label: 'Valeur totale',
                          value: formatCurrency(totalValue),
                          color: Colors.green.shade700,
                        ),
                        _StatCard(
                          icon: Icons.warning_amber_rounded,
                          label: 'Sous le minimum',
                          value: '${lowStock.length}',
                          color: Colors.amber.shade700,
                          accentLeft: lowStock.isNotEmpty,
                        ),
                        _StatCard(
                          icon: Icons.cancel_rounded,
                          label: 'Rupture de stock',
                          value: '${outOfStock.length}',
                          color: theme.colorScheme.error,
                          accentLeft: outOfStock.isNotEmpty,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_showStockSettings)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seuil d\'alerte par défaut',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Utilisé pour les produits sans seuil défini. En dessous, le stock est en alerte.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _defaultThresholdController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '5',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: _saveDefaultThreshold,
                                child: const Text('Enregistrer'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final narrow = w < 560;
                            final shortSegmentLabel = w < 400;
                            final seenCatIds = <String>{};
                            final distinctCategories = categories
                                .where((c) => seenCatIds.add(c.id))
                                .toList();
                            final categoryValue = _filterCategory.isEmpty
                                ? ''
                                : (distinctCategories.any(
                                        (c) => c.id == _filterCategory,
                                      )
                                      ? _filterCategory
                                      : '');
                            final dropdownCat = DropdownButtonFormField<String>(
                              value: categoryValue,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              hint: Text(
                                'Catégorie',
                                overflow: TextOverflow.ellipsis,
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text(
                                    'Toutes',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...distinctCategories.map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(() => _filterCategory = v ?? '');
                              },
                            );
                            const _statusValues = ['all', 'low', 'out'];
                            final statusValue =
                                _statusValues.contains(_filterStatus)
                                ? _filterStatus
                                : 'all';
                            final dropdownStatut =
                                DropdownButtonFormField<String>(
                              value: statusValue,
                              decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                              ),
                              isExpanded: true,
                              items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text(
                                        'Tous',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'low',
                                      child: Text(
                                        'Sous minimum',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'out',
                                      child: Text(
                                        'Rupture',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              ],
                              onChanged: (v) {
                                setState(() => _filterStatus = v ?? 'all');
                              },
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (narrow) ...[
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'Rechercher produit, SKU...',
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: dropdownCat),
                                      const SizedBox(width: 12),
                                      Expanded(child: dropdownStatut),
                                    ],
                                  ),
                                ] else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          onChanged: (_) => setState(() {}),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Rechercher produit, SKU, code-barres...',
                                            prefixIcon: const Icon(
                                              Icons.search_rounded,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(width: 180, child: dropdownCat),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 160,
                                        child: dropdownStatut,
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                                SegmentedButton<bool>(
                                  segments: [
                                    const ButtonSegment(
                                      value: false,
                                      label: Text('Stock'),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text(
                                        shortSegmentLabel
                                            ? 'Mouvements'
                                            : 'Historique mouvements',
                                      ),
                                      icon: const Icon(
                                        Icons.history_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                  selected: {_showMovements},
                                    onSelectionChanged: (s) {
                                    setState(() {
                                      _showMovements = s.first;
                                      if (_showMovements) {
                                        Future.microtask(
                                          () => _refreshSync(
                                            storeId: effectiveStoreId,
                                          ),
                                        );
                                      }
                                    });
                                  },
                                ),
                            const SizedBox(height: 12),
                            Text(
                              'Inventaire physique : appuyez sur l’icône d’un produit pour ajuster le stock (variation ou quantité comptée).',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                            ),
                              ],
                            );
                          },
                        ),
                      ),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_showMovements)
                        loadingMovements
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _MovementsTable(
                                    movements: paginatedMovements,
                                  ),
                                  if (movementsPageCount > 1) ...[
                                    const SizedBox(height: 16),
                                    _buildMovementsPagination(
                                      context,
                                      movementsTotalCount,
                                      movementsPageCount,
                                      movementsEffectivePage,
                                    ),
                                  ],
                                ],
                              )
                      else if (filteredItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Aucun produit correspondant. Créez des produits ou ajustez les filtres.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StockTable(
                              items: paginatedItems,
                              effectiveMin: (i) =>
                                  _effectiveMin(i, overrides, defaultThreshold),
                              defaultThreshold: defaultThreshold,
                              onAdjust: canAdjust
                              ? (item) {
                                  final product = AdjustStockProduct(
                              id: item.productId,
                              name: item.product?.name ?? '—',
                              sku: item.product?.sku,
                              unit: item.product?.unit ?? 'pce',
                              currentQty: item.quantity,
                            );
                            setState(() => _adjustingItem = product);
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        if (!mounted ||
                                            !context.mounted ||
                                            _adjustingItem == null)
                                          return;
                                        final uid = context
                                            .read<AuthProvider>()
                                            .user
                                            ?.id;
                              final sid = effectiveStoreId;
                              if (uid == null) return;
                              showDialog(
                                context: context,
                                          builder: (context) =>
                                              AdjustStockDialog(
                                  product: product,
                                  storeId: sid,
                                  userId: uid,
                                  onSuccess: (int newQty) async {
                                                  setState(
                                                    () => _adjustingItem = null,
                                                  );
                                                  await _applyStockChange(
                                                    sid,
                                                    product.id,
                                                    newQty,
                                                  );
                                                },
                                                onOfflineEnqueue:
                                                    ({
                                    required String storeId,
                                    required String productId,
                                    required int delta,
                                    required String reason,
                                    required String userId,
                                    required int newQuantity,
                                  }) async {
                                                      final db = ref.read(
                                                        appDatabaseProvider,
                                                      );
                                                      final now = DateTime.now()
                                                          .toUtc()
                                                          .toIso8601String();
                                                      await db
                                                          .enqueuePendingAction(
                                      'stock_adjustment',
                                      jsonEncode({
                                                              'store_id':
                                                                  storeId,
                                                              'product_id':
                                                                  productId,
                                        'delta': delta,
                                        'reason': reason,
                                        'user_id': userId,
                                      }),
                                    );
                                                      await db.upsertInventory(
                                                        storeId,
                                                        productId,
                                                        newQuantity,
                                                        now,
                                                      );
                                  },
                                ),
                              ).then((_) {
                                          if (mounted)
                                            setState(
                                              () => _adjustingItem = null,
                                            );
                                  });
                                });
                              }
                              : null,
                            ),
                            if (pageCount > 1) ...[
                              const SizedBox(height: 16),
                              _buildInventoryPagination(
                                context,
                                totalCount,
                                pageCount,
                                effectivePage,
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.accentLeft = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool accentLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = 72.0;
    return Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
              if (accentLeft)
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(-2, 0),
                ),
        ],
      ),
      child: Row(
        children: [
              if (accentLeft)
          Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (accentLeft) const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
          Expanded(
            child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
              children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                const SizedBox(height: 2),
                Text(
                  value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}

class _StockTable extends StatelessWidget {
  const _StockTable({
    required this.items,
    required this.effectiveMin,
    required this.defaultThreshold,
    this.onAdjust,
  });

  final List<InventoryItem> items;
  final int Function(InventoryItem) effectiveMin;
  final int defaultThreshold;
  final void Function(InventoryItem)? onAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        columns: const [
          DataColumn(label: Text('Produit')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Qté'), numeric: true),
          DataColumn(label: Text('Réservé'), numeric: true),
          DataColumn(label: Text('Min'), numeric: true),
          DataColumn(label: Text('Unité')),
          DataColumn(label: Text('Niveau')),
          DataColumn(label: Text('Actions')),
        ],
        rows: items.map((i) {
          final min = effectiveMin(i);
          return DataRow(
            cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child:
                            i.product?.productImages != null &&
                                i.product!.productImages!.isNotEmpty
                            ? Image.network(
                                i.product!.productImages!.first.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.inventory_2_rounded,
                                  size: 22,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Icon(
                                Icons.inventory_2_rounded,
                                size: 22,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          i.product?.name ?? '—',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(i.product?.sku ?? '—')),
              DataCell(
                Text(
                  '${i.quantity}',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              DataCell(
                Text(
                  '${i.reservedQuantity}',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              DataCell(
                Text(
                  '$min',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              DataCell(Text(i.product?.unit ?? 'pce')),
              DataCell(
                StockRangeSlider(
                  quantity: i.quantity,
                  alertThreshold: min > 0 ? min : defaultThreshold,
                ),
              ),
              DataCell(
                onAdjust != null
                    ? IconButton(
                        onPressed: () => onAdjust!(i),
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        tooltip: 'Ajuster',
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MovementsTable extends StatelessWidget {
  const _MovementsTable({required this.movements});

  final List<StockMovement> movements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (movements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Aucun mouvement récent',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Produit')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Quantité'), numeric: true),
          DataColumn(label: Text('Note')),
        ],
        rows: movements.map((m) {
          final label = _movementLabels[m.type] ?? m.type;
          return DataRow(
            cells: [
              DataCell(
                Text(
                  DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(DateTime.parse(m.createdAt)),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DataCell(Text(m.product?.name ?? '—')),
              DataCell(Text(label)),
              DataCell(
                Text(
                '${m.quantity > 0 ? '+' : ''}${m.quantity}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                    color: m.quantity > 0
                        ? Colors.green.shade700
                        : theme.colorScheme.error,
                ),
                ),
              ),
              DataCell(Text(m.notes ?? '—', style: theme.textTheme.bodySmall)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    for (final e in this) return e;
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/config/routes.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/inventory.dart';
import '../../../data/models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/permissions_provider.dart';
import '../../../core/constants/permissions.dart';
import '../../../shared/utils/format_currency.dart';
import '../../../shared/widgets/company_load_error_screen.dart';
import '../products/widgets/stock_range_indicator.dart';

/// Construit une liste [InventoryItem] à partir des produits et du stock (Drift).
List<InventoryItem> _buildItemsFromProductsAndStock(
  List<Product> products,
  Map<String, int> stockByProductId,
  String storeId,
  String now,
) {
  final items = <InventoryItem>[];
  for (final p in products) {
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

/// Seuil d'alerte effectif (produit ou défaut 5).
int _effectiveMin(InventoryItem item) {
  final min = item.product?.stockMin ?? 0;
  return min > 0 ? min : 5;
}

/// Écran Stock (alertes) — offline+sync : lecture Drift, rupture/alertes calculés en local, sync au refresh.
class StockCashierPage extends ConsumerStatefulWidget {
  const StockCashierPage({super.key});

  @override
  ConsumerState<StockCashierPage> createState() => _StockCashierPageState();
}

class _StockCashierPageState extends ConsumerState<StockCashierPage> {
  bool _syncTriggeredOnce = false;
  static const int _pageSize = 20;
  int _currentRupturePage = 0;
  int _currentAlertesPage = 0;

  Future<void> _runSyncThenRefresh() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    if (uid == null) return;
    try {
      await ref
          .read(syncServiceV2Provider)
          .sync(
            userId: uid,
            companyId: company.currentCompanyId,
            storeId: company.currentStoreId,
          );
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          AppErrorHandler.toUserMessage(e, fallback: 'Sync échouée'),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runSyncThenRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    // Même logique que le sidebar : accessible à tous ceux qui ont le menu (canInventory && !owner).
    final canInventory =
        permissions.hasPermission(Permissions.stockView) ||
        permissions.hasPermission(Permissions.stockAdjust) ||
        permissions.hasPermission(Permissions.stockTransfer);
    if (permissions.hasLoaded && (permissions.isOwner || !canInventory)) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || !context.mounted) return;
        try {
          context.go(AppRoutes.dashboard);
        } catch (_) {}
      });
      return const SizedBox.shrink();
    }
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    final storeName = company.currentStore?.name;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (company.loadError != null && company.companies.isEmpty) {
      return CompanyLoadErrorScreen(
        message: company.loadError!,
        title: 'Stock',
        appBar: isWide ? null : AppBar(title: const Text('Stock')),
      );
    }
    if (storeId == null || companyId == null) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Stock')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Stock',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionnez une boutique pour voir les ruptures et alertes.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Theme.of(context).dividerColor),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Choisissez une boutique',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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

    final productsAsync = ref.watch(productsStreamProvider(companyId));
    final stockAsync = ref.watch(inventoryQuantitiesStreamProvider(storeId));
    final products = productsAsync.valueOrNull ?? [];
    final stockByProductId = stockAsync.valueOrNull ?? {};
    final loading = productsAsync.isLoading || stockAsync.isLoading;
    final error = productsAsync.hasError
        ? AppErrorHandler.toUserMessage(
            productsAsync.error!,
            fallback: 'Impossible de charger les produits.',
          )
        : (stockAsync.hasError
              ? AppErrorHandler.toUserMessage(
                  stockAsync.error!,
                  fallback: 'Impossible de charger le stock.',
                )
              : null);

    if (!_syncTriggeredOnce && products.isEmpty && !productsAsync.isLoading) {
      _syncTriggeredOnce = true;
      Future.microtask(() => _runSyncThenRefresh());
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final allItems = _buildItemsFromProductsAndStock(
      products
          .where((p) => p.isActive && p.isAvailableInBoutiqueStock)
          .toList(),
      stockByProductId,
      storeId,
      now,
    );
    final rupture = allItems.where((i) => i.quantity <= 0).toList();
    final alertes = allItems.where((i) {
      if (i.quantity <= 0) return false;
      final min = _effectiveMin(i);
      return i.quantity < min;
    }).toList();

    final rupturePageCount = rupture.isEmpty
        ? 1
        : (rupture.length / _pageSize).ceil();
    final alertesPageCount = alertes.isEmpty
        ? 1
        : (alertes.length / _pageSize).ceil();
    if (_currentRupturePage >= rupturePageCount) {
      _currentRupturePage = (rupturePageCount - 1).clamp(0, rupture.length);
    }
    if (_currentAlertesPage >= alertesPageCount) {
      _currentAlertesPage = (alertesPageCount - 1).clamp(0, alertes.length);
    }
    final paginatedRupture = rupture.isEmpty
        ? <InventoryItem>[]
        : rupture
              .skip(_currentRupturePage * _pageSize)
              .take(_pageSize)
              .toList();
    final paginatedAlertes = alertes.isEmpty
        ? <InventoryItem>[]
        : alertes
              .skip(_currentAlertesPage * _pageSize)
              .take(_pageSize)
              .toList();

    if (loading && allItems.isEmpty) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Stock')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Stock')),
      body: RefreshIndicator(
        onRefresh: _runSyncThenRefresh,
        child: SafeArea(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        storeName != null
                            ? 'Ruptures et alertes — $storeName'
                            : 'Ruptures et alertes',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.08),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _SummaryChip(
                        label: 'Rupture',
                        count: rupture.length,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      _SummaryChip(
                        label: 'Sous le min.',
                        count: alertes.length,
                        color: Colors.amber.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Rupture de stock',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (rupture.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Aucun produit en rupture')),
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProductStockTile(
                        item: paginatedRupture[index],
                        threshold: 5,
                      ),
                      childCount: paginatedRupture.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildPagination(
                    context,
                    rupture.length,
                    rupturePageCount,
                    _currentRupturePage,
                    () => setState(
                      () => _currentRupturePage = (_currentRupturePage - 1)
                          .clamp(0, rupturePageCount - 1),
                    ),
                    () => setState(
                      () => _currentRupturePage = (_currentRupturePage + 1)
                          .clamp(0, rupturePageCount - 1),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Sous le minimum (alertes)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (alertes.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Aucune alerte')),
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProductStockTile(
                        item: paginatedAlertes[index],
                        threshold: _effectiveMin(paginatedAlertes[index]),
                      ),
                      childCount: paginatedAlertes.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildPagination(
                    context,
                    alertes.length,
                    alertesPageCount,
                    _currentAlertesPage,
                    () => setState(
                      () => _currentAlertesPage = (_currentAlertesPage - 1)
                          .clamp(0, alertesPageCount - 1),
                    ),
                    () => setState(
                      () => _currentAlertesPage = (_currentAlertesPage + 1)
                          .clamp(0, alertesPageCount - 1),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(
    BuildContext context,
    int totalCount,
    int pageCount,
    int currentPageIndex,
    VoidCallback onPrev,
    VoidCallback onNext,
  ) {
    final theme = Theme.of(context);
    final start = totalCount == 0 ? 0 : currentPageIndex * _pageSize + 1;
    final end = (currentPageIndex + 1) * _pageSize;
    final endClamped = end > totalCount ? totalCount : end;
    final isNarrow = MediaQuery.sizeOf(context).width < 500;
    if (totalCount <= _pageSize && totalCount > 0) {
      return const SizedBox.shrink();
    }
    if (totalCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Card(
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
                onPressed: currentPageIndex > 0 ? onPrev : null,
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
                onPressed: currentPageIndex < pageCount - 1 ? onNext : null,
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
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              '$label : ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductStockTile extends StatelessWidget {
  const _ProductStockTile({required this.item, required this.threshold});

  final InventoryItem item;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = item.product;
    final name = p?.name ?? '—';
    final sku = p?.sku ?? '—';
    final price = p?.salePrice ?? 0;
    final qty = item.quantity;

    final firstImageUrl =
        p?.productImages != null && p!.productImages!.isNotEmpty
        ? p.productImages!.first.url
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: firstImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        firstImageUrl,
                        fit: BoxFit.cover,
                        width: 44,
                        height: 44,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.inventory_2_outlined,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.inventory_2_outlined,
                      size: 24,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sku · ${formatCurrency(price)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  StockRangeIndicator(
                    quantity: qty,
                    alertThreshold: threshold <= 0 ? 5 : threshold,
                  ),
                ],
              ),
            ),
            Text(
              '$qty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: qty <= 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

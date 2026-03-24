import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/purchase.dart';
import '../../../providers/offline_providers.dart';
import '../../../shared/utils/format_currency.dart';
import 'owner_notification.dart';

/// Liste des notifications owner (même ids que la boîte de dialogue).
List<OwnerNotificationItem> _computeOwnerNotificationsCount({
  required List<Product> products,
  required List<Sale> sales,
  required Map<String, int> stockByProductId,
  required Map<String, int?> stockMinOverrides,
  required Map<String, String> earliestInStore,
  required List<Purchase> purchases,
  required Set<String> productIdsSold,
  required List<({String productId, int quantity})> top10Sold,
  required DateTime now,
}) {
  final List<OwnerNotificationItem> items = [];
  final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
  final todayEnd = '${todayStart.substring(0, 10)}T23:59:59.999Z';

  // Ruptures
  final stockouts = products.where((p) => p.isActive && (stockByProductId[p.id] ?? 0) <= 0).toList();
  if (stockouts.isNotEmpty) {
    items.add(OwnerNotificationItem(
      id: 'stockout',
      type: OwnerNotificationType.stockout,
      title: 'Ruptures de stock',
      subtitle: '${stockouts.length} produit(s) en rupture.',
      trailing: '${stockouts.length}',
    ));
  }

  // Produits sous le stock minimum
  final underMin = products.where((p) {
    if (!p.isActive) return false;
    final qty = stockByProductId[p.id] ?? 0;
    if (qty <= 0) return false;
    final min = stockMinOverrides[p.id] ?? p.stockMin;
    return qty < min;
  }).toList();
  if (underMin.isNotEmpty) {
    items.add(OwnerNotificationItem(
      id: 'under_min_stock',
      type: OwnerNotificationType.underMinStock,
      title: 'Produits sous le stock minimum',
      subtitle: '',
      trailing: '${underMin.length}',
    ));
  }

  // Grosses factures du jour
  final salesToday = sales.where((s) {
    if (s.status != SaleStatus.completed) return false;
    return s.createdAt.compareTo(todayStart) >= 0 && s.createdAt.compareTo(todayEnd) <= 0;
  }).toList();
  salesToday.sort((a, b) => b.total.compareTo(a.total));
  final topSales = salesToday.take(5).toList();
  if (topSales.isNotEmpty) {
    items.add(OwnerNotificationItem(
      id: 'top_sales_today',
      type: OwnerNotificationType.topSalesToday,
      title: 'Plus grosses factures du jour',
      subtitle: '',
      trailing: formatCurrency(topSales.first.total),
    ));
  }

  // Entrées massives
  const massiveThreshold = 50000.0;
  final purchasesToday = purchases.where((p) {
    if (p.status == PurchaseStatus.cancelled || p.status == PurchaseStatus.draft) return false;
    final d = DateTime.tryParse(p.createdAt);
    if (d == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }).where((p) => p.total >= massiveThreshold).toList();
  if (purchasesToday.isNotEmpty) {
    items.add(OwnerNotificationItem(
      id: 'massive_stock_entry',
      type: OwnerNotificationType.massiveStockEntry,
      title: 'Entrée massive de stock',
      subtitle: '',
      trailing: formatCurrency(purchasesToday.fold<double>(0, (s, p) => s + p.total)),
    ));
  }

  // Produits non vendus depuis 1 mois (présents en boutique depuis ≥ 30 jours)
  final cutoffDate = now.subtract(const Duration(days: 30));
  final notSold = products.where((p) {
    if (!p.isActive || productIdsSold.contains(p.id)) return false;
    final firstDateStr = earliestInStore[p.id];
    if (firstDateStr == null) return false;
    final firstDate = DateTime.tryParse(firstDateStr);
    if (firstDate == null) return false;
    final firstDay = DateTime(firstDate.year, firstDate.month, firstDate.day);
    if (firstDay.isAfter(cutoffDate)) return false;
    return true;
  }).toList();
  if (notSold.isNotEmpty) {
    items.add(OwnerNotificationItem(
      id: 'products_not_sold_months',
      type: OwnerNotificationType.productsNotSoldMonths,
      title: 'Produits non vendus depuis 1 mois',
      subtitle: '',
      trailing: '${notSold.length}',
    ));
  }

  // Top 10 produits les plus vendus
  if (top10Sold.isNotEmpty) {
    items.add(OwnerNotificationItem(
      id: 'top_10_products_sold',
      type: OwnerNotificationType.top10ProductsSold,
      title: 'Top 10 produits les plus vendus',
      subtitle: '',
      trailing: '10',
    ));
  }

  // Tendances IA (toujours une entrée)
  items.add(OwnerNotificationItem(
    id: 'trends_ai',
    type: OwnerNotificationType.trendsAi,
    title: 'Tendances (IA)',
    subtitle: '',
    trailing: null,
  ));

  return items;
}

/// IDs des notifications masquées par l'utilisateur (partagé avec le dialog pour que le badge reflète le même nombre).
final ownerNotificationHiddenIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Liste des notifications owner (même ordre et ids que dans la boîte de dialogue).
/// En cas d'erreur ou de données manquantes, retourne une liste vide pour éviter tout crash.
final ownerNotificationItemsProvider = Provider.autoDispose.family<List<OwnerNotificationItem>, ({String companyId, String storeId})>((ref, params) {
  try {
    final productsAsync = ref.watch(productsStreamProvider(params.companyId));
    final salesAsync = ref.watch(salesStreamProvider((companyId: params.companyId, storeId: null)));
    final stockAsync = ref.watch(inventoryQuantitiesStreamProvider(params.storeId));
    final stockMinOverridesAsync = ref.watch(stockMinOverridesStreamProvider(params.storeId));
    final earliestInStoreAsync = ref.watch(earliestStockMovementDateByProductProvider(params.storeId));
    final purchasesAsync = ref.watch(purchasesStreamProvider((
      companyId: params.companyId,
      storeId: null,
      supplierId: null,
      status: null,
      fromDate: null,
      toDate: null,
    )));
    final productIdsSoldAsync = ref.watch(productIdsSoldLastMonthProvider(params.companyId));
    final top10SoldAsync = ref.watch(top10ProductsSoldProvider(params.companyId));

    final products = productsAsync.valueOrNull ?? <Product>[];
    final sales = salesAsync.valueOrNull ?? <Sale>[];
    final stockByProductId = stockAsync.valueOrNull ?? <String, int>{};
    final stockMinOverrides = stockMinOverridesAsync.valueOrNull ?? <String, int?>{};
    final earliestInStore = earliestInStoreAsync.valueOrNull ?? <String, String>{};
    final purchases = purchasesAsync.valueOrNull ?? <Purchase>[];
    final productIdsSold = productIdsSoldAsync.valueOrNull ?? <String>{};
    final top10Sold = top10SoldAsync.valueOrNull ?? <({String productId, int quantity})>[];

    return _computeOwnerNotificationsCount(
      products: products,
      sales: sales,
      stockByProductId: stockByProductId,
      stockMinOverrides: stockMinOverrides,
      earliestInStore: earliestInStore,
      purchases: purchases,
      productIdsSold: productIdsSold,
      top10Sold: top10Sold,
      now: DateTime.now(),
    );
  } catch (_) {
    return [];
  }
});

/// Nombre de notifications visibles (celles affichées dans la boîte, hors masquées) — badge dynamique.
/// Ne lance jamais : si la liste des items échoue, le count vaut 0.
final ownerNotificationsCountProvider = Provider.autoDispose.family<int, ({String companyId, String storeId})>((ref, params) {
  try {
    final items = ref.watch(ownerNotificationItemsProvider(params));
    final hiddenIds = ref.watch(ownerNotificationHiddenIdsProvider);
    return items.where((i) => !hiddenIds.contains(i.id)).length;
  } catch (_) {
    return 0;
  }
});

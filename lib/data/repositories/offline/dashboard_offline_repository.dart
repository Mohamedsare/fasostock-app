import '../../local/drift/app_database.dart';
import '../../models/reports.dart';

/// Calcule les KPIs du tableau de bord à partir des données Drift (offline-first).
class DashboardOfflineRepository {
  DashboardOfflineRepository(this._db);

  final AppDatabase _db;

  /// Retourne les données du dashboard/rapports pour la période et le scope donnés.
  /// Utilise uniquement les données locales (Drift).
  /// [topProductsLimit] : nombre de top produits (défaut 5 pour dashboard, 10 pour rapports).
  /// En cas d'erreur (DB, etc.), lance une [Exception] avec un message utilisateur.
  Future<DashboardOfflineResult> getDashboardData({
    required String companyId,
    String? storeId,
    required String fromDate,
    required String toDate,
    required String selectedDay,
    int topProductsLimit = 5,
  }) async {
    try {
      return await _getDashboardDataImpl(
        companyId: companyId,
        storeId: storeId,
        fromDate: fromDate,
        toDate: toDate,
        selectedDay: selectedDay,
        topProductsLimit: topProductsLimit,
      );
    } catch (e) {
      throw Exception('Impossible de charger les données. Réessayez.');
    }
  }

  Future<DashboardOfflineResult> _getDashboardDataImpl({
    required String companyId,
    String? storeId,
    required String fromDate,
    required String toDate,
    required String selectedDay,
    int topProductsLimit = 5,
  }) async {
    final sales = await _db.getLocalSalesInRange(
      companyId,
      storeId: storeId,
      fromDate: fromDate,
      toDate: toDate,
    );
    final saleIds = sales.map((s) => s.id).toList();
    final saleItems = saleIds.isEmpty ? <LocalSaleItem>[] : await _db.getLocalSaleItemsForSales(saleIds);
    final products = await _db.getLocalProducts(companyId);
    final productMap = {for (final p in products) p.id: p};

    final salesSummary = _computeSalesSummary(sales, saleItems, productMap);
    final salesByDay = _computeSalesByDay(sales);
    final topProducts = _computeTopProducts(saleItems, productMap, limit: topProductsLimit);

    final purchases = await _db.getLocalPurchases(
      companyId,
      storeId: storeId,
      fromDate: fromDate,
      toDate: toDate,
    );
    final purchasesFiltered = purchases.where((p) =>
        p.status == 'confirmed' || p.status == 'received' || p.status == 'partially_received').toList();
    final purchasesSummary = _computePurchasesSummary(purchasesFiltered);

    final daySales = await _db.getLocalSalesInRange(
      companyId,
      storeId: storeId,
      fromDate: selectedDay,
      toDate: selectedDay,
    );
    final daySaleIds = daySales.map((s) => s.id).toList();
    final dayItems = daySaleIds.isEmpty ? <LocalSaleItem>[] : await _db.getLocalSaleItemsForSales(daySaleIds);
    final daySalesSummary = _computeSalesSummary(daySales, dayItems, productMap);

    final dayPurchases = await _db.getLocalPurchases(
      companyId,
      storeId: storeId,
      fromDate: selectedDay,
      toDate: selectedDay,
    );
    final dayPurchasesFiltered = dayPurchases.where((p) =>
        p.status == 'confirmed' || p.status == 'received' || p.status == 'partially_received').toList();
    final dayPurchasesSummary = PurchasesSummary(
      totalAmount: dayPurchasesFiltered.fold(0.0, (s, p) => s + p.total),
      count: dayPurchasesFiltered.length,
    );

    final stockValue = await _computeStockValue(companyId, storeId, products);
    final lowStockCount = await _computeLowStockCount(companyId, storeId, products);

    return DashboardOfflineResult(
      salesSummary: salesSummary,
      salesByDay: salesByDay,
      topProducts: topProducts,
      purchasesSummary: purchasesSummary,
      stockValue: stockValue,
      lowStockCount: lowStockCount,
      daySalesSummary: daySalesSummary,
      dayPurchasesSummary: dayPurchasesSummary,
    );
  }

  SalesSummary _computeSalesSummary(
    List<LocalSale> sales,
    List<LocalSaleItem> items,
    Map<String, LocalProduct> productMap,
  ) {
    double totalAmount = 0;
    double margin = 0;
    int itemsSold = 0;
    for (final s in sales) {
      totalAmount += s.total;
    }
    for (final i in items) {
      itemsSold += i.quantity;
      final product = productMap[i.productId];
      final purchasePrice = product?.purchasePrice ?? 0;
      margin += i.total - (purchasePrice * i.quantity);
    }
    return SalesSummary(
      totalAmount: totalAmount,
      count: sales.length,
      itemsSold: itemsSold,
      margin: margin,
    );
  }

  List<SalesByDay> _computeSalesByDay(List<LocalSale> sales) {
    final byDay = <String, ({double total, int count})>{};
    for (final s in sales) {
      final date = s.createdAt.length >= 10 ? s.createdAt.substring(0, 10) : s.createdAt;
      final cur = byDay[date] ?? (total: 0, count: 0);
      byDay[date] = (total: cur.total + s.total, count: cur.count + 1);
    }
    final list = byDay.entries
        .map((e) => SalesByDay(date: e.key, total: e.value.total, count: e.value.count))
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<TopProduct> _computeTopProducts(
    List<LocalSaleItem> items,
    Map<String, LocalProduct> productMap, {
    int limit = 5,
  }) {
    final agg = <String, ({String name, int qty, double revenue, double cost})>{};
    for (final i in items) {
      final product = productMap[i.productId];
      final name = product?.name ?? '—';
      final purchasePrice = product?.purchasePrice ?? 0;
      final cur = agg[i.productId] ?? (name: name, qty: 0, revenue: 0, cost: 0);
      agg[i.productId] = (
        name: name,
        qty: cur.qty + i.quantity,
        revenue: cur.revenue + i.total,
        cost: cur.cost + (purchasePrice * i.quantity),
      );
    }
    final list = agg.entries
        .map((e) => TopProduct(
              productId: e.key,
              productName: e.value.name,
              quantitySold: e.value.qty,
              revenue: e.value.revenue,
              margin: e.value.revenue - e.value.cost,
            ))
        .toList();
    list.sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }

  PurchasesSummary _computePurchasesSummary(List<LocalPurchase> purchases) {
    final total = purchases.fold(0.0, (s, p) => s + p.total);
    return PurchasesSummary(totalAmount: total, count: purchases.length);
  }

  Future<StockValue> _computeStockValue(String companyId, String? storeId, List<LocalProduct> products) async {
    final productPriceMap = {for (final p in products) p.id: p.salePrice};
    if (storeId != null && storeId.isNotEmpty) {
      final inv = await _db.getInventoryQuantities(storeId);
      double totalValue = 0;
      for (final e in inv.entries) {
        final price = productPriceMap[e.key] ?? 0;
        totalValue += e.value * price;
      }
      return StockValue(totalValue: totalValue, productCount: inv.length);
    }
    final stores = await _db.getLocalStores(companyId);
    double totalValue = 0;
    final seen = <String>{};
    for (final store in stores) {
      final inv = await _db.getInventoryQuantities(store.id);
      for (final e in inv.entries) {
        final price = productPriceMap[e.key] ?? 0;
        totalValue += e.value * price;
        seen.add('${store.id}-${e.key}');
      }
    }
    return StockValue(totalValue: totalValue, productCount: seen.length);
  }

  Future<int> _computeLowStockCount(String companyId, String? storeId, List<LocalProduct> products) async {
    final defaultThreshold = await _db.getDefaultStockAlertThreshold(companyId);
    final productMinMap = {for (final p in products) p.id: p.stockMin};
    final storeIds = storeId != null && storeId.isNotEmpty
        ? [storeId]
        : (await _db.getLocalStores(companyId)).map((s) => s.id).toList();
    int count = 0;
    for (final sid in storeIds) {
      final inv = await _db.getInventoryQuantities(sid);
      final overrides = await _db.getStockMinOverrides(sid);
      for (final e in inv.entries) {
        final min = overrides[e.key] ?? productMinMap[e.key] ?? defaultThreshold;
        if (e.value <= min) count++;
      }
    }
    return count;
  }
}

/// Résultat agrégé du dashboard (données locales).
class DashboardOfflineResult {
  const DashboardOfflineResult({
    required this.salesSummary,
    required this.salesByDay,
    required this.topProducts,
    required this.purchasesSummary,
    required this.stockValue,
    required this.lowStockCount,
    required this.daySalesSummary,
    required this.dayPurchasesSummary,
  });

  final SalesSummary salesSummary;
  final List<SalesByDay> salesByDay;
  final List<TopProduct> topProducts;
  final PurchasesSummary purchasesSummary;
  final StockValue stockValue;
  final int lowStockCount;
  final SalesSummary daySalesSummary;
  final PurchasesSummary dayPurchasesSummary;
}

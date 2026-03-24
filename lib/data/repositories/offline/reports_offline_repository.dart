import '../../local/drift/app_database.dart';
import '../../models/reports.dart';
import 'package:drift/drift.dart';

class ReportsOfflineRepository {
  ReportsOfflineRepository(this._db);

  final AppDatabase _db;

  Future<SalesKpis> getSalesKpis({
    required String companyId,
    String? storeId,
    String? cashierUserId,
    String? productId,
    String? categoryId,
    required String fromDate,
    required String toDate,
    int topLimit = 10,
  }) async {
    final sales = await _db.getLocalSalesInRange(
      companyId,
      storeId: storeId,
      createdBy: cashierUserId,
      fromDate: fromDate,
      toDate: toDate,
    );
    final saleIds = sales.map((s) => s.id).toList();
    final items = saleIds.isEmpty ? <LocalSaleItem>[] : await _db.getLocalSaleItemsForSales(saleIds);
    final products = await _db.getLocalProducts(companyId);
    final productMap = {for (final p in products) p.id: p};

    final categories = await _db.select(_db.localCategories).get();
    final categoryMap = {for (final c in categories) c.id: c.name};

    // Optional filters by product/category (applied on items, then sales reduced to those containing matches).
    final filtered = _applyProductCategoryFilter(
      sales: sales,
      items: items,
      productMap: productMap,
      productId: productId,
      categoryId: categoryId,
    );

    final summary = _computeSalesSummary(filtered.sales, filtered.items, productMap);
    final ticketAverage = summary.count > 0 ? (summary.totalAmount / summary.count) : 0.0;
    final salesByDay = _computeSalesByDay(filtered.sales);

    final topProducts = _computeTopProducts(filtered.items, productMap, limit: topLimit, descending: true);
    final leastProducts = _computeTopProducts(filtered.items, productMap, limit: topLimit, descending: false);

    final salesByCategory = _computeSalesByCategory(
      items: filtered.items,
      productMap: productMap,
      categoryMap: categoryMap,
      limit: 12,
    );

    return SalesKpis(
      salesSummary: summary,
      ticketAverage: ticketAverage,
      salesByDay: salesByDay,
      topProducts: topProducts,
      leastProducts: leastProducts,
      salesByCategory: salesByCategory,
    );
  }

  Future<StockAlerts> getStockAlerts({
    required String companyId,
    required String storeId,
    required String fromDate,
    required String toDate,
    int maxItems = 20,
  }) async {
    final products = await _db.getLocalProducts(companyId);
    final productMap = {for (final p in products) p.id: p};
    final inv = await _db.getInventoryQuantities(storeId);
    final overrides = await _db.getStockMinOverrides(storeId);
    final defaultThreshold = await _db.getDefaultStockAlertThreshold(companyId);

    final outOfStock = <StockAlertItem>[];
    final lowStock = <StockAlertItem>[];

    for (final e in inv.entries) {
      final p = productMap[e.key];
      if (p == null) continue;
      final threshold = overrides[e.key] ?? (p.stockMin > 0 ? p.stockMin : defaultThreshold);
      final qty = e.value;
      if (qty <= 0) {
        outOfStock.add(StockAlertItem(productId: p.id, productName: p.name, quantity: qty, threshold: threshold));
      } else if (qty <= threshold) {
        lowStock.add(StockAlertItem(productId: p.id, productName: p.name, quantity: qty, threshold: threshold));
      }
    }
    outOfStock.sort((a, b) => a.quantity.compareTo(b.quantity));
    lowStock.sort((a, b) => a.quantity.compareTo(b.quantity));

    final movements = await (_db.select(_db.localStockMovements)
          ..where((t) => t.storeId.equals(storeId) &
              t.createdAt.isBiggerOrEqualValue(fromDate) &
              t.createdAt.isSmallerOrEqualValue('${toDate}T23:59:59.999Z'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    int entries = 0;
    int exits = 0;
    final byDayNet = <String, int>{};
    for (final m in movements) {
      final day = m.createdAt.length >= 10 ? m.createdAt.substring(0, 10) : m.createdAt;
      final qty = m.quantity;
      if (qty >= 0) {
        entries += qty;
      } else {
        exits += qty.abs();
      }
      byDayNet[day] = (byDayNet[day] ?? 0) + qty;
    }
    final byDayNetList = byDayNet.entries
        .map((e) => StockMovementByDay(date: e.key, netQuantity: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return StockAlerts(
      currentStockCount: inv.length,
      outOfStock: outOfStock.take(maxItems).toList(),
      lowStock: lowStock.take(maxItems).toList(),
      entries: entries,
      exits: exits,
      net: entries - exits,
      byDayNet: byDayNetList,
    );
  }

  ({List<LocalSale> sales, List<LocalSaleItem> items}) _applyProductCategoryFilter({
    required List<LocalSale> sales,
    required List<LocalSaleItem> items,
    required Map<String, LocalProduct> productMap,
    String? productId,
    String? categoryId,
  }) {
    final hasProduct = productId != null && productId.isNotEmpty;
    final hasCategory = categoryId != null && categoryId.isNotEmpty;
    if (!hasProduct && !hasCategory) return (sales: sales, items: items);

    bool itemMatch(LocalSaleItem i) {
      if (hasProduct && i.productId != productId) return false;
      if (hasCategory) {
        final p = productMap[i.productId];
        if (p == null) return false;
        if ((p.categoryId ?? '') != categoryId) return false;
      }
      return true;
    }

    final matchedItems = items.where(itemMatch).toList();
    final saleIds = matchedItems.map((i) => i.saleId).toSet();
    final matchedSales = sales.where((s) => saleIds.contains(s.id)).toList();
    return (sales: matchedSales, items: matchedItems);
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
    return SalesSummary(totalAmount: totalAmount, count: sales.length, itemsSold: itemsSold, margin: margin);
  }

  List<SalesByDay> _computeSalesByDay(List<LocalSale> sales) {
    final byDay = <String, ({double total, int count})>{};
    for (final s in sales) {
      final date = s.createdAt.length >= 10 ? s.createdAt.substring(0, 10) : s.createdAt;
      final cur = byDay[date] ?? (total: 0, count: 0);
      byDay[date] = (total: cur.total + s.total, count: cur.count + 1);
    }
    final list = byDay.entries.map((e) => SalesByDay(date: e.key, total: e.value.total, count: e.value.count)).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<TopProduct> _computeTopProducts(
    List<LocalSaleItem> items,
    Map<String, LocalProduct> productMap, {
    required int limit,
    required bool descending,
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
    var list = agg.entries
        .map((e) => TopProduct(
              productId: e.key,
              productName: e.value.name,
              quantitySold: e.value.qty,
              revenue: e.value.revenue,
              margin: e.value.revenue - e.value.cost,
            ))
        .where((p) => p.quantitySold > 0)
        .toList();
    list.sort((a, b) => descending ? b.revenue.compareTo(a.revenue) : a.revenue.compareTo(b.revenue));
    if (!descending) {
      // keep only items with revenue > 0 to avoid a flood of zeros (products never sold in range)
      list = list.where((p) => p.revenue > 0).toList();
    }
    return list.take(limit).toList();
  }

  List<CategorySales> _computeSalesByCategory({
    required List<LocalSaleItem> items,
    required Map<String, LocalProduct> productMap,
    required Map<String, String> categoryMap,
    int limit = 12,
  }) {
    final agg = <String?, ({String name, double revenue, int qty})>{};
    for (final i in items) {
      final p = productMap[i.productId];
      final cid = p?.categoryId;
      final name = cid != null && categoryMap.containsKey(cid) ? categoryMap[cid]! : 'Sans catégorie';
      final cur = agg[cid] ?? (name: name, revenue: 0.0, qty: 0);
      agg[cid] = (name: name, revenue: cur.revenue + i.total, qty: cur.qty + i.quantity);
    }
    final list = agg.entries
        .map((e) => CategorySales(categoryId: e.key, categoryName: e.value.name, revenue: e.value.revenue, quantity: e.value.qty))
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }
}


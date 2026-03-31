import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reports.dart';
import 'package:intl/intl.dart';

/// Rapports — même logique que reportsApi (web).
class ReportsRepository {
  ReportsRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<SalesSummary> getSalesSummary(ReportsFilters filters) async {
    var q = _client
        .from('sales')
        .select('id, total, subtotal, discount')
        .eq('company_id', filters.companyId)
        .eq('status', 'completed')
        .gte('created_at', filters.fromDate)
        .lte('created_at', '${filters.toDate}T23:59:59.999Z');
    if (filters.storeId != null) q = q.eq('store_id', filters.storeId!);
    final sales = await q;
    if ((sales as List).isEmpty) return const SalesSummary();
    final saleIds = (sales as List).map((s) => (s as Map)['id'] as String).toList();
    final items = await _client.from('sale_items').select('sale_id, quantity, unit_price, total, product:products(id, purchase_price)').inFilter('sale_id', saleIds);
    double totalAmount = 0, margin = 0;
    int itemsSold = 0;
    for (final s in sales as List) {
      totalAmount += ((s as Map)['total'] as num?)?.toDouble() ?? 0;
    }
    for (final x in items as List) {
      final m = x as Map;
      itemsSold += (m['quantity'] as num?)?.toInt() ?? 0;
      final total = (m['total'] as num?)?.toDouble() ?? 0;
      final product = m['product'] as Map?;
      final purchasePrice = (product?['purchase_price'] as num?)?.toDouble() ?? 0;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      margin += total - (purchasePrice * qty);
    }
    return SalesSummary(totalAmount: totalAmount, count: (sales as List).length, itemsSold: itemsSold, margin: margin);
  }

  Future<List<SalesByDay>> getSalesByDay(ReportsFilters filters) async {
    var q = _client
        .from('sales')
        .select('id, total, created_at')
        .eq('company_id', filters.companyId)
        .eq('status', 'completed')
        .gte('created_at', filters.fromDate)
        .lte('created_at', '${filters.toDate}T23:59:59.999Z');
    if (filters.storeId != null) q = q.eq('store_id', filters.storeId!);
    final sales = await q;
    final byDay = <String, ({double total, int count})>{};
    for (final s in sales as List) {
      final m = s as Map;
      final date = (m['created_at'] as String?)?.substring(0, 10) ?? '';
      final cur = byDay[date] ?? (total: 0, count: 0);
      byDay[date] = (total: cur.total + ((m['total'] as num?)?.toDouble() ?? 0), count: cur.count + 1);
    }
    final list = byDay.entries.map((e) => SalesByDay(date: e.key, total: e.value.total, count: e.value.count)).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<List<TopProduct>> getTopProducts(ReportsFilters filters, {int limit = 10}) async {
    var q = _client
        .from('sales')
        .select('id')
        .eq('company_id', filters.companyId)
        .eq('status', 'completed')
        .gte('created_at', filters.fromDate)
        .lte('created_at', '${filters.toDate}T23:59:59.999Z');
    if (filters.storeId != null) q = q.eq('store_id', filters.storeId!);
    final sales = await q;
    if ((sales as List).isEmpty) return [];
    final saleIds = (sales as List).map((s) => (s as Map)['id'] as String).toList();
    final items = await _client.from('sale_items').select('product_id, quantity, unit_price, total, product:products(id, name, purchase_price)').inFilter('sale_id', saleIds);
    final agg = <String, ({String name, int qty, double revenue, double cost})>{};
    for (final x in items as List) {
      final m = x as Map;
      final pid = m['product_id'] as String?;
      if (pid == null) continue;
      final product = m['product'] as Map?;
      final name = product?['name'] as String? ?? '—';
      final purchasePrice = (product?['purchase_price'] as num?)?.toDouble() ?? 0;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final total = (m['total'] as num?)?.toDouble() ?? 0;
      final cur = agg[pid] ?? (name: name, qty: 0, revenue: 0, cost: 0);
      agg[pid] = (name: name, qty: cur.qty + qty, revenue: cur.revenue + total, cost: cur.cost + (purchasePrice * qty));
    }
    final list = agg.entries.map((e) => TopProduct(productId: e.key, productName: e.value.name, quantitySold: e.value.qty, revenue: e.value.revenue, margin: e.value.revenue - e.value.cost)).toList();
    list.sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }

  Future<PurchasesSummary> getPurchasesSummary(ReportsFilters filters) async {
    var q = _client
        .from('purchases')
        .select('id, total')
        .eq('company_id', filters.companyId)
        .inFilter('status', ['confirmed', 'received', 'partially_received'])
        .gte('created_at', filters.fromDate)
        .lte('created_at', '${filters.toDate}T23:59:59.999Z');
    if (filters.storeId != null) q = q.eq('store_id', filters.storeId!);
    final data = await q;
    double totalAmount = 0;
    for (final p in data as List) {
      totalAmount += ((p as Map)['total'] as num?)?.toDouble() ?? 0;
    }
    return PurchasesSummary(totalAmount: totalAmount, count: (data as List).length);
  }

  Future<StockValue> getStockValue(String companyId, [String? storeId]) async {
    if (storeId == null) return const StockValue();
    final inv = await _client.from('store_inventory').select('product_id, quantity, product:products(id, sale_price, purchase_price)').eq('store_id', storeId);
    final invList = inv as List?;
    if (invList == null) return const StockValue();
    double totalValue = 0;
    for (final row in invList) {
      final m = row as Map;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final product = m['product'] as Map?;
      final price = (product?['sale_price'] as num?)?.toDouble() ?? 0;
      totalValue += qty * price;
    }
    return StockValue(totalValue: totalValue, productCount: invList.length);
  }

  Future<StockValue> getCompanyStockValue(String companyId) async {
    final stores = await _client.from('stores').select('id').eq('company_id', companyId).eq('is_active', true);
    if ((stores as List).isEmpty) return const StockValue();
    final storeIds = (stores as List).map((s) => (s as Map)['id'] as String).toList();
    final inv = await _client.from('store_inventory').select('store_id, product_id, quantity, product:products(id, sale_price)').inFilter('store_id', storeIds);
    double totalValue = 0;
    final seen = <String>{};
    for (final row in inv as List) {
      final m = row as Map;
      totalValue += ((m['quantity'] as num?)?.toInt() ?? 0) * ((m['product'] as Map?)?['sale_price'] as num? ?? 0).toDouble();
      seen.add('${m['store_id']}-${m['product_id']}');
    }
    return StockValue(totalValue: totalValue, productCount: seen.length);
  }

  Future<int> getLowStockCount(String companyId, [String? storeId]) async {
    List<String> storeIds;
    if (storeId != null) {
      storeIds = [storeId];
    } else {
      final stores = await _client.from('stores').select('id').eq('company_id', companyId).eq('is_active', true);
      storeIds = (stores as List).map((s) => (s as Map)['id'] as String).toList();
    }
    if (storeIds.isEmpty) return 0;
    final inv = await _client.from('store_inventory').select('store_id, product_id, quantity, product:products(id, stock_min)').inFilter('store_id', storeIds);
    final overrides = await _client.from('product_store_settings').select('store_id, product_id, stock_min_override').inFilter('store_id', storeIds);
    final overrideMap = <String, int?>{};
    for (final o in overrides as List) {
      final m = o as Map;
      overrideMap['${m['store_id']}-${m['product_id']}'] = (m['stock_min_override'] as num?)?.toInt();
    }
    final alertKeys = <String>{};
    for (final row in inv as List) {
      final m = row as Map;
      final sid = m['store_id'] as String?;
      final pid = m['product_id'] as String?;
      if (sid == null || pid == null) continue;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final product = m['product'] as Map?;
      final min = overrideMap['$sid-$pid'] ?? (product?['stock_min'] as num?)?.toInt() ?? 0;
      if (qty <= min) alertKeys.add('$sid-$pid');
    }
    return alertKeys.length;
  }
}

/// Période par défaut (today / week / month) — équivalent getDefaultDateRange (web).
({String from, String to}) getDefaultDateRange(String period) {
  final now = DateTime.now();
  late DateTime from;
  late DateTime to;
  if (period == 'today') {
    from = DateTime(now.year, now.month, now.day);
    to = from.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  } else if (period == 'week') {
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));
    from = DateTime(monday.year, monday.month, monday.day);
    to = from.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
  } else {
    from = DateTime(now.year, now.month, 1);
    to = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  }
  return (from: DateFormat('yyyy-MM-dd').format(from), to: DateFormat('yyyy-MM-dd').format(to));
}

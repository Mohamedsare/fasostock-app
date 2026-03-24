/// Filtres rapports — aligné avec ReportsFilters.
class ReportsFilters {
  const ReportsFilters({
    required this.companyId,
    this.storeId,
    required this.fromDate,
    required this.toDate,
  });
  final String companyId;
  final String? storeId;
  final String fromDate;
  final String toDate;
}

class SalesSummary {
  const SalesSummary({
    this.totalAmount = 0,
    this.count = 0,
    this.itemsSold = 0,
    this.margin = 0,
  });
  final double totalAmount;
  final int count;
  final int itemsSold;
  final double margin;
}

class SalesByDay {
  const SalesByDay({
    required this.date,
    this.total = 0,
    this.count = 0,
  });
  final String date;
  final double total;
  final int count;
}

class TopProduct {
  const TopProduct({
    required this.productId,
    required this.productName,
    this.quantitySold = 0,
    this.revenue = 0,
    this.margin = 0,
  });
  final String productId;
  final String productName;
  final int quantitySold;
  final double revenue;
  final double margin;
}

class PurchasesSummary {
  const PurchasesSummary({this.totalAmount = 0, this.count = 0});
  final double totalAmount;
  final int count;
}

class StockValue {
  const StockValue({this.totalValue = 0, this.productCount = 0});
  final double totalValue;
  final int productCount;
}

/// KPI ventes (rapport) — ajoute ticket moyen.
class SalesKpis {
  const SalesKpis({
    required this.salesSummary,
    required this.ticketAverage,
    required this.salesByDay,
    required this.topProducts,
    required this.leastProducts,
    required this.salesByCategory,
  });

  final SalesSummary salesSummary;
  final double ticketAverage;
  final List<SalesByDay> salesByDay;
  final List<TopProduct> topProducts;
  final List<TopProduct> leastProducts;
  final List<CategorySales> salesByCategory;
}

class CategorySales {
  const CategorySales({
    required this.categoryId,
    required this.categoryName,
    required this.revenue,
    required this.quantity,
  });

  final String? categoryId;
  final String categoryName;
  final double revenue;
  final int quantity;
}

class StockAlerts {
  const StockAlerts({
    required this.currentStockCount,
    required this.outOfStock,
    required this.lowStock,
    required this.entries,
    required this.exits,
    required this.net,
    required this.byDayNet,
  });

  final int currentStockCount;
  final List<StockAlertItem> outOfStock;
  final List<StockAlertItem> lowStock;
  final int entries;
  final int exits;
  final int net;
  final List<StockMovementByDay> byDayNet;
}

class StockAlertItem {
  const StockAlertItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.threshold,
  });

  final String productId;
  final String productName;
  final int quantity;
  final int threshold;
}

class StockMovementByDay {
  const StockMovementByDay({required this.date, required this.netQuantity});
  final String date; // yyyy-MM-dd
  final int netQuantity; // +in / -out
}

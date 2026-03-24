/// Contexte envoyé à l'IA pour les prédictions — aligné web PredictionContext.
class PredictionContext {
  const PredictionContext({
    required this.companyName,
    this.storeName,
    required this.period,
    required this.salesSummary,
    this.previousMonthSummary,
    required this.salesByDay,
    required this.topProducts,
    required this.purchasesSummary,
    required this.stockValue,
    required this.lowStockCount,
    required this.marginRatePercent,
  });

  final String companyName;
  final String? storeName;
  final String period;
  final SalesSummaryForPrediction salesSummary;
  final PreviousMonthSummary? previousMonthSummary;
  final List<SalesByDayPrediction> salesByDay;
  final List<TopProductPrediction> topProducts;
  final PurchasesSummaryForPrediction purchasesSummary;
  final double stockValue;
  final int lowStockCount;
  final double marginRatePercent;
}

class SalesSummaryForPrediction {
  const SalesSummaryForPrediction({
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

class PreviousMonthSummary {
  const PreviousMonthSummary({
    required this.totalAmount,
    required this.count,
    required this.margin,
  });
  final double totalAmount;
  final int count;
  final double margin;
}

class SalesByDayPrediction {
  const SalesByDayPrediction({required this.date, this.total = 0, this.count = 0});
  final String date;
  final double total;
  final int count;
}

class TopProductPrediction {
  const TopProductPrediction({
    required this.productName,
    this.quantitySold = 0,
    this.revenue = 0,
    this.margin = 0,
  });
  final String productName;
  final int quantitySold;
  final double revenue;
  final double margin;
}

class PurchasesSummaryForPrediction {
  const PurchasesSummaryForPrediction({this.totalAmount = 0, this.count = 0});
  final double totalAmount;
  final int count;
}

/// Réponse structurée IA — alignée web PredictionStructured.
class PredictionStructured {
  const PredictionStructured({
    this.forecastWeekCa = 0,
    this.forecastMonthCa = 0,
    this.trend = 'stable',
    this.trendReason = '',
    this.restockPriorities = const [],
    this.alerts = const [],
    this.recommendations = const [],
    this.commentary = '',
  });

  final double forecastWeekCa;
  final double forecastMonthCa;
  final String trend; // up | down | stable
  final String trendReason;
  final List<RestockPriority> restockPriorities;
  final List<PredictionAlert> alerts;
  final List<PredictionRecommendation> recommendations;
  final String commentary;
}

class RestockPriority {
  const RestockPriority({
    required this.productName,
    this.quantitySuggested = '',
    this.priority = 'low',
  });
  final String productName;
  final String quantitySuggested;
  final String priority; // high | medium | low
}

class PredictionAlert {
  const PredictionAlert({this.type = '', this.message = ''});
  final String type;
  final String message;
}

class PredictionRecommendation {
  const PredictionRecommendation({this.action = ''});
  final String action;
}

/// Payload cache dernière prédiction — aligné web LastPredictionPayload.
class LastPredictionPayload {
  const LastPredictionPayload({
    required this.structured,
    required this.text,
    required this.contextSummary,
  });
  final PredictionStructured structured;
  final String text;
  final ContextSummary contextSummary;
}

class ContextSummary {
  const ContextSummary({
    required this.period,
    required this.salesSummaryTotalAmount,
  });
  final String period;
  final double salesSummaryTotalAmount;
}

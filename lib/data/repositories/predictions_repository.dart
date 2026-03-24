import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/prediction.dart';
import '../models/reports.dart';
import 'reports_repository.dart';

/// Clé API DeepSeek — définie à la build : --dart-define=DEEPSEEK_API_KEY=xxx
bool isDeepSeekConfigured() {
  const key = String.fromEnvironment('DEEPSEEK_API_KEY', defaultValue: '');
  return key.trim().isNotEmpty;
}

String _getDeepSeekApiKey() {
  const key = String.fromEnvironment('DEEPSEEK_API_KEY', defaultValue: '');
  if (key.trim().isEmpty) throw Exception('Clé API DeepSeek non configurée');
  return key.trim();
}

/// Période mois précédent — équivalent getPreviousMonthRange (web).
({String from, String to}) _getPreviousMonthRange() {
  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1, 1);
  final to = DateTime(prev.year, prev.month + 1, 0, 23, 59, 59, 999);
  return (
    from: DateFormat('yyyy-MM-dd').format(prev),
    to: DateFormat('yyyy-MM-dd').format(to),
  );
}

/// Contexte pour l'IA — aligné web fetchPredictionContext.
Future<PredictionContext> fetchPredictionContext(
  String companyId,
  String companyName, {
  String? storeId,
  String? storeName,
  ReportsRepository? reportsRepo,
}) async {
  final repo = reportsRepo ?? ReportsRepository();
  final range = getDefaultDateRange('month');
  final prevRange = _getPreviousMonthRange();
  final filters = ReportsFilters(
    companyId: companyId,
    storeId: storeId,
    fromDate: range.from,
    toDate: range.to,
  );
  final prevFilters = ReportsFilters(
    companyId: companyId,
    storeId: storeId,
    fromDate: prevRange.from,
    toDate: prevRange.to,
  );

  final results = await Future.wait([
    repo.getSalesSummary(filters),
    repo.getTopProducts(filters, limit: 15),
    storeId != null
        ? repo.getStockValue(companyId, storeId)
        : repo.getCompanyStockValue(companyId),
    repo.getPurchasesSummary(filters),
    repo.getLowStockCount(companyId, storeId),
    repo.getSalesByDay(filters),
    repo.getSalesSummary(prevFilters),
  ]);

  final salesSummary = results[0] as SalesSummary;
  final topProducts = results[1] as List<TopProduct>;
  final stockResult = results[2] as StockValue;
  final purchasesSummary = results[3] as PurchasesSummary;
  final lowStockCount = results[4] as int;
  final salesByDay = results[5] as List<SalesByDay>;
  final prevSalesSummary = results[6] as SalesSummary;

  final marginRatePercent = salesSummary.totalAmount > 0
      ? (salesSummary.margin / salesSummary.totalAmount) * 100
      : 0.0;

  final periodStr = '${DateFormat('dd MMM yyyy', 'fr_FR').format(DateTime.parse(range.from))} → ${DateFormat('dd MMM yyyy', 'fr_FR').format(DateTime.parse(range.to))}';

  PreviousMonthSummary? prevSummary;
  if (prevSalesSummary.totalAmount > 0 || prevSalesSummary.count > 0) {
    prevSummary = PreviousMonthSummary(
      totalAmount: prevSalesSummary.totalAmount,
      count: prevSalesSummary.count,
      margin: prevSalesSummary.margin,
    );
  }

  return PredictionContext(
    companyName: companyName,
    storeName: storeName,
    period: periodStr,
    salesSummary: SalesSummaryForPrediction(
      totalAmount: salesSummary.totalAmount,
      count: salesSummary.count,
      itemsSold: salesSummary.itemsSold,
      margin: salesSummary.margin,
    ),
    previousMonthSummary: prevSummary,
    salesByDay: salesByDay
        .map((d) => SalesByDayPrediction(date: d.date, total: d.total, count: d.count))
        .toList(),
    topProducts: topProducts
        .map((p) => TopProductPrediction(
              productName: p.productName,
              quantitySold: p.quantitySold,
              revenue: p.revenue,
              margin: p.margin,
            ))
        .toList(),
    purchasesSummary: PurchasesSummaryForPrediction(
      totalAmount: purchasesSummary.totalAmount,
      count: purchasesSummary.count,
    ),
    stockValue: stockResult.totalValue,
    lowStockCount: lowStockCount,
    marginRatePercent: marginRatePercent,
  );
}

String _buildContextText(PredictionContext ctx, String formatCurrency(dynamic)) {
  final scope = ctx.storeName != null
      ? 'Boutique: ${ctx.storeName}'
      : 'Entreprise: ${ctx.companyName} (toutes boutiques)';

  String trend = '';
  if (ctx.salesByDay.length >= 2) {
    final mid = ctx.salesByDay.length ~/ 2;
    final sumFirst = ctx.salesByDay.take(mid).fold<double>(0, (s, d) => s + d.total);
    final sumSecond = ctx.salesByDay.skip(mid).fold<double>(0, (s, d) => s + d.total);
    final trendPct = sumFirst > 0 ? ((sumSecond - sumFirst) / sumFirst) * 100 : 0.0;
    trend = 'Tendance CA en cours de mois: ${trendPct >= 0 ? '+' : ''}${trendPct.toStringAsFixed(1)}% (2e moitié vs 1re moitié).';
  }

  String comparison = '';
  if (ctx.previousMonthSummary != null) {
    final p = ctx.previousMonthSummary!;
    final deltaCa = ctx.salesSummary.totalAmount - p.totalAmount;
    final deltaPct = p.totalAmount > 0 ? (deltaCa / p.totalAmount) * 100 : 0.0;
    comparison = '''
Mois précédent (comparaison):
  CA: ${formatCurrency(p.totalAmount)} (${p.count} ventes)
  Évolution ce mois: ${deltaCa >= 0 ? '+' : ''}${formatCurrency(deltaCa)} (${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}%)
  Marge mois précédent: ${formatCurrency(p.margin)}''';
  }

  final dailyLine = ctx.salesByDay.isNotEmpty
      ? '\nCA par jour (${ctx.salesByDay.length} jours avec ventes):\n${ctx.salesByDay.map((d) => '  ${d.date}: ${formatCurrency(d.total)} (${d.count} ventes)').join('\n')}'
      : '\nAucune vente détaillée par jour ce mois.';

  return '''
Période: ${ctx.period}
Contexte: $scope
${trend.isNotEmpty ? '\n$trend' : ''}

--- CE MOIS ---
Chiffre d'affaires: ${formatCurrency(ctx.salesSummary.totalAmount)} (${ctx.salesSummary.count} ventes, ${ctx.salesSummary.itemsSold} articles vendus)
Marge: ${formatCurrency(ctx.salesSummary.margin)} (taux: ${ctx.marginRatePercent.toStringAsFixed(1)}%)
Achats: ${formatCurrency(ctx.purchasesSummary.totalAmount)} (${ctx.purchasesSummary.count} commandes)
Valeur stock: ${formatCurrency(ctx.stockValue)}
Alertes stock (produits sous seuil minimum): ${ctx.lowStockCount}
$comparison
$dailyLine

--- TOP 15 PRODUITS VENDUS (ce mois) ---
${ctx.topProducts.asMap().entries.map((e) => '${e.key + 1}. ${e.value.productName}: ${e.value.quantitySold} vendus, CA ${formatCurrency(e.value.revenue)}, marge ${formatCurrency(e.value.margin)}').join('\n')}
'''.trim();
}

const _kLastPredictionType = 'last_prediction';

/// Dernière prédiction en cache — aligné web getLastPrediction.
Future<LastPredictionPayload?> getLastPrediction(
  String companyId,
  String? storeId,
  SupabaseClient? client,
) async {
  final c = client ?? Supabase.instance.client;
  var q = c
      .from('ai_insights_cache')
      .select('payload, created_at, store_id')
      .eq('company_id', companyId)
      .eq('insight_type', _kLastPredictionType);
  final res = await q.order('created_at', ascending: false).limit(10);
  if ((res as List).isEmpty) return null;
  final list = res as List;
  final match = list.cast<Map>().where((r) {
    final sid = r['store_id'];
    if (storeId == null) return sid == null;
    return sid == storeId;
  });
  final row = match.isNotEmpty ? match.first : null;
  if (row == null) return null;
  final payload = row['payload'];
  if (payload == null || payload is! Map) return null;
  final structured = _payloadToStructured(payload['structured'] as Map?);
  if (structured == null) return null;
  final contextSummary = payload['contextSummary'] as Map?;
  if (contextSummary == null) return null;
  return LastPredictionPayload(
    structured: structured,
    text: payload['text'] as String? ?? structured.commentary,
    contextSummary: ContextSummary(
      period: contextSummary['period'] as String? ?? '',
      salesSummaryTotalAmount: (contextSummary['salesSummaryTotalAmount'] as num?)?.toDouble() ?? 0,
    ),
  );
}

PredictionStructured? _payloadToStructured(Map? s) {
  if (s == null) return null;
  final fw = (s['forecast_week_ca'] as num?)?.toDouble() ?? 0.0;
  final fm = (s['forecast_month_ca'] as num?)?.toDouble() ?? 0.0;
  final restock = (s['restock_priorities'] as List?)
      ?.map((e) => RestockPriority(
            productName: (e as Map)['product_name'] as String? ?? '',
            quantitySuggested: (e['quantity_suggested'] as String?) ?? '',
            priority: (e['priority'] as String?) ?? 'low',
          ))
      .toList() ?? [];
  final alerts = (s['alerts'] as List?)
      ?.map((e) => PredictionAlert(
            type: (e as Map)['type'] as String? ?? '',
            message: (e['message'] as String?) ?? '',
          ))
      .toList() ?? [];
  final recs = (s['recommendations'] as List?)
      ?.map((e) => PredictionRecommendation(action: (e as Map)['action'] as String? ?? ''))
      .toList() ?? [];
  return PredictionStructured(
    forecastWeekCa: fw,
    forecastMonthCa: fm,
    trend: (s['trend'] as String?) ?? 'stable',
    trendReason: (s['trend_reason'] as String?) ?? '',
    restockPriorities: restock,
    alerts: alerts,
    recommendations: recs,
    commentary: (s['commentary'] as String?) ?? '',
  );
}

/// Sauvegarde dernière prédiction — aligné web saveLastPrediction.
Future<void> saveLastPrediction(
  String companyId,
  String? storeId,
  LastPredictionPayload payload,
  SupabaseClient? client,
) async {
  final c = client ?? Supabase.instance.client;
  final expiresAt = DateTime.now().add(const Duration(days: 365 * 10));
  final map = {
    'structured': {
      'forecast_week_ca': payload.structured.forecastWeekCa,
      'forecast_month_ca': payload.structured.forecastMonthCa,
      'trend': payload.structured.trend,
      'trend_reason': payload.structured.trendReason,
      'restock_priorities': payload.structured.restockPriorities
          .map((r) => {
                'product_name': r.productName,
                'quantity_suggested': r.quantitySuggested,
                'priority': r.priority,
              })
          .toList(),
      'alerts': payload.structured.alerts
          .map((a) => {'type': a.type, 'message': a.message})
          .toList(),
      'recommendations': payload.structured.recommendations
          .map((r) => {'action': r.action})
          .toList(),
      'commentary': payload.structured.commentary,
    },
    'text': payload.text,
    'contextSummary': {
      'period': payload.contextSummary.period,
      'salesSummaryTotalAmount': payload.contextSummary.salesSummaryTotalAmount,
    },
  };
  await c.from('ai_insights_cache').insert({
    'company_id': companyId,
    'store_id': storeId,
    'insight_type': _kLastPredictionType,
    'payload': map,
    'expires_at': expiresAt.toIso8601String(),
  });
}

const _structuredSystemPrompt = r'''
Tu es un expert IA pour la gestion de stock et ventes (FasoStock). Tu dois répondre UNIQUEMENT avec un objet JSON valide, sans texte avant ou après. Pas de markdown, pas de ```json.
Schéma strict de l'objet à renvoyer (tous les champs obligatoires) :
{
  "forecast_week_ca": number (estimation CA en XOF pour la semaine à venir, 0 si impossible),
  "forecast_month_ca": number (estimation CA en XOF pour le mois à venir, 0 si impossible),
  "trend": "up" | "down" | "stable",
  "trend_reason": "string (une phrase)",
  "restock_priorities": [ { "product_name": "string", "quantity_suggested": "string (ex: 20 unités)", "priority": "high"|"medium"|"low" } ],
  "alerts": [ { "type": "string (ex: rupture, promo, trésorerie)", "message": "string" } ],
  "recommendations": [ { "action": "string" } ],
  "commentary": "string (résumé en 2 à 4 paragraphes en français: prévision CA, réappro, alertes, recommandations)"
}
Utilise les noms de produits des données fournies pour restock_priorities. Garde des tableaux vides [] si rien à signaler.
''';

String _extractJson(String text) {
  final trimmed = text.trim();
  final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(trimmed);
  if (codeBlock != null) return codeBlock.group(1)!.trim();
  if (trimmed.startsWith('{')) return trimmed;
  return trimmed;
}

/// Appel DeepSeek et parsing JSON structuré — aligné web getPredictionsStructured.
Future<({PredictionStructured structured, String text})> getPredictionsStructured(
  PredictionContext context,
  String formatCurrency(dynamic),
) async {
  final apiKey = _getDeepSeekApiKey();
  final body = {
    'model': 'deepseek-chat',
    'messages': [
      {'role': 'system', 'content': _structuredSystemPrompt},
      {
        'role': 'user',
        'content':
            'Données:\n${_buildContextText(context, formatCurrency)}\n\nRéponds UNIQUEMENT avec l\'objet JSON demandé (forecast en XOF, tableaux restock_priorities/alerts/recommendations, commentary en français).',
      },
    ],
    'max_tokens': 1200,
    'temperature': 0.3,
    'response_format': {'type': 'json_object'},
  };

  final response = await http.post(
    Uri.parse('https://api.deepseek.com/v1/chat/completions'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode != 200) {
    throw Exception('DeepSeek API: ${response.statusCode} ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final choices = data['choices'] as List?;
  final content = choices?.isNotEmpty == true
      ? (choices!.first as Map)['message'] is Map
          ? ((choices.first as Map)['message'] as Map)['content'] as String?
          : null
      : null;
  if (content == null) throw Exception('Réponse DeepSeek invalide');

  final jsonStr = _extractJson(content);
  Map<String, dynamic> parsed;
  try {
    parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (_) {
    throw Exception('Réponse IA invalide (JSON attendu)');
  }

  final forecastWeekCa = (parsed['forecast_week_ca'] as num?)?.toDouble() ?? 0.0;
  final forecastMonthCa = (parsed['forecast_month_ca'] as num?)?.toDouble() ?? 0.0;
  if (forecastWeekCa == 0 && forecastMonthCa == 0) {
    throw Exception('Réponse IA incomplète');
  }

  final restockList = parsed['restock_priorities'] as List? ?? [];
  final alertsList = parsed['alerts'] as List? ?? [];
  final recsList = parsed['recommendations'] as List? ?? [];

  final structured = PredictionStructured(
    forecastWeekCa: forecastWeekCa,
    forecastMonthCa: forecastMonthCa,
    trend: (parsed['trend'] as String?) ?? 'stable',
    trendReason: (parsed['trend_reason'] as String?) ?? '',
    restockPriorities: restockList
        .map((e) => RestockPriority(
              productName: (e as Map)['product_name'] as String? ?? '',
              quantitySuggested: (e['quantity_suggested'] as String?) ?? '',
              priority: (e['priority'] as String?) ?? 'low',
            ))
        .toList(),
    alerts: alertsList
        .map((e) => PredictionAlert(
              type: (e as Map)['type'] as String? ?? '',
              message: (e['message'] as String?) ?? '',
            ))
        .toList(),
    recommendations: recsList
        .map((e) => PredictionRecommendation(
              action: (e as Map)['action'] as String? ?? '',
            ))
        .toList(),
    commentary: (parsed['commentary'] as String?) ?? '',
  );

  return (structured: structured, text: structured.commentary);
}

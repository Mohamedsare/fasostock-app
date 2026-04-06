import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/config/routes.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/constants/permissions.dart';
import '../../../data/models/prediction.dart';
import '../../../data/repositories/predictions_repository.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/permissions_provider.dart';
import '../../../shared/utils/format_currency.dart';

/// Page Prédictions IA — alignée web : états (entreprise, désactivé, API), génération, cartes, graphique, listes.
class AiInsightsPage extends StatefulWidget {
  const AiInsightsPage({super.key});

  @override
  State<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends State<AiInsightsPage> {
  bool _loading = false;
  String? _error;
  PredictionStructured? _structured;
  PredictionContext? _context;
  String? _predictionsText;
  String? _lastCompanyId;
  String? _lastStoreId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLastIfNeeded();
    });
  }

  void _resetState() {
    setState(() {
      _structured = null;
      _context = null;
      _predictionsText = null;
    });
  }

  Future<void> _loadLastIfNeeded() async {
    final company = context.read<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    if (companyId == null || !isDeepSeekConfigured()) return;
    _resetState();
    try {
      final last = await getLastPrediction(companyId, storeId, null);
      if (last != null && mounted) {
        setState(() {
          _structured = last.structured;
          _predictionsText = last.text;
          _context = PredictionContext(
            companyName: company.currentCompany?.name ?? '',
            storeName: company.currentStore?.name,
            period: last.contextSummary.period,
            salesSummary: SalesSummaryForPrediction(
              totalAmount: last.contextSummary.salesSummaryTotalAmount,
            ),
            previousMonthSummary: null,
            salesByDay: const [],
            topProducts: const [],
            purchasesSummary: const PurchasesSummaryForPrediction(),
            stockValue: 0,
            lowStockCount: 0,
            marginRatePercent: 0,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _generate() async {
    final company = context.read<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final companyName = company.currentCompany?.name ?? '';
    final storeId = company.currentStoreId;
    final storeName = company.currentStore?.name;
    if (companyId == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _structured = null;
      _context = null;
      _predictionsText = null;
    });
    try {
      final ctx = await fetchPredictionContext(
        companyId,
        companyName,
        storeId: storeId,
        storeName: storeName,
      );
      if (!mounted) return;
      setState(() => _context = ctx);

      final result = await getPredictionsStructured(ctx, (v) => formatCurrency(v is num ? v : 0));
      if (!mounted) return;
      setState(() {
        _structured = result.structured;
        _predictionsText = result.text;
      });

      await saveLastPrediction(
        companyId,
        storeId,
        LastPredictionPayload(
          structured: result.structured,
          text: result.text,
          contextSummary: ContextSummary(
            period: ctx.period,
            salesSummaryTotalAmount: ctx.salesSummary.totalAmount,
          ),
        ),
        null,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserMessage(e);
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    if (permissions.hasLoaded && permissions.isCashier) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || !context.mounted) return;
        try {
          context.go(AppRoutes.sales);
        } catch (_) {}
      });
      return const SizedBox.shrink();
    }
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final configured = isDeepSeekConfigured();

    if (companyId != _lastCompanyId || storeId != _lastStoreId) {
      _lastCompanyId = companyId;
      _lastStoreId = storeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resetState();
        if (companyId != null && configured) _loadLastIfNeeded();
      });
    }

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return _buildScaffold(
        context,
        isWide,
        title: 'Prédictions IA',
        description: 'Insights et recommandations',
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
    if (companyId != null && !permissions.hasPermission(Permissions.aiInsightsView)) {
      return _buildScaffold(
        context,
        isWide,
        title: 'Prédictions IA',
        description: 'Insights et recommandations',
        body: _buildNoAccessCard(context),
      );
    }

    if (companyId == null) {
      return _buildScaffold(
        context,
        isWide,
        title: 'Prédictions IA',
        description: 'Insights et recommandations',
        body: _buildMessageCard(
          context,
          'Sélectionnez une entreprise pour afficher les prédictions.',
        ),
      );
    }

    if (company.currentCompany?.aiPredictionsEnabled == false) {
      return _buildScaffold(
        context,
        isWide,
        title: 'Prédictions IA',
        description: 'Insights et recommandations',
        body: _buildDisabledCard(context),
      );
    }

    if (!configured) {
      return _buildScaffold(
        context,
        isWide,
        title: 'Prédictions IA',
        description: 'Insights et recommandations',
        body: _buildApiNotConfiguredCard(context),
      );
    }

    final description = company.currentCompany != null
        ? 'Insights pour ${company.currentCompany!.name}${company.currentStore != null ? ' · ${company.currentStore!.name}' : ''}'
        : 'Insights et recommandations';

    return _buildScaffold(
      context,
      isWide,
      title: 'Prédictions IA',
      description: description,
      showGenerateButton: true,
      loading: _loading,
      onGenerate: _generate,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            _buildErrorCard(context),
            const SizedBox(height: 20),
          ],
          if (_structured != null && _context != null) ...[
            _buildKpiCards(context),
            const SizedBox(height: 24),
            _buildChartCard(context),
            const SizedBox(height: 24),
            _buildTwoColumns(context, isWide),
            if (_structured!.recommendations.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildRecommendationsCard(context),
            ],
            if (_predictionsText != null && _predictionsText!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCommentaryCard(context),
            ],
          ],
          if (_structured == null && !_loading) _buildEmptyPromptCard(context),
        ],
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    bool isWide, {
    required String title,
    required String description,
    required Widget body,
    bool showGenerateButton = false,
    bool loading = false,
    VoidCallback? onGenerate,
  }) {
    return Scaffold(
      appBar: null,
      body: RefreshIndicator(
        onRefresh: () async {
          _resetState();
          await _loadLastIfNeeded();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 20,
            vertical: isWide ? 28 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isWide, title, description,
                  showGenerateButton: showGenerateButton,
                  loading: loading,
                  onGenerate: onGenerate),
              const SizedBox(height: 24),
              body,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isWide,
    String title,
    String description, {
    bool showGenerateButton = false,
    bool loading = false,
    VoidCallback? onGenerate,
  }) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (showGenerateButton && onGenerate != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: loading ? null : onGenerate,
                  icon: loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.onPrimary),
                  label: Text(loading ? 'Analyse…' : 'Générer les prédictions'),
                ),
              ],
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
                      title,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showGenerateButton && onGenerate != null)
                FilledButton.icon(
                  onPressed: loading ? null : onGenerate,
                  icon: loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.onPrimary),
                  label: Text(loading ? 'Analyse…' : 'Générer les prédictions'),
                ),
            ],
          );
  }

  Widget _buildNoAccessCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Vous n\'avez pas accès à cette section.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 40,
                color: Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Prédictions IA désactivées',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'L\'accès aux prédictions IA est désactivé pour votre entreprise. Contactez l\'administrateur de la plateforme pour plus d\'informations.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiNotConfiguredCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_rounded,
                size: 40,
                color: Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'API DeepSeek non configurée',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ajoutez la clé API DeepSeek (dart-define ou configuration) pour activer les prédictions.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context) {
    final theme = Theme.of(context);
    final s = _structured!;
    final ctx = _context!;
    final cards = [
      _KpiCard(
        label: 'CA prévu (semaine)',
        value: formatCurrency(s.forecastWeekCa),
        accent: true,
      ),
      _KpiCard(
        label: 'CA prévu (mois)',
        value: formatCurrency(s.forecastMonthCa),
      ),
      _KpiCard(
        label: 'Tendance',
        value: s.trend == 'up'
            ? 'Hausse'
            : s.trend == 'down'
                ? 'Baisse'
                : 'Stable',
        subtitle: s.trendReason.isNotEmpty ? s.trendReason : null,
      ),
      _KpiCard(
        label: 'CA mois actuel',
        value: formatCurrency(ctx.salesSummary.totalAmount),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final count = w > 900 ? 4 : (w > 600 ? 2 : 2);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: w < 400 ? 1.0 : 1.35,
          children: cards.map((c) => _buildSingleKpiCard(theme, c)).toList(),
        );
      },
    );
  }

  Widget _buildSingleKpiCard(ThemeData theme, _KpiCard c) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: c.accent
            ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 2)
            : BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              c.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              c.value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (c.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                c.subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context) {
    final theme = Theme.of(context);
    final s = _structured!;
    final ctx = _context!;
    final data = [
      (ctx.salesSummary.totalAmount, 'CA mois actuel'),
      (s.forecastMonthCa, 'CA prévu (mois)'),
      (s.forecastWeekCa, 'CA prévu (sem.)'),
    ];
    final maxY = data.map((e) => e.$1).reduce((a, b) => a > b ? a : b) * 1.15;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'CA réel vs prévision',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY.clamp(1.0, double.infinity),
                  barGroups: data.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.$1,
                          color: theme.colorScheme.primary,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                      showingTooltipIndicators: [0],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i >= 0 && i < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data[i].$2,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, _, _, _) {
                        final d = data[group.x];
                        return BarTooltipItem(
                          formatCurrency(d.$1),
                          (theme.textTheme.bodySmall ?? theme.textTheme.bodyMedium)!
                              .copyWith(fontWeight: FontWeight.w600),
                        );
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
  }

  Widget _buildTwoColumns(BuildContext context, bool isWide) {
    final theme = Theme.of(context);
    final s = _structured!;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildRestockCard(theme, s)),
          const SizedBox(width: 24),
          Expanded(child: _buildAlertsCard(theme, s)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRestockCard(theme, s),
        const SizedBox(height: 24),
        _buildAlertsCard(theme, s),
      ],
    );
  }

  Widget _buildRestockCard(ThemeData theme, PredictionStructured s) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Réapprovisionnement prioritaire',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (s.restockPriorities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aucun produit à réapprovisionner',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...s.restockPriorities.map((r) {
              final priorityColor = r.priority == 'high'
                  ? Colors.red
                  : r.priority == 'medium'
                      ? Colors.amber
                      : theme.colorScheme.onSurfaceVariant;
              final priorityLabel =
                  r.priority == 'high' ? 'Priorité haute' : r.priority == 'medium' ? 'Moyenne' : 'Basse';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.productName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (r.quantitySuggested.isNotEmpty)
                            Text(
                              r.quantitySuggested,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priorityLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(ThemeData theme, PredictionStructured s) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 22, color: Colors.amber.shade700),
                const SizedBox(width: 10),
                Text(
                  'Alertes et risques',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (s.alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aucune alerte',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...s.alerts.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (a.type.isNotEmpty)
                        Text(
                          a.type.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        a.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(BuildContext context) {
    final theme = Theme.of(context);
    final s = _structured!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Recommandations stratégiques',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...s.recommendations.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          r.action,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentaryCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Résumé et analyse',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _predictionsText ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPromptCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Text(
            'Cliquez sur « Générer les prédictions » pour afficher statistiques, graphiques et recommandations.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _KpiCard {
  const _KpiCard({
    required this.label,
    required this.value,
    this.subtitle,
    this.accent = false,
  });
  final String label;
  final String value;
  final String? subtitle;
  final bool accent;
}

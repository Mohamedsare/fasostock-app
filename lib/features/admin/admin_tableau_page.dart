import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/utils/format_currency.dart';
import 'shared/admin_ui.dart';

const _chartAxisColor = Color(0xFF475569);

/// Tableau de bord admin — design premium : hero, KPIs, graphiques.
class AdminTableauPage extends StatefulWidget {
  const AdminTableauPage({super.key});

  @override
  State<AdminTableauPage> createState() => _AdminTableauPageState();
}

class _AdminTableauPageState extends State<AdminTableauPage> {
  final AdminRepository _repo = AdminRepository();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;

    return Container(
      color: AdminPalette.surfaceAlt,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Tableau de bord',
            description: "Vue d'ensemble et statistiques avancées de la plateforme",
          ),
          const SizedBox(height: 24),
          _buildHeroCard(context),
          const SizedBox(height: 28),
          _buildStatsSection(context),
          const SizedBox(height: 28),
          _buildChartSection(context, 'Évolution du CA', "30 derniers jours"),
          _buildSalesOverTimeChart(context),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final useRow = w > 800;
              return useRow
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTopByCA(context)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildTopBySales(context)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildTopByCA(context),
                        const SizedBox(height: 24),
                        _buildTopBySales(context),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),
          _buildChartSection(context, 'Répartition du CA par jour', '30 jours'),
          _buildDailyHistogram(context),
        ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
            const Color(0xFF0F172A).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFFEA580C), size: 36),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Super Admin',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tableau de bord plateforme — statistiques globales et pilotage.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return FutureBuilder(
      future: _repo.getStats(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return AdminCard(
            padding: const EdgeInsets.all(32),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final s = snap.data!;
        final cards = [
          _StatCard(icon: Icons.business_rounded, label: 'Entreprises', value: '${s.companiesCount}', color: const Color(0xFFEA580C)),
          _StatCard(icon: Icons.store_rounded, label: 'Boutiques', value: '${s.storesCount}', color: const Color(0xFF0EA5E9)),
          _StatCard(icon: Icons.people_rounded, label: 'Utilisateurs', value: '${s.usersCount}', color: const Color(0xFF10B981)),
          _StatCard(icon: Icons.card_membership_rounded, label: 'Abonnements actifs', value: '${s.activeSubscriptionsCount}', color: const Color(0xFF6366F1)),
          _StatCard(icon: Icons.shopping_cart_rounded, label: 'Ventes', value: '${s.salesCount}', color: const Color(0xFF8B5CF6)),
          _StatCard(icon: Icons.trending_up_rounded, label: 'CA total', value: formatCurrency(s.salesTotalAmount), color: const Color(0xFFF59E0B)),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final crossCount = w > 1200 ? 6 : (w > 1000 ? 3 : (w > 700 ? 3 : 2));
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: w < 400 ? 1.2 : (w < 700 ? 1.4 : 1.55),
              children: cards,
            );
          },
        );
      },
    );
  }

  Widget _buildChartSection(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: AdminPalette.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AdminPalette.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOverTimeChart(BuildContext context) {
    return FutureBuilder(
      future: _repo.getSalesOverTime(days: 30),
      builder: (context, snap) {
        if (!snap.hasData) {
          return AdminCard(
            padding: const EdgeInsets.all(24),
            child: const SizedBox(height: 280, child: Center(child: CircularProgressIndicator())),
          );
        }
        final data = snap.data!;
        final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.total)).toList();
        return AdminCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 280,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (v, _) => Text(
                            '${(v / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(color: _chartAxisColor, fontSize: 11),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 5,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i >= 0 && i < data.length) {
                              try {
                                final d = DateTime.parse(data[i].date);
                                return Text(DateFormat('dd/MM').format(d), style: const TextStyle(color: _chartAxisColor, fontSize: 10));
                              } catch (_) {}
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color(0xFF0EA5E9),
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                              const Color(0xFF0EA5E9).withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopByCA(BuildContext context) {
    return FutureBuilder<List<AdminSalesByCompany>>(
      future: _repo.getSalesByCompany(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return AdminCard(
            padding: const EdgeInsets.all(24),
            child: const SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
          );
        }
        final list = snap.data!.take(10).toList();
        final maxAmount = list.isEmpty ? 1.0 : list.map((e) => e.totalAmount).reduce((a, b) => a > b ? a : b) * 1.1;
        return AdminCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top 10 entreprises par CA',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AdminPalette.title,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 320,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxAmount,
                    barGroups: list.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.totalAmount.toDouble(),
                          color: const Color(0xFFEA580C),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFFEA580C).withValues(alpha: 0.85),
                              const Color(0xFFEA580C),
                            ],
                          ),
                        )
                      ],
                      showingTooltipIndicators: [0],
                    )).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i >= 0 && i < list.length) {
                              final n = list[i].companyName;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  n.length > 12 ? '${n.substring(0, 11)}…' : n,
                                  style: const TextStyle(color: _chartAxisColor, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (v, _) => Text(
                            '${(v / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(color: _chartAxisColor, fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(color: AdminPalette.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBySales(BuildContext context) {
    return FutureBuilder<List<AdminSalesByCompany>>(
      future: _repo.getSalesByCompany(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return AdminCard(
            padding: const EdgeInsets.all(24),
            child: const SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
          );
        }
        final list = List<AdminSalesByCompany>.from(snap.data!);
        list.sort((a, b) => b.salesCount.compareTo(a.salesCount));
        final top = list.take(10).toList();
        final maxSales = top.isEmpty ? 1.0 : top.map((e) => e.salesCount).reduce((a, b) => a > b ? a : b) * 1.1;
        return AdminCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top 10 par nombre de ventes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 320,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxSales.toDouble(),
                    barGroups: top.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.salesCount.toDouble(),
                          color: const Color(0xFF8B5CF6),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                              const Color(0xFF8B5CF6),
                            ],
                          ),
                        )
                      ],
                      showingTooltipIndicators: [0],
                    )).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i >= 0 && i < top.length) {
                              final n = top[i].companyName;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  n.length > 12 ? '${n.substring(0, 11)}…' : n,
                                  style: const TextStyle(color: _chartAxisColor, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (v, _) => Text(
                            '${v.toInt()}',
                            style: const TextStyle(color: _chartAxisColor, fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(color: AdminPalette.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyHistogram(BuildContext context) {
    return FutureBuilder(
      future: _repo.getSalesOverTime(days: 30),
      builder: (context, snap) {
        if (!snap.hasData) {
          return AdminCard(
            padding: const EdgeInsets.all(24),
            child: const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
          );
        }
        final data = snap.data!;
        return AdminCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: data.isEmpty ? 1 : data.map((e) => e.total).reduce((a, b) => a > b ? a : b) * 1.1,
                    barGroups: data.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.total.toDouble(),
                          color: const Color(0xFFEA580C),
                          width: 10,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFFEA580C).withValues(alpha: 0.7),
                              const Color(0xFFEA580C),
                            ],
                          ),
                        )
                      ],
                      showingTooltipIndicators: [0],
                    )).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 5,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i >= 0 && i < data.length) {
                              try {
                                final d = DateTime.parse(data[i].date);
                                return Text(
                                  DateFormat('dd/MM').format(d),
                                  style: TextStyle(color: _chartAxisColor, fontSize: 9),
                                );
                              } catch (_) {}
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (v, _) => Text(
                            '${(v / 1000).toStringAsFixed(0)}k',
                            style: const TextStyle(color: _chartAxisColor, fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(color: AdminPalette.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                        color: AdminPalette.title,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AdminPalette.subtitle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

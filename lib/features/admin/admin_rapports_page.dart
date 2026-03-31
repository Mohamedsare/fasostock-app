import 'package:flutter/material.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/utils/format_currency.dart';
import 'shared/admin_ui.dart';

/// Rapports ventes admin — design aligné tableau de bord.
class AdminRapportsPage extends StatelessWidget {
  const AdminRapportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: 'Rapports',
            description: "Vue d'ensemble des ventes et du CA par entreprise",
          ),
          const SizedBox(height: 24),
          FutureBuilder<AdminStats>(
            future: AdminRepository().getStats(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return AdminCard(
                  padding: const EdgeInsets.all(32),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final s = snap.data!;
              return Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.shopping_cart_rounded,
                      label: 'Ventes totales (complétées)',
                      value: '${s.salesCount}',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.trending_up_rounded,
                      label: 'CA total plateforme',
                      value: formatCurrency(s.salesTotalAmount),
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'CA par entreprise',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<AdminSalesByCompany>>(
            future: AdminRepository().getSalesByCompany(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return AdminCard(
                  padding: const EdgeInsets.all(24),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data!;
              return AdminCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Entreprise')),
                      DataColumn(label: Text('Nb ventes'), numeric: true),
                      DataColumn(label: Text('CA'), numeric: true),
                    ],
                    rows: list.map((r) => DataRow(
                      cells: [
                        DataCell(Text(r.companyName)),
                        DataCell(Text('${r.salesCount}')),
                        DataCell(Text(formatCurrency(r.totalAmount))),
                      ],
                    )).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/models/purchase.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import '../../../shared/utils/format_currency.dart';
import 'owner_notification.dart';
import 'owner_notifications_provider.dart';

/// Résultat du calcul de tendance hebdo (CA des 7 derniers jours vs 7 jours précédents).
({String label, String subtitle, String? trailing}) _computeWeeklyTrend(
  List<Sale> sales,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final completed = sales
      .where((s) => s.status == SaleStatus.completed)
      .toList();

  // Semaine courante : 7 derniers jours (jusqu'à aujourd'hui inclus).
  final thisWeekStart = today.subtract(const Duration(days: 6));
  // Semaine précédente : 7 jours avant.
  final lastWeekStart = today.subtract(const Duration(days: 13));
  final lastWeekEnd = today.subtract(const Duration(days: 7));

  double totalThisWeek = 0;
  double totalLastWeek = 0;
  for (final s in completed) {
    final d = DateTime.tryParse(s.createdAt);
    if (d == null) continue;
    final saleDate = DateTime(d.year, d.month, d.day);
    if (saleDate.isBefore(thisWeekStart)) {
      if (!saleDate.isBefore(lastWeekStart) && !saleDate.isAfter(lastWeekEnd)) {
        totalLastWeek += s.total;
      }
    } else {
      if (!saleDate.isAfter(today)) totalThisWeek += s.total;
    }
  }

  if (totalLastWeek == 0) {
    if (totalThisWeek > 0) {
      return (
        label: 'Progression',
        subtitle:
            'Par rapport à la semaine précédente : vous êtes en progression (nouvelle activité).',
        trailing: formatCurrency(totalThisWeek),
      );
    }
    return (
      label: 'Stable',
      subtitle:
          'Par rapport à la semaine précédente : pas encore assez de données pour la tendance.',
      trailing: null,
    );
  }

  final deltaPercent = ((totalThisWeek - totalLastWeek) / totalLastWeek) * 100;
  if (deltaPercent > 0) {
    return (
      label: 'Progression',
      subtitle:
          'Par rapport à la semaine précédente : vous êtes en progression.',
      trailing: '+${deltaPercent.toStringAsFixed(1)} %',
    );
  }
  if (deltaPercent < 0) {
    return (
      label: 'Régression',
      subtitle:
          'Par rapport à la semaine précédente : vous êtes en régression.',
      trailing: '${deltaPercent.toStringAsFixed(1)} %',
    );
  }
  return (
    label: 'Stable',
    subtitle:
        'Par rapport à la semaine précédente : chiffre d\'affaires stable.',
    trailing: '0 %',
  );
}

/// Couleur et icône pour la tendance IA (vert = progression, rouge = régression, gris = stable).
({Color color, IconData icon}) _trendStyle(String label) {
  switch (label) {
    case 'Progression':
      return (color: const Color(0xFF2E7D32), icon: Icons.trending_up_rounded);
    case 'Régression':
      return (
        color: const Color(0xFFC62828),
        icon: Icons.trending_down_rounded,
      );
    default:
      return (
        color: const Color(0xFF616161),
        icon: Icons.trending_flat_rounded,
      );
  }
}

/// Couleurs par gravité/bonté : critical=rouge, warning=orange, good=vert, info=bleu.
const _colorCritical = Color(0xFFC62828); // rouge
const _colorWarning = Color(0xFFE65100); // orange
const _colorGood = Color(0xFF2E7D32); // vert
const _colorInfo = Color(0xFF1565C0); // bleu
const _colorNeutral = Color(0xFF616161); // gris

({Color color, IconData icon}) _styleForNotification(
  OwnerNotificationType type, [
  String? trendLabel,
]) {
  if (type == OwnerNotificationType.trendsAi && trendLabel != null) {
    return _trendStyle(trendLabel);
  }
  switch (type) {
    case OwnerNotificationType.stockout:
      return (color: _colorCritical, icon: Icons.inventory_2_outlined);
    case OwnerNotificationType.underMinStock:
      return (color: _colorWarning, icon: Icons.warning_amber_rounded);
    case OwnerNotificationType.topSalesToday:
      return (color: _colorGood, icon: Icons.receipt_long_rounded);
    case OwnerNotificationType.massiveStockEntry:
      return (color: _colorInfo, icon: Icons.local_shipping_rounded);
    case OwnerNotificationType.productsNotSoldMonths:
      return (color: _colorWarning, icon: Icons.trending_down_rounded);
    case OwnerNotificationType.top10ProductsSold:
      return (color: _colorGood, icon: Icons.star_rounded);
    case OwnerNotificationType.trendsAi:
      return (color: _colorNeutral, icon: Icons.auto_awesome_rounded);
  }
}

/// Boîte de dialogue des notifications owner (ruptures, grosses factures, entrées stock, tendances).
/// Affichée depuis l’icône de la top bar (desktop, owner uniquement).
class OwnerNotificationsDialog extends ConsumerStatefulWidget {
  const OwnerNotificationsDialog({super.key});

  @override
  ConsumerState<OwnerNotificationsDialog> createState() =>
      _OwnerNotificationsDialogState();
}

class _OwnerNotificationsDialogState
    extends ConsumerState<OwnerNotificationsDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    try {
      final company = context.watch<CompanyProvider>();
      final companyId = company.currentCompanyId ?? '';
      final storeId = company.currentStoreId ?? '';

      final productsAsync = ref.watch(productsStreamProvider(companyId));
    final salesAsync = ref.watch(
      salesStreamProvider((companyId: companyId, storeId: null)),
    );
    final stockAsync = ref.watch(inventoryQuantitiesStreamProvider(storeId));
    final purchasesAsync = ref.watch(
      purchasesStreamProvider((
        companyId: companyId,
        storeId: null,
        supplierId: null,
        status: null,
        fromDate: null,
        toDate: null,
      )),
    );
    final productIdsSoldAsync = ref.watch(
      productIdsSoldLastMonthProvider(companyId),
    );
    final earliestInStoreAsync = ref.watch(
      earliestStockMovementDateByProductProvider(storeId),
    );
    final stockMinOverridesAsync = ref.watch(
      stockMinOverridesStreamProvider(storeId),
    );
    final top10SoldAsync = ref.watch(top10ProductsSoldProvider(companyId));

    final products = productsAsync.valueOrNull ?? <Product>[];
    final sales = salesAsync.valueOrNull ?? <Sale>[];
    final stockByProductId = stockAsync.valueOrNull ?? <String, int>{};
    final purchases = purchasesAsync.valueOrNull ?? <Purchase>[];
    final productIdsSold = productIdsSoldAsync.valueOrNull ?? <String>{};
    final earliestInStore =
        earliestInStoreAsync.valueOrNull ?? <String, String>{};
    final stockMinOverrides =
        stockMinOverridesAsync.valueOrNull ?? <String, int?>{};
    final top10Sold =
        top10SoldAsync.valueOrNull ?? <({String productId, int quantity})>[];

    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();
    final todayEnd = '${todayStart.substring(0, 10)}T23:59:59.999Z';

    final List<OwnerNotificationItem> items = [];

    // Ruptures (stock = 0 pour la boutique courante)
    final stockouts = products
        .where((p) => p.isActive && (stockByProductId[p.id] ?? 0) <= 0)
        .toList();
    if (stockouts.isNotEmpty) {
      items.add(
        OwnerNotificationItem(
          id: 'stockout',
          type: OwnerNotificationType.stockout,
          title: 'Ruptures de stock',
          subtitle:
              '${stockouts.length} produit(s) en rupture dans la boutique actuelle.',
          trailing: '${stockouts.length}',
        ),
      );
    }

    // Produits sous le stock minimum (quantité > 0 mais < seuil) — liste dans la boîte
    final underMin = products.where((p) {
      if (!p.isActive) return false;
      final qty = stockByProductId[p.id] ?? 0;
      if (qty <= 0) return false;
      final min = stockMinOverrides[p.id] ?? p.stockMin;
      return qty < min;
    }).toList();
    if (underMin.isNotEmpty) {
      final underMinLines = underMin.map((p) {
        final qty = stockByProductId[p.id] ?? 0;
        final min = stockMinOverrides[p.id] ?? p.stockMin;
        return '• ${p.name} : Stock $qty / minimum $min';
      }).join('\n');
      items.add(
        OwnerNotificationItem(
          id: 'under_min_stock',
          type: OwnerNotificationType.underMinStock,
          title: 'Sous le minimum (alertes)',
          subtitle: underMinLines,
          trailing: '${underMin.length}',
        ),
      );
    }

    // Grosses factures du jour (ventes complétées aujourd’hui, tri par total décroissant, top 5)
    final salesToday = sales.where((s) {
      if (s.status != SaleStatus.completed) return false;
      final created = s.createdAt;
      return created.compareTo(todayStart) >= 0 &&
          created.compareTo(todayEnd) <= 0;
    }).toList();
    salesToday.sort((a, b) => b.total.compareTo(a.total));
    final topSales = salesToday.take(5).toList();
    if (topSales.isNotEmpty) {
      items.add(
        OwnerNotificationItem(
          id: 'top_sales_today',
          type: OwnerNotificationType.topSalesToday,
          title: 'Plus grosses factures du jour',
          subtitle: topSales.length == 1
              ? '1 vente : ${formatCurrency(topSales.first.total)}'
              : 'Top ${topSales.length} : ${formatCurrency(topSales.first.total)} max.',
          trailing: formatCurrency(topSales.first.total),
        ),
      );
    }

    // Entrées massives de stock (achats confirmés/reçus aujourd’hui avec total élevé)
    const massiveThreshold = 50000.0;
    final purchasesToday = purchases
        .where((p) {
          if (p.status == PurchaseStatus.cancelled ||
              p.status == PurchaseStatus.draft)
            return false;
          final d = DateTime.tryParse(p.createdAt);
          if (d == null) return false;
          final today = DateTime(now.year, now.month, now.day);
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        })
        .where((p) => p.total >= massiveThreshold)
        .toList();
    if (purchasesToday.isNotEmpty) {
      items.add(
        OwnerNotificationItem(
          id: 'massive_stock_entry',
          type: OwnerNotificationType.massiveStockEntry,
          title: 'Entrée massive de stock',
          subtitle:
              '${purchasesToday.length} achat(s) aujourd\'hui ≥ ${formatCurrency(massiveThreshold)}.',
          trailing: formatCurrency(
            purchasesToday.fold<double>(0, (s, p) => s + p.total),
          ),
        ),
      );
    }

    // Produits non vendus depuis au moins 1 mois (uniquement ceux présents en boutique depuis ≥ 30 jours)
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
      items.add(
        OwnerNotificationItem(
          id: 'products_not_sold_months',
          type: OwnerNotificationType.productsNotSoldMonths,
          title: 'Produits non vendus depuis 1 mois',
          subtitle:
              '${notSold.length} produit(s) dans cette boutique depuis au moins 30 jours, sans vente sur les 30 derniers jours.',
          trailing: '${notSold.length}',
        ),
      );
    }

    // Top 10 produits les plus vendus — affichage ultra simple à comprendre
    if (top10Sold.isNotEmpty) {
      final productById = {for (final p in products) p.id: p};
      const explanation = 'Classement des 10 produits les plus vendus. Le nombre = combien d\'unités vendues en 30 jours.';
      final lines = top10Sold.asMap().entries.map((e) {
        final rank = e.key + 1;
        final name = productById[e.value.productId]?.name ?? 'Produit';
        return 'N°$rank  $name  =  ${e.value.quantity} unités vendues';
      }).join('\n');
      items.add(
        OwnerNotificationItem(
          id: 'top_10_products_sold',
          type: OwnerNotificationType.top10ProductsSold,
          title: 'Top 10 : produits qui se vendent le plus',
          subtitle: '$explanation\n\n$lines',
          trailing: '10',
        ),
      );
    }

    // Tendances IA : progression ou régression (CA des 7 derniers jours vs 7 jours précédents)
    final trend = _computeWeeklyTrend(sales);
    items.add(
      OwnerNotificationItem(
        id: 'trends_ai',
        type: OwnerNotificationType.trendsAi,
        title: 'Tendances (IA) — ${trend.label}',
        subtitle: trend.subtitle,
        trailing: trend.trailing,
      ),
    );

    final hiddenIds = ref.watch(ownerNotificationHiddenIdsProvider);
    final visible = items.where((e) => !hiddenIds.contains(e.id)).toList();

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceXl,
                AppTheme.spaceLg,
                AppTheme.spaceXl,
                AppTheme.spaceMd,
              ),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: primary,
                    size: 28,
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceXl),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                            Text(
                              'Aucune notification à afficher',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceSm,
                        horizontal: AppTheme.spaceMd,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        final trendLabel =
                            item.type == OwnerNotificationType.trendsAi
                            ? _computeWeeklyTrend(sales).label
                            : null;
                        final style = _styleForNotification(
                          item.type,
                          trendLabel,
                        );
                        final leadingColor = style.color;
                        final leadingBg = style.color.withOpacity(0.12);
                        return Material(
                          color: theme.colorScheme.surfaceContainerLow
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              border: Border(
                                left: BorderSide(color: style.color, width: 4),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceMd,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: leadingBg,
                                child: Icon(
                                  style.icon,
                                  color: leadingColor,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: leadingColor,
                                ),
                              ),
                              subtitle: item.type == OwnerNotificationType.top10ProductsSold &&
                                      item.subtitle.contains('\n\n')
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.subtitle.split('\n\n').first,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            item.subtitle
                                                .split('\n\n')
                                                .skip(1)
                                                .join('\n\n'),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                  height: 1.4,
                                                ),
                                            maxLines: 12,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(
                                      item.subtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                            height: 1.3,
                                          ),
                                      maxLines: 12,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.trailing != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        item.trailing!,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: leadingColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  TextButton(
                                    onPressed: () {
                                      ref
                                          .read(
                                            ownerNotificationHiddenIdsProvider
                                                .notifier,
                                          )
                                          .update((s) => s..add(item.id));
                                    },
                                    child: Text(
                                      'Masquer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    } catch (_) {
      return Dialog(
        backgroundColor: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible d\'afficher les notifications.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
                label: const Text('Fermer'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

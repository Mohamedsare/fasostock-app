/// Type de notification owner (ruptures, grosses factures, entrées stock, etc.).
enum OwnerNotificationType {
  stockout,
  underMinStock,
  topSalesToday,
  massiveStockEntry,
  productsNotSoldMonths,
  top10ProductsSold,
  trendsAi,
}

/// Une notification affichée dans la boîte owner (top bar, desktop).
class OwnerNotificationItem {
  const OwnerNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String id;
  final OwnerNotificationType type;
  final String title;
  final String subtitle;
  final String? trailing;
}

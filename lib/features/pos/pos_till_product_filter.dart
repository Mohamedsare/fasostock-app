import '../../data/models/product.dart';

/// Règle unique pour **POS rapide** et **Facture A4** : un produit n’apparaît pas
/// s’il est inactif ou si le stock **boutique** (Drift / `store_inventory`) est ≤ 0.
bool isProductShownOnStoreTill(Product p, Map<String, int> stockByProductId) {
  if (!p.isActive) return false;
  return (stockByProductId[p.id] ?? 0) > 0;
}

/// Filtre défensif — même logique que [isProductShownOnStoreTill].
List<Product> filterProductsForStoreTill(
  Iterable<Product> products,
  Map<String, int> stockByProductId,
) {
  return products.where((p) => isProductShownOnStoreTill(p, stockByProductId)).toList();
}

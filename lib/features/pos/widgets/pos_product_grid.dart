import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import 'pos_product_card.dart';

/// Grille de produits POS avec message vide si [products] est vide.
class PosProductGrid extends StatelessWidget {
  const PosProductGrid({
    super.key,
    required this.products,
    required this.stockByProductId,
    required this.onAddToCart,
    this.emptyMessage,
  });

  final List<Product> products;
  final Map<String, int> stockByProductId;
  final void Function(Product p) onAddToCart;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'Aucun produit actif',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossCount = w > 600 ? 4 : 2;
        final aspectRatio = w < 400 ? 0.76 : (w < 600 ? 0.84 : 0.90);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            final stock = stockByProductId[p.id] ?? 0;
            return PosProductCard(
              product: p,
              stock: stock,
              onTap: () => onAddToCart(p),
            );
          },
        );
      },
    );
  }
}

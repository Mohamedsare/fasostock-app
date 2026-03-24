import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import '../pos_quick_constants.dart';
import 'pos_quick_product_card.dart';

/// Grille produits caisse rapide avec pull-to-refresh.
class PosQuickProductGrid extends StatelessWidget {
  const PosQuickProductGrid({
    super.key,
    required this.products,
    required this.stockByProductId,
    required this.onAddToCart,
    required this.onRefresh,
  });

  final List<Product> products;
  final Map<String, int> stockByProductId;
  final void Function(Product p) onAddToCart;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'Aucun produit',
                style: TextStyle(color: PosQuickColors.textePrincipal.withOpacity(0.6), fontSize: 15),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossCount = w > 900 ? 5 : (w > 600 ? 4 : 3);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              final stock = stockByProductId[p.id] ?? 0;
              return PosQuickProductCard(
                product: p,
                stock: stock,
                onTap: () => onAddToCart(p),
              );
            },
          ),
        );
      },
    );
  }
}

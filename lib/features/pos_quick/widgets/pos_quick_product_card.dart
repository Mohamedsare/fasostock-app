import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import '../../pos/widgets/pos_product_card.dart';

/// Carte produit caisse rapide — même rendu que [PosProductCard] (Facture A4).
class PosQuickProductCard extends StatelessWidget {
  const PosQuickProductCard({
    super.key,
    required this.product,
    required this.stock,
    required this.onTap,
  });

  final Product product;
  final int stock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PosProductCard(
      product: product,
      stock: stock,
      onTap: onTap,
    );
  }
}

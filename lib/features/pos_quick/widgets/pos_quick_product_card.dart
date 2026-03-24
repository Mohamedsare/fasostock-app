import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import '../../../shared/utils/format_currency.dart';
import '../pos_quick_constants.dart';

/// Carte produit caisse rapide — thumbnail, nom, prix. Style orange.
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

  bool get disabled => stock <= 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: PosQuickColors.fondPrincipal,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosQuickColors.bordure),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _thumbnail(product),
              const SizedBox(height: 6),
              Text(
                product.name,
                style: const TextStyle(color: PosQuickColors.textePrincipal, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                formatCurrency(product.salePrice),
                style: const TextStyle(color: PosQuickColors.orangePrincipal, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _thumbnail(Product p) {
    final url = p.productImages?.isNotEmpty == true ? p.productImages!.first.url : null;
    return SizedBox(
      width: 48,
      height: 48,
      child: url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: 48,
                height: 48,
                errorBuilder: (_, __, ___) => Icon(Icons.inventory_2_outlined, color: PosQuickColors.orangePrincipal.withOpacity(0.8), size: 28),
              ),
            )
          : Icon(Icons.inventory_2_outlined, color: PosQuickColors.orangePrincipal.withOpacity(0.8), size: 28),
    );
  }
}

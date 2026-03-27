import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import '../../../shared/utils/format_currency.dart';
import '../../pos_quick/pos_quick_constants.dart';

/// Carte produit dans la grille POS — image, nom, prix, stock. Appel à [onTap] si [disabled] est false.
class PosProductCard extends StatelessWidget {
  const PosProductCard({
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: PosQuickColors.fondPrincipal,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: disabled
                  ? PosQuickColors.bordure
                  : PosQuickColors.orangePrincipal.withValues(alpha: 0.35),
              width: disabled ? 1 : 1.5,
            ),
            boxShadow: [
              if (!disabled)
                BoxShadow(
                  color: PosQuickColors.orangePrincipal.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: product.productImages?.isNotEmpty == true
                    ? Image.network(
                        product.productImages!.first.url,
                        height: 98,
                        width: 98,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(98),
                      )
                    : _placeholder(98),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: PosQuickColors.textePrincipal,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatCurrency(product.salePrice)}${stock >= 0 ? ' · $stock' : ''}',
                      style: TextStyle(
                        color: disabled
                            ? PosQuickColors.textePrincipal.withValues(alpha: 0.6)
                            : PosQuickColors.orangePrincipal,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _placeholder([double size = 48]) {
    return Icon(
      Icons.inventory_2_outlined,
      size: size * 0.5,
      color: PosQuickColors.orangePrincipal.withValues(alpha: 0.7),
    );
  }
}

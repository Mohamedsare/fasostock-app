import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import '../../../shared/utils/format_currency.dart';

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
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: disabled ? theme.dividerColor : theme.colorScheme.primary.withOpacity(0.3),
              width: disabled ? 1 : 1.5,
            ),
            boxShadow: [
              if (!disabled)
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.06),
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
                        errorBuilder: (_, __, ___) => _placeholder(theme, 98),
                      )
                    : _placeholder(theme, 98),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatCurrency(product.salePrice)}${stock >= 0 ? ' · $stock' : ''}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
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

  static Widget _placeholder(ThemeData theme, [double size = 48]) {
    return Container(
      height: size,
      width: size,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.inventory_2_rounded, size: size * 0.5, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../data/models/product.dart';

String? firstProductImageUrl(Product p) {
  final imgs = p.productImages;
  if (imgs == null || imgs.isEmpty) return null;
  return imgs.reduce((a, b) => a.position <= b.position ? a : b).url;
}

/// Vignette carrée pour listes transfert / sélecteur produit.
Widget transferProductThumbnail(
  ThemeData theme,
  String? imageUrl, {
  double size = 44,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: size * 0.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: size * 0.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    ),
  );
}

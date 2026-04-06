import 'package:flutter/material.dart';

import '../../../core/breakpoints.dart';
import '../../../data/models/product.dart';
import 'pos_product_card.dart';

/// Bande produits facture-tab : défilement horizontal.
/// — **Ultra mobile** (largeur `<` [Breakpoints.tablet]) : **une seule rangée** de cartes hautes (plus de hauteur utile par tuile).
/// — Tablette / large : **2 rangées** comme avant.
class PosProductTwoRowHorizontalStrip extends StatelessWidget {
  const PosProductTwoRowHorizontalStrip({
    super.key,
    required this.products,
    required this.stockByProductId,
    required this.onAddToCart,
    this.emptyMessage,
    /// Hauteur utile imposée par le parent (ex. bandeau facture mobile) — adapte la bande et les tuiles.
    this.viewportHeight,
  });

  final List<Product> products;
  final Map<String, int> stockByProductId;
  final void Function(Product p) onAddToCart;
  final String? emptyMessage;
  final double? viewportHeight;

  /// Hauteur fixe du bandeau (2 rangées + paddings) — un peu plus haut pour miniatures lisibles.
  static const double stripHeight = 282;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (products.isEmpty) {
      final h = viewportHeight;
      return SizedBox(
        height: h != null && h.isFinite && h > 0 ? h.clamp(80.0, 400.0) : 96,
        child: Center(
          child: Text(
            emptyMessage ?? 'Aucun produit actif',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final w = MediaQuery.sizeOf(context).width;
    final ultraMobileStrip = w < Breakpoints.tablet;
    final crossAxisCount = ultraMobileStrip ? 1 : 2;

    var mainExtent = w >= Breakpoints.factureTabWideFlexStep2
        ? 172.0
        : (w >= Breakpoints.factureTabWideFlexStep1 ? 152.0 : 132.0);
    var stripH = w >= Breakpoints.factureTabWideFlexStep2
        ? 332.0
        : (w >= Breakpoints.factureTabWideFlexStep1 ? 304.0 : stripHeight);
    final vh = viewportHeight;
    if (vh != null && vh.isFinite && vh > 0) {
      stripH = vh;
      // Une rangée sur téléphone : largeur tuile un peu réduite pour faire défiler plus de produits.
      final ref = stripHeight;
      var scale = (vh / ref).clamp(0.65, 1.15);
      if (ultraMobileStrip) {
        scale = (scale * 0.92).clamp(0.7, 1.05);
      }
      mainExtent = (mainExtent * scale).clamp(96.0, 180.0);
    }

    return SizedBox(
      height: stripH,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        // Garde plus de tuiles hors écran « vivantes » pour limiter le rechargement des images au scroll.
        cacheExtent: 480,
        padding: EdgeInsets.fromLTRB(
          12,
          4,
          12,
          ultraMobileStrip ? 8 : (viewportHeight != null && viewportHeight! < 300 ? 8 : 12),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisExtent: mainExtent,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final p = products[index];
          final stock = stockByProductId[p.id] ?? 0;
          return PosProductCard(
            key: ValueKey<String>('pos_strip_${p.id}'),
            product: p,
            stock: stock,
            style: PosProductCardStyle.strip,
            onTap: () => onAddToCart(p),
          );
        },
      ),
    );
  }
}

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
    final cs = theme.colorScheme;
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'Aucun produit actif',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurface,
              ),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

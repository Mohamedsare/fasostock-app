import 'dart:math' show max, min;

import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import '../../../shared/utils/format_currency.dart';
import '../../pos_quick/pos_quick_constants.dart';

/// Variante d’affichage pour [PosProductCard].
enum PosProductCardStyle {
  /// Image grande, texte sous l’image (grille POS classique).
  grid,
  /// Colonne : miniature, nom, prix, stock (bandeau 2 lignes facture-tab).
  strip,
}

/// Carte produit dans la grille POS — image, nom, prix, stock. Appel à [onTap] si [disabled] est false.
class PosProductCard extends StatelessWidget {
  const PosProductCard({
    super.key,
    required this.product,
    required this.stock,
    required this.onTap,
    this.style = PosProductCardStyle.grid,
  });

  final Product product;
  final int stock;
  final VoidCallback? onTap;
  final PosProductCardStyle style;

  bool get disabled => !product.isActive;

  @override
  Widget build(BuildContext context) {
    if (style == PosProductCardStyle.strip) {
      return _buildStripCard(context);
    }
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const hPad = 10.0;
            const vPad = 8.0;
            const gapBelowImage = 3.0;
            // Réserve nom (2 lignes ~13px) + prix — évite overflow de ~1–2px sur grilles serrées.
            const minTextBlock = 38.0;
            final maxImg = 98.0;
            final sideBudget = constraints.maxWidth - 2 * hPad;
            final heightBudget = constraints.maxHeight -
                2 * vPad -
                gapBelowImage -
                minTextBlock;
            final imgSide = min(
              maxImg,
              min(sideBudget, heightBudget),
            ).clamp(56.0, maxImg);
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final cachePx = (imgSide * dpr).round().clamp(48, 512);

            Widget imageBox = ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.productImages?.isNotEmpty == true
                  ? RepaintBoundary(
                      child: Image.network(
                        product.productImages!.first.url,
                        height: imgSide,
                        width: imgSide,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: cachePx,
                        cacheHeight: cachePx,
                        errorBuilder: (_, _, _) => _placeholderIcon(imgSide),
                      ),
                    )
                  : _placeholderIcon(imgSide),
            );

            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: disabled
                      ? cs.outline.withValues(alpha: 0.45)
                      : PosQuickColors.orangePrincipal.withValues(alpha: 0.35),
                  width: disabled ? 1 : 1.5,
                ),
                boxShadow: [
                  if (!disabled)
                    BoxShadow(
                      color: PosQuickColors.orangePrincipal.withValues(
                        alpha: 0.1,
                      ),
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
                  imageBox,
                  const SizedBox(height: gapBelowImage),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            product.name,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.2,
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
                                ? cs.onSurface.withValues(alpha: 0.5)
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
            );
          },
        ),
      ),
    );
  }

  /// Une colonne : miniature, nom, prix, stock. S’adapte à la hauteur des cellules du strip (pas d’overflow).
  Widget _buildStripCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              // Grille 2 rangées : cellules souvent ~120–140 px — il faut budgéter nom + prix + stock sans [Expanded].
              final padV = h < 118 ? 3.0 : 5.0;
              final padH = w < 128 ? 6.0 : 8.0;
              final innerH = h - 2 * padV;
              final gapAfterThumb = innerH < 112 ? 2.0 : (innerH < 126 ? 3.0 : 4.0);
              final nameLines = innerH < 128 ? 1 : 2;
              final nameFontSize = innerH < 112 ? 9.0 : (innerH < 124 ? 10.0 : 11.0);
              final nameLineHeight = 1.12;
              final nameBlockH = nameFontSize * nameLineHeight * nameLines;
              const gapNameToPrice = 2.0;
              final priceFontSize = innerH < 112 ? 10.0 : 11.0;
              final stockFontSize = innerH < 112 ? 9.0 : 10.0;
              // Lignes prix / stock (hauteur réelle ~ fontSize × strut, marge de sécurité +2 px).
              final tailBelowName = gapNameToPrice +
                  (priceFontSize * 1.15 + 2) +
                  1 +
                  (stockFontSize * 1.15 + 2);
              final thumbBudget =
                  innerH - gapAfterThumb - nameBlockH - tailBelowName;
              final thumb = min(
                w - 2 * padH - 2,
                min(
                  innerH * 0.48,
                  thumbBudget.isFinite ? max(22.0, thumbBudget) : innerH * 0.35,
                ),
              ).clamp(22.0, 72.0);
              final nameStyle = TextStyle(
                color: disabled
                    ? cs.onSurface.withValues(alpha: 0.55)
                    : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: nameFontSize,
                height: nameLineHeight,
              );
              final priceStyle = TextStyle(
                color: disabled
                    ? cs.onSurface.withValues(alpha: 0.5)
                    : PosQuickColors.orangePrincipal,
                fontSize: priceFontSize,
                fontWeight: FontWeight.w800,
                height: 1.05,
              );
              final stockStyle = TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: stockFontSize,
                fontWeight: FontWeight.w500,
                height: 1.05,
              );

              final dpr = MediaQuery.devicePixelRatioOf(context);
              final cachePx = (thumb * dpr).round().clamp(48, 512);
              Widget thumbChild = product.productImages?.isNotEmpty == true
                  ? RepaintBoundary(
                      child: Image.network(
                        product.productImages!.first.url,
                        height: thumb,
                        width: thumb,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: cachePx,
                        cacheHeight: cachePx,
                        errorBuilder: (_, _, _) =>
                            Center(child: _placeholderIcon(thumb)),
                      ),
                    )
                  : Center(child: _placeholderIcon(thumb));

              return Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: disabled
                        ? cs.outline.withValues(alpha: 0.45)
                        : PosQuickColors.orangePrincipal
                            .withValues(alpha: 0.35),
                    width: disabled ? 1 : 1.5,
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: padH,
                  vertical: padV,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: thumb,
                        height: thumb,
                        child: thumbChild,
                      ),
                    ),
                    SizedBox(height: gapAfterThumb),
                    SizedBox(
                      height: nameBlockH,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          product.name,
                          style: nameStyle,
                          maxLines: nameLines,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(height: gapNameToPrice),
                    Text(
                      formatCurrency(product.salePrice),
                      style: priceStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      stock >= 0 ? 'Stock : $stock' : 'Stock : —',
                      style: stockStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _placeholderIcon([double size = 48]) {
    return Icon(
      Icons.inventory_2_outlined,
      size: size * 0.5,
      color: PosQuickColors.orangePrincipal.withValues(alpha: 0.7),
    );
  }
}

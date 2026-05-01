import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Indicateur de niveau de stock (équivalent StockRangeSlider web).
/// Affiche la quantité et une barre colorée : rouge (rupture), orange (faible), gris, vert.
class StockRangeIndicator extends StatelessWidget {
  const StockRangeIndicator({
    super.key,
    required this.quantity,
    required this.alertThreshold,
  });

  final int quantity;
  final int alertThreshold;

  static Color _colorForVariant(String variant, BuildContext context) {
    final theme = Theme.of(context);
    switch (variant) {
      case 'danger':
        return theme.colorScheme.error;
      case 'warning':
        return Colors.amber;
      case 'success':
        return Colors.green;
      default:
        return theme.colorScheme.outline;
    }
  }

  static String _variant(int qty, int threshold) {
    final t = threshold <= 0 ? 5 : threshold;
    final q = qty.clamp(0, 0x7fffffff);
    if (q <= 0) return 'danger';
    if (q <= t) return 'warning';
    if (q <= 2 * t) return 'default';
    return 'success';
  }

  @override
  Widget build(BuildContext context) {
    final t = alertThreshold <= 0 ? 5 : alertThreshold;
    final q = quantity.clamp(0, 0x7fffffff);
    final max = [q, 2 * t, 10].reduce((a, b) => a > b ? a : b);
    final percent = max > 0 ? (q / max).clamp(0.0, 1.0) : 0.0;
    final variant = _variant(quantity, t);
    final color = _colorForVariant(variant, context);
    final isOutOfStock = q <= 0;
    final effectivePercent = isOutOfStock ? 1.0 : percent;
    final effectiveBackground = isOutOfStock
        ? color.withValues(alpha: 0.55)
        : color.withValues(alpha: 0.2);

    return LayoutBuilder(
      builder: (context, constraints) {
        const qtyW = 28.0;
        const gap = 8.0;
        final maxW = constraints.maxWidth;
        final barW = maxW.isFinite ? math.max(0.0, maxW - qtyW - gap) : 72.0;
        return Row(
          children: [
            SizedBox(
              width: qtyW,
              child: Text(
                '$quantity',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: barW,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: effectivePercent,
                  minHeight: 8,
                  backgroundColor: effectiveBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

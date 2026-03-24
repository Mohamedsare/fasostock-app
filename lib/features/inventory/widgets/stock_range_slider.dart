import 'package:flutter/material.dart';

/// Variant visuel du niveau de stock (aligné web StockRangeSlider).
enum StockRangeVariant { danger, warning, default_, success }

/// Calcule le variant à partir de la quantité et du seuil (aligné getStockRange web).
StockRangeVariant getStockRangeVariant(int quantity, int alertThreshold) {
  final threshold = alertThreshold > 0 ? alertThreshold : 5;
  final q = quantity.clamp(0, 999999);
  if (q <= 0) return StockRangeVariant.danger;
  if (q <= threshold) return StockRangeVariant.warning;
  if (q <= 2 * threshold) return StockRangeVariant.default_;
  return StockRangeVariant.success;
}

/// Barre de niveau de stock — rupture (rouge), faible (ambre), moyen (gris), bon (vert).
class StockRangeSlider extends StatelessWidget {
  const StockRangeSlider({
    super.key,
    required this.quantity,
    required this.alertThreshold,
  });

  final int quantity;
  final int alertThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final threshold = alertThreshold > 0 ? alertThreshold : 5;
    final qty = quantity.clamp(0, 999999);
    final max = [qty, 2 * threshold, 10].reduce((a, b) => a > b ? a : b);
    final percent = max > 0 ? (qty / max).clamp(0.0, 1.0) * 100 : 0.0;
    final variant = getStockRangeVariant(quantity, alertThreshold);

    Color fillColor;
    Color trackColor;
    switch (variant) {
      case StockRangeVariant.danger:
        fillColor = theme.colorScheme.error;
        trackColor = theme.colorScheme.error.withValues(alpha: 0.2);
        break;
      case StockRangeVariant.warning:
        fillColor = Colors.amber.shade700;
        trackColor = Colors.amber.withValues(alpha: 0.2);
        break;
      case StockRangeVariant.success:
        fillColor = Colors.green.shade700;
        trackColor = Colors.green.withValues(alpha: 0.2);
        break;
      case StockRangeVariant.default_:
        fillColor = theme.colorScheme.onSurfaceVariant;
        trackColor = theme.colorScheme.surfaceContainerHighest;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '$qty',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 10,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
        ),
      ],
    );
  }
}

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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$quantity',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

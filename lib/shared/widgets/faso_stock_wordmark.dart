import 'package:flutter/material.dart';

/// Marque « Faso » (noir / onSurface) + « Stock » (orange accent) — aligné web / maquette.
class FasoStockWordmark extends StatelessWidget {
  const FasoStockWordmark({
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fasoColor = theme.brightness == Brightness.light
        ? const Color(0xFF1C1B1F)
        : theme.colorScheme.onSurface;

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: 'Faso', style: TextStyle(color: fasoColor)),
          TextSpan(text: 'Stock', style: TextStyle(color: primary)),
        ],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

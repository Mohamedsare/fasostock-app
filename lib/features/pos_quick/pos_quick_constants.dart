import 'package:flutter/material.dart';

/// Couleurs POS Caisse Rapide (FasoStock).
class PosQuickColors {
  PosQuickColors._();

  static const Color orangePrincipal = Color(0xFFF97316);
  static const Color orangeClair = Color(0xFFFDBA74);
  static const Color fondPrincipal = Color(0xFFFFFFFF);
  static const Color fondSecondaire = Color(0xFFF8F9FA);
  static const Color textePrincipal = Color(0xFF1F2937);
  static const Color bordure = Color(0xFFE5E7EB);
}

/// Thème Material du contexte — lisible en mode clair et sombre.
extension PosThemeContext on BuildContext {
  ColorScheme get posScheme => Theme.of(this).colorScheme;
}

/// Champs POS : surfaces et bords issus du [ColorScheme].
class PosInputTheme {
  PosInputTheme._();

  static InputDecoration denseField(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const r = 8.0;
    final br = BorderRadius.circular(r);
    final side = BorderSide(color: cs.outline.withValues(alpha: 0.45));
    final ob = OutlineInputBorder(borderRadius: br, borderSide: side);
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: ob,
      enabledBorder: ob,
      focusedBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    );
  }

  static InputDecoration roundedField(
    BuildContext context, {
    double radius = 12,
    EdgeInsetsGeometry? contentPadding,
    String? labelText,
    String? hintText,
    TextStyle? hintStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final br = BorderRadius.circular(radius);
    final side = BorderSide(color: cs.outline.withValues(alpha: 0.45));
    final ob = OutlineInputBorder(borderRadius: br, borderSide: side);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: hintStyle ??
          t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: contentPadding,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: ob,
      enabledBorder: ob,
      focusedBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
    );
  }

  static InputDecoration dropdownDecoration(
    BuildContext context, {
    double radius = 8,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    bool isDense = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final br = BorderRadius.circular(radius);
    final side = BorderSide(color: cs.outline.withValues(alpha: 0.45));
    final ob = OutlineInputBorder(borderRadius: br, borderSide: side);
    return InputDecoration(
      isDense: isDense,
      contentPadding: contentPadding,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: ob,
      enabledBorder: ob,
      focusedBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    );
  }
}

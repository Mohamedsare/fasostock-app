import 'package:flutter/material.dart';

/// Palette admin — tons doux, ni blanc pur ni trop sombre.
class AdminPalette {
  AdminPalette._();
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color accent = Color(0xFFEA580C);
  /// Fond des cartes et champs (gris très clair, pas de blanc pur).
  static const Color surface = Color(0xFFF1F5F9);
  /// Fond de la zone de contenu (légèrement plus clair que surface).
  static const Color surfaceAlt = Color(0xFFF8FAFC);
  static const Color appBarBg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFCBD5E1);
  /// Texte principal (gris foncé lisible, pas noir).
  static const Color title = Color(0xFF475569);
  /// Texte secondaire (gris moyen).
  static const Color subtitle = Color(0xFF64748B);
  static const Color muted = Color(0xFF94A3B8);

  /// En-têtes de tableau (lisibles, contraste élevé).
  static const TextStyle dataTableHeader = TextStyle(
    fontWeight: FontWeight.w700,
    color: AdminPalette.title,
    fontSize: 13,
  );
  /// Cellules de tableau (texte principal lisible).
  static const TextStyle dataTableCell = TextStyle(
    color: AdminPalette.title,
    fontSize: 14,
  );
}

/// Décoration des champs de formulaire admin (bordure, radius cohérents).
InputDecoration adminInputDecoration({
  required String labelText,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AdminPalette.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AdminPalette.accent, width: 1.5),
    ),
    filled: true,
    fillColor: AdminPalette.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

/// En-tête de page admin — titre + description (design cohérent).
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AdminPalette.title,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AdminPalette.subtitle,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Carte admin — fond gris très clair (pas de blanc pur), bordure douce, radius 16.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminPalette.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}

import 'package:flutter/material.dart';

/// Toasts de succès, erreur et info — design soigné, positionnement au-dessus de la bottom nav.
class AppToast {
  AppToast._();

  /// Marge basse pour afficher au-dessus de la barre de navigation (évite le recouvrement).
  static const EdgeInsets _margin = EdgeInsets.fromLTRB(16, 0, 16, 80);

  static const Color _successBgLight = Color(0xFF166534);
  static const Color _successBgDark = Color(0xFF15803D);
  static const Color _errorBgLight = Color(0xFFB91C1C);
  static const Color _errorBgDark = Color(0xFFDC2626);
  static const Color _infoBgLight = Color(0xFF1E40AF);
  static const Color _infoBgDark = Color(0xFF2563EB);

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: Theme.of(context).brightness == Brightness.light ? _successBgLight : _successBgDark,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: Theme.of(context).brightness == Brightness.light ? _errorBgLight : _errorBgDark,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: Theme.of(context).brightness == Brightness.light ? _infoBgLight : _infoBgDark,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: _margin,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: backgroundColor,
        duration: const Duration(milliseconds: 3200),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

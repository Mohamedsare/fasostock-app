import 'dart:async';

import 'package:flutter/material.dart';

/// Toasts de succès, erreur et info — design soigné.
///
/// Affichage via le [Overlay] du [Navigator] racine : **au-dessus des dialogues**,
/// bottom sheets et du reste de l’UI (équivalent « z-index » maximal dans Flutter).
class AppToast {
  AppToast._();

  /// Marge basse pour afficher au-dessus de la barre de navigation (évite le recouvrement).
  static const double _bottomInset = 80;

  static OverlayEntry? _overlayEntry;
  static Timer? _hideTimer;

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

  /// Overlay du [Navigator] racine : dernier [Overlay.insert] = peint au-dessus (modales incluses).
  static OverlayState? _rootOverlay(BuildContext context) {
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    final o = rootNav?.overlay;
    if (o != null) return o;
    return Overlay.maybeOf(context, rootOverlay: true);
  }

  static void _dismissActive() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    if (!context.mounted) return;

    // Anciens SnackBars éventuels (autres chemins) ne doivent pas rester visibles.
    try {
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    } catch (_) {}

    _dismissActive();

    final theme = Theme.of(context);
    final overlay = _rootOverlay(context);
    if (overlay == null) {
      _showSnackBarFallback(
        context,
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        theme: theme,
      );
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom + _bottomInset;
        return Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: Material(
            elevation: 24,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            color: backgroundColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
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
          ),
        );
      },
    );

    _overlayEntry = entry;
    overlay.insert(entry);

    _hideTimer = Timer(const Duration(milliseconds: 3200), _dismissActive);
  }

  /// Si aucun overlay (tests / embed rare) : comportement proche de l’ancien SnackBar.
  static void _showSnackBarFallback(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required ThemeData theme,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, _bottomInset),
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

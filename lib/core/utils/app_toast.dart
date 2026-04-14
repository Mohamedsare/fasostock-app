import 'dart:async';

import 'package:flutter/material.dart';

/// Toasts de succès, erreur et info — design soigné.
///
/// Affichage **en haut** de l’écran (sous la zone sûre), via [Overlay] : au-dessus des dialogues,
/// bottom sheets et du reste de l’UI.
class AppToast {
  AppToast._();

  /// Marge sous la zone sûre haute (statut / encoche) — toast en haut de l’écran.
  static const double _topInset = 12;

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

  /// Overlay du navigateur qui **porte la route actuelle** (Shell / GoRouter), puis racine.
  ///
  /// Avant : on prenait d’abord le navigateur racine — sur desktop, l’overlay utile est souvent
  /// celui du navigateur **imbriqué** ; sinon [Overlay.maybeOf] restait null → repli SnackBar **en bas**.
  static OverlayState? _resolveOverlay(BuildContext context) {
    final nav = Navigator.maybeOf(context);
    if (nav?.overlay != null) return nav!.overlay;
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav?.overlay != null) return rootNav!.overlay;
    return Overlay.maybeOf(context, rootOverlay: false) ??
        Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.maybeOf(context);
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

    // Anciens SnackBars / bannières (repli) ne doivent pas rester visibles.
    try {
      final m = ScaffoldMessenger.maybeOf(context);
      m?.hideCurrentSnackBar();
      m?.hideCurrentMaterialBanner();
    } catch (_) {}

    _dismissActive();

    final theme = Theme.of(context);
    final overlay = _resolveOverlay(context);
    if (overlay == null) {
      _showTopFallback(
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
        final top = MediaQuery.paddingOf(ctx).top + _topInset;
        return Positioned(
          left: 16,
          right: 16,
          top: top,
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

  /// Si aucun [Overlay] (tests / embed rare) : bannière **en haut** du [Scaffold] (pas SnackBar en bas).
  static void _showTopFallback(
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
    try {
      messenger.hideCurrentMaterialBanner();
    } catch (_) {}

    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Icon(icon, color: Colors.white, size: 22),
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () {
              _hideTimer?.cancel();
              _hideTimer = null;
              try {
                messenger.hideCurrentMaterialBanner();
              } catch (_) {}
            },
          ),
        ],
      ),
    );

    _hideTimer = Timer(const Duration(milliseconds: 3200), () {
      try {
        messenger.hideCurrentMaterialBanner();
      } catch (_) {}
      _hideTimer = null;
    });
  }
}

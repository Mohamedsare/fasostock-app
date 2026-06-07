import 'package:flutter/material.dart';
import '../../../core/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import 'fs_haptic.dart';

/// Affiche un contenu modal de manière adaptative :
/// - **Sur mobile (< 600px)** : `showModalBottomSheet` (sheet plein écran possible, drag handle,
///   safe area, surface arrondie en haut) — pattern Material 3 mobile.
/// - **Sur desktop (≥ 600px)** : `showDialog` classique (centré, barrière modale).
///
/// L'API reste équivalente à `showDialog<T>` côté caller : `Navigator.pop(context, value)` fonctionne
/// pareil dans les deux modes.
///
/// ```dart
/// final result = await showFsResponsiveModal<bool>(
///   context: context,
///   builder: (ctx) => _MyEditDialog(),
/// );
/// ```
Future<T?> showFsResponsiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  bool isScrollControlled = true,
}) {
  final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
  if (isMobile) {
    FsHaptic.light();
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      barrierColor: barrierColor,
      clipBehavior: Clip.antiAlias,
    );
  }
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );
}

/// Variante "confirmation" — fenêtre courte avec titre, message et 2 boutons (annuler / confirmer).
/// Sur mobile, devient un bottom sheet compact ; sur desktop, un AlertDialog classique.
/// Renvoie `true` si l'utilisateur confirme, `false`/`null` sinon.
Future<bool?> showFsConfirm({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  IconData? icon,
  bool dangerous = false,
}) {
  return showFsResponsiveModal<bool>(
    context: context,
    builder: (ctx) => _FsConfirmContent(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      dangerous: dangerous,
    ),
  );
}

class _FsConfirmContent extends StatelessWidget {
  const _FsConfirmContent({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.dangerous,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final bool dangerous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final danger = dangerous ? cs.error : cs.primary;
    final iconColor = dangerous ? cs.error : cs.primary;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? AppTheme.spaceLgM : AppTheme.spaceXl,
        isMobile ? AppTheme.spaceMdM : AppTheme.spaceLg,
        isMobile ? AppTheme.spaceLgM : AppTheme.spaceXl,
        isMobile ? AppTheme.spaceLgM : AppTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
            ),
            SizedBox(height: isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd),
          ],
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: icon != null ? TextAlign.center : TextAlign.start,
          ),
          if (message != null && message!.isNotEmpty) ...[
            SizedBox(height: isMobile ? AppTheme.spaceSmM : AppTheme.spaceSm),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: icon != null ? TextAlign.center : TextAlign.start,
            ),
          ],
          SizedBox(height: isMobile ? AppTheme.spaceLgM : AppTheme.spaceLg),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: danger,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    FsHaptic.medium();
                    Navigator.of(context).pop(true);
                  },
                  child: Text(confirmLabel),
                ),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: danger),
                  onPressed: () {
                    FsHaptic.medium();
                    Navigator.of(context).pop(true);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            ),
        ],
      ),
    );

    if (isMobile) {
      return SafeArea(top: false, child: content);
    }
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: content,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adapte la couleur des icônes système (status bar / navigation bar Android) selon le thème :
/// fond clair → icônes sombres, fond sombre → icônes claires. Sans ça, la barre d'état du
/// téléphone reste figée et fait "non natif" en mode sombre.
///
/// À placer une fois au plus haut niveau du shell mobile (au-dessus du Scaffold).
class FsStatusBar extends StatelessWidget {
  const FsStatusBar({
    super.key,
    required this.child,
    this.transparentNavigationBar = true,
  });

  final Widget child;

  /// Sur Android, rend la barre de navigation système transparente (edge-to-edge moderne).
  final bool transparentNavigationBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: transparentNavigationBar
            ? Colors.transparent
            : theme.colorScheme.surface,
        systemNavigationBarIconBrightness: isLight
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}

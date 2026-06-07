import 'package:flutter/material.dart';

import '../../../core/breakpoints.dart';

/// En-tête de page listes / pilotage.
///
/// **Mobile** : le titre est dans l’AppBar du shell ([MobileShellTitle]) — ici
/// seulement le sous-titre et les actions (évite double barre + titre qui scroll).
///
/// **Desktop / tablette** : titre + sous-titre + actions comme avant.
class FsMobilePageHeader extends StatelessWidget {
  const FsMobilePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  static bool isMobileLayout(BuildContext context) =>
      Breakpoints.isMobile(MediaQuery.sizeOf(context).width);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = isMobileLayout(context);

    final subtitleWidget = subtitle == null
        ? null
        : Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );

    if (mobile) {
      if (subtitleWidget == null && trailing == null) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?subtitleWidget,
          if (trailing != null) ...[
            if (subtitleWidget != null) const SizedBox(height: 12),
            trailing!,
          ],
        ],
      );
    }

    if (trailing != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _titleBlock(theme, subtitleWidget)),
          const SizedBox(width: 12),
          trailing!,
        ],
      );
    }

    return _titleBlock(theme, subtitleWidget);
  }

  Widget _titleBlock(ThemeData theme, Widget? subtitleWidget) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitleWidget != null) ...[
          const SizedBox(height: 4),
          subtitleWidget,
        ],
      ],
    );
  }
}

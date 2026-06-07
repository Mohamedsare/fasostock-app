import 'package:flutter/material.dart';
import 'fs_haptic.dart';

/// `RefreshIndicator` enrichi pour FasoStock : couleurs du thème, haptique au déclenchement
/// (pattern natif iOS/Android), et `AlwaysScrollableScrollPhysics` automatique si nécessaire
/// pour que le pull fonctionne même sur contenus courts.
///
/// Remplace les `RefreshIndicator(...)` bruts pour donner un "feel" natif uniforme.
class FsPullToRefresh extends StatelessWidget {
  const FsPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 56,
    this.edgeOffset = 0,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double displacement;
  final double edgeOffset;

  Future<void> _handleRefresh() async {
    FsHaptic.light();
    await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      strokeWidth: 2.6,
      displacement: displacement,
      edgeOffset: edgeOffset,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      child: child,
    );
  }
}

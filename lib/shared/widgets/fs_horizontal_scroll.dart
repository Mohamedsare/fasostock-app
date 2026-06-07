import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/breakpoints.dart';

/// Seuil aligné sur le web : barre fine + molette utile à partir de [Breakpoints.desktop].
bool fsUseDesktopHorizontalScrollUx(BuildContext context) {
  return Breakpoints.isDesktop(MediaQuery.sizeOf(context).width);
}

/// Enveloppe un scrollable **horizontal** : sur desktop, scrollbar fine toujours visible
/// quand le contenu dépasse, et la molette verticale de la souris fait défiler horizontalement.
///
/// [builder] reçoit un [ScrollController] à attacher **obligatoirement** au scrollable horizontal.
class FsHorizontalScrollShell extends StatefulWidget {
  const FsHorizontalScrollShell({
    super.key,
    required this.builder,
    this.mouseWheelToHorizontal = true,
  });

  final Widget Function(BuildContext context, ScrollController controller) builder;
  final bool mouseWheelToHorizontal;

  @override
  State<FsHorizontalScrollShell> createState() => _FsHorizontalScrollShellState();
}

class _FsHorizontalScrollShellState extends State<FsHorizontalScrollShell> {
  late final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.mouseWheelToHorizontal) return;
    if (!fsUseDesktopHorizontalScrollUx(context)) return;
    if (event is! PointerScrollEvent) return;
    if (event.kind != PointerDeviceKind.mouse) return;
    final c = _controller;
    if (!c.hasClients) return;
    final dy = event.scrollDelta.dy;
    final dx = event.scrollDelta.dx;
    if (dy == 0) return;
    if (dx.abs() >= dy.abs()) return;
    final pos = c.position;
    if (pos.maxScrollExtent <= 0) return;
    final atStart = c.offset <= 0 && dy < 0;
    final atEnd = c.offset >= pos.maxScrollExtent - 0.5 && dy > 0;
    if (atStart || atEnd) return;
    final next = (c.offset + dy).clamp(0.0, pos.maxScrollExtent);
    c.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = fsUseDesktopHorizontalScrollUx(context);
    Widget body = widget.builder(context, _controller);

    if (desktop) {
      body = Scrollbar(
        controller: _controller,
        thickness: 5,
        radius: const Radius.circular(999),
        thumbVisibility: true,
        child: body,
      );
    }

    if (desktop && widget.mouseWheelToHorizontal) {
      body = Listener(
        onPointerSignal: _onPointerSignal,
        child: body,
      );
    }

    return body;
  }
}

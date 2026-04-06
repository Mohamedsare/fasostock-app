import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../pos_quick/pos_quick_constants.dart';

/// P.U. facture (FCFA entiers) : commit après pause de frappe ou perte de focus.
class PosCartUnitPriceField extends StatefulWidget {
  const PosCartUnitPriceField({
    super.key,
    required this.controller,
    required this.currentUnitPrice,
    required this.onCommit,
    this.surfaceColor,
  });

  final TextEditingController controller;
  final double currentUnitPrice;
  final Color? surfaceColor;
  final void Function(double value) onCommit;

  @override
  State<PosCartUnitPriceField> createState() => _PosCartUnitPriceFieldState();
}

class _PosCartUnitPriceFieldState extends State<PosCartUnitPriceField> {
  static const int _kDebounceMs = 700;
  static const double _kMaxPu = 999_999_999;

  Timer? _debounce;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _flush();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PosCartUnitPriceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = widget.currentUnitPrice.round();
    final b = oldWidget.currentUnitPrice.round();
    if (a == b) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_fieldIsFocusedForSync()) return;
      final want = '$a';
      try {
        if (widget.controller.text != want) {
          widget.controller.text = want;
        }
      } catch (_) {
        // Contrôleur disposé par le parent avant ce frame.
      }
    });
  }

  bool _fieldIsFocusedForSync() {
    if (_focusNode.hasFocus) return true;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    if (identical(primary, _focusNode)) return true;
    for (final n in primary.children) {
      if (identical(n, _focusNode)) return true;
    }
    return false;
  }

  double _parseCommit(String t) {
    final digits = t.replaceAll(RegExp(r'\s'), '');
    if (digits.isEmpty) return widget.currentUnitPrice;
    final n = int.tryParse(digits);
    if (n == null) return widget.currentUnitPrice;
    return n.clamp(0, _kMaxPu).toDouble();
  }

  void _flush() {
    _debounce?.cancel();
    final t = widget.controller.text.trim();
    if (t.isEmpty) {
      widget.controller.text = '${widget.currentUnitPrice.round()}';
      return;
    }
    final v = _parseCommit(t);
    if (v.round() != widget.currentUnitPrice.round()) {
      widget.onCommit(v);
    } else {
      widget.controller.text = '${v.round()}';
    }
  }

  void _onTypingPaused() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _kDebounceMs), () {
      if (!mounted) return;
      final t = widget.controller.text.trim();
      if (t.isEmpty) return;
      final v = _parseCommit(t);
      if (v.round() != widget.currentUnitPrice.round()) {
        widget.onCommit(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final baseDeco = PosInputTheme.denseField(context);
    return TextField(
      focusNode: _focusNode,
      controller: widget.controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.end,
      style: theme.textTheme.titleSmall?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      decoration: baseDeco.copyWith(
        fillColor: widget.surfaceColor ?? baseDeco.fillColor,
        hintText: '0',
        hintStyle: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
      onChanged: (_) => _onTypingPaused(),
      onEditingComplete: _flush,
      onSubmitted: (_) {
        _debounce?.cancel();
        _flush();
      },
      onTap: () => widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      ),
    );
  }
}

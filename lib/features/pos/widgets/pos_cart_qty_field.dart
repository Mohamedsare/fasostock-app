import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../pos_quick/pos_quick_constants.dart';

/// Champ quantité : la valeur n’est envoyée au panier qu’après **fin de saisie**
/// (pause d’au moins [_kDebounceMs] sans frappe, ou sortie du champ / Entrée).
class PosCartQtyField extends StatefulWidget {
  const PosCartQtyField({
    super.key,
    required this.controller,
    required this.currentQuantity,
    required this.surfaceColor,
    required this.onCommit,
  });

  final TextEditingController controller;
  final int currentQuantity;
  final Color surfaceColor;
  final void Function(int value) onCommit;

  @override
  State<PosCartQtyField> createState() => _PosCartQtyFieldState();
}

class _PosCartQtyFieldState extends State<PosCartQtyField> {
  /// Délai sans nouvelle frappe avant d’appliquer la quantité (arrêt de saisie).
  static const int _kDebounceMs = 700;

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
  void didUpdateWidget(PosCartQtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentQuantity == oldWidget.currentQuantity) return;

    /// Après le frame : évite d’écraser le brouillon (ex. champ vidé) quand `hasFocus`
    /// n’est pas encore fiable au même tick qu’un `setState` parent — aligné web
    /// (`activeElement` + `useLayoutEffect`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Tant que ce champ a le focus (ou est le focus primaire), ne pas réinjecter la quantité panier.
      if (_fieldIsFocusedForSync()) return;
      final want =
          widget.currentQuantity == 0 ? '' : '${widget.currentQuantity}';
      if (widget.controller.text != want) {
        widget.controller.text = want;
      }
    });
  }

  /// `hasFocus` seul peut être faux un court instant ; on aligne aussi sur le focus primaire.
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

  void _flush() {
    _debounce?.cancel();
    final t = widget.controller.text.trim();
    if (t.isEmpty) return;
    final n = int.tryParse(t);
    if (n != null && n >= 0 && n != widget.currentQuantity) widget.onCommit(n);
  }

  void _onTypingPaused() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _kDebounceMs), () {
      if (!mounted) return;
      final t = widget.controller.text.trim();
      if (t.isEmpty) return;
      final n = int.tryParse(t);
      if (n != null && n >= 0 && n != widget.currentQuantity) {
        widget.onCommit(n);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _focusNode,
      controller: widget.controller,
      keyboardType: TextInputType.text,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: PosQuickColors.textePrincipal,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: widget.surfaceColor,
      ),
      onChanged: (_) => _onTypingPaused(),
      onEditingComplete: _flush,
      onSubmitted: (_) {
        _debounce?.cancel();
        final t = widget.controller.text.trim();
        final n = int.tryParse(t);
        if (n != null && n >= 0 && n != widget.currentQuantity) {
          widget.onCommit(n);
        } else if (n == null || n < 0) {
          widget.controller.text = widget.currentQuantity == 0
              ? ''
              : '${widget.currentQuantity}';
        }
      },
      onTap: () => widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      ),
    );
  }
}

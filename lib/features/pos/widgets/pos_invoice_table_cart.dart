import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/breakpoints.dart';
import '../../../providers/pos_cart_settings_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../../pos_quick/pos_quick_constants.dart';
import '../pos_models.dart';
import 'pos_cart_qty_field.dart';
import 'pos_cart_unit_price_field.dart';

/// Panier POS facture : lignes en tableau (même données / même PDF A4 que les tuiles).
class PosInvoiceTableCart extends StatelessWidget {
  const PosInvoiceTableCart({
    super.key,
    required this.cart,
    required this.effectiveStock,
    required this.qtyControllers,
    required this.puControllers,
    required this.onQtyDelta,
    required this.onSetQty,
    required this.onSetUnitPrice,
    required this.onUnitChange,
    required this.onRemove,
  });

  final List<PosCartItem> cart;
  final int Function(String productId) effectiveStock;
  final Map<String, TextEditingController> qtyControllers;
  final Map<String, TextEditingController> puControllers;
  final void Function(String productId, int delta) onQtyDelta;
  final void Function(String productId, int value) onSetQty;
  final void Function(String productId, double unitPrice) onSetUnitPrice;
  final void Function(String productId, String unit) onUnitChange;
  final void Function(String productId) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final settings = context.read<PosCartSettingsProvider>();
    // [ListenableBuilder] : réagit aux réglages sans [context.watch] (évite les assertions
    // InheritedWidget à la fermeture de dialogues / routes empilés avec le POS).
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final showInput = settings.invoiceShowQuantityInput;
        final showButtons = settings.invoiceShowQuantityButtons;

        final headerStyle = theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: cs.onSurface,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenW = MediaQuery.sizeOf(context).width;
            var viewportW = constraints.maxWidth;
            if (!viewportW.isFinite || viewportW <= 0) {
              viewportW = screenW;
            }
            final ultraMobile = screenW < Breakpoints.tablet;
            final tabletNeedsScroll = !ultraMobile &&
                screenW < Breakpoints.shellDesktop;
            // Téléphone / tablette : minWidth > viewport → scroll horizontal, colonne Article et Qté lisibles.
            final tableMinWidth = ultraMobile
                ? math.max(520.0, viewportW)
                : tabletNeedsScroll
                    ? math.max(640.0, viewportW * 1.1)
                    : math.max(320.0, viewportW);
            final headerCompact = ultraMobile || tabletNeedsScroll;

            final table = Table(
              border: TableBorder.all(
                color: cs.outline.withValues(alpha: 0.4),
                width: 1,
              ),
              columnWidths: const {
                0: FlexColumnWidth(3.0),
                1: FlexColumnWidth(0.85),
                2: FlexColumnWidth(1.1),
                3: FlexColumnWidth(1.25),
                4: FlexColumnWidth(1.0),
                5: FixedColumnWidth(52),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                  ),
                  children: [
                    _hCell('Article', headerStyle, compact: headerCompact),
                    _hCell(
                      headerCompact ? 'U.' : 'Unité',
                      headerStyle,
                      compact: headerCompact,
                    ),
                    _hCell('Qté', headerStyle, compact: headerCompact),
                    _hCell('P.U.', headerStyle, compact: headerCompact),
                    _hCell(
                      headerCompact ? 'T.' : 'Total',
                      headerStyle,
                      compact: headerCompact,
                    ),
                    _hCell('', headerStyle, compact: headerCompact),
                  ],
                ),
                ...cart.map((c) {
              final stock = effectiveStock(c.productId);
              final lowStock = stock >= 0 && c.quantity > stock;
              final controller = qtyControllers[c.productId]!;
              final puController = puControllers[c.productId]!;
              return TableRow(
                decoration: BoxDecoration(
                  color: lowStock
                      ? Colors.red.shade50.withValues(alpha: 0.35)
                      : null,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.25,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lowStock)
                          Text(
                            'Stock: $stock',
                            style: TextStyle(
                              color: cs.error,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: kInvoiceUnits.contains(c.unit) ? c.unit : 'pce',
                      isDense: true,
                      isExpanded: true,
                      dropdownColor: cs.surfaceContainerHigh,
                      style: TextStyle(color: cs.onSurface, fontSize: 13),
                      decoration: PosInputTheme.dropdownDecoration(context),
                      items: kInvoiceUnits
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(
                                u,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onUnitChange(c.productId, v);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showButtons)
                            IconButton.filled(
                              tooltip: 'Diminuer la quantité',
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                onQtyDelta(c.productId, -1);
                              },
                              icon: const Icon(Icons.remove_rounded, size: 22),
                              style: IconButton.styleFrom(
                                shape: const CircleBorder(),
                                fixedSize: const Size(
                                  Breakpoints.minTouchTarget,
                                  Breakpoints.minTouchTarget,
                                ),
                                minimumSize: const Size(
                                  Breakpoints.minTouchTarget,
                                  Breakpoints.minTouchTarget,
                                ),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor:
                                    cs.surfaceContainerHighest,
                                foregroundColor: cs.onSurface,
                              ),
                            ),
                          if (showInput)
                            SizedBox(
                              width: 72,
                              child: PosCartQtyField(
                                controller: controller,
                                currentQuantity: c.quantity,
                                onCommit: (v) => onSetQty(c.productId, v),
                              ),
                            )
                          else
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '${c.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          if (showButtons)
                            IconButton.filled(
                              tooltip: 'Augmenter la quantité',
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                onQtyDelta(c.productId, 1);
                              },
                              icon: const Icon(Icons.add_rounded, size: 22),
                              style: IconButton.styleFrom(
                                shape: const CircleBorder(),
                                fixedSize: const Size(
                                  Breakpoints.minTouchTarget,
                                  Breakpoints.minTouchTarget,
                                ),
                                minimumSize: const Size(
                                  Breakpoints.minTouchTarget,
                                  Breakpoints.minTouchTarget,
                                ),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: PosQuickColors.orangePrincipal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: SizedBox(
                      width: math.min(104, math.max(72, screenW * 0.2)),
                      child: PosCartUnitPriceField(
                        controller: puController,
                        currentUnitPrice: c.unitPrice,
                        onCommit: (v) => onSetUnitPrice(c.productId, v),
                      ),
                    ),
                  ),
                  _dCell(cs, formatCurrency(c.total), emphasis: true),
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: IconButton(
                      onPressed: () => onRemove(c.productId),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 22,
                        color: cs.error,
                      ),
                      tooltip: 'Supprimer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        );

        // Dans un parent déjà scrollable (ex. panier fusionné mobile), pas de scroll
        // vertical ici — hauteur libre + scroll horizontal seulement.
        if (!constraints.hasBoundedHeight) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableMinWidth),
              child: table,
            ),
          );
        }

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            primary: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tableMinWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: table,
                ),
              ),
            ),
          ),
        );
      },
    );
      },
    );
  }

  static Widget _hCell(
    String text,
    TextStyle? style, {
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 10 : 14,
      ),
      child: Text(
        text,
        style: style?.copyWith(
          fontSize: compact ? 12 : 14,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static Widget _dCell(ColorScheme cs, String text, {bool emphasis = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          textAlign: TextAlign.end,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: emphasis ? 16 : 14,
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
            color: emphasis
                ? PosQuickColors.orangePrincipal
                : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

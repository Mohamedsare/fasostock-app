import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/pos_cart_settings_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../../pos_quick/pos_quick_constants.dart';
import '../pos_models.dart';
import 'pos_cart_qty_field.dart';

/// Ligne du panier POS : miniature, nom, qté (+/- ou champ), unité, total, supprimer.
class PosCartTile extends StatelessWidget {
  const PosCartTile({
    super.key,
    required this.item,
    required this.stock,
    required this.qtyController,
    required this.onQtyDelta,
    required this.onSetQty,
    required this.onUnitChange,
    required this.onRemove,
  });

  final PosCartItem item;
  final int stock;
  final TextEditingController qtyController;
  final void Function(int delta) onQtyDelta;
  final void Function(int value) onSetQty;
  final void Function(String unit) onUnitChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = context.posScheme;
    final posCart = context.watch<PosCartSettingsProvider>();
    final showInput = posCart.invoiceShowQuantityInput;
    final showButtons = posCart.invoiceShowQuantityButtons;
    final lowStock = stock >= 0 && item.quantity > stock;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: lowStock
              ? cs.error.withValues(alpha: 0.65)
              : cs.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          _thumbnail(theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showButtons) _qtyButton(cs, -1),
                    if (showInput)
                      SizedBox(
                        width: 72,
                        child: PosCartQtyField(
                          controller: qtyController,
                          currentQuantity: item.quantity,
                          onCommit: onSetQty,
                        ),
                      )
                    else
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    if (showButtons) _qtyButton(cs, 1),
                    if (lowStock)
                      Text(
                        'Stock: $stock',
                        style: TextStyle(color: cs.error, fontSize: 12),
                      ),
                    SizedBox(
                      width: 82,
                      child: DropdownButtonFormField<String>(
                        initialValue: kInvoiceUnits.contains(item.unit)
                            ? item.unit
                            : 'pce',
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: cs.surfaceContainerHigh,
                        style: TextStyle(color: cs.onSurface, fontSize: 11),
                        decoration: PosInputTheme.dropdownDecoration(
                          context,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                        ),
                        items: kInvoiceUnits
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(
                                  u,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) onUnitChange(v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency(item.total),
                  style: const TextStyle(
                    color: PosQuickColors.orangePrincipal,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: cs.error,
                  ),
                  tooltip: 'Supprimer',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(ThemeData theme) {
    final url = item.imageUrl;
    return SizedBox(
      width: 44,
      height: 44,
      child: url != null && url.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                errorBuilder: (_, _, _) => _placeholder(theme, 44),
              ),
            )
          : _placeholder(theme, 44),
    );
  }

  Widget _placeholder(ThemeData theme, double size) {
    return Icon(
      Icons.inventory_2_outlined,
      color: PosQuickColors.orangePrincipal.withValues(alpha: 0.7),
      size: size * 0.55,
    );
  }

  Widget _qtyButton(ColorScheme cs, int delta) {
    final plus = delta > 0;
    return IconButton.filled(
      onPressed: () => onQtyDelta(delta),
      icon: Icon(plus ? Icons.add_rounded : Icons.remove_rounded, size: 20),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(36, 36),
        backgroundColor:
            plus ? PosQuickColors.orangePrincipal : cs.surfaceContainerHighest,
        foregroundColor: plus ? Colors.white : cs.onSurface,
      ),
    );
  }
}

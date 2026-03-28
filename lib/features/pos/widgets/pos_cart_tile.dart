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
    final posCart = context.watch<PosCartSettingsProvider>();
    final showInput = posCart.invoiceShowQuantityInput;
    final showButtons = posCart.invoiceShowQuantityButtons;
    final lowStock = stock >= 0 && item.quantity > stock;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosQuickColors.fondPrincipal,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: lowStock ? Colors.red.shade300 : PosQuickColors.bordure,
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
                  style: const TextStyle(
                    color: PosQuickColors.textePrincipal,
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
                    if (showButtons) _qtyButton(theme, -1),
                    if (showInput)
                      SizedBox(
                        width: 72,
                        child: PosCartQtyField(
                          controller: qtyController,
                          currentQuantity: item.quantity,
                          surfaceColor: theme.colorScheme.surface,
                          onCommit: onSetQty,
                        ),
                      )
                    else
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PosQuickColors.textePrincipal,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    if (showButtons) _qtyButton(theme, 1),
                    if (lowStock)
                      Text(
                        'Stock: $stock',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    SizedBox(
                      width: 82,
                      child: DropdownButtonFormField<String>(
                        value: kInvoiceUnits.contains(item.unit)
                            ? item.unit
                            : 'pce',
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: PosQuickColors.fondPrincipal,
                        ),
                        items: kInvoiceUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(),
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
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Colors.red,
                  ),
                  tooltip: 'Supprimer',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                errorBuilder: (_, _, _) => _placeholder(44),
              ),
            )
          : _placeholder(44),
    );
  }

  static Widget _placeholder([double size = 48]) {
    return Icon(
      Icons.inventory_2_outlined,
      color: PosQuickColors.orangePrincipal.withValues(alpha: 0.7),
      size: size * 0.55,
    );
  }

  Widget _qtyButton(ThemeData theme, int delta) {
    final plus = delta > 0;
    return IconButton.filled(
      onPressed: () => onQtyDelta(delta),
      icon: Icon(plus ? Icons.add_rounded : Icons.remove_rounded, size: 20),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(36, 36),
        backgroundColor: plus
            ? PosQuickColors.orangePrincipal
            : PosQuickColors.fondSecondaire,
        foregroundColor: plus ? Colors.white : PosQuickColors.textePrincipal,
      ),
    );
  }
}

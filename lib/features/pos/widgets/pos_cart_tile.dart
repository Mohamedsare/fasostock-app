import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/pos_cart_settings_provider.dart';
import '../../../shared/utils/format_currency.dart';
import '../pos_models.dart';

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
    final showInput = posCart.showQuantityInput;
    final showButtons = posCart.showQuantityButtons;
    final lowStock = stock >= 0 && item.quantity > stock;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lowStock
            ? theme.colorScheme.errorContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
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
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          onChanged: (v) {
                            final t = v.trim();
                            if (t.isEmpty) return;
                            final n = int.tryParse(t);
                            if (n != null && n >= 0 && n != item.quantity) onSetQty(n);
                          },
                          onSubmitted: (v) {
                            final n = int.tryParse(v.trim());
                            if (n != null && n >= 0) {
                              onSetQty(n);
                            } else {
                              qtyController.text = '${item.quantity}';
                            }
                          },
                          onTap: () => qtyController.selection = TextSelection(baseOffset: 0, extentOffset: qtyController.text.length),
                        ),
                      )
                    else
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (showButtons) _qtyButton(theme, 1),
                    if (lowStock)
                      Text('Stock: $stock', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                    SizedBox(
                      width: 82,
                      child: DropdownButtonFormField<String>(
                        value: kInvoiceUnits.contains(item.unit) ? item.unit : 'pce',
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
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
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
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
                errorBuilder: (_, __, ___) => _placeholder(theme, 44),
              ),
            )
          : _placeholder(theme, 44),
    );
  }

  static Widget _placeholder(ThemeData theme, [double size = 48]) {
    return Container(
      height: size,
      width: size,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.inventory_2_rounded, size: size * 0.5, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _qtyButton(ThemeData theme, int delta) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onQtyDelta(delta),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(delta > 0 ? Icons.add_rounded : Icons.remove_rounded, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

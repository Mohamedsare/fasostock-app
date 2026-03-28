import 'package:flutter/material.dart';

import '../../../shared/utils/format_currency.dart';
import '../../pos/widgets/pos_cart_qty_field.dart';
import '../pos_quick_constants.dart';
import '../pos_quick_models.dart';

/// Ligne panier caisse rapide : miniature, nom, qté (+/- et/ou champ), total, supprimer.
class PosQuickCartTile extends StatelessWidget {
  const PosQuickCartTile({
    super.key,
    required this.item,
    required this.stock,
    required this.qtyController,
    required this.onQtyDelta,
    required this.onSetQty,
    required this.onRemove,
    required this.showQuantityInput,
    required this.showQuantityButtons,
  });

  final PosCartItem item;
  final int stock;
  final TextEditingController qtyController;
  final void Function(int delta) onQtyDelta;
  final void Function(int value) onSetQty;
  final VoidCallback onRemove;
  final bool showQuantityInput;
  final bool showQuantityButtons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowStock = stock >= 0 && item.quantity > stock;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PosQuickColors.fondPrincipal,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: lowStock ? Colors.red.shade300 : PosQuickColors.bordure,
        ),
      ),
      child: Row(
        children: [
          _thumbnail(item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showQuantityButtons)
                      IconButton.filled(
                        onPressed: () => onQtyDelta(-1),
                        icon: const Icon(Icons.remove_rounded, size: 20),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(36, 36),
                          backgroundColor: PosQuickColors.fondSecondaire,
                          foregroundColor: PosQuickColors.textePrincipal,
                        ),
                      ),
                    if (showQuantityInput)
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: PosQuickColors.textePrincipal,
                          ),
                        ),
                      ),
                    if (showQuantityButtons)
                      IconButton.filled(
                        onPressed: () => onQtyDelta(1),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(36, 36),
                          backgroundColor: PosQuickColors.orangePrincipal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (lowStock)
                      Text(
                        'Stock: $stock',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(item.total),
                style: const TextStyle(
                  color: PosQuickColors.orangePrincipal,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.red,
                ),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _thumbnail(PosCartItem c) {
    final url = c.imageUrl;
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
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.inventory_2_outlined,
                  color: PosQuickColors.orangePrincipal.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
            )
          : Icon(
              Icons.inventory_2_outlined,
              color: PosQuickColors.orangePrincipal.withValues(alpha: 0.7),
              size: 24,
            ),
    );
  }
}

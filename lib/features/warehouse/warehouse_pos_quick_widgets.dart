import 'package:flutter/material.dart';

import '../../data/models/category.dart';
import '../pos_quick/pos_quick_constants.dart';

/// En-tête 60px orange, aligné sur la caisse POS rapide.
class WarehousePosQuickHeader extends StatelessWidget {
  const WarehousePosQuickHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.onClose,
    this.closeEnabled = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosQuickColors.orangePrincipal,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.store_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                tooltip: 'Fermer',
                onPressed: closeEnabled ? onClose : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre de recherche identique à la zone gauche POS rapide.
InputDecoration warehousePosQuickSearchDecoration({
  String hintText = 'Scanner ou rechercher un produit...',
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: PosQuickColors.textePrincipal.withValues(alpha: 0.5)),
    prefixIcon: const Icon(Icons.search_rounded, color: PosQuickColors.orangePrincipal, size: 24),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: PosQuickColors.fondPrincipal,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PosQuickColors.bordure),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PosQuickColors.bordure),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PosQuickColors.orangePrincipal, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

/// Chips catégories comme la caisse rapide.
class WarehousePosCategoryChips extends StatelessWidget {
  const WarehousePosCategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final void Function(String? categoryId) onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _PosStyleCategoryChip(
            label: 'Tous',
            selected: selectedCategoryId == null,
            onSelected: () => onCategorySelected(null),
          ),
          const SizedBox(width: 8),
          ...categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PosStyleCategoryChip(
                label: c.name,
                selected: selectedCategoryId == c.id,
                onSelected: () => onCategorySelected(c.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosStyleCategoryChip extends StatelessWidget {
  const _PosStyleCategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : PosQuickColors.textePrincipal,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: PosQuickColors.orangePrincipal,
      backgroundColor: PosQuickColors.fondSecondaire,
      side: BorderSide(
        color: selected ? PosQuickColors.orangePrincipal : PosQuickColors.bordure,
        width: selected ? 2 : 1,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }
}

/// Champs formulaire sur fond gris POS (zone droite).
InputDecoration warehousePosFormFieldDecoration({
  required String labelText,
  String? hintText,
  String? suffixText,
  String? helperText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixText: suffixText,
    helperText: helperText,
    filled: true,
    fillColor: PosQuickColors.fondPrincipal,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PosQuickColors.bordure),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PosQuickColors.bordure),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: PosQuickColors.orangePrincipal, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

import 'package:flutter/material.dart';

import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../pos_quick_constants.dart';
import 'pos_quick_product_grid.dart';

/// Zone gauche caisse rapide : barre scan/recherche, catégories, grille produits.
class PosQuickLeftZone extends StatelessWidget {
  const PosQuickLeftZone({
    super.key,
    required this.searchController,
    required this.selectedCategoryId,
    required this.categories,
    required this.filteredProducts,
    required this.stockByProductId,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onCategorySelected,
    required this.onAddToCart,
    required this.onScanPressed,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final String? selectedCategoryId;
  final List<Category> categories;
  final List<Product> filteredProducts;
  final Map<String, int> stockByProductId;
  final void Function(String) onSearchChanged;
  final void Function(String) onSearchSubmitted;
  final void Function(String? categoryId) onCategorySelected;
  final void Function(Product p) onAddToCart;
  final VoidCallback onScanPressed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              height: 55,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
                autofocus: true,
                textInputAction: TextInputAction.done,
                style: TextStyle(color: cs.onSurface),
                decoration: PosInputTheme.roundedField(
                  context,
                  radius: 12,
                  hintText: 'Scanner ou rechercher un produit...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: IconButton(
                    icon: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: PosQuickColors.orangePrincipal,
                      size: 26,
                    ),
                    onPressed: onScanPressed,
                    tooltip: 'Ouvrir le scan caméra',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  suffixIcon: Icon(
                    Icons.search_rounded,
                    color: PosQuickColors.orangePrincipal,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            // Les FilterChip dépassent ~48px (padding + cible tactile) — 44px provoquait overflow.
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'Tous',
                  categoryId: null,
                  selected: selectedCategoryId == null,
                  onSelected: () => onCategorySelected(null),
                ),
                const SizedBox(width: 8),
                ...categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      label: c.name,
                      categoryId: c.id,
                      selected: selectedCategoryId == c.id,
                      onSelected: () => onCategorySelected(c.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PosQuickProductGrid(
              products: filteredProducts,
              stockByProductId: stockByProductId,
              onAddToCart: onAddToCart,
              onRefresh: onRefresh,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.categoryId,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String? categoryId;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : cs.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: PosQuickColors.orangePrincipal,
      backgroundColor: cs.surfaceContainerHighest,
      side: BorderSide(
        color: selected
            ? PosQuickColors.orangePrincipal
            : cs.outline.withValues(alpha: 0.45),
        width: selected ? 2 : 1,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

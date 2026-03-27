import 'package:flutter/material.dart';

import '../../../data/models/category.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/product.dart';
import '../../pos_quick/pos_quick_constants.dart';
import 'pos_product_grid.dart';

/// Zone principale POS : barre recherche + client + bouton créer client + grille produits.
class PosMainArea extends StatelessWidget {
  const PosMainArea({
    super.key,
    required this.searchController,
    required this.customerId,
    required this.customers,
    required this.filteredProducts,
    required this.stockByProductId,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCustomerIdChanged,
    required this.onCategorySelected,
    required this.onCreateCustomer,
    required this.onSelectOrCreateCustomer,
    required this.onAddToCart,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final String customerId;
  final List<Customer> customers;
  final List<Product> filteredProducts;
  final Map<String, int> stockByProductId;
  final List<Category> categories;
  final String? selectedCategoryId;
  final void Function(String?) onCustomerIdChanged;
  final void Function(String? categoryId) onCategorySelected;
  final VoidCallback onCreateCustomer;
  final VoidCallback onSelectOrCreateCustomer;
  final void Function(Product p) onAddToCart;
  final void Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosQuickColors.fondPrincipal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Rechercher produit (nom, SKU, code-barres)...',
                        hintStyle: TextStyle(
                          color: PosQuickColors.textePrincipal.withValues(alpha: 0.5),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: PosQuickColors.orangePrincipal,
                          size: 24,
                        ),
                        filled: true,
                        fillColor: PosQuickColors.fondPrincipal,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: PosQuickColors.bordure,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width > 600 ? 180 : 140,
                  child: DropdownButtonFormField<String>(
                    value: customerId.isEmpty || !customers.any((c) => c.id == customerId) ? null : customerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: PosQuickColors.fondPrincipal,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PosQuickColors.bordure),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    hint: Text('Client', overflow: TextOverflow.ellipsis),
                    items: [
                      const DropdownMenuItem<String>(value: '', child: Text('—', overflow: TextOverflow.ellipsis)),
                      ...customers.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: onCustomerIdChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Créer un client',
                  child: IconButton.filled(
                    onPressed: onCreateCustomer,
                    icon: const Icon(Icons.person_add_rounded, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: PosQuickColors.orangePrincipal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'Tous',
                  selected: selectedCategoryId == null,
                  onSelected: () => onCategorySelected(null),
                ),
                const SizedBox(width: 8),
                ...categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      label: c.name,
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
            child: PosProductGrid(
              products: filteredProducts,
              stockByProductId: stockByProductId,
              onAddToCart: onAddToCart,
              emptyMessage: searchController.text.trim().isEmpty ? 'Aucun produit actif' : 'Aucun résultat',
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

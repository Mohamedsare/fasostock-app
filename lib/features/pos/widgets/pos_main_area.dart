import 'package:flutter/material.dart';

import '../../../data/models/customer.dart';
import '../../../data/models/product.dart';
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
    required this.onCustomerIdChanged,
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
  final void Function(String?) onCustomerIdChanged;
  final VoidCallback onCreateCustomer;
  final VoidCallback onSelectOrCreateCustomer;
  final void Function(Product p) onAddToCart;
  final void Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Rechercher produit (nom, SKU, code-barres)...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    hint: Text(
                      'Client',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

import 'package:flutter/material.dart';

import '../../../core/breakpoints.dart';
import '../../../data/models/category.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/product.dart';
import '../../pos_quick/pos_quick_constants.dart';
import 'pos_product_grid.dart';

/// Mode d’affichage de la grille produits dans [PosMainArea].
enum PosMainProductGridMode {
  /// Grille classique (prend tout l’espace vertical restant).
  expandedGrid,

  /// Bande fixe : 2 lignes de cartes, défilement horizontal (écran facture tableau).
  twoRowHorizontalStrip,
}

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
    required this.onCategorySelected,
    required this.onCreateCustomer,
    required this.onSelectOrCreateCustomer,
    required this.onAddToCart,
    required this.onSearchChanged,
    this.onCustomerIdChanged,
    this.productGridMode = PosMainProductGridMode.expandedGrid,
    this.onLeavePos,
    this.onSyncPressed,
    /// Affiche client + création client (caisse / facture). Désactiver pour un flux sans client (ex. réception dépôt).
    this.showCustomerRow = true,
    /// Si non null, remplace le tooltip du bouton retour (ex. « Fermer » dans un dialogue).
    this.leavePosTooltip,
    /// Bandeau facture (strip) : sur mobile, remplit la hauteur du bandeau sans scroll vertical
    /// sur tout le bloc — recherche + **filtre catégorie** restent visibles, seule la grille défile.
    this.pinStripProductArea = false,
  });

  final TextEditingController searchController;
  final String customerId;
  final List<Customer> customers;
  final List<Product> filteredProducts;
  final Map<String, int> stockByProductId;
  final List<Category> categories;
  final String? selectedCategoryId;
  final void Function(String?)? onCustomerIdChanged;
  final void Function(String? categoryId) onCategorySelected;
  final VoidCallback onCreateCustomer;
  final VoidCallback onSelectOrCreateCustomer;
  final void Function(Product p) onAddToCart;
  final void Function(String) onSearchChanged;
  final PosMainProductGridMode productGridMode;

  /// Bouton retour (ex. facture tableau sans top bar).
  final VoidCallback? onLeavePos;

  /// Actualiser données (bouton dispo en mode strip si renseigné).
  final VoidCallback? onSyncPressed;

  final bool showCustomerRow;

  final String? leavePosTooltip;

  final bool pinStripProductArea;

  @override
  Widget build(BuildContext context) {
    final cs = context.posScheme;
    final stripMode =
        productGridMode == PosMainProductGridMode.twoRowHorizontalStrip;
    final pinStrip = stripMode && pinStripProductArea;
    final screenW = MediaQuery.sizeOf(context).width;
    // Facture TAB sur téléphone : une seule ligne (retour + recherche + client + …) déborde — on empile.
    final stripUltraMobile =
        stripMode && screenW < Breakpoints.tablet;
    return Container(
      decoration: BoxDecoration(color: cs.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize:
            stripMode && !pinStrip ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              stripMode ? 12 : 16,
              stripUltraMobile ? 8 : (stripMode ? 10 : 12),
              stripMode ? 12 : 16,
              stripUltraMobile ? 6 : 8,
            ),
            child: stripUltraMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (onLeavePos != null) ...[
                            IconButton.filled(
                              onPressed: onLeavePos,
                              tooltip:
                                  leavePosTooltip ?? 'Retour aux ventes',
                              icon: const Icon(Icons.arrow_back_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    PosQuickColors.orangePrincipal,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: TextField(
                                controller: searchController,
                                onChanged: onSearchChanged,
                                style: TextStyle(color: cs.onSurface),
                                decoration: PosInputTheme.roundedField(
                                  context,
                                  radius: 12,
                                  hintText: 'Rechercher…',
                                  hintStyle: TextStyle(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.85),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: PosQuickColors.orangePrincipal,
                                    size: 22,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (stripMode && onSyncPressed != null) ...[
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: onSyncPressed,
                              tooltip: 'Actualiser',
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: cs.onSurface
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (showCustomerRow) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey<String>(
                                  customerId.isEmpty ||
                                          !customers.any(
                                            (c) => c.id == customerId,
                                          )
                                      ? ''
                                      : customerId,
                                ),
                                initialValue:
                                    customerId.isEmpty ||
                                        !customers.any(
                                          (c) => c.id == customerId,
                                        )
                                    ? null
                                    : customerId,
                                isExpanded: true,
                                dropdownColor: cs.surfaceContainerHigh,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 14,
                                ),
                                decoration:
                                    PosInputTheme.dropdownDecoration(
                                  context,
                                  radius: 12,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                hint: Text(
                                  'Client',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: '',
                                    child: Text(
                                      '—',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ),
                                  ...customers.map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: onCustomerIdChanged,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Créer un client',
                              child: IconButton.filled(
                                visualDensity: VisualDensity.compact,
                                onPressed: onCreateCustomer,
                                icon: const Icon(
                                  Icons.person_add_rounded,
                                  size: 22,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      PosQuickColors.orangePrincipal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (onLeavePos != null) ...[
                        IconButton.filled(
                          onPressed: onLeavePos,
                          tooltip: leavePosTooltip ?? 'Retour aux ventes',
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: PosQuickColors.orangePrincipal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 55,
                          child: TextField(
                            controller: searchController,
                            onChanged: onSearchChanged,
                            style: TextStyle(color: cs.onSurface),
                            decoration: PosInputTheme.roundedField(
                              context,
                              radius: 12,
                              hintText: stripMode
                                  ? 'Rechercher…'
                                  : 'Rechercher produit (nom, SKU, code-barres)...',
                              hintStyle: TextStyle(
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.85),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: PosQuickColors.orangePrincipal,
                                size: 24,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showCustomerRow) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          width: screenW > 600 ? 180 : 140,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey<String>(
                              customerId.isEmpty ||
                                      !customers
                                          .any((c) => c.id == customerId)
                                  ? ''
                                  : customerId,
                            ),
                            initialValue: customerId.isEmpty ||
                                    !customers.any((c) => c.id == customerId)
                                ? null
                                : customerId,
                            isExpanded: true,
                            dropdownColor: cs.surfaceContainerHigh,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                            ),
                            decoration: PosInputTheme.dropdownDecoration(
                              context,
                              radius: 12,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            hint: Text(
                              'Client',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: '',
                                child: Text(
                                  '—',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.onSurface),
                                ),
                              ),
                              ...customers.map(
                                (c) => DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: cs.onSurface),
                                  ),
                                ),
                              ),
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
                      if (stripMode && onSyncPressed != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: onSyncPressed,
                          tooltip: 'Actualiser',
                          icon: Icon(
                            Icons.refresh_rounded,
                            color:
                                cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          SizedBox(
            height: stripUltraMobile ? 48 : 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: stripMode ? 12 : 16),
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
          SizedBox(height: stripMode ? 6 : 8),
          if (stripMode && pinStrip)
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  return PosProductTwoRowHorizontalStrip(
                    products: filteredProducts,
                    stockByProductId: stockByProductId,
                    onAddToCart: onAddToCart,
                    viewportHeight: c.maxHeight.isFinite && c.maxHeight > 0
                        ? c.maxHeight
                        : null,
                    emptyMessage: searchController.text.trim().isEmpty
                        ? 'Aucun produit actif'
                        : 'Aucun résultat',
                  );
                },
              ),
            )
          else if (stripMode)
            PosProductTwoRowHorizontalStrip(
              products: filteredProducts,
              stockByProductId: stockByProductId,
              onAddToCart: onAddToCart,
              emptyMessage: searchController.text.trim().isEmpty
                  ? 'Aucun produit actif'
                  : 'Aucun résultat',
            )
          else
            Expanded(
              child: PosProductGrid(
                products: filteredProducts,
                stockByProductId: stockByProductId,
                onAddToCart: onAddToCart,
                emptyMessage: searchController.text.trim().isEmpty
                    ? 'Aucun produit actif'
                    : 'Aucun résultat',
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
    final cs = context.posScheme;
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
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected
            ? PosQuickColors.orangePrincipal
            : cs.outline.withValues(alpha: 0.55),
        width: selected ? 2 : 1,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

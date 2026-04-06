import 'package:flutter/material.dart';

/// Panneau latéral du panier POS : en-tête "Articles (n)", liste des lignes, footer (récap + paiement).
class PosCartPanel extends StatelessWidget {
  const PosCartPanel({
    super.key,
    required this.cartItemCount,
    required this.cartTiles,
    required this.footer,
    this.cartListBody,
    /// Facture tableau / petits écrans : tableau + pied (paiement) dans un même scroll,
    /// évite l’overflow quand le footer est plus haut que l’espace restant.
    this.scrollBodyWithFooter = false,
    /// Si non null, remplace le titre « Panier · n article(s) » (ex. réception dépôt).
    this.panelTitleOverride,
  });

  final int cartItemCount;
  final List<Widget> cartTiles;
  final Widget footer;
  /// Si non null, remplace la liste scrollable des [cartTiles] (ex. vue tableau facture).
  final Widget? cartListBody;
  final bool scrollBodyWithFooter;

  final String? panelTitleOverride;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mergeScroll =
        scrollBodyWithFooter && cartListBody != null;

    final headerTitle = panelTitleOverride ??
        'Panier · $cartItemCount article${cartItemCount != 1 ? 's' : ''}';

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        cartListBody != null ? 14 : 12,
        16,
        cartListBody != null ? 10 : 8,
      ),
      child: Row(
        children: [
          Text(
            headerTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: cartListBody != null ? 20 : 16,
            ),
          ),
        ],
      ),
    );

    if (mergeScroll) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  primary: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cartListBody!,
                      footer,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: cartItemCount == 0
                ? Center(
                    child: Text(
                      'Panier vide',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : (cartListBody ??
                    ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: cartTiles.length,
                      itemBuilder: (context, index) => cartTiles[index],
                    )),
          ),
          footer,
        ],
      ),
    );
  }
}

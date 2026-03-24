import 'package:flutter/material.dart';

import '../pos_quick_constants.dart';

/// Zone droite caisse rapide : titre panier, liste des lignes, footer (récap + paiement).
class PosQuickRightZone extends StatelessWidget {
  const PosQuickRightZone({
    super.key,
    required this.cartItemCount,
    required this.cartTiles,
    required this.footer,
  });

  final int cartItemCount;
  final List<Widget> cartTiles;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PosQuickColors.fondSecondaire,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Panier · $cartItemCount article${cartItemCount != 1 ? 's' : ''}',
              style: const TextStyle(color: PosQuickColors.textePrincipal, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          Expanded(
            child: cartTiles.isEmpty
                ? const Center(child: Text('Panier vide', style: TextStyle(color: PosQuickColors.textePrincipal)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cartTiles.length,
                    itemBuilder: (context, index) => cartTiles[index],
                  ),
          ),
          footer,
        ],
      ),
    );
  }
}

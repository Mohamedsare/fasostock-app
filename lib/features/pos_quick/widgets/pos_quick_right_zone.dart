import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Panier · $cartItemCount article${cartItemCount != 1 ? 's' : ''}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: cartTiles.isEmpty
                ? Center(
                    child: Text(
                      'Panier vide',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
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

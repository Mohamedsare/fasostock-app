import 'package:flutter/material.dart';

/// Panneau latéral du panier POS : en-tête "Articles (n)", liste des lignes, footer (récap + paiement).
class PosCartPanel extends StatelessWidget {
  const PosCartPanel({
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

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Articles ($cartItemCount)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.shopping_cart_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Panier', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cartTiles.isEmpty
                ? Center(
                    child: Text(
                      'Panier vide',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartTiles.length,
                    itemBuilder: (context, index) => cartTiles[index],
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: footer,
          ),
        ],
      ),
    );
  }
}

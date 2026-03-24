import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/permissions_provider.dart';

/// Page Aide / Onboarding — contenu d'aide in-app (réservé à l'owner dans le menu).
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    if (permissions.hasLoaded && !permissions.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Aide')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Cette section est réservée au propriétaire de l\'entreprise.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Bienvenue dans FasoStock. Voici l\'essentiel pour bien démarrer.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _Section(
            title: 'Démarrage',
            icon: Icons.rocket_launch_rounded,
            items: const [
              'Sélectionnez votre entreprise et la boutique dans la barre du haut.',
              'Le tableau de bord affiche les indicateurs (ventes, stock).',
              'Utilisez le menu pour accéder aux Produits, Ventes, Stock, Clients.',
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Ventes',
            icon: Icons.shopping_cart_rounded,
            items: const [
              'Caisse rapide : ventes rapides avec ticket thermique.',
              'Facture A4 : ventes détaillées avec facture PDF personnalisable.',
              'Historique des ventes : consultez, réimprimez ou téléchargez les factures.',
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Produits et stock',
            icon: Icons.inventory_2_rounded,
            items: const [
              'Produits : créez, modifiez, importez en CSV (modèle exportable).',
              'Stock : ajustez les quantités, transférez entre boutiques.',
              'Alertes : consultez les ruptures (menu Stock alertes pour les caissiers).',
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Paramètres',
            icon: Icons.settings_rounded,
            items: const [
              'Paramétrage facture A4 : logo, slogan, signataire (par boutique).',
              'Caisse rapide : impression automatique, type de quantité (+/- ou champ).',
              'Abonnement : consultez votre plan dans Paramètres.',
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                      Expanded(child: Text(e, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

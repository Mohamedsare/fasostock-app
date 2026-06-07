import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/routes.dart';

/// Titre et navigation de l’AppBar mobile du shell.
class MobileShellTitle {
  MobileShellTitle._();

  static const Map<String, String> _routeTitles = {
    AppRoutes.dashboard: 'Tableau de bord',
    AppRoutes.products: 'Produits',
    AppRoutes.sales: 'Ventes',
    AppRoutes.stores: 'Boutiques',
    AppRoutes.inventory: 'Stock',
    AppRoutes.stockCashier: 'Stock (alertes)',
    AppRoutes.purchases: 'Achats',
    AppRoutes.warehouse: 'Magasin',
    AppRoutes.transfers: 'Transferts',
    AppRoutes.customers: 'Clients',
    AppRoutes.credit: 'Crédit client',
    AppRoutes.suppliers: 'Fournisseurs',
    AppRoutes.reports: 'Rapports',
    AppRoutes.ai: 'Prédictions IA',
    AppRoutes.users: 'Utilisateurs',
    AppRoutes.audit: 'Journal d\'audit',
    AppRoutes.printers: 'Imprimantes',
    AppRoutes.settings: 'Paramètres',
    AppRoutes.help: 'Aide',
    AppRoutes.notifications: 'Notifications',
    AppRoutes.integrations: 'Intégrations API',
  };

  /// Écrans « tâche » sous une boutique : retour au lieu du menu drawer.
  static bool prefersBackLeading(String path) {
    if (path.contains('/pos-quick')) return true;
    if (path.contains('/facture-tab')) return true;
    if (RegExp(r'/stores/[^/]+/pos').hasMatch(path)) return true;
    return false;
  }

  /// Retourne le libellé pour [path] (GoRouter), ou `null` → wordmark FasoStock.
  static String? forPath(String path) {
    if (path.contains('/pos-quick')) return 'Caisse rapide';
    if (path.contains('/facture-tab')) return 'Facture (tableau)';
    if (RegExp(r'/stores/[^/]+/pos$').hasMatch(path)) return 'Facture A4';

    for (final e in _routeTitles.entries) {
      if (path == e.key || path.startsWith('${e.key}/')) {
        return e.value;
      }
    }
    return null;
  }

  /// Cible de repli si la pile GoRouter ne peut pas [GoRouter.pop].
  static String backFallbackLocation(String path, {Uri? uri}) {
    final u = uri ?? Uri(path: path);
    if (u.queryParameters.containsKey('editSale')) {
      return AppRoutes.sales;
    }
    if (prefersBackLeading(path)) {
      return AppRoutes.stores;
    }
    return AppRoutes.dashboard;
  }

  static void navigateBack(BuildContext context) {
    final router = GoRouter.of(context);
    final uri = GoRouterState.of(context).uri;
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go(backFallbackLocation(uri.path, uri: uri));
  }
}

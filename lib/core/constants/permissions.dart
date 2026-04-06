/// Clés de permission — alignées avec backend role_permissions et constants/permissions.ts (web).
class Permissions {
  Permissions._();

  static const String companyManage = 'company.manage';
  static const String storesCreate = 'stores.create';
  static const String storesRequestExtra = 'stores.request_extra';
  static const String storesApproveExtra = 'stores.approve_extra';
  static const String storesView = 'stores.view';
  static const String productsCreate = 'products.create';
  static const String productsUpdate = 'products.update';
  static const String productsDelete = 'products.delete';
  static const String productsView = 'products.view';
  static const String productsImport = 'products.import';
  static const String salesCreate = 'sales.create';
  static const String salesUpdate = 'sales.update';
  static const String salesCancel = 'sales.cancel';
  static const String salesRefund = 'sales.refund';
  static const String salesView = 'sales.view';
  static const String salesInvoiceA4 = 'sales.invoice_a4';
  /// POS facture A4 avec lignes affichées en tableau (même PDF A4 que le POS classique).
  static const String salesInvoiceA4Table = 'sales.invoice_a4_table';
  static const String purchasesCreate = 'purchases.create';
  static const String purchasesView = 'purchases.view';
  static const String purchasesCancel = 'purchases.cancel';
  static const String purchasesUpdate = 'purchases.update';
  static const String purchasesDelete = 'purchases.delete';
  static const String stockAdjust = 'stock.adjust';
  static const String stockTransfer = 'stock.transfer';
  static const String stockView = 'stock.view';
  /// Dépôt central (magasin) : RPC + lecture inventaire/mouvements/bons — rôle Magasinier (stock_manager) par défaut.
  static const String warehouseManage = 'warehouse.manage';
  static const String reportsViewGlobal = 'reports.view_global';
  static const String reportsViewStore = 'reports.view_store';
  static const String usersManage = 'users.manage';
  static const String settingsManage = 'settings.manage';
  static const String aiInsightsView = 'ai.insights.view';
  static const String cashOpenClose = 'cash.open_close';
  static const String cashView = 'cash.view';
  static const String auditView = 'audit.view';
  static const String dashboardView = 'dashboard.view';
  static const String customersView = 'customers.view';
  static const String customersManage = 'customers.manage';
  /// Page Crédit / créances (propriétaire par défaut ; accord explicite aux autres).
  static const String creditView = 'credit.view';
  static const String suppliersView = 'suppliers.view';
  static const String suppliersManage = 'suppliers.manage';
  static const String transfersCreate = 'transfers.create';
  static const String transfersApprove = 'transfers.approve';

  static const List<String> all = [
    companyManage,
    storesCreate,
    storesRequestExtra,
    storesApproveExtra,
    storesView,
    productsCreate,
    productsUpdate,
    productsDelete,
    productsView,
    productsImport,
    salesCreate,
    salesUpdate,
    salesCancel,
    salesRefund,
    salesView,
    salesInvoiceA4,
    salesInvoiceA4Table,
    purchasesCreate,
    purchasesView,
    purchasesCancel,
    purchasesUpdate,
    purchasesDelete,
    stockAdjust,
    stockTransfer,
    stockView,
    warehouseManage,
    reportsViewGlobal,
    reportsViewStore,
    usersManage,
    settingsManage,
    aiInsightsView,
    cashOpenClose,
    cashView,
    auditView,
    dashboardView,
    customersView,
    customersManage,
    creditView,
    suppliersView,
    suppliersManage,
    transfersCreate,
    transfersApprove,
  ];

  /// Libellés français pour l'écran Gestion des droits.
  static const Map<String, String> labels = {
    companyManage: 'Gérer l\'entreprise',
    storesCreate: 'Créer des boutiques',
    storesRequestExtra: 'Demander des boutiques en plus',
    storesApproveExtra: 'Approuver les demandes de boutiques',
    storesView: 'Voir les boutiques',
    productsCreate: 'Créer des produits',
    productsUpdate: 'Modifier des produits',
    productsDelete: 'Supprimer des produits',
    productsView: 'Voir les produits',
    productsImport: 'Importer des produits (CSV)',
    salesCreate: 'Créer des ventes (caisse rapide)',
    salesUpdate: 'Modifier des ventes complétées',
    salesCancel: 'Annuler des ventes',
    salesRefund: 'Rembourser des ventes',
    salesView: 'Voir l\'historique des ventes',
    salesInvoiceA4: 'Émettre des factures A4',
    salesInvoiceA4Table: 'POS facture A4 (vue tableau)',
    purchasesCreate: 'Créer des achats',
    purchasesView: 'Voir les achats',
    purchasesCancel: 'Annuler des achats',
    purchasesUpdate: 'Modifier des achats (brouillons)',
    purchasesDelete: 'Supprimer des achats (brouillons)',
    stockAdjust: 'Ajuster le stock',
    stockTransfer: 'Transférer le stock',
    stockView: 'Voir le stock / inventaire',
    warehouseManage: 'Gérer le dépôt magasin (complet)',
    reportsViewGlobal: 'Voir les rapports (global)',
    reportsViewStore: 'Voir les rapports (boutique)',
    usersManage: 'Gérer les utilisateurs',
    settingsManage: 'Gérer les paramètres',
    aiInsightsView: 'Voir les insights IA',
    cashOpenClose: 'Ouvrir / fermer la caisse',
    cashView: 'Voir la caisse / mouvements',
    auditView: 'Voir l\'audit',
    dashboardView: 'Voir le tableau de bord',
    customersView: 'Voir les clients',
    customersManage: 'Gérer les clients',
    creditView: 'Voir la page Crédit (créances clients)',
    suppliersView: 'Voir les fournisseurs',
    suppliersManage: 'Gérer les fournisseurs',
    transfersCreate: 'Créer / gérer les transferts',
    transfersApprove: 'Approuver les transferts',
  };
}

/// Noms de routes — alignés avec l'app web (ROUTES dans routes/index.tsx).
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String createSuperAdmin = '/create-super-admin';

  static const String dashboard = '/dashboard';
  static const String stores = '/stores';
  static String storeDetail(String id) => '/stores/$id';
  /// POS actuel = Facture A4 (vente détaillée).
  static String pos(String storeId) => '/stores/$storeId/pos';
  /// Caisse rapide / ticket thermique.
  static String posQuick(String storeId) => '/stores/$storeId/pos-quick';
  /// Alias explicite pour le POS facture A4 (même route que pos).
  static String posInvoice(String storeId) => '/stores/$storeId/pos';
  /// POS facture A4 — lignes du panier affichées en tableau (même PDF A4).
  static String factureTab(String storeId) => '/stores/$storeId/facture-tab';

  static const String products = '/products';
  static const String inventory = '/inventory';
  /// Écran Stock C (caissier) : rupture + alertes, lecture seule.
  static const String stockCashier = '/stock-c';
  static const String sales = '/sales';
  static const String purchases = '/purchases';
  /// Dépôt central (magasin) — réservé owner ; distinct du stock par boutique.
  static const String warehouse = '/warehouse';
  static const String customers = '/customers';
  /// Crédit client / créances — aligné appweb ROUTES.credit.
  static const String credit = '/credit';
  static const String suppliers = '/suppliers';
  static const String transfers = '/transfers';
  static const String cash = '/cash';
  static const String reports = '/reports';
  static const String ai = '/ai';
  static const String settings = '/settings';
  static const String users = '/users';
  static const String audit = '/audit';
  static const String help = '/help';
  static const String notifications = '/notifications';
  static const String integrations = '/integrations';

  static const String admin = '/admin';
  static const String adminCompanies = '/admin/companies';
  static const String adminStores = '/admin/stores';
  static const String adminUsers = '/admin/users';
  static const String adminAi = '/admin/ai';
  static const String adminRapports = '/admin/reports';
  static const String adminAudit = '/admin/audit';
  static const String adminAppErrors = '/admin/app-errors';
  static const String adminMessages = '/admin/messages';
  static const String adminSettings = '/admin/settings';
}

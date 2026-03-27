import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/config/routes.dart';
import '../core/constants/permissions.dart';
import '../providers/auth_provider.dart';
import '../providers/permissions_provider.dart';
import '../shared/widgets/app_shell.dart';
import '../shared/widgets/offline_sync_wrapper.dart';
import '../features/auth/login/login_page.dart';
import '../features/auth/forgot_password/forgot_password_page.dart';
import '../features/auth/register/register_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/products/products_page.dart';
import '../features/sales/sales_page.dart';
import '../features/stores/stores_page.dart';
import '../features/pos/pos_page.dart';
// ignore: uri_does_not_exist
import '../features/pos_quick/pos_quick_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/inventory/stock_cashier_page.dart';
import '../features/purchases/purchases_page.dart';
import '../features/warehouse/warehouse_page.dart';
import '../features/transfers/transfers_page.dart';
import '../features/suppliers/suppliers_page.dart';
import '../features/customers/customers_page.dart';
import '../features/reports/reports_page.dart';
import '../features/ai/ai_insights_page.dart';
import '../features/users/users_page.dart';
import '../features/audit/audit_page.dart';
import '../features/help/help_page.dart';
import '../features/integrations/integrations_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/settings/settings_page.dart';
import '../features/admin/shared/admin_shell.dart';
import '../features/admin/admin_tableau_page.dart';
import '../features/admin/admin_entreprises_page.dart';
import '../features/admin/admin_boutiques_page.dart';
import '../features/admin/admin_users_page.dart';
import '../features/admin/admin_audit_page.dart';
import '../features/admin/admin_app_errors_page.dart';
import '../features/admin/admin_messages_page.dart';
import '../features/admin/admin_rapports_page.dart';
import '../features/admin/admin_settings_page.dart';
import '../features/admin/admin_ai_page.dart';

/// Route d'attente au démarrage (évite l'écran blanc).
const String _splashPath = '/_splash';

/// Router principal — redirect selon auth et is_super_admin (même logique que LandingOrApp).
GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: _splashPath,
    debugLogDiagnostics: false,
    refreshListenable: authProvider,
    redirect: (BuildContext context, GoRouterState state) {
      final auth = authProvider;
      final path = state.uri.path;

      // Pendant le chargement auth : rester sur splash (écran de chargement)
      if (auth.loading) {
        return path == _splashPath ? null : _splashPath;
      }

      final isLoggedIn = auth.isAuthenticated;
      final isSuperAdmin = auth.isSuperAdmin;

      const publicPaths = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
      ];

      // Connecté mais profil pas encore chargé (ex: juste après signedIn) : ne pas
      // rediriger vers dashboard/admin pour laisser la page login faire refreshProfile()
      // puis naviguer. Les échecs durables (JWT / réseau) déconnectent via AuthProvider
      // pour éviter un splash infini.
      if (isLoggedIn && auth.profile == null) {
        if (publicPaths.contains(path)) return null;
        return path == _splashPath ? null : _splashPath;
      }

      // Quitter la splash vers la bonne destination
      if (path == _splashPath) {
        if (!isLoggedIn) return AppRoutes.login;
        if (isSuperAdmin) return AppRoutes.admin;
        return AppRoutes.dashboard;
      }

      // Routes publiques
      if (publicPaths.contains(path)) {
        if (isLoggedIn) {
          if (isSuperAdmin) return AppRoutes.admin;
          return AppRoutes.dashboard;
        }
        return null;
      }

      if (!isLoggedIn) return AppRoutes.login;

      // Super admin : catégoriquement limité à l'espace admin — jamais dashboard ni autres routes app.
      if (isSuperAdmin) {
        final inAdminSpace = path.startsWith('/admin');
        if (!inAdminSpace) return AppRoutes.admin;
        return null;
      }

      // Utilisateur normal : pas d'accès admin
      if (path.startsWith('/admin')) return AppRoutes.dashboard;
      if (path == '/') return AppRoutes.dashboard;

      // Caisse rapide : réservée aux utilisateurs avec sales.create
      if (path.endsWith('pos-quick')) {
        try {
          final perm = context.read<PermissionsProvider>();
          if (perm.hasLoaded && !perm.hasPermission(Permissions.salesCreate)) {
            return AppRoutes.stores;
          }
        } catch (_) {}
      }
      // POS Facture A4 : réservé aux utilisateurs avec sales.invoice_a4
      if (path.contains('/stores/') &&
          path.endsWith('/pos') &&
          !path.contains('pos-quick')) {
        try {
          final perm = context.read<PermissionsProvider>();
          if (perm.hasLoaded &&
              !perm.hasPermission(Permissions.salesInvoiceA4)) {
            return AppRoutes.stores;
          }
        } catch (_) {}
      }

      return null;
    },
    routes: [
      GoRoute(
        path: _splashPath,
        builder: (context, state) => Container(
          color: const Color(0xFFF1F5F9),
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFEA580C)),
                    const SizedBox(height: 16),
                    Text(
                      'Chargement...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(child: OfflineSyncWrapper(child: child)),
        routes: [
          GoRoute(path: '/', redirect: (context, state) => AppRoutes.dashboard),
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.stores,
            builder: (context, state) => const StoresPage(),
          ),
          GoRoute(
            path: '/stores/:storeId/pos',
            builder: (context, state) {
              final storeId = state.pathParameters['storeId'] ?? '';
              return PosPage(storeId: storeId);
            },
          ),
          GoRoute(
            path: '/stores/:storeId/pos-quick',
            builder: (context, state) {
              final storeId = state.pathParameters['storeId'] ?? '';
              // ignore: undefined_function
              return PosQuickPage(storeId: storeId);
            },
          ),
          GoRoute(
            path: AppRoutes.products,
            builder: (context, state) => const ProductsPage(),
          ),
          GoRoute(
            path: AppRoutes.sales,
            builder: (context, state) => const SalesPage(),
          ),
          GoRoute(
            path: AppRoutes.inventory,
            builder: (context, state) => const InventoryPage(),
          ),
          GoRoute(
            path: AppRoutes.stockCashier,
            builder: (context, state) => const StockCashierPage(),
          ),
          GoRoute(
            path: AppRoutes.purchases,
            builder: (context, state) => const PurchasesPage(),
          ),
          GoRoute(
            path: AppRoutes.warehouse,
            builder: (context, state) => const WarehousePage(),
          ),
          GoRoute(
            path: AppRoutes.transfers,
            builder: (context, state) => const TransfersPage(),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomersPage(),
          ),
          GoRoute(
            path: AppRoutes.suppliers,
            builder: (context, state) => const SuppliersPage(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: AppRoutes.ai,
            builder: (context, state) => const AiInsightsPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.users,
            builder: (context, state) => const UsersPage(),
          ),
          GoRoute(
            path: AppRoutes.audit,
            builder: (context, state) => const AuditPage(),
          ),
          GoRoute(
            path: AppRoutes.help,
            builder: (context, state) => const HelpPage(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: AppRoutes.integrations,
            builder: (context, state) => const IntegrationsPage(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminTableauPage(),
            routes: [
              GoRoute(
                path: 'companies',
                builder: (context, state) => const AdminEntreprisesPage(),
              ),
              GoRoute(
                path: 'stores',
                builder: (context, state) => const AdminBoutiquesPage(),
              ),
              GoRoute(
                path: 'users',
                builder: (context, state) => const AdminUsersPage(),
              ),
              GoRoute(
                path: 'audit',
                builder: (context, state) => const AdminAuditPage(),
              ),
              GoRoute(
                path: 'app-errors',
                builder: (context, state) => const AdminAppErrorsPage(),
              ),
              GoRoute(
                path: 'messages',
                builder: (context, state) => const AdminMessagesPage(),
              ),
              GoRoute(
                path: 'ai',
                builder: (context, state) => const AdminAIPage(),
              ),
              GoRoute(
                path: 'reports',
                builder: (context, state) => const AdminRapportsPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const AdminSettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

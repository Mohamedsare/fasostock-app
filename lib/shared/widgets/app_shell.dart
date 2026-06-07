import 'dart:async';
import 'dart:math' show max, min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' hide Consumer;
import '../../core/breakpoints.dart';
import '../../core/config/routes.dart';
import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../features/notifications/owner_notifications_dialog.dart';
import '../../features/notifications/owner_notifications_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../core/utils/user_country_time.dart';
import 'faso_stock_wordmark.dart';
import 'mobile/fs_haptic.dart';
import 'mobile/fs_status_bar.dart';
import 'mobile/mobile_shell_title.dart';

/// Layout principal : sidebar réductible (desktop) + drawer (mobile, drawer-only,
/// pas de bottom nav — pattern Linear/Notion/Slack pour app métier dense).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const double sidebarWidth = 228;
  static const double sidebarCollapsedWidth = 64;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _mobileScaffoldKey =
      GlobalKey<ScaffoldState>();
  static const _navItems = [
    (
      path: AppRoutes.dashboard,
      label: 'Tableau de bord',
      icon: Icons.dashboard_rounded,
    ),
    (
      path: AppRoutes.products,
      label: 'Produits',
      icon: Icons.inventory_2_rounded,
    ),
    (path: AppRoutes.sales, label: 'Ventes', icon: Icons.shopping_cart_rounded),
    (path: AppRoutes.stores, label: 'Boutiques', icon: Icons.store_rounded),
    (path: AppRoutes.inventory, label: 'Stock', icon: Icons.warehouse_rounded),
    (
      path: AppRoutes.stockCashier,
      label: 'Stock (alertes)',
      icon: Icons.warehouse_rounded,
    ),
    (
      path: AppRoutes.purchases,
      label: 'Achats',
      icon: Icons.local_shipping_rounded,
    ),
    (
      path: AppRoutes.warehouse,
      label: 'Magasin',
      icon: Icons.home_work_rounded,
    ),
    (
      path: AppRoutes.transfers,
      label: 'Transferts',
      icon: Icons.swap_horiz_rounded,
    ),
    (path: AppRoutes.customers, label: 'Clients', icon: Icons.person_rounded),
    (
      path: AppRoutes.credit,
      label: 'Crédit',
      icon: Icons.account_balance_wallet_rounded,
    ),
    (
      path: AppRoutes.suppliers,
      label: 'Fournisseurs',
      icon: Icons.business_center_rounded,
    ),
    (path: AppRoutes.reports, label: 'Rapports', icon: Icons.bar_chart_rounded),
    (
      path: AppRoutes.ai,
      label: 'Prédictions IA',
      icon: Icons.auto_awesome_rounded,
    ),
    (path: AppRoutes.users, label: 'Utilisateurs', icon: Icons.people_rounded),
    (
      path: AppRoutes.audit,
      label: 'Journal d\'audit',
      icon: Icons.history_rounded,
    ),
    (
      path: AppRoutes.integrations,
      label: 'Intégrations API',
      icon: Icons.key_rounded,
    ),
    (path: AppRoutes.printers, label: 'Imprimantes', icon: Icons.print_rounded),
    (
      path: AppRoutes.settings,
      label: 'Paramètres',
      icon: Icons.settings_rounded,
    ),
    (path: AppRoutes.help, label: 'Aide', icon: Icons.help_outline_rounded),
    (
      path: AppRoutes.notifications,
      label: 'Notifications',
      icon: Icons.notifications_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final company = context.watch<CompanyProvider>();
    final permissions = context.watch<PermissionsProvider>();
    final isAdminRoute = GoRouterState.of(
      context,
    ).uri.path.startsWith('/admin');
    final isWide = Breakpoints.isShellDesktop(MediaQuery.sizeOf(context).width);

    // Super admin : redirigé vers l'espace admin. Délai pour éviter assertion semantics parentDataDirty.
    if (auth.isSuperAdmin) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || !context.mounted) return;
        try {
          context.go(AppRoutes.admin);
        } catch (_) {}
      });
      return Scaffold(
        body: ExcludeSemantics(
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Redirection...'),
              ],
            ),
          ),
        ),
      );
    }

    const cashierPaths = {
      AppRoutes.sales,
      AppRoutes.products,
      AppRoutes.customers,
      AppRoutes.stockCashier,
    };

    // Fallback uniquement pendant le chargement des droits. Une fois hasLoaded = true (succès ou erreur),
    // on filtre toujours par permissions pour ne pas exposer de menu après un échec de chargement.
    final List<({String path, String label, IconData icon})> visibleNavItems;
    if (!permissions.hasLoaded) {
      visibleNavItems = _navItems
          .where((e) => cashierPaths.contains(e.path))
          .toList();
    } else {
      final canReports =
          permissions.hasPermission(Permissions.reportsViewGlobal) ||
          permissions.hasPermission(Permissions.reportsViewStore);
      final warehouseModuleOn =
          company.currentCompany?.warehouseFeatureEnabled ?? true;
      final aiModuleOn = company.currentCompany?.aiPredictionsEnabled ?? false;
      final canAi =
          permissions.hasPermission(Permissions.aiInsightsView) && aiModuleOn;
      final canUsers =
          permissions.hasPermission(Permissions.usersManage) ||
          permissions.isOwner;
      final canSettings = permissions.hasPermission(Permissions.settingsManage);
      final canTransfers =
          permissions.hasPermission(Permissions.stockTransfer) ||
          permissions.hasPermission(Permissions.transfersCreate) ||
          permissions.hasPermission(Permissions.transfersApprove);
      final canDashboard = permissions.hasPermission(Permissions.dashboardView);
      final canProducts =
          permissions.hasPermission(Permissions.productsView) ||
          permissions.hasPermission(Permissions.productsCreate) ||
          permissions.hasPermission(Permissions.productsUpdate) ||
          permissions.hasPermission(Permissions.productsDelete);
      final canSales =
          permissions.hasPermission(Permissions.salesView) ||
          permissions.hasPermission(Permissions.salesCreate) ||
          permissions.hasPermission(Permissions.salesInvoiceA4);
      final canStores =
          permissions.hasPermission(Permissions.storesView) ||
          permissions.hasPermission(Permissions.storesCreate);
      final canInventory =
          permissions.hasPermission(Permissions.stockView) ||
          permissions.hasPermission(Permissions.stockAdjust) ||
          permissions.hasPermission(Permissions.stockTransfer);
      final canPurchases =
          permissions.hasPermission(Permissions.purchasesView) ||
          permissions.hasPermission(Permissions.purchasesCreate) ||
          permissions.hasPermission(Permissions.purchasesCancel) ||
          permissions.hasPermission(Permissions.purchasesUpdate) ||
          permissions.hasPermission(Permissions.purchasesDelete);
      final canCustomers =
          permissions.hasPermission(Permissions.customersView) ||
          permissions.hasPermission(Permissions.customersManage);
      final canSuppliers =
          permissions.hasPermission(Permissions.suppliersView) ||
          permissions.hasPermission(Permissions.suppliersManage);
      final canAudit =
          permissions.hasPermission(Permissions.auditView) ||
          permissions.isOwner;
      visibleNavItems = _navItems.where((e) {
        // Stock (alertes) : réservé aux caissiers / magasiniers, pas affiché pour l'owner.
        if (e.path == AppRoutes.stockCashier) {
          return canInventory && !permissions.isOwner;
        }
        if (e.path == AppRoutes.dashboard) return canDashboard;
        if (e.path == AppRoutes.products) return canProducts;
        if (e.path == AppRoutes.sales) return canSales;
        if (e.path == AppRoutes.stores) return canStores;
        // Stock (inventaire complet) : masqué pour la caissière, qui ne voit que "Stock (alertes)".
        if (e.path == AppRoutes.inventory) {
          return canInventory && !permissions.isCashier;
        }
        if (e.path == AppRoutes.purchases) return canPurchases;
        // Magasin (dépôt central) : droit + module non désactivé par la plateforme.
        if (e.path == AppRoutes.warehouse) {
          return permissions.canManageWarehouse && warehouseModuleOn;
        }
        if (e.path == AppRoutes.customers) return canCustomers;
        if (e.path == AppRoutes.credit) return permissions.canAccessCredit;
        if (e.path == AppRoutes.suppliers) return canSuppliers;
        if (e.path == AppRoutes.reports) return canReports;
        if (e.path == AppRoutes.ai) return canAi;
        if (e.path == AppRoutes.users) return canUsers;
        if (e.path == AppRoutes.settings || e.path == AppRoutes.printers) {
          return canSettings;
        }
        if (e.path == AppRoutes.transfers) return canTransfers;
        // Journal d'audit : visible pour les rôles avec droit (ex. comptable), pas dans le menu de l'owner.
        if (e.path == AppRoutes.audit) return canAudit && !permissions.isOwner;
        // Aide et Notifications : visibles uniquement pour l'owner.
        if (e.path == AppRoutes.help) return permissions.isOwner;
        if (e.path == AppRoutes.notifications) return permissions.isOwner;
        // Intégrations API : pas dans le sidebar (l'owner y accède via Paramètres).
        if (e.path == AppRoutes.integrations) return false;
        return true;
      }).toList();
    }

    return Scaffold(
      body: Row(
        children: [
          if (isWide && !isAdminRoute)
            _Sidebar(
              collapsed: _sidebarCollapsed,
              collapsedWidth: AppShell.sidebarCollapsedWidth,
              fullWidth: AppShell.sidebarWidth,
              auth: auth,
              company: company,
              isAdmin: false,
              navItems: visibleNavItems,
              onToggleCollapse: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),
          Expanded(
            child: isWide || isAdminRoute
                ? Column(
                    children: [
                      if (isWide && !isAdminRoute)
                        Consumer(
                          builder: (context, ref, _) {
                            final companyId = company.currentCompanyId ?? '';
                            final storeId = company.currentStoreId ?? '';
                            final notificationCount = ref.watch(
                              ownerNotificationsCountProvider((
                                companyId: companyId,
                                storeId: storeId,
                              )),
                            );
                            return _AppBar(
                              auth: auth,
                              company: company,
                              isAdmin: false,
                              isOwner: permissions.isOwner,
                              notificationCount: notificationCount,
                              sidebarCollapsed: _sidebarCollapsed,
                              onMenuTap: () => setState(
                                () => _sidebarCollapsed = !_sidebarCollapsed,
                              ),
                            );
                          },
                        ),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final path = GoRouterState.of(context).uri.path;
                            final factureTabFullWidth = path.contains(
                              '/facture-tab',
                            );
                            final shellW = MediaQuery.sizeOf(context).width;
                            final maxW = factureTabFullWidth
                                ? double.infinity
                                : Breakpoints.effectiveMaxContentWidth(shellW);
                            final padX = factureTabFullWidth && isWide
                                ? 10.0
                                : (isWide
                                      ? AppTheme.spaceXl
                                      : AppTheme.spaceLg);
                            final padYTop = factureTabFullWidth && isWide
                                ? 6.0
                                : (isWide
                                      ? AppTheme.spaceXl
                                      : AppTheme.spaceMd);
                            final padYBottom = factureTabFullWidth && isWide
                                ? 10.0
                                : (isWide
                                      ? AppTheme.spaceXl
                                      : AppTheme.spaceLg);
                            return Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxW),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    padX,
                                    padYTop,
                                    padX,
                                    padYBottom,
                                  ),
                                  child: widget.child,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : Scaffold(
                    key: _mobileScaffoldKey,
                    /* Stratégie mobile : drawer-only.
                       Avec 20+ destinations et plusieurs rôles (owner, caissier, comptable),
                       une bottom nav 3+Plus était un compromis bancal. Le drawer offre
                       l'accès complet et libère 100% de la hauteur écran pour le contenu —
                       pattern Linear / Notion / Slack mobile. Le hamburger reste à 1 tap
                       en haut à gauche de l'AppBar. */
                    drawer: visibleNavItems.isEmpty
                        ? null
                        : _MobileNavigationDrawer(
                            navItems: visibleNavItems,
                            company: company,
                            userEmail: auth.user?.email,
                          ),
                    appBar: _MobileAppBar(
                      preferredHeight: 56,
                      onMenuPressed: visibleNavItems.isEmpty
                          ? null
                          : () => _mobileScaffoldKey.currentState?.openDrawer(),
                    ),
                    body: LayoutBuilder(
                      builder: (bodyContext, constraints) {
                        final w = MediaQuery.sizeOf(context).width;
                        final isMobile = Breakpoints.isMobile(w);
                        final path = GoRouterState.of(context).uri.path;
                        final factureTabRoute = path.contains('/facture-tab');
                        /* POS facture-tab : pleine largeur (comme shell desktop) pour le tableau. */
                        /* Aligné appweb `FsPage` : px-3 (12px) sur mobile — sauf facture-tab. */
                        final horizontal = factureTabRoute
                            ? 0.0
                            : (isMobile
                                  ? 12.0
                                  : (w < Breakpoints.tablet
                                        ? AppTheme.spaceLg
                                        : AppTheme.spaceXl));
                        final vertical = factureTabRoute
                            ? 4.0
                            : (isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd);
                        /* La barre du shell est déjà sous la status bar : sans ça, chaque AppBar
                           interne avec primary=true réservait *deux fois* la marge — bande blanche. */
                        return MediaQuery.removePadding(
                          context: bodyContext,
                          removeTop: true,
                          child: SafeArea(
                            left: true,
                            right: true,
                            top: false,
                            bottom: true,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontal,
                                vertical: vertical,
                              ),
                              child: widget.child,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Heure dans la topbar desktop : murale système ([DateTime.now], fuseau de l'appareil).
class _DesktopClock extends StatefulWidget {
  const _DesktopClock();

  @override
  State<_DesktopClock> createState() => _DesktopClockState();
}

class _DesktopClockState extends State<_DesktopClock> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = formatDeviceWallClockHms(_now);
    final dateFormat = DateFormat('EEE d MMM', 'fr_FR');
    final dateStr = dateFormat.format(_now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({
    required this.auth,
    required this.company,
    required this.isAdmin,
    required this.isOwner,
    this.notificationCount = 0,
    required this.sidebarCollapsed,
    required this.onMenuTap,
  });

  final AuthProvider auth;
  final CompanyProvider company;
  final bool isAdmin;
  final bool isOwner;
  final int notificationCount;
  final bool sidebarCollapsed;
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              sidebarCollapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              key: ValueKey(sidebarCollapsed),
              size: 26,
            ),
          ),
          onPressed: onMenuTap,
          tooltip: sidebarCollapsed ? 'Ouvrir le menu' : 'Réduire le menu',
        ),
        titleSpacing: 0,
        title: isAdmin
            ? Text(
                'Admin plateforme',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  fontSize: 18,
                ),
              )
            : Row(
                children: [
                  const Expanded(child: SizedBox()),
                  const _DesktopClock(),
                  const Expanded(child: SizedBox()),
                ],
              ),
        actions: [
          if (isOwner) ...[
            Badge(
              isLabelVisible: notificationCount > 0,
              label: Text(
                notificationCount > 99 ? '99+' : '$notificationCount',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_rounded, size: 24),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => const OwnerNotificationsDialog(),
                ),
                tooltip: 'Notifications',
              ),
            ),
            const SizedBox(width: 32),
          ],
          if (company.companies.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: DropdownButtonHideUnderline(
                  child: Builder(
                    builder: (context) {
                      final seenIds = <String>{};
                      final distinctCompanies = company.companies
                          .where((c) => seenIds.add(c.id))
                          .toList();
                      final value =
                          company.currentCompanyId != null &&
                              distinctCompanies.any(
                                (c) => c.id == company.currentCompanyId,
                              )
                          ? company.currentCompanyId
                          : null;
                      return DropdownButton<String>(
                        value: value,
                        hint: Text(
                          'Entreprise',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        isDense: true,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(10),
                        items: distinctCompanies
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => company.setCurrentCompanyId(id),
                      );
                    },
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 24),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            tooltip: 'Déconnexion',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Logo barre mobile — `companies.logo_url` si présent (comme appweb), sinon pastille + icône inventaire.
Widget _mobileToolbarBrandFallback(Color primary) {
  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: primary.withValues(alpha: 0.22)),
    ),
    child: Icon(Icons.inventory_2_outlined, size: 18, color: primary),
  );
}

class _MobileToolbarBrandGlyph extends StatelessWidget {
  const _MobileToolbarBrandGlyph({
    required this.logoUrl,
    required this.primary,
  });

  final String? logoUrl;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final u = logoUrl?.trim();
    if (u == null || u.isEmpty) {
      return _mobileToolbarBrandFallback(primary);
    }
    return SizedBox(
      width: 32,
      height: 32,
      child: Image.network(
        u,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _mobileToolbarBrandFallback(primary),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            ),
          );
        },
      ),
    );
  }
}

/// App bar mobile — barre **fixe** Material 3 :
/// - **Racine** (drawer) : menu ☰ + titre + déconnexion ;
/// - **Tâche** (caisse, POS…) : ← retour + titre (pas de déconnexion — via drawer après retour).
class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MobileAppBar({this.onMenuPressed, this.preferredHeight = 56});

  /// `null` masque le bouton menu (ex. aucune entrée de navigation).
  final VoidCallback? onMenuPressed;
  final double preferredHeight;

  @override
  Size get preferredSize => Size.fromHeight(preferredHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final path = GoRouterState.of(context).uri.path;
    final pageTitle = MobileShellTitle.forPath(path);
    final useBack = MobileShellTitle.prefersBackLeading(path);
    final showMenu = !useBack && onMenuPressed != null;
    final leadingPad = max(4.0, MediaQuery.paddingOf(context).left);

    return FsStatusBar(
      child: AppBar(
        toolbarHeight: preferredHeight,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: (showMenu || useBack) ? 0 : 16,
        leadingWidth: (showMenu || useBack) ? 56 : 0,
        leading: useBack
            ? Padding(
                padding: EdgeInsets.only(left: leadingPad),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: onSurface),
                  onPressed: () {
                    FsHaptic.selection();
                    MobileShellTitle.navigateBack(context);
                  },
                  tooltip: 'Retour',
                ),
              )
            : showMenu
            ? Padding(
                padding: EdgeInsets.only(left: leadingPad),
                child: IconButton(
                  icon: Icon(Icons.menu_rounded, color: onSurface),
                  onPressed: () {
                    FsHaptic.selection();
                    onMenuPressed!();
                  },
                  tooltip: 'Ouvrir le menu de navigation',
                ),
              )
            : null,
        title: pageTitle != null
            ? Text(
                pageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  fontSize: 18,
                ),
              )
            : InkWell(
                onTap: () {
                  FsHaptic.selection();
                  context.go(AppRoutes.dashboard);
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusMdM),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MobileToolbarBrandGlyph(
                        logoUrl: context
                            .watch<CompanyProvider>()
                            .currentCompany
                            ?.logoUrl,
                        primary: primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FasoStockWordmark(
                          style: theme.textTheme.titleLarge!.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            fontSize: 17,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        actions: [
          if (!useBack)
            IconButton(
              icon: Icon(Icons.logout_rounded, color: onSurface),
              onPressed: () async {
                FsHaptic.selection();
                final auth = context.read<AuthProvider>();
                await auth.signOut();
                if (context.mounted) context.go(AppRoutes.login);
              },
              tooltip: 'Déconnexion',
            ),
          SizedBox(width: max(4.0, MediaQuery.paddingOf(context).right)),
        ],
      ),
    );
  }
}

String _navDrawerEmailInitials(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return '?';
  final parts = local
      .split(RegExp(r'[._-]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (local.length >= 2) return local.substring(0, 2).toUpperCase();
  return local[0].toUpperCase();
}

/// Groupe sémantique du drawer mobile — l'ordre des [paths] détermine l'ordre d'affichage
/// dans la section. Une section n'est rendue que si elle contient au moins un item visible
/// (filtré par permissions). L'ordre global des sections est donné par [_navSections].
class _NavSection {
  const _NavSection({required this.label, required this.paths});
  final String label;
  final List<String> paths;
}

/// Sections du drawer mobile — alignées sur la mentalité de l'opérateur :
/// Pilotage (vue d'ensemble) → Vente (flux quotidien) → Stock (catalogue & flux) →
/// Organisation (entités structurelles) → Système (configuration & support).
const List<_NavSection> _navSections = [
  _NavSection(
    label: 'Pilotage',
    paths: [AppRoutes.dashboard, AppRoutes.reports, AppRoutes.ai],
  ),
  _NavSection(
    label: 'Vente',
    paths: [AppRoutes.sales, AppRoutes.customers, AppRoutes.credit],
  ),
  _NavSection(
    label: 'Stock',
    paths: [
      AppRoutes.products,
      AppRoutes.inventory,
      AppRoutes.stockCashier,
      AppRoutes.purchases,
      AppRoutes.warehouse,
      AppRoutes.transfers,
      AppRoutes.suppliers,
    ],
  ),
  _NavSection(
    label: 'Organisation',
    paths: [AppRoutes.stores, AppRoutes.users],
  ),
  _NavSection(
    label: 'Système',
    paths: [
      AppRoutes.settings,
      AppRoutes.printers,
      AppRoutes.audit,
      AppRoutes.notifications,
      AppRoutes.integrations,
      AppRoutes.help,
    ],
  ),
];

/// Tiroir mobile — navigation principale sur mobile (drawer-only, pas de bottom nav).
/// Largeur 320 px max (84% de l'écran), entrées **groupées par sections** (Pilotage,
/// Vente, Stock, Organisation, Système), highlight de l'item actif, pilule « Menu »
/// pour fermer. Accessible via le hamburger leading de [_MobileAppBar].
class _MobileNavigationDrawer extends StatelessWidget {
  const _MobileNavigationDrawer({
    required this.navItems,
    required this.company,
    this.userEmail,
  });

  final List<({String path, String label, IconData icon})> navItems;
  final CompanyProvider company;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    /* Drawer mobile natif : 84 % de l'écran, plafonné à 320 (confortable pour le pouce). */
    final screenW = MediaQuery.sizeOf(context).width;
    final drawerW = min(320.0, screenW * 0.84);
    const webSidebarOrange = Color(0xFFF97316);
    final drawerBg = isDark
        ? const Color(0xFF3A1D0F)
        : Color.alphaBlend(
            webSidebarOrange.withValues(alpha: 0.34),
            Colors.white,
          );
    final drawerBorderColor = isDark
        ? const Color(0xFF7C3A12)
        : Color.alphaBlend(
            webSidebarOrange.withValues(alpha: 0.34),
            Colors.black.withValues(alpha: 0.1),
          );

    void closeDrawer() {
      Navigator.of(context).pop();
    }

    return Drawer(
      width: drawerW,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: drawerBg,
          border: Border(right: BorderSide(color: drawerBorderColor, width: 1)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: isDark ? 0.1 : 0.04),
              blurRadius: 24,
              offset: const Offset(-2, 0),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(-1, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  AppTheme.spaceXl,
                  AppTheme.spaceMd,
                  AppTheme.spaceLg,
                ),
                child: InkWell(
                  onTap: () {
                    closeDrawer();
                    context.go(AppRoutes.dashboard);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _SidebarBrandGlyph(
                          logoUrl: company.currentCompany?.logoUrl?.trim(),
                          primary: primary,
                          collapsed: false,
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FasoStockWordmark(
                                style: theme.textTheme.titleLarge!.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  fontSize: 18,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'G.Commerciale',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd,
                    AppTheme.spaceSm,
                    AppTheme.spaceMd,
                    AppTheme.spaceLg,
                  ),
                  children: _buildSectionedNav(
                    context: context,
                    navItems: navItems,
                    onBeforeNavigate: closeDrawer,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  AppTheme.spaceSm,
                  AppTheme.spaceMd,
                  AppTheme.spaceLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MobileDrawerMenuPill(onPressed: closeDrawer),
                    if (userEmail != null && userEmail!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spaceSm),
                      _MobileDrawerAccountChip(email: userEmail!.trim()),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Construit la liste des widgets enfants pour le ListView sectionné du drawer.
///
/// Pour chaque section déclarée dans [_navSections], on ne génère un header + items
/// que si la section contient au moins un item visible (filtré par permissions amont).
/// Les items orphelins (non rattachés à une section) sont concaténés à la fin sous
/// un en-tête "Divers" — protection contre une nouvelle route oubliée.
List<Widget> _buildSectionedNav({
  required BuildContext context,
  required List<({String path, String label, IconData icon})> navItems,
  required VoidCallback onBeforeNavigate,
}) {
  final visibleByPath = {for (final i in navItems) i.path: i};
  final usedPaths = <String>{};
  final children = <Widget>[];

  for (var sIdx = 0; sIdx < _navSections.length; sIdx++) {
    final section = _navSections[sIdx];
    final items = section.paths
        .where(visibleByPath.containsKey)
        .map((p) => visibleByPath[p]!)
        .toList();
    if (items.isEmpty) continue;
    if (children.isNotEmpty) {
      children.add(const SizedBox(height: AppTheme.spaceMd));
    }
    children.add(_DrawerSectionHeader(label: section.label));
    for (final e in items) {
      usedPaths.add(e.path);
      children.add(
        _NavTile(
          path: e.path,
          label: e.label,
          icon: e.icon,
          collapsed: false,
          onBeforeNavigate: onBeforeNavigate,
        ),
      );
    }
  }

  /* Filet de sécurité : si une nouvelle route apparaît sans être placée dans
     [_navSections], elle reste accessible sous "Divers" en bas de la liste. */
  final orphans = navItems
      .where((i) => !usedPaths.contains(i.path))
      .toList();
  if (orphans.isNotEmpty) {
    if (children.isNotEmpty) {
      children.add(const SizedBox(height: AppTheme.spaceMd));
    }
    children.add(const _DrawerSectionHeader(label: 'Divers'));
    for (final e in orphans) {
      children.add(
        _NavTile(
          path: e.path,
          label: e.label,
          icon: e.icon,
          collapsed: false,
          onBeforeNavigate: onBeforeNavigate,
        ),
      );
    }
  }
  return children;
}

/// En-tête de section dans le drawer mobile — typographie compacte M3, lettres espacées,
/// teinte primaire atténuée pour scanner les groupes sans dominer les items.
class _DrawerSectionHeader extends StatelessWidget {
  const _DrawerSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceSm,
        AppTheme.spaceXs,
        AppTheme.spaceSm,
        AppTheme.spaceXs,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: cs.primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.85 : 0.75,
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Pilule Menu + chevron — même principe que `app-sidebar.tsx` (variant mobileDrawer).
class _MobileDrawerMenuPill extends StatelessWidget {
  const _MobileDrawerMenuPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.45)
        : const Color(0xFFF5F5F5);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.07);

    return Semantics(
      button: true,
      label: 'Fermer le menu',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        elevation: 2,
        shadowColor: shadowColor,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.menu_rounded, size: 18, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Menu',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark
                          ? theme.colorScheme.onSurface
                          : const Color(0xFF262626),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.85,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileDrawerAccountChip extends StatelessWidget {
  const _MobileDrawerAccountChip({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final primary = cs.primary;
    final initials = _navDrawerEmailInitials(email);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              initials,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: primary,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMPTE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo entreprise (`companies.logo_url`) ou icône par défaut si absent / erreur de chargement.
class _SidebarBrandGlyph extends StatelessWidget {
  const _SidebarBrandGlyph({
    required this.logoUrl,
    required this.primary,
    required this.collapsed,
  });

  final String? logoUrl;
  final Color primary;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    // Sidebar réduite 64px : logo ~44 ; étendue : logo plus lisible sans carte de fond.
    final size = collapsed ? 44.0 : 54.0;
    final radius = collapsed ? 8.0 : 10.0;
    final u = logoUrl?.trim();
    if (u == null || u.isEmpty) {
      return Icon(Icons.inventory_2_rounded, color: primary, size: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        u,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Icon(Icons.inventory_2_rounded, color: primary, size: size),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.5,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.collapsed,
    required this.collapsedWidth,
    required this.fullWidth,
    required this.auth,
    required this.company,
    required this.isAdmin,
    required this.navItems,
    required this.onToggleCollapse,
  });

  final bool collapsed;
  final double collapsedWidth;
  final double fullWidth;
  final AuthProvider auth;
  final CompanyProvider company;
  final bool isAdmin;
  final List<({String path, String label, IconData icon})> navItems;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = collapsed ? collapsedWidth : fullWidth;
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    const webSidebarOrange = Color(0xFFF97316);
    final sidebarBg = isDark
        ? const Color(0xFF3A1D0F)
        : Color.alphaBlend(
            webSidebarOrange.withValues(alpha: 0.34),
            Colors.white,
          );
    final sidebarBorderColor = isDark
        ? const Color(0xFF7C3A12)
        : Color.alphaBlend(
            webSidebarOrange.withValues(alpha: 0.34),
            Colors.black.withValues(alpha: 0.1),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 24,
            offset: const Offset(-2, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(-1, 0),
          ),
        ],
      ),
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              // En-tête marque — logo sans carte de fond ; tailles calées sur collapsedWidth (64px).
              Padding(
                padding: EdgeInsets.fromLTRB(
                  collapsed ? 6 : AppTheme.spaceMd,
                  collapsed ? AppTheme.spaceLg : AppTheme.spaceXl,
                  collapsed ? 6 : AppTheme.spaceMd,
                  collapsed ? AppTheme.spaceSm : AppTheme.spaceLg,
                ),
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    _SidebarBrandGlyph(
                      logoUrl: company.currentCompany?.logoUrl?.trim(),
                      primary: primary,
                      collapsed: collapsed,
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isAdmin
                                ? Text(
                                    'Admin',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      fontSize: 18,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : FasoStockWordmark(
                                    style: theme.textTheme.titleLarge!.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      fontSize: 18,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            Text(
                              isAdmin ? 'Plateforme' : 'G.Commerciale',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    collapsed ? AppTheme.spaceSm : AppTheme.spaceMd,
                    AppTheme.spaceSm,
                    collapsed ? AppTheme.spaceSm : AppTheme.spaceMd,
                    AppTheme.spaceLg,
                  ),
                  children: navItems
                      .map(
                        (e) => _NavTile(
                          path: e.path,
                          label: e.label,
                          icon: e.icon,
                          collapsed: collapsed,
                        ),
                      )
                      .toList(),
                ),
              ),
              // Bouton réduire — style pill
              Padding(
                padding: EdgeInsets.fromLTRB(
                  collapsed ? AppTheme.spaceSm : AppTheme.spaceMd,
                  AppTheme.spaceSm,
                  collapsed ? AppTheme.spaceSm : AppTheme.spaceMd,
                  collapsed ? AppTheme.spaceMd : AppTheme.spaceLg,
                ),
                child: Tooltip(
                  message: collapsed ? 'Agrandir le menu' : 'Réduire le menu',
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHigh.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    child: InkWell(
                      onTap: onToggleCollapse,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: collapsed ? 10 : 12,
                          horizontal: collapsed ? 10 : 14,
                        ),
                        child: Row(
                          mainAxisSize: collapsed
                              ? MainAxisSize.min
                              : MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              collapsed
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            if (!collapsed) ...[
                              const SizedBox(width: AppTheme.spaceSm),
                              Expanded(
                                child: Text(
                                  'Réduire le menu',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.path,
    required this.label,
    required this.icon,
    required this.collapsed,
    this.onBeforeNavigate,
  });

  final String path;
  final String label;
  final IconData icon;
  final bool collapsed;

  /// Ex. fermer le tiroir avant [context.go].
  final VoidCallback? onBeforeNavigate;

  bool _isActive(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (path == AppRoutes.dashboard) return loc == path;
    return loc.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _isActive(context);
    final primary = theme.colorScheme.primary;
    final isDesktop = Breakpoints.isShellDesktop(
      MediaQuery.sizeOf(context).width,
    );
    final collapsedIconSize = isDesktop ? 31.0 : 26.0;
    final expandedIconSize = isDesktop ? 28.0 : 24.0;

    if (collapsed) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: isActive
                    ? primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: InkWell(
                  onTap: () {
                    if (!isActive) FsHaptic.selection();
                    onBeforeNavigate?.call();
                    context.go(path);
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        icon,
                        size: collapsedIconSize,
                        color: isActive
                            ? primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              if (isActive)
                Positioned(
                  left: 0,
                  top: 10,
                  bottom: 10,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: isActive
                ? primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              onTap: () {
                if (!isActive) FsHaptic.selection();
                onBeforeNavigate?.call();
                context.go(path);
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive
                            ? primary.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHigh.withValues(
                                alpha: 0.5,
                              ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        icon,
                        size: expandedIconSize,
                        color: isActive
                            ? primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 14,
                          color: isActive
                              ? primary
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isActive)
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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

/// Layout principal : sidebar réductible (desktop) + bottom nav (mobile).
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
  final GlobalKey<ScaffoldState> _mobileScaffoldKey = GlobalKey<ScaffoldState>();
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
    (
      path: AppRoutes.printers,
      label: 'Imprimantes',
      icon: Icons.print_rounded,
    ),
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
      final warehouseModuleOn = company.currentCompany?.warehouseFeatureEnabled ?? true;
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
                            final factureTabFullWidth =
                                path.contains('/facture-tab');
                            final shellW = MediaQuery.sizeOf(context).width;
                            final maxW = factureTabFullWidth
                                ? double.infinity
                                : Breakpoints.effectiveMaxContentWidth(
                                    shellW,
                                  );
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
                    drawer: visibleNavItems.isEmpty
                        ? null
                        : _MobileNavigationDrawer(
                            navItems: visibleNavItems,
                            company: company,
                            userEmail: auth.user?.email,
                          ),
                    appBar: _MobileAppBar(
                      preferredHeight: 58,
                      onMenuPressed: visibleNavItems.isEmpty
                          ? null
                          : () =>
                                _mobileScaffoldKey.currentState?.openDrawer(),
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
                            : (isMobile
                                  ? AppTheme.spaceMdM
                                  : AppTheme.spaceMd);
                        /* La barre du shell est déjà sous la status bar : sans ça, chaque AppBar
                           interne avec primary=true réservait *deux fois* la marge → bande blanche. */
                        return MediaQuery.removePadding(
                          context: bodyContext,
                          removeTop: true,
                          child: SafeArea(
                            left: true,
                            right: true,
                            top: false,
                            bottom: false,
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
                    bottomNavigationBar: _BottomNav(
                      auth: auth,
                      company: company,
                      navItems: visibleNavItems,
                      onMoreTap: () =>
                          _showMoreBottomSheet(context, visibleNavItems),
                      isMobile: Breakpoints.isMobile(
                        MediaQuery.sizeOf(context).width,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Aligné sur `appweb/components/layout/more-sheet.tsx` : surface thème, grille 4 cols.
  void _showMoreBottomSheet(
    BuildContext context,
    List<({String path, String label, IconData icon})> visibleNavItems,
  ) {
    const bottomPaths = [
      AppRoutes.dashboard,
      AppRoutes.products,
      AppRoutes.sales,
    ];
    final moreItems = visibleNavItems
        .where((e) => !bottomPaths.contains(e.path))
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: const Color(0x73000000),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final h = MediaQuery.sizeOf(ctx).height;
        final safeBottom = MediaQuery.paddingOf(ctx).bottom;
        final accentHeader = theme.brightness == Brightness.dark ? 0.12 : 0.08;

        return Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(ctx).top),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: h * 0.85),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 40,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            cs.primary.withValues(alpha: accentHeader),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: cs.onSurfaceVariant.withValues(
                                alpha: 0.35,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (h * 0.7).clamp(200.0, 520.0),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + safeBottom),
                        child: moreItems.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'Aucune autre section',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  const gap = 4.0;
                                  const crossAxisCount = 4;
                                  const tileHeight = 76.0;
                                  final w = constraints.maxWidth;
                                  final cellW =
                                      (w - (crossAxisCount - 1) * gap) /
                                      crossAxisCount;
                                  final aspect = cellW / tileHeight;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: gap,
                                      mainAxisSpacing: gap,
                                      childAspectRatio: aspect,
                                    ),
                                    itemCount: moreItems.length,
                                    itemBuilder: (context, index) {
                                      final e = moreItems[index];
                                      return Material(
                                        color: cs.surfaceContainer,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(
                                            color: cs.outline.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(ctx).pop();
                                            context.go(e.path);
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          splashColor: cs.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                          highlightColor: cs.primary
                                              .withValues(alpha: 0.06),
                                          child: Padding(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 2,
                                              vertical: 6,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: cs.primary
                                                        .withValues(
                                                      alpha: 0.14,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      8,
                                                    ),
                                                    border: Border.all(
                                                      color: cs.primary
                                                          .withValues(
                                                        alpha: 0.22,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    e.icon,
                                                    size: 16,
                                                    color: cs.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  e.label,
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.25,
                                                    color: cs.onSurface,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Heure dans la topbar desktop : murale système ([DateTime.now], fuseau de l’appareil).
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
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
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
      width: 36,
      height: 36,
      child: Image.network(
        u,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _mobileToolbarBrandFallback(primary),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary),
            ),
          );
        },
      ),
    );
  }
}

/// App bar mobile — alignée `app-shell.tsx` (web) : logo + menu → drawer navigation plein, déconnexion.
class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MobileAppBar({this.onMenuPressed, this.preferredHeight = 58});

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
    final borderColor = theme.dividerColor.withValues(alpha: 0.06);
    final shellIconButton = IconButton.styleFrom(
      padding: const EdgeInsets.all(8),
      minimumSize: const Size(40, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: preferredHeight,
        automaticallyImplyLeading: false,
        leadingWidth: 0,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.only(
            left: max(12.0, MediaQuery.paddingOf(context).left),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => context.go(AppRoutes.dashboard),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MobileToolbarBrandGlyph(
                        logoUrl:
                            context.watch<CompanyProvider>().currentCompany?.logoUrl,
                        primary: primary,
                      ),
                      const SizedBox(width: 8),
                      FasoStockWordmark(
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onMenuPressed != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.menu_rounded, size: 20, color: onSurface),
                  onPressed: onMenuPressed,
                  tooltip: 'Ouvrir le menu de navigation',
                  style: shellIconButton,
                ),
              ],
            ],
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(
              right: max(12.0, MediaQuery.paddingOf(context).right),
            ),
            child: IconButton(
              icon: Icon(Icons.logout_rounded, size: 20, color: onSurface),
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                await auth.signOut();
                if (context.mounted) context.go(AppRoutes.login);
              },
              tooltip: 'Déconnexion',
              style: shellIconButton,
            ),
          ),
        ],
      ),
    );
  }
}

String _navDrawerEmailInitials(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return '?';
  final parts = local.split(RegExp(r'[._-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  if (local.length >= 2) return local.substring(0, 2).toUpperCase();
  return local[0].toUpperCase();
}

/// Tiroir mobile — aligné appweb : largeur max 260px, toutes les entrées, pilule « Menu » pour fermer.
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
    final drawerW = min(260.0, MediaQuery.sizeOf(context).width);

    void closeDrawer() {
      Navigator.of(context).pop();
    }

    return Drawer(
      width: drawerW,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    theme.colorScheme.surfaceContainerLowest,
                    theme.colorScheme.surfaceContainerLowest
                        .withValues(alpha: 0.98),
                  ]
                : [
                    theme.colorScheme.surfaceContainerLowest,
                    theme.colorScheme.surfaceContainerLow
                        .withValues(alpha: 0.5),
                  ],
          ),
          border: Border(
            right: BorderSide(
              color: theme.dividerColor.withValues(alpha: isDark ? 0.15 : 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: isDark ? 0.08 : 0.03),
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
                                'Gestion & caisse',
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
                  children: navItems
                      .map(
                        (e) => _NavTile(
                          path: e.path,
                          label: e.label,
                          icon: e.icon,
                          collapsed: false,
                          onBeforeNavigate: closeDrawer,
                        ),
                      )
                      .toList(),
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
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.85),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surfaceContainerLowest,
                  theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.98),
                ]
              : [
                  theme.colorScheme.surfaceContainerLowest,
                  theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                ],
        ),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: isDark ? 0.15 : 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.08 : 0.03),
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
                              isAdmin ? 'Plateforme' : 'Gestion & caisse',
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
                    color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
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
                        size: 26,
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
            color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              onTap: () {
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
                            : theme.colorScheme.surfaceContainerHigh
                                  .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(
                        icon,
                        size: 24,
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
                          fontSize: 15,
                          color: isActive
                              ? primary
                              : theme.colorScheme.onSurface,
                        ),
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

/// Bottom nav mobile — aligné appweb : Accueil, Produits, Vente, Plus (barre pleine largeur).
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.auth,
    required this.company,
    required this.navItems,
    required this.onMoreTap,
    this.isMobile = false,
  });

  final AuthProvider auth;
  final CompanyProvider company;
  final List<({String path, String label, IconData icon})> navItems;
  final VoidCallback onMoreTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = GoRouterState.of(context).uri.path;
    const bottomPaths = [
      AppRoutes.dashboard,
      AppRoutes.products,
      AppRoutes.sales,
    ];
    final mainItems = navItems.any((e) => e.path == AppRoutes.dashboard)
        ? navItems.where((e) => bottomPaths.contains(e.path)).toList()
        : navItems.take(3).toList();
    if (mainItems.isEmpty) return const SizedBox.shrink();

    int selectedIndex = mainItems.indexWhere(
      (e) => e.path == AppRoutes.dashboard
          ? loc == e.path
          : loc.startsWith(e.path),
    );
    if (selectedIndex < 0) selectedIndex = 0;

    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    String labelFor(String path) {
      /* Libellés courts alignés appweb `MOBILE_LABELS` */
      if (path == AppRoutes.dashboard) return 'Accueil';
      if (path == AppRoutes.sales) return 'Vente';
      if (path == AppRoutes.products) return 'Produits';
      if (path == AppRoutes.customers) return 'Clients';
      if (path == AppRoutes.inventory) return 'Stock';
      if (path == AppRoutes.stockCashier) return 'Stock (alertes)';
      if (path == AppRoutes.purchases) return 'Achats';
      if (path == AppRoutes.suppliers) return 'Fournisseurs';
      return path;
    }

    /// Barre pleine largeur (non flottante), alignée `shellBottomNavBarClass` / grille 4 colonnes (web).
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surface.withValues(alpha: isMobile ? 0.965 : 0.95),
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: isMobile ? 0.055 : 0.06),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMobile ? 0.052 : 0.08),
              blurRadius: isMobile ? 16 : 32,
              offset: Offset(0, isMobile ? -4 : -8),
              spreadRadius: isMobile ? -5 : -12,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              max(isMobile ? 6.0 : 8.0, MediaQuery.paddingOf(context).left),
              isMobile ? 4 : 8,
              max(isMobile ? 6.0 : 8.0, MediaQuery.paddingOf(context).right),
              max(isMobile ? 5.0 : 8.0, MediaQuery.paddingOf(context).bottom),
            ),
            child: Row(
              children: [
                ...List.generate(mainItems.length, (i) {
                  final e = mainItems[i];
                  final isSelected = i == selectedIndex;
                  return Expanded(
                    child: _NavDestination(
                      path: e.path,
                      label: labelFor(e.path),
                      icon: e.icon,
                      isSelected: isSelected,
                      primary: primary,
                      theme: theme,
                      onTap: () => context.go(e.path),
                      isMobile: isMobile,
                    ),
                  );
                }),
                Expanded(
                  child: _NavDestination(
                    path: null,
                    label: 'Plus',
                    icon: Icons.more_horiz_rounded,
                    isSelected: false,
                    primary: primary,
                    theme: theme,
                    onTap: onMoreTap,
                    isMobile: isMobile,
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

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    this.path,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.primary,
    required this.theme,
    required this.onTap,
    this.isMobile = false,
  });

  final String? path;
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color primary;
  final ThemeData theme;
  final VoidCallback onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    /* Mobile : équilibre lisibilité / hauteur (entre compact et barre d’origine). */
    final minH = isMobile ? 44.0 : 56.0;
    final vPad = isMobile ? 3.0 : 6.0;
    final hPad = isMobile ? 5.0 : 6.0;
    final iconGap = isMobile ? 2.0 : 4.0;
    final iconSize = isMobile ? 22.0 : 26.0;
    final labelSize = isMobile ? 10.0 : 11.0;
    final radius = isMobile ? 13.0 : 16.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: primary.withValues(alpha: 0.12),
        highlightColor: primary.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          constraints: BoxConstraints(minHeight: minH),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: isMobile ? 0.12 : 0.13)
                : null,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isMobile ? 0.03 : 0.04,
                      ),
                      blurRadius: isMobile ? 1.5 : 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: isSelected
                    ? primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              SizedBox(height: iconGap),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  letterSpacing: isMobile ? -0.22 : -0.2,
                  color: isSelected
                      ? primary
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

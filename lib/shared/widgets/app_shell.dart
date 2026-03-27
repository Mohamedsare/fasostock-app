import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' hide Consumer;
import '../../core/breakpoints.dart';
import '../../core/utils/user_country_time.dart';
import '../../core/config/routes.dart';
import '../../core/constants/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../features/notifications/owner_notifications_dialog.dart';
import '../../features/notifications/owner_notifications_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/permissions_provider.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navItems = [
    (path: AppRoutes.dashboard, label: 'Tableau de bord', icon: Icons.dashboard_rounded),
    (path: AppRoutes.products, label: 'Produits', icon: Icons.inventory_2_rounded),
    (path: AppRoutes.sales, label: 'Ventes', icon: Icons.shopping_cart_rounded),
    (path: AppRoutes.stores, label: 'Boutiques', icon: Icons.store_rounded),
    (path: AppRoutes.inventory, label: 'Stock', icon: Icons.warehouse_rounded),
    (path: AppRoutes.stockCashier, label: 'Stock (alertes)', icon: Icons.warehouse_rounded),
    (path: AppRoutes.purchases, label: 'Achats', icon: Icons.local_shipping_rounded),
    (path: AppRoutes.warehouse, label: 'Magasin', icon: Icons.home_work_rounded),
    (path: AppRoutes.transfers, label: 'Transferts', icon: Icons.swap_horiz_rounded),
    (path: AppRoutes.customers, label: 'Clients', icon: Icons.person_rounded),
    (path: AppRoutes.suppliers, label: 'Fournisseurs', icon: Icons.business_center_rounded),
    (path: AppRoutes.reports, label: 'Rapports', icon: Icons.bar_chart_rounded),
    (path: AppRoutes.ai, label: 'Prédictions IA', icon: Icons.auto_awesome_rounded),
    (path: AppRoutes.users, label: 'Utilisateurs', icon: Icons.people_rounded),
    (path: AppRoutes.audit, label: 'Journal d\'audit', icon: Icons.history_rounded),
    (path: AppRoutes.integrations, label: 'Intégrations API', icon: Icons.key_rounded),
    (path: AppRoutes.settings, label: 'Paramètres', icon: Icons.settings_rounded),
    (path: AppRoutes.help, label: 'Aide', icon: Icons.help_outline_rounded),
    (path: AppRoutes.notifications, label: 'Notifications', icon: Icons.notifications_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final company = context.watch<CompanyProvider>();
    final permissions = context.watch<PermissionsProvider>();
    final isAdminRoute = GoRouterState.of(context).uri.path.startsWith('/admin');
    final isWide = Breakpoints.isDesktop(MediaQuery.sizeOf(context).width);

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
      visibleNavItems = _navItems.where((e) => cashierPaths.contains(e.path)).toList();
    } else {
      final canReports = permissions.hasPermission(Permissions.reportsViewGlobal) ||
          permissions.hasPermission(Permissions.reportsViewStore);
      final canAi = permissions.hasPermission(Permissions.aiInsightsView);
      final canUsers = permissions.hasPermission(Permissions.usersManage) || permissions.isOwner;
      final canSettings = permissions.hasPermission(Permissions.settingsManage);
      final canTransfers = permissions.hasPermission(Permissions.stockTransfer) ||
          permissions.hasPermission(Permissions.transfersCreate) ||
          permissions.hasPermission(Permissions.transfersApprove);
      final canDashboard = permissions.hasPermission(Permissions.dashboardView);
      final canProducts = permissions.hasPermission(Permissions.productsView) ||
          permissions.hasPermission(Permissions.productsCreate) ||
          permissions.hasPermission(Permissions.productsUpdate) ||
          permissions.hasPermission(Permissions.productsDelete);
      final canSales = permissions.hasPermission(Permissions.salesView) ||
          permissions.hasPermission(Permissions.salesCreate) ||
          permissions.hasPermission(Permissions.salesInvoiceA4);
      final canStores = permissions.hasPermission(Permissions.storesView) ||
          permissions.hasPermission(Permissions.storesCreate);
      final canInventory = permissions.hasPermission(Permissions.stockView) ||
          permissions.hasPermission(Permissions.stockAdjust) ||
          permissions.hasPermission(Permissions.stockTransfer);
      final canPurchases = permissions.hasPermission(Permissions.purchasesView) ||
          permissions.hasPermission(Permissions.purchasesCreate) ||
          permissions.hasPermission(Permissions.purchasesCancel) ||
          permissions.hasPermission(Permissions.purchasesUpdate) ||
          permissions.hasPermission(Permissions.purchasesDelete);
      final canCustomers = permissions.hasPermission(Permissions.customersView) ||
          permissions.hasPermission(Permissions.customersManage);
      final canSuppliers = permissions.hasPermission(Permissions.suppliersView) ||
          permissions.hasPermission(Permissions.suppliersManage);
      final canAudit = permissions.hasPermission(Permissions.auditView) || permissions.isOwner;
      visibleNavItems = _navItems.where((e) {
        // Stock (alertes) : réservé aux caissiers / magasiniers, pas affiché pour l'owner.
        if (e.path == AppRoutes.stockCashier) return canInventory && !permissions.isOwner;
        if (e.path == AppRoutes.dashboard) return canDashboard;
        if (e.path == AppRoutes.products) return canProducts;
        if (e.path == AppRoutes.sales) return canSales;
        if (e.path == AppRoutes.stores) return canStores;
        // Stock (inventaire complet) : masqué pour la caissière, qui ne voit que "Stock (alertes)".
        if (e.path == AppRoutes.inventory) return canInventory && !permissions.isCashier;
        if (e.path == AppRoutes.purchases) return canPurchases;
        // Magasin (dépôt central) : réservé au propriétaire.
        if (e.path == AppRoutes.warehouse) return permissions.isOwner;
        if (e.path == AppRoutes.customers) return canCustomers;
        if (e.path == AppRoutes.suppliers) return canSuppliers;
        if (e.path == AppRoutes.reports) return canReports;
        if (e.path == AppRoutes.ai) return canAi;
        if (e.path == AppRoutes.users) return canUsers;
        if (e.path == AppRoutes.settings) return canSettings;
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
              onToggleCollapse: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
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
                            final notificationCount = ref.watch(ownerNotificationsCountProvider((companyId: companyId, storeId: storeId)));
                            return _AppBar(
                              auth: auth,
                              company: company,
                              isAdmin: false,
                              isOwner: permissions.isOwner,
                              notificationCount: notificationCount,
                              sidebarCollapsed: _sidebarCollapsed,
                              onMenuTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                            );
                          },
                        ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: Breakpoints.effectiveMaxContentWidth(MediaQuery.sizeOf(context).width),
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                isWide ? AppTheme.spaceXl : AppTheme.spaceLg,
                                isWide ? AppTheme.spaceXl : AppTheme.spaceMd,
                                isWide ? AppTheme.spaceXl : AppTheme.spaceLg,
                                isWide ? AppTheme.spaceXl : AppTheme.spaceLg,
                              ),
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Scaffold(
                    key: _scaffoldKey,
                    drawer: _AppDrawer(
                      auth: auth,
                      company: company,
                      navItems: visibleNavItems,
                    ),
                    appBar: _MobileAppBar(
                      company: company,
                      preferredHeight: Breakpoints.isMobile(MediaQuery.sizeOf(context).width) ? 52 : 58,
                    ),
                    body: LayoutBuilder(
                      builder: (_, constraints) {
                        final w = MediaQuery.sizeOf(context).width;
                        final isMobile = Breakpoints.isMobile(w);
                        final horizontal = isMobile
                            ? (w < 360 ? AppTheme.spaceMdM : AppTheme.spaceLgM)
                            : (w < Breakpoints.tablet ? AppTheme.spaceLg : AppTheme.spaceXl);
                        final vertical = isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd;
                        return SafeArea(
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
                        );
                      },
                    ),
                    bottomNavigationBar: _BottomNav(
                      auth: auth,
                      company: company,
                      navItems: visibleNavItems,
                      onMoreTap: () => _showMoreBottomSheet(context, visibleNavItems, auth),
                      isMobile: Breakpoints.isMobile(MediaQuery.sizeOf(context).width),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showMoreBottomSheet(
    BuildContext context,
    List<({String path, String label, IconData icon})> visibleNavItems,
    AuthProvider auth,
  ) {
    const bottomPaths = [AppRoutes.dashboard, AppRoutes.products, AppRoutes.sales];
    final moreItems = visibleNavItems.where((e) => !bottomPaths.contains(e.path)).toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFF38383A);
    final tileBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFF48484A);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    const spacing = 12.0;
                    const minItemWidth = 100.0;
                    final crossCount = w < 360 ? 2 : 3;
                    var itemWidth = (w - (crossCount - 1) * spacing) / crossCount;
                    if (itemWidth < minItemWidth) itemWidth = (w - spacing) / 2;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: moreItems.map((e) {
                        return SizedBox(
                          width: itemWidth,
                          child: Material(
                            color: tileBg,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                context.go(e.path);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(e.icon, size: 30, color: Colors.white),
                                    const SizedBox(height: 8),
                                    Text(
                                      e.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await auth.signOut();
                        if (context.mounted) context.go(AppRoutes.login);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: theme.colorScheme.onError, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Déconnexion',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onError,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

/// Heure dans la topbar desktop : fuseau du pays de la boutique courante (champ pays), sinon heure appareil.
class _DesktopClock extends StatefulWidget {
  const _DesktopClock({this.countryHint});

  /// Pays saisi sur la boutique (ex. « Burkina Faso », `BF`) — voir [nowInUserCountry].
  final String? countryHint;

  @override
  State<_DesktopClock> createState() => _DesktopClockState();
}

class _DesktopClockState extends State<_DesktopClock> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = nowInUserCountry(widget.countryHint);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = nowInUserCountry(widget.countryHint));
    });
  }

  @override
  void didUpdateWidget(covariant _DesktopClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryHint != widget.countryHint) {
      _now = nowInUserCountry(widget.countryHint);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('EEE d MMM', 'fr_FR');
    final timeStr = timeFormat.format(_now);
    final dateStr = dateFormat.format(_now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
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
        border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.12))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  _DesktopClock(countryHint: company.currentStore?.country),
                  const Expanded(child: SizedBox()),
                ],
              ),
        actions: [
        if (isOwner) ...[
          Badge(
            isLabelVisible: notificationCount > 0,
            label: Text(
              notificationCount > 99 ? '99+' : '$notificationCount',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
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
                      final distinctCompanies = company.companies.where((c) => seenIds.add(c.id)).toList();
                      final value = company.currentCompanyId != null &&
                              distinctCompanies.any((c) => c.id == company.currentCompanyId)
                          ? company.currentCompanyId
                          : null;
                      return DropdownButton<String>(
                        value: value,
                        hint: Text('Entreprise', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis),
                        isDense: true,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(10),
                        items: distinctCompanies
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))))
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

/// App bar mobile — logo + menu (drawer) + déconnexion. Hauteur réduite sur mobile (width < 600).
class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MobileAppBar({required this.company, this.preferredHeight = 52});

  final CompanyProvider company;
  final double preferredHeight;

  @override
  Size get preferredSize => Size.fromHeight(preferredHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final borderColor = theme.dividerColor.withOpacity(0.12);
    final buttonStyle = IconButton.styleFrom(
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      minimumSize: const Size(44, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: theme.colorScheme.surfaceContainerLow.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: borderColor, width: 1),
      ),
    );
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: preferredHeight,
      leadingWidth: 44,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(Icons.menu_rounded, size: 26, color: primary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          tooltip: 'Menu',
          style: buttonStyle,
        ),
      ),
      titleSpacing: 12,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              fontSize: 17,
            ),
            children: [
              TextSpan(text: 'Faso', style: TextStyle(color: onSurface)),
              TextSpan(text: 'Stock', style: TextStyle(color: primary)),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: theme.dividerColor.withOpacity(0.08),
        ),
      ),
      actions: [
        if (company.companies.length > 1)
          Builder(
            builder: (context) {
              final seenIds = <String>{};
              final distinctCompanies = company.companies.where((c) => seenIds.add(c.id)).toList();
              final value = company.currentCompanyId != null &&
                      distinctCompanies.any((c) => c.id == company.currentCompanyId)
                  ? company.currentCompanyId
                  : null;
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    hint: Text('Entr.', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
                    borderRadius: BorderRadius.circular(8),
                    isExpanded: true,
                    isDense: true,
                    items: distinctCompanies
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (id) => company.setCurrentCompanyId(id),
                  ),
                ),
              );
            },
          ),
        IconButton(
          icon: Icon(Icons.logout_rounded, size: 24, color: primary),
          onPressed: () async {
            final auth = context.read<AuthProvider>();
            await auth.signOut();
            if (context.mounted) context.go(AppRoutes.login);
          },
          tooltip: 'Déconnexion',
          style: buttonStyle,
        ),
      ],
    );
  }
}

/// Drawer mobile — navigation complète (toutes les sections) + entreprise.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.auth,
    required this.company,
    required this.navItems,
  });

  final AuthProvider auth;
  final CompanyProvider company;
  final List<({String path, String label, IconData icon})> navItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = GoRouterState.of(context).uri.path;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceMd),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.primary, size: 28),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'FasoStock',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Gestion & caisse',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (company.companies.length > 1) ...[
              Builder(
                builder: (context) {
                  final seenIds = <String>{};
                  final distinctCompanies = company.companies.where((c) => seenIds.add(c.id)).toList();
                  final value = company.currentCompanyId != null &&
                          distinctCompanies.any((c) => c.id == company.currentCompanyId)
                      ? company.currentCompanyId
                      : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                    child: DropdownButtonFormField<String>(
                      value: value,
                      decoration: InputDecoration(
                        labelText: 'Entreprise',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      items: distinctCompanies
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (id) => company.setCurrentCompanyId(id),
                    ),
                  );
                },
              ),
            ],
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm, horizontal: AppTheme.spaceSm),
                children: navItems.map((e) {
                  final active = e.path == AppRoutes.dashboard
                      ? path == e.path || path == '${e.path}/'
                      : path.startsWith(e.path);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
                    child: Material(
                      color: active ? theme.colorScheme.primaryContainer.withOpacity(0.35) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          e.icon,
                          size: 24,
                          color: active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          e.label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 15,
                            color: active ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          ),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(e.path);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(Icons.logout_rounded, size: 24, color: theme.colorScheme.error),
              title: Text(
                'Déconnexion',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: theme.colorScheme.error,
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              onTap: () async {
                Navigator.of(context).pop();
                await auth.signOut();
                if (context.mounted) context.go(AppRoutes.login);
              },
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],
        ),
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
                  theme.colorScheme.surfaceContainerLowest.withOpacity(0.98),
                ]
              : [
                  theme.colorScheme.surfaceContainerLowest,
                  theme.colorScheme.surfaceContainerLow.withOpacity(0.5),
                ],
        ),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withOpacity(isDark ? 0.15 : 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(isDark ? 0.08 : 0.03),
            blurRadius: 24,
            offset: const Offset(-2, 0),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
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
            // En-tête marque — en mode réduit padding/tailles réduits pour rester sous collapsedWidth (64px) et éviter overflow.
            Padding(
              padding: EdgeInsets.fromLTRB(
                collapsed ? 6 : AppTheme.spaceMd,
                collapsed ? AppTheme.spaceLg : AppTheme.spaceXl,
                collapsed ? 6 : AppTheme.spaceMd,
                collapsed ? AppTheme.spaceSm : AppTheme.spaceLg,
              ),
              child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(collapsed ? 8 : 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primary.withOpacity(0.2),
                        primary.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: primary,
                    size: collapsed ? 28 : 30,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isAdmin ? 'Admin' : 'FasoStock',
                          style: theme.textTheme.titleLarge?.copyWith(
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
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9),
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
              children: navItems.map((e) => _NavTile(
                path: e.path,
                label: e.label,
                icon: e.icon,
                collapsed: collapsed,
              )).toList(),
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
                color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.6),
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
                      mainAxisSize: collapsed ? MainAxisSize.min : MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
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
  });

  final String path;
  final String label;
  final IconData icon;
  final bool collapsed;

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
                    ? primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: InkWell(
                  onTap: () => context.go(path),
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
            color: isActive
                ? primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              onTap: () => context.go(path),
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
                            ? primary.withOpacity(0.15)
                            : theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
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
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
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

/// Bottom nav mobile — 4 liens : Tableau de bord, Produits, Vente, Plus..
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
    const bottomPaths = [AppRoutes.dashboard, AppRoutes.products, AppRoutes.sales];
    final mainItems = navItems.any((e) => e.path == AppRoutes.dashboard)
        ? navItems.where((e) => bottomPaths.contains(e.path)).toList()
        : navItems.take(3).toList();
    if (mainItems.isEmpty) return const SizedBox.shrink();

    int selectedIndex = mainItems.indexWhere((e) =>
        e.path == AppRoutes.dashboard ? loc == e.path : loc.startsWith(e.path));
    if (selectedIndex < 0) selectedIndex = 0;

    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    String labelFor(String path) {
      if (path == AppRoutes.sales) return 'Vente';
      if (path == AppRoutes.dashboard) return 'Tableau de bord';
      if (path == AppRoutes.products) return 'Produits';
      if (path == AppRoutes.customers) return 'Clients';
      if (path == AppRoutes.inventory) return 'Stock';
      if (path == AppRoutes.stockCashier) return 'Stock (alertes)';
      if (path == AppRoutes.purchases) return 'Achats';
      if (path == AppRoutes.suppliers) return 'Fournisseurs';
      return path;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd,
        0,
        isMobile ? AppTheme.spaceMdM : AppTheme.spaceMd,
        isMobile ? AppTheme.spaceLgM : AppTheme.spaceLg,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: isMobile ? 52 : 64,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(isMobile ? AppTheme.radiusXlM : AppTheme.radiusXl),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? AppTheme.radiusXlM : AppTheme.radiusXl),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: isMobile ? 4 : 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                        label: 'Plus..',
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: primary.withOpacity(0.12),
        highlightColor: primary.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withOpacity(0.18),
                      primary.withOpacity(0.08),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: SizedBox(
            height: isMobile ? 40 : Breakpoints.minTouchTarget,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    icon,
                    size: isMobile ? 22 : 26,
                    color: isSelected
                        ? primary
                        : theme.colorScheme.onSurfaceVariant.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: isMobile ? 1 : 2),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: isMobile ? 11 : 12,
                    height: 1.2,
                    letterSpacing: 0.1,
                    color: isSelected
                        ? primary
                        : theme.colorScheme.onSurfaceVariant.withOpacity(0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

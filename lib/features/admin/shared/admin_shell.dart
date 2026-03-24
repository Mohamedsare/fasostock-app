import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/config/routes.dart';
import '../../../providers/auth_provider.dart';

/// Palette admin — sidebar sombre, accent orange.
class _AdminPalette {
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarActive = Color(0xFFEA580C);
  static const Color sidebarActiveBg = Color(0x14EA580C);
  static const Color sidebarText = Color(0xFFF1F5F9);
  static const Color sidebarTextMuted = Color(0xFF94A3B8);
  static const Color appBarBg = Color(0xFFFAFBFC);
  static const Color appBarBorder = Color(0xFFE2E8F0);
}

const double _adminSidebarWidth = 260;
const double _adminSidebarCollapsedWidth = 72;

const _adminNavItems = [
  (path: AppRoutes.admin, label: 'Tableau', icon: Icons.dashboard_rounded),
  (path: AppRoutes.adminCompanies, label: 'Entreprises', icon: Icons.business_rounded),
  (path: AppRoutes.adminStores, label: 'Boutiques', icon: Icons.store_rounded),
  (path: AppRoutes.adminUsers, label: 'Utilisateurs', icon: Icons.people_rounded),
  (path: AppRoutes.adminAudit, label: 'Journal d\'audit', icon: Icons.history_rounded),
  (path: AppRoutes.adminAppErrors, label: 'Erreurs App', icon: Icons.bug_report_rounded),
  (path: AppRoutes.adminMessages, label: 'Messages', icon: Icons.message_rounded),
  (path: AppRoutes.adminAi, label: 'IA', icon: Icons.auto_awesome_rounded),
  (path: AppRoutes.adminRapports, label: 'Rapports', icon: Icons.bar_chart_rounded),
  (path: AppRoutes.adminSettings, label: 'Paramètres', icon: Icons.settings_rounded),
];

/// Layout admin plateforme — sidebar (desktop) / drawer + app bar (mobile).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final path = GoRouterState.of(context).uri.path;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final collapsed = _collapsed;

    return Scaffold(
      backgroundColor: _AdminPalette.appBarBg,
      drawer: isWide ? null : _AdminDrawer(
        path: path,
        onSignOut: () async {
          await auth.signOut();
          if (!mounted || !context.mounted) return;
          try {
            context.go(AppRoutes.login);
          } catch (_) {}
        },
      ),
      appBar: isWide ? null : _AdminMobileAppBar(),
      body: Row(
        children: [
          if (isWide)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              width: collapsed ? _adminSidebarCollapsedWidth : _adminSidebarWidth,
              child: _AdminSidebar(
                collapsed: collapsed,
                path: path,
                onToggle: () => setState(() => _collapsed = !_collapsed),
                onSignOut: () async {
                  await auth.signOut();
                  if (!mounted || !context.mounted) return;
                  try {
                    context.go(AppRoutes.login);
                  } catch (_) {}
                },
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (isWide) _AdminAppBar(collapsed: collapsed, onMenuTap: () => setState(() => _collapsed = !_collapsed)),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Drawer mobile — même style que la sidebar (dark, premium).
class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.path, required this.onSignOut});

  final String path;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _AdminPalette.sidebarBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              _AdminDrawerHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  children: [
                    ..._adminNavItems.map((e) {
                      final active = e.path == AppRoutes.admin
                          ? path == e.path || path == '${e.path}/'
                          : path.startsWith(e.path);
                      return _NavItem(
                        path: e.path,
                        label: e.label,
                        icon: e.icon,
                        collapsed: false,
                        active: active,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go(e.path);
                        },
                      );
                    }),
                  ],
                ),
              ),
              Divider(height: 1, color: _AdminPalette.sidebarTextMuted.withOpacity(0.2)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: _NavItem(
                  path: '',
                  label: 'Déconnexion',
                  icon: Icons.logout_rounded,
                  collapsed: false,
                  active: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSignOut();
                  },
                  isSignOut: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _AdminPalette.sidebarActive.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _AdminPalette.sidebarActive.withOpacity(0.4), width: 1),
            ),
            child: const Icon(Icons.shield_rounded, color: _AdminPalette.sidebarActive, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Plateforme',
                  style: TextStyle(
                    color: _AdminPalette.sidebarText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Super Admin',
                  style: TextStyle(
                    color: _AdminPalette.sidebarTextMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// App bar mobile — titre + menu (ouvre le drawer).
class _AdminMobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _AdminPalette.appBarBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, size: 26),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          tooltip: 'Menu',
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _AdminPalette.sidebarActive.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_rounded, color: _AdminPalette.sidebarActive, size: 20),
          ),
          Flexible(
            child: Text(
              'Administration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: const Color(0xFF1E293B),
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      titleSpacing: 0,
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.collapsed,
    required this.path,
    required this.onToggle,
    required this.onSignOut,
  });

  final bool collapsed;
  final String path;
  final VoidCallback onToggle;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _AdminPalette.sidebarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _AdminSidebarHeader(collapsed: collapsed, onToggle: onToggle),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14, vertical: 8),
                children: [
                  ..._adminNavItems.map((e) {
                    final active = e.path == AppRoutes.admin
                        ? path == e.path || path == '${e.path}/'
                        : path.startsWith(e.path);
                    return _NavItem(
                      path: e.path,
                      label: e.label,
                      icon: e.icon,
                      collapsed: collapsed,
                      active: active,
                      onTap: () => context.go(e.path),
                    );
                  }),
                ],
              ),
            ),
            Divider(height: 1, color: _AdminPalette.sidebarTextMuted.withOpacity(0.2)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 10 : 14, vertical: 8),
              child: _NavItem(
                path: '',
                label: 'Déconnexion',
                icon: Icons.logout_rounded,
                collapsed: collapsed,
                active: false,
                onTap: onSignOut,
                isSignOut: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSidebarHeader extends StatelessWidget {
  const _AdminSidebarHeader({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 18, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _AdminPalette.sidebarActive.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _AdminPalette.sidebarActive.withOpacity(0.4), width: 1),
                ),
                child: const Icon(Icons.shield_rounded, color: _AdminPalette.sidebarActive, size: 24),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Plateforme',
                        style: TextStyle(
                          color: _AdminPalette.sidebarText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Super Admin',
                        style: TextStyle(
                          color: _AdminPalette.sidebarTextMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  color: _AdminPalette.sidebarTextMuted,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.collapsed,
    required this.active,
    required this.onTap,
    this.isSignOut = false,
  });

  final String path;
  final String label;
  final IconData icon;
  final bool collapsed;
  final bool active;
  final VoidCallback onTap;
  final bool isSignOut;

  @override
  Widget build(BuildContext context) {
    final color = isSignOut
        ? _AdminPalette.sidebarTextMuted
        : (active ? _AdminPalette.sidebarActive : _AdminPalette.sidebarText);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? _AdminPalette.sidebarActiveBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 14 : 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                if (!collapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AdminAppBar({required this.collapsed, required this.onMenuTap});

  final bool collapsed;
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _AdminPalette.appBarBg,
        border: Border(bottom: BorderSide(color: _AdminPalette.appBarBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                collapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
              tooltip: collapsed ? 'Ouvrir le menu' : 'Réduire le menu',
              onPressed: onMenuTap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Administration',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: const Color(0xFF1E293B),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

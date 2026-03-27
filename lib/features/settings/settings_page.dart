import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/breakpoints.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/store.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/subscription_repository.dart';
import '../../../providers/offline_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../core/config/routes.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/theme_mode_provider.dart';
import '../../../providers/pos_cart_settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Page Paramètres — profil, compte, entreprise/boutique, déconnexion (aligné web SettingsPage).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final SettingsRepository _repo = SettingsRepository();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _clearingSales = false;
  bool _clearingPurchases = false;
  bool _clearingTransfers = false;
  bool _clearingProducts = false;
  bool _clearingStock = false;
  bool _clearingStockMovements = false;
  bool _clearingWarehouseStock = false;
  bool _clearingWarehouseMovements = false;
  String? _dangerScopeStoreId;
  String? _profileError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncProfile();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _syncProfile() {
    final profile = context.read<AuthProvider>().profile;
    if (profile != null && _fullNameController.text != (profile.fullName ?? '')) {
      _fullNameController.text = profile.fullName ?? '';
    }
  }

  Future<void> _saveProfile() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });
    try {
      await _repo.updateProfile(user.id, fullName: _fullNameController.text.trim().isEmpty ? null : _fullNameController.text.trim());
      if (!mounted) return;
      await authProvider.refreshProfile(signOutIfProfileStillMissing: false);
      if (!mounted) return;
      setState(() => _savingProfile = false);
      AppToast.success(context, 'Profil mis à jour');
    } catch (e, st) {
      AppErrorHandler.log('Settings.saveProfile: $e', st);
      if (mounted) {
        setState(() {
          _savingProfile = false;
          _profileError = AppErrorHandler.toUserMessage(e);
        });
      }
    }
  }

  Future<void> _changePassword() async {
    final newPwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPwd.length < 6) {
      setState(() => _passwordError = 'Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    if (newPwd != confirm) {
      setState(() => _passwordError = 'Les mots de passe ne correspondent pas');
      return;
    }
    setState(() {
      _changingPassword = true;
      _passwordError = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPwd));
      if (mounted) {
        setState(() {
          _changingPassword = false;
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        AppToast.success(context, 'Mot de passe mis à jour');
      }
    } catch (e, st) {
      AppErrorHandler.log('Settings.changePassword: $e', st);
      if (mounted) {
        setState(() {
          _changingPassword = false;
          _passwordError = AppErrorHandler.toUserMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final auth = context.watch<AuthProvider>();
    final company = context.watch<CompanyProvider>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    if (!permissions.hasLoaded || auth.loading) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Paramètres')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (permissions.isCashier) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || !context.mounted) return;
        try {
          context.go(AppRoutes.sales);
        } catch (_) {}
      });
      return const SizedBox.shrink();
    }
    if (company.currentCompanyId != null && !permissions.hasPermission(Permissions.settingsManage)) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Paramètres')),
        body: Center(child: _buildNoAccessCard(context)),
      );
    }

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Paramètres')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 32 : 20,
          vertical: isWide ? 28 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, isWide),
            const SizedBox(height: 24),
            _buildAppearanceCard(context),
            const SizedBox(height: 20),
            _buildPosCartCard(context),
            const SizedBox(height: 20),
            _buildProfileCard(context, auth),
            const SizedBox(height: 20),
            _buildAccountCard(context, auth),
            const SizedBox(height: 20),
            if (company.currentCompany != null) ...[
              _buildCompanyCard(context, company),
              const SizedBox(height: 20),
            ],
            if (company.currentCompanyId != null) ...[
              _buildSubscriptionCard(context, company.currentCompanyId!),
              const SizedBox(height: 20),
            ],
            if (permissions.isOwner && company.currentCompanyId != null) ...[
              _buildIntegrationsCard(context),
              const SizedBox(height: 20),
            ],
            if (permissions.isOwner) ...[
              _buildTwoFactorCard(context),
              const SizedBox(height: 20),
            ],
            if (permissions.isOwner && company.currentCompanyId != null) ...[
              _buildDangerHistoryCard(
                company.currentCompanyId!,
                company.stores,
              ),
              const SizedBox(height: 20),
            ],
            _buildSignOutCard(context, auth),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccessCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Vous n\'avez pas accès à cette section.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    final theme = Theme.of(context);
    final themeModeProvider = context.watch<ThemeModeProvider>();
    final current = themeModeProvider.themeMode;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Apparence',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Choisir le thème de l\'application',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final isMobile = Breakpoints.isMobile(MediaQuery.sizeOf(context).width);
                return SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_rounded, size: 20),
                      label: isMobile ? const SizedBox.shrink() : const Text('Système'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_rounded, size: 20),
                      label: isMobile ? const SizedBox.shrink() : const Text('Clair'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_rounded, size: 20),
                      label: isMobile ? const SizedBox.shrink() : const Text('Sombre'),
                    ),
                  ],
                  selected: {current},
                  onSelectionChanged: (Set<ThemeMode> selected) {
                    final mode = selected.first;
                    themeModeProvider.setThemeMode(mode);
                  },
                  showSelectedIcon: false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosCartCard(BuildContext context) {
    final theme = Theme.of(context);
    final posCart = context.watch<PosCartSettingsProvider>();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Caisse (POS)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Un seul mode à la fois (indépendant de l\'entreprise ou de la boutique). Le panier se met à jour automatiquement à la saisie.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Toujours un mode actif : si vous désactivez le mode courant, l’autre est activé automatiquement.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Champ de saisie pour la quantité'),
              subtitle: const Text('Saisir le nombre : le total se met à jour automatiquement'),
              value: posCart.showQuantityInput,
              onChanged: (v) => posCart.setShowQuantityInput(v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Boutons (-) et (+)'),
              subtitle: const Text('Incrémenter ou décrémenter la quantité'),
              value: posCart.showQuantityButtons,
              onChanged: (v) => posCart.setShowQuantityButtons(v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isWide) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paramètres',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Profil, compte et entreprise',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paramètres',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Profil, compte et entreprise',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildProfileCard(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    if (auth.user == null) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.person_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Profil',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_profileError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 20, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _profileError!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Nom affiché',
                hintText: 'Votre nom',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() => _profileError = null),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _savingProfile ? null : _saveProfile,
              child: _savingProfile
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    if (auth.user == null) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.mail_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Compte',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Email',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                auth.user?.email ?? '—',
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Changer le mot de passe',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_passwordError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 20, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _passwordError!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                hintText: '••••••••',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() => _passwordError = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                hintText: '••••••••',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (_) => setState(() => _passwordError = null),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _changingPassword ? null : _changePassword,
              child: _changingPassword
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Mettre à jour le mot de passe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(BuildContext context, CompanyProvider company) {
    final theme = Theme.of(context);
    final companies = company.companies;
    final stores = company.stores;
    final currentCompany = company.currentCompany;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.business_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Entreprise',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (companies.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: company.currentCompanyId,
                decoration: InputDecoration(
                  labelText: 'Entreprise',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                isExpanded: true,
                items: companies.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) company.setCurrentCompanyId(id);
                },
              ),
              const SizedBox(height: 16),
            ] else if (currentCompany != null) ...[
              Text(
                'Entreprise',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentCompany.name,
                style: theme.textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
            ],
            if (stores.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: company.currentStoreId,
                decoration: InputDecoration(
                  labelText: 'Boutique',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— Toutes —')),
                  ...stores.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (id) => company.setCurrentStoreId(id),
              ),
            ] else if (currentCompany != null) ...[
              Text(
                'Aucune boutique configurée',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildIntegrationsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      child: ListTile(
        leading: Icon(Icons.key_rounded, size: 22, color: theme.colorScheme.primary),
        title: const Text('Intégrations API & Webhooks'),
        subtitle: const Text('Clés API et URLs de webhook pour vos intégrations'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go(AppRoutes.integrations),
      ),
    );
  }

  Widget _buildTwoFactorCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.security_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Authentification à deux facteurs (2FA)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Renforcez la sécurité de votre compte avec un code à usage unique (application type Google Authenticator).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('2FA'),
                    content: const Text(
                      'L\'activation de la double authentification sera disponible prochainement. En attendant, utilisez un mot de passe fort.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.lock_rounded, size: 20),
              label: const Text('Activer la 2FA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, String companyId) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.card_membership_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Abonnement',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<SubscriptionInfo?>(
              future: SubscriptionRepository().getByCompany(companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }
                final sub = snapshot.data;
                final planName = sub?.planName ?? 'Gratuit';
                final status = sub?.status ?? 'active';
                final statusLabel = status == 'active' ? 'Actif' : status == 'past_due' ? 'Paiement en attente' : status == 'canceled' ? 'Résilié' : status;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan : $planName', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text('Statut : $statusLabel', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (sub?.currentPeriodEnd != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Renouvellement : ${_formatDate(sub!.currentPeriodEnd!)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerHistoryCard(
    String companyId,
    List<Store> stores,
  ) {
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    final scopeLabel = _dangerScopeStoreId == null
        ? 'Toute l\'entreprise'
        : 'Boutique sélectionnée';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: danger.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, size: 22, color: danger),
                const SizedBox(width: 10),
                Text(
                  'Vider historiques entreprise',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Zone danger: action irréversible. Vous pouvez supprimer les historiques pour toute l\'entreprise ou seulement une boutique.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _dangerScopeStoreId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Périmètre de suppression',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Toute l\'entreprise'),
                ),
                ...stores.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text('Boutique: ${s.name}'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _dangerScopeStoreId = v),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: danger.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warehouse_rounded, size: 18, color: danger),
                      const SizedBox(width: 8),
                      Text(
                        'Magasin (dépôt)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Suppression dédiée au dépôt central de l'entreprise (stock + mouvements du magasin).",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_dangerScopeStoreId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Astuce: repassez le périmètre sur « Toute l’entreprise » pour activer ces actions dépôt.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: (_clearingWarehouseStock || _dangerScopeStoreId != null)
                            ? null
                            : () => _confirmAndRunDangerAction(
                                  title: 'Vider le stock du magasin ?',
                                  body:
                                      'Le stock du dépôt central sera remis à zéro. Les stocks boutiques ne sont pas concernés.',
                                  actionLabel: 'Vider stock magasin',
                                  run: () async {
                                    setState(() => _clearingWarehouseStock = true);
                                    try {
                                      final deleted =
                                          await _repo.clearWarehouseStock(companyId);
                                      await ref
                                          .read(appDatabaseProvider)
                                          .clearLocalWarehouseStock(companyId);
                                      await _refreshAfterDangerAction();
                                      if (!mounted) return;
                                      AppToast.success(
                                        context,
                                        'Stock magasin vidé ($deleted ligne(s) supprimée(s)).',
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _clearingWarehouseStock = false);
                                      }
                                    }
                                  },
                                ),
                        icon: _clearingWarehouseStock
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.warehouse_rounded, size: 18),
                        label: const Text('Vider stock magasin'),
                        style: OutlinedButton.styleFrom(foregroundColor: danger),
                      ),
                      OutlinedButton.icon(
                        onPressed: (_clearingWarehouseMovements || _dangerScopeStoreId != null)
                            ? null
                            : () => _confirmAndRunDangerAction(
                                  title: 'Vider l\'historique magasin ?',
                                  body:
                                      'Tous les mouvements du dépôt central seront supprimés définitivement. Les mouvements boutiques ne sont pas concernés.',
                                  actionLabel: 'Vider mouvements magasin',
                                  run: () async {
                                    setState(
                                      () => _clearingWarehouseMovements = true,
                                    );
                                    try {
                                      final deleted = await _repo
                                          .clearWarehouseMovementsHistory(
                                        companyId,
                                      );
                                      await ref
                                          .read(appDatabaseProvider)
                                          .clearLocalWarehouseMovementsHistory(
                                            companyId,
                                          );
                                      await _refreshAfterDangerAction();
                                      if (!mounted) return;
                                      AppToast.success(
                                        context,
                                        'Historique magasin vidé ($deleted mouvement(s) supprimé(s)).',
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(
                                          () => _clearingWarehouseMovements = false,
                                        );
                                      }
                                    }
                                  },
                                ),
                        icon: _clearingWarehouseMovements
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.history_toggle_off_rounded, size: 18),
                        label: const Text('Vider mouvements magasin'),
                        style: OutlinedButton.styleFrom(foregroundColor: danger),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _clearingProducts
                      ? null
                      : () => _confirmAndRunDangerAction(
                            title: 'Vider le catalogue produits ?',
                            body:
                                'Tous les produits de l\'entreprise seront supprimés définitivement. Action globale entreprise.',
                            actionLabel: 'Vider produits',
                            run: () async {
                              if (_dangerScopeStoreId != null) {
                                throw Exception(
                                  'Les produits sont partagés au niveau entreprise. Sélectionnez "Toute l\'entreprise".',
                                );
                              }
                              setState(() => _clearingProducts = true);
                              try {
                                final deleted =
                                    await _repo.clearProductsCatalog(companyId);
                                await ref
                                    .read(appDatabaseProvider)
                                    .clearLocalProductsCatalog(companyId);
                                await _refreshAfterDangerAction();
                                if (!mounted) return;
                                AppToast.success(
                                  context,
                                  'Catalogue vidé ($deleted produit(s) supprimé(s)).',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _clearingProducts = false);
                                }
                              }
                            },
                          ),
                  icon: _clearingProducts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_rounded, size: 18),
                  label: const Text('Vider produits'),
                  style: OutlinedButton.styleFrom(foregroundColor: danger),
                ),
                OutlinedButton.icon(
                  onPressed: _clearingSales
                      ? null
                      : () => _confirmAndRunDangerAction(
                            title: 'Vider l\'historique des ventes ?',
                            body:
                                'Toutes les ventes (et leurs lignes/paiements/retours) de cette entreprise seront supprimées définitivement.',
                            actionLabel: 'Vider ventes',
                            run: () async {
                              setState(() => _clearingSales = true);
                              try {
                                final deleted = await _repo.clearSalesHistory(
                                  companyId,
                                  storeId: _dangerScopeStoreId,
                                );
                                await ref
                                    .read(appDatabaseProvider)
                                    .clearLocalSalesHistory(
                                      companyId,
                                      storeId: _dangerScopeStoreId,
                                    );
                                await _refreshAfterDangerAction();
                                if (!mounted) return;
                                AppToast.success(
                                  context,
                                  'Historique ventes vidé ($deleted vente(s) supprimée(s)) - $scopeLabel.',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _clearingSales = false);
                                }
                              }
                            },
                          ),
                  icon: _clearingSales
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.point_of_sale_rounded, size: 18),
                  label: const Text('Vider ventes'),
                  style: OutlinedButton.styleFrom(foregroundColor: danger),
                ),
                OutlinedButton.icon(
                  onPressed: _clearingPurchases
                      ? null
                      : () => _confirmAndRunDangerAction(
                            title: 'Vider l\'historique des achats ?',
                            body:
                                'Tous les achats (et leurs lignes) de cette entreprise seront supprimés définitivement.',
                            actionLabel: 'Vider achats',
                            run: () async {
                              setState(() => _clearingPurchases = true);
                              try {
                                final deleted = await _repo.clearPurchasesHistory(
                                  companyId,
                                  storeId: _dangerScopeStoreId,
                                );
                                await ref
                                    .read(appDatabaseProvider)
                                    .clearLocalPurchasesHistory(
                                      companyId,
                                      storeId: _dangerScopeStoreId,
                                    );
                                await _refreshAfterDangerAction();
                                if (!mounted) return;
                                AppToast.success(
                                  context,
                                  'Historique achats vidé ($deleted achat(s) supprimé(s)) - $scopeLabel.',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _clearingPurchases = false);
                                }
                              }
                            },
                          ),
                  icon: _clearingPurchases
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shopping_bag_rounded, size: 18),
                  label: const Text('Vider achats'),
                  style: OutlinedButton.styleFrom(foregroundColor: danger),
                ),
                OutlinedButton.icon(
                  onPressed: _clearingTransfers
                      ? null
                      : () => _confirmAndRunDangerAction(
                            title: 'Vider l\'historique des transferts ?',
                            body:
                                'Tous les transferts (et leurs lignes) de cette entreprise seront supprimés définitivement.',
                            actionLabel: 'Vider transferts',
                            run: () async {
                              setState(() => _clearingTransfers = true);
                              try {
                                final deleted = await _repo.clearTransfersHistory(
                                  companyId,
                                  storeId: _dangerScopeStoreId,
                                );
                                await ref
                                    .read(appDatabaseProvider)
                                    .clearLocalTransfersHistory(
                                      companyId,
                                      storeId: _dangerScopeStoreId,
                                    );
                                await _refreshAfterDangerAction();
                                if (!mounted) return;
                                AppToast.success(
                                  context,
                                  'Historique transferts vidé ($deleted transfert(s) supprimé(s)) - $scopeLabel.',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _clearingTransfers = false);
                                }
                              }
                            },
                          ),
                  icon: _clearingTransfers
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Vider transferts'),
                  style: OutlinedButton.styleFrom(foregroundColor: danger),
                ),
                OutlinedButton.icon(
                  onPressed: _clearingStock
                      ? null
                      : () => _confirmAndRunDangerAction(
                            title: 'Vider le stock ?',
                            body:
                                'Le stock sera remis à zéro pour le périmètre sélectionné.',
                            actionLabel: 'Vider stock',
                            run: () async {
                              setState(() => _clearingStock = true);
                              try {
                                final deleted = await _repo.clearStock(
                                  companyId,
                                  storeId: _dangerScopeStoreId,
                                );
                                await ref
                                    .read(appDatabaseProvider)
                                    .clearLocalStock(
                                      companyId,
                                      storeId: _dangerScopeStoreId,
                                    );
                                await _refreshAfterDangerAction();
                                if (!mounted) return;
                                AppToast.success(
                                  context,
                                  'Stock vidé ($deleted ligne(s) supprimée(s)) - $scopeLabel.',
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _clearingStock = false);
                                }
                              }
                            },
                          ),
                  icon: _clearingStock
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.layers_clear_rounded, size: 18),
                  label: const Text('Vider stock'),
                  style: OutlinedButton.styleFrom(foregroundColor: danger),
                ),
                OutlinedButton.icon(
                  onPressed: _clearingStockMovements
                      ? null
                      : () => _confirmAndRunDangerAction(
                            title: 'Vider l\'historique des mouvements ?',
                            body:
                                'Tous les mouvements de stock du périmètre sélectionné seront supprimés définitivement.',
                            actionLabel: 'Vider mouvements',
                            run: () async {
                              setState(() => _clearingStockMovements = true);
                              try {
                                final deleted =
                                    await _repo.clearStockMovementsHistory(
                                  companyId,
                                  storeId: _dangerScopeStoreId,
                                );
                                await ref
                                    .read(appDatabaseProvider)
                                    .clearLocalStockMovementsHistory(
                                      companyId,
                                      storeId: _dangerScopeStoreId,
                                    );
                                await _refreshAfterDangerAction();
                                if (!mounted) return;
                                AppToast.success(
                                  context,
                                  'Historique mouvements vidé ($deleted mouvement(s) supprimé(s)) - $scopeLabel.',
                                );
                              } finally {
                                if (mounted) {
                                  setState(
                                    () => _clearingStockMovements = false,
                                  );
                                }
                              }
                            },
                          ),
                  icon: _clearingStockMovements
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history_toggle_off_rounded, size: 18),
                  label: const Text('Vider mouvements'),
                  style: OutlinedButton.styleFrom(foregroundColor: danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRunDangerAction({
    required String title,
    required String body,
    required String actionLabel,
    required Future<void> Function() run,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: Colors.red),
        title: Text(title),
        content: Text('$body\n\nConfirmez pour continuer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Oui, supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await run();
    } catch (e) {
      if (mounted) {
        AppErrorHandler.show(context, e, fallback: '$actionLabel impossible.');
      }
    }
  }

  Future<void> _refreshAfterDangerAction() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null) {
      try {
        await ref.read(syncServiceV2Provider).sync(
              userId: userId,
              companyId: company.currentCompanyId,
              storeId: company.currentStoreId,
            );
      } catch (e, st) {
        // No blocking error for UI refresh, but keep technical trace.
        AppErrorHandler.log('Settings.refreshAfterDangerAction.sync: $e', st);
      }
    }
    ref.invalidate(salesStreamProvider);
    ref.invalidate(purchasesStreamProvider);
    ref.invalidate(transfersStreamProvider);
    ref.invalidate(productsStreamProvider);
    ref.invalidate(inventoryQuantitiesStreamProvider);
    ref.invalidate(stockMovementsStreamProvider);
    ref.invalidate(warehouseInventoryStreamProvider);
    ref.invalidate(warehouseMovementsStreamProvider);
    ref.invalidate(warehouseDispatchInvoicesStreamProvider);
  }

  Widget _buildSignOutCard(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Déconnexion',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Se déconnecter de FasoStock',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  // Navigation is handled by router redirect when user becomes null
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Se déconnecter'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

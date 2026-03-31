import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../../../core/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/constants/role_labels.dart';
import '../../../providers/permissions_provider.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/utils/app_toast.dart';
import '../../../data/models/company_member.dart';
import '../../../data/repositories/users_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/offline_providers.dart';
import 'widgets/create_user_dialog.dart';

/// Page Utilisateurs — liste des membres depuis Drift (offline+sync), activer/désactiver, retirer.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final UsersRepository _repo = UsersRepository();

  List<String> _permissionKeys = [];
  bool _permissionKeysLoading = true;
  String? _error;

  String? _rightsSelectedUserId;
  List<String> _rightsPermissionKeys = [];
  bool _rightsLoading = false;
  String? _rightsError;
  final Set<String> _rightsUpdatingKeys = {};

  String? get _currentUserId => context.read<AuthProvider>().user?.id;
  bool _hasUsersManage(List<String> keys) => keys.contains(Permissions.usersManage);
  bool _isOwner(List<CompanyMember> members) => members.any((m) => m.userId == _currentUserId && m.role.slug == 'owner');
  bool _canManageUsers(List<CompanyMember> members, List<String> keys) => _hasUsersManage(keys) || _isOwner(members);

  List<CompanyMember> _rightsSelectableMembers(List<CompanyMember> members) {
    final callerOwner = _isOwner(members);
    return members.where((m) {
      if (m.userId == _currentUserId || !m.isActive) return false;
      if (!callerOwner && m.role.slug == 'owner') return false;
      return true;
    }).toList();
  }

  String? _lastCompanyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCompaniesIfNeeded();
      _loadPermissionKeys();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId != _lastCompanyId) {
      _lastCompanyId = companyId;
      _rightsSelectedUserId = null;
      _rightsError = null;
      _rightsPermissionKeys = [];
      if (companyId != null) _loadPermissionKeys();
    }
  }

  void _loadCompaniesIfNeeded() {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    if (userId != null && company.companies.isEmpty && !company.loading) {
      company.loadCompanies(userId);
    }
  }

  Future<void> _loadPermissionKeys() async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null) {
      setState(() => _permissionKeysLoading = false);
      return;
    }
    try {
      final keys = await _repo.getMyPermissionKeys(companyId);
      if (mounted) {
        setState(() {
        _permissionKeys = keys;
        _permissionKeysLoading = false;
      });
      }
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) {
        setState(() {
        _error = AppErrorHandler.toUserMessage(e);
        _permissionKeysLoading = false;
      });
      }
    }
  }

  Future<void> _refreshSync() async {
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final uid = auth.user?.id;
    final companyId = company.currentCompanyId;
    if (uid != null) {
      try {
        await ref.read(syncServiceV2Provider).sync(
          userId: uid,
          companyId: companyId,
          storeId: company.currentStoreId,
        );
      } catch (_) {}
    }
    if (!mounted) return;
    final cid = company.currentCompanyId;
    if (cid != null) ref.invalidate(companyMembersStreamProvider(cid));
  }

  Future<void> _toggleActive(CompanyMember m, String companyId) async {
    try {
      await _repo.setCompanyMemberActive(m.id, !m.isActive);
      if (!mounted) return;
      await ref.read(companyMembersOfflineRepositoryProvider).updateMemberIsActive(m.id, !m.isActive);
      if (!mounted) return;
      ref.invalidate(companyMembersStreamProvider(companyId));
      AppToast.success(context, m.isActive ? 'Utilisateur désactivé' : 'Utilisateur activé');
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _loadRightsForUser(String? userId) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId == null || userId == null) {
      setState(() {
        _rightsSelectedUserId = userId;
        _rightsPermissionKeys = [];
        _rightsLoading = false;
        _rightsError = null;
      });
      return;
    }
    setState(() {
      _rightsSelectedUserId = userId;
      _rightsLoading = true;
      _rightsError = null;
    });
    try {
      final keys = await _repo.getUserPermissionKeys(companyId, userId);
      if (mounted && _rightsSelectedUserId == userId) {
        setState(() {
          _rightsPermissionKeys = keys;
          _rightsLoading = false;
        });
      }
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted && _rightsSelectedUserId == userId) {
        setState(() {
          _rightsError = AppErrorHandler.toUserMessage(e);
          _rightsPermissionKeys = [];
          _rightsLoading = false;
        });
      }
    }
  }

  Future<void> _toggleUserPermission(String permissionKey, bool granted) async {
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    final userId = _rightsSelectedUserId;
    if (companyId == null || userId == null) return;
    setState(() => _rightsUpdatingKeys.add(permissionKey));
    try {
      await _repo.setUserPermissionOverride(companyId, userId, permissionKey, granted);
      if (!mounted || _rightsSelectedUserId != userId) return;
      setState(() {
        _rightsUpdatingKeys.remove(permissionKey);
        if (granted) {
          if (!_rightsPermissionKeys.contains(permissionKey)) {
            _rightsPermissionKeys = [..._rightsPermissionKeys, permissionKey]..sort();
          }
        } else {
          _rightsPermissionKeys = _rightsPermissionKeys.where((k) => k != permissionKey).toList();
        }
      });
      if (mounted) {
        AppToast.success(context, granted ? 'Droit accordé' : 'Droit retiré');
      }
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) {
        setState(() => _rightsUpdatingKeys.remove(permissionKey));
        AppErrorHandler.show(context, e);
      }
    }
  }

  Future<void> _removeMember(CompanyMember m, String companyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer l\'utilisateur'),
        content: Text(
          'Retirer ${m.profile?.fullName?.trim().isEmpty == false ? m.profile!.fullName!.trim() : 'cet utilisateur'} de l\'entreprise ? Il perdra l\'accès à l\'entreprise et à ses boutiques.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.removeCompanyMember(m.id);
      if (!mounted) return;
      await ref.read(companyMembersOfflineRepositoryProvider).deleteMember(m.id);
      if (!mounted) return;
      ref.invalidate(companyMembersStreamProvider(companyId));
      AppToast.success(context, 'Utilisateur retiré de l\'entreprise');
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _applyMemberCreated(String companyId) async {
    try {
      final list = await _repo.listCompanyMembers(companyId);
      await ref.read(companyMembersOfflineRepositoryProvider).replaceMembers(companyId, list);
      ref.invalidate(companyMembersStreamProvider(companyId));
      _loadPermissionKeys();
    } catch (e, st) {
      AppErrorHandler.log(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<PermissionsProvider>();
    final canAccessUsers = permissions.hasPermission(Permissions.usersManage) || permissions.isOwner;
    if (permissions.hasLoaded && !canAccessUsers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Utilisateurs')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text("Vous n'avez pas accès à cette page.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }
    final company = context.watch<CompanyProvider>();
    final companyId = company.currentCompanyId;
    final w = MediaQuery.sizeOf(context).width;
    final isWide = Breakpoints.isDesktop(w);
    final isMobile = Breakpoints.isMobile(w);

    if (company.loading && company.companies.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company.loadError != null && company.companies.isEmpty) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Utilisateurs')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(company.loadError!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
      );
    }
    if (companyId == null) {
      return Scaffold(
        appBar: isWide ? null : AppBar(title: const Text('Utilisateurs')),
        body: const Center(child: Text('Aucune entreprise. Contactez l\'administrateur.')),
      );
    }

    final asyncMembers = ref.watch(companyMembersStreamProvider(companyId));
    final members = asyncMembers.valueOrNull ?? [];
    final membersLoading = asyncMembers.isLoading;
    final membersError = asyncMembers.hasError && asyncMembers.error != null
        ? AppErrorHandler.toUserMessage(asyncMembers.error, fallback: 'Impossible de charger les utilisateurs.')
        : null;
    final loading = membersLoading || _permissionKeysLoading;
    final error = _error ?? membersError;
    final canManage = _canManageUsers(members, _permissionKeys);

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Utilisateurs')),
      body: RefreshIndicator(
        onRefresh: _refreshSync,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : (isMobile ? AppTheme.spaceXlM : 20),
            vertical: isWide ? 28 : (isMobile ? AppTheme.spaceXlM : 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isWide),
              const SizedBox(height: 24),
              if (error != null) ...[
                _buildErrorCard(context, error),
                const SizedBox(height: 24),
              ],
              if (!canManage) ...[
                _buildNoAccessCard(context),
              ] else if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _buildMembersCard(context, isWide, members, companyId),
                if (_canManageUsers(members, _permissionKeys)) ...[
                  const SizedBox(height: 24),
                  _buildRightsSection(context, isWide, members),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isWide) {
    final theme = Theme.of(context);
    final narrow = Breakpoints.isNarrow(MediaQuery.sizeOf(context).width);
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Utilisateurs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gérer les accès et les droits des utilisateurs de l\'entreprise',
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
                      'Utilisateurs',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gérer les accès et les droits des utilisateurs de l\'entreprise',
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

  Widget _buildErrorCard(BuildContext context, String errorMessage) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () async { await _refreshSync(); _loadPermissionKeys(); },
                child: const Text('Réessayer'),
              ),
            ),
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

  Widget _buildRightsSection(BuildContext context, bool isWide, List<CompanyMember> members) {
    final theme = Theme.of(context);
    final selectable = _rightsSelectableMembers(members);
    // Garder la valeur du dropdown dans la liste pour éviter l'assertion Flutter ; réinitialiser si l'utilisateur n'est plus sélectionnable.
    final selectedUserIdInList = _rightsSelectedUserId != null &&
        selectable.any((m) => m.userId == _rightsSelectedUserId)
        ? _rightsSelectedUserId
        : null;
    if (_rightsSelectedUserId != null && selectedUserIdInList == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _rightsSelectedUserId = null;
            _rightsPermissionKeys = [];
            _rightsError = null;
          });
        }
      });
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Gestion des droits',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sélectionnez un utilisateur pour affiner ses droits (magasin, stock, produits, achats, etc.). Les droits affichés sont effectifs (rôle Magasinier ou autre + surcharges). Décocher retire une permission même si le rôle la donne par défaut ; cocher l’ajoute si le rôle ne la prévoit pas. Seul le propriétaire peut modifier un autre propriétaire.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedUserIdInList,
                  decoration: InputDecoration(
                    labelText: 'Utilisateur',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— Choisir un utilisateur —')),
                    ...selectable.map((m) {
                      final name = m.profile?.fullName?.trim().isEmpty == false
                          ? m.profile!.fullName!.trim()
                          : 'Sans nom';
                      return DropdownMenuItem(
                        value: m.userId,
                        child: Text('$name (${RoleLabels.labelFr(m.role.slug, m.role.name)})', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (v) => _loadRightsForUser(v),
                ),
                if (selectedUserIdInList != null) ...[
                  const SizedBox(height: 20),
                  if (_rightsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_rightsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _rightsError!,
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _rightsError = null);
                              _loadRightsForUser(_rightsSelectedUserId);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      'Droits effectifs (cochez pour ajouter, décochez pour retirer)',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ...Permissions.all.map((key) {
                      final label = Permissions.labels[key] ?? key;
                      final hasRight = _rightsPermissionKeys.contains(key);
                      final updating = _rightsUpdatingKeys.contains(key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Switch(
                              value: hasRight,
                              onChanged: updating
                                  ? null
                                  : (value) => _toggleUserPermission(key, value),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersCard(BuildContext context, bool isWide, List<CompanyMember> members, String companyId) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_rounded, size: 22, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Membres',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (_canManageUsers(members, _permissionKeys))
                  FilledButton.icon(
                    onPressed: () => _openCreateUser(context, companyId),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Créer un utilisateur'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Aucun membre pour cette entreprise.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final m = members[index];
                return _MemberTile(
                  member: m,
                  isCurrentUser: m.userId == _currentUserId,
                  canToggle: _canManageUsers(members, _permissionKeys),
                  canRemove: _canManageUsers(members, _permissionKeys) && _isOwner(members) && m.userId != _currentUserId,
                  onToggleActive: () => _toggleActive(m, companyId),
                  onRemove: () => _removeMember(m, companyId),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openCreateUser(BuildContext context, String companyId) {
    final stores = context.read<CompanyProvider>().stores;
    showDialog<void>(
      context: context,
      builder: (ctx) => CreateUserDialog(
        companyId: companyId,
        stores: stores,
        onSuccess: () {
          Navigator.of(ctx).pop();
          _applyMemberCreated(companyId);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.canToggle,
    required this.canRemove,
    required this.onToggleActive,
    required this.onRemove,
  });

  final CompanyMember member;
  final bool isCurrentUser;
  final bool canToggle;
  final bool canRemove;
  final VoidCallback onToggleActive;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member.profile?.fullName?.trim().isEmpty == false
        ? member.profile!.fullName!.trim()
        : 'Sans nom';
    final narrow = Breakpoints.isNarrow(MediaQuery.sizeOf(context).width);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: narrow ? 12 : 8),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            RoleLabels.labelFr(member.role.slug, member.role.name),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: member.isActive
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        member.isActive ? 'Actif' : 'Inactif',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: member.isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (canToggle)
                      IconButton(
                        icon: Icon(
                          member.isActive ? Icons.person_off_rounded : Icons.person_rounded,
                          size: 22,
                        ),
                        onPressed: onToggleActive,
                        tooltip: member.isActive ? 'Désactiver' : 'Activer',
                      ),
                    if (canRemove)
                      IconButton(
                        icon: Icon(Icons.person_remove_rounded, size: 22, color: theme.colorScheme.error),
                        onPressed: onRemove,
                        tooltip: 'Retirer de l\'entreprise',
                      ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Vous',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RoleLabels.labelFr(member.role.slug, member.role.name),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: member.isActive
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    member.isActive ? 'Actif' : 'Inactif',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: member.isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (canToggle) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onToggleActive,
                    icon: Icon(member.isActive ? Icons.person_off_rounded : Icons.person_rounded, size: 18),
                    label: Text(member.isActive ? 'Désactiver' : 'Activer'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
                if (canRemove) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.person_remove_rounded, color: theme.colorScheme.error),
                    onPressed: onRemove,
                    tooltip: 'Retirer de l\'entreprise',
                  ),
                ],
              ],
            ),
    );
  }
}

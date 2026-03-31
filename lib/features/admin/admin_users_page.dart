import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';
import '../../providers/auth_provider.dart';
import 'shared/admin_ui.dart';

/// Gestion utilisateurs plateforme (équivalent AdminUsersPage web).
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AdminRepository _repo = AdminRepository();
  final _searchController = TextEditingController();
  String _search = '';
  AdminUser? _editUser;
  String _editFullName = '';
  bool _editIsSuperAdmin = false;
  List<String> _editCompanyIds = [];
  bool _loadingCompanies = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final padding = isWide ? 32.0 : 20.0;

    return Container(
      color: AdminPalette.surfaceAlt,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(title: 'Utilisateurs', description: 'Gestion complète des utilisateurs de la plateforme'),
          const SizedBox(height: 24),
          FutureBuilder<List<LockedLogin>>(
            future: _repo.listLockedLogins(),
            builder: (context, lockSnap) {
              if (lockSnap.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AdminCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Erreur lors du chargement des comptes bloqués.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error))),
                        TextButton(onPressed: () => setState(() {}), child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                );
              }
              final lockedList = lockSnap.data ?? [];
              if (lockedList.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AdminCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text('Comptes bloqués (connexion)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AdminPalette.title)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ces comptes sont verrouillés après 5 tentatives de connexion. Débloquez-les pour que l\'utilisateur puisse se reconnecter.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminPalette.subtitle),
                      ),
                      const SizedBox(height: 12),
                      ...lockedList.map((lock) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(lock.emailLower, style: const TextStyle(fontFamily: 'monospace', color: AdminPalette.title))),
                            if (lock.lockedAt != null && lock.lockedAt!.isNotEmpty) Text(lock.lockedAt!.length > 19 ? lock.lockedAt!.substring(0, 19) : lock.lockedAt!, style: const TextStyle(color: AdminPalette.subtitle, fontSize: 13)),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => _unlockLogin(lock.emailLower),
                              icon: const Icon(Icons.lock_open_rounded, size: 18),
                              label: const Text('Débloquer'),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
          TextField(
            controller: _searchController,
            decoration: adminInputDecoration(
              labelText: 'Rechercher par nom, email, entreprise…',
              prefixIcon: const Icon(Icons.search, color: AdminPalette.subtitle),
            ),
            style: const TextStyle(color: AdminPalette.title),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<AdminUser>>(
            future: _repo.listUsers(),
            builder: (context, snap) {
              if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
              var users = snap.data!;
              if (_search.trim().isNotEmpty) {
                final q = _search.toLowerCase();
                users = users.where((u) =>
                    (u.fullName ?? '').toLowerCase().contains(q) ||
                    (u.email ?? '').toLowerCase().contains(q) ||
                    (u.companyNames).any((c) => c.toLowerCase().contains(q))).toList();
              }
              return AdminCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('Nom', style: AdminPalette.dataTableHeader)),
                      DataColumn(label: Text('Email', style: AdminPalette.dataTableHeader)),
                      DataColumn(label: Text('Entreprises', style: AdminPalette.dataTableHeader)),
                      DataColumn(label: Text('Rôle', style: AdminPalette.dataTableHeader)),
                      DataColumn(label: Text('Statut', style: AdminPalette.dataTableHeader)),
                      DataColumn(label: Text('Actions', style: AdminPalette.dataTableHeader)),
                    ],
                    rows: users.map((u) {
                      return DataRow(
                        cells: [
                          DataCell(Text(u.fullName ?? '—', style: AdminPalette.dataTableCell)),
                          DataCell(Text(u.email ?? '—', style: AdminPalette.dataTableCell)),
                          DataCell(Text((u.companyNames).join(', ').isNotEmpty ? (u.companyNames).join(', ') : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: AdminPalette.dataTableCell)),
                          DataCell(Text(u.isSuperAdmin ? 'Super admin' : 'Utilisateur', style: TextStyle(color: u.isSuperAdmin ? AdminPalette.accent : AdminPalette.title, fontWeight: FontWeight.w500))),
                          DataCell(Text(u.isActive ? 'Actif' : 'Désactivé', style: TextStyle(color: u.isActive ? Colors.green : AdminPalette.subtitle, fontWeight: FontWeight.w500))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, size: 20, color: AdminPalette.title), tooltip: 'Modifier', onPressed: () => _openEdit(u)),
                              if (currentUserId != u.id && u.isActive) IconButton(icon: const Icon(Icons.person_off, size: 20, color: Colors.amber), tooltip: 'Désactiver', onPressed: () => _setUserActive(u.id, false)),
                              if (currentUserId != u.id && !u.isActive) IconButton(icon: const Icon(Icons.person_add, size: 20, color: Colors.green), tooltip: 'Réactiver', onPressed: () => _setUserActive(u.id, true)),
                              // Super admin peut supprimer n'importe quel type d'utilisateur (sauf lui-même).
                              if (currentUserId != u.id) IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), tooltip: 'Supprimer définitivement', onPressed: () => _confirmDelete(u)),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
            if (_editUser != null) _buildEditDialog(context),
          ],
        ),
      ),
    );
  }

  void _openEdit(AdminUser u) async {
    setState(() {
      _editUser = u;
      _editFullName = u.fullName ?? '';
      _editIsSuperAdmin = u.isSuperAdmin;
      _editCompanyIds = [];
      _loadingCompanies = true;
    });
    try {
      final ids = await _repo.getUserCompanyIds(u.id);
      if (mounted) {
        setState(() {
        _editCompanyIds = ids;
        _loadingCompanies = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  Future<void> _saveEdit() async {
    if (_editUser == null) return;
    try {
      await _repo.adminUpdateProfile(_editUser!.id, fullName: _editFullName.trim().isEmpty ? null : _editFullName.trim(), isSuperAdmin: _editIsSuperAdmin);
      await _repo.setUserCompanies(_editUser!.id, _editCompanyIds);
      if (mounted) {
        setState(() => _editUser = null);
        AppToast.success(context, 'Utilisateur mis à jour');
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _setUserActive(String userId, bool active) async {
    try {
      await _repo.setUserActive(userId, active);
      if (mounted) {
        setState(() {});
        AppToast.success(context, active ? 'Compte réactivé' : 'Compte désactivé');
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _unlockLogin(String email) async {
    try {
      await _repo.unlockLogin(email);
      if (mounted) {
        setState(() {});
        AppToast.success(context, 'Compte débloqué : $email');
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _doDelete(AdminUser target) async {
    try {
      await _repo.deleteUser(target.id);
      if (mounted) {
        AppToast.success(context, 'Utilisateur supprimé');
        setState(() {});
      }
    } catch (e) {
      if (mounted) AppErrorHandler.show(context, e);
    }
  }

  Future<void> _confirmDelete(AdminUser target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
          "L'utilisateur ${target.fullName ?? target.email ?? '—'} (${target.isSuperAdmin ? 'Super admin' : 'utilisateur'}) sera supprimé définitivement. Irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _doDelete(target);
    }
  }

  Widget _buildEditDialog(BuildContext context) {
    return FutureBuilder<List<AdminCompany>>(
      future: AdminRepository().listCompanies(),
      builder: (context, snap) {
        final companies = snap.data ?? [];
        return AlertDialog(
          title: const Text("Modifier l'utilisateur"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_editUser != null) Text(_editUser!.email ?? '—', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey('edit_fullname_$_editFullName'),
                  initialValue: _editFullName,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  onChanged: (v) => setState(() => _editFullName = v),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Super admin'),
                  value: _editIsSuperAdmin,
                  onChanged: (v) => setState(() => _editIsSuperAdmin = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Text('Entreprises rattachées', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                _loadingCompanies
                    ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                    : Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(8)),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: companies.length,
                          itemBuilder: (_, i) {
                            final c = companies[i];
                            return CheckboxListTile(
                              title: Text(c.name),
                              value: _editCompanyIds.contains(c.id),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _editCompanyIds.add(c.id);
                                } else {
                                  _editCompanyIds.remove(c.id);
                                }
                              }),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => setState(() => _editUser = null), child: const Text('Annuler')),
            FilledButton(onPressed: _saveEdit, child: const Text('Enregistrer')),
          ],
        );
      },
    );
  }

}

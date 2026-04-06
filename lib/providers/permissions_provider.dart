import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/permissions.dart';
import '../core/errors/app_error_handler.dart';
import '../data/repositories/users_repository.dart';

/// Permissions par entreprise — équivalent usePermissions (web). Super_admin a tout.
/// load(companyId) : appel réseau unique (changement d'entreprise, sync, reprise app).
/// hasPermission(key) : lecture synchrone en mémoire (Set), aucun blocage — préserve la fluidité.
class PermissionsProvider extends ChangeNotifier {
  PermissionsProvider({
    required this.isSuperAdmin,
    UsersRepository? usersRepository,
  }) : _users = usersRepository ?? UsersRepository();

  final bool isSuperAdmin;
  final UsersRepository _users;

  List<String> _permissionKeys = [];
  Set<String> _permissionKeysSet = {};
  String? _roleSlug;
  String? _loadedCompanyId;
  bool _loaded = false;

  static String _prefsKey(String companyId, String suffix) => 'perm_cache_v1:$companyId:$suffix';

  Future<void> _saveCache(String companyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey(companyId, 'keys'), _permissionKeys);
      await prefs.setString(_prefsKey(companyId, 'role'), _roleSlug ?? '');
      await prefs.setInt(_prefsKey(companyId, 'ts'), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<bool> _loadCache(String companyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList(_prefsKey(companyId, 'keys')) ?? const <String>[];
      final role = prefs.getString(_prefsKey(companyId, 'role')) ?? '';
      if (keys.isEmpty && role.isEmpty) return false;
      _permissionKeys = keys;
      _permissionKeysSet = keys.toSet();
      _roleSlug = role.isEmpty ? null : role;
      _loadedCompanyId = companyId;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get hasLoaded => _loaded;
  String? get loadedCompanyId => _loadedCompanyId;
  /// Owner peut toujours accéder à la section Utilisateurs (créer, gérer), même sans users.manage.
  bool get isOwner => _roleSlug == 'owner';

  /// Propriétaire ou rôle Magasinier (permission [Permissions.warehouseManage]).
  bool get canManageWarehouse =>
      isOwner || hasPermission(Permissions.warehouseManage);

  /// Propriétaire ou permission [Permissions.creditView] (accordée via gestion des droits).
  bool get canAccessCredit =>
      isOwner || hasPermission(Permissions.creditView);
  /// Slug du rôle courant (ex. cashier, owner) — pour restreindre la nav.
  String? get roleSlug => _roleSlug;
  /// True si l'utilisateur est caissier (menu limité : Ventes, Produits, Clients, Stock C).
  bool get isCashier => _roleSlug == 'cashier';
  /// Manager : produits, ventes, stock, achats, clients, fournisseurs, rapports ; pas boutiques, IA, utilisateurs, paramètres.
  bool get isManager => _roleSlug == 'manager';
  /// Store Manager : comme Manager mais limité à une boutique ; pas rapports globaux.
  bool get isStoreManager => _roleSlug == 'store_manager';
  /// Magasinier : dépôt central ([Permissions.warehouseManage]) + flux stock / produits (voir rôle en base).
  bool get isStockManager => _roleSlug == 'stock_manager';
  /// Comptable : ventes, achats, clients, fournisseurs, rapports (lecture / export).
  bool get isAccountant => _roleSlug == 'accountant';
  /// Lecture seule : produits, stock, clients, rapports en lecture.
  bool get isViewer => _roleSlug == 'viewer';

  Future<void> load(String? companyId) async {
    if (companyId == null || companyId.isEmpty) {
      _permissionKeys = [];
      _permissionKeysSet = {};
      _roleSlug = null;
      _loadedCompanyId = null;
      _loaded = true;
      notifyListeners();
      return;
    }
    if (isSuperAdmin) {
      _permissionKeys = Permissions.all;
      _permissionKeysSet = Permissions.all.toSet();
      _roleSlug = 'super_admin';
      _loadedCompanyId = companyId;
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final results = await Future.wait([
        _users.getMyPermissionKeys(companyId),
        _users.getMyRoleSlug(companyId),
      ]);
      _permissionKeys = results[0] as List<String>;
      _permissionKeysSet = _permissionKeys.toSet();
      _roleSlug = results[1] as String?;
      _loadedCompanyId = companyId;
      await _saveCache(companyId);
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      // Try restoring from persisted cache (works after restart even fully offline).
      final restored = await _loadCache(companyId);
      // Offline / transient network failure: keep last known permissions so the UI can
      // continue to function offline. If we have nothing yet, fall back to empty.
      final hasLastKnown = restored || (_loadedCompanyId == companyId && _permissionKeysSet.isNotEmpty);
      if (!hasLastKnown) {
        _permissionKeys = [];
        _permissionKeysSet = {};
        _roleSlug = null;
      }
      _loadedCompanyId = companyId;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Vérification synchrone en mémoire — jamais d'appel réseau, aucun impact sur la fluidité.
  bool hasPermission(String key) {
    if (isSuperAdmin) return true;
    return _permissionKeysSet.contains(key);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company_member.dart';

/// Membres entreprise et permissions — même API que usersApi (web).
class UsersRepository {
  UsersRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<RoleOption>> listRoles() async {
    final data = await _client.from('roles').select('id, name, slug').order('name');
    return (data as List).map((e) => RoleOption.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<CompanyMember>> listCompanyMembers(String companyId) async {
    final rows = await _client
        .from('user_company_roles')
        .select('id, user_id, role_id, is_active, created_at, roles(name, slug)')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    if ((rows as List).isEmpty) return [];
    final userIds = (rows as List).map((r) => (r as Map)['user_id'] as String).toSet().toList();
    final profiles = await _client.from('profiles').select('id, full_name').inFilter('id', userIds);
    final byId = <String, Map<String, dynamic>>{};
    for (final p in profiles as List) {
      final m = p as Map;
      final id = m['id'] as String?;
      if (id != null) byId[id] = Map<String, dynamic>.from(m);
    }
    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final uid = m['user_id'] as String?;
      m['profile'] = uid != null && byId.containsKey(uid) ? byId[uid] : null;
      return CompanyMember.fromJson(m);
    }).toList();
  }

  Future<void> setCompanyMemberActive(String userCompanyRoleId, bool isActive) async {
    await _client.from('user_company_roles').update({'is_active': isActive}).eq('id', userCompanyRoleId);
  }

  Future<void> removeCompanyMember(String ucrId) async {
    await _client.rpc('remove_company_member', params: {'p_ucr_id': ucrId});
  }

  /// Permissions de l'utilisateur courant pour une entreprise (RPC get_my_permission_keys).
  Future<List<String>> getMyPermissionKeys(String companyId) async {
    final data = await _client.rpc('get_my_permission_keys', params: {'p_company_id': companyId});
    return (data as List).map((e) => e.toString()).toList();
  }

  /// Permissions effectives d'un utilisateur (rôle + overrides). Réservé à l'owner.
  Future<List<String>> getUserPermissionKeys(String companyId, String userId) async {
    final data = await _client.rpc(
      'get_user_permission_keys',
      params: {'p_company_id': companyId, 'p_user_id': userId},
    );
    if (data == null) return [];
    if (data is! List) throw Exception('Réponse invalide lors du chargement des droits.');
    return data.map((e) => e.toString()).toList();
  }

  /// Ajoute (granted=true) ou retire (granted=false) une permission pour un utilisateur. Réservé à l'owner.
  Future<void> setUserPermissionOverride(
    String companyId,
    String userId,
    String permissionKey,
    bool granted,
  ) async {
    if (permissionKey.trim().isEmpty) {
      throw ArgumentError('Clé de permission invalide.');
    }
    await _client.rpc(
      'set_user_permission_override',
      params: {
        'p_company_id': companyId,
        'p_user_id': userId,
        'p_permission_key': permissionKey,
        'p_granted': granted,
      },
    );
  }

  /// Slug du rôle de l'utilisateur courant pour une entreprise (RPC get_my_role_slug).
  /// Permet d'afficher "Utilisateurs" aux owners même sans permission users.manage.
  Future<String?> getMyRoleSlug(String companyId) async {
    final data = await _client.rpc('get_my_role_slug', params: {'p_company_id': companyId});
    return data as String?;
  }

  /// Crée un utilisateur dans l'entreprise via l'Edge Function create-company-user (aligné web).
  /// Le type (rôle) est bien enregistré en base (user_company_roles.role_id) et appliqué
  /// aux restrictions (get_my_role_slug / get_my_permission_keys).
  Future<void> createCompanyUser({
    required String companyId,
    required String email,
    required String password,
    String? fullName,
    required String roleSlug,
    List<String>? storeIds,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw Exception('Session absente. Déconnectez-vous puis reconnectez-vous.');
    }
    final slug = roleSlug.trim().toLowerCase();
    if (slug.isEmpty) {
      throw Exception('Le type d\'utilisateur (rôle) est requis.');
    }
    await _client.auth.refreshSession();

    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'full_name': (fullName?.trim().isEmpty ?? true) ? null : fullName!.trim(),
      'role_slug': slug,
      'company_id': companyId,
    };
    if (storeIds != null && storeIds.isNotEmpty) body['store_ids'] = storeIds;

    final res = await _client.functions.invoke('create-company-user', body: body);

    final data = res.data;
    if (res.status != 200 && data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }
}

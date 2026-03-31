import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_models.dart';

/// Admin plateforme — même API que adminApi (web). Réservé super_admin.
class AdminRepository {
  AdminRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AdminCompany>> listCompanies() async {
    final data = await _client
        .from('companies')
        .select('id, name, slug, is_active, store_quota, ai_predictions_enabled, created_at')
        .order('created_at', ascending: false);
    return (data as List).map((e) => AdminCompany.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<AdminStore>> listStores([String? companyId]) async {
    var q = _client.from('stores').select('id, company_id, name, code, is_active, is_primary, created_at');
    if (companyId != null) q = q.eq('company_id', companyId);
    final data = await q.order('created_at', ascending: false);
    return (data as List).map((e) => AdminStore.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> updateCompany(String id, {bool? isActive, bool? aiPredictionsEnabled}) async {
    final patch = <String, dynamic>{};
    if (isActive != null) patch['is_active'] = isActive;
    if (aiPredictionsEnabled != null) patch['ai_predictions_enabled'] = aiPredictionsEnabled;
    if (patch.isEmpty) return;
    await _client.from('companies').update(patch).eq('id', id);
  }

  Future<void> updateStore(String id, {bool? isActive}) async {
    if (isActive == null) return;
    await _client.from('stores').update({'is_active': isActive}).eq('id', id);
  }

  Future<void> deleteCompany(String id) async {
    await _client.from('companies').delete().eq('id', id);
  }

  Future<void> deleteStore(String id) async {
    await _client.from('stores').delete().eq('id', id);
  }

  Future<AdminStats> getStats() async {
    final companies = await _client.from('companies').select('id');
    final stores = await _client.from('stores').select('id');
    final ucr = await _client.from('user_company_roles').select('id');
    final salesData = await _client.from('sales').select('id, total').eq('status', 'completed');
    double salesTotalAmount = 0;
    for (final r in salesData as List) {
      salesTotalAmount += ((r as Map)['total'] as num?)?.toDouble() ?? 0;
    }
    int subsCount = 0;
    try {
      final subs = await _client.from('company_subscriptions').select('id').eq('status', 'active');
      subsCount = (subs as List).length;
    } catch (_) {}
    return AdminStats(
      companiesCount: (companies as List).length,
      storesCount: (stores as List).length,
      usersCount: (ucr as List).length,
      salesCount: (salesData as List).length,
      salesTotalAmount: salesTotalAmount,
      activeSubscriptionsCount: subsCount,
    );
  }

  Future<List<AdminUser>> listUsers() async {
    final data = await _client.rpc('admin_list_users');
    return (data as List).map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<AdminSalesByCompany>> getSalesByCompany() async {
    final sales = await _client.from('sales').select('company_id, total').eq('status', 'completed');
    final companies = await _client.from('companies').select('id, name');
    final byCompany = <String, ({int count, double total})>{};
    for (final s in sales as List) {
      final m = s as Map;
      final cid = m['company_id'] as String?;
      if (cid == null) continue;
      final cur = byCompany[cid] ?? (count: 0, total: 0);
      byCompany[cid] = (count: cur.count + 1, total: cur.total + ((m['total'] as num?)?.toDouble() ?? 0));
    }
    final list = <AdminSalesByCompany>[];
    for (final c in companies as List) {
      final m = c as Map;
      final id = m['id'] as String?;
      final name = m['name'] as String? ?? '—';
      if (id == null) continue;
      final agg = byCompany[id] ?? (count: 0, total: 0);
      list.add(AdminSalesByCompany(companyId: id, companyName: name, salesCount: agg.count, totalAmount: agg.total));
    }
    list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return list;
  }

  Future<List<AdminSalesOverTimeItem>> getSalesOverTime({int days = 30}) async {
    final fromDate = DateTime.now().subtract(Duration(days: days));
    final fromStr = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
    final sales = await _client.from('sales').select('created_at, total').eq('status', 'completed').gte('created_at', fromStr);
    final byDay = <String, ({int count, double total})>{};
    for (final s in sales as List) {
      final m = s as Map;
      final day = (m['created_at'] as String?)?.substring(0, 10) ?? '';
      final cur = byDay[day] ?? (count: 0, total: 0);
      byDay[day] = (count: cur.count + 1, total: cur.total + ((m['total'] as num?)?.toDouble() ?? 0));
    }
    final result = <AdminSalesOverTimeItem>[];
    for (var d = 0; d < days; d++) {
      final date = fromDate.add(Duration(days: d));
      final dayStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final agg = byDay[dayStr] ?? (count: 0, total: 0);
      result.add(AdminSalesOverTimeItem(date: dayStr, count: agg.count, total: agg.total));
    }
    return result;
  }

  Future<void> adminUpdateProfile(String userId, {String? fullName, bool? isSuperAdmin}) async {
    await _client.rpc('admin_update_profile', params: {
      'p_user_id': userId,
      'p_full_name': ?fullName,
      'p_is_super_admin': ?isSuperAdmin,
    });
  }

  Future<List<String>> getUserCompanyIds(String userId) async {
    final data = await _client.rpc('admin_get_user_company_ids', params: {'p_user_id': userId});
    return (data as List).map((e) => e.toString()).toList();
  }

  Future<void> setUserCompanies(String userId, List<String> companyIds, {String roleSlug = 'store_manager'}) async {
    await _client.rpc('admin_set_user_companies', params: {
      'p_user_id': userId,
      'p_company_ids': companyIds,
      'p_role_slug': roleSlug,
    });
  }

  Future<void> setUserActive(String userId, bool active) async {
    await _client.rpc('admin_set_user_active', params: {'p_user_id': userId, 'p_active': active});
  }

  Future<void> deleteUser(String userId) async {
    dynamic res;
    final token = _client.auth.currentSession?.accessToken;
    try {
      res = await _client.functions.invoke(
        'admin-delete-user',
        body: {
          'user_id': userId,
          if (token != null && token.isNotEmpty) 'access_token': token,
        },
      );
    } catch (_) {
      // Retry once after session refresh, without overriding SDK headers.
      final refreshed = await _client.auth.refreshSession();
      if (refreshed.session?.accessToken == null ||
          refreshed.session!.accessToken.isEmpty) {
        throw Exception('Session expirée. Veuillez vous reconnecter puis réessayer.');
      }
      final refreshedToken = refreshed.session!.accessToken;
      res = await _client.functions.invoke(
        'admin-delete-user',
        body: {'user_id': userId, 'access_token': refreshedToken},
      );
    }

    final err = (res.data as Map?)?['error'];
    if (err != null) throw Exception(err.toString());
  }

  /// Comptes bloqués après 5 tentatives de connexion (super_admin).
  Future<List<LockedLogin>> listLockedLogins() async {
    final data = await _client.rpc('admin_list_locked_logins');
    return (data as List).map((e) => LockedLogin.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Débloquer un compte (super_admin).
  Future<void> unlockLogin(String email) async {
    await _client.rpc('admin_unlock_login', params: {'p_email': email});
  }

  Future<Map<String, String>> getPlatformSettings() async {
    final data = await _client.from('platform_settings').select('key, value');
    final out = <String, String>{};
    for (final row in data as List) {
      final m = row as Map;
      out[m['key'] as String] = m['value'] as String;
    }
    return out;
  }

  Future<void> setPlatformSetting(String key, String value) async {
    await _client.from('platform_settings').upsert({'key': key, 'value': value, 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'key');
  }

  Future<void> setPlatformSettings(Map<String, String> settings) async {
    for (final e in settings.entries) {
      await setPlatformSetting(e.key, e.value);
    }
  }

  Future<List<Map<String, dynamic>>> listLandingChatMessages({int limit = 500}) async {
    final data = await _client.from('landing_chat_messages').select('id, session_id, role, content, created_at').order('created_at', ascending: false).limit(limit);
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Super admin : envoie une notification à un utilisateur (visible dans son espace Notifications).
  Future<void> sendNotificationToUser(String userId, String title, {String? body, String type = 'admin_message'}) async {
    await _client.rpc('admin_create_notification', params: {
      'p_user_id': userId,
      'p_title': title,
      'p_body': body,
      'p_type': type,
    });
  }

  /// Super admin : envoie une notification à tous les owners (chaque owner la voit dans Notifications).
  Future<int> sendNotificationToAllOwners(String title, {String? body, String type = 'admin_message'}) async {
    final res = await _client.rpc('admin_create_notification_to_owners', params: {
      'p_title': title,
      'p_body': body,
      'p_type': type,
    });
    return res as int;
  }

  /// Super admin : liste des erreurs remontées par les apps clientes.
  Future<List<AdminAppErrorLog>> listAppErrors({
    String? companyId,
    String? userId,
    String? source,
    String? level,
    /// `web` | `flutter` — filtre sur la colonne `client_kind` (migration 00074).
    String? clientKind,
    String? fromDate,
    String? toDate,
    int limit = 200,
  }) async {
    var q = _client.from('app_error_logs').select(
      'id, created_at, user_id, company_id, store_id, source, level, message, stack_trace, error_type, platform, client_kind, context',
    );
    if (companyId != null && companyId.isNotEmpty) q = q.eq('company_id', companyId);
    if (userId != null && userId.isNotEmpty) q = q.eq('user_id', userId);
    if (source != null && source.isNotEmpty) q = q.eq('source', source);
    if (level != null && level.isNotEmpty) q = q.eq('level', level);
    if (clientKind != null && clientKind.isNotEmpty) q = q.eq('client_kind', clientKind);
    if (fromDate != null && fromDate.isNotEmpty) q = q.gte('created_at', fromDate);
    if (toDate != null && toDate.isNotEmpty) {
      q = q.lte('created_at', '${toDate}T23:59:59.999Z');
    }
    final data = await q.order('created_at', ascending: false).limit(limit);
    return (data as List)
        .map((e) => AdminAppErrorLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

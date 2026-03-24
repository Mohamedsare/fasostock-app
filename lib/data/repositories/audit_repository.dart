import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_log.dart';

/// Journal d'audit — lecture des logs, enregistrement via RPC.
class AuditRepository {
  AuditRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Liste paginée des entrées d'audit pour une entreprise.
  Future<List<AuditLogEntry>> list(
    String companyId, {
    String? storeId,
    String? action,
    String? entityType,
    String? fromDate,
    String? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = _client
        .from('audit_logs')
        .select('id, company_id, store_id, user_id, action, entity_type, entity_id, old_data, new_data, created_at')
        .eq('company_id', companyId);
    if (storeId != null) q = q.eq('store_id', storeId);
    if (action != null && action.isNotEmpty) q = q.eq('action', action);
    if (entityType != null && entityType.isNotEmpty) q = q.eq('entity_type', entityType);
    if (fromDate != null) q = q.gte('created_at', fromDate);
    if (toDate != null) q = q.lte('created_at', '${toDate}T23:59:59.999Z');
    final data = await q.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return (data as List).map((e) => AuditLogEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Liste pour le super admin : toutes les entreprises ou une seule (companyId null = toutes).
  Future<List<AuditLogEntry>> listForAdmin(
    String? companyId, {
    String? action,
    String? entityType,
    String? fromDate,
    String? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = _client
        .from('audit_logs')
        .select('id, company_id, store_id, user_id, action, entity_type, entity_id, old_data, new_data, created_at');
    if (companyId != null && companyId.isNotEmpty) q = q.eq('company_id', companyId);
    if (action != null && action.isNotEmpty) q = q.eq('action', action);
    if (entityType != null && entityType.isNotEmpty) q = q.eq('entity_type', entityType);
    if (fromDate != null) q = q.gte('created_at', fromDate);
    if (toDate != null) q = q.lte('created_at', '${toDate}T23:59:59.999Z');
    final data = await q.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return (data as List).map((e) => AuditLogEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Enregistre une action dans le journal d'audit (RPC).
  Future<String> log({
    required String companyId,
    required String action,
    required String entityType,
    String? storeId,
    String? entityId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    final result = await _client.rpc(
      'log_audit',
      params: {
        'p_company_id': companyId,
        'p_action': action,
        'p_entity_type': entityType,
        'p_store_id': storeId,
        'p_entity_id': entityId,
        'p_old_data': oldData,
        'p_new_data': newData,
      },
    );
    return result as String;
  }
}

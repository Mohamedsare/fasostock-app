import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';
import '../models/store.dart';

/// Chargement des entreprises et boutiques pour l'utilisateur connecté — équivalent CompanyContext.
class CompanyRepository {
  CompanyRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Entreprises auxquelles l'utilisateur a accès (user_company_roles actifs).
  Future<List<Company>> getCompaniesForUser(String userId) async {
    final roles = await _client
        .from('user_company_roles')
        .select('company_id')
        .eq('user_id', userId)
        .eq('is_active', true);
    if ((roles as List).isEmpty) return [];
    final companyIds = (roles as List).map((r) => (r as Map)['company_id'] as String).toSet().toList();
    if (companyIds.isEmpty) return [];
    final data = await _client
        .from('companies')
        .select('id, name, slug, is_active, store_quota, ai_predictions_enabled')
        .inFilter('id', companyIds);
    return (data as List).map((e) => Company.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Boutiques actives d'une entreprise.
  Future<List<Store>> getStoresForCompany(String companyId) async {
    final data = await _client
        .from('stores')
        .select('id, company_id, name, code, address, logo_url, phone, email, description, is_active, is_primary, pos_discount_enabled, created_at')
        .eq('company_id', companyId)
        .eq('is_active', true);
    return (data as List).map((e) => Store.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../models/company.dart';
import '../models/store.dart';

String _toSafeMessage(Object? e) => ErrorMapper.toMessage(e);

/// Chargement des entreprises et boutiques pour l'utilisateur connecté — équivalent CompanyContext.
class CompanyRepository {
  CompanyRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _companyFields =
      'id, name, slug, business_type_slug, logo_url, is_active, store_quota, ai_predictions_enabled';

  /// Même bucket public que les logos boutique (`00006_store_logos_bucket.sql`).
  static const String _logosBucket = 'store-logos';

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
        .select(_companyFields)
        .inFilter('id', companyIds);
    return (data as List).map((e) => Company.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Met à jour des champs `companies` (ex. `logo_url`). Réservé aux rôles autorisés par RLS (owner, etc.).
  Future<Company> updateCompany(String companyId, Map<String, dynamic> patch) async {
    try {
      final data = await _client
          .from('companies')
          .update(patch)
          .eq('id', companyId)
          .select(_companyFields)
          .single();
      return Company.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  /// Envoie un logo entreprise dans le bucket `store-logos` (chemin `company/{id}/…`).
  Future<String> uploadCompanyLogo(
    String companyId,
    List<int> bytes,
    String fileName,
    String contentType,
  ) async {
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final path = 'company/$companyId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from(_logosBucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType),
          );
      return _client.storage.from(_logosBucket).getPublicUrl(path);
    } catch (e) {
      throw UserFriendlyError(_toSafeMessage(e));
    }
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

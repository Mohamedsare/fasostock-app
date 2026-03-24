import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error_handler.dart';
import '../models/store.dart';

/// Réutilise ErrorMapper pour ne jamais propager de message technique.
String _toSafeMessage(Object? e) => ErrorMapper.toMessage(e);

/// Boutiques — même API que storesService (web).
class StoresRepository {
  StoresRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _storeFields =
      'id, company_id, name, code, address, logo_url, phone, email, description, is_active, is_primary, pos_discount_enabled, created_at, '
      'currency, primary_color, secondary_color, invoice_prefix, footer_text, legal_info, signature_url, stamp_url, payment_terms, tax_label, tax_number, city, country, commercial_name, slogan, activity, mobile_money, invoice_short_title, invoice_signer_title, invoice_signer_name, invoice_template';

  Future<List<Store>> getStoresByCompany(String companyId) async {
    try {
      final data = await _client
          .from('stores')
          .select(_storeFields)
          .eq('company_id', companyId);
      final list = data as List;
      return list.map((e) {
        try {
          return Store.fromJson(Map<String, dynamic>.from(e as Map));
        } catch (_) {
          throw const UserFriendlyError('Impossible de charger les boutiques : données invalides.');
        }
      }).toList();
    } catch (e) {
      if (e is UserFriendlyError) rethrow;
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  Future<Store?> getStore(String id) async {
    try {
      final data = await _client.from('stores').select(_storeFields).eq('id', id).maybeSingle();
      if (data == null) return null;
      try {
        return Store.fromJson(Map<String, dynamic>.from(data as Map));
      } catch (_) {
        throw const UserFriendlyError('Impossible de charger la boutique : données invalides.');
      }
    } catch (e) {
      if (e is UserFriendlyError) rethrow;
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  Future<Map<String, dynamic>?> getCompanyWithQuota(String companyId) async {
    try {
      final res = await _client.from('companies').select('store_quota').eq('id', companyId).maybeSingle();
      return res != null ? Map<String, dynamic>.from(res as Map) : null;
    } catch (e) {
      if (e is UserFriendlyError) rethrow;
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  Future<Store> createStore(CreateStoreInput input) async {
    try {
      final res = await _client.rpc(
        'create_store',
        params: {
          'p_company_id': input.companyId,
          'p_name': input.name,
          'p_address': input.address,
          'p_phone': input.phone,
          'p_email': input.email,
          'p_description': input.description,
          'p_is_primary': input.isPrimary,
        },
      );
      if (res == null) throw const UserFriendlyError('Création de la boutique impossible.');
      Store store;
      try {
        store = Store.fromJson(Map<String, dynamic>.from(res as Map));
      } catch (_) {
        throw const UserFriendlyError('Création de la boutique : données invalides.');
      }
      if (input.logoUrl != null && input.logoUrl!.isNotEmpty) {
        await _client.from('stores').update({'logo_url': input.logoUrl}).eq('id', store.id);
        return Store(
          id: store.id,
          companyId: store.companyId,
          name: store.name,
          code: store.code,
          address: store.address,
          logoUrl: input.logoUrl,
          phone: store.phone,
          email: store.email,
          description: store.description,
          isActive: store.isActive,
          isPrimary: store.isPrimary,
          posDiscountEnabled: store.posDiscountEnabled,
          createdAt: store.createdAt,
        );
      }
      return store;
    } catch (e) {
      if (e is UserFriendlyError) rethrow;
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  Future<Store> updateStore(String id, Map<String, dynamic> patch) async {
    try {
      final data = await _client.from('stores').update(patch).eq('id', id).select(_storeFields).single();
      try {
        return Store.fromJson(Map<String, dynamic>.from(data as Map));
      } catch (_) {
        throw const UserFriendlyError('Impossible d\'enregistrer la boutique : données invalides.');
      }
    } catch (e) {
      if (e is UserFriendlyError) rethrow;
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }

  static const String bucketStoreLogos = 'store-logos';

  Future<String> uploadStoreLogo(String storeId, List<int> bytes, String fileName, String contentType) async {
    try {
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final path = '$storeId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from(bucketStoreLogos).uploadBinary(path, Uint8List.fromList(bytes), fileOptions: FileOptions(contentType: contentType));
      final url = _client.storage.from(bucketStoreLogos).getPublicUrl(path);
      return url;
    } catch (e) {
      if (e is UserFriendlyError) rethrow;
      throw UserFriendlyError(_toSafeMessage(e));
    }
  }
}

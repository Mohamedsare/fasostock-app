import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

/// Paramètres entreprise et profil — companySettingsApi + profilesApi (web).
class SettingsRepository {
  SettingsRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _keyDefaultStockAlert = 'default_stock_alert_threshold';
  static const _defaultStockAlertValue = 5;

  Future<int> getDefaultStockAlertThreshold(String companyId) async {
    final data = await _client
        .from('company_settings')
        .select('value')
        .eq('company_id', companyId)
        .eq('key', _keyDefaultStockAlert)
        .maybeSingle();
    if (data == null) return _defaultStockAlertValue;
    final raw = (data as Map)['value'];
    if (raw is int && raw >= 0) return raw;
    if (raw is String) {
      final n = int.tryParse(raw);
      if (n != null && n >= 0) return n;
    }
    return _defaultStockAlertValue;
  }

  Future<void> setDefaultStockAlertThreshold(String companyId, int value) async {
    if (value < 0) throw Exception('Le seuil doit être >= 0');
    final existing = await _client
        .from('company_settings')
        .select('id')
        .eq('company_id', companyId)
        .eq('key', _keyDefaultStockAlert)
        .maybeSingle();
    if (existing != null) {
      await _client.from('company_settings').update({'value': value}).eq('company_id', companyId).eq('key', _keyDefaultStockAlert);
    } else {
      await _client.from('company_settings').insert({'company_id': companyId, 'key': _keyDefaultStockAlert, 'value': value});
    }
  }

  Future<Profile> updateProfile(String userId, {String? fullName}) async {
    final data = await _client.from('profiles').update({'full_name': fullName}).eq('id', userId).select().single();
    return Profile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<int> clearSalesHistory(String companyId, {String? storeId}) async {
    final res = await _client.rpc(
      'owner_clear_sales_history',
      params: {
        'p_company_id': companyId,
        'p_store_id': storeId,
      },
    );
    return (res as num?)?.toInt() ?? 0;
  }

  Future<int> clearPurchasesHistory(String companyId, {String? storeId}) async {
    final res = await _client.rpc(
      'owner_clear_purchases_history',
      params: {
        'p_company_id': companyId,
        'p_store_id': storeId,
      },
    );
    return (res as num?)?.toInt() ?? 0;
  }

  Future<int> clearTransfersHistory(String companyId, {String? storeId}) async {
    final res = await _client.rpc(
      'owner_clear_transfers_history',
      params: {
        'p_company_id': companyId,
        'p_store_id': storeId,
      },
    );
    return (res as num?)?.toInt() ?? 0;
  }

  Future<int> clearProductsCatalog(String companyId) async {
    final res = await _client.rpc(
      'owner_clear_products_catalog',
      params: {'p_company_id': companyId},
    );
    return (res as num?)?.toInt() ?? 0;
  }

  Future<int> clearStock(String companyId, {String? storeId}) async {
    final res = await _client.rpc(
      'owner_clear_stock',
      params: {
        'p_company_id': companyId,
        'p_store_id': storeId,
      },
    );
    return (res as num?)?.toInt() ?? 0;
  }

  Future<int> clearStockMovementsHistory(String companyId, {String? storeId}) async {
    final res = await _client.rpc(
      'owner_clear_stock_movements_history',
      params: {
        'p_company_id': companyId,
        'p_store_id': storeId,
      },
    );
    return (res as num?)?.toInt() ?? 0;
  }

  /// Version explicite "magasin/dépôt" (entreprise entière, sans boutique).
  Future<int> clearWarehouseStock(String companyId) async {
    return clearStock(companyId, storeId: null);
  }

  /// Version explicite "magasin/dépôt" pour l'historique des mouvements.
  Future<int> clearWarehouseMovementsHistory(String companyId) async {
    return clearStockMovementsHistory(companyId, storeId: null);
  }
}

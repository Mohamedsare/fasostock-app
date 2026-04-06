import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/public_website_url.dart';
import '../models/profile.dart';

/// Paramètres entreprise et profil — companySettingsApi + profilesApi (web).
class SettingsRepository {
  SettingsRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Dernière valeur connue par entreprise — évite un flash « carte absente » au retour
  /// sur Ventes / Boutiques pendant le fetch réseau.
  static final Map<String, bool> _invoiceTablePosEnabledByCompany = {};

  static bool? peekInvoiceTablePosEnabled(String companyId) =>
      _invoiceTablePosEnabledByCompany[companyId];

  static const _keyDefaultStockAlert = 'default_stock_alert_threshold';
  static const _keyPublicWebsiteUrl = 'public_website_url';
  static const _keyInvoiceTablePosEnabled = 'invoice_table_pos_enabled';
  static const _defaultStockAlertValue = 5;

  /// Propriétaire : active l’entrée « Facture (tableau) » sur les boutiques (droit utilisateur distinct).
  Future<bool> getInvoiceTablePosEnabled(String companyId) async {
    final data = await _client
        .from('company_settings')
        .select('value')
        .eq('company_id', companyId)
        .eq('key', _keyInvoiceTablePosEnabled)
        .maybeSingle();
    bool result;
    if (data == null) {
      result = false;
    } else {
      final raw = (data as Map)['value'];
      if (raw is bool) {
        result = raw;
      } else if (raw is String) {
        final s = raw.trim().toLowerCase();
        result = s == 'true' || s == '1' || s == 'yes';
      } else if (raw is num) {
        result = raw != 0;
      } else {
        result = false;
      }
    }
    _invoiceTablePosEnabledByCompany[companyId] = result;
    return result;
  }

  Future<void> setInvoiceTablePosEnabled(String companyId, bool enabled) async {
    final existing = await _client
        .from('company_settings')
        .select('id')
        .eq('company_id', companyId)
        .eq('key', _keyInvoiceTablePosEnabled)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('company_settings')
          .update({'value': enabled})
          .eq('company_id', companyId)
          .eq('key', _keyInvoiceTablePosEnabled);
    } else {
      await _client.from('company_settings').insert({
        'company_id': companyId,
        'key': _keyInvoiceTablePosEnabled,
        'value': enabled,
      });
    }
    _invoiceTablePosEnabledByCompany[companyId] = enabled;
  }

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

  /// Site web public — encodé dans le QR des tickets caisse rapide si renseigné.
  Future<String?> getPublicWebsiteUrl(String companyId) async {
    final data = await _client
        .from('company_settings')
        .select('value')
        .eq('company_id', companyId)
        .eq('key', _keyPublicWebsiteUrl)
        .maybeSingle();
    if (data == null) return null;
    final raw = (data as Map)['value'];
    if (raw == null) return null;
    final s = raw is String ? raw : raw.toString().trim();
    return normalizePublicWebsiteUrlForQr(s);
  }

  /// [url] vide ou null : supprime le paramètre (QR repasse au format texte ticket).
  Future<void> setPublicWebsiteUrl(String companyId, String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _client
          .from('company_settings')
          .delete()
          .eq('company_id', companyId)
          .eq('key', _keyPublicWebsiteUrl);
      return;
    }
    final normalized = normalizePublicWebsiteUrlForQr(trimmed);
    if (normalized == null) {
      throw const UserFriendlyError(
        'URL du site invalide. Exemple : https://srfaso.com',
      );
    }
    final existing = await _client
        .from('company_settings')
        .select('id')
        .eq('company_id', companyId)
        .eq('key', _keyPublicWebsiteUrl)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('company_settings')
          .update({'value': normalized})
          .eq('company_id', companyId)
          .eq('key', _keyPublicWebsiteUrl);
    } else {
      await _client.from('company_settings').insert({
        'company_id': companyId,
        'key': _keyPublicWebsiteUrl,
        'value': normalized,
      });
    }
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

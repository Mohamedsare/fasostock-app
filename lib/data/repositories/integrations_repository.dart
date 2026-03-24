import 'package:supabase_flutter/supabase_flutter.dart';

/// Clé API (vue liste, sans la clé complète).
class ApiKeyInfo {
  const ApiKeyInfo({
    required this.id,
    required this.name,
    required this.keyPrefix,
    this.lastUsedAt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String keyPrefix;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) {
    final last = json['last_used_at'];
    final created = json['created_at'];
    return ApiKeyInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      keyPrefix: json['key_prefix'] as String,
      lastUsedAt: last != null ? DateTime.tryParse(last.toString()) : null,
      createdAt: created is String ? DateTime.parse(created) : created as DateTime,
    );
  }
}

class IntegrationsRepository {
  IntegrationsRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<List<ApiKeyInfo>> listApiKeys(String companyId) async {
    final data = await _client
        .from('api_keys')
        .select('id, name, key_prefix, last_used_at, created_at')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => ApiKeyInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Crée une clé API. Retourne la clé en clair (à afficher une seule fois).
  Future<Map<String, dynamic>> createApiKey(String companyId, String name) async {
    final res = await _client.rpc('create_api_key', params: {'p_company_id': companyId, 'p_name': name});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> deleteApiKey(String id) async {
    await _client.from('api_keys').delete().eq('id', id);
  }

  /// Liste des webhooks (owner). Vide si table non utilisée.
  Future<List<WebhookEndpointInfo>> listWebhooks(String companyId) async {
    try {
      final data = await _client
          .from('webhook_endpoints')
          .select('id, url, events, is_active, created_at')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => WebhookEndpointInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }
}

/// Webhook (vue liste).
class WebhookEndpointInfo {
  const WebhookEndpointInfo({
    required this.id,
    required this.url,
    required this.events,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String url;
  final List<String> events;
  final bool isActive;
  final DateTime createdAt;

  factory WebhookEndpointInfo.fromJson(Map<String, dynamic> json) {
    final events = json['events'];
    final created = json['created_at'];
    return WebhookEndpointInfo(
      id: json['id'] as String,
      url: json['url'] as String,
      events: events is List ? (events).map((e) => e.toString()).toList() : [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: created is String ? DateTime.parse(created) : created as DateTime,
    );
  }
}

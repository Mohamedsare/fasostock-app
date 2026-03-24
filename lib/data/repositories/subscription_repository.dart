import 'package:supabase_flutter/supabase_flutter.dart';

/// Abonnement entreprise — plan et statut (base pour Stripe).
class SubscriptionInfo {
  const SubscriptionInfo({
    required this.planSlug,
    required this.planName,
    required this.status,
    this.currentPeriodEnd,
  });

  final String planSlug;
  final String planName;
  final String status;
  final DateTime? currentPeriodEnd;

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final plan = json['subscription_plans'];
    Map<String, dynamic>? planMap;
    if (plan is Map) planMap = Map<String, dynamic>.from(plan);
    final periodEnd = json['current_period_end'];
    return SubscriptionInfo(
      planSlug: planMap?['slug'] as String? ?? 'free',
      planName: planMap?['name'] as String? ?? 'Gratuit',
      status: json['status'] as String? ?? 'active',
      currentPeriodEnd: periodEnd != null ? DateTime.tryParse(periodEnd.toString()) : null,
    );
  }
}

class SubscriptionRepository {
  SubscriptionRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  /// Récupère l'abonnement de l'entreprise (avec plan).
  Future<SubscriptionInfo?> getByCompany(String companyId) async {
    final data = await _client
        .from('company_subscriptions')
        .select('status, current_period_end, subscription_plans(slug, name)')
        .eq('company_id', companyId)
        .maybeSingle();
    if (data == null) return null;
    final m = Map<String, dynamic>.from(data as Map);
    m['subscription_plans'] = data['subscription_plans'];
    return SubscriptionInfo.fromJson(m);
  }

  /// Liste des plans disponibles (pour affichage ou upgrade).
  Future<List<Map<String, dynamic>>> listPlans() async {
    final data = await _client
        .from('subscription_plans')
        .select('id, slug, name, description, price_cents, currency, interval, max_stores, max_users')
        .eq('is_active', true)
        .order('price_cents');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

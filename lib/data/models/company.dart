/// Entreprise — aligné avec Company (CompanyContext) et table companies.
class Company {
  const Company({
    required this.id,
    required this.name,
    this.slug,
    this.businessTypeSlug,
    this.logoUrl,
    this.isActive = true,
    this.storeQuota = 1,
    this.aiPredictionsEnabled = false,
  });

  final String id;
  final String name;
  final String? slug;
  /// `companies.business_type_slug` — choix d’activité à l’inscription.
  final String? businessTypeSlug;
  /// Logo entreprise (`companies.logo_url`) — affichage shell, etc.
  final String? logoUrl;
  final bool isActive;
  final int storeQuota;
  final bool aiPredictionsEnabled;

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      businessTypeSlug: json['business_type_slug'] as String?,
      logoUrl: json['logo_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      storeQuota: (json['store_quota'] is int)
          ? json['store_quota'] as int
          : (json['store_quota'] as num?)?.toInt() ?? 1,
      aiPredictionsEnabled: json['ai_predictions_enabled'] as bool? ?? false,
    );
  }
}

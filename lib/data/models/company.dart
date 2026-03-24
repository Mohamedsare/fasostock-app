/// Entreprise — aligné avec Company (CompanyContext) et table companies.
class Company {
  const Company({
    required this.id,
    required this.name,
    this.slug,
    this.isActive = true,
    this.storeQuota = 1,
    this.aiPredictionsEnabled = false,
  });

  final String id;
  final String name;
  final String? slug;
  final bool isActive;
  final int storeQuota;
  final bool aiPredictionsEnabled;

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      storeQuota: (json['store_quota'] is int)
          ? json['store_quota'] as int
          : (json['store_quota'] as num?)?.toInt() ?? 1,
      aiPredictionsEnabled: json['ai_predictions_enabled'] as bool? ?? false,
    );
  }
}

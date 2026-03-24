/// Marque produit — table brands.
class Brand {
  const Brand({
    required this.id,
    required this.companyId,
    required this.name,
  });

  final String id;
  final String companyId;
  final String name;

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
    );
  }
}

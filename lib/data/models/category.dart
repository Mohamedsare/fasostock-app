/// Catégorie produit — table categories.
class Category {
  const Category({
    required this.id,
    required this.companyId,
    required this.name,
    this.parentId,
  });

  final String id;
  final String companyId;
  final String name;
  final String? parentId;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
    );
  }
}

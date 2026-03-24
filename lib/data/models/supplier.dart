/// Fournisseur — aligné avec Supplier (suppliersApi), lecture seule côté API.
class Supplier {
  const Supplier({
    required this.id,
    required this.companyId,
    required this.name,
    this.contact,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String id;
  final String companyId;
  final String name;
  final String? contact;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      contact: json['contact'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

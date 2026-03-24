/// Type client — individual | company.
enum CustomerType {
  individual,
  company,
}

extension CustomerTypeExt on CustomerType {
  static CustomerType fromString(String v) =>
      v == 'company' ? CustomerType.company : CustomerType.individual;
  String get value => name;
}

/// Client — aligné avec Customer (customersApi).
class Customer {
  const Customer({
    required this.id,
    required this.companyId,
    required this.name,
    this.type = CustomerType.individual,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String name;
  final CustomerType type;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      type: CustomerTypeExt.fromString(json['type'] as String? ?? 'individual'),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class CreateCustomerInput {
  const CreateCustomerInput({
    required this.companyId,
    required this.name,
    this.type = CustomerType.individual,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });
  final String companyId;
  final String name;
  final CustomerType type;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}

class UpdateCustomerInput {
  const UpdateCustomerInput({
    this.name,
    this.type,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });
  final String? name;
  final CustomerType? type;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}

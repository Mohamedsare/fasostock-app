import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';

/// Clients — même API que customersApi (web).
class CustomersRepository {
  CustomersRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _fields = 'id, company_id, name, type, phone, email, address, notes, created_at, updated_at';

  Future<List<Customer>> list(String companyId) async {
    final data = await _client.from('customers').select(_fields).eq('company_id', companyId).order('name');
    return (data as List).map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Customer?> get(String id) async {
    final data = await _client.from('customers').select(_fields).eq('id', id).maybeSingle();
    return data != null ? Customer.fromJson(Map<String, dynamic>.from(data as Map)) : null;
  }

  Future<Customer> create(CreateCustomerInput input) async {
    final data = await _client.from('customers').insert({
      'company_id': input.companyId,
      'name': input.name,
      'type': input.type.value,
      'phone': input.phone,
      'email': input.email,
      'address': input.address,
      'notes': input.notes,
    }).select(_fields).single();
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Customer> update(String id, UpdateCustomerInput input) async {
    final patch = <String, dynamic>{};
    if (input.name != null) patch['name'] = input.name;
    if (input.type != null) patch['type'] = input.type!.value;
    if (input.phone != null) patch['phone'] = input.phone;
    if (input.email != null) patch['email'] = input.email;
    if (input.address != null) patch['address'] = input.address;
    if (input.notes != null) patch['notes'] = input.notes;
    final data = await _client.from('customers').update(patch).eq('id', id).select(_fields).single();
    return Customer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }
}

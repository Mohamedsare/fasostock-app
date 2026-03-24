import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier.dart';

/// Fournisseurs — aligné web (list + create via insert).
class SuppliersRepository {
  SuppliersRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _fields = 'id, company_id, name, contact, phone, email, address, notes';

  Future<List<Supplier>> list(String companyId) async {
    final data = await _client
        .from('suppliers')
        .select(_fields)
        .eq('company_id', companyId)
        .order('name');
    final list = data as List;
    return list.map((e) => Supplier.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Supplier> create(String companyId, {
    required String name,
    String? contact,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final res = await _client.from('suppliers').insert({
      'company_id': companyId,
      'name': name,
      'contact': contact,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
    }).select(_fields).single();
    return Supplier.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Supplier> update(String id, Map<String, dynamic> patch) async {
    final res = await _client.from('suppliers').update(patch).eq('id', id).select(_fields).single();
    return Supplier.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> delete(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
  }
}

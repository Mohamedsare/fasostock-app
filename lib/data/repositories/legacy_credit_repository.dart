import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legacy_credit.dart';

class LegacyCreditRepository {
  LegacyCreditRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _select =
      'id, company_id, store_id, customer_id, title, principal_amount, due_at, internal_note, created_by, created_at, updated_at, store:stores(id,name), customer:customers(id,name,phone), payments:legacy_customer_credit_payments(id, method, amount, reference, created_at)';

  Future<List<LegacyCreditRow>> list({
    required String companyId,
    String? storeId,
    required String fromYmd,
    required String toYmd,
  }) async {
    var q = _client
        .from('legacy_customer_credits')
        .select(_select)
        .eq('company_id', companyId);
    if (storeId != null && storeId.isNotEmpty) q = q.eq('store_id', storeId);
    if (fromYmd.isNotEmpty) q = q.gte('created_at', '${fromYmd}T00:00:00.000Z');
    if (toYmd.isNotEmpty) q = q.lte('created_at', '${toYmd}T23:59:59.999Z');
    final data = await q.order('created_at', ascending: false);
    return (data as List)
        .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> create({
    required String companyId,
    required String storeId,
    required String customerId,
    required String title,
    required double amount,
    String? dueAtIso,
    String? internalNote,
  }) async {
    await _client.rpc('owner_create_legacy_customer_credit', params: {
      'p_company_id': companyId,
      'p_store_id': storeId,
      'p_customer_id': customerId,
      'p_title': title,
      'p_amount': amount,
      'p_due_at': dueAtIso,
      'p_internal_note': internalNote,
    });
  }

  Future<void> appendPayment({
    required String creditId,
    required String method,
    required double amount,
    String? reference,
  }) async {
    await _client.rpc('append_legacy_customer_credit_payment', params: {
      'p_credit_id': creditId,
      'p_method': method,
      'p_amount': amount,
      'p_reference': reference,
    });
  }

  Future<void> delete({required String creditId}) async {
    await _client.from('legacy_customer_credits').delete().eq('id', creditId);
  }

  LegacyCreditRow _fromJson(Map<String, dynamic> row) {
    final storeRaw = row['store'];
    final customerRaw = row['customer'];
    final store = storeRaw is List
        ? (storeRaw.isEmpty ? null : Map<String, dynamic>.from(storeRaw.first as Map))
        : (storeRaw is Map ? Map<String, dynamic>.from(storeRaw) : null);
    final customer = customerRaw is List
        ? (customerRaw.isEmpty
            ? null
            : Map<String, dynamic>.from(customerRaw.first as Map))
        : (customerRaw is Map ? Map<String, dynamic>.from(customerRaw) : null);
    final paymentsRaw = row['payments'];
    final payments = paymentsRaw is List
        ? paymentsRaw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map(
              (p) => LegacyCreditPayment(
                id: (p['id'] ?? '').toString(),
                method: (p['method'] ?? '').toString(),
                amount: (p['amount'] as num?)?.toDouble() ?? 0,
                reference: p['reference'] as String?,
                createdAt: (p['created_at'] ?? '').toString(),
              ),
            )
            .toList()
        : const <LegacyCreditPayment>[];
    return LegacyCreditRow(
      id: (row['id'] ?? '').toString(),
      companyId: (row['company_id'] ?? '').toString(),
      storeId: (row['store_id'] ?? '').toString(),
      customerId: (row['customer_id'] ?? '').toString(),
      title: (row['title'] ?? 'Crédit libre').toString(),
      principalAmount: (row['principal_amount'] as num?)?.toDouble() ?? 0,
      dueAt: row['due_at'] as String?,
      internalNote: row['internal_note'] as String?,
      createdBy: (row['created_by'] ?? '').toString(),
      createdAt: (row['created_at'] ?? '').toString(),
      updatedAt: (row['updated_at'] ?? '').toString(),
      storeName: store?['name'] as String?,
      customerName: customer?['name'] as String?,
      customerPhone: customer?['phone'] as String?,
      payments: payments,
    );
  }
}

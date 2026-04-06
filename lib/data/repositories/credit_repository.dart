import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../models/sale.dart';
import 'sales_repository.dart';

/// Crédit / créances — aligné `appweb/lib/features/credit/api.ts`.
class CreditRepository {
  CreditRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _creditListSelect =
      'id, company_id, store_id, customer_id, sale_number, status, subtotal, discount, tax, total, created_by, created_at, updated_at, sale_mode, document_type, credit_due_at, credit_internal_note, store:stores(id, name), customer:customers(id, name, phone), sale_payments(id, method, amount, reference, created_at)';

  static const _creditDetailSelect =
      'id, company_id, store_id, customer_id, sale_number, status, subtotal, discount, tax, total, created_by, created_at, updated_at, sale_mode, document_type, credit_due_at, credit_internal_note, store:stores(id, name), customer:customers(id, name, phone, address), sale_items(id, sale_id, product_id, quantity, unit_price, discount, total, product:products(id,name,sku,unit)), sale_payments(id, method, amount, reference, created_at)';

  Map<String, dynamic>? _singleOrList(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      if (raw.isEmpty) return null;
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Sale _parseListRow(Map<String, dynamic> row, String? creatorLabel) {
    final storeMap = _singleOrList(row['store']);
    final customerMap = _singleOrList(row['customer']);
    final payRaw = row['sale_payments'];
    List<SalePayment>? payments;
    if (payRaw is List) {
      payments = payRaw.map((e) => SalePayment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    return Sale(
      id: row['id'] as String,
      companyId: row['company_id'] as String,
      storeId: row['store_id'] as String,
      customerId: row['customer_id'] as String?,
      saleNumber: row['sale_number'] as String,
      status: SaleStatusExt.fromString(row['status'] as String? ?? 'draft'),
      subtotal: _d(row['subtotal']),
      discount: _d(row['discount']),
      tax: _d(row['tax']),
      total: _d(row['total']),
      createdBy: row['created_by'] as String,
      createdAt: row['created_at'] as String,
      updatedAt: row['updated_at'] as String,
      store: storeMap != null ? StoreRef.fromJson(storeMap) : null,
      customer: customerMap != null ? CustomerRef.fromJson(customerMap) : null,
      saleItems: null,
      salePayments: payments,
      saleMode: row['sale_mode'] != null ? SaleMode.fromString(row['sale_mode'] as String) : null,
      documentType: row['document_type'] != null ? DocumentType.fromString(row['document_type'] as String) : null,
      createdByLabel: creatorLabel,
      creditDueAt: row['credit_due_at'] as String?,
      creditInternalNote: row['credit_internal_note'] as String?,
    );
  }

  static double _d(dynamic v) => (v is num) ? v.toDouble() : 0;

  Future<Map<String, String>> _fetchCreatorLabels(List<String> userIds) async {
    final map = <String, String>{};
    final uniq = userIds.toSet().where((id) => id.isNotEmpty).toList();
    String fallback(String id) =>
        id.length >= 8 ? 'Utilisateur ${id.substring(0, 8)}…' : 'Utilisateur';
    for (final id in uniq) {
      map[id] = fallback(id);
    }
    const chunkSize = 120;
    for (var i = 0; i < uniq.length; i += chunkSize) {
      final chunk = uniq.sublist(i, i + chunkSize > uniq.length ? uniq.length : i + chunkSize);
      try {
        final data = await _client.from('profiles').select('id, full_name').inFilter('id', chunk);
        for (final p in data as List) {
          final m = Map<String, dynamic>.from(p as Map);
          final id = m['id'] as String?;
          final fn = (m['full_name'] as String?)?.trim();
          if (id != null) {
            map[id] = (fn != null && fn.isNotEmpty) ? fn : fallback(id);
          }
        }
      } catch (_) {}
    }
    return map;
  }

  static Map<String, dynamic> _normalizeEmbeddedSaleItemJson(
    Map<String, dynamic> raw,
    String fallbackSaleId,
  ) {
    final m = Map<String, dynamic>.from(raw);
    if (m['sale_id'] == null || (m['sale_id'] is String && (m['sale_id'] as String).isEmpty)) {
      m['sale_id'] = fallbackSaleId;
    }
    final pr = m['product'];
    if (pr is List) {
      if (pr.isEmpty) {
        m['product'] = null;
      } else {
        final pr0 = pr.first;
        m['product'] = pr0 is Map ? Map<String, dynamic>.from(pr0) : null;
      }
    }
    if (m['product'] is Map) {
      final pm = Map<String, dynamic>.from(m['product'] as Map);
      if (pm['name'] == null || (pm['name'] is String && (pm['name'] as String).isEmpty)) {
        pm['name'] = 'Produit';
      }
      m['product'] = pm;
    }
    return m;
  }

  Future<List<Sale>> listCreditSales({
    required String companyId,
    String? storeId,
    required String fromUtc,
    required String toDate,
  }) async {
    var q = _client
        .from('sales')
        .select(_creditListSelect)
        .eq('company_id', companyId)
        .eq('status', SaleStatus.completed.value)
        .not('customer_id', 'is', null);
    if (storeId != null && storeId.isNotEmpty) {
      q = q.eq('store_id', storeId);
    }
    if (fromUtc.isNotEmpty) q = q.gte('created_at', fromUtc);
    final data = await q.lte('created_at', '${toDate}T23:59:59.999Z').order('created_at', ascending: false);
    final rows = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final creatorIds = rows.map((r) => r['created_by'] as String).toList();
    final labels = await _fetchCreatorLabels(creatorIds);
    return rows.map((r) {
      final uid = r['created_by'] as String;
      return _parseListRow(r, labels[uid]);
    }).toList();
  }

  Future<Sale?> fetchCreditSaleDetail(String saleId) async {
    try {
      return await _fetchCreditSaleDetailEmbedded(saleId);
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      try {
        return await _fetchCreditSaleDetailViaListAndItems(saleId);
      } catch (e2, st2) {
        AppErrorHandler.log(e2, st2);
        rethrow;
      }
    }
  }

  Future<Sale?> _fetchCreditSaleDetailEmbedded(String saleId) async {
    final data = await _client.from('sales').select(_creditDetailSelect).eq('id', saleId).maybeSingle();
    if (data == null) return null;
    final row = Map<String, dynamic>.from(data as Map);
    final itemsRaw = row.remove('sale_items');
    final uid = row['created_by'] as String;
    final creatorLabels = await _fetchCreatorLabels([uid]);
    final sale = _parseListRow(row, creatorLabels[uid]);
    List<SaleItem>? items;
    if (itemsRaw is List) {
      items = itemsRaw.map((e) {
        final m = _normalizeEmbeddedSaleItemJson(Map<String, dynamic>.from(e as Map), sale.id);
        return SaleItem.fromJson(m);
      }).toList();
    }
    return Sale(
      id: sale.id,
      companyId: sale.companyId,
      storeId: sale.storeId,
      customerId: sale.customerId,
      saleNumber: sale.saleNumber,
      status: sale.status,
      subtotal: sale.subtotal,
      discount: sale.discount,
      tax: sale.tax,
      total: sale.total,
      createdBy: sale.createdBy,
      createdAt: sale.createdAt,
      updatedAt: sale.updatedAt,
      store: sale.store,
      customer: sale.customer,
      saleItems: items,
      salePayments: sale.salePayments,
      saleMode: sale.saleMode,
      documentType: sale.documentType,
      createdByLabel: sale.createdByLabel,
      creditDueAt: sale.creditDueAt,
      creditInternalNote: sale.creditInternalNote,
    );
  }

  /// Si le select imbriqué échoue (RLS, schéma, etc.) : même projection que la liste + `sale_items` en requête dédiée.
  Future<Sale?> _fetchCreditSaleDetailViaListAndItems(String saleId) async {
    final data = await _client.from('sales').select(_creditListSelect).eq('id', saleId).maybeSingle();
    if (data == null) return null;
    final row = Map<String, dynamic>.from(data as Map);
    final uid = row['created_by'] as String;
    final creatorLabels = await _fetchCreatorLabels([uid]);
    final sale = _parseListRow(row, creatorLabels[uid]);
    final items = await SalesRepository(_client).getItems(saleId);
    return Sale(
      id: sale.id,
      companyId: sale.companyId,
      storeId: sale.storeId,
      customerId: sale.customerId,
      saleNumber: sale.saleNumber,
      status: sale.status,
      subtotal: sale.subtotal,
      discount: sale.discount,
      tax: sale.tax,
      total: sale.total,
      createdBy: sale.createdBy,
      createdAt: sale.createdAt,
      updatedAt: sale.updatedAt,
      store: sale.store,
      customer: sale.customer,
      saleItems: items,
      salePayments: sale.salePayments,
      saleMode: sale.saleMode,
      documentType: sale.documentType,
      createdByLabel: sale.createdByLabel,
      creditDueAt: sale.creditDueAt,
      creditInternalNote: sale.creditInternalNote,
    );
  }

  Future<void> appendSalePayment({
    required String saleId,
    required PaymentMethod method,
    required double amount,
    String? reference,
  }) async {
    await _client.rpc('append_sale_payment', params: {
      'p_sale_id': saleId,
      'p_method': method.value,
      'p_amount': amount,
      'p_reference': reference,
    });
  }

  Future<void> updateSaleCreditMeta({
    required String saleId,
    String? creditDueAtIso,
    String? creditInternalNote,
  }) async {
    await _client.from('sales').update({
      'credit_due_at': creditDueAtIso,
      'credit_internal_note': (creditInternalNote?.trim().isEmpty ?? true) ? null : creditInternalNote!.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', saleId);
  }
}

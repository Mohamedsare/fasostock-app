import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sale.dart';
import '../../core/utils/client_request_id.dart';

/// Ventes — même API que salesApi (web).
class SalesRepository {
  SalesRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _saleSelect =
      'id, company_id, store_id, customer_id, sale_number, status, subtotal, discount, tax, total, created_by, created_at, updated_at, sale_mode, document_type, credit_due_at, credit_internal_note, store:stores(id, name), customer:customers(id, name, phone)';

  Future<List<Sale>> list(
    String companyId, {
    String? storeId,
    SaleStatus? status,
    String? fromDate,
    String? toDate,
    int? limit,
  }) async {
    var q = _client
        .from('sales')
        .select(_saleSelect)
        .eq('company_id', companyId);
    if (storeId != null) q = q.eq('store_id', storeId);
    if (status != null) q = q.eq('status', status.value);
    if (fromDate != null) q = q.gte('created_at', fromDate);
    if (toDate != null) q = q.lte('created_at', '${toDate}T23:59:59.999Z');
    var ordered = q.order('created_at', ascending: false);
    if (limit != null && limit > 0) ordered = ordered.limit(limit);
    final data = await ordered;
    return (data as List)
        .map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Sale?> get(String id) async {
    final data = await _client
        .from('sales')
        .select(_saleSelect)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    final sale = Sale.fromJson(Map<String, dynamic>.from(data as Map));
    final items = await getItems(id);
    final payments = await getPayments(id);
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
      salePayments: payments,
      saleMode: sale.saleMode,
      documentType: sale.documentType,
      createdByLabel: sale.createdByLabel,
      creditDueAt: sale.creditDueAt,
      creditInternalNote: sale.creditInternalNote,
    );
  }

  Future<List<SaleItem>> getItems(String saleId) async {
    final data = await _client
        .from('sale_items')
        .select(
          'id, sale_id, product_id, quantity, unit_price, discount, total, product:products(id, name, sku, unit)',
        )
        .eq('sale_id', saleId)
        .order('created_at');
    return (data as List)
        .map((e) => SaleItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<SalePayment>> getPayments(String saleId) async {
    final data = await _client
        .from('sale_payments')
        .select('id, sale_id, method, amount, reference, created_at')
        .eq('sale_id', saleId);
    return (data as List)
        .map((e) => SalePayment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// RPC create_sale_with_stock — retourne l'id de la vente créée.
  /// sale_mode et document_type (dual-POS) sont optionnels côté API (défaut quick_pos / thermal_receipt).
  Future<Sale> create(CreateSaleInput input, String userId) async {
    final payload = {
      'p_company_id': input.companyId,
      'p_store_id': input.storeId,
      'p_customer_id': input.customerId,
      'p_created_by': userId,
      'p_items': input.items
          .map(
            (i) => {
              'product_id': i.productId,
              'quantity': i.quantity,
              'unit_price': i.unitPrice,
              'discount': i.discount,
            },
          )
          .toList(),
      'p_payments': input.payments
          .map(
            (p) => {
              'method': p.method.value,
              'amount': p.amount,
              'reference': p.reference,
            },
          )
          .toList(),
      'p_discount': input.discount,
      'p_sale_mode': input.saleMode.value,
      'p_document_type': input.documentType.value,
      // Permet de lever toute ambiguïté si la DB a deux overloads (avec/sans idempotence).
      'p_client_request_id': newClientRequestId(),
    };
    dynamic res;
    try {
      res = await _client.rpc('create_sale_with_stock', params: payload);
    } catch (e) {
      // Si l'overload avec p_client_request_id n'existe pas, retenter sans cette clé.
      final msg = e.toString();
      if (msg.contains('create_sale_with_stock') &&
          msg.contains('PGRST202') &&
          msg.contains('p_client_request_id')) {
        final payload2 = Map<String, dynamic>.from(payload)
          ..remove('p_client_request_id');
        res = await _client.rpc('create_sale_with_stock', params: payload2);
      } else {
        rethrow;
      }
    }
    if (res == null) throw Exception('create_sale_with_stock a retourné null');
    final saleId = res as String;
    final sale = await get(saleId);
    if (sale == null) throw Exception('Vente créée mais introuvable');
    return sale;
  }

  Future<void> cancel(String id) async {
    await _client.rpc('cancel_sale_restore_stock', params: {'p_sale_id': id});
  }

  /// Propriétaire uniquement (`owner_purge_cancelled_sale`) — retire définitivement une vente déjà annulée.
  Future<void> purgeCancelledAsOwner({
    required String companyId,
    required String saleNumber,
  }) async {
    await _client.rpc(
      'owner_purge_cancelled_sale',
      params: {'p_company_id': companyId, 'p_sale_number': saleNumber.trim()},
    );
  }

  /// RPC update_completed_sale_with_stock — remplace lignes et paiements, recalcule le stock.
  Future<Sale> updateCompleted({
    required String saleId,
    required String? customerId,
    required List<CreateSaleItemInput> items,
    required List<CreateSalePaymentInput> payments,
    double discount = 0,
    SaleMode? saleMode,
    DocumentType? documentType,
  }) async {
    await _client.rpc(
      'update_completed_sale_with_stock',
      params: {
        'p_sale_id': saleId,
        'p_customer_id': customerId,
        'p_items': items
            .map(
              (i) => {
                'product_id': i.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
                'discount': i.discount,
              },
            )
            .toList(),
        'p_payments': payments
            .map(
              (p) => {
                'method': p.method.value,
                'amount': p.amount,
                'reference': p.reference,
              },
            )
            .toList(),
        'p_discount': discount,
        'p_sale_mode': saleMode?.value,
        'p_document_type': documentType?.value,
      },
    );
    final sale = await get(saleId);
    if (sale == null) throw Exception('Vente introuvable après modification');
    return sale;
  }
}

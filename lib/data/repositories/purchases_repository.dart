import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase.dart';

/// Achats — même API que purchasesApi (web).
class PurchasesRepository {
  PurchasesRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _purchaseSelect =
      'id, company_id, store_id, supplier_id, reference, status, total, created_by, created_at, updated_at, store:stores(id, name), supplier:suppliers(id, name, phone)';

  Future<List<Purchase>> list(
    String companyId, {
    String? storeId,
    String? supplierId,
    PurchaseStatus? status,
    String? fromDate,
    String? toDate,
  }) async {
    var q = _client.from('purchases').select(_purchaseSelect).eq('company_id', companyId);
    if (storeId != null) q = q.eq('store_id', storeId);
    if (supplierId != null) q = q.eq('supplier_id', supplierId);
    if (status != null) q = q.eq('status', status.value);
    if (fromDate != null) q = q.gte('created_at', fromDate);
    if (toDate != null) q = q.lte('created_at', '${toDate}T23:59:59.999Z');
    final data = await q.order('created_at', ascending: false);
    return (data as List).map((e) => Purchase.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Purchase?> get(String id) async {
    final data = await _client.from('purchases').select(_purchaseSelect).eq('id', id).maybeSingle();
    if (data == null) return null;
    final purchase = Purchase.fromJson(Map<String, dynamic>.from(data as Map));
    final items = await getItems(id);
    final payments = await getPayments(id);
    return Purchase(
      id: purchase.id,
      companyId: purchase.companyId,
      storeId: purchase.storeId,
      supplierId: purchase.supplierId,
      reference: purchase.reference,
      status: purchase.status,
      total: purchase.total,
      createdBy: purchase.createdBy,
      createdAt: purchase.createdAt,
      updatedAt: purchase.updatedAt,
      store: purchase.store,
      supplier: purchase.supplier,
      purchaseItems: items,
      purchasePayments: payments,
    );
  }

  Future<List<PurchaseItem>> getItems(String purchaseId) async {
    final data = await _client
        .from('purchase_items')
        .select('id, purchase_id, product_id, quantity, unit_price, total, product:products(id, name, sku, unit)')
        .eq('purchase_id', purchaseId);
    final list = data as List?;
    if (list == null) return [];
    return list.map((e) => PurchaseItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Récupère les lignes d'achat pour plusieurs achats en une requête (sync offline).
  Future<List<PurchaseItem>> getItemsForPurchaseIds(List<String> purchaseIds) async {
    if (purchaseIds.isEmpty) return [];
    final data = await _client
        .from('purchase_items')
        .select('id, purchase_id, product_id, quantity, unit_price, total')
        .inFilter('purchase_id', purchaseIds);
    final list = data as List?;
    if (list == null) return [];
    return list.map((e) => PurchaseItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<PurchasePayment>> getPayments(String purchaseId) async {
    final data = await _client.from('purchase_payments').select('id, purchase_id, amount, method, paid_at').eq('purchase_id', purchaseId);
    final list = data as List?;
    if (list == null) return [];
    return list.map((e) => PurchasePayment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Purchase> create(CreatePurchaseInput input, String userId) async {
    final total = input.items.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);
    final reference = input.reference?.trim().isNotEmpty == true ? input.reference! : 'A-${DateTime.now().millisecondsSinceEpoch}';
    final purchaseData = await _client.from('purchases').insert({
      'company_id': input.companyId,
      'store_id': input.storeId,
      'supplier_id': input.supplierId,
      'reference': reference,
      'status': 'draft',
      'total': total,
      'created_by': userId,
    }).select().single();
    final purchase = Purchase.fromJson(Map<String, dynamic>.from(purchaseData as Map));
    final items = input.items.map((i) => {
      'purchase_id': purchase.id,
      'product_id': i.productId,
      'quantity': i.quantity,
      'unit_price': i.unitPrice,
      'total': i.quantity * i.unitPrice,
    }).toList();
    await _client.from('purchase_items').insert(items);
    if (input.payments != null && input.payments!.isNotEmpty) {
      await _client.from('purchase_payments').insert(input.payments!.map((p) => {
        'purchase_id': purchase.id,
        'amount': p.amount,
        'method': p.method.name,
      }).toList());
    }
    final full = await get(purchase.id);
    return full ?? purchase;
  }

  Future<void> confirm(String id, String userId) async {
    await _client.rpc('confirm_purchase_with_stock', params: {'p_purchase_id': id, 'p_created_by': userId});
  }

  Future<void> cancel(String id) async {
    final p = await get(id);
    if (p == null || p.status != PurchaseStatus.draft) throw Exception('Seuls les brouillons peuvent être annulés');
    await _client.from('purchases').update({'status': 'cancelled'}).eq('id', id);
  }

  /// Met à jour un achat brouillon (référence et/ou lignes).
  Future<Purchase> update(String id, {String? reference, List<CreatePurchaseItemInput>? items}) async {
    final p = await get(id);
    if (p == null || p.status != PurchaseStatus.draft) throw Exception('Seuls les brouillons peuvent être modifiés');
    double? newTotal;
    if (items != null) {
      newTotal = items.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);
      await _client.from('purchase_items').delete().eq('purchase_id', id);
      if (items.isNotEmpty) {
        await _client.from('purchase_items').insert(
          items.map((i) => {
            'purchase_id': id,
            'product_id': i.productId,
            'quantity': i.quantity,
            'unit_price': i.unitPrice,
            'total': i.quantity * i.unitPrice,
          }).toList(),
        );
      }
    }
    final Map<String, Object> patch = {};
    if (reference != null) patch['reference'] = reference;
    if (newTotal != null) patch['total'] = newTotal;
    if (patch.isNotEmpty) {
      await _client.from('purchases').update(patch).eq('id', id);
    }
    final updated = await get(id);
    return updated ?? p;
  }

  /// Supprime un achat brouillon (et ses lignes / paiements).
  Future<void> delete(String id) async {
    final p = await get(id);
    if (p == null || p.status != PurchaseStatus.draft) throw Exception('Seuls les brouillons peuvent être supprimés');
    await _client.from('purchases').delete().eq('id', id);
  }
}

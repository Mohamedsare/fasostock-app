import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory.dart';
import 'products_repository.dart';

/// Stock / inventaire — même logique que inventoryApi (web).
class InventoryRepository {
  InventoryRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client,
        _products = ProductsRepository(client);

  final SupabaseClient _client;
  final ProductsRepository _products;

  Future<Map<String, int?>> getStoreStockMinOverrides(String storeId) async {
    final data = await _client
        .from('product_store_settings')
        .select('product_id, stock_min_override')
        .eq('store_id', storeId);
    final out = <String, int?>{};
    for (final row in data as List) {
      final m = row as Map;
      final pid = m['product_id'] as String?;
      if (pid != null) out[pid] = (m['stock_min_override'] as num?)?.toInt();
    }
    return out;
  }

  Future<Map<String, int>> getStockByStore(String storeId) async {
    final data = await _client.from('store_inventory').select('product_id, quantity').eq('store_id', storeId);
    final out = <String, int>{};
    for (final row in data as List) {
      final m = row as Map;
      final pid = m['product_id'] as String?;
      final q = (m['quantity'] as num?)?.toInt();
      if (pid != null && q != null) out[pid] = q;
    }
    return out;
  }

  Future<List<InventoryItem>> list(
    String companyId,
    String storeId, {
    String? search,
    String? categoryId,
    String? status,
  }) async {
    final products = await _products.list(companyId);
    final invData = await _client
        .from('store_inventory')
        .select('id, store_id, product_id, quantity, reserved_quantity, updated_at')
        .eq('store_id', storeId);
    final invMap = <String, Map<String, dynamic>>{};
    // Garde-fou : Supabase peut renvoyer null en cas d'erreur.
    final invList = invData as List?;
    if (invList != null) {
      for (final r in invList) {
        final m = Map<String, dynamic>.from(r as Map);
        final pid = m['product_id'] as String?;
        if (pid != null) invMap[pid] = m;
      }
    }
    final items = <InventoryItem>[];
    for (final p in products) {
      final inv = invMap[p.id];
      final quantity = (inv?['quantity'] as num?)?.toInt() ?? 0;
      final reserved = (inv?['reserved_quantity'] as num?)?.toInt() ?? 0;
      final item = InventoryItem(
        id: inv?['id'] as String? ?? 'temp-${p.id}',
        storeId: storeId,
        productId: p.id,
        quantity: quantity,
        reservedQuantity: reserved,
        updatedAt: inv?['updated_at'] as String? ?? DateTime.now().toUtc().toIso8601String(),
        product: InventoryProductRef(
          id: p.id,
          name: p.name,
          sku: p.sku,
          barcode: p.barcode,
          unit: p.unit,
          salePrice: p.salePrice,
          stockMin: p.stockMin,
          productImages: p.productImages?.map((i) => ImageUrlRef(url: i.url)).toList(),
        ),
      );
      if (search != null && search.isNotEmpty) {
        final s = search.toLowerCase();
        if (!p.name.toLowerCase().contains(s) &&
            !(p.sku?.toLowerCase().contains(s) ?? false) &&
            !(p.barcode?.contains(search) ?? false)) continue;
      }
      if (categoryId != null && p.categoryId != categoryId) continue;
      if (status == 'low' && (p.stockMin <= 0 || quantity > p.stockMin)) continue;
      if (status == 'out' && quantity > 0) continue;
      items.add(item);
    }
    items.sort((a, b) => (a.product?.name ?? '').compareTo(b.product?.name ?? ''));
    return items;
  }

  Future<List<StockMovement>> getMovements(String storeId, {String? productId, int limit = 50}) async {
    var q = _client
        .from('stock_movements')
        .select('id, store_id, product_id, type, quantity, reference_type, reference_id, created_by, created_at, notes, product:products(id, name, sku, unit)')
        .eq('store_id', storeId);
    if (productId != null) q = q.eq('product_id', productId);
    final data = await q.order('created_at', ascending: false).limit(limit);
    return (data as List).map((e) => StockMovement.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> adjust(String storeId, String productId, int delta, String reason, String userId) async {
    await _client.rpc('inventory_adjust_atomic', params: {
      'p_store_id': storeId,
      'p_product_id': productId,
      'p_delta': delta,
      'p_reason': reason.isNotEmpty ? reason : 'Ajustement manuel',
      'p_created_by': userId,
    });
  }
}

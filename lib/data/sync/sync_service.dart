import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/local_db.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../repositories/products_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/customers_repository.dart';
import '../repositories/stores_repository.dart';

/// Synchronisation en arrière-plan : clients en attente, ventes en attente, ajustements stock, puis rafraîchit les caches.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final LocalDb _db = LocalDb.instance;
  final ProductsRepository _productsRepo = ProductsRepository();
  final InventoryRepository _inventoryRepo = InventoryRepository();
  final CustomersRepository _customersRepo = CustomersRepository();
  final StoresRepository _storesRepo = StoresRepository();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  static const String _pendingCustomerPrefix = 'pending:';

  /// 1) Crée les clients en attente (map local_id -> real_id).
  /// 2) Envoie les ventes en attente (p_customer_id "pending:xxx" remplacé par l'id réel).
  /// 3) Applique les ajustements de stock en attente.
  /// 4) Rafraîchit les caches.
  Future<SyncResult> sync({
    required String userId,
    required String? companyId,
    required String? storeId,
  }) async {
    if (_isSyncing) return SyncResult(sent: 0, errors: 0);
    _isSyncing = true;
    int sent = 0;
    int errors = 0;
    try {
      final customerIdMap = await _syncPendingCustomers();
      final client = Supabase.instance.client;
      final pendingSales = await _db.getPendingSales();
      for (final item in pendingSales) {
        final id = item['id'] as String?;
        final payload = item['payload'] as Map<String, dynamic>?;
        if (id == null || payload == null) continue;
        try {
          final p = Map<String, dynamic>.from(payload);
          final customerId = p['p_customer_id'];
          if (customerId is String && customerId.startsWith(_pendingCustomerPrefix)) {
            final realId = customerIdMap[customerId];
            p['p_customer_id'] = realId;
          }
          await client.rpc('create_sale_with_stock', params: p);
          await _db.removePendingSale(id);
          sent++;
        } catch (_) {
          errors++;
        }
      }
      await _syncPendingStockAdjustments(userId);
      if (companyId != null) {
        await _refreshCaches(companyId, storeId);
      }
      return SyncResult(sent: sent, errors: errors);
    } finally {
      _isSyncing = false;
    }
  }

  Future<Map<String, String>> _syncPendingCustomers() async {
    final map = <String, String>{};
    final pending = await _db.getPendingCustomers();
    for (final row in pending) {
      final localId = row['local_id'] as String?;
      final companyId = row['company_id'] as String?;
      final name = row['name'] as String?;
      if (localId == null || companyId == null || name == null) continue;
      try {
        final type = row['type'] as String? ?? 'individual';
        final customer = await _customersRepo.create(CreateCustomerInput(
          companyId: companyId,
          name: name,
          type: type == 'company' ? CustomerType.company : CustomerType.individual,
          phone: row['phone'] as String?,
        ));
        map[_pendingCustomerPrefix + localId] = customer.id;
        await _db.removePendingCustomer(localId);
      } catch (_) {}
    }
    return map;
  }

  Future<void> _syncPendingStockAdjustments(String userId) async {
    final pending = await _db.getPendingStockAdjustments();
    for (final row in pending) {
      final id = row['id'] as String?;
      final storeId = row['store_id'] as String?;
      final productId = row['product_id'] as String?;
      final delta = row['delta'];
      final reason = row['reason'] as String? ?? 'Ajustement (sync hors ligne)';
      final uid = row['user_id'] as String? ?? userId;
      if (id == null || storeId == null || productId == null || delta == null) continue;
      final deltaInt = delta is int ? delta : (delta as num).toInt();
      try {
        await _inventoryRepo.adjust(storeId, productId, deltaInt, reason, uid);
        await _db.removePendingStockAdjustment(id);
      } catch (_) {}
    }
  }

  Future<void> _refreshCaches(String companyId, String? storeId) async {
    try {
      final products = await _productsRepo.list(companyId);
      final productMaps = products.map((p) => _productToJson(p)).toList();
      await _db.saveProducts(companyId, productMaps);
    } catch (_) {}
    if (storeId != null) {
      try {
        final stock = await _inventoryRepo.getStockByStore(storeId);
        await _db.saveInventory(storeId, stock);
      } catch (_) {}
    }
    try {
      final customers = await _customersRepo.list(companyId);
      final customerMaps = customers.map(_customerToJson).toList();
      await _db.saveCustomers(companyId, customerMaps);
    } catch (_) {}
    try {
      final stores = await _storesRepo.getStoresByCompany(companyId);
      final storeMaps = stores.map((s) => s.toJson()).toList();
      await _db.saveStores(companyId, storeMaps);
    } catch (_) {}
  }

  static Map<String, dynamic> _productToJson(Product p) {
    return {
      'id': p.id,
      'company_id': p.companyId,
      'name': p.name,
      'sku': p.sku,
      'barcode': p.barcode,
      'unit': p.unit,
      'purchase_price': p.purchasePrice,
      'sale_price': p.salePrice,
      'min_price': p.minPrice,
      'stock_min': p.stockMin,
      'description': p.description,
      'is_active': p.isActive,
      'category_id': p.categoryId,
      'brand_id': p.brandId,
    };
  }

  static Map<String, dynamic> _customerToJson(Customer c) {
    return {
      'id': c.id,
      'company_id': c.companyId,
      'name': c.name,
      'type': c.type.value,
      'phone': c.phone,
      'email': c.email,
      'address': c.address,
      'notes': c.notes,
      'created_at': c.createdAt,
      'updated_at': c.updatedAt,
    };
  }
}

class SyncResult {
  const SyncResult({required this.sent, required this.errors});
  final int sent;
  final int errors;
}

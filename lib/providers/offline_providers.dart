import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/drift/app_database.dart';
import '../data/models/customer.dart';
import '../data/models/product.dart';
import '../data/models/sale.dart';
import '../data/models/store.dart';
import '../data/repositories/products_repository.dart';
import '../data/models/brand.dart';
import '../data/models/category.dart';
import '../data/models/purchase.dart';
import '../data/models/inventory.dart';
import '../data/models/stock_transfer.dart';
import '../data/models/supplier.dart';
import '../data/models/warehouse_movement.dart';
import '../data/models/warehouse_stock_line.dart';
import '../data/repositories/offline/brands_offline_repository.dart';
import '../data/repositories/offline/categories_offline_repository.dart';
import '../data/repositories/offline/customers_offline_repository.dart';
import '../data/repositories/offline/products_offline_repository.dart';
import '../data/repositories/offline/sales_offline_repository.dart';
import '../data/repositories/offline/stores_offline_repository.dart';
import '../data/repositories/offline/purchases_offline_repository.dart';
import '../data/repositories/offline/suppliers_offline_repository.dart';
import '../data/repositories/offline/transfers_offline_repository.dart';
import '../data/repositories/offline/warehouse_offline_repository.dart';
import '../data/repositories/warehouse_dispatch_input.dart';
import '../data/repositories/offline/dashboard_offline_repository.dart';
import '../data/repositories/offline/company_members_offline_repository.dart';
import '../data/repositories/offline/reports_offline_repository.dart';
import '../data/repositories/credit_sync_facade.dart';
import '../data/models/company_member.dart';
import '../data/sync/sync_service_v2.dart';

/// App database — single instance for offline-first storage.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Offline-first products repository (reads from Drift, sync writes from Supabase).
final productsOfflineRepositoryProvider = Provider<ProductsOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProductsOfflineRepository(db, ProductsRepository());
});

final customersOfflineRepositoryProvider = Provider<CustomersOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomersOfflineRepository(db);
});

final salesOfflineRepositoryProvider = Provider<SalesOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SalesOfflineRepository(db);
});

/// Crédit : mutations offline-first + même lecture locale que les ventes.
final creditSyncFacadeProvider = Provider<CreditSyncFacade>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final offline = ref.watch(salesOfflineRepositoryProvider);
  return CreditSyncFacade(db, offline);
});

/// Ventes « éligibles crédit » depuis Drift : complété + client + plage de dates (stream réactif paiements inclus).
final creditSalesFilteredStreamProvider =
    StreamProvider.autoDispose.family<List<Sale>, ({String companyId, String? storeId, String fromYmd, String toYmd})>(
  (ref, key) {
    if (key.companyId.isEmpty) return Stream.value([]);
    final repo = ref.watch(salesOfflineRepositoryProvider);
    final fromUtc = '${key.fromYmd}T00:00:00.000Z';
    final toEnd = '${key.toYmd}T23:59:59.999Z';
    return repo.watchSales(key.companyId, storeId: key.storeId).map((sales) {
      final filtered = sales.where((s) {
        if (s.status != SaleStatus.completed) return false;
        final cid = s.customerId;
        if (cid == null || cid.isEmpty) return false;
        if (s.createdAt.compareTo(fromUtc) < 0) return false;
        if (s.createdAt.compareTo(toEnd) > 0) return false;
        return true;
      }).toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    });
  },
);

final storesOfflineRepositoryProvider = Provider<StoresOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StoresOfflineRepository(db);
});

final categoriesOfflineRepositoryProvider = Provider<CategoriesOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoriesOfflineRepository(db);
});

final brandsOfflineRepositoryProvider = Provider<BrandsOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BrandsOfflineRepository(db);
});

final suppliersOfflineRepositoryProvider = Provider<SuppliersOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SuppliersOfflineRepository(db);
});

final purchasesOfflineRepositoryProvider = Provider<PurchasesOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PurchasesOfflineRepository(db);
});

final transfersOfflineRepositoryProvider = Provider<TransfersOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransfersOfflineRepository(db);
});

final warehouseOfflineRepositoryProvider = Provider<WarehouseOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WarehouseOfflineRepository(db);
});

final companyMembersOfflineRepositoryProvider = Provider<CompanyMembersOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CompanyMembersOfflineRepository(db);
});

/// Sync service (push pending → Supabase, pull → Drift).
final syncServiceV2Provider = Provider<SyncServiceV2>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final productsOffline = ref.watch(productsOfflineRepositoryProvider);
  return SyncServiceV2(db, productsOffline);
});

/// Stream des produits depuis Drift — UI lit toujours en local (instantané).
final productsStreamProvider = StreamProvider.autoDispose.family<List<Product>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(productsOfflineRepositoryProvider);
  return repo.watchProducts(companyId);
});

/// Stream des quantités en stock par produit pour une boutique (Drift).
final inventoryQuantitiesStreamProvider = StreamProvider.autoDispose.family<Map<String, int>, String>((ref, storeId) {
  if (storeId.isEmpty) return Stream.value({});
  final db = ref.watch(appDatabaseProvider);
  return db.watchInventoryQuantities(storeId);
});

/// Date d’entrée en boutique par produit (plus ancien mouvement de stock) — pour « non vendus depuis 1 mois ».
/// Un produit n’est compté que s’il est dans la boutique depuis au moins 30 jours.
final earliestStockMovementDateByProductProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((ref, storeId) async {
  if (storeId.isEmpty) return {};
  ref.watch(inventoryQuantitiesStreamProvider(storeId));
  final db = ref.read(appDatabaseProvider);
  return db.getEarliestStockMovementDateByProduct(storeId);
});

/// Stream des clients depuis Drift.
final customersStreamProvider = StreamProvider.autoDispose.family<List<Customer>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(customersOfflineRepositoryProvider);
  return repo.watchCustomers(companyId);
});

/// Stream des ventes depuis Drift (companyId + storeId optionnel).
final salesStreamProvider = StreamProvider.autoDispose.family<List<Sale>, ({String companyId, String? storeId})>((ref, params) {
  if (params.companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(salesOfflineRepositoryProvider);
  return repo.watchSales(params.companyId, storeId: params.storeId);
});

/// Stream des boutiques depuis Drift.
final storesStreamProvider = StreamProvider.autoDispose.family<List<Store>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(storesOfflineRepositoryProvider);
  return repo.watchStores(companyId);
});

/// Stream des catégories depuis Drift.
final categoriesStreamProvider = StreamProvider.autoDispose.family<List<Category>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(categoriesOfflineRepositoryProvider);
  return repo.watchCategories(companyId);
});

/// Stream des marques depuis Drift.
final brandsStreamProvider = StreamProvider.autoDispose.family<List<Brand>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(brandsOfflineRepositoryProvider);
  return repo.watchBrands(companyId);
});

/// Stream des fournisseurs depuis Drift.
final suppliersStreamProvider = StreamProvider.autoDispose.family<List<Supplier>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(suppliersOfflineRepositoryProvider);
  return repo.watchSuppliers(companyId);
});

/// Stream des achats depuis Drift (avec filtres optionnels).
final purchasesStreamProvider = StreamProvider.autoDispose.family<List<Purchase>, ({String companyId, String? storeId, String? supplierId, PurchaseStatus? status, String? fromDate, String? toDate})>((ref, params) {
  if (params.companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(purchasesOfflineRepositoryProvider);
  return repo.watchPurchases(
    params.companyId,
    storeId: params.storeId,
    supplierId: params.supplierId,
    status: params.status,
    fromDate: params.fromDate,
    toDate: params.toDate,
  );
});

/// Stream des transferts depuis Drift.
final transfersStreamProvider = StreamProvider.autoDispose.family<List<StockTransfer>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(transfersOfflineRepositoryProvider);
  return repo.watchTransfers(companyId);
});

/// Stock magasin (dépôt) depuis Drift — mis à jour au pull sync.
final warehouseInventoryStreamProvider =
    StreamProvider.autoDispose.family<List<WarehouseStockLine>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  return ref.watch(warehouseOfflineRepositoryProvider).watchStockLines(companyId);
});

/// Mouvements magasin depuis Drift.
final warehouseMovementsStreamProvider =
    StreamProvider.autoDispose.family<List<WarehouseMovement>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  return ref.watch(warehouseOfflineRepositoryProvider).watchMovements(companyId);
});

/// Bons de sortie dépôt (« Historiques des bons ») depuis Drift — mis à jour au pull sync.
final warehouseDispatchInvoicesStreamProvider =
    StreamProvider.autoDispose.family<List<WarehouseDispatchInvoiceSummary>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  return ref.watch(warehouseOfflineRepositoryProvider).watchDispatchInvoices(companyId);
});

/// Stream des membres entreprise (écran Utilisateurs) depuis Drift.
final companyMembersStreamProvider = StreamProvider.autoDispose.family<List<CompanyMember>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value([]);
  final repo = ref.watch(companyMembersOfflineRepositoryProvider);
  return repo.watchMembers(companyId);
});

/// Nombre d'actions en attente de synchronisation (ventes, clients, etc.).
final pendingActionsCountStreamProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPendingActionsCount();
});

/// Seuil alerte stock par défaut (société) depuis Drift.
final defaultStockAlertThresholdStreamProvider = StreamProvider.autoDispose.family<int, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value(5);
  final db = ref.watch(appDatabaseProvider);
  return db.watchDefaultStockAlertThreshold(companyId);
});

/// Overrides stock_min par boutique depuis Drift.
final stockMinOverridesStreamProvider = StreamProvider.autoDispose.family<Map<String, int?>, String>((ref, storeId) {
  if (storeId.isEmpty) return Stream.value({});
  final db = ref.watch(appDatabaseProvider);
  return db.watchStockMinOverrides(storeId);
});

/// Repository dashboard offline (calcul KPIs depuis Drift).
final dashboardOfflineRepositoryProvider = Provider<DashboardOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DashboardOfflineRepository(db);
});

/// Repository rapports offline (KPIs + catégories + stock) depuis Drift.
final reportsOfflineRepositoryProvider = Provider<ReportsOfflineRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReportsOfflineRepository(db);
});

/// Émet quand les données Drift utiles aux KPIs dashboard/rapports changent (ventes, lignes, achats, stock boutique,
/// produits, catégories, seuils, réglages société) — y compris après sync ou écritures Realtime.
/// Les écrans écoutent ce stream avec debounce et rechargent depuis Drift (pas d’appel réseau direct).
final dashboardDataChangeTriggerStreamProvider = StreamProvider.autoDispose.family<Object, String>((ref, companyId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDashboardDataTrigger(companyId).map((_) => Object());
});

/// Stream des mouvements de stock depuis Drift (par boutique), avec libellé produit depuis le catalogue local.
final stockMovementsStreamProvider = StreamProvider.autoDispose.family<List<StockMovement>, String>((ref, storeId) {
  if (storeId.isEmpty) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchLocalStockMovements(storeId, limit: 500).asyncMap((rows) async {
    if (rows.isEmpty) return <StockMovement>[];
    final ids = rows.map((r) => r.productId).toSet();
    final refsById = await db.getMovementProductRefsByIds(ids);
    return rows
        .map(
          (r) => StockMovement(
            id: r.id,
            storeId: r.storeId,
            productId: r.productId,
            type: r.type,
            quantity: r.quantity,
            referenceType: r.referenceType,
            referenceId: r.referenceId,
            createdBy: r.createdBy,
            createdAt: r.createdAt,
            notes: r.notes,
            product: refsById[r.productId],
          ),
        )
        .toList();
  });
});

/// IDs des produits vendus au moins une fois dans les 30 derniers jours (pour notifications owner).
final productIdsSoldLastMonthProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, companyId) async {
  ref.watch(salesStreamProvider((companyId: companyId, storeId: null)));
  final db = ref.read(appDatabaseProvider);
  final now = DateTime.now();
  final monthAgo = now.subtract(const Duration(days: 30));
  final from = DateTime(monthAgo.year, monthAgo.month, monthAgo.day).toUtc().toIso8601String();
  final to = now.toUtc().toIso8601String();
  final sales = await db.getLocalSalesInRange(companyId, fromDate: from, toDate: to);
  final saleIds = sales.map((s) => s.id).toList();
  if (saleIds.isEmpty) return {};
  final items = await db.getLocalSaleItemsForSales(saleIds);
  return items.map((i) => i.productId).toSet();
});

/// Top 10 produits les plus vendus (quantité) sur les 30 derniers jours — pour notifications owner.
final top10ProductsSoldProvider = FutureProvider.autoDispose.family<List<({String productId, int quantity})>, String>((ref, companyId) async {
  ref.watch(salesStreamProvider((companyId: companyId, storeId: null)));
  final db = ref.read(appDatabaseProvider);
  final now = DateTime.now();
  final monthAgo = now.subtract(const Duration(days: 30));
  final from = DateTime(monthAgo.year, monthAgo.month, monthAgo.day).toUtc().toIso8601String();
  final to = now.toUtc().toIso8601String();
  final sales = await db.getLocalSalesInRange(companyId, fromDate: from, toDate: to);
  final saleIds = sales.map((s) => s.id).toList();
  if (saleIds.isEmpty) return [];
  final items = await db.getLocalSaleItemsForSales(saleIds);
  final byProduct = <String, int>{};
  for (final i in items) {
    byProduct[i.productId] = (byProduct[i.productId] ?? 0) + i.quantity;
  }
  final sorted = byProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(10).map((e) => (productId: e.key, quantity: e.value)).toList();
});

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/drift/app_database.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/customers_repository.dart';
import '../repositories/sales_repository.dart';
import '../repositories/stores_repository.dart';
import '../models/purchase.dart';
import '../repositories/offline/products_offline_repository.dart';
import '../repositories/products_repository.dart';
import '../models/stock_transfer.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/suppliers_repository.dart';
import '../repositories/transfers_repository.dart';
import '../repositories/users_repository.dart';
import '../../core/utils/client_request_id.dart';

/// Offline-first sync: push pending actions to Supabase, then pull and merge into Drift.
/// - All reads in the UI come from Drift (never wait for network).
/// - Writes go to Drift + pending_actions; this service pushes and then pulls.
/// - Conflict resolution: last-write-wins using updated_at from Supabase.
class SyncServiceV2 {
  SyncServiceV2(this._db, this._productsOffline);

  final AppDatabase _db;
  final ProductsOfflineRepository _productsOffline;

  final InventoryRepository _inventoryRepo = InventoryRepository();
  final CustomersRepository _customersRepo = CustomersRepository();
  final SalesRepository _salesRepo = SalesRepository();
  final StoresRepository _storesRepo = StoresRepository();
  final ProductsRepository _productsRepo = ProductsRepository();
  final SuppliersRepository _suppliersRepo = SuppliersRepository();
  final PurchasesRepository _purchasesRepo = PurchasesRepository();
  final TransfersRepository _transfersRepo = TransfersRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final UsersRepository _usersRepo = UsersRepository();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  static const String _pendingCustomerPrefix = 'pending:';

  /// 1) Push pending actions (sales, stock adjustments, customers) to Supabase.
  /// 2) Pull from Supabase and upsert into Drift (products, inventory, customers, stores).
  /// Ne lance jamais : retourne toujours [SyncResult] (sent, errors). Les erreurs sont loguées en debug.
  Future<SyncResult> sync({
    required String userId,
    required String? companyId,
    required String? storeId,
  }) async {
    if (_isSyncing) return const SyncResult(sent: 0, errors: 0, pulled: false);
    _isSyncing = true;
    int sent = 0;
    int errors = 0;
    var pulled = false;
    try {
      final pending = await _db.getPendingActions();
      final customerIdMap = <String, String>{};

      for (final item in pending) {
        final id = item['id'] as int?;
        final kind = item['kind'] as String?;
        final payloadRaw = item['payload'] as String?;
        if (id == null || kind == null || payloadRaw == null) continue;
        try {
          final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
          if (kind == 'customer') {
            final localId = payload['local_id'] as String? ?? '';
            final realId = await _pushCustomer(payload);
            if (realId != null) {
              customerIdMap[_pendingCustomerPrefix + localId] = realId;
              await _db.deleteLocalCustomer(_pendingCustomerPrefix + localId);
            }
          } else if (kind == 'sale') {
            await _pushSale(payload, customerIdMap);
          } else if (kind == 'stock_adjustment') {
            await _pushStockAdjustment(payload, userId);
          } else if (kind == 'product_import') {
            await _pushProductImport(payload);
          } else if (kind == 'transfer') {
            await _pushTransfer(payload);
          }
          await _db.markPendingActionSynced(id);
          sent++;
        } catch (e, st) {
          errors++;
          if (kDebugMode) {
            debugPrint('[Sync] Erreur push $kind: $e');
            debugPrint(st.toString());
          }
        }
      }

      if (companyId != null) {
        try {
          await _pullAndMerge(companyId, storeId);
          pulled = true;
        } catch (e, st) {
          errors++;
          if (kDebugMode) {
            debugPrint('[Sync] Erreur pull: $e');
            debugPrint(st.toString());
          }
        }
      }
      return SyncResult(sent: sent, errors: errors, pulled: pulled);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Sync] Erreur générale: $e');
        debugPrint(st.toString());
      }
      return SyncResult(sent: sent, errors: errors + 1, pulled: false);
    } finally {
      _isSyncing = false;
    }
  }

  Future<String?> _pushCustomer(Map<String, dynamic> payload) async {
    final companyId = payload['company_id'] as String?;
    final name = payload['name'] as String?;
    if (companyId == null || name == null) return null;
    final type = payload['type'] as String? ?? 'individual';
    final customer = await _customersRepo.create(
      CreateCustomerInput(
        companyId: companyId,
        name: name,
        type: type == 'company'
            ? CustomerType.company
            : CustomerType.individual,
        phone: payload['phone'] as String?,
        email: payload['email'] as String?,
        address: payload['address'] as String?,
        notes: payload['notes'] as String?,
      ),
    );
    return customer.id;
  }

  Future<void> _pushSale(
    Map<String, dynamic> payload,
    Map<String, String> customerIdMap,
  ) async {
    final client = Supabase.instance.client;
    final localId = payload['local_id'] as String?;
    final rawParams = payload['rpc'];
    final p = rawParams is Map
        ? Map<String, dynamic>.from(rawParams)
        : Map<String, dynamic>.from(payload);
    final customerId = p['p_customer_id'];
    if (customerId is String && customerId.startsWith(_pendingCustomerPrefix)) {
      p['p_customer_id'] = customerIdMap[customerId];
    }
    // Certains environnements ont deux overloads de `create_sale_with_stock`
    // (avec/sans `p_client_request_id`). En forçant la clé quand elle est absente,
    // on évite l'ambiguïté PostgREST et on stabilise le replay offline.
    p['p_client_request_id'] ??= newClientRequestId();
    try {
      await client.rpc('create_sale_with_stock', params: p);
    } catch (e) {
      // Si la DB ne contient pas l'overload avec `p_client_request_id`, retenter
      // sans cette clé (pour que les 2 caisses restent fonctionnelles).
      final msg = e.toString();
      if (msg.contains('create_sale_with_stock') && msg.contains('PGRST202') && msg.contains('p_client_request_id')) {
        final p2 = Map<String, dynamic>.from(p);
        p2.remove('p_client_request_id');
        await client.rpc('create_sale_with_stock', params: p2);
      } else {
        rethrow;
      }
    }
    if (localId != null && localId.isNotEmpty) {
      final pendingSaleId =
          _pendingCustomerPrefix + localId; // "pending:" prefix
      await _db.deleteLocalSaleItemsBySaleId(pendingSaleId);
      await _db.deleteLocalSale(pendingSaleId);
    }
  }

  Future<void> _pushStockAdjustment(
    Map<String, dynamic> payload,
    String userId,
  ) async {
    final storeId = payload['store_id'] as String?;
    final productId = payload['product_id'] as String?;
    final delta = payload['delta'];
    final reason =
        payload['reason'] as String? ?? 'Ajustement (sync hors ligne)';
    final uid = payload['user_id'] as String? ?? userId;
    if (storeId == null || productId == null || delta == null) return;
    final deltaInt = delta is int ? delta : (delta as num).toInt();
    await _inventoryRepo.adjust(storeId, productId, deltaInt, reason, uid);
  }

  /// Crée un transfert sur Supabase (rejoué depuis la file hors ligne).
  Future<void> _pushTransfer(Map<String, dynamic> payload) async {
    final companyId = payload['company_id'] as String?;
    final fromStoreId = payload['from_store_id'] as String?;
    final toStoreId = payload['to_store_id'] as String?;
    final requestedBy = payload['requested_by'] as String?;
    final localId = payload['local_id'] as String?;
    final itemsRaw = payload['items'];
    if (companyId == null ||
        toStoreId == null ||
        requestedBy == null ||
        itemsRaw is! List)
      return;
    if (fromStoreId == null || fromStoreId.isEmpty) return;
    final items = itemsRaw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (items.isEmpty) return;
    final validItems = items
        .where(
          (i) =>
              (i['product_id'] as String?).toString().isNotEmpty &&
              ((i['quantity_requested'] as num?)?.toInt() ?? 0) > 0,
        )
        .map(
          (i) => CreateTransferItemInput(
            productId: i['product_id'] as String,
            quantityRequested: (i['quantity_requested'] as num).toInt(),
          ),
        )
        .toList();
    if (validItems.isEmpty) return;
    final input = CreateTransferInput(
      companyId: companyId,
      fromStoreId: fromStoreId,
      toStoreId: toStoreId,
      fromWarehouse: false,
      items: validItems,
    );
    await _transfersRepo.create(input, requestedBy);
    if (localId != null && localId.isNotEmpty) {
      await _db.deleteLocalTransfer(localId);
    }
  }

  /// Rejoue un import CSV enregistré hors ligne : crée produits (et catégories/marques) puis stock entrant.
  Future<void> _pushProductImport(Map<String, dynamic> payload) async {
    final companyId = payload['company_id'] as String?;
    final storeId = payload['store_id'] as String?;
    final uid = payload['user_id'] as String?;
    final rowsRaw = payload['rows'];
    if (companyId == null || rowsRaw is! List) return;
    final rows = rowsRaw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (rows.isEmpty) return;
    await _productsRepo.importFromCsv(
      companyId,
      rows,
      storeId: storeId,
      userId: uid,
    );
  }

  /// Pull from Supabase and merge into Drift (last-write-wins via server updated_at).
  /// Chaque bloc est dans un try/catch pour qu'une erreur (réseau, API) ne bloque pas les autres.
  Future<void> _pullAndMerge(String companyId, String? storeId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _productsOffline.pullAndMerge(companyId);
    try {
      final threshold = await _settingsRepo.getDefaultStockAlertThreshold(
        companyId,
      );
      await _db.upsertDefaultStockAlertThreshold(companyId, threshold);
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull defaultStockAlertThreshold: $e');
    }
    if (storeId != null && storeId.isNotEmpty) {
      try {
        final stock = await _inventoryRepo.getStockByStore(storeId);
        for (final e in stock.entries) {
          await _db.upsertInventory(storeId, e.key, e.value, now);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Sync] pull inventory: $e');
      }
      try {
        final movements = await _inventoryRepo.getMovements(
          storeId,
          limit: 500,
        );
        await _db.upsertLocalStockMovements(
          movements.map(
            (m) => LocalStockMovementsCompanion.insert(
              id: m.id,
              storeId: m.storeId,
              productId: m.productId,
              type: m.type,
              quantity: m.quantity,
              referenceType: Value(m.referenceType),
              referenceId: Value(m.referenceId),
              createdBy: Value(m.createdBy),
              createdAt: m.createdAt,
              notes: Value(m.notes),
            ),
          ),
        );
        await _db.deleteLocalStockMovementsNotIn(
          storeId,
          movements.map((m) => m.id).toSet(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Sync] pull stockMovements: $e');
      }
      try {
        final overrides = await _inventoryRepo.getStoreStockMinOverrides(
          storeId,
        );
        await _db.upsertStockMinOverrides(storeId, overrides);
        await _db.deleteStockMinOverridesNotIn(storeId, overrides.keys.toSet());
      } catch (e) {
        if (kDebugMode) debugPrint('[Sync] pull stockMinOverrides: $e');
      }
    }
    try {
      final members = await _usersRepo.listCompanyMembers(companyId);
      final memberKeepIds = members.map((m) => m.id).toSet();
      await _db.upsertLocalCompanyMembers(
        members.map(
          (m) => LocalCompanyMembersCompanion.insert(
            id: m.id,
            companyId: companyId,
            userId: m.userId,
            roleId: m.roleId,
            isActive: Value(m.isActive),
            createdAt: m.createdAt,
            roleName: m.role.name,
            roleSlug: m.role.slug,
            profileFullName: Value(m.profile?.fullName),
            email: Value(m.email),
          ),
        ),
      );
      await _db.deleteLocalCompanyMembersNotIn(companyId, memberKeepIds);
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull companyMembers: $e');
    }
    try {
      final customers = await _customersRepo.list(companyId);
      final keepIds = customers.map((c) => c.id).toSet();
      final companions = customers.map(
        (c) => LocalCustomersCompanion.insert(
          id: c.id,
          companyId: c.companyId,
          name: c.name,
          type: Value(c.type.value),
          phone: Value(c.phone),
          email: Value(c.email),
          address: Value(c.address),
          notes: Value(c.notes),
          createdAt: c.createdAt ?? now,
          updatedAt: c.updatedAt ?? now,
        ),
      );
      await _db.upsertLocalCustomers(companions);
      await _db.deleteLocalCustomersNotIn(companyId, keepIds);
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull customers: $e');
    }
    try {
      final stores = await _storesRepo.getStoresByCompany(companyId);
      final storeCompanions = stores.map(
        (s) => LocalStoresCompanion.insert(
          id: s.id,
          companyId: s.companyId,
          name: s.name,
          code: Value(s.code),
          address: Value(s.address),
          logoUrl: Value(s.logoUrl),
          phone: Value(s.phone),
          email: Value(s.email),
          description: Value(s.description),
          isActive: Value(s.isActive),
          isPrimary: Value(s.isPrimary),
          posDiscountEnabled: Value(s.posDiscountEnabled),
          updatedAt: s.createdAt ?? now,
          currency: Value(s.currency),
          primaryColor: Value(s.primaryColor),
          secondaryColor: Value(s.secondaryColor),
          invoicePrefix: Value(s.invoicePrefix),
          footerText: Value(s.footerText),
          legalInfo: Value(s.legalInfo),
          signatureUrl: Value(s.signatureUrl),
          stampUrl: Value(s.stampUrl),
          paymentTerms: Value(s.paymentTerms),
          taxLabel: Value(s.taxLabel),
          taxNumber: Value(s.taxNumber),
          city: Value(s.city),
          country: Value(s.country),
          commercialName: Value(s.commercialName),
          slogan: Value(s.slogan),
          activity: Value(s.activity),
          mobileMoney: Value(s.mobileMoney),
          invoiceShortTitle: Value(s.invoiceShortTitle),
          invoiceSignerTitle: Value(s.invoiceSignerTitle),
          invoiceSignerName: Value(s.invoiceSignerName),
          invoiceTemplate: Value(s.invoiceTemplate),
        ),
      );
      await _db.upsertLocalStores(storeCompanions);
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull stores: $e');
    }
    try {
      final sales = await _salesRepo.list(companyId, storeId: storeId);
      for (final sale in sales) {
        await _db.upsertLocalSale(
          LocalSalesCompanion.insert(
            id: sale.id,
            companyId: sale.companyId,
            storeId: sale.storeId,
            customerId: Value(sale.customerId),
            saleNumber: sale.saleNumber,
            status: sale.status.value,
            subtotal: Value(sale.subtotal),
            discount: Value(sale.discount),
            tax: Value(sale.tax),
            total: sale.total,
            createdBy: sale.createdBy,
            createdAt: sale.createdAt,
            updatedAt: sale.updatedAt,
            saleMode: Value(sale.saleMode?.value),
            documentType: Value(sale.documentType?.value),
          ),
        );
        final items = await _salesRepo.getItems(sale.id);
        if (items.isNotEmpty) {
          await _db.upsertLocalSaleItems(
            items.map(
              (i) => LocalSaleItemsCompanion.insert(
                id: i.id,
                saleId: i.saleId,
                productId: i.productId,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                total: i.total,
                createdAt: now,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull sales: $e');
    }
    try {
      final categories = await _productsRepo.categories(companyId);
      await _db.upsertLocalCategories(
        categories.map(
          (c) => LocalCategoriesCompanion.insert(
            id: c.id,
            companyId: c.companyId,
            name: c.name,
            parentId: Value(c.parentId),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull categories: $e');
    }
    try {
      final brands = await _productsRepo.brands(companyId);
      await _db.upsertLocalBrands(
        brands.map(
          (b) => LocalBrandsCompanion.insert(
            id: b.id,
            companyId: b.companyId,
            name: b.name,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull brands: $e');
    }
    try {
      final suppliers = await _suppliersRepo.list(companyId);
      await _db.upsertLocalSuppliers(
        suppliers.map(
          (s) => LocalSuppliersCompanion.insert(
            id: s.id,
            companyId: s.companyId,
            name: s.name,
            contact: Value(s.contact),
            phone: Value(s.phone),
            email: Value(s.email),
            address: Value(s.address),
            notes: Value(s.notes),
            updatedAt: now,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull suppliers: $e');
    }
    try {
      final purchases = await _purchasesRepo.list(companyId);
      final purchaseIds = purchases.map((p) => p.id).toList();
      final items = await _purchasesRepo.getItemsForPurchaseIds(purchaseIds);
      await _db.upsertLocalPurchases(
        purchases.map(
          (p) => LocalPurchasesCompanion.insert(
            id: p.id,
            companyId: p.companyId,
            storeId: p.storeId,
            supplierId: p.supplierId,
            reference: Value(p.reference),
            status: p.status.value,
            total: p.total,
            createdBy: p.createdBy,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
          ),
        ),
      );
      await _db.deleteLocalPurchaseItemsForPurchases(purchaseIds);
      await _db.upsertLocalPurchaseItems(
        items.map(
          (i) => LocalPurchaseItemsCompanion.insert(
            id: i.id,
            purchaseId: i.purchaseId,
            productId: i.productId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            total: i.total,
          ),
        ),
      );
      await _db.deleteLocalPurchasesNotIn(companyId, purchaseIds.toSet());
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull purchases: $e');
    }
    try {
      final transfers = await _transfersRepo.list(companyId);
      final transferIds = transfers.map((t) => t.id).toList();
      final transferItems = await _transfersRepo.getItemsForTransferIds(
        transferIds,
      );
      await _db.upsertLocalTransfers(
        transfers.map(
          (t) => LocalTransfersCompanion.insert(
            id: t.id,
            companyId: t.companyId,
            fromStoreId: t.fromStoreId,
            toStoreId: t.toStoreId,
            fromWarehouse: const Value(false),
            status: t.status.value,
            requestedBy: t.requestedBy,
            approvedBy: Value(t.approvedBy),
            shippedAt: Value(t.shippedAt),
            receivedAt: Value(t.receivedAt),
            receivedBy: Value(t.receivedBy),
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
          ),
        ),
      );
      await _db.deleteLocalTransferItemsForTransfers(transferIds);
      await _db.upsertLocalTransferItems(
        transferItems.map(
          (i) => LocalTransferItemsCompanion.insert(
            id: i.id,
            transferId: i.transferId,
            productId: i.productId,
            quantityRequested: i.quantityRequested,
            quantityShipped: Value(i.quantityShipped),
            quantityReceived: Value(i.quantityReceived),
          ),
        ),
      );
      await _db.deleteLocalTransfersNotIn(companyId, transferIds.toSet());
    } catch (e) {
      if (kDebugMode) debugPrint('[Sync] pull transfers: $e');
    }
  }
}

class SyncResult {
  const SyncResult({
    required this.sent,
    required this.errors,
    this.pulled = false,
  });
  final int sent;
  final int errors;

  /// True si le pull Drift (produits, stock, etc.) a été exécuté avec succès pour cette sync.
  final bool pulled;
}

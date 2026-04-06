import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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
import '../repositories/warehouse_repository.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/client_request_id.dart';

/// Offline-first sync: push pending actions to Supabase, then pull and merge into Drift.
/// - All reads in the UI come from Drift (never wait for network).
/// - Writes go to Drift + pending_actions; this service pushes and then pulls.
/// - Conflict resolution: last-write-wins using updated_at from Supabase.
class SyncServiceV2 {
  SyncServiceV2(
    this._db,
    this._productsOffline, {
    Future<void> Function(Map<String, dynamic> payload)?
    pushWarehouseSetThresholdOverride,
  }) : _pushWarehouseSetThresholdOverride = pushWarehouseSetThresholdOverride;

  final AppDatabase _db;
  final ProductsOfflineRepository? _productsOffline;

  InventoryRepository? _inventoryRepoCached;
  CustomersRepository? _customersRepoCached;
  SalesRepository? _salesRepoCached;
  StoresRepository? _storesRepoCached;
  ProductsRepository? _productsRepoCached;
  SuppliersRepository? _suppliersRepoCached;
  PurchasesRepository? _purchasesRepoCached;
  TransfersRepository? _transfersRepoCached;
  SettingsRepository? _settingsRepoCached;
  UsersRepository? _usersRepoCached;
  WarehouseRepository? _warehouseRepoCached;
  InventoryRepository get _inventoryRepo =>
      _inventoryRepoCached ??= InventoryRepository();
  CustomersRepository get _customersRepo =>
      _customersRepoCached ??= CustomersRepository();
  SalesRepository get _salesRepo => _salesRepoCached ??= SalesRepository();
  StoresRepository get _storesRepo => _storesRepoCached ??= StoresRepository();
  ProductsRepository get _productsRepo =>
      _productsRepoCached ??= ProductsRepository();
  SuppliersRepository get _suppliersRepo =>
      _suppliersRepoCached ??= SuppliersRepository();
  PurchasesRepository get _purchasesRepo =>
      _purchasesRepoCached ??= PurchasesRepository();
  TransfersRepository get _transfersRepo =>
      _transfersRepoCached ??= TransfersRepository();
  SettingsRepository get _settingsRepo =>
      _settingsRepoCached ??= SettingsRepository();
  UsersRepository get _usersRepo => _usersRepoCached ??= UsersRepository();
  WarehouseRepository get _warehouseRepo =>
      _warehouseRepoCached ??= WarehouseRepository();
  final Future<void> Function(Map<String, dynamic> payload)?
  _pushWarehouseSetThresholdOverride;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  bool _inventoryLightPullInFlight = false;

  static const String _pendingCustomerPrefix = 'pending:';
  static const int _baseRetryDelayMs = 1500;
  static const int _maxRetryDelayMs = 5 * 60 * 1000;
  final Map<int, int> _pendingFailCounts = <int, int>{};

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
        final updatedAt = item['updatedAt'] as int?;
        if (id == null || kind == null || payloadRaw == null) continue;
        if (!_isRetryDue(id, updatedAt)) continue;
        try {
          final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
          var handled = true;
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
          } else if (kind == 'warehouse_manual_entry') {
            await _pushWarehouseManualEntry(payload);
          } else if (kind == 'warehouse_dispatch_invoice') {
            await _pushWarehouseDispatchInvoice(payload, customerIdMap);
          } else if (kind == 'warehouse_adjustment') {
            await _pushWarehouseAdjustment(payload);
          } else if (kind == 'warehouse_exit_sale') {
            await _pushWarehouseExitSale(payload);
          } else if (kind == 'warehouse_set_threshold') {
            await _pushWarehouseSetThreshold(payload);
          } else if (kind == 'credit_append_payment') {
            await _pushCreditAppendPayment(payload);
          } else if (kind == 'credit_update_meta') {
            await _pushCreditUpdateMeta(payload);
          } else {
            handled = false;
          }
          if (!handled) {
            throw UnsupportedError('Pending action kind non géré: $kind');
          }
          await _db.markPendingActionSynced(id);
          _pendingFailCounts.remove(id);
          sent++;
        } catch (e, st) {
          _pendingFailCounts[id] = (_pendingFailCounts[id] ?? 0) + 1;
          await _db.markPendingActionFailed(id);
          errors++;
          if (kDebugMode) {
            debugPrint('[Sync] Erreur push $kind: $e');
            debugPrint(st.toString());
          }
          if (!_isExpectedBusinessPushError(e)) {
            AppErrorHandler.log(
              'SyncV2.push pending id=$id kind=$kind: $e',
              st,
            );
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
          AppErrorHandler.log('SyncV2.pullAndMerge companyId=$companyId: $e', st);
        }
      }
      return SyncResult(sent: sent, errors: errors, pulled: pulled);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Sync] Erreur générale: $e');
        debugPrint(st.toString());
      }
      AppErrorHandler.log('SyncV2.sync outer: $e', st);
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
    _normalizeSalePaymentsInPlace(p);
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
        _normalizeSalePaymentsInPlace(p2);
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
    final fromWarehouse = payload['from_warehouse'] as bool? ?? false;
    final toStoreId = payload['to_store_id'] as String?;
    final requestedBy = payload['requested_by'] as String?;
    final localId = payload['local_id'] as String?;
    final itemsRaw = payload['items'];
    if (companyId == null ||
        toStoreId == null ||
        requestedBy == null ||
        itemsRaw is! List) {
      return;
    }
    if (!fromWarehouse && (fromStoreId == null || fromStoreId.isEmpty)) return;
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
      fromStoreId: fromWarehouse ? null : fromStoreId,
      toStoreId: toStoreId,
      fromWarehouse: fromWarehouse,
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

  /// Seules les quantités `store_inventory` (léger, pour rafraîchir les écrans sans sync complète).
  /// Utilisé en secours si Realtime ne livre pas les changements (réseau, config projet, etc.).
  Future<void> _pullInventoryQuantitiesOnly(String storeId, String now) async {
    try {
      final stock = await _inventoryRepo.getStockByStore(storeId);
      final keepIds = stock.keys.toSet();
      for (final e in stock.entries) {
        await _db.upsertInventory(storeId, e.key, e.value, now);
      }
      await _db.deleteStoreInventoryNotIn(storeId, keepIds);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull inventory quantities only: $e');
      AppErrorHandler.log(
        'SyncV2.pull inventory quantities storeId=$storeId: $e',
        st,
      );
    }
  }

  /// Remet à jour le stock Drift pour des boutiques précises (rapide, hors file « light poll »).
  /// À appeler après annulation vente, ajustement serveur, etc. : ne dépend pas de [sync] ni du timer.
  Future<void> pullInventoryQuantitiesForStores(Iterable<String> storeIds) async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final id in storeIds) {
      if (id.isEmpty) continue;
      await _pullInventoryQuantitiesOnly(id, now);
    }
  }

  /// Tirage périodique des quantités pour **toutes** les boutiques visibles (API), pas seulement le miroir Drift.
  ///
  /// Cause fréquente de « rien ne bouge sur le PC » : [getLocalStores] peut être incomplet ou vieux alors que
  /// l’utilisateur est sur le POS d’une boutique ; on ne tirait jamais le `store_id` concerné depuis Supabase.
  /// En ligne, on s’aligne sur la liste `stores` (PostgREST + RLS), comme le web ; hors ligne / erreur réseau,
  /// repli sur les boutiques présentes localement.
  ///
  /// Ne **pas** bloquer sur [_isSyncing].
  ///
  /// [extraStoreIds] : ex. boutique courante dans l’UI (POS) — ajoutée même si absente de la réponse API transitoire.
  Future<void> pullStoreInventoryLight({
    required String companyId,
    Set<String> extraStoreIds = const {},
  }) async {
    if (_inventoryLightPullInFlight) return;
    _inventoryLightPullInFlight = true;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final ids = <String>{};
      for (final id in extraStoreIds) {
        if (id.isNotEmpty) ids.add(id);
      }

      try {
        final apiStores = await _storesRepo.getStoresByCompany(companyId);
        for (final s in apiStores) {
          ids.add(s.id);
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Sync] pullStoreInventoryLight getStoresByCompany: $e');
        }
        // Erreur non bloquante ici: on bascule sur le cache Drift.
        // Évite de polluer les logs d'erreurs pour un simple fallback réseau/schéma.
        if (e is! UserFriendlyError) {
          AppErrorHandler.log(
            'SyncV2.pullStoreInventoryLight stores companyId=$companyId: $e',
            st,
          );
        }
        final localStores = await _db.getLocalStores(companyId);
        for (final s in localStores) {
          ids.add(s.id);
        }
      }

      if (ids.isEmpty) return;

      for (final sid in ids) {
        await _pullInventoryQuantitiesOnly(sid, now);
      }
    } finally {
      _inventoryLightPullInFlight = false;
    }
  }

  /// Stock boutique + mouvements + seuils pour une boutique (Drift).
  Future<void> _pullInventoryForStore(
    String companyId,
    String storeId,
    String now,
  ) async {
    await _pullInventoryQuantitiesOnly(storeId, now);
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull stockMovements: $e');
      AppErrorHandler.log(
        'SyncV2.pull stock_movements storeId=$storeId: $e',
        st,
      );
    }
    try {
      final overrides = await _inventoryRepo.getStoreStockMinOverrides(
        storeId,
      );
      await _db.upsertStockMinOverrides(storeId, overrides);
      await _db.deleteStockMinOverridesNotIn(storeId, overrides.keys.toSet());
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull stockMinOverrides: $e');
      AppErrorHandler.log(
        'SyncV2.pull stock_min_overrides storeId=$storeId: $e',
        st,
      );
    }
  }

  Future<void> _pullSalesIntoDrift(String companyId, String? storeId, String now) async {
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
            creditDueAt: Value(sale.creditDueAt),
            creditInternalNote: Value(sale.creditInternalNote),
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
        try {
          final pays = await _salesRepo.getPayments(sale.id);
          await _db.replaceLocalSalePaymentsFromModels(sale.id, pays, now);
        } catch (e, st) {
          if (kDebugMode) debugPrint('[Sync] pull sale_payments ${sale.id}: $e');
          AppErrorHandler.log('SyncV2.pull sale_payments saleId=${sale.id}: $e', st);
        }
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull sales: $e');
      AppErrorHandler.log(
        'SyncV2.pull sales companyId=$companyId storeId=$storeId: $e',
        st,
      );
    }
  }

  /// Ventes uniquement — pour rafraîchir l’écran liste chez tous les appareils (ex. toutes les 10 s).
  Future<void> pullSalesFromServer({
    required String companyId,
    String? storeId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _pullSalesIntoDrift(companyId, storeId, now);
  }

  /// Pull from Supabase and merge into Drift (last-write-wins via server updated_at).
  /// Chaque bloc est dans un try/catch pour qu'une erreur (réseau, API) ne bloque pas les autres.
  Future<void> _pullAndMerge(String companyId, String? storeId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _productsOffline?.pullAndMerge(companyId);
    try {
      final threshold = await _settingsRepo.getDefaultStockAlertThreshold(
        companyId,
      );
      await _db.upsertDefaultStockAlertThreshold(companyId, threshold);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull defaultStockAlertThreshold: $e');
      AppErrorHandler.log(
        'SyncV2.pull default_stock_alert_threshold companyId=$companyId: $e',
        st,
      );
    }
    try {
      final siteUrl = await _settingsRepo.getPublicWebsiteUrl(companyId);
      if (siteUrl == null || siteUrl.isEmpty) {
        await _db.deletePublicWebsiteUrl(companyId);
      } else {
        await _db.upsertPublicWebsiteUrl(companyId, siteUrl);
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull publicWebsiteUrl: $e');
      AppErrorHandler.log(
        'SyncV2.pull public_website_url companyId=$companyId: $e',
        st,
      );
    }
    // Transfert magasin → boutique : receive crédite store_inventory côté serveur.
    // Avec storeId null (sync depuis l’écran Magasin), il faut quand même tirer le stock
    // de chaque boutique, sinon le cache local ne reflète pas la réception.
    if (storeId != null && storeId.isNotEmpty) {
      await _pullInventoryForStore(companyId, storeId, now);
    } else {
      try {
        final stores = await _storesRepo.getStoresByCompany(companyId);
        // Séquentiel : une seule connexion Drift (isolate) — en parallèle, plusieurs
        // écritures peuvent provoquer SQLITE_BUSY sur Windows (« cannot commit transaction »).
        for (final s in stores) {
          await _pullInventoryForStore(companyId, s.id, now);
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[Sync] pull inventory (toutes boutiques): $e');
        }
        AppErrorHandler.log(
          'SyncV2.pull inventory all stores companyId=$companyId: $e',
          st,
        );
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull companyMembers: $e');
      AppErrorHandler.log(
        'SyncV2.pull company_members companyId=$companyId: $e',
        st,
      );
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull customers: $e');
      AppErrorHandler.log('SyncV2.pull customers companyId=$companyId: $e', st);
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull stores: $e');
      AppErrorHandler.log('SyncV2.pull stores companyId=$companyId: $e', st);
    }
    await _pullSalesIntoDrift(companyId, storeId, now);
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull categories: $e');
      AppErrorHandler.log('SyncV2.pull categories companyId=$companyId: $e', st);
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull brands: $e');
      AppErrorHandler.log('SyncV2.pull brands companyId=$companyId: $e', st);
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull suppliers: $e');
      AppErrorHandler.log('SyncV2.pull suppliers companyId=$companyId: $e', st);
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull purchases: $e');
      AppErrorHandler.log('SyncV2.pull purchases companyId=$companyId: $e', st);
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
            fromWarehouse: Value(t.fromWarehouse),
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
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull transfers: $e');
      AppErrorHandler.log('SyncV2.pull transfers companyId=$companyId: $e', st);
    }
    try {
      final whInv = await _warehouseRepo.listInventory(companyId);
      await _db.upsertLocalWarehouseInventory(
        whInv.map(
          (line) => LocalWarehouseInventoryCompanion.insert(
            companyId: companyId,
            productId: line.productId,
            quantity: Value(line.quantity),
            avgUnitCost: Value(line.avgUnitCost),
            stockMinWarehouse: Value(line.stockMinWarehouse),
            updatedAt: line.updatedAt ?? now,
          ),
        ),
      );
      await _db.deleteLocalWarehouseInventoryNotIn(
        companyId,
        whInv.map((l) => l.productId).toSet(),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull warehouseInventory: $e');
      AppErrorHandler.log('SyncV2.pull warehouse_inventory companyId=$companyId: $e', st);
    }
    try {
      final whMov = await _warehouseRepo.listMovements(companyId, limit: 500);
      await _db.upsertLocalWarehouseMovements(
        whMov.map(
          (m) => LocalWarehouseMovementsCompanion.insert(
            id: m.id,
            companyId: companyId,
            productId: m.productId,
            movementKind: m.movementKind,
            quantity: m.quantity,
            unitCost: Value(m.unitCost),
            packagingType: Value(m.packagingType),
            packsQuantity: Value(m.packsQuantity),
            referenceType: Value(m.referenceType),
            referenceId: Value(m.referenceId),
            notes: Value(m.notes),
            createdAt: m.createdAt ?? now,
          ),
        ),
      );
      await _db.deleteLocalWarehouseMovementsNotIn(
        companyId,
        whMov.map((m) => m.id).toSet(),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull warehouseMovements: $e');
      AppErrorHandler.log('SyncV2.pull warehouse_movements companyId=$companyId: $e', st);
    }
    try {
      final dispatchInv = await _warehouseRepo.listDispatchInvoices(companyId, limit: 200);
      await _db.upsertLocalWarehouseDispatchInvoices(
        dispatchInv.map(
          (row) => LocalWarehouseDispatchInvoicesCompanion.insert(
            id: row.id,
            companyId: companyId,
            customerId: Value(row.customerId),
            customerName: Value(row.customerName),
            documentNumber: row.documentNumber,
            notes: Value(row.notes),
            createdAt: row.createdAt,
          ),
        ),
      );
      await _db.deleteLocalWarehouseDispatchInvoicesNotIn(
        companyId,
        dispatchInv.map((e) => e.id).toSet(),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('[Sync] pull warehouseDispatchInvoices: $e');
      AppErrorHandler.log('SyncV2.pull warehouse_dispatch_invoices companyId=$companyId: $e', st);
    }
  }

  Future<void> _pushWarehouseManualEntry(Map<String, dynamic> payload) async {
    final companyId = payload['company_id'] as String?;
    final productId = payload['product_id'] as String?;
    if (companyId == null || productId == null) {
      throw StateError('warehouse_manual_entry: company_id / product_id manquants');
    }
    await _warehouseRepo.registerManualEntry(
      companyId: companyId,
      productId: productId,
      quantity: _payloadInt(payload['quantity']),
      unitCost: _payloadDouble(payload['unit_cost']),
      packagingType: payload['packaging_type'] as String? ?? 'unite',
      packsQuantity: _payloadDouble(payload['packs_quantity'], fallback: 1),
      notes: payload['notes'] as String?,
    );
  }

  Future<void> _pushWarehouseDispatchInvoice(
    Map<String, dynamic> payload,
    Map<String, String> customerIdMap,
  ) async {
    final companyId = payload['company_id'] as String?;
    if (companyId == null) {
      throw StateError('warehouse_dispatch_invoice: company_id manquant');
    }
    var customerId = payload['customer_id'] as String?;
    if (customerId == null || customerId.trim().isEmpty) {
      throw StateError('warehouse_dispatch_invoice: customer_id obligatoire');
    }
    if (customerId.startsWith(_pendingCustomerPrefix)) {
      final resolved = customerIdMap[customerId];
      if (resolved == null || resolved.isEmpty) {
        throw StateError('warehouse_dispatch_invoice: client en attente de synchronisation');
      }
      customerId = resolved;
    }
    final rawLines = payload['lines'];
    if (rawLines is! List || rawLines.isEmpty) {
      throw StateError('warehouse_dispatch_invoice: lines manquantes ou vides');
    }
    final lines = <WarehouseDispatchLineInput>[];
    for (final e in rawLines) {
      final m = Map<String, dynamic>.from(e as Map);
      lines.add(
        WarehouseDispatchLineInput(
          productId: m['product_id'] as String,
          quantity: _payloadInt(m['quantity']),
          unitPrice: _payloadDouble(m['unit_price']),
        ),
      );
    }
    await _warehouseRepo.createDispatchInvoice(
      companyId: companyId,
      customerId: customerId,
      notes: payload['notes'] as String?,
      lines: lines,
    );
  }

  Future<void> _pushWarehouseAdjustment(Map<String, dynamic> payload) async {
    final companyId = payload['company_id'] as String?;
    final productId = payload['product_id'] as String?;
    if (companyId == null || productId == null) {
      throw StateError('warehouse_adjustment: company_id / product_id manquants');
    }
    final delta = _payloadInt(payload['delta']);
    final unitCost = payload['unit_cost'];
    await _warehouseRepo.registerAdjustment(
      companyId: companyId,
      productId: productId,
      delta: delta,
      unitCost: unitCost == null ? null : _payloadDouble(unitCost),
      reason: payload['reason'] as String?,
    );
  }

  Future<void> _pushWarehouseExitSale(Map<String, dynamic> payload) async {
    final companyId = payload['company_id'] as String?;
    final saleId = payload['sale_id'] as String?;
    if (companyId == null || saleId == null) {
      throw StateError('warehouse_exit_sale: company_id / sale_id manquants');
    }
    if (saleId.startsWith(_pendingCustomerPrefix)) {
      // Dépend d'abord de la sync de la vente. On conserve l'action en pending.
      throw StateError('warehouse_exit_sale: sale_id local en attente de sync');
    }
    await _warehouseRepo.registerExitForSale(companyId: companyId, saleId: saleId);
  }

  Future<void> _pushWarehouseSetThreshold(Map<String, dynamic> payload) async {
    if (_pushWarehouseSetThresholdOverride != null) {
      await _pushWarehouseSetThresholdOverride(payload);
      return;
    }
    final companyId = payload['company_id'] as String?;
    final productId = payload['product_id'] as String?;
    if (companyId == null || productId == null) {
      throw StateError('warehouse_set_threshold: company_id / product_id manquants');
    }
    await _warehouseRepo.setStockMinWarehouse(
      companyId: companyId,
      productId: productId,
      minValue: _payloadInt(payload['min']),
    );
  }

  static int _payloadInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static double _payloadDouble(Object? v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }

  static bool _isExpectedBusinessPushError(Object error) {
    final m = error.toString().toLowerCase();
    return m.contains('stock insuffisant') ||
        m.contains('sale_payments_amount_check') ||
        m.contains('warehouse_dispatch_invoice: client en attente de synchronisation') ||
        m.contains('warehouse_exit_sale: sale_id local en attente de sync');
  }

  static void _normalizeSalePaymentsInPlace(Map<String, dynamic> params) {
    final rawPayments = params['p_payments'];
    if (rawPayments is! List) return;

    final subtotal = _payloadDouble(params['p_subtotal']);
    final discount = _payloadDouble(params['p_discount']);
    final fallbackTotal = (subtotal - discount).clamp(0.0, double.infinity).toDouble();
    final rpcTotal = _extractTotalFromItems(params['p_items'], discount);
    final saleTotal = rpcTotal > 0 ? rpcTotal : fallbackTotal;
    final floorAmount = saleTotal > 0 ? 0.01 : 0.01;

    final normalized = <Map<String, dynamic>>[];
    for (final p in rawPayments) {
      if (p is! Map) continue;
      final row = Map<String, dynamic>.from(p);
      final amount = _payloadDouble(row['amount']);
      final safeAmount = saleTotal > 0
          ? (amount <= 0 ? saleTotal : amount.clamp(0.01, saleTotal).toDouble())
          : (amount <= 0 ? floorAmount : amount);
      row['amount'] = safeAmount;
      normalized.add(row);
    }
    if (normalized.isEmpty) {
      normalized.add({
        'method': 'cash',
        'amount': saleTotal > 0 ? saleTotal : floorAmount,
        'reference': null,
      });
    }
    params['p_payments'] = normalized;
  }

  static double _extractTotalFromItems(Object? rawItems, double discount) {
    if (rawItems is! List) return 0;
    double subtotal = 0;
    for (final item in rawItems) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final qty = _payloadInt(m['quantity']);
      final unitPrice = _payloadDouble(m['unit_price']);
      final lineDiscount = _payloadDouble(m['discount']);
      subtotal += (qty * unitPrice) - lineDiscount;
    }
    return (subtotal - discount).clamp(0.0, double.infinity).toDouble();
  }

  Future<void> _pushCreditAppendPayment(Map<String, dynamic> payload) async {
    final saleId = payload['sale_id'] as String?;
    final method = payload['method'] as String?;
    if (saleId == null || saleId.isEmpty || method == null || method.isEmpty) {
      throw ArgumentError('credit_append_payment: sale_id et method requis');
    }
    final amount = (payload['amount'] is num) ? (payload['amount'] as num).toDouble() : 0;
    if (amount <= 0) throw ArgumentError('credit_append_payment: montant invalide');
    final client = Supabase.instance.client;
    await client.rpc('append_sale_payment', params: {
      'p_sale_id': saleId,
      'p_method': method,
      'p_amount': amount,
      'p_reference': payload['reference'],
    });
    final now = DateTime.now().toUtc().toIso8601String();
    final pays = await _salesRepo.getPayments(saleId);
    await _db.replaceLocalSalePaymentsFromModels(saleId, pays, now);
  }

  Future<void> _pushCreditUpdateMeta(Map<String, dynamic> payload) async {
    final saleId = payload['sale_id'] as String?;
    if (saleId == null || saleId.isEmpty) {
      throw ArgumentError('credit_update_meta: sale_id requis');
    }
    final due = payload['credit_due_at'] as String?;
    final noteRaw = payload['credit_internal_note'];
    final note = noteRaw is String ? noteRaw : null;
    final trimmedNote = note == null
        ? null
        : (note.trim().isEmpty ? null : note.trim());
    final client = Supabase.instance.client;
    await client.from('sales').update({
      'credit_due_at': due,
      'credit_internal_note': trimmedNote,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', saleId);
    await _db.updateLocalSaleCreditMeta(saleId, due, trimmedNote);
  }

  bool _isRetryDue(int pendingId, int? updatedAtEpochMs) {
    final updatedAt = updatedAtEpochMs ?? 0;
    if (updatedAt <= 0) return true;
    final failCount = _pendingFailCounts[pendingId] ?? 0;
    final delayMs = retryDelayMsForFailCount(failCount);
    final elapsed = DateTime.now().millisecondsSinceEpoch - updatedAt;
    return elapsed >= delayMs;
  }

  @visibleForTesting
  static int retryDelayMsForFailCount(int failCount) {
    if (failCount <= 0) return 0;
    final exp = math.min(failCount - 1, 8);
    final delay = _baseRetryDelayMs * (1 << exp);
    return math.min(delay, _maxRetryDelayMs);
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

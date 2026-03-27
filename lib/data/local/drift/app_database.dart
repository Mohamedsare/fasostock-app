import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart' show SqliteException;

part 'app_database.g.dart';
// drift codegen

// ---------------------------------------------------------------------------
// Tables — offline-first local mirror of Supabase (indexed for performance)
// All reads from UI go to these tables first; sync updates them in background.
// Principe 3: index sur colonnes de filtre pour requêtes rapides (local + Supabase).
// ---------------------------------------------------------------------------

@TableIndex(name: 'idx_local_products_company_id', columns: {#companyId})
class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pce'))();
  RealColumn get purchasePrice => real().withDefault(const Constant(0))();
  RealColumn get salePrice => real().withDefault(const Constant(0))();
  RealColumn get minPrice => real().nullable()();
  IntColumn get stockMin => integer().withDefault(const Constant(0))();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get categoryId => text().nullable()();
  TextColumn get brandId => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  /// `both` | `warehouse_only` | `boutique_only` — aligné colonne Supabase `product_scope`.
  TextColumn get productScope => text().withDefault(const Constant('both'))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_store_inventory_store_id', columns: {#storeId})
class StoreInventory extends Table {
  TextColumn get storeId => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  IntColumn get reservedQuantity => integer().withDefault(const Constant(0))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {storeId, productId};
}

class LocalSales extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get storeId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get saleNumber => text()();
  TextColumn get status => text()();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  TextColumn get createdBy => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  /// quick_pos | invoice_pos — pour distinguer A4 vs Thermique dans la liste.
  TextColumn get saleMode => text().nullable()();
  /// thermal_receipt | a4_invoice — source de vérité pour l'affichage type document.
  TextColumn get documentType => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(LocalSales, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCustomers extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('individual'))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSuppliers extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get name => text()();
  TextColumn get contact => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_local_stores_company_id', columns: {#companyId})
class LocalStores extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get posDiscountEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text()();
  // Paramètres facture A4
  TextColumn get currency => text().nullable()();
  TextColumn get primaryColor => text().nullable()();
  TextColumn get secondaryColor => text().nullable()();
  TextColumn get invoicePrefix => text().nullable()();
  TextColumn get footerText => text().nullable()();
  TextColumn get legalInfo => text().nullable()();
  TextColumn get signatureUrl => text().nullable()();
  TextColumn get stampUrl => text().nullable()();
  TextColumn get paymentTerms => text().nullable()();
  TextColumn get taxLabel => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get commercialName => text().nullable()();
  TextColumn get slogan => text().nullable()();
  TextColumn get activity => text().nullable()();
  TextColumn get mobileMoney => text().nullable()();
  TextColumn get invoiceShortTitle => text().nullable()();
  TextColumn get invoiceSignerTitle => text().nullable()();
  TextColumn get invoiceSignerName => text().nullable()();
  TextColumn get invoiceTemplate => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_local_categories_company_id', columns: {#companyId})
class LocalCategories extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_local_brands_company_id', columns: {#companyId})
class LocalBrands extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_local_purchases_company_id', columns: {#companyId})
class LocalPurchases extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get storeId => text()();
  TextColumn get supplierId => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get status => text()();
  RealColumn get total => real()();
  TextColumn get createdBy => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text().references(LocalPurchases, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_local_transfers_company_id', columns: {#companyId})
class LocalTransfers extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get fromStoreId => text()();
  TextColumn get toStoreId => text()();
  BoolColumn get fromWarehouse => boolean().withDefault(const Constant(false))();
  TextColumn get status => text()();
  TextColumn get requestedBy => text()();
  TextColumn get approvedBy => text().nullable()();
  TextColumn get shippedAt => text().nullable()();
  TextColumn get receivedAt => text().nullable()();
  TextColumn get receivedBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalTransferItems extends Table {
  TextColumn get id => text()();
  TextColumn get transferId => text().references(LocalTransfers, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text()();
  IntColumn get quantityRequested => integer()();
  IntColumn get quantityShipped => integer().withDefault(const Constant(0))();
  IntColumn get quantityReceived => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stock magasin (dépôt central) — miroir offline.
@TableIndex(name: 'idx_local_wh_inv_company', columns: {#companyId})
class LocalWarehouseInventory extends Table {
  TextColumn get companyId => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  RealColumn get avgUnitCost => real().nullable()();
  IntColumn get stockMinWarehouse => integer().withDefault(const Constant(0))();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {companyId, productId};
}

/// Mouvements magasin — miroir offline (lecture).
@TableIndex(name: 'idx_local_wh_mov_company', columns: {#companyId})
class LocalWarehouseMovements extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get productId => text()();
  TextColumn get movementKind => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitCost => real().nullable()();
  TextColumn get packagingType => text().withDefault(const Constant('unite'))();
  RealColumn get packsQuantity => real().withDefault(const Constant(1))();
  TextColumn get referenceType => text().withDefault(const Constant('manual'))();
  TextColumn get referenceId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bons / factures de sortie dépôt — miroir offline (liste « Historiques des bons »).
@TableIndex(name: 'idx_local_wh_dispatch_company', columns: {#companyId})
class LocalWarehouseDispatchInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  TextColumn get documentNumber => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_local_stock_movements_store_id', columns: {#storeId})
class LocalStockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get productId => text()();
  TextColumn get type => text()();
  IntColumn get quantity => integer()();
  TextColumn get referenceType => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Paramètres société (ex: seuil alerte stock par défaut).
class LocalCompanySettings extends Table {
  TextColumn get companyId => text()();
  TextColumn get key => text()();
  TextColumn get valueText => text()();

  @override
  Set<Column> get primaryKey => {companyId, key};
}

/// Overrides stock_min par boutique/produit.
class LocalStockMinOverrides extends Table {
  TextColumn get storeId => text()();
  TextColumn get productId => text()();
  IntColumn get stockMinOverride => integer().nullable()();

  @override
  Set<Column> get primaryKey => {storeId, productId};
}

/// Membres entreprise (user_company_roles + rôle + profil) — offline-first écran Utilisateurs.
@TableIndex(name: 'idx_local_company_members_company_id', columns: {#companyId})
class LocalCompanyMembers extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get userId => text()();
  TextColumn get roleId => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt => text()();
  TextColumn get roleName => text()();
  TextColumn get roleSlug => text()();
  TextColumn get profileFullName => text().nullable()();
  TextColumn get email => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pending actions to push to Supabase (sales, stock adjustments, new customers, etc.).
@TableIndex(name: 'idx_pending_actions_synced', columns: {#synced})
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()(); // 'sale' | 'stock_adjustment' | 'customer' | 'product' | etc.
  TextColumn get payload => text()(); // JSON
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [
  LocalProducts,
  StoreInventory,
  LocalSales,
  LocalSaleItems,
  LocalCustomers,
  LocalSuppliers,
  LocalStores,
  LocalCategories,
  LocalBrands,
  LocalPurchases,
  LocalPurchaseItems,
  LocalTransfers,
  LocalTransferItems,
  LocalWarehouseInventory,
  LocalWarehouseMovements,
  LocalWarehouseDispatchInvoices,
  LocalStockMovements,
  LocalCompanySettings,
  LocalStockMinOverrides,
  LocalCompanyMembers,
  PendingActions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 21;

  /// Évite les erreurs « duplicate column name » si le fichier SQLite a été partiellement migré
  /// ou si `user_version` ne reflète pas le schéma réel.
  Future<bool> _sqliteColumnExists(String table, String column) async {
    final rows = await customSelect(
      "SELECT name FROM pragma_table_info('$table')",
      readsFrom: const {},
    ).get();
    for (final row in rows) {
      if (row.read<String>('name') == column) return true;
    }
    return false;
  }

  Future<bool> _sqliteTableExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$name' LIMIT 1",
      readsFrom: const {},
    ).get();
    return rows.isNotEmpty;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_products_company_id ON local_products(company_id)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_store_inventory_store_id ON store_inventory(store_id)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_pending_actions_synced ON pending_actions(synced)');
      }
      if (from < 3) {
        await migrator.createTable(localStores);
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_stores_company_id ON local_stores(company_id)');
      }
      if (from < 4) {
        await migrator.createTable(localCategories);
        await migrator.createTable(localBrands);
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_categories_company_id ON local_categories(company_id)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_brands_company_id ON local_brands(company_id)');
      }
      // v5: garantit que local_categories et local_brands existent (répare les bases déjà en v4 sans ces tables).
      if (from < 5) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS local_categories (
            id TEXT NOT NULL PRIMARY KEY,
            company_id TEXT NOT NULL,
            name TEXT NOT NULL,
            parent_id TEXT
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS local_brands (
            id TEXT NOT NULL PRIMARY KEY,
            company_id TEXT NOT NULL,
            name TEXT NOT NULL
          )
        ''');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_categories_company_id ON local_categories(company_id)');
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_brands_company_id ON local_brands(company_id)');
      }
      if (from < 6) {
        await migrator.createTable(localPurchases);
        await migrator.createTable(localPurchaseItems);
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_purchases_company_id ON local_purchases(company_id)');
      }
      if (from < 7) {
        await migrator.createTable(localTransfers);
        await migrator.createTable(localTransferItems);
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_transfers_company_id ON local_transfers(company_id)');
      }
      if (from < 8) {
        await migrator.createTable(localStockMovements);
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_stock_movements_store_id ON local_stock_movements(store_id)');
      }
      if (from < 9) {
        await migrator.createTable(localCompanySettings);
        await migrator.createTable(localStockMinOverrides);
      }
      if (from < 10) {
        await customStatement('ALTER TABLE local_stores ADD COLUMN currency TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN primary_color TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN secondary_color TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN invoice_prefix TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN footer_text TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN legal_info TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN signature_url TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN stamp_url TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN payment_terms TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN tax_label TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN tax_number TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN city TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN country TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN commercial_name TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN slogan TEXT');
      }
      if (from < 11) {
        await customStatement('ALTER TABLE local_stores ADD COLUMN invoice_short_title TEXT');
      }
      if (from < 12) {
        await customStatement('ALTER TABLE local_stores ADD COLUMN invoice_signer_title TEXT');
        await customStatement('ALTER TABLE local_stores ADD COLUMN invoice_signer_name TEXT');
      }
      if (from < 13) {
        await migrator.createTable(localCompanyMembers);
        await customStatement('CREATE INDEX IF NOT EXISTS idx_local_company_members_company_id ON local_company_members(company_id)');
      }
      if (from < 14) {
        await customStatement('ALTER TABLE local_products ADD COLUMN image_url TEXT');
      }
      if (from < 15) {
        await customStatement('ALTER TABLE local_stores ADD COLUMN activity TEXT');
      }
      if (from < 16) {
        await customStatement('ALTER TABLE local_sales ADD COLUMN sale_mode TEXT');
        await customStatement('ALTER TABLE local_sales ADD COLUMN document_type TEXT');
      }
      if (from < 17) {
        await customStatement('ALTER TABLE local_stores ADD COLUMN mobile_money TEXT');
      }
      if (from < 18) {
        await customStatement('ALTER TABLE local_stores ADD COLUMN invoice_template TEXT');
      }
      if (from < 19) {
        if (!await _sqliteColumnExists('local_transfers', 'from_warehouse')) {
          await customStatement('ALTER TABLE local_transfers ADD COLUMN from_warehouse INTEGER NOT NULL DEFAULT 0');
        }
        if (!await _sqliteTableExists('local_warehouse_inventory')) {
          await migrator.createTable(localWarehouseInventory);
        }
        if (!await _sqliteTableExists('local_warehouse_movements')) {
          await migrator.createTable(localWarehouseMovements);
        }
        await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_local_wh_inv_company ON local_warehouse_inventory(company_id)');
        await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_local_wh_mov_company ON local_warehouse_movements(company_id)');
      }
      if (from < 20) {
        if (!await _sqliteColumnExists('local_products', 'product_scope')) {
          await customStatement("ALTER TABLE local_products ADD COLUMN product_scope TEXT NOT NULL DEFAULT 'both'");
        }
      }
      if (from < 21) {
        if (!await _sqliteTableExists('local_warehouse_dispatch_invoices')) {
          await migrator.createTable(localWarehouseDispatchInvoices);
        }
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_local_wh_dispatch_company ON local_warehouse_dispatch_invoices(company_id)',
        );
      }
    },
  );

  /// Products: read from local (offline-first). UI watches this stream. Limit 10k for very large catalogs.
  Stream<List<LocalProduct>> watchLocalProducts(String companyId, {int limit = 10000, int offset = 0}) {
    return (select(localProducts)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit, offset: offset))
        .watch();
  }

  Future<List<LocalProduct>> getLocalProducts(String companyId, {int? limit, int? offset}) async {
    var q = select(localProducts)
        ..where((t) => t.companyId.equals(companyId))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (limit != null) q = q..limit(limit, offset: offset ?? 0);
    return q.get();
  }

  /// Taille des sous-lots pour éviter SQLITE_BUSY / « cannot commit … » sur Windows
  /// (drift en isolate + gros batch) et les transactions trop longues.
  static const int _upsertProductsChunkSize = 300;

  Future<void> upsertLocalProducts(Iterable<LocalProductsCompanion> items) async {
    final chunk = <LocalProductsCompanion>[];
    for (final item in items) {
      chunk.add(item);
      if (chunk.length >= _upsertProductsChunkSize) {
        await _upsertLocalProductsChunkWithRetry(chunk);
        chunk.clear();
      }
    }
    if (chunk.isNotEmpty) {
      await _upsertLocalProductsChunkWithRetry(chunk);
    }
  }

  Future<void> _upsertLocalProductsChunkWithRetry(List<LocalProductsCompanion> chunk) async {
    const maxAttempts = 4;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await batch((batch) {
          for (final item in chunk) {
            batch.insert(localProducts, item, mode: InsertMode.insertOrReplace);
          }
        });
        return;
      } on SqliteException catch (e) {
        final busy = e.resultCode == 5; // SQLITE_BUSY
        if (!busy || attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 40 * math.pow(2, attempt).toInt()));
      }
    }
  }

  /// Supprime de Drift les produits de la société qui ne sont plus dans [keepIds] (reflète les suppressions côté serveur).
  Future<void> deleteLocalProductsNotIn(String companyId, Set<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(localProducts)
          ..where((t) => t.companyId.equals(companyId) & t.id.isNotIn(keepIds)))
        .go();
  }

  /// Supprime un produit du cache local (après suppression côté serveur) — la liste se met à jour immédiatement.
  Future<void> deleteLocalProduct(String productId) async {
    await (delete(localProducts)..where((t) => t.id.equals(productId))).go();
  }

  Future<int> clearLocalProductsCatalog(String companyId) async {
    final rows = await (select(localProducts)..where((t) => t.companyId.equals(companyId))).get();
    if (rows.isEmpty) return 0;
    final n = rows.length;
    await (delete(localProducts)..where((t) => t.companyId.equals(companyId))).go();
    return n;
  }

  /// Met à jour isActive d'un produit en local (après activation/désactivation côté serveur) — mise à jour immédiate à l'écran.
  Future<void> updateLocalProductIsActive(String productId, bool isActive) async {
    await (update(localProducts)..where((t) => t.id.equals(productId)))
        .write(LocalProductsCompanion(isActive: Value(isActive)));
  }

  /// Store inventory: read/upsert by store.
  Future<Map<String, int>> getInventoryQuantities(String storeId) async {
    final rows = await (select(storeInventory)..where((t) => t.storeId.equals(storeId))).get();
    return {for (final r in rows) r.productId: r.quantity};
  }

  Stream<Map<String, int>> watchInventoryQuantities(String storeId) {
    return (select(storeInventory)..where((t) => t.storeId.equals(storeId)))
        .watch()
        .map((rows) => {for (final r in rows) r.productId: r.quantity});
  }

  Future<void> upsertInventory(String storeId, String productId, int quantity, String updatedAt) async {
    await into(storeInventory).insertOnConflictUpdate(
      StoreInventoryCompanion.insert(
        storeId: storeId,
        productId: productId,
        quantity: Value(quantity),
        reservedQuantity: const Value(0),
        updatedAt: updatedAt,
      ),
    );
  }

  /// Supprime les lignes de stock boutique absentes côté serveur (évite stock fantôme après pull).
  /// Même logique que [deleteLocalWarehouseInventoryNotIn].
  Future<void> deleteStoreInventoryNotIn(String storeId, Set<String> keepProductIds) async {
    if (keepProductIds.isEmpty) {
      await (delete(storeInventory)..where((t) => t.storeId.equals(storeId))).go();
      return;
    }
    await (delete(storeInventory)
          ..where((t) => t.storeId.equals(storeId) & t.productId.isNotIn(keepProductIds)))
        .go();
  }

  Future<int> clearLocalStock(String companyId, {String? storeId}) async {
    final targetStoreIds = <String>{};
    if (storeId != null && storeId.isNotEmpty) {
      targetStoreIds.add(storeId);
    } else {
      final stores = await (select(localStores)..where((t) => t.companyId.equals(companyId))).get();
      targetStoreIds.addAll(stores.map((s) => s.id));
    }
    int deleted = 0;
    if (targetStoreIds.isNotEmpty) {
      final invRows = await (select(storeInventory)..where((t) => t.storeId.isIn(targetStoreIds))).get();
      deleted += invRows.length;
      await (delete(storeInventory)..where((t) => t.storeId.isIn(targetStoreIds))).go();
    }
    if (storeId == null || storeId.isEmpty) {
      final whRows = await (select(localWarehouseInventory)..where((t) => t.companyId.equals(companyId))).get();
      deleted += whRows.length;
      await (delete(localWarehouseInventory)..where((t) => t.companyId.equals(companyId))).go();
    }
    return deleted;
  }

  /// Pending actions queue for sync (push to Supabase).
  Future<void> enqueuePendingAction(String kind, String payloadJson) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(pendingActions).insert(
      PendingActionsCompanion.insert(
        kind: kind,
        payload: payloadJson,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final rows = await (select(pendingActions)
          ..where((t) => t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows
        .map(
          (r) => {
            'id': r.id,
            'kind': r.kind,
            'payload': r.payload,
            'createdAt': r.createdAt,
            'updatedAt': r.updatedAt,
          },
        )
        .toList();
  }

  /// Stream du nombre d'actions en attente (pour afficher "X action(s) en attente" dans la bannière offline).
  Stream<int> watchPendingActionsCount() {
    return (select(pendingActions)..where((t) => t.synced.equals(false))).watch().map((list) => list.length);
  }

  Future<void> markPendingActionSynced(int id) async {
    await (update(pendingActions)..where((t) => t.id.equals(id))).write(const PendingActionsCompanion(synced: Value(true)));
  }

  /// Marque une tentative échouée pour appliquer un backoff basé sur [updatedAt].
  Future<void> markPendingActionFailed(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(pendingActions)..where((t) => t.id.equals(id))).write(PendingActionsCompanion(updatedAt: Value(now)));
  }

  /// Supprime l'action « transfer » non synchronisée liée à un brouillon local (local_id = id pending:…).
  Future<void> deleteUnsyncedPendingTransferByLocalId(String transferLocalId) async {
    final rows = await (select(pendingActions)
          ..where((t) => t.kind.equals('transfer') & t.synced.equals(false)))
        .get();
    for (final r in rows) {
      try {
        final m = jsonDecode(r.payload) as Map<String, dynamic>?;
        if (m != null && m['local_id'] == transferLocalId) {
          await (delete(pendingActions)..where((t) => t.id.equals(r.id))).go();
          return;
        }
      } catch (_) {}
    }
  }

  /// Customers: offline-first list by company.
  Stream<List<LocalCustomer>> watchLocalCustomers(String companyId) {
    return (select(localCustomers)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> upsertLocalCustomers(Iterable<LocalCustomersCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localCustomers, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Supprime un client local (ex. client pending après sync réussi).
  Future<void> deleteLocalCustomer(String id) async {
    await (delete(localCustomers)..where((t) => t.id.equals(id))).go();
  }

  /// Supprime les clients locaux absents du serveur (pull). Garde les `pending:xxx` (création hors ligne).
  Future<void> deleteLocalCustomersNotIn(String companyId, Set<String> keepIds) async {
    final rows = await (select(localCustomers)..where((t) => t.companyId.equals(companyId))).get();
    final toRemove = rows.map((r) => r.id).where((id) => !keepIds.contains(id) && !id.startsWith('pending:')).toSet();
    if (toRemove.isEmpty) return;
    await (delete(localCustomers)..where((t) => t.companyId.equals(companyId) & t.id.isIn(toRemove))).go();
  }

  /// Sales: offline-first list by company (optionally by store).
  Stream<List<LocalSale>> watchLocalSales(String companyId, {String? storeId}) {
    return (select(localSales)
          ..where((t) {
            var e = t.companyId.equals(companyId);
            if (storeId != null && storeId.isNotEmpty) e = e & t.storeId.equals(storeId);
            return e;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Émet à chaque changement des ventes ou achats pour la société — utilisé par le dashboard pour rafraîchir les KPIs en temps réel (sans casser offline+sync).
  Stream<void> watchDashboardDataTrigger(String companyId) {
    final c = StreamController<void>.broadcast(sync: true);
    late StreamSubscription<dynamic> sub1, sub2;
    sub1 = watchLocalSales(companyId).listen((_) => c.add(null));
    sub2 = watchLocalPurchases(companyId).listen((_) => c.add(null));
    c.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };
    return c.stream;
  }

  /// Sales dans une plage de dates (pour dashboard offline).
  Future<List<LocalSale>> getLocalSalesInRange(
    String companyId, {
    String? storeId,
    String? createdBy,
    String? fromDate,
    String? toDate,
  }) async {
    var q = select(localSales)
      ..where((t) {
        var e = t.companyId.equals(companyId) & t.status.equals('completed');
        if (storeId != null && storeId.isNotEmpty) e = e & t.storeId.equals(storeId);
        if (createdBy != null && createdBy.isNotEmpty) e = e & t.createdBy.equals(createdBy);
        if (fromDate != null && fromDate.isNotEmpty) e = e & t.createdAt.isBiggerOrEqualValue(fromDate);
        if (toDate != null && toDate.isNotEmpty) e = e & t.createdAt.isSmallerOrEqualValue('${toDate}T23:59:59.999Z');
        return e;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.get();
  }

  Future<List<LocalSaleItem>> getLocalSaleItems(String saleId) async {
    return (select(localSaleItems)..where((t) => t.saleId.equals(saleId))).get();
  }

  Future<List<LocalSaleItem>> getLocalSaleItemsForSales(List<String> saleIds) async {
    if (saleIds.isEmpty) return [];
    return (select(localSaleItems)..where((t) => t.saleId.isIn(saleIds))).get();
  }

  Future<void> upsertLocalSale(LocalSalesCompanion sale) async {
    await into(localSales).insertOnConflictUpdate(sale);
  }

  /// Met à jour le statut d'une vente en local (ex. après annulation).
  Future<void> updateLocalSaleStatus(String saleId, String status) async {
    await (update(localSales)..where((t) => t.id.equals(saleId)))
        .write(LocalSalesCompanion(status: Value(status)));
  }

  Future<void> upsertLocalSaleItems(Iterable<LocalSaleItemsCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localSaleItems, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalSaleItemsBySaleId(String saleId) async {
    await (delete(localSaleItems)..where((t) => t.saleId.equals(saleId))).go();
  }

  Future<void> deleteLocalSale(String saleId) async {
    await (delete(localSales)..where((t) => t.id.equals(saleId))).go();
  }

  Future<int> clearLocalSalesHistory(String companyId, {String? storeId}) async {
    final salesToDelete = await (select(localSales)..where((t) {
          var e = t.companyId.equals(companyId);
          if (storeId != null && storeId.isNotEmpty) {
            e = e & t.storeId.equals(storeId);
          }
          return e;
        }))
        .get();
    if (salesToDelete.isEmpty) return 0;
    final ids = salesToDelete.map((s) => s.id).toList();
    await (delete(localSaleItems)..where((t) => t.saleId.isIn(ids))).go();
    await (delete(localSales)..where((t) => t.id.isIn(ids))).go();
    return ids.length;
  }

  /// Stores: offline-first list by company.
  Stream<List<LocalStore>> watchLocalStores(String companyId) {
    return (select(localStores)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<LocalStore>> getLocalStores(String companyId) async {
    return (select(localStores)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<void> upsertLocalStores(Iterable<LocalStoresCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localStores, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Suppliers: offline-first list by company.
  Stream<List<LocalSupplier>> watchLocalSuppliers(String companyId) {
    return (select(localSuppliers)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<LocalSupplier>> getLocalSuppliers(String companyId) async {
    return (select(localSuppliers)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<void> upsertLocalSuppliers(Iterable<LocalSuppliersCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localSuppliers, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalSupplier(String id) async {
    await (delete(localSuppliers)..where((t) => t.id.equals(id))).go();
  }

  /// Categories: offline-first list by company.
  Stream<List<LocalCategory>> watchLocalCategories(String companyId) {
    return (select(localCategories)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> upsertLocalCategories(Iterable<LocalCategoriesCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localCategories, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalCategory(String id) async {
    await (delete(localCategories)..where((t) => t.id.equals(id))).go();
  }

  /// Brands: offline-first list by company.
  Stream<List<LocalBrand>> watchLocalBrands(String companyId) {
    return (select(localBrands)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> upsertLocalBrands(Iterable<LocalBrandsCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localBrands, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalBrand(String id) async {
    await (delete(localBrands)..where((t) => t.id.equals(id))).go();
  }

  /// Purchases: offline-first list by company with optional filters.
  Stream<List<LocalPurchase>> watchLocalPurchases(
    String companyId, {
    String? storeId,
    String? supplierId,
    String? status,
    String? fromDate,
    String? toDate,
  }) {
    return (select(localPurchases)
          ..where((t) {
            var e = t.companyId.equals(companyId);
            if (storeId != null && storeId.isNotEmpty) e = e & t.storeId.equals(storeId);
            if (supplierId != null && supplierId.isNotEmpty) e = e & t.supplierId.equals(supplierId);
            if (status != null && status.isNotEmpty) e = e & t.status.equals(status);
            if (fromDate != null && fromDate.isNotEmpty) e = e & t.createdAt.isBiggerOrEqualValue(fromDate);
            if (toDate != null && toDate.isNotEmpty) e = e & t.createdAt.isSmallerOrEqualValue('${toDate}T23:59:59.999Z');
            return e;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<LocalPurchase>> getLocalPurchases(
    String companyId, {
    String? storeId,
    String? supplierId,
    String? status,
    String? fromDate,
    String? toDate,
  }) async {
    var q = select(localPurchases)
      ..where((t) {
        var e = t.companyId.equals(companyId);
        if (storeId != null && storeId.isNotEmpty) e = e & t.storeId.equals(storeId);
        if (supplierId != null && supplierId.isNotEmpty) e = e & t.supplierId.equals(supplierId);
        if (status != null && status.isNotEmpty) e = e & t.status.equals(status);
        if (fromDate != null && fromDate.isNotEmpty) e = e & t.createdAt.isBiggerOrEqualValue(fromDate);
        if (toDate != null && toDate.isNotEmpty) e = e & t.createdAt.isSmallerOrEqualValue('${toDate}T23:59:59.999Z');
        return e;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.get();
  }

  Future<List<LocalPurchaseItem>> getLocalPurchaseItemsForPurchases(List<String> purchaseIds) async {
    if (purchaseIds.isEmpty) return [];
    return (select(localPurchaseItems)..where((t) => t.purchaseId.isIn(purchaseIds))).get();
  }

  /// Stream des lignes d'achat pour une société (pour réagir aux changements items + achats).
  Stream<void> watchLocalPurchaseItemsForCompany(String companyId) {
    final query = select(localPurchaseItems).join([
      innerJoin(localPurchases, localPurchaseItems.purchaseId.equalsExp(localPurchases.id)),
    ])..where(localPurchases.companyId.equals(companyId));
    return query.watch().map((_) {});
  }

  Future<void> upsertLocalPurchases(Iterable<LocalPurchasesCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localPurchases, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> updateLocalPurchaseStatus(String purchaseId, String status) async {
    await (update(localPurchases)..where((t) => t.id.equals(purchaseId)))
        .write(LocalPurchasesCompanion(status: Value(status)));
  }

  Future<void> upsertLocalPurchaseItems(Iterable<LocalPurchaseItemsCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localPurchaseItems, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Supprime les lignes d'achat pour les achats donnés (avant remplacement par le sync).
  Future<void> deleteLocalPurchaseItemsForPurchases(List<String> purchaseIds) async {
    if (purchaseIds.isEmpty) return;
    await (delete(localPurchaseItems)..where((t) => t.purchaseId.isIn(purchaseIds))).go();
  }

  Future<void> deleteLocalPurchase(String purchaseId) async {
    await (delete(localPurchaseItems)..where((t) => t.purchaseId.equals(purchaseId))).go();
    await (delete(localPurchases)..where((t) => t.id.equals(purchaseId))).go();
  }

  Future<int> clearLocalPurchasesHistory(String companyId, {String? storeId}) async {
    final purchasesToDelete = await (select(localPurchases)..where((t) {
          var e = t.companyId.equals(companyId);
          if (storeId != null && storeId.isNotEmpty) {
            e = e & t.storeId.equals(storeId);
          }
          return e;
        }))
        .get();
    if (purchasesToDelete.isEmpty) return 0;
    final ids = purchasesToDelete.map((p) => p.id).toList();
    await (delete(localPurchaseItems)..where((t) => t.purchaseId.isIn(ids))).go();
    await (delete(localPurchases)..where((t) => t.id.isIn(ids))).go();
    return ids.length;
  }

  Future<void> deleteLocalPurchasesNotIn(String companyId, Set<String> keepIds) async {
    await (delete(localPurchases)
          ..where((t) => t.companyId.equals(companyId) & t.id.isNotIn(keepIds)))
        .go();
  }

  /// Transferts: offline-first list by company with optional filters.
  Stream<List<LocalTransfer>> watchLocalTransfers(
    String companyId, {
    String? fromStoreId,
    String? toStoreId,
    String? status,
    String? fromDate,
    String? toDate,
  }) {
    return (select(localTransfers)
          ..where((t) {
            var e = t.companyId.equals(companyId);
            if (fromStoreId != null && fromStoreId.isNotEmpty) e = e & t.fromStoreId.equals(fromStoreId);
            if (toStoreId != null && toStoreId.isNotEmpty) e = e & t.toStoreId.equals(toStoreId);
            if (status != null && status.isNotEmpty) e = e & t.status.equals(status);
            if (fromDate != null && fromDate.isNotEmpty) e = e & t.createdAt.isBiggerOrEqualValue(fromDate);
            if (toDate != null && toDate.isNotEmpty) e = e & t.createdAt.isSmallerOrEqualValue('${toDate}T23:59:59.999Z');
            return e;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<LocalTransfer>> getLocalTransfers(
    String companyId, {
    String? fromStoreId,
    String? toStoreId,
    String? status,
    String? fromDate,
    String? toDate,
  }) async {
    var q = select(localTransfers)
      ..where((t) {
        var e = t.companyId.equals(companyId);
        if (fromStoreId != null && fromStoreId.isNotEmpty) e = e & t.fromStoreId.equals(fromStoreId);
        if (toStoreId != null && toStoreId.isNotEmpty) e = e & t.toStoreId.equals(toStoreId);
        if (status != null && status.isNotEmpty) e = e & t.status.equals(status);
        if (fromDate != null && fromDate.isNotEmpty) e = e & t.createdAt.isBiggerOrEqualValue(fromDate);
        if (toDate != null && toDate.isNotEmpty) e = e & t.createdAt.isSmallerOrEqualValue('${toDate}T23:59:59.999Z');
        return e;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return q.get();
  }

  Future<List<LocalTransferItem>> getLocalTransferItemsForTransfers(List<String> transferIds) async {
    if (transferIds.isEmpty) return [];
    return (select(localTransferItems)..where((t) => t.transferId.isIn(transferIds))).get();
  }

  Future<void> upsertLocalTransfers(Iterable<LocalTransfersCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localTransfers, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> upsertLocalTransferItems(Iterable<LocalTransferItemsCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localTransferItems, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalTransferItemsForTransfers(List<String> transferIds) async {
    if (transferIds.isEmpty) return;
    await (delete(localTransferItems)..where((t) => t.transferId.isIn(transferIds))).go();
  }

  Future<void> deleteLocalTransfer(String transferId) async {
    await deleteLocalTransferItemsForTransfers([transferId]);
    await (delete(localTransfers)..where((t) => t.id.equals(transferId))).go();
  }

  Future<int> clearLocalTransfersHistory(String companyId, {String? storeId}) async {
    final transfersToDelete = await (select(localTransfers)..where((t) {
          var e = t.companyId.equals(companyId);
          if (storeId != null && storeId.isNotEmpty) {
            e = e & (t.fromStoreId.equals(storeId) | t.toStoreId.equals(storeId));
          }
          return e;
        }))
        .get();
    if (transfersToDelete.isEmpty) return 0;
    final ids = transfersToDelete.map((t) => t.id).toList();
    await (delete(localTransferItems)..where((t) => t.transferId.isIn(ids))).go();
    await (delete(localTransfers)..where((t) => t.id.isIn(ids))).go();
    return ids.length;
  }

  Future<void> deleteLocalTransfersNotIn(String companyId, Set<String> keepIds) async {
    await (delete(localTransfers)
          ..where((t) => t.companyId.equals(companyId) & t.id.isNotIn(keepIds)))
        .go();
  }

  /// Mouvements de stock : lecture locale par boutique (jusqu'à 500 derniers pour historique).
  Stream<List<LocalStockMovement>> watchLocalStockMovements(String storeId, {int limit = 500}) {
    return (select(localStockMovements)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> upsertLocalStockMovements(Iterable<LocalStockMovementsCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localStockMovements, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalStockMovementsNotIn(String storeId, Set<String> keepIds) async {
    await (delete(localStockMovements)
          ..where((t) => t.storeId.equals(storeId) & t.id.isNotIn(keepIds)))
        .go();
  }

  Future<int> clearLocalStockMovementsHistory(String companyId, {String? storeId}) async {
    int deleted = 0;
    if (storeId != null && storeId.isNotEmpty) {
      final rows = await (select(localStockMovements)..where((t) => t.storeId.equals(storeId))).get();
      deleted += rows.length;
      await (delete(localStockMovements)..where((t) => t.storeId.equals(storeId))).go();
      return deleted;
    }
    final stores = await (select(localStores)..where((t) => t.companyId.equals(companyId))).get();
    final ids = stores.map((s) => s.id).toSet();
    if (ids.isNotEmpty) {
      final rows = await (select(localStockMovements)..where((t) => t.storeId.isIn(ids))).get();
      deleted += rows.length;
      await (delete(localStockMovements)..where((t) => t.storeId.isIn(ids))).go();
    }
    final whRows = await (select(localWarehouseMovements)..where((t) => t.companyId.equals(companyId))).get();
    deleted += whRows.length;
    await (delete(localWarehouseMovements)..where((t) => t.companyId.equals(companyId))).go();
    return deleted;
  }

  /// Nettoie uniquement le stock dépôt local (sans toucher les boutiques).
  Future<int> clearLocalWarehouseStock(String companyId) async {
    final rows = await (select(localWarehouseInventory)
          ..where((t) => t.companyId.equals(companyId)))
        .get();
    if (rows.isEmpty) return 0;
    await (delete(localWarehouseInventory)..where((t) => t.companyId.equals(companyId))).go();
    return rows.length;
  }

  /// Nettoie uniquement les mouvements dépôt locaux (sans toucher les boutiques).
  Future<int> clearLocalWarehouseMovementsHistory(String companyId) async {
    final rows = await (select(localWarehouseMovements)
          ..where((t) => t.companyId.equals(companyId)))
        .get();
    if (rows.isEmpty) return 0;
    await (delete(localWarehouseMovements)..where((t) => t.companyId.equals(companyId))).go();
    return rows.length;
  }

  /// Date d’entrée en boutique par produit : plus ancien mouvement de stock pour chaque produit dans [storeId].
  /// Utilisé pour « produits non vendus depuis 1 mois » (on ne compte que les produits présents depuis au moins 1 mois).
  Future<Map<String, String>> getEarliestStockMovementDateByProduct(String storeId) async {
    final rows = await (select(localStockMovements)..where((t) => t.storeId.equals(storeId))).get();
    final map = <String, String>{};
    for (final r in rows) {
      final existing = map[r.productId];
      if (existing == null || r.createdAt.compareTo(existing) < 0) {
        map[r.productId] = r.createdAt;
      }
    }
    return map;
  }

  static const String _keyDefaultStockAlert = 'default_stock_alert_threshold';

  /// Seuil alerte stock par défaut (société) — stream.
  Stream<int> watchDefaultStockAlertThreshold(String companyId) {
    return (select(localCompanySettings)
          ..where((t) => t.companyId.equals(companyId) & t.key.equals(_keyDefaultStockAlert)))
        .watch()
        .map((rows) {
          if (rows.isEmpty) return 5;
          final v = rows.first.valueText;
          final n = int.tryParse(v);
          return n != null && n >= 0 ? n : 5;
        });
  }

  Future<void> upsertDefaultStockAlertThreshold(String companyId, int value) async {
    await into(localCompanySettings).insertOnConflictUpdate(
      LocalCompanySettingsCompanion.insert(
        companyId: companyId,
        key: _keyDefaultStockAlert,
        valueText: value.toString(),
      ),
    );
  }

  Future<int> getDefaultStockAlertThreshold(String companyId) async {
    final rows = await (select(localCompanySettings)
          ..where((t) => t.companyId.equals(companyId) & t.key.equals(_keyDefaultStockAlert)))
        .get();
    if (rows.isEmpty) return 5;
    final n = int.tryParse(rows.first.valueText);
    return n != null && n >= 0 ? n : 5;
  }

  Future<Map<String, int?>> getStockMinOverrides(String storeId) async {
    final rows = await (select(localStockMinOverrides)..where((t) => t.storeId.equals(storeId))).get();
    return {for (final r in rows) r.productId: r.stockMinOverride};
  }

  /// Overrides stock_min par boutique — stream.
  Stream<Map<String, int?>> watchStockMinOverrides(String storeId) {
    return (select(localStockMinOverrides)..where((t) => t.storeId.equals(storeId)))
        .watch()
        .map((rows) => {for (final r in rows) r.productId: r.stockMinOverride});
  }

  Future<void> upsertStockMinOverrides(String storeId, Map<String, int?> overrides) async {
    await batch((batch) {
      for (final e in overrides.entries) {
        batch.insert(
          localStockMinOverrides,
          LocalStockMinOverridesCompanion.insert(
            storeId: storeId,
            productId: e.key,
            stockMinOverride: Value(e.value),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> deleteStockMinOverridesNotIn(String storeId, Set<String> productIds) async {
    await (delete(localStockMinOverrides)
          ..where((t) => t.storeId.equals(storeId) & t.productId.isNotIn(productIds)))
        .go();
  }

  /// Membres entreprise : offline-first écran Utilisateurs.
  Stream<List<LocalCompanyMember>> watchLocalCompanyMembers(String companyId) {
    return (select(localCompanyMembers)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<void> upsertLocalCompanyMembers(Iterable<LocalCompanyMembersCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localCompanyMembers, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalCompanyMember(String id) async {
    await (delete(localCompanyMembers)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteLocalCompanyMembersNotIn(String companyId, Set<String> keepIds) async {
    if (keepIds.isEmpty) return;
    await (delete(localCompanyMembers)
          ..where((t) => t.companyId.equals(companyId) & t.id.isNotIn(keepIds)))
        .go();
  }

  Future<void> updateLocalCompanyMemberIsActive(String id, bool isActive) async {
    await (update(localCompanyMembers)..where((t) => t.id.equals(id)))
        .write(LocalCompanyMembersCompanion(isActive: Value(isActive)));
  }

  // --- Magasin (dépôt central) offline ---

  Stream<List<LocalWarehouseInventoryData>> watchLocalWarehouseInventory(String companyId) {
    return (select(localWarehouseInventory)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<Map<String, int>> getWarehouseInventoryQuantities(String companyId) async {
    final rows = await (select(localWarehouseInventory)..where((t) => t.companyId.equals(companyId))).get();
    return {for (final r in rows) r.productId: r.quantity};
  }

  Future<void> upsertLocalWarehouseInventory(Iterable<LocalWarehouseInventoryCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localWarehouseInventory, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalWarehouseInventoryNotIn(String companyId, Set<String> keepProductIds) async {
    if (keepProductIds.isEmpty) {
      await (delete(localWarehouseInventory)..where((t) => t.companyId.equals(companyId))).go();
      return;
    }
    await (delete(localWarehouseInventory)
          ..where((t) => t.companyId.equals(companyId) & t.productId.isNotIn(keepProductIds)))
        .go();
  }

  Stream<List<LocalWarehouseMovement>> watchLocalWarehouseMovements(String companyId, {int limit = 300}) {
    return (select(localWarehouseMovements)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> upsertLocalWarehouseMovements(Iterable<LocalWarehouseMovementsCompanion> items) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localWarehouseMovements, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalWarehouseMovementsNotIn(String companyId, Set<String> keepIds) async {
    if (keepIds.isEmpty) {
      await (delete(localWarehouseMovements)..where((t) => t.companyId.equals(companyId))).go();
      return;
    }
    await (delete(localWarehouseMovements)
          ..where((t) => t.companyId.equals(companyId) & t.id.isNotIn(keepIds)))
        .go();
  }

  Stream<List<LocalWarehouseDispatchInvoice>> watchLocalWarehouseDispatchInvoices(String companyId) {
    return (select(localWarehouseDispatchInvoices)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<void> upsertLocalWarehouseDispatchInvoices(
    Iterable<LocalWarehouseDispatchInvoicesCompanion> items,
  ) async {
    await batch((batch) {
      for (final item in items) {
        batch.insert(localWarehouseDispatchInvoices, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> deleteLocalWarehouseDispatchInvoicesNotIn(String companyId, Set<String> keepIds) async {
    if (keepIds.isEmpty) {
      await (delete(localWarehouseDispatchInvoices)..where((t) => t.companyId.equals(companyId))).go();
      return;
    }
    await (delete(localWarehouseDispatchInvoices)
          ..where((t) => t.companyId.equals(companyId) & t.id.isNotIn(keepIds)))
        .go();
  }

  /// Retire un bon du cache local (ex. après annulation côté serveur).
  Future<void> deleteLocalWarehouseDispatchInvoice(String invoiceId) async {
    await (delete(localWarehouseDispatchInvoices)..where((t) => t.id.equals(invoiceId))).go();
  }

  /// Vide le cache local des bons dépôt (sans toucher le serveur).
  Future<int> clearLocalWarehouseDispatchInvoices(String companyId) async {
    final rows = await (select(localWarehouseDispatchInvoices)
          ..where((t) => t.companyId.equals(companyId)))
        .get();
    if (rows.isEmpty) return 0;
    await (delete(localWarehouseDispatchInvoices)..where((t) => t.companyId.equals(companyId))).go();
    return rows.length;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Sur Windows, getApplicationSupportDirectory() évite Documents/OneDrive et permissions.
    final dbDir = await getApplicationSupportDirectory();
    final dir = Directory(dbDir.path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dbDir.path, 'fasostock_drift.db'));
    return NativeDatabase.createInBackground(
    file,
    setup: (db) {
      // Windows: SQLite peut renvoyer SQLITE_BUSY si le commit arrive trop tôt
      // ou en concurrence avec d’autres lecteurs ; WAL + busy_timeout réduit fortement les échecs.
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = NORMAL');
    },
  );
  });
}

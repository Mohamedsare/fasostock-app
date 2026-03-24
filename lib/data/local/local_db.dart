import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base de données locale : cache (produits, stock, clients, boutiques) + file des ventes en attente.
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const String _dbName = 'fasostock_offline.db';
  static const int _version = 2;

  Database? _db;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final dbPath = join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      dbPath,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _initialized = true;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_sales (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await _createPendingCustomersAndAdjustments(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createPendingCustomersAndAdjustments(db);
  }

  Future<void> _createPendingCustomersAndAdjustments(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_customers (
        local_id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        type TEXT NOT NULL DEFAULT 'individual',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_stock_adjustments (
        id TEXT PRIMARY KEY,
        store_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Database? get _database => _db;

  bool get isReady => _initialized && _db != null;

  // ---- Cache générique (key = "products:$companyId", "inventory:$storeId", etc.) ----

  Future<void> setCache(String key, String value) async {
    final d = _database;
    if (d == null) return;
    await d.insert(
      'cache',
      {'key': key, 'value': value, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCache(String key) async {
    final d = _database;
    if (d == null) return null;
    final rows = await d.query('cache', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> removeCache(String key) async {
    final d = _database;
    if (d == null) return;
    await d.delete('cache', where: 'key = ?', whereArgs: [key]);
  }

  static String _productsKey(String companyId) => 'products:$companyId';
  static String _inventoryKey(String storeId) => 'inventory:$storeId';
  static String _customersKey(String companyId) => 'customers:$companyId';
  static String _storesKey(String companyId) => 'stores:$companyId';

  Future<void> saveProducts(String companyId, List<Map<String, dynamic>> list) async {
    await setCache(_productsKey(companyId), jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>?> getProducts(String companyId) async {
    final raw = await getCache(_productsKey(companyId));
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveInventory(String storeId, Map<String, int> map) async {
    final list = map.entries.map((e) => {'product_id': e.key, 'quantity': e.value}).toList();
    await setCache(_inventoryKey(storeId), jsonEncode(list));
  }

  Future<Map<String, int>?> getInventory(String storeId) async {
    final raw = await getCache(_inventoryKey(storeId));
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    final out = <String, int>{};
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final pid = m['product_id'] as String?;
      final q = m['quantity'];
      if (pid != null && q != null) out[pid] = (q is int) ? q : (q as num).toInt();
    }
    return out;
  }

  Future<void> saveCustomers(String companyId, List<Map<String, dynamic>> list) async {
    await setCache(_customersKey(companyId), jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>?> getCustomers(String companyId) async {
    final raw = await getCache(_customersKey(companyId));
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveStores(String companyId, List<Map<String, dynamic>> list) async {
    await setCache(_storesKey(companyId), jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>?> getStores(String companyId) async {
    final raw = await getCache(_storesKey(companyId));
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---- Pending sales (ventes en attente de sync) ----

  Future<void> enqueuePendingSale(String id, Map<String, dynamic> payload) async {
    final d = _database;
    if (d == null) return;
    await d.insert(
      'pending_sales',
      {
        'id': id,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    final d = _database;
    if (d == null) return [];
    final rows = await d.query('pending_sales', orderBy: 'created_at ASC');
    return rows.map((r) {
      final payload = r['payload'] as String?;
      return {'id': r['id'], 'payload': payload != null ? jsonDecode(payload) as Map<String, dynamic> : <String, dynamic>{}};
    }).toList();
  }

  Future<void> removePendingSale(String id) async {
    final d = _database;
    if (d == null) return;
    await d.delete('pending_sales', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingSalesCount() async {
    final d = _database;
    if (d == null) return 0;
    final r = await d.rawQuery('SELECT COUNT(*) as c FROM pending_sales');
    return (r.first['c'] as int?) ?? 0;
  }

  // ---- Pending customers (création client hors ligne) ----

  Future<void> enqueuePendingCustomer({
    required String localId,
    required String companyId,
    required String name,
    String? phone,
    String type = 'individual',
  }) async {
    final d = _database;
    if (d == null) return;
    await d.insert(
      'pending_customers',
      {
        'local_id': localId,
        'company_id': companyId,
        'name': name,
        'phone': phone,
        'type': type,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingCustomers() async {
    final d = _database;
    if (d == null) return [];
    final rows = await d.query('pending_customers', orderBy: 'created_at ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> removePendingCustomer(String localId) async {
    final d = _database;
    if (d == null) return;
    await d.delete('pending_customers', where: 'local_id = ?', whereArgs: [localId]);
  }

  // ---- Pending stock adjustments ----

  Future<void> enqueuePendingStockAdjustment({
    required String id,
    required String storeId,
    required String productId,
    required int delta,
    required String reason,
    required String userId,
  }) async {
    final d = _database;
    if (d == null) return;
    await d.insert(
      'pending_stock_adjustments',
      {
        'id': id,
        'store_id': storeId,
        'product_id': productId,
        'delta': delta,
        'reason': reason,
        'user_id': userId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingStockAdjustments() async {
    final d = _database;
    if (d == null) return [];
    final rows = await d.query('pending_stock_adjustments', orderBy: 'created_at ASC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> removePendingStockAdjustment(String id) async {
    final d = _database;
    if (d == null) return;
    await d.delete('pending_stock_adjustments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _initialized = false;
    }
  }
}

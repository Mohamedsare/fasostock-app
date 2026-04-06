import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fasostock/data/local/drift/app_database.dart';
import 'package:fasostock/data/models/product_image.dart';
import 'package:fasostock/data/repositories/offline/products_offline_repository.dart';
import 'package:fasostock/data/repositories/products_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key-for-unit-tests',
    );
  });

  /// [ProductsRepository] exige un client Supabase initialisé ; ces tests n’appellent pas le réseau.
  late ProductsRepository remote;

  setUp(() {
    remote = ProductsRepository();
  });

  group('ProductsOfflineRepository', () {
    test('applyRealtimeRow preserves local image_url when payload has no images', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ProductsOfflineRepository(db, remote);

      await db.upsertLocalProducts([
        LocalProductsCompanion.insert(
          id: 'p1',
          companyId: 'c1',
          name: 'Item',
          imageUrl: const Value('https://keep.example/a.png'),
          updatedAt: '2020-01-01T00:00:00.000Z',
        ),
      ]);

      await repo.applyRealtimeRow({
        'id': 'p1',
        'company_id': 'c1',
        'name': 'Item renamed',
        'unit': 'pce',
        'purchase_price': 1,
        'sale_price': 2,
        'stock_min': 0,
        'is_active': true,
        'product_scope': 'both',
        'updated_at': '2020-01-02T00:00:00.000Z',
      });

      final rows = await db.getLocalProducts('c1');
      expect(rows.single.imageUrl, 'https://keep.example/a.png');
      expect(rows.single.name, 'Item renamed');
    });

    test('applyRealtimeRow removes local product when deleted_at is set', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ProductsOfflineRepository(db, remote);

      await db.upsertLocalProducts([
        LocalProductsCompanion.insert(
          id: 'p1',
          companyId: 'c1',
          name: 'Item',
          updatedAt: '2020-01-01T00:00:00.000Z',
        ),
      ]);

      await repo.applyRealtimeRow({
        'id': 'p1',
        'company_id': 'c1',
        'name': 'Item',
        'deleted_at': '2020-06-01T12:00:00.000Z',
      });

      final rows = await db.getLocalProducts('c1');
      expect(rows, isEmpty);
    });

    test('applyPrimaryImageUrl uses smallest position', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ProductsOfflineRepository(db, remote);

      await db.upsertLocalProducts([
        LocalProductsCompanion.insert(
          id: 'p1',
          companyId: 'c1',
          name: 'Item',
          updatedAt: '2020-01-01T00:00:00.000Z',
        ),
      ]);

      await repo.applyPrimaryImageUrl('p1', [
        const ProductImage(id: 'i2', productId: 'p1', url: 'https://b.png', position: 2),
        const ProductImage(id: 'i0', productId: 'p1', url: 'https://a.png', position: 0),
      ]);

      final rows = await db.getLocalProducts('c1');
      expect(rows.single.imageUrl, 'https://a.png');
    });

    test('refreshPrimaryImageFromRemote uses testGetImages when provided', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ProductsOfflineRepository(
        db,
        remote,
        testGetImages: (id) async {
          expect(id, 'p1');
          return [
            const ProductImage(id: 'i0', productId: 'p1', url: 'https://remote.png', position: 1),
          ];
        },
      );

      await db.upsertLocalProducts([
        LocalProductsCompanion.insert(
          id: 'p1',
          companyId: 'c1',
          name: 'Item',
          updatedAt: '2020-01-01T00:00:00.000Z',
        ),
      ]);

      await repo.refreshPrimaryImageFromRemote('p1');

      final rows = await db.getLocalProducts('c1');
      expect(rows.single.imageUrl, 'https://remote.png');
    });

    test('applyPrimaryImageUrl no-op if product absent locally', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ProductsOfflineRepository(db, remote);

      await repo.applyPrimaryImageUrl('missing', [
        const ProductImage(id: 'i', productId: 'missing', url: 'https://x.png', position: 0),
      ]);

      final rows = await db.getLocalProducts('c1');
      expect(rows, isEmpty);
    });
  });
}

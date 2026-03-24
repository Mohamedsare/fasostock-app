import 'package:drift/drift.dart';

import '../../local/drift/app_database.dart';
import '../../models/product.dart';
import '../../models/product_image.dart';
import '../products_repository.dart';

/// Offline-first products: UI reads from Drift; sync service writes from Supabase.
/// Pattern: UI → Provider → this repo → Drift (read) / Drift + PendingActions (write).
class ProductsOfflineRepository {
  ProductsOfflineRepository(this._db, this._supabaseRepo);

  final AppDatabase _db;
  final ProductsRepository _supabaseRepo;

  /// Stream products from local DB — UI never waits for network. Limit 10k for very large catalogs (offline+sync).
  Stream<List<Product>> watchProducts(String companyId, {int limit = 10000, int offset = 0}) {
    return _db
        .watchLocalProducts(companyId, limit: limit, offset: offset)
        .map((rows) => rows.map(_localToProduct).toList());
  }

  /// One-shot read from local (e.g. for search with pagination).
  Future<List<Product>> getProductsLocal(String companyId, {int? limit, int? offset}) async {
    final rows = await _db.getLocalProducts(companyId, limit: limit, offset: offset);
    return rows.map(_localToProduct).toList();
  }

  static Product _localToProduct(LocalProduct row) {
    final String? imageUrl = row.imageUrl;
    final List<ProductImage>? productImages = imageUrl != null && imageUrl.isNotEmpty
        ? [ProductImage(id: '${row.id}-img', productId: row.id, url: imageUrl, position: 0)]
        : null;
    return Product(
      id: row.id,
      companyId: row.companyId,
      name: row.name,
      sku: row.sku,
      barcode: row.barcode,
      unit: row.unit,
      purchasePrice: row.purchasePrice,
      salePrice: row.salePrice,
      minPrice: row.minPrice,
      stockMin: row.stockMin,
      description: row.description,
      isActive: row.isActive,
      categoryId: row.categoryId,
      brandId: row.brandId,
      category: null,
      brand: null,
      productImages: productImages,
      productScope: row.productScope,
    );
  }

  /// Upsert un seul produit en local (après création ou modification côté serveur) — mise à jour immédiate à l'écran.
  Future<void> upsertProduct(Product p) async {
    await upsertFromRemote([p]);
  }

  /// Write from sync: upsert products from Supabase into Drift (uses updated_at on server).
  Future<void> upsertFromRemote(List<Product> products) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final companions = products.map((p) {
      final firstImageUrl = p.productImages?.isNotEmpty == true ? p.productImages!.first.url : null;
      return LocalProductsCompanion.insert(
        id: p.id,
        companyId: p.companyId,
        name: p.name,
        sku: Value(p.sku),
        barcode: Value(p.barcode),
        unit: Value(p.unit),
        purchasePrice: Value(p.purchasePrice),
        salePrice: Value(p.salePrice),
        minPrice: Value(p.minPrice),
        stockMin: Value(p.stockMin),
        description: Value(p.description),
        isActive: Value(p.isActive),
        categoryId: Value(p.categoryId),
        brandId: Value(p.brandId),
        imageUrl: Value(firstImageUrl),
        productScope: Value(p.productScope),
        updatedAt: now,
      );
    });
    await _db.upsertLocalProducts(companions);
  }

  /// Pull from Supabase and write to Drift (called by sync service when online).
  /// Suppressions côté serveur : on retire de Drift les produits absents de la liste renvoyée.
  Future<void> pullAndMerge(String companyId) async {
    final list = await _supabaseRepo.list(companyId);
    await upsertFromRemote(list);
    final keepIds = list.map((p) => p.id).toSet();
    await _db.deleteLocalProductsNotIn(companyId, keepIds);
  }
}

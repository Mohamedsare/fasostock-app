import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/errors/app_error_handler.dart';
import '../../local/drift/app_database.dart';
import '../../models/product.dart';
import '../../models/product_image.dart' show ProductImage, primaryProductImageUrl;
import '../products_repository.dart';

/// Offline-first products: UI reads from Drift; sync service writes from Supabase.
/// Pattern: UI → Provider → this repo → Drift (read) / Drift + PendingActions (write).
class ProductsOfflineRepository {
  ProductsOfflineRepository(
    this._db,
    this._supabaseRepo, {
    @visibleForTesting Future<List<ProductImage>> Function(String productId)?
        testGetImages,
  }) : _testGetImages = testGetImages;

  final AppDatabase _db;
  final ProductsRepository _supabaseRepo;

  /// Tests unitaires : court-circuite [ProductsRepository.getImages] (pas de Supabase).
  final Future<List<ProductImage>> Function(String productId)? _testGetImages;

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
      final firstImageUrl = primaryProductImageUrl(p.productImages ?? const []);
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

  /// Une ligne `postgres_changes` sur `public.products` (Realtime) — pas de `product_images`.
  /// [deleted_at] renseigné → suppression locale ; sinon upsert en conservant `image_url` locale si inchangée.
  Future<void> applyRealtimeRow(Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final deleted = row['deleted_at'];
      if (deleted != null && deleted.toString().trim().isNotEmpty) {
        await _db.deleteLocalProduct(id);
        return;
      }

      final companyId = row['company_id']?.toString();
      if (companyId == null || companyId.isEmpty) return;

      late final Product p;
      try {
        p = Product.fromJson(Map<String, dynamic>.from(row));
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'products_offline_apply_realtime',
          logContext: {'phase': 'parse', 'product_id': id},
        );
        return;
      }

      final existing = await _db.getLocalProductsByIds({id});
      final preservedImage =
          existing.isNotEmpty ? existing.first.imageUrl?.trim() : null;
      final firstImageUrl = (p.productImages?.isNotEmpty == true)
          ? primaryProductImageUrl(p.productImages!)
          : (preservedImage?.isNotEmpty == true ? preservedImage : null);

      final updatedAt = row['updated_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String();

      await _db.upsertLocalProducts([
        LocalProductsCompanion.insert(
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
          updatedAt: updatedAt,
        ),
      ]);
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'products_offline_apply_realtime',
        logContext: {'phase': 'drift', 'product_id': id},
      );
    }
  }

  /// Événement `delete` physique sur `products` (peu fréquent si soft-delete).
  Future<void> removeLocalByProductId(String productId) async {
    await _db.deleteLocalProduct(productId);
  }

  /// Met à jour la vignette locale à partir d’une liste déjà connue (tests / pipeline image).
  Future<void> applyPrimaryImageUrl(String productId, List<ProductImage> images) async {
    final local = await _db.getLocalProductsByIds({productId});
    if (local.isEmpty) return;
    await _db.updateLocalProductImageUrl(productId, primaryProductImageUrl(images));
  }

  /// Après événement Realtime sur `product_images` : re-fetch léger puis MAJ `image_url` locale.
  /// Erreurs réseau / SQLite : journalisées ici (pas de propagation — arrière-plan Realtime).
  Future<void> refreshPrimaryImageFromRemote(String productId) async {
    try {
      final local = await _db.getLocalProductsByIds({productId});
      if (local.isEmpty) return;
      final images = await _getProductImages(productId);
      await _db.updateLocalProductImageUrl(
        productId,
        primaryProductImageUrl(images),
      );
    } catch (e, st) {
      AppErrorHandler.logWithContext(
        e,
        stackTrace: st,
        logSource: 'products_offline_refresh_image',
        logContext: {'product_id': productId},
      );
    }
  }

  Future<List<ProductImage>> _getProductImages(String productId) {
    final override = _testGetImages;
    if (override != null) return override(productId);
    return _supabaseRepo.getImages(productId);
  }
}

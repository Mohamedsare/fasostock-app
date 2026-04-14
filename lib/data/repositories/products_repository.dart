import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/brand.dart';
import '../models/product_image.dart';
import 'inventory_repository.dart';

/// Produits, catégories, marques — même API que productsApi (web).
class ProductsRepository {
  ProductsRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _productSelect =
      'id, company_id, name, sku, barcode, unit, purchase_price, sale_price, wholesale_price, wholesale_qty, min_price, stock_min, description, is_active, category_id, brand_id, category:categories(id, name), brand:brands(id, name)';

  Future<List<Product>> list(
    String companyId, {
    bool includeDeleted = false,
  }) async {
    var q = _client
        .from('products')
        .select(_productSelect)
        .eq('company_id', companyId);
    if (!includeDeleted) q = q.filter('deleted_at', 'is', null);
    final data = await q.order('name');
    final list = (data as List)
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    for (final p in list) {
      final images = await getImages(p.id);
      list[list.indexOf(p)] = Product(
        id: p.id,
        companyId: p.companyId,
        name: p.name,
        sku: p.sku,
        barcode: p.barcode,
        unit: p.unit,
        purchasePrice: p.purchasePrice,
        salePrice: p.salePrice,
        wholesalePrice: p.wholesalePrice,
        wholesaleQty: p.wholesaleQty,
        minPrice: p.minPrice,
        stockMin: p.stockMin,
        description: p.description,
        isActive: p.isActive,
        categoryId: p.categoryId,
        brandId: p.brandId,
        category: p.category,
        brand: p.brand,
        productImages: images,
        productScope: p.productScope,
      );
    }
    return list;
  }

  Future<Product?> get(String id) async {
    final data = await _client
        .from('products')
        .select(_productSelect)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    final p = Product.fromJson(Map<String, dynamic>.from(data as Map));
    final images = await getImages(p.id);
    return Product(
      id: p.id,
      companyId: p.companyId,
      name: p.name,
      sku: p.sku,
      barcode: p.barcode,
      unit: p.unit,
      purchasePrice: p.purchasePrice,
      salePrice: p.salePrice,
      wholesalePrice: p.wholesalePrice,
      wholesaleQty: p.wholesaleQty,
      minPrice: p.minPrice,
      stockMin: p.stockMin,
      description: p.description,
      isActive: p.isActive,
      categoryId: p.categoryId,
      brandId: p.brandId,
      category: p.category,
      brand: p.brand,
      productImages: images,
      productScope: p.productScope,
    );
  }

  Future<List<ProductImage>> getImages(String productId) async {
    final data = await _client
        .from('product_images')
        .select('id, product_id, url, position')
        .eq('product_id', productId)
        .order('position');
    return (data as List)
        .map((e) => ProductImage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Product> create(CreateProductInput input) async {
    final data = await _client
        .from('products')
        .insert({
          'company_id': input.companyId,
          'name': input.name,
          'sku': input.sku,
          'barcode': input.barcode,
          'unit': input.unit,
          'purchase_price': input.purchasePrice,
          'sale_price': input.salePrice,
          'wholesale_price': input.wholesalePrice,
          'wholesale_qty': input.wholesaleQty,
          'min_price': null,
          'stock_min': input.stockMin,
          'description': input.description,
          'is_active': input.isActive,
          'category_id': input.categoryId,
          'brand_id': input.brandId,
          'product_scope': input.productScope,
        })
        .select()
        .single();
    return Product.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Product> update(String id, Map<String, dynamic> patch) async {
    final data = await _client
        .from('products')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Product.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> softDelete(String id) async {
    await _client
        .from('products')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'is_active': false,
        })
        .eq('id', id);
  }

  Future<void> setActive(String id, bool isActive) async {
    await _client.from('products').update({'is_active': isActive}).eq('id', id);
  }

  Future<ProductImage> addImage(
    String productId,
    List<int> bytes,
    String fileName,
    String contentType,
  ) async {
    const bucket = 'product-images';
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final path = '$productId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType),
        );
    final url = _client.storage.from(bucket).getPublicUrl(path);
    final maxPos = await _client
        .from('product_images')
        .select('position')
        .eq('product_id', productId)
        .order('position', ascending: false)
        .limit(1)
        .maybeSingle();
    final pos = (maxPos != null && (maxPos as Map)['position'] != null)
        ? ((maxPos as Map)['position'] as num).toInt() + 1
        : 0;
    final data = await _client
        .from('product_images')
        .insert({'product_id': productId, 'url': url, 'position': pos})
        .select()
        .single();
    return ProductImage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteImage(String imageId) async {
    await _client.from('product_images').delete().eq('id', imageId);
  }

  Future<List<Category>> categories(String companyId) async {
    final data = await _client
        .from('categories')
        .select('id, company_id, name, parent_id')
        .eq('company_id', companyId)
        .order('name');
    return (data as List)
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Category> createCategory(
    String companyId,
    String name, [
    String? parentId,
  ]) async {
    final data = await _client
        .from('categories')
        .insert({'company_id': companyId, 'name': name, 'parent_id': parentId})
        .select()
        .single();
    return Category.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Category> updateCategory(String id, String name) async {
    final data = await _client
        .from('categories')
        .update({'name': name})
        .eq('id', id)
        .select()
        .single();
    return Category.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }

  Future<List<Brand>> brands(String companyId) async {
    final data = await _client
        .from('brands')
        .select('id, company_id, name')
        .eq('company_id', companyId)
        .order('name');
    return (data as List)
        .map((e) => Brand.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Brand> createBrand(String companyId, String name) async {
    final data = await _client
        .from('brands')
        .insert({'company_id': companyId, 'name': name})
        .select()
        .single();
    return Brand.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Brand> updateBrand(String id, String name) async {
    final data = await _client
        .from('brands')
        .update({'name': name})
        .eq('id', id)
        .select()
        .single();
    return Brand.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> deleteBrand(String id) async {
    await _client.from('brands').delete().eq('id', id);
  }

  /// Import produits depuis lignes CSV — batch insert pour rapidité, [onProgress] pour l'UI.
  /// Chaque map: name (required), sku?, barcode?, unit?, purchase_price?, sale_price?, stock_min?, stock_entrant?, description?, is_active?, category?, brand?.
  Future<({int created, List<String> errors})> importFromCsv(
    String companyId,
    List<Map<String, dynamic>> rows, {
    String? storeId,
    String? userId,
    void Function(int current, int total)? onProgress,
  }) async {
    const batchSize = 50;
    final invRepo = InventoryRepository(_client);
    final total = rows.length;
    onProgress?.call(0, total);

    final existingCats = await categories(companyId);
    final existingBrands = await brands(companyId);
    final catMap = {for (final c in existingCats) c.name.toLowerCase(): c.id};
    final brandMap = {
      for (final b in existingBrands) b.name.toLowerCase(): b.id,
    };

    final valid = <_RowPayload>[];
    final errors = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final name = (r['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final catName = (r['category'] as String? ?? '').trim();
      final brandName = (r['brand'] as String? ?? '').trim();
      if (catName.isNotEmpty && !catMap.containsKey(catName.toLowerCase())) {
        try {
          final c = await createCategory(companyId, catName);
          catMap[catName.toLowerCase()] = c.id;
        } catch (e) {
          errors.add('Ligne ${i + 2} (catégorie): $e');
          continue;
        }
      }
      if (brandName.isNotEmpty &&
          !brandMap.containsKey(brandName.toLowerCase())) {
        try {
          final b = await createBrand(companyId, brandName);
          brandMap[brandName.toLowerCase()] = b.id;
        } catch (e) {
          errors.add('Ligne ${i + 2} (marque): $e');
          continue;
        }
      }
      final isActiveVal =
          r['is_active'] == true ||
          r['is_active'] == 1 ||
          (r['is_active'] is String &&
              [
                '1',
                'true',
                'oui',
                'yes',
              ].contains((r['is_active'] as String).toLowerCase()));
      valid.add(
        _RowPayload(
          name: name,
          sku: (r['sku'] as String? ?? '').trim(),
          barcode: (r['barcode'] as String? ?? '').trim(),
          unit: (r['unit'] as String? ?? 'pce').trim(),
          purchasePrice: (r['purchase_price'] is num)
              ? (r['purchase_price'] as num).toDouble()
              : 0,
          salePrice: (r['sale_price'] is num)
              ? (r['sale_price'] as num).toDouble()
              : 0,
          stockMin: (r['stock_min'] is num)
              ? (r['stock_min'] as num).toInt()
              : 0,
          stockEntrant: (r['stock_entrant'] is num)
              ? (r['stock_entrant'] as num).toInt()
              : 0,
          description: (r['description'] as String? ?? '').trim(),
          isActive: isActiveVal,
          categoryId: catName.isEmpty ? null : catMap[catName.toLowerCase()],
          brandId: brandName.isEmpty ? null : brandMap[brandName.toLowerCase()],
        ),
      );
    }

    var created = 0;
    for (var start = 0; start < valid.length; start += batchSize) {
      final chunk = valid.skip(start).take(batchSize).toList();
      final payloads = chunk
          .map(
            (p) => {
              'company_id': companyId,
              'name': p.name,
              'sku': p.sku.isEmpty ? null : p.sku,
              'barcode': p.barcode.isEmpty ? null : p.barcode,
              'unit': p.unit.isEmpty ? 'pce' : p.unit,
              'purchase_price': p.purchasePrice,
              'sale_price': p.salePrice,
              'min_price': null,
              'stock_min': p.stockMin,
              'description': p.description.isEmpty ? null : p.description,
              'is_active': p.isActive,
              'category_id': p.categoryId,
              'brand_id': p.brandId,
            },
          )
          .toList();
      try {
        final data = await _client
            .from('products')
            .insert(payloads)
            .select('id');
        final ids = (data as List)
            .map((r) => (r as Map)['id'] as String)
            .toList();
        if (storeId != null && userId != null && ids.length == chunk.length) {
          for (var j = 0; j < chunk.length; j++) {
            if (chunk[j].stockEntrant > 0) {
              await invRepo.adjust(
                storeId,
                ids[j],
                chunk[j].stockEntrant,
                'Stock entrant (import)',
                userId,
              );
            }
          }
        }
        created += chunk.length;
        onProgress?.call(created, total);
      } catch (e) {
        if (chunk.length == 1) {
          errors.add('Ligne ${start + 2}: $e');
        } else {
          errors.add('Lignes ${start + 2} à ${start + chunk.length + 1}: $e');
        }
      }
    }
    return (created: created, errors: errors);
  }
}

class _RowPayload {
  _RowPayload({
    required this.name,
    required this.sku,
    required this.barcode,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockMin,
    required this.stockEntrant,
    required this.description,
    required this.isActive,
    this.categoryId,
    this.brandId,
  });
  final String name;
  final String sku;
  final String barcode;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final int stockMin;
  final int stockEntrant;
  final String description;
  final bool isActive;
  final String? categoryId;
  final String? brandId;
}

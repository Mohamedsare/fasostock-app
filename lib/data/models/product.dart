import 'product_image.dart';

/// Portée stock / canaux : [productScope] = `both` | `warehouse_only` | `boutique_only` (colonne `product_scope`).
enum ProductScope {
  both,
  warehouseOnly,
  boutiqueOnly;

  static ProductScope fromWire(String? v) {
    switch (v) {
      case 'warehouse_only':
        return ProductScope.warehouseOnly;
      case 'boutique_only':
        return ProductScope.boutiqueOnly;
      case 'both':
      default:
        return ProductScope.both;
    }
  }

  String get wireValue {
    switch (this) {
      case ProductScope.both:
        return 'both';
      case ProductScope.warehouseOnly:
        return 'warehouse_only';
      case ProductScope.boutiqueOnly:
        return 'boutique_only';
    }
  }
}

/// Produit — aligné avec Product (productsApi) et table products.
class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.name,
    this.sku,
    this.barcode,
    this.unit = 'pce',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.minPrice,
    this.stockMin = 0,
    this.description,
    this.isActive = true,
    this.categoryId,
    this.brandId,
    this.category,
    this.brand,
    this.productImages,
    this.productScope = 'both',
  });

  final String id;
  final String companyId;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final double? minPrice;
  final int stockMin;
  final String? description;
  final bool isActive;
  final String? categoryId;
  final String? brandId;
  final CategoryRef? category;
  final BrandRef? brand;
  final List<ProductImage>? productImages;

  /// `both` | `warehouse_only` | `boutique_only`
  final String productScope;

  ProductScope get scope => ProductScope.fromWire(productScope);

  /// Entrées / sorties / stock **dépôt magasin**.
  bool get isAvailableInWarehouse =>
      scope == ProductScope.both || scope == ProductScope.warehouseOnly;

  /// Vente caisse / stock **boutique**.
  bool get isAvailableInBoutiqueStock =>
      scope == ProductScope.both || scope == ProductScope.boutiqueOnly;

  /// Transfert dépôt → boutique : articles « les deux » uniquement.
  bool get canTransferFromDepotToStore => scope == ProductScope.both;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      unit: json['unit'] as String? ?? 'pce',
      purchasePrice: _toDouble(json['purchase_price']),
      salePrice: _toDouble(json['sale_price']),
      minPrice: json['min_price'] != null ? _toDouble(json['min_price']) : null,
      stockMin: _toInt(json['stock_min']),
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      categoryId: json['category_id'] as String?,
      brandId: json['brand_id'] as String?,
      category: json['category'] != null ? CategoryRef.fromJson(Map<String, dynamic>.from(json['category'] as Map)) : null,
      brand: json['brand'] != null ? BrandRef.fromJson(Map<String, dynamic>.from(json['brand'] as Map)) : null,
      productImages: null,
      productScope: json['product_scope'] as String? ?? 'both',
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}

/// Référence catégorie (select imbriqué).
class CategoryRef {
  const CategoryRef({required this.id, required this.name});
  final String id;
  final String name;
  static CategoryRef fromJson(Map<String, dynamic> json) =>
      CategoryRef(id: json['id'] as String, name: json['name'] as String);
}

/// Référence marque (select imbriqué).
class BrandRef {
  const BrandRef({required this.id, required this.name});
  final String id;
  final String name;
  static BrandRef fromJson(Map<String, dynamic> json) =>
      BrandRef(id: json['id'] as String, name: json['name'] as String);
}

/// Input création/édition produit.
class CreateProductInput {
  const CreateProductInput({
    required this.companyId,
    required this.name,
    this.sku,
    this.barcode,
    this.unit = 'pce',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.minPrice,
    this.stockMin = 0,
    this.description,
    this.isActive = true,
    this.categoryId,
    this.brandId,
    this.productScope = 'both',
  });

  final String companyId;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final double? minPrice;
  final int stockMin;
  final String? description;
  final bool isActive;
  final String? categoryId;
  final String? brandId;
  final String productScope;
}

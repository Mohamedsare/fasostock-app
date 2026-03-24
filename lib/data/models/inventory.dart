/// Élément de stock par boutique — aligné avec InventoryItem (inventoryApi).
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.storeId,
    required this.productId,
    this.quantity = 0,
    this.reservedQuantity = 0,
    this.updatedAt = '',
    this.product,
  });

  final String id;
  final String storeId;
  final String productId;
  final int quantity;
  final int reservedQuantity;
  final String updatedAt;
  final InventoryProductRef? product;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String? ?? '',
      storeId: json['store_id'] as String,
      productId: json['product_id'] as String,
      quantity: (json['quantity'] is int) ? json['quantity'] as int : (json['quantity'] as num?)?.toInt() ?? 0,
      reservedQuantity: (json['reserved_quantity'] is int) ? json['reserved_quantity'] as int : 0,
      updatedAt: json['updated_at'] as String? ?? '',
      product: json['product'] != null ? InventoryProductRef.fromJson(Map<String, dynamic>.from(json['product'] as Map)) : null,
    );
  }
}

class InventoryProductRef {
  const InventoryProductRef({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.unit = 'pce',
    this.salePrice = 0,
    this.stockMin = 0,
    this.productImages,
  });
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final double salePrice;
  final int stockMin;
  final List<ImageUrlRef>? productImages;

  static InventoryProductRef fromJson(Map<String, dynamic> json) {
    return InventoryProductRef(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      unit: json['unit'] as String? ?? 'pce',
      salePrice: (json['sale_price'] is num) ? (json['sale_price'] as num).toDouble() : 0,
      stockMin: (json['stock_min'] is int) ? json['stock_min'] as int : (json['stock_min'] as num?)?.toInt() ?? 0,
      productImages: null,
    );
  }
}

class ImageUrlRef {
  const ImageUrlRef({required this.url});
  final String url;
}

/// Mouvement de stock — aligné avec StockMovement.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.storeId,
    required this.productId,
    required this.type,
    required this.quantity,
    this.referenceType,
    this.referenceId,
    this.createdBy,
    required this.createdAt,
    this.notes,
    this.product,
  });

  final String id;
  final String storeId;
  final String productId;
  final String type;
  final int quantity;
  final String? referenceType;
  final String? referenceId;
  final String? createdBy;
  final String createdAt;
  final String? notes;
  final MovementProductRef? product;

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      productId: json['product_id'] as String,
      type: json['type'] as String? ?? '',
      quantity: (json['quantity'] is int) ? json['quantity'] as int : (json['quantity'] as num).toInt(),
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] as String,
      notes: json['notes'] as String?,
      product: json['product'] != null ? MovementProductRef.fromJson(Map<String, dynamic>.from(json['product'] as Map)) : null,
    );
  }
}

/// Référence produit pour mouvement de stock.
class MovementProductRef {
  const MovementProductRef({required this.id, required this.name, this.sku, this.unit = 'pce'});
  final String id;
  final String name;
  final String? sku;
  final String unit;
  static MovementProductRef fromJson(Map<String, dynamic> json) => MovementProductRef(
        id: json['id'] as String,
        name: json['name'] as String,
        sku: json['sku'] as String?,
        unit: json['unit'] as String? ?? 'pce',
      );
}

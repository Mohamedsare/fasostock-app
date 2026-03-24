/// Ligne de stock magasin (dépôt central) avec détail produit embarqué.
class WarehouseStockLine {
  const WarehouseStockLine({
    required this.productId,
    required this.quantity,
    required this.productName,
    this.sku,
    this.unit = 'pce',
    this.avgUnitCost,
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.stockMin = 0,
    this.stockMinWarehouse = 0,
    this.updatedAt,
  });

  final String productId;
  final int quantity;
  final String productName;
  final String? sku;
  final String unit;
  final double? avgUnitCost;
  final double purchasePrice;
  final double salePrice;
  /// Seuil produit (boutique / catalogue).
  final int stockMin;
  /// Seuil dédié magasin (0 = recours à [stockMin] pour l’alerte).
  final int stockMinWarehouse;
  final String? updatedAt;

  double get valueAtCost => quantity * (avgUnitCost ?? purchasePrice);
  double get valueAtSale => quantity * salePrice;

  int get effectiveAlertThreshold => stockMinWarehouse > 0 ? stockMinWarehouse : stockMin;

  bool get isLowStock => quantity <= effectiveAlertThreshold;

  factory WarehouseStockLine.fromJson(Map<String, dynamic> json) {
    final product = json['product'] != null
        ? Map<String, dynamic>.from(json['product'] as Map)
        : <String, dynamic>{};
    return WarehouseStockLine(
      productId: json['product_id'] as String? ?? product['id'] as String? ?? '',
      quantity: _toInt(json['quantity']),
      productName: product['name'] as String? ?? '—',
      sku: product['sku'] as String?,
      unit: product['unit'] as String? ?? 'pce',
      avgUnitCost: json['avg_unit_cost'] != null ? _toDouble(json['avg_unit_cost']) : null,
      purchasePrice: _toDouble(product['purchase_price']),
      salePrice: _toDouble(product['sale_price']),
      stockMin: _toInt(product['stock_min']),
      stockMinWarehouse: _toInt(json['stock_min_warehouse']),
      updatedAt: json['updated_at'] as String?,
    );
  }

  static int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    return 0;
  }
}

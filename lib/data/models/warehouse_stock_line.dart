/// Ligne de stock magasin (dépôt central) avec détail produit embarqué.
class WarehouseStockLine {
  const WarehouseStockLine({
    required this.productId,
    required this.quantity,
    required this.productName,
    this.imageUrl,
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
  /// Première image produit (tri `position`) — affichage liste stock dépôt.
  final String? imageUrl;
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
      imageUrl: _firstImageUrlFromProductMap(product),
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

  static String? _firstImageUrlFromProductMap(Map<String, dynamic> product) {
    final raw = product['product_images'];
    if (raw is! List || raw.isEmpty) return null;
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        rows.add(e);
      } else if (e is Map) {
        rows.add(Map<String, dynamic>.from(e));
      }
    }
    if (rows.isEmpty) return null;
    rows.sort(
      (a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0),
    );
    final u = rows.first['url'];
    return u is String && u.isNotEmpty ? u : null;
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

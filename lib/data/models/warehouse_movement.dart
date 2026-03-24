/// Mouvement magasin (entrée / sortie).
class WarehouseMovement {
  const WarehouseMovement({
    required this.id,
    required this.productId,
    required this.movementKind,
    required this.quantity,
    this.unitCost,
    this.packagingType = 'unite',
    this.packsQuantity = 1,
    this.referenceType = 'manual',
    this.referenceId,
    this.notes,
    this.createdAt,
    this.productName,
    this.productSku,
  });

  final String id;
  final String productId;
  /// `entry` ou `exit`
  final String movementKind;
  final int quantity;
  final double? unitCost;
  final String packagingType;
  final double packsQuantity;
  final String referenceType;
  final String? referenceId;
  final String? notes;
  final String? createdAt;
  final String? productName;
  final String? productSku;

  bool get isEntry => movementKind == 'entry';
  bool get isExit => movementKind == 'exit';

  factory WarehouseMovement.fromJson(Map<String, dynamic> json) {
    final product = json['product'] != null
        ? Map<String, dynamic>.from(json['product'] as Map)
        : <String, dynamic>{};
    return WarehouseMovement(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      movementKind: json['movement_kind'] as String? ?? 'entry',
      quantity: _toInt(json['quantity']),
      unitCost: json['unit_cost'] != null ? _toDouble(json['unit_cost']) : null,
      packagingType: json['packaging_type'] as String? ?? 'unite',
      packsQuantity: _toDouble(json['packs_quantity'], fallback: 1),
      referenceType: json['reference_type'] as String? ?? 'manual',
      referenceId: json['reference_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      productName: product['name'] as String?,
      productSku: product['sku'] as String?,
    );
  }

  static int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static double _toDouble(Object? v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    return fallback;
  }
}

/// Ligne pour un bon / facture de sortie **dépôt** (magasin).
class WarehouseDispatchLineInput {
  const WarehouseDispatchLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final int quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}

/// Résultat RPC [WarehouseRepository.createDispatchInvoice].
class WarehouseDispatchInvoiceResult {
  const WarehouseDispatchInvoiceResult({
    required this.id,
    required this.documentNumber,
  });

  final String id;
  final String documentNumber;
}

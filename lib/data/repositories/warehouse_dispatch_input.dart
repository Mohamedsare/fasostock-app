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

/// Résumé d'un bon / facture de sortie dépôt.
class WarehouseDispatchInvoiceSummary {
  const WarehouseDispatchInvoiceSummary({
    required this.id,
    required this.companyId,
    required this.documentNumber,
    required this.createdAt,
    this.customerId,
    this.customerName,
    this.notes,
  });

  final String id;
  final String companyId;
  final String documentNumber;
  final String createdAt;
  final String? customerId;
  final String? customerName;
  final String? notes;
}

/// Ligne d'un bon / facture de sortie dépôt.
class WarehouseDispatchInvoiceLine {
  const WarehouseDispatchInvoiceLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.productSku,
    this.productUnit = 'pce',
  });

  final String productId;
  final String productName;
  final String? productSku;
  final String productUnit;
  final int quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;
}

/// Détail complet d'un bon / facture de sortie dépôt.
class WarehouseDispatchInvoiceDetails {
  const WarehouseDispatchInvoiceDetails({
    required this.id,
    required this.companyId,
    required this.documentNumber,
    required this.createdAt,
    required this.lines,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.notes,
  });

  final String id;
  final String companyId;
  final String documentNumber;
  final String createdAt;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? notes;
  final List<WarehouseDispatchInvoiceLine> lines;

  double get subtotal => lines.fold<double>(0, (s, l) => s + l.total);
}

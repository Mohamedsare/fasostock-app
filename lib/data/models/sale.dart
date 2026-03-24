/// Mode de vente (dual-POS).
enum SaleMode {
  quickPos('quick_pos'),
  invoicePos('invoice_pos');

  const SaleMode(this.value);
  final String value;
  static SaleMode fromString(String v) =>
      SaleMode.values.firstWhere((e) => e.value == v, orElse: () => SaleMode.quickPos);
}

/// Type de document généré.
enum DocumentType {
  thermalReceipt('thermal_receipt'),
  a4Invoice('a4_invoice');

  const DocumentType(this.value);
  final String value;
  static DocumentType fromString(String v) =>
      DocumentType.values.firstWhere((e) => e.value == v, orElse: () => DocumentType.thermalReceipt);
}

/// Méthode de paiement — aligné avec le web.
enum PaymentMethod {
  cash,
  mobile_money,
  card,
  transfer,
  other,
}

extension PaymentMethodExt on PaymentMethod {
  static PaymentMethod fromString(String v) {
    switch (v) {
      case 'cash':
        return PaymentMethod.cash;
      case 'mobile_money':
        return PaymentMethod.mobile_money;
      case 'card':
        return PaymentMethod.card;
      case 'transfer':
        return PaymentMethod.transfer;
      default:
        return PaymentMethod.other;
    }
  }

  String get value => name;
}

/// Statut vente.
enum SaleStatus {
  draft,
  completed,
  cancelled,
  refunded,
}

extension SaleStatusExt on SaleStatus {
  static SaleStatus fromString(String v) {
    switch (v) {
      case 'draft':
        return SaleStatus.draft;
      case 'completed':
        return SaleStatus.completed;
      case 'cancelled':
        return SaleStatus.cancelled;
      case 'refunded':
        return SaleStatus.refunded;
      default:
        return SaleStatus.draft;
    }
  }

  String get value => name;
}

/// Vente — aligné avec Sale (salesApi).
class Sale {
  const Sale({
    required this.id,
    required this.companyId,
    required this.storeId,
    this.customerId,
    required this.saleNumber,
    required this.status,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.store,
    this.customer,
    this.saleItems,
    this.salePayments,
    this.saleMode,
    this.documentType,
  });

  final String id;
  final String companyId;
  final String storeId;
  final String? customerId;
  final String saleNumber;
  final SaleStatus status;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final StoreRef? store;
  final CustomerRef? customer;
  final List<SaleItem>? saleItems;
  final List<SalePayment>? salePayments;
  final SaleMode? saleMode;
  final DocumentType? documentType;

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      storeId: json['store_id'] as String,
      customerId: json['customer_id'] as String?,
      saleNumber: json['sale_number'] as String,
      status: SaleStatusExt.fromString(json['status'] as String? ?? 'draft'),
      subtotal: _d(json['subtotal']),
      discount: _d(json['discount']),
      tax: _d(json['tax']),
      total: _d(json['total']),
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      store: json['store'] != null ? StoreRef.fromJson(Map<String, dynamic>.from(json['store'] as Map)) : null,
      customer: json['customer'] != null ? CustomerRef.fromJson(Map<String, dynamic>.from(json['customer'] as Map)) : null,
      saleItems: null,
      salePayments: null,
      saleMode: json['sale_mode'] != null ? SaleMode.fromString(json['sale_mode'] as String) : null,
      documentType: json['document_type'] != null ? DocumentType.fromString(json['document_type'] as String) : null,
    );
  }

  static double _d(dynamic v) => (v is num) ? v.toDouble() : 0;
}

class StoreRef {
  const StoreRef({required this.id, required this.name});
  final String id;
  final String name;
  static StoreRef fromJson(Map<String, dynamic> json) =>
      StoreRef(id: json['id'] as String, name: json['name'] as String);
}

class CustomerRef {
  const CustomerRef({required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;
  static CustomerRef fromJson(Map<String, dynamic> json) => CustomerRef(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
      );
}

class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.total,
    this.product,
  });

  final String id;
  final String saleId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double total;
  final ProductRef? product;

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      productId: json['product_id'] as String,
      quantity: (json['quantity'] is int) ? json['quantity'] as int : (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] is num) ? (json['unit_price'] as num).toDouble() : 0,
      discount: (json['discount'] is num) ? (json['discount'] as num).toDouble() : 0,
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : 0,
      product: json['product'] != null ? ProductRef.fromJson(Map<String, dynamic>.from(json['product'] as Map)) : null,
    );
  }
}

class ProductRef {
  const ProductRef({required this.id, required this.name, this.sku, this.unit = 'pce'});
  final String id;
  final String name;
  final String? sku;
  final String unit;
  static ProductRef fromJson(Map<String, dynamic> json) => ProductRef(
        id: json['id'] as String,
        name: json['name'] as String,
        sku: json['sku'] as String?,
        unit: json['unit'] as String? ?? 'pce',
      );
}

class SalePayment {
  const SalePayment({
    required this.id,
    required this.saleId,
    required this.method,
    required this.amount,
    this.reference,
  });

  final String id;
  final String saleId;
  final PaymentMethod method;
  final double amount;
  final String? reference;

  factory SalePayment.fromJson(Map<String, dynamic> json) {
    return SalePayment(
      id: json['id'] as String,
      saleId: json['sale_id'] as String,
      method: PaymentMethodExt.fromString(json['method'] as String? ?? 'other'),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0,
      reference: json['reference'] as String?,
    );
  }
}

/// Input création vente (RPC create_sale_with_stock).
class CreateSaleInput {
  const CreateSaleInput({
    required this.companyId,
    required this.storeId,
    this.customerId,
    required this.items,
    this.discount = 0,
    required this.payments,
    this.saleMode = SaleMode.quickPos,
    this.documentType = DocumentType.thermalReceipt,
  });

  final String companyId;
  final String storeId;
  final String? customerId;
  final List<CreateSaleItemInput> items;
  final double discount;
  final List<CreateSalePaymentInput> payments;
  final SaleMode saleMode;
  final DocumentType documentType;
}

class CreateSaleItemInput {
  const CreateSaleItemInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
  });
  final String productId;
  final int quantity;
  final double unitPrice;
  final double discount;
}

class CreateSalePaymentInput {
  const CreateSalePaymentInput({
    required this.method,
    required this.amount,
    this.reference,
  });
  final PaymentMethod method;
  final double amount;
  final String? reference;
}

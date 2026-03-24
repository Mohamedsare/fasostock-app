import 'sale.dart'; // PaymentMethod

/// Statut achat.
enum PurchaseStatus {
  draft,
  confirmed,
  partially_received,
  received,
  cancelled,
}

extension PurchaseStatusExt on PurchaseStatus {
  static PurchaseStatus fromString(String v) {
    switch (v) {
      case 'draft':
        return PurchaseStatus.draft;
      case 'confirmed':
        return PurchaseStatus.confirmed;
      case 'partially_received':
        return PurchaseStatus.partially_received;
      case 'received':
        return PurchaseStatus.received;
      case 'cancelled':
        return PurchaseStatus.cancelled;
      default:
        return PurchaseStatus.draft;
    }
  }

  String get value => name;
}

/// Achat — aligné avec Purchase (purchasesApi).
class Purchase {
  const Purchase({
    required this.id,
    required this.companyId,
    required this.storeId,
    required this.supplierId,
    this.reference,
    required this.status,
    required this.total,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.store,
    this.supplier,
    this.purchaseItems,
    this.purchasePayments,
  });

  final String id;
  final String companyId;
  final String storeId;
  final String supplierId;
  final String? reference;
  final PurchaseStatus status;
  final double total;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final StoreRef? store;
  final SupplierRef? supplier;
  final List<PurchaseItem>? purchaseItems;
  final List<PurchasePayment>? purchasePayments;

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      storeId: json['store_id'] as String,
      supplierId: json['supplier_id'] as String,
      reference: json['reference'] as String?,
      status: PurchaseStatusExt.fromString(json['status'] as String? ?? 'draft'),
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : 0,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      store: json['store'] != null ? StoreRef.fromJson(Map<String, dynamic>.from(json['store'] as Map)) : null,
      supplier: json['supplier'] != null ? SupplierRef.fromJson(Map<String, dynamic>.from(json['supplier'] as Map)) : null,
      purchaseItems: null,
      purchasePayments: null,
    );
  }
}

class StoreRef {
  const StoreRef({required this.id, required this.name});
  final String id;
  final String name;
  static StoreRef fromJson(Map<String, dynamic> json) => StoreRef(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class SupplierRef {
  const SupplierRef({required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;
  static SupplierRef fromJson(Map<String, dynamic> json) => SupplierRef(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
      );
}

class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.product,
  });

  final String id;
  final String purchaseId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double total;
  final ProductRef? product;

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String,
      productId: json['product_id'] as String,
      quantity: (json['quantity'] is int) ? json['quantity'] as int : (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] is num) ? (json['unit_price'] as num).toDouble() : 0,
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : 0,
      product: json['product'] != null ? ProductRef.fromJson(Map<String, dynamic>.from(json['product'] as Map)) : null,
    );
  }
}

class PurchasePayment {
  const PurchasePayment({
    required this.id,
    required this.purchaseId,
    required this.amount,
    required this.method,
    required this.paidAt,
  });

  final String id;
  final String purchaseId;
  final double amount;
  final PaymentMethod method;
  final String paidAt;

  factory PurchasePayment.fromJson(Map<String, dynamic> json) {
    return PurchasePayment(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String,
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0,
      method: PaymentMethodExt.fromString(json['method'] as String? ?? 'other'),
      paidAt: json['paid_at'] as String,
    );
  }
}

/// Input création achat.
class CreatePurchaseInput {
  const CreatePurchaseInput({
    required this.companyId,
    required this.storeId,
    required this.supplierId,
    this.reference,
    required this.items,
    this.payments,
  });

  final String companyId;
  final String storeId;
  final String supplierId;
  final String? reference;
  final List<CreatePurchaseItemInput> items;
  final List<CreatePurchasePaymentInput>? payments;
}

class CreatePurchaseItemInput {
  const CreatePurchaseItemInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });
  final String productId;
  final int quantity;
  final double unitPrice;
}

class CreatePurchasePaymentInput {
  const CreatePurchasePaymentInput({required this.method, required this.amount});
  final PaymentMethod method;
  final double amount;
}

/// Statut transfert — aligné avec transfer_status (BDD).
enum TransferStatus {
  draft,
  pending,
  approved,
  shipped,
  received,
  rejected,
  cancelled,
}

extension TransferStatusExt on TransferStatus {
  static TransferStatus fromString(String? v) {
    switch (v) {
      case 'draft':
        return TransferStatus.draft;
      case 'pending':
        return TransferStatus.pending;
      case 'approved':
        return TransferStatus.approved;
      case 'shipped':
        return TransferStatus.shipped;
      case 'received':
        return TransferStatus.received;
      case 'rejected':
        return TransferStatus.rejected;
      case 'cancelled':
        return TransferStatus.cancelled;
      default:
        return TransferStatus.draft;
    }
  }

  String get value => name;
}

/// Transfert de stock — aligné avec stock_transfers (web).
class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.companyId,
    required this.fromStoreId,
    required this.toStoreId,
    this.fromWarehouse = false,
    required this.status,
    required this.requestedBy,
    this.approvedBy,
    this.shippedAt,
    this.receivedAt,
    this.receivedBy,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  final String id;
  final String companyId;

  /// Vide si [fromWarehouse] (origine = dépôt magasin).
  final String fromStoreId;
  final String toStoreId;

  /// Transfert depuis le stock central (magasin) vers une boutique.
  final bool fromWarehouse;
  final TransferStatus status;
  final String requestedBy;
  final String? approvedBy;
  final String? shippedAt;
  final String? receivedAt;
  final String? receivedBy;
  final String createdAt;
  final String updatedAt;
  final List<StockTransferItem>? items;

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    final fromWh = json['from_warehouse'] as bool? ?? false;
    final fromSid = json['from_store_id'] as String?;
    return StockTransfer(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      fromStoreId: fromWh ? '' : (fromSid ?? ''),
      toStoreId: json['to_store_id'] as String,
      fromWarehouse: fromWh,
      status: TransferStatusExt.fromString(json['status'] as String?),
      requestedBy: json['requested_by'] as String,
      approvedBy: json['approved_by'] as String?,
      shippedAt: json['shipped_at'] as String?,
      receivedAt: json['received_at'] as String?,
      receivedBy: json['received_by'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      items: null,
    );
  }
}

/// Ligne d'un transfert.
class StockTransferItem {
  const StockTransferItem({
    required this.id,
    required this.transferId,
    required this.productId,
    required this.quantityRequested,
    this.quantityShipped = 0,
    this.quantityReceived = 0,
    this.productName,
  });

  final String id;
  final String transferId;
  final String productId;
  final int quantityRequested;
  final int quantityShipped;
  final int quantityReceived;
  final String? productName;

  factory StockTransferItem.fromJson(Map<String, dynamic> json) {
    final productMap = _productMapFromJson(json['product']);
    return StockTransferItem(
      id: json['id'] as String,
      transferId: json['transfer_id'] as String,
      productId: json['product_id'] as String,
      quantityRequested: json['quantity_requested'] as int,
      quantityShipped: json['quantity_shipped'] as int? ?? 0,
      quantityReceived: json['quantity_received'] as int? ?? 0,
      productName: productMap?['name'] as String?,
    );
  }

  /// PostgREST renvoie souvent un objet ; certaines formes legacy une liste d’un seul élément.
  static Map<String, dynamic>? _productMapFromJson(Object? raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }
}

/// Input création transfert.
class CreateTransferInput {
  const CreateTransferInput({
    required this.companyId,
    this.fromStoreId,
    required this.toStoreId,
    required this.items,
    this.fromWarehouse = false,
  });

  final String companyId;

  /// Ignoré si [fromWarehouse] est true (origine magasin).
  final String? fromStoreId;
  final String toStoreId;
  final List<CreateTransferItemInput> items;
  final bool fromWarehouse;
}

class CreateTransferItemInput {
  const CreateTransferItemInput({
    required this.productId,
    required this.quantityRequested,
  });

  final String productId;
  final int quantityRequested;
}

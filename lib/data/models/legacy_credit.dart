class LegacyCreditPayment {
  const LegacyCreditPayment({
    required this.id,
    required this.method,
    required this.amount,
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String method;
  final double amount;
  final String? reference;
  final String createdAt;
}

class LegacyCreditRow {
  const LegacyCreditRow({
    required this.id,
    required this.companyId,
    required this.storeId,
    required this.customerId,
    required this.title,
    required this.principalAmount,
    this.dueAt,
    this.internalNote,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.storeName,
    this.customerName,
    this.customerPhone,
    required this.payments,
  });

  final String id;
  final String companyId;
  final String storeId;
  final String customerId;
  final String title;
  final double principalAmount;
  final String? dueAt;
  final String? internalNote;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? storeName;
  final String? customerName;
  final String? customerPhone;
  final List<LegacyCreditPayment> payments;
}

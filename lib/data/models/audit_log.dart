/// Entrée du journal d'audit (activité par entreprise).
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.companyId,
    required this.action,
    required this.entityType,
    required this.createdAt,
    this.storeId,
    this.userId,
    this.entityId,
    this.oldData,
    this.newData,
    this.userEmail,
  });

  final String id;
  final String? companyId;
  final String? storeId;
  final String? userId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final DateTime createdAt;
  final String? userEmail;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    return AuditLogEntry(
      id: json['id'] as String,
      companyId: json['company_id'] as String?,
      storeId: json['store_id'] as String?,
      userId: json['user_id'] as String?,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      oldData: json['old_data'] != null ? Map<String, dynamic>.from(json['old_data'] as Map) : null,
      newData: json['new_data'] != null ? Map<String, dynamic>.from(json['new_data'] as Map) : null,
      createdAt: createdAt is String ? DateTime.parse(createdAt) : createdAt as DateTime,
      userEmail: null,
    );
  }
}

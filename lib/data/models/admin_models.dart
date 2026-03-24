/// Entreprise (vue admin) — aligné avec AdminCompany.
class AdminCompany {
  const AdminCompany({
    required this.id,
    required this.name,
    this.slug,
    this.isActive = true,
    this.storeQuota = 0,
    this.aiPredictionsEnabled = false,
    this.createdAt,
  });
  final String id;
  final String name;
  final String? slug;
  final bool isActive;
  final int storeQuota;
  final bool aiPredictionsEnabled;
  final String? createdAt;

  factory AdminCompany.fromJson(Map<String, dynamic> json) {
    return AdminCompany(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      storeQuota: (json['store_quota'] is int) ? json['store_quota'] as int : (json['store_quota'] as num?)?.toInt() ?? 0,
      aiPredictionsEnabled: json['ai_predictions_enabled'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Boutique (vue admin).
class AdminStore {
  const AdminStore({
    required this.id,
    required this.companyId,
    required this.name,
    this.code,
    this.isActive = true,
    this.isPrimary = false,
    this.createdAt,
  });
  final String id;
  final String companyId;
  final String name;
  final String? code;
  final bool isActive;
  final bool isPrimary;
  final String? createdAt;

  factory AdminStore.fromJson(Map<String, dynamic> json) {
    return AdminStore(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Utilisateur (vue admin) — admin_list_users RPC.
class AdminUser {
  const AdminUser({
    required this.id,
    this.email,
    this.fullName,
    this.isSuperAdmin = false,
    this.isActive = true,
    this.companyNames = const [],
  });
  final String id;
  final String? email;
  final String? fullName;
  final bool isSuperAdmin;
  final bool isActive;
  final List<String> companyNames;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      companyNames: (json['company_names'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AdminStats {
  const AdminStats({
    this.companiesCount = 0,
    this.storesCount = 0,
    this.usersCount = 0,
    this.salesCount = 0,
    this.salesTotalAmount = 0,
    this.activeSubscriptionsCount = 0,
  });
  final int companiesCount;
  final int storesCount;
  final int usersCount;
  final int salesCount;
  final double salesTotalAmount;
  final int activeSubscriptionsCount;
}

class AdminSalesByCompany {
  const AdminSalesByCompany({
    required this.companyId,
    required this.companyName,
    this.salesCount = 0,
    this.totalAmount = 0,
  });
  final String companyId;
  final String companyName;
  final int salesCount;
  final double totalAmount;
}

class AdminSalesOverTimeItem {
  const AdminSalesOverTimeItem({
    required this.date,
    this.count = 0,
    this.total = 0,
  });
  final String date;
  final int count;
  final double total;
}

/// Compte bloqué après 5 tentatives de connexion (super_admin peut débloquer).
class LockedLogin {
  const LockedLogin({
    required this.emailLower,
    required this.failedAttempts,
    required this.lockedAt,
  });
  final String emailLower;
  final int failedAttempts;
  final String? lockedAt;

  factory LockedLogin.fromJson(Map<String, dynamic> json) {
    return LockedLogin(
      emailLower: json['email_lower'] as String,
      failedAttempts: (json['failed_attempts'] is int) ? json['failed_attempts'] as int : (json['failed_attempts'] as num?)?.toInt() ?? 0,
      lockedAt: json['locked_at'] as String?,
    );
  }
}

/// Erreur applicative remontée par les apps clientes (vue super admin).
class AdminAppErrorLog {
  const AdminAppErrorLog({
    required this.id,
    required this.createdAt,
    this.userId,
    this.companyId,
    this.storeId,
    required this.source,
    required this.level,
    required this.message,
    this.stackTrace,
    this.errorType,
    this.platform,
    this.context,
  });

  final String id;
  final String createdAt;
  final String? userId;
  final String? companyId;
  final String? storeId;
  final String source;
  final String level;
  final String message;
  final String? stackTrace;
  final String? errorType;
  final String? platform;
  final Map<String, dynamic>? context;

  factory AdminAppErrorLog.fromJson(Map<String, dynamic> json) {
    return AdminAppErrorLog(
      id: json['id'] as String,
      createdAt: json['created_at'] as String,
      userId: json['user_id'] as String?,
      companyId: json['company_id'] as String?,
      storeId: json['store_id'] as String?,
      source: (json['source'] as String?) ?? 'app',
      level: (json['level'] as String?) ?? 'error',
      message: (json['message'] as String?) ?? '',
      stackTrace: json['stack_trace'] as String?,
      errorType: json['error_type'] as String?,
      platform: json['platform'] as String?,
      context: json['context'] is Map
          ? Map<String, dynamic>.from(json['context'] as Map)
          : null,
    );
  }
}

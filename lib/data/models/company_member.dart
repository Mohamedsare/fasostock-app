/// Rôle (option pour sélection).
class RoleOption {
  const RoleOption({
    required this.id,
    required this.name,
    required this.slug,
  });
  final String id;
  final String name;
  final String slug;

  factory RoleOption.fromJson(Map<String, dynamic> json) {
    return RoleOption(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}

/// Membre entreprise — user_company_roles + role + profile.
class CompanyMember {
  const CompanyMember({
    required this.id,
    required this.userId,
    required this.roleId,
    this.isActive = true,
    this.createdAt = '',
    required this.role,
    this.profile,
    this.email,
  });
  final String id;
  final String userId;
  final String roleId;
  final bool isActive;
  final String createdAt;
  final RoleRef role;
  final ProfileRef? profile;
  final String? email;

  factory CompanyMember.fromJson(Map<String, dynamic> json) {
    return CompanyMember(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      roleId: json['role_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
      role: json['roles'] != null
          ? RoleRef.fromJson(Map<String, dynamic>.from(json['roles'] as Map))
          : const RoleRef(name: '—', slug: ''),
      profile: json['profile'] != null ? ProfileRef.fromJson(Map<String, dynamic>.from(json['profile'] as Map)) : null,
      email: json['email'] as String?,
    );
  }
}

class RoleRef {
  const RoleRef({required this.name, required this.slug});
  final String name;
  final String slug;
  static RoleRef fromJson(Map<String, dynamic> json) =>
      RoleRef(name: json['name'] as String? ?? '—', slug: json['slug'] as String? ?? '');
}

class ProfileRef {
  const ProfileRef({this.fullName});
  final String? fullName;
  static ProfileRef fromJson(Map<String, dynamic> json) =>
      ProfileRef(fullName: json['full_name'] as String?);
}

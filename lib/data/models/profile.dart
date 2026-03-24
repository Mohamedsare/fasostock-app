/// Profil utilisateur — aligné avec profiles (Supabase) et AuthContext Profile.
class Profile {
  const Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.isSuperAdmin = false,
    this.isActive = true,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final bool isSuperAdmin;
  final bool isActive;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

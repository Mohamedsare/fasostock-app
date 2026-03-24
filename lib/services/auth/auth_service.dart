import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/profile.dart';
import '../../core/errors/error_messages.dart';

/// Service d'authentification — même logique que AuthContext + authService (signIn, profile, signOut).
class AuthService {
  AuthService(this._supabase);

  final SupabaseClient _supabase;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Récupère le profil depuis la table profiles (même select que le web).
  Future<Profile?> getProfile(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, is_super_admin, is_active')
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return null;
      return Profile.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (_) {
      return null;
    }
  }

  /// Connexion — même appel que signInWithPassword côté web.
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      return res;
    } on AuthException catch (e) {
      throw Exception(ErrorMessages.translate(e.message, code: e.statusCode));
    }
  }

  /// Déconnexion.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Envoi du lien de réinitialisation mot de passe — même redirectTo que le web.
  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
    } on AuthException catch (e) {
      throw Exception(ErrorMessages.translate(e.message, code: e.statusCode));
    }
  }

  /// Inscription : entreprise + owner + première boutique (aligné registerCompany web).
  Future<RegisterCompanyResult> registerCompany(RegisterCompanyInput input) async {
    final slug = _slugFromName(input.companyName);
    final res = await _supabase.auth.signUp(
      email: input.ownerEmail,
      password: input.ownerPassword,
      data: {'full_name': input.ownerFullName},
    );
    if (res.user == null) throw Exception('Inscription échouée.');
    final userId = res.user!.id;

    await _supabase.from('profiles').upsert({
      'id': userId,
      'full_name': input.ownerFullName,
      'is_super_admin': false,
      'is_active': true,
    });

    final rpc = await _supabase.rpc('create_company_with_owner', params: {
      'p_company_name': input.companyName,
      'p_company_slug': input.companySlug.isNotEmpty ? input.companySlug : slug,
      'p_store_name': input.firstStoreName,
      'p_store_code': null,
      'p_store_phone': input.firstStorePhone.isNotEmpty ? input.firstStorePhone : null,
    });
    if (rpc == null) throw Exception('Création entreprise échouée.');
    final map = rpc as Map<String, dynamic>;
    return RegisterCompanyResult(
      userId: userId,
      companyId: map['company_id'] as String,
      storeId: map['store_id'] as String,
    );
  }

  static String _slugFromName(String name) {
    if (name.trim().isEmpty) return 'entreprise';
    final n = name.toLowerCase().trim();
    final withoutAccents = n
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('ô', 'o')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c');
    final slug = withoutAccents
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'entreprise' : slug;
  }
}

class RegisterCompanyInput {
  const RegisterCompanyInput({
    required this.companyName,
    required this.companySlug,
    required this.ownerEmail,
    required this.ownerPassword,
    required this.ownerFullName,
    required this.firstStoreName,
    required this.firstStorePhone,
  });
  final String companyName;
  final String companySlug;
  final String ownerEmail;
  final String ownerPassword;
  final String ownerFullName;
  final String firstStoreName;
  final String firstStorePhone;
}

class RegisterCompanyResult {
  const RegisterCompanyResult({required this.userId, required this.companyId, required this.storeId});
  final String userId;
  final String companyId;
  final String storeId;
}

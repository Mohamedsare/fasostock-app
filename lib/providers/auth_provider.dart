import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/profile.dart';
import '../services/auth/auth_service.dart';
import 'company_provider.dart';
import 'permissions_provider.dart';

/// État auth global — équivalent AuthContext (user, session, profile, loading, isSuperAdmin, signOut, refreshProfile).
class AppAuthState {
  const AppAuthState({
    this.user,
    this.session,
    this.profile,
    this.loading = true,
  });

  final User? user;
  final Session? session;
  final Profile? profile;
  final bool loading;

  bool get isSuperAdmin => profile?.isSuperAdmin ?? false;
  bool get isAuthenticated => user != null;
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._auth) {
    _init();
    _sub = _auth.authStateChanges.listen(_onAuthStateChange);
  }

  final AuthService _auth;
  StreamSubscription<AuthState>? _sub;

  CompanyProvider? _company;
  PermissionsProvider? _permissions;

  /// À appeler au démarrage (ex. dans main) pour que signOut réinitialise company et permissions.
  void setSessionProviders(CompanyProvider? company, PermissionsProvider? permissions) {
    _company = company;
    _permissions = permissions;
  }

  AppAuthState _state = const AppAuthState();
  AppAuthState get state => _state;

  User? get user => _state.user;
  Session? get session => _state.session;
  Profile? get profile => _state.profile;
  bool get loading => _state.loading;
  bool get isSuperAdmin => _state.isSuperAdmin;
  bool get isAuthenticated => _state.isAuthenticated;

  Future<void> _init() async {
    final session = _auth.currentSession;
    final user = _auth.currentUser;
    _state = AppAuthState(
      user: user,
      session: session,
      profile: null,
      loading: false,
    );
    if (user != null) {
      Profile? p = await _auth.getProfile(user.id);
      for (var i = 0; i < 2 && p != null && p.isActive == false; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        p = await _auth.getProfile(user.id);
      }
      _applyProfile(p);
    }
    notifyListeners();
  }

  void _applyProfile(Profile? p) {
    _state = AppAuthState(
      user: _state.user,
      session: _state.session,
      profile: p,
      loading: _state.loading,
    );
    if (p != null && p.isActive == false) {
      _auth.signOut();
      _state = const AppAuthState(loading: false);
    }
    notifyListeners();
  }

  void _onAuthStateChange(AuthState authState) {
    final user = authState.session?.user;
    if (user != null) {
      // Après un signIn (bouton Connexion), on ne charge pas le profil ici : la page de login
      // appelle refreshProfile() après un délai. Évite la course qui provoquait "Compte désactivé".
      if (authState.event == AuthChangeEvent.signedIn) {
        _state = AppAuthState(
          user: user,
          session: authState.session,
          profile: _state.profile,
          loading: false,
        );
        notifyListeners();
        return;
      }
      // initialSession, tokenRefreshed, etc. : charger le profil avec délai et retentatives.
      Future<void>.delayed(const Duration(milliseconds: 400), () async {
        if (_auth.currentUser?.id != user.id) return;
        Profile? p = await _auth.getProfile(user.id);
        for (var i = 0; i < 2 && p != null && p.isActive == false; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (_auth.currentUser?.id != user.id) return;
          p = await _auth.getProfile(user.id);
        }
        if (_auth.currentUser?.id == user.id) _applyProfile(p);
      });
    } else {
      // Session expirée, déconnexion ailleurs ou token invalide : même nettoyage que signOut.
      _company?.loadCompanies(null);
      _permissions?.load(null);
      _state = const AppAuthState(loading: false);
      notifyListeners();
    }
  }

  Future<Profile?> refreshProfile() async {
    final u = _auth.currentUser ?? _auth.currentSession?.user;
    if (u == null) {
      _state = AppAuthState(user: _state.user, session: _state.session, profile: null, loading: false);
      notifyListeners();
      return null;
    }
    Profile? p = await _auth.getProfile(u.id);
    // Jusqu'à 3 retentatives si is_active == false (évite faux positif juste après login)
    for (var i = 0; i < 3 && p != null && p.isActive == false; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      p = await _auth.getProfile(u.id);
    }
    _applyProfile(p);
    return p;
  }

  /// Déconnexion. Réinitialise aussi company et permissions si fournis au démarrage
  /// (évite qu'un autre utilisateur soit pris pour le précédent sans relancer l'app).
  Future<void> signOut({
    CompanyProvider? company,
    PermissionsProvider? permissions,
  }) async {
    final c = company ?? _company;
    final p = permissions ?? _permissions;
    await c?.loadCompanies(null);
    await p?.load(null);
    await _auth.signOut();
    _state = const AppAuthState(loading: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

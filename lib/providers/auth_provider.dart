import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/app_error_handler.dart';
import '../core/services/profile_session_cache.dart';
import '../data/models/profile.dart';
import '../services/auth/auth_service.dart';
import 'company_provider.dart';
import 'permissions_provider.dart';

/// Reprises après [Profile] null (réseau, timeout) — évite splash infini puis déconnexion si échec durable.
const int _kProfileNullRetriesCold = 6;
const int _kProfileNullRetriesLogin = 12;
const Duration _kProfileNullRetryDelay = Duration(milliseconds: 500);

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
  void setSessionProviders(
    CompanyProvider? company,
    PermissionsProvider? permissions,
  ) {
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
      final optimistic = await ProfileSessionCache.loadOptimisticForUser(
        user.id,
      );
      if (optimistic != null && _auth.currentUser?.id == user.id) {
        _applyProfile(optimistic, fromSessionCache: true);
      }
      Profile? p = await _loadProfileUntilResolved(
        user.id,
        maxNullRetries: _kProfileNullRetriesCold,
        nullRetryDelay: _kProfileNullRetryDelay,
        signOutIfStillNull: true,
      );
      if (_auth.currentUser == null) {
        notifyListeners();
        return;
      }
      for (var i = 0; i < 2 && p != null && p.isActive == false; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        p = await _loadProfileUntilResolved(
          user.id,
          maxNullRetries: _kProfileNullRetriesCold,
          nullRetryDelay: _kProfileNullRetryDelay,
          signOutIfStillNull: true,
        );
        if (_auth.currentUser == null) {
          notifyListeners();
          return;
        }
      }
      _applyProfile(p, fromSessionCache: false);
    }
    notifyListeners();
  }

  /// JWT expiré → [AuthService.refreshSession] puis une requête ; sinon retentatives sur `null` (réseau).
  /// Si [signOutIfStillNull] et profil toujours absent → [signOut] (plus de splash bloqué).
  Future<Profile?> _loadProfileUntilResolved(
    String userId, {
    required int maxNullRetries,
    required Duration nullRetryDelay,
    required bool signOutIfStillNull,
  }) async {
    for (var attempt = 0; attempt <= maxNullRetries; attempt++) {
      final p = await _loadProfileWithJwtRecovery(userId);
      if (_auth.currentUser == null) return null;
      if (p != null) return p;
      if (attempt < maxNullRetries) {
        await Future<void>.delayed(nullRetryDelay);
      }
    }
    if (signOutIfStillNull && _auth.currentUser != null) {
      await signOut();
    }
    return null;
  }

  /// Une tentative : JWT → refresh + retry ; erreurs non-JWT → `null` (voir [_loadProfileUntilResolved]).
  Future<Profile?> _loadProfileWithJwtRecovery(String userId) async {
    try {
      return await _auth.getProfile(userId);
    } on PostgrestException catch (e) {
      if (!isJwtPostgrestError(e)) return null;
      try {
        await _auth.refreshSession();
      } catch (e, st) {
        AppErrorHandler.logWithContext(
          e,
          stackTrace: st,
          logSource: 'auth_provider',
          logContext: const {'phase': 'refresh_session_after_jwt_error'},
        );
        await signOut();
        return null;
      }
      try {
        return await _auth.getProfile(userId);
      } on PostgrestException catch (e2) {
        if (isJwtPostgrestError(e2)) {
          await signOut();
        }
        return null;
      }
    }
  }

  void _applyProfile(Profile? p, {bool fromSessionCache = false}) {
    _state = AppAuthState(
      user: _state.user,
      session: _state.session,
      profile: p,
      loading: _state.loading,
    );
    if (p != null && p.isActive == false) {
      unawaited(ProfileSessionCache.clear());
      _auth.signOut();
      _state = const AppAuthState(loading: false);
    } else if (p != null && p.isActive && !fromSessionCache) {
      unawaited(ProfileSessionCache.save(p));
    }
    notifyListeners();
  }

  void _onAuthStateChange(AuthState authState) {
    final user = authState.session?.user;
    if (user != null) {
      // Après un signIn (bouton Connexion), on ne charge pas le profil ici : la page de login
      // appelle refreshProfile() après un délai. Évite la course qui provoquait "Compte désactivé".
      if (authState.event == AuthChangeEvent.signedIn) {
        final prev = _state.profile;
        final sameUser = prev != null && prev.id == user.id;
        _state = AppAuthState(
          user: user,
          session: authState.session,
          profile: sameUser ? prev : null,
          loading: false,
        );
        notifyListeners();
        return;
      }
      // initialSession, tokenRefreshed, etc. : charger le profil avec délai et retentatives.
      Future<void>.delayed(const Duration(milliseconds: 400), () async {
        if (_auth.currentUser?.id != user.id) return;
        Profile? p = await _loadProfileUntilResolved(
          user.id,
          maxNullRetries: _kProfileNullRetriesCold,
          nullRetryDelay: _kProfileNullRetryDelay,
          signOutIfStillNull: true,
        );
        if (_auth.currentUser == null) return;
        for (var i = 0; i < 2 && p != null && p.isActive == false; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (_auth.currentUser?.id != user.id) return;
          p = await _loadProfileUntilResolved(
            user.id,
            maxNullRetries: _kProfileNullRetriesCold,
            nullRetryDelay: _kProfileNullRetryDelay,
            signOutIfStillNull: true,
          );
          if (_auth.currentUser == null) return;
        }
        if (_auth.currentUser?.id == user.id) {
          _applyProfile(p, fromSessionCache: false);
        }
      });
    } else {
      // Session expirée, déconnexion ailleurs ou token invalide : même nettoyage que signOut.
      unawaited(ProfileSessionCache.clear());
      _company?.loadCompanies(null);
      _permissions?.load(null);
      _state = const AppAuthState(loading: false);
      notifyListeners();
    }
  }

  /// [fromLoginAttempt] : plus de reprises (connexion lente). [signOutIfProfileStillMissing] : si `false`,
  /// en cas d'échec durable on ne déconnecte pas et on conserve le profil déjà en mémoire (ex. Paramètres).
  Future<Profile?> refreshProfile({
    bool fromLoginAttempt = false,
    bool signOutIfProfileStillMissing = true,
  }) async {
    final u = _auth.currentUser ?? _auth.currentSession?.user;
    if (u == null) {
      _state = AppAuthState(
        user: _state.user,
        session: _state.session,
        profile: null,
        loading: false,
      );
      notifyListeners();
      return null;
    }
    final maxNull = fromLoginAttempt
        ? _kProfileNullRetriesLogin
        : _kProfileNullRetriesCold;
    Profile? p = await _loadProfileUntilResolved(
      u.id,
      maxNullRetries: maxNull,
      nullRetryDelay: _kProfileNullRetryDelay,
      signOutIfStillNull: signOutIfProfileStillMissing,
    );
    if (_auth.currentUser == null) return null;
    if (p == null) {
      return null;
    }
    // Jusqu'à 3 retentatives si is_active == false (évite faux positif juste après login)
    for (var i = 0; i < 3 && p != null && p.isActive == false; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      p = await _loadProfileUntilResolved(
        u.id,
        maxNullRetries: maxNull,
        nullRetryDelay: _kProfileNullRetryDelay,
        signOutIfStillNull: signOutIfProfileStillMissing,
      );
      if (_auth.currentUser == null) return null;
      if (p == null) {
        return null;
      }
    }
    _applyProfile(p, fromSessionCache: false);
    return p;
  }

  /// Déconnexion. Réinitialise aussi company et permissions si fournis au démarrage
  /// (évite qu'un autre utilisateur soit pris pour le précédent sans relancer l'app).
  Future<void> signOut({
    CompanyProvider? company,
    PermissionsProvider? permissions,
  }) async {
    await ProfileSessionCache.clear();
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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/app_toast.dart';
import '../../data/sync/sales_realtime_sync.dart';
import '../../data/sync/store_inventory_realtime_sync.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/offline_providers.dart';

/// Délai entre deux syncs automatiques en arrière-plan (quand en ligne).
/// 45 s : bon compromis pour que ventes / statuts (ex. annulation) se propagent sans attendre ~90 s.
const Duration _periodicSyncInterval = Duration(seconds: 45);

/// Relecture légère des quantités `store_inventory` (REST) — contourne Realtime si les WS ne passent pas.
const Duration _inventoryLightPollInterval = Duration(seconds: 2);

/// Initialise la connexion (Connectivity) et réchauffe Drift au premier build.
/// Déclenche SyncServiceV2 au démarrage, à la reconnexion, au retour de l'app au premier plan,
/// et toutes les 45 s quand en ligne. Affiche une bannière "Mode hors ligne" quand il n'y a pas de connexion.
class OfflineSyncWrapper extends ConsumerStatefulWidget {
  const OfflineSyncWrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineSyncWrapper> createState() => _OfflineSyncWrapperState();
}

class _OfflineSyncWrapperState extends ConsumerState<OfflineSyncWrapper> with WidgetsBindingObserver {
  final ConnectivityService _connectivity = ConnectivityService.instance;
  StreamSubscription<bool>? _sub;
  Timer? _periodicSyncTimer;
  Timer? _inventoryLightPollTimer;
  bool _isOnline = true;
  bool _dbReady = false;
  /// Dernière paire (utilisateur + entreprise) pour laquelle on a lancé la sync « au démarrage ».
  /// Évite les doublons à chaque rebuild, mais permet une nouvelle sync après login ou changement d’entreprise.
  String? _lastInitialSyncKey;
  int _lastSyncErrors = 0;
  StoreInventoryRealtimeSync? _storeInventoryRealtime;
  SalesRealtimeSync? _salesRealtime;
  bool _postgresRealtimeActive = false;
  bool? _lastWantPostgresRealtime;
  /// Dernière entreprise pour laquelle on a déclenché un pull stock immédiat (changement de société).
  String? _lastInventoryKickCompanyId;

  static bool _errorHandlersInstalled = false;

  @override
  void initState() {
    super.initState();
    if (!_errorHandlersInstalled) {
      _errorHandlersInstalled = true;
      AppErrorHandler.installFlutterErrorHandlers();
    }
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _dbReady) {
      unawaited(_onAppResumed());
    }
  }

  /// Après veille (surtout Windows / desktop), le JWT peut être expiré avant les requêtes PostgREST.
  /// Tente un refresh **avant** sync / permissions pour limiter les `PGRST303` / « JWT expired ».
  Future<void> _onAppResumed() async {
    await _refreshSessionBestEffort();
    if (!mounted) return;
    if (_isOnline) {
      final auth = context.read<AuthProvider>();
      final company = context.read<CompanyProvider>();
      final cid = company.currentCompanyId;
      if (auth.user?.id != null && cid != null) {
        final extra = <String>{};
        final cs = company.currentStoreId;
        if (cs != null && cs.isNotEmpty) extra.add(cs);
        unawaited(
          ref.read(syncServiceV2Provider).pullStoreInventoryLight(companyId: cid, extraStoreIds: extra),
        );
      }
      _runSync(silent: true);
    }
    _reloadPermissions();
  }

  Future<void> _refreshSessionBestEffort() async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return;
      await client.auth.refreshSession();
    } catch (_) {
      // Refresh token expiré ou erreur réseau : l’utilisateur verra « Session expirée » si besoin.
    }
  }

  Future<void> _init() async {
    await _connectivity.init();
    if (mounted) {
      setState(() {
        _isOnline = _connectivity.isOnline;
        _dbReady = true; // Drift est réchauffé au premier build via appDatabaseProvider
      });
      _sub = _connectivity.onConnectivityChanged.listen((online) {
        if (!mounted) return;
        setState(() => _isOnline = online);
        if (online) {
          _runSync(silent: false);
          _startPeriodicSync();
        } else {
          _stopPeriodicSync();
        }
      });
      if (_connectivity.isOnline) _startPeriodicSync();
    }
  }

  void _startPeriodicSync() {
    _stopPeriodicSync();
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      if (_dbReady && _isOnline) _runSync(silent: true);
    });
    _startInventoryLightPoll();
  }

  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _stopInventoryLightPoll();
  }

  void _startInventoryLightPoll() {
    _stopInventoryLightPoll();
    void runInventoryLightPull() {
      if (!_dbReady || !_isOnline || !mounted) return;
      final auth = context.read<AuthProvider>();
      final company = context.read<CompanyProvider>();
      if (auth.user?.id == null) return;
      final companyId = company.currentCompanyId;
      if (companyId == null) return;
      final sync = ref.read(syncServiceV2Provider);
      final extra = <String>{};
      final cs = company.currentStoreId;
      if (cs != null && cs.isNotEmpty) extra.add(cs);
      unawaited(sync.pullStoreInventoryLight(companyId: companyId, extraStoreIds: extra));
    }

    runInventoryLightPull();
    _inventoryLightPollTimer = Timer.periodic(_inventoryLightPollInterval, (_) => runInventoryLightPull());
  }

  void _stopInventoryLightPoll() {
    _inventoryLightPollTimer?.cancel();
    _inventoryLightPollTimer = null;
  }

  void _reloadPermissions() {
    if (!mounted) return;
    final companyId = context.read<CompanyProvider>().currentCompanyId;
    if (companyId != null) {
      context.read<PermissionsProvider>().load(companyId);
    }
  }

  Future<void> _runSync({bool silent = false}) async {
    if (!_dbReady) return;
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    final companyId = company.currentCompanyId;
    final storeId = company.currentStoreId;
    if (userId == null) return;
    try {
      final sync = ref.read(syncServiceV2Provider);
      final result = await sync.sync(
        userId: userId,
        companyId: companyId,
        storeId: storeId,
      );
      if (!mounted) return;
      if (result.sent > 0) company.refreshStores();
      _reloadPermissions();
      if (silent) return;
      if (result.errors == 0 && mounted) setState(() => _lastSyncErrors = 0);
      // Succès : toast si file poussée **ou** pull local réussi (ex. première connexion, rien en attente).
      if (result.errors == 0 && (result.sent > 0 || result.pulled)) {
        AppToast.success(context, 'Données synchronisées.');
      } else if (result.errors > 0) {
        _lastSyncErrors = result.errors;
        if (mounted) setState(() {});
        AppToast.error(
          context,
          'Certaines données n\'ont pas pu être synchronisées. Réessayez (tirez pour actualiser ou reconnectez-vous).',
        );
      }
    } catch (e, st) {
      if (kDebugMode) AppErrorHandler.log(e, st);
      if (mounted && !silent) {
        AppToast.error(context, 'Synchronisation impossible. Réessayez plus tard.');
      }
    }
  }

  /// Lance une sync complète (push file + pull Drift) dès que l’utilisateur est connecté **et**
  /// qu’une entreprise est connue — typiquement après la **première connexion** ou le chargement des sociétés.
  /// Une fois par couple (userId, companyId) tant que la session reste la même ; relancé si changement d’entreprise ou nouvelle connexion après déconnexion.
  void _maybeRunSyncOnStart() {
    if (!_dbReady || !_isOnline) return;
    final auth = context.read<AuthProvider>();
    final company = context.read<CompanyProvider>();
    final userId = auth.user?.id;
    final companyId = company.currentCompanyId;
    if (userId == null) {
      _lastInitialSyncKey = null;
      return;
    }
    if (companyId == null) return;
    final key = '$userId|$companyId';
    if (_lastInitialSyncKey == key) return;
    _lastInitialSyncKey = key;
    ref.read(appDatabaseProvider);
    Future.microtask(() async {
      await _runSync(silent: false);
    });
  }

  /// Stock (`store_inventory`) + ventes (`sales`) : même garde (en ligne + session).
  /// Offline / sync périodique inchangés : pas de WS hors ligne ; le pull reste le filet.
  void _setPostgresRealtimeActive(bool active) {
    if (active == _postgresRealtimeActive) return;
    _postgresRealtimeActive = active;
    if (active) {
      final db = ref.read(appDatabaseProvider);
      _storeInventoryRealtime ??= StoreInventoryRealtimeSync(db);
      _salesRealtime ??= SalesRealtimeSync(db, syncService: ref.read(syncServiceV2Provider));
      unawaited(_storeInventoryRealtime!.start());
      unawaited(_salesRealtime!.start());
    } else {
      unawaited(_storeInventoryRealtime?.stop() ?? Future<void>.value());
      unawaited(_salesRealtime?.stop() ?? Future<void>.value());
      _storeInventoryRealtime = null;
      _salesRealtime = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _stopPeriodicSync();
    unawaited(_storeInventoryRealtime?.stop() ?? Future<void>.value());
    unawaited(_salesRealtime?.stop() ?? Future<void>.value());
    _storeInventoryRealtime = null;
    _salesRealtime = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    ref.read(appDatabaseProvider); // Warm Drift on first build so first screen is instant.
    _maybeRunSyncOnStart();
    final wantPostgresRealtime =
        _dbReady && _isOnline && context.read<AuthProvider>().user != null;
    if (_lastWantPostgresRealtime != wantPostgresRealtime) {
      _lastWantPostgresRealtime = wantPostgresRealtime;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _setPostgresRealtimeActive(wantPostgresRealtime);
      });
    }
    final company = context.watch<CompanyProvider>();
    final permissions = context.read<PermissionsProvider>();
    final companyId = company.currentCompanyId;
    final pendingCountAsync = ref.watch(pendingActionsCountStreamProvider);
    final pendingCount = pendingCountAsync.valueOrNull ?? 0;
    if (companyId != null && companyId != permissions.loadedCompanyId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.read<PermissionsProvider>().load(companyId);
      });
    }
    final authUser = context.read<AuthProvider>().user;
    if (companyId == null) {
      _lastInventoryKickCompanyId = null;
    } else if (_dbReady &&
        _isOnline &&
        authUser != null &&
        companyId != _lastInventoryKickCompanyId) {
      _lastInventoryKickCompanyId = companyId;
      final toPull = companyId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final co = context.read<CompanyProvider>();
        final extra = <String>{};
        final cs = co.currentStoreId;
        if (cs != null && cs.isNotEmpty) extra.add(cs);
        unawaited(
          ref.read(syncServiceV2Provider).pullStoreInventoryLight(companyId: toPull, extraStoreIds: extra),
        );
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isOnline)
          Material(
            color: Colors.orange.shade700,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pendingCount > 0
                            ? 'Mode hors ligne — $pendingCount action(s) en attente. Synchronisation à la reconnexion.'
                            : 'Mode hors ligne — les ventes seront synchronisées à la reconnexion.',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_isOnline && _lastSyncErrors > 0)
          Material(
            color: Colors.red.shade700,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.sync_problem_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Échec de synchronisation ($_lastSyncErrors). Tirez pour réessayer.',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _lastSyncErrors = 0);
                        _runSync(silent: false);
                      },
                      child: Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

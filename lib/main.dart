import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'core/config/env.dart';
import 'core/config/supabase_config_storage.dart';
import 'services/auth/auth_service.dart';
import 'providers/auth_provider.dart';
import 'providers/company_provider.dart';
import 'providers/permissions_provider.dart';
import 'core/errors/app_error_handler.dart';
import 'core/errors/crash_reporting.dart';
import 'navigation/app_router.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows / desktop : resynchronise l’état des touches avec le moteur tôt pour limiter
  // les AssertionError dans HardwareKeyboard._assertEventIsRegular (événements clavier
  // parfois reçus hors séquence avant que l’état interne soit aligné).
  unawaited(HardwareKeyboard.instance.syncKeyboardState());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(HardwareKeyboard.instance.syncKeyboardState());
  });
  await CrashReporting.init();
  final rootZone = Zone.current;

  // Erreurs asynchrones non rattrapées (Future sans catch) : log, évite le crash.
  runZonedGuarded(() async {
    await initializeDateFormatting('fr_FR', null);
    tz_data.initializeTimeZones();
    // runApp dans la même zone que ensureInitialized pour éviter "Zone mismatch".
    rootZone.run(() => runApp(const _AppLoader()));
  }, (Object error, StackTrace stackTrace) {
    AppErrorHandler.log(error, stackTrace);
    if (kDebugMode && _isKnownFlutterKeyboardAssertionFromPlatform(error, stackTrace)) {
      return;
    }
    CrashReporting.captureException(error, stackTrace);
  });

  // Erreurs du framework Flutter (build, layout, etc.) : log ; en debug, afficher l’écran rouge.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode && _isKnownFlutterKeyboardAssertion(details)) {
      AppErrorHandler.log(details.exception, details.stack);
      return;
    }
    AppErrorHandler.log(details.exception, details.stack);
    CrashReporting.captureException(details.exception, details.stack);
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode && _isKnownFlutterKeyboardAssertionFromPlatform(error, stack)) {
      AppErrorHandler.log(error, stack);
      return true;
    }
    AppErrorHandler.log(error, stack);
    CrashReporting.captureException(error, stack);
    return true;
  };
}

/// Assertion connue côté moteur Flutter (clavier matériel) — souvent Windows / hot reload.
bool _isKnownFlutterKeyboardAssertion(FlutterErrorDetails details) {
  final ex = details.exception;
  if (ex is! AssertionError) return false;
  final st = details.stack?.toString() ?? '';
  return st.contains('hardware_keyboard.dart') &&
      st.contains('_assertEventIsRegular');
}

bool _isKnownFlutterKeyboardAssertionFromPlatform(Object error, StackTrace stack) {
  if (error is! AssertionError) return false;
  final st = stack.toString();
  return st.contains('hardware_keyboard.dart') &&
      st.contains('_assertEventIsRegular');
}

/// Charge Supabase puis affiche l'app (ou écran config / erreur) — évite l'écran blanc.
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  late Future<Widget> _future = _load();

  Future<Widget> _load() async {
    try {
      // initializeDateFormatting déjà fait dans runZonedGuarded avant runApp — évite double coût au démarrage.
      final stored = await SupabaseConfigStorage.get();
      final String url = stored?.url ?? Env.supabaseUrl;
      final String anonKey = stored?.anonKey ?? Env.supabaseAnonKey;

      // Validation au démarrage : fail fast si config invalide (évite host lookup sur URL incorrecte).
      final configError = Env.validateSupabaseConfig(url, anonKey);
      if (configError != null) {
        return MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEA580C))),
          debugShowCheckedModeBanner: false,
          home: _ConfigSupabaseScreen(
            onSaved: () => setState(() => _future = _load()),
            initialMessage: configError,
          ),
        );
      }

      await Supabase.initialize(url: url, anonKey: anonKey);
      final supabase = Supabase.instance.client;
      final authService = AuthService(supabase);
      final authProvider = AuthProvider(authService);
      final companyProvider = CompanyProvider();
      final permissionsProvider = PermissionsProvider(isSuperAdmin: authProvider.isSuperAdmin);
      authProvider.setSessionProviders(companyProvider, permissionsProvider);
      companyProvider.addListener(() {
        permissionsProvider.load(companyProvider.currentCompanyId);
      });
      permissionsProvider.load(companyProvider.currentCompanyId);
      final router = createAppRouter(authProvider);
      return ProviderScope(
        child: FasoStockApp(
          authProvider: authProvider,
          companyProvider: companyProvider,
          permissionsProvider: permissionsProvider,
          router: router,
        ),
      );
    } catch (e, st) {
      AppErrorHandler.log(e, st);
      final message = AppErrorHandler.toUserMessage(e, fallback: 'Une erreur inattendue s\'est produite. Rouvrez l\'app.');
      return MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEA580C))),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur au démarrage', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!;
        if (snapshot.hasError) {
          final msg = AppErrorHandler.toUserMessage(snapshot.error, fallback: 'Erreur au chargement. Rouvrez l\'app.');
          return MaterialApp(
            theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEA580C))),
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(msg),
                ),
              ),
            ),
          );
        }
    return MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEA580C))),
          debugShowCheckedModeBanner: false,
          home: Container(
            color: const Color(0xFFF1F5F9),
            child: Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              body: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFEA580C)),
                      const SizedBox(height: 16),
                      Text('Chargement...', style: TextStyle(color: Colors.grey.shade800, fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Écran de saisie URL + clé Supabase (quand config absente au build ou invalide).
class _ConfigSupabaseScreen extends StatefulWidget {
  const _ConfigSupabaseScreen({required this.onSaved, this.initialMessage});

  final VoidCallback onSaved;
  final String? initialMessage;

  @override
  State<_ConfigSupabaseScreen> createState() => _ConfigSupabaseScreenState();
}

class _ConfigSupabaseScreenState extends State<_ConfigSupabaseScreen> {
  final _urlController = TextEditingController();
  final _anonKeyController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    final key = _anonKeyController.text.trim();
    final validationError = Env.validateSupabaseConfig(url, key);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await SupabaseConfigStorage.set(url: url, anonKey: key);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Erreur lors de l\'enregistrement. Réessayez.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              const SizedBox(height: 24),
              Icon(Icons.settings_suggest_rounded, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Config Supabase',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
            Text(
                'Saisissez l\'URL et la clé anon de votre projet Supabase (Dashboard → Settings → API).',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (widget.initialMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.initialMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL Supabase',
                  hintText: 'https://xxxxx.supabase.co',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _anonKeyController,
                decoration: const InputDecoration(
                  labelText: 'Clé anon (anon public)',
                  hintText: 'eyJhbGciOiJIUzI1NiIs...',
                ),
                obscureText: true,
                autocorrect: false,
                maxLines: 1,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 14)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer et lancer'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

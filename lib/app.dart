import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/breakpoints.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/company_provider.dart';
import 'providers/permissions_provider.dart';
import 'providers/products_page_provider.dart';
import 'providers/sales_page_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'providers/pos_cart_settings_provider.dart';

/// Point d'entrée UI — thème, Providers, GoRouter.
/// Sur mobile (width < 600), thème et textScaler réduits pour tout afficher correctement.
class FasoStockApp extends StatelessWidget {
  const FasoStockApp({
    super.key,
    required this.authProvider,
    required this.companyProvider,
    required this.permissionsProvider,
    required this.router,
  });

  final AuthProvider authProvider;
  final CompanyProvider companyProvider;
  final PermissionsProvider permissionsProvider;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<CompanyProvider>.value(value: companyProvider),
        ChangeNotifierProvider<PermissionsProvider>.value(value: permissionsProvider),
        ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
        ChangeNotifierProvider(create: (_) => PosCartSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductsPageProvider()),
        ChangeNotifierProvider(create: (_) => SalesPageProvider()),
      ],
      child: Consumer<ThemeModeProvider>(
        builder: (_, themeModeProvider, _) {
          final w = MediaQuery.sizeOf(context).width;
          final isMobile = Breakpoints.isMobile(w);
          return MaterialApp.router(
            title: 'FasoStock',
            debugShowCheckedModeBanner: false,
            locale: const Locale('fr', 'FR'),
            supportedLocales: const [
              Locale('fr', 'FR'),
              Locale('en'),
            ],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: isMobile ? AppTheme.lightMobile() : AppTheme.light(),
            darkTheme: isMobile ? AppTheme.darkMobile() : AppTheme.dark(),
            themeMode: themeModeProvider.themeMode,
            routerConfig: router,
            builder: (context, child) {
              if (!isMobile) return child ?? const SizedBox.shrink();
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(0.92),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

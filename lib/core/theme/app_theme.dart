import 'package:flutter/material.dart';

/// Thème épuré et convivial — espace de travail clair, hiérarchie lisible, espacements généreux.
class AppTheme {
  AppTheme._();

  // Palette sobre et accueillante
  static const Color _accent = Color(0xFFE85D2C); // orange chaleureux
  static const Color _surfaceLight = Color(0xFFF8F7F5); // fond doux, légèrement chaud
  static const Color _surfaceContainerLight = Color(0xFFF1F0EC);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF121212);
  static const Color _surfaceContainerDark = Color(0xFF1E1E1E);

  /// Espacements cohérents (scale 4 → 8, 12, 16, 24, 32)
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  /// Rayons arrondis (convivialité)
  static const double radiusSm = 10;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  /// Espacements MOBILE uniquement (tout réduire pour petit écran)
  static const double spaceXsM = 3;
  static const double spaceSmM = 6;
  static const double spaceMdM = 8;
  static const double spaceLgM = 10;
  static const double spaceXlM = 14;
  static const double spaceXxlM = 20;

  /// Rayons mobile (légèrement réduits)
  static const double radiusSmM = 8;
  static const double radiusMdM = 10;
  static const double radiusLgM = 12;
  static const double radiusXlM = 14;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.light,
      primary: _accent,
      surface: _surfaceLight,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        surface: _surfaceLight,
        surfaceContainerHighest: _surfaceContainerLight,
        surfaceContainerLow: const Color(0xFFF5F4F0),
        surfaceContainerLowest: _cardLight,
        primaryContainer: _accent.withValues(alpha: 0.12),
        onPrimaryContainer: const Color(0xFF5C2A0E),
      ),
      scaffoldBackgroundColor: _surfaceLight,
      fontFamily: 'Roboto',
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 58,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 26),
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        color: _cardLight,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black.withValues(alpha: 0.04),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        filled: true,
        fillColor: _surfaceContainerLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 40,
        dense: true,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(fontSize: 15, height: 1.45, color: colorScheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: _cardLight,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _cardLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
      primary: _accent,
      surface: _surfaceDark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(
        surface: _surfaceDark,
        surfaceContainerHighest: _surfaceContainerDark,
        surfaceContainerLow: const Color(0xFF2C2C2C),
        surfaceContainerLowest: const Color(0xFF252525),
        primaryContainer: _accent.withValues(alpha: 0.18),
      ),
      scaffoldBackgroundColor: _surfaceDark,
      fontFamily: 'Roboto',
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 58,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 26),
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
        color: _surfaceContainerDark,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd)),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 40,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: _surfaceContainerDark,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(fontSize: 15, height: 1.45, color: colorScheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _surfaceContainerDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
    );
  }

  /// Thème light pour MOBILE uniquement (width < 600) — tailles réduites partout.
  static ThemeData lightMobile() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.light,
      primary: _accent,
      surface: _surfaceLight,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        surface: _surfaceLight,
        surfaceContainerHighest: _surfaceContainerLight,
        surfaceContainerLow: const Color(0xFFF5F4F0),
        surfaceContainerLowest: _cardLight,
        primaryContainer: _accent.withValues(alpha: 0.12),
        onPrimaryContainer: const Color(0xFF5C2A0E),
      ),
      scaffoldBackgroundColor: _surfaceLight,
      fontFamily: 'Roboto',
      textTheme: _buildTextThemeMobile(Brightness.light),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 58,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 20),
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLgM)),
        color: _cardLight,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black.withValues(alpha: 0.04),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMdM)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMdM),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMdM),
          borderSide: const BorderSide(color: _accent, width: 1.2),
        ),
        filled: true,
        fillColor: _surfaceContainerLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmM)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        minLeadingWidth: 32,
        dense: true,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmM)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: const TextStyle(fontSize: 11),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXlM)),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(fontSize: 12, height: 1.4, color: colorScheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 52,
        elevation: 0,
        backgroundColor: _cardLight,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 18,
          color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _cardLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXlM)),
        ),
      ),
    );
  }

  /// Thème dark pour MOBILE uniquement (width < 600).
  static ThemeData darkMobile() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
      primary: _accent,
      surface: _surfaceDark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(
        surface: _surfaceDark,
        surfaceContainerHighest: _surfaceContainerDark,
        surfaceContainerLow: const Color(0xFF2C2C2C),
        surfaceContainerLowest: const Color(0xFF252525),
        primaryContainer: _accent.withValues(alpha: 0.18),
      ),
      scaffoldBackgroundColor: _surfaceDark,
      fontFamily: 'Roboto',
      textTheme: _buildTextThemeMobile(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 58,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 20),
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLgM)),
        color: _surfaceContainerDark,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMdM)),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmM)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        minLeadingWidth: 32,
        dense: true,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXlM)),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(fontSize: 12, height: 1.4, color: colorScheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 52,
        elevation: 0,
        backgroundColor: _surfaceContainerDark,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 18,
          color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMdM)),
        contentTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _surfaceContainerDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXlM)),
        ),
      ),
    );
  }

  /// Text theme pour MOBILE — toutes les tailles réduites.
  static TextTheme _buildTextThemeMobile(Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;
    final color = brightness == Brightness.light
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFE6E1E5);
    return TextTheme(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color,
        fontSize: 20,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: color,
        fontSize: 18,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color,
        fontSize: 16,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: -0.3,
        height: 1.25,
        color: color,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 17,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.35,
        color: color,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        height: 1.35,
        color: color,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        height: 1.4,
        color: color,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 13,
        height: 1.45,
        color: color,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: color,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 11,
        height: 1.35,
        color: color.withValues(alpha: 0.85),
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.1,
        color: color,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        color: color,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 10,
        letterSpacing: 0.4,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white;
    final color = brightness == Brightness.light
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFE6E1E5);
    return TextTheme(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: color,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 26,
        letterSpacing: -0.3,
        height: 1.25,
        color: color,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        height: 1.35,
        color: color,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: -0.2,
        height: 1.3,
        color: color,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.35,
        color: color,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.4,
        color: color,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        color: color,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        color: color,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: color.withValues(alpha: 0.85),
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.1,
        color: color,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: color,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.4,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }
}

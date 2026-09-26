// lib/theme/app_theme.dart
// Smart Rental Management — design tokens (Emerald + Teal).
//
// Light + Dark theme support. Material 3 throughout.
//
// Color philosophy:
//   Primary  = Emerald Green (trust, growth, property/landscape associations)
//   Secondary = Teal (modern, calm, professional contrast)
//
// Spacing philosophy: 8dp grid (4 / 8 / 16 / 24 / 32 / 48).
// Radius philosophy: 16dp is the canonical radius; 8 for chips, 24 for hero.
// Elevation philosophy: Material 3 tonal surfaces + soft shadows.

import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF2E7D32);          // Emerald Green 800
  static const Color primaryLight = Color(0xFF4CAF50);     // Green 500
  static const Color primaryLighter = Color(0xFF81C784);   // Green 300
  static const Color primarySurface = Color(0xFFE8F5E9);   // Green 50
  static const Color primaryBorder = Color(0xFFC8E6C9);    // Green 100
  static const Color primaryDark = Color(0xFF1B5E20);      // Green 900

  // Secondary (Teal)
  static const Color secondary = Color(0xFF26A69A);         // Teal 400
  static const Color secondaryLight = Color(0xFF80CBC4);    // Teal 200
  static const Color secondarySurface = Color(0xFFE0F2F1);  // Teal 50
  static const Color secondaryBorder = Color(0xFFB2DFDB);   // Teal 100
  static const Color secondaryDark = Color(0xFF00796B);     // Teal 900

  // Light theme neutrals
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderStrongLight = Color(0xFFD1D5DB);
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  // Dark theme neutrals (M3 dark surface palette)
  static const Color backgroundDark = Color(0xFF0F1419);    // near-black with cool tint
  static const Color surfaceDark = Color(0xFF1A1F2E);       // elevated card surface
  static const Color surfaceHighDark = Color(0xFF252B3B);   // higher elevation
  static const Color borderDark = Color(0xFF2D3548);        // hairline
  static const Color borderStrongDark = Color(0xFF3D465C);  // input border
  static const Color textPrimaryDark = Color(0xFFF1F5F9);   // near-white
  static const Color textSecondaryDark = Color(0xFF94A3B8); // slate
  static const Color textTertiaryDark = Color(0xFF64748B);  // dim slate

  // Dark-themed brand variants (slightly brighter for dark bg contrast)
  static const Color primarySurfaceDark = Color(0xFF1B3320);  // emerald 950
  static const Color primaryBorderDark = Color(0xFF2D5234);   // emerald 900
  static const Color secondarySurfaceDark = Color(0xFF0F2A2A); // teal 950
  static const Color secondaryBorderDark = Color(0xFF1F4D49);  // teal 900

  // Status (FSM colors — work in both themes)
  static const Color statusRequested = Color(0xFF6B7280);
  static const Color statusAccepted = Color(0xFF26A69A);
  static const Color statusScheduled = Color(0xFF6366F1);
  static const Color statusInProgress = Color(0xFFFB8C00);
  static const Color statusCompleted = Color(0xFF2E7D32);
  static const Color statusDelayed = Color(0xFFEF4444);
  static const Color statusCancelled = Color(0xFF991B1B);

  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFB8C00);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF26A69A);
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

class AppRadius {
  static const double xs = 6;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;     // ★ canonical — cards, dialogs
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;
}

class AppElevation {
  static const double none = 0;
  static const double card = 1;
  static const double floating = 4;
  static const double sheet = 8;
}

/// Mode-aware color resolver. Lets widgets ask "what's the right text color
/// for this surface?" without hardcoding light or dark values.
///
/// Usage: `AppTheme.semantic(context).textPrimary` or
///        `AppTheme.semantic(context).surface` — works in both modes.
class SemanticColors {
  const SemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primarySurface,
    required this.primaryBorder,
    required this.secondarySurface,
    required this.secondaryBorder,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primarySurface;
  final Color primaryBorder;
  final Color secondarySurface;
  final Color secondaryBorder;
  final Color shadow;

  static SemanticColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _dark : _light;
  }

  /// Light semantic palette. Public for testing.
  static const lightTokens = SemanticColors(
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    surfaceAlt: AppColors.backgroundLight,
    border: AppColors.borderLight,
    borderStrong: AppColors.borderStrongLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textTertiary: AppColors.textTertiaryLight,
    primarySurface: AppColors.primarySurface,
    primaryBorder: AppColors.primaryBorder,
    secondarySurface: AppColors.secondarySurface,
    secondaryBorder: AppColors.secondaryBorder,
    shadow: Color(0x1A1F2937),
  );

  /// Dark semantic palette. Public for testing.
  static const darkTokens = SemanticColors(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceAlt: AppColors.surfaceHighDark,
    border: AppColors.borderDark,
    borderStrong: AppColors.borderStrongDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    primarySurface: AppColors.primarySurfaceDark,
    primaryBorder: AppColors.primaryBorderDark,
    secondarySurface: AppColors.secondarySurfaceDark,
    secondaryBorder: AppColors.secondaryBorderDark,
    shadow: Color(0x66000000),
  );

  // Internal aliases (kept for backwards compat with internal callers).
  static const _light = lightTokens;
  static const _dark = darkTokens;
}

class AppTheme {
  static const Color primary = AppColors.primary;
  static const Color secondary = AppColors.secondary;

  /// Hero gradients — same brand in both modes (emerald + teal).
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryLight],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.secondaryDark, AppColors.secondary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C2D12), Color(0xFFEA580C)],
  );

  // ============== LIGHT THEME ==============
  static ThemeData light() => _build(brightness: Brightness.light);

  // ============== DARK THEME ==============
  static ThemeData dark() => _build(brightness: Brightness.dark);

  // ============== SHARED BUILDER ==============
  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final sem = isDark ? SemanticColors._dark : SemanticColors._light;

    final colorScheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.dark,
            primary: AppColors.primaryLight,        // brighter for dark bg
            onPrimary: const Color(0xFF003912),
            secondary: AppColors.secondaryLight,
            onSecondary: const Color(0xFF003733),
            surface: sem.surface,
            onSurface: sem.textPrimary,
            error: AppColors.error,
            onError: Colors.white,
          )
        : ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
            primary: primary,
            secondary: secondary,
            surface: sem.surface,
            onSurface: sem.textPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: sem.background,
      appBarTheme: AppBarTheme(
        backgroundColor: sem.surface,
        foregroundColor: sem.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: sem.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: sem.textSecondary),
      ),
      cardTheme: CardTheme(
        color: sem.surface,
        elevation: AppElevation.card,
        shadowColor: sem.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: BorderSide(color: sem.border),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.primaryLight : primary,
          foregroundColor: isDark ? const Color(0xFF003912) : AppColors.textPrimaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.primaryLight : primary,
          side: BorderSide(
            color: isDark ? AppColors.primaryLight : primary,
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.primaryLight : primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? sem.surfaceAlt : AppColors.backgroundLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: sem.textTertiary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: sem.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: sem.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryLight : primary,
            width: 1.5,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: sem.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: sem.surface,
        elevation: 1,
        indicatorColor: isDark ? AppColors.primarySurfaceDark : AppColors.primarySurface,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: sem.textPrimary),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? AppColors.primaryLight : primary,
        foregroundColor: isDark ? const Color(0xFF003912) : AppColors.textPrimaryLight,
        elevation: AppElevation.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.l)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sem.surface,
        elevation: AppElevation.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: sem.borderStrong,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? sem.surfaceAlt : AppColors.textPrimaryLight,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.primarySurfaceDark : AppColors.primarySurface,
        labelStyle: TextStyle(
          color: isDark ? AppColors.primaryLighter : AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide(
          color: isDark ? AppColors.primaryBorderDark : AppColors.primaryBorder,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: sem.surface,
        surfaceTintColor: sem.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          side: BorderSide(color: sem.border),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: sem.surface,
        surfaceTintColor: sem.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.primaryLight : primary,
      ),
      iconTheme: IconThemeData(color: sem.textSecondary),
      listTileTheme: ListTileThemeData(
        iconColor: sem.textSecondary,
        textColor: sem.textPrimary,
      ),
    );
  }
}

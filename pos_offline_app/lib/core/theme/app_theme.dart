import 'package:flutter/material.dart';

/// Semua konstanta warna app — light & dark
class AppColors {
  AppColors._();

  // ── Accent (sama di light & dark) ──────────────────────────────
  static const Color accent       = Color(0xFFFF6B35);
  static const Color accentLight  = Color(0xFFFF8C42);
  static const Color accentDark   = Color(0xFFEA580C);

  // ── Success / Warning / Error ───────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error   = Color(0xFFF44336);
  static const Color info    = Color(0xFF2196F3);

  // ── LIGHT ───────────────────────────────────────────────────────
  static const Color lightBackground  = Color(0xFFF4F5F7);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt  = Color(0xFFF8F9FA);
  static const Color lightTextPrimary = Color(0xFF1A1D26);
  static const Color lightTextSecondary = Color(0xFF888C9A);
  static const Color lightDivider     = Color(0xFFE8E9EF);
  static const Color lightBorder      = Color(0xFFE0E0E0);

  // Sidebar light
  static const Color lightSidebarTop    = Color(0xFF1E2235);
  static const Color lightSidebarMid    = Color(0xFF2D3154);
  static const Color lightSidebarBottom = Color(0xFF1E2235);

  // ── DARK ────────────────────────────────────────────────────────
  static const Color darkBackground    = Color(0xFF0F1117);
  static const Color darkSurface       = Color(0xFF1A1D26);
  static const Color darkSurfaceAlt    = Color(0xFF1E2235);
  static const Color darkSurfaceCard   = Color(0xFF242838);
  static const Color darkTextPrimary   = Color(0xFFE8E9EF);
  static const Color darkTextSecondary = Color(0xFF8B8FA8);
  static const Color darkDivider       = Color(0xFF2A2D3E);
  static const Color darkBorder        = Color(0xFF2E3147);

  // Sidebar dark
  static const Color darkSidebarTop    = Color(0xFF0D0F18);
  static const Color darkSidebarMid    = Color(0xFF141728);
  static const Color darkSidebarBottom = Color(0xFF0D0F18);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary:    AppColors.accent,
          secondary:  AppColors.accentLight,
          surface:    AppColors.lightSurface,
          error:      AppColors.error,
          onPrimary:  Colors.white,
          onSecondary: Colors.white,
          onSurface:  AppColors.lightTextPrimary,
          onError:    Colors.white,
          outline:    AppColors.lightBorder,
          surfaceContainerHighest: AppColors.lightSurfaceAlt,
        ),
        scaffoldBackgroundColor: AppColors.lightBackground,
        cardColor:               AppColors.lightSurface,
        dividerColor:            AppColors.lightDivider,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightSidebarTop,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightSurfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: AppColors.lightTextPrimary),
          bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
          bodySmall:  TextStyle(color: AppColors.lightTextSecondary),
          titleLarge: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
          titleMedium:TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.grey[400]),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : Colors.grey[300]),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary:    AppColors.accent,
          secondary:  AppColors.accentLight,
          surface:    AppColors.darkSurface,
          error:      AppColors.error,
          onPrimary:  Colors.white,
          onSecondary: Colors.white,
          onSurface:  AppColors.darkTextPrimary,
          onError:    Colors.white,
          outline:    AppColors.darkBorder,
          surfaceContainerHighest: AppColors.darkSurfaceAlt,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        cardColor:               AppColors.darkSurface,
        dividerColor:            AppColors.darkDivider,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSidebarTop,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurfaceCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: AppColors.darkTextPrimary),
          bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
          bodySmall:  TextStyle(color: AppColors.darkTextSecondary),
          titleLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold),
          titleMedium:TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.grey[600]),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : Colors.grey[800]),
        ),
      );
}

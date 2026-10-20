import 'package:flutter/material.dart';

class AppColors {
  // Brand Base
  static const Color primary = Color(0xFF00B4D8);
  static const Color secondary = accent;
  static const Color primaryDark = Color(0xFF0077B6);
  static const Color primaryLight = Color(0xFF90E0EF);
  static const Color accent = Color(0xFF48CAE4);

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF0D1B2A);
  static const Color darkSurface = Color(0xFF1B263B);
  static const Color darkSurfaceLight = Color(0xFF2E3D52);
  static const Color darkBorder = Color(0xFF3A4B64);
  static const Color darkTextPrimary = Color(0xFFF8F9FA);
  static const Color darkTextSecondary = Color(0xFFADB5BD);
  static const Color darkTextMuted = Color(0xFF6C757D);

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFF4F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFE9ECEF);
  static const Color lightBorder = Color(0xFFDEE2E6);
  static const Color lightTextPrimary = Color(0xFF1D2D44);
  static const Color lightTextSecondary = Color(0xFF495057);
  static const Color lightTextMuted = Color(0xFF8D99AE);

  // Legacy compatibility fallbacks (defaults to dark theme tokens)
  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color surfaceLight = darkSurfaceLight;
  static const Color border = darkBorder;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;

  // 1. Monitoring Telemetry Status (Monitoring Zones)
  static const Color zoneOptimal = Color(0xFF10B981); // Emerald
  static const Color zoneLow = Color(0xFFF59E0B);     // Amber
  static const Color zoneCritical = Color(0xFFEF4444); // Red/Coral
  static const Color zoneOffline = Color(0xFF6B7280);  // Slate Grey

  // 2. Irrigation Hydrology Status
  static const Color irrigationSafe = Color(0xFF06B6D4);      // Cyan
  static const Color irrigationRefluxNeeded = Color(0xFFF97316); // Orange
  static const Color irrigationFlooded = Color(0xFF3B82F6);   // Blue

  // Backward compatibility aliases
  static const Color awdSafe = irrigationSafe;
  static const Color awdRefluxNeeded = irrigationRefluxNeeded;
  static const Color awdFlooded = irrigationFlooded;

  // 3. Centralized Irrigation Status
  static const Color pumpActive = Color(0xFF14B8A6);   // Teal
  static const Color pumpIdle = Color(0xFF64748B);     // Slate
  static const Color valveOpen = Color(0xFF2563EB);    // Vivid Blue
  static const Color valveClosed = Color(0xFF475569);  // Charcoal

  // 4. Device Hardware & Signal Status
  static const Color deviceBatteryGood = Color(0xFF22C55E);
  static const Color deviceBatteryLow = Color(0xFFEAB308);
  static const Color deviceLoRaConnected = Color(0xFF6366F1);
  static const Color deviceLoRaWeak = Color(0xFFEC4899);

  // 5. General Alerts & Badges
  static const Color alertInfo = Color(0xFF3B82F6);
  static const Color alertSuccess = Color(0xFF10B981);
  static const Color alertWarning = Color(0xFFF59E0B);
  static const Color alertError = Color(0xFFEF4444);

  // General Status Aliases
  static const Color info = alertInfo;
  static const Color success = alertSuccess;
  static const Color warning = alertWarning;
  static const Color error = alertError;
  // Dynamic theme-aware resolvers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color surfaceLightOf(BuildContext context) =>
      isDark(context) ? darkSurfaceLight : lightSurfaceLight;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : lightTextMuted;
}

extension AppColorsThemeExtension on BuildContext {
  bool get isDarkMode => AppColors.isDark(this);
  Color get appBackground => AppColors.backgroundOf(this);
  Color get appSurface => AppColors.surfaceOf(this);
  Color get appSurfaceLight => AppColors.surfaceLightOf(this);
  Color get appBorder => AppColors.borderOf(this);
  Color get appTextPrimary => AppColors.textPrimaryOf(this);
  Color get appTextSecondary => AppColors.textSecondaryOf(this);
  Color get appTextMuted => AppColors.textMutedOf(this);
}

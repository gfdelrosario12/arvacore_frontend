import 'package:flutter/material.dart';

class AppColors {
  // Brand Base — Green Eco-Tech Futuristic Palette
  static const Color primary = Color(0xFF10B981);       // Emerald
  static const Color secondary = Color(0xFF39FF88);     // Neon Accent
  static const Color primaryDark = Color(0xFF065F46);   // Forest
  static const Color primaryLight = Color(0xFF6EE7B7);  // Light Emerald
  static const Color accent = Color(0xFF39FF88);        // Neon Green Accent

  // Futuristic Green Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF071510);   // Dark Green Void
  static const Color darkSurface = Color(0xFF10251B);      // Deep Emerald Surface
  static const Color darkSurfaceLight = Color(0xFF183827); // Elevated Glass Surface
  static const Color darkBorder = Color(0xFF1B4D36);       // Emerald Border
  static const Color darkTextPrimary = Color(0xFFF0FDF4);  // Crisp Eco-White
  static const Color darkTextSecondary = Color(0xFFA7F3D0);// Subtle Mint
  static const Color darkTextMuted = Color(0xFF6EE7B7);    // Muted Emerald

  // Light Theme Surfaces (Refined Eco-Tech Day)
  static const Color lightBackground = Color(0xFFF0FDF4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFDCFCE7);
  static const Color lightBorder = Color(0xFFA7F3D0);
  static const Color lightTextPrimary = Color(0xFF064E3B);
  static const Color lightTextSecondary = Color(0xFF047857);
  static const Color lightTextMuted = Color(0xFF10B981);

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
  static const Color irrigationSafe = Color(0xFF10B981);      // Emerald Safe
  static const Color irrigationRefluxNeeded = Color(0xFFF97316); // Orange
  static const Color irrigationFlooded = Color(0xFF059669);   // Deep Emerald Flood

  // Backward compatibility aliases
  static const Color awdSafe = irrigationSafe;
  static const Color awdRefluxNeeded = irrigationRefluxNeeded;
  static const Color awdFlooded = irrigationFlooded;

  // 3. Centralized Irrigation Status
  static const Color pumpActive = Color(0xFF39FF88);   // Neon Green Active
  static const Color pumpIdle = Color(0xFF4B6B5C);     // Muted Green-Grey
  static const Color valveOpen = Color(0xFF10B981);    // Emerald Valve Open
  static const Color valveClosed = Color(0xFF334E41);  // Dark Eco Slate

  // 4. Device Hardware & Signal Status
  static const Color deviceBatteryGood = Color(0xFF39FF88);
  static const Color deviceBatteryLow = Color(0xFFEAB308);
  static const Color deviceLoRaConnected = Color(0xFF10B981);
  static const Color deviceLoRaWeak = Color(0xFFF59E0B);

  // 5. General Alerts & Badges
  static const Color alertInfo = Color(0xFF10B981);
  static const Color alertSuccess = Color(0xFF39FF88);
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

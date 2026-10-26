import 'package:flutter/material.dart';

/// Centralized Design System Tokens & Breakpoints for ArvaLink
/// Standardized across Mobile, Tablet, and Desktop / Web.
class AppDimensions {
  // Centralized Responsive Breakpoints
  static const double breakpointMobile = 600.0;
  static const double breakpointTablet = 1024.0;
  static const double breakpointDesktop = 1440.0;

  // Viewport Width Constraints
  static const double minMobileWidth = 360.0;
  static const double maxMobileContentWidth = 600.0;
  static const double maxTabletContentWidth = 960.0;
  static const double maxDesktopContentWidth = 1380.0;

  // Legacy compatibility alias
  static const double maxMobileWidth = maxMobileContentWidth;

  // Touch Target Minimum (Accessibility standard)
  static const double minTouchTarget = 48.0;

  // Padding & Spacing Tokens
  static const double spaceXxs = 2.0;
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double spaceXxl = 48.0;

  // Border Radius Tokens
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // Icon Size Tokens
  static const double iconXs = 14.0;
  static const double iconSm = 18.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 40.0;

  // Elevation Tokens
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Component Sizes
  static const double buttonHeight = 48.0;
  static const double buttonHeightCompact = 36.0;
  static const double chipHeight = 36.0;
  static const double badgeHeight = 26.0;
  static const double inputHeight = 52.0;

  // Web & Desktop Navigation
  static const double webSidebarWidth = 260.0;
  static const double webRailWidth = 72.0;

  // Helper Queries
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < breakpointMobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= breakpointMobile && width < breakpointTablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointTablet;

  static bool isWideScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpointMobile;
}

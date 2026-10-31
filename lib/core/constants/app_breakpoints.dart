import 'package:flutter/material.dart';
import 'app_dimensions.dart';

/// Centralized Responsive Breakpoint Utilities for ArvaLink.
/// Ensures consistent adaptation across Mobile, Tablet, and Desktop/Web.
class AppBreakpoints {
  static const double smallMobile = AppDimensions.breakpointSmallMobile; // 480
  static const double mobile = AppDimensions.breakpointMobile;           // 768
  static const double tablet = AppDimensions.breakpointTablet;           // 1024
  static const double desktop = AppDimensions.breakpointDesktop;         // 1200
  static const double largeDesktop = AppDimensions.breakpointLargeDesktop; // 1440

  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < smallMobile;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  static bool isSmallDesktop(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= desktop && w < largeDesktop;
  }

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= largeDesktop;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobile;

  /// Returns responsive value based on current breakpoint
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= AppDimensions.breakpointLargeDesktop && largeDesktop != null) {
      return largeDesktop;
    }
    if (w >= AppDimensions.breakpointDesktop && desktop != null) {
      return desktop;
    }
    if (w >= AppDimensions.breakpointTablet && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}

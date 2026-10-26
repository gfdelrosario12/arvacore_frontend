import 'package:flutter/material.dart';
import 'app_dimensions.dart';

/// Centralized Responsive Breakpoint Utilities for ArvaLink.
/// Ensures consistent adaptation across Mobile, Tablet, and Desktop/Web.
class AppBreakpoints {
  static const double mobile = AppDimensions.breakpointMobile;
  static const double tablet = AppDimensions.breakpointTablet;
  static const double desktop = AppDimensions.breakpointDesktop;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

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
  }) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= AppDimensions.breakpointTablet && desktop != null) {
      return desktop;
    }
    if (w >= AppDimensions.breakpointMobile && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}

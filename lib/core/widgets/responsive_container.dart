import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';

/// Adaptive responsive container providing optimal content framing for:
/// - Mobile: Natural fluid full-width layout with touch-friendly margins.
/// - Tablet: Centered layout constrained to [AppDimensions.maxTabletContentWidth].
/// - Desktop/Web: Centered layout constrained to [AppDimensions.maxDesktopContentWidth].
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxCustomWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxCustomWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    double maxWidth;
    if (maxCustomWidth != null) {
      maxWidth = maxCustomWidth!;
    } else if (width >= AppDimensions.breakpointTablet) {
      maxWidth = AppDimensions.maxDesktopContentWidth;
    } else if (width >= AppDimensions.breakpointMobile) {
      maxWidth = AppDimensions.maxTabletContentWidth;
    } else {
      maxWidth = double.infinity;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class AquaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AquaCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBorder = borderColor ?? (isDark 
        ? const Color(0xFF1E3A56) 
        : const Color(0xFFE2E8F0));

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: gradient == null 
            ? (isDark ? AppColors.darkSurface : AppColors.lightSurface) 
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: defaultBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: content,
        ),
      );
    }

    return content;
  }
}

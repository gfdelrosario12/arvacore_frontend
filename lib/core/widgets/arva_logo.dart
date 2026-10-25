import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_strings.dart';

/// Centralized, standardized ArvaLink branding logo widget.
/// Renders the official emblem asset with graceful fallback to a themed icon emblem.
class ArvaLogo extends StatelessWidget {
  /// Dimension (width/height) of the emblem.
  final double size;

  /// Whether to display the text label next to or below the emblem.
  final bool showLabel;

  /// Layout orientation if label is shown.
  final Axis direction;

  /// Custom color override for the emblem border/icon fallback.
  final Color? color;

  /// Custom label text override (defaults to AppStrings.arvaLinkName).
  final String? customLabel;

  /// Subtitle or descriptor text.
  final String? subtitle;

  const ArvaLogo({
    super.key,
    this.size = 40.0,
    this.showLabel = false,
    this.direction = Axis.horizontal,
    this.color,
    this.customLabel,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = color ?? AppColors.primary;

    final emblem = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brandColor.withValues(alpha: 0.12),
        border: Border.all(
          color: brandColor.withValues(alpha: 0.4),
          width: size > 48 ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.15),
            blurRadius: size * 0.2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/arvalink_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.water_drop,
                size: size * 0.55,
                color: brandColor,
              ),
            );
          },
        ),
      ),
    );

    if (!showLabel) {
      return emblem;
    }

    final labelWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: direction == Axis.horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          customLabel ?? AppStrings.arvaLinkName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: theme.textTheme.bodyLarge?.color,
          ),
          textAlign: direction == Axis.horizontal ? TextAlign.start : TextAlign.center,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: direction == Axis.horizontal ? TextAlign.start : TextAlign.center,
          ),
        ],
      ],
    );

    if (direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          const SizedBox(width: AppDimensions.spaceSm),
          Flexible(child: labelWidget),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          const SizedBox(height: AppDimensions.spaceSm),
          labelWidget,
        ],
      );
    }
  }
}

import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';

enum AquaButtonVariant { primary, secondary, outline, text }

class AquaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AquaButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final bool compact;

  const AquaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AquaButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget childWidget;
    if (isLoading) {
      childWidget = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else {
      childWidget = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppDimensions.iconSm),
            const SizedBox(width: AppDimensions.spaceSm),
          ],
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final effectiveFullWidth = compact ? false : isFullWidth;
    final effectiveHeight = compact ? 34.0 : AppDimensions.buttonHeight;
    final compactPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
        : null;

    Widget button;
    switch (variant) {
      case AquaButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: compact
              ? ElevatedButton.styleFrom(
                  padding: compactPadding,
                  minimumSize: Size(0, effectiveHeight),
                )
              : null,
          child: childWidget,
        );
        break;
      case AquaButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.white,
            padding: compactPadding,
            minimumSize: compact ? Size(0, effectiveHeight) : null,
          ),
          child: childWidget,
        );
        break;
      case AquaButtonVariant.outline:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: compact
              ? OutlinedButton.styleFrom(
                  padding: compactPadding,
                  minimumSize: Size(0, effectiveHeight),
                )
              : null,
          child: childWidget,
        );
        break;
      case AquaButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(0, compact ? effectiveHeight : AppDimensions.minTouchTarget),
            padding: compactPadding,
          ),
          child: childWidget,
        );
        break;
    }

    if (effectiveFullWidth) {
      return SizedBox(
        width: double.infinity,
        height: effectiveHeight,
        child: button,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: effectiveHeight),
      child: button,
    );
  }
}

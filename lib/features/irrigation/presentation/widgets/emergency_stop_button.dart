import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

class EmergencyStopButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const EmergencyStopButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.alertError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.alertError, width: 2),
      ),
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.alertError, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'HIGH-PRIORITY SAFETY INTERLOCK',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.alertError,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Immediately halts main pump execution and closes central distribution valves regardless of automatic or manual mode state.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alertError,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.touch_app, size: 28),
              label: const Text(
                'EMERGENCY STOP CENTRAL PUMP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              onPressed: isLoading ? null : onPressed,
            ),
          ),
        ],
      ),
    );
  }
}

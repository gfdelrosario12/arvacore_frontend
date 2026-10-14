import 'package:flutter/material.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_button.dart';

class PairingRequestsModal extends StatelessWidget {
  final List<PairingRequestDto> requests;
  final ValueChanged<PairingRequestDto> onAllow;
  final ValueChanged<PairingRequestDto> onReject;

  const PairingRequestsModal({
    super.key,
    required this.requests,
    required this.onAllow,
    required this.onReject,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PairingRequestDto> requests,
    required ValueChanged<PairingRequestDto> onAllow,
    required ValueChanged<PairingRequestDto> onReject,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PairingRequestsModal(
        requests: requests,
        onAllow: onAllow,
        onReject: onReject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Incoming Node Pairing Requests',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${requests.length} Pending',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(
            'Hardware nodes that pressed their physical pairing button. Click Allow to proceed with device selection and zone assignment.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: Center(
                child: Text('No pending pairing requests.', style: theme.textTheme.bodyMedium),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spaceSm),
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceSm),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.developer_board, size: 20, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  req.nodeId,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: req.recognized
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                req.recognized ? 'RECOGNIZED' : 'UNKNOWN NODE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: req.recognized ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'MAC: ${req.macAddress ?? 'N/A'} • Model: ${req.hardwareModel ?? 'ESP32'} • FW: ${req.firmwareVersion ?? 'v1.0'}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        Text(
                          'Requested: ${req.requestedAt}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
                        ),
                        if (req.existingZoneName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Current Assigned Zone: ${req.existingZoneName}',
                            style: const TextStyle(fontSize: 11, color: AppColors.primary),
                          ),
                        ],
                        const SizedBox(height: AppDimensions.spaceSm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AquaButton(
                              label: 'Reject',
                              icon: Icons.close,
                              variant: AquaButtonVariant.outline,
                              compact: true,
                              onPressed: () => onReject(req),
                            ),
                            const SizedBox(width: 8),
                            AquaButton(
                              label: 'Allow',
                              icon: Icons.check,
                              variant: AquaButtonVariant.primary,
                              compact: true,
                              onPressed: () => onAllow(req),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


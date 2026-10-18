import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

class NodeUnpairConfirmationDialog extends StatefulWidget {
  final String nodeId;
  final String? displayName;
  final Future<bool> Function() onConfirm;

  const NodeUnpairConfirmationDialog({
    super.key,
    required this.nodeId,
    this.displayName,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String nodeId,
    String? displayName,
    required Future<bool> Function() onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NodeUnpairConfirmationDialog(
        nodeId: nodeId,
        displayName: displayName,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<NodeUnpairConfirmationDialog> createState() =>
      _NodeUnpairConfirmationDialogState();
}

class _NodeUnpairConfirmationDialogState
    extends State<NodeUnpairConfirmationDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _handleUnpair() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onConfirm();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Unpairing failed. Please check network and permissions.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Error during unpairing: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.displayName != null && widget.displayName!.isNotEmpty
        ? '${widget.displayName} (${widget.nodeId})'
        : widget.nodeId;

    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.link_off_rounded,
              color: AppColors.error,
              size: 32,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          const Text(
            'Unpair ArvaNode',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Are you sure you want to forcefully unpair $label?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Consequences of unpairing:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _bulletPoint('Node authorization credentials are immediately revoked.'),
                  _bulletPoint('Subsequent telemetry transmissions will be rejected.'),
                  _bulletPoint('Assigned monitoring zone and point bindings are cleared.'),
                  _bulletPoint('Physical ESP32 node must undergo fresh pairing to rejoin.'),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          height: AppDimensions.buttonHeight,
          child: TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ),
        SizedBox(
          height: AppDimensions.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleUnpair,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.link_off_rounded, size: 18),
            label: Text(_isSubmitting ? 'Unpairing...' : 'Force Unpair'),
          ),
        ),
      ],
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import '../../../core/api/api_dtos.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/widgets.dart';
import '../../../main.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../diagnostics/presentation/device_diagnostics_screen.dart';
import '../../nodes/domain/models/models.dart';
import '../../nodes/data/repositories/api_node_repository.dart';
import '../../nodes/presentation/widgets/node_registration_dialog.dart';
import '../../../core/api/api_factory.dart';
import '../domain/models/settings_models.dart';
import 'providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsNotifier? notifier;

  const SettingsScreen({super.key, this.notifier});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = widget.notifier ??
        SettingsNotifier(themeModeNotifier: themeModeNotifier);
    _notifier.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifier.removeListener(_onSettingsChanged);
    if (widget.notifier == null) _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _notifier.state;

    return ResponsiveContainer(
      child: state.status == SettingsLoadStatus.loading
          ? const LoadingStateWidget(message: 'Loading ArvaCore settings...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ArvaCore Settings', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Preferences for your operator experience',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  if (state.errorMessage != null) _buildErrorBanner(state.errorMessage!),
                  if (state.status == SettingsLoadStatus.saving) _buildSavingBanner(),
                  _buildAccountSection(context, state.settings.account),
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildNodePairingSection(context),
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildNotificationSection(context, state.settings.notifications),
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildUnitsSection(context, state.settings.measurementUnit),
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildAppearanceSection(context, state.settings.appearance),
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildLanguageSection(context, state.settings.language),
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildApplicationSection(context, state.settings.application),
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildSystemSection(context, state.settings.system),
                  const SizedBox(height: AppDimensions.spaceMd),
                  AquaButton(
                    label: 'Open Device Diagnostics',
                    icon: Icons.health_and_safety_outlined,
                    variant: AquaButtonVariant.outline,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DeviceDiagnosticsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNodePairingSection(BuildContext context) {
    final theme = Theme.of(context);
    return _section(
      context,
      'Hardware Node Pairing & Discovery',
      Icons.sensors_outlined,
      [
        Row(
          children: [
            const Icon(Icons.bluetooth_searching, size: 20, color: AppColors.primary),
            const SizedBox(width: AppDimensions.spaceSm),
            Expanded(
              child: Text(
                'Press the physical pairing button on your sensor node hardware to activate discoverable mode.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        AquaButton(
          label: 'Discover & Pair Hardware Node',
          icon: Icons.search,
          variant: AquaButtonVariant.primary,
          onPressed: () => _handleNodePairing(context),
        ),
        const SizedBox(height: AppDimensions.spaceXs),
        Text(
          'Discovered nodes can be dynamically assigned to new or existing monitoring zones.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _handleNodePairing(BuildContext context) async {
    final List<NodeDiscoveryInfo> discovered = [];
    try {
      final pairings = await ApiRepositoryFactory().system.getPendingPairingRequests();
      for (final p in pairings) {
        discovered.add(NodeDiscoveryInfo(
          id: p.nodeId,
          macAddress: p.macAddress ?? p.nodeId,
          hardwareModel: p.hardwareModel ?? 'ESP32 Wi-Fi Node',
          firmwareVersion: p.firmwareVersion ?? '1.0.0',
          rssiDbm: -65,
          detectedAt: DateTime.tryParse(p.requestedAt) ?? DateTime.now(),
          pairingRequestId: p.id,
          recognized: p.recognized,
          pairingStatus: p.pairingStatus,
          existingLifecycleState: p.existingLifecycleState,
          existingZoneId: p.existingZoneId,
          existingZoneName: p.existingZoneName,
        ));
      }
    } catch (_) {}

    try {
      final nodeRepo = ApiNodeRepository(ApiRepositoryFactory().nodes);
      final unassigned = await nodeRepo.fetchDiscoveredNodes();
      for (final u in unassigned) {
        if (!discovered.any((d) => d.macAddress == u.macAddress || d.id == u.id)) {
          discovered.add(u);
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    await NodeRegistrationDialog.show(
      context,
      discoveredNodes: discovered,
      onRefresh: () async {
        final List<NodeDiscoveryInfo> updated = [];
        try {
          final pending = await ApiRepositoryFactory().system.getPendingPairingRequests();
          for (final p in pending) {
            updated.add(NodeDiscoveryInfo(
              id: p.nodeId,
              macAddress: p.macAddress ?? p.nodeId,
              hardwareModel: p.hardwareModel ?? 'ESP32 Wi-Fi Node',
              firmwareVersion: p.firmwareVersion ?? '1.0.0',
              rssiDbm: -65,
              detectedAt: DateTime.tryParse(p.requestedAt) ?? DateTime.now(),
              pairingRequestId: p.id,
              recognized: p.recognized,
              pairingStatus: p.pairingStatus,
              existingLifecycleState: p.existingLifecycleState,
              existingZoneId: p.existingZoneId,
              existingZoneName: p.existingZoneName,
            ));
          }
        } catch (_) {}

        try {
          final nodeRepo = ApiNodeRepository(ApiRepositoryFactory().nodes);
          final unassigned = await nodeRepo.fetchDiscoveredNodes();
          for (final u in unassigned) {
            if (!updated.any((d) => d.macAddress == u.macAddress || d.id == u.id)) {
              updated.add(u);
            }
          }
        } catch (_) {}

        return updated;
      },
      onRegister: (NodeRegistrationRequestDto request) async {
        if (!context.mounted) return true;
        final matching = discovered.firstWhere(
          (d) => d.macAddress == request.macAddress,
          orElse: () => discovered.first,
        );

        if (matching.pairingRequestId != null) {
          int? zoneNum;
          if (request.zoneId.isNotEmpty) {
            zoneNum = int.tryParse(request.zoneId.replaceAll(RegExp(r'[^0-9]'), ''));
          }
          await ApiRepositoryFactory().system.approvePairingRequest(
            matching.pairingRequestId!,
            nodeId: request.displayName.isNotEmpty ? request.displayName : matching.id,
            identityType: 'MAC_ADDRESS',
            identityValue: request.macAddress,
            macAddress: request.macAddress,
            hardwareModel: matching.hardwareModel,
            monitoringZoneId: zoneNum,
          );
        } else {
          final nodeRepo = ApiNodeRepository(ApiRepositoryFactory().nodes);
          await nodeRepo.registerNode(request);
        }

        if (!context.mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully paired hardware ArvaNode ${request.displayName} (${request.macAddress})!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        return true;
      },
    );
  }

  Widget _buildAccountSection(BuildContext context, AccountSummary account) {
    final theme = Theme.of(context);
    final session = globalAuthNotifier.value.session;
    final username = session?.username.isNotEmpty == true ? session!.username : account.username;
    final email = session?.email.isNotEmpty == true ? session!.email : account.email;
    final role = session?.userRole?.displayLabel ?? (session?.role.isNotEmpty == true ? session!.role.toUpperCase() : account.role.toUpperCase());

    return _section(
      context,
      'User & Account',
      Icons.account_circle_outlined,
      [
        _valueRow('User', username, Icons.person_outline),
        _valueRow('Email', email, Icons.email_outlined),
        _valueRow('Role', role, Icons.badge_outlined),
        const SizedBox(height: AppDimensions.spaceSm),
        AquaButton(
          label: 'Sign Out ($username)',
          icon: Icons.logout,
          variant: AquaButtonVariant.outline,
          onPressed: () => _handleLogout(context),
        ),
        const SizedBox(height: AppDimensions.spaceXs),
        Text(
          'Account changes and session isolation are managed by ArvaCore authentication services.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildNotificationSection(
    BuildContext context,
    NotificationPreferences preferences,
  ) {
    return _section(
      context,
      'Notification Preferences',
      Icons.notifications_outlined,
      [
        _switchTile(
          'System alerts',
          'Receive important application health alerts',
          preferences.systemAlerts,
          (value) => _notifier.setNotifications(
            preferences.copyWith(systemAlerts: value),
          ),
        ),
        _switchTile(
          'Irrigation updates',
          'Receive field-level irrigation command updates',
          preferences.irrigationUpdates,
          (value) => _notifier.setNotifications(
            preferences.copyWith(irrigationUpdates: value),
          ),
        ),
        _switchTile(
          'Stale telemetry',
          'Be notified when monitoring data needs attention',
          preferences.staleTelemetry,
          (value) => _notifier.setNotifications(
            preferences.copyWith(staleTelemetry: value),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsSection(BuildContext context, MeasurementUnit unit) {
    return _section(
      context,
      'Measurement Units',
      Icons.straighten_outlined,
      [
        const Text('Used in settings-owned presentation only.'),
        const SizedBox(height: AppDimensions.spaceSm),
        AquaChipSelector<MeasurementUnit>(
          options: const [
            AquaChipOption(value: MeasurementUnit.metric, label: 'Metric', icon: Icons.public),
            AquaChipOption(value: MeasurementUnit.imperial, label: 'Imperial', icon: Icons.public),
          ],
          selectedValue: unit,
          onSelected: _notifier.setMeasurementUnit,
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context, SettingsAppearance appearance) {
    return _section(
      context,
      'Appearance',
      Icons.palette_outlined,
      [
        AquaChipSelector<SettingsAppearance>(
          options: const [
            AquaChipOption(value: SettingsAppearance.system, label: 'System', icon: Icons.brightness_auto),
            AquaChipOption(value: SettingsAppearance.light, label: 'Light', icon: Icons.light_mode),
            AquaChipOption(value: SettingsAppearance.dark, label: 'Dark', icon: Icons.dark_mode),
          ],
          selectedValue: appearance,
          onSelected: _notifier.setAppearance,
        ),
      ],
    );
  }

  Widget _buildLanguageSection(BuildContext context, SettingsLanguage language) {
    return _section(
      context,
      'Language',
      Icons.translate_outlined,
      [
        AquaChipSelector<SettingsLanguage>(
          options: const [
            AquaChipOption(value: SettingsLanguage.english, label: 'English', icon: Icons.language),
            AquaChipOption(value: SettingsLanguage.filipino, label: 'Filipino', icon: Icons.language),
          ],
          selectedValue: language,
          onSelected: _notifier.setLanguage,
        ),
      ],
    );
  }

  Widget _buildApplicationSection(
    BuildContext context,
    ApplicationInformation application,
  ) {
    return _section(
      context,
      'Application Information',
      Icons.info_outline,
      [
        _valueRow('Application', application.appName, Icons.water_drop_outlined),
        _valueRow('Version', application.version, Icons.numbers),
        _valueRow('Data source', application.dataSource, Icons.cloud_outlined),
      ],
    );
  }

  Widget _buildSystemSection(BuildContext context, SystemPreferences preferences) {
    return _section(
      context,
      'System Preferences',
      Icons.tune_outlined,
      [
        _switchTile(
          '24-hour time',
          'Use 24-hour formatting in settings-owned presentation',
          preferences.use24HourTime,
          (value) => _notifier.setSystemPreferences(
            preferences.copyWith(use24HourTime: value),
          ),
        ),
        _switchTile(
          'Confirm destructive actions',
          'Ask for confirmation before supported destructive actions',
          preferences.confirmDestructiveActions,
          (value) => _notifier.setSystemPreferences(
            preferences.copyWith(confirmDestructiveActions: value),
          ),
        ),
        const Divider(),
        _valueRow(
          'Irrigation configuration',
          'Managed by Central Field Control',
          Icons.water_drop_outlined,
        ),
        Text(
          'Settings does not configure zone-level irrigation behavior, pumps, or valves.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _valueRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: _notifier.state.isBusy ? null : onChanged,
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return _feedbackBanner(
      Icons.error_outline,
      AppColors.alertError,
      message,
      action: TextButton(
        onPressed: _notifier.load,
        child: const Text('Retry'),
      ),
    );
  }

  Widget _buildSavingBanner() {
    return _feedbackBanner(
      Icons.sync,
      AppColors.primary,
      'Saving settings...',
    );
  }

  Widget _feedbackBanner(
    IconData icon,
    Color color,
    String message, {
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceSm,
        vertical: AppDimensions.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(child: Text(message)),
          ?action,
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final username = globalAuthNotifier.value.session?.username;
    final userLabel = username != null && username.isNotEmpty ? username : 'active';
    final confirmed = await AquaDialog.show(
      context: context,
      title: 'Sign Out of ArvaCore?',
      message: 'Are you sure you want to end your $userLabel session?',
      confirmText: 'Sign Out',
      icon: Icons.logout,
      iconColor: AppColors.alertError,
    );
    if (confirmed == true) await globalAuthNotifier.logout();
  }
}

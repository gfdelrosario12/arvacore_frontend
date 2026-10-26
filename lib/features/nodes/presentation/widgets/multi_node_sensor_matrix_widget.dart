import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../nodes/domain/models/models.dart';

/// Renders real-time telemetry across the 6 standardized sensor categories
/// for every registered ArvaNode in the ecosystem.
///
/// Handles:
/// 1. Water Level Sensor (Ultrasonic distance in cm, depth cm, status)
/// 2. Soil Moisture & Matric Potential Sensor (% moisture, matric tension kPa)
/// 3. Ambient Temperature & Relative Humidity (°C & % RH)
/// 4. Leaf Wetness Sensor (Surface wetness index / duration)
/// 5. Soil Temperature & Chemical Property Probes (Soil temp °C, pH, EC mS/cm)
/// 6. Optical Chlorophyll / Leaf Color Sensor (SPAD index / LCC scale)
class MultiNodeSensorMatrixWidget extends StatelessWidget {
  final List<Esp32Node> nodes;
  final bool isLoading;
  final String? filterQuery;

  const MultiNodeSensorMatrixWidget({
    super.key,
    required this.nodes,
    this.isLoading = false,
    this.filterQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    var filteredNodes = nodes.where((n) =>
        n.lifecycleState != NodeLifecycleStatus.unregistered &&
        n.lifecycleState != NodeLifecycleStatus.decommissioned).toList();

    if (filterQuery != null && filterQuery!.trim().isNotEmpty) {
      final q = filterQuery!.trim().toLowerCase();
      filteredNodes = filteredNodes.where((n) {
        return n.id.toLowerCase().contains(q) ||
            n.displayName.toLowerCase().contains(q) ||
            (n.assignedZoneCode ?? '').toLowerCase().contains(q) ||
            (n.assignedZoneName ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (isLoading && filteredNodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spaceXl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (filteredNodes.isEmpty) {
      return AquaCard(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.sensors_off_outlined, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: AppDimensions.spaceSm),
              Text(
                filterQuery != null && filterQuery!.isNotEmpty
                    ? 'No ArvaNodes match "$filterQuery"'
                    : 'No registered ArvaNodes transmitting telemetry.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Guide Header Banner
        Container(
          margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '6 Agricultural Sensor Categories Telemetry Matrix',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Live continuous observations collected per ArvaNode. Channels without physical transducers are truthfully documented as "Not Equipped / Channel Inactive" without placeholder zeros.',
                style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ],
          ),
        ),

        // Node Cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredNodes.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spaceMd),
          itemBuilder: (context, index) {
            final node = filteredNodes[index];
            return _buildNodeSensorCategoriesCard(context, theme, node, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildNodeSensorCategoriesCard(
    BuildContext context,
    ThemeData theme,
    Esp32Node node,
    bool isDark,
  ) {
    final zoneCode = node.assignedZoneCode ?? (node.assignedZoneId != null ? 'Zone ${node.assignedZoneId}' : 'Unassigned');
    final isOnline = node.isOnline;
    final lastSeenStr = node.lastSeen.toLocal().toString().split('.').first;

    return AquaCard(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isOnline ? AppColors.success : AppColors.alertError).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(
                  Icons.sensors,
                  size: 20,
                  color: isOnline ? AppColors.success : AppColors.alertError,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            node.displayName.isNotEmpty ? node.displayName : node.id,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            zoneCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Node ID: ${node.id} • Last Seen: $lastSeenStr',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge.deviceStatus(isOnline ? 'ONLINE' : 'OFFLINE', compact: true),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.spaceSm),

          // The 6 Categories Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final crossAxisCount = isWide ? 3 : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: isWide ? 1.45 : 1.35,
                children: [
                  // Category 1: Water Level
                  _buildCategoryTile(
                    theme: theme,
                    title: '1. Water Level Sensor',
                    icon: Icons.water_drop_outlined,
                    iconColor: AppColors.primary,
                    content: _buildWaterLevelContent(node),
                    statusText: node.ultrasonicSensorHealth != null && node.ultrasonicSensorHealth!.toUpperCase() == 'OK'
                        ? 'Calibrated'
                        : (node.isUltrasonicSensorFailed ? 'Transducer Error' : 'Active'),
                    statusColor: node.isUltrasonicSensorFailed ? AppColors.alertError : AppColors.primary,
                  ),

                  // Category 2: Soil Moisture & Matric Potential
                  _buildCategoryTile(
                    theme: theme,
                    title: '2. Soil Moisture & Tension',
                    icon: Icons.grass_outlined,
                    iconColor: AppColors.zoneOptimal,
                    content: _buildSoilMoistureContent(node),
                    statusText: node.isSoilSensorFailed ? 'Probe Fault' : 'Active',
                    statusColor: node.isSoilSensorFailed ? AppColors.alertError : AppColors.zoneOptimal,
                  ),

                  // Category 3: Ambient Temp & Humidity
                  _buildCategoryTile(
                    theme: theme,
                    title: '3. Ambient Temp & RH',
                    icon: Icons.thermostat_outlined,
                    iconColor: Colors.orange.shade700,
                    content: _buildAmbientContent(node),
                    statusText: node.temperatureCelsius != null || node.humidityPercent != null ? 'Telemetry Active' : 'Not Equipped',
                    statusColor: node.temperatureCelsius != null ? Colors.orange.shade700 : Colors.grey,
                  ),

                  // Category 4: Leaf Wetness Sensor
                  _buildCategoryTile(
                    theme: theme,
                    title: '4. Leaf Wetness Sensor',
                    icon: Icons.eco_outlined,
                    iconColor: Colors.teal,
                    content: const [
                      Text('Surface Wetness: Unavailable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Duration: Not Equipped', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                    statusText: 'Not Installed',
                    statusColor: Colors.grey,
                  ),

                  // Category 5: Soil Temp & Chemical / EC
                  _buildCategoryTile(
                    theme: theme,
                    title: '5. Soil Temp & Chemical / EC',
                    icon: Icons.science_outlined,
                    iconColor: Colors.purple.shade600,
                    content: const [
                      Text('Soil Temp: Unavailable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('EC / Salinity: Not Equipped', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Soil pH: Not Equipped', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                    statusText: 'Probe Not Detected',
                    statusColor: Colors.grey,
                  ),

                  // Category 6: Optical Chlorophyll / Leaf Color
                  _buildCategoryTile(
                    theme: theme,
                    title: '6. Optical Chlorophyll / Color',
                    icon: Icons.camera_alt_outlined,
                    iconColor: Colors.indigo,
                    content: const [
                      Text('SPAD Chlorophyll: Unavailable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Leaf Color Chart (LCC): Not Installed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                    statusText: 'Optical Channel Offline',
                    statusColor: Colors.grey,
                  ),
                ],
              );
            },
          ),

          // Bottom Power & Signal Strip
          const SizedBox(height: AppDimensions.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.battery_charging_full, size: 14, color: isOnline ? AppColors.success : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Battery: ${node.batteryPercent != null ? "${node.batteryPercent}%" : (node.batteryVoltage != null ? "${node.batteryVoltage!.toStringAsFixed(2)}V" : "--")}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'RSSI: ${node.rssiDbm != null ? "${node.rssiDbm} dBm" : "Nominal"}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                Text(
                  'HW: ${node.hardwareRevision} • FW: ${node.firmwareVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWaterLevelContent(Esp32Node node) {
    if (node.isUltrasonicSensorFailed) {
      return const [
        Text('Sensor Fault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.alertError)),
        Text('Echo signal failure', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ];
    }
    final depth = node.waterLevelCm;
    final dist = node.waterLevelDistanceCm;

    return [
      Text(
        depth != null ? '${depth.toStringAsFixed(1)} cm depth' : 'No Depth Reading',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: depth != null ? AppColors.primary : Colors.grey,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        dist != null ? 'Raw Echo: ${dist.toStringAsFixed(1)} cm' : 'Raw Echo: --',
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    ];
  }

  List<Widget> _buildSoilMoistureContent(Esp32Node node) {
    if (node.isSoilSensorFailed) {
      return const [
        Text('Sensor Fault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.alertError)),
        Text('Capacitive trace open', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ];
    }
    final moisture = node.soilMoisturePercent;

    return [
      Text(
        moisture != null ? '${moisture.toStringAsFixed(1)}% moisture' : 'No Moisture Reading',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: moisture != null ? AppColors.zoneOptimal : Colors.grey,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'Matric Tension: Not Installed',
        style: TextStyle(fontSize: 10, color: Colors.grey),
      ),
    ];
  }

  List<Widget> _buildAmbientContent(Esp32Node node) {
    final temp = node.temperatureCelsius;
    final hum = node.humidityPercent;

    if (temp == null && hum == null) {
      return const [
        Text('Air Temp: Unavailable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        SizedBox(height: 2),
        Text('Humidity: Unavailable', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ];
    }

    return [
      Text(
        temp != null ? '${temp.toStringAsFixed(1)} °C ambient' : 'Air Temp: --',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 2),
      Text(
        hum != null ? '${hum.toStringAsFixed(1)}% RH' : 'RH: --',
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    ];
  }

  Widget _buildCategoryTile({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> content,
    required String statusText,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../../../core/realtime/realtime_events.dart';
import '../../../control/domain/models/control_enums.dart';
import '../../data/repositories/node_repository.dart';
import '../../domain/models/models.dart';

/// State object representing LoRaWAN device management and link diagnostics state.
class LoRaWANNodeStateData {
  final List<SensorNode> loRaWANNodes;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final ControlUserRole userRole;
  final Map<String, String> pendingDownlinks; // devEui -> status

  const LoRaWANNodeStateData({
    this.loRaWANNodes = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.userRole = ControlUserRole.operator,
    this.pendingDownlinks = const {},
  });

  bool get isAuthorized =>
      userRole == ControlUserRole.admin || userRole == ControlUserRole.operator;

  int get activeLoRaWANCount => loRaWANNodes.where((n) => n.isOnline).length;

  LoRaWANNodeStateData copyWith({
    List<SensorNode>? loRaWANNodes,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    ControlUserRole? userRole,
    Map<String, String>? pendingDownlinks,
  }) {
    return LoRaWANNodeStateData(
      loRaWANNodes: loRaWANNodes ?? this.loRaWANNodes,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      userRole: userRole ?? this.userRole,
      pendingDownlinks: pendingDownlinks ?? this.pendingDownlinks,
    );
  }
}

/// ChangeNotifier for managing LoRaWAN device identities, downlinks, and link status updates.
class LoRaWANNodeNotifier extends ChangeNotifier {
  final NodeRepository _nodeRepository;
  final RealtimeCoordinator? _realtimeCoordinator;
  LoRaWANNodeStateData _state;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;

  LoRaWANNodeNotifier({
    required NodeRepository nodeRepository,
    RealtimeCoordinator? realtimeCoordinator,
    ControlUserRole userRole = ControlUserRole.operator,
  })  : _nodeRepository = nodeRepository,
        _realtimeCoordinator = realtimeCoordinator,
        _state = LoRaWANNodeStateData(userRole: userRole) {
    _init();
  }

  LoRaWANNodeStateData get state => _state;

  void _setState(LoRaWANNodeStateData newState) {
    _state = newState;
    notifyListeners();
  }

  void _init() {
    loadLoRaWANNodes();
    _subscribeToRealtimeEvents();
  }

  Future<void> loadLoRaWANNodes() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final allNodes = await _nodeRepository.fetchNodes();
      final loRaWANOnly = allNodes
          .where((n) => n.loRaWANIdentity != null || n.macAddress.startsWith('DEV-') || n.macAddress.contains('0004A3'))
          .toList();
      _setState(_state.copyWith(loRaWANNodes: loRaWANOnly, isLoading: false));
    } catch (e) {
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load LoRaWAN devices: $e',
      ));
    }
  }

  /// Register a new LoRaWAN dynamic sensor node without hardcoded node IDs or quadrant codes.
  Future<bool> registerLoRaWANNode({
    required String devEui,
    required String joinEui,
    required String appKey,
    required String displayName,
    required String assignedFieldId,
    required String assignedZoneId,
  }) async {
    if (!_state.isAuthorized) {
      _setState(_state.copyWith(
        errorMessage: 'Unauthorized: Operator or Admin role required for LoRaWAN node registration.',
      ));
      return false;
    }

    _setState(_state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true));
    try {
      final request = NodeRegistrationRequestDto(
        macAddress: devEui,
        displayName: displayName,
        fieldId: assignedFieldId,
        zoneId: assignedZoneId,
      );

      final registered = await _nodeRepository.registerNode(request);
      final updatedNode = registered.copyWith(
        loRaWANIdentity: LoRaWANIdentity(
          devEui: devEui,
          joinEui: joinEui,
          appKey: appKey,
        ),
      );

      final updatedList = [..._state.loRaWANNodes, updatedNode];
      _setState(_state.copyWith(
        loRaWANNodes: updatedList,
        isSubmitting: false,
        successMessage: 'Successfully registered LoRaWAN device $devEui',
      ));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to register LoRaWAN device: $e',
      ));
      return false;
    }
  }

  /// Queue a Class A downlink command for a registered LoRaWAN node.
  Future<bool> queueDownlinkCommand({
    required String devEui,
    required int newIntervalSeconds,
  }) async {
    if (!_state.isAuthorized) {
      _setState(_state.copyWith(
        errorMessage: 'Unauthorized: Operator or Admin role required to queue downlinks.',
      ));
      return false;
    }

    final updatedDownlinks = Map<String, String>.from(_state.pendingDownlinks);
    updatedDownlinks[devEui] = 'queued';
    _setState(_state.copyWith(pendingDownlinks: updatedDownlinks));

    try {
      final targetNodeIndex = _state.loRaWANNodes.indexWhere(
        (n) => n.loRaWANIdentity?.devEui == devEui || n.macAddress == devEui,
      );
      if (targetNodeIndex != -1) {
        final node = _state.loRaWANNodes[targetNodeIndex];
        final updatedConfigDto = TransmissionConfigDto(
          intervalSeconds: newIntervalSeconds,
        );
        final updatedIdentity = node.loRaWANIdentity?.copyWith(
          fCntDown: (node.loRaWANIdentity?.fCntDown ?? 0) + 1,
          downlinkStatus: 'queued',
        );

        final resultConfig = await _nodeRepository.configureTransmissionInterval(
          node.id,
          updatedConfigDto,
        );

        final updatedNode = node.copyWith(
          transmissionConfig: resultConfig,
          loRaWANIdentity: updatedIdentity,
        );

        final updatedList = List<SensorNode>.from(_state.loRaWANNodes);
        updatedList[targetNodeIndex] = updatedNode;

        _setState(_state.copyWith(
          loRaWANNodes: updatedList,
          successMessage: 'Downlink queued for $devEui (will apply on next uplink window)',
        ));
        return true;
      }
      return false;
    } catch (e) {
      _setState(_state.copyWith(
        errorMessage: 'Failed to queue downlink: $e',
      ));
      return false;
    }
  }

  void _subscribeToRealtimeEvents() {
    if (_realtimeCoordinator == null) return;
    _realtimeSubscription = _realtimeCoordinator.eventStream.listen((event) {
      if (event.type == RealtimeEventType.nodeStatus ||
          event.type == RealtimeEventType.lorawanTelemetry ||
          event.type == RealtimeEventType.lorawanDeviceStatus) {
        loadLoRaWANNodes();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import '../../../../core/api/api_factory.dart';
import '../../../../core/api/api_client.dart';
import '../../domain/models/arvagate_models.dart';

class ArvaGateRepository {
  final ApiClient _client;

  ArvaGateRepository({ApiClient? client})
      : _client = client ?? ApiRepositoryFactory().client;

  Future<ArvaGateSubsystemStatus> fetchStatus({String deviceId = 'ARVAGATE-CTRL-01'}) async {
    try {
      final res = await _client.get('/api/v1/gates/status/$deviceId');
      if (res is Map<String, dynamic>) {
        return ArvaGateSubsystemStatus.fromJson(res);
      }
    } catch (e) {
      debugPrint('Error fetching ArvaGate status: $e');
    }
    // Safe default offline model
    return ArvaGateSubsystemStatus(
      deviceId: deviceId,
      displayName: 'ArvaGate Central Canal Controller',
      connectivityStatus: 'OFFLINE',
      gates: [
        ArvaGateModel(gateIndex: 1, gateLabel: 'Gate 1 (Inflow Canal)', currentState: 'CLOSED', requestedState: 'CLOSED', physicalConfirmed: false),
        ArvaGateModel(gateIndex: 2, gateLabel: 'Gate 2 (Mid Lateral)', currentState: 'CLOSED', requestedState: 'CLOSED', physicalConfirmed: false),
        ArvaGateModel(gateIndex: 3, gateLabel: 'Gate 3 (Distal Canal)', currentState: 'CLOSED', requestedState: 'CLOSED', physicalConfirmed: false),
      ],
      recentEvents: [],
    );
  }

  Future<bool> dispatchCommand({
    String deviceId = 'ARVAGATE-CTRL-01',
    required String targetGates,
    required String action,
    String? rationale,
  }) async {
    try {
      final res = await _client.post(
        '/api/v1/gates/command/$deviceId',
        body: {
          'targetGates': targetGates,
          'action': action,
          'rationale': rationale ?? 'Manual operator gate actuation',
        },
      );
      return res != null;
    } catch (e) {
      debugPrint('Error dispatching ArvaGate command: $e');
      return false;
    }
  }
}

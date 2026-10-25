import 'dart:async';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_factory.dart';
import '../../domain/models/farming_chat_models.dart';

class FarmingChatRepository {
  final ApiClient _apiClient;

  FarmingChatRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiRepositoryFactory().client;

  Future<FarmingChatState> sendMessage({
    String? sessionId,
    required String message,
    int fieldId = 1,
    String? selectedCrop,
    String? plantingMethod,
    String? intendedSchedule,
  }) async {
    final payload = <String, Object?>{
      'sessionId': sessionId,
      'message': message,
      'fieldId': fieldId,
      'selectedCrop': selectedCrop,
      'plantingMethod': plantingMethod,
      'intendedSchedule': intendedSchedule,
    };

    final response = await _apiClient.post(
      '/api/v1/farming-chat/message',
      body: payload,
    );

    if (response is Map<String, dynamic>) {
      return FarmingChatState.fromJson(response);
    }
    throw Exception('Invalid response format from farming chat endpoint');
  }

  Future<FarmingChatState> getSession(String sessionId) async {
    final response = await _apiClient.get('/api/v1/farming-chat/sessions/$sessionId');
    if (response is Map<String, dynamic>) {
      return FarmingChatState.fromJson(response);
    }
    throw Exception('Failed to retrieve farming chat session');
  }

  Future<FarmingChatState> resetSession(String sessionId, {int fieldId = 1}) async {
    final response = await _apiClient.post(
      '/api/v1/farming-chat/sessions/$sessionId/reset?fieldId=$fieldId',
    );
    if (response is Map<String, dynamic>) {
      return FarmingChatState.fromJson(response);
    }
    throw Exception('Failed to reset farming chat session');
  }

  Future<Map<String, dynamic>> confirmPlan(int planId) async {
    final response = await _apiClient.post(
      '/api/v1/farming-chat/plans/$planId/confirm',
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw Exception('Failed to confirm planting plan');
  }

  Future<FarmingChatState> toggleTask(int planId, int taskId) async {
    final response = await _apiClient.post(
      '/api/v1/farming-chat/plans/$planId/tasks/$taskId/toggle',
    );
    if (response is Map<String, dynamic>) {
      return FarmingChatState.fromJson(response);
    }
    throw Exception('Failed to update planting task');
  }
}


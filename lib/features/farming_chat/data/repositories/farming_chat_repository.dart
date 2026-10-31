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
    Map<String, dynamic>? formData,
  }) async {
    final payload = <String, Object?>{
      'sessionId': sessionId,
      'message': message,
      'fieldId': fieldId,
      'selectedCrop': selectedCrop,
      'plantingMethod': plantingMethod,
      'intendedSchedule': intendedSchedule,
      if (formData != null) 'formData': formData,
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

  Future<List<ChatSessionSummaryModel>> listSessions({
    int? fieldId,
    bool includeArchived = false,
  }) async {
    final query = StringBuffer('?includeArchived=$includeArchived');
    if (fieldId != null) {
      query.write('&fieldId=$fieldId');
    }
    final response = await _apiClient.get('/api/v1/farming-chat/sessions$query');
    if (response is List) {
      return response
          .map((item) => ChatSessionSummaryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ChatSessionSummaryModel> archiveSession(String sessionId, {bool archive = true}) async {
    final response = await _apiClient.post(
      '/api/v1/farming-chat/sessions/$sessionId/archive?archive=$archive',
    );
    if (response is Map<String, dynamic>) {
      return ChatSessionSummaryModel.fromJson(response);
    }
    throw Exception('Failed to archive session');
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

  Future<PlanDetailModel> getPlanDetails(int planId) async {
    final response = await _apiClient.get('/api/v1/farming-chat/plans/$planId');
    if (response is Map<String, dynamic>) {
      return PlanDetailModel.fromJson(response);
    }
    throw Exception('Failed to retrieve plan details');
  }

  Future<PlanDetailModel> updatePlanLifecycleStatus(
    int planId, {
    required String status,
    String? reason,
    String? completionEvidence,
  }) async {
    final payload = <String, Object?>{
      'status': status,
      if (reason != null) 'reason': reason,
      if (completionEvidence != null) 'completionEvidence': completionEvidence,
    };

    final response = await _apiClient.patch(
      '/api/v1/farming-chat/plans/$planId/status',
      body: payload,
    );

    if (response is Map<String, dynamic>) {
      return PlanDetailModel.fromJson(response);
    }
    throw Exception('Failed to update plan lifecycle status');
  }

  Future<FarmingChatState> linkPlanToSession(
    int planId,
    String sessionId, {
    String linkType = 'RESUMED',
  }) async {
    final response = await _apiClient.post(
      '/api/v1/farming-chat/plans/$planId/sessions/$sessionId/link?linkType=$linkType',
    );
    if (response is Map<String, dynamic>) {
      return FarmingChatState.fromJson(response);
    }
    throw Exception('Failed to resume and link plan to session');
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

  Future<PlanDetailModel> addTaskDependency(
    int planId,
    int taskId,
    int dependsOnTaskId, {
    String dependencyType = 'REQUIRED',
  }) async {
    final payload = <String, Object?>{
      'dependsOnTaskId': dependsOnTaskId,
      'dependencyType': dependencyType,
    };

    final response = await _apiClient.post(
      '/api/v1/farming-chat/plans/$planId/tasks/$taskId/dependencies',
      body: payload,
    );

    if (response is Map<String, dynamic>) {
      return PlanDetailModel.fromJson(response);
    }
    throw Exception('Failed to add task dependency');
  }

  Future<PlanDetailModel> removeTaskDependency(
    int planId,
    int taskId,
    int dependsOnTaskId,
  ) async {
    final response = await _apiClient.delete(
      '/api/v1/farming-chat/plans/$planId/tasks/$taskId/dependencies/$dependsOnTaskId',
    );
    if (response is Map<String, dynamic>) {
      return PlanDetailModel.fromJson(response);
    }
    throw Exception('Failed to remove task dependency');
  }
}

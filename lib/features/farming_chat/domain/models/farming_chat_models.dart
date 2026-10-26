class PlantingTaskModel {
  final int id;
  final String category;
  final String title;
  final String description;
  final String status;
  final String? blockingReason;
  final bool requiresConfirmation;

  const PlantingTaskModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    this.blockingReason,
    this.requiresConfirmation = false,
  });

  factory PlantingTaskModel.fromJson(Map<String, dynamic> json) {
    return PlantingTaskModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'FARMER_MANUAL',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      blockingReason: json['blockingReason'] as String?,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isBlocked => status == 'BLOCKED' || category == 'SAFETY_BLOCKED';
  bool get isAutomated => category == 'SYSTEM_AUTOMATED';
}

class FarmingChatState {
  final String sessionId;
  final String currentStep;
  final String replyText;
  final int? planId;
  final String? planCode;
  final int readinessScore;
  final String readinessStatus;
  final String? promptQuestion;
  final bool requiresConfirmation;
  final List<PlantingTaskModel> tasks;
  final List<String> agronomicReferences;
  final List<String> warnings;
  final String disclaimer;
  final List<String> suggestedQuestions;

  // RBAC fields from trusted backend context
  final String? userRole;
  final bool canControlIrrigation;
  final bool canManageUsers;
  final bool canViewAuditLogs;
  final List<String> authorizedCapabilities;

  const FarmingChatState({
    required this.sessionId,
    required this.currentStep,
    required this.replyText,
    this.planId,
    this.planCode,
    this.readinessScore = 0,
    this.readinessStatus = 'ASSESSING',
    this.promptQuestion,
    this.requiresConfirmation = false,
    this.tasks = const [],
    this.agronomicReferences = const [],
    this.warnings = const [],
    this.disclaimer = 'Advisory only. Physical actions require explicit confirmation.',
    this.suggestedQuestions = const [],
    this.userRole,
    this.canControlIrrigation = false,
    this.canManageUsers = false,
    this.canViewAuditLogs = false,
    this.authorizedCapabilities = const [],
  });

  factory FarmingChatState.fromJson(Map<String, dynamic> json) {
    return FarmingChatState(
      sessionId: json['sessionId'] as String? ?? '',
      currentStep: json['currentStep'] as String? ?? 'CROP_SELECTION',
      replyText: json['replyText'] as String? ?? 'What do you want to plant today?',
      planId: (json['planId'] as num?)?.toInt(),
      planCode: json['planCode'] as String?,
      readinessScore: (json['readinessScore'] as num?)?.toInt() ?? 0,
      readinessStatus: json['readinessStatus'] as String? ?? 'ASSESSING',
      promptQuestion: json['promptQuestion'] as String?,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => PlantingTaskModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
      agronomicReferences: (json['agronomicReferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      disclaimer: json['disclaimer'] as String? ??
          'Advisory only. Physical actions require explicit confirmation.',
      suggestedQuestions: (json['suggestedQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      userRole: json['userRole'] as String?,
      canControlIrrigation: json['canControlIrrigation'] as bool? ?? false,
      canManageUsers: json['canManageUsers'] as bool? ?? false,
      canViewAuditLogs: json['canViewAuditLogs'] as bool? ?? false,
      authorizedCapabilities: (json['authorizedCapabilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class ChatMessageItem {
  final String sender; // 'USER', 'ASSISTANT'
  final String text;
  final DateTime timestamp;
  final FarmingChatState? state;

  ChatMessageItem({
    required this.sender,
    required this.text,
    DateTime? timestamp,
    this.state,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => sender == 'USER';
}


class WorkflowStepModel {
  final String stepCode;
  final String name;
  final String status; // PENDING, ELIGIBLE, WAITING, IN_PROGRESS, COMPLETED, FAILED, BLOCKED, SKIPPED, INVALIDATED
  final List<String> dependsOn;
  final String? blockingReason;
  final String? skipReason;
  final bool requiresUserDecision;
  final bool isRemediation;

  const WorkflowStepModel({
    required this.stepCode,
    required this.name,
    required this.status,
    this.dependsOn = const [],
    this.blockingReason,
    this.skipReason,
    this.requiresUserDecision = false,
    this.isRemediation = false,
  });

  factory WorkflowStepModel.fromJson(Map<String, dynamic> json) {
    return WorkflowStepModel(
      stepCode: json['stepCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      dependsOn: (json['dependsOn'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      blockingReason: json['blockingReason'] as String?,
      skipReason: json['skipReason'] as String?,
      requiresUserDecision: json['requiresUserDecision'] as bool? ?? false,
      isRemediation: json['isRemediation'] as bool? ?? false,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isWaiting => status == 'WAITING' || status == 'WAITING_FOR_DECISION';
  bool get isBlocked => status == 'BLOCKED';
  bool get isFailed => status == 'FAILED';
  bool get isSkipped => status == 'SKIPPED';
  bool get isEligible => status == 'ELIGIBLE';
}

class ContextualFormFieldModel {
  final String id;
  final String label;
  final String type; // 'select', 'date', 'text', 'number'
  final String? placeholder;
  final bool required;
  final String? defaultValue;
  final List<String> options;

  const ContextualFormFieldModel({
    required this.id,
    required this.label,
    required this.type,
    this.placeholder,
    this.required = false,
    this.defaultValue,
    this.options = const [],
  });

  factory ContextualFormFieldModel.fromJson(Map<String, dynamic> json) {
    return ContextualFormFieldModel(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      placeholder: json['placeholder'] as String?,
      required: json['required'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class ContextualFormModel {
  final String formId;
  final String formType;
  final String title;
  final String description;
  final String submitButtonLabel;
  final List<ContextualFormFieldModel> fields;

  const ContextualFormModel({
    required this.formId,
    required this.formType,
    required this.title,
    required this.description,
    this.submitButtonLabel = 'Submit to Arva',
    this.fields = const [],
  });

  factory ContextualFormModel.fromJson(Map<String, dynamic> json) {
    return ContextualFormModel(
      formId: json['formId'] as String? ?? '',
      formType: json['formType'] as String? ?? 'GENERIC',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      submitButtonLabel: json['submitButtonLabel'] as String? ?? 'Submit to Arva',
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => ContextualFormFieldModel.fromJson(f as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class PlantingTaskModel {
  final int id;
  final String category;
  final String title;
  final String description;
  final String status; // PENDING, IN_PROGRESS, COMPLETED, BLOCKED, CANCELLED
  final String? blockingReason;
  final String? priority;
  final String? deadline;
  final String? evidenceSource;
  final String? completionEvidence;
  final bool requiresConfirmation;
  final List<int> dependsOnTaskIds;
  final bool isBlocked;

  const PlantingTaskModel({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    this.blockingReason,
    this.priority,
    this.deadline,
    this.evidenceSource,
    this.completionEvidence,
    this.requiresConfirmation = false,
    this.dependsOnTaskIds = const [],
    this.isBlocked = false,
  });

  factory PlantingTaskModel.fromJson(Map<String, dynamic> json) {
    return PlantingTaskModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'FARMER_MANUAL',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      blockingReason: json['blockingReason'] as String?,
      priority: json['priority'] as String?,
      deadline: json['deadline'] as String?,
      evidenceSource: json['evidenceSource'] as String?,
      completionEvidence: json['completionEvidence'] as String?,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
      dependsOnTaskIds: (json['dependsOnTaskIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }

  bool get isCompleted => status == 'COMPLETED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isAutomated => category == 'SYSTEM_AUTOMATED';
  bool get isCritical => priority == 'CRITICAL_PREREQUISITE';
}

class ChatSessionSummaryModel {
  final String sessionId;
  final String title;
  final String userId;
  final int? fieldId;
  final String currentStep;
  final String? selectedCrop;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastActivityAt;
  final int messageCount;
  final int planCount;
  final List<PlanSnippetModel> associatedPlans;

  const ChatSessionSummaryModel({
    required this.sessionId,
    required this.title,
    required this.userId,
    this.fieldId,
    required this.currentStep,
    this.selectedCrop,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
    this.messageCount = 0,
    this.planCount = 0,
    this.associatedPlans = const [],
  });

  factory ChatSessionSummaryModel.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummaryModel(
      sessionId: json['sessionId'] as String? ?? '',
      title: json['title'] as String? ?? 'Agricultural Consultation',
      userId: json['userId'] as String? ?? '',
      fieldId: (json['fieldId'] as num?)?.toInt(),
      currentStep: json['currentStep'] as String? ?? 'CROP_SELECTION',
      selectedCrop: json['selectedCrop'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      lastActivityAt: DateTime.tryParse(json['lastActivityAt'] as String? ?? '') ?? DateTime.now(),
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      planCount: (json['planCount'] as num?)?.toInt() ?? 0,
      associatedPlans: (json['associatedPlans'] as List<dynamic>?)
              ?.map((p) => PlanSnippetModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class PlanSnippetModel {
  final int planId;
  final String planCode;
  final String title;
  final String lifecycleStatus;
  final int progressPercent;

  const PlanSnippetModel({
    required this.planId,
    required this.planCode,
    required this.title,
    required this.lifecycleStatus,
    required this.progressPercent,
  });

  factory PlanSnippetModel.fromJson(Map<String, dynamic> json) {
    return PlanSnippetModel(
      planId: (json['planId'] as num?)?.toInt() ?? 0,
      planCode: json['planCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      lifecycleStatus: json['lifecycleStatus'] as String? ?? 'NOT_STARTED',
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlanDetailModel {
  final int id;
  final String planCode;
  final String title;
  final String? description;
  final String? sessionId;
  final int fieldId;
  final String cropName;
  final String? plantingMethod;
  final String? intendedSchedule;
  final String lifecycleStatus; // NOT_STARTED, IN_PROGRESS, CONTINUED, COMPLETED, CANCELLED, FAILED
  final int progressPercent;
  final String? statusReason;
  final String? completionEvidence;
  final int readinessScore;
  final String readinessStatus;
  final String? summaryText;
  final String irrigationSafetyStatus;
  final bool farmerConfirmed;
  final List<PlantingTaskModel> tasks;
  final List<String> associatedSessionIds;

  const PlanDetailModel({
    required this.id,
    required this.planCode,
    required this.title,
    this.description,
    this.sessionId,
    required this.fieldId,
    required this.cropName,
    this.plantingMethod,
    this.intendedSchedule,
    required this.lifecycleStatus,
    required this.progressPercent,
    this.statusReason,
    this.completionEvidence,
    required this.readinessScore,
    required this.readinessStatus,
    this.summaryText,
    required this.irrigationSafetyStatus,
    required this.farmerConfirmed,
    this.tasks = const [],
    this.associatedSessionIds = const [],
  });

  factory PlanDetailModel.fromJson(Map<String, dynamic> json) {
    return PlanDetailModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      planCode: json['planCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      sessionId: json['sessionId'] as String?,
      fieldId: (json['fieldId'] as num?)?.toInt() ?? 1,
      cropName: json['cropName'] as String? ?? '',
      plantingMethod: json['plantingMethod'] as String?,
      intendedSchedule: json['intendedSchedule'] as String?,
      lifecycleStatus: json['lifecycleStatus'] as String? ?? 'NOT_STARTED',
      progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
      statusReason: json['statusReason'] as String?,
      completionEvidence: json['completionEvidence'] as String?,
      readinessScore: (json['readinessScore'] as num?)?.toInt() ?? 0,
      readinessStatus: json['readinessStatus'] as String? ?? 'ASSESSING',
      summaryText: json['summaryText'] as String?,
      irrigationSafetyStatus: json['irrigationSafetyStatus'] as String? ?? 'VERIFIED_SAFE',
      farmerConfirmed: json['farmerConfirmed'] as bool? ?? false,
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => PlantingTaskModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
      associatedSessionIds: (json['associatedSessionIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  bool get isCompleted => lifecycleStatus == 'COMPLETED';
  bool get isInProgress => lifecycleStatus == 'IN_PROGRESS';
  bool get isContinued => lifecycleStatus == 'CONTINUED';
  bool get isCancelled => lifecycleStatus == 'CANCELLED';
  bool get isFailed => lifecycleStatus == 'FAILED';
}

class FarmingChatState {
  final String sessionId;
  final String currentStep;
  final String replyText;
  final int? planId;
  final String? planCode;
  final String? planTitle;
  final String planLifecycleStatus;
  final int planProgressPercent;
  final int readinessScore;
  final String readinessStatus;
  final String? promptQuestion;
  final bool requiresConfirmation;
  final List<PlantingTaskModel> tasks;
  final List<String> agronomicReferences;
  final List<String> warnings;
  final String disclaimer;
  final List<String> suggestedQuestions;
  final ContextualFormModel? contextualForm;

  // RBAC fields from trusted backend context
  final String? userRole;
  final bool canControlIrrigation;
  final bool canManageUsers;
  final bool canViewAuditLogs;
  final List<String> authorizedCapabilities;

  // 13-Step Workflow Engine & Task Lifecycle
  final String taskLifecycleStatus;
  final List<WorkflowStepModel> workflowSteps;

  const FarmingChatState({
    required this.sessionId,
    required this.currentStep,
    required this.replyText,
    this.planId,
    this.planCode,
    this.planTitle,
    this.planLifecycleStatus = 'NOT_STARTED',
    this.planProgressPercent = 0,
    this.readinessScore = 0,
    this.readinessStatus = 'ASSESSING',
    this.promptQuestion,
    this.requiresConfirmation = false,
    this.tasks = const [],
    this.agronomicReferences = const [],
    this.warnings = const [],
    this.disclaimer = 'Advisory only. Physical actions require explicit confirmation.',
    this.suggestedQuestions = const [],
    this.contextualForm,
    this.userRole,
    this.canControlIrrigation = false,
    this.canManageUsers = false,
    this.canViewAuditLogs = false,
    this.authorizedCapabilities = const [],
    this.taskLifecycleStatus = 'PENDING',
    this.workflowSteps = const [],
  });

  factory FarmingChatState.fromJson(Map<String, dynamic> json) {
    return FarmingChatState(
      sessionId: json['sessionId'] as String? ?? '',
      currentStep: json['currentStep'] as String? ?? 'CROP_SELECTION',
      replyText: json['replyText'] as String? ?? 'What do you want to plant today?',
      planId: (json['planId'] as num?)?.toInt(),
      planCode: json['planCode'] as String?,
      planTitle: json['planTitle'] as String?,
      planLifecycleStatus: json['planLifecycleStatus'] as String? ?? 'NOT_STARTED',
      planProgressPercent: (json['planProgressPercent'] as num?)?.toInt() ?? 0,
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
      contextualForm: json['contextualForm'] != null
          ? ContextualFormModel.fromJson(json['contextualForm'] as Map<String, dynamic>)
          : null,
      userRole: json['userRole'] as String?,
      canControlIrrigation: json['canControlIrrigation'] as bool? ?? false,
      canManageUsers: json['canManageUsers'] as bool? ?? false,
      canViewAuditLogs: json['canViewAuditLogs'] as bool? ?? false,
      authorizedCapabilities: (json['authorizedCapabilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      taskLifecycleStatus: json['taskLifecycleStatus'] as String? ?? 'PENDING',
      workflowSteps: (json['workflowSteps'] as List<dynamic>?)
              ?.map((w) => WorkflowStepModel.fromJson(w as Map<String, dynamic>))
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

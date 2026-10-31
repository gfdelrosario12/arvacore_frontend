import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/farming_chat/domain/models/farming_chat_models.dart';

void main() {
  group('Farming Chat Models & Lifecycle Tests', () {
    test('PlanDetailModel deserialization and lifecycle flags', () {
      final json = {
        'id': 42,
        'planCode': 'PLAN-042',
        'title': 'Lowland Rice NSIC Rc 222 Preparation',
        'description': 'Terrace AWD preparation',
        'sessionId': 'chat-sess-abc',
        'fieldId': 1,
        'cropName': 'Lowland Rice (NSIC Rc 222)',
        'lifecycleStatus': 'CONTINUED',
        'progressPercent': 60,
        'statusReason': 'Paused for rain',
        'readinessScore': 75,
        'readinessStatus': 'READY',
        'irrigationSafetyStatus': 'VERIFIED_SAFE',
        'farmerConfirmed': true,
        'tasks': [
          {
            'id': 1,
            'category': 'SYSTEM_AUTOMATED',
            'title': 'Pre-Irrigation Land Soaking',
            'description': 'Soak fields',
            'status': 'COMPLETED',
            'dependsOnTaskIds': [],
            'isBlocked': false,
          },
          {
            'id': 2,
            'category': 'FARMER_MANUAL',
            'title': 'Plowing and Harrowing',
            'description': 'Plow field',
            'status': 'PENDING',
            'dependsOnTaskIds': [1],
            'isBlocked': false,
          }
        ],
        'associatedSessionIds': ['chat-sess-abc', 'chat-sess-def'],
      };

      final plan = PlanDetailModel.fromJson(json);

      expect(plan.id, equals(42));
      expect(plan.planCode, equals('PLAN-042'));
      expect(plan.lifecycleStatus, equals('CONTINUED'));
      expect(plan.isContinued, isTrue);
      expect(plan.isCompleted, isFalse);
      expect(plan.progressPercent, equals(60));
      expect(plan.tasks.length, equals(2));
      expect(plan.tasks[0].isCompleted, isTrue);
      expect(plan.tasks[1].dependsOnTaskIds, contains(1));
      expect(plan.associatedSessionIds, contains('chat-sess-def'));
    });

    test('ChatSessionSummaryModel deserialization with plans', () {
      final json = {
        'sessionId': 'chat-sess-123',
        'title': 'Rice AWD Advice',
        'userId': 'Gladwin',
        'fieldId': 1,
        'currentStep': 'PREPARATION_ACTIVE',
        'selectedCrop': 'Lowland Rice (NSIC Rc 222)',
        'isArchived': false,
        'createdAt': '2026-10-31T10:00:00Z',
        'updatedAt': '2026-10-31T10:30:00Z',
        'lastActivityAt': '2026-10-31T10:30:00Z',
        'messageCount': 12,
        'planCount': 1,
        'associatedPlans': [
          {
            'planId': 42,
            'planCode': 'PLAN-042',
            'title': 'Lowland Rice Plan',
            'lifecycleStatus': 'IN_PROGRESS',
            'progressPercent': 50,
          }
        ],
      };

      final session = ChatSessionSummaryModel.fromJson(json);

      expect(session.sessionId, equals('chat-sess-123'));
      expect(session.title, equals('Rice AWD Advice'));
      expect(session.messageCount, equals(12));
      expect(session.planCount, equals(1));
      expect(session.associatedPlans.first.lifecycleStatus, equals('IN_PROGRESS'));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow/features/farming_chat/domain/models/farming_chat_models.dart';
import 'package:aquaflow/features/farming_chat/presentation/widgets/planting_task_checklist_widget.dart';

void main() {
  group('PlantingTaskChecklistWidget Tests', () {
    testWidgets('renders all task categories properly', (WidgetTester tester) async {
      final tasks = [
        const PlantingTaskModel(
          id: 1,
          category: 'SYSTEM_AUTOMATED',
          title: 'Pre-Irrigation Land Soaking',
          description: 'Deliver 3.0 cm water layer',
          status: 'PENDING',
          requiresConfirmation: true,
        ),
        const PlantingTaskModel(
          id: 2,
          category: 'FARMER_MANUAL',
          title: 'Plowing and Primary Harrowing',
          description: 'Break clods to 15-20 cm depth',
          status: 'PENDING',
        ),
        const PlantingTaskModel(
          id: 3,
          category: 'EQUIPMENT_INFO',
          title: 'Certified Seed Check',
          description: 'Confirm germination >85%',
          status: 'PENDING',
        ),
        const PlantingTaskModel(
          id: 4,
          category: 'SAFETY_BLOCKED',
          title: 'Clear Active Emergency Stop',
          description: 'E-Stop latch is engaged',
          status: 'BLOCKED',
          blockingReason: 'Emergency stop active on control circuit',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlantingTaskChecklistWidget(
              tasks: tasks,
              planId: 10,
              onToggleTask: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Planting Preparation Checklist'), findsOneWidget);
      expect(find.text('Pre-Irrigation Land Soaking'), findsOneWidget);
      expect(find.text('Plowing and Primary Harrowing'), findsOneWidget);
      expect(find.text('Certified Seed Check'), findsOneWidget);
      expect(find.text('Clear Active Emergency Stop'), findsOneWidget);
      expect(find.text('Blocked: Emergency stop active on control circuit'), findsOneWidget);
    });
  });
}


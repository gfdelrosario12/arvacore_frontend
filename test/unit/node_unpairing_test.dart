import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/control/domain/models/control_enums.dart';
import 'package:aquaflow_frontend/features/nodes/data/repositories/node_repository.dart';
import 'package:aquaflow_frontend/features/nodes/presentation/providers/node_management_notifier.dart';
import 'package:aquaflow_frontend/features/nodes/presentation/widgets/node_unpair_dialog.dart';

void main() {
  group('Node Unpairing Lifecycle & RBAC Tests', () {
    late MockNodeRepository repository;
    late NodeManagementNotifier notifier;

    setUp(() {
      repository = MockNodeRepository();
      notifier = NodeManagementNotifier(repository: repository);
    });

    test('MockNodeRepository unpairs active node and returns it to discovered', () async {
      final initialNodes = await repository.fetchNodes();
      expect(initialNodes.isNotEmpty, isTrue);
      final target = initialNodes.first;

      final success = await repository.unpairNode(target.id);
      expect(success, isTrue);

      final updatedNodes = await repository.fetchNodes();
      expect(updatedNodes.any((n) => n.id == target.id), isFalse);

      final discovered = await repository.fetchDiscoveredNodes();
      expect(discovered.any((d) => d.id == target.id || d.macAddress == target.macAddress), isTrue);
    });

    test('NodeManagementNotifier enforces RBAC: viewer is rejected', () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.setUserRole(ControlUserRole.viewer);

      final result = await notifier.unpairNode('NODE-01');
      expect(result, isFalse);
      expect(notifier.state.errorMessage, contains('Unauthorized: Viewers cannot unpair sensor nodes.'));
    });

    test('NodeManagementNotifier allows operator to unpair node', () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.setUserRole(ControlUserRole.operator);

      final result = await notifier.unpairNode('NODE-01');
      expect(result, isTrue);
      expect(notifier.state.nodes.any((n) => n.id == 'NODE-01'), isFalse);
      expect(notifier.state.errorMessage, isNull);
    });

    testWidgets('NodeUnpairConfirmationDialog renders consequences and confirms unpairing',
        (WidgetTester tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  NodeUnpairConfirmationDialog.show(
                    context,
                    nodeId: 'NODE-01',
                    displayName: 'Sensor Node 01',
                    onConfirm: () async {
                      confirmed = true;
                      return true;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check contents
      expect(find.text('Unpair ArvaNode'), findsOneWidget);
      expect(find.textContaining('NODE-01'), findsWidgets);
      expect(find.text('Consequences of unpairing:'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Force Unpair'), findsOneWidget);

      // Tap Force Unpair
      await tester.tap(find.text('Force Unpair'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      expect(find.text('Unpair ArvaNode'), findsNothing);
    });
  });
}


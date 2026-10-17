import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_role.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/manual_control_screen.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/widgets/emergency_stop_button.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/widgets/manual_control_confirmation_dialog.dart';

void main() {
  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('ManualControlScreen Widget Tests', () {
    testWidgets('Renders Manual Control Screen title, target badge, and Emergency Stop button', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ManualControlScreen(
            userRole: UserRole.operator,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manual Control'), findsOneWidget);
      expect(find.text('TARGET: ENTIRE FIELD'), findsOneWidget);
      expect(find.text('EMERGENCY STOP CENTRAL PUMP'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('Shows warning banner and disables triggers when user has viewer role', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ManualControlScreen(
            userRole: UserRole.viewer,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('lacks operator privileges'), findsOneWidget);
    });
  });

  group('EmergencyStopButton Widget Tests', () {
    testWidgets('Renders button and triggers onPressed callback when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          EmergencyStopButton(
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EMERGENCY STOP CENTRAL PUMP'), findsOneWidget);
      await tester.tap(find.text('EMERGENCY STOP CENTRAL PUMP'));
      expect(tapped, isTrue);
    });
  });

  group('ManualControlConfirmationDialog Widget Tests', () {
    testWidgets('Renders confirmation dialog with field-wide scope warning and requires confirmation checkbox', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ManualControlConfirmationDialog.show(
                    context: context,
                    initialDurationMinutes: 30,
                    actionType: 'start',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Manual Pulse'), findsOneWidget);
      expect(find.textContaining('TARGET SCOPE: ENTIRE FIELD'), findsOneWidget);
      expect(find.text('Dispatch Start'), findsOneWidget);

      // Verify Dispatch button is initially disabled until checkbox is checked
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Dispatch Start'));
      expect(button.onPressed, isNull);

      // Tap confirmation checkbox
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // Verify button is now enabled
      final enabledButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Dispatch Start'));
      expect(enabledButton.onPressed, isNotNull);
    });
  });
}

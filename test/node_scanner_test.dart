import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/field/presentation/field_screen.dart';
import 'package:aquaflow_frontend/features/nodes/data/repositories/node_repository.dart';
import 'package:aquaflow_frontend/features/zones/data/repositories/zone_repository.dart';

void main() {
  group('FieldScreen Node Scanner & Dynamic Zones Widget Tests', () {
    testWidgets('renders node scanner button and opens registration dialog',
        (WidgetTester tester) async {
      final zoneRepo = ZoneRepositoryImpl();
      final nodeRepo = MockNodeRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: FieldScreen(
            repository: zoneRepo,
            nodeRepository: nodeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify QR scanner icon button is present in header
      final scannerButton = find.byIcon(Icons.qr_code_scanner);
      expect(scannerButton, findsOneWidget);

      // Tap scanner button to open NodeRegistrationDialog
      await tester.tap(scannerButton);
      await tester.pumpAndSettle();

      expect(find.text('Approve & Pair Hardware Node'), findsOneWidget);
      expect(find.text('Hardware MAC Address'), findsOneWidget);
      expect(find.text('Assign to Monitoring Zone'), findsOneWidget);
    });
  });
}


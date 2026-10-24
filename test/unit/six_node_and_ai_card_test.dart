import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/home/presentation/widgets/arva_ai_advisor_card.dart';

void main() {
  group('ArvaAiAdvisorCard Tests', () {
    testWidgets('renders AI advisory card with summary and disclaimer', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ArvaAiAdvisorCard(
              summaryText: 'All 6 terraces report water depth in safe AWD drying window.',
              proposalType: 'NONE',
            ),
          ),
        ),
      );

      expect(find.text('Arva AI Advisory Companion'), findsOneWidget);
      expect(find.text('ADVISORY ONLY'), findsOneWidget);
      expect(find.text('All 6 terraces report water depth in safe AWD drying window.'), findsOneWidget);
      expect(find.textContaining('Notice: Arva AI does not directly control pumps'), findsOneWidget);
      expect(find.textContaining('AWD Action Proposal'), findsNothing);
    });

    testWidgets('renders action proposal with human review button when proposal active', (WidgetTester tester) async {
      bool reviewed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArvaAiAdvisorCard(
              summaryText: 'Pitak 6 has reached -15.0 cm.',
              proposalType: 'REFLOOD_PROPOSAL',
              targetZone: 'Pitak 6 (Tail Drain)',
              rationale: 'AWD desiccation threshold reached.',
              onReviewProposal: () {
                reviewed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('AWD Action Proposal: REFLOOD PROPOSAL'), findsOneWidget);
      expect(find.text('Target: Pitak 6 (Tail Drain)'), findsOneWidget);
      expect(find.text('Review & Authorize in Control'), findsOneWidget);

      await tester.tap(find.text('Review & Authorize in Control'));
      await tester.pump();

      expect(reviewed, isTrue);
    });
  });
}

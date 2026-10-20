import 'package:aquaflow_frontend/core/offline/offline_models.dart';
import 'package:aquaflow_frontend/core/widgets/offline_banner.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/auth_token.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_role.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_session.dart';
import 'package:aquaflow_frontend/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/manual_control_screen.dart';
import 'package:aquaflow_frontend/features/field/presentation/field_screen.dart';
import 'package:aquaflow_frontend/features/home/data/repositories/field_dashboard_repository.dart';
import 'package:aquaflow_frontend/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aquaflow_frontend/features/home/domain/models/field_dashboard_summary.dart';
import 'support/responsive.dart';

class FailingDashboardRepository implements FieldDashboardRepository {
  bool shouldFail = true;
  final _fallbackRepo = FieldDashboardRepositoryImpl();

  @override
  Future<FieldDashboardSummary> fetchDashboardSummary({MockState mockState = MockState.normal}) async {
    if (shouldFail) {
      throw Exception('Connection timeout');
    }
    return _fallbackRepo.fetchDashboardSummary(mockState: mockState);
  }
}

void main() {
  group('Responsive viewports', () {
    setUp(() {
      // Authenticate as operator to see control buttons
      final operatorToken = AuthToken(
        accessToken: 'test_access',
        refreshToken: 'test_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        fieldId: 'field_test',
        role: UserRole.operator,
      );
      final operatorSession = UserSession(
        userId: 'test_operator',
        username: 'test_operator',
        email: 'test@operator.com',
        role: 'Operator',
        token: operatorToken,
      );
      globalAuthNotifier.state = AuthState.authenticated(operatorSession);
    });

    tearDown(() {
      // Reset auth state without calling secure storage
      globalAuthNotifier.state = AuthState.unauthenticated();
    });

    for (final width in [
      360.0,
      400.0,
      600.0,
      900.0,
      1200.0,
    ]) {
      testWidgets('HomeScreen at ${width.toInt()}px has no overflow',
          (tester) async {
        await setPhoneWidth(tester, width);
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              repository: FieldDashboardRepositoryImpl(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('ManualControlScreen at ${width.toInt()}px keeps Start action',
          (tester) async {
        await setPhoneWidth(tester, width);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ManualControlScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Start'), findsOneWidget);
        expect(find.textContaining('ENTIRE FIELD'), findsWidgets);
      });

      testWidgets('FieldScreen at ${width.toInt()}px shows Q1–Q4', (tester) async {
        await setPhoneWidth(tester, width);
        await tester.pumpWidget(const MaterialApp(home: FieldScreen()));
        await tester.pumpAndSettle();

        expect(find.textContaining('Q1'), findsWidgets);
        expect(find.textContaining('Q2'), findsWidgets);
        expect(find.textContaining('Q3'), findsWidgets);
        expect(find.textContaining('Q4'), findsWidgets);
      });
    }
  });

  group('Async UI states', () {
    testWidgets('HomeScreen loading then content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: FieldDashboardRepositoryImpl()),
        ),
      );
      expect(find.textContaining('Loading'), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.textContaining('ArvaLink'), findsOneWidget);
    });

    testWidgets('HomeScreen error and recovery via retry button',
        (tester) async {
      final repo = FailingDashboardRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Telemetry Sync Error'), findsOneWidget);
      expect(find.byTooltip('Retry Telemetry Retrieval'), findsOneWidget);

      repo.shouldFail = false;
      await tester.tap(find.byTooltip('Retry Telemetry Retrieval'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ArvaLink'), findsOneWidget);
    });

    testWidgets('OfflineBanner shows offline and recovery labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(state: ConnectivityState.offline),
          ),
        ),
      );
      expect(find.textContaining('Offline'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(state: ConnectivityState.recovery),
          ),
        ),
      );
      expect(find.textContaining('Recovering'), findsOneWidget);
    });
  });
}

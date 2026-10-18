import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/settings/data/repositories/settings_repository.dart';
import 'package:aquaflow_frontend/features/settings/domain/models/settings_models.dart';
import 'package:aquaflow_frontend/features/settings/presentation/providers/settings_provider.dart';
import 'package:aquaflow_frontend/features/settings/presentation/settings_screen.dart';

void main() {
  group('Settings models and persistence', () {
    test('defaults include typed preferences and round-trip values', () {
      final defaults = SettingsSnapshot.defaults();
      final restored = defaults.withMap({
        ...defaults.toMap(),
        'appearance': 'light',
        'measurementUnit': 'imperial',
        'language': 'filipino',
      });

      expect(defaults.appearance, SettingsAppearance.system);
      expect(restored.appearance, SettingsAppearance.light);
      expect(restored.measurementUnit, MeasurementUnit.imperial);
      expect(restored.language, SettingsLanguage.filipino);
      expect(restored.notifications.systemAlerts, isTrue);
    });

    test('repository saves and loads settings asynchronously', () async {
      final repository = LocalSettingsRepository(latency: Duration.zero);
      final settings = SettingsSnapshot.defaults().copyWith(
        appearance: SettingsAppearance.dark,
      );

      await repository.save(settings);
      final loaded = await repository.load();

      expect(loaded.appearance, SettingsAppearance.dark);
    });

    test('notifier restores last valid value when save fails', () async {
      final repository = LocalSettingsRepository(
        latency: Duration.zero,
        failSave: true,
      );
      final notifier = SettingsNotifier(repository: repository);
      addTearDown(notifier.dispose);
      await notifier.load();

      await notifier.setAppearance(SettingsAppearance.light);

      expect(notifier.state.settings.appearance, SettingsAppearance.system);
      expect(notifier.state.status, SettingsLoadStatus.error);
      expect(notifier.state.errorMessage, contains('Unable to save settings'));
    });

    test('appearance updates the supplied global theme notifier', () async {
      final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
      final notifier = SettingsNotifier(
        repository: LocalSettingsRepository(latency: Duration.zero),
        themeModeNotifier: themeNotifier,
      );
      addTearDown(() {
        notifier.dispose();
        themeNotifier.dispose();
      });
      await notifier.load();

      await notifier.setAppearance(SettingsAppearance.dark);

      expect(themeNotifier.value, ThemeMode.dark);
    });
  });

  group('SettingsScreen', () {
    testWidgets('renders modular settings sections and scope guardrails', (tester) async {
      final notifier = SettingsNotifier(
        repository: LocalSettingsRepository(latency: Duration.zero),
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SettingsScreen(notifier: notifier))),
      );
      await tester.pumpAndSettle();

      expect(find.text('User & Account'), findsOneWidget);
      expect(find.text('Hardware Node Pairing & Discovery'), findsOneWidget);
      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Measurement Units'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Application Information'), findsOneWidget);
      expect(find.text('System Preferences'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.textContaining('Central Field Control'), findsOneWidget);
      expect(find.text('Q1 irrigation'), findsNothing);
      expect(find.text('Q2 irrigation'), findsNothing);
      expect(find.text('Pump action'), findsNothing);
      expect(find.text('Valve action'), findsNothing);
    });

    testWidgets('renders node pairing section and opens node registration dialog', (tester) async {
      final notifier = SettingsNotifier(
        repository: LocalSettingsRepository(latency: Duration.zero),
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SettingsScreen(notifier: notifier))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hardware Node Pairing & Discovery'), findsOneWidget);
      await tester.ensureVisible(find.text('Discover & Pair Hardware Node'));
      await tester.tap(find.text('Discover & Pair Hardware Node'));
      await tester.pumpAndSettle();

      expect(find.text('Hardware Node Discovery'), findsOneWidget);
      expect(find.text('No Nodes Requested to Pair'), findsOneWidget);
    });

    testWidgets('selects Light appearance and persists it', (tester) async {
      final notifier = SettingsNotifier(
        repository: LocalSettingsRepository(latency: Duration.zero),
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SettingsScreen(notifier: notifier))),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Light'));
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(notifier.state.settings.appearance, SettingsAppearance.light);
      expect(notifier.state.status, SettingsLoadStatus.ready);
    });

    testWidgets('shows retryable load error without discarding defaults', (tester) async {
      final notifier = SettingsNotifier(
        repository: LocalSettingsRepository(
          latency: Duration.zero,
          failLoad: true,
        ),
      );
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SettingsScreen(notifier: notifier))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Unable to load saved settings'), findsOneWidget);
      expect(find.text('User & Account'), findsOneWidget);
    });
  });
}

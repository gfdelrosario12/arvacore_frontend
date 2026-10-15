import 'package:flutter/material.dart';

enum SettingsAppearance { system, light, dark }

enum MeasurementUnit { metric, imperial }

enum SettingsLanguage { english, filipino }

enum SettingsLoadStatus { initial, loading, ready, saving, error }

class AccountSummary {
  final String username;
  final String email;
  final String role;

  const AccountSummary({
    required this.username,
    required this.email,
    required this.role,
  });
}

class NotificationPreferences {
  final bool systemAlerts;
  final bool irrigationUpdates;
  final bool staleTelemetry;

  const NotificationPreferences({
    this.systemAlerts = true,
    this.irrigationUpdates = true,
    this.staleTelemetry = true,
  });

  NotificationPreferences copyWith({
    bool? systemAlerts,
    bool? irrigationUpdates,
    bool? staleTelemetry,
  }) {
    return NotificationPreferences(
      systemAlerts: systemAlerts ?? this.systemAlerts,
      irrigationUpdates: irrigationUpdates ?? this.irrigationUpdates,
      staleTelemetry: staleTelemetry ?? this.staleTelemetry,
    );
  }
}

class ApplicationInformation {
  final String appName;
  final String version;
  final String dataSource;

  const ApplicationInformation({
    required this.appName,
    required this.version,
    required this.dataSource,
  });
}

class SystemPreferences {
  final bool use24HourTime;
  final bool confirmDestructiveActions;

  const SystemPreferences({
    this.use24HourTime = false,
    this.confirmDestructiveActions = true,
  });

  SystemPreferences copyWith({
    bool? use24HourTime,
    bool? confirmDestructiveActions,
  }) {
    return SystemPreferences(
      use24HourTime: use24HourTime ?? this.use24HourTime,
      confirmDestructiveActions:
          confirmDestructiveActions ?? this.confirmDestructiveActions,
    );
  }
}

class SettingsSnapshot {
  final AccountSummary account;
  final NotificationPreferences notifications;
  final MeasurementUnit measurementUnit;
  final SettingsAppearance appearance;
  final SettingsLanguage language;
  final ApplicationInformation application;
  final SystemPreferences system;

  const SettingsSnapshot({
    required this.account,
    this.notifications = const NotificationPreferences(),
    this.measurementUnit = MeasurementUnit.metric,
    this.appearance = SettingsAppearance.system,
    this.language = SettingsLanguage.english,
    required this.application,
    this.system = const SystemPreferences(),
  });

  static SettingsSnapshot defaults({AccountSummary? account}) {
    return SettingsSnapshot(
      account: account ??
          const AccountSummary(
            username: 'Operator',
            email: 'operator@arvacore.local',
            role: 'operator',
          ),
      application: const ApplicationInformation(
        appName: 'ArvaCore',
        version: '1.0.0+1',
        dataSource: 'ArvaCore API / Remote Telemetry',
      ),
    );
  }

  ThemeMode get themeMode {
    switch (appearance) {
      case SettingsAppearance.system:
        return ThemeMode.system;
      case SettingsAppearance.light:
        return ThemeMode.light;
      case SettingsAppearance.dark:
        return ThemeMode.dark;
    }
  }

  SettingsSnapshot copyWith({
    NotificationPreferences? notifications,
    MeasurementUnit? measurementUnit,
    SettingsAppearance? appearance,
    SettingsLanguage? language,
    SystemPreferences? system,
  }) {
    return SettingsSnapshot(
      account: account,
      notifications: notifications ?? this.notifications,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      appearance: appearance ?? this.appearance,
      language: language ?? this.language,
      application: application,
      system: system ?? this.system,
    );
  }

  Map<String, Object> toMap() {
    return {
      'measurementUnit': measurementUnit.name,
      'appearance': appearance.name,
      'language': language.name,
      'systemAlerts': notifications.systemAlerts,
      'irrigationUpdates': notifications.irrigationUpdates,
      'staleTelemetry': notifications.staleTelemetry,
      'use24HourTime': system.use24HourTime,
      'confirmDestructiveActions': system.confirmDestructiveActions,
    };
  }

  SettingsSnapshot withMap(Map<String, Object?> values) {
    return copyWith(
      measurementUnit: _enumValue(
        MeasurementUnit.values,
        values['measurementUnit'],
        measurementUnit,
      ),
      appearance: _enumValue(
        SettingsAppearance.values,
        values['appearance'],
        appearance,
      ),
      language: _enumValue(
        SettingsLanguage.values,
        values['language'],
        language,
      ),
      notifications: notifications.copyWith(
        systemAlerts: values['systemAlerts'] as bool? ?? notifications.systemAlerts,
        irrigationUpdates:
            values['irrigationUpdates'] as bool? ?? notifications.irrigationUpdates,
        staleTelemetry:
            values['staleTelemetry'] as bool? ?? notifications.staleTelemetry,
      ),
      system: system.copyWith(
        use24HourTime: values['use24HourTime'] as bool? ?? system.use24HourTime,
        confirmDestructiveActions: values['confirmDestructiveActions'] as bool? ??
            system.confirmDestructiveActions,
      ),
    );
  }

  T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) return fallback;
    return values.firstWhere(
      (value) => value.name == raw,
      orElse: () => fallback,
    );
  }
}

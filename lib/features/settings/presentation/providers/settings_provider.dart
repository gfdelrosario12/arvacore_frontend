import 'package:flutter/material.dart';
import '../../../../core/config/iot_simulation_mode.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/settings_models.dart';

class SettingsState {
  final SettingsSnapshot settings;
  final SettingsLoadStatus status;
  final String? errorMessage;

  const SettingsState({
    required this.settings,
    this.status = SettingsLoadStatus.initial,
    this.errorMessage,
  });

  bool get isBusy =>
      status == SettingsLoadStatus.loading || status == SettingsLoadStatus.saving;

  SettingsState copyWith({
    SettingsSnapshot? settings,
    SettingsLoadStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SettingsNotifier extends ChangeNotifier {
  final SettingsRepository repository;
  final ValueNotifier<ThemeMode>? themeModeNotifier;
  SettingsState _state;
  bool _isDisposed = false;

  SettingsNotifier({
    SettingsRepository? repository,
    this.themeModeNotifier,
    SettingsSnapshot? initialSettings,
  })  : repository = repository ?? LocalSettingsRepository(),
        _state = SettingsState(
          settings: initialSettings ?? SettingsSnapshot.defaults(),
        ) {
    load();
  }

  SettingsState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(
      status: SettingsLoadStatus.loading,
      clearError: true,
    );
    _notify();
    try {
      final settings = await repository.load();
      globalIotTestModeNotifier.value = settings.system.iotTestMode;
      _state = _state.copyWith(
        settings: settings,
        status: SettingsLoadStatus.ready,
        clearError: true,
      );
      _applyTheme(settings);
    } catch (error) {
      _state = _state.copyWith(
        status: SettingsLoadStatus.error,
        errorMessage: error.toString(),
      );
    }
    _notify();
  }

  Future<void> setAppearance(SettingsAppearance appearance) {
    return _persist(_state.settings.copyWith(appearance: appearance));
  }

  Future<void> setMeasurementUnit(MeasurementUnit unit) {
    return _persist(_state.settings.copyWith(measurementUnit: unit));
  }

  Future<void> setLanguage(SettingsLanguage language) {
    return _persist(_state.settings.copyWith(language: language));
  }

  Future<void> setNotifications(NotificationPreferences notifications) {
    return _persist(_state.settings.copyWith(notifications: notifications));
  }

  Future<void> setSystemPreferences(SystemPreferences system) {
    return _persist(_state.settings.copyWith(system: system));
  }

  Future<void> _persist(SettingsSnapshot next) async {
    final previous = _state.settings;
    _state = _state.copyWith(
      settings: next,
      status: SettingsLoadStatus.saving,
      clearError: true,
    );
    _notify();
    try {
      await repository.save(next);
      globalIotTestModeNotifier.value = next.system.iotTestMode;
      _state = _state.copyWith(
        status: SettingsLoadStatus.ready,
        clearError: true,
      );
      _applyTheme(next);
    } catch (error) {
      _state = _state.copyWith(
        settings: previous,
        status: SettingsLoadStatus.error,
        errorMessage: error.toString(),
      );
    }
    _notify();
  }

  void _applyTheme(SettingsSnapshot settings) {
    themeModeNotifier?.value = settings.themeMode;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

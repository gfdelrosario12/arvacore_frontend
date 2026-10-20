import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import '../../../../core/api/api_factory.dart';
import '../../data/repositories/api_diagnostics_repository.dart';
import '../../data/repositories/diagnostics_repository.dart';
import '../../domain/models/models.dart';

class DiagnosticsStateData {
  final List<DeviceDiagnostic> devices;
  final bool isLoading;
  final String? errorMessage;
  final DeviceCategory? categoryFilter;
  final DeviceDiagnostic? selectedDevice;

  const DiagnosticsStateData({
    this.devices = const [],
    this.isLoading = false,
    this.errorMessage,
    this.categoryFilter,
    this.selectedDevice,
  });

  int get totalDevices => devices.length;

  int get healthyCount =>
      devices.where((d) => d.healthStatus == DeviceHealthStatus.healthy).length;

  int get warningCount => devices
      .where((d) =>
          d.healthStatus == DeviceHealthStatus.degraded ||
          d.healthStatus == DeviceHealthStatus.stale)
      .length;

  int get errorCount => devices
      .where((d) =>
          d.healthStatus == DeviceHealthStatus.offline ||
          d.healthStatus == DeviceHealthStatus.error)
      .length;

  List<DeviceDiagnostic> get filteredDevices {
    if (categoryFilter == null) return devices;
    return devices.where((d) => d.category == categoryFilter).toList();
  }

  List<DeviceDiagnostic> get sensorNodes =>
      devices.where((d) => d.category == DeviceCategory.sensorNode).toList();

  DeviceDiagnostic? get gateway => devices
      .where((d) => d.category == DeviceCategory.gateway)
      .firstOrNull;

  DeviceDiagnostic? get centralController => devices
      .where((d) => d.category == DeviceCategory.centralController)
      .firstOrNull;

  DiagnosticsStateData copyWith({
    List<DeviceDiagnostic>? devices,
    bool? isLoading,
    String? errorMessage,
    DeviceCategory? categoryFilter,
    bool clearCategoryFilter = false,
    DeviceDiagnostic? selectedDevice,
    bool clearSelectedDevice = false,
    bool clearError = false,
  }) {
    return DiagnosticsStateData(
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      selectedDevice: clearSelectedDevice ? null : (selectedDevice ?? this.selectedDevice),
    );
  }
}

bool get _isTestEnvironment {
  if (kIsWeb) {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }
  try {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
  } catch (_) {}
  try {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  } catch (_) {
    return false;
  }
}

class DiagnosticsNotifier extends ChangeNotifier {
  final DiagnosticsRepository _repository;
  DiagnosticsStateData _state = const DiagnosticsStateData();
  StreamSubscription<List<DeviceDiagnostic>>? _subscription;
  bool _isDisposed = false;

  DiagnosticsNotifier({DiagnosticsRepository? repository})
      : _repository = repository ??
            (_isTestEnvironment
                ? MockDiagnosticsRepository()
                : ApiDiagnosticsRepository(
                    ApiRepositoryFactory().devices,
                    nodeApi: ApiRepositoryFactory().nodes,
                    irrigationApi: ApiRepositoryFactory().irrigation,
                    systemApi: ApiRepositoryFactory().system,
                  )) {
    _init();
  }

  DiagnosticsStateData get state => _state;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _init() {
    fetchDiagnostics();
    if (!_isTestEnvironment) {
      _subscription = _repository.watchDeviceDiagnostics().listen((devices) {
        _state = _state.copyWith(devices: devices);
        notifyListeners();
      });
    }
  }

  Future<void> fetchDiagnostics() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final devices = await _repository.fetchDeviceDiagnostics();
      _state = _state.copyWith(devices: devices, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch device diagnostics: $e',
      );
    }
    notifyListeners();
  }

  void setCategoryFilter(DeviceCategory? category) {
    if (category == null) {
      _state = _state.copyWith(clearCategoryFilter: true);
    } else {
      _state = _state.copyWith(categoryFilter: category);
    }
    notifyListeners();
  }

  void selectDevice(DeviceDiagnostic? device) {
    if (device == null) {
      _state = _state.copyWith(clearSelectedDevice: true);
    } else {
      _state = _state.copyWith(selectedDevice: device);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

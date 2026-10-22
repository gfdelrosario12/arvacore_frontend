import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../../core/api/api_factory.dart';
import '../../data/repositories/alert_repository.dart';
import '../../domain/models/models.dart';

class AlertStateData {
  final List<SystemAlert> alerts;
  final bool isLoading;
  final String? errorMessage;
  final AlertSeverity? severityFilter;
  final AlertCategory? categoryFilter;
  final bool unreadOnly;
  final String searchQuery;

  const AlertStateData({
    this.alerts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.severityFilter,
    this.categoryFilter,
    this.unreadOnly = false,
    this.searchQuery = '',
  });

  int get unreadCount => alerts.where((a) => !a.isRead).length;

  List<SystemAlert> get filteredAlerts {
    return alerts.where((alert) {
      if (severityFilter != null && alert.severity != severityFilter) {
        return false;
      }
      if (categoryFilter != null && alert.category != categoryFilter) {
        return false;
      }
      if (unreadOnly && alert.isRead) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchesTitle = alert.title.toLowerCase().contains(query);
        final matchesDesc = alert.description.toLowerCase().contains(query);
        final matchesSource = alert.source.name.toLowerCase().contains(query);
        if (!matchesTitle && !matchesDesc && !matchesSource) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  AlertStateData copyWith({
    List<SystemAlert>? alerts,
    bool? isLoading,
    String? errorMessage,
    AlertSeverity? severityFilter,
    bool clearSeverityFilter = false,
    AlertCategory? categoryFilter,
    bool clearCategoryFilter = false,
    bool? unreadOnly,
    String? searchQuery,
    bool clearError = false,
  }) {
    return AlertStateData(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      severityFilter: clearSeverityFilter ? null : (severityFilter ?? this.severityFilter),
      categoryFilter: clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      unreadOnly: unreadOnly ?? this.unreadOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class AlertNotifier extends ChangeNotifier with WidgetsBindingObserver {
  final AlertRepository _repository;
  final bool _enablePolling;
  AlertStateData _state = const AlertStateData();
  StreamSubscription<List<SystemAlert>>? _subscription;
  Timer? _pollTimer;
  bool _isDisposed = false;
  bool _isForeground = true;
  bool _syncInFlight = false;

  AlertNotifier({
    AlertRepository? repository,
    bool enablePolling = false,
    Duration pollInterval = const Duration(seconds: 12),
  })  : _repository = repository ??
            ApiAlertRepository(ApiRepositoryFactory().alerts),
        _enablePolling = enablePolling {
    if (_enablePolling) {
      WidgetsBinding.instance.addObserver(this);
      _pollTimer = Timer.periodic(pollInterval, (_) {
        if (_isForeground && !_isDisposed) {
          syncIncremental();
        }
      });
    }
    _init();
  }

  AlertStateData get state => _state;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      syncIncremental();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _isForeground = false;
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _init() {
    fetchAlerts();
    _subscription = _repository.watchAlerts().listen((alerts) {
      _state = _state.copyWith(alerts: alerts);
      notifyListeners();
    });
  }

  Future<void> fetchAlerts() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final alerts = await _repository.fetchAlerts();
      _state = _state.copyWith(alerts: alerts, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load system alerts: $e',
      );
    }
    notifyListeners();
  }

  Future<void> syncIncremental() async {
    if (_syncInFlight || _isDisposed) return;
    _syncInFlight = true;
    try {
      final alerts = await _repository.syncIncremental();
      _state = _state.copyWith(alerts: alerts, clearError: true);
      notifyListeners();
    } catch (_) {
    } finally {
      _syncInFlight = false;
    }
  }

  void setSeverityFilter(AlertSeverity? severity) {
    if (severity == null) {
      _state = _state.copyWith(clearSeverityFilter: true);
    } else {
      _state = _state.copyWith(severityFilter: severity);
    }
    notifyListeners();
  }

  void setCategoryFilter(AlertCategory? category) {
    if (category == null) {
      _state = _state.copyWith(clearCategoryFilter: true);
    } else {
      _state = _state.copyWith(categoryFilter: category);
    }
    notifyListeners();
  }

  void toggleUnreadFilter(bool unreadOnly) {
    _state = _state.copyWith(unreadOnly: unreadOnly);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _state = _state.copyWith(searchQuery: query);
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    final updated = _state.alerts.map((a) => a.id == id ? a.copyWith(isRead: true) : a).toList();
    _state = _state.copyWith(alerts: updated);
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    final updated = _state.alerts.map((a) => a.copyWith(isRead: true)).toList();
    _state = _state.copyWith(alerts: updated);
    notifyListeners();
  }

  Future<void> deleteAlert(String id) async {
    await _repository.deleteAlert(id);
    final updated = _state.alerts.where((a) => a.id != id).toList();
    _state = _state.copyWith(alerts: updated);
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_enablePolling) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _pollTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

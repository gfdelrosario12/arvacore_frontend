import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../../../core/realtime/realtime_events.dart';
import '../../data/repositories/telemetry_stream_repository.dart';
import '../../domain/models/telemetry_stream_event.dart';
import '../../domain/models/telemetry_stream_summary.dart';

class TelemetryStreamNotifier extends ChangeNotifier {
  final TelemetryStreamRepository _repository;
  final RealtimeCoordinator? _realtimeCoordinator;

  List<TelemetryStreamEvent> _events = [];
  final List<TelemetryStreamEvent> _pausedBuffer = [];
  TelemetryStreamSummary _summary = const TelemetryStreamSummary();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 30;

  bool _isPaused = false;
  String? _selectedNodeId;
  String? _selectedStatus;
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  List<String> _availableNodeIds = [];
  List<String> _availableStatuses = ['PROCESSED', 'PARTIALLY_PROCESSED', 'REJECTED', 'FAILED'];

  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _fallbackPollTimer;
  bool _isDisposed = false;

  TelemetryStreamNotifier({
    TelemetryStreamRepository? repository,
    RealtimeCoordinator? realtimeCoordinator,
  })  : _repository = repository ?? ApiTelemetryStreamRepository(),
        _realtimeCoordinator = realtimeCoordinator {
    _init();
  }

  List<TelemetryStreamEvent> get events => List.unmodifiable(_events);
  List<TelemetryStreamEvent> get pausedBuffer => List.unmodifiable(_pausedBuffer);
  TelemetryStreamSummary get summary => _summary;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isPaused => _isPaused;
  int get pausedCount => _pausedBuffer.length;

  String? get selectedNodeId => _selectedNodeId;
  String? get selectedStatus => _selectedStatus;
  String get searchQuery => _searchQuery;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;

  List<String> get availableNodeIds => _availableNodeIds;
  List<String> get availableStatuses => _availableStatuses;

  bool get isRealtimeConnected =>
      _realtimeCoordinator?.state.connection == RealtimeConnectionState.connected;

  RealtimeConnectionState get connectionState =>
      _realtimeCoordinator?.state.connection ?? RealtimeConnectionState.disconnected;

  Future<void> _init() async {
    await fetchFilterOptions();
    await fetchSummary();
    await fetchInitialEvents();

    if (_realtimeCoordinator != null) {
      _realtimeSubscription = _realtimeCoordinator.events.listen(_handleRealtimeEvent);
    }

    // Set up lifecycle-aware REST polling (every 4 seconds while active and not paused)
    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isLoading && !_isPaused) {
        _pollRecentEvents();
      }
    });
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (_isDisposed) return;
    if (event.type == RealtimeEventType.telemetryStream ||
        event.type == RealtimeEventType.lorawanTelemetry ||
        event.type == RealtimeEventType.measurement) {
      try {
        final Map<String, dynamic> payload = event.payload;
        // Check if payload contains TelemetryStreamEvent response
        if (payload.containsKey('eventId') || payload.containsKey('nodeId')) {
          final streamEvent = TelemetryStreamEvent.fromJson(payload);
          _incorporateIncomingEvent(streamEvent);
        }
      } catch (e) {
        debugPrint('Error parsing realtime telemetry event: $e');
      }
    }
  }

  void _incorporateIncomingEvent(TelemetryStreamEvent incoming) {
    // Avoid duplicates by eventId
    if (_events.any((e) => e.eventId == incoming.eventId) ||
        _pausedBuffer.any((e) => e.eventId == incoming.eventId)) {
      return;
    }

    // Update filter options if new node encountered
    if (!_availableNodeIds.contains(incoming.nodeId)) {
      _availableNodeIds = List.from(_availableNodeIds)..add(incoming.nodeId)..sort();
    }

    // Update summary counts
    final isFailure = incoming.status == TelemetryStreamStatus.failed ||
        incoming.status == TelemetryStreamStatus.rejected;
    _summary = _summary.copyWith(
      totalTransmissions: _summary.totalTransmissions + 1,
      recentTransmissionsCount: _summary.recentTransmissionsCount + 1,
      failedOrRejectedCount: isFailure
          ? _summary.failedOrRejectedCount + 1
          : _summary.failedOrRejectedCount,
      lastEventReceivedAt: incoming.receivedAt,
    );

    // Apply current active filters to visibility
    if (_matchesFilters(incoming)) {
      if (_isPaused) {
        _pausedBuffer.insert(0, incoming);
      } else {
        _events.insert(0, incoming);
      }
    }

    notifyListeners();
  }

  bool _matchesFilters(TelemetryStreamEvent event) {
    if (_selectedNodeId != null &&
        _selectedNodeId!.isNotEmpty &&
        event.nodeId != _selectedNodeId) {
      return false;
    }
    if (_selectedStatus != null &&
        _selectedStatus!.isNotEmpty &&
        event.rawStatus.toUpperCase() != _selectedStatus!.toUpperCase()) {
      return false;
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      final matchNode = event.nodeId.toLowerCase().contains(q);
      final matchZone = event.zoneCode?.toLowerCase().contains(q) ?? false;
      final matchMsg = event.statusMessage?.toLowerCase().contains(q) ?? false;
      final matchStatus = event.rawStatus.toLowerCase().contains(q);
      if (!matchNode && !matchZone && !matchMsg && !matchStatus) return false;
    }
    if (_fromDate != null && event.receivedAt.isBefore(_fromDate!)) return false;
    if (_toDate != null && event.receivedAt.isAfter(_toDate!)) return false;
    return true;
  }

  Future<void> fetchInitialEvents() async {
    _isLoading = true;
    _currentPage = 0;
    _hasMore = true;
    notifyListeners();

    try {
      final list = await _repository.fetchEvents(
        nodeId: _selectedNodeId,
        status: _selectedStatus,
        search: _searchQuery,
        from: _fromDate,
        to: _toDate,
        page: 0,
        size: _pageSize,
      );
      _events = list;
      _hasMore = list.length >= _pageSize;
      _pausedBuffer.clear();
    } catch (e) {
      debugPrint('Error fetching telemetry stream events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final list = await _repository.fetchEvents(
        nodeId: _selectedNodeId,
        status: _selectedStatus,
        search: _searchQuery,
        from: _fromDate,
        to: _toDate,
        page: nextPage,
        size: _pageSize,
      );

      if (list.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        // Append unique events
        final existingIds = _events.map((e) => e.eventId).toSet();
        final newItems = list.where((e) => !existingIds.contains(e.eventId)).toList();
        _events.addAll(newItems);
        _hasMore = list.length >= _pageSize;
      }
    } catch (e) {
      debugPrint('Error loading more telemetry stream events: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchSummary() async {
    try {
      final summary = await _repository.fetchSummary();
      _summary = summary;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching stream summary: $e');
    }
  }

  Future<void> fetchFilterOptions() async {
    try {
      final options = await _repository.fetchFilterOptions();
      if (options['nodeIds'] is List) {
        _availableNodeIds = List<String>.from(options['nodeIds']);
      }
      if (options['statuses'] is List) {
        _availableStatuses = List<String>.from(options['statuses']);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching stream filter options: $e');
    }
  }

  Future<void> _pollRecentEvents() async {
    try {
      final DateTime? latestTime = _events.isNotEmpty ? _events.first.receivedAt : null;
      final recent = await _repository.fetchRecentEvents(limit: 20, after: latestTime);
      for (final event in recent.reversed) {
        _incorporateIncomingEvent(event);
      }
    } catch (e) {
      debugPrint('Error polling recent events: $e');
    }
  }

  void togglePause() {
    _isPaused = !_isPaused;
    if (!_isPaused && _pausedBuffer.isNotEmpty) {
      // Flush buffered items to the top of the feed
      _events.insertAll(0, _pausedBuffer);
      _pausedBuffer.clear();
    }
    notifyListeners();
  }

  void setNodeFilter(String? nodeId) {
    if (_selectedNodeId == nodeId) return;
    _selectedNodeId = nodeId;
    fetchInitialEvents();
  }

  void setStatusFilter(String? status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    fetchInitialEvents();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    fetchInitialEvents();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _fromDate = from;
    _toDate = to;
    fetchInitialEvents();
  }

  void clearFilters() {
    _selectedNodeId = null;
    _selectedStatus = null;
    _searchQuery = '';
    _fromDate = null;
    _toDate = null;
    fetchInitialEvents();
  }

  Future<void> refresh() async {
    await fetchFilterOptions();
    await fetchSummary();
    await fetchInitialEvents();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _realtimeSubscription?.cancel();
    _fallbackPollTimer?.cancel();
    super.dispose();
  }
}


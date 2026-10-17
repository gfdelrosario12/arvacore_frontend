import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../api/api_token_store.dart';
import 'realtime_config.dart';
import 'realtime_events.dart';
import 'realtime_transport.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  degraded,
  closed,
}

typedef RealtimeEventAdapter = FutureOr<void> Function(RealtimeEvent event);
typedef RealtimeBootstrap = Future<void> Function();
typedef RealtimePoll = Future<void> Function();

class RealtimeState {
  final RealtimeConnectionState connection;
  final int reconnectAttempts;
  final DateTime? lastEventAt;
  final String? lastError;
  final bool isPollingFallback;

  const RealtimeState({
    this.connection = RealtimeConnectionState.disconnected,
    this.reconnectAttempts = 0,
    this.lastEventAt,
    this.lastError,
    this.isPollingFallback = false,
  });

  bool get isHealthy => connection == RealtimeConnectionState.connected;
  bool get isDegraded =>
      connection == RealtimeConnectionState.degraded || isPollingFallback;

  RealtimeState copyWith({
    RealtimeConnectionState? connection,
    int? reconnectAttempts,
    DateTime? lastEventAt,
    String? lastError,
    bool clearError = false,
    bool? isPollingFallback,
  }) {
    return RealtimeState(
      connection: connection ?? this.connection,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      isPollingFallback: isPollingFallback ?? this.isPollingFallback,
    );
  }
}

class RealtimeCoordinator extends ChangeNotifier with WidgetsBindingObserver {
  final RealtimeTransport transport;
  final RealtimeConfig config;
  final ApiTokenStore tokenStore;
  final RealtimeBootstrap? bootstrap;
  final RealtimePoll? poll;
  final List<RealtimeEventAdapter> _adapters;
  final _eventController = StreamController<RealtimeEvent>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  final Map<String, RealtimeEvent> _latestEvents = {};
  final Set<String> _recentEventIds = <String>{};
  final Map<String, int> _latestSequences = {};
  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<Object>? _transportErrorSubscription;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  RealtimeState _state = const RealtimeState();
  bool _isDisposed = false;
  bool _foreground = true;
  bool _startInFlight = false;
  final bool _observesLifecycle;

  RealtimeCoordinator({
    required this.transport,
    required this.tokenStore,
    RealtimeConfig? config,
    this.bootstrap,
    this.poll,
    List<RealtimeEventAdapter> adapters = const [],
    bool observeLifecycle = false,
  })  : config = config ?? RealtimeConfig.fromEnvironment(),
        _adapters = List<RealtimeEventAdapter>.from(adapters),
        _observesLifecycle = observeLifecycle {
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _messageSubscription = transport.messages.listen(_handleMessage);
    _transportErrorSubscription = transport.errors.listen(_handleTransportError);
  }

  RealtimeState get state => _state;
  Stream<RealtimeEvent> get events => _eventController.stream;
  Stream<RealtimeEvent> get eventStream => _eventController.stream;
  Stream<Object> get errors => _errorController.stream;
  Map<String, RealtimeEvent> get latestEvents => Map.unmodifiable(_latestEvents);

  void addAdapter(RealtimeEventAdapter adapter) => _adapters.add(adapter);

  Future<void> start() async {
    if (_isDisposed || _startInFlight || !_foreground) return;
    if (_state.connection == RealtimeConnectionState.connected) return;
    _startInFlight = true;
    _cancelReconnect();
    _setState(_state.copyWith(
      connection: _state.reconnectAttempts == 0
          ? RealtimeConnectionState.connecting
          : RealtimeConnectionState.reconnecting,
      clearError: true,
    ));
    try {
      await bootstrap?.call();
      final accessToken = await tokenStore.readAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw const RealtimeValidationException(
          'Cannot open realtime session without an access token.',
        );
      }
      await transport.connect(config.endpoint, accessToken: accessToken);
      await transport.subscribe(config.topics);
      _setState(_state.copyWith(
        connection: RealtimeConnectionState.connected,
        reconnectAttempts: 0,
        isPollingFallback: false,
        clearError: true,
      ));
      _stopPolling();
    } catch (error) {
      _handleFailure(error);
    } finally {
      _startInFlight = false;
    }
  }

  Future<void> stop({bool closed = true}) async {
    _cancelReconnect();
    _stopPolling();
    await transport.close();
    _setState(_state.copyWith(
      connection: closed
          ? RealtimeConnectionState.closed
          : RealtimeConnectionState.disconnected,
      isPollingFallback: false,
    ));
  }

  Future<void> logout() => stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(handleLifecycle(state));
  }

  Future<void> handleLifecycle(AppLifecycleState lifecycleState) async {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        _foreground = true;
        await start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _foreground = false;
        await stop(closed: false);
    }
  }

  void _handleMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) {
        throw const RealtimeValidationException('Realtime event must be an object.');
      }
      _acceptEvent(RealtimeEvent.fromJson(Map<String, dynamic>.from(decoded)));
    } catch (error) {
      _recordError(error);
      _setState(_state.copyWith(
        connection: RealtimeConnectionState.degraded,
        isPollingFallback: true,
      ));
      _startPolling();
    }
  }

  void _acceptEvent(RealtimeEvent event) {
    if (_recentEventIds.contains(event.eventId)) return;
    final latestSequence = _latestSequences[event.aggregateKey];
    if (event.sequence > 0 && latestSequence != null && event.sequence <= latestSequence) return;
    _recentEventIds.add(event.eventId);
    if (event.sequence > 0) {
      _latestSequences[event.aggregateKey] = event.sequence;
    }
    _latestEvents[event.aggregateKey] = event;
    while (_recentEventIds.length > config.maxRecentEventIds) {
      _recentEventIds.remove(_recentEventIds.first);
    }
    _setState(_state.copyWith(
      lastEventAt: event.occurredAt,
      clearError: true,
    ));
    _eventController.add(event);
    for (final adapter in List<RealtimeEventAdapter>.from(_adapters)) {
      try {
        final result = adapter(event);
        if (result is Future<void>) unawaited(result);
      } catch (error) {
        _recordError(error);
      }
    }
  }

  void _handleTransportError(Object error) {
    _recordError(error);
    _handleFailure(error);
  }

  void _handleFailure(Object error) {
    _setState(_state.copyWith(
      connection: _state.reconnectAttempts >= config.maxReconnectAttempts
          ? RealtimeConnectionState.degraded
          : RealtimeConnectionState.reconnecting,
      lastError: error.toString(),
      isPollingFallback: true,
    ));
    _startPolling();
    if (_foreground &&
        _state.reconnectAttempts < config.maxReconnectAttempts &&
        _reconnectTimer == null) {
      final attempt = _state.reconnectAttempts + 1;
      final exponential = config.reconnectBaseDelay * (1 << (attempt - 1));
      final delay = exponential > config.reconnectMaxDelay
          ? config.reconnectMaxDelay
          : exponential;
      _setState(_state.copyWith(reconnectAttempts: attempt));
      _reconnectTimer = Timer(delay, () {
        _reconnectTimer = null;
        unawaited(start());
      });
    }
  }

  void _startPolling() {
    if (poll == null || _pollTimer != null) return;
    _pollTimer = Timer.periodic(config.staleAfter, (_) async {
      try {
        await poll!.call();
      } catch (error) {
        _recordError(error);
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _recordError(Object error) {
    if (!_isDisposed) _errorController.add(error);
  }

  void _setState(RealtimeState state) {
    _state = state;
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_observesLifecycle) WidgetsBinding.instance.removeObserver(this);
    _cancelReconnect();
    _stopPolling();
    _messageSubscription?.cancel();
    _transportErrorSubscription?.cancel();
    _eventController.close();
    _errorController.close();
    super.dispose();
  }
}

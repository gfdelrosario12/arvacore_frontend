import 'dart:async';
import 'dart:math';

/// Centralized REST polling service for the Home Dashboard.
///
/// The ArvaLink Home Dashboard is the single consumer of this service: it owns the
/// only 5-second telemetry poll used by the dashboard, so no widget ever schedules its
/// own timer and no two widgets fetch the same telemetry independently.
///
/// Guarantees:
/// - A fixed [pollInterval] (5 seconds by default) between polling attempts.
/// - Never more than one request in flight; overlapping attempts await the running one.
/// - Bounded exponential backoff while the backend is unreachable, automatically
///   returning to the normal interval as soon as a poll succeeds again.
/// - Polling is fully stopped while the dashboard is not visible and while the
///   application is inactive, and it is cancelled on [dispose].
/// - A manual refresh ([forcePoll]) never bypasses the in-flight guard, so pulling
///   to refresh cannot stack requests on top of the periodic poll.
class DashboardPollingService {
  final Future<void> Function() fetchCallback;
  final Duration pollInterval;
  final Duration backoffBaseDelay;
  final Duration backoffMaxDelay;
  final int maxReconnectAttempts;

  Timer? _timer;
  bool _running = false;
  bool _inFlight = false;
  Future<void>? _pending;
  int _consecutiveFailures = 0;
  DateTime? _lastPollAt;
  DateTime? _lastSuccessAt;
  String? _lastError;

  DashboardPollingService({
    required this.fetchCallback,
    this.pollInterval = const Duration(seconds: 5),
    this.backoffBaseDelay = const Duration(seconds: 2),
    this.backoffMaxDelay = const Duration(seconds: 30),
    this.maxReconnectAttempts = 5,
  });

  bool get isPolling => _running;
  bool get isRequestInFlight => _inFlight;
  bool get isDegraded => _consecutiveFailures > 0;
  int get consecutiveFailures => _consecutiveFailures;
  DateTime? get lastPollAt => _lastPollAt;
  DateTime? get lastSuccessAt => _lastSuccessAt;
  String? get lastError => _lastError;

  /// Starts the periodic poll. Safe to call repeatedly; only the first call arms the timer.
  void start() {
    if (_running) return;
    _running = true;
    _schedule(const Duration(milliseconds: 300));
  }

  /// Stops polling and cancels any pending timer. In-flight requests are allowed to finish.
  void stop() {
    _running = false;
    _cancelTimer();
  }

  /// Runs a poll immediately and reschedules the next one.
  ///
  /// Never starts a second concurrent request: when a poll is already running the
  /// existing request is awaited instead.
  Future<void> forcePoll() async {
    _cancelTimer();
    await _executePoll();
    if (_running) {
      _schedule(_nextDelay());
    }
  }

  /// Cancels every pending timer and releases the service.
  void dispose() {
    stop();
  }

  Duration _nextDelay() {
    if (_consecutiveFailures == 0) {
      // Small jitter keeps several clients from hitting the backend at the same instant.
      return pollInterval + Duration(milliseconds: Random().nextInt(400));
    }
    if (_consecutiveFailures >= maxReconnectAttempts) {
      // Bounded retry budget exhausted: fall back to the slowest permitted cadence.
      return backoffMaxDelay + Duration(milliseconds: Random().nextInt(500));
    }
    final int exponent = min(_consecutiveFailures - 1, 5);
    final Duration exponential = backoffBaseDelay * (1 << exponent);
    return exponential > backoffMaxDelay ? backoffMaxDelay : exponential;
  }

  void _schedule(Duration delay) {
    _cancelTimer();
    if (!_running) return;
    _timer = Timer(delay, () async {
      if (!_running) return;
      await _executePoll();
      if (_running) {
        _schedule(_nextDelay());
      }
    });
  }

  Future<void> _executePoll() async {
    final Future<void>? running = _pending;
    if (running != null) {
      // A request is already in flight: await it instead of stacking another one.
      await running;
      return;
    }

    final Completer<void> completer = Completer<void>();
    _pending = completer.future;
    _inFlight = true;
    _lastPollAt = DateTime.now();

    try {
      await fetchCallback();
      _consecutiveFailures = 0;
      _lastSuccessAt = DateTime.now();
      _lastError = null;
    } catch (error) {
      _consecutiveFailures++;
      _lastError = error.toString();
    } finally {
      _inFlight = false;
      _pending = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

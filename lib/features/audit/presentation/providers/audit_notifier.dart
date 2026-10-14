import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/api/api_factory.dart';
import '../../../../core/api/api_services.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../../../core/realtime/realtime_events.dart';

import '../../data/repositories/account_audit_repository.dart';
import '../../domain/models/account_audit_event.dart';
import '../../domain/models/audit_category.dart';
import '../../domain/models/audit_result.dart';

class AuditFilterState {
  final AuditCategory? category;
  final AuditResult? result;
  final String actorQuery;
  final String targetQuery;
  final DateTimeRangeFilter timeRange;

  const AuditFilterState({
    this.category,
    this.result,
    this.actorQuery = '',
    this.targetQuery = '',
    this.timeRange = DateTimeRangeFilter.all,
  });

  AuditFilterState copyWith({
    AuditCategory? category,
    bool clearCategory = false,
    AuditResult? result,
    bool clearResult = false,
    String? actorQuery,
    String? targetQuery,
    DateTimeRangeFilter? timeRange,
  }) {
    return AuditFilterState(
      category: clearCategory ? null : (category ?? this.category),
      result: clearResult ? null : (result ?? this.result),
      actorQuery: actorQuery ?? this.actorQuery,
      targetQuery: targetQuery ?? this.targetQuery,
      timeRange: timeRange ?? this.timeRange,
    );
  }
}

enum DateTimeRangeFilter { all, last24h, last7d, last30d }

class AuditStateData {
  final List<AccountAuditEvent> events;
  final AccountAuditEvent? selectedEventDetail;
  final bool isLoading;
  final bool isLiveFeedActive;
  final String? errorMessage;
  final AuditFilterState filters;
  final bool hasMorePages;
  final int currentOffset;

  const AuditStateData({
    this.events = const [],
    this.selectedEventDetail,
    this.isLoading = false,
    this.isLiveFeedActive = true,
    this.errorMessage,
    this.filters = const AuditFilterState(),
    this.hasMorePages = true,
    this.currentOffset = 0,
  });

  AuditStateData copyWith({
    List<AccountAuditEvent>? events,
    AccountAuditEvent? selectedEventDetail,
    bool clearSelectedDetail = false,
    bool? isLoading,
    bool? isLiveFeedActive,
    String? errorMessage,
    bool clearErrorMessage = false,
    AuditFilterState? filters,
    bool? hasMorePages,
    int? currentOffset,
  }) {
    return AuditStateData(
      events: events ?? this.events,
      selectedEventDetail: clearSelectedDetail
          ? null
          : (selectedEventDetail ?? this.selectedEventDetail),
      isLoading: isLoading ?? this.isLoading,
      isLiveFeedActive: isLiveFeedActive ?? this.isLiveFeedActive,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      filters: filters ?? this.filters,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      currentOffset: currentOffset ?? this.currentOffset,
    );
  }
}

class AuditNotifier extends ValueNotifier<AuditStateData> {
  final AccountAuditRepository _repository;
  final RealtimeCoordinator? _realtimeCoordinator;

  AuditNotifier({
    AccountAuditRepository? repository,
    RealtimeCoordinator? realtimeCoordinator,
  })  : _repository = repository ??
            AccountAuditRepositoryImpl(
              AccountAuditApiService(ApiRepositoryFactory().client),
            ),
        _realtimeCoordinator = realtimeCoordinator,
        super(const AuditStateData()) {
    loadAuditEvents();
    subscribeToRealtime();
  }

  Future<void> loadAuditEvents({bool refresh = true}) async {
    final offset = refresh ? 0 : value.currentOffset;
    value = value.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      DateTime? from;
      final now = DateTime.now();
      switch (value.filters.timeRange) {
        case DateTimeRangeFilter.last24h:
          from = now.subtract(const Duration(hours: 24));
          break;
        case DateTimeRangeFilter.last7d:
          from = now.subtract(const Duration(days: 7));
          break;
        case DateTimeRangeFilter.last30d:
          from = now.subtract(const Duration(days: 30));
          break;
        case DateTimeRangeFilter.all:
          from = null;
          break;
      }

      final fetched = await _repository.fetchAuditEvents(
        category: value.filters.category,
        actorId: value.filters.actorQuery.isNotEmpty ? value.filters.actorQuery : null,
        targetType: value.filters.targetQuery.isNotEmpty ? value.filters.targetQuery : null,
        from: from,
        limit: 50,
        offset: offset,
      );

      var filtered = fetched;
      if (value.filters.result != null) {
        filtered = filtered.where((e) => e.result == value.filters.result).toList();
      }

      final updatedEvents = refresh ? filtered : [...value.events, ...filtered];
      value = value.copyWith(
        events: updatedEvents,
        isLoading: false,
        hasMorePages: fetched.length >= 50,
        currentOffset: offset + fetched.length,
      );
    } catch (e) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadAuditEventDetail(String eventId) async {
    try {
      final event = await _repository.fetchAuditEvent(eventId);
      value = value.copyWith(selectedEventDetail: event);
    } catch (e) {
      value = value.copyWith(errorMessage: 'Unable to load event detail: $e');
    }
  }

  void clearEventDetail() {
    value = value.copyWith(clearSelectedDetail: true);
  }

  void applyFilters(AuditFilterState newFilters) {
    value = value.copyWith(filters: newFilters);
    loadAuditEvents(refresh: true);
  }

  void toggleLiveFeed(bool enabled) {
    value = value.copyWith(isLiveFeedActive: enabled);
  }

  void subscribeToRealtime() {
    if (_realtimeCoordinator == null) return;
    _realtimeCoordinator.events.listen((envelope) {
      if (!value.isLiveFeedActive) return;
      if (envelope.type == RealtimeEventType.auditEvent) {
        try {
          final event = AccountAuditEvent.fromJson(
            Map<String, dynamic>.from(envelope.payload),
          );

          // Deduplicate by eventId
          if (value.events.any((e) => e.eventId == event.eventId)) return;

          final updated = [event, ...value.events];
          value = value.copyWith(events: updated);
        } catch (_) {}
      }
    });
  }

  String exportAuditEvents({required bool isJson}) {
    if (isJson) {
      final jsonList = value.events.map((e) => e.toJson()).toList();
      return const JsonEncoder.withIndent('  ').convert(jsonList);
    } else {
      final sb = StringBuffer();
      sb.writeln('eventId,timestamp,actorType,actorId,actorDisplayName,category,action,targetType,targetId,result,failureReason');
      for (final e in value.events) {
        sb.writeln(
          '"${e.eventId}","${e.timestamp.toIso8601String()}","${e.actor.type.name}","${e.actor.id}","${e.actor.displayName}","${e.category.name}","${e.action}","${e.target.type}","${e.target.id}","${e.result.name}","${e.metadata.failureReason ?? ''}"',
        );
      }
      return sb.toString();
    }
  }
}


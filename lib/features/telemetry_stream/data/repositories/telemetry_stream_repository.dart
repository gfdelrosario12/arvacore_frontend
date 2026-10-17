import '../../domain/models/telemetry_stream_event.dart';
import '../../domain/models/telemetry_stream_summary.dart';
import '../../../../core/api/api_factory.dart';
import '../../../../core/api/api_services.dart';

abstract class TelemetryStreamRepository {
  Future<List<TelemetryStreamEvent>> fetchEvents({
    String? nodeId,
    int? fieldId,
    String? status,
    DateTime? from,
    DateTime? to,
    String? search,
    int page = 0,
    int size = 50,
  });

  Future<List<TelemetryStreamEvent>> fetchRecentEvents({int limit = 50, DateTime? after});

  Future<TelemetryStreamSummary> fetchSummary();

  Future<Map<String, dynamic>> fetchFilterOptions();
}

class ApiTelemetryStreamRepository implements TelemetryStreamRepository {
  final TelemetryStreamApiService _apiService;

  ApiTelemetryStreamRepository([TelemetryStreamApiService? apiService])
      : _apiService = apiService ?? ApiRepositoryFactory().telemetryStream;

  @override
  Future<List<TelemetryStreamEvent>> fetchEvents({
    String? nodeId,
    int? fieldId,
    String? status,
    DateTime? from,
    DateTime? to,
    String? search,
    int page = 0,
    int size = 50,
  }) async {
    final response = await _apiService.getEvents(
      nodeId: nodeId,
      fieldId: fieldId,
      status: status,
      from: from,
      to: to,
      search: search,
      page: page,
      size: size,
    );

    if (response is Map) {
      final content = response['content'];
      if (content is List) {
        return content
            .map((item) => TelemetryStreamEvent.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } else if (response is List) {
      return response
          .map((item) => TelemetryStreamEvent.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  @override
  Future<List<TelemetryStreamEvent>> fetchRecentEvents({int limit = 50, DateTime? after}) async {
    final response = await _apiService.getRecentEvents(limit: limit, after: after);
    if (response is List) {
      return response
          .map((item) => TelemetryStreamEvent.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  @override
  Future<TelemetryStreamSummary> fetchSummary() async {
    final response = await _apiService.getSummary();
    if (response is Map) {
      return TelemetryStreamSummary.fromJson(Map<String, dynamic>.from(response));
    }
    return const TelemetryStreamSummary();
  }

  @override
  Future<Map<String, dynamic>> fetchFilterOptions() async {
    final response = await _apiService.getFilterOptions();
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {
      'nodeIds': <String>[],
      'statuses': <String>['PROCESSED', 'PARTIALLY_PROCESSED', 'REJECTED', 'FAILED'],
      'zones': <dynamic>[],
    };
  }
}


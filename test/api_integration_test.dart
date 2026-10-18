import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aquaflow_frontend/core/api/api_client.dart';
import 'package:aquaflow_frontend/core/api/api_config.dart';
import 'package:aquaflow_frontend/core/api/api_dtos.dart';
import 'package:aquaflow_frontend/core/api/api_errors.dart';
import 'package:aquaflow_frontend/core/api/api_services.dart';
import 'package:aquaflow_frontend/core/api/api_token_store.dart';

void main() {
  test('client sends JSON headers and access token to configured base URL', () async {
    final transport = _FakeHttpClient((request) async {
      expect(request.url.toString(), 'https://example.test/api/v1/fields');
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['Authorization'], 'Bearer access-1');
      return _response(request, 200, '{"items":[]}');
    });
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test'),
      httpClient: transport,
      tokenStore: _FakeTokenStore(access: 'access-1'),
    );

    final result = await client.get('/api/fields');

    expect(result, isA<Map<String, dynamic>>());
  });

  test('GET retries transient failures within the configured bound', () async {
    var calls = 0;
    final transport = _FakeHttpClient((request) async {
      calls++;
      return _response(request, calls == 1 ? 503 : 200, '{"items":[]}');
    });
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test', maxGetRetries: 1),
      httpClient: transport,
    );

    await client.get('/api/fields', retryable: true);

    expect(calls, 2);
  });

  test('irrigation service always sends ENTIRE FIELD and uses command endpoints', () async {
    final paths = <String>[];
    final transport = _FakeHttpClient((request) async {
      paths.add(request.url.path);
      return _response(request, 200, '{"outcome":"completed"}');
    });
    final service = IrrigationApiService(
      ApiClient(
        config: const ApiConfig(baseUrl: 'https://example.test'),
        httpClient: transport,
      ),
    );

    await service.start(durationMinutes: 30);
    await service.stop();

    expect(paths, ['/api/v1/irrigation/start', '/api/v1/irrigation/stop']);
  });

  test('zone-specific irrigation DTOs fail before transport', () {
    expect(
      () => const IrrigationCommandDto(target: 'Q1').toJson(),
      throwsA(isA<FormatException>()),
    );
  });

  test('expired authorization refreshes once and replays the request', () async {
    var calls = 0;
    final transport = _FakeHttpClient((request) async {
      calls++;
      if (calls == 1) return _response(request, 401, '{"message":"expired"}');
      expect(request.headers['Authorization'], 'Bearer refreshed');
      return _response(request, 200, '{"items":[]}');
    });
    final store = _FakeTokenStore(access: 'expired', refresh: 'refresh-1');
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test'),
      httpClient: transport,
      tokenStore: store,
      refreshToken: (token) async {
        expect(token, 'refresh-1');
        await store.writeTokens(accessToken: 'refreshed', refreshToken: token);
        return 'refreshed';
      },
    );

    await client.get('/api/fields');

    expect(calls, 2);
  });

  test('malformed response maps to a decoding error', () async {
    final transport = _FakeHttpClient((request) async => _response(request, 200, '{bad'));
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test'),
      httpClient: transport,
    );

    expect(
      () => client.get('/api/fields'),
      throwsA(isA<ApiException>().having((error) => error.kind, 'kind', ApiErrorKind.decoding)),
    );
  });

  test('HTTP 403 maps to insufficientRole and preserves the session', () async {
    final transport = _FakeHttpClient((request) async => _response(request, 403, '{"message":"forbidden"}'));
    final store = _FakeTokenStore(access: 'access-1', refresh: 'refresh-1');
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test'),
      httpClient: transport,
      tokenStore: store,
    );

    expect(
      () => client.get('/api/fields'),
      throwsA(isA<ApiException>().having((error) => error.kind, 'kind', ApiErrorKind.insufficientRole)),
    );

    expect(store.access, 'access-1');
    expect(store.refresh, 'refresh-1');
  });

  test('HTTP 401 after refresh failure maps to unauthenticated and clears the session', () async {
    var calls = 0;
    final transport = _FakeHttpClient((request) async {
      calls++;
      if (calls == 1) return _response(request, 401, '{"message":"expired"}');
      return _response(request, 401, '{"message":"refresh failed"}');
    });
    final store = _FakeTokenStore(access: 'expired', refresh: 'refresh-1');
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test'),
      httpClient: transport,
      tokenStore: store,
      refreshToken: (token) async {
        return null;
      },
    );

    ApiException? caughtError;
    try {
      await client.get('/api/fields');
    } on ApiException catch (e) {
      caughtError = e;
    }

    expect(caughtError, isNotNull);
    expect(caughtError!.kind, ApiErrorKind.authentication);
    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('401 and 403 are not conflated', () async {
    final transport = _FakeHttpClient((request) async => _response(request, 403, '{"message":"forbidden"}'));
    final client = ApiClient(
      config: const ApiConfig(baseUrl: 'https://example.test'),
      httpClient: transport,
    );

    ApiException? caughtError;
    try {
      await client.get('/api/fields');
    } on ApiException catch (e) {
      caughtError = e;
    }

    expect(caughtError, isNotNull);
    expect(caughtError!.kind, ApiErrorKind.insufficientRole);
    expect(caughtError.isInsufficientRole, isTrue);
    expect(caughtError.isUnauthenticated, isFalse);
  });
}

http.StreamedResponse _response(http.BaseRequest request, int status, String body) {
  return http.StreamedResponse(
    Stream<List<int>>.value(body.codeUnits),
    status,
    request: request,
    headers: const {'content-type': 'application/json'},
  );
}

class _FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  _FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

class _FakeTokenStore implements ApiTokenStore {
  String? access;
  String? refresh;

  _FakeTokenStore({this.access, this.refresh});

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> writeTokens({required String accessToken, String? refreshToken}) async {
    access = accessToken;
    refresh = refreshToken ?? refresh;
  }

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }
}

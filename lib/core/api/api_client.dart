import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../security/sensitive_data_redactor.dart';
import 'api_config.dart';
import 'api_errors.dart';
import 'api_token_store.dart';

typedef TokenRefresh = Future<String?> Function(String refreshToken);

class ApiClient {
  final ApiConfig config;
  final http.Client httpClient;
  final ApiTokenStore? tokenStore;
  final TokenRefresh? refreshToken;
  Future<String?>? _refreshInFlight;

  ApiClient({
    ApiConfig? config,
    http.Client? httpClient,
    this.tokenStore,
    this.refreshToken,
  })  : config = config ?? ApiConfig.fromEnvironment(),
        httpClient = httpClient ?? http.Client();

  Future<Object?> get(
    String path, {
    Map<String, String>? query,
    bool authorized = true,
    bool retryable = true,
  }) {
    return request(
      'GET',
      path,
      query: query,
      authorized: authorized,
      retryable: retryable,
    );
  }

  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    bool authorized = true,
    bool retryable = false,
  }) {
    return request(
      'POST',
      path,
      body: body,
      authorized: authorized,
      retryable: retryable,
    );
  }

  Future<Object?> put(
    String path, {
    Map<String, Object?>? body,
    bool authorized = true,
    bool retryable = false,
  }) {
    return request(
      'PUT',
      path,
      body: body,
      authorized: authorized,
      retryable: retryable,
    );
  }

  Future<Object?> patch(
    String path, {
    Map<String, Object?>? body,
    bool authorized = true,
    bool retryable = false,
  }) {
    return request(
      'PATCH',
      path,
      body: body,
      authorized: authorized,
      retryable: retryable,
    );
  }

  Future<Object?> delete(
    String path, {
    Map<String, String>? query,
    bool authorized = true,
    bool retryable = false,
  }) {
    return request(
      'DELETE',
      path,
      query: query,
      authorized: authorized,
      retryable: retryable,
    );
  }

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool authorized = true,
    bool retryable = false,
  }) async {
    config.ensureSecureTransport();

    final uri = _buildUri(path, query);
    final headers = await _headers(authorized);
    _diagnoseRequest(method, uri, headers, body);

    final response = await _send(
      method,
      uri,
      headers,
      body,
      retryable: retryable && method == 'GET',
    );

    if (response.statusCode == 401 && authorized && refreshToken != null) {
      final refresh = tokenStore == null
          ? null
          : await tokenStore!.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        await tokenStore?.clearTokens();
        throw const ApiException(
          kind: ApiErrorKind.authentication,
          message: 'Authentication expired and no refresh token is available.',
          statusCode: 401,
        );
      }

      final newAccessToken = await _refresh(refresh);
      if (newAccessToken == null || newAccessToken.isEmpty) {
        await tokenStore?.clearTokens();
        throw const ApiException(
          kind: ApiErrorKind.authentication,
          message: 'Unable to refresh the authentication session.',
          statusCode: 401,
        );
      }

      final replayHeaders = await _headers(authorized);
      final replay = await _send(
        method,
        uri,
        replayHeaders,
        body,
        retryable: false,
      );
      return _decodeResponse(replay);
    }

    return _decodeResponse(response);
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?>? body, {
    required bool retryable,
    bool isFallbackAttempt = false,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) request.body = jsonEncode(body);
        final streamed = await httpClient.send(request).timeout(
          config.connectTimeout + config.receiveTimeout,
        );
        final response = await http.Response.fromStream(streamed);
        if (retryable &&
            _isRetryableStatus(response.statusCode) &&
            attempt < config.maxGetRetries) {
          await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          attempt++;
          continue;
        }
        return response;
      } on TimeoutException catch (error) {
        if (!isFallbackAttempt && config.fallbackBaseUrl != null) {
          final fallbackUri = _buildFallbackUri(uri);
          if (fallbackUri != null && fallbackUri != uri) {
            debugPrint('[ApiClient] Primary API timeout ($uri). Falling back to backup localhost: $fallbackUri');
            return _send(
              method,
              fallbackUri,
              headers,
              body,
              retryable: retryable,
              isFallbackAttempt: true,
            );
          }
        }
        if (retryable && attempt < config.maxGetRetries) {
          await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          attempt++;
          continue;
        }
        throw ApiException(
          kind: ApiErrorKind.timeout,
          message: 'The API request timed out.',
          cause: error,
        );
      } on ApiException {
        rethrow;
      } catch (error) {
        if (!isFallbackAttempt && config.fallbackBaseUrl != null) {
          final fallbackUri = _buildFallbackUri(uri);
          if (fallbackUri != null && fallbackUri != uri) {
            debugPrint('[ApiClient] Primary API connectivity error ($uri). Falling back to backup localhost: $fallbackUri');
            return _send(
              method,
              fallbackUri,
              headers,
              body,
              retryable: retryable,
              isFallbackAttempt: true,
            );
          }
        }
        if (_isTlsFailure(error)) {
          throw ApiException(
            kind: ApiErrorKind.transportSecurity,
            message:
                'TLS connection to the ArvaCore API could not be established securely.',
            cause: error,
          );
        }
        if (retryable && attempt < config.maxGetRetries) {
          await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          attempt++;
          continue;
        }
        throw ApiException(
          kind: ApiErrorKind.connectivity,
          message: 'Unable to reach the ArvaCore API.',
          cause: error,
        );
      }
    }
  }

  Object? _decodeResponse(http.Response response) {
    final statusCode = response.statusCode;
    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (error) {
        throw ApiException(
          kind: ApiErrorKind.decoding,
          message: 'The API returned invalid JSON.',
          statusCode: statusCode,
          cause: error,
        );
      }
    }

    if (statusCode >= 200 && statusCode < 300) return decoded;
    throw ApiException(
      kind: _errorKind(statusCode),
      message: _errorMessage(decoded, statusCode),
      statusCode: statusCode,
    );
  }

  Future<Map<String, String>> _headers(bool authorized) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Client': 'aquasense-mobile',
    };
    if (authorized && tokenStore != null) {
      final accessToken = await tokenStore!.readAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    return headers;
  }

  Future<String?> _refresh(String refreshTokenValue) {
    return _refreshInFlight ??= refreshToken!(refreshTokenValue).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final base = Uri.parse(config.baseUrl);
    var normalizedPath = path.startsWith('/') ? path : '/$path';
    
    // Automatically bridge /api/<endpoint> to /api/v1/<endpoint> if not already v1
    if (normalizedPath.startsWith('/api/') && !normalizedPath.startsWith('/api/v1/')) {
      final sub = normalizedPath.substring(5); // after /api/
      // Map quarters to zones for backend compatibility
      if (sub.startsWith('quarters')) {
        normalizedPath = '/api/v1/zones${sub.substring(8)}';
      } else {
        normalizedPath = '/api/v1/$sub';
      }
    }

    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;

    return base.replace(
      path: '$basePath$normalizedPath',
      queryParameters: query,
    );
  }

  Uri? _buildFallbackUri(Uri primaryUri) {
    final fallbackStr = config.fallbackBaseUrl;
    if (fallbackStr == null || fallbackStr.isEmpty) return null;
    final fallbackBase = Uri.tryParse(fallbackStr);
    if (fallbackBase == null) return null;

    final base = Uri.parse(config.baseUrl);
    var relPath = primaryUri.path;
    if (relPath.startsWith(base.path)) {
      relPath = relPath.substring(base.path.length);
    }
    final normRel = relPath.startsWith('/') ? relPath : '/$relPath';
    final fallbackBasePath = fallbackBase.path.endsWith('/')
        ? fallbackBase.path.substring(0, fallbackBase.path.length - 1)
        : fallbackBase.path;

    return fallbackBase.replace(
      path: '$fallbackBasePath$normRel',
      queryParameters: primaryUri.queryParameters.isEmpty ? null : primaryUri.queryParameters,
    );
  }

  bool _isTlsFailure(Object error) {
    final name = error.runtimeType.toString();
    return name.contains('Handshake') ||
        name.contains('Tls') ||
        name.contains('Certificate') ||
        error.toString().toLowerCase().contains('certificate');
  }

  bool _isRetryableStatus(int statusCode) =>
      statusCode == 408 || statusCode == 425 || statusCode == 429 || statusCode >= 500;

  ApiErrorKind _errorKind(int statusCode) {
    if (statusCode == 401) return ApiErrorKind.authentication;
    // 403 maps to insufficientRole (session preserved, show role warning).
    // This is distinct from 401 (session cleared, redirect to login).
    if (statusCode == 403) return ApiErrorKind.insufficientRole;
    if (statusCode == 400 || statusCode == 422) return ApiErrorKind.validation;
    if (statusCode >= 500) return ApiErrorKind.server;
    return ApiErrorKind.unexpected;
  }

  String _errorMessage(Object? decoded, int statusCode) {
    if (decoded is Map<String, dynamic> && decoded['message'] is String) {
      return SensitiveDataRedactor.redactString(decoded['message'] as String);
    }
    if (statusCode == 403) {
      // Do not reveal role claim, token contents, or which permission failed.
      return 'You do not have permission to perform this action.';
    }
    if (statusCode == 401) {
      return 'Authentication is required or the session has expired.';
    }
    return 'AquaSense API request failed with status $statusCode.';
  }

  void _diagnoseRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?>? body,
  ) {
    if (!kDebugMode) return;
    final safeHeaders = SensitiveDataRedactor.redactHeaders(headers);
    final safeBody =
        body == null ? null : SensitiveDataRedactor.redactMap(body);
    debugPrint(
      SensitiveDataRedactor.redactString(
        'ApiClient $method ${uri.path} headers=$safeHeaders body=$safeBody',
      ),
    );
  }

  void close() => httpClient.close();
}

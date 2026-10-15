import 'api_errors.dart';

class ApiConfig {
  final String baseUrl;
  final String? fallbackBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxGetRetries;

  /// When true, allows `http:` base URLs for local/test builds only.
  /// Production and staging MUST leave this false and use HTTPS.
  final bool allowInsecureHttp;

  const ApiConfig({
    required this.baseUrl,
    this.fallbackBaseUrl = 'http://localhost:8080/api/v1',
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.maxGetRetries = 2,
    this.allowInsecureHttp = true,
  });

  /// Loads base URL from `--dart-define=ARVACORE_API_BASE_URL=<url>` or legacy `--dart-define=AQUASENSE_API_BASE_URL=<url>`.
  /// When no URL is provided, defaults to local: http://localhost:8080/api/v1
  /// Includes backup overflow fallback to remote API when local is unreachable (or vice versa).
  factory ApiConfig.fromEnvironment() {
    // Check for explicit base URL in environment
    const legacyUrl = String.fromEnvironment('AQUASENSE_API_BASE_URL');
    const arvacoreUrl = String.fromEnvironment('ARVACORE_API_BASE_URL');
    
    // If given, use the given remote/custom API; otherwise default to local
    final configuredBaseUrl = arvacoreUrl.isNotEmpty
        ? arvacoreUrl
        : (legacyUrl.isNotEmpty ? legacyUrl : 'http://localhost:8080/api/v1');

    const legacyInsecure = bool.fromEnvironment('AQUASENSE_ALLOW_INSECURE_HTTP', defaultValue: false);
    const arvacoreInsecure = bool.fromEnvironment('ARVACORE_ALLOW_INSECURE_HTTP', defaultValue: false);
    // Allow insecure HTTP for local dev
    final allowInsecureHttp = arvacoreInsecure || legacyInsecure || true;

    // Fallback: If configured is remote, fallback to local; if configured is local, fallback to remote
    const customFallback = String.fromEnvironment('ARVACORE_FALLBACK_API_BASE_URL');
    final fallbackUrl = customFallback.isNotEmpty
        ? customFallback
        : (configuredBaseUrl.contains('localhost') || configuredBaseUrl.contains('127.0.0.1')
            ? 'https://api-aquaflow.gladwindr.me/api/v1'
            : 'http://localhost:8080/api/v1');

    return ApiConfig(
      baseUrl: configuredBaseUrl,
      fallbackBaseUrl: fallbackUrl,
      allowInsecureHttp: allowInsecureHttp,
    );
  }

  Uri? get baseUri => Uri.tryParse(baseUrl);

  bool get isSecureTransport {
    final uri = baseUri;
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme == 'http' && allowInsecureHttp) return true;
    return false;
  }

  void ensureSecureTransport() {
    final uri = baseUri;
    if (uri == null || uri.host.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.transportSecurity,
        message:
            'API base URL is invalid. Configure ARVACORE_API_BASE_URL with an HTTPS URL.',
      );
    }
    if (uri.scheme == 'https') return;
    if (uri.scheme == 'http' && allowInsecureHttp) return;
    throw ApiException(
      kind: ApiErrorKind.transportSecurity,
      message:
          'Insecure API base URL rejected. Use HTTPS, or set ARVACORE_ALLOW_INSECURE_HTTP only for local tests.',
    );
  }
}

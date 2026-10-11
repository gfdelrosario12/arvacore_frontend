import 'api_errors.dart';

class ApiConfig {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxGetRetries;

  /// When true, allows `http:` base URLs for local/test builds only.
  /// Production and staging MUST leave this false and use HTTPS.
  final bool allowInsecureHttp;

  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.maxGetRetries = 2,
    this.allowInsecureHttp = false,
  });

  /// Loads base URL from `--dart-define=ARVACORE_API_BASE_URL=<url>` or legacy `--dart-define=AQUASENSE_API_BASE_URL=<url>`.
  /// Optional `--dart-define=ARVACORE_ALLOW_INSECURE_HTTP=true` permits HTTP for local tests.
  /// Do not embed production credentials or secrets in source; inject via dart-define only.
  factory ApiConfig.fromEnvironment() {
    const legacyUrl = String.fromEnvironment('AQUASENSE_API_BASE_URL');
    const arvacoreUrl = String.fromEnvironment('ARVACORE_API_BASE_URL');
    final configuredBaseUrl = arvacoreUrl.isNotEmpty
        ? arvacoreUrl
        : (legacyUrl.isNotEmpty ? legacyUrl : 'https://api.aquasense.local');

    const legacyInsecure = bool.fromEnvironment('AQUASENSE_ALLOW_INSECURE_HTTP', defaultValue: false);
    const arvacoreInsecure = bool.fromEnvironment('ARVACORE_ALLOW_INSECURE_HTTP', defaultValue: false);
    final allowInsecureHttp = arvacoreInsecure || legacyInsecure;

    return ApiConfig(
      baseUrl: configuredBaseUrl,
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
            'API base URL is invalid. Configure AQUASENSE_API_BASE_URL with an HTTPS URL.',
      );
    }
    if (uri.scheme == 'https') return;
    if (uri.scheme == 'http' && allowInsecureHttp) return;
    throw ApiException(
      kind: ApiErrorKind.transportSecurity,
      message:
          'Insecure API base URL rejected. Use HTTPS, or set AQUASENSE_ALLOW_INSECURE_HTTP only for local tests.',
    );
  }
}

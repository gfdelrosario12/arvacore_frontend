import 'api_client.dart';
import 'api_config.dart';
import 'api_repositories.dart';
import 'api_services.dart';
import 'api_token_store.dart';

class ApiRepositoryFactory {
  static ApiRepositoryFactory? _instance;
  static final ApiTokenStore _sharedTokenStore = SecureApiTokenStore();

  static ApiTokenStore get sharedTokenStore => _sharedTokenStore;

  final ApiClient client;
  late final AuthApiService auth;
  late final FieldApiService fields;
  late final AnalyticsApiService analytics;
  late final AlertApiService alerts;
  late final DeviceApiService devices;
  late final NodeApiService nodes;
  late final IrrigationApiService irrigation;
  late final LoRaWANApiService lorawan;
  late final SystemApiService system;
  late final EvaluationApiService evaluation;
  late final TelemetryStreamApiService telemetryStream;

  factory ApiRepositoryFactory({
    ApiConfig? config,
    ApiClient? client,
    ApiTokenStore? tokenStore,
  }) {
    if (config == null && client == null && tokenStore == null) {
      return _instance ??= ApiRepositoryFactory._internal();
    }
    return ApiRepositoryFactory._internal(
      config: config,
      client: client,
      tokenStore: tokenStore,
    );
  }

  ApiRepositoryFactory._internal({
    ApiConfig? config,
    ApiClient? client,
    ApiTokenStore? tokenStore,
  }) : client = client ??
            ApiClient(
              config: config,
              tokenStore: tokenStore ?? _sharedTokenStore,
            ) {
    auth = AuthApiService(this.client);
    fields = FieldApiService(this.client);
    analytics = AnalyticsApiService(this.client);
    alerts = AlertApiService(this.client);
    devices = DeviceApiService(this.client);
    nodes = NodeApiService(this.client);
    irrigation = IrrigationApiService(this.client);
    lorawan = LoRaWANApiService(this.client);
    system = SystemApiService(this.client);
    evaluation = EvaluationApiService(this.client);
    telemetryStream = TelemetryStreamApiService(this.client);
  }

  ApiResourceRepositories get resources => ApiResourceRepositories(
        fields: fields,
        analytics: analytics,
        alerts: alerts,
        devices: devices,
        nodes: nodes,
        irrigation: irrigation,
      );

  void close() => client.close();
}

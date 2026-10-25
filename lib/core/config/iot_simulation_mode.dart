import 'package:flutter/foundation.dart';

/// Global notifier for IoT Workflow Simulation Mode.
/// When true:
/// 1. Frontend & backend validate requests and authorization identically to production.
/// 2. Command preparation passes.
/// 3. Physical hardware downlinks (LoRaWAN/MQTT/relays) are completely bypassed.
/// 4. Simulated device acknowledgments are returned.
/// 5. Shows confirmation: "Workflow Test Passed — Irrigation activation was processed successfully in simulation mode. No physical device was activated."
/// 6. Records events as [SIMULATION] audit entries, keeping real production records untouched.
final ValueNotifier<bool> globalIotTestModeNotifier = ValueNotifier<bool>(false);


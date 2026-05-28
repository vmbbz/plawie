import 'native_bridge.dart';

/// Runtime boundary for the OpenClaw Gateway process.
///
/// Phase 1 keeps the production implementation on PRoot while giving
/// GatewayService a stable seam for future native Node experiments.
abstract interface class GatewayRuntime {
  String get id;
  String get label;
  Stream<String> get logStream;

  Future<bool> start({bool allowDuringSetup = false});
  Future<bool> stop();
  Future<bool> isRunning();
  Future<String> getLogs();
}

class ProotGatewayRuntime implements GatewayRuntime {
  const ProotGatewayRuntime();

  @override
  String get id => 'proot';

  @override
  String get label => 'PRoot Gateway Runtime';

  @override
  Stream<String> get logStream => NativeBridge.gatewayLogStream;

  @override
  Future<bool> start({bool allowDuringSetup = false}) {
    return NativeBridge.startGateway(allowDuringSetup: allowDuringSetup);
  }

  @override
  Future<bool> stop() {
    return NativeBridge.stopGateway();
  }

  @override
  Future<bool> isRunning() {
    return NativeBridge.isGatewayRunning();
  }

  @override
  Future<String> getLogs() {
    return NativeBridge.getGatewayLogs();
  }
}

class GatewayRuntimeRegistry {
  GatewayRuntimeRegistry._();

  static final GatewayRuntime current = const ProotGatewayRuntime();
}

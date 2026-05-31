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

class NativeNodeGatewayRuntime implements GatewayRuntime {
  const NativeNodeGatewayRuntime();

  @override
  String get id => 'native-node-smoke';

  @override
  String get label => 'Native Node Gateway Smoke Runtime';

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Future<bool> start({bool allowDuringSetup = false}) {
    return NativeBridge.startNativeGatewaySmokeRuntime();
  }

  @override
  Future<bool> stop() {
    return NativeBridge.stopNativeGatewaySmokeRuntime();
  }

  @override
  Future<bool> isRunning() {
    return NativeBridge.isNativeGatewaySmokeRuntimeRunning();
  }

  @override
  Future<String> getLogs() {
    return NativeBridge.getNativeGatewaySmokeRuntimeLogs();
  }
}

class NativeNodeProcessGatewayRuntime implements GatewayRuntime {
  const NativeNodeProcessGatewayRuntime();

  @override
  String get id => 'native-node-embedded-smoke';

  @override
  String get label => 'Embedded Native Node Smoke Runtime';

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Future<bool> start({bool allowDuringSetup = false}) {
    return NativeBridge.startNativeNodeSmokeRuntime();
  }

  @override
  Future<bool> stop() {
    return NativeBridge.stopNativeNodeSmokeRuntime();
  }

  @override
  Future<bool> isRunning() {
    return NativeBridge.isNativeNodeSmokeRuntimeRunning();
  }

  @override
  Future<String> getLogs() {
    return NativeBridge.getNativeNodeSmokeRuntimeLogs();
  }
}

class NativeNodeProductionPortCanaryRuntime implements GatewayRuntime {
  const NativeNodeProductionPortCanaryRuntime();

  @override
  String get id => 'native-node-production-port-canary';

  @override
  String get label => 'Embedded Native Node Production-Port Canary Runtime';

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Future<bool> start({bool allowDuringSetup = false}) {
    return NativeBridge.startNativeNodeProductionPortCanaryRuntime();
  }

  @override
  Future<bool> stop() {
    return NativeBridge.stopNativeNodeSmokeRuntime();
  }

  @override
  Future<bool> isRunning() {
    return NativeBridge.isNativeNodeProductionPortCanaryRuntimeRunning();
  }

  @override
  Future<String> getLogs() {
    return NativeBridge.getNativeNodeSmokeRuntimeLogs();
  }
}

class GatewayRuntimeRegistry {
  GatewayRuntimeRegistry._();

  static final GatewayRuntime current = const ProotGatewayRuntime();
  static final GatewayRuntime nativeNodeSmoke =
      const NativeNodeGatewayRuntime();
  static final GatewayRuntime nativeNodeProcessSmoke =
      const NativeNodeProcessGatewayRuntime();
  static final GatewayRuntime nativeNodeProductionPortCanary =
      const NativeNodeProductionPortCanaryRuntime();
}

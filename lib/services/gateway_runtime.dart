import 'dart:async';

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
  Stream<String> get logStream => _pollNativeGatewayLogs(getLogs);

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
  Stream<String> get logStream => _pollNativeGatewayLogs(getLogs);

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
  Stream<String> get logStream => _pollNativeGatewayLogs(getLogs);

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

class NativeNodeFullGatewayBootstrapRuntime implements GatewayRuntime {
  const NativeNodeFullGatewayBootstrapRuntime();

  @override
  String get id => 'native-node-full-gateway-bootstrap';

  @override
  String get label => 'Embedded Native Node Full Gateway Bootstrap Runtime';

  @override
  Stream<String> get logStream => _pollNativeGatewayLogs(getLogs);

  @override
  Future<bool> start({bool allowDuringSetup = false}) {
    return NativeBridge.startNativeNodeFullGatewayBootstrapRuntime();
  }

  @override
  Future<bool> stop() {
    return NativeBridge.stopNativeNodeSmokeRuntime();
  }

  @override
  Future<bool> isRunning() {
    return NativeBridge.isNativeNodeFullGatewayBootstrapRuntimeRunning();
  }

  @override
  Future<String> getLogs() {
    return NativeBridge.getNativeNodeSmokeRuntimeLogs();
  }
}

class NativeNodeFullGatewayProductionRuntime implements GatewayRuntime {
  const NativeNodeFullGatewayProductionRuntime();

  @override
  String get id => 'native-node-full-gateway-production';

  @override
  String get label => 'Embedded Native Node Full Gateway Production Runtime';

  @override
  Stream<String> get logStream => _pollNativeGatewayLogs(getLogs);

  @override
  Future<bool> start({bool allowDuringSetup = false}) {
    return NativeBridge.startNativeNodeFullGatewayProductionRuntime();
  }

  @override
  Future<bool> stop() {
    return NativeBridge.stopNativeNodeSmokeRuntime();
  }

  @override
  Future<bool> isRunning() {
    return NativeBridge.isNativeNodeFullGatewayProductionRuntimeRunning();
  }

  @override
  Future<String> getLogs() {
    return NativeBridge.getNativeNodeSmokeRuntimeLogs();
  }
}

const _nativeLogPollInterval = Duration(seconds: 2);
const _nativeLogPollTimeout = Duration(seconds: 3);
const _nativeInitialLogReplayLimit = 80;

Stream<String> _pollNativeGatewayLogs(
  Future<String> Function() readLogs,
) async* {
  var previousLog = '';

  while (true) {
    try {
      final currentLog =
          (await readLogs().timeout(_nativeLogPollTimeout)).trimRight();
      if (currentLog.isNotEmpty && currentLog != previousLog) {
        final rotated =
            previousLog.isNotEmpty && !currentLog.startsWith(previousLog);
        final chunk = previousLog.isEmpty || rotated
            ? currentLog
            : currentLog.substring(previousLog.length).trimLeft();

        if (rotated) {
          yield '[native] log stream resumed after rotation or runtime restart';
        }

        final lines = chunk
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trimRight())
            .where((line) => line.isNotEmpty)
            .toList();
        final replayLines = (previousLog.isEmpty || rotated) &&
                lines.length > _nativeInitialLogReplayLimit
            ? lines.sublist(lines.length - _nativeInitialLogReplayLimit)
            : lines;

        for (final line in replayLines) {
          final nativeTagged =
              line.startsWith('[native') ? line : '[native] $line';
          yield _redactGatewayLogLine(nativeTagged);
        }

        previousLog = currentLog;
      }
    } catch (error) {
      yield '[native] log poll failed: ${error.runtimeType}';
    }

    await Future<void>.delayed(_nativeLogPollInterval);
  }
}

String _redactGatewayLogLine(String line) {
  var redacted = line;
  redacted = redacted.replaceAllMapped(
    RegExp(r'(Authorization:\s*Bearer\s+)[^\s]+', caseSensitive: false),
    (match) => '${match.group(1)}<redacted>',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'((?:api[_-]?key|apikey)["=:\s]+)[^,\s"}]+', caseSensitive: false),
    (match) => '${match.group(1)}<redacted>',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'(\btoken=)[^&\s]+', caseSensitive: false),
    (match) => '${match.group(1)}<redacted>',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'\b((?:sk-or|sk-proj|sk)-)[A-Za-z0-9_\-]{8,}\b'),
    (match) => '${match.group(1)}<redacted>',
  );
  return redacted;
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
  static final GatewayRuntime nativeNodeFullGatewayBootstrap =
      const NativeNodeFullGatewayBootstrapRuntime();
  static final GatewayRuntime nativeNodeFullGatewayProduction =
      const NativeNodeFullGatewayProductionRuntime();

  static GatewayRuntime runtimeForId(String? id) {
    switch (id) {
      case 'native-node-full-gateway-production':
        return nativeNodeFullGatewayProduction;
      case 'native-node-full-gateway-bootstrap':
        return nativeNodeFullGatewayBootstrap;
      case 'native-node-production-port-canary':
        return nativeNodeProductionPortCanary;
      case 'native-node-embedded-smoke':
        return nativeNodeProcessSmoke;
      case 'native-node-smoke':
        return nativeNodeSmoke;
      case 'proot':
      case null:
      case '':
        return current;
      default:
        return current;
    }
  }
}

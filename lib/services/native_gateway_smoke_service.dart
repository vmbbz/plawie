import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'gateway_runtime.dart';

class NativeGatewaySmokeReport {
  final bool passed;
  final bool skipped;
  final String message;
  final Map<String, dynamic>? health;

  const NativeGatewaySmokeReport({
    required this.passed,
    required this.message,
    this.skipped = false,
    this.health,
  });
}

/// Hidden Phase 2 diagnostics for the native Gateway runtime track.
///
/// Enable with:
/// `--dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`
///
/// This never touches the production Gateway port and never routes chat.
class NativeGatewaySmokeService {
  NativeGatewaySmokeService._();

  static const bool diagnosticsEnabled = bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS',
    defaultValue: false,
  );

  static final GatewayRuntime _runtime = GatewayRuntimeRegistry.nativeNodeSmoke;
  static final GatewayRuntime _nodeRuntime =
      GatewayRuntimeRegistry.nativeNodeProcessSmoke;

  static Future<void> runStartupSelfTestIfEnabled({
    required void Function(String message) log,
  }) async {
    if (!diagnosticsEnabled) return;

    log('[NATIVE-SMOKE] Diagnostics enabled; testing isolated native runtime.');
    final first = await runLifecycleSmokeTest(log: log, label: 'first');
    final second = await runLifecycleSmokeTest(log: log, label: 'restart');
    final node = await runNativeNodeProcessSmokeTest(log: log);

    if (first.passed && second.passed && node.passed) {
      log('[NATIVE-SMOKE] Native smoke runtime and embedded Node diagnostics passed.');
    } else if (first.passed && second.passed && node.skipped) {
      log('[NATIVE-SMOKE] Native Android smoke passed; embedded Node skipped: ${node.message}');
    } else if (first.passed && second.passed) {
      log('[NATIVE-SMOKE] Native Android smoke passed; embedded Node failed: ${node.message}');
    } else {
      log('[NATIVE-SMOKE] Native smoke runtime diagnostics failed: '
          '${first.message}; ${second.message}; ${node.message}');
    }
  }

  static Future<NativeGatewaySmokeReport> runNativeNodeProcessSmokeTest({
    required void Function(String message) log,
  }) async {
    try {
      await _nodeRuntime.stop();
      final started = await _nodeRuntime.start();
      if (!started) {
        final logs = await _nodeRuntime.getLogs();
        final missing = logs.contains('embedded libnode.so is not packaged') ||
            logs.contains('embedded Node bridge is not packaged');
        return NativeGatewaySmokeReport(
          passed: false,
          skipped: missing,
          message: missing
              ? 'embedded libnode.so or bridge is not packaged yet'
              : 'embedded native Node did not start',
        );
      }

      final health =
          await _probeHealth(expectedRuntime: 'native-node-embedded');
      final ok = health['ok'] == true &&
          health['runtime'] == 'native-node-embedded' &&
          health['port'] == AppConstants.nativeGatewaySmokePort &&
          health['productionGatewayPort'] == AppConstants.gatewayPort &&
          health['openclawStarted'] == false &&
          _preflightPassed(health['preflight']);
      log('[NATIVE-NODE-EMBEDDED] health: ${jsonEncode(health)}');

      final stopped = await _nodeRuntime.stop();
      final stillRunning = await _nodeRuntime.isRunning();
      if (!stopped || stillRunning) {
        return NativeGatewaySmokeReport(
          passed: false,
          message: 'embedded native Node did not stop cleanly',
          health: health,
        );
      }

      return NativeGatewaySmokeReport(
        passed: ok,
        message: ok ? 'ok' : 'unexpected embedded native Node health payload',
        health: health,
      );
    } catch (e) {
      unawaited(_nodeRuntime.stop());
      return NativeGatewaySmokeReport(
        passed: false,
        message: e.toString(),
      );
    }
  }

  static Future<NativeGatewaySmokeReport> runLifecycleSmokeTest({
    required void Function(String message) log,
    String label = 'manual',
  }) async {
    try {
      await _runtime.stop();
      final started = await _runtime.start();
      if (!started) {
        return const NativeGatewaySmokeReport(
          passed: false,
          message: 'native smoke runtime did not start',
        );
      }

      final health = await _probeHealth(
        expectedRuntime: 'native-gateway-smoke',
      );
      final ok = health['ok'] == true &&
          health['runtime'] == 'native-gateway-smoke' &&
          health['port'] == AppConstants.nativeGatewaySmokePort &&
          health['productionGatewayPort'] == AppConstants.gatewayPort &&
          health['openclawStarted'] == false;
      log('[NATIVE-SMOKE] $label health: ${jsonEncode(health)}');

      final stopped = await _runtime.stop();
      final stillRunning = await _runtime.isRunning();
      if (!stopped || stillRunning) {
        return NativeGatewaySmokeReport(
          passed: false,
          message: 'native smoke runtime did not stop cleanly',
          health: health,
        );
      }

      return NativeGatewaySmokeReport(
        passed: ok,
        message: ok ? 'ok' : 'unexpected health payload',
        health: health,
      );
    } catch (e) {
      unawaited(_runtime.stop());
      return NativeGatewaySmokeReport(
        passed: false,
        message: e.toString(),
      );
    }
  }

  static bool _preflightPassed(Object? value) {
    if (value is! Map<String, dynamic>) return false;

    final builtins = value['builtinModules'];
    final builtinsOk = builtins is Map<String, dynamic> &&
        builtins.values.every((entry) => entry == true);

    final bridgeTools = value['bridgeToolNames'];
    final bridgeToolsOk = bridgeTools is List &&
        bridgeTools.contains('get_battery') &&
        bridgeTools.contains('read_sensor') &&
        bridgeTools.contains('vibrate');

    final skillCount = value['skillCount'];
    return value['passed'] == true &&
        value['engineOk'] == true &&
        value['nodeModulesTarAssetPresent'] == true &&
        value['openclawStarted'] == false &&
        skillCount is num &&
        skillCount >= 4 &&
        value['bridgeToolsLoaded'] == true &&
        value['intlOk'] == true &&
        builtinsOk &&
        bridgeToolsOk;
  }

  static Future<Map<String, dynamic>> _probeHealth({
    required String expectedRuntime,
  }) async {
    final client = http.Client();
    try {
      Object? lastError;
      for (var attempt = 0; attempt < 12; attempt++) {
        try {
          final response = await client
              .get(Uri.parse('${AppConstants.nativeGatewaySmokeUrl}/health'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode != 200) {
            throw StateError('HTTP ${response.statusCode}: ${response.body}');
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw StateError('Health payload was not a JSON object');
          }
          if (decoded['runtime'] != expectedRuntime) {
            throw StateError(
              'Expected $expectedRuntime health, got ${decoded['runtime']}',
            );
          }
          return decoded;
        } catch (e) {
          lastError = e;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      throw StateError('Health probe failed: $lastError');
    } finally {
      client.close();
    }
  }
}

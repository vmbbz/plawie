import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'gateway_runtime.dart';

class NativeGatewaySmokeReport {
  final bool passed;
  final String message;
  final Map<String, dynamic>? health;

  const NativeGatewaySmokeReport({
    required this.passed,
    required this.message,
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

  static Future<void> runStartupSelfTestIfEnabled({
    required void Function(String message) log,
  }) async {
    if (!diagnosticsEnabled) return;

    log('[NATIVE-SMOKE] Diagnostics enabled; testing isolated native runtime.');
    final first = await runLifecycleSmokeTest(log: log, label: 'first');
    final second = await runLifecycleSmokeTest(log: log, label: 'restart');

    if (first.passed && second.passed) {
      log('[NATIVE-SMOKE] Native smoke runtime start/health/stop/restart passed.');
    } else {
      log('[NATIVE-SMOKE] Native smoke runtime diagnostics failed: '
          '${first.message}; ${second.message}');
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

      final health = await _probeHealth();
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

  static Future<Map<String, dynamic>> _probeHealth() async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse('${AppConstants.nativeGatewaySmokeUrl}/health'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}: ${response.body}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Health payload was not a JSON object');
      }
      return decoded;
    } finally {
      client.close();
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'gateway_runtime.dart';
import 'native_gateway_shadow_parity_service.dart';

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
/// Most canaries stay off the production Gateway port. The production-port
/// bind canary is explicit, stops PRoot first, keeps native routing disabled,
/// and rolls back to PRoot before returning.
class NativeGatewaySmokeService {
  NativeGatewaySmokeService._();

  static const bool diagnosticsEnabled = bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS',
    defaultValue: false,
  );

  static final GatewayRuntime _runtime = GatewayRuntimeRegistry.nativeNodeSmoke;
  static final GatewayRuntime _nodeRuntime =
      GatewayRuntimeRegistry.nativeNodeProcessSmoke;
  static final GatewayRuntime _productionPortRuntime =
      GatewayRuntimeRegistry.nativeNodeProductionPortCanary;
  static bool _startupSelfTestInFlight = false;
  static bool _canaryComparisonInFlight = false;
  static bool _productionPortBindInFlight = false;
  static bool _canaryComparisonPassed = false;
  static DateTime? _lastCanaryComparisonAttemptAt;
  static const Duration _canaryComparisonRetryCooldown = Duration(seconds: 30);

  static Future<void> runStartupSelfTestIfEnabled({
    required void Function(String message) log,
  }) async {
    if (!diagnosticsEnabled) return;
    if (_startupSelfTestInFlight) return;

    _startupSelfTestInFlight = true;
    try {
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
    } finally {
      _startupSelfTestInFlight = false;
    }
  }

  static Future<void> runCanaryComparisonIfEnabled({
    required void Function(String message) log,
    Map<String, dynamic>? productionHealth,
  }) async {
    if (!diagnosticsEnabled) return;
    if (_startupSelfTestInFlight ||
        _canaryComparisonInFlight ||
        _canaryComparisonPassed) {
      return;
    }
    final now = DateTime.now();
    final last = _lastCanaryComparisonAttemptAt;
    if (last != null && now.difference(last) < _canaryComparisonRetryCooldown) {
      return;
    }

    _canaryComparisonInFlight = true;
    _lastCanaryComparisonAttemptAt = now;
    try {
      if (!await _nodeRuntime.isRunning()) {
        final started = await _nodeRuntime.start();
        if (!started) {
          log('[NATIVE-CANARY] native 18790 did not start; PRoot remains primary.');
          return;
        }
      }

      final nativeHealth =
          await _probeHealth(expectedRuntime: 'native-node-embedded');
      final nativeProbe = await _probeJson('/gateway/probe');
      final dryRun = await _postJson(
        '/gateway/chat-send-dry-run',
        _sampleGatewayWsChatSendFrame(
          requestId: 'probe-canary-shadow-request',
          idempotencyKey: 'probe-canary-shadow-idempotency',
        ),
        expectedStatus: 202,
      );
      final directCanary = await _postJson(
        '/gateway/chat-send-canary',
        _sampleGatewayWsChatSendFrame(
          requestId: 'probe-direct-canary-request',
          idempotencyKey: 'probe-direct-canary-idempotency',
        ),
        expectedStatus: 202,
      );

      final dryRunAck = dryRun['ack'] is Map
          ? Map<String, dynamic>.from(dryRun['ack'] as Map)
          : <String, dynamic>{};
      final directCanaryAck = directCanary['ack'] is Map
          ? Map<String, dynamic>.from(directCanary['ack'] as Map)
          : <String, dynamic>{};
      final endpoints = nativeProbe['endpoints'];
      final productionOk = productionHealth == null ||
          productionHealth['ok'] == true ||
          productionHealth['health'] != null ||
          productionHealth.isNotEmpty;
      final nativeOk = nativeHealth['ok'] == true &&
          nativeHealth['runtime'] == 'native-node-embedded' &&
          nativeHealth['port'] == AppConstants.nativeGatewaySmokePort &&
          nativeProbe['runtime'] == 'native-node-embedded' &&
          nativeProbe['canaryOnly'] == true &&
          nativeProbe['chatRoutingEnabled'] == false &&
          nativeProbe['providerCallsEnabled'] == false &&
          nativeProbe['acceptsDryRunQueue'] == true &&
          endpoints is List &&
          endpoints.contains('/gateway/chat-send-dry-run') &&
          endpoints.contains('/gateway/chat-send-canary') &&
          endpoints.contains('/gateway/dry-run-sessions');
      final dryRunOk = dryRun['ok'] == true &&
          dryRun['parsed'] == true &&
          dryRun['acceptedForRouting'] == false &&
          dryRun['acceptedForQueue'] == true &&
          dryRun['queuedForDryRun'] == true &&
          dryRun['queueStatus'] == 'parsed_disabled' &&
          dryRun['providerCallsEnabled'] == false &&
          dryRun['executionEnabled'] == false &&
          dryRun['source'] == 'shadow-dry-run' &&
          dryRun['directCanary'] == false &&
          dryRunAck['route'] == 'disabled';
      final directCanaryOk = directCanary['ok'] == true &&
          directCanary['parsed'] == true &&
          directCanary['acceptedForRouting'] == false &&
          directCanary['acceptedForQueue'] == true &&
          directCanary['queuedForDryRun'] == true &&
          directCanary['queueStatus'] == 'parsed_disabled' &&
          directCanary['providerCallsEnabled'] == false &&
          directCanary['executionEnabled'] == false &&
          directCanary['source'] == 'direct-canary' &&
          directCanary['canaryMode'] == 'direct-dry-run' &&
          directCanary['directCanary'] == true &&
          directCanaryAck['route'] == 'disabled';
      final report = {
        'ok': productionOk && nativeOk && dryRunOk && directCanaryOk,
        'mode': 'side-by-side',
        'primary': 'proot',
        'canary': 'native-node-embedded',
        'production': {
          'port': AppConstants.gatewayPort,
          'healthy': productionOk,
          if (productionHealth?['ok'] != null) 'ok': productionHealth?['ok'],
          if (productionHealth?['runtime'] != null)
            'runtime': productionHealth?['runtime'],
          if (productionHealth?['version'] != null)
            'version': productionHealth?['version'],
        },
        'native': {
          'port': AppConstants.nativeGatewaySmokePort,
          'healthy': nativeOk,
          'node': nativeHealth['node'],
          'canaryOnly': nativeProbe['canaryOnly'],
          'chatRoutingEnabled': nativeProbe['chatRoutingEnabled'],
          'providerCallsEnabled': nativeProbe['providerCallsEnabled'],
          'acceptsDryRunQueue': nativeProbe['acceptsDryRunQueue'],
          'productionSkillCount': nativeProbe['productionSkillCount'],
          'dryRunEndpoint': true,
          'directCanaryEndpoint': true,
        },
        'dryRun': {
          'parsed': dryRun['parsed'],
          'route': dryRunAck['route'],
          'source': dryRunAck['source'],
          'canaryMode': dryRunAck['canaryMode'],
          'directCanary': dryRunAck['directCanary'],
          'queueStatus': dryRunAck['queueStatus'],
          'nativeSessionId': dryRunAck['nativeSessionId'],
          'runId': dryRunAck['runId'],
          'acceptedForRouting': dryRun['acceptedForRouting'],
          'acceptedForQueue': dryRun['acceptedForQueue'],
          'metadataHash': dryRunAck['metadataHash'],
        },
        'directCanary': {
          'parsed': directCanary['parsed'],
          'route': directCanaryAck['route'],
          'source': directCanaryAck['source'],
          'canaryMode': directCanaryAck['canaryMode'],
          'directCanary': directCanaryAck['directCanary'],
          'queueStatus': directCanaryAck['queueStatus'],
          'nativeSessionId': directCanaryAck['nativeSessionId'],
          'runId': directCanaryAck['runId'],
          'acceptedForRouting': directCanary['acceptedForRouting'],
          'acceptedForQueue': directCanary['acceptedForQueue'],
          'metadataHash': directCanaryAck['metadataHash'],
        },
        'decision': 'PRoot remains primary; native is parse-only canary.',
      };
      _canaryComparisonPassed = report['ok'] == true;
      log('[NATIVE-CANARY] ${jsonEncode(report)}');
    } catch (e) {
      log('[NATIVE-CANARY] side-by-side comparison pending: $e');
    } finally {
      _canaryComparisonInFlight = false;
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
      final gatewayProbe = await _probeJson('/gateway/probe');
      final capabilities = await _probeJson('/gateway/capabilities');
      final skillRegistry = await _probeJson('/gateway/skill-registry');
      final models = await _probeJson('/v1/models');
      final chatShape = await _postJson(
        '/v1/chat/completions',
        _sampleChatCompletionRequest(),
        expectedStatus: 409,
      );
      final wsFrameShape = await _postJson(
        '/gateway/ws-frame-shape',
        _sampleGatewayWsChatSendFrame(),
        expectedStatus: 200,
      );
      final chatSendDryRun = await _postJson(
        '/gateway/chat-send-dry-run',
        _sampleGatewayWsChatSendFrame(
          requestId: 'probe-dry-run-request',
          idempotencyKey: 'probe-dry-run-idempotency',
        ),
        expectedStatus: 202,
      );
      final chatSendDirectCanary = await _postJson(
        '/gateway/chat-send-canary',
        _sampleGatewayWsChatSendFrame(
          requestId: 'probe-direct-canary-request',
          idempotencyKey: 'probe-direct-canary-idempotency',
        ),
        expectedStatus: 202,
      );
      final dryRunSessions = await _probeJson('/gateway/dry-run-sessions');
      final shadowParity =
          await NativeGatewayShadowParityService.observeChatSendFrame(
        _sampleGatewayWsChatSendFrame(
          requestId: 'probe-shadow-parity-request',
          idempotencyKey: 'probe-shadow-parity-idempotency',
        ),
        log: log,
      );
      final ok = health['ok'] == true &&
          health['runtime'] == 'native-node-embedded' &&
          health['port'] == AppConstants.nativeGatewaySmokePort &&
          health['productionGatewayPort'] == AppConstants.gatewayPort &&
          health['openclawStarted'] == false &&
          _preflightPassed(health['preflight']) &&
          _gatewayProbePassed(health['gatewayProbe']) &&
          _gatewayProbePassed(gatewayProbe) &&
          _capabilitiesProbePassed(capabilities) &&
          _skillRegistryProbePassed(skillRegistry) &&
          _modelProbePassed(models) &&
          _chatShapeProbePassed(chatShape) &&
          _wsFrameShapeProbePassed(wsFrameShape) &&
          _chatSendDryRunProbePassed(
            chatSendDryRun,
            expectedRequestId: 'probe-dry-run-request',
          ) &&
          _chatSendDirectCanaryProbePassed(chatSendDirectCanary) &&
          _dryRunSessionsProbePassed(dryRunSessions) &&
          (shadowParity?.parityOk == true) &&
          (shadowParity?.dryRunOk == true);
      log('[NATIVE-NODE-EMBEDDED] health: ${jsonEncode(health)}');
      log('[NATIVE-NODE-EMBEDDED] gateway probe: ${jsonEncode(gatewayProbe)}');
      log('[NATIVE-NODE-EMBEDDED] capabilities: ${jsonEncode(capabilities)}');
      log(
        '[NATIVE-NODE-EMBEDDED] skill registry: ${jsonEncode({
              'ok': skillRegistry['ok'],
              'readOnly': skillRegistry['readOnly'],
              'skillCount': skillRegistry['skillCount'],
              'countsByClass': skillRegistry['countsByClass'],
            })}',
      );
      log(
        '[NATIVE-NODE-EMBEDDED] chat request shape: ${jsonEncode(chatShape['requestShape'])}',
      );
      log(
        '[NATIVE-NODE-EMBEDDED] ws chat frame shape: ${jsonEncode(wsFrameShape['requestShape'])}',
      );
      log(
        '[NATIVE-NODE-EMBEDDED] chat.send dry-run: ${jsonEncode(chatSendDryRun['ack'])}',
      );
      log(
        '[NATIVE-NODE-EMBEDDED] chat.send direct canary: ${jsonEncode(chatSendDirectCanary['ack'])}',
      );
      log(
        '[NATIVE-NODE-EMBEDDED] dry-run sessions: ${jsonEncode({
              'ok': dryRunSessions['ok'],
              'sessionCount': dryRunSessions['sessionCount'],
              'pendingQueueDepth': dryRunSessions['pendingQueueDepth'],
              'totalCompleted': dryRunSessions['totalCompleted'],
              'totalDuplicate': dryRunSessions['totalDuplicate'],
            })}',
      );

      if (NativeGatewayShadowParityService.shadowDiagnosticsEnabled) {
        log(
          '[NATIVE-NODE-EMBEDDED] keeping parser running for real-turn shadow parity.',
        );
        return NativeGatewaySmokeReport(
          passed: ok,
          message: ok
              ? 'ok; parser kept alive'
              : 'unexpected embedded native Node health payload',
          health: health,
        );
      }

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

  static Future<Map<String, dynamic>> runRuntimeSelectionCanary({
    required void Function(String message) log,
  }) async {
    final productionRuntime = GatewayRuntimeRegistry.current;
    final canaryRuntime = GatewayRuntimeRegistry.nativeNodeProcessSmoke;
    final productionRunning = await productionRuntime
        .isRunning()
        .timeout(const Duration(seconds: 3), onTimeout: () => false)
        .catchError((_) => false);

    Map<String, dynamic> productionHealth = <String, dynamic>{};
    Object? productionHealthError;
    if (productionRunning) {
      try {
        productionHealth = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthError = e;
      }
    }

    final nativeWasRunning = await canaryRuntime
        .isRunning()
        .timeout(const Duration(seconds: 3), onTimeout: () => false)
        .catchError((_) => false);
    var nativeStartedByCanary = false;
    if (!nativeWasRunning) {
      nativeStartedByCanary = await canaryRuntime
          .start()
          .timeout(const Duration(seconds: 8), onTimeout: () => false)
          .catchError((_) => false);
    }
    var nativeRunning = nativeWasRunning;
    Map<String, dynamic> nativeHealth = <String, dynamic>{};
    Map<String, dynamic> nativeProbe = <String, dynamic>{};
    Object? nativeError;
    if (nativeWasRunning || nativeStartedByCanary) {
      try {
        nativeHealth = await _probeHealth(
          expectedRuntime: 'native-node-embedded',
        );
        nativeProbe = await _probeJson('/gateway/probe');
        nativeRunning = true;
      } catch (e) {
        nativeError = e;
        nativeRunning = await canaryRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);
      }
    }

    final productionHealthOk = productionHealth['ok'] == true ||
        productionHealth['status'] == 'ok' ||
        productionHealth.isNotEmpty;
    final nativeOk = nativeRunning &&
        nativeHealth['ok'] == true &&
        nativeHealth['runtime'] == 'native-node-embedded' &&
        nativeHealth['port'] == AppConstants.nativeGatewaySmokePort &&
        nativeProbe['runtime'] == 'native-node-embedded' &&
        nativeProbe['canaryOnly'] == true &&
        nativeProbe['chatRoutingEnabled'] == false &&
        nativeProbe['providerCallsEnabled'] == false;
    final selectionGuardOk = productionRuntime.id == 'proot' &&
        canaryRuntime.id == 'native-node-embedded-smoke' &&
        AppConstants.gatewayPort != AppConstants.nativeGatewaySmokePort &&
        nativeProbe['productionReady'] == false &&
        nativeProbe['openclawStarted'] == false;
    final fallbackOk = productionRuntime.id == 'proot';
    final ok = productionRunning &&
        productionHealthOk &&
        nativeOk &&
        selectionGuardOk &&
        fallbackOk;

    final report = <String, dynamic>{
      'ok': ok,
      'phase': 'hidden-runtime-selection-canary',
      'mode': 'side-by-side-selection',
      'activeRuntimeId': productionRuntime.id,
      'activeRuntimeLabel': productionRuntime.label,
      'activeRuntimeIsProot': productionRuntime.id == 'proot',
      'fallbackRuntimeId': 'proot',
      'fallbackOneActionAway': fallbackOk,
      'productionPort': AppConstants.gatewayPort,
      'nativeCanaryPort': AppConstants.nativeGatewaySmokePort,
      'portsIsolated':
          AppConstants.gatewayPort != AppConstants.nativeGatewaySmokePort,
      'productionRunning': productionRunning,
      'productionHealthOk': productionHealthOk,
      'productionRuntimeReported': productionHealth['runtime'],
      if (productionHealthError != null)
        'productionHealthError': productionHealthError.toString(),
      'canaryRuntimeId': canaryRuntime.id,
      'canaryRuntimeLabel': canaryRuntime.label,
      'nativeWasRunning': nativeWasRunning,
      'nativeStartedByCanary': nativeStartedByCanary,
      'nativeRunning': nativeRunning,
      'nativeHealthOk': nativeOk,
      'nativeRuntimeReported': nativeHealth['runtime'],
      'nativeNode': nativeHealth['node'],
      if (nativeError != null) 'nativeError': nativeError.toString(),
      'selectionGuardOk': selectionGuardOk,
      'nativeProductionReady': nativeProbe['productionReady'] == true,
      'nativeOpenClawStarted': nativeProbe['openclawStarted'] == true,
      'nativeChatRoutingEnabled': nativeProbe['chatRoutingEnabled'] == true,
      'nativeProviderCallsEnabled': nativeProbe['providerCallsEnabled'] == true,
      'nativeToolExecutionEnabled': nativeProbe['toolExecutionEnabled'] == true,
      'nativeCanaryOnly': nativeProbe['canaryOnly'] == true,
      'decision': ok
          ? 'PRoot remains active; native is selectable only as an isolated canary.'
          : 'Runtime selection canary is not ready for promotion.',
      'nextGate': 'native production-port bind only after explicit PRoot stop',
    };
    log('[NATIVE-RUNTIME-SELECT] ${jsonEncode(report)}');
    return report;
  }

  static Future<Map<String, dynamic>> runProductionPortBindCanary({
    required void Function(String message) log,
  }) async {
    if (_productionPortBindInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-bind-canary',
        'alreadyInFlight': true,
        'decision': 'Production-port bind canary is already running.',
      };
    }

    _productionPortBindInFlight = true;
    try {
      final productionRuntime = GatewayRuntimeRegistry.current;
      final canaryRuntime = _productionPortRuntime;
      var nativeSmokeWasRunning = false;
      var nativeSmokeStopRequested = false;
      var nativeSmokeRestored = false;
      var preflightProductionRunning = false;
      var productionHealthOkBefore = false;
      var prootStopRequested = false;
      var productionPortReleased = false;
      var nativeStarted = false;
      var nativeRunning = false;
      var nativeObservedAlive = false;
      var nativeStopped = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-PORT-BIND] Opening guarded production-port bind canary.');

      try {
        nativeSmokeWasRunning = await _nodeRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);
        nativeSmokeStopRequested = await _nodeRuntime
            .stop()
            .timeout(const Duration(seconds: 8), onTimeout: () => false)
            .catchError((_) => false);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        preflightProductionRunning = await productionRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);
        if (!preflightProductionRunning) {
          await productionRuntime
              .start(allowDuringSetup: true)
              .timeout(const Duration(seconds: 30), onTimeout: () => false)
              .catchError((_) => false);
          preflightProductionRunning = await productionRuntime
              .isRunning()
              .timeout(const Duration(seconds: 3), onTimeout: () => false)
              .catchError((_) => false);
        }

        try {
          productionBefore = await _probeProductionJson(
            '/health',
            attempts: 12,
            retryDelay: const Duration(milliseconds: 500),
          );
          productionHealthOkBefore = productionBefore['ok'] == true ||
              productionBefore['status'] == 'ok' ||
              productionBefore.isNotEmpty;
        } catch (e) {
          productionBeforeError = e;
        }

        if (productionRuntime.id != 'proot') {
          throw StateError(
            'Production-port canary requires PRoot as the current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before the bind canary.',
          );
        }

        log('[NATIVE-PORT-BIND] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly after PRoot stop.',
          );
        }

        log('[NATIVE-PORT-BIND] Starting native on 18789 with routing disabled.');
        nativeStarted = await canaryRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native production-port canary did not start.');
        }

        nativeHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 60,
          retryDelay: const Duration(milliseconds: 500),
        );
        nativeProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 12,
          retryDelay: const Duration(milliseconds: 250),
        );
        nativeObservedAlive = true;
        nativeRunning = await canaryRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);
      } catch (e) {
        if (prootStopRequested || productionPortReleased || nativeStarted) {
          nativeError = e;
        } else {
          prootStopError = e;
        }
      } finally {
        try {
          nativeStopped = await canaryRuntime
              .stop()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          nativeStopError = e;
        }

        try {
          for (var attempt = 1; attempt <= 3; attempt++) {
            rollbackStarted = await productionRuntime
                .start(allowDuringSetup: true)
                .timeout(const Duration(seconds: 40), onTimeout: () => false);
            try {
              rollbackHealth = await _probeProductionJson(
                '/health',
                attempts: 80,
                retryDelay: const Duration(milliseconds: 750),
                requestTimeout: const Duration(seconds: 1),
              );
              rollbackHealthOk = rollbackHealth['ok'] == true ||
                  rollbackHealth['status'] == 'ok' ||
                  rollbackHealth.isNotEmpty;
            } catch (e) {
              rollbackError = e;
            }
            rollbackRunning = await productionRuntime
                .isRunning()
                .timeout(const Duration(seconds: 3), onTimeout: () => false)
                .catchError((_) => false);
            if (rollbackStarted && rollbackRunning && rollbackHealthOk) {
              rollbackError = null;
              break;
            }
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          rollbackError = e;
        }

        if ((nativeSmokeWasRunning || nativeSmokeStopRequested) &&
            rollbackHealthOk) {
          nativeSmokeRestored = await _nodeRuntime
              .start()
              .timeout(const Duration(seconds: 8), onTimeout: () => false)
              .catchError((_) => false);
        }
      }

      final nativeGuardOk = nativeObservedAlive &&
          nativeHealth['ok'] == true &&
          nativeHealth['runtime'] == 'native-node-embedded' &&
          nativeHealth['port'] == AppConstants.gatewayPort &&
          nativeHealth['productionPortBindCanary'] == true &&
          nativeHealth['openclawStarted'] == false &&
          nativeProbe['runtime'] == 'native-node-embedded' &&
          nativeProbe['port'] == AppConstants.gatewayPort &&
          nativeProbe['productionPortBindCanary'] == true &&
          nativeProbe['canaryOnly'] == true &&
          nativeProbe['productionReady'] == false &&
          nativeProbe['openclawStarted'] == false &&
          nativeProbe['chatRoutingEnabled'] == false &&
          nativeProbe['providerCallsEnabled'] == false &&
          nativeProbe['toolExecutionEnabled'] != true;
      final rollbackOk = rollbackStarted && rollbackRunning && rollbackHealthOk;
      final ok = productionRuntime.id == 'proot' &&
          preflightProductionRunning &&
          productionHealthOkBefore &&
          prootStopRequested &&
          productionPortReleased &&
          nativeStarted &&
          nativeGuardOk &&
          nativeStopped &&
          rollbackOk;

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-bind-canary',
        'mode': 'stop-proot-bind-native-rollback-proot',
        'activeRuntimeId': productionRuntime.id,
        'canaryRuntimeId': canaryRuntime.id,
        'productionPort': AppConstants.gatewayPort,
        'nativeSmokePort': AppConstants.nativeGatewaySmokePort,
        'nativeSmokeWasRunning': nativeSmokeWasRunning,
        'nativeSmokeStopRequested': nativeSmokeStopRequested,
        'nativeSmokeRestored': nativeSmokeRestored,
        'preflightProductionRunning': preflightProductionRunning,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionRuntimeBefore': productionBefore['runtime'],
        if (productionBeforeError != null)
          'productionBeforeError': productionBeforeError.toString(),
        'prootStopRequested': prootStopRequested,
        if (prootStopError != null) 'prootStopError': prootStopError.toString(),
        'productionPortReleased': productionPortReleased,
        'nativeStarted': nativeStarted,
        'nativeRunning': nativeRunning,
        'nativeObservedAlive': nativeObservedAlive,
        'nativeHealthOk': nativeGuardOk,
        'nativeRuntimeReported': nativeHealth['runtime'],
        'nativePortReported': nativeHealth['port'],
        'nativeCanaryMode': nativeHealth['canaryMode'],
        'nativeProductionPortBindCanary':
            nativeHealth['productionPortBindCanary'] == true,
        'nativeCanaryOnly': nativeProbe['canaryOnly'] == true,
        'nativeOpenClawStarted': nativeProbe['openclawStarted'] == true,
        'nativeChatRoutingEnabled': nativeProbe['chatRoutingEnabled'] == true,
        'nativeProviderCallsEnabled':
            nativeProbe['providerCallsEnabled'] == true,
        'nativeToolExecutionEnabled':
            nativeProbe['toolExecutionEnabled'] == true,
        if (nativeError != null) 'nativeError': nativeError.toString(),
        'nativeStopped': nativeStopped,
        if (nativeStopError != null)
          'nativeStopError': nativeStopError.toString(),
        'rollbackRuntimeId': 'proot',
        'rollbackStarted': rollbackStarted,
        'rollbackRunning': rollbackRunning,
        'rollbackHealthOk': rollbackHealthOk,
        'rollbackRuntimeReported': rollbackHealth['runtime'],
        if (rollbackError != null) 'rollbackError': rollbackError.toString(),
        'decision': ok
            ? 'Native proved it can bind 18789 as a canary; PRoot was restored.'
            : 'Production-port bind canary is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'native can own 18789 only after full routing/provider/tool parity gates',
      };
      log('[NATIVE-PORT-BIND] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortBindInFlight = false;
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

  static bool _gatewayProbePassed(Object? value) {
    if (value is! Map<String, dynamic>) return false;

    final endpoints = value['endpoints'];
    final endpointsOk = endpoints is List &&
        endpoints.contains('/health') &&
        endpoints.contains('/gateway/probe') &&
        endpoints.contains('/gateway/capabilities') &&
        endpoints.contains('/gateway/skill-registry') &&
        endpoints.contains('/gateway/request-shape') &&
        endpoints.contains('/gateway/ws-frame-shape') &&
        endpoints.contains('/gateway/chat-send-dry-run') &&
        endpoints.contains('/gateway/chat-send-canary') &&
        endpoints.contains('/gateway/dry-run-sessions') &&
        endpoints.contains('/v1/models') &&
        endpoints.contains('/v1/chat/completions');

    final skillCount = value['skillCount'];
    final toolCount = value['toolCount'];
    return value['passed'] == true &&
        value['probe'] == 'mobile-openclaw-gateway-bootstrap' &&
        value['gatewayShape'] == 'openclaw-http-probe' &&
        value['runtime'] == 'native-node-embedded' &&
        value['canaryOnly'] == true &&
        value['productionReady'] == false &&
        value['openclawStarted'] == false &&
        value['chatRoutingEnabled'] == false &&
        value['providerCallsEnabled'] == false &&
        value['acceptsDryRunQueue'] == true &&
        value['fullSkillRegistryLoaded'] == false &&
        value['productionSkillRegistryInspected'] == true &&
        value['productionSkillCount'] is num &&
        (value['productionSkillCount'] as num) >= 50 &&
        value['skillRegistryMode'] == 'curated-mobile-preflight' &&
        skillCount is num &&
        skillCount >= 4 &&
        toolCount is num &&
        toolCount >= 3 &&
        endpointsOk;
  }

  static bool _capabilitiesProbePassed(Map<String, dynamic> value) {
    final skills = value['skillFiles'];
    final tools = value['bridgeToolNames'];
    return value['ok'] == true &&
        value['runtime'] == 'native-node-embedded' &&
        value['capabilityMode'] == 'curated-mobile-preflight' &&
        value['canaryOnly'] == true &&
        value['openclawStarted'] == false &&
        value['fullSkillRegistryLoaded'] == false &&
        value['productionSkillRegistryInspected'] == true &&
        value['productionSkillCount'] is num &&
        (value['productionSkillCount'] as num) >= 50 &&
        value['productionSkillsLoaded'] == false &&
        value['skillCount'] is num &&
        (value['skillCount'] as num) >= 4 &&
        skills is List &&
        skills.contains('battery.md') &&
        tools is List &&
        tools.contains('get_battery') &&
        tools.contains('read_sensor') &&
        tools.contains('vibrate');
  }

  static bool _skillRegistryProbePassed(Map<String, dynamic> value) {
    final skills = value['skills'];
    if (skills is! List) return false;

    final ids = skills
        .whereType<Map>()
        .map((skill) => skill['id']?.toString())
        .whereType<String>()
        .toSet();
    final countsByClass = value['countsByClass'];

    return value['ok'] == true &&
        value['readOnly'] == true &&
        value['executionEnabled'] == false &&
        value['registrySource'] == 'proot-openclaw-skills' &&
        value['openclawStarted'] == false &&
        value['chatRoutingEnabled'] == false &&
        value['canaryOnly'] == true &&
        value['skillCount'] is num &&
        (value['skillCount'] as num) >= 50 &&
        ids.contains('weather') &&
        ids.contains('canvas') &&
        ids.contains('device-node') &&
        ids.contains('gestures') &&
        ids.contains('tts-voice') &&
        countsByClass is Map &&
        countsByClass.isNotEmpty;
  }

  static bool _modelProbePassed(Map<String, dynamic> value) {
    final models = value['data'];
    if (models is! List || models.isEmpty || models.first is! Map) {
      return false;
    }
    final first = Map<String, dynamic>.from(models.first as Map);
    final capabilities = first['capabilities'];

    return value['object'] == 'list' &&
        value['probeOnly'] == true &&
        value['canaryOnly'] == true &&
        first['id'] == 'plawie/native-node-probe' &&
        capabilities is Map &&
        capabilities['chat'] == false &&
        capabilities['tool_calls'] == false &&
        capabilities['streaming'] == false;
  }

  static bool _chatShapeProbePassed(Map<String, dynamic> value) {
    final error = value['error'];
    final shape = value['requestShape'];
    if (error is! Map || shape is! Map) return false;

    final roles = shape['roleCounts'];
    final toolNames = shape['toolNames'];
    return error['code'] == 'chat_disabled' &&
        value['runtime'] == 'native-node-embedded' &&
        value['canaryOnly'] == true &&
        value['openclawStarted'] == false &&
        value['providerCallsEnabled'] == false &&
        value['executionEnabled'] == false &&
        shape['ok'] == true &&
        shape['requestShape'] == 'openai-chat-completions' &&
        shape['model'] == 'plawie/native-node-probe' &&
        shape['stream'] == true &&
        shape['acceptedForRouting'] == false &&
        shape['providerCallsEnabled'] == false &&
        shape['executionEnabled'] == false &&
        shape['safeForProbe'] == true &&
        shape['messageCount'] == 3 &&
        roles is Map &&
        roles['system'] == 1 &&
        roles['user'] == 1 &&
        roles['assistant'] == 1 &&
        shape['toolCount'] == 2 &&
        toolNames is List &&
        toolNames.contains('get_battery') &&
        toolNames.contains('vibrate');
  }

  static bool _wsFrameShapeProbePassed(Map<String, dynamic> value) {
    final shape = value['requestShape'];
    if (shape is! Map) return false;

    final hints = shape['mobileToolHints'];
    return value['ok'] == true &&
        value['runtime'] == 'native-node-embedded' &&
        value['canaryOnly'] == true &&
        value['openclawStarted'] == false &&
        shape['ok'] == true &&
        shape['requestShape'] == 'openclaw-ws-rpc-chat-send' &&
        shape['frameType'] == 'req' &&
        shape['method'] == 'chat.send' &&
        shape['hasId'] == true &&
        shape['sessionKey'] == 'main' &&
        shape['idempotencyKeyPresent'] == true &&
        shape['timeoutMs'] == 300000 &&
        shape['hasMobileToolContext'] == true &&
        shape['mobileNodeHandle'] == 'OpenClaw Mobile' &&
        shape['notificationListDisabled'] == true &&
        shape['looksLikeProductionChatSend'] == true &&
        shape['acceptedForRouting'] == false &&
        shape['providerCallsEnabled'] == false &&
        shape['executionEnabled'] == false &&
        hints is List &&
        hints.contains('camera_snap') &&
        hints.contains('avatar.gesture') &&
        hints.contains('haptic.vibrate') &&
        hints.contains('notifications.list');
  }

  static bool _chatSendDryRunProbePassed(
    Map<String, dynamic> value, {
    String expectedRequestId = 'probe-chat-send-request',
    String expectedSource = 'shadow-dry-run',
    String expectedCanaryMode = 'shadow-dry-run',
    bool expectedDirectCanary = false,
  }) {
    final shape = value['requestShape'];
    final ack = value['ack'];
    if (shape is! Map || ack is! Map) return false;

    final hints = ack['mobileToolHints'];
    return value['ok'] == true &&
        value['type'] == 'res' &&
        value['id'] == expectedRequestId &&
        value['method'] == 'chat.send' &&
        value['runtime'] == 'native-node-embedded' &&
        value['canaryOnly'] == true &&
        value['dryRun'] == true &&
        value['source'] == expectedSource &&
        value['canaryMode'] == expectedCanaryMode &&
        value['directCanary'] == expectedDirectCanary &&
        value['parsed'] == true &&
        value['openclawStarted'] == false &&
        value['acceptedForRouting'] == false &&
        value['acceptedForQueue'] == true &&
        value['queuedForDryRun'] == true &&
        value['queueStatus'] == 'parsed_disabled' &&
        value['chatRoutingEnabled'] == false &&
        value['providerCallsEnabled'] == false &&
        value['executionEnabled'] == false &&
        ack['parsed'] == true &&
        ack['route'] == 'disabled' &&
        ack['source'] == expectedSource &&
        ack['canaryMode'] == expectedCanaryMode &&
        ack['directCanary'] == expectedDirectCanary &&
        ack['queueStatus'] == 'parsed_disabled' &&
        ack['sessionKey'] == 'main' &&
        ack['nativeSessionId'] is String &&
        (ack['nativeSessionId'] as String).isNotEmpty &&
        ack['requestId'] == expectedRequestId &&
        ack['runId'] is String &&
        (ack['runId'] as String).isNotEmpty &&
        ack['sequence'] is num &&
        ack['queueDepthBefore'] is num &&
        ack['queueDepthAfter'] is num &&
        ack['pendingQueueDepth'] == 0 &&
        ack['sessionCompleted'] is num &&
        ack['duplicate'] == false &&
        ack['idempotencyKeyPresent'] == true &&
        ack['timeoutMs'] == 300000 &&
        ack['messageChars'] is num &&
        ack['hasMobileToolContext'] == true &&
        ack['mobileNodeHandle'] == 'OpenClaw Mobile' &&
        ack['metadataHash'] is String &&
        (ack['metadataHash'] as String).isNotEmpty &&
        shape['looksLikeProductionChatSend'] == true &&
        shape['acceptedForRouting'] == false &&
        shape['providerCallsEnabled'] == false &&
        shape['executionEnabled'] == false &&
        hints is List &&
        hints.contains('camera_snap') &&
        hints.contains('avatar.gesture') &&
        hints.contains('haptic.vibrate') &&
        hints.contains('notifications.list');
  }

  static bool _chatSendDirectCanaryProbePassed(Map<String, dynamic> value) {
    return _chatSendDryRunProbePassed(
      value,
      expectedRequestId: 'probe-direct-canary-request',
      expectedSource: 'direct-canary',
      expectedCanaryMode: 'direct-dry-run',
      expectedDirectCanary: true,
    );
  }

  static bool _dryRunSessionsProbePassed(Map<String, dynamic> value) {
    final sessions = value['sessions'];
    if (sessions is! List || sessions.isEmpty || sessions.first is! Map) {
      return false;
    }
    final first = Map<String, dynamic>.from(sessions.first as Map);
    return value['ok'] == true &&
        value['runtime'] == 'native-node-embedded' &&
        value['canaryOnly'] == true &&
        value['dryRun'] == true &&
        value['queueMode'] == 'parse-only' &&
        value['route'] == 'disabled' &&
        value['acceptedForRouting'] == false &&
        value['chatRoutingEnabled'] == false &&
        value['providerCallsEnabled'] == false &&
        value['executionEnabled'] == false &&
        value['sessionCount'] is num &&
        (value['sessionCount'] as num) >= 1 &&
        value['pendingQueueDepth'] == 0 &&
        value['totalCompleted'] is num &&
        (value['totalCompleted'] as num) >= 1 &&
        first['sessionKey'] == 'main' &&
        first['nativeSessionId'] is String &&
        (first['nativeSessionId'] as String).isNotEmpty &&
        first['completed'] is num &&
        (first['completed'] as num) >= 1;
  }

  static Map<String, dynamic> _sampleChatCompletionRequest() {
    return {
      'model': 'plawie/native-node-probe',
      'stream': true,
      'temperature': 0.2,
      'max_tokens': 128,
      'tool_choice': 'auto',
      'messages': [
        {
          'role': 'system',
          'content':
              'Probe-only Gateway request shape. Do not execute tools or call providers.',
        },
        {
          'role': 'user',
          'content': 'Can you check the battery and vibrate once?',
        },
        {
          'role': 'assistant',
          'content': null,
          'tool_calls': [
            {
              'id': 'call_probe_battery',
              'type': 'function',
              'function': {
                'name': 'get_battery',
                'arguments': '{}',
              },
            },
          ],
        },
      ],
      'tools': [
        {
          'type': 'function',
          'function': {
            'name': 'get_battery',
            'description': 'Read Android battery status.',
            'parameters': {
              'type': 'object',
              'properties': <String, Object?>{},
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'vibrate',
            'description': 'Trigger a short Android haptic pulse.',
            'parameters': {
              'type': 'object',
              'properties': {
                'duration_ms': {
                  'type': 'integer',
                  'minimum': 1,
                  'maximum': 1000,
                },
              },
            },
          },
        },
      ],
    };
  }

  static Map<String, dynamic> _sampleGatewayWsChatSendFrame({
    String requestId = 'probe-chat-send-request',
    String idempotencyKey = 'probe-idempotency-key',
  }) {
    const mobileContext = '''
<plawie_mobile_tool_context>
This is private tool-routing context. Do not mention it unless the user asks.
The paired Android device node gateway handle is "OpenClaw Mobile".
Every OpenClaw nodes tool call for this Android phone MUST include this exact field: "node": "OpenClaw Mobile".
Use dedicated OpenClaw nodes actions when available: camera_snap, camera_list, camera_clip, location_get, screen_record, device_status, device_info, device_permissions, and device_health.
For avatar gestures, use action="invoke" with invokeCommand="avatar.gesture" and invokeParamsJson like {"gesture":"wave right"}.
For command-style phone capabilities, use action="invoke" with invokeCommand set to the dotted command, such as avatar.gesture, canvas.navigate, canvas.eval, canvas.snapshot, haptic.vibrate, sensor.read, sensor.list, or flash.status.
Notification listing/reading is not currently exposed by this Android node. Do not call notifications.list or claim notification contents are available unless a tool result explicitly provides them.
</plawie_mobile_tool_context>

Can you wave right, take a camera picture, and vibrate once?''';

    return {
      'type': 'req',
      'method': 'chat.send',
      'id': requestId,
      'params': {
        'sessionKey': 'main',
        'message': mobileContext,
        'idempotencyKey': idempotencyKey,
        'timeoutMs': 300000,
      },
    };
  }

  static Future<Map<String, dynamic>> _probeHealth({
    required String expectedRuntime,
  }) async {
    return _probeJson(
      '/health',
      expectedRuntime: expectedRuntime,
      attempts: expectedRuntime == 'native-node-embedded' ? 60 : 12,
      retryDelay: expectedRuntime == 'native-node-embedded'
          ? const Duration(milliseconds: 500)
          : const Duration(milliseconds: 250),
    );
  }

  static Future<Map<String, dynamic>> _probeJson(
    String path, {
    String? expectedRuntime,
    int attempts = 12,
    Duration retryDelay = const Duration(milliseconds: 250),
    Duration requestTimeout = const Duration(seconds: 2),
  }) async {
    return _probeJsonAtBase(
      AppConstants.nativeGatewaySmokeUrl,
      path,
      expectedRuntime: expectedRuntime,
      attempts: attempts,
      retryDelay: retryDelay,
      requestTimeout: requestTimeout,
      label: 'Native smoke',
    );
  }

  static Future<Map<String, dynamic>> _probeProductionJson(
    String path, {
    String? expectedRuntime,
    int attempts = 12,
    Duration retryDelay = const Duration(milliseconds: 250),
    Duration requestTimeout = const Duration(seconds: 2),
  }) async {
    return _probeJsonAtBase(
      AppConstants.gatewayUrl,
      path,
      expectedRuntime: expectedRuntime,
      attempts: attempts,
      retryDelay: retryDelay,
      requestTimeout: requestTimeout,
      label: 'Production',
    );
  }

  static Future<Map<String, dynamic>> _probeJsonAtBase(
    String baseUrl,
    String path, {
    String? expectedRuntime,
    int attempts = 12,
    Duration retryDelay = const Duration(milliseconds: 250),
    Duration requestTimeout = const Duration(seconds: 2),
    required String label,
  }) async {
    final client = http.Client();
    try {
      Object? lastError;
      for (var attempt = 0; attempt < attempts; attempt++) {
        try {
          final normalizedPath = path.startsWith('/') ? path : '/$path';
          final response = await client
              .get(Uri.parse('$baseUrl$normalizedPath'))
              .timeout(requestTimeout);
          if (response.statusCode != 200) {
            throw StateError('HTTP ${response.statusCode}: ${response.body}');
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw StateError('Health payload was not a JSON object');
          }
          if (expectedRuntime != null &&
              decoded['runtime'] != expectedRuntime) {
            throw StateError(
              'Expected $expectedRuntime health, got ${decoded['runtime']}',
            );
          }
          return decoded;
        } catch (e) {
          lastError = e;
          if (retryDelay > Duration.zero) {
            await Future<void>.delayed(retryDelay);
          }
        }
      }
      throw StateError('$label JSON probe $path failed: $lastError');
    } finally {
      client.close();
    }
  }

  static Future<bool> _waitForProductionPortReleased({
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    final client = http.Client();
    while (DateTime.now().isBefore(deadline)) {
      try {
        await client
            .get(Uri.parse('${AppConstants.gatewayUrl}/health'))
            .timeout(const Duration(milliseconds: 700));
      } catch (_) {
        client.close();
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    client.close();
    return false;
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    required int expectedStatus,
  }) async {
    final client = http.Client();
    try {
      Object? lastError;
      for (var attempt = 0; attempt < 12; attempt++) {
        try {
          final normalizedPath = path.startsWith('/') ? path : '/$path';
          final response = await client
              .post(
                Uri.parse(
                  '${AppConstants.nativeGatewaySmokeUrl}$normalizedPath',
                ),
                headers: const {'content-type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 2));
          if (response.statusCode != expectedStatus) {
            throw StateError('HTTP ${response.statusCode}: ${response.body}');
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw StateError('POST payload was not a JSON object');
          }
          return decoded;
        } catch (e) {
          lastError = e;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      throw StateError('JSON POST probe $path failed: $lastError');
    } finally {
      client.close();
    }
  }
}

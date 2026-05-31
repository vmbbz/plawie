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
  static bool _productionPortBindSoakInFlight = false;
  static bool _runtimeOwnerCanaryInFlight = false;
  static bool _productionPortRouteOwnerInFlight = false;
  static bool _productionPortProviderEnvelopeInFlight = false;
  static bool _productionPortProviderBuilderInFlight = false;
  static bool _productionPortProviderTransportInFlight = false;
  static bool _productionPortProviderLiveInFlight = false;
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
      var nativePortReleasedAfterStop = false;
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
          productionHealthOkBefore =
              _productionHealthLooksLikeProot(productionBefore);
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
        if (prootStopRequested || nativeStarted) {
          nativePortReleasedAfterStop = await _waitForProductionPortReleased(
            timeout: const Duration(seconds: 35),
          );
        } else {
          nativePortReleasedAfterStop = true;
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
              rollbackHealthOk =
                  _productionHealthLooksLikeProot(rollbackHealth);
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
          nativePortReleasedAfterStop &&
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
        'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
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

  static Future<Map<String, dynamic>> runProductionPortBindSoak({
    required void Function(String message) log,
    int cycles = 3,
  }) async {
    if (_productionPortBindSoakInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-bind-soak',
        'alreadyInFlight': true,
        'decision': 'Production-port bind soak is already running.',
      };
    }

    final requestedCycles = cycles;
    final normalizedCycles = cycles.clamp(1, 5).toInt();
    _productionPortBindSoakInFlight = true;
    final startedAt = DateTime.now();
    final reports = <Map<String, dynamic>>[];
    Map<String, dynamic> finalProductionHealth = <String, dynamic>{};
    Map<String, dynamic> finalNativeSmokeHealth = <String, dynamic>{};
    Object? finalProductionHealthError;
    Object? finalNativeSmokeHealthError;
    var failedCycle = 0;

    try {
      log(
        '[NATIVE-PORT-SOAK] Starting $normalizedCycles guarded '
        'production-port bind cycles.',
      );

      for (var cycle = 1; cycle <= normalizedCycles; cycle++) {
        log('[NATIVE-PORT-SOAK] Cycle $cycle/$normalizedCycles opening.');
        final report = await runProductionPortBindCanary(log: log);
        reports.add({
          'cycle': cycle,
          ...report,
        });
        if (report['ok'] != true) {
          failedCycle = cycle;
          log('[NATIVE-PORT-SOAK] Cycle $cycle failed; stopping soak.');
          break;
        }
        if (cycle < normalizedCycles) {
          await Future<void>.delayed(const Duration(seconds: 3));
        }
      }

      try {
        finalProductionHealth = await _probeProductionJson(
          '/health',
          attempts: 20,
          retryDelay: const Duration(milliseconds: 500),
          requestTimeout: const Duration(seconds: 1),
        );
      } catch (e) {
        finalProductionHealthError = e;
      }

      try {
        finalNativeSmokeHealth = await _probeHealth(
          expectedRuntime: 'native-node-embedded',
        );
      } catch (e) {
        finalNativeSmokeHealthError = e;
      }

      final passedCycles =
          reports.where((report) => report['ok'] == true).length;
      final finalProductionOk =
          _productionHealthLooksLikeProot(finalProductionHealth);
      final finalNativeSmokeOk =
          finalNativeSmokeHealth['runtime'] == 'native-node-embedded' &&
              finalNativeSmokeHealth['port'] ==
                  AppConstants.nativeGatewaySmokePort &&
              finalNativeSmokeHealth['productionPortBindCanary'] != true &&
              finalNativeSmokeHealth['openclawStarted'] == false;
      final ok = failedCycle == 0 &&
          passedCycles == normalizedCycles &&
          finalProductionOk &&
          finalNativeSmokeOk;

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-bind-soak',
        'mode': 'repeat-stop-proot-bind-native-rollback-proot',
        'requestedCycles': requestedCycles,
        'cycles': normalizedCycles,
        'passedCycles': passedCycles,
        'failedCycle': failedCycle == 0 ? null : failedCycle,
        'productionPort': AppConstants.gatewayPort,
        'nativeSmokePort': AppConstants.nativeGatewaySmokePort,
        'finalProductionHealthOk': finalProductionOk,
        'finalProductionRuntimeReported': finalProductionHealth['runtime'],
        if (finalProductionHealthError != null)
          'finalProductionHealthError': finalProductionHealthError.toString(),
        'finalNativeSmokeHealthOk': finalNativeSmokeOk,
        'finalNativeSmokeRuntimeReported': finalNativeSmokeHealth['runtime'],
        'finalNativeSmokePortReported': finalNativeSmokeHealth['port'],
        if (finalNativeSmokeHealthError != null)
          'finalNativeSmokeHealthError': finalNativeSmokeHealthError.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'reports': reports,
        'decision': ok
            ? 'Native survived repeated guarded ownership handoffs; PRoot and smoke lanes were restored.'
            : 'Production-port ownership soak is not promotable; inspect failedCycle and final health.',
        'nextGate':
            'hidden runtime-owner selection toggle with automatic rollback',
      };
      log('[NATIVE-PORT-SOAK] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortBindSoakInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runRuntimeOwnerCanary({
    required void Function(String message) log,
    int holdSeconds = 5,
  }) async {
    if (_runtimeOwnerCanaryInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-runtime-owner-canary',
        'alreadyInFlight': true,
        'decision': 'Runtime-owner canary is already running.',
      };
    }

    final requestedHoldSeconds = holdSeconds;
    final normalizedHoldSeconds = holdSeconds.clamp(3, 30).toInt();
    _runtimeOwnerCanaryInFlight = true;
    final ownerProbeSamples = <Map<String, dynamic>>[];
    final ownerProbeFailures = <Map<String, dynamic>>[];
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.current;
      final ownerRuntime = _productionPortRuntime;
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
      var nativeOwnerProbesOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
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

      log('[NATIVE-OWNER-CANARY] Opening temporary native owner canary.');

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
          productionHealthOkBefore =
              _productionHealthLooksLikeProot(productionBefore);
        } catch (e) {
          productionBeforeError = e;
        }

        if (productionRuntime.id != 'proot') {
          throw StateError(
            'Runtime-owner canary requires PRoot as the current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before owner canary.',
          );
        }

        log('[NATIVE-OWNER-CANARY] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before owner canary.',
          );
        }

        log(
          '[NATIVE-OWNER-CANARY] Native owning 18789 for '
          '$normalizedHoldSeconds seconds with routing disabled.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native runtime-owner canary did not start.');
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
        nativeRunning = await ownerRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);

        for (var second = 1; second <= normalizedHoldSeconds; second++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          try {
            final healthSample = await _probeProductionJson(
              '/health',
              expectedRuntime: 'native-node-embedded',
              attempts: 3,
              retryDelay: const Duration(milliseconds: 100),
              requestTimeout: const Duration(seconds: 1),
            );
            final probeSample = await _probeProductionJson(
              '/gateway/probe',
              expectedRuntime: 'native-node-embedded',
              attempts: 3,
              retryDelay: const Duration(milliseconds: 100),
              requestTimeout: const Duration(seconds: 1),
            );
            final guardOk = healthSample['ok'] == true &&
                healthSample['runtime'] == 'native-node-embedded' &&
                healthSample['port'] == AppConstants.gatewayPort &&
                healthSample['productionPortBindCanary'] == true &&
                healthSample['openclawStarted'] == false &&
                probeSample['runtime'] == 'native-node-embedded' &&
                probeSample['port'] == AppConstants.gatewayPort &&
                probeSample['productionPortBindCanary'] == true &&
                probeSample['canaryOnly'] == true &&
                probeSample['productionReady'] == false &&
                probeSample['openclawStarted'] == false &&
                probeSample['chatRoutingEnabled'] == false &&
                probeSample['providerCallsEnabled'] == false &&
                probeSample['toolExecutionEnabled'] != true;
            final sample = <String, dynamic>{
              'second': second,
              'healthOk': healthSample['ok'] == true,
              'probeRuntime': probeSample['runtime'],
              'port': healthSample['port'],
              'canaryOnly': probeSample['canaryOnly'] == true,
              'openclawStarted': probeSample['openclawStarted'] == true,
              'chatRoutingEnabled': probeSample['chatRoutingEnabled'] == true,
              'providerCallsEnabled':
                  probeSample['providerCallsEnabled'] == true,
              'toolExecutionEnabled':
                  probeSample['toolExecutionEnabled'] == true,
              'guardOk': guardOk,
            };
            ownerProbeSamples.add(sample);
            if (!guardOk) {
              ownerProbeFailures.add(sample);
            }
          } catch (e) {
            ownerProbeFailures.add(<String, dynamic>{
              'second': second,
              'error': e.toString(),
            });
          }
        }
        nativeOwnerProbesOk =
            ownerProbeSamples.length == normalizedHoldSeconds &&
                ownerProbeFailures.isEmpty;
      } catch (e) {
        if (prootStopRequested || productionPortReleased || nativeStarted) {
          nativeError = e;
        } else {
          prootStopError = e;
        }
      } finally {
        try {
          nativeStopped = await ownerRuntime
              .stop()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          nativeStopError = e;
        }
        if (prootStopRequested || nativeStarted) {
          nativePortReleasedAfterStop = await _waitForProductionPortReleased(
            timeout: const Duration(seconds: 35),
          );
        } else {
          nativePortReleasedAfterStop = true;
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
              rollbackHealthOk =
                  _productionHealthLooksLikeProot(rollbackHealth);
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

      final nativeInitialGuardOk = nativeObservedAlive &&
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
          nativeInitialGuardOk &&
          nativeOwnerProbesOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-runtime-owner-canary',
        'mode': 'native-temporary-owner-with-automatic-rollback',
        'requestedHoldSeconds': requestedHoldSeconds,
        'holdSeconds': normalizedHoldSeconds,
        'activeRuntimeId': productionRuntime.id,
        'temporaryOwnerRuntimeId': ownerRuntime.id,
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
        'nativeInitialGuardOk': nativeInitialGuardOk,
        'nativeOwnerProbesOk': nativeOwnerProbesOk,
        'ownerProbeCount': ownerProbeSamples.length,
        'ownerProbeFailures': ownerProbeFailures,
        'ownerProbeSamples': ownerProbeSamples,
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
        'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
        'rollbackRuntimeId': 'proot',
        'rollbackStarted': rollbackStarted,
        'rollbackRunning': rollbackRunning,
        'rollbackHealthOk': rollbackHealthOk,
        'rollbackRuntimeReported': rollbackHealth['runtime'],
        if (rollbackError != null) 'rollbackError': rollbackError.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native held 18789 as a guarded temporary owner; PRoot was restored.'
            : 'Runtime-owner canary is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'native production-port route owner dry-run before any real provider or tool routing',
      };
      log('[NATIVE-OWNER-CANARY] ${jsonEncode(report)}');
      return report;
    } finally {
      _runtimeOwnerCanaryInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runProductionPortRouteOwnerDryRun({
    required void Function(String message) log,
  }) async {
    if (_productionPortRouteOwnerInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-route-owner-dry-run',
        'alreadyInFlight': true,
        'decision': 'Production-port route-owner dry-run is already running.',
      };
    }

    _productionPortRouteOwnerInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.current;
      final ownerRuntime = _productionPortRuntime;
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
      var routeDryRunSent = false;
      var routeAckOk = false;
      var routePlanOk = false;
      var routeProviderGateOk = false;
      var routeToolGateOk = false;
      var routeOrderOk = false;
      var routeEndOk = false;
      var routeDryRunOk = false;
      var postRouteGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postRouteHealth = <String, dynamic>{};
      Map<String, dynamic> postRouteProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> routeEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? routeError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-ROUTE-OWNER] Opening production-port route dry-run.');

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
          productionHealthOkBefore =
              _productionHealthLooksLikeProot(productionBefore);
        } catch (e) {
          productionBeforeError = e;
        }

        if (productionRuntime.id != 'proot') {
          throw StateError(
            'Route-owner dry-run requires PRoot as the current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before route dry-run.',
          );
        }

        log('[NATIVE-ROUTE-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before route dry-run.',
          );
        }

        log(
          '[NATIVE-ROUTE-OWNER] Starting native on 18789 and sending '
          'routing skeleton dry-run.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native route-owner dry-run did not start.');
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
        nativeRunning = await ownerRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);

        routeDryRunSent = true;
        routeEvents = await _streamProductionNdjson(
          '/gateway/chat-route-skeleton-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-route-owner-request',
            idempotencyKey: 'production-route-owner-idempotency-key',
          ),
          expectedStatus: 202,
        );

        final ackEvent = _firstEvent(routeEvents, 'ack');
        final routePlanEvent = _firstEvent(routeEvents, 'route_plan');
        final providerGateEvent = _firstEvent(routeEvents, 'provider_gate');
        final toolGateEvent = _firstEvent(routeEvents, 'tool_gate');
        final endEvent = _firstEvent(routeEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final routePlan = routePlanEvent['routePlan'] is Map
            ? Map<String, dynamic>.from(routePlanEvent['routePlan'] as Map)
            : <String, dynamic>{};
        final providerGate = providerGateEvent['gate'] is Map
            ? Map<String, dynamic>.from(providerGateEvent['gate'] as Map)
            : <String, dynamic>{};
        final toolGate = toolGateEvent['gate'] is Map
            ? Map<String, dynamic>.from(toolGateEvent['gate'] as Map)
            : <String, dynamic>{};
        final providerCallGate = routePlan['providerCallGate'] is Map
            ? Map<String, dynamic>.from(routePlan['providerCallGate'] as Map)
            : <String, dynamic>{};
        final toolExecutionGate = routePlan['toolExecutionGate'] is Map
            ? Map<String, dynamic>.from(routePlan['toolExecutionGate'] as Map)
            : <String, dynamic>{};
        final cancellation = routePlan['cancellation'] is Map
            ? Map<String, dynamic>.from(routePlan['cancellation'] as Map)
            : <String, dynamic>{};
        final observedOrder =
            routeEvents.map((event) => event['event']?.toString()).toList();
        const expectedOrder = <String>[
          'ack',
          'route_plan',
          'provider_gate',
          'tool_gate',
          'delta',
          'delta',
          'end',
        ];
        routeOrderOk = observedOrder.length >= expectedOrder.length;
        for (var i = 0; i < expectedOrder.length && routeOrderOk; i++) {
          routeOrderOk = observedOrder[i] == expectedOrder[i];
        }
        routeAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == true &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'disabled' &&
            ackEvent['routeStatus'] == 'blocked_before_provider' &&
            ackEvent['acceptedForRouting'] == false &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == true &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['providerCallsEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ack['routeStatus'] == 'blocked_before_provider' &&
            ack['providerCallsEnabled'] != true &&
            ack['executionEnabled'] != true;
        routePlanOk = routePlanEvent['ok'] == true &&
            routePlan['routeStatus'] == 'blocked_before_provider' &&
            routePlan['acceptedForRouting'] == false &&
            routePlan['chatRoutingEnabled'] == false &&
            providerCallGate['enabled'] == false &&
            toolExecutionGate['enabled'] == false &&
            cancellation['supported'] == true &&
            cancellation['endpoint'] == '/gateway/chat-route-skeleton-cancel';
        routeProviderGateOk = providerGateEvent['ok'] == true &&
            providerGateEvent['providerCallsEnabled'] == false &&
            providerGate['enabled'] == false &&
            providerGate['status'] == 'blocked';
        routeToolGateOk = toolGateEvent['ok'] == true &&
            toolGateEvent['executionEnabled'] == false &&
            toolGate['enabled'] == false &&
            toolGate['status'] == 'blocked';
        routeEndOk = endEvent['ok'] == true &&
            endEvent['finishReason'] == 'routing_skeleton_complete' &&
            endEvent['providerCallsEnabled'] == false &&
            endEvent['executionEnabled'] == false;
        routeDryRunOk = routeAckOk &&
            routePlanOk &&
            routeProviderGateOk &&
            routeToolGateOk &&
            routeOrderOk &&
            routeEndOk;

        postRouteHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postRouteProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postRouteGuardOk = postRouteHealth['ok'] == true &&
            postRouteHealth['runtime'] == 'native-node-embedded' &&
            postRouteHealth['port'] == AppConstants.gatewayPort &&
            postRouteHealth['productionPortBindCanary'] == true &&
            postRouteHealth['openclawStarted'] == false &&
            postRouteProbe['runtime'] == 'native-node-embedded' &&
            postRouteProbe['port'] == AppConstants.gatewayPort &&
            postRouteProbe['productionPortBindCanary'] == true &&
            postRouteProbe['canaryOnly'] == true &&
            postRouteProbe['productionReady'] == false &&
            postRouteProbe['openclawStarted'] == false &&
            postRouteProbe['chatRoutingEnabled'] == false &&
            postRouteProbe['providerCallsEnabled'] == false &&
            postRouteProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (routeDryRunSent) {
          routeError = e;
        } else if (prootStopRequested ||
            productionPortReleased ||
            nativeStarted) {
          nativeError = e;
        } else {
          prootStopError = e;
        }
      } finally {
        try {
          nativeStopped = await ownerRuntime
              .stop()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          nativeStopError = e;
        }
        if (prootStopRequested || nativeStarted) {
          nativePortReleasedAfterStop = await _waitForProductionPortReleased(
            timeout: const Duration(seconds: 35),
          );
        } else {
          nativePortReleasedAfterStop = true;
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
              rollbackHealthOk =
                  _productionHealthLooksLikeProot(rollbackHealth);
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

      final nativeInitialGuardOk = nativeObservedAlive &&
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
          nativeInitialGuardOk &&
          routeDryRunOk &&
          postRouteGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final observedOrder =
          routeEvents.map((event) => event['event']?.toString()).toList();
      final ackEvent = _firstEvent(routeEvents, 'ack');
      final routePlanEvent = _firstEvent(routeEvents, 'route_plan');
      final endEvent = _firstEvent(routeEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final routePlan = routePlanEvent['routePlan'] is Map
          ? Map<String, dynamic>.from(routePlanEvent['routePlan'] as Map)
          : <String, dynamic>{};

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-route-owner-dry-run',
        'mode': 'native-production-port-route-skeleton-with-rollback',
        'activeRuntimeId': productionRuntime.id,
        'temporaryOwnerRuntimeId': ownerRuntime.id,
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
        'nativeInitialGuardOk': nativeInitialGuardOk,
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
        'routeDryRunSent': routeDryRunSent,
        'routeDryRunOk': routeDryRunOk,
        'routeAckOk': routeAckOk,
        'routePlanOk': routePlanOk,
        'routeProviderGateOk': routeProviderGateOk,
        'routeToolGateOk': routeToolGateOk,
        'routeOrderOk': routeOrderOk,
        'routeEndOk': routeEndOk,
        'routeEventsCount': routeEvents.length,
        'routeObservedOrder': observedOrder,
        'routeStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'routePlanStatus': routePlan['routeStatus'],
        'routeFinishReason': endEvent['finishReason'],
        'routeAcceptedForRouting': ackEvent['acceptedForRouting'] == true,
        'routeProviderCallsEnabled': ackEvent['providerCallsEnabled'] == true,
        'routeExecutionEnabled': ackEvent['executionEnabled'] == true,
        'routeRunId': ack['runId'],
        'routeRequestId': ack['requestId'],
        if (routeError != null) 'routeError': routeError.toString(),
        'postRouteGuardOk': postRouteGuardOk,
        'postRouteRuntimeReported': postRouteHealth['runtime'],
        'postRouteCanaryOnly': postRouteProbe['canaryOnly'] == true,
        'postRouteChatRoutingEnabled':
            postRouteProbe['chatRoutingEnabled'] == true,
        'postRouteProviderCallsEnabled':
            postRouteProbe['providerCallsEnabled'] == true,
        'postRouteToolExecutionEnabled':
            postRouteProbe['toolExecutionEnabled'] == true,
        'nativeStopped': nativeStopped,
        if (nativeStopError != null)
          'nativeStopError': nativeStopError.toString(),
        'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
        'rollbackRuntimeId': 'proot',
        'rollbackStarted': rollbackStarted,
        'rollbackRunning': rollbackRunning,
        'rollbackHealthOk': rollbackHealthOk,
        'rollbackRuntimeReported': rollbackHealth['runtime'],
        if (rollbackError != null) 'rollbackError': rollbackError.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native owned 18789, accepted a route dry-run, blocked execution, and PRoot was restored.'
            : 'Production-port route owner dry-run is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'native production-port provider envelope dry-run with provider calls still disabled',
      };
      log('[NATIVE-ROUTE-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortRouteOwnerInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runProductionPortProviderEnvelopeDryRun({
    required void Function(String message) log,
  }) async {
    if (_productionPortProviderEnvelopeInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-envelope-dry-run',
        'alreadyInFlight': true,
        'decision':
            'Production-port provider envelope dry-run is already running.',
      };
    }

    _productionPortProviderEnvelopeInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.current;
      final ownerRuntime = _productionPortRuntime;
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
      var providerDryRunSent = false;
      var providerAckOk = false;
      var providerEnvelopeOk = false;
      var providerGateOk = false;
      var providerErrorContractOk = false;
      var providerOrderOk = false;
      var providerEndOk = false;
      var providerDryRunOk = false;
      var postProviderGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postProviderHealth = <String, dynamic>{};
      Map<String, dynamic> postProviderProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> providerEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? providerError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-PROVIDER-OWNER] Opening provider envelope dry-run.');

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
          productionHealthOkBefore =
              _productionHealthLooksLikeProot(productionBefore);
        } catch (e) {
          productionBeforeError = e;
        }

        if (productionRuntime.id != 'proot') {
          throw StateError(
            'Provider envelope dry-run requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before provider dry-run.',
          );
        }

        log('[NATIVE-PROVIDER-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before provider dry-run.',
          );
        }

        log(
          '[NATIVE-PROVIDER-OWNER] Starting native on 18789 and building '
          'provider envelope with outbound network disabled.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native provider envelope dry-run did not start.');
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
        nativeRunning = await ownerRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);

        providerDryRunSent = true;
        providerEvents = await _streamProductionNdjson(
          '/gateway/chat-provider-shell-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-provider-envelope-request',
            idempotencyKey: 'production-provider-envelope-idempotency-key',
            model: 'openrouter/auto',
            provider: 'openrouter',
          ),
          expectedStatus: 202,
        );

        final ackEvent = _firstEvent(providerEvents, 'ack');
        final envelopeEvent = _firstEvent(providerEvents, 'provider_envelope');
        final gateEvent = _firstEvent(providerEvents, 'provider_gate');
        final errorContractEvent =
            _firstEvent(providerEvents, 'provider_error_contract');
        final endEvent = _firstEvent(providerEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final envelope = envelopeEvent['envelope'] is Map
            ? Map<String, dynamic>.from(envelopeEvent['envelope'] as Map)
            : <String, dynamic>{};
        final gate = gateEvent['gate'] is Map
            ? Map<String, dynamic>.from(gateEvent['gate'] as Map)
            : <String, dynamic>{};
        final errorContract = errorContractEvent['errorContract'] is Map
            ? Map<String, dynamic>.from(
                errorContractEvent['errorContract'] as Map,
              )
            : <String, dynamic>{};
        final observedOrder =
            providerEvents.map((event) => event['event']?.toString()).toList();
        const expectedOrder = <String>[
          'ack',
          'provider_envelope',
          'provider_gate',
          'provider_error_contract',
          'delta',
          'delta',
          'end',
        ];
        providerOrderOk = observedOrder.length >= expectedOrder.length;
        for (var i = 0; i < expectedOrder.length && providerOrderOk; i++) {
          providerOrderOk = observedOrder[i] == expectedOrder[i];
        }

        final envelopeHash = envelope['envelopeHash']?.toString() ?? '';
        final errorFields = errorContract['fields'];
        providerAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == true &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'disabled' &&
            ackEvent['routeStatus'] == 'blocked_before_outbound_provider' &&
            ackEvent['acceptedForRouting'] == false &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == true &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['providerCallsEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['requestedModel'] == 'openrouter/auto' &&
            ack['transport'] == 'openai-compatible-chat-completions' &&
            ack['providerCallsEnabled'] != true &&
            ack['executionEnabled'] != true;
        providerEnvelopeOk = envelopeEvent['ok'] == true &&
            envelope['provider'] == 'openrouter' &&
            envelope['requestedModel'] == 'openrouter/auto' &&
            envelope['providerModel'] == 'openrouter/auto' &&
            envelope['transport'] == 'openai-compatible-chat-completions' &&
            envelope['method'] == 'POST' &&
            envelope['stream'] == true &&
            envelope['outboundNetworkEnabled'] == false &&
            envelope['authMaterialPresent'] == false &&
            envelopeHash.isNotEmpty;
        providerGateOk = gateEvent['ok'] == true &&
            gateEvent['providerCallsEnabled'] == false &&
            gate['enabled'] == false &&
            gate['status'] == 'blocked' &&
            gate['wouldCallProvider'] == 'openrouter';
        providerErrorContractOk = errorContractEvent['ok'] == true &&
            errorContractEvent['provider'] == 'openrouter' &&
            errorContract['rawProviderErrorForwarding'] == true &&
            errorFields is List &&
            errorFields.contains('rawError') &&
            errorFields.contains('normalizedError.message');
        providerEndOk = endEvent['ok'] == true &&
            endEvent['finishReason'] == 'provider_shell_complete' &&
            endEvent['provider'] == 'openrouter' &&
            endEvent['requestedModel'] == 'openrouter/auto' &&
            endEvent['providerCallsEnabled'] == false &&
            endEvent['executionEnabled'] == false;
        providerDryRunOk = providerAckOk &&
            providerEnvelopeOk &&
            providerGateOk &&
            providerErrorContractOk &&
            providerOrderOk &&
            providerEndOk;

        postProviderHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postProviderProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postProviderGuardOk = postProviderHealth['ok'] == true &&
            postProviderHealth['runtime'] == 'native-node-embedded' &&
            postProviderHealth['port'] == AppConstants.gatewayPort &&
            postProviderHealth['productionPortBindCanary'] == true &&
            postProviderHealth['openclawStarted'] == false &&
            postProviderProbe['runtime'] == 'native-node-embedded' &&
            postProviderProbe['port'] == AppConstants.gatewayPort &&
            postProviderProbe['productionPortBindCanary'] == true &&
            postProviderProbe['canaryOnly'] == true &&
            postProviderProbe['productionReady'] == false &&
            postProviderProbe['openclawStarted'] == false &&
            postProviderProbe['chatRoutingEnabled'] == false &&
            postProviderProbe['providerCallsEnabled'] == false &&
            postProviderProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (providerDryRunSent) {
          providerError = e;
        } else if (prootStopRequested ||
            productionPortReleased ||
            nativeStarted) {
          nativeError = e;
        } else {
          prootStopError = e;
        }
      } finally {
        try {
          nativeStopped = await ownerRuntime
              .stop()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          nativeStopError = e;
        }
        if (prootStopRequested || nativeStarted) {
          nativePortReleasedAfterStop = await _waitForProductionPortReleased(
            timeout: const Duration(seconds: 35),
          );
        } else {
          nativePortReleasedAfterStop = true;
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
              rollbackHealthOk =
                  _productionHealthLooksLikeProot(rollbackHealth);
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

      final nativeInitialGuardOk = nativeObservedAlive &&
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
          nativeInitialGuardOk &&
          providerDryRunOk &&
          postProviderGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final observedOrder =
          providerEvents.map((event) => event['event']?.toString()).toList();
      final ackEvent = _firstEvent(providerEvents, 'ack');
      final envelopeEvent = _firstEvent(providerEvents, 'provider_envelope');
      final gateEvent = _firstEvent(providerEvents, 'provider_gate');
      final endEvent = _firstEvent(providerEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final envelope = envelopeEvent['envelope'] is Map
          ? Map<String, dynamic>.from(envelopeEvent['envelope'] as Map)
          : <String, dynamic>{};
      final gate = gateEvent['gate'] is Map
          ? Map<String, dynamic>.from(gateEvent['gate'] as Map)
          : <String, dynamic>{};

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-provider-envelope-dry-run',
        'mode': 'native-production-port-provider-envelope-with-rollback',
        'activeRuntimeId': productionRuntime.id,
        'temporaryOwnerRuntimeId': ownerRuntime.id,
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
        'nativeInitialGuardOk': nativeInitialGuardOk,
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
        'providerDryRunSent': providerDryRunSent,
        'providerDryRunOk': providerDryRunOk,
        'providerAckOk': providerAckOk,
        'providerEnvelopeOk': providerEnvelopeOk,
        'providerGateOk': providerGateOk,
        'providerErrorContractOk': providerErrorContractOk,
        'providerOrderOk': providerOrderOk,
        'providerEndOk': providerEndOk,
        'providerEventsCount': providerEvents.length,
        'providerObservedOrder': observedOrder,
        'providerRouteStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'providerFinishReason': endEvent['finishReason'],
        'provider': envelope['provider'] ?? ack['provider'],
        'requestedModel': envelope['requestedModel'] ?? ack['requestedModel'],
        'providerModel': envelope['providerModel'],
        'transport': envelope['transport'] ?? ack['transport'],
        'envelopeHash': envelope['envelopeHash'] ?? ack['envelopeHash'],
        'outboundNetworkEnabled': envelope['outboundNetworkEnabled'] == true,
        'authMaterialPresent': envelope['authMaterialPresent'] == true,
        'providerGateEnabled': gate['enabled'] == true,
        'providerGateStatus': gate['status'],
        'providerAcceptedForRouting': ackEvent['acceptedForRouting'] == true,
        'providerCallsEnabled': ackEvent['providerCallsEnabled'] == true,
        'providerExecutionEnabled': ackEvent['executionEnabled'] == true,
        'providerRunId': ack['runId'],
        'providerRequestId': ack['requestId'],
        if (providerError != null) 'providerError': providerError.toString(),
        'postProviderGuardOk': postProviderGuardOk,
        'postProviderRuntimeReported': postProviderHealth['runtime'],
        'postProviderCanaryOnly': postProviderProbe['canaryOnly'] == true,
        'postProviderChatRoutingEnabled':
            postProviderProbe['chatRoutingEnabled'] == true,
        'postProviderCallsEnabled':
            postProviderProbe['providerCallsEnabled'] == true,
        'postProviderToolExecutionEnabled':
            postProviderProbe['toolExecutionEnabled'] == true,
        'nativeStopped': nativeStopped,
        if (nativeStopError != null)
          'nativeStopError': nativeStopError.toString(),
        'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
        'rollbackRuntimeId': 'proot',
        'rollbackStarted': rollbackStarted,
        'rollbackRunning': rollbackRunning,
        'rollbackHealthOk': rollbackHealthOk,
        'rollbackRuntimeReported': rollbackHealth['runtime'],
        if (rollbackError != null) 'rollbackError': rollbackError.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native owned 18789, built a provider envelope, blocked outbound network, and PRoot was restored.'
            : 'Production-port provider envelope dry-run is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'native production-port provider request builder dry-run before transport invocation',
      };
      log('[NATIVE-PROVIDER-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortProviderEnvelopeInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortProviderRequestBuilderDryRun({
    required void Function(String message) log,
  }) async {
    if (_productionPortProviderBuilderInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-request-builder-dry-run',
        'alreadyInFlight': true,
        'decision':
            'Production-port provider request builder dry-run is already running.',
      };
    }

    _productionPortProviderBuilderInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.current;
      final ownerRuntime = _productionPortRuntime;
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
      var builderDryRunSent = false;
      var builderAckOk = false;
      var providerRequestOk = false;
      var requestValidationOk = false;
      var transportGateOk = false;
      var providerErrorContractOk = false;
      var builderOrderOk = false;
      var builderEndOk = false;
      var builderDryRunOk = false;
      var postBuilderGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postBuilderHealth = <String, dynamic>{};
      Map<String, dynamic> postBuilderProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> builderEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? builderError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-BUILDER-OWNER] Opening provider request builder dry-run.');

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
          productionHealthOkBefore =
              _productionHealthLooksLikeProot(productionBefore);
        } catch (e) {
          productionBeforeError = e;
        }

        if (productionRuntime.id != 'proot') {
          throw StateError(
            'Provider request builder dry-run requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before request builder dry-run.',
          );
        }

        log('[NATIVE-BUILDER-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before request builder dry-run.',
          );
        }

        log(
          '[NATIVE-BUILDER-OWNER] Starting native on 18789 and normalizing '
          'provider request with transport disabled.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError(
            'Native provider request builder dry-run did not start.',
          );
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
        nativeRunning = await ownerRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);

        builderDryRunSent = true;
        builderEvents = await _streamProductionNdjson(
          '/gateway/chat-provider-request-builder-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-provider-builder-request',
            idempotencyKey: 'production-provider-builder-idempotency-key',
            model: 'openrouter/auto',
            provider: 'openrouter',
          ),
          expectedStatus: 202,
        );

        final ackEvent = _firstEvent(builderEvents, 'ack');
        final requestEvent = _firstEvent(builderEvents, 'provider_request');
        final validationEvent =
            _firstEvent(builderEvents, 'request_validation');
        final transportGateEvent = _firstEvent(builderEvents, 'transport_gate');
        final errorContractEvent =
            _firstEvent(builderEvents, 'provider_error_contract');
        final endEvent = _firstEvent(builderEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final requestBuilder = requestEvent['requestBuilder'] is Map
            ? Map<String, dynamic>.from(
                requestEvent['requestBuilder'] as Map,
              )
            : <String, dynamic>{};
        final headerValidation = validationEvent['headerValidation'] is Map
            ? Map<String, dynamic>.from(
                validationEvent['headerValidation'] as Map,
              )
            : <String, dynamic>{};
        final bodyValidation = validationEvent['bodyValidation'] is Map
            ? Map<String, dynamic>.from(
                validationEvent['bodyValidation'] as Map,
              )
            : <String, dynamic>{};
        final providerConfigStatus =
            validationEvent['providerConfigStatus'] is Map
                ? Map<String, dynamic>.from(
                    validationEvent['providerConfigStatus'] as Map,
                  )
                : <String, dynamic>{};
        final transportGate = transportGateEvent['gate'] is Map
            ? Map<String, dynamic>.from(transportGateEvent['gate'] as Map)
            : <String, dynamic>{};
        final errorContract = errorContractEvent['errorContract'] is Map
            ? Map<String, dynamic>.from(
                errorContractEvent['errorContract'] as Map,
              )
            : <String, dynamic>{};
        final observedOrder =
            builderEvents.map((event) => event['event']?.toString()).toList();
        const expectedOrder = <String>[
          'ack',
          'provider_request',
          'request_validation',
          'transport_gate',
          'provider_error_contract',
          'delta',
          'delta',
          'end',
        ];
        builderOrderOk = observedOrder.length >= expectedOrder.length;
        for (var i = 0; i < expectedOrder.length && builderOrderOk; i++) {
          builderOrderOk = observedOrder[i] == expectedOrder[i];
        }

        final headersHash = requestBuilder['headersHash']?.toString() ?? '';
        final bodyHash = requestBuilder['bodyHash']?.toString() ?? '';
        final requestHash = requestBuilder['requestHash']?.toString() ?? '';
        final errorFields = errorContract['fields'];
        builderAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == true &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'disabled' &&
            ackEvent['routeStatus'] == 'blocked_before_transport_invocation' &&
            ackEvent['acceptedForRouting'] == false &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == true &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['providerCallsEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ackEvent['transportInvocationEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['requestedModel'] == 'openrouter/auto' &&
            ack['transport'] == 'openai-compatible-chat-completions' &&
            ack['validationOk'] == true &&
            ack['transportInvocationEnabled'] == false &&
            ack['providerCallsEnabled'] != true &&
            ack['executionEnabled'] != true;
        providerRequestOk = requestEvent['ok'] == true &&
            requestBuilder['provider'] == 'openrouter' &&
            requestBuilder['requestedModel'] == 'openrouter/auto' &&
            requestBuilder['providerModel'] == 'openrouter/auto' &&
            requestBuilder['transport'] ==
                'openai-compatible-chat-completions' &&
            requestBuilder['method'] == 'POST' &&
            requestBuilder['outboundNetworkEnabled'] == false &&
            requestBuilder['transportInvocationEnabled'] == false &&
            requestBuilder['providerCallsEnabled'] == false &&
            requestBuilder['executionEnabled'] == false &&
            headersHash.isNotEmpty &&
            bodyHash.isNotEmpty &&
            requestHash.isNotEmpty &&
            requestBuilder['validationOk'] == true;
        requestValidationOk = validationEvent['ok'] == true &&
            validationEvent['validationOk'] == true &&
            headerValidation['contentTypeOk'] == true &&
            headerValidation['acceptOk'] == true &&
            headerValidation['forbiddenHeadersPresent'] == false &&
            headerValidation['rawSecretsPresent'] == false &&
            bodyValidation['modelPresent'] == true &&
            bodyValidation['messagesNormalized'] == true &&
            bodyValidation['rawPromptRedacted'] == true &&
            bodyValidation['streamMode'] == true &&
            providerConfigStatus['mode'] == 'shape_only' &&
            providerConfigStatus['apiKeyLoaded'] == false &&
            providerConfigStatus['endpointResolved'] == true &&
            providerConfigStatus['headersNormalized'] == true &&
            providerConfigStatus['bodyNormalized'] == true;
        transportGateOk = transportGateEvent['ok'] == true &&
            transportGateEvent['transportInvocationEnabled'] == false &&
            transportGateEvent['providerCallsEnabled'] == false &&
            transportGate['enabled'] == false &&
            transportGate['status'] == 'blocked' &&
            transportGate['blockedBefore'] == 'fetch_or_http_request';
        providerErrorContractOk = errorContractEvent['ok'] == true &&
            errorContractEvent['provider'] == 'openrouter' &&
            errorContract['rawProviderErrorForwarding'] == true &&
            errorFields is List &&
            errorFields.contains('rawError') &&
            errorFields.contains('normalizedError.message');
        builderEndOk = endEvent['ok'] == true &&
            endEvent['finishReason'] == 'provider_request_builder_complete' &&
            endEvent['provider'] == 'openrouter' &&
            endEvent['requestedModel'] == 'openrouter/auto' &&
            endEvent['validationOk'] == true &&
            endEvent['transportInvocationEnabled'] == false &&
            endEvent['providerCallsEnabled'] == false &&
            endEvent['executionEnabled'] == false;
        builderDryRunOk = builderAckOk &&
            providerRequestOk &&
            requestValidationOk &&
            transportGateOk &&
            providerErrorContractOk &&
            builderOrderOk &&
            builderEndOk;

        postBuilderHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postBuilderProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postBuilderGuardOk = postBuilderHealth['ok'] == true &&
            postBuilderHealth['runtime'] == 'native-node-embedded' &&
            postBuilderHealth['port'] == AppConstants.gatewayPort &&
            postBuilderHealth['productionPortBindCanary'] == true &&
            postBuilderHealth['openclawStarted'] == false &&
            postBuilderProbe['runtime'] == 'native-node-embedded' &&
            postBuilderProbe['port'] == AppConstants.gatewayPort &&
            postBuilderProbe['productionPortBindCanary'] == true &&
            postBuilderProbe['canaryOnly'] == true &&
            postBuilderProbe['productionReady'] == false &&
            postBuilderProbe['openclawStarted'] == false &&
            postBuilderProbe['chatRoutingEnabled'] == false &&
            postBuilderProbe['providerCallsEnabled'] == false &&
            postBuilderProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (builderDryRunSent) {
          builderError = e;
        } else if (prootStopRequested ||
            productionPortReleased ||
            nativeStarted) {
          nativeError = e;
        } else {
          prootStopError = e;
        }
      } finally {
        try {
          nativeStopped = await ownerRuntime
              .stop()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          nativeStopError = e;
        }
        if (prootStopRequested || nativeStarted) {
          nativePortReleasedAfterStop = await _waitForProductionPortReleased(
            timeout: const Duration(seconds: 35),
          );
        } else {
          nativePortReleasedAfterStop = true;
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
              rollbackHealthOk =
                  _productionHealthLooksLikeProot(rollbackHealth);
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

      final nativeInitialGuardOk = nativeObservedAlive &&
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
          nativeInitialGuardOk &&
          builderDryRunOk &&
          postBuilderGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final observedOrder =
          builderEvents.map((event) => event['event']?.toString()).toList();
      final ackEvent = _firstEvent(builderEvents, 'ack');
      final requestEvent = _firstEvent(builderEvents, 'provider_request');
      final validationEvent = _firstEvent(builderEvents, 'request_validation');
      final transportGateEvent = _firstEvent(builderEvents, 'transport_gate');
      final endEvent = _firstEvent(builderEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final requestBuilder = requestEvent['requestBuilder'] is Map
          ? Map<String, dynamic>.from(requestEvent['requestBuilder'] as Map)
          : <String, dynamic>{};
      final providerConfigStatus =
          validationEvent['providerConfigStatus'] is Map
              ? Map<String, dynamic>.from(
                  validationEvent['providerConfigStatus'] as Map,
                )
              : <String, dynamic>{};
      final transportGate = transportGateEvent['gate'] is Map
          ? Map<String, dynamic>.from(transportGateEvent['gate'] as Map)
          : <String, dynamic>{};

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-provider-request-builder-dry-run',
        'mode': 'native-production-port-provider-builder-with-rollback',
        'activeRuntimeId': productionRuntime.id,
        'temporaryOwnerRuntimeId': ownerRuntime.id,
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
        'nativeInitialGuardOk': nativeInitialGuardOk,
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
        'builderDryRunSent': builderDryRunSent,
        'builderDryRunOk': builderDryRunOk,
        'builderAckOk': builderAckOk,
        'providerRequestOk': providerRequestOk,
        'requestValidationOk': requestValidationOk,
        'transportGateOk': transportGateOk,
        'providerErrorContractOk': providerErrorContractOk,
        'builderOrderOk': builderOrderOk,
        'builderEndOk': builderEndOk,
        'builderEventsCount': builderEvents.length,
        'builderObservedOrder': observedOrder,
        'builderRouteStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'builderFinishReason': endEvent['finishReason'],
        'provider': requestBuilder['provider'] ?? ack['provider'],
        'requestedModel':
            requestBuilder['requestedModel'] ?? ack['requestedModel'],
        'providerModel': requestBuilder['providerModel'],
        'transport': requestBuilder['transport'] ?? ack['transport'],
        'headersHash': requestBuilder['headersHash'] ?? ack['headersHash'],
        'bodyHash': requestBuilder['bodyHash'] ?? ack['bodyHash'],
        'requestHash': requestBuilder['requestHash'] ?? ack['requestHash'],
        'validationOk': requestBuilder['validationOk'] == true ||
            validationEvent['validationOk'] == true,
        'providerConfigMode': providerConfigStatus['mode'],
        'apiKeyLoaded': providerConfigStatus['apiKeyLoaded'] == true,
        'outboundNetworkEnabled':
            requestBuilder['outboundNetworkEnabled'] == true,
        'transportInvocationEnabled':
            requestBuilder['transportInvocationEnabled'] == true ||
                ackEvent['transportInvocationEnabled'] == true,
        'transportGateEnabled': transportGate['enabled'] == true,
        'transportGateStatus': transportGate['status'],
        'transportBlockedBefore': transportGate['blockedBefore'],
        'builderAcceptedForRouting': ackEvent['acceptedForRouting'] == true,
        'builderProviderCallsEnabled': ackEvent['providerCallsEnabled'] == true,
        'builderExecutionEnabled': ackEvent['executionEnabled'] == true,
        'builderRunId': ack['runId'],
        'builderRequestId': ack['requestId'],
        if (builderError != null) 'builderError': builderError.toString(),
        'postBuilderGuardOk': postBuilderGuardOk,
        'postBuilderRuntimeReported': postBuilderHealth['runtime'],
        'postBuilderCanaryOnly': postBuilderProbe['canaryOnly'] == true,
        'postBuilderChatRoutingEnabled':
            postBuilderProbe['chatRoutingEnabled'] == true,
        'postBuilderProviderCallsEnabled':
            postBuilderProbe['providerCallsEnabled'] == true,
        'postBuilderToolExecutionEnabled':
            postBuilderProbe['toolExecutionEnabled'] == true,
        'nativeStopped': nativeStopped,
        if (nativeStopError != null)
          'nativeStopError': nativeStopError.toString(),
        'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
        'rollbackRuntimeId': 'proot',
        'rollbackStarted': rollbackStarted,
        'rollbackRunning': rollbackRunning,
        'rollbackHealthOk': rollbackHealthOk,
        'rollbackRuntimeReported': rollbackHealth['runtime'],
        if (rollbackError != null) 'rollbackError': rollbackError.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native owned 18789, normalized the provider request, blocked transport invocation, and PRoot was restored.'
            : 'Production-port provider request builder dry-run is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'native production-port transport shim dry-run before DNS/TLS/provider billing',
      };
      log('[NATIVE-BUILDER-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortProviderBuilderInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortProviderTransportShimDryRun({
    required void Function(String message) log,
  }) async {
    if (_productionPortProviderTransportInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-transport-shim-dry-run',
        'alreadyInFlight': true,
        'decision':
            'Production-port provider transport shim dry-run is already running.',
      };
    }

    _productionPortProviderTransportInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.current;
      final ownerRuntime = _productionPortRuntime;
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
      var transportDryRunSent = false;
      var transportAckOk = false;
      var transportShimOk = false;
      var abortContractOk = false;
      var transportGateOk = false;
      var shimValidationOk = false;
      var transportOrderOk = false;
      var transportEndOk = false;
      var transportDryRunOk = false;
      var postTransportGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postTransportHealth = <String, dynamic>{};
      Map<String, dynamic> postTransportProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> transportEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? transportError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-TRANSPORT-OWNER] Opening provider transport shim dry-run.');

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
          productionHealthOkBefore =
              _productionHealthLooksLikeProot(productionBefore);
        } catch (e) {
          productionBeforeError = e;
        }

        if (productionRuntime.id != 'proot') {
          throw StateError(
            'Provider transport shim dry-run requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before transport shim dry-run.',
          );
        }

        log('[NATIVE-TRANSPORT-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before transport shim dry-run.',
          );
        }

        log(
          '[NATIVE-TRANSPORT-OWNER] Starting native on 18789 and proving '
          'transport abort before DNS/TLS/provider billing.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError(
            'Native provider transport shim dry-run did not start.',
          );
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
        nativeRunning = await ownerRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);

        transportDryRunSent = true;
        transportEvents = await _streamProductionNdjson(
          '/gateway/chat-provider-transport-shim-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-provider-transport-request',
            idempotencyKey: 'production-provider-transport-idempotency-key',
            model: 'openrouter/auto',
            provider: 'openrouter',
          ),
          expectedStatus: 202,
        );

        final ackEvent = _firstEvent(transportEvents, 'ack');
        final shimEvent = _firstEvent(transportEvents, 'transport_shim');
        final abortEvent = _firstEvent(transportEvents, 'abort_contract');
        final gateEvent = _firstEvent(transportEvents, 'transport_gate');
        final validationEvent = _firstEvent(transportEvents, 'shim_validation');
        final endEvent = _firstEvent(transportEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final transportShim = shimEvent['transportShim'] is Map
            ? Map<String, dynamic>.from(shimEvent['transportShim'] as Map)
            : <String, dynamic>{};
        final transportObject = transportShim['transportObject'] is Map
            ? Map<String, dynamic>.from(
                transportShim['transportObject'] as Map,
              )
            : <String, dynamic>{};
        final abortContract = abortEvent['abortContract'] is Map
            ? Map<String, dynamic>.from(abortEvent['abortContract'] as Map)
            : <String, dynamic>{};
        final networkProbe = abortEvent['networkProbe'] is Map
            ? Map<String, dynamic>.from(abortEvent['networkProbe'] as Map)
            : <String, dynamic>{};
        final transportGate = gateEvent['gate'] is Map
            ? Map<String, dynamic>.from(gateEvent['gate'] as Map)
            : <String, dynamic>{};
        final shimValidation = validationEvent['shimValidation'] is Map
            ? Map<String, dynamic>.from(
                validationEvent['shimValidation'] as Map,
              )
            : <String, dynamic>{};
        final observedOrder =
            transportEvents.map((event) => event['event']?.toString()).toList();
        const expectedOrder = <String>[
          'ack',
          'transport_shim',
          'abort_contract',
          'transport_gate',
          'shim_validation',
          'delta',
          'delta',
          'end',
        ];
        transportOrderOk = observedOrder.length >= expectedOrder.length;
        for (var i = 0; i < expectedOrder.length && transportOrderOk; i++) {
          transportOrderOk = observedOrder[i] == expectedOrder[i];
        }

        final headersHash = transportShim['headersHash']?.toString() ?? '';
        final bodyHash = transportShim['bodyHash']?.toString() ?? '';
        final requestHash = transportShim['requestHash']?.toString() ?? '';
        final transportHash = transportShim['transportHash']?.toString() ?? '';
        transportAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == true &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'disabled' &&
            ackEvent['routeStatus'] == 'aborted_before_dns' &&
            ackEvent['acceptedForRouting'] == false &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == true &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['providerCallsEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ackEvent['transportInvocationEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['requestedModel'] == 'openrouter/auto' &&
            ack['transport'] == 'openai-compatible-chat-completions' &&
            ack['validationOk'] == true &&
            ack['abortStage'] == 'before_dns' &&
            ack['abortedLocally'] == true &&
            ack['dnsLookupStarted'] == false &&
            ack['tlsHandshakeStarted'] == false &&
            ack['socketOpened'] == false &&
            ack['requestBytesWritten'] == 0 &&
            ack['providerBillingSurfaceReached'] == false &&
            ack['transportInvocationEnabled'] == false &&
            ack['providerCallsEnabled'] != true &&
            ack['executionEnabled'] != true;
        transportShimOk = shimEvent['ok'] == true &&
            transportShim['provider'] == 'openrouter' &&
            transportShim['requestedModel'] == 'openrouter/auto' &&
            transportShim['providerModel'] == 'openrouter/auto' &&
            transportShim['transport'] ==
                'openai-compatible-chat-completions' &&
            transportShim['stopBefore'] == 'dns_tls_socket_or_fetch' &&
            transportShim['validationOk'] == true &&
            headersHash.isNotEmpty &&
            bodyHash.isNotEmpty &&
            requestHash.isNotEmpty &&
            transportHash.isNotEmpty &&
            transportObject['adapter'] == 'native-node-fetch-compatible-shim' &&
            transportObject['method'] == 'POST' &&
            transportObject['streamExpected'] == true &&
            transportObject['outboundNetworkEnabled'] == false &&
            transportObject['transportInvocationEnabled'] == false &&
            transportObject['providerCallsEnabled'] == false &&
            transportObject['executionEnabled'] == false;
        abortContractOk = abortEvent['ok'] == true &&
            abortContract['abortControllerCreated'] == true &&
            abortContract['signalAttached'] == true &&
            abortContract['abortedLocally'] == true &&
            abortContract['abortStage'] == 'before_dns' &&
            networkProbe['dnsLookupStarted'] == false &&
            networkProbe['tlsHandshakeStarted'] == false &&
            networkProbe['socketOpened'] == false &&
            networkProbe['requestBytesWritten'] == 0 &&
            networkProbe['responseBytesRead'] == 0 &&
            networkProbe['providerBillingSurfaceReached'] == false;
        transportGateOk = gateEvent['ok'] == true &&
            gateEvent['transportInvocationEnabled'] == false &&
            gateEvent['providerCallsEnabled'] == false &&
            transportGate['enabled'] == false &&
            transportGate['status'] == 'aborted_locally' &&
            transportGate['blockedBefore'] == 'dns_lookup';
        shimValidationOk = validationEvent['ok'] == true &&
            validationEvent['validationOk'] == true &&
            shimValidation['adapterSelected'] == true &&
            shimValidation['endpointResolved'] == true &&
            shimValidation['signalAttached'] == true &&
            shimValidation['abortedBeforeDns'] == true &&
            shimValidation['noSocketOpened'] == true &&
            shimValidation['noBytesWritten'] == true &&
            shimValidation['billingSurfaceUnreached'] == true;
        transportEndOk = endEvent['ok'] == true &&
            endEvent['finishReason'] == 'provider_transport_shim_complete' &&
            endEvent['provider'] == 'openrouter' &&
            endEvent['requestedModel'] == 'openrouter/auto' &&
            endEvent['validationOk'] == true &&
            endEvent['transportInvocationEnabled'] == false &&
            endEvent['providerCallsEnabled'] == false &&
            endEvent['executionEnabled'] == false;
        transportDryRunOk = transportAckOk &&
            transportShimOk &&
            abortContractOk &&
            transportGateOk &&
            shimValidationOk &&
            transportOrderOk &&
            transportEndOk;

        postTransportHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postTransportProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postTransportGuardOk = postTransportHealth['ok'] == true &&
            postTransportHealth['runtime'] == 'native-node-embedded' &&
            postTransportHealth['port'] == AppConstants.gatewayPort &&
            postTransportHealth['productionPortBindCanary'] == true &&
            postTransportHealth['openclawStarted'] == false &&
            postTransportProbe['runtime'] == 'native-node-embedded' &&
            postTransportProbe['port'] == AppConstants.gatewayPort &&
            postTransportProbe['productionPortBindCanary'] == true &&
            postTransportProbe['canaryOnly'] == true &&
            postTransportProbe['productionReady'] == false &&
            postTransportProbe['openclawStarted'] == false &&
            postTransportProbe['chatRoutingEnabled'] == false &&
            postTransportProbe['providerCallsEnabled'] == false &&
            postTransportProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (transportDryRunSent) {
          transportError = e;
        } else if (prootStopRequested ||
            productionPortReleased ||
            nativeStarted) {
          nativeError = e;
        } else {
          prootStopError = e;
        }
      } finally {
        try {
          nativeStopped = await ownerRuntime
              .stop()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          nativeStopError = e;
        }
        if (prootStopRequested || nativeStarted) {
          nativePortReleasedAfterStop = await _waitForProductionPortReleased(
            timeout: const Duration(seconds: 35),
          );
        } else {
          nativePortReleasedAfterStop = true;
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
              rollbackHealthOk =
                  _productionHealthLooksLikeProot(rollbackHealth);
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

      final nativeInitialGuardOk = nativeObservedAlive &&
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
          nativeInitialGuardOk &&
          transportDryRunOk &&
          postTransportGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final observedOrder =
          transportEvents.map((event) => event['event']?.toString()).toList();
      final ackEvent = _firstEvent(transportEvents, 'ack');
      final shimEvent = _firstEvent(transportEvents, 'transport_shim');
      final abortEvent = _firstEvent(transportEvents, 'abort_contract');
      final gateEvent = _firstEvent(transportEvents, 'transport_gate');
      final validationEvent = _firstEvent(transportEvents, 'shim_validation');
      final endEvent = _firstEvent(transportEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final transportShim = shimEvent['transportShim'] is Map
          ? Map<String, dynamic>.from(shimEvent['transportShim'] as Map)
          : <String, dynamic>{};
      final abortContract = abortEvent['abortContract'] is Map
          ? Map<String, dynamic>.from(abortEvent['abortContract'] as Map)
          : <String, dynamic>{};
      final networkProbe = abortEvent['networkProbe'] is Map
          ? Map<String, dynamic>.from(abortEvent['networkProbe'] as Map)
          : <String, dynamic>{};
      final transportGate = gateEvent['gate'] is Map
          ? Map<String, dynamic>.from(gateEvent['gate'] as Map)
          : <String, dynamic>{};
      final shimValidation = validationEvent['shimValidation'] is Map
          ? Map<String, dynamic>.from(
              validationEvent['shimValidation'] as Map,
            )
          : <String, dynamic>{};

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-provider-transport-shim-dry-run',
        'mode': 'native-production-port-provider-transport-with-rollback',
        'activeRuntimeId': productionRuntime.id,
        'temporaryOwnerRuntimeId': ownerRuntime.id,
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
        'nativeInitialGuardOk': nativeInitialGuardOk,
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
        'transportDryRunSent': transportDryRunSent,
        'transportDryRunOk': transportDryRunOk,
        'transportAckOk': transportAckOk,
        'transportShimOk': transportShimOk,
        'abortContractOk': abortContractOk,
        'transportGateOk': transportGateOk,
        'shimValidationOk': shimValidationOk,
        'transportOrderOk': transportOrderOk,
        'transportEndOk': transportEndOk,
        'transportEventsCount': transportEvents.length,
        'transportObservedOrder': observedOrder,
        'transportRouteStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'transportFinishReason': endEvent['finishReason'],
        'provider': transportShim['provider'] ?? ack['provider'],
        'requestedModel':
            transportShim['requestedModel'] ?? ack['requestedModel'],
        'providerModel': transportShim['providerModel'],
        'transport': transportShim['transport'] ?? ack['transport'],
        'headersHash': transportShim['headersHash'] ?? ack['headersHash'],
        'bodyHash': transportShim['bodyHash'] ?? ack['bodyHash'],
        'requestHash': transportShim['requestHash'] ?? ack['requestHash'],
        'transportHash': transportShim['transportHash'] ?? ack['transportHash'],
        'validationOk': transportShim['validationOk'] == true ||
            validationEvent['validationOk'] == true,
        'abortStage': abortContract['abortStage'] ?? ack['abortStage'],
        'abortedLocally': abortContract['abortedLocally'] == true ||
            ack['abortedLocally'] == true,
        'dnsLookupStarted': networkProbe['dnsLookupStarted'] == true ||
            ack['dnsLookupStarted'] == true,
        'tlsHandshakeStarted': networkProbe['tlsHandshakeStarted'] == true ||
            ack['tlsHandshakeStarted'] == true,
        'socketOpened':
            networkProbe['socketOpened'] == true || ack['socketOpened'] == true,
        'requestBytesWritten':
            networkProbe['requestBytesWritten'] ?? ack['requestBytesWritten'],
        'responseBytesRead': networkProbe['responseBytesRead'],
        'providerBillingSurfaceReached':
            networkProbe['providerBillingSurfaceReached'] == true ||
                ack['providerBillingSurfaceReached'] == true,
        'shimAdapterSelected': shimValidation['adapterSelected'] == true,
        'shimEndpointResolved': shimValidation['endpointResolved'] == true,
        'outboundNetworkEnabled': false,
        'transportInvocationEnabled':
            transportShim['transportInvocationEnabled'] == true ||
                ackEvent['transportInvocationEnabled'] == true,
        'transportGateEnabled': transportGate['enabled'] == true,
        'transportGateStatus': transportGate['status'],
        'transportBlockedBefore': transportGate['blockedBefore'],
        'transportAcceptedForRouting': ackEvent['acceptedForRouting'] == true,
        'transportProviderCallsEnabled':
            ackEvent['providerCallsEnabled'] == true,
        'transportExecutionEnabled': ackEvent['executionEnabled'] == true,
        'transportRunId': ack['runId'],
        'transportRequestId': ack['requestId'],
        if (transportError != null) 'transportError': transportError.toString(),
        'postTransportGuardOk': postTransportGuardOk,
        'postTransportRuntimeReported': postTransportHealth['runtime'],
        'postTransportCanaryOnly': postTransportProbe['canaryOnly'] == true,
        'postTransportChatRoutingEnabled':
            postTransportProbe['chatRoutingEnabled'] == true,
        'postTransportProviderCallsEnabled':
            postTransportProbe['providerCallsEnabled'] == true,
        'postTransportToolExecutionEnabled':
            postTransportProbe['toolExecutionEnabled'] == true,
        'nativeStopped': nativeStopped,
        if (nativeStopError != null)
          'nativeStopError': nativeStopError.toString(),
        'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
        'rollbackRuntimeId': 'proot',
        'rollbackStarted': rollbackStarted,
        'rollbackRunning': rollbackRunning,
        'rollbackHealthOk': rollbackHealthOk,
        'rollbackRuntimeReported': rollbackHealth['runtime'],
        if (rollbackError != null) 'rollbackError': rollbackError.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native owned 18789, constructed the provider transport shim, aborted before DNS/TLS/provider billing, and PRoot was restored.'
            : 'Production-port provider transport shim dry-run is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'native production-port bounded live provider canary with explicit provider calls toggle',
      };
      log('[NATIVE-TRANSPORT-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortProviderTransportInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runProductionPortProviderLiveCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String prompt = 'native production provider live canary',
  }) async {
    if (_productionPortProviderLiveInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-live-canary',
        'alreadyInFlight': true,
        'decision': 'Production-port provider live canary is already running.',
      };
    }

    _productionPortProviderLiveInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.current;
      final ownerRuntime = _productionPortRuntime;
      final providerConfigForNative = Map<String, dynamic>.from(providerConfig);
      final providerHint =
          providerConfigForNative['provider']?.toString().trim();
      final providerModel = providerConfigForNative['model']?.toString().trim();
      final apiKeyLoaded =
          providerConfigForNative['apiKey']?.toString().trim().isNotEmpty ==
              true;
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
      var liveCanarySent = false;
      var liveAckOk = false;
      var providerRequestOk = false;
      var providerGateOk = false;
      var providerCallStartedOk = false;
      var providerResponseOk = false;
      var providerErrorSurfaceOk = false;
      var liveOrderOk = false;
      var liveEndOk = false;
      var liveSuccessOk = false;
      var liveCanaryOk = false;
      var postLiveGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postLiveHealth = <String, dynamic>{};
      Map<String, dynamic> postLiveProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> liveEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? liveError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-LIVE-OWNER] Opening bounded provider live canary.');

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
          productionHealthOkBefore =
              _productionHealthLooksLikeProot(productionBefore);
        } catch (e) {
          productionBeforeError = e;
        }

        if (productionRuntime.id != 'proot') {
          throw StateError(
            'Provider live canary requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before live provider canary.',
          );
        }

        log('[NATIVE-LIVE-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before live provider canary.',
          );
        }

        log(
          '[NATIVE-LIVE-OWNER] Starting native on 18789 for one bounded '
          'provider call.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native provider live canary did not start.');
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
        nativeRunning = await ownerRuntime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false)
            .catchError((_) => false);

        liveCanarySent = true;
        liveEvents = await _streamProductionNdjson(
          '/gateway/chat-provider-live-canary-stream',
          {
            ..._sampleGatewayWsChatSendFrame(
              requestId: 'production-provider-live-request',
              idempotencyKey: 'production-provider-live-idempotency-key',
              model: providerHint == null || providerHint.isEmpty
                  ? null
                  : '$providerHint/$providerModel',
              provider: providerHint,
              message: prompt,
            ),
            'nativeCanaryProviderConfig': providerConfigForNative,
          },
          expectedStatus: 202,
          streamIdleTimeout: const Duration(seconds: 70),
        );

        final ackEvent = _firstEvent(liveEvents, 'ack');
        final requestEvent = _firstEvent(liveEvents, 'provider_request');
        final gateEvent = _firstEvent(liveEvents, 'provider_gate');
        final callStartedEvent =
            _firstEvent(liveEvents, 'provider_call_started');
        final responseEvent = _firstEvent(liveEvents, 'provider_response');
        final providerErrorEvent = _firstEvent(liveEvents, 'provider_error');
        final endEvent = _firstEvent(liveEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final providerRequest = requestEvent['providerRequest'] is Map
            ? Map<String, dynamic>.from(
                requestEvent['providerRequest'] as Map,
              )
            : <String, dynamic>{};
        final gate = gateEvent['gate'] is Map
            ? Map<String, dynamic>.from(gateEvent['gate'] as Map)
            : <String, dynamic>{};
        final rawProviderError =
            providerErrorEvent['rawProviderError']?.toString() ??
                (providerErrorEvent['error'] is Map
                    ? (providerErrorEvent['error'] as Map)['raw']?.toString()
                    : null) ??
                '';
        final deltaEvents =
            liveEvents.where((event) => event['event'] == 'delta').toList();
        final observedOrder =
            liveEvents.map((event) => event['event']?.toString()).toList();
        final firstEvents = observedOrder.take(4).toList();
        liveOrderOk = firstEvents.length >= 2 &&
            firstEvents[0] == 'ack' &&
            firstEvents[1] == 'provider_request' &&
            (firstEvents.length < 3 ||
                firstEvents[2] == 'provider_call_started' ||
                firstEvents[2] == 'provider_gate');

        final maxTokens = providerRequest['maxTokens'];
        final requestBodyBytes = providerRequest['requestBodyBytes'];
        liveAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['validationOk'] == true &&
            ack['maxTokens'] is num &&
            (ack['maxTokens'] as num) <= 32 &&
            ack['requestBodyBytes'] is num &&
            (ack['requestBodyBytes'] as num) > 0;
        providerRequestOk = requestEvent['ok'] == true &&
            providerRequest['provider'] == 'openrouter' &&
            providerRequest['transport'] ==
                'openai-compatible-chat-completions' &&
            providerRequest['transportInvocationEnabled'] == true &&
            providerRequest['providerCallsEnabled'] == true &&
            maxTokens is num &&
            maxTokens <= 32 &&
            requestBodyBytes is num &&
            requestBodyBytes > 0 &&
            providerRequest['requestHash']?.toString().isNotEmpty == true;
        providerGateOk = gateEvent.isEmpty ||
            (gateEvent['ok'] == false &&
                gate['enabled'] == false &&
                gate['blockedBefore'] == 'fetch' &&
                gateEvent['transportInvocationEnabled'] == false &&
                gateEvent['providerCallsEnabled'] == false);
        providerCallStartedOk = callStartedEvent['ok'] == true &&
            callStartedEvent['provider'] == 'openrouter' &&
            callStartedEvent['providerCallStarted'] == true &&
            callStartedEvent['providerBillingSurfaceReached'] == true &&
            callStartedEvent['requestBodyBytes'] is num &&
            (callStartedEvent['requestBodyBytes'] as num) > 0;
        providerResponseOk =
            responseEvent['runtime'] == 'native-node-embedded' &&
                responseEvent['provider'] == 'openrouter' &&
                responseEvent['statusCode'] is num;
        providerErrorSurfaceOk = providerErrorEvent.isNotEmpty &&
            providerErrorEvent['runtime'] == 'native-node-embedded' &&
            providerErrorEvent['provider'] == 'openrouter' &&
            rawProviderError.isNotEmpty &&
            providerErrorEvent['error'] is Map;
        liveEndOk = endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['providerCallsEnabled'] == true &&
            endEvent['executionEnabled'] == false &&
            endEvent['finishReason'] != null;
        liveSuccessOk = liveEndOk &&
            endEvent['ok'] == true &&
            endEvent['statusCode'] == 200 &&
            deltaEvents.isNotEmpty &&
            endEvent['textChars'] is num &&
            (endEvent['textChars'] as num) > 0;
        liveCanaryOk = liveAckOk &&
            providerRequestOk &&
            providerGateOk &&
            providerCallStartedOk &&
            (providerResponseOk || providerErrorSurfaceOk) &&
            liveOrderOk &&
            liveEndOk &&
            (liveSuccessOk || providerErrorSurfaceOk);

        postLiveHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postLiveProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postLiveGuardOk = postLiveHealth['ok'] == true &&
            postLiveHealth['runtime'] == 'native-node-embedded' &&
            postLiveHealth['port'] == AppConstants.gatewayPort &&
            postLiveHealth['productionPortBindCanary'] == true &&
            postLiveHealth['openclawStarted'] == false &&
            postLiveProbe['runtime'] == 'native-node-embedded' &&
            postLiveProbe['port'] == AppConstants.gatewayPort &&
            postLiveProbe['productionPortBindCanary'] == true &&
            postLiveProbe['canaryOnly'] == true &&
            postLiveProbe['productionReady'] == false &&
            postLiveProbe['openclawStarted'] == false &&
            postLiveProbe['chatRoutingEnabled'] == false &&
            postLiveProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (liveCanarySent) {
          liveError = e;
        } else if (prootStopRequested ||
            productionPortReleased ||
            nativeStarted) {
          nativeError = e;
        } else {
          prootStopError = e;
        }
      } finally {
        try {
          nativeStopped = await ownerRuntime
              .stop()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          nativeStopError = e;
        }
        if (prootStopRequested || nativeStarted) {
          nativePortReleasedAfterStop = await _waitForProductionPortReleased(
            timeout: const Duration(seconds: 35),
          );
        } else {
          nativePortReleasedAfterStop = true;
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
              rollbackHealthOk =
                  _productionHealthLooksLikeProot(rollbackHealth);
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

      final nativeInitialGuardOk = nativeObservedAlive &&
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
          nativeProbe['toolExecutionEnabled'] != true;
      final rollbackOk = rollbackStarted && rollbackRunning && rollbackHealthOk;
      final ok = productionRuntime.id == 'proot' &&
          preflightProductionRunning &&
          productionHealthOkBefore &&
          prootStopRequested &&
          productionPortReleased &&
          nativeStarted &&
          nativeInitialGuardOk &&
          liveCanaryOk &&
          postLiveGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final observedOrder =
          liveEvents.map((event) => event['event']?.toString()).toList();
      final ackEvent = _firstEvent(liveEvents, 'ack');
      final requestEvent = _firstEvent(liveEvents, 'provider_request');
      final callStartedEvent = _firstEvent(liveEvents, 'provider_call_started');
      final responseEvent = _firstEvent(liveEvents, 'provider_response');
      final providerErrorEvent = _firstEvent(liveEvents, 'provider_error');
      final endEvent = _firstEvent(liveEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final providerRequest = requestEvent['providerRequest'] is Map
          ? Map<String, dynamic>.from(requestEvent['providerRequest'] as Map)
          : <String, dynamic>{};
      final rawProviderError =
          providerErrorEvent['rawProviderError']?.toString() ??
              (providerErrorEvent['error'] is Map
                  ? (providerErrorEvent['error'] as Map)['raw']?.toString()
                  : null) ??
              '';
      final deltaEvents =
          liveEvents.where((event) => event['event'] == 'delta').toList();

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-provider-live-canary',
        'mode': 'native-production-port-provider-live-with-rollback',
        'activeRuntimeId': productionRuntime.id,
        'temporaryOwnerRuntimeId': ownerRuntime.id,
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
        'nativeInitialGuardOk': nativeInitialGuardOk,
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
        'liveCanarySent': liveCanarySent,
        'liveCanaryOk': liveCanaryOk,
        'liveSuccessOk': liveSuccessOk,
        'liveAckOk': liveAckOk,
        'providerRequestOk': providerRequestOk,
        'providerGateOk': providerGateOk,
        'providerCallStartedOk': providerCallStartedOk,
        'providerResponseOk': providerResponseOk,
        'providerErrorSurfaceOk': providerErrorSurfaceOk,
        'liveOrderOk': liveOrderOk,
        'liveEndOk': liveEndOk,
        'liveEventsCount': liveEvents.length,
        'liveObservedOrder': observedOrder,
        'liveRouteStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'liveFinishReason': endEvent['finishReason'],
        'provider': providerRequest['provider'] ?? ack['provider'],
        'requestedModel':
            providerRequest['requestedModel'] ?? ack['requestedModel'],
        'providerModel':
            providerRequest['providerModel'] ?? ack['providerModel'],
        'transport': providerRequest['transport'] ?? ack['transport'],
        'requestHash': providerRequest['requestHash'] ?? ack['requestHash'],
        'maxTokens': providerRequest['maxTokens'] ?? ack['maxTokens'],
        'promptChars': providerRequest['promptChars'] ?? ack['promptChars'],
        'requestBodyBytes':
            providerRequest['requestBodyBytes'] ?? ack['requestBodyBytes'],
        'apiKeyLoaded': apiKeyLoaded,
        'providerCallStarted': callStartedEvent['providerCallStarted'] == true,
        'providerBillingSurfaceReached':
            callStartedEvent['providerBillingSurfaceReached'] == true,
        'statusCode': responseEvent['statusCode'] ?? endEvent['statusCode'],
        'contentType': responseEvent['contentType'],
        'firstByteMs': responseEvent['firstByteMs'],
        'firstTokenMs': endEvent['firstTokenMs'],
        'durationMsProvider': endEvent['durationMs'],
        'textChars': endEvent['textChars'],
        'deltaCount': deltaEvents.length,
        'rawProviderErrorForwarded': rawProviderError.isNotEmpty,
        if (rawProviderError.isNotEmpty)
          'rawProviderErrorPreview': rawProviderError.length > 500
              ? rawProviderError.substring(0, 500)
              : rawProviderError,
        if (liveError != null) 'liveError': liveError.toString(),
        'postLiveGuardOk': postLiveGuardOk,
        'postLiveRuntimeReported': postLiveHealth['runtime'],
        'postLiveCanaryOnly': postLiveProbe['canaryOnly'] == true,
        'postLiveChatRoutingEnabled':
            postLiveProbe['chatRoutingEnabled'] == true,
        'postLiveProviderCallsEnabled':
            postLiveProbe['providerCallsEnabled'] == true,
        'postLiveToolExecutionEnabled':
            postLiveProbe['toolExecutionEnabled'] == true,
        'nativeStopped': nativeStopped,
        if (nativeStopError != null)
          'nativeStopError': nativeStopError.toString(),
        'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
        'rollbackRuntimeId': 'proot',
        'rollbackStarted': rollbackStarted,
        'rollbackRunning': rollbackRunning,
        'rollbackHealthOk': rollbackHealthOk,
        'rollbackRuntimeReported': rollbackHealth['runtime'],
        if (rollbackError != null) 'rollbackError': rollbackError.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? (liveSuccessOk
                ? 'Native owned 18789, completed one bounded provider stream, and PRoot was restored.'
                : 'Native owned 18789, reached provider and forwarded the raw provider error, and PRoot was restored.')
            : 'Production-port provider live canary is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'production-port stream parser and cancellation parity under native owner',
      };
      log('[NATIVE-LIVE-OWNER] ${jsonEncode({
            ...report,
            'rawProviderErrorPreview':
                rawProviderError.isEmpty ? null : '<redacted in activity log>',
          })}');
      return report;
    } finally {
      _productionPortProviderLiveInFlight = false;
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
    String? model,
    String? provider,
    String? message,
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

    final params = <String, dynamic>{
      'sessionKey': 'main',
      'message': (message != null && message.trim().isNotEmpty)
          ? message.trim()
          : mobileContext,
      'idempotencyKey': idempotencyKey,
      'timeoutMs': 300000,
    };
    if (model != null && model.trim().isNotEmpty) {
      params['model'] = model.trim();
    }
    if (provider != null && provider.trim().isNotEmpty) {
      params['provider'] = provider.trim();
    }

    return {
      'type': 'req',
      'method': 'chat.send',
      'id': requestId,
      'params': params,
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

  static Map<String, dynamic> _firstEvent(
    List<Map<String, dynamic>> events,
    String eventName,
  ) {
    for (final event in events) {
      if (event['event'] == eventName) return event;
    }
    return <String, dynamic>{};
  }

  static bool _productionHealthLooksLikeProot(Map<String, dynamic> health) {
    if (health.isEmpty) return false;
    if (health['runtime'] == 'native-node-embedded') return false;
    if (health['productionPortBindCanary'] == true) return false;
    return health['ok'] == true ||
        health['status'] == 'ok' ||
        health['status'] == 'live' ||
        health.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> _streamProductionNdjson(
    String path,
    Map<String, dynamic> payload, {
    required int expectedStatus,
    Duration streamIdleTimeout = const Duration(seconds: 12),
  }) async {
    final client = http.Client();
    try {
      final normalizedPath = path.startsWith('/') ? path : '/$path';
      final request = http.Request(
        'POST',
        Uri.parse('${AppConstants.gatewayUrl}$normalizedPath'),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(payload);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 2500));
      if (response.statusCode != expectedStatus) {
        final body = await response.stream.bytesToString();
        throw StateError('HTTP ${response.statusCode}: $body');
      }

      final events = <Map<String, dynamic>>[];
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(streamIdleTimeout)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          events.add(decoded);
        }
      }
      return events;
    } finally {
      client.close();
    }
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

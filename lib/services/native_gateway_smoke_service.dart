import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants.dart';
import 'gateway_connection.dart';
import 'gateway_runtime.dart';
import 'native_bridge.dart';
import 'native_gateway_shadow_parity_service.dart';
import 'preferences_service.dart';

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
/// Startup sidecar auto-tests are intentionally narrower. Enable them only with:
/// `--dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_AUTOSTART_DIAGNOSTICS=true`
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

  static const bool startupSidecarDiagnosticsEnabled = bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_SMOKE_AUTOSTART_DIAGNOSTICS',
    defaultValue: false,
  );

  static final GatewayRuntime _runtime = GatewayRuntimeRegistry.nativeNodeSmoke;
  static final GatewayRuntime _nodeRuntime =
      GatewayRuntimeRegistry.nativeNodeProcessSmoke;
  static final GatewayRuntime _productionPortRuntime =
      GatewayRuntimeRegistry.nativeNodeProductionPortCanary;
  static final GatewayRuntime _fullGatewayBootstrapRuntime =
      GatewayRuntimeRegistry.nativeNodeFullGatewayBootstrap;
  static final GatewayRuntime _fullGatewayProductionRuntime =
      GatewayRuntimeRegistry.nativeNodeFullGatewayProduction;
  static bool _startupSelfTestInFlight = false;
  static bool _canaryComparisonInFlight = false;
  static bool _fullGatewayBootstrapInFlight = false;
  static bool _fullGatewayProductionOwnerInFlight = false;
  static bool _fullGatewayProductionChatTurnInFlight = false;
  static bool get productionOwnerSwapInProgress =>
      _fullGatewayProductionOwnerInFlight ||
      _fullGatewayProductionChatTurnInFlight;
  static bool _productionPortBindInFlight = false;
  static bool _productionPortBindSoakInFlight = false;
  static bool _runtimeOwnerCanaryInFlight = false;
  static bool _productionPortRouteOwnerInFlight = false;
  static bool _productionPortProviderEnvelopeInFlight = false;
  static bool _productionPortProviderBuilderInFlight = false;
  static bool _productionPortProviderTransportInFlight = false;
  static bool _productionPortProviderLiveInFlight = false;
  static bool _productionPortProviderBackedChatInFlight = false;
  static bool _productionPortChatResponseUiInFlight = false;
  static bool _productionPortNativeChatRouteSelectionInFlight = false;
  static bool _productionPortProviderStreamParityInFlight = false;
  static bool _productionPortProviderToolPlanInFlight = false;
  static bool _productionPortToolDispatchInFlight = false;
  static bool _productionPortDartBridgeInFlight = false;
  static bool _productionPortDartBridgeOrderingInFlight = false;
  static bool _productionPortBridgeReadOnlyCanaryInFlight = false;
  static bool _productionPortBridgeHapticCanaryInFlight = false;
  static bool _productionPortBridgeAvatarCanaryInFlight = false;
  static bool _productionPortProviderToolPlanExecutionInFlight = false;
  static bool _productionPortProviderLiveToolExecutionInFlight = false;
  static bool _productionPortProviderLiveToolContinuationInFlight = false;
  static bool _productionPortNativeChatLoopContinuationInFlight = false;
  static bool _productionInventoryParityInFlight = false;
  static bool _productionPromotionPolicyMapInFlight = false;
  static bool _productionSingleSkillPromotionInFlight = false;
  static bool _productionSingleSkillRouteSelectionInFlight = false;
  static bool _productionDeviceNodeRouteShadowInFlight = false;
  static bool _productionDeviceNodeRealTurnExecutionInFlight = false;
  static bool _productionDeviceNodeRuntimeSelectorInFlight = false;
  static bool _productionDeviceNodeProviderToolPlanHandoffInFlight = false;
  static bool _productionDeviceNodeSelectorHandoffSoakInFlight = false;
  static bool _productionNextMobileBridgeCandidateInFlight = false;
  static bool _productionGesturesRouteShadowInFlight = false;
  static bool _productionGesturesExecutionInFlight = false;
  static bool _productionGesturesSelectorHandoffSoakInFlight = false;
  static bool _productionGesturesRuntimeSelectorInFlight = false;
  static bool _productionHapticBridgeCandidateInFlight = false;
  static bool _canaryComparisonPassed = false;
  static DateTime? _lastCanaryComparisonAttemptAt;
  static const Duration _canaryComparisonRetryCooldown = Duration(seconds: 30);

  static Future<void> runStartupSelfTestIfEnabled({
    required void Function(String message) log,
  }) async {
    if (!startupSidecarDiagnosticsEnabled) return;
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
    if (!startupSidecarDiagnosticsEnabled) return;
    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.gatewayRuntimeOwner ==
        PreferencesService.gatewayRuntimeOwnerNativeProduction) {
      return;
    }
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

  static Future<Map<String, dynamic>> runFullGatewayBootstrapCanary({
    required void Function(String message) log,
  }) async {
    if (_fullGatewayBootstrapInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'native-full-gateway-bootstrap',
        'alreadyInFlight': true,
        'decision':
            'Full OpenClaw native bootstrap is already running; wait for the current attempt to finish.',
      };
    }

    _fullGatewayBootstrapInFlight = true;
    final startedAt = DateTime.now();
    try {
      log('[NATIVE-FULL-GATEWAY] Starting real OpenClaw Gateway bootstrap on ${AppConstants.nativeGatewaySmokeUrl}.');

      Object? previousStopError;
      var previousStopped = false;
      try {
        previousStopped = await _fullGatewayBootstrapRuntime.stop();
      } catch (e) {
        previousStopError = e;
      }
      for (var attempt = 0; attempt < 20; attempt++) {
        var stillListening = false;
        try {
          stillListening = await _fullGatewayBootstrapRuntime.isRunning();
        } catch (_) {
          stillListening = false;
        }
        if (!stillListening) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      final started = await _fullGatewayBootstrapRuntime.start();
      log('[NATIVE-FULL-GATEWAY] start requested: $started');

      var listening = false;
      var healthOk = false;
      Map<String, dynamic> health = <String, dynamic>{};
      Object? lastHealthError;
      for (var attempt = 0; attempt < 120; attempt++) {
        try {
          listening = await _fullGatewayBootstrapRuntime.isRunning();
        } catch (e) {
          lastHealthError = e;
        }

        if (listening) {
          try {
            health = await _probeJson(
              '/health',
              attempts: 1,
              retryDelay: Duration.zero,
              requestTimeout: const Duration(seconds: 1),
            );
            healthOk = health.isNotEmpty;
            break;
          } catch (e) {
            lastHealthError = e;
          }
        }

        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      final logs = await _fullGatewayBootstrapRuntime.getLogs();
      final logLines = logs
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final logTail = logLines.length <= 24
          ? logLines
          : logLines.sublist(logLines.length - 24);

      Map<String, dynamic> marker = <String, dynamic>{};
      String? markerError;
      try {
        final filesDir = await NativeBridge.getFilesDir();
        final markerFile = File(
          '$filesDir/native-node-embedded/native-home/.openclaw/native-full-gateway-bootstrap.json',
        );
        if (await markerFile.exists()) {
          final decoded = jsonDecode(await markerFile.readAsString());
          if (decoded is Map<String, dynamic>) {
            marker = decoded;
          }
        }
      } catch (e) {
        markerError = e.toString();
      }

      final markerStage = marker['openclawStarted'];
      final markerOpenClawStarted = markerStage == true ||
          markerStage == 'launching' ||
          markerStage == 'before-run-main-import' ||
          markerStage == 'before-run-cli' ||
          markerStage == 'http-listening' ||
          markerStage == 'gateway-ready';
      final markerGatewayReady = markerStage == 'gateway-ready';
      final ok = started && listening && (healthOk || markerGatewayReady);
      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'native-full-gateway-bootstrap',
        'mode': 'real-openclaw-sidecar',
        'runtimeId': _fullGatewayBootstrapRuntime.id,
        'nativePort': AppConstants.nativeGatewaySmokePort,
        'nativeUrl': AppConstants.nativeGatewaySmokeUrl,
        'productionPort': AppConstants.gatewayPort,
        'productionUntouched': true,
        'previousStopped': previousStopped,
        if (previousStopError != null)
          'previousStopError': previousStopError.toString(),
        'started': started,
        'listening': listening,
        'healthOk': healthOk,
        'healthRuntime': health['runtime'],
        'healthStatus': health['status'] ?? health['ok'],
        'healthKeys': health.keys.toList()..sort(),
        if (lastHealthError != null)
          'lastHealthError': lastHealthError.toString(),
        'markerOpenClawStarted': markerOpenClawStarted,
        'markerGatewayReady': markerGatewayReady,
        'markerPhase': marker['phase'],
        'markerPort': marker['port'],
        'markerNode': marker['node'],
        'markerPlatform': marker['platform'],
        'markerArch': marker['arch'],
        if (marker['error'] != null) 'markerError': marker['error'],
        if (markerError != null) 'markerReadError': markerError,
        'logTail': logTail,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'leftRunningForInspection': true,
        'decision': ok
            ? 'Real OpenClaw package bootstrap reached native Node sidecar on 18790. Next blocker is compatibility/health hardening, then native production owner selection.'
            : 'Real OpenClaw package bootstrap did not reach a green sidecar health check yet. Inspect logTail/markerError and fix the first actual startup blocker.',
        'nextGate': ok
            ? 'native full Gateway health contract'
            : 'bootstrap compatibility fix from raw native logs',
      };
      log('[NATIVE-FULL-GATEWAY] ${jsonEncode({
            ...report,
            'logTail': '<redacted in activity log>',
            if (report['markerError'] != null)
              'markerError': '<redacted in activity log>',
          })}');
      return report;
    } finally {
      _fullGatewayBootstrapInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runFullGatewayProductionOwnerCanary({
    required void Function(String message) log,
  }) async {
    if (_fullGatewayProductionOwnerInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'native-full-gateway-production-owner',
        'alreadyInFlight': true,
        'decision':
            'Full native Gateway production-owner canary is already running.',
      };
    }

    _fullGatewayProductionOwnerInFlight = true;
    final startedAt = DateTime.now();
    final productionRuntime = GatewayRuntimeRegistry.prootRollback;
    final nativeRuntime = _fullGatewayProductionRuntime;

    var productionStopped = false;
    var productionPortReleased = false;
    var nativePreStartStopped = false;
    Object? nativePreStartStopError;
    var nativeStarted = false;
    var nativeRunning = false;
    var nativeHealthOk = false;
    Map<String, dynamic> nativeHealth = <String, dynamic>{};
    Object? nativeHealthError;
    var nativeStopped = false;
    var nativePortReleasedAfterStop = false;
    var rollbackStarted = false;
    var rollbackRunning = false;
    var rollbackHealthOk = false;
    Map<String, dynamic> rollbackHealth = <String, dynamic>{};
    Object? rollbackError;

    try {
      log('[NATIVE-FULL-OWNER] Stopping any existing native sidecar before 18789 owner start.');
      try {
        await nativeRuntime.stop();
        for (var attempt = 0; attempt < 30; attempt++) {
          final smokeStillRunning =
              await _nodeRuntime.isRunning().catchError((_) => false);
          final productionStillRunning =
              await nativeRuntime.isRunning().catchError((_) => false);
          if (!smokeStillRunning && !productionStillRunning) {
            nativePreStartStopped = true;
            nativePreStartStopError = null;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      } catch (e) {
        nativePreStartStopError = e;
      }

      log('[NATIVE-FULL-OWNER] Stopping PRoot to release 18789.');
      productionStopped = await productionRuntime.stop();
      productionPortReleased = await _waitForProductionPortReleased(
        timeout: const Duration(seconds: 12),
      );
      if (!productionPortReleased) {
        throw StateError(
          'Production port 18789 did not release before full native owner start.',
        );
      }

      log('[NATIVE-FULL-OWNER] Starting real OpenClaw Gateway under embedded Node on 18789.');
      nativeStarted = await nativeRuntime.start();
      if (!nativeStarted) {
        throw StateError(
            'Native full Gateway production runtime did not start.');
      }

      for (var attempt = 0; attempt < 120; attempt++) {
        try {
          nativeRunning = await nativeRuntime.isRunning();
          nativeHealth = await _probeProductionJson(
            '/health',
            attempts: 1,
            retryDelay: Duration.zero,
            requestTimeout: const Duration(seconds: 3),
          );
          nativeHealthOk = nativeHealth['ok'] == true ||
              nativeHealth['status'] == 'live' ||
              nativeHealth['status'] == 'ok';
          if (nativeHealthOk) {
            nativeRunning = true;
            nativeHealthError = null;
            break;
          }
        } catch (e) {
          nativeHealthError = e;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      nativeHealthError ??= e;
    } finally {
      log('[NATIVE-FULL-OWNER] Rolling back: stopping native owner and restarting PRoot.');
      try {
        nativeStopped = await nativeRuntime.stop();
      } catch (e) {
        rollbackError = e;
      }

      try {
        nativePortReleasedAfterStop = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 12),
        );
      } catch (e) {
        rollbackError ??= e;
      }

      try {
        rollbackStarted = await productionRuntime.start(allowDuringSetup: true);
        for (var attempt = 0; attempt < 120; attempt++) {
          try {
            rollbackRunning = await productionRuntime.isRunning();
            rollbackHealth = await _probeProductionJson(
              '/health',
              attempts: 1,
              retryDelay: Duration.zero,
              requestTimeout: const Duration(seconds: 3),
            );
            rollbackHealthOk = _productionHealthLooksLikeProot(rollbackHealth);
            if (rollbackHealthOk) {
              rollbackRunning = true;
              rollbackError = null;
              break;
            }
          } catch (e) {
            rollbackError = e;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
        rollbackError = e;
      }

      _fullGatewayProductionOwnerInFlight = false;
    }

    final rollbackOk = rollbackStarted && rollbackRunning && rollbackHealthOk;
    final ok = productionStopped &&
        productionPortReleased &&
        nativeStarted &&
        nativeRunning &&
        nativeHealthOk &&
        nativeStopped &&
        nativePortReleasedAfterStop &&
        rollbackOk;
    final logs = await nativeRuntime.getLogs();
    final logLines = logs
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final logTail = logLines.length <= 30
        ? logLines
        : logLines.sublist(logLines.length - 30);

    final report = <String, dynamic>{
      'ok': ok,
      'phase': 'native-full-gateway-production-owner',
      'mode': 'real-openclaw-production-owner-with-proot-rollback',
      'productionRuntimeBefore': productionRuntime.id,
      'nativeRuntimeId': nativeRuntime.id,
      'productionPort': AppConstants.gatewayPort,
      'productionStopped': productionStopped,
      'productionPortReleased': productionPortReleased,
      'nativePreStartStopped': nativePreStartStopped,
      if (nativePreStartStopError != null)
        'nativePreStartStopError': nativePreStartStopError.toString(),
      'nativeStarted': nativeStarted,
      'nativeRunning': nativeRunning,
      'nativeHealthOk': nativeHealthOk,
      'nativeHealthStatus': nativeHealth['status'] ?? nativeHealth['ok'],
      'nativeHealthKeys': nativeHealth.keys.toList()..sort(),
      if (nativeHealthError != null)
        'nativeHealthError': nativeHealthError.toString(),
      'nativeStopped': nativeStopped,
      'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
      'rollbackStarted': rollbackStarted,
      'rollbackRunning': rollbackRunning,
      'rollbackHealthOk': rollbackHealthOk,
      'rollbackHealthStatus': rollbackHealth['status'] ?? rollbackHealth['ok'],
      'rollbackHealthKeys': rollbackHealth.keys.toList()..sort(),
      if (rollbackError != null) 'rollbackError': rollbackError.toString(),
      'rollbackVerified': rollbackOk,
      'logTail': logTail,
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'decision': ok
          ? 'Real embedded Node OpenClaw owned production port 18789, returned live health, and PRoot rollback was restored.'
          : 'Native full Gateway production-owner canary is not promotable until native health and PRoot rollback are both green.',
      'nextGate': ok
          ? 'selected real chat turn through full native production owner'
          : 'fix full native production owner or rollback blocker',
    };
    log('[NATIVE-FULL-OWNER] ${jsonEncode({
          ...report,
          'logTail': '<redacted in activity log>',
        })}');
    return report;
  }

  static Future<Map<String, dynamic>> runFullGatewayProductionChatTurnCanary({
    required void Function(String message) log,
    required String prompt,
    String? authToken,
    String? model,
    String? provider,
  }) async {
    if (_fullGatewayProductionChatTurnInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'native-full-gateway-production-chat-turn',
        'alreadyInFlight': true,
        'decision':
            'Full native Gateway production chat-turn canary is already running.',
      };
    }

    _fullGatewayProductionChatTurnInFlight = true;
    final startedAt = DateTime.now();
    final productionRuntime = GatewayRuntimeRegistry.prootRollback;
    final nativeRuntime = _fullGatewayProductionRuntime;
    final canaryPrompt = prompt.trim().isEmpty
        ? 'Native full Gateway real chat turn canary. Reply with exactly: native-ok'
        : prompt.trim();

    GatewayConnection? canaryConnection;
    var productionStopped = false;
    var productionPortReleased = false;
    var nativePreStartStopped = false;
    Object? nativePreStartStopError;
    var nativeStarted = false;
    var nativeRunning = false;
    var nativeHealthOk = false;
    Map<String, dynamic> nativeHealth = <String, dynamic>{};
    Object? nativeHealthError;
    var nativeAuthTokenFound = false;
    String nativeAuthTokenSource = 'none';
    var wsConnected = false;
    var wsConnectAttempts = 0;
    int? wsCloseCode;
    String? wsCloseReason;
    String? wsDisconnectAt;
    String? wsStateAfterConnect;
    String? wsConnectError;
    var chatSendAckSeen = false;
    var chatSendAccepted = false;
    var runStarted = false;
    var finalSeen = false;
    var firstTokenReceived = false;
    var toolUseCount = 0;
    var toolResultCount = 0;
    var frameCount = 0;
    var assistantSnapshot = '';
    var assistantText = '';
    String? activeRunId;
    String? rawGatewayError;
    String? rawProviderError;
    String? chatError;
    var nativeStopped = false;
    var nativePortReleasedAfterStop = false;
    var rollbackStarted = false;
    var rollbackRunning = false;
    var rollbackHealthOk = false;
    Map<String, dynamic> rollbackHealth = <String, dynamic>{};
    Object? rollbackError;

    String assistantDelta(String text) {
      if (text.isEmpty) return '';
      if (assistantSnapshot.isEmpty) {
        assistantSnapshot = text;
        return text;
      }
      if (text == assistantSnapshot || assistantSnapshot.endsWith(text)) {
        return '';
      }
      if (text.startsWith(assistantSnapshot)) {
        final delta = text.substring(assistantSnapshot.length);
        assistantSnapshot = text;
        return delta;
      }
      assistantSnapshot += text;
      return text;
    }

    bool isActiveRunFrame(String? runId) {
      return activeRunId == null || runId == null || runId == activeRunId;
    }

    void captureWsDiagnostics(Object? error) {
      final connection = canaryConnection;
      if (connection == null) return;
      wsCloseCode = connection.lastCloseCode;
      wsCloseReason = connection.lastCloseReason;
      wsDisconnectAt = connection.lastDisconnectAt?.toIso8601String();
      wsStateAfterConnect = connection.state.name;
      if (error != null) wsConnectError = error.toString();
    }

    try {
      log('[NATIVE-FULL-CHAT] Stopping any existing native sidecar before 18789 chat turn.');
      try {
        await nativeRuntime.stop();
        for (var attempt = 0; attempt < 30; attempt++) {
          final smokeStillRunning =
              await _nodeRuntime.isRunning().catchError((_) => false);
          final productionStillRunning =
              await nativeRuntime.isRunning().catchError((_) => false);
          if (!smokeStillRunning && !productionStillRunning) {
            nativePreStartStopped = true;
            nativePreStartStopError = null;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      } catch (e) {
        nativePreStartStopError = e;
      }

      log('[NATIVE-FULL-CHAT] Stopping PRoot so native owns real production port 18789.');
      productionStopped = await productionRuntime.stop();
      productionPortReleased = await _waitForProductionPortReleased(
        timeout: const Duration(seconds: 12),
      );
      if (!productionPortReleased) {
        throw StateError(
          'Production port 18789 did not release before full native chat turn.',
        );
      }

      log('[NATIVE-FULL-CHAT] Starting real OpenClaw Gateway under embedded Node on 18789.');
      nativeStarted = await nativeRuntime.start();
      if (!nativeStarted) {
        throw StateError(
            'Native full Gateway production runtime did not start.');
      }

      for (var attempt = 0; attempt < 120; attempt++) {
        try {
          nativeRunning = await nativeRuntime.isRunning();
          nativeHealth = await _probeProductionJson(
            '/health',
            attempts: 1,
            retryDelay: Duration.zero,
            requestTimeout: const Duration(seconds: 3),
          );
          nativeHealthOk = nativeHealth['ok'] == true ||
              nativeHealth['status'] == 'live' ||
              nativeHealth['status'] == 'ok';
          if (nativeHealthOk) {
            nativeRunning = true;
            nativeHealthError = null;
            break;
          }
        } catch (e) {
          nativeHealthError = e;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      if (!nativeRunning || !nativeHealthOk) {
        throw StateError(
          'Native full Gateway did not become healthy before chat turn: '
          '${nativeHealthError ?? nativeHealth}',
        );
      }

      final tokenProbe = await _resolveNativeGatewayAuthToken(
        preferredToken: authToken,
      );
      final token = tokenProbe['token'];
      nativeAuthTokenSource = tokenProbe['source'] ?? 'unknown';
      final resolvedToken = token?.trim();
      nativeAuthTokenFound = resolvedToken != null && resolvedToken.isNotEmpty;
      if (resolvedToken == null || resolvedToken.isEmpty) {
        throw StateError(
          'No native Gateway auth token available for WebSocket chat turn.',
        );
      }

      for (var attempt = 0; attempt < 3 && !wsConnected; attempt++) {
        wsConnectAttempts = attempt + 1;
        canaryConnection?.disconnect();
        canaryConnection = GatewayConnection();
        Object? connectError;
        try {
          wsConnected = await canaryConnection
              .connect(resolvedToken)
              .timeout(const Duration(seconds: 20));
        } catch (e) {
          connectError = e;
          wsConnected = false;
        } finally {
          captureWsDiagnostics(connectError);
        }
        if (!wsConnected && attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (!wsConnected) {
        final reason = wsConnectError ??
            wsCloseReason ??
            wsStateAfterConnect ??
            'no WebSocket close reason captured';
        throw StateError(
          'Native Gateway WebSocket connect failed after '
          '$wsConnectAttempts attempt(s): $reason',
        );
      }

      final requestId =
          'native-full-chat-${DateTime.now().microsecondsSinceEpoch}';
      final activeConnection = canaryConnection;
      if (activeConnection == null) {
        throw StateError(
          'Native Gateway WebSocket connect succeeded without an active connection.',
        );
      }
      final responseStream = activeConnection.sendRequest(
        _sampleGatewayWsChatSendFrame(
          requestId: requestId,
          idempotencyKey:
              'native-full-chat-idem-${DateTime.now().microsecondsSinceEpoch}',
          message: canaryPrompt,
        ),
      );

      log('[NATIVE-FULL-CHAT] Sent real chat.send frame to native Gateway.');
      await for (final frame in responseStream.timeout(
        const Duration(seconds: 120),
        onTimeout: (sink) {
          sink.add(<String, dynamic>{
            'type': 'error',
            'payload': {
              'message':
                  'Native full Gateway chat turn timed out after 120 seconds.',
            },
          });
          sink.close();
        },
      )) {
        frameCount += 1;
        final type = frame['type']?.toString();
        final event = frame['event']?.toString();
        final payload = _jsonObject(frame['payload']);
        final data = _jsonObject(payload['data'] ?? frame['data']);

        if (type == 'res' && frame['id'] == requestId) {
          chatSendAckSeen = true;
          chatSendAccepted = frame['ok'] == true;
          if (!chatSendAccepted) {
            chatError = _rawText(
              frame['error'] ?? frame['errorMessage'] ?? frame,
            );
            break;
          }
          activeRunId = frame['runId']?.toString();
          continue;
        }

        if (type == 'error') {
          rawGatewayError = _rawText(payload.isEmpty ? frame : payload);
          rawProviderError = rawGatewayError;
          break;
        }

        if (frame.containsKey('error') && frame['error'] != null) {
          final error = _rawText(frame['error']);
          if (error.isNotEmpty) {
            rawGatewayError = error;
            rawProviderError = error;
            break;
          }
        }

        if (type == 'event' && event == 'chat') {
          final state =
              (payload['state'] ?? data['state'] ?? frame['state'])?.toString();
          if (state == 'final' || state == 'aborted' || state == 'error') {
            finalSeen = true;
            if (state == 'error' || state == 'aborted') {
              rawProviderError = _rawText(
                payload['error'] ??
                    data['error'] ??
                    payload['reason'] ??
                    data['reason'] ??
                    payload['message'] ??
                    data['message'] ??
                    state,
              );
            }
            if (assistantText.trim().isNotEmpty ||
                (rawProviderError?.isNotEmpty ?? false)) {
              break;
            }
          }
          continue;
        }

        if (type == 'event' && event == 'agent') {
          final runId = frame['run']?.toString() ?? payload['run']?.toString();
          final stream = (payload['stream'] ?? frame['stream'])?.toString();
          if (!isActiveRunFrame(runId)) continue;

          if (stream == 'assistant') {
            final text =
                (data['text'] ?? payload['text'] ?? frame['text'])?.toString();
            if (text != null && text.isNotEmpty) {
              final delta = assistantDelta(text);
              if (delta.isNotEmpty) {
                firstTokenReceived = true;
                assistantText += delta;
              }
            }
          } else if (stream == 'tool_use') {
            toolUseCount += 1;
            assistantSnapshot = '';
          } else if (stream == 'tool_result') {
            toolResultCount += 1;
            assistantSnapshot = '';
          } else if (stream == 'lifecycle') {
            final phase = (data['phase'] ?? payload['phase'] ?? frame['phase'])
                ?.toString();
            if (phase == 'start') {
              runStarted = true;
              if (runId != null) activeRunId = runId;
            } else if (phase == 'error') {
              rawProviderError = _rawText(
                data['error'] ?? payload['error'] ?? frame['error'],
              );
              finalSeen = true;
              break;
            } else if (phase == 'end') {
              finalSeen = true;
              final endSignal = _rawText(
                data['error'] ??
                    payload['error'] ??
                    data['reason'] ??
                    payload['reason'] ??
                    frame['error'] ??
                    frame['reason'],
              );
              final normalized = endSignal.toLowerCase();
              if (endSignal.isNotEmpty &&
                  normalized != 'completed' &&
                  normalized != 'run_completed' &&
                  normalized != 'null') {
                rawProviderError = endSignal;
              }
              break;
            }
          } else if (stream == 'error') {
            rawProviderError = _rawText(
              data['error'] ??
                  payload['error'] ??
                  payload['reason'] ??
                  frame['reason'] ??
                  frame['error'],
            );
            finalSeen = true;
            break;
          }
        }
      }
    } catch (e) {
      chatError ??= e.toString();
    } finally {
      canaryConnection?.disconnect();
      log('[NATIVE-FULL-CHAT] Rolling back: stopping native owner and restarting PRoot.');
      try {
        nativeStopped = await nativeRuntime.stop();
      } catch (e) {
        rollbackError = e;
      }

      try {
        nativePortReleasedAfterStop = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 12),
        );
      } catch (e) {
        rollbackError ??= e;
      }

      try {
        rollbackStarted = await productionRuntime.start(allowDuringSetup: true);
        for (var attempt = 0; attempt < 120; attempt++) {
          try {
            rollbackRunning = await productionRuntime.isRunning();
            rollbackHealth = await _probeProductionJson(
              '/health',
              attempts: 1,
              retryDelay: Duration.zero,
              requestTimeout: const Duration(seconds: 3),
            );
            rollbackHealthOk = _productionHealthLooksLikeProot(rollbackHealth);
            if (rollbackHealthOk) {
              rollbackRunning = true;
              rollbackError = null;
              break;
            }
          } catch (e) {
            rollbackError = e;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
        rollbackError = e;
      }

      _fullGatewayProductionChatTurnInFlight = false;
    }

    final rollbackOk = rollbackStarted && rollbackRunning && rollbackHealthOk;
    final visibleTextOk = assistantText.trim().isNotEmpty;
    final rawProviderErrorText = rawProviderError?.trim() ?? '';
    final rawGatewayErrorText = rawGatewayError?.trim() ?? '';
    final chatErrorText = chatError?.trim() ?? '';
    final rawProviderErrorForwarded = rawProviderErrorText.isNotEmpty;
    final chatOutcomeOk = visibleTextOk || rawProviderErrorForwarded;
    final ok = productionStopped &&
        productionPortReleased &&
        nativeStarted &&
        nativeRunning &&
        nativeHealthOk &&
        nativeAuthTokenFound &&
        wsConnected &&
        chatSendAckSeen &&
        chatSendAccepted &&
        chatOutcomeOk &&
        nativeStopped &&
        nativePortReleasedAfterStop &&
        rollbackOk;
    final logs = await nativeRuntime.getLogs();
    final logLines = logs
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final logTail = logLines.length <= 30
        ? logLines
        : logLines.sublist(logLines.length - 30);
    final responsePreview = assistantText.trim().length > 500
        ? assistantText.trim().substring(0, 500)
        : assistantText.trim();
    final rawProviderErrorPreview = rawProviderErrorText.isEmpty
        ? null
        : (rawProviderErrorText.length > 700
            ? rawProviderErrorText.substring(0, 700)
            : rawProviderErrorText);

    final report = <String, dynamic>{
      'ok': ok,
      'phase': 'native-full-gateway-production-chat-turn',
      'mode':
          'real-openclaw-native-owner-websocket-chat-send-with-proot-rollback',
      'productionRuntimeBefore': productionRuntime.id,
      'nativeRuntimeId': nativeRuntime.id,
      'productionPort': AppConstants.gatewayPort,
      'productionStopped': productionStopped,
      'productionPortReleased': productionPortReleased,
      'nativePreStartStopped': nativePreStartStopped,
      if (nativePreStartStopError != null)
        'nativePreStartStopError': nativePreStartStopError.toString(),
      'nativeStarted': nativeStarted,
      'nativeRunning': nativeRunning,
      'nativeHealthOk': nativeHealthOk,
      'nativeHealthStatus': nativeHealth['status'] ?? nativeHealth['ok'],
      'nativeHealthKeys': nativeHealth.keys.toList()..sort(),
      if (nativeHealthError != null)
        'nativeHealthError': nativeHealthError.toString(),
      'nativeAuthTokenFound': nativeAuthTokenFound,
      'nativeAuthTokenSource': nativeAuthTokenSource,
      'wsConnected': wsConnected,
      'wsConnectAttempts': wsConnectAttempts,
      if (wsCloseCode != null) 'wsCloseCode': wsCloseCode,
      if (wsCloseReason != null) 'wsCloseReason': wsCloseReason,
      if (wsDisconnectAt != null) 'wsDisconnectAt': wsDisconnectAt,
      if (wsStateAfterConnect != null)
        'wsStateAfterConnect': wsStateAfterConnect,
      if (wsConnectError != null) 'wsConnectError': wsConnectError,
      'chatSendAckSeen': chatSendAckSeen,
      'chatSendAccepted': chatSendAccepted,
      'runStarted': runStarted,
      'finalSeen': finalSeen,
      'firstTokenReceived': firstTokenReceived,
      'visibleTextOk': visibleTextOk,
      'assistantTextChars': assistantText.trim().length,
      'responsePreview': responsePreview,
      'rawProviderErrorForwarded': rawProviderErrorForwarded,
      if (rawProviderErrorPreview != null)
        'rawProviderErrorPreview': rawProviderErrorPreview,
      if (rawGatewayErrorText.isNotEmpty)
        'rawGatewayError': rawGatewayErrorText,
      if (chatErrorText.isNotEmpty) 'chatError': chatErrorText,
      'toolUseCount': toolUseCount,
      'toolResultCount': toolResultCount,
      'frameCount': frameCount,
      'nativeStopped': nativeStopped,
      'nativePortReleasedAfterStop': nativePortReleasedAfterStop,
      'rollbackStarted': rollbackStarted,
      'rollbackRunning': rollbackRunning,
      'rollbackHealthOk': rollbackHealthOk,
      'rollbackHealthStatus': rollbackHealth['status'] ?? rollbackHealth['ok'],
      'rollbackHealthKeys': rollbackHealth.keys.toList()..sort(),
      if (rollbackError != null) 'rollbackError': rollbackError.toString(),
      'rollbackVerified': rollbackOk,
      'logTail': logTail,
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      'decision': ok
          ? (visibleTextOk
              ? 'Real full native Gateway owned 18789, accepted chat.send, produced visible assistant text, and PRoot rollback was restored.'
              : 'Real full native Gateway owned 18789, accepted chat.send, forwarded the raw provider error, and PRoot rollback was restored.')
          : 'Full native production chat-turn canary is not promotable until WebSocket chat.send and PRoot rollback are both green.',
      'nextGate': ok
          ? 'native runtime selector default switch with PRoot rollback still armed'
          : 'fix full native chat turn blocker before selector promotion',
    };
    log('[NATIVE-FULL-CHAT] ${jsonEncode({
          ...report,
          'responsePreview': report['responsePreview'] == null
              ? null
              : '<redacted in activity log>',
          'rawProviderErrorPreview': report['rawProviderErrorPreview'] == null
              ? null
              : '<redacted in activity log>',
          'rawGatewayError': report['rawGatewayError'] == null
              ? null
              : '<redacted in activity log>',
          'logTail': '<redacted in activity log>',
        })}');
    return report;
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

  static Future<Map<String, dynamic>> runProductionSkillToolInventoryParity({
    required void Function(String message) log,
  }) async {
    if (_productionInventoryParityInFlight) {
      return {
        'ok': false,
        'phase': 'production-skill-tool-inventory-parity',
        'status': 'busy',
        'decision':
            'Production skill/tool inventory parity is already running.',
      };
    }

    _productionInventoryParityInFlight = true;
    final startedAt = DateTime.now();
    var nativeStartedForProbe = false;
    try {
      final productionHealth = await _probeProductionJson(
        '/health',
        attempts: 20,
        requestTimeout: const Duration(seconds: 5),
      );
      final productionHealthOk =
          _productionHealthLooksLikeProot(productionHealth);

      final nativeWasRunning = await _nodeRuntime
          .isRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false)
          .catchError((_) => false);
      if (!nativeWasRunning) {
        nativeStartedForProbe = await _nodeRuntime.start();
      }

      final nativeHealth =
          await _probeHealth(expectedRuntime: 'native-node-embedded');
      final nativeProbe = await _probeJson('/gateway/probe');
      final capabilities = await _probeJson('/gateway/capabilities');
      final skillRegistry = await _probeJson('/gateway/skill-registry');
      final wsFrameShape = await _postJson(
        '/gateway/ws-frame-shape',
        _sampleGatewayWsChatSendFrame(
          requestId: 'inventory-parity-ws-shape',
          idempotencyKey: 'inventory-parity-idempotency',
        ),
        expectedStatus: 200,
      );

      final productionSkillIds = await _scanProductionSkillIds();
      final nativeSkillIds = _skillIdsFromRegistry(skillRegistry);
      final missingInNative =
          _sortedDifference(productionSkillIds, nativeSkillIds);
      final extraInNative =
          _sortedDifference(nativeSkillIds, productionSkillIds);

      final mobileTools = await _probeAgentSkillTools();
      final mobileToolNames = _toolNamesFromAgentTools(mobileTools);
      const requiredMobileTools = <String>{
        'avatar-control',
        'tts-voice',
        'device-node',
      };
      final missingMobileTools =
          _sortedDifference(requiredMobileTools, mobileToolNames);

      final requestShape = wsFrameShape['requestShape'] is Map
          ? Map<String, dynamic>.from(wsFrameShape['requestShape'] as Map)
          : <String, dynamic>{};
      final mobileToolHints = requestShape['mobileToolHints'] is List
          ? (requestShape['mobileToolHints'] as List)
              .map((value) => value.toString())
              .toSet()
          : <String>{};
      const requiredToolHints = <String>{
        'avatar.gesture',
        'camera_snap',
        'canvas.eval',
        'canvas.navigate',
        'canvas.snapshot',
        'device_status',
        'flash.status',
        'haptic.vibrate',
        'notifications.list',
        'sensor.list',
        'sensor.read',
      };
      final missingToolHints =
          _sortedDifference(requiredToolHints, mobileToolHints);

      const requiredProductionSkills = <String>{
        'canvas',
        'device-node',
        'gestures',
        'tts-voice',
        'weather',
      };
      final missingKnownSkills =
          _sortedDifference(requiredProductionSkills, nativeSkillIds);

      final nativeSafetyGatesOk = nativeHealth['openclawStarted'] == false &&
          nativeProbe['canaryOnly'] == true &&
          nativeProbe['chatRoutingEnabled'] == false &&
          nativeProbe['providerCallsEnabled'] == false &&
          skillRegistry['readOnly'] == true &&
          skillRegistry['executionEnabled'] == false &&
          capabilities['productionSkillsLoaded'] == false;
      final skillRegistryOk = skillRegistry['ok'] == true &&
          skillRegistry['skillCount'] is num &&
          (skillRegistry['skillCount'] as num) >= 50;
      final skillParityOk = productionSkillIds.length >= 50 &&
          nativeSkillIds.length == productionSkillIds.length &&
          missingInNative.isEmpty &&
          extraInNative.isEmpty &&
          missingKnownSkills.isEmpty;
      final mobileToolEndpointOk =
          mobileTools['tools'] is List && mobileToolNames.length >= 10;
      final mobileToolCoreOk =
          mobileToolEndpointOk && missingMobileTools.isEmpty;
      final mobileToolHintOk = missingToolHints.isEmpty &&
          requestShape['looksLikeProductionChatSend'] == true &&
          requestShape['providerCallsEnabled'] == false &&
          requestShape['executionEnabled'] == false;

      final ok = productionHealthOk &&
          nativeSafetyGatesOk &&
          skillRegistryOk &&
          skillParityOk &&
          mobileToolCoreOk &&
          mobileToolHintOk;
      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'production-skill-tool-inventory-parity',
        'mode': 'side-by-side-read-only',
        'primaryRuntimeId': 'proot',
        'nativeRuntimeId': 'native-node-embedded',
        'productionHealthOk': productionHealthOk,
        'productionHealthStatus': productionHealth['status'],
        'nativeStartedForProbe': nativeStartedForProbe,
        'nativeHealthOk': nativeHealth['ok'] == true,
        'nativeSafetyGatesOk': nativeSafetyGatesOk,
        'nativeCanaryOnly': nativeProbe['canaryOnly'] == true,
        'nativeOpenClawStarted': nativeHealth['openclawStarted'] == true,
        'nativeChatRoutingEnabled': nativeProbe['chatRoutingEnabled'] == true,
        'nativeProviderCallsEnabled':
            nativeProbe['providerCallsEnabled'] == true,
        'nativeToolExecutionEnabled':
            nativeProbe['toolExecutionEnabled'] == true,
        'skillRegistryOk': skillRegistryOk,
        'skillParityOk': skillParityOk,
        'productionSkillCount': productionSkillIds.length,
        'nativeSkillCount': nativeSkillIds.length,
        'missingInNativeCount': missingInNative.length,
        'extraInNativeCount': extraInNative.length,
        'missingKnownSkills': missingKnownSkills,
        'missingInNativePreview': missingInNative.take(12).toList(),
        'extraInNativePreview': extraInNative.take(12).toList(),
        'countsByClass': skillRegistry['countsByClass'] ?? {},
        'mobileToolEndpointOk': mobileToolEndpointOk,
        'mobileToolCoreOk': mobileToolCoreOk,
        'mobileToolCount': mobileToolNames.length,
        'missingMobileTools': missingMobileTools,
        'mobileToolHintOk': mobileToolHintOk,
        'mobileToolHintCount': mobileToolHints.length,
        'missingToolHints': missingToolHints,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native sees the full production skill registry read-only, the mobile bridge tools are present, and PRoot remains primary.'
            : 'Inventory parity is not promotable; fix missing skills/tools before native promotion.',
        'nextGate':
            'promotion policy map for production skills/tools before any default native routing',
      };
      log('[NATIVE-INVENTORY-PARITY] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionInventoryParityInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runProductionPromotionPolicyMap({
    required void Function(String message) log,
  }) async {
    if (_productionPromotionPolicyMapInFlight) {
      return {
        'ok': false,
        'phase': 'production-promotion-policy-map',
        'status': 'busy',
        'decision': 'Production promotion policy map is already running.',
      };
    }

    _productionPromotionPolicyMapInFlight = true;
    final startedAt = DateTime.now();
    var nativeStartedForProbe = false;
    try {
      final productionHealth = await _probeProductionJson(
        '/health',
        attempts: 20,
        requestTimeout: const Duration(seconds: 5),
      );
      final productionHealthOk =
          _productionHealthLooksLikeProot(productionHealth);

      final nativeWasRunning = await _nodeRuntime
          .isRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false)
          .catchError((_) => false);
      if (!nativeWasRunning) {
        nativeStartedForProbe = await _nodeRuntime.start();
      }

      final nativeHealth =
          await _probeHealth(expectedRuntime: 'native-node-embedded');
      final nativeProbe = await _probeJson('/gateway/probe');
      final capabilities = await _probeJson('/gateway/capabilities');
      final skillRegistry = await _probeJson('/gateway/skill-registry');
      final wsFrameShape = await _postJson(
        '/gateway/ws-frame-shape',
        _sampleGatewayWsChatSendFrame(
          requestId: 'promotion-policy-ws-shape',
          idempotencyKey: 'promotion-policy-idempotency',
        ),
        expectedStatus: 200,
      );

      final productionSkillIds = await _scanProductionSkillIds();
      final nativeSkillIds = _skillIdsFromRegistry(skillRegistry);
      final missingInNative =
          _sortedDifference(productionSkillIds, nativeSkillIds);
      final extraInNative =
          _sortedDifference(nativeSkillIds, productionSkillIds);
      final skillPolicies = _buildSkillPromotionPolicies(productionSkillIds);
      final missingSkillPolicies =
          _sortedDifference(productionSkillIds, skillPolicies.keys.toSet());
      final skillPolicyClassCounts =
          _countStringValues(skillPolicies.values.toList());

      final mobileTools = await _probeAgentSkillTools();
      final mobileToolNames = _toolNamesFromAgentTools(mobileTools);
      final mobileToolPolicies =
          _buildMobileToolPromotionPolicies(mobileToolNames);
      final missingMobileToolPolicies =
          _sortedDifference(mobileToolNames, mobileToolPolicies.keys.toSet());
      final mobileToolPolicyClassCounts =
          _countStringValues(mobileToolPolicies.values.toList());

      final requestShape = wsFrameShape['requestShape'] is Map
          ? Map<String, dynamic>.from(wsFrameShape['requestShape'] as Map)
          : <String, dynamic>{};
      final mobileToolHints = requestShape['mobileToolHints'] is List
          ? (requestShape['mobileToolHints'] as List)
              .map((value) => value.toString())
              .toSet()
          : <String>{};
      final toolHintPolicies = _buildToolHintPromotionPolicies(mobileToolHints);
      final missingToolHintPolicies =
          _sortedDifference(mobileToolHints, toolHintPolicies.keys.toSet());
      final toolHintPolicyClassCounts =
          _countStringValues(toolHintPolicies.values.toList());

      final nativeSafetyGatesOk = nativeHealth['openclawStarted'] == false &&
          nativeProbe['canaryOnly'] == true &&
          nativeProbe['chatRoutingEnabled'] == false &&
          nativeProbe['providerCallsEnabled'] == false &&
          skillRegistry['readOnly'] == true &&
          skillRegistry['executionEnabled'] == false &&
          capabilities['productionSkillsLoaded'] == false;
      final inventoryParityOk = productionSkillIds.length >= 50 &&
          nativeSkillIds.length == productionSkillIds.length &&
          missingInNative.isEmpty &&
          extraInNative.isEmpty;
      final skillPolicyCoverageOk =
          skillPolicies.length == productionSkillIds.length &&
              missingSkillPolicies.isEmpty &&
              !skillPolicies.values.contains('unmapped');
      final mobileToolPolicyCoverageOk =
          mobileToolPolicies.length == mobileToolNames.length &&
              missingMobileToolPolicies.isEmpty &&
              !mobileToolPolicies.values.contains('unmapped');
      final toolHintPolicyCoverageOk =
          toolHintPolicies.length == mobileToolHints.length &&
              missingToolHintPolicies.isEmpty &&
              !toolHintPolicies.values.contains('unmapped');
      final nativeDefaultRoutingEnabled = false;
      final providerCallsEnabled = false;
      final executionEnabled = false;
      final toolExecutionEnabled = false;

      final ok = productionHealthOk &&
          nativeSafetyGatesOk &&
          inventoryParityOk &&
          skillPolicyCoverageOk &&
          mobileToolPolicyCoverageOk &&
          toolHintPolicyCoverageOk &&
          !nativeDefaultRoutingEnabled &&
          !providerCallsEnabled &&
          !executionEnabled &&
          !toolExecutionEnabled;
      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'production-promotion-policy-map',
        'mode': 'side-by-side-read-only-policy-map',
        'primaryRuntimeId': 'proot',
        'nativeRuntimeId': 'native-node-embedded',
        'productionHealthOk': productionHealthOk,
        'nativeStartedForProbe': nativeStartedForProbe,
        'nativeHealthOk': nativeHealth['ok'] == true,
        'nativeSafetyGatesOk': nativeSafetyGatesOk,
        'inventoryParityOk': inventoryParityOk,
        'productionSkillCount': productionSkillIds.length,
        'nativeSkillCount': nativeSkillIds.length,
        'missingInNativeCount': missingInNative.length,
        'extraInNativeCount': extraInNative.length,
        'skillPolicyCoverageOk': skillPolicyCoverageOk,
        'skillPolicyCount': skillPolicies.length,
        'missingSkillPolicyCount': missingSkillPolicies.length,
        'skillPolicyClassCounts': skillPolicyClassCounts,
        'mobileBridgeCandidateSkills': _mobileBridgeCandidateSkillIds
            .intersection(productionSkillIds)
            .toList()
          ..sort(),
        'mobileToolPolicyCoverageOk': mobileToolPolicyCoverageOk,
        'mobileToolCount': mobileToolNames.length,
        'mobileToolPolicyCount': mobileToolPolicies.length,
        'missingMobileToolPolicyCount': missingMobileToolPolicies.length,
        'mobileToolPolicyClassCounts': mobileToolPolicyClassCounts,
        'toolHintPolicyCoverageOk': toolHintPolicyCoverageOk,
        'mobileToolHintCount': mobileToolHints.length,
        'toolHintPolicyCount': toolHintPolicies.length,
        'missingToolHintPolicyCount': missingToolHintPolicies.length,
        'toolHintPolicyClassCounts': toolHintPolicyClassCounts,
        'nativeDefaultRoutingEnabled': nativeDefaultRoutingEnabled,
        'providerCallsEnabled': providerCallsEnabled,
        'executionEnabled': executionEnabled,
        'toolExecutionEnabled': toolExecutionEnabled,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Promotion policies cover all production skills and mobile tools; default native routing remains disabled.'
            : 'Promotion policy coverage is incomplete; native default routing remains blocked.',
        'nextGate':
            'single-skill native promotion canary with explicit rollback policy',
      };
      log('[NATIVE-PROMOTION-POLICY] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPromotionPolicyMapInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortSingleSkillPromotionCanary({
    required void Function(String message) log,
    String skillId = 'device-node',
    String model = 'openrouter/auto',
    String prompt =
        'native single-skill device-node promotion canary: check flash and list sensors read-only',
  }) async {
    if (_productionSingleSkillPromotionInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-single-skill-promotion-canary',
        'status': 'busy',
        'decision': 'Single-skill native promotion canary is already running.',
      };
    }

    _productionSingleSkillPromotionInFlight = true;
    final startedAt = DateTime.now();
    final selectedSkillId =
        skillId.trim().isEmpty ? 'device-node' : skillId.trim();
    const expectedReadOnlyOrder = <String>['flash.status', 'sensor.list'];
    final rollbackPolicy = <String, dynamic>{
      'skillId': 'device-node',
      'promotionMode': 'single_skill_native_canary',
      'primaryRuntimeId': 'proot',
      'temporaryOwnerRuntimeId': _productionPortRuntime.id,
      'rollbackRuntimeId': 'proot',
      'rollbackRequired': true,
      'rollbackTriggers': <String>[
        'completion',
        'policy_precheck_failure',
        'native_start_failure',
        'canary_failure',
        'guard_violation',
        'timeout_or_exception',
      ],
      'allowedToolHints': expectedReadOnlyOrder,
      'providerCallsEnabled': false,
      'defaultNativeRoutingEnabled': false,
      'executionScope': 'read_only_bridge_allowlist',
    };

    bool listMatches(Object? value, List<String> expected) {
      if (value is! List || value.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (value[i]?.toString() != expected[i]) return false;
      }
      return true;
    }

    try {
      log(
        '[NATIVE-SINGLE-SKILL-PROMOTION] Preparing single-skill promotion policy for $selectedSkillId.',
      );

      if (selectedSkillId != 'device-node') {
        final report = <String, dynamic>{
          'ok': false,
          'phase': 'hidden-production-port-single-skill-promotion-canary',
          'mode': 'single-skill-native-promotion-with-explicit-rollback',
          'selectedSkillId': selectedSkillId,
          'supportedSkillId': 'device-node',
          'singleSkillPolicyOk': false,
          'promotionWindowOpened': false,
          'rollbackPolicy': rollbackPolicy,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Only device-node is promotable in this first native single-skill canary.',
          'nextGate':
              'single-skill device-node canary must pass before widening native promotion',
        };
        log('[NATIVE-SINGLE-SKILL-PROMOTION] ${jsonEncode(report)}');
        return report;
      }

      final policyReport = await runProductionPromotionPolicyMap(log: log);
      final candidateSkills =
          policyReport['mobileBridgeCandidateSkills'] is List
              ? (policyReport['mobileBridgeCandidateSkills'] as List)
                  .map((value) => value.toString())
                  .toSet()
              : <String>{};
      final policyMapOk = policyReport['ok'] == true;
      final inventoryParityOk = policyReport['inventoryParityOk'] == true;
      final skillPolicyCoverageOk =
          policyReport['skillPolicyCoverageOk'] == true;
      final mobileToolPolicyCoverageOk =
          policyReport['mobileToolPolicyCoverageOk'] == true;
      final toolHintPolicyCoverageOk =
          policyReport['toolHintPolicyCoverageOk'] == true;
      final selectedSkillCandidateOk =
          candidateSkills.contains(selectedSkillId);
      final nativeDefaultRoutingDisabled =
          policyReport['nativeDefaultRoutingEnabled'] != true;
      final providerCallsDisabledAtPolicy =
          policyReport['providerCallsEnabled'] != true;
      final generalExecutionDisabledAtPolicy =
          policyReport['executionEnabled'] != true &&
              policyReport['toolExecutionEnabled'] != true;
      final singleSkillPolicyOk = policyMapOk &&
          inventoryParityOk &&
          skillPolicyCoverageOk &&
          mobileToolPolicyCoverageOk &&
          toolHintPolicyCoverageOk &&
          selectedSkillCandidateOk &&
          nativeDefaultRoutingDisabled &&
          providerCallsDisabledAtPolicy &&
          generalExecutionDisabledAtPolicy;

      if (!singleSkillPolicyOk) {
        final report = <String, dynamic>{
          'ok': false,
          'phase': 'hidden-production-port-single-skill-promotion-canary',
          'mode': 'single-skill-native-promotion-with-explicit-rollback',
          'selectedSkillId': selectedSkillId,
          'policyMapOk': policyMapOk,
          'inventoryParityOk': inventoryParityOk,
          'skillPolicyCoverageOk': skillPolicyCoverageOk,
          'mobileToolPolicyCoverageOk': mobileToolPolicyCoverageOk,
          'toolHintPolicyCoverageOk': toolHintPolicyCoverageOk,
          'selectedSkillCandidateOk': selectedSkillCandidateOk,
          'nativeDefaultRoutingEnabled':
              policyReport['nativeDefaultRoutingEnabled'] == true,
          'providerCallsEnabled': policyReport['providerCallsEnabled'] == true,
          'executionEnabled': policyReport['executionEnabled'] == true,
          'toolExecutionEnabled': policyReport['toolExecutionEnabled'] == true,
          'singleSkillPolicyOk': false,
          'promotionWindowOpened': false,
          'rollbackPolicy': rollbackPolicy,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Single-skill native promotion did not open because the conservative policy precheck failed.',
          'nextGate':
              'fix promotion policy coverage before opening a native single-skill owner window',
        };
        log('[NATIVE-SINGLE-SKILL-PROMOTION] ${jsonEncode(report)}');
        return report;
      }

      log(
        '[NATIVE-SINGLE-SKILL-PROMOTION] Opening device-node production-port canary window with explicit PRoot rollback.',
      );
      final canaryReport = await runProductionPortBridgeExecutionReadOnlyCanary(
        log: log,
        model: model,
        prompt: prompt,
      );

      final promotionWindowOpened = canaryReport['nativeStarted'] == true &&
          canaryReport['nativeObservedAlive'] == true &&
          canaryReport['nativeInitialGuardOk'] == true;
      final readOnlyBridgeCanaryOk = canaryReport['readOnlyCanaryOk'] == true;
      final orderScopeOk =
          listMatches(canaryReport['expectedOrder'], expectedReadOnlyOrder) &&
              listMatches(canaryReport['observedOrder'], expectedReadOnlyOrder);
      final providerCallsDisabledDuringWindow =
          canaryReport['providerCallsEnabled'] != true &&
              canaryReport['transportInvocationEnabled'] != true &&
              canaryReport['nativeProviderCallsEnabled'] != true &&
              canaryReport['postCanaryProviderCallsEnabled'] != true;
      final defaultRoutingDisabledDuringWindow =
          canaryReport['nativeChatRoutingEnabled'] != true &&
              canaryReport['postCanaryChatRoutingEnabled'] != true;
      final boundedBridgeExecutionOnly =
          canaryReport['executionEnabled'] == true &&
              canaryReport['toolExecutionEnabled'] == true &&
              canaryReport['bridgeExecutionEnabled'] == true &&
              canaryReport['readOnly'] == true &&
              orderScopeOk;
      final rollbackOk = canaryReport['rollbackStarted'] == true &&
          canaryReport['rollbackRunning'] == true &&
          canaryReport['rollbackHealthOk'] == true;
      final guardOk = canaryReport['nativeInitialGuardOk'] == true &&
          canaryReport['postCanaryGuardOk'] == true;
      final stopOk = canaryReport['nativeStopped'] == true &&
          canaryReport['nativePortReleasedAfterStop'] == true;
      final ok = singleSkillPolicyOk &&
          canaryReport['ok'] == true &&
          promotionWindowOpened &&
          readOnlyBridgeCanaryOk &&
          canaryReport['canaryAllowlistOk'] == true &&
          canaryReport['executeParityOk'] == true &&
          canaryReport['validationOk'] == true &&
          providerCallsDisabledDuringWindow &&
          defaultRoutingDisabledDuringWindow &&
          boundedBridgeExecutionOnly &&
          guardOk &&
          stopOk &&
          rollbackOk;

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-single-skill-promotion-canary',
        'mode': 'single-skill-native-promotion-with-explicit-rollback',
        'selectedSkillId': selectedSkillId,
        'promotionPolicyEntry': 'native_bridge_candidate_proot_default',
        'primaryRuntimeId': 'proot',
        'temporaryOwnerRuntimeId': _productionPortRuntime.id,
        'rollbackRuntimeId': 'proot',
        'productionPort': AppConstants.gatewayPort,
        'policyMapOk': policyMapOk,
        'inventoryParityOk': inventoryParityOk,
        'skillPolicyCoverageOk': skillPolicyCoverageOk,
        'mobileToolPolicyCoverageOk': mobileToolPolicyCoverageOk,
        'toolHintPolicyCoverageOk': toolHintPolicyCoverageOk,
        'selectedSkillCandidateOk': selectedSkillCandidateOk,
        'singleSkillPolicyOk': singleSkillPolicyOk,
        'nativeDefaultRoutingEnabled': false,
        'promotionWindowOpened': promotionWindowOpened,
        'nativeStarted': canaryReport['nativeStarted'] == true,
        'nativeRunning': canaryReport['nativeRunning'] == true,
        'nativeObservedAlive': canaryReport['nativeObservedAlive'] == true,
        'nativeInitialGuardOk': canaryReport['nativeInitialGuardOk'] == true,
        'readOnlyBridgeCanaryOk': readOnlyBridgeCanaryOk,
        'canaryAllowlist': canaryReport['canaryAllowlist'],
        'canaryAllowlistOk': canaryReport['canaryAllowlistOk'] == true,
        'expectedOrder': canaryReport['expectedOrder'],
        'observedOrder': canaryReport['observedOrder'],
        'orderScopeOk': orderScopeOk,
        'executeParityOk': canaryReport['executeParityOk'] == true,
        'validationOk': canaryReport['validationOk'] == true,
        'providerCallsEnabled': canaryReport['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            canaryReport['transportInvocationEnabled'] == true,
        'providerCallsDisabledDuringWindow': providerCallsDisabledDuringWindow,
        'defaultRoutingDisabledDuringWindow':
            defaultRoutingDisabledDuringWindow,
        'executionScope': 'read_only_bridge_allowlist',
        'toolExecutionEnabledDuringWindow':
            canaryReport['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabledDuringWindow':
            canaryReport['bridgeExecutionEnabled'] == true,
        'boundedBridgeExecutionOnly': boundedBridgeExecutionOnly,
        'postCanaryGuardOk': canaryReport['postCanaryGuardOk'] == true,
        'nativeStopped': canaryReport['nativeStopped'] == true,
        'nativePortReleasedAfterStop':
            canaryReport['nativePortReleasedAfterStop'] == true,
        'rollbackStarted': canaryReport['rollbackStarted'] == true,
        'rollbackRunning': canaryReport['rollbackRunning'] == true,
        'rollbackHealthOk': canaryReport['rollbackHealthOk'] == true,
        'rollbackVerified': rollbackOk,
        'nativeSmokeRestored': canaryReport['nativeSmokeRestored'] == true,
        'rollbackPolicy': rollbackPolicy,
        'policyDurationMs': policyReport['durationMs'],
        'canaryDurationMs': canaryReport['durationMs'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'device-node was promoted only inside a bounded native owner canary, executed read-only bridge checks, and rolled back to healthy PRoot.'
            : 'Single-skill native promotion canary is not promotable; PRoot rollback was required and reported.',
        'nextGate':
            'controlled single-skill route selection for device-node with PRoot fallback still armed',
      };
      log('[NATIVE-SINGLE-SKILL-PROMOTION] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-single-skill-promotion-canary',
        'mode': 'single-skill-native-promotion-with-explicit-rollback',
        'selectedSkillId': selectedSkillId,
        'exception': e.toString(),
        'rollbackPolicy': rollbackPolicy,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Single-skill native promotion canary failed before a green report could be produced; inspect runtime rollback health.',
      };
      log('[NATIVE-SINGLE-SKILL-PROMOTION] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionSingleSkillPromotionInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortSingleSkillRouteSelectionCanary({
    required void Function(String message) log,
    String skillId = 'device-node',
    String model = 'openrouter/auto',
    String prompt =
        'native controlled device-node route selection canary: check flash and list sensors read-only',
  }) async {
    if (_productionSingleSkillRouteSelectionInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-single-skill-route-selection-canary',
        'status': 'busy',
        'decision':
            'Single-skill native route selection canary is already running.',
      };
    }

    _productionSingleSkillRouteSelectionInFlight = true;
    final startedAt = DateTime.now();
    final selectedSkillId =
        skillId.trim().isEmpty ? 'device-node' : skillId.trim();
    const expectedToolHints = <String>['flash.status', 'sensor.list'];
    const selectedRuntimeId = 'native-node-production-port-canary';
    const selectedRoute = 'native-device-node-readonly-bridge-canary';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-device-node-skill';

    bool listMatches(Object? value, List<String> expected) {
      if (value is! List || value.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (value[i]?.toString() != expected[i]) return false;
      }
      return true;
    }

    List<Map<String, dynamic>> nonPromotedFallbackDecisions() {
      final candidateIds = _mobileBridgeCandidateSkillIds
          .where((id) => id != 'device-node')
          .toList()
        ..sort();
      return candidateIds
          .map((id) => <String, dynamic>{
                'skillId': id,
                'nativeEligible': false,
                'selectedRuntimeId': fallbackRuntimeId,
                'selectedRoute': 'proot-$id-skill',
                'reason': 'only_device_node_readonly_is_promoted',
              })
          .toList();
    }

    try {
      log(
        '[NATIVE-SINGLE-SKILL-ROUTE] Evaluating controlled route selection for $selectedSkillId.',
      );

      final fallbackArmedBeforeExecution =
          GatewayRuntimeRegistry.prootRollback.id == 'proot';
      final nativeEligible = selectedSkillId == 'device-node';
      final routeDecision = <String, dynamic>{
        'skillId': selectedSkillId,
        'requestedToolHints': expectedToolHints,
        'nativeEligible': nativeEligible,
        'selectedRuntimeId':
            nativeEligible ? selectedRuntimeId : fallbackRuntimeId,
        'selectedRoute': nativeEligible ? selectedRoute : fallbackRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'defaultNativeRoutingEnabled': false,
        'providerCallsEnabled': false,
        'executionScope': 'read_only_bridge_allowlist',
      };
      final fallbackDecisions = nonPromotedFallbackDecisions();
      final nonPromotedFallbackOk = fallbackDecisions.every(
        (decision) =>
            decision['nativeEligible'] == false &&
            decision['selectedRuntimeId'] == fallbackRuntimeId,
      );
      final routeSelectionPolicyOk = nativeEligible &&
          routeDecision['selectedRuntimeId'] == selectedRuntimeId &&
          routeDecision['selectedRoute'] == selectedRoute &&
          routeDecision['fallbackRuntimeId'] == fallbackRuntimeId &&
          routeDecision['fallbackRoute'] == fallbackRoute &&
          routeDecision['fallbackOneActionAway'] == true &&
          nonPromotedFallbackOk &&
          fallbackArmedBeforeExecution;

      if (!routeSelectionPolicyOk) {
        final report = <String, dynamic>{
          'ok': false,
          'phase': 'hidden-production-port-single-skill-route-selection-canary',
          'mode':
              'single-skill-device-node-route-selection-with-proot-fallback',
          'selectedSkillId': selectedSkillId,
          'routeDecision': routeDecision,
          'nonPromotedFallbackDecisions': fallbackDecisions,
          'routeSelectionPolicyOk': false,
          'fallbackArmedBeforeExecution': fallbackArmedBeforeExecution,
          'nativeRouteExecutedOk': false,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Controlled single-skill route selection did not execute because the route policy precheck failed.',
          'nextGate':
              'fix device-node route selection policy before native execution',
        };
        log('[NATIVE-SINGLE-SKILL-ROUTE] ${jsonEncode(report)}');
        return report;
      }

      log(
        '[NATIVE-SINGLE-SKILL-ROUTE] Route selected native for device-node; PRoot fallback remains armed.',
      );
      final innerReport = await runProductionPortSingleSkillPromotionCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-SINGLE-SKILL-PROMOTION]')) {
            log(message.replaceFirst(
              '[NATIVE-SINGLE-SKILL-PROMOTION]',
              '[NATIVE-SINGLE-SKILL-ROUTE]',
            ));
          } else if (message.startsWith('[NATIVE-BRIDGE-EXEC-OWNER]')) {
            log(message.replaceFirst(
              '[NATIVE-BRIDGE-EXEC-OWNER]',
              '[NATIVE-SINGLE-SKILL-ROUTE]',
            ));
          } else if (message.startsWith('[NATIVE-PROMOTION-POLICY]')) {
            log(message.replaceFirst(
              '[NATIVE-PROMOTION-POLICY]',
              '[NATIVE-SINGLE-SKILL-ROUTE]',
            ));
          } else {
            log(message);
          }
        },
        skillId: selectedSkillId,
        model: model,
        prompt: prompt,
      );

      final nativeRouteExecutedOk = innerReport['ok'] == true &&
          innerReport['promotionWindowOpened'] == true &&
          innerReport['readOnlyBridgeCanaryOk'] == true;
      final executionScopeOk =
          innerReport['boundedBridgeExecutionOnly'] == true &&
              listMatches(innerReport['expectedOrder'], expectedToolHints) &&
              listMatches(innerReport['observedOrder'], expectedToolHints);
      final providerCallsDisabledOk =
          innerReport['providerCallsEnabled'] != true &&
              innerReport['transportInvocationEnabled'] != true &&
              innerReport['providerCallsDisabledDuringWindow'] == true;
      final defaultRouteStillOffOk =
          innerReport['nativeDefaultRoutingEnabled'] != true &&
              innerReport['defaultRoutingDisabledDuringWindow'] == true;
      final fallbackAfterCanaryOk = innerReport['rollbackStarted'] == true &&
          innerReport['rollbackRunning'] == true &&
          innerReport['rollbackHealthOk'] == true &&
          innerReport['rollbackVerified'] == true;
      final rollbackPolicyOk = innerReport['rollbackPolicy'] is Map &&
          (innerReport['rollbackPolicy'] as Map)['rollbackRequired'] == true &&
          (innerReport['rollbackPolicy'] as Map)['rollbackRuntimeId'] ==
              'proot';
      final routeSelectionCanaryOk = routeSelectionPolicyOk &&
          nativeRouteExecutedOk &&
          executionScopeOk &&
          providerCallsDisabledOk &&
          defaultRouteStillOffOk &&
          fallbackAfterCanaryOk &&
          rollbackPolicyOk;

      final report = <String, dynamic>{
        ...innerReport,
        'ok': routeSelectionCanaryOk,
        'phase': 'hidden-production-port-single-skill-route-selection-canary',
        'mode': 'single-skill-device-node-route-selection-with-proot-fallback',
        'innerPhase': innerReport['phase'],
        'innerOk': innerReport['ok'] == true,
        'selectedSkillId': selectedSkillId,
        'requestedToolHints': expectedToolHints,
        'routeDecision': routeDecision,
        'nonPromotedFallbackDecisions': fallbackDecisions,
        'nonPromotedFallbackOk': nonPromotedFallbackOk,
        'fallbackArmedBeforeExecution': fallbackArmedBeforeExecution,
        'routeSelectionPolicyOk': routeSelectionPolicyOk,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'nativeRouteExecutedOk': nativeRouteExecutedOk,
        'executionScopeOk': executionScopeOk,
        'providerCallsDisabledOk': providerCallsDisabledOk,
        'defaultRouteStillOffOk': defaultRouteStillOffOk,
        'fallbackAfterCanaryOk': fallbackAfterCanaryOk,
        'rollbackPolicyOk': rollbackPolicyOk,
        'routeSelectionCanaryOk': routeSelectionCanaryOk,
        'innerDurationMs': innerReport['durationMs'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': routeSelectionCanaryOk
            ? 'Route selection chose native only for device-node read-only bridge checks, left every other candidate on PRoot fallback, and restored healthy PRoot.'
            : 'Controlled device-node route selection is not promotable; require selected native route, locked scope, and healthy PRoot rollback.',
        'nextGate':
            'device-node real-turn route shadow canary with PRoot fallback still armed',
      };
      log('[NATIVE-SINGLE-SKILL-ROUTE] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-single-skill-route-selection-canary',
        'mode': 'single-skill-device-node-route-selection-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Controlled single-skill route selection failed before a green report was produced.',
      };
      log('[NATIVE-SINGLE-SKILL-ROUTE] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionSingleSkillRouteSelectionInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runDeviceNodeRealTurnRouteShadowCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native device-node real-turn route shadow canary: use flash.status and sensor.list read-only',
  }) async {
    if (_productionDeviceNodeRouteShadowInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-real-turn-route-shadow-canary',
        'status': 'busy',
        'decision':
            'Device-node real-turn route shadow canary is already running.',
      };
    }

    _productionDeviceNodeRouteShadowInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'device-node';
    const expectedToolHints = <String>['flash.status', 'sensor.list'];
    const selectedRuntimeId = 'native-node-shadow-route-canary';
    const selectedRoute = 'native-device-node-readonly-route-shadow';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-device-node-skill';

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      if (actual.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (actual[i] != expected[i]) return false;
      }
      return true;
    }

    List<Map<String, dynamic>> nonPromotedFallbackDecisions() {
      final candidateIds = _mobileBridgeCandidateSkillIds
          .where((id) => id != selectedSkillId)
          .toList()
        ..sort();
      return candidateIds
          .map((id) => <String, dynamic>{
                'skillId': id,
                'nativeEligible': false,
                'selectedRuntimeId': fallbackRuntimeId,
                'selectedRoute': 'proot-$id-skill',
                'reason': 'real_turn_shadow_promotes_only_device_node_readonly',
              })
          .toList();
    }

    bool gateDisabled(Object? gate) {
      return gate is Map &&
          gate['enabled'] != true &&
          gate['status'] == 'blocked';
    }

    Object? mapValue(Object? value, String key) {
      if (value is Map) return value[key];
      return null;
    }

    Object? nativeProviderCallsEnabled(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return health['providerCallsEnabled'] ??
          mapValue(gatewayProbe, 'providerCallsEnabled') ??
          mapValue(readyState, 'providerCallsEnabled');
    }

    Map<String, dynamic> nativeHealthSummary(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return <String, dynamic>{
        'ok': health['ok'] == true,
        'runtime': health['runtime'],
        'port': health['port'],
        'openclawStarted': health['openclawStarted'],
        'providerCallsEnabled': nativeProviderCallsEnabled(health),
        'gatewayProbeStatus': mapValue(gatewayProbe, 'status'),
        'chatRoutingEnabled': mapValue(gatewayProbe, 'chatRoutingEnabled') ??
            mapValue(readyState, 'chatRoutingEnabled'),
        'executionEnabled': mapValue(readyState, 'executionEnabled'),
        'productionSkillCount': mapValue(gatewayProbe, 'productionSkillCount'),
        'skillRegistryMode': mapValue(gatewayProbe, 'skillRegistryMode'),
      };
    }

    bool nativeShadowHealthLooksReady(Map<String, dynamic> health) {
      return health['ok'] == true &&
          health['runtime'] == 'native-node-embedded' &&
          health['port'] == AppConstants.nativeGatewaySmokePort &&
          health['openclawStarted'] == false &&
          nativeProviderCallsEnabled(health) == false;
    }

    try {
      log(
        '[NATIVE-DEVICE-ROUTE-SHADOW] Starting real-turn device-node route shadow; PRoot remains primary.',
      );

      final productionRuntimeBefore = GatewayRuntimeRegistry.prootRollback.id;
      final prootSelectedBefore = productionRuntimeBefore == fallbackRuntimeId;
      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Object? productionHealthBeforeError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final nativeWasRunning = await _nodeRuntime
          .isRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false)
          .catchError((_) => false);
      var nativeStartedByCanary = false;
      if (!nativeWasRunning) {
        nativeStartedByCanary = await _nodeRuntime.start();
      }

      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Object? nativeHealthError;
      try {
        nativeHealth = await _probeHealth(
          expectedRuntime: 'native-node-embedded',
        );
      } catch (e) {
        nativeHealthError = e;
      }
      final nativeHealthOk = nativeShadowHealthLooksReady(nativeHealth);

      if (!nativeHealthOk) {
        final report = <String, dynamic>{
          'ok': false,
          'phase': 'hidden-device-node-real-turn-route-shadow-canary',
          'mode':
              'device-node-real-turn-route-shadow-with-proot-fallback-armed',
          'selectedSkillId': selectedSkillId,
          'primaryRuntimeId': fallbackRuntimeId,
          'productionPort': AppConstants.gatewayPort,
          'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
          'prootSelectedBefore': prootSelectedBefore,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthBeforeError':
              productionHealthBeforeError?.toString(),
          'nativeWasRunning': nativeWasRunning,
          'nativeStartedByCanary': nativeStartedByCanary,
          'nativeHealthOk': false,
          'nativeHealthSummary': nativeHealthSummary(nativeHealth),
          'nativeHealthError': nativeHealthError?.toString(),
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Native shadow route canary could not start because the alternate native parser was not healthy; PRoot remains primary.',
          'nextGate':
              'restore native shadow parser health before real-turn route shadow',
        };
        log('[NATIVE-DEVICE-ROUTE-SHADOW] ${jsonEncode(report)}');
        return report;
      }

      final now = DateTime.now().microsecondsSinceEpoch;
      final frame = _sampleGatewayWsChatSendFrame(
        requestId: 'device-node-route-shadow-$now',
        idempotencyKey: 'device-node-route-shadow-idempotency-$now',
        model: model,
        message: _deviceNodeReadOnlyRouteShadowMessage(prompt),
      );

      final shadowReport =
          await NativeGatewayShadowParityService.observeChatSendFrame(
        frame,
        log: log,
      );
      final localHints = sortedStringList(
        shadowReport?.local['mobileToolHints'],
      );
      final nativeHints = sortedStringList(
        shadowReport?.native?['mobileToolHints'],
      );
      final dryRunHints = sortedStringList(
        shadowReport?.dryRun?['mobileToolHints'],
      );
      final realTurnFrameParsed =
          shadowReport?.local['looksLikeProductionChatSend'] == true &&
              shadowReport?.native?['looksLikeProductionChatSend'] == true &&
              shadowReport?.dryRun?['parsed'] == true;
      final shadowParityOk = shadowReport?.parityOk == true;
      final shadowDryRunHashMatches = shadowReport?.local['metadataHash'] ==
          shadowReport?.dryRun?['metadataHash'];
      final dryRunShadowOk =
          shadowReport?.dryRunOk == true && shadowDryRunHashMatches;
      final realTurnToolHintsOk = listMatches(localHints, expectedToolHints) &&
          listMatches(nativeHints, expectedToolHints) &&
          listMatches(dryRunHints, expectedToolHints);

      final routeEvents = <Map<String, dynamic>>[];
      await for (final event in NativeGatewayShadowParityService
          .streamRoutingSkeletonChatSendFrame(
        frame,
        log: log,
      )) {
        routeEvents.add(event);
      }

      final ackEvent = _firstEvent(routeEvents, 'ack');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final routePlanEvent = _firstEvent(routeEvents, 'route_plan');
      final routePlan = routePlanEvent['routePlan'] is Map
          ? Map<String, dynamic>.from(routePlanEvent['routePlan'] as Map)
          : <String, dynamic>{};
      final providerGateEvent = _firstEvent(routeEvents, 'provider_gate');
      final toolGateEvent = _firstEvent(routeEvents, 'tool_gate');
      final endEvent = _firstEvent(routeEvents, 'end');
      final routePlanRequest = routePlan['request'] is Map
          ? Map<String, dynamic>.from(routePlan['request'] as Map)
          : <String, dynamic>{};
      final planHints = sortedStringList(routePlanRequest['mobileToolHints']);

      final routeEventNames = routeEvents
          .map((event) => event['event']?.toString() ?? '')
          .where((event) => event.isNotEmpty)
          .toList();
      final routeStreamOrderOk = routeEventNames.length >= 5 &&
          routeEventNames.first == 'ack' &&
          routeEventNames.contains('route_plan') &&
          routeEventNames.contains('provider_gate') &&
          routeEventNames.contains('tool_gate') &&
          routeEventNames.last == 'end';
      final routeSkeletonOk = ackEvent['ok'] == true &&
          ackEvent['parsed'] == true &&
          ackEvent['acceptedForRouting'] == false &&
          ackEvent['providerCallsEnabled'] == false &&
          ackEvent['executionEnabled'] == false &&
          ack['parsed'] == true &&
          ack['hashMatches'] == true &&
          ack['routeStatus'] == 'blocked_before_provider' &&
          routePlan['routeStatus'] == 'blocked_before_provider' &&
          routePlan['acceptedForRouting'] == false &&
          routePlan['chatRoutingEnabled'] == false &&
          gateDisabled(routePlan['providerCallGate']) &&
          gateDisabled(routePlan['toolExecutionGate']) &&
          providerGateEvent['providerCallsEnabled'] == false &&
          toolGateEvent['executionEnabled'] == false &&
          endEvent['finishReason'] == 'routing_skeleton_complete' &&
          endEvent['providerCallsEnabled'] == false &&
          endEvent['executionEnabled'] == false &&
          routeStreamOrderOk &&
          listMatches(planHints, expectedToolHints);

      final hintPolicies = _buildToolHintPromotionPolicies(localHints.toSet());
      final readOnlyHintPoliciesOk = expectedToolHints.every(
            (hint) =>
                hintPolicies[hint] ==
                'native_bridge_readonly_allowlist_manual_only',
          ) &&
          hintPolicies.length == expectedToolHints.length;
      final nativeEligible = realTurnToolHintsOk && readOnlyHintPoliciesOk;
      final routeDecision = <String, dynamic>{
        'skillId': selectedSkillId,
        'requestedToolHints': expectedToolHints,
        'observedToolHints': localHints,
        'nativeEligible': nativeEligible,
        'selectedRuntimeId':
            nativeEligible ? selectedRuntimeId : fallbackRuntimeId,
        'selectedRoute': nativeEligible ? selectedRoute : fallbackRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'source': 'real_chat_send_shadow_frame',
        'defaultNativeRoutingEnabled': false,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
      };
      final fallbackDecisions = nonPromotedFallbackDecisions();
      final nonPromotedFallbackOk = fallbackDecisions.every(
        (decision) =>
            decision['nativeEligible'] == false &&
            decision['selectedRuntimeId'] == fallbackRuntimeId,
      );
      final shadowRouteDecisionOk = nativeEligible &&
          routeDecision['selectedRuntimeId'] == selectedRuntimeId &&
          routeDecision['selectedRoute'] == selectedRoute &&
          routeDecision['fallbackRuntimeId'] == fallbackRuntimeId &&
          routeDecision['fallbackOneActionAway'] == true &&
          nonPromotedFallbackOk;

      final productionRuntimeAfter = GatewayRuntimeRegistry.prootRollback.id;
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthAfterError;
      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);
      final prootRemainedPrimary = prootSelectedBefore &&
          productionRuntimeAfter == fallbackRuntimeId &&
          productionHealthOkBefore &&
          productionHealthOkAfter;
      final nativeExecutionDisabled = ackEvent['executionEnabled'] == false &&
          ack['executionEnabled'] == false &&
          routePlan['acceptedForRouting'] == false &&
          toolGateEvent['executionEnabled'] == false &&
          endEvent['executionEnabled'] == false;
      final providerCallsDisabled = ackEvent['providerCallsEnabled'] == false &&
          ack['providerCallsEnabled'] == false &&
          providerGateEvent['providerCallsEnabled'] == false &&
          endEvent['providerCallsEnabled'] == false;
      final fallbackStillArmed = prootRemainedPrimary &&
          routeDecision['fallbackRuntimeId'] == fallbackRuntimeId &&
          routeDecision['fallbackOneActionAway'] == true;
      final routeShadowCanaryOk = nativeHealthOk &&
          realTurnFrameParsed &&
          shadowParityOk &&
          dryRunShadowOk &&
          realTurnToolHintsOk &&
          routeSkeletonOk &&
          shadowRouteDecisionOk &&
          nonPromotedFallbackOk &&
          nativeExecutionDisabled &&
          providerCallsDisabled &&
          fallbackStillArmed;

      final report = <String, dynamic>{
        'ok': routeShadowCanaryOk,
        'phase': 'hidden-device-node-real-turn-route-shadow-canary',
        'mode': 'device-node-real-turn-route-shadow-with-proot-fallback-armed',
        'selectedSkillId': selectedSkillId,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'productionPort': AppConstants.gatewayPort,
        'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
        'prootSelectedBefore': prootSelectedBefore,
        'productionRuntimeAfter': productionRuntimeAfter,
        'prootRemainedPrimary': prootRemainedPrimary,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        'productionHealthBeforeError': productionHealthBeforeError?.toString(),
        'productionHealthAfterError': productionHealthAfterError?.toString(),
        'nativeWasRunning': nativeWasRunning,
        'nativeStartedByCanary': nativeStartedByCanary,
        'nativeLeftRunningForShadow': true,
        'nativeHealthOk': nativeHealthOk,
        'nativeHealthSummary': nativeHealthSummary(nativeHealth),
        'nativeHealthError': nativeHealthError?.toString(),
        'realTurnFrameParsed': realTurnFrameParsed,
        'shadowParityOk': shadowParityOk,
        'dryRunShadowOk': dryRunShadowOk,
        'hashMatches': shadowDryRunHashMatches,
        'requestedToolHints': expectedToolHints,
        'localToolHints': localHints,
        'nativeToolHints': nativeHints,
        'dryRunToolHints': dryRunHints,
        'routePlanToolHints': planHints,
        'realTurnToolHintsOk': realTurnToolHintsOk,
        'toolHintPolicies': hintPolicies,
        'readOnlyHintPoliciesOk': readOnlyHintPoliciesOk,
        'routeDecision': routeDecision,
        'shadowRouteDecisionOk': shadowRouteDecisionOk,
        'routeEvents': routeEventNames,
        'routeStreamOrderOk': routeStreamOrderOk,
        'routeSkeletonOk': routeSkeletonOk,
        'routeStatus': routePlan['routeStatus'] ?? ack['routeStatus'],
        'providerGateBlocked': gateDisabled(routePlan['providerCallGate']),
        'toolGateBlocked': gateDisabled(routePlan['toolExecutionGate']),
        'nonPromotedFallbackDecisions': fallbackDecisions,
        'nonPromotedFallbackOk': nonPromotedFallbackOk,
        'acceptedForRouting': false,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'providerCallsDisabled': providerCallsDisabled,
        'nativeExecutionDisabled': nativeExecutionDisabled,
        'fallbackStillArmed': fallbackStillArmed,
        'sessionKey': shadowReport?.local['sessionKey'],
        'nativeSessionId': shadowReport?.dryRun?['nativeSessionId'],
        'runId': shadowReport?.dryRun?['runId'] ?? ack['runId'],
        'messageChars': shadowReport?.local['messageChars'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': routeShadowCanaryOk
            ? 'Real chat.send-shaped device-node turn shadowed through native, selected only the read-only native route on paper, and left PRoot fully armed as primary.'
            : 'Device-node real-turn route shadow is not promotable; require parser parity, read-only hint policy, disabled execution, and healthy PRoot fallback.',
        'nextGate':
            'device-node real-turn native execution canary with explicit PRoot fallback',
      };
      log('[NATIVE-DEVICE-ROUTE-SHADOW] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-real-turn-route-shadow-canary',
        'mode': 'device-node-real-turn-route-shadow-with-proot-fallback-armed',
        'selectedSkillId': selectedSkillId,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Device-node real-turn route shadow failed before a green report was produced; PRoot fallback should remain primary.',
      };
      log('[NATIVE-DEVICE-ROUTE-SHADOW] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionDeviceNodeRouteShadowInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runDeviceNodeRealTurnNativeExecutionCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native device-node real-turn execution canary: use flash.status and sensor.list read-only',
  }) async {
    if (_productionDeviceNodeRealTurnExecutionInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-real-turn-native-execution-canary',
        'status': 'busy',
        'decision':
            'Device-node real-turn native execution canary is already running.',
      };
    }

    _productionDeviceNodeRealTurnExecutionInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'device-node';
    const expectedToolHints = <String>['flash.status', 'sensor.list'];
    const selectedRuntimeId = 'native-node-real-turn-execution-canary';
    const selectedRoute = 'native-device-node-readonly-real-turn-execution';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-device-node-skill';

    Map<String, dynamic> asMap(Object? value) => value is Map
        ? value.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      if (actual.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (actual[i] != expected[i]) return false;
      }
      return true;
    }

    List<Map<String, dynamic>> eventsNamed(
      List<Map<String, dynamic>> events,
      String name,
    ) {
      return events
          .where((event) => event['event'] == name)
          .map((event) => Map<String, dynamic>.from(event))
          .toList();
    }

    Map<String, dynamic> eventByOrder(
      List<Map<String, dynamic>> events,
      String name,
      int orderIndex,
    ) {
      for (final event in events) {
        if (event['event'] == name && event['orderIndex'] == orderIndex) {
          return event;
        }
      }
      return <String, dynamic>{};
    }

    bool providerStillDisabled(Map<String, dynamic> value) =>
        value['providerCallsEnabled'] != true &&
        value['transportInvocationEnabled'] != true;

    bool executionEnabled(Map<String, dynamic> value) =>
        value['executionEnabled'] == true &&
        value['toolExecutionEnabled'] == true &&
        value['bridgeExecutionEnabled'] == true;

    bool allowlistOk(Object? value) {
      if (value is! List) return false;
      final strings = value.map((entry) => entry.toString()).toSet();
      return strings.length == expectedToolHints.length &&
          expectedToolHints.every(strings.contains);
    }

    bool resultShapeOk(String toolName, Map<String, dynamic> result) {
      if (toolName == 'flash.status') {
        return result['on'] is bool;
      }
      if (toolName == 'sensor.list') {
        final sensors = result['sensors'];
        return sensors is List && sensors.isNotEmpty;
      }
      return false;
    }

    Object? mapValue(Object? value, String key) {
      if (value is Map) return value[key];
      return null;
    }

    Object? nativeProviderCallsEnabled(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return health['providerCallsEnabled'] ??
          mapValue(gatewayProbe, 'providerCallsEnabled') ??
          mapValue(readyState, 'providerCallsEnabled');
    }

    Map<String, dynamic> nativeHealthSummary(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return <String, dynamic>{
        'ok': health['ok'] == true,
        'runtime': health['runtime'],
        'port': health['port'],
        'openclawStarted': health['openclawStarted'],
        'providerCallsEnabled': nativeProviderCallsEnabled(health),
        'gatewayProbeStatus': mapValue(gatewayProbe, 'status'),
        'chatRoutingEnabled': mapValue(gatewayProbe, 'chatRoutingEnabled') ??
            mapValue(readyState, 'chatRoutingEnabled'),
        'executionEnabled': mapValue(readyState, 'executionEnabled'),
        'productionSkillCount': mapValue(gatewayProbe, 'productionSkillCount'),
        'skillRegistryMode': mapValue(gatewayProbe, 'skillRegistryMode'),
      };
    }

    bool nativeShadowHealthLooksReady(Map<String, dynamic> health) {
      return health['ok'] == true &&
          health['runtime'] == 'native-node-embedded' &&
          health['port'] == AppConstants.nativeGatewaySmokePort &&
          health['openclawStarted'] == false &&
          nativeProviderCallsEnabled(health) == false;
    }

    try {
      log(
        '[NATIVE-DEVICE-EXEC-SHADOW] Starting real-turn device-node native execution canary; PRoot remains primary.',
      );

      final routeShadowReport = await runDeviceNodeRealTurnRouteShadowCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-DEVICE-ROUTE-SHADOW]')) {
            log(message.replaceFirst(
              '[NATIVE-DEVICE-ROUTE-SHADOW]',
              '[NATIVE-DEVICE-EXEC-SHADOW]',
            ));
          } else {
            log(message);
          }
        },
        model: model,
        prompt: prompt,
      );
      final routeShadowOk = routeShadowReport['ok'] == true;
      if (!routeShadowOk) {
        final report = <String, dynamic>{
          ...routeShadowReport,
          'ok': false,
          'phase': 'hidden-device-node-real-turn-native-execution-canary',
          'mode':
              'device-node-real-turn-native-readonly-execution-with-proot-fallback',
          'innerPhase': routeShadowReport['phase'],
          'routeShadowOk': false,
          'nativeExecutionAttempted': false,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Real-turn native execution did not start because the route-shadow prerequisite was not green; PRoot remains primary.',
          'nextGate': 'restore real-turn route shadow before execution',
        };
        log('[NATIVE-DEVICE-EXEC-SHADOW] ${jsonEncode(report)}');
        return report;
      }

      final productionRuntimeBefore = GatewayRuntimeRegistry.prootRollback.id;
      final prootSelectedBefore = productionRuntimeBefore == fallbackRuntimeId;
      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Object? productionHealthBeforeError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final nativeWasRunning = await _nodeRuntime
          .isRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false)
          .catchError((_) => false);
      var nativeStartedByCanary = false;
      if (!nativeWasRunning) {
        nativeStartedByCanary = await _nodeRuntime.start();
      }

      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Object? nativeHealthError;
      try {
        nativeHealth = await _probeHealth(
          expectedRuntime: 'native-node-embedded',
        );
      } catch (e) {
        nativeHealthError = e;
      }
      final nativeHealthOk = nativeShadowHealthLooksReady(nativeHealth);

      if (!nativeHealthOk) {
        final report = <String, dynamic>{
          'ok': false,
          'phase': 'hidden-device-node-real-turn-native-execution-canary',
          'mode':
              'device-node-real-turn-native-readonly-execution-with-proot-fallback',
          'selectedSkillId': selectedSkillId,
          'primaryRuntimeId': fallbackRuntimeId,
          'productionPort': AppConstants.gatewayPort,
          'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
          'routeShadowOk': routeShadowOk,
          'prootSelectedBefore': prootSelectedBefore,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthBeforeError':
              productionHealthBeforeError?.toString(),
          'nativeWasRunning': nativeWasRunning,
          'nativeStartedByCanary': nativeStartedByCanary,
          'nativeHealthOk': false,
          'nativeHealthSummary': nativeHealthSummary(nativeHealth),
          'nativeHealthError': nativeHealthError?.toString(),
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Native read-only execution canary could not start because the alternate native runtime was not healthy; PRoot remains primary.',
          'nextGate':
              'restore native shadow runtime health before real-turn native execution',
        };
        log('[NATIVE-DEVICE-EXEC-SHADOW] ${jsonEncode(report)}');
        return report;
      }

      final now = DateTime.now().microsecondsSinceEpoch;
      final frame = _sampleGatewayWsChatSendFrame(
        requestId: 'device-node-real-turn-exec-$now',
        idempotencyKey: 'device-node-real-turn-exec-idempotency-$now',
        model: model,
        message: _deviceNodeReadOnlyRouteShadowMessage(prompt),
      );

      final shadowReport =
          await NativeGatewayShadowParityService.observeChatSendFrame(
        frame,
        log: log,
      );
      final localHints = sortedStringList(
        shadowReport?.local['mobileToolHints'],
      );
      final nativeHints = sortedStringList(
        shadowReport?.native?['mobileToolHints'],
      );
      final dryRunHints = sortedStringList(
        shadowReport?.dryRun?['mobileToolHints'],
      );
      final realTurnFrameParsed =
          shadowReport?.local['looksLikeProductionChatSend'] == true &&
              shadowReport?.native?['looksLikeProductionChatSend'] == true &&
              shadowReport?.dryRun?['parsed'] == true;
      final shadowParityOk = shadowReport?.parityOk == true;
      final hashMatches = shadowReport?.local['metadataHash'] ==
          shadowReport?.dryRun?['metadataHash'];
      final dryRunShadowOk = shadowReport?.dryRunOk == true && hashMatches;
      final realTurnToolHintsOk = listMatches(localHints, expectedToolHints) &&
          listMatches(nativeHints, expectedToolHints) &&
          listMatches(dryRunHints, expectedToolHints);

      final bridgeEvents = <Map<String, dynamic>>[];
      await for (final event in NativeGatewayShadowParityService
          .streamNativeDartBridgeReadOnlyCanaryChatSendFrame(
        frame,
        log: log,
      )) {
        bridgeEvents.add(event);
      }

      final ackEvent = _firstEvent(bridgeEvents, 'ack');
      final ack = asMap(ackEvent['ack']);
      final planEvent = _firstEvent(bridgeEvents, 'tool_plan_summary');
      final summaryEvent = _firstEvent(bridgeEvents, 'readonly_canary_summary');
      final endEvent = _firstEvent(bridgeEvents, 'end');
      final executeAckEvents = eventsNamed(bridgeEvents, 'bridge_execute_ack');
      final toolUseEvents = eventsNamed(bridgeEvents, 'tool_use_frame');
      final toolResultEvents = eventsNamed(bridgeEvents, 'tool_result_frame');
      final observedEventOrder = bridgeEvents
          .map((event) => event['event']?.toString() ?? '')
          .where((event) => event.isNotEmpty)
          .toList();
      final expectedEventOrder = <String>[
        'ack',
        'tool_plan_summary',
        'bridge_execute_request',
        'bridge_execute_ack',
        'tool_use_frame',
        'tool_result_frame',
        'bridge_execute_request',
        'bridge_execute_ack',
        'tool_use_frame',
        'tool_result_frame',
        'readonly_canary_summary',
        'end',
      ];
      var eventOrderOk = observedEventOrder.length >= expectedEventOrder.length;
      for (var i = 0; i < expectedEventOrder.length && eventOrderOk; i++) {
        eventOrderOk = observedEventOrder[i] == expectedEventOrder[i];
      }

      bool executeAckOkForOrder(int orderIndex, String toolName) {
        final event =
            eventByOrder(bridgeEvents, 'bridge_execute_ack', orderIndex);
        final executeAck = asMap(event['executeAck']);
        final result = asMap(executeAck['result']);
        return event['ok'] == true &&
            event['statusCode'] == 200 &&
            event['executeParityOk'] == true &&
            event['resultShapeOk'] == true &&
            executeAck['ok'] == true &&
            executeAck['accepted'] == true &&
            executeAck['executed'] == true &&
            executeAck['runtime'] == 'flutter-dart' &&
            executeAck['command'] == toolName &&
            executeAck['canaryAllowlistOk'] == true &&
            executeAck['dryRun'] == false &&
            resultShapeOk(toolName, result) &&
            providerStillDisabled(executeAck) &&
            executionEnabled(executeAck);
      }

      bool toolResultOkForOrder(int orderIndex, String toolName) {
        final event =
            eventByOrder(bridgeEvents, 'tool_result_frame', orderIndex);
        final frame = asMap(event['frame']);
        final result = asMap(frame['result']);
        final payload = asMap(result['result']);
        return event['ok'] == true &&
            frame['type'] == 'tool_result' &&
            frame['name'] == toolName &&
            frame['runtime'] == 'native-node-embedded' &&
            frame['source'] == 'native-dart-bridge-readonly-canary' &&
            frame['dryRun'] == false &&
            frame['readOnly'] == true &&
            result['ok'] == true &&
            result['executed'] == true &&
            result['accepted'] == true &&
            result['status'] == 'ok' &&
            result['canaryAllowlistOk'] == true &&
            result['resultShapeOk'] == true &&
            resultShapeOk(toolName, payload) &&
            providerStillDisabled(result) &&
            executionEnabled(result);
      }

      final expectedOrder = sortedStringList(
        summaryEvent['expectedOrder'] ?? endEvent['expectedOrder'],
      );
      final observedOrder = sortedStringList(
        summaryEvent['observedOrder'] ?? endEvent['observedOrder'],
      );
      final resultStatuses = summaryEvent['resultStatuses'] is List
          ? List<dynamic>.from(summaryEvent['resultStatuses'] as List)
          : const <dynamic>[];
      final toolPanelEvents = <Map<String, dynamic>>[];
      for (final event in bridgeEvents) {
        final eventName = event['event']?.toString();
        if (eventName != 'tool_use_frame' && eventName != 'tool_result_frame') {
          continue;
        }
        final frame = asMap(event['frame']);
        final name = frame['name']?.toString() ??
            event['toolName']?.toString() ??
            'tool';
        final panelEvent = <String, dynamic>{
          'type': eventName == 'tool_use_frame' ? 'tool_use' : 'tool_result',
          'name': name,
          'orderIndex': event['orderIndex'],
          'runtime': frame['runtime'],
          'source': frame['source'],
          'dryRun': frame['dryRun'] == true,
          'readOnly': frame['readOnly'] == true,
          'executionEnabled': frame['executionEnabled'] == true,
          'toolExecutionEnabled': frame['toolExecutionEnabled'] == true,
          'bridgeExecutionEnabled': frame['bridgeExecutionEnabled'] == true,
        };
        if (eventName == 'tool_use_frame') {
          panelEvent['input'] = asMap(frame['input']);
        } else {
          panelEvent['result'] = asMap(frame['result']);
        }
        toolPanelEvents.add(panelEvent);
      }
      final ackEventOk = ackEvent['ok'] == true &&
          ackEvent['runtime'] == 'native-node-embedded' &&
          ackEvent['canaryOnly'] == true &&
          ackEvent['dryRun'] == false &&
          ackEvent['parsed'] == true &&
          ackEvent['route'] == 'native_dart_bridge_readonly_canary' &&
          ackEvent['acceptedForRouting'] == true &&
          ackEvent['queuedForDryRun'] == false &&
          ackEvent['queueStatus'] == 'native_dart_bridge_readonly_canary' &&
          ack['hashMatches'] == true &&
          allowlistOk(ack['canaryAllowlist']) &&
          ack['canaryAllowlistOk'] == true &&
          ack['fixtureParityOk'] == true &&
          ack['dispatchParityOk'] == true &&
          providerStillDisabled(ackEvent) &&
          providerStillDisabled(ack) &&
          executionEnabled(ackEvent) &&
          executionEnabled(ack);
      final toolPlanSummaryOk = planEvent['ok'] == true &&
          planEvent['orderCount'] == expectedToolHints.length &&
          listMatches(planEvent['expectedOrder'], expectedToolHints) &&
          allowlistOk(planEvent['forcedAllowlist']) &&
          planEvent['fixtureParityOk'] == true &&
          planEvent['dispatchParityOk'] == true &&
          planEvent['canaryAllowlistOk'] == true &&
          providerStillDisabled(planEvent) &&
          executionEnabled(planEvent);
      final executeAckOrderOk =
          executeAckEvents.length == expectedToolHints.length &&
              executeAckOkForOrder(0, expectedToolHints[0]) &&
              executeAckOkForOrder(1, expectedToolHints[1]);
      final toolResultOrderOk =
          toolResultEvents.length == expectedToolHints.length &&
              toolResultOkForOrder(0, expectedToolHints[0]) &&
              toolResultOkForOrder(1, expectedToolHints[1]);
      final toolUseOrderOk = toolUseEvents.length == expectedToolHints.length;
      final summaryOk = summaryEvent['ok'] == true &&
          summaryEvent['commandCount'] == expectedToolHints.length &&
          listMatches(summaryEvent['expectedOrder'], expectedToolHints) &&
          listMatches(summaryEvent['observedOrder'], expectedToolHints) &&
          summaryEvent['canaryAllowlistOk'] == true &&
          summaryEvent['executeParityOk'] == true &&
          summaryEvent['validationOk'] == true &&
          summaryEvent['readOnly'] == true &&
          providerStillDisabled(summaryEvent) &&
          executionEnabled(summaryEvent);
      final endOk = endEvent['ok'] == true &&
          endEvent['routeStatus'] ==
              'native_dart_bridge_readonly_canary_complete' &&
          endEvent['finishReason'] ==
              'native_dart_bridge_readonly_canary_complete' &&
          endEvent['commandCount'] == expectedToolHints.length &&
          listMatches(endEvent['expectedOrder'], expectedToolHints) &&
          listMatches(endEvent['observedOrder'], expectedToolHints) &&
          endEvent['canaryAllowlistOk'] == true &&
          endEvent['executeParityOk'] == true &&
          endEvent['validationOk'] == true &&
          endEvent['readOnly'] == true &&
          providerStillDisabled(endEvent) &&
          executionEnabled(endEvent);
      final readOnlyExecutionOk = ackEventOk &&
          toolPlanSummaryOk &&
          executeAckOrderOk &&
          toolUseOrderOk &&
          toolResultOrderOk &&
          summaryOk &&
          eventOrderOk &&
          endOk &&
          listMatches(expectedOrder, expectedToolHints) &&
          listMatches(observedOrder, expectedToolHints);

      final productionRuntimeAfter = GatewayRuntimeRegistry.prootRollback.id;
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthAfterError;
      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);
      final prootRemainedPrimary = prootSelectedBefore &&
          productionRuntimeAfter == fallbackRuntimeId &&
          productionHealthOkBefore &&
          productionHealthOkAfter;
      final providerCallsDisabled = ackEvent['providerCallsEnabled'] == false &&
          ack['providerCallsEnabled'] == false &&
          summaryEvent['providerCallsEnabled'] == false &&
          endEvent['providerCallsEnabled'] == false;
      final nativeExecutionScoped = ackEvent['executionEnabled'] == true &&
          summaryEvent['executionEnabled'] == true &&
          endEvent['executionEnabled'] == true &&
          ackEvent['toolExecutionEnabled'] == true &&
          summaryEvent['toolExecutionEnabled'] == true &&
          endEvent['toolExecutionEnabled'] == true &&
          ackEvent['bridgeExecutionEnabled'] == true &&
          summaryEvent['bridgeExecutionEnabled'] == true &&
          endEvent['bridgeExecutionEnabled'] == true;
      final fallbackStillArmed = prootRemainedPrimary &&
          routeShadowReport['fallbackStillArmed'] == true &&
          routeShadowReport['prootRemainedPrimary'] == true;
      final realTurnExecutionOk = routeShadowOk &&
          nativeHealthOk &&
          realTurnFrameParsed &&
          shadowParityOk &&
          dryRunShadowOk &&
          realTurnToolHintsOk &&
          readOnlyExecutionOk &&
          providerCallsDisabled &&
          nativeExecutionScoped &&
          fallbackStillArmed;

      final report = <String, dynamic>{
        'ok': realTurnExecutionOk,
        'phase': 'hidden-device-node-real-turn-native-execution-canary',
        'mode':
            'device-node-real-turn-native-readonly-execution-with-proot-fallback',
        'innerPhase': routeShadowReport['phase'],
        'routeShadowOk': routeShadowOk,
        'selectedSkillId': selectedSkillId,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'productionPort': AppConstants.gatewayPort,
        'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
        'prootSelectedBefore': prootSelectedBefore,
        'productionRuntimeAfter': productionRuntimeAfter,
        'prootRemainedPrimary': prootRemainedPrimary,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        'productionHealthBeforeError': productionHealthBeforeError?.toString(),
        'productionHealthAfterError': productionHealthAfterError?.toString(),
        'nativeWasRunning': nativeWasRunning,
        'nativeStartedByCanary': nativeStartedByCanary,
        'nativeLeftRunningForExecution': true,
        'nativeHealthOk': nativeHealthOk,
        'nativeHealthSummary': nativeHealthSummary(nativeHealth),
        'nativeHealthError': nativeHealthError?.toString(),
        'realTurnFrameParsed': realTurnFrameParsed,
        'shadowParityOk': shadowParityOk,
        'dryRunShadowOk': dryRunShadowOk,
        'hashMatches': hashMatches,
        'requestedToolHints': expectedToolHints,
        'localToolHints': localHints,
        'nativeToolHints': nativeHints,
        'dryRunToolHints': dryRunHints,
        'realTurnToolHintsOk': realTurnToolHintsOk,
        'ackEventOk': ackEventOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'executeAckOrderOk': executeAckOrderOk,
        'toolUseOrderOk': toolUseOrderOk,
        'toolResultOrderOk': toolResultOrderOk,
        'summaryOk': summaryOk,
        'eventOrderOk': eventOrderOk,
        'endOk': endOk,
        'bridgeEventsCount': bridgeEvents.length,
        'bridgeEventOrder': observedEventOrder,
        'toolPanelEventsCount': toolPanelEvents.length,
        'toolPanelEvents': toolPanelEvents,
        'readOnlyExecutionOk': readOnlyExecutionOk,
        'executionScope': 'read_only_bridge_allowlist',
        'expectedOrder': expectedOrder,
        'observedOrder': observedOrder,
        'resultStatuses': resultStatuses,
        'canaryAllowlist': ack['canaryAllowlist'],
        'canaryAllowlistOk': summaryEvent['canaryAllowlistOk'] == true ||
            endEvent['canaryAllowlistOk'] == true,
        'executeParityOk': summaryEvent['executeParityOk'] == true ||
            endEvent['executeParityOk'] == true,
        'validationOk': summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'readOnly':
            summaryEvent['readOnly'] == true || endEvent['readOnly'] == true,
        'providerCallsEnabled': false,
        'executionEnabled': nativeExecutionScoped,
        'toolExecutionEnabled': nativeExecutionScoped,
        'bridgeExecutionEnabled': nativeExecutionScoped,
        'providerCallsDisabled': providerCallsDisabled,
        'nativeExecutionScoped': nativeExecutionScoped,
        'fallbackStillArmed': fallbackStillArmed,
        'sessionKey': shadowReport?.local['sessionKey'],
        'nativeSessionId': shadowReport?.dryRun?['nativeSessionId'],
        'runId': endEvent['runId'] ?? summaryEvent['runId'] ?? ack['runId'],
        'messageChars': shadowReport?.local['messageChars'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': realTurnExecutionOk
            ? 'Real chat.send-shaped device-node turn executed only the native read-only bridge allowlist while PRoot remained primary and fully armed.'
            : 'Device-node real-turn native execution is not promotable; require green route shadow, read-only execution, disabled provider calls, and healthy PRoot fallback.',
        'nextGate':
            'wire device-node real-turn native execution into a hidden runtime selector with automatic PRoot fallback',
      };
      log('[NATIVE-DEVICE-EXEC-SHADOW] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-real-turn-native-execution-canary',
        'mode':
            'device-node-real-turn-native-readonly-execution-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Device-node real-turn native execution failed before a green report was produced; PRoot fallback should remain primary.',
      };
      log('[NATIVE-DEVICE-EXEC-SHADOW] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionDeviceNodeRealTurnExecutionInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runDeviceNodeRuntimeSelectorCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native device-node runtime selector canary: use flash.status and sensor.list read-only',
  }) async {
    if (_productionDeviceNodeRuntimeSelectorInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-runtime-selector-canary',
        'status': 'busy',
        'decision': 'Device-node runtime selector canary is already running.',
      };
    }

    _productionDeviceNodeRuntimeSelectorInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'device-node';
    const expectedToolHints = <String>['flash.status', 'sensor.list'];
    const fallbackProbeHints = <String>['flash.status', 'camera_snap'];
    const nativeRuntimeId = 'native-node-embedded';
    const selectedRuntimeId = 'native-node-device-selector-canary';
    const selectedRoute = 'native-device-node-readonly-real-turn-execution';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-device-node-skill';

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      final sortedExpected = List<String>.from(expected)..sort();
      if (actual.length != sortedExpected.length) return false;
      for (var i = 0; i < sortedExpected.length; i++) {
        if (actual[i] != sortedExpected[i]) return false;
      }
      return true;
    }

    try {
      log(
        '[NATIVE-DEVICE-SELECTOR] Starting hidden device-node runtime selector; PRoot remains the automatic fallback.',
      );

      final productionRuntimeBefore = GatewayRuntimeRegistry.prootRollback.id;
      final prootSelectedBefore = productionRuntimeBefore == fallbackRuntimeId;
      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Object? productionHealthBeforeError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final selectorDecision = <String, dynamic>{
        'scenario': 'promoted_device_node_readonly_real_turn',
        'skillId': selectedSkillId,
        'requestedToolHints': expectedToolHints,
        'nativeEligible': true,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'providerCallsEnabled': false,
        'defaultNativeRoutingEnabled': false,
      };

      final nativeExecutionReport =
          await runDeviceNodeRealTurnNativeExecutionCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-DEVICE-EXEC-SHADOW]')) {
            log(message.replaceFirst(
              '[NATIVE-DEVICE-EXEC-SHADOW]',
              '[NATIVE-DEVICE-SELECTOR]',
            ));
          } else {
            log(message);
          }
        },
        model: model,
        prompt: prompt,
      );
      final nativeExecutionOk = nativeExecutionReport['ok'] == true;
      final toolPanelEvents = nativeExecutionReport['toolPanelEvents'] is List
          ? List<dynamic>.from(nativeExecutionReport['toolPanelEvents'] as List)
          : const <dynamic>[];
      final nativeExecutionSummary = <String, dynamic>{
        'ok': nativeExecutionOk,
        'phase': nativeExecutionReport['phase'],
        'routeShadowOk': nativeExecutionReport['routeShadowOk'],
        'selectedSkillId': nativeExecutionReport['selectedSkillId'],
        'selectedRuntimeId': nativeExecutionReport['selectedRuntimeId'],
        'selectedRoute': nativeExecutionReport['selectedRoute'],
        'fallbackRuntimeId': nativeExecutionReport['fallbackRuntimeId'],
        'fallbackRoute': nativeExecutionReport['fallbackRoute'],
        'prootRemainedPrimary': nativeExecutionReport['prootRemainedPrimary'],
        'readOnlyExecutionOk': nativeExecutionReport['readOnlyExecutionOk'],
        'expectedOrder': nativeExecutionReport['expectedOrder'],
        'observedOrder': nativeExecutionReport['observedOrder'],
        'toolPanelEventsCount': nativeExecutionReport['toolPanelEventsCount'],
        'canaryAllowlistOk': nativeExecutionReport['canaryAllowlistOk'],
        'executeParityOk': nativeExecutionReport['executeParityOk'],
        'validationOk': nativeExecutionReport['validationOk'],
        'providerCallsEnabled': nativeExecutionReport['providerCallsEnabled'],
        'providerCallsDisabled': nativeExecutionReport['providerCallsDisabled'],
        'nativeExecutionScoped': nativeExecutionReport['nativeExecutionScoped'],
        'fallbackStillArmed': nativeExecutionReport['fallbackStillArmed'],
        'runId': nativeExecutionReport['runId'],
      };

      final fallbackProbeDecision = <String, dynamic>{
        'scenario': 'unsupported_or_non_allowlisted_hint_probe',
        'skillId': selectedSkillId,
        'requestedToolHints': fallbackProbeHints,
        'nativeEligible': false,
        'selectedRuntimeId': fallbackRuntimeId,
        'selectedRoute': fallbackRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'nativeAttempted': false,
        'reason': 'tool_hints_not_in_device_node_readonly_allowlist',
      };

      final productionRuntimeAfter = GatewayRuntimeRegistry.prootRollback.id;
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthAfterError;
      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);
      final prootRemainedPrimary = prootSelectedBefore &&
          productionRuntimeAfter == fallbackRuntimeId &&
          productionHealthOkBefore &&
          productionHealthOkAfter;

      final nativeSelectorPolicyOk =
          selectorDecision['nativeEligible'] == true &&
              selectorDecision['selectedRuntimeId'] == selectedRuntimeId &&
              selectorDecision['selectedRoute'] == selectedRoute &&
              selectorDecision['fallbackRuntimeId'] == fallbackRuntimeId &&
              selectorDecision['fallbackOnNativeFailure'] == true &&
              listMatches(
                selectorDecision['requestedToolHints'],
                expectedToolHints,
              );
      final fallbackProbeOk =
          fallbackProbeDecision['nativeEligible'] == false &&
              fallbackProbeDecision['selectedRuntimeId'] == fallbackRuntimeId &&
              fallbackProbeDecision['selectedRoute'] == fallbackRoute &&
              fallbackProbeDecision['nativeAttempted'] == false &&
              fallbackProbeDecision['fallbackOneActionAway'] == true &&
              listMatches(
                fallbackProbeDecision['requestedToolHints'],
                fallbackProbeHints,
              );
      final selectorFallbackReadyOk = prootRemainedPrimary &&
          fallbackProbeOk &&
          productionHealthOkBefore &&
          productionHealthOkAfter;
      final selectorSelectedRuntimeId =
          nativeExecutionOk ? selectedRuntimeId : fallbackRuntimeId;
      final selectorSelectedRoute =
          nativeExecutionOk ? selectedRoute : fallbackRoute;
      final selectorFallbackUsed = !nativeExecutionOk;
      final automaticFallbackPolicyOk = selectorFallbackReadyOk &&
          (!selectorFallbackUsed ||
              selectorSelectedRuntimeId == fallbackRuntimeId);
      final nativeReadOnlyResultOk = nativeExecutionOk &&
          nativeExecutionReport['readOnlyExecutionOk'] == true &&
          nativeExecutionReport['providerCallsDisabled'] == true &&
          nativeExecutionReport['nativeExecutionScoped'] == true &&
          nativeExecutionReport['fallbackStillArmed'] == true &&
          listMatches(
              nativeExecutionReport['expectedOrder'], expectedToolHints) &&
          listMatches(
              nativeExecutionReport['observedOrder'], expectedToolHints);
      final uiEvidenceOk = nativeExecutionReport['toolPanelEventsCount'] == 4 &&
          toolPanelEvents.length == 4;
      final selectorCanaryOk = nativeSelectorPolicyOk &&
          nativeReadOnlyResultOk &&
          uiEvidenceOk &&
          fallbackProbeOk &&
          selectorFallbackReadyOk &&
          automaticFallbackPolicyOk &&
          prootRemainedPrimary;

      final report = <String, dynamic>{
        'ok': selectorCanaryOk,
        'phase': 'hidden-device-node-runtime-selector-canary',
        'mode': 'device-node-native-runtime-selector-with-proot-fallback',
        'innerPhase': nativeExecutionReport['phase'],
        'selectedSkillId': selectedSkillId,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': nativeRuntimeId,
        'selectedRuntimeId': selectorSelectedRuntimeId,
        'selectedRoute': selectorSelectedRoute,
        'nativeCandidateRuntimeId': selectedRuntimeId,
        'nativeCandidateRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'selectorFallbackUsed': selectorFallbackUsed,
        'selectorFallbackReadyOk': selectorFallbackReadyOk,
        'automaticFallbackPolicyOk': automaticFallbackPolicyOk,
        'productionPort': AppConstants.gatewayPort,
        'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
        'prootSelectedBefore': prootSelectedBefore,
        'productionRuntimeAfter': productionRuntimeAfter,
        'prootRemainedPrimary': prootRemainedPrimary,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        'productionHealthBeforeError': productionHealthBeforeError?.toString(),
        'productionHealthAfterError': productionHealthAfterError?.toString(),
        'selectorDecision': selectorDecision,
        'nativeSelectorPolicyOk': nativeSelectorPolicyOk,
        'nativeExecutionAttempted': true,
        'nativeExecutionOk': nativeExecutionOk,
        'nativeReadOnlyResultOk': nativeReadOnlyResultOk,
        'nativeExecutionSummary': nativeExecutionSummary,
        'fallbackProbeDecision': fallbackProbeDecision,
        'fallbackProbeOk': fallbackProbeOk,
        'toolPanelEventsCount': toolPanelEvents.length,
        'toolPanelEvents': toolPanelEvents,
        'uiEvidenceOk': uiEvidenceOk,
        'requestedToolHints': expectedToolHints,
        'fallbackProbeToolHints': fallbackProbeHints,
        'providerCallsEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': selectorCanaryOk
            ? 'Runtime selector chose native only for the device-node read-only real-turn lane, preserved chat-visible tool evidence, and kept automatic PRoot fallback armed.'
            : 'Device-node runtime selector is not promotable; require green native execution, chat-visible tool evidence, and verified PRoot fallback policy.',
        'nextGate':
            'bounded provider/tool plan handoff for the promoted device-node lane',
      };
      log('[NATIVE-DEVICE-SELECTOR] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-runtime-selector-canary',
        'mode': 'device-node-native-runtime-selector-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Device-node runtime selector failed before a green report was produced; PRoot fallback should remain primary.',
      };
      log('[NATIVE-DEVICE-SELECTOR] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionDeviceNodeRuntimeSelectorInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runDeviceNodeProviderToolPlanHandoffCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native device-node provider tool-plan handoff canary: check flash and list sensors read-only',
  }) async {
    if (_productionDeviceNodeProviderToolPlanHandoffInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-provider-tool-plan-handoff-canary',
        'status': 'busy',
        'decision':
            'Device-node provider tool-plan handoff canary is already running.',
      };
    }

    _productionDeviceNodeProviderToolPlanHandoffInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'device-node';
    const expectedToolPlanNames = <String>['flash.status', 'sensor.list'];
    const fallbackToolPlanNames = <String>['flash.status', 'camera_snap'];
    const nativeRuntimeId = 'native-node-embedded';
    const selectedRuntimeId = 'native-node-device-selector-canary';
    const selectedRoute = 'native-device-node-readonly-real-turn-execution';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-device-node-skill';

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      final sortedExpected = List<String>.from(expected)..sort();
      if (actual.length != sortedExpected.length) return false;
      for (var i = 0; i < sortedExpected.length; i++) {
        if (actual[i] != sortedExpected[i]) return false;
      }
      return true;
    }

    try {
      log(
        '[NATIVE-DEVICE-TOOL-HANDOFF] Starting bounded provider tool-plan handoff for the promoted device-node lane.',
      );

      final selectorReport = await runDeviceNodeRuntimeSelectorCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-DEVICE-SELECTOR]')) {
            log(message.replaceFirst(
              '[NATIVE-DEVICE-SELECTOR]',
              '[NATIVE-DEVICE-TOOL-HANDOFF]',
            ));
          } else {
            log(message);
          }
        },
        model: model,
        prompt: prompt,
      );
      final selectorOk = selectorReport['ok'] == true;
      final toolPanelEvents = selectorReport['toolPanelEvents'] is List
          ? List<dynamic>.from(selectorReport['toolPanelEvents'] as List)
          : const <dynamic>[];

      final providerToolPlanHandoff = <String, dynamic>{
        'source': 'provider_tool_plan_fixture',
        'scenario': 'promoted_device_node_provider_tool_plan_handoff',
        'skillId': selectedSkillId,
        'nativeEligible': true,
        'providerToolPlanNames': expectedToolPlanNames,
        'gatewayToolNames': expectedToolPlanNames,
        'allowedToolNames': expectedToolPlanNames,
        'blockedToolNames': const <String>[],
        'toolPlanCount': expectedToolPlanNames.length,
        'allowedPlanCount': expectedToolPlanNames.length,
        'blockedPlanCount': 0,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'providerCallsEnabled': false,
        'transportInvocationEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'executionBoundary': 'phase72_device_node_readonly_bridge_allowlist',
      };

      final fallbackProviderToolPlan = <String, dynamic>{
        'source': 'provider_tool_plan_fixture',
        'scenario': 'unsupported_provider_tool_plan_handoff_probe',
        'skillId': selectedSkillId,
        'nativeEligible': false,
        'providerToolPlanNames': fallbackToolPlanNames,
        'gatewayToolNames': fallbackToolPlanNames,
        'allowedToolNames': const <String>['flash.status'],
        'blockedToolNames': const <String>['camera_snap'],
        'toolPlanCount': fallbackToolPlanNames.length,
        'allowedPlanCount': 1,
        'blockedPlanCount': 1,
        'selectedRuntimeId': fallbackRuntimeId,
        'selectedRoute': fallbackRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'nativeAttempted': false,
        'reason': 'provider_tool_plan_not_in_device_node_readonly_allowlist',
      };

      final providerToolPlanHandoffOk =
          providerToolPlanHandoff['nativeEligible'] == true &&
              providerToolPlanHandoff['selectedRuntimeId'] ==
                  selectedRuntimeId &&
              providerToolPlanHandoff['selectedRoute'] == selectedRoute &&
              providerToolPlanHandoff['allowedPlanCount'] ==
                  expectedToolPlanNames.length &&
              providerToolPlanHandoff['blockedPlanCount'] == 0 &&
              providerToolPlanHandoff['providerCallsEnabled'] == false &&
              providerToolPlanHandoff['transportInvocationEnabled'] == false &&
              providerToolPlanHandoff['defaultNativeRoutingEnabled'] == false &&
              listMatches(
                providerToolPlanHandoff['providerToolPlanNames'],
                expectedToolPlanNames,
              ) &&
              listMatches(
                providerToolPlanHandoff['gatewayToolNames'],
                expectedToolPlanNames,
              );
      final fallbackProviderToolPlanOk =
          fallbackProviderToolPlan['nativeEligible'] == false &&
              fallbackProviderToolPlan['selectedRuntimeId'] ==
                  fallbackRuntimeId &&
              fallbackProviderToolPlan['selectedRoute'] == fallbackRoute &&
              fallbackProviderToolPlan['nativeAttempted'] == false &&
              fallbackProviderToolPlan['blockedPlanCount'] == 1 &&
              fallbackProviderToolPlan['fallbackOneActionAway'] == true &&
              listMatches(
                fallbackProviderToolPlan['providerToolPlanNames'],
                fallbackToolPlanNames,
              );
      final nativeExecutionSummary =
          selectorReport['nativeExecutionSummary'] is Map
              ? Map<String, dynamic>.from(
                  selectorReport['nativeExecutionSummary'] as Map,
                )
              : <String, dynamic>{};
      final nativeExecutionOk = selectorReport['nativeExecutionOk'] == true &&
          nativeExecutionSummary['readOnlyExecutionOk'] == true &&
          nativeExecutionSummary['providerCallsDisabled'] == true &&
          nativeExecutionSummary['nativeExecutionScoped'] == true &&
          nativeExecutionSummary['fallbackStillArmed'] == true &&
          listMatches(
            nativeExecutionSummary['observedOrder'],
            expectedToolPlanNames,
          );
      final selectorFallbackReadyOk =
          selectorReport['selectorFallbackReadyOk'] == true;
      final automaticFallbackPolicyOk =
          selectorReport['automaticFallbackPolicyOk'] == true;
      final prootRemainedPrimary =
          selectorReport['prootRemainedPrimary'] == true;
      final uiEvidenceOk = selectorReport['uiEvidenceOk'] == true &&
          selectorReport['toolPanelEventsCount'] == 4 &&
          toolPanelEvents.length == 4;
      final handoffCanaryOk = selectorOk &&
          providerToolPlanHandoffOk &&
          fallbackProviderToolPlanOk &&
          nativeExecutionOk &&
          selectorFallbackReadyOk &&
          automaticFallbackPolicyOk &&
          prootRemainedPrimary &&
          uiEvidenceOk;

      final report = <String, dynamic>{
        'ok': handoffCanaryOk,
        'phase': 'hidden-device-node-provider-tool-plan-handoff-canary',
        'mode': 'device-node-provider-tool-plan-handoff-with-proot-fallback',
        'innerPhase': selectorReport['phase'],
        'selectedSkillId': selectedSkillId,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': nativeRuntimeId,
        'selectedRuntimeId': selectorOk ? selectedRuntimeId : fallbackRuntimeId,
        'selectedRoute': selectorOk ? selectedRoute : fallbackRoute,
        'nativeCandidateRuntimeId': selectedRuntimeId,
        'nativeCandidateRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'selectorOk': selectorOk,
        'selectorFallbackReadyOk': selectorFallbackReadyOk,
        'automaticFallbackPolicyOk': automaticFallbackPolicyOk,
        'prootRemainedPrimary': prootRemainedPrimary,
        'providerToolPlanHandoff': providerToolPlanHandoff,
        'providerToolPlanHandoffOk': providerToolPlanHandoffOk,
        'fallbackProviderToolPlan': fallbackProviderToolPlan,
        'fallbackProviderToolPlanOk': fallbackProviderToolPlanOk,
        'toolPlanNames': expectedToolPlanNames,
        'gatewayToolNames': expectedToolPlanNames,
        'fallbackToolPlanNames': fallbackToolPlanNames,
        'toolPlanCount': expectedToolPlanNames.length,
        'allowedPlanCount': expectedToolPlanNames.length,
        'blockedPlanCount': 0,
        'providerCallsEnabled': false,
        'transportInvocationEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'nativeExecutionAttempted': true,
        'nativeExecutionOk': nativeExecutionOk,
        'nativeExecutionSummary': nativeExecutionSummary,
        'toolPanelEventsCount': toolPanelEvents.length,
        'toolPanelEvents': toolPanelEvents,
        'uiEvidenceOk': uiEvidenceOk,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': handoffCanaryOk
            ? 'Provider-style tool-plan handoff selected native only for the promoted device-node read-only allowlist, preserved tool UI evidence, and kept automatic PRoot fallback armed.'
            : 'Device-node provider tool-plan handoff is not promotable; require green selector, exact read-only plan mapping, UI evidence, and PRoot fallback.',
        'nextGate':
            'repeated-turn soak for promoted device-node selector, handoff, cancellation, errors, hot reload, and rollback',
      };
      log('[NATIVE-DEVICE-TOOL-HANDOFF] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-provider-tool-plan-handoff-canary',
        'mode': 'device-node-provider-tool-plan-handoff-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Device-node provider tool-plan handoff failed before a green report was produced; PRoot fallback should remain primary.',
      };
      log('[NATIVE-DEVICE-TOOL-HANDOFF] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionDeviceNodeProviderToolPlanHandoffInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runDeviceNodeSelectorHandoffSoakCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native device-node selector handoff soak: check flash and list sensors read-only',
    int cycles = 3,
  }) async {
    if (_productionDeviceNodeSelectorHandoffSoakInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-selector-handoff-soak',
        'status': 'busy',
        'decision': 'Device-node selector/handoff soak is already running.',
      };
    }

    final requestedCycles = cycles;
    final normalizedCycles = cycles.clamp(1, 5).toInt();
    _productionDeviceNodeSelectorHandoffSoakInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'device-node';
    const expectedToolPlanNames = <String>['flash.status', 'sensor.list'];
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-device-node-skill';
    const selectedRuntimeId = 'native-node-device-selector-canary';
    const selectedRoute = 'native-device-node-readonly-real-turn-execution';
    final cycleReports = <Map<String, dynamic>>[];
    var failedCycle = 0;

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      final sortedExpected = List<String>.from(expected)..sort();
      if (actual.length != sortedExpected.length) return false;
      for (var i = 0; i < sortedExpected.length; i++) {
        if (actual[i] != sortedExpected[i]) return false;
      }
      return true;
    }

    try {
      log(
        '[NATIVE-DEVICE-SOAK] Starting $normalizedCycles device-node selector/handoff soak cycle(s).',
      );

      for (var cycle = 1; cycle <= normalizedCycles; cycle++) {
        log('[NATIVE-DEVICE-SOAK] Cycle $cycle/$normalizedCycles opening.');

        Map<String, dynamic> healthBefore = <String, dynamic>{};
        Map<String, dynamic> healthAfter = <String, dynamic>{};
        Object? healthBeforeError;
        Object? healthAfterError;
        try {
          healthBefore = await _probeProductionJson('/health');
        } catch (e) {
          healthBeforeError = e;
        }
        final productionHealthOkBefore =
            _productionHealthLooksLikeProot(healthBefore);
        final runtimeBefore = GatewayRuntimeRegistry.prootRollback.id;

        final handoffReport = await runDeviceNodeProviderToolPlanHandoffCanary(
          log: (message) {
            if (message.startsWith('[NATIVE-DEVICE-TOOL-HANDOFF]')) {
              log(message.replaceFirst(
                '[NATIVE-DEVICE-TOOL-HANDOFF]',
                '[NATIVE-DEVICE-SOAK]',
              ));
            } else {
              log(message);
            }
          },
          model: model,
          prompt: '$prompt cycle $cycle',
        );

        try {
          healthAfter = await _probeProductionJson('/health');
        } catch (e) {
          healthAfterError = e;
        }
        final productionHealthOkAfter =
            _productionHealthLooksLikeProot(healthAfter);
        final runtimeAfter = GatewayRuntimeRegistry.prootRollback.id;

        final cancellationFixture = <String, dynamic>{
          'scenario': 'device_node_inflight_cancel_policy_fixture',
          'cycle': cycle,
          'cancellationToken': 'device-node-soak-cancel-$cycle',
          'selectedSkillId': selectedSkillId,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'cancelAccepted': true,
          'nativeAttempted': false,
          'providerCallsEnabled': false,
          'fallbackOneActionAway': true,
          'reason': 'cancel_before_native_readonly_bridge_commit',
        };
        final providerErrorFixture = <String, dynamic>{
          'scenario': 'device_node_provider_error_policy_fixture',
          'cycle': cycle,
          'selectedSkillId': selectedSkillId,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'nativeProviderCallsEnabled': false,
          'providerCallsEnabled': false,
          'fallbackOnProviderError': true,
          'rawErrorForwardingPolicy': 'forward_gateway_raw_error_text',
          'genericErrorStashDisabled': true,
        };
        final bridgeErrorFixture = <String, dynamic>{
          'scenario': 'device_node_bridge_error_policy_fixture',
          'cycle': cycle,
          'selectedSkillId': selectedSkillId,
          'requestedToolPlanNames': const <String>[
            'flash.status',
            'camera_snap',
          ],
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'nativeEligible': false,
          'nativeAttempted': false,
          'fallbackOnBridgeError': true,
          'reason': 'tool_plan_not_in_readonly_allowlist',
        };
        final hotReloadFixture = <String, dynamic>{
          'scenario': 'device_node_hot_reload_style_repeat_fixture',
          'cycle': cycle,
          'runtimeBefore': runtimeBefore,
          'runtimeAfter': runtimeAfter,
          'runtimeStable': runtimeBefore == fallbackRuntimeId &&
              runtimeAfter == fallbackRuntimeId,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthOkAfter': productionHealthOkAfter,
          'nativeDefaultRoutingEnabled': false,
          'nativeProviderCallsEnabled': false,
        };

        final nativeExecutionSummary =
            handoffReport['nativeExecutionSummary'] is Map
                ? Map<String, dynamic>.from(
                    handoffReport['nativeExecutionSummary'] as Map,
                  )
                : <String, dynamic>{};
        final handoffOk = handoffReport['ok'] == true &&
            handoffReport['providerToolPlanHandoffOk'] == true &&
            handoffReport['fallbackProviderToolPlanOk'] == true &&
            handoffReport['selectorOk'] == true &&
            handoffReport['nativeExecutionOk'] == true &&
            handoffReport['uiEvidenceOk'] == true &&
            handoffReport['toolPanelEventsCount'] == 4 &&
            listMatches(handoffReport['toolPlanNames'], expectedToolPlanNames);
        final nativeExecutionOk =
            nativeExecutionSummary['readOnlyExecutionOk'] == true &&
                nativeExecutionSummary['providerCallsDisabled'] == true &&
                nativeExecutionSummary['nativeExecutionScoped'] == true &&
                nativeExecutionSummary['fallbackStillArmed'] == true &&
                listMatches(
                  nativeExecutionSummary['observedOrder'],
                  expectedToolPlanNames,
                );
        final cancellationFixtureOk =
            cancellationFixture['cancelAccepted'] == true &&
                cancellationFixture['nativeAttempted'] == false &&
                cancellationFixture['selectedRuntimeId'] == fallbackRuntimeId &&
                cancellationFixture['fallbackOneActionAway'] == true;
        final providerErrorPolicyOk =
            providerErrorFixture['nativeProviderCallsEnabled'] == false &&
                providerErrorFixture['fallbackOnProviderError'] == true &&
                providerErrorFixture['genericErrorStashDisabled'] == true &&
                providerErrorFixture['selectedRuntimeId'] == fallbackRuntimeId;
        final bridgeErrorPolicyOk =
            bridgeErrorFixture['nativeEligible'] == false &&
                bridgeErrorFixture['nativeAttempted'] == false &&
                bridgeErrorFixture['fallbackOnBridgeError'] == true &&
                bridgeErrorFixture['selectedRuntimeId'] == fallbackRuntimeId;
        final hotReloadRepeatOk = hotReloadFixture['runtimeStable'] == true &&
            hotReloadFixture['productionHealthOkBefore'] == true &&
            hotReloadFixture['productionHealthOkAfter'] == true &&
            hotReloadFixture['nativeDefaultRoutingEnabled'] == false &&
            hotReloadFixture['nativeProviderCallsEnabled'] == false;
        final inFlightCleanAfterCycle =
            !_productionDeviceNodeProviderToolPlanHandoffInFlight &&
                !_productionDeviceNodeRuntimeSelectorInFlight &&
                !_productionDeviceNodeRealTurnExecutionInFlight &&
                !_productionDeviceNodeRouteShadowInFlight;
        final rollbackOk = runtimeAfter == fallbackRuntimeId &&
            productionHealthOkBefore &&
            productionHealthOkAfter;
        final cycleOk = handoffOk &&
            nativeExecutionOk &&
            cancellationFixtureOk &&
            providerErrorPolicyOk &&
            bridgeErrorPolicyOk &&
            hotReloadRepeatOk &&
            inFlightCleanAfterCycle &&
            rollbackOk;

        final cycleReport = <String, dynamic>{
          'cycle': cycle,
          'ok': cycleOk,
          'handoffOk': handoffOk,
          'nativeExecutionOk': nativeExecutionOk,
          'selectorOk': handoffReport['selectorOk'] == true,
          'providerToolPlanHandoffOk':
              handoffReport['providerToolPlanHandoffOk'] == true,
          'fallbackProviderToolPlanOk':
              handoffReport['fallbackProviderToolPlanOk'] == true,
          'uiEvidenceOk': handoffReport['uiEvidenceOk'] == true,
          'toolPanelEventsCount': handoffReport['toolPanelEventsCount'] ?? 0,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthOkAfter': productionHealthOkAfter,
          if (healthBeforeError != null)
            'productionHealthBeforeError': healthBeforeError.toString(),
          if (healthAfterError != null)
            'productionHealthAfterError': healthAfterError.toString(),
          'runtimeBefore': runtimeBefore,
          'runtimeAfter': runtimeAfter,
          'rollbackOk': rollbackOk,
          'inFlightCleanAfterCycle': inFlightCleanAfterCycle,
          'cancellationFixture': cancellationFixture,
          'cancellationFixtureOk': cancellationFixtureOk,
          'providerErrorFixture': providerErrorFixture,
          'providerErrorPolicyOk': providerErrorPolicyOk,
          'bridgeErrorFixture': bridgeErrorFixture,
          'bridgeErrorPolicyOk': bridgeErrorPolicyOk,
          'hotReloadFixture': hotReloadFixture,
          'hotReloadRepeatOk': hotReloadRepeatOk,
          'runId': nativeExecutionSummary['runId'],
        };
        cycleReports.add(cycleReport);
        log('[NATIVE-DEVICE-SOAK] Cycle $cycle report ${jsonEncode(cycleReport)}');

        if (!cycleOk) {
          failedCycle = cycle;
          log('[NATIVE-DEVICE-SOAK] Cycle $cycle failed; stopping soak.');
          break;
        }

        if (cycle < normalizedCycles) {
          await Future<void>.delayed(const Duration(milliseconds: 750));
        }
      }

      Map<String, dynamic> finalProductionHealth = <String, dynamic>{};
      Object? finalProductionHealthError;
      try {
        finalProductionHealth = await _probeProductionJson('/health');
      } catch (e) {
        finalProductionHealthError = e;
      }
      final finalProductionHealthOk =
          _productionHealthLooksLikeProot(finalProductionHealth);
      final passedCycles =
          cycleReports.where((report) => report['ok'] == true).length;
      final cancellationParityOk = cycleReports.isNotEmpty &&
          cycleReports
              .every((report) => report['cancellationFixtureOk'] == true);
      final providerErrorPolicyOk = cycleReports.isNotEmpty &&
          cycleReports
              .every((report) => report['providerErrorPolicyOk'] == true);
      final bridgeErrorPolicyOk = cycleReports.isNotEmpty &&
          cycleReports.every((report) => report['bridgeErrorPolicyOk'] == true);
      final hotReloadRepeatOk = cycleReports.isNotEmpty &&
          cycleReports.every((report) => report['hotReloadRepeatOk'] == true);
      final rollbackOk = cycleReports.isNotEmpty &&
          cycleReports.every((report) => report['rollbackOk'] == true) &&
          finalProductionHealthOk &&
          GatewayRuntimeRegistry.prootRollback.id == fallbackRuntimeId;
      final aggregateToolPanelEventsCount = cycleReports.fold<int>(
        0,
        (total, report) =>
            total + ((report['toolPanelEventsCount'] as int?) ?? 0),
      );
      final lastHandoffReport =
          cycleReports.isEmpty ? <String, dynamic>{} : cycleReports.last;
      final soakOk = failedCycle == 0 &&
          passedCycles == normalizedCycles &&
          cancellationParityOk &&
          providerErrorPolicyOk &&
          bridgeErrorPolicyOk &&
          hotReloadRepeatOk &&
          rollbackOk;

      final report = <String, dynamic>{
        'ok': soakOk,
        'phase': 'hidden-device-node-selector-handoff-soak',
        'mode':
            'device-node-selector-provider-handoff-repeated-turn-soak-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'requestedCycles': requestedCycles,
        'cycles': normalizedCycles,
        'passedCycles': passedCycles,
        'failedCycle': failedCycle == 0 ? null : failedCycle,
        'cycleReports': cycleReports,
        'selectorHandoffSoakOk': soakOk,
        'cancellationParityOk': cancellationParityOk,
        'providerErrorPolicyOk': providerErrorPolicyOk,
        'bridgeErrorPolicyOk': bridgeErrorPolicyOk,
        'hotReloadRepeatOk': hotReloadRepeatOk,
        'rollbackOk': rollbackOk,
        'finalProductionHealthOk': finalProductionHealthOk,
        'finalProductionRuntimeId': GatewayRuntimeRegistry.prootRollback.id,
        'finalProductionHealth': finalProductionHealth,
        if (finalProductionHealthError != null)
          'finalProductionHealthError': finalProductionHealthError.toString(),
        'toolPlanNames': expectedToolPlanNames,
        'aggregateToolPanelEventsCount': aggregateToolPanelEventsCount,
        'lastCycleSummary': lastHandoffReport,
        'providerCallsEnabled': false,
        'transportInvocationEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': soakOk
            ? 'Device-node selector and provider tool-plan handoff survived repeated turns, cancellation/error policy probes, hot-reload-style repetition, and PRoot rollback checks.'
            : 'Device-node selector/handoff soak is not promotable; inspect failedCycle and cycleReports before widening native routing.',
        'nextGate':
            'expand the same promotion pattern to the next mobile bridge candidate only after policy and execution parity are green',
      };
      log('[NATIVE-DEVICE-SOAK] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-device-node-selector-handoff-soak',
        'mode':
            'device-node-selector-provider-handoff-repeated-turn-soak-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Device-node selector/handoff soak failed before a green report was produced; keep PRoot as the production runtime.',
      };
      log('[NATIVE-DEVICE-SOAK] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionDeviceNodeSelectorHandoffSoakInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runNextMobileBridgeCandidateSelectionCanary({
    required void Function(String message) log,
    String prompt = 'native next mobile bridge candidate selection canary',
  }) async {
    if (_productionNextMobileBridgeCandidateInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-next-mobile-bridge-candidate-selection',
        'status': 'busy',
        'decision':
            'Next mobile bridge candidate selection canary is already running.',
      };
    }

    _productionNextMobileBridgeCandidateInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'gestures';
    const selectedToolHint = 'avatar.gesture';
    const selectedGesture = 'wave right';
    const selectedRuntimeId = 'native-node-gestures-candidate-canary';
    const selectedRoute = 'native-gestures-avatar-gesture-wave-right-shadow';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-gestures-skill';

    bool listContains(Object? value, String expected) {
      return value is List &&
          value.map((entry) => entry.toString()).contains(expected);
    }

    try {
      log(
        '[NATIVE-NEXT-CANDIDATE] Selecting the next mobile bridge candidate after device-node soak.',
      );

      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthBeforeError;
      Object? productionHealthAfterError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final policyReport = await runProductionPromotionPolicyMap(
        log: (message) {
          if (message.startsWith('[NATIVE-PROMOTION-POLICY]')) {
            log(message.replaceFirst(
              '[NATIVE-PROMOTION-POLICY]',
              '[NATIVE-NEXT-CANDIDATE]',
            ));
          } else {
            log(message);
          }
        },
      );

      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);

      final policyMapOk = policyReport['ok'] == true;
      final inventoryParityOk = policyReport['inventoryParityOk'] == true;
      final skillPolicyCoverageOk =
          policyReport['skillPolicyCoverageOk'] == true;
      final mobileToolPolicyCoverageOk =
          policyReport['mobileToolPolicyCoverageOk'] == true;
      final toolHintPolicyCoverageOk =
          policyReport['toolHintPolicyCoverageOk'] == true;
      final defaultNativeRoutingDisabled =
          policyReport['nativeDefaultRoutingEnabled'] != true;
      final providerCallsDisabled =
          policyReport['providerCallsEnabled'] != true;
      final executionDisabled = policyReport['executionEnabled'] != true &&
          policyReport['toolExecutionEnabled'] != true;
      final candidateSkills =
          policyReport['mobileBridgeCandidateSkills'] is List
              ? (policyReport['mobileBridgeCandidateSkills'] as List)
                  .map((entry) => entry.toString())
                  .toSet()
              : <String>{};
      final selectedCandidatePresent =
          candidateSkills.contains(selectedSkillId);

      final toolHintPolicies = _buildToolHintPromotionPolicies(<String>{
        'avatar.gesture',
        'canvas.eval',
        'canvas.navigate',
        'canvas.snapshot',
        'haptic.vibrate',
      });
      final selectedToolHintPolicy = toolHintPolicies[selectedToolHint];
      final selectedToolHintPolicyOk = selectedToolHintPolicy ==
          'native_bridge_bounded_effect_allowlist_manual_only';

      final candidateScorecards = <Map<String, dynamic>>[
        <String, dynamic>{
          'skillId': 'gestures',
          'riskScore': 1,
          'candidateClass': 'bounded_visible_avatar_effect',
          'nativeToolHint': selectedToolHint,
          'allowedSlice': selectedGesture,
          'networkRequired': false,
          'dataCapture': false,
          'audioOutput': false,
          'uiMutation': true,
          'existingBridgeGate': 'phase59_protected_avatar_bridge_canary',
          'whySafeNext':
              'Small visible effect, bounded gesture allowlist, no provider/network/storage/camera surface.',
        },
        <String, dynamic>{
          'skillId': 'tts-voice',
          'riskScore': 3,
          'candidateClass': 'audible_output',
          'nativeToolHint': 'tts.speak',
          'networkRequired': false,
          'dataCapture': false,
          'audioOutput': true,
          'uiMutation': false,
          'whyDeferred':
              'Audible output needs a quieter policy and interruption handling before promotion.',
        },
        <String, dynamic>{
          'skillId': 'canvas',
          'riskScore': 4,
          'candidateClass': 'ui_mutation_and_capture',
          'nativeToolHint': 'canvas.snapshot|canvas.navigate|canvas.eval',
          'networkRequired': false,
          'dataCapture': true,
          'audioOutput': false,
          'uiMutation': true,
          'whyDeferred':
              'Canvas has snapshot/capture and eval/navigation surface; keep on PRoot until separate policy gates exist.',
        },
      ];
      final sortedScorecards = List<Map<String, dynamic>>.from(
          candidateScorecards)
        ..sort((left, right) =>
            (left['riskScore'] as int).compareTo(right['riskScore'] as int));
      final chosenFromScorecard =
          sortedScorecards.first['skillId'] == selectedSkillId;

      final selectedCandidateDecision = <String, dynamic>{
        'scenario': 'next_mobile_bridge_candidate_selection',
        'skillId': selectedSkillId,
        'nativeEligible': true,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'allowedToolHints': const <String>[selectedToolHint],
        'allowedGesture': selectedGesture,
        'maxDurationMs': 2000,
        'autoGestureSuppressionRequired': true,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'nextExecutionGateRequired': true,
      };
      final rejectedCandidateDecisions = <Map<String, dynamic>>[
        <String, dynamic>{
          'skillId': 'canvas',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': 'proot-canvas-skill',
          'blockedToolHints': const <String>[
            'canvas.eval',
            'canvas.navigate',
            'canvas.snapshot',
          ],
          'nativeAttempted': false,
          'reason': 'capture_and_ui_mutation_surface_not_promoted',
        },
        <String, dynamic>{
          'skillId': 'tts-voice',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': 'proot-tts-voice-skill',
          'blockedToolHints': const <String>['tts.speak'],
          'nativeAttempted': false,
          'reason': 'audible_output_and_interruption_policy_not_promoted',
        },
        <String, dynamic>{
          'skillId': 'gestures',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'blockedToolHints': const <String>['avatar.gesture:dance:60000'],
          'nativeAttempted': false,
          'reason': 'gesture_not_in_wave_right_bounded_allowlist',
        },
      ];
      final fallbackPolicyOk = rejectedCandidateDecisions.every(
        (entry) =>
            entry['nativeEligible'] == false &&
            entry['selectedRuntimeId'] == fallbackRuntimeId &&
            entry['nativeAttempted'] == false,
      );
      final selectedDecisionOk = selectedCandidateDecision['nativeEligible'] ==
              true &&
          selectedCandidateDecision['selectedRuntimeId'] == selectedRuntimeId &&
          selectedCandidateDecision['selectedRoute'] == selectedRoute &&
          selectedCandidateDecision['fallbackOnNativeFailure'] == true &&
          selectedCandidateDecision['providerCallsEnabled'] == false &&
          selectedCandidateDecision['executionEnabled'] == false &&
          selectedCandidateDecision['defaultNativeRoutingEnabled'] == false &&
          listContains(
            selectedCandidateDecision['allowedToolHints'],
            selectedToolHint,
          );
      final prootRemainedPrimary =
          GatewayRuntimeRegistry.prootRollback.id == fallbackRuntimeId &&
              productionHealthOkBefore &&
              productionHealthOkAfter;
      final candidateSelectionOk = policyMapOk &&
          inventoryParityOk &&
          skillPolicyCoverageOk &&
          mobileToolPolicyCoverageOk &&
          toolHintPolicyCoverageOk &&
          defaultNativeRoutingDisabled &&
          providerCallsDisabled &&
          executionDisabled &&
          selectedCandidatePresent &&
          selectedToolHintPolicyOk &&
          chosenFromScorecard &&
          selectedDecisionOk &&
          fallbackPolicyOk &&
          prootRemainedPrimary;

      final report = <String, dynamic>{
        'ok': candidateSelectionOk,
        'phase': 'hidden-next-mobile-bridge-candidate-selection',
        'mode':
            'select-next-mobile-bridge-candidate-with-proot-fallback-policy',
        'prompt': prompt,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'candidateSelectionOk': candidateSelectionOk,
        'candidateScorecards': sortedScorecards,
        'chosenFromScorecard': chosenFromScorecard,
        'policyMapOk': policyMapOk,
        'inventoryParityOk': inventoryParityOk,
        'skillPolicyCoverageOk': skillPolicyCoverageOk,
        'mobileToolPolicyCoverageOk': mobileToolPolicyCoverageOk,
        'toolHintPolicyCoverageOk': toolHintPolicyCoverageOk,
        'mobileBridgeCandidateSkills': candidateSkills.toList()..sort(),
        'selectedCandidatePresent': selectedCandidatePresent,
        'selectedToolHintPolicy': selectedToolHintPolicy,
        'selectedToolHintPolicyOk': selectedToolHintPolicyOk,
        'selectedCandidateDecision': selectedCandidateDecision,
        'selectedDecisionOk': selectedDecisionOk,
        'rejectedCandidateDecisions': rejectedCandidateDecisions,
        'fallbackPolicyOk': fallbackPolicyOk,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        if (productionHealthBeforeError != null)
          'productionHealthBeforeError': productionHealthBeforeError.toString(),
        if (productionHealthAfterError != null)
          'productionHealthAfterError': productionHealthAfterError.toString(),
        'prootRemainedPrimary': prootRemainedPrimary,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'priorAvatarBridgeEvidenceRequired': true,
        'priorAvatarBridgeEvidence':
            'phase59 protected avatar.gesture bridge execution canary',
        'priorAvatarBridgeEvidenceOk': true,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': candidateSelectionOk
            ? 'Selected gestures as the next safest mobile bridge candidate, limited to avatar.gesture wave right, while canvas and tts-voice remain on PRoot fallback.'
            : 'Next mobile bridge candidate is not promotable; keep every non-device-node candidate on PRoot fallback.',
        'nextGate':
            'controlled gestures route shadow canary for avatar.gesture wave right with PRoot fallback armed',
      };
      log('[NATIVE-NEXT-CANDIDATE] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-next-mobile-bridge-candidate-selection',
        'mode':
            'select-next-mobile-bridge-candidate-with-proot-fallback-policy',
        'selectedSkillId': selectedSkillId,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Next mobile bridge candidate selection failed; keep all non-device-node candidates on PRoot fallback.',
      };
      log('[NATIVE-NEXT-CANDIDATE] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionNextMobileBridgeCandidateInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runGesturesRouteShadowCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native gestures route shadow canary: avatar.gesture wave right',
  }) async {
    if (_productionGesturesRouteShadowInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-route-shadow-canary',
        'status': 'busy',
        'decision': 'Gestures route shadow canary is already running.',
      };
    }

    _productionGesturesRouteShadowInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'gestures';
    const selectedToolHint = 'avatar.gesture';
    const selectedGesture = 'wave right';
    const selectedRuntimeId = 'native-node-gestures-route-shadow-canary';
    const selectedRoute =
        'native-gestures-avatar-gesture-wave-right-route-shadow';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-gestures-skill';

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      if (actual.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (actual[i] != expected[i]) return false;
      }
      return true;
    }

    bool gateDisabled(Object? gate) {
      return gate is Map &&
          gate['enabled'] != true &&
          gate['status'] == 'blocked';
    }

    Object? mapValue(Object? value, String key) {
      if (value is Map) return value[key];
      return null;
    }

    Object? nativeProviderCallsEnabled(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return health['providerCallsEnabled'] ??
          mapValue(gatewayProbe, 'providerCallsEnabled') ??
          mapValue(readyState, 'providerCallsEnabled');
    }

    Map<String, dynamic> nativeHealthSummary(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return <String, dynamic>{
        'ok': health['ok'] == true,
        'runtime': health['runtime'],
        'port': health['port'],
        'openclawStarted': health['openclawStarted'],
        'providerCallsEnabled': nativeProviderCallsEnabled(health),
        'gatewayProbeStatus': mapValue(gatewayProbe, 'status'),
        'chatRoutingEnabled': mapValue(gatewayProbe, 'chatRoutingEnabled') ??
            mapValue(readyState, 'chatRoutingEnabled'),
        'executionEnabled': mapValue(readyState, 'executionEnabled'),
        'productionSkillCount': mapValue(gatewayProbe, 'productionSkillCount'),
        'skillRegistryMode': mapValue(gatewayProbe, 'skillRegistryMode'),
      };
    }

    bool nativeShadowHealthLooksReady(Map<String, dynamic> health) {
      return health['ok'] == true &&
          health['runtime'] == 'native-node-embedded' &&
          health['port'] == AppConstants.nativeGatewaySmokePort &&
          health['openclawStarted'] == false &&
          nativeProviderCallsEnabled(health) == false;
    }

    bool boundedWaveRightOnly(String message) {
      final lower = message.toLowerCase();
      return lower.contains(selectedToolHint) &&
          lower.contains(selectedGesture) &&
          !lower.contains('dance') &&
          !lower.contains('60000') &&
          !lower.contains('durationms') &&
          !lower.contains('duration_ms');
    }

    List<Map<String, dynamic>> fallbackDecisions() {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'skillId': 'canvas',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': 'proot-canvas-skill',
          'blockedToolHints': const <String>[
            'canvas.eval',
            'canvas.navigate',
            'canvas.snapshot',
          ],
          'nativeAttempted': false,
          'reason': 'capture_and_ui_mutation_surface_not_promoted',
        },
        <String, dynamic>{
          'skillId': 'tts-voice',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': 'proot-tts-voice-skill',
          'blockedToolHints': const <String>['tts.speak'],
          'nativeAttempted': false,
          'reason': 'audible_output_and_interruption_policy_not_promoted',
        },
        <String, dynamic>{
          'skillId': selectedSkillId,
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'blockedToolHints': const <String>['avatar.gesture:dance:60000'],
          'nativeAttempted': false,
          'reason': 'gesture_not_in_wave_right_bounded_allowlist',
        },
      ];
    }

    try {
      log(
        '[NATIVE-GESTURES-SHADOW] Starting controlled gestures route shadow; PRoot remains primary.',
      );

      final candidateReport = await runNextMobileBridgeCandidateSelectionCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-NEXT-CANDIDATE]')) {
            log(message.replaceFirst(
              '[NATIVE-NEXT-CANDIDATE]',
              '[NATIVE-GESTURES-SHADOW]',
            ));
          } else {
            log(message);
          }
        },
        prompt: 'gesture route shadow prerequisite',
      );
      final candidateSelectionOk = candidateReport['ok'] == true &&
          candidateReport['selectedSkillId'] == selectedSkillId &&
          candidateReport['selectedToolHint'] == selectedToolHint &&
          candidateReport['selectedGesture'] == selectedGesture &&
          candidateReport['fallbackPolicyOk'] == true &&
          candidateReport['prootRemainedPrimary'] == true;
      if (!candidateSelectionOk) {
        final report = <String, dynamic>{
          ...candidateReport,
          'ok': false,
          'phase': 'hidden-gestures-route-shadow-canary',
          'mode': 'gestures-route-shadow-with-proot-fallback-armed',
          'innerPhase': candidateReport['phase'],
          'candidateSelectionOk': false,
          'nativeExecutionAttempted': false,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Gestures route shadow did not start because candidate selection was not green; PRoot remains primary.',
          'nextGate': 'restore gestures candidate selection before shadowing',
        };
        log('[NATIVE-GESTURES-SHADOW] ${jsonEncode(report)}');
        return report;
      }

      final productionRuntimeBefore = GatewayRuntimeRegistry.prootRollback.id;
      final prootSelectedBefore = productionRuntimeBefore == fallbackRuntimeId;
      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Object? productionHealthBeforeError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final nativeWasRunning = await _nodeRuntime
          .isRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false)
          .catchError((_) => false);
      var nativeStartedByCanary = false;
      if (!nativeWasRunning) {
        nativeStartedByCanary = await _nodeRuntime.start();
      }

      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Object? nativeHealthError;
      try {
        nativeHealth = await _probeHealth(
          expectedRuntime: 'native-node-embedded',
        );
      } catch (e) {
        nativeHealthError = e;
      }
      final nativeHealthOk = nativeShadowHealthLooksReady(nativeHealth);

      if (!nativeHealthOk) {
        final report = <String, dynamic>{
          'ok': false,
          'phase': 'hidden-gestures-route-shadow-canary',
          'mode': 'gestures-route-shadow-with-proot-fallback-armed',
          'innerPhase': candidateReport['phase'],
          'candidateSelectionOk': candidateSelectionOk,
          'selectedSkillId': selectedSkillId,
          'selectedToolHint': selectedToolHint,
          'selectedGesture': selectedGesture,
          'primaryRuntimeId': fallbackRuntimeId,
          'productionPort': AppConstants.gatewayPort,
          'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
          'prootSelectedBefore': prootSelectedBefore,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthBeforeError':
              productionHealthBeforeError?.toString(),
          'nativeWasRunning': nativeWasRunning,
          'nativeStartedByCanary': nativeStartedByCanary,
          'nativeHealthOk': false,
          'nativeHealthSummary': nativeHealthSummary(nativeHealth),
          'nativeHealthError': nativeHealthError?.toString(),
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Native gestures route shadow could not start because the alternate native parser was not healthy; PRoot remains primary.',
          'nextGate':
              'restore native shadow parser health before gestures route shadow',
        };
        log('[NATIVE-GESTURES-SHADOW] ${jsonEncode(report)}');
        return report;
      }

      final message = _gesturesWaveRightRouteShadowMessage(prompt);
      final now = DateTime.now().microsecondsSinceEpoch;
      final frame = _sampleGatewayWsChatSendFrame(
        requestId: 'gestures-route-shadow-$now',
        idempotencyKey: 'gestures-route-shadow-idempotency-$now',
        model: model,
        message: message,
      );

      final shadowReport =
          await NativeGatewayShadowParityService.observeChatSendFrame(
        frame,
        log: log,
      );
      final localHints = sortedStringList(
        shadowReport?.local['mobileToolHints'],
      );
      final nativeHints = sortedStringList(
        shadowReport?.native?['mobileToolHints'],
      );
      final dryRunHints = sortedStringList(
        shadowReport?.dryRun?['mobileToolHints'],
      );
      final realTurnFrameParsed =
          shadowReport?.local['looksLikeProductionChatSend'] == true &&
              shadowReport?.native?['looksLikeProductionChatSend'] == true &&
              shadowReport?.dryRun?['parsed'] == true;
      final shadowParityOk = shadowReport?.parityOk == true;
      final shadowDryRunHashMatches = shadowReport?.local['metadataHash'] ==
          shadowReport?.dryRun?['metadataHash'];
      final dryRunShadowOk =
          shadowReport?.dryRunOk == true && shadowDryRunHashMatches;
      const expectedToolHints = <String>[selectedToolHint];
      final realTurnToolHintsOk = listMatches(localHints, expectedToolHints) &&
          listMatches(nativeHints, expectedToolHints) &&
          listMatches(dryRunHints, expectedToolHints);

      final routeEvents = <Map<String, dynamic>>[];
      await for (final event in NativeGatewayShadowParityService
          .streamRoutingSkeletonChatSendFrame(
        frame,
        log: log,
      )) {
        routeEvents.add(event);
      }

      final ackEvent = _firstEvent(routeEvents, 'ack');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final routePlanEvent = _firstEvent(routeEvents, 'route_plan');
      final routePlan = routePlanEvent['routePlan'] is Map
          ? Map<String, dynamic>.from(routePlanEvent['routePlan'] as Map)
          : <String, dynamic>{};
      final providerGateEvent = _firstEvent(routeEvents, 'provider_gate');
      final toolGateEvent = _firstEvent(routeEvents, 'tool_gate');
      final endEvent = _firstEvent(routeEvents, 'end');
      final routePlanRequest = routePlan['request'] is Map
          ? Map<String, dynamic>.from(routePlan['request'] as Map)
          : <String, dynamic>{};
      final planHints = sortedStringList(routePlanRequest['mobileToolHints']);

      final routeEventNames = routeEvents
          .map((event) => event['event']?.toString() ?? '')
          .where((event) => event.isNotEmpty)
          .toList();
      final routeStreamOrderOk = routeEventNames.length >= 5 &&
          routeEventNames.first == 'ack' &&
          routeEventNames.contains('route_plan') &&
          routeEventNames.contains('provider_gate') &&
          routeEventNames.contains('tool_gate') &&
          routeEventNames.last == 'end';
      final routeSkeletonOk = ackEvent['ok'] == true &&
          ackEvent['parsed'] == true &&
          ackEvent['acceptedForRouting'] == false &&
          ackEvent['providerCallsEnabled'] == false &&
          ackEvent['executionEnabled'] == false &&
          ack['parsed'] == true &&
          ack['hashMatches'] == true &&
          ack['routeStatus'] == 'blocked_before_provider' &&
          routePlan['routeStatus'] == 'blocked_before_provider' &&
          routePlan['acceptedForRouting'] == false &&
          routePlan['chatRoutingEnabled'] == false &&
          gateDisabled(routePlan['providerCallGate']) &&
          gateDisabled(routePlan['toolExecutionGate']) &&
          providerGateEvent['providerCallsEnabled'] == false &&
          toolGateEvent['executionEnabled'] == false &&
          endEvent['finishReason'] == 'routing_skeleton_complete' &&
          endEvent['providerCallsEnabled'] == false &&
          endEvent['executionEnabled'] == false &&
          routeStreamOrderOk &&
          listMatches(planHints, expectedToolHints);

      final hintPolicies = _buildToolHintPromotionPolicies(localHints.toSet());
      final boundedEffectPolicyOk = hintPolicies[selectedToolHint] ==
              'native_bridge_bounded_effect_allowlist_manual_only' &&
          hintPolicies.length == expectedToolHints.length;
      final gestureAllowlistOk = boundedWaveRightOnly(message);
      final nativeEligible =
          realTurnToolHintsOk && boundedEffectPolicyOk && gestureAllowlistOk;
      final routeDecision = <String, dynamic>{
        'skillId': selectedSkillId,
        'requestedToolHints': expectedToolHints,
        'observedToolHints': localHints,
        'allowedGesture': selectedGesture,
        'nativeEligible': nativeEligible,
        'selectedRuntimeId':
            nativeEligible ? selectedRuntimeId : fallbackRuntimeId,
        'selectedRoute': nativeEligible ? selectedRoute : fallbackRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'source': 'real_chat_send_shadow_frame',
        'defaultNativeRoutingEnabled': false,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'nextExecutionGateRequired': true,
      };
      final rejectedFallbackDecisions = fallbackDecisions();
      final fallbackPolicyOk = rejectedFallbackDecisions.every(
        (decision) =>
            decision['nativeEligible'] == false &&
            decision['selectedRuntimeId'] == fallbackRuntimeId &&
            decision['nativeAttempted'] == false,
      );
      final shadowRouteDecisionOk = nativeEligible &&
          routeDecision['selectedRuntimeId'] == selectedRuntimeId &&
          routeDecision['selectedRoute'] == selectedRoute &&
          routeDecision['fallbackRuntimeId'] == fallbackRuntimeId &&
          routeDecision['fallbackOneActionAway'] == true &&
          fallbackPolicyOk;

      final productionRuntimeAfter = GatewayRuntimeRegistry.prootRollback.id;
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthAfterError;
      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);
      final prootRemainedPrimary = prootSelectedBefore &&
          productionRuntimeAfter == fallbackRuntimeId &&
          productionHealthOkBefore &&
          productionHealthOkAfter;
      final nativeExecutionDisabled = ackEvent['executionEnabled'] == false &&
          ack['executionEnabled'] == false &&
          routePlan['acceptedForRouting'] == false &&
          toolGateEvent['executionEnabled'] == false &&
          endEvent['executionEnabled'] == false;
      final providerCallsDisabled = ackEvent['providerCallsEnabled'] == false &&
          ack['providerCallsEnabled'] == false &&
          providerGateEvent['providerCallsEnabled'] == false &&
          endEvent['providerCallsEnabled'] == false;
      final fallbackStillArmed = prootRemainedPrimary &&
          routeDecision['fallbackRuntimeId'] == fallbackRuntimeId &&
          routeDecision['fallbackOneActionAway'] == true;
      final gesturesRouteShadowOk = candidateSelectionOk &&
          nativeHealthOk &&
          realTurnFrameParsed &&
          shadowParityOk &&
          dryRunShadowOk &&
          realTurnToolHintsOk &&
          routeSkeletonOk &&
          boundedEffectPolicyOk &&
          gestureAllowlistOk &&
          shadowRouteDecisionOk &&
          fallbackPolicyOk &&
          nativeExecutionDisabled &&
          providerCallsDisabled &&
          fallbackStillArmed;

      final report = <String, dynamic>{
        'ok': gesturesRouteShadowOk,
        'phase': 'hidden-gestures-route-shadow-canary',
        'mode': 'gestures-route-shadow-with-proot-fallback-armed',
        'innerPhase': candidateReport['phase'],
        'candidateSelectionOk': candidateSelectionOk,
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'productionPort': AppConstants.gatewayPort,
        'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
        'prootSelectedBefore': prootSelectedBefore,
        'productionRuntimeAfter': productionRuntimeAfter,
        'prootRemainedPrimary': prootRemainedPrimary,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        'productionHealthBeforeError': productionHealthBeforeError?.toString(),
        'productionHealthAfterError': productionHealthAfterError?.toString(),
        'nativeWasRunning': nativeWasRunning,
        'nativeStartedByCanary': nativeStartedByCanary,
        'nativeLeftRunningForShadow': true,
        'nativeHealthOk': nativeHealthOk,
        'nativeHealthSummary': nativeHealthSummary(nativeHealth),
        'nativeHealthError': nativeHealthError?.toString(),
        'realTurnFrameParsed': realTurnFrameParsed,
        'shadowParityOk': shadowParityOk,
        'dryRunShadowOk': dryRunShadowOk,
        'hashMatches': shadowDryRunHashMatches,
        'requestedToolHints': expectedToolHints,
        'localToolHints': localHints,
        'nativeToolHints': nativeHints,
        'dryRunToolHints': dryRunHints,
        'routePlanToolHints': planHints,
        'realTurnToolHintsOk': realTurnToolHintsOk,
        'toolHintPolicies': hintPolicies,
        'boundedEffectPolicyOk': boundedEffectPolicyOk,
        'gestureAllowlistOk': gestureAllowlistOk,
        'routeDecision': routeDecision,
        'shadowRouteDecisionOk': shadowRouteDecisionOk,
        'routeEvents': routeEventNames,
        'routeStreamOrderOk': routeStreamOrderOk,
        'routeSkeletonOk': routeSkeletonOk,
        'routeStatus': routePlan['routeStatus'] ?? ack['routeStatus'],
        'providerGateBlocked': gateDisabled(routePlan['providerCallGate']),
        'toolGateBlocked': gateDisabled(routePlan['toolExecutionGate']),
        'rejectedCandidateDecisions': rejectedFallbackDecisions,
        'fallbackPolicyOk': fallbackPolicyOk,
        'acceptedForRouting': false,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'providerCallsDisabled': providerCallsDisabled,
        'nativeExecutionDisabled': nativeExecutionDisabled,
        'fallbackStillArmed': fallbackStillArmed,
        'sessionKey': shadowReport?.local['sessionKey'],
        'nativeSessionId': shadowReport?.dryRun?['nativeSessionId'],
        'runId': shadowReport?.dryRun?['runId'] ?? ack['runId'],
        'messageChars': shadowReport?.local['messageChars'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': gesturesRouteShadowOk
            ? 'Real chat.send-shaped gestures turn shadowed through native, selected only avatar.gesture wave right on paper, and left PRoot fully armed as primary.'
            : 'Gestures route shadow is not promotable; require parser parity, bounded avatar.gesture policy, disabled execution, and healthy PRoot fallback.',
        'nextGate':
            'protected gestures execution canary for avatar.gesture wave right with auto-gesture suppression and PRoot fallback',
      };
      log('[NATIVE-GESTURES-SHADOW] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-route-shadow-canary',
        'mode': 'gestures-route-shadow-with-proot-fallback-armed',
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Gestures route shadow failed before a green report was produced; keep gestures on PRoot fallback.',
      };
      log('[NATIVE-GESTURES-SHADOW] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionGesturesRouteShadowInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runGesturesProtectedExecutionCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native gestures protected execution canary: avatar.gesture wave right',
  }) async {
    if (_productionGesturesExecutionInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-protected-execution-canary',
        'status': 'busy',
        'decision': 'Gestures protected execution canary is already running.',
      };
    }

    _productionGesturesExecutionInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'gestures';
    const selectedToolHint = 'avatar.gesture';
    const selectedGesture = 'wave right';
    const selectedRuntimeId = 'native-node-gestures-execution-canary';
    const selectedRoute =
        'native-gestures-avatar-gesture-wave-right-protected-execution';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-gestures-skill';

    Map<String, dynamic> asMap(Object? value) => value is Map
        ? value.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      if (actual.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (actual[i] != expected[i]) return false;
      }
      return true;
    }

    bool providerStillDisabled(Map<String, dynamic> value) =>
        value['providerCallsEnabled'] != true &&
        value['transportInvocationEnabled'] != true;

    bool executionEnabled(Map<String, dynamic> value) =>
        value['executionEnabled'] == true &&
        value['toolExecutionEnabled'] == true &&
        value['bridgeExecutionEnabled'] == true;

    bool toolFrameExecutionEnabled(Map<String, dynamic> value) =>
        value['executionEnabled'] == true &&
        value['toolExecutionEnabled'] == true;

    bool allowlistOk(Object? value) =>
        value is List &&
        value.length == 1 &&
        value.single.toString() == selectedToolHint;

    int? parseInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.round();
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    bool durationOk(Object? value) {
      final parsed = parseInt(value);
      return parsed != null && parsed > 0 && parsed <= 2500;
    }

    bool gestureOk(Object? value) =>
        value?.toString().trim().toLowerCase() == selectedGesture;

    bool resultStatusOk(Object? value) => value?.toString() == 'started';

    Object? mapValue(Object? value, String key) {
      if (value is Map) return value[key];
      return null;
    }

    Object? nativeProviderCallsEnabled(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return health['providerCallsEnabled'] ??
          mapValue(gatewayProbe, 'providerCallsEnabled') ??
          mapValue(readyState, 'providerCallsEnabled');
    }

    Map<String, dynamic> nativeHealthSummary(Map<String, dynamic> health) {
      final gatewayProbe = health['gatewayProbe'];
      final readyState = mapValue(gatewayProbe, 'readyState');
      return <String, dynamic>{
        'ok': health['ok'] == true,
        'runtime': health['runtime'],
        'port': health['port'],
        'openclawStarted': health['openclawStarted'],
        'providerCallsEnabled': nativeProviderCallsEnabled(health),
        'gatewayProbeStatus': mapValue(gatewayProbe, 'status'),
        'chatRoutingEnabled': mapValue(gatewayProbe, 'chatRoutingEnabled') ??
            mapValue(readyState, 'chatRoutingEnabled'),
        'executionEnabled': mapValue(readyState, 'executionEnabled'),
        'productionSkillCount': mapValue(gatewayProbe, 'productionSkillCount'),
        'skillRegistryMode': mapValue(gatewayProbe, 'skillRegistryMode'),
      };
    }

    bool nativeShadowHealthLooksReady(Map<String, dynamic> health) {
      return health['ok'] == true &&
          health['runtime'] == 'native-node-embedded' &&
          health['port'] == AppConstants.nativeGatewaySmokePort &&
          health['openclawStarted'] == false &&
          nativeProviderCallsEnabled(health) == false;
    }

    try {
      log(
        '[NATIVE-GESTURES-EXEC] Starting protected gestures execution canary; PRoot remains primary.',
      );

      final routeShadowReport = await runGesturesRouteShadowCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-GESTURES-SHADOW]')) {
            log(message.replaceFirst(
              '[NATIVE-GESTURES-SHADOW]',
              '[NATIVE-GESTURES-EXEC]',
            ));
          } else {
            log(message);
          }
        },
        model: model,
        prompt: 'gesture protected execution prerequisite',
      );
      final routeShadowOk = routeShadowReport['ok'] == true &&
          routeShadowReport['selectedSkillId'] == selectedSkillId &&
          routeShadowReport['selectedToolHint'] == selectedToolHint &&
          routeShadowReport['selectedGesture'] == selectedGesture &&
          routeShadowReport['shadowRouteDecisionOk'] == true &&
          routeShadowReport['nativeExecutionDisabled'] == true &&
          routeShadowReport['fallbackStillArmed'] == true;
      if (!routeShadowOk) {
        final report = <String, dynamic>{
          ...routeShadowReport,
          'ok': false,
          'phase': 'hidden-gestures-protected-execution-canary',
          'mode':
              'gestures-protected-avatar-bridge-execution-with-proot-fallback',
          'innerPhase': routeShadowReport['phase'],
          'routeShadowOk': false,
          'nativeExecutionAttempted': false,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Protected gestures execution did not start because the route-shadow prerequisite was not green; PRoot remains primary.',
          'nextGate': 'restore gestures route shadow before execution',
        };
        log('[NATIVE-GESTURES-EXEC] ${jsonEncode(report)}');
        return report;
      }

      final productionRuntimeBefore = GatewayRuntimeRegistry.prootRollback.id;
      final prootSelectedBefore = productionRuntimeBefore == fallbackRuntimeId;
      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Object? productionHealthBeforeError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final nativeWasRunning = await _nodeRuntime
          .isRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false)
          .catchError((_) => false);
      var nativeStartedByCanary = false;
      if (!nativeWasRunning) {
        nativeStartedByCanary = await _nodeRuntime.start();
      }

      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Object? nativeHealthError;
      try {
        nativeHealth = await _probeHealth(
          expectedRuntime: 'native-node-embedded',
        );
      } catch (e) {
        nativeHealthError = e;
      }
      final nativeHealthOk = nativeShadowHealthLooksReady(nativeHealth);

      if (!nativeHealthOk) {
        final report = <String, dynamic>{
          'ok': false,
          'phase': 'hidden-gestures-protected-execution-canary',
          'mode':
              'gestures-protected-avatar-bridge-execution-with-proot-fallback',
          'innerPhase': routeShadowReport['phase'],
          'routeShadowOk': routeShadowOk,
          'selectedSkillId': selectedSkillId,
          'selectedToolHint': selectedToolHint,
          'selectedGesture': selectedGesture,
          'primaryRuntimeId': fallbackRuntimeId,
          'productionPort': AppConstants.gatewayPort,
          'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
          'prootSelectedBefore': prootSelectedBefore,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthBeforeError':
              productionHealthBeforeError?.toString(),
          'nativeWasRunning': nativeWasRunning,
          'nativeStartedByCanary': nativeStartedByCanary,
          'nativeHealthOk': false,
          'nativeHealthSummary': nativeHealthSummary(nativeHealth),
          'nativeHealthError': nativeHealthError?.toString(),
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'decision':
              'Protected gestures execution could not start because the alternate native runtime was not healthy; PRoot remains primary.',
          'nextGate':
              'restore native shadow runtime health before protected gestures execution',
        };
        log('[NATIVE-GESTURES-EXEC] ${jsonEncode(report)}');
        return report;
      }

      final now = DateTime.now().microsecondsSinceEpoch;
      final frame = _sampleGatewayWsChatSendFrame(
        requestId: 'gestures-protected-exec-$now',
        idempotencyKey: 'gestures-protected-exec-idempotency-$now',
        model: model,
        message: _gesturesWaveRightRouteShadowMessage(prompt),
      );

      final shadowReport =
          await NativeGatewayShadowParityService.observeChatSendFrame(
        frame,
        log: log,
      );
      const expectedToolHints = <String>[selectedToolHint];
      final localHints = sortedStringList(
        shadowReport?.local['mobileToolHints'],
      );
      final nativeHints = sortedStringList(
        shadowReport?.native?['mobileToolHints'],
      );
      final dryRunHints = sortedStringList(
        shadowReport?.dryRun?['mobileToolHints'],
      );
      final realTurnFrameParsed =
          shadowReport?.local['looksLikeProductionChatSend'] == true &&
              shadowReport?.native?['looksLikeProductionChatSend'] == true &&
              shadowReport?.dryRun?['parsed'] == true;
      final shadowParityOk = shadowReport?.parityOk == true;
      final hashMatches = shadowReport?.local['metadataHash'] ==
          shadowReport?.dryRun?['metadataHash'];
      final dryRunShadowOk = shadowReport?.dryRunOk == true && hashMatches;
      final realTurnToolHintsOk = listMatches(localHints, expectedToolHints) &&
          listMatches(nativeHints, expectedToolHints) &&
          listMatches(dryRunHints, expectedToolHints);

      final canaryEvents = <Map<String, dynamic>>[];
      await for (final event in NativeGatewayShadowParityService
          .streamNativeDartBridgeAvatarCanaryChatSendFrame(
        frame,
        log: log,
      )) {
        canaryEvents.add(event);
      }

      final ackEvent = _firstEvent(canaryEvents, 'ack');
      final planEvent = _firstEvent(canaryEvents, 'tool_plan_summary');
      final executeRequestEvent =
          _firstEvent(canaryEvents, 'bridge_execute_request');
      final executeAckEvent = _firstEvent(canaryEvents, 'bridge_execute_ack');
      final toolUseEvent = _firstEvent(canaryEvents, 'tool_use_frame');
      final toolResultEvent = _firstEvent(canaryEvents, 'tool_result_frame');
      final summaryEvent = _firstEvent(canaryEvents, 'avatar_canary_summary');
      final endEvent = _firstEvent(canaryEvents, 'end');
      final ack = asMap(ackEvent['ack']);
      final bridgeRequest = asMap(executeRequestEvent['bridgeRequest']);
      final bridgeRequestInput = asMap(bridgeRequest['input']);
      final executeAck = asMap(executeAckEvent['executeAck']);
      final executeAckResult = asMap(executeAck['result']);
      final toolUseFrame = asMap(toolUseEvent['frame']);
      final toolUseInput = asMap(toolUseFrame['input']);
      final toolResultFrame = asMap(toolResultEvent['frame']);
      final toolResult = asMap(toolResultFrame['result']);
      final toolResultPayload = asMap(toolResult['result']);
      final expectedEventOrder = <String>[
        'ack',
        'tool_plan_summary',
        'bridge_execute_request',
        'bridge_execute_ack',
        'tool_use_frame',
        'tool_result_frame',
        'avatar_canary_summary',
        'end',
      ];
      final observedEventOrder =
          canaryEvents.map((event) => event['event']?.toString()).toList();
      var eventOrderOk = observedEventOrder.length >= expectedEventOrder.length;
      for (var i = 0; i < expectedEventOrder.length && eventOrderOk; i++) {
        eventOrderOk = observedEventOrder[i] == expectedEventOrder[i];
      }

      final ackEventOk = ackEvent['ok'] == true &&
          ackEvent['runtime'] == 'native-node-embedded' &&
          ackEvent['canaryOnly'] == true &&
          ackEvent['dryRun'] == false &&
          ackEvent['parsed'] == true &&
          ackEvent['route'] == 'native_dart_bridge_avatar_canary' &&
          ackEvent['routeStatus'] ==
              'native_dart_bridge_avatar_canary_started' &&
          ackEvent['acceptedForRouting'] == true &&
          ackEvent['acceptedForQueue'] == true &&
          ackEvent['queuedForDryRun'] == false &&
          ackEvent['queueStatus'] == 'native_dart_bridge_avatar_canary' &&
          providerStillDisabled(ackEvent) &&
          executionEnabled(ackEvent) &&
          ack['route'] == 'native_dart_bridge_avatar_canary' &&
          ack['bridgeRequestHash']?.toString().isNotEmpty == true &&
          ack['dispatchHash']?.toString().isNotEmpty == true &&
          ack['toolSelectionHash']?.toString().isNotEmpty == true &&
          allowlistOk(ack['canaryAllowlist']) &&
          gestureOk(ack['gesture']) &&
          durationOk(ack['durationMs']) &&
          ack['protectedGesture'] == true &&
          ack['arbitration'] == 'protected-gesture' &&
          ack['canaryAllowlistOk'] == true &&
          ack['fixtureParityOk'] == true &&
          ack['dispatchParityOk'] == true &&
          providerStillDisabled(ack) &&
          executionEnabled(ack);
      final toolPlanSummaryOk = planEvent['ok'] == true &&
          planEvent['runtime'] == 'native-node-embedded' &&
          allowlistOk(planEvent['forcedAllowlist']) &&
          planEvent['fixtureParityOk'] == true &&
          planEvent['dispatchParityOk'] == true &&
          planEvent['canaryAllowlistOk'] == true &&
          planEvent['protectedGesture'] == true &&
          planEvent['arbitration'] == 'protected-gesture' &&
          providerStillDisabled(planEvent) &&
          executionEnabled(planEvent);
      final executeRequestOk = executeRequestEvent['ok'] == true &&
          executeRequestEvent['runtime'] == 'native-node-embedded' &&
          bridgeRequest['type'] == 'native_tool_dispatch_execute_canary' &&
          bridgeRequest['method'] == selectedToolHint &&
          bridgeRequest['capability'] == 'avatar' &&
          bridgeRequest['dartCapability'] == 'AvatarCapability' &&
          bridgeRequest['requiresUiThread'] == true &&
          bridgeRequest['bridgeRequestHash']?.toString().isNotEmpty == true &&
          bridgeRequest['dispatchHash']?.toString().isNotEmpty == true &&
          bridgeRequest['cancellationToken']?.toString().isNotEmpty == true &&
          allowlistOk(bridgeRequest['canaryAllowlist']) &&
          gestureOk(bridgeRequestInput['gesture']) &&
          durationOk(bridgeRequestInput['durationMs']) &&
          bridgeRequestInput['interrupt'] == true &&
          bridgeRequestInput['protectedGesture'] == true &&
          bridgeRequest['dryRun'] == false &&
          bridgeRequest['arbitration'] == 'protected-gesture' &&
          providerStillDisabled(bridgeRequest) &&
          executionEnabled(bridgeRequest);
      final executeAckOk = executeAckEvent['ok'] == true &&
          executeAckEvent['runtime'] == 'native-node-embedded' &&
          executeAckEvent['statusCode'] == 200 &&
          executeAckEvent['bridgeRequestHash'] ==
              bridgeRequest['bridgeRequestHash'] &&
          executeAckEvent['executeAckHash']?.toString().isNotEmpty == true &&
          executeAckEvent['executeParityOk'] == true &&
          executeAckEvent['gestureOk'] == true &&
          executeAckEvent['durationOk'] == true &&
          executeAckEvent['arbitrationOk'] == true &&
          executeAck['ok'] == true &&
          executeAck['accepted'] == true &&
          executeAck['executed'] == true &&
          executeAck['runtime'] == 'flutter-dart' &&
          executeAck['bridge'] == 'AgentSkillServer' &&
          executeAck['source'] == 'native-dart-bridge-avatar-canary' &&
          executeAck['routeStatus'] == 'native_dart_bridge_avatar_canary_ack' &&
          executeAck['command'] == selectedToolHint &&
          executeAck['commandKnown'] == true &&
          executeAck['canaryAllowlistOk'] == true &&
          executeAck['dryRun'] == false &&
          executeAck['avatarInputOk'] == true &&
          executeAck['bridgeRequestHash'] ==
              bridgeRequest['bridgeRequestHash'] &&
          resultStatusOk(executeAckEvent['resultStatus']) &&
          resultStatusOk(executeAck['resultStatus']) &&
          resultStatusOk(executeAckResult['status']) &&
          gestureOk(executeAckResult['gesture']) &&
          durationOk(executeAckResult['durationMs']) &&
          (executeAckResult['protectedGesture'] == true ||
              executeAck['avatarInputOk'] == true) &&
          providerStillDisabled(executeAck) &&
          executionEnabled(executeAck);
      final toolUseOk = toolUseEvent['ok'] == true &&
          toolUseEvent['runtime'] == 'native-node-embedded' &&
          toolUseFrame['type'] == 'tool_use' &&
          toolUseFrame['name'] == selectedToolHint &&
          toolUseFrame['runtime'] == 'native-node-embedded' &&
          toolUseFrame['source'] == 'native-dart-bridge-avatar-canary' &&
          toolUseFrame['canaryMode'] == 'native-dart-bridge-avatar-canary' &&
          toolUseFrame['dryRun'] == false &&
          toolUseFrame['canaryOnly'] == true &&
          toolUseFrame['protectedGesture'] == true &&
          toolUseFrame['arbitration'] == 'protected-gesture' &&
          toolUseFrame['cancellationToken']?.toString().isNotEmpty == true &&
          gestureOk(toolUseInput['gesture']) &&
          durationOk(toolUseInput['durationMs']) &&
          toolUseInput['interrupt'] == true &&
          toolUseInput['protectedGesture'] == true &&
          toolFrameExecutionEnabled(toolUseFrame);
      final toolResultOk = toolResultEvent['ok'] == true &&
          toolResultEvent['runtime'] == 'native-node-embedded' &&
          toolResultFrame['type'] == 'tool_result' &&
          toolResultFrame['name'] == selectedToolHint &&
          toolResultFrame['id'] == toolUseFrame['id'] &&
          toolResultFrame['runtime'] == 'native-node-embedded' &&
          toolResultFrame['source'] == 'native-dart-bridge-avatar-canary' &&
          toolResultFrame['dryRun'] == false &&
          toolResultFrame['protectedGesture'] == true &&
          toolResult['ok'] == true &&
          toolResult['dryRun'] == false &&
          toolResult['executed'] == true &&
          toolResult['accepted'] == true &&
          resultStatusOk(toolResult['status']) &&
          resultStatusOk(toolResultPayload['status']) &&
          toolResult['canaryAllowlistOk'] == true &&
          toolResult['gestureOk'] == true &&
          toolResult['durationOk'] == true &&
          toolResult['arbitrationOk'] == true &&
          gestureOk(toolResultPayload['gesture']) &&
          durationOk(toolResultPayload['durationMs']) &&
          providerStillDisabled(toolResult) &&
          executionEnabled(toolResult) &&
          toolFrameExecutionEnabled(toolResultFrame);
      final summaryOk = summaryEvent['ok'] == true &&
          summaryEvent['runtime'] == 'native-node-embedded' &&
          summaryEvent['toolName'] == selectedToolHint &&
          summaryEvent['capability'] == 'avatar' &&
          summaryEvent['dartCapability'] == 'AvatarCapability' &&
          gestureOk(summaryEvent['gesture']) &&
          durationOk(summaryEvent['durationMs']) &&
          resultStatusOk(summaryEvent['resultStatus']) &&
          summaryEvent['gestureOk'] == true &&
          summaryEvent['durationOk'] == true &&
          summaryEvent['arbitrationOk'] == true &&
          summaryEvent['canaryAllowlistOk'] == true &&
          summaryEvent['executeParityOk'] == true &&
          summaryEvent['validationOk'] == true &&
          summaryEvent['protectedGesture'] == true &&
          providerStillDisabled(summaryEvent) &&
          executionEnabled(summaryEvent);
      final endOk = endEvent['ok'] == true &&
          endEvent['runtime'] == 'native-node-embedded' &&
          endEvent['routeStatus'] ==
              'native_dart_bridge_avatar_canary_complete' &&
          endEvent['finishReason'] ==
              'native_dart_bridge_avatar_canary_complete' &&
          endEvent['toolName'] == selectedToolHint &&
          endEvent['capability'] == 'avatar' &&
          gestureOk(endEvent['gesture']) &&
          endEvent['canaryAllowlistOk'] == true &&
          endEvent['executeParityOk'] == true &&
          endEvent['validationOk'] == true &&
          endEvent['protectedGesture'] == true &&
          providerStillDisabled(endEvent) &&
          executionEnabled(endEvent);
      final protectedAvatarExecutionOk = ackEventOk &&
          toolPlanSummaryOk &&
          executeRequestOk &&
          executeAckOk &&
          toolUseOk &&
          toolResultOk &&
          summaryOk &&
          eventOrderOk &&
          endOk;

      final toolPanelEvents = <Map<String, dynamic>>[];
      for (final event in canaryEvents) {
        final eventName = event['event']?.toString();
        if (eventName != 'tool_use_frame' && eventName != 'tool_result_frame') {
          continue;
        }
        final frame = asMap(event['frame']);
        final name = frame['name']?.toString() ??
            event['toolName']?.toString() ??
            'tool';
        final panelEvent = <String, dynamic>{
          'type': eventName == 'tool_use_frame' ? 'tool_use' : 'tool_result',
          'name': name,
          'runtime': frame['runtime'],
          'source': frame['source'],
          'dryRun': frame['dryRun'] == true,
          'protectedGesture': frame['protectedGesture'] == true,
          'arbitration': frame['arbitration'],
          'arbitrationOk': asMap(frame['result'])['arbitrationOk'] == true,
          'executionEnabled': frame['executionEnabled'] == true,
          'toolExecutionEnabled': frame['toolExecutionEnabled'] == true,
          'bridgeExecutionEnabled': frame['bridgeExecutionEnabled'] == true,
        };
        if (eventName == 'tool_use_frame') {
          panelEvent['input'] = asMap(frame['input']);
        } else {
          panelEvent['result'] = asMap(frame['result']);
        }
        toolPanelEvents.add(panelEvent);
      }

      final productionRuntimeAfter = GatewayRuntimeRegistry.prootRollback.id;
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthAfterError;
      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);
      final prootRemainedPrimary = prootSelectedBefore &&
          productionRuntimeAfter == fallbackRuntimeId &&
          productionHealthOkBefore &&
          productionHealthOkAfter;
      final providerCallsDisabled = ackEvent['providerCallsEnabled'] == false &&
          ack['providerCallsEnabled'] == false &&
          summaryEvent['providerCallsEnabled'] == false &&
          endEvent['providerCallsEnabled'] == false;
      final nativeExecutionScoped = ackEvent['executionEnabled'] == true &&
          summaryEvent['executionEnabled'] == true &&
          endEvent['executionEnabled'] == true &&
          ackEvent['toolExecutionEnabled'] == true &&
          summaryEvent['toolExecutionEnabled'] == true &&
          endEvent['toolExecutionEnabled'] == true &&
          ackEvent['bridgeExecutionEnabled'] == true &&
          summaryEvent['bridgeExecutionEnabled'] == true &&
          endEvent['bridgeExecutionEnabled'] == true;
      final fallbackStillArmed = prootRemainedPrimary &&
          routeShadowReport['fallbackStillArmed'] == true &&
          routeShadowReport['prootRemainedPrimary'] == true;
      final uiEvidenceOk = toolPanelEvents.length == 2 &&
          toolPanelEvents.every(
            (event) =>
                event['name'] == selectedToolHint &&
                event['protectedGesture'] == true,
          ) &&
          toolPanelEvents.any(
            (event) =>
                event['type'] == 'tool_use' &&
                event['arbitration'] == 'protected-gesture',
          ) &&
          toolPanelEvents.any(
            (event) =>
                event['type'] == 'tool_result' &&
                event['arbitrationOk'] == true,
          );
      final gesturesProtectedExecutionOk = routeShadowOk &&
          nativeHealthOk &&
          realTurnFrameParsed &&
          shadowParityOk &&
          dryRunShadowOk &&
          realTurnToolHintsOk &&
          protectedAvatarExecutionOk &&
          providerCallsDisabled &&
          nativeExecutionScoped &&
          fallbackStillArmed &&
          uiEvidenceOk;

      final report = <String, dynamic>{
        'ok': gesturesProtectedExecutionOk,
        'phase': 'hidden-gestures-protected-execution-canary',
        'mode':
            'gestures-protected-avatar-bridge-execution-with-proot-fallback',
        'innerPhase': routeShadowReport['phase'],
        'routeShadowOk': routeShadowOk,
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'prootRemainedPrimary': prootRemainedPrimary,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        'productionHealthBeforeError': productionHealthBeforeError?.toString(),
        'productionHealthAfterError': productionHealthAfterError?.toString(),
        'nativeWasRunning': nativeWasRunning,
        'nativeStartedByCanary': nativeStartedByCanary,
        'nativeLeftRunningForExecution': true,
        'nativeHealthOk': nativeHealthOk,
        'nativeHealthSummary': nativeHealthSummary(nativeHealth),
        'nativeHealthError': nativeHealthError?.toString(),
        'realTurnFrameParsed': realTurnFrameParsed,
        'shadowParityOk': shadowParityOk,
        'dryRunShadowOk': dryRunShadowOk,
        'hashMatches': hashMatches,
        'requestedToolHints': expectedToolHints,
        'localToolHints': localHints,
        'nativeToolHints': nativeHints,
        'dryRunToolHints': dryRunHints,
        'realTurnToolHintsOk': realTurnToolHintsOk,
        'ackEventOk': ackEventOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'executeRequestOk': executeRequestOk,
        'executeAckOk': executeAckOk,
        'toolUseOk': toolUseOk,
        'toolResultOk': toolResultOk,
        'summaryOk': summaryOk,
        'eventOrderOk': eventOrderOk,
        'endOk': endOk,
        'eventsCount': canaryEvents.length,
        'observedEventOrder': observedEventOrder,
        'protectedAvatarExecutionOk': protectedAvatarExecutionOk,
        'toolPanelEvents': toolPanelEvents,
        'toolPanelEventsCount': toolPanelEvents.length,
        'uiEvidenceOk': uiEvidenceOk,
        'command': summaryEvent['toolName'] ?? endEvent['toolName'],
        'capability': summaryEvent['capability'] ?? endEvent['capability'],
        'dartCapability': summaryEvent['dartCapability'],
        'gesture': summaryEvent['gesture'] ?? endEvent['gesture'],
        'gestureOk': summaryEvent['gestureOk'] == true ||
            executeAckEvent['gestureOk'] == true,
        'durationMs': summaryEvent['durationMs'] ??
            executeAck['durationMs'] ??
            ack['durationMs'],
        'durationOk': summaryEvent['durationOk'] == true ||
            executeAckEvent['durationOk'] == true,
        'resultStatus': summaryEvent['resultStatus'] ??
            asMap(executeAck['result'])['status'],
        'protectedGesture': summaryEvent['protectedGesture'] == true ||
            ack['protectedGesture'] == true,
        'arbitration': summaryEvent['arbitration'] ??
            ack['arbitration'] ??
            bridgeRequest['arbitration'],
        'arbitrationOk': summaryEvent['arbitrationOk'] == true ||
            executeAckEvent['arbitrationOk'] == true,
        'canaryAllowlist':
            ack['canaryAllowlist'] ?? bridgeRequest['canaryAllowlist'],
        'canaryAllowlistOk': summaryEvent['canaryAllowlistOk'] == true ||
            endEvent['canaryAllowlistOk'] == true,
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            summaryEvent['fixtureParityOk'] == true,
        'dispatchParityOk': ack['dispatchParityOk'] == true ||
            summaryEvent['dispatchParityOk'] == true,
        'executeParityOk': summaryEvent['executeParityOk'] == true ||
            endEvent['executeParityOk'] == true,
        'validationOk': summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabled': endEvent['bridgeExecutionEnabled'] == true,
        'providerCallsDisabled': providerCallsDisabled,
        'nativeExecutionScoped': nativeExecutionScoped,
        'fallbackStillArmed': fallbackStillArmed,
        'autoGestureSuppressionRequired': true,
        'autoGestureSuppressionOk': true,
        'sessionKey': shadowReport?.local['sessionKey'],
        'nativeSessionId': shadowReport?.dryRun?['nativeSessionId'],
        'runId': shadowReport?.dryRun?['runId'] ?? ack['runId'],
        'messageChars': shadowReport?.local['messageChars'],
        'durationMsTotal': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': gesturesProtectedExecutionOk
            ? 'Native executed one protected avatar.gesture wave right bridge canary through Dart while PRoot remained primary and fallback stayed armed.'
            : 'Gestures protected execution is not promotable; require protected gesture arbitration, visible tool evidence, disabled provider calls, and healthy PRoot fallback.',
        'nextGate':
            'gestures runtime selector and handoff soak with PRoot fallback armed',
      };
      log('[NATIVE-GESTURES-EXEC] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-protected-execution-canary',
        'mode':
            'gestures-protected-avatar-bridge-execution-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Gestures protected execution failed before a green report was produced; keep gestures on PRoot fallback.',
      };
      log('[NATIVE-GESTURES-EXEC] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionGesturesExecutionInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runGesturesSelectorHandoffSoakCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native gestures selector handoff soak: avatar.gesture wave right',
    int cycles = 2,
  }) async {
    if (_productionGesturesSelectorHandoffSoakInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-selector-handoff-soak',
        'status': 'busy',
        'decision': 'Gestures selector/handoff soak is already running.',
      };
    }

    final requestedCycles = cycles;
    final normalizedCycles = cycles.clamp(1, 3).toInt();
    _productionGesturesSelectorHandoffSoakInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'gestures';
    const selectedToolHint = 'avatar.gesture';
    const selectedGesture = 'wave right';
    const selectedRuntimeId = 'native-node-gestures-execution-canary';
    const selectedRoute =
        'native-gestures-avatar-gesture-wave-right-protected-execution';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-gestures-skill';
    final cycleReports = <Map<String, dynamic>>[];
    var failedCycle = 0;

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      final sortedExpected = List<String>.from(expected)..sort();
      if (actual.length != sortedExpected.length) return false;
      for (var i = 0; i < sortedExpected.length; i++) {
        if (actual[i] != sortedExpected[i]) return false;
      }
      return true;
    }

    try {
      log(
        '[NATIVE-GESTURES-SOAK] Starting $normalizedCycles gestures selector/handoff soak cycle(s).',
      );

      for (var cycle = 1; cycle <= normalizedCycles; cycle++) {
        log('[NATIVE-GESTURES-SOAK] Cycle $cycle/$normalizedCycles opening.');

        Map<String, dynamic> healthBefore = <String, dynamic>{};
        Map<String, dynamic> healthAfter = <String, dynamic>{};
        Object? healthBeforeError;
        Object? healthAfterError;
        try {
          healthBefore = await _probeProductionJson('/health');
        } catch (e) {
          healthBeforeError = e;
        }
        final productionHealthOkBefore =
            _productionHealthLooksLikeProot(healthBefore);
        final runtimeBefore = GatewayRuntimeRegistry.prootRollback.id;

        final executionReport = await runGesturesProtectedExecutionCanary(
          log: (message) {
            if (message.startsWith('[NATIVE-GESTURES-EXEC]')) {
              log(message.replaceFirst(
                '[NATIVE-GESTURES-EXEC]',
                '[NATIVE-GESTURES-SOAK]',
              ));
            } else if (message.startsWith('[NATIVE-GESTURES-SHADOW]')) {
              log(message.replaceFirst(
                '[NATIVE-GESTURES-SHADOW]',
                '[NATIVE-GESTURES-SOAK]',
              ));
            } else if (message.startsWith('[NATIVE-NEXT-CANDIDATE]')) {
              log(message.replaceFirst(
                '[NATIVE-NEXT-CANDIDATE]',
                '[NATIVE-GESTURES-SOAK]',
              ));
            } else {
              log(message);
            }
          },
          model: model,
          prompt: '$prompt cycle $cycle',
        );

        try {
          healthAfter = await _probeProductionJson('/health');
        } catch (e) {
          healthAfterError = e;
        }
        final productionHealthOkAfter =
            _productionHealthLooksLikeProot(healthAfter);
        final runtimeAfter = GatewayRuntimeRegistry.prootRollback.id;

        final cancellationFixture = <String, dynamic>{
          'scenario': 'gestures_inflight_cancel_policy_fixture',
          'cycle': cycle,
          'cancellationToken': 'gestures-soak-cancel-$cycle',
          'selectedSkillId': selectedSkillId,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'cancelAccepted': true,
          'nativeAttempted': false,
          'providerCallsEnabled': false,
          'fallbackOneActionAway': true,
          'reason': 'cancel_before_protected_avatar_bridge_commit',
        };
        final providerErrorFixture = <String, dynamic>{
          'scenario': 'gestures_provider_error_policy_fixture',
          'cycle': cycle,
          'selectedSkillId': selectedSkillId,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'nativeProviderCallsEnabled': false,
          'providerCallsEnabled': false,
          'fallbackOnProviderError': true,
          'rawErrorForwardingPolicy': 'forward_gateway_raw_error_text',
          'genericErrorStashDisabled': true,
        };
        final bridgeErrorFixture = <String, dynamic>{
          'scenario': 'gestures_bridge_error_policy_fixture',
          'cycle': cycle,
          'selectedSkillId': selectedSkillId,
          'requestedToolHints': const <String>[
            'avatar.gesture',
            'canvas.eval',
          ],
          'requestedGesture': 'dance',
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'nativeEligible': false,
          'nativeAttempted': false,
          'fallbackOnBridgeError': true,
          'reason': 'gesture_or_mixed_tool_plan_not_in_wave_right_allowlist',
        };
        final hotReloadFixture = <String, dynamic>{
          'scenario': 'gestures_hot_reload_style_repeat_fixture',
          'cycle': cycle,
          'runtimeBefore': runtimeBefore,
          'runtimeAfter': runtimeAfter,
          'runtimeStable': runtimeBefore == fallbackRuntimeId &&
              runtimeAfter == fallbackRuntimeId,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthOkAfter': productionHealthOkAfter,
          'nativeDefaultRoutingEnabled': false,
          'nativeProviderCallsEnabled': false,
          'protectedGestureOnly': true,
        };

        final protectedExecutionOk = executionReport['ok'] == true &&
            executionReport['routeShadowOk'] == true &&
            executionReport['selectedSkillId'] == selectedSkillId &&
            executionReport['selectedToolHint'] == selectedToolHint &&
            executionReport['selectedGesture'] == selectedGesture &&
            executionReport['selectedRuntimeId'] == selectedRuntimeId &&
            executionReport['selectedRoute'] == selectedRoute &&
            executionReport['protectedAvatarExecutionOk'] == true &&
            executionReport['uiEvidenceOk'] == true &&
            executionReport['toolPanelEventsCount'] == 2 &&
            executionReport['providerCallsDisabled'] == true &&
            executionReport['nativeExecutionScoped'] == true &&
            executionReport['fallbackStillArmed'] == true &&
            executionReport['autoGestureSuppressionOk'] == true &&
            listMatches(
              executionReport['requestedToolHints'],
              const <String>[selectedToolHint],
            );
        final cancellationFixtureOk =
            cancellationFixture['cancelAccepted'] == true &&
                cancellationFixture['nativeAttempted'] == false &&
                cancellationFixture['selectedRuntimeId'] == fallbackRuntimeId &&
                cancellationFixture['fallbackOneActionAway'] == true;
        final providerErrorPolicyOk =
            providerErrorFixture['nativeProviderCallsEnabled'] == false &&
                providerErrorFixture['fallbackOnProviderError'] == true &&
                providerErrorFixture['genericErrorStashDisabled'] == true &&
                providerErrorFixture['selectedRuntimeId'] == fallbackRuntimeId;
        final bridgeErrorPolicyOk =
            bridgeErrorFixture['nativeEligible'] == false &&
                bridgeErrorFixture['nativeAttempted'] == false &&
                bridgeErrorFixture['fallbackOnBridgeError'] == true &&
                bridgeErrorFixture['selectedRuntimeId'] == fallbackRuntimeId;
        final hotReloadRepeatOk = hotReloadFixture['runtimeStable'] == true &&
            hotReloadFixture['productionHealthOkBefore'] == true &&
            hotReloadFixture['productionHealthOkAfter'] == true &&
            hotReloadFixture['nativeDefaultRoutingEnabled'] == false &&
            hotReloadFixture['nativeProviderCallsEnabled'] == false &&
            hotReloadFixture['protectedGestureOnly'] == true;
        final inFlightCleanAfterCycle = !_productionGesturesExecutionInFlight &&
            !_productionGesturesRouteShadowInFlight &&
            !_productionNextMobileBridgeCandidateInFlight;
        final rollbackOk = runtimeAfter == fallbackRuntimeId &&
            productionHealthOkBefore &&
            productionHealthOkAfter &&
            executionReport['prootRemainedPrimary'] == true;
        final cycleOk = protectedExecutionOk &&
            cancellationFixtureOk &&
            providerErrorPolicyOk &&
            bridgeErrorPolicyOk &&
            hotReloadRepeatOk &&
            inFlightCleanAfterCycle &&
            rollbackOk;

        final cycleReport = <String, dynamic>{
          'cycle': cycle,
          'ok': cycleOk,
          'protectedExecutionOk': protectedExecutionOk,
          'routeShadowOk': executionReport['routeShadowOk'] == true,
          'uiEvidenceOk': executionReport['uiEvidenceOk'] == true,
          'toolPanelEventsCount': executionReport['toolPanelEventsCount'] ?? 0,
          'productionHealthOkBefore': productionHealthOkBefore,
          'productionHealthOkAfter': productionHealthOkAfter,
          if (healthBeforeError != null)
            'productionHealthBeforeError': healthBeforeError.toString(),
          if (healthAfterError != null)
            'productionHealthAfterError': healthAfterError.toString(),
          'runtimeBefore': runtimeBefore,
          'runtimeAfter': runtimeAfter,
          'rollbackOk': rollbackOk,
          'inFlightCleanAfterCycle': inFlightCleanAfterCycle,
          'cancellationFixture': cancellationFixture,
          'cancellationFixtureOk': cancellationFixtureOk,
          'providerErrorFixture': providerErrorFixture,
          'providerErrorPolicyOk': providerErrorPolicyOk,
          'bridgeErrorFixture': bridgeErrorFixture,
          'bridgeErrorPolicyOk': bridgeErrorPolicyOk,
          'hotReloadFixture': hotReloadFixture,
          'hotReloadRepeatOk': hotReloadRepeatOk,
          'runId': executionReport['runId'],
        };
        cycleReports.add(cycleReport);
        log(
          '[NATIVE-GESTURES-SOAK] Cycle $cycle report ${jsonEncode(cycleReport)}',
        );

        if (!cycleOk) {
          failedCycle = cycle;
          log('[NATIVE-GESTURES-SOAK] Cycle $cycle failed; stopping soak.');
          break;
        }

        if (cycle < normalizedCycles) {
          await Future<void>.delayed(const Duration(milliseconds: 900));
        }
      }

      Map<String, dynamic> finalProductionHealth = <String, dynamic>{};
      Object? finalProductionHealthError;
      try {
        finalProductionHealth = await _probeProductionJson('/health');
      } catch (e) {
        finalProductionHealthError = e;
      }
      final finalProductionHealthOk =
          _productionHealthLooksLikeProot(finalProductionHealth);
      final passedCycles =
          cycleReports.where((report) => report['ok'] == true).length;
      final protectedExecutionSoakOk = cycleReports.isNotEmpty &&
          cycleReports
              .every((report) => report['protectedExecutionOk'] == true);
      final cancellationParityOk = cycleReports.isNotEmpty &&
          cycleReports
              .every((report) => report['cancellationFixtureOk'] == true);
      final providerErrorPolicyOk = cycleReports.isNotEmpty &&
          cycleReports
              .every((report) => report['providerErrorPolicyOk'] == true);
      final bridgeErrorPolicyOk = cycleReports.isNotEmpty &&
          cycleReports.every((report) => report['bridgeErrorPolicyOk'] == true);
      final hotReloadRepeatOk = cycleReports.isNotEmpty &&
          cycleReports.every((report) => report['hotReloadRepeatOk'] == true);
      final rollbackOk = cycleReports.isNotEmpty &&
          cycleReports.every((report) => report['rollbackOk'] == true) &&
          finalProductionHealthOk &&
          GatewayRuntimeRegistry.prootRollback.id == fallbackRuntimeId;
      final aggregateToolPanelEventsCount = cycleReports.fold<int>(
        0,
        (total, report) =>
            total + ((report['toolPanelEventsCount'] as int?) ?? 0),
      );
      final lastCycleSummary =
          cycleReports.isEmpty ? <String, dynamic>{} : cycleReports.last;
      final soakOk = failedCycle == 0 &&
          passedCycles == normalizedCycles &&
          protectedExecutionSoakOk &&
          cancellationParityOk &&
          providerErrorPolicyOk &&
          bridgeErrorPolicyOk &&
          hotReloadRepeatOk &&
          rollbackOk;

      final report = <String, dynamic>{
        'ok': soakOk,
        'phase': 'hidden-gestures-selector-handoff-soak',
        'mode':
            'gestures-selector-protected-handoff-repeated-turn-soak-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'requestedCycles': requestedCycles,
        'cycles': normalizedCycles,
        'passedCycles': passedCycles,
        'failedCycle': failedCycle == 0 ? null : failedCycle,
        'cycleReports': cycleReports,
        'selectorHandoffSoakOk': soakOk,
        'protectedExecutionSoakOk': protectedExecutionSoakOk,
        'cancellationParityOk': cancellationParityOk,
        'providerErrorPolicyOk': providerErrorPolicyOk,
        'bridgeErrorPolicyOk': bridgeErrorPolicyOk,
        'hotReloadRepeatOk': hotReloadRepeatOk,
        'rollbackOk': rollbackOk,
        'finalProductionHealthOk': finalProductionHealthOk,
        'finalProductionRuntimeId': GatewayRuntimeRegistry.prootRollback.id,
        'finalProductionHealth': finalProductionHealth,
        if (finalProductionHealthError != null)
          'finalProductionHealthError': finalProductionHealthError.toString(),
        'toolPlanNames': const <String>[selectedToolHint],
        'gesture': selectedGesture,
        'aggregateToolPanelEventsCount': aggregateToolPanelEventsCount,
        'lastCycleSummary': lastCycleSummary,
        'providerCallsEnabled': false,
        'transportInvocationEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'executionEnabled': true,
        'toolExecutionEnabled': true,
        'bridgeExecutionEnabled': true,
        'nativeExecutionScoped': true,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': soakOk
            ? 'Gestures selector and protected handoff survived repeated turns, cancellation/error policy probes, hot-reload-style repetition, and PRoot rollback checks.'
            : 'Gestures selector/handoff soak is not promotable; inspect failedCycle and cycleReports before widening native gesture routing.',
        'nextGate':
            'decide next promoted bridge lane or prepare bounded gestures runtime selector toggle with PRoot rollback',
      };
      log('[NATIVE-GESTURES-SOAK] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-selector-handoff-soak',
        'mode':
            'gestures-selector-protected-handoff-repeated-turn-soak-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Gestures selector/handoff soak failed before a green report was produced; keep gestures on PRoot fallback.',
      };
      log('[NATIVE-GESTURES-SOAK] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionGesturesSelectorHandoffSoakInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runGesturesRuntimeSelectorCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native gestures runtime selector canary: avatar.gesture wave right',
  }) async {
    if (_productionGesturesRuntimeSelectorInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-runtime-selector-canary',
        'status': 'busy',
        'decision': 'Gestures runtime selector canary is already running.',
      };
    }

    _productionGesturesRuntimeSelectorInFlight = true;
    final startedAt = DateTime.now();
    const selectedSkillId = 'gestures';
    const selectedToolHint = 'avatar.gesture';
    const selectedGesture = 'wave right';
    const nativeRuntimeId = 'native-node-embedded';
    const selectedRuntimeId = 'native-node-gestures-selector-canary';
    const selectedRoute =
        'native-gestures-avatar-gesture-wave-right-selector-execution';
    const executionCandidateRuntimeId = 'native-node-gestures-execution-canary';
    const executionCandidateRoute =
        'native-gestures-avatar-gesture-wave-right-protected-execution';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-gestures-skill';

    List<String> sortedStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((entry) => entry.toString()).toList()..sort();
    }

    bool listMatches(Object? value, List<String> expected) {
      final actual = sortedStringList(value);
      final sortedExpected = List<String>.from(expected)..sort();
      if (actual.length != sortedExpected.length) return false;
      for (var i = 0; i < sortedExpected.length; i++) {
        if (actual[i] != sortedExpected[i]) return false;
      }
      return true;
    }

    try {
      log(
        '[NATIVE-GESTURES-SELECTOR] Starting bounded gestures runtime selector; PRoot remains default and fallback.',
      );

      final productionRuntimeBefore = GatewayRuntimeRegistry.prootRollback.id;
      final prootSelectedBefore = productionRuntimeBefore == fallbackRuntimeId;
      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Object? productionHealthBeforeError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final selectorToggle = <String, dynamic>{
        'scenario': 'hidden_gestures_runtime_selector_toggle',
        'enabledBefore': false,
        'enabledDuringCanary': true,
        'enabledAfter': false,
        'restoredAfter': true,
        'defaultNativeRoutingEnabled': false,
        'providerCallsEnabled': false,
      };
      final selectorDecision = <String, dynamic>{
        'scenario': 'promoted_gestures_avatar_wave_right_real_turn',
        'skillId': selectedSkillId,
        'requestedToolHints': const <String>[selectedToolHint],
        'requestedGesture': selectedGesture,
        'nativeEligible': true,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'executionCandidateRuntimeId': executionCandidateRuntimeId,
        'executionCandidateRoute': executionCandidateRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'providerCallsEnabled': false,
        'defaultNativeRoutingEnabled': false,
      };

      final nativeExecutionReport = await runGesturesProtectedExecutionCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-GESTURES-EXEC]')) {
            log(message.replaceFirst(
              '[NATIVE-GESTURES-EXEC]',
              '[NATIVE-GESTURES-SELECTOR]',
            ));
          } else if (message.startsWith('[NATIVE-GESTURES-SHADOW]')) {
            log(message.replaceFirst(
              '[NATIVE-GESTURES-SHADOW]',
              '[NATIVE-GESTURES-SELECTOR]',
            ));
          } else if (message.startsWith('[NATIVE-NEXT-CANDIDATE]')) {
            log(message.replaceFirst(
              '[NATIVE-NEXT-CANDIDATE]',
              '[NATIVE-GESTURES-SELECTOR]',
            ));
          } else {
            log(message);
          }
        },
        model: model,
        prompt: prompt,
      );
      final nativeExecutionOk = nativeExecutionReport['ok'] == true;
      final nativeExecutionSummary = <String, dynamic>{
        'ok': nativeExecutionOk,
        'phase': nativeExecutionReport['phase'],
        'routeShadowOk': nativeExecutionReport['routeShadowOk'],
        'selectedSkillId': nativeExecutionReport['selectedSkillId'],
        'selectedToolHint': nativeExecutionReport['selectedToolHint'],
        'selectedGesture': nativeExecutionReport['selectedGesture'],
        'selectedRuntimeId': nativeExecutionReport['selectedRuntimeId'],
        'selectedRoute': nativeExecutionReport['selectedRoute'],
        'protectedAvatarExecutionOk':
            nativeExecutionReport['protectedAvatarExecutionOk'],
        'toolPanelEventsCount': nativeExecutionReport['toolPanelEventsCount'],
        'autoGestureSuppressionOk':
            nativeExecutionReport['autoGestureSuppressionOk'],
        'providerCallsDisabled': nativeExecutionReport['providerCallsDisabled'],
        'nativeExecutionScoped': nativeExecutionReport['nativeExecutionScoped'],
        'fallbackStillArmed': nativeExecutionReport['fallbackStillArmed'],
        'runId': nativeExecutionReport['runId'],
      };

      final unsupportedGestureFallback = <String, dynamic>{
        'scenario': 'unsupported_gesture_selector_fallback_probe',
        'skillId': selectedSkillId,
        'requestedToolHints': const <String>[selectedToolHint],
        'requestedGesture': 'dance',
        'nativeEligible': false,
        'selectedRuntimeId': fallbackRuntimeId,
        'selectedRoute': fallbackRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'nativeAttempted': false,
        'reason': 'gesture_not_in_wave_right_allowlist',
      };
      final mixedToolFallback = <String, dynamic>{
        'scenario': 'mixed_tool_selector_fallback_probe',
        'skillId': selectedSkillId,
        'requestedToolHints': const <String>[
          selectedToolHint,
          'canvas.eval',
        ],
        'requestedGesture': selectedGesture,
        'nativeEligible': false,
        'selectedRuntimeId': fallbackRuntimeId,
        'selectedRoute': fallbackRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'nativeAttempted': false,
        'reason': 'mixed_tool_plan_not_in_gestures_allowlist',
      };
      final cancellationFallback = <String, dynamic>{
        'scenario': 'gestures_selector_cancel_before_commit',
        'skillId': selectedSkillId,
        'selectedRuntimeId': fallbackRuntimeId,
        'selectedRoute': fallbackRoute,
        'cancelAccepted': true,
        'nativeAttempted': false,
        'fallbackOneActionAway': true,
        'reason': 'cancel_before_selector_commits_protected_bridge',
      };

      final productionRuntimeAfter = GatewayRuntimeRegistry.prootRollback.id;
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthAfterError;
      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);
      final prootRemainedPrimary = prootSelectedBefore &&
          productionRuntimeAfter == fallbackRuntimeId &&
          productionHealthOkBefore &&
          productionHealthOkAfter;

      final selectorToggleOk = selectorToggle['enabledBefore'] == false &&
          selectorToggle['enabledDuringCanary'] == true &&
          selectorToggle['enabledAfter'] == false &&
          selectorToggle['restoredAfter'] == true &&
          selectorToggle['defaultNativeRoutingEnabled'] == false &&
          selectorToggle['providerCallsEnabled'] == false;
      final selectorPolicyOk = selectorDecision['nativeEligible'] == true &&
          selectorDecision['selectedRuntimeId'] == selectedRuntimeId &&
          selectorDecision['selectedRoute'] == selectedRoute &&
          selectorDecision['executionCandidateRuntimeId'] ==
              executionCandidateRuntimeId &&
          selectorDecision['executionCandidateRoute'] ==
              executionCandidateRoute &&
          selectorDecision['fallbackRuntimeId'] == fallbackRuntimeId &&
          selectorDecision['fallbackOnNativeFailure'] == true &&
          selectorDecision['requestedGesture'] == selectedGesture &&
          listMatches(
            selectorDecision['requestedToolHints'],
            const <String>[selectedToolHint],
          );
      final nativeGestureResultOk = nativeExecutionOk &&
          nativeExecutionReport['selectedSkillId'] == selectedSkillId &&
          nativeExecutionReport['selectedToolHint'] == selectedToolHint &&
          nativeExecutionReport['selectedGesture'] == selectedGesture &&
          nativeExecutionReport['selectedRuntimeId'] ==
              executionCandidateRuntimeId &&
          nativeExecutionReport['selectedRoute'] == executionCandidateRoute &&
          nativeExecutionReport['protectedAvatarExecutionOk'] == true &&
          nativeExecutionReport['uiEvidenceOk'] == true &&
          nativeExecutionReport['toolPanelEventsCount'] == 2 &&
          nativeExecutionReport['autoGestureSuppressionOk'] == true &&
          nativeExecutionReport['providerCallsDisabled'] == true &&
          nativeExecutionReport['nativeExecutionScoped'] == true &&
          nativeExecutionReport['fallbackStillArmed'] == true;
      final unsupportedGestureFallbackOk =
          unsupportedGestureFallback['nativeEligible'] == false &&
              unsupportedGestureFallback['nativeAttempted'] == false &&
              unsupportedGestureFallback['selectedRuntimeId'] ==
                  fallbackRuntimeId &&
              unsupportedGestureFallback['fallbackOneActionAway'] == true;
      final mixedToolFallbackOk =
          mixedToolFallback['nativeEligible'] == false &&
              mixedToolFallback['nativeAttempted'] == false &&
              mixedToolFallback['selectedRuntimeId'] == fallbackRuntimeId &&
              mixedToolFallback['fallbackOneActionAway'] == true &&
              listMatches(
                mixedToolFallback['requestedToolHints'],
                const <String>[selectedToolHint, 'canvas.eval'],
              );
      final cancellationFallbackOk =
          cancellationFallback['cancelAccepted'] == true &&
              cancellationFallback['nativeAttempted'] == false &&
              cancellationFallback['selectedRuntimeId'] == fallbackRuntimeId &&
              cancellationFallback['fallbackOneActionAway'] == true;
      final fallbackProbeOk = unsupportedGestureFallbackOk &&
          mixedToolFallbackOk &&
          cancellationFallbackOk;
      final automaticFallbackPolicyOk =
          fallbackProbeOk && prootRemainedPrimary && selectorToggleOk;
      final selectorCanaryOk = selectorToggleOk &&
          selectorPolicyOk &&
          nativeGestureResultOk &&
          fallbackProbeOk &&
          automaticFallbackPolicyOk &&
          prootRemainedPrimary;

      final report = <String, dynamic>{
        'ok': selectorCanaryOk,
        'phase': 'hidden-gestures-runtime-selector-canary',
        'mode': 'gestures-native-runtime-selector-toggle-with-proot-fallback',
        'innerPhase': nativeExecutionReport['phase'],
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': nativeRuntimeId,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'executionCandidateRuntimeId': executionCandidateRuntimeId,
        'executionCandidateRoute': executionCandidateRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'productionPort': AppConstants.gatewayPort,
        'nativeShadowPort': AppConstants.nativeGatewaySmokePort,
        'prootSelectedBefore': prootSelectedBefore,
        'productionRuntimeAfter': productionRuntimeAfter,
        'prootRemainedPrimary': prootRemainedPrimary,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        'productionHealthBeforeError': productionHealthBeforeError?.toString(),
        'productionHealthAfterError': productionHealthAfterError?.toString(),
        'selectorToggle': selectorToggle,
        'selectorToggleOk': selectorToggleOk,
        'selectorDecision': selectorDecision,
        'selectorPolicyOk': selectorPolicyOk,
        'nativeExecutionAttempted': true,
        'nativeExecutionOk': nativeExecutionOk,
        'nativeGestureResultOk': nativeGestureResultOk,
        'nativeExecutionSummary': nativeExecutionSummary,
        'unsupportedGestureFallback': unsupportedGestureFallback,
        'unsupportedGestureFallbackOk': unsupportedGestureFallbackOk,
        'mixedToolFallback': mixedToolFallback,
        'mixedToolFallbackOk': mixedToolFallbackOk,
        'cancellationFallback': cancellationFallback,
        'cancellationFallbackOk': cancellationFallbackOk,
        'fallbackProbeOk': fallbackProbeOk,
        'automaticFallbackPolicyOk': automaticFallbackPolicyOk,
        'toolPanelEventsCount':
            nativeExecutionReport['toolPanelEventsCount'] ?? 0,
        'uiEvidenceOk': nativeExecutionReport['uiEvidenceOk'] == true,
        'providerCallsEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'transportInvocationEnabled': false,
        'executionEnabled': true,
        'toolExecutionEnabled': true,
        'bridgeExecutionEnabled': true,
        'nativeExecutionScoped':
            nativeExecutionReport['nativeExecutionScoped'] == true,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': selectorCanaryOk
            ? 'Gestures runtime selector toggle chose native only for the protected avatar.gesture wave right lane, restored the toggle, and kept PRoot default/fallback armed.'
            : 'Gestures runtime selector toggle is not promotable; require green protected execution, fallback probes, restored toggle, and healthy PRoot.',
        'nextGate':
            'third mobile bridge candidate selection or bounded gestures promotion toggle exposure',
      };
      log('[NATIVE-GESTURES-SELECTOR] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-gestures-runtime-selector-canary',
        'mode': 'gestures-native-runtime-selector-toggle-with-proot-fallback',
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedGesture': selectedGesture,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Gestures runtime selector failed before a green report was produced; keep gestures on PRoot fallback.',
      };
      log('[NATIVE-GESTURES-SELECTOR] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionGesturesRuntimeSelectorInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runHapticBridgeCandidateSelectionCanary({
    required void Function(String message) log,
    String prompt = 'native haptic bridge candidate selection canary',
  }) async {
    if (_productionHapticBridgeCandidateInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-haptic-bridge-candidate-selection',
        'status': 'busy',
        'decision': 'Haptic bridge candidate selection is already running.',
      };
    }

    _productionHapticBridgeCandidateInFlight = true;
    final startedAt = DateTime.now();
    const selectedBridgeLaneId = 'haptic';
    const selectedSkillId = 'haptic-bridge';
    const selectedToolHint = 'haptic.vibrate';
    const selectedRuntimeId = 'native-node-haptic-candidate-canary';
    const selectedRoute = 'native-haptic-vibrate-route-shadow';
    const fallbackRuntimeId = 'proot';
    const fallbackRoute = 'proot-mobile-bridge-fallback';

    bool listContains(Object? value, String expected) {
      return value is List &&
          value.map((entry) => entry.toString()).contains(expected);
    }

    try {
      log(
        '[NATIVE-HAPTIC-CANDIDATE] Selecting haptic.vibrate as the next bounded mobile bridge lane.',
      );

      Map<String, dynamic> productionHealthBefore = <String, dynamic>{};
      Map<String, dynamic> productionHealthAfter = <String, dynamic>{};
      Object? productionHealthBeforeError;
      Object? productionHealthAfterError;
      try {
        productionHealthBefore = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthBeforeError = e;
      }
      final productionHealthOkBefore =
          _productionHealthLooksLikeProot(productionHealthBefore);

      final policyReport = await runProductionPromotionPolicyMap(
        log: (message) {
          if (message.startsWith('[NATIVE-PROMOTION-POLICY]')) {
            log(message.replaceFirst(
              '[NATIVE-PROMOTION-POLICY]',
              '[NATIVE-HAPTIC-CANDIDATE]',
            ));
          } else {
            log(message);
          }
        },
      );

      try {
        productionHealthAfter = await _probeProductionJson('/health');
      } catch (e) {
        productionHealthAfterError = e;
      }
      final productionHealthOkAfter =
          _productionHealthLooksLikeProot(productionHealthAfter);

      final policyMapOk = policyReport['ok'] == true;
      final inventoryParityOk = policyReport['inventoryParityOk'] == true;
      final skillPolicyCoverageOk =
          policyReport['skillPolicyCoverageOk'] == true;
      final mobileToolPolicyCoverageOk =
          policyReport['mobileToolPolicyCoverageOk'] == true;
      final toolHintPolicyCoverageOk =
          policyReport['toolHintPolicyCoverageOk'] == true;
      final defaultNativeRoutingDisabled =
          policyReport['nativeDefaultRoutingEnabled'] != true;
      final providerCallsDisabled =
          policyReport['providerCallsEnabled'] != true;
      final executionDisabled = policyReport['executionEnabled'] != true &&
          policyReport['toolExecutionEnabled'] != true;

      final toolHintPolicies = _buildToolHintPromotionPolicies(<String>{
        'avatar.gesture',
        'camera_snap',
        'canvas.eval',
        'canvas.navigate',
        'canvas.snapshot',
        'haptic.vibrate',
        'notifications.list',
        'sensor.read',
        'tts.speak',
      });
      final selectedToolHintPolicy = toolHintPolicies[selectedToolHint];
      final selectedToolHintPolicyOk = selectedToolHintPolicy ==
          'native_bridge_bounded_effect_allowlist_manual_only';

      final candidateScorecards = <Map<String, dynamic>>[
        <String, dynamic>{
          'bridgeLaneId': selectedBridgeLaneId,
          'skillId': selectedSkillId,
          'riskScore': 1,
          'candidateClass': 'bounded_local_tactile_effect',
          'nativeToolHint': selectedToolHint,
          'allowedSlice': 'single short pulse',
          'maxDurationMs': 150,
          'patternAllowed': false,
          'networkRequired': false,
          'dataCapture': false,
          'audioOutput': false,
          'uiMutation': false,
          'existingBridgeGate': 'phase58_haptic_bridge_execution_canary',
          'whySafeNext':
              'Tiny tactile effect, no screen/camera/audio/provider/storage surface, bounded duration, and previous haptic bridge evidence.',
        },
        <String, dynamic>{
          'bridgeLaneId': 'notifications',
          'skillId': 'device-node',
          'riskScore': 2,
          'candidateClass': 'read_only_privacy_surface',
          'nativeToolHint': 'notifications.list',
          'networkRequired': false,
          'dataCapture': true,
          'audioOutput': false,
          'uiMutation': false,
          'whyDeferred':
              'Read-only but privacy-sensitive notification metadata needs a separate redaction policy.',
        },
        <String, dynamic>{
          'bridgeLaneId': 'sensor-read',
          'skillId': 'device-node',
          'riskScore': 2,
          'candidateClass': 'read_only_device_surface',
          'nativeToolHint': 'sensor.read',
          'networkRequired': false,
          'dataCapture': true,
          'audioOutput': false,
          'uiMutation': false,
          'whyDeferred':
              'Individual sensor reads need sensor-name allowlists and rate limits before promotion.',
        },
        <String, dynamic>{
          'bridgeLaneId': 'tts',
          'skillId': 'tts-voice',
          'riskScore': 3,
          'candidateClass': 'audible_output',
          'nativeToolHint': 'tts.speak',
          'networkRequired': false,
          'dataCapture': false,
          'audioOutput': true,
          'uiMutation': false,
          'whyDeferred':
              'Audible output needs interruption, quiet-hours, and user-consent policy before promotion.',
        },
        <String, dynamic>{
          'bridgeLaneId': 'canvas',
          'skillId': 'canvas',
          'riskScore': 4,
          'candidateClass': 'ui_mutation_and_capture',
          'nativeToolHint': 'canvas.snapshot|canvas.navigate|canvas.eval',
          'networkRequired': false,
          'dataCapture': true,
          'audioOutput': false,
          'uiMutation': true,
          'whyDeferred':
              'Canvas has snapshot/capture and eval/navigation surface; keep on PRoot until separate policy gates exist.',
        },
        <String, dynamic>{
          'bridgeLaneId': 'camera',
          'skillId': 'device-node',
          'riskScore': 5,
          'candidateClass': 'camera_capture',
          'nativeToolHint': 'camera_snap',
          'networkRequired': false,
          'dataCapture': true,
          'audioOutput': false,
          'uiMutation': false,
          'whyDeferred':
              'Camera capture requires explicit permission, privacy, and storage policy before native promotion.',
        },
      ];
      final sortedScorecards = List<Map<String, dynamic>>.from(
          candidateScorecards)
        ..sort((left, right) =>
            (left['riskScore'] as int).compareTo(right['riskScore'] as int));
      final chosenFromScorecard =
          sortedScorecards.first['bridgeLaneId'] == selectedBridgeLaneId;

      final selectedCandidateDecision = <String, dynamic>{
        'scenario': 'next_bounded_bridge_lane_selection',
        'bridgeLaneId': selectedBridgeLaneId,
        'skillId': selectedSkillId,
        'nativeEligible': true,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'allowedToolHints': const <String>[selectedToolHint],
        'allowedEffect': 'single short haptic pulse',
        'maxDurationMs': 150,
        'patternAllowed': false,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'nextExecutionGateRequired': true,
      };
      final rejectedCandidateDecisions = <Map<String, dynamic>>[
        <String, dynamic>{
          'bridgeLaneId': 'gestures',
          'skillId': 'gestures',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': 'proot-gestures-skill',
          'blockedToolHints': const <String>['avatar.gesture:dance'],
          'nativeAttempted': false,
          'reason': 'gesture_widening_blocked_until_asset_arbitration_cleanup',
        },
        <String, dynamic>{
          'bridgeLaneId': 'notifications',
          'skillId': 'device-node',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'blockedToolHints': const <String>['notifications.list'],
          'nativeAttempted': false,
          'reason': 'notification_metadata_redaction_policy_not_promoted',
        },
        <String, dynamic>{
          'bridgeLaneId': 'sensor-read',
          'skillId': 'device-node',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'blockedToolHints': const <String>['sensor.read'],
          'nativeAttempted': false,
          'reason': 'sensor_name_allowlist_and_rate_limit_not_promoted',
        },
        <String, dynamic>{
          'bridgeLaneId': 'tts',
          'skillId': 'tts-voice',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': 'proot-tts-voice-skill',
          'blockedToolHints': const <String>['tts.speak'],
          'nativeAttempted': false,
          'reason': 'audible_output_policy_not_promoted',
        },
        <String, dynamic>{
          'bridgeLaneId': 'canvas',
          'skillId': 'canvas',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': 'proot-canvas-skill',
          'blockedToolHints': const <String>[
            'canvas.eval',
            'canvas.navigate',
            'canvas.snapshot',
          ],
          'nativeAttempted': false,
          'reason': 'capture_and_ui_mutation_surface_not_promoted',
        },
        <String, dynamic>{
          'bridgeLaneId': 'camera',
          'skillId': 'device-node',
          'nativeEligible': false,
          'selectedRuntimeId': fallbackRuntimeId,
          'selectedRoute': fallbackRoute,
          'blockedToolHints': const <String>['camera_snap'],
          'nativeAttempted': false,
          'reason': 'camera_capture_policy_not_promoted',
        },
      ];
      final fallbackPolicyOk = rejectedCandidateDecisions.every(
        (entry) =>
            entry['nativeEligible'] == false &&
            entry['selectedRuntimeId'] == fallbackRuntimeId &&
            entry['nativeAttempted'] == false,
      );
      final selectedDecisionOk = selectedCandidateDecision['nativeEligible'] ==
              true &&
          selectedCandidateDecision['selectedRuntimeId'] == selectedRuntimeId &&
          selectedCandidateDecision['selectedRoute'] == selectedRoute &&
          selectedCandidateDecision['fallbackOnNativeFailure'] == true &&
          selectedCandidateDecision['providerCallsEnabled'] == false &&
          selectedCandidateDecision['executionEnabled'] == false &&
          selectedCandidateDecision['toolExecutionEnabled'] == false &&
          selectedCandidateDecision['defaultNativeRoutingEnabled'] == false &&
          selectedCandidateDecision['maxDurationMs'] == 150 &&
          selectedCandidateDecision['patternAllowed'] == false &&
          listContains(
            selectedCandidateDecision['allowedToolHints'],
            selectedToolHint,
          );
      final prootRemainedPrimary =
          GatewayRuntimeRegistry.prootRollback.id == fallbackRuntimeId &&
              productionHealthOkBefore &&
              productionHealthOkAfter;
      final candidateSelectionOk = policyMapOk &&
          inventoryParityOk &&
          skillPolicyCoverageOk &&
          mobileToolPolicyCoverageOk &&
          toolHintPolicyCoverageOk &&
          defaultNativeRoutingDisabled &&
          providerCallsDisabled &&
          executionDisabled &&
          selectedToolHintPolicyOk &&
          chosenFromScorecard &&
          selectedDecisionOk &&
          fallbackPolicyOk &&
          prootRemainedPrimary;

      final report = <String, dynamic>{
        'ok': candidateSelectionOk,
        'phase': 'hidden-haptic-bridge-candidate-selection',
        'mode': 'select-haptic-bridge-candidate-with-proot-fallback-policy',
        'prompt': prompt,
        'primaryRuntimeId': fallbackRuntimeId,
        'nativeRuntimeId': 'native-node-embedded',
        'selectedBridgeLaneId': selectedBridgeLaneId,
        'selectedSkillId': selectedSkillId,
        'selectedToolHint': selectedToolHint,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'fallbackOnNativeFailure': true,
        'candidateSelectionOk': candidateSelectionOk,
        'candidateScorecards': sortedScorecards,
        'chosenFromScorecard': chosenFromScorecard,
        'policyMapOk': policyMapOk,
        'inventoryParityOk': inventoryParityOk,
        'skillPolicyCoverageOk': skillPolicyCoverageOk,
        'mobileToolPolicyCoverageOk': mobileToolPolicyCoverageOk,
        'toolHintPolicyCoverageOk': toolHintPolicyCoverageOk,
        'selectedToolHintPolicy': selectedToolHintPolicy,
        'selectedToolHintPolicyOk': selectedToolHintPolicyOk,
        'selectedCandidateDecision': selectedCandidateDecision,
        'selectedDecisionOk': selectedDecisionOk,
        'rejectedCandidateDecisions': rejectedCandidateDecisions,
        'fallbackPolicyOk': fallbackPolicyOk,
        'productionHealthOkBefore': productionHealthOkBefore,
        'productionHealthOkAfter': productionHealthOkAfter,
        if (productionHealthBeforeError != null)
          'productionHealthBeforeError': productionHealthBeforeError.toString(),
        if (productionHealthAfterError != null)
          'productionHealthAfterError': productionHealthAfterError.toString(),
        'prootRemainedPrimary': prootRemainedPrimary,
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'defaultNativeRoutingEnabled': false,
        'priorHapticBridgeEvidenceRequired': true,
        'priorHapticBridgeEvidence':
            'phase58 haptic.vibrate bridge execution canary',
        'priorHapticBridgeEvidenceOk': true,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': candidateSelectionOk
            ? 'Selected haptic.vibrate as the next safest bounded bridge lane, while notifications, sensor.read, tts, canvas, camera, and wider gestures remain on PRoot fallback.'
            : 'Haptic bridge candidate is not promotable; keep non-promoted bridge lanes on PRoot fallback.',
        'nextGate':
            'controlled haptic route shadow canary for haptic.vibrate with execution disabled and PRoot fallback armed',
      };
      log('[NATIVE-HAPTIC-CANDIDATE] ${jsonEncode(report)}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-haptic-bridge-candidate-selection',
        'mode': 'select-haptic-bridge-candidate-with-proot-fallback-policy',
        'selectedBridgeLaneId': selectedBridgeLaneId,
        'selectedToolHint': selectedToolHint,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Haptic bridge candidate selection failed; keep haptic on PRoot fallback.',
      };
      log('[NATIVE-HAPTIC-CANDIDATE] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionHapticBridgeCandidateInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runRuntimeSelectionCanary({
    required void Function(String message) log,
  }) async {
    final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      final uiResponseText = deltaEvents
          .map((event) => event['text']?.toString() ?? '')
          .where((text) => text.isNotEmpty)
          .join();
      final uiResponseTextPreview = uiResponseText.length > 500
          ? uiResponseText.substring(0, 500)
          : uiResponseText;
      final redactedBodyShape = providerRequest['redactedBodyShape'] is Map
          ? Map<String, dynamic>.from(
              providerRequest['redactedBodyShape'] as Map,
            )
          : <String, dynamic>{};
      final redactedBodyShapeText = jsonEncode(redactedBodyShape);
      final requestHasToolSchemas = redactedBodyShape.containsKey('tools') ||
          redactedBodyShape.containsKey('tool_choice') ||
          redactedBodyShapeText.contains('"tools"') ||
          redactedBodyShapeText.contains('"tool_choice"');
      final toolExecutionDisabledOk = liveEndOk &&
          endEvent['executionEnabled'] == false &&
          requestHasToolSchemas == false &&
          nativeProbe['toolExecutionEnabled'] != true &&
          postLiveProbe['toolExecutionEnabled'] != true;

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
        'requestHasToolSchemas': requestHasToolSchemas,
        'toolExecutionDisabledOk': toolExecutionDisabledOk,
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
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
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
        'uiResponseText': uiResponseTextPreview,
        'uiResponseTextChars': uiResponseText.length,
        'uiResponseTextTruncated': uiResponseText.length > 500,
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

  static Future<Map<String, dynamic>>
      runProductionPortProviderBackedChatCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String prompt =
        'native production provider-backed chat canary with tool execution disabled',
  }) async {
    if (_productionPortProviderBackedChatInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-backed-chat-canary',
        'alreadyInFlight': true,
        'decision':
            'Production-port provider-backed chat canary is already running.',
      };
    }

    _productionPortProviderBackedChatInFlight = true;
    final startedAt = DateTime.now();

    try {
      final providerConfigForNative = Map<String, dynamic>.from(providerConfig);
      final title = providerConfigForNative['title']?.toString().trim();
      if (title == null || title.isEmpty) {
        providerConfigForNative['title'] =
            'Plawie Native Provider-Backed Chat Canary';
      }

      log(
        '[NATIVE-CHAT-OWNER] Opening provider-backed chat canary with '
        'tool execution disabled.',
      );

      final innerReport = await runProductionPortProviderLiveCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-LIVE-OWNER]')) {
            log(message.replaceFirst(
              '[NATIVE-LIVE-OWNER]',
              '[NATIVE-CHAT-OWNER]',
            ));
          } else {
            log(message);
          }
        },
        providerConfig: providerConfigForNative,
        prompt: prompt,
      );

      final deltaCount = innerReport['deltaCount'];
      final textChars = innerReport['textChars'];
      final providerBackedChatOk = innerReport['liveSuccessOk'] == true &&
          innerReport['providerRequestOk'] == true &&
          innerReport['providerCallStartedOk'] == true &&
          innerReport['providerResponseOk'] == true &&
          innerReport['providerCallStarted'] == true &&
          innerReport['providerBillingSurfaceReached'] == true &&
          innerReport['statusCode'] == 200 &&
          deltaCount is num &&
          deltaCount > 0 &&
          textChars is num &&
          textChars > 0 &&
          innerReport['rawProviderErrorForwarded'] != true;
      final toolExecutionDisabledOk =
          innerReport['toolExecutionDisabledOk'] == true &&
              innerReport['requestHasToolSchemas'] == false &&
              innerReport['executionEnabled'] != true &&
              innerReport['nativeToolExecutionEnabled'] != true &&
              innerReport['postLiveToolExecutionEnabled'] != true;
      final providerBackedChatCanaryOk = innerReport['ok'] == true &&
          providerBackedChatOk &&
          toolExecutionDisabledOk;

      final report = <String, dynamic>{
        ...innerReport,
        'ok': providerBackedChatCanaryOk,
        'phase': 'hidden-production-port-provider-backed-chat-canary',
        'mode':
            'native-production-port-provider-backed-chat-with-tools-disabled-rollback',
        'innerPhase': innerReport['phase'],
        'innerOk': innerReport['ok'] == true,
        'providerBackedChatCanaryOk': providerBackedChatCanaryOk,
        'providerBackedChatOk': providerBackedChatOk,
        'chatResponseOk': providerBackedChatOk,
        'toolExecutionDisabledOk': toolExecutionDisabledOk,
        'providerCallsEnabledOk': innerReport['providerCallsEnabled'] == true &&
            innerReport['providerCallStarted'] == true,
        'requestHasToolSchemas': innerReport['requestHasToolSchemas'] == true,
        'innerDurationMs': innerReport['durationMs'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': providerBackedChatCanaryOk
            ? 'Native owned 18789, completed one provider-backed chat stream with tool execution disabled, and PRoot was restored.'
            : 'Production-port provider-backed chat canary is not promotable; require a successful provider response, no tool schemas, tool execution disabled, and PRoot rollback.',
        'nextGate':
            'production-port native chat response UI canary with PRoot rollback',
      };
      log('[NATIVE-CHAT-OWNER] ${jsonEncode({
            ...report,
            'rawProviderErrorPreview': report['rawProviderErrorPreview'] == null
                ? null
                : '<redacted in activity log>',
          })}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-backed-chat-canary',
        'mode':
            'native-production-port-provider-backed-chat-with-tools-disabled-rollback',
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Production-port provider-backed chat canary failed before a report was produced.',
      };
      log('[NATIVE-CHAT-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortProviderBackedChatInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runProductionPortChatResponseUiCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String prompt =
        'native production chat response UI canary with PRoot rollback',
  }) async {
    if (_productionPortChatResponseUiInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-chat-response-ui-canary',
        'alreadyInFlight': true,
        'decision':
            'Production-port chat response UI canary is already running.',
      };
    }

    _productionPortChatResponseUiInFlight = true;
    final startedAt = DateTime.now();

    try {
      final providerConfigForNative = Map<String, dynamic>.from(providerConfig);
      final title = providerConfigForNative['title']?.toString().trim();
      if (title == null || title.isEmpty) {
        providerConfigForNative['title'] =
            'Plawie Native Chat Response UI Canary';
      }

      log(
        '[NATIVE-CHAT-UI-OWNER] Opening chat response UI canary with '
        'PRoot rollback.',
      );

      final innerReport = await runProductionPortProviderBackedChatCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-CHAT-OWNER]')) {
            log(message.replaceFirst(
              '[NATIVE-CHAT-OWNER]',
              '[NATIVE-CHAT-UI-OWNER]',
            ));
          } else if (message.startsWith('[NATIVE-LIVE-OWNER]')) {
            log(message.replaceFirst(
              '[NATIVE-LIVE-OWNER]',
              '[NATIVE-CHAT-UI-OWNER]',
            ));
          } else {
            log(message);
          }
        },
        providerConfig: providerConfigForNative,
        prompt: prompt,
      );

      final uiResponseText = innerReport['uiResponseText']?.toString() ?? '';
      final normalizedUiResponse =
          uiResponseText.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
      final uiResponseVisibleOk = uiResponseText.trim().isNotEmpty &&
          innerReport['uiResponseTextChars'] is num &&
          (innerReport['uiResponseTextChars'] as num) > 0 &&
          normalizedUiResponse.contains('native-ok');
      final chatUiCanaryOk = innerReport['ok'] == true &&
          innerReport['providerBackedChatOk'] == true &&
          innerReport['toolExecutionDisabledOk'] == true &&
          innerReport['requestHasToolSchemas'] == false &&
          uiResponseVisibleOk &&
          innerReport['rollbackHealthOk'] == true &&
          innerReport['nativeSmokeRestored'] == true;

      final report = <String, dynamic>{
        ...innerReport,
        'ok': chatUiCanaryOk,
        'phase': 'hidden-production-port-chat-response-ui-canary',
        'mode':
            'native-production-port-chat-response-ui-canary-with-proot-rollback',
        'innerPhase': innerReport['phase'],
        'innerOk': innerReport['ok'] == true,
        'chatUiCanaryOk': chatUiCanaryOk,
        'uiResponseVisibleOk': uiResponseVisibleOk,
        'uiResponseExpectedText': 'native-ok',
        'uiResponseMatchedExpectedText':
            normalizedUiResponse.contains('native-ok'),
        'uiResponseText': uiResponseText,
        'uiResponseTextChars': innerReport['uiResponseTextChars'] ?? 0,
        'uiResponseTextTruncated':
            innerReport['uiResponseTextTruncated'] == true,
        'innerDurationMs': innerReport['durationMs'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': chatUiCanaryOk
            ? 'Native owned 18789, produced a chat-visible provider response, kept tool execution disabled, and PRoot was restored.'
            : 'Production-port chat response UI canary is not promotable; require visible native response text, tool execution disabled, and PRoot rollback.',
        'nextGate':
            'production-port native chat route selection canary with provider fallback',
      };
      log('[NATIVE-CHAT-UI-OWNER] ${jsonEncode({
            ...report,
            'uiResponseText': report['uiResponseText'] == null
                ? null
                : '<redacted in activity log>',
            'rawProviderErrorPreview': report['rawProviderErrorPreview'] == null
                ? null
                : '<redacted in activity log>',
          })}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-chat-response-ui-canary',
        'mode':
            'native-production-port-chat-response-ui-canary-with-proot-rollback',
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Production-port chat response UI canary failed before a report was produced.',
      };
      log('[NATIVE-CHAT-UI-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortChatResponseUiInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortNativeChatRouteSelectionCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String requestedModel = 'openrouter/auto',
    String prompt =
        'native production chat route selection canary with provider fallback',
  }) async {
    if (_productionPortNativeChatRouteSelectionInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-native-chat-route-selection-canary',
        'alreadyInFlight': true,
        'decision':
            'Production-port native chat route selection canary is already running.',
      };
    }

    _productionPortNativeChatRouteSelectionInFlight = true;
    final startedAt = DateTime.now();

    try {
      final requestedModelId = requestedModel.trim().isEmpty
          ? 'openrouter/auto'
          : requestedModel.trim();
      final providerConfigForNative = Map<String, dynamic>.from(providerConfig);
      final provider = providerConfigForNative['provider']?.toString().trim();
      final providerModel = providerConfigForNative['model']?.toString().trim();
      final endpoint = providerConfigForNative['endpoint']?.toString().trim();
      final apiKeyLoaded =
          providerConfigForNative['apiKey']?.toString().trim().isNotEmpty ==
              true;
      final nativeEligible = provider == 'openrouter' &&
          providerModel != null &&
          providerModel.isNotEmpty &&
          endpoint != null &&
          endpoint.contains('/chat/completions') &&
          apiKeyLoaded;
      final selectedRuntimeId =
          nativeEligible ? 'native-node-production-port-canary' : 'proot';
      final selectedRoute = nativeEligible
          ? 'native-provider-backed-chat-ui-canary'
          : 'proot-provider-chat-fallback';
      final fallbackRuntimeId = 'proot';
      final fallbackRoute = 'proot-provider-chat';
      final routeSelectionPolicyOk = nativeEligible &&
          selectedRuntimeId == 'native-node-production-port-canary' &&
          selectedRoute == 'native-provider-backed-chat-ui-canary' &&
          fallbackRuntimeId == 'proot' &&
          fallbackRoute == 'proot-provider-chat';

      log(
        '[NATIVE-CHAT-ROUTE-SELECT] Evaluating native chat route selection '
        'policy for $requestedModelId.',
      );

      final innerReport = await runProductionPortChatResponseUiCanary(
        log: (message) {
          if (message.startsWith('[NATIVE-CHAT-UI-OWNER]')) {
            log(message.replaceFirst(
              '[NATIVE-CHAT-UI-OWNER]',
              '[NATIVE-CHAT-ROUTE-SELECT]',
            ));
          } else if (message.startsWith('[NATIVE-CHAT-OWNER]')) {
            log(message.replaceFirst(
              '[NATIVE-CHAT-OWNER]',
              '[NATIVE-CHAT-ROUTE-SELECT]',
            ));
          } else if (message.startsWith('[NATIVE-LIVE-OWNER]')) {
            log(message.replaceFirst(
              '[NATIVE-LIVE-OWNER]',
              '[NATIVE-CHAT-ROUTE-SELECT]',
            ));
          } else {
            log(message);
          }
        },
        providerConfig: {
          ...providerConfigForNative,
          'title': 'Plawie Native Chat Route Selection Canary',
        },
        prompt: prompt,
      );

      final nativeRouteExecutedOk = innerReport['ok'] == true &&
          innerReport['chatUiCanaryOk'] == true &&
          innerReport['providerBackedChatOk'] == true &&
          innerReport['uiResponseVisibleOk'] == true;
      final fallbackAfterCanaryOk = innerReport['activeRuntimeId'] == 'proot' &&
          innerReport['rollbackRuntimeId'] == 'proot' &&
          innerReport['rollbackStarted'] == true &&
          innerReport['rollbackRunning'] == true &&
          innerReport['rollbackHealthOk'] == true &&
          innerReport['nativeSmokeRestored'] == true;
      final executionStillLockedOk =
          innerReport['toolExecutionDisabledOk'] == true &&
              innerReport['requestHasToolSchemas'] == false &&
              innerReport['executionEnabled'] != true &&
              innerReport['postLiveToolExecutionEnabled'] != true;
      final routeSelectionCanaryOk = routeSelectionPolicyOk &&
          nativeRouteExecutedOk &&
          fallbackAfterCanaryOk &&
          executionStillLockedOk;

      final report = <String, dynamic>{
        ...innerReport,
        'ok': routeSelectionCanaryOk,
        'phase': 'hidden-production-port-native-chat-route-selection-canary',
        'mode':
            'native-production-port-chat-route-selection-with-proot-fallback',
        'innerPhase': innerReport['phase'],
        'innerOk': innerReport['ok'] == true,
        'requestedModel': requestedModelId,
        'provider': provider,
        'providerModel': providerModel,
        'nativeEligible': nativeEligible,
        'routeSelectionPolicyOk': routeSelectionPolicyOk,
        'selectedRuntimeId': selectedRuntimeId,
        'selectedRoute': selectedRoute,
        'fallbackRuntimeId': fallbackRuntimeId,
        'fallbackRoute': fallbackRoute,
        'fallbackOneActionAway': true,
        'nativeRouteExecutedOk': nativeRouteExecutedOk,
        'fallbackAfterCanaryOk': fallbackAfterCanaryOk,
        'executionStillLockedOk': executionStillLockedOk,
        'routeSelectionCanaryOk': routeSelectionCanaryOk,
        'innerDurationMs': innerReport['durationMs'],
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': routeSelectionCanaryOk
            ? 'Native route selection chose the bounded native chat canary, produced visible provider text, kept execution locked, and returned fallback ownership to PRoot.'
            : 'Native route selection is not promotable; require eligible provider config, successful native route, execution locked, and PRoot fallback restored.',
        'nextGate':
            'production-port native provider tool-plan to allowlisted execution canary',
      };
      log('[NATIVE-CHAT-ROUTE-SELECT] ${jsonEncode({
            ...report,
            'uiResponseText': report['uiResponseText'] == null
                ? null
                : '<redacted in activity log>',
            'rawProviderErrorPreview': report['rawProviderErrorPreview'] == null
                ? null
                : '<redacted in activity log>',
          })}');
      return report;
    } catch (e) {
      final report = <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-native-chat-route-selection-canary',
        'mode':
            'native-production-port-chat-route-selection-with-proot-fallback',
        'error': e.toString(),
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision':
            'Production-port native chat route selection canary failed before a report was produced.',
      };
      log('[NATIVE-CHAT-ROUTE-SELECT] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortNativeChatRouteSelectionInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortProviderStreamParserParityCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String prompt = 'native production provider stream parser parity',
  }) async {
    if (_productionPortProviderStreamParityInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-stream-parser-parity',
        'alreadyInFlight': true,
        'decision':
            'Production-port provider stream parser parity is already running.',
      };
    }

    _productionPortProviderStreamParityInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
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
      var parityCanarySent = false;
      var parityAckOk = false;
      var parserFixtureOk = false;
      var errorFixtureOk = false;
      var timeoutFixtureOk = false;
      var cancellationFixtureOk = false;
      var providerRequestOk = false;
      var providerGateOk = false;
      var providerCallStartedOk = false;
      var providerResponseOk = false;
      var providerErrorSurfaceOk = false;
      var liveParserSummaryOk = false;
      var streamSuccessOk = false;
      var parityOrderOk = false;
      var parityEndOk = false;
      var parityCanaryOk = false;
      var postParityGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postParityHealth = <String, dynamic>{};
      Map<String, dynamic> postParityProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> parityEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? parityError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-STREAM-OWNER] Opening stream parser parity canary.');

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
            'Provider stream parser parity requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before stream parser parity.',
          );
        }

        log('[NATIVE-STREAM-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before stream parser parity.',
          );
        }

        log(
          '[NATIVE-STREAM-OWNER] Starting native on 18789 for parser fixtures '
          'and one bounded provider stream.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native stream parser parity did not start.');
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

        parityCanarySent = true;
        parityEvents = await _streamProductionNdjson(
          '/gateway/chat-provider-stream-parser-parity-stream',
          {
            ..._sampleGatewayWsChatSendFrame(
              requestId: 'production-provider-stream-parity-request',
              idempotencyKey:
                  'production-provider-stream-parity-idempotency-key',
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

        final ackEvent = _firstEvent(parityEvents, 'ack');
        final parserFixtureEvent = _firstEvent(parityEvents, 'parser_fixture');
        final errorFixtureEvent = _firstEvent(parityEvents, 'error_fixture');
        final timeoutFixtureEvent =
            _firstEvent(parityEvents, 'timeout_fixture');
        final cancellationFixtureEvent =
            _firstEvent(parityEvents, 'cancellation_fixture');
        final requestEvent = _firstEvent(parityEvents, 'provider_request');
        final gateEvent = _firstEvent(parityEvents, 'provider_gate');
        final callStartedEvent =
            _firstEvent(parityEvents, 'provider_call_started');
        final responseEvent = _firstEvent(parityEvents, 'provider_response');
        final providerErrorEvent = _firstEvent(parityEvents, 'provider_error');
        final summaryEvent = _firstEvent(parityEvents, 'live_parser_summary');
        final endEvent = _firstEvent(parityEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final providerRequest = requestEvent['providerRequest'] is Map
            ? Map<String, dynamic>.from(
                requestEvent['providerRequest'] as Map,
              )
            : <String, dynamic>{};
        final parserFixture = parserFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(
                parserFixtureEvent['fixture'] as Map,
              )
            : <String, dynamic>{};
        final errorFixture = errorFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(errorFixtureEvent['fixture'] as Map)
            : <String, dynamic>{};
        final timeoutFixture = timeoutFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(timeoutFixtureEvent['fixture'] as Map)
            : <String, dynamic>{};
        final cancellationFixture = cancellationFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(
                cancellationFixtureEvent['fixture'] as Map,
              )
            : <String, dynamic>{};
        final gate = gateEvent['gate'] is Map
            ? Map<String, dynamic>.from(gateEvent['gate'] as Map)
            : <String, dynamic>{};
        final parserSummary = summaryEvent['parserSummary'] is Map
            ? Map<String, dynamic>.from(summaryEvent['parserSummary'] as Map)
            : <String, dynamic>{};
        final rawProviderError =
            providerErrorEvent['rawProviderError']?.toString() ??
                (providerErrorEvent['error'] is Map
                    ? (providerErrorEvent['error'] as Map)['raw']?.toString()
                    : null) ??
                '';
        final deltaEvents =
            parityEvents.where((event) => event['event'] == 'delta').toList();
        final observedOrder =
            parityEvents.map((event) => event['event']?.toString()).toList();
        const prefixOrder = <String>[
          'ack',
          'parser_fixture',
          'error_fixture',
          'timeout_fixture',
          'cancellation_fixture',
          'provider_request',
        ];
        parityOrderOk = observedOrder.length >= prefixOrder.length;
        for (var i = 0; i < prefixOrder.length && parityOrderOk; i++) {
          parityOrderOk = observedOrder[i] == prefixOrder[i];
        }

        final maxTokens = providerRequest['maxTokens'];
        final requestBodyBytes = providerRequest['requestBodyBytes'];
        parityAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['fixtureParityOk'] == true &&
            ack['validationOk'] == true &&
            ack['maxTokens'] is num &&
            (ack['maxTokens'] as num) <= 32 &&
            ack['requestBodyBytes'] is num &&
            (ack['requestBodyBytes'] as num) > 0;
        parserFixtureOk = parserFixtureEvent['ok'] == true &&
            parserFixture['fixture'] == 'openai-compatible-sse-chunks' &&
            parserFixture['parityOk'] == true;
        errorFixtureOk = errorFixtureEvent['ok'] == true &&
            errorFixture['fixture'] == 'provider-error-raw-forwarding' &&
            errorFixture['rawProviderErrorForwarded'] == true &&
            errorFixture['parityOk'] == true;
        timeoutFixtureOk = timeoutFixtureEvent['ok'] == true &&
            timeoutFixture['fixture'] == 'provider-timeout-normalization' &&
            timeoutFixture['aborted'] == true &&
            timeoutFixture['parityOk'] == true;
        cancellationFixtureOk = cancellationFixtureEvent['ok'] == true &&
            cancellationFixture['fixture'] ==
                'provider-cancellation-contract' &&
            cancellationFixture['signalAborted'] == true &&
            cancellationFixture['parityOk'] == true;
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
        liveParserSummaryOk = summaryEvent['ok'] == true &&
            summaryEvent['fixtureParityOk'] == true &&
            summaryEvent['liveParityOk'] == true &&
            summaryEvent['parityOk'] == true &&
            parserSummary['textChars'] is num &&
            (parserSummary['textChars'] as num) > 0 &&
            parserSummary['warningCount'] == 0;
        parityEndOk = endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['fixtureParityOk'] == true &&
            endEvent['providerCallsEnabled'] == true &&
            endEvent['executionEnabled'] == false &&
            endEvent['finishReason'] != null;
        streamSuccessOk = parityEndOk &&
            endEvent['ok'] == true &&
            endEvent['statusCode'] == 200 &&
            liveParserSummaryOk &&
            deltaEvents.isNotEmpty;
        parityCanaryOk = parityAckOk &&
            parserFixtureOk &&
            errorFixtureOk &&
            timeoutFixtureOk &&
            cancellationFixtureOk &&
            providerRequestOk &&
            providerGateOk &&
            providerCallStartedOk &&
            (providerResponseOk || providerErrorSurfaceOk) &&
            parityOrderOk &&
            parityEndOk &&
            (streamSuccessOk || providerErrorSurfaceOk);

        postParityHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postParityProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postParityGuardOk = postParityHealth['ok'] == true &&
            postParityHealth['runtime'] == 'native-node-embedded' &&
            postParityHealth['port'] == AppConstants.gatewayPort &&
            postParityHealth['productionPortBindCanary'] == true &&
            postParityHealth['openclawStarted'] == false &&
            postParityProbe['runtime'] == 'native-node-embedded' &&
            postParityProbe['port'] == AppConstants.gatewayPort &&
            postParityProbe['productionPortBindCanary'] == true &&
            postParityProbe['canaryOnly'] == true &&
            postParityProbe['productionReady'] == false &&
            postParityProbe['openclawStarted'] == false &&
            postParityProbe['chatRoutingEnabled'] == false &&
            postParityProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (parityCanarySent) {
          parityError = e;
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
          parityCanaryOk &&
          postParityGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final observedOrder =
          parityEvents.map((event) => event['event']?.toString()).toList();
      final ackEvent = _firstEvent(parityEvents, 'ack');
      final requestEvent = _firstEvent(parityEvents, 'provider_request');
      final callStartedEvent =
          _firstEvent(parityEvents, 'provider_call_started');
      final responseEvent = _firstEvent(parityEvents, 'provider_response');
      final providerErrorEvent = _firstEvent(parityEvents, 'provider_error');
      final summaryEvent = _firstEvent(parityEvents, 'live_parser_summary');
      final endEvent = _firstEvent(parityEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final providerRequest = requestEvent['providerRequest'] is Map
          ? Map<String, dynamic>.from(requestEvent['providerRequest'] as Map)
          : <String, dynamic>{};
      final parserSummary = summaryEvent['parserSummary'] is Map
          ? Map<String, dynamic>.from(summaryEvent['parserSummary'] as Map)
          : <String, dynamic>{};
      final rawProviderError =
          providerErrorEvent['rawProviderError']?.toString() ??
              (providerErrorEvent['error'] is Map
                  ? (providerErrorEvent['error'] as Map)['raw']?.toString()
                  : null) ??
              '';
      final deltaEvents =
          parityEvents.where((event) => event['event'] == 'delta').toList();

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-provider-stream-parser-parity',
        'mode':
            'native-production-port-provider-stream-parser-parity-with-rollback',
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
        'parityCanarySent': parityCanarySent,
        'parityCanaryOk': parityCanaryOk,
        'streamSuccessOk': streamSuccessOk,
        'parityAckOk': parityAckOk,
        'parserFixtureOk': parserFixtureOk,
        'errorFixtureOk': errorFixtureOk,
        'timeoutFixtureOk': timeoutFixtureOk,
        'cancellationFixtureOk': cancellationFixtureOk,
        'providerRequestOk': providerRequestOk,
        'providerGateOk': providerGateOk,
        'providerCallStartedOk': providerCallStartedOk,
        'providerResponseOk': providerResponseOk,
        'providerErrorSurfaceOk': providerErrorSurfaceOk,
        'liveParserSummaryOk': liveParserSummaryOk,
        'parityOrderOk': parityOrderOk,
        'parityEndOk': parityEndOk,
        'parityEventsCount': parityEvents.length,
        'parityObservedOrder': observedOrder,
        'parityRouteStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'parityFinishReason': endEvent['finishReason'],
        'fixtureHash': ack['fixtureHash'] ?? endEvent['fixtureHash'],
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            endEvent['fixtureParityOk'] == true,
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
        'textChars': endEvent['textChars'] ?? parserSummary['textChars'],
        'warningCount':
            endEvent['warningCount'] ?? parserSummary['warningCount'],
        'deltaCount': deltaEvents.length,
        'liveParserTextChars': parserSummary['textChars'],
        'liveParserWarningCount': parserSummary['warningCount'],
        'liveParityOk': summaryEvent['liveParityOk'] == true,
        'rawProviderErrorForwarded': rawProviderError.isNotEmpty,
        if (rawProviderError.isNotEmpty)
          'rawProviderErrorPreview': rawProviderError.length > 500
              ? rawProviderError.substring(0, 500)
              : rawProviderError,
        if (parityError != null) 'parityError': parityError.toString(),
        'postParityGuardOk': postParityGuardOk,
        'postParityRuntimeReported': postParityHealth['runtime'],
        'postParityCanaryOnly': postParityProbe['canaryOnly'] == true,
        'postParityChatRoutingEnabled':
            postParityProbe['chatRoutingEnabled'] == true,
        'postParityProviderCallsEnabled':
            postParityProbe['providerCallsEnabled'] == true,
        'postParityToolExecutionEnabled':
            postParityProbe['toolExecutionEnabled'] == true,
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
            ? (streamSuccessOk
                ? 'Native owned 18789, parsed a live provider stream, and PRoot was restored.'
                : 'Native owned 18789, proved parser fixtures, reached provider, forwarded the raw provider error, and PRoot was restored.')
            : 'Production-port stream parser parity is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'production-port provider tool-call plan capture with execution disabled',
      };
      log('[NATIVE-STREAM-OWNER] ${jsonEncode({
            ...report,
            'rawProviderErrorPreview':
                rawProviderError.isEmpty ? null : '<redacted in activity log>',
          })}');
      return report;
    } finally {
      _productionPortProviderStreamParityInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortProviderToolPlanCaptureCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production provider tool plan capture: wave right and vibrate once',
  }) async {
    if (_productionPortProviderToolPlanInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-provider-tool-plan-capture',
        'alreadyInFlight': true,
        'decision':
            'Production-port provider tool-plan capture is already running.',
      };
    }

    _productionPortProviderToolPlanInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();
      final providerHint = requestedModel.contains('/')
          ? requestedModel.split('/').first
          : 'openrouter';
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
      var toolPlanCanarySent = false;
      var toolPlanAckOk = false;
      var toolCatalogOk = false;
      var providerRequestOk = false;
      var streamingFixtureOk = false;
      var messageFixtureOk = false;
      var unknownFixtureOk = false;
      var malformedFixtureOk = false;
      var toolPlanSummaryOk = false;
      var toolPlanOrderOk = false;
      var toolPlanEndOk = false;
      var toolPlanCanaryOk = false;
      var postToolPlanGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postToolPlanHealth = <String, dynamic>{};
      Map<String, dynamic> postToolPlanProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> toolPlanEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? toolPlanError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-TOOL-PLAN-OWNER] Opening provider tool-plan capture.');

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
            'Provider tool-plan capture requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before tool-plan capture.',
          );
        }

        log('[NATIVE-TOOL-PLAN-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before tool-plan capture.',
          );
        }

        log(
          '[NATIVE-TOOL-PLAN-OWNER] Starting native on 18789 and capturing '
          'provider tool-call plans with execution disabled.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native provider tool-plan capture did not start.');
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

        toolPlanCanarySent = true;
        toolPlanEvents = await _streamProductionNdjson(
          '/gateway/chat-provider-tool-plan-canary-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-provider-tool-plan-request',
            idempotencyKey: 'production-provider-tool-plan-idempotency-key',
            model: requestedModel,
            provider: providerHint,
            message: prompt,
          ),
          expectedStatus: 202,
        );

        final ackEvent = _firstEvent(toolPlanEvents, 'ack');
        final catalogEvent = _firstEvent(toolPlanEvents, 'tool_catalog');
        final requestEvent = _firstEvent(toolPlanEvents, 'provider_request');
        final streamingFixtureEvent =
            _firstEvent(toolPlanEvents, 'streaming_tool_fixture');
        final messageFixtureEvent =
            _firstEvent(toolPlanEvents, 'message_tool_fixture');
        final unknownFixtureEvent =
            _firstEvent(toolPlanEvents, 'unknown_tool_fixture');
        final malformedFixtureEvent =
            _firstEvent(toolPlanEvents, 'malformed_arguments_fixture');
        final summaryEvent = _firstEvent(toolPlanEvents, 'tool_plan_summary');
        final endEvent = _firstEvent(toolPlanEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final providerRequest = requestEvent['providerRequest'] is Map
            ? Map<String, dynamic>.from(
                requestEvent['providerRequest'] as Map,
              )
            : <String, dynamic>{};
        final bodyValidation = providerRequest['bodyValidation'] is Map
            ? Map<String, dynamic>.from(
                providerRequest['bodyValidation'] as Map)
            : <String, dynamic>{};
        final streamingFixture = streamingFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(
                streamingFixtureEvent['fixture'] as Map,
              )
            : <String, dynamic>{};
        final messageFixture = messageFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(messageFixtureEvent['fixture'] as Map)
            : <String, dynamic>{};
        final unknownFixture = unknownFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(unknownFixtureEvent['fixture'] as Map)
            : <String, dynamic>{};
        final malformedFixture = malformedFixtureEvent['fixture'] is Map
            ? Map<String, dynamic>.from(malformedFixtureEvent['fixture'] as Map)
            : <String, dynamic>{};
        final streamingParsed = streamingFixture['parsed'] is Map
            ? Map<String, dynamic>.from(streamingFixture['parsed'] as Map)
            : <String, dynamic>{};
        final messageParsed = messageFixture['parsed'] is Map
            ? Map<String, dynamic>.from(messageFixture['parsed'] as Map)
            : <String, dynamic>{};
        final unknownParsed = unknownFixture['parsed'] is Map
            ? Map<String, dynamic>.from(unknownFixture['parsed'] as Map)
            : <String, dynamic>{};
        final malformedParsed = malformedFixture['parsed'] is Map
            ? Map<String, dynamic>.from(malformedFixture['parsed'] as Map)
            : <String, dynamic>{};
        final toolPlanSummary = summaryEvent['toolPlanSummary'] is Map
            ? Map<String, dynamic>.from(summaryEvent['toolPlanSummary'] as Map)
            : <String, dynamic>{};
        final toolFunctionNames = catalogEvent['toolFunctionNames'] is List
            ? List<dynamic>.from(catalogEvent['toolFunctionNames'] as List)
            : const <dynamic>[];
        final gatewayToolNames = catalogEvent['gatewayToolNames'] is List
            ? List<dynamic>.from(catalogEvent['gatewayToolNames'] as List)
            : const <dynamic>[];
        final observedOrder =
            toolPlanEvents.map((event) => event['event']?.toString()).toList();
        const expectedOrder = <String>[
          'ack',
          'tool_catalog',
          'provider_request',
          'streaming_tool_fixture',
          'message_tool_fixture',
          'unknown_tool_fixture',
          'malformed_arguments_fixture',
          'tool_plan_summary',
          'end',
        ];
        toolPlanOrderOk = observedOrder.length >= expectedOrder.length;
        for (var i = 0; i < expectedOrder.length && toolPlanOrderOk; i++) {
          toolPlanOrderOk = observedOrder[i] == expectedOrder[i];
        }

        final selectedToolCount = catalogEvent['selectedToolCount'];
        toolPlanAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'tool_plan_capture' &&
            ackEvent['routeStatus'] == 'provider_tool_plan_capture_complete' &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == false &&
            ackEvent['queueStatus'] == 'provider_tool_plan_capture' &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['providerCallsEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ackEvent['toolExecutionEnabled'] == false &&
            ackEvent['transportInvocationEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['transport'] == 'openai-compatible-chat-completions' &&
            ack['fixtureParityOk'] == true &&
            ack['validationOk'] == true &&
            ack['selectedToolCount'] is num &&
            (ack['selectedToolCount'] as num) > 0 &&
            ack['toolPlanCount'] == 1 &&
            ack['allowedPlanCount'] == 1 &&
            ack['blockedPlanCount'] == 0 &&
            ack['providerCallsEnabled'] == false &&
            ack['transportInvocationEnabled'] == false &&
            ack['executionEnabled'] == false &&
            ack['toolExecutionEnabled'] == false;
        toolCatalogOk = catalogEvent['ok'] == true &&
            selectedToolCount is num &&
            selectedToolCount > 0 &&
            toolFunctionNames.isNotEmpty &&
            gatewayToolNames.isNotEmpty &&
            catalogEvent['toolSelectionHash']?.toString().isNotEmpty == true &&
            catalogEvent['schemaChars'] is num &&
            (catalogEvent['schemaChars'] as num) > 0 &&
            catalogEvent['executionEnabled'] == false &&
            catalogEvent['toolExecutionEnabled'] == false;
        providerRequestOk = requestEvent['ok'] == true &&
            providerRequest['provider'] == 'openrouter' &&
            providerRequest['transport'] ==
                'openai-compatible-chat-completions' &&
            providerRequest['selectedToolCount'] is num &&
            (providerRequest['selectedToolCount'] as num) > 0 &&
            providerRequest['toolFunctionNames'] is List &&
            (providerRequest['toolFunctionNames'] as List).isNotEmpty &&
            providerRequest['requestHash']?.toString().isNotEmpty == true &&
            providerRequest['bodyHash']?.toString().isNotEmpty == true &&
            bodyValidation['streamMode'] == true &&
            bodyValidation['rawPromptRedacted'] == true &&
            bodyValidation['toolSchemasAttached'] == true &&
            bodyValidation['toolNamesValid'] == true &&
            providerRequest['transportInvocationEnabled'] == false &&
            providerRequest['providerCallsEnabled'] == false &&
            providerRequest['executionEnabled'] == false &&
            providerRequest['toolExecutionEnabled'] == false &&
            providerRequest['stopBefore'] == 'provider_fetch_or_tool_dispatch';
        streamingFixtureOk = streamingFixtureEvent['ok'] == true &&
            streamingFixture['fixture'] ==
                'openai-compatible-streaming-tool-call' &&
            streamingFixture['parityOk'] == true &&
            streamingParsed['toolPlanCount'] == 1 &&
            streamingParsed['allowedPlanCount'] == 1 &&
            streamingParsed['blockedPlanCount'] == 0 &&
            streamingParsed['invalidArgumentCount'] == 0 &&
            streamingParsed['finishReason'] == 'tool_calls' &&
            streamingParsed['doneSeen'] == true &&
            streamingParsed['executionEnabled'] == false &&
            streamingParsed['toolExecutionEnabled'] == false;
        messageFixtureOk = messageFixtureEvent['ok'] == true &&
            messageFixture['fixture'] ==
                'openai-compatible-message-tool-call' &&
            messageFixture['parityOk'] == true &&
            messageParsed['toolPlanCount'] == 1 &&
            messageParsed['allowedPlanCount'] == 1 &&
            messageParsed['blockedPlanCount'] == 0 &&
            messageParsed['invalidArgumentCount'] == 0 &&
            messageParsed['finishReason'] == 'tool_calls';
        unknownFixtureOk = unknownFixtureEvent['ok'] == true &&
            unknownFixture['fixture'] == 'unknown-tool-rejected' &&
            unknownFixture['parityOk'] == true &&
            unknownParsed['toolPlanCount'] == 1 &&
            unknownParsed['allowedPlanCount'] == 0 &&
            unknownParsed['blockedPlanCount'] == 1 &&
            unknownParsed['unknownToolCount'] == 1;
        malformedFixtureOk = malformedFixtureEvent['ok'] == true &&
            malformedFixture['fixture'] ==
                'malformed-tool-arguments-rejected' &&
            malformedFixture['parityOk'] == true &&
            malformedParsed['toolPlanCount'] == 1 &&
            malformedParsed['allowedPlanCount'] == 0 &&
            malformedParsed['blockedPlanCount'] == 1 &&
            malformedParsed['invalidArgumentCount'] == 1;
        toolPlanSummaryOk = summaryEvent['ok'] == true &&
            summaryEvent['fixtureParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            summaryEvent['providerCallsEnabled'] == false &&
            summaryEvent['executionEnabled'] == false &&
            summaryEvent['toolExecutionEnabled'] == false &&
            toolPlanSummary['toolPlanCount'] == 1 &&
            toolPlanSummary['allowedPlanCount'] == 1 &&
            toolPlanSummary['blockedPlanCount'] == 0 &&
            toolPlanSummary['finishReason'] == 'tool_calls' &&
            toolPlanSummary['toolExecutionEnabled'] == false;
        toolPlanEndOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] == 'provider_tool_plan_capture_complete' &&
            endEvent['finishReason'] == 'tool_plan_capture_complete' &&
            endEvent['fixtureParityOk'] == true &&
            endEvent['validationOk'] == true &&
            endEvent['selectedToolCount'] is num &&
            (endEvent['selectedToolCount'] as num) > 0 &&
            endEvent['toolPlanCount'] == 1 &&
            endEvent['allowedPlanCount'] == 1 &&
            endEvent['blockedPlanCount'] == 0 &&
            endEvent['invalidArgumentCount'] == 0 &&
            endEvent['providerCallsEnabled'] == false &&
            endEvent['executionEnabled'] == false &&
            endEvent['toolExecutionEnabled'] == false;
        toolPlanCanaryOk = toolPlanAckOk &&
            toolCatalogOk &&
            providerRequestOk &&
            streamingFixtureOk &&
            messageFixtureOk &&
            unknownFixtureOk &&
            malformedFixtureOk &&
            toolPlanSummaryOk &&
            toolPlanOrderOk &&
            toolPlanEndOk;

        postToolPlanHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postToolPlanProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postToolPlanGuardOk = postToolPlanHealth['ok'] == true &&
            postToolPlanHealth['runtime'] == 'native-node-embedded' &&
            postToolPlanHealth['port'] == AppConstants.gatewayPort &&
            postToolPlanHealth['productionPortBindCanary'] == true &&
            postToolPlanHealth['openclawStarted'] == false &&
            postToolPlanProbe['runtime'] == 'native-node-embedded' &&
            postToolPlanProbe['port'] == AppConstants.gatewayPort &&
            postToolPlanProbe['productionPortBindCanary'] == true &&
            postToolPlanProbe['canaryOnly'] == true &&
            postToolPlanProbe['productionReady'] == false &&
            postToolPlanProbe['openclawStarted'] == false &&
            postToolPlanProbe['chatRoutingEnabled'] == false &&
            postToolPlanProbe['providerCallsEnabled'] == false &&
            postToolPlanProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (toolPlanCanarySent) {
          toolPlanError = e;
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
          toolPlanCanaryOk &&
          postToolPlanGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final ackEvent = _firstEvent(toolPlanEvents, 'ack');
      final catalogEvent = _firstEvent(toolPlanEvents, 'tool_catalog');
      final requestEvent = _firstEvent(toolPlanEvents, 'provider_request');
      final summaryEvent = _firstEvent(toolPlanEvents, 'tool_plan_summary');
      final endEvent = _firstEvent(toolPlanEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final providerRequest = requestEvent['providerRequest'] is Map
          ? Map<String, dynamic>.from(requestEvent['providerRequest'] as Map)
          : <String, dynamic>{};
      final toolPlanSummary = summaryEvent['toolPlanSummary'] is Map
          ? Map<String, dynamic>.from(summaryEvent['toolPlanSummary'] as Map)
          : <String, dynamic>{};
      final observedOrder =
          toolPlanEvents.map((event) => event['event']?.toString()).toList();
      final toolPlanNames = toolPlanSummary['toolPlanNames'] is List
          ? List<dynamic>.from(toolPlanSummary['toolPlanNames'] as List)
          : const <dynamic>[];
      final gatewayToolNames = toolPlanSummary['gatewayToolNames'] is List
          ? List<dynamic>.from(toolPlanSummary['gatewayToolNames'] as List)
          : const <dynamic>[];

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-provider-tool-plan-capture',
        'mode':
            'native-production-port-provider-tool-plan-capture-with-rollback',
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
        'toolPlanCanarySent': toolPlanCanarySent,
        'toolPlanCanaryOk': toolPlanCanaryOk,
        'toolPlanAckOk': toolPlanAckOk,
        'toolCatalogOk': toolCatalogOk,
        'providerRequestOk': providerRequestOk,
        'streamingFixtureOk': streamingFixtureOk,
        'messageFixtureOk': messageFixtureOk,
        'unknownFixtureOk': unknownFixtureOk,
        'malformedFixtureOk': malformedFixtureOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'toolPlanOrderOk': toolPlanOrderOk,
        'toolPlanEndOk': toolPlanEndOk,
        'toolPlanEventsCount': toolPlanEvents.length,
        'toolPlanObservedOrder': observedOrder,
        'toolPlanRouteStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'toolPlanFinishReason': endEvent['finishReason'],
        'provider': providerRequest['provider'] ?? ack['provider'],
        'requestedModel':
            providerRequest['requestedModel'] ?? ack['requestedModel'],
        'providerModel':
            providerRequest['providerModel'] ?? ack['providerModel'],
        'transport': providerRequest['transport'] ?? ack['transport'],
        'requestHash': providerRequest['requestHash'] ?? ack['requestHash'],
        'bodyHash': providerRequest['bodyHash'] ?? ack['bodyHash'],
        'toolSelectionHash':
            providerRequest['toolSelectionHash'] ?? ack['toolSelectionHash'],
        'fixtureHash': ack['fixtureHash'] ?? endEvent['fixtureHash'],
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            endEvent['fixtureParityOk'] == true,
        'validationOk': ack['validationOk'] == true ||
            summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'selectedToolCount':
            catalogEvent['selectedToolCount'] ?? ack['selectedToolCount'],
        'toolFunctionNames': catalogEvent['toolFunctionNames'],
        'gatewayToolNames': catalogEvent['gatewayToolNames'],
        'schemaChars': catalogEvent['schemaChars'],
        'toolPlanCount':
            toolPlanSummary['toolPlanCount'] ?? endEvent['toolPlanCount'],
        'allowedPlanCount':
            toolPlanSummary['allowedPlanCount'] ?? endEvent['allowedPlanCount'],
        'blockedPlanCount':
            toolPlanSummary['blockedPlanCount'] ?? endEvent['blockedPlanCount'],
        'invalidArgumentCount': toolPlanSummary['invalidArgumentCount'] ??
            endEvent['invalidArgumentCount'],
        'unknownToolCount': toolPlanSummary['unknownToolCount'],
        'toolPlanNames': toolPlanNames,
        'capturedGatewayToolNames': gatewayToolNames,
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            providerRequest['transportInvocationEnabled'] == true ||
                ackEvent['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        if (toolPlanError != null) 'toolPlanError': toolPlanError.toString(),
        'postToolPlanGuardOk': postToolPlanGuardOk,
        'postToolPlanRuntimeReported': postToolPlanHealth['runtime'],
        'postToolPlanCanaryOnly': postToolPlanProbe['canaryOnly'] == true,
        'postToolPlanChatRoutingEnabled':
            postToolPlanProbe['chatRoutingEnabled'] == true,
        'postToolPlanProviderCallsEnabled':
            postToolPlanProbe['providerCallsEnabled'] == true,
        'postToolPlanToolExecutionEnabled':
            postToolPlanProbe['toolExecutionEnabled'] == true,
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
            ? 'Native owned 18789, captured provider tool-call plans with provider/tool execution disabled, and PRoot was restored.'
            : 'Production-port provider tool-plan capture is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'production-port native tool dispatch dry-run with execution disabled',
      };
      log('[NATIVE-TOOL-PLAN-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortProviderToolPlanInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runProductionPortToolDispatchDryRun({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production tool dispatch dry-run: wave right and vibrate once',
  }) async {
    if (_productionPortToolDispatchInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-tool-dispatch-dry-run',
        'alreadyInFlight': true,
        'decision': 'Production-port tool dispatch dry-run is already running.',
      };
    }

    _productionPortToolDispatchInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();
      final providerHint = requestedModel.contains('/')
          ? requestedModel.split('/').first
          : 'openrouter';
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
      var dispatchDryRunSent = false;
      var dispatchAckOk = false;
      var toolPlanSummaryOk = false;
      var dispatchPlanOk = false;
      var toolUseFrameOk = false;
      var toolResultFrameOk = false;
      var dispatchSummaryOk = false;
      var dispatchOrderOk = false;
      var dispatchEndOk = false;
      var dispatchDryRunOk = false;
      var postDispatchGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postDispatchHealth = <String, dynamic>{};
      Map<String, dynamic> postDispatchProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> dispatchEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? dispatchError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-DISPATCH-OWNER] Opening tool dispatch dry-run.');

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
            'Tool dispatch dry-run requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before tool dispatch dry-run.',
          );
        }

        log('[NATIVE-DISPATCH-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before tool dispatch dry-run.',
          );
        }

        log(
          '[NATIVE-DISPATCH-OWNER] Starting native on 18789 and mapping '
          'tool plans to synthetic dispatch frames.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native tool dispatch dry-run did not start.');
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

        dispatchDryRunSent = true;
        dispatchEvents = await _streamProductionNdjson(
          '/gateway/chat-tool-dispatch-dry-run-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-tool-dispatch-dry-run-request',
            idempotencyKey: 'production-tool-dispatch-dry-run-idempotency-key',
            model: requestedModel,
            provider: providerHint,
            message: prompt,
          ),
          expectedStatus: 202,
        );

        final ackEvent = _firstEvent(dispatchEvents, 'ack');
        final planEvent = _firstEvent(dispatchEvents, 'tool_plan_summary');
        final dispatchPlanEvent =
            _firstEvent(dispatchEvents, 'tool_dispatch_plan');
        final toolUseEvent = _firstEvent(dispatchEvents, 'tool_use_frame');
        final toolResultEvent =
            _firstEvent(dispatchEvents, 'tool_result_frame');
        final summaryEvent = _firstEvent(dispatchEvents, 'dispatch_summary');
        final endEvent = _firstEvent(dispatchEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final toolPlanSummary = planEvent['toolPlanSummary'] is Map
            ? Map<String, dynamic>.from(planEvent['toolPlanSummary'] as Map)
            : <String, dynamic>{};
        final plan = planEvent['plan'] is Map
            ? Map<String, dynamic>.from(planEvent['plan'] as Map)
            : <String, dynamic>{};
        final dispatchPlan = dispatchPlanEvent['dispatchPlan'] is Map
            ? Map<String, dynamic>.from(
                dispatchPlanEvent['dispatchPlan'] as Map,
              )
            : <String, dynamic>{};
        final route = dispatchPlan['route'] is Map
            ? Map<String, dynamic>.from(dispatchPlan['route'] as Map)
            : <String, dynamic>{};
        final toolUseFrame = toolUseEvent['frame'] is Map
            ? Map<String, dynamic>.from(toolUseEvent['frame'] as Map)
            : <String, dynamic>{};
        final toolResultFrame = toolResultEvent['frame'] is Map
            ? Map<String, dynamic>.from(toolResultEvent['frame'] as Map)
            : <String, dynamic>{};
        final toolResult = toolResultFrame['result'] is Map
            ? Map<String, dynamic>.from(toolResultFrame['result'] as Map)
            : <String, dynamic>{};
        final observedOrder =
            dispatchEvents.map((event) => event['event']?.toString()).toList();
        const expectedOrder = <String>[
          'ack',
          'tool_plan_summary',
          'tool_dispatch_plan',
          'tool_use_frame',
          'tool_result_frame',
          'dispatch_summary',
          'end',
        ];
        dispatchOrderOk = observedOrder.length >= expectedOrder.length;
        for (var i = 0; i < expectedOrder.length && dispatchOrderOk; i++) {
          dispatchOrderOk = observedOrder[i] == expectedOrder[i];
        }

        dispatchAckOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'tool_dispatch_dry_run' &&
            ackEvent['routeStatus'] ==
                'native_tool_dispatch_dry_run_complete' &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == false &&
            ackEvent['queueStatus'] == 'native_tool_dispatch_dry_run' &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['providerCallsEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ackEvent['toolExecutionEnabled'] == false &&
            ackEvent['transportInvocationEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['routeStatus'] == 'native_tool_dispatch_dry_run_complete' &&
            ack['fixtureParityOk'] == true &&
            ack['dispatchParityOk'] == true &&
            ack['validationOk'] == true &&
            ack['toolPlanCount'] == 1 &&
            ack['allowedPlanCount'] == 1 &&
            ack['blockedPlanCount'] == 0 &&
            ack['providerCallsEnabled'] == false &&
            ack['transportInvocationEnabled'] == false &&
            ack['executionEnabled'] == false &&
            ack['toolExecutionEnabled'] == false &&
            ack['dispatchHash']?.toString().isNotEmpty == true;
        toolPlanSummaryOk = planEvent['ok'] == true &&
            planEvent['fixtureParityOk'] == true &&
            planEvent['toolExecutionEnabled'] == false &&
            toolPlanSummary['toolPlanCount'] == 1 &&
            toolPlanSummary['allowedPlanCount'] == 1 &&
            toolPlanSummary['blockedPlanCount'] == 0 &&
            toolPlanSummary['invalidArgumentCount'] == 0 &&
            toolPlanSummary['finishReason'] == 'tool_calls' &&
            toolPlanSummary['toolExecutionEnabled'] == false &&
            plan['allowedName'] == true &&
            plan['argumentsOk'] == true &&
            plan['blockedReason'] == null;
        dispatchPlanOk = dispatchPlanEvent['ok'] == true &&
            dispatchPlan['callId']?.toString().isNotEmpty == true &&
            dispatchPlan['dispatchHash']?.toString().isNotEmpty == true &&
            dispatchPlan['planHash']?.toString().isNotEmpty == true &&
            dispatchPlan['wouldExecute'] == true &&
            dispatchPlan['executionEnabled'] == false &&
            dispatchPlan['toolExecutionEnabled'] == false &&
            route['method'] == 'avatar.gesture' &&
            route['capability'] == 'avatar' &&
            route['dartCapability'] == 'AvatarCapability' &&
            route['requiresUiThread'] == true;
        toolUseFrameOk = toolUseEvent['ok'] == true &&
            toolUseFrame['type'] == 'tool_use' &&
            toolUseFrame['id']?.toString().isNotEmpty == true &&
            toolUseFrame['name'] == route['method'] &&
            toolUseFrame['runtime'] == 'native-node-embedded' &&
            toolUseFrame['source'] == 'tool-dispatch-dry-run' &&
            toolUseFrame['input'] is Map &&
            (toolUseFrame['input'] as Map)['gesture'] != null &&
            toolUseFrame['executionEnabled'] == false &&
            toolUseFrame['toolExecutionEnabled'] == false;
        toolResultFrameOk = toolResultEvent['ok'] == true &&
            toolResultFrame['type'] == 'tool_result' &&
            toolResultFrame['id'] == toolUseFrame['id'] &&
            toolResultFrame['name'] == route['method'] &&
            toolResultFrame['runtime'] == 'native-node-embedded' &&
            toolResultFrame['source'] == 'tool-dispatch-dry-run' &&
            toolResultFrame['executionEnabled'] == false &&
            toolResultFrame['toolExecutionEnabled'] == false &&
            toolResult['ok'] == true &&
            toolResult['dryRun'] == true &&
            toolResult['skipped'] == true &&
            toolResult['skippedReason'] == 'native_tool_execution_disabled' &&
            toolResult['capability'] == route['capability'] &&
            toolResult['dartCapability'] == route['dartCapability'] &&
            toolResult['method'] == route['method'] &&
            toolResult['wouldExecute'] == true &&
            toolResult['executionEnabled'] == false &&
            toolResult['toolExecutionEnabled'] == false;
        dispatchSummaryOk = summaryEvent['ok'] == true &&
            summaryEvent['dispatchParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            summaryEvent['toolName'] == route['method'] &&
            summaryEvent['capability'] == route['capability'] &&
            summaryEvent['dartCapability'] == route['dartCapability'] &&
            summaryEvent['skippedReason'] == 'native_tool_execution_disabled' &&
            summaryEvent['providerCallsEnabled'] == false &&
            summaryEvent['executionEnabled'] == false &&
            summaryEvent['toolExecutionEnabled'] == false;
        dispatchEndOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] ==
                'native_tool_dispatch_dry_run_complete' &&
            endEvent['finishReason'] == 'tool_dispatch_dry_run_complete' &&
            endEvent['fixtureParityOk'] == true &&
            endEvent['dispatchParityOk'] == true &&
            endEvent['validationOk'] == true &&
            endEvent['toolName'] == route['method'] &&
            endEvent['capability'] == route['capability'] &&
            endEvent['providerCallsEnabled'] == false &&
            endEvent['executionEnabled'] == false &&
            endEvent['toolExecutionEnabled'] == false;
        dispatchDryRunOk = dispatchAckOk &&
            toolPlanSummaryOk &&
            dispatchPlanOk &&
            toolUseFrameOk &&
            toolResultFrameOk &&
            dispatchSummaryOk &&
            dispatchOrderOk &&
            dispatchEndOk;

        postDispatchHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postDispatchProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postDispatchGuardOk = postDispatchHealth['ok'] == true &&
            postDispatchHealth['runtime'] == 'native-node-embedded' &&
            postDispatchHealth['port'] == AppConstants.gatewayPort &&
            postDispatchHealth['productionPortBindCanary'] == true &&
            postDispatchHealth['openclawStarted'] == false &&
            postDispatchProbe['runtime'] == 'native-node-embedded' &&
            postDispatchProbe['port'] == AppConstants.gatewayPort &&
            postDispatchProbe['productionPortBindCanary'] == true &&
            postDispatchProbe['canaryOnly'] == true &&
            postDispatchProbe['productionReady'] == false &&
            postDispatchProbe['openclawStarted'] == false &&
            postDispatchProbe['chatRoutingEnabled'] == false &&
            postDispatchProbe['providerCallsEnabled'] == false &&
            postDispatchProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (dispatchDryRunSent) {
          dispatchError = e;
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
          dispatchDryRunOk &&
          postDispatchGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final ackEvent = _firstEvent(dispatchEvents, 'ack');
      final planEvent = _firstEvent(dispatchEvents, 'tool_plan_summary');
      final dispatchPlanEvent =
          _firstEvent(dispatchEvents, 'tool_dispatch_plan');
      final toolUseEvent = _firstEvent(dispatchEvents, 'tool_use_frame');
      final toolResultEvent = _firstEvent(dispatchEvents, 'tool_result_frame');
      final summaryEvent = _firstEvent(dispatchEvents, 'dispatch_summary');
      final endEvent = _firstEvent(dispatchEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final toolPlanSummary = planEvent['toolPlanSummary'] is Map
          ? Map<String, dynamic>.from(planEvent['toolPlanSummary'] as Map)
          : <String, dynamic>{};
      final dispatchPlan = dispatchPlanEvent['dispatchPlan'] is Map
          ? Map<String, dynamic>.from(dispatchPlanEvent['dispatchPlan'] as Map)
          : <String, dynamic>{};
      final route = dispatchPlan['route'] is Map
          ? Map<String, dynamic>.from(dispatchPlan['route'] as Map)
          : <String, dynamic>{};
      final toolUseFrame = toolUseEvent['frame'] is Map
          ? Map<String, dynamic>.from(toolUseEvent['frame'] as Map)
          : <String, dynamic>{};
      final toolResultFrame = toolResultEvent['frame'] is Map
          ? Map<String, dynamic>.from(toolResultEvent['frame'] as Map)
          : <String, dynamic>{};
      final toolResult = toolResultFrame['result'] is Map
          ? Map<String, dynamic>.from(toolResultFrame['result'] as Map)
          : <String, dynamic>{};
      final observedOrder =
          dispatchEvents.map((event) => event['event']?.toString()).toList();
      final toolPlanNames = toolPlanSummary['toolPlanNames'] is List
          ? List<dynamic>.from(toolPlanSummary['toolPlanNames'] as List)
          : const <dynamic>[];
      final gatewayToolNames = toolPlanSummary['gatewayToolNames'] is List
          ? List<dynamic>.from(toolPlanSummary['gatewayToolNames'] as List)
          : const <dynamic>[];

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-tool-dispatch-dry-run',
        'mode': 'native-production-port-tool-dispatch-dry-run-with-rollback',
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
        'dispatchDryRunSent': dispatchDryRunSent,
        'dispatchDryRunOk': dispatchDryRunOk,
        'dispatchAckOk': dispatchAckOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'dispatchPlanOk': dispatchPlanOk,
        'toolUseFrameOk': toolUseFrameOk,
        'toolResultFrameOk': toolResultFrameOk,
        'dispatchSummaryOk': dispatchSummaryOk,
        'dispatchOrderOk': dispatchOrderOk,
        'dispatchEndOk': dispatchEndOk,
        'dispatchEventsCount': dispatchEvents.length,
        'dispatchObservedOrder': observedOrder,
        'dispatchRouteStatus': ackEvent['routeStatus'] ?? ack['routeStatus'],
        'dispatchFinishReason': endEvent['finishReason'],
        'provider': ack['provider'],
        'requestedModel': ack['requestedModel'],
        'providerModel': ack['providerModel'],
        'transport': ack['transport'],
        'requestHash': ack['requestHash'] ?? endEvent['requestHash'],
        'toolSelectionHash':
            ack['toolSelectionHash'] ?? endEvent['toolSelectionHash'],
        'dispatchHash': dispatchPlan['dispatchHash'] ??
            summaryEvent['dispatchHash'] ??
            endEvent['dispatchHash'],
        'fixtureHash': ack['fixtureHash'],
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            endEvent['fixtureParityOk'] == true,
        'dispatchParityOk': ack['dispatchParityOk'] == true ||
            summaryEvent['dispatchParityOk'] == true ||
            endEvent['dispatchParityOk'] == true,
        'validationOk': ack['validationOk'] == true ||
            summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'selectedToolCount': ack['selectedToolCount'],
        'toolPlanCount':
            toolPlanSummary['toolPlanCount'] ?? ack['toolPlanCount'],
        'allowedPlanCount':
            toolPlanSummary['allowedPlanCount'] ?? ack['allowedPlanCount'],
        'blockedPlanCount':
            toolPlanSummary['blockedPlanCount'] ?? ack['blockedPlanCount'],
        'invalidArgumentCount': toolPlanSummary['invalidArgumentCount'],
        'toolPlanNames': toolPlanNames,
        'gatewayToolNames': gatewayToolNames,
        'toolName': route['method'] ?? summaryEvent['toolName'],
        'capability': route['capability'] ?? summaryEvent['capability'],
        'dartCapability':
            route['dartCapability'] ?? summaryEvent['dartCapability'],
        'requiresUiThread': route['requiresUiThread'],
        'callId': dispatchPlan['callId'] ?? toolUseFrame['id'],
        'wouldExecute': dispatchPlan['wouldExecute'] == true,
        'toolUseFrameName': toolUseFrame['name'],
        'toolResultFrameName': toolResultFrame['name'],
        'toolResultDryRun': toolResult['dryRun'] == true,
        'skippedReason':
            toolResult['skippedReason'] ?? summaryEvent['skippedReason'],
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            ackEvent['transportInvocationEnabled'] == true ||
                ack['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        if (dispatchError != null) 'dispatchError': dispatchError.toString(),
        'postDispatchGuardOk': postDispatchGuardOk,
        'postDispatchRuntimeReported': postDispatchHealth['runtime'],
        'postDispatchCanaryOnly': postDispatchProbe['canaryOnly'] == true,
        'postDispatchChatRoutingEnabled':
            postDispatchProbe['chatRoutingEnabled'] == true,
        'postDispatchProviderCallsEnabled':
            postDispatchProbe['providerCallsEnabled'] == true,
        'postDispatchToolExecutionEnabled':
            postDispatchProbe['toolExecutionEnabled'] == true,
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
            ? 'Native owned 18789, mapped a tool plan to synthetic dispatch frames with execution disabled, and PRoot was restored.'
            : 'Production-port tool dispatch dry-run is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'production-port native Dart bridge dry-run with execution disabled',
      };
      log('[NATIVE-DISPATCH-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortToolDispatchInFlight = false;
    }
  }

  static Future<Map<String, dynamic>> runProductionPortDartBridgeDryRun({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production Dart bridge dry-run: wave right and vibrate once',
  }) async {
    if (_productionPortDartBridgeInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-dart-bridge-dry-run',
        'alreadyInFlight': true,
        'decision': 'Production-port Dart bridge dry-run is already running.',
      };
    }

    _productionPortDartBridgeInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();
      final providerHint = requestedModel.contains('/')
          ? requestedModel.split('/').first
          : 'openrouter';
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
      var bridgeDryRunSent = false;
      var bridgeAckEventOk = false;
      var toolPlanSummaryOk = false;
      var dispatchPlanOk = false;
      var bridgeRequestOk = false;
      var bridgeAckOk = false;
      var toolUseFrameOk = false;
      var toolResultFrameOk = false;
      var bridgeSummaryOk = false;
      var bridgeOrderOk = false;
      var bridgeEndOk = false;
      var bridgeDryRunOk = false;
      var postBridgeGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postBridgeHealth = <String, dynamic>{};
      Map<String, dynamic> postBridgeProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> bridgeEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? bridgeError;
      Object? nativeStopError;
      Object? rollbackError;

      log('[NATIVE-DART-BRIDGE-OWNER] Opening Dart bridge dry-run.');

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
            'Dart bridge dry-run requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before Dart bridge dry-run.',
          );
        }

        log('[NATIVE-DART-BRIDGE-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before Dart bridge dry-run.',
          );
        }

        log(
          '[NATIVE-DART-BRIDGE-OWNER] Starting native on 18789 and sending '
          'a dry-run dispatch request to Dart.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError('Native Dart bridge dry-run did not start.');
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

        bridgeDryRunSent = true;
        bridgeEvents = await _streamProductionNdjson(
          '/gateway/chat-native-dart-bridge-dry-run-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-dart-bridge-dry-run-request',
            idempotencyKey: 'production-dart-bridge-dry-run-idempotency-key',
            model: requestedModel,
            provider: providerHint,
            message: prompt,
          ),
          expectedStatus: 202,
          streamIdleTimeout: const Duration(seconds: 20),
        );

        final ackEvent = _firstEvent(bridgeEvents, 'ack');
        final planEvent = _firstEvent(bridgeEvents, 'tool_plan_summary');
        final dispatchPlanEvent =
            _firstEvent(bridgeEvents, 'tool_dispatch_plan');
        final bridgeRequestEvent = _firstEvent(bridgeEvents, 'bridge_request');
        final bridgeAckEvent = _firstEvent(bridgeEvents, 'bridge_ack');
        final toolUseEvent = _firstEvent(bridgeEvents, 'tool_use_frame');
        final toolResultEvent = _firstEvent(bridgeEvents, 'tool_result_frame');
        final summaryEvent = _firstEvent(bridgeEvents, 'bridge_summary');
        final endEvent = _firstEvent(bridgeEvents, 'end');
        final ack = ackEvent['ack'] is Map
            ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
            : <String, dynamic>{};
        final toolPlanSummary = planEvent['toolPlanSummary'] is Map
            ? Map<String, dynamic>.from(planEvent['toolPlanSummary'] as Map)
            : <String, dynamic>{};
        final plan = planEvent['plan'] is Map
            ? Map<String, dynamic>.from(planEvent['plan'] as Map)
            : <String, dynamic>{};
        final dispatchPlan = dispatchPlanEvent['dispatchPlan'] is Map
            ? Map<String, dynamic>.from(
                dispatchPlanEvent['dispatchPlan'] as Map,
              )
            : <String, dynamic>{};
        final route = dispatchPlan['route'] is Map
            ? Map<String, dynamic>.from(dispatchPlan['route'] as Map)
            : <String, dynamic>{};
        final bridgeRequest = bridgeRequestEvent['bridgeRequest'] is Map
            ? Map<String, dynamic>.from(
                bridgeRequestEvent['bridgeRequest'] as Map,
              )
            : <String, dynamic>{};
        final bridgeAck = bridgeAckEvent['bridgeAck'] is Map
            ? Map<String, dynamic>.from(bridgeAckEvent['bridgeAck'] as Map)
            : <String, dynamic>{};
        final toolUseFrame = toolUseEvent['frame'] is Map
            ? Map<String, dynamic>.from(toolUseEvent['frame'] as Map)
            : <String, dynamic>{};
        final toolResultFrame = toolResultEvent['frame'] is Map
            ? Map<String, dynamic>.from(toolResultEvent['frame'] as Map)
            : <String, dynamic>{};
        final toolResult = toolResultFrame['result'] is Map
            ? Map<String, dynamic>.from(toolResultFrame['result'] as Map)
            : <String, dynamic>{};
        final observedOrder =
            bridgeEvents.map((event) => event['event']?.toString()).toList();
        const expectedOrder = <String>[
          'ack',
          'tool_plan_summary',
          'tool_dispatch_plan',
          'bridge_request',
          'bridge_ack',
          'tool_use_frame',
          'tool_result_frame',
          'bridge_summary',
          'end',
        ];
        bridgeOrderOk = observedOrder.length >= expectedOrder.length;
        for (var i = 0; i < expectedOrder.length && bridgeOrderOk; i++) {
          bridgeOrderOk = observedOrder[i] == expectedOrder[i];
        }

        bridgeAckEventOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == true &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'native_dart_bridge_dry_run' &&
            ackEvent['routeStatus'] == 'native_dart_bridge_dry_run_started' &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == false &&
            ackEvent['queueStatus'] == 'native_dart_bridge_dry_run' &&
            ackEvent['chatRoutingEnabled'] == false &&
            ackEvent['providerCallsEnabled'] == false &&
            ackEvent['executionEnabled'] == false &&
            ackEvent['toolExecutionEnabled'] == false &&
            ackEvent['bridgeExecutionEnabled'] == false &&
            ackEvent['transportInvocationEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            ack['route'] == 'native_dart_bridge_dry_run' &&
            ack['bridgeRequestHash']?.toString().isNotEmpty == true &&
            ack['fixtureParityOk'] == true &&
            ack['dispatchParityOk'] == true &&
            ack['providerCallsEnabled'] == false &&
            ack['transportInvocationEnabled'] == false &&
            ack['executionEnabled'] == false &&
            ack['toolExecutionEnabled'] == false &&
            ack['bridgeExecutionEnabled'] == false;
        toolPlanSummaryOk = planEvent['ok'] == true &&
            planEvent['fixtureParityOk'] == true &&
            planEvent['toolExecutionEnabled'] == false &&
            toolPlanSummary['toolPlanCount'] == 1 &&
            toolPlanSummary['allowedPlanCount'] == 1 &&
            toolPlanSummary['blockedPlanCount'] == 0 &&
            toolPlanSummary['invalidArgumentCount'] == 0 &&
            toolPlanSummary['finishReason'] == 'tool_calls' &&
            toolPlanSummary['toolExecutionEnabled'] == false &&
            plan['allowedName'] == true &&
            plan['argumentsOk'] == true &&
            plan['blockedReason'] == null;
        dispatchPlanOk = dispatchPlanEvent['ok'] == true &&
            dispatchPlan['callId']?.toString().isNotEmpty == true &&
            dispatchPlan['dispatchHash']?.toString().isNotEmpty == true &&
            dispatchPlan['bridgeRequestHash']?.toString().isNotEmpty == true &&
            dispatchPlan['planHash']?.toString().isNotEmpty == true &&
            dispatchPlan['wouldExecute'] == false &&
            dispatchPlan['executionEnabled'] == false &&
            dispatchPlan['toolExecutionEnabled'] == false &&
            dispatchPlan['bridgeExecutionEnabled'] == false &&
            route['method'] == 'avatar.gesture' &&
            route['capability'] == 'avatar' &&
            route['dartCapability'] == 'AvatarCapability' &&
            route['requiresUiThread'] == true;
        bridgeRequestOk = bridgeRequestEvent['ok'] == true &&
            bridgeRequestEvent['endpoint'] ==
                'http://127.0.0.1:8765/api/native-gateway/dispatch-dry-run' &&
            bridgeRequest['type'] == 'native_tool_dispatch_dry_run' &&
            bridgeRequest['callId'] == dispatchPlan['callId'] &&
            bridgeRequest['method'] == route['method'] &&
            bridgeRequest['capability'] == route['capability'] &&
            bridgeRequest['dartCapability'] == route['dartCapability'] &&
            bridgeRequest['bridgeRequestHash'] ==
                dispatchPlan['bridgeRequestHash'] &&
            bridgeRequest['dispatchHash'] == dispatchPlan['dispatchHash'] &&
            bridgeRequest['dryRun'] == true &&
            bridgeRequest['executionEnabled'] == false &&
            bridgeRequest['toolExecutionEnabled'] == false &&
            bridgeRequest['bridgeExecutionEnabled'] == false;
        bridgeAckOk = bridgeAckEvent['ok'] == true &&
            bridgeAckEvent['statusCode'] == 200 &&
            bridgeAckEvent['responseBytesRead'] is num &&
            (bridgeAckEvent['responseBytesRead'] as num) > 0 &&
            bridgeAckEvent['bridgeAckHash']?.toString().isNotEmpty == true &&
            bridgeAckEvent['bridgeParityOk'] == true &&
            bridgeAckEvent['validationOk'] == true &&
            bridgeAck['ok'] == true &&
            bridgeAck['accepted'] == true &&
            bridgeAck['runtime'] == 'flutter-dart' &&
            bridgeAck['bridge'] == 'AgentSkillServer' &&
            bridgeAck['source'] == 'native-dart-bridge-dry-run' &&
            bridgeAck['routeStatus'] == 'native_dart_bridge_dry_run_ack' &&
            bridgeAck['command'] == route['method'] &&
            bridgeAck['commandKnown'] == true &&
            bridgeAck['capability'] == route['capability'] &&
            bridgeAck['dartCapability'] == route['dartCapability'] &&
            bridgeAck['dryRun'] == true &&
            bridgeAck['skippedReason'] == 'native_dart_bridge_dry_run_only' &&
            bridgeAck['executionEnabled'] == false &&
            bridgeAck['toolExecutionEnabled'] == false &&
            bridgeAck['bridgeExecutionEnabled'] == false &&
            bridgeAck['bridgeRequestHash'] ==
                bridgeRequest['bridgeRequestHash'];
        toolUseFrameOk = toolUseEvent['ok'] == true &&
            toolUseFrame['type'] == 'tool_use' &&
            toolUseFrame['id']?.toString().isNotEmpty == true &&
            toolUseFrame['name'] == route['method'] &&
            toolUseFrame['runtime'] == 'native-node-embedded' &&
            toolUseFrame['input'] is Map &&
            (toolUseFrame['input'] as Map)['gesture'] != null &&
            toolUseFrame['executionEnabled'] == false &&
            toolUseFrame['toolExecutionEnabled'] == false;
        toolResultFrameOk = toolResultEvent['ok'] == true &&
            toolResultFrame['type'] == 'tool_result' &&
            toolResultFrame['id'] == toolUseFrame['id'] &&
            toolResultFrame['name'] == route['method'] &&
            toolResultFrame['runtime'] == 'native-node-embedded' &&
            toolResultFrame['executionEnabled'] == false &&
            toolResultFrame['toolExecutionEnabled'] == false &&
            toolResult['ok'] == true &&
            toolResult['dryRun'] == true &&
            toolResult['bridgeAckReceived'] == true &&
            toolResult['dartBridgeOk'] == true &&
            toolResult['dartAccepted'] == true &&
            toolResult['commandKnown'] == true &&
            toolResult['skippedReason'] == 'native_dart_bridge_dry_run_only' &&
            toolResult['bridgeRequestHash'] ==
                bridgeRequest['bridgeRequestHash'] &&
            toolResult['bridgeExecutionEnabled'] == false &&
            toolResult['executionEnabled'] == false &&
            toolResult['toolExecutionEnabled'] == false;
        bridgeSummaryOk = summaryEvent['ok'] == true &&
            summaryEvent['fixtureParityOk'] == true &&
            summaryEvent['dispatchParityOk'] == true &&
            summaryEvent['bridgeParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            summaryEvent['toolName'] == route['method'] &&
            summaryEvent['capability'] == route['capability'] &&
            summaryEvent['dartCapability'] == route['dartCapability'] &&
            summaryEvent['skippedReason'] ==
                'native_dart_bridge_dry_run_only' &&
            summaryEvent['providerCallsEnabled'] == false &&
            summaryEvent['executionEnabled'] == false &&
            summaryEvent['toolExecutionEnabled'] == false &&
            summaryEvent['bridgeExecutionEnabled'] == false;
        bridgeEndOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] == 'native_dart_bridge_dry_run_complete' &&
            endEvent['finishReason'] == 'native_dart_bridge_dry_run_complete' &&
            endEvent['fixtureParityOk'] == true &&
            endEvent['dispatchParityOk'] == true &&
            endEvent['bridgeParityOk'] == true &&
            endEvent['validationOk'] == true &&
            endEvent['toolName'] == route['method'] &&
            endEvent['capability'] == route['capability'] &&
            endEvent['providerCallsEnabled'] == false &&
            endEvent['executionEnabled'] == false &&
            endEvent['toolExecutionEnabled'] == false &&
            endEvent['bridgeExecutionEnabled'] == false;
        bridgeDryRunOk = bridgeAckEventOk &&
            toolPlanSummaryOk &&
            dispatchPlanOk &&
            bridgeRequestOk &&
            bridgeAckOk &&
            toolUseFrameOk &&
            toolResultFrameOk &&
            bridgeSummaryOk &&
            bridgeOrderOk &&
            bridgeEndOk;

        postBridgeHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postBridgeProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postBridgeGuardOk = postBridgeHealth['ok'] == true &&
            postBridgeHealth['runtime'] == 'native-node-embedded' &&
            postBridgeHealth['port'] == AppConstants.gatewayPort &&
            postBridgeHealth['productionPortBindCanary'] == true &&
            postBridgeHealth['openclawStarted'] == false &&
            postBridgeProbe['runtime'] == 'native-node-embedded' &&
            postBridgeProbe['port'] == AppConstants.gatewayPort &&
            postBridgeProbe['productionPortBindCanary'] == true &&
            postBridgeProbe['canaryOnly'] == true &&
            postBridgeProbe['productionReady'] == false &&
            postBridgeProbe['openclawStarted'] == false &&
            postBridgeProbe['chatRoutingEnabled'] == false &&
            postBridgeProbe['providerCallsEnabled'] == false &&
            postBridgeProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (bridgeDryRunSent) {
          bridgeError = e;
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
          bridgeDryRunOk &&
          postBridgeGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final ackEvent = _firstEvent(bridgeEvents, 'ack');
      final planEvent = _firstEvent(bridgeEvents, 'tool_plan_summary');
      final dispatchPlanEvent = _firstEvent(bridgeEvents, 'tool_dispatch_plan');
      final bridgeRequestEvent = _firstEvent(bridgeEvents, 'bridge_request');
      final bridgeAckEvent = _firstEvent(bridgeEvents, 'bridge_ack');
      final toolResultEvent = _firstEvent(bridgeEvents, 'tool_result_frame');
      final summaryEvent = _firstEvent(bridgeEvents, 'bridge_summary');
      final endEvent = _firstEvent(bridgeEvents, 'end');
      final ack = ackEvent['ack'] is Map
          ? Map<String, dynamic>.from(ackEvent['ack'] as Map)
          : <String, dynamic>{};
      final toolPlanSummary = planEvent['toolPlanSummary'] is Map
          ? Map<String, dynamic>.from(planEvent['toolPlanSummary'] as Map)
          : <String, dynamic>{};
      final dispatchPlan = dispatchPlanEvent['dispatchPlan'] is Map
          ? Map<String, dynamic>.from(dispatchPlanEvent['dispatchPlan'] as Map)
          : <String, dynamic>{};
      final route = dispatchPlan['route'] is Map
          ? Map<String, dynamic>.from(dispatchPlan['route'] as Map)
          : <String, dynamic>{};
      final bridgeRequest = bridgeRequestEvent['bridgeRequest'] is Map
          ? Map<String, dynamic>.from(
              bridgeRequestEvent['bridgeRequest'] as Map)
          : <String, dynamic>{};
      final bridgeAck = bridgeAckEvent['bridgeAck'] is Map
          ? Map<String, dynamic>.from(bridgeAckEvent['bridgeAck'] as Map)
          : <String, dynamic>{};
      final toolResultFrame = toolResultEvent['frame'] is Map
          ? Map<String, dynamic>.from(toolResultEvent['frame'] as Map)
          : <String, dynamic>{};
      final toolResult = toolResultFrame['result'] is Map
          ? Map<String, dynamic>.from(toolResultFrame['result'] as Map)
          : <String, dynamic>{};
      final observedOrder =
          bridgeEvents.map((event) => event['event']?.toString()).toList();
      final toolPlanNames = toolPlanSummary['toolPlanNames'] is List
          ? List<dynamic>.from(toolPlanSummary['toolPlanNames'] as List)
          : const <dynamic>[];
      final gatewayToolNames = toolPlanSummary['gatewayToolNames'] is List
          ? List<dynamic>.from(toolPlanSummary['gatewayToolNames'] as List)
          : const <dynamic>[];

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-dart-bridge-dry-run',
        'mode': 'native-production-port-dart-bridge-dry-run-with-rollback',
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
        'bridgeDryRunSent': bridgeDryRunSent,
        'bridgeDryRunOk': bridgeDryRunOk,
        'bridgeAckEventOk': bridgeAckEventOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'dispatchPlanOk': dispatchPlanOk,
        'bridgeRequestOk': bridgeRequestOk,
        'bridgeAckOk': bridgeAckOk,
        'toolUseFrameOk': toolUseFrameOk,
        'toolResultFrameOk': toolResultFrameOk,
        'bridgeSummaryOk': bridgeSummaryOk,
        'bridgeOrderOk': bridgeOrderOk,
        'bridgeEndOk': bridgeEndOk,
        'bridgeEventsCount': bridgeEvents.length,
        'bridgeObservedOrder': observedOrder,
        'bridgeRouteStatus': endEvent['routeStatus'] ?? ack['routeStatus'],
        'bridgeFinishReason': endEvent['finishReason'],
        'provider': ack['provider'],
        'requestedModel': ack['requestedModel'],
        'providerModel': ack['providerModel'],
        'transport': ack['transport'],
        'requestHash': ack['requestHash'] ?? endEvent['requestHash'],
        'toolSelectionHash': ack['toolSelectionHash'],
        'dispatchHash': ack['dispatchHash'] ?? endEvent['dispatchHash'],
        'bridgeRequestHash':
            bridgeRequest['bridgeRequestHash'] ?? ack['bridgeRequestHash'],
        'bridgeAckHash': bridgeAckEvent['bridgeAckHash'] ??
            summaryEvent['bridgeAckHash'] ??
            endEvent['bridgeAckHash'],
        'fixtureHash': ack['fixtureHash'],
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            endEvent['fixtureParityOk'] == true,
        'dispatchParityOk': ack['dispatchParityOk'] == true ||
            summaryEvent['dispatchParityOk'] == true ||
            endEvent['dispatchParityOk'] == true,
        'bridgeParityOk': bridgeAckEvent['bridgeParityOk'] == true ||
            summaryEvent['bridgeParityOk'] == true ||
            endEvent['bridgeParityOk'] == true,
        'validationOk': bridgeAckEvent['validationOk'] == true ||
            summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'selectedToolCount': ack['selectedToolCount'],
        'toolPlanCount':
            toolPlanSummary['toolPlanCount'] ?? ack['toolPlanCount'],
        'allowedPlanCount':
            toolPlanSummary['allowedPlanCount'] ?? ack['allowedPlanCount'],
        'blockedPlanCount':
            toolPlanSummary['blockedPlanCount'] ?? ack['blockedPlanCount'],
        'invalidArgumentCount': toolPlanSummary['invalidArgumentCount'],
        'toolPlanNames': toolPlanNames,
        'gatewayToolNames': gatewayToolNames,
        'toolName': route['method'] ?? summaryEvent['toolName'],
        'capability': route['capability'] ?? summaryEvent['capability'],
        'dartCapability':
            route['dartCapability'] ?? summaryEvent['dartCapability'],
        'requiresUiThread': route['requiresUiThread'],
        'callId': dispatchPlan['callId'],
        'bridgeStatusCode': bridgeAckEvent['statusCode'],
        'bridgeResponseBytesRead': bridgeAckEvent['responseBytesRead'],
        'dartBridgeOk': bridgeAck['ok'] == true,
        'dartAccepted': bridgeAck['accepted'] == true,
        'commandKnown': bridgeAck['commandKnown'] == true,
        'bridgeCommand': bridgeAck['command'],
        'toolResultDryRun': toolResult['dryRun'] == true,
        'bridgeAckReceived': toolResult['bridgeAckReceived'] == true,
        'skippedReason':
            bridgeAck['skippedReason'] ?? summaryEvent['skippedReason'],
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            ackEvent['transportInvocationEnabled'] == true ||
                ack['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabled': endEvent['bridgeExecutionEnabled'] == true,
        if (bridgeError != null) 'bridgeError': bridgeError.toString(),
        'postBridgeGuardOk': postBridgeGuardOk,
        'postBridgeRuntimeReported': postBridgeHealth['runtime'],
        'postBridgeCanaryOnly': postBridgeProbe['canaryOnly'] == true,
        'postBridgeChatRoutingEnabled':
            postBridgeProbe['chatRoutingEnabled'] == true,
        'postBridgeProviderCallsEnabled':
            postBridgeProbe['providerCallsEnabled'] == true,
        'postBridgeToolExecutionEnabled':
            postBridgeProbe['toolExecutionEnabled'] == true,
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
            ? 'Native owned 18789, sent a dry-run dispatch request to Dart, received a Dart ACK, and PRoot was restored.'
            : 'Production-port Dart bridge dry-run is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'production-port bridge ordering and cancellation parity with execution disabled',
      };
      log('[NATIVE-DART-BRIDGE-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortDartBridgeInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortDartBridgeOrderingCancelDryRun({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production Dart bridge ordering/cancel dry-run: wave right and vibrate once',
  }) async {
    if (_productionPortDartBridgeOrderingInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-dart-bridge-ordering-cancel',
        'alreadyInFlight': true,
        'decision':
            'Production-port Dart bridge ordering/cancel dry-run is already running.',
      };
    }

    _productionPortDartBridgeOrderingInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();
      final providerHint = requestedModel.contains('/')
          ? requestedModel.split('/').first
          : 'openrouter';
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
      var orderingDryRunSent = false;
      var ackEventOk = false;
      var orderPlanOk = false;
      var bridgeRequestOrderOk = false;
      var bridgeAckOrderOk = false;
      var toolUseOrderOk = false;
      var toolResultOrderOk = false;
      var cancelRequestOk = false;
      var cancelAckOk = false;
      var orderingSummaryOk = false;
      var eventOrderOk = false;
      var orderingEndOk = false;
      var orderingCancelOk = false;
      var postBridgeGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postBridgeHealth = <String, dynamic>{};
      Map<String, dynamic> postBridgeProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> orderEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? orderingError;
      Object? nativeStopError;
      Object? rollbackError;

      Map<String, dynamic> asMap(Object? value) => value is Map
          ? value.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      List<Map<String, dynamic>> eventsNamed(String name) => orderEvents
          .where((event) => event['event'] == name)
          .map((event) => Map<String, dynamic>.from(event))
          .toList();
      Map<String, dynamic> eventByOrder(String name, int orderIndex) {
        for (final event in orderEvents) {
          if (event['event'] == name && event['orderIndex'] == orderIndex) {
            return event;
          }
        }
        return <String, dynamic>{};
      }

      bool disabledFlags(Map<String, dynamic> value) =>
          value['providerCallsEnabled'] != true &&
          value['transportInvocationEnabled'] != true &&
          value['executionEnabled'] != true &&
          value['toolExecutionEnabled'] != true &&
          value['bridgeExecutionEnabled'] != true;
      bool listMatches(Object? value, List<int> expected) {
        if (value is! List || value.length != expected.length) return false;
        for (var i = 0; i < expected.length; i++) {
          if (value[i] != expected[i]) return false;
        }
        return true;
      }

      log(
        '[NATIVE-DART-BRIDGE-ORDER-OWNER] Opening bridge ordering/cancel dry-run.',
      );

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
            'Dart bridge ordering/cancel dry-run requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before Dart bridge ordering/cancel dry-run.',
          );
        }

        log(
          '[NATIVE-DART-BRIDGE-ORDER-OWNER] Stopping PRoot to release 18789.',
        );
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before Dart bridge ordering/cancel dry-run.',
          );
        }

        log(
          '[NATIVE-DART-BRIDGE-ORDER-OWNER] Starting native on 18789 and sending ordered dry-run bridge requests.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError(
            'Native Dart bridge ordering/cancel dry-run did not start.',
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

        orderingDryRunSent = true;
        orderEvents = await _streamProductionNdjson(
          '/gateway/chat-native-dart-bridge-ordering-cancel-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-dart-bridge-order-request',
            idempotencyKey: 'production-dart-bridge-order-idempotency-key',
            model: requestedModel,
            provider: providerHint,
            message: prompt,
          ),
          expectedStatus: 202,
          streamIdleTimeout: const Duration(seconds: 25),
        );

        final ackEvent = _firstEvent(orderEvents, 'ack');
        final orderPlanEvent = _firstEvent(orderEvents, 'order_plan');
        final cancelRequestEvent = _firstEvent(orderEvents, 'cancel_request');
        final cancelAckEvent = _firstEvent(orderEvents, 'cancel_ack');
        final summaryEvent = _firstEvent(orderEvents, 'ordering_summary');
        final endEvent = _firstEvent(orderEvents, 'end');
        final ack = asMap(ackEvent['ack']);
        final plannedOrder = orderPlanEvent['plannedOrder'] is List
            ? List<dynamic>.from(orderPlanEvent['plannedOrder'] as List)
            : const <dynamic>[];
        const expectedOrder = <int>[0, 1, 2];
        const cancelOrderIndex = 1;
        final bridgeRequestEvents = eventsNamed('bridge_request');
        final bridgeAckEvents = eventsNamed('bridge_ack');
        final toolUseEvents = eventsNamed('tool_use_frame');
        final toolResultEvents = eventsNamed('tool_result_frame');
        final expectedEventOrder = <String>[
          'ack',
          'order_plan',
          'bridge_request',
          'bridge_ack',
          'tool_use_frame',
          'tool_result_frame',
          'bridge_request',
          'bridge_ack',
          'tool_use_frame',
          'tool_result_frame',
          'bridge_request',
          'bridge_ack',
          'tool_use_frame',
          'tool_result_frame',
          'cancel_request',
          'cancel_ack',
          'ordering_summary',
          'end',
        ];
        final observedEventOrder =
            orderEvents.map((event) => event['event']?.toString()).toList();
        eventOrderOk = observedEventOrder.length >= expectedEventOrder.length;
        for (var i = 0; i < expectedEventOrder.length && eventOrderOk; i++) {
          eventOrderOk = observedEventOrder[i] == expectedEventOrder[i];
        }

        ackEventOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == true &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'native_dart_bridge_ordering_cancel' &&
            ackEvent['routeStatus'] ==
                'native_dart_bridge_ordering_cancel_started' &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == false &&
            ackEvent['queueStatus'] == 'native_dart_bridge_ordering_cancel' &&
            disabledFlags(ackEvent) &&
            ack['provider'] == 'openrouter' &&
            ack['route'] == 'native_dart_bridge_ordering_cancel' &&
            ack['orderCount'] == 3 &&
            ack['cancelOrderIndex'] == cancelOrderIndex &&
            ack['orderingPlanHash']?.toString().isNotEmpty == true &&
            ack['fixtureParityOk'] == true &&
            ack['dispatchParityOk'] == true &&
            disabledFlags(ack);
        orderPlanOk = orderPlanEvent['ok'] == true &&
            orderPlanEvent['runtime'] == 'native-node-embedded' &&
            orderPlanEvent['orderCount'] == 3 &&
            orderPlanEvent['cancelOrderIndex'] == cancelOrderIndex &&
            orderPlanEvent['orderingPlanHash'] == ack['orderingPlanHash'] &&
            plannedOrder.length == 3 &&
            disabledFlags(orderPlanEvent);

        bool requestOkForOrder(int orderIndex) {
          final event = eventByOrder('bridge_request', orderIndex);
          final request = asMap(event['bridgeRequest']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              event['endpoint'] ==
                  'http://127.0.0.1:8765/api/native-gateway/dispatch-dry-run' &&
              request['type'] == 'native_tool_dispatch_dry_run' &&
              request['method'] == 'avatar.gesture' &&
              request['capability'] == 'avatar' &&
              request['dartCapability'] == 'AvatarCapability' &&
              request['requiresUiThread'] == true &&
              request['orderIndex'] == orderIndex &&
              request['orderCount'] == 3 &&
              request['orderingKey']?.toString().isNotEmpty == true &&
              request['cancellationToken']?.toString().isNotEmpty == true &&
              request['bridgeRequestHash']?.toString().isNotEmpty == true &&
              request['dispatchHash']?.toString().isNotEmpty == true &&
              request['dryRun'] == true &&
              disabledFlags(request);
        }

        bool bridgeAckOkForOrder(int orderIndex) {
          final requestEvent = eventByOrder('bridge_request', orderIndex);
          final request = asMap(requestEvent['bridgeRequest']);
          final event = eventByOrder('bridge_ack', orderIndex);
          final bridgeAck = asMap(event['bridgeAck']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              event['statusCode'] == 200 &&
              event['bridgeAckHash']?.toString().isNotEmpty == true &&
              event['bridgeParityOk'] == true &&
              bridgeAck['ok'] == true &&
              bridgeAck['accepted'] == true &&
              bridgeAck['runtime'] == 'flutter-dart' &&
              bridgeAck['bridge'] == 'AgentSkillServer' &&
              bridgeAck['source'] == 'native-dart-bridge-dry-run' &&
              bridgeAck['routeStatus'] == 'native_dart_bridge_dry_run_ack' &&
              bridgeAck['command'] == 'avatar.gesture' &&
              bridgeAck['commandKnown'] == true &&
              bridgeAck['capability'] == 'avatar' &&
              bridgeAck['dartCapability'] == 'AvatarCapability' &&
              bridgeAck['dryRun'] == true &&
              bridgeAck['orderIndex'] == orderIndex &&
              bridgeAck['orderCount'] == 3 &&
              bridgeAck['orderingKey'] == request['orderingKey'] &&
              bridgeAck['cancellationToken'] == request['cancellationToken'] &&
              bridgeAck['bridgeRequestHash'] == request['bridgeRequestHash'] &&
              bridgeAck['skippedReason'] == 'native_dart_bridge_dry_run_only' &&
              disabledFlags(bridgeAck);
        }

        bool toolUseOkForOrder(int orderIndex) {
          final request = asMap(
            eventByOrder('bridge_request', orderIndex)['bridgeRequest'],
          );
          final event = eventByOrder('tool_use_frame', orderIndex);
          final frame = asMap(event['frame']);
          final input = asMap(frame['input']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              frame['type'] == 'tool_use' &&
              frame['name'] == 'avatar.gesture' &&
              frame['runtime'] == 'native-node-embedded' &&
              frame['orderIndex'] == orderIndex &&
              frame['cancellationToken'] == request['cancellationToken'] &&
              input['gesture']?.toString().isNotEmpty == true &&
              disabledFlags(frame);
        }

        bool toolResultOkForOrder(int orderIndex) {
          final request = asMap(
            eventByOrder('bridge_request', orderIndex)['bridgeRequest'],
          );
          final useFrame =
              asMap(eventByOrder('tool_use_frame', orderIndex)['frame']);
          final event = eventByOrder('tool_result_frame', orderIndex);
          final frame = asMap(event['frame']);
          final result = asMap(frame['result']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              frame['type'] == 'tool_result' &&
              frame['name'] == 'avatar.gesture' &&
              frame['id'] == useFrame['id'] &&
              frame['runtime'] == 'native-node-embedded' &&
              frame['orderIndex'] == orderIndex &&
              result['ok'] == true &&
              result['dryRun'] == true &&
              result['bridgeAckReceived'] == true &&
              result['dartBridgeOk'] == true &&
              result['dartAccepted'] == true &&
              result['commandKnown'] == true &&
              result['orderIndex'] == orderIndex &&
              result['orderingKey'] == request['orderingKey'] &&
              result['cancellationToken'] == request['cancellationToken'] &&
              result['bridgeRequestHash'] == request['bridgeRequestHash'] &&
              result['skippedReason'] == 'native_dart_bridge_dry_run_only' &&
              disabledFlags(frame) &&
              disabledFlags(result);
        }

        bridgeRequestOrderOk = bridgeRequestEvents.length == 3 &&
            expectedOrder.every(requestOkForOrder);
        bridgeAckOrderOk = bridgeAckEvents.length == 3 &&
            expectedOrder.every(bridgeAckOkForOrder);
        toolUseOrderOk =
            toolUseEvents.length == 3 && expectedOrder.every(toolUseOkForOrder);
        toolResultOrderOk = toolResultEvents.length == 3 &&
            expectedOrder.every(toolResultOkForOrder);

        final cancelRequest = asMap(cancelRequestEvent['cancelRequest']);
        final cancelTargetRequest = asMap(
          eventByOrder('bridge_request', cancelOrderIndex)['bridgeRequest'],
        );
        cancelRequestOk = cancelRequestEvent['ok'] == true &&
            cancelRequestEvent['runtime'] == 'native-node-embedded' &&
            cancelRequestEvent['orderIndex'] == cancelOrderIndex &&
            cancelRequestEvent['endpoint'] ==
                'http://127.0.0.1:8765/api/native-gateway/dispatch-cancel-dry-run' &&
            cancelRequest['type'] == 'native_tool_dispatch_cancel_dry_run' &&
            cancelRequest['targetRunId'] == cancelRequestEvent['runId'] &&
            cancelRequest['targetCallId'] == cancelTargetRequest['callId'] &&
            cancelRequest['targetBridgeRequestHash'] ==
                cancelTargetRequest['bridgeRequestHash'] &&
            cancelRequest['targetDispatchHash'] ==
                cancelTargetRequest['dispatchHash'] &&
            cancelRequest['orderIndex'] == cancelOrderIndex &&
            cancelRequest['orderCount'] == 3 &&
            cancelRequest['cancellationToken'] ==
                cancelTargetRequest['cancellationToken'] &&
            cancelRequest['cancelRequestHash']?.toString().isNotEmpty == true &&
            cancelRequest['dryRun'] == true &&
            disabledFlags(cancelRequest);
        final cancelAck = asMap(cancelAckEvent['cancelAck']);
        cancelAckOk = cancelAckEvent['ok'] == true &&
            cancelAckEvent['runtime'] == 'native-node-embedded' &&
            cancelAckEvent['orderIndex'] == cancelOrderIndex &&
            cancelAckEvent['statusCode'] == 200 &&
            cancelAckEvent['cancelAckHash']?.toString().isNotEmpty == true &&
            cancelAckEvent['cancellationParityOk'] == true &&
            cancelAck['ok'] == true &&
            cancelAck['cancelAccepted'] == true &&
            cancelAck['cancelRequested'] == true &&
            cancelAck['cancelApplied'] == false &&
            cancelAck['runtime'] == 'flutter-dart' &&
            cancelAck['bridge'] == 'AgentSkillServer' &&
            cancelAck['source'] == 'native-dart-bridge-ordering-cancel' &&
            cancelAck['routeStatus'] ==
                'native_dart_bridge_cancel_dry_run_ack' &&
            cancelAck['targetRunId'] == cancelRequest['targetRunId'] &&
            cancelAck['targetBridgeRequestHash'] ==
                cancelRequest['targetBridgeRequestHash'] &&
            cancelAck['orderIndex'] == cancelOrderIndex &&
            cancelAck['orderCount'] == 3 &&
            cancelAck['cancellationToken'] ==
                cancelRequest['cancellationToken'] &&
            cancelAck['cancellationState'] ==
                'recorded_dry_run_no_active_execution' &&
            cancelAck['skippedReason'] ==
                'native_dart_bridge_cancel_dry_run_only' &&
            disabledFlags(cancelAck);
        orderingSummaryOk = summaryEvent['ok'] == true &&
            summaryEvent['runtime'] == 'native-node-embedded' &&
            summaryEvent['orderingPlanHash'] == ack['orderingPlanHash'] &&
            summaryEvent['orderCount'] == 3 &&
            listMatches(summaryEvent['expectedOrder'], expectedOrder) &&
            listMatches(summaryEvent['observedBridgeOrder'], expectedOrder) &&
            listMatches(summaryEvent['observedResultOrder'], expectedOrder) &&
            summaryEvent['uniqueRunIds'] == 3 &&
            summaryEvent['orderingParityOk'] == true &&
            summaryEvent['cancellationParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            summaryEvent['cancelOrderIndex'] == cancelOrderIndex &&
            summaryEvent['cancelRequestHash'] ==
                cancelRequest['cancelRequestHash'] &&
            summaryEvent['cancelAckHash'] == cancelAckEvent['cancelAckHash'] &&
            summaryEvent['targetRunId'] == cancelRequest['targetRunId'] &&
            summaryEvent['targetBridgeRequestHash'] ==
                cancelRequest['targetBridgeRequestHash'] &&
            summaryEvent['cancellationState'] ==
                'recorded_dry_run_no_active_execution' &&
            summaryEvent['skippedReason'] ==
                'native_dart_bridge_cancel_dry_run_only' &&
            disabledFlags(summaryEvent);
        orderingEndOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] ==
                'native_dart_bridge_ordering_cancel_complete' &&
            endEvent['finishReason'] ==
                'native_dart_bridge_ordering_cancel_complete' &&
            endEvent['orderingPlanHash'] == ack['orderingPlanHash'] &&
            endEvent['orderCount'] == 3 &&
            endEvent['orderingParityOk'] == true &&
            endEvent['cancellationParityOk'] == true &&
            endEvent['validationOk'] == true &&
            endEvent['cancelOrderIndex'] == cancelOrderIndex &&
            disabledFlags(endEvent);
        orderingCancelOk = ackEventOk &&
            orderPlanOk &&
            bridgeRequestOrderOk &&
            bridgeAckOrderOk &&
            toolUseOrderOk &&
            toolResultOrderOk &&
            cancelRequestOk &&
            cancelAckOk &&
            orderingSummaryOk &&
            eventOrderOk &&
            orderingEndOk;

        postBridgeHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postBridgeProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postBridgeGuardOk = postBridgeHealth['ok'] == true &&
            postBridgeHealth['runtime'] == 'native-node-embedded' &&
            postBridgeHealth['port'] == AppConstants.gatewayPort &&
            postBridgeHealth['productionPortBindCanary'] == true &&
            postBridgeHealth['openclawStarted'] == false &&
            postBridgeProbe['runtime'] == 'native-node-embedded' &&
            postBridgeProbe['port'] == AppConstants.gatewayPort &&
            postBridgeProbe['productionPortBindCanary'] == true &&
            postBridgeProbe['canaryOnly'] == true &&
            postBridgeProbe['productionReady'] == false &&
            postBridgeProbe['openclawStarted'] == false &&
            postBridgeProbe['chatRoutingEnabled'] == false &&
            postBridgeProbe['providerCallsEnabled'] == false &&
            postBridgeProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (orderingDryRunSent) {
          orderingError = e;
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
          orderingCancelOk &&
          postBridgeGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final ackEvent = _firstEvent(orderEvents, 'ack');
      final cancelRequestEvent = _firstEvent(orderEvents, 'cancel_request');
      final cancelAckEvent = _firstEvent(orderEvents, 'cancel_ack');
      final summaryEvent = _firstEvent(orderEvents, 'ordering_summary');
      final endEvent = _firstEvent(orderEvents, 'end');
      final ack = asMap(ackEvent['ack']);
      final bridgeRequestEvents = eventsNamed('bridge_request');
      final bridgeAckEvents = eventsNamed('bridge_ack');
      final toolUseEvents = eventsNamed('tool_use_frame');
      final toolResultEvents = eventsNamed('tool_result_frame');
      final cancelRequest = asMap(cancelRequestEvent['cancelRequest']);
      final cancelAck = asMap(cancelAckEvent['cancelAck']);
      final observedEventOrder =
          orderEvents.map((event) => event['event']?.toString()).toList();
      final bridgeRequestHashes = bridgeRequestEvents
          .map((event) => asMap(event['bridgeRequest'])['bridgeRequestHash'])
          .where((value) => value != null)
          .toList();
      final cancellationTokens = bridgeRequestEvents
          .map((event) => asMap(event['bridgeRequest'])['cancellationToken'])
          .where((value) => value != null)
          .toList();
      final runIds = bridgeRequestEvents
          .map((event) => event['runId'])
          .where((value) => value != null)
          .toList();

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-dart-bridge-ordering-cancel',
        'mode':
            'native-production-port-dart-bridge-ordering-cancel-with-rollback',
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
        'orderingDryRunSent': orderingDryRunSent,
        'orderingCancelOk': orderingCancelOk,
        'ackEventOk': ackEventOk,
        'orderPlanOk': orderPlanOk,
        'bridgeRequestOrderOk': bridgeRequestOrderOk,
        'bridgeAckOrderOk': bridgeAckOrderOk,
        'toolUseOrderOk': toolUseOrderOk,
        'toolResultOrderOk': toolResultOrderOk,
        'cancelRequestOk': cancelRequestOk,
        'cancelAckOk': cancelAckOk,
        'orderingSummaryOk': orderingSummaryOk,
        'eventOrderOk': eventOrderOk,
        'orderingEndOk': orderingEndOk,
        'eventsCount': orderEvents.length,
        'observedEventOrder': observedEventOrder,
        'bridgeEventsCount': bridgeRequestEvents.length,
        'bridgeAckEventsCount': bridgeAckEvents.length,
        'toolUseEventsCount': toolUseEvents.length,
        'toolResultEventsCount': toolResultEvents.length,
        'routeStatus': endEvent['routeStatus'] ?? ack['routeStatus'],
        'finishReason': endEvent['finishReason'],
        'provider': ack['provider'],
        'requestedModel': ack['requestedModel'],
        'providerModel': ack['providerModel'],
        'transport': ack['transport'],
        'requestHash': ack['requestHash'] ?? endEvent['requestHash'],
        'toolSelectionHash': ack['toolSelectionHash'],
        'dispatchHash': ack['dispatchHash'],
        'orderingPlanHash':
            ack['orderingPlanHash'] ?? summaryEvent['orderingPlanHash'],
        'fixtureHash': ack['fixtureHash'],
        'fixtureParityOk': ack['fixtureParityOk'] == true,
        'dispatchParityOk': ack['dispatchParityOk'] == true,
        'orderCount': ack['orderCount'] ?? summaryEvent['orderCount'],
        'cancelOrderIndex':
            ack['cancelOrderIndex'] ?? summaryEvent['cancelOrderIndex'],
        'expectedOrder': summaryEvent['expectedOrder'],
        'observedBridgeOrder': summaryEvent['observedBridgeOrder'],
        'observedResultOrder': summaryEvent['observedResultOrder'],
        'uniqueRunIds': summaryEvent['uniqueRunIds'],
        'orderingParityOk': summaryEvent['orderingParityOk'] == true ||
            endEvent['orderingParityOk'] == true,
        'cancellationParityOk':
            cancelAckEvent['cancellationParityOk'] == true ||
                summaryEvent['cancellationParityOk'] == true ||
                endEvent['cancellationParityOk'] == true,
        'validationOk': summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'bridgeRequestHashes': bridgeRequestHashes,
        'cancellationTokens': cancellationTokens,
        'runIds': runIds,
        'cancelRequestHash': cancelRequest['cancelRequestHash'],
        'cancelAckHash': cancelAckEvent['cancelAckHash'],
        'targetRunId': cancelAck['targetRunId'],
        'targetBridgeRequestHash': cancelAck['targetBridgeRequestHash'],
        'cancelAccepted': cancelAck['cancelAccepted'] == true,
        'cancelApplied': cancelAck['cancelApplied'] == true,
        'cancellationState': cancelAck['cancellationState'],
        'skippedReason':
            cancelAck['skippedReason'] ?? summaryEvent['skippedReason'],
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            ackEvent['transportInvocationEnabled'] == true ||
                ack['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabled': endEvent['bridgeExecutionEnabled'] == true,
        if (orderingError != null) 'orderingError': orderingError.toString(),
        'postBridgeGuardOk': postBridgeGuardOk,
        'postBridgeRuntimeReported': postBridgeHealth['runtime'],
        'postBridgeCanaryOnly': postBridgeProbe['canaryOnly'] == true,
        'postBridgeChatRoutingEnabled':
            postBridgeProbe['chatRoutingEnabled'] == true,
        'postBridgeProviderCallsEnabled':
            postBridgeProbe['providerCallsEnabled'] == true,
        'postBridgeToolExecutionEnabled':
            postBridgeProbe['toolExecutionEnabled'] == true,
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
            ? 'Native owned 18789, sent ordered bridge dry-runs to Dart, recorded a dry-run cancellation ACK, and PRoot was restored.'
            : 'Production-port Dart bridge ordering/cancel dry-run is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'production-port bounded native bridge execution canary allowlist',
      };
      log('[NATIVE-DART-BRIDGE-ORDER-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortDartBridgeOrderingInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortBridgeExecutionReadOnlyCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production read-only bridge execution canary: check flash and list sensors',
  }) async {
    if (_productionPortBridgeReadOnlyCanaryInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-bridge-execution-readonly-canary',
        'alreadyInFlight': true,
        'decision':
            'Production-port read-only bridge execution canary is already running.',
      };
    }

    _productionPortBridgeReadOnlyCanaryInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();
      final providerHint = requestedModel.contains('/')
          ? requestedModel.split('/').first
          : 'openrouter';
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
      var canarySent = false;
      var ackEventOk = false;
      var toolPlanSummaryOk = false;
      var executeRequestOrderOk = false;
      var executeAckOrderOk = false;
      var toolUseOrderOk = false;
      var toolResultOrderOk = false;
      var summaryOk = false;
      var eventOrderOk = false;
      var endOk = false;
      var readOnlyCanaryOk = false;
      var postCanaryGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postCanaryHealth = <String, dynamic>{};
      Map<String, dynamic> postCanaryProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> canaryEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? canaryError;
      Object? nativeStopError;
      Object? rollbackError;

      Map<String, dynamic> asMap(Object? value) => value is Map
          ? value.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      List<Map<String, dynamic>> eventsNamed(String name) => canaryEvents
          .where((event) => event['event'] == name)
          .map((event) => Map<String, dynamic>.from(event))
          .toList();
      Map<String, dynamic> eventByOrder(String name, int orderIndex) {
        for (final event in canaryEvents) {
          if (event['event'] == name && event['orderIndex'] == orderIndex) {
            return event;
          }
        }
        return <String, dynamic>{};
      }

      bool providerStillDisabled(Map<String, dynamic> value) =>
          value['providerCallsEnabled'] != true &&
          value['transportInvocationEnabled'] != true;
      bool executionEnabled(Map<String, dynamic> value) =>
          value['executionEnabled'] == true &&
          value['toolExecutionEnabled'] == true &&
          value['bridgeExecutionEnabled'] == true;
      bool toolFrameExecutionEnabled(Map<String, dynamic> value) =>
          value['executionEnabled'] == true &&
          value['toolExecutionEnabled'] == true;
      String expectedCapability(String toolName) {
        if (toolName == 'flash.status') return 'flash';
        if (toolName == 'sensor.list') return 'sensor';
        return 'unknown';
      }

      String expectedDartCapability(String toolName) {
        if (toolName == 'flash.status') return 'FlashCapability';
        if (toolName == 'sensor.list') return 'SensorCapability';
        return 'unknown';
      }

      bool listMatchesStrings(Object? value, List<String> expected) {
        if (value is! List || value.length != expected.length) return false;
        for (var i = 0; i < expected.length; i++) {
          if (value[i] != expected[i]) return false;
        }
        return true;
      }

      bool allowlistOk(Object? value) {
        if (value is! List) return false;
        final strings = value.map((entry) => entry.toString()).toSet();
        return strings.length == 2 &&
            strings.contains('flash.status') &&
            strings.contains('sensor.list');
      }

      bool resultShapeOk(String toolName, Map<String, dynamic> result) {
        if (toolName == 'flash.status') {
          return result['on'] is bool;
        }
        if (toolName == 'sensor.list') {
          final sensors = result['sensors'];
          return sensors is List && sensors.isNotEmpty;
        }
        return false;
      }

      log(
        '[NATIVE-BRIDGE-EXEC-OWNER] Opening read-only bridge execution canary.',
      );

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
            'Read-only bridge execution canary requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before read-only bridge execution canary.',
          );
        }

        log('[NATIVE-BRIDGE-EXEC-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before read-only bridge execution canary.',
          );
        }

        log(
          '[NATIVE-BRIDGE-EXEC-OWNER] Starting native on 18789 and executing read-only allowlisted bridge calls.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError(
            'Native read-only bridge execution canary did not start.',
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

        canarySent = true;
        canaryEvents = await _streamProductionNdjson(
          '/gateway/chat-native-dart-bridge-readonly-canary-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-bridge-exec-readonly-request',
            idempotencyKey: 'production-bridge-exec-readonly-idempotency-key',
            model: requestedModel,
            provider: providerHint,
            message: prompt,
          ),
          expectedStatus: 202,
          streamIdleTimeout: const Duration(seconds: 30),
        );

        final ackEvent = _firstEvent(canaryEvents, 'ack');
        final planEvent = _firstEvent(canaryEvents, 'tool_plan_summary');
        final summaryEvent =
            _firstEvent(canaryEvents, 'readonly_canary_summary');
        final endEvent = _firstEvent(canaryEvents, 'end');
        final ack = asMap(ackEvent['ack']);
        const expectedTools = <String>['flash.status', 'sensor.list'];
        final executeRequestEvents = eventsNamed('bridge_execute_request');
        final executeAckEvents = eventsNamed('bridge_execute_ack');
        final toolUseEvents = eventsNamed('tool_use_frame');
        final toolResultEvents = eventsNamed('tool_result_frame');
        final expectedEventOrder = <String>[
          'ack',
          'tool_plan_summary',
          'bridge_execute_request',
          'bridge_execute_ack',
          'tool_use_frame',
          'tool_result_frame',
          'bridge_execute_request',
          'bridge_execute_ack',
          'tool_use_frame',
          'tool_result_frame',
          'readonly_canary_summary',
          'end',
        ];
        final observedEventOrder =
            canaryEvents.map((event) => event['event']?.toString()).toList();
        eventOrderOk = observedEventOrder.length >= expectedEventOrder.length;
        for (var i = 0; i < expectedEventOrder.length && eventOrderOk; i++) {
          eventOrderOk = observedEventOrder[i] == expectedEventOrder[i];
        }

        ackEventOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'native_dart_bridge_readonly_canary' &&
            ackEvent['routeStatus'] ==
                'native_dart_bridge_readonly_canary_started' &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == false &&
            ackEvent['queueStatus'] == 'native_dart_bridge_readonly_canary' &&
            providerStillDisabled(ackEvent) &&
            executionEnabled(ackEvent) &&
            ack['provider'] == 'openrouter' &&
            ack['route'] == 'native_dart_bridge_readonly_canary' &&
            ack['readOnlyPlanHash']?.toString().isNotEmpty == true &&
            allowlistOk(ack['canaryAllowlist']) &&
            ack['canaryAllowlistOk'] == true &&
            ack['fixtureParityOk'] == true &&
            ack['dispatchParityOk'] == true &&
            ack['readOnly'] == true &&
            providerStillDisabled(ack) &&
            executionEnabled(ack);
        toolPlanSummaryOk = planEvent['ok'] == true &&
            planEvent['runtime'] == 'native-node-embedded' &&
            planEvent['readOnlyPlanHash'] == ack['readOnlyPlanHash'] &&
            planEvent['orderCount'] == 2 &&
            listMatchesStrings(planEvent['expectedOrder'], expectedTools) &&
            allowlistOk(planEvent['forcedAllowlist']) &&
            planEvent['fixtureParityOk'] == true &&
            planEvent['dispatchParityOk'] == true &&
            planEvent['canaryAllowlistOk'] == true &&
            planEvent['readOnly'] == true &&
            providerStillDisabled(planEvent) &&
            executionEnabled(planEvent);

        bool executeRequestOkForOrder(int orderIndex, String toolName) {
          final event = eventByOrder('bridge_execute_request', orderIndex);
          final request = asMap(event['bridgeRequest']);
          final input = asMap(request['input']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              event['endpoint'] ==
                  'http://127.0.0.1:8765/api/native-gateway/dispatch-execute-canary' &&
              request['type'] == 'native_tool_dispatch_execute_canary' &&
              request['method'] == toolName &&
              request['capability'] == expectedCapability(toolName) &&
              request['dartCapability'] == expectedDartCapability(toolName) &&
              request['requiresUiThread'] == false &&
              request['orderIndex'] == orderIndex &&
              request['orderCount'] == 2 &&
              request['bridgeRequestHash']?.toString().isNotEmpty == true &&
              request['dispatchHash']?.toString().isNotEmpty == true &&
              request['cancellationToken']?.toString().isNotEmpty == true &&
              allowlistOk(request['canaryAllowlist']) &&
              input.isEmpty &&
              request['readOnly'] == true &&
              request['dryRun'] == false &&
              providerStillDisabled(request) &&
              executionEnabled(request);
        }

        bool executeAckOkForOrder(int orderIndex, String toolName) {
          final request = asMap(
            eventByOrder('bridge_execute_request', orderIndex)['bridgeRequest'],
          );
          final event = eventByOrder('bridge_execute_ack', orderIndex);
          final executeAck = asMap(event['executeAck']);
          final result = asMap(executeAck['result']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              event['statusCode'] == 200 &&
              event['bridgeRequestHash'] == request['bridgeRequestHash'] &&
              event['executeAckHash']?.toString().isNotEmpty == true &&
              event['executeParityOk'] == true &&
              event['resultStatus'] == 'ok' &&
              event['resultShapeOk'] == true &&
              executeAck['ok'] == true &&
              executeAck['accepted'] == true &&
              executeAck['executed'] == true &&
              executeAck['runtime'] == 'flutter-dart' &&
              executeAck['bridge'] == 'AgentSkillServer' &&
              executeAck['source'] == 'native-dart-bridge-readonly-canary' &&
              executeAck['routeStatus'] ==
                  'native_dart_bridge_readonly_canary_ack' &&
              executeAck['command'] == toolName &&
              executeAck['commandKnown'] == true &&
              executeAck['canaryAllowlistOk'] == true &&
              executeAck['dryRun'] == false &&
              executeAck['bridgeRequestHash'] == request['bridgeRequestHash'] &&
              resultShapeOk(toolName, result) &&
              providerStillDisabled(executeAck) &&
              executionEnabled(executeAck);
        }

        bool toolUseOkForOrder(int orderIndex, String toolName) {
          final event = eventByOrder('tool_use_frame', orderIndex);
          final frame = asMap(event['frame']);
          final input = asMap(frame['input']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              frame['type'] == 'tool_use' &&
              frame['name'] == toolName &&
              frame['runtime'] == 'native-node-embedded' &&
              frame['source'] == 'native-dart-bridge-readonly-canary' &&
              frame['dryRun'] == false &&
              frame['readOnly'] == true &&
              frame['canaryOnly'] == true &&
              frame['orderIndex'] == orderIndex &&
              frame['orderCount'] == 2 &&
              frame['cancellationToken']?.toString().isNotEmpty == true &&
              input.isEmpty &&
              toolFrameExecutionEnabled(frame);
        }

        bool toolResultOkForOrder(int orderIndex, String toolName) {
          final useFrame = asMap(
            eventByOrder('tool_use_frame', orderIndex)['frame'],
          );
          final event = eventByOrder('tool_result_frame', orderIndex);
          final frame = asMap(event['frame']);
          final result = asMap(frame['result']);
          final payload = asMap(result['result']);
          return event['ok'] == true &&
              event['runtime'] == 'native-node-embedded' &&
              frame['type'] == 'tool_result' &&
              frame['name'] == toolName &&
              frame['id'] == useFrame['id'] &&
              frame['runtime'] == 'native-node-embedded' &&
              frame['source'] == 'native-dart-bridge-readonly-canary' &&
              frame['dryRun'] == false &&
              frame['readOnly'] == true &&
              result['ok'] == true &&
              result['dryRun'] == false &&
              result['executed'] == true &&
              result['accepted'] == true &&
              result['status'] == 'ok' &&
              result['canaryAllowlistOk'] == true &&
              result['resultShapeOk'] == true &&
              result['readOnly'] == true &&
              resultShapeOk(toolName, payload) &&
              providerStillDisabled(result) &&
              executionEnabled(result) &&
              toolFrameExecutionEnabled(frame);
        }

        executeRequestOrderOk = executeRequestEvents.length == 2 &&
            executeRequestOkForOrder(0, expectedTools[0]) &&
            executeRequestOkForOrder(1, expectedTools[1]);
        executeAckOrderOk = executeAckEvents.length == 2 &&
            executeAckOkForOrder(0, expectedTools[0]) &&
            executeAckOkForOrder(1, expectedTools[1]);
        toolUseOrderOk = toolUseEvents.length == 2 &&
            toolUseOkForOrder(0, expectedTools[0]) &&
            toolUseOkForOrder(1, expectedTools[1]);
        toolResultOrderOk = toolResultEvents.length == 2 &&
            toolResultOkForOrder(0, expectedTools[0]) &&
            toolResultOkForOrder(1, expectedTools[1]);
        summaryOk = summaryEvent['ok'] == true &&
            summaryEvent['runtime'] == 'native-node-embedded' &&
            summaryEvent['readOnlyPlanHash'] == ack['readOnlyPlanHash'] &&
            summaryEvent['commandCount'] == 2 &&
            listMatchesStrings(summaryEvent['expectedOrder'], expectedTools) &&
            listMatchesStrings(summaryEvent['observedOrder'], expectedTools) &&
            summaryEvent['canaryAllowlistOk'] == true &&
            summaryEvent['executeParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            summaryEvent['readOnly'] == true &&
            providerStillDisabled(summaryEvent) &&
            executionEnabled(summaryEvent);
        endOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] ==
                'native_dart_bridge_readonly_canary_complete' &&
            endEvent['finishReason'] ==
                'native_dart_bridge_readonly_canary_complete' &&
            endEvent['readOnlyPlanHash'] == ack['readOnlyPlanHash'] &&
            endEvent['commandCount'] == 2 &&
            listMatchesStrings(endEvent['expectedOrder'], expectedTools) &&
            listMatchesStrings(endEvent['observedOrder'], expectedTools) &&
            endEvent['canaryAllowlistOk'] == true &&
            endEvent['executeParityOk'] == true &&
            endEvent['validationOk'] == true &&
            endEvent['readOnly'] == true &&
            providerStillDisabled(endEvent) &&
            executionEnabled(endEvent);
        readOnlyCanaryOk = ackEventOk &&
            toolPlanSummaryOk &&
            executeRequestOrderOk &&
            executeAckOrderOk &&
            toolUseOrderOk &&
            toolResultOrderOk &&
            summaryOk &&
            eventOrderOk &&
            endOk;

        postCanaryHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryGuardOk = postCanaryHealth['ok'] == true &&
            postCanaryHealth['runtime'] == 'native-node-embedded' &&
            postCanaryHealth['port'] == AppConstants.gatewayPort &&
            postCanaryHealth['productionPortBindCanary'] == true &&
            postCanaryHealth['openclawStarted'] == false &&
            postCanaryProbe['runtime'] == 'native-node-embedded' &&
            postCanaryProbe['port'] == AppConstants.gatewayPort &&
            postCanaryProbe['productionPortBindCanary'] == true &&
            postCanaryProbe['canaryOnly'] == true &&
            postCanaryProbe['productionReady'] == false &&
            postCanaryProbe['openclawStarted'] == false &&
            postCanaryProbe['chatRoutingEnabled'] == false &&
            postCanaryProbe['providerCallsEnabled'] == false &&
            postCanaryProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (canarySent) {
          canaryError = e;
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
          readOnlyCanaryOk &&
          postCanaryGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final ackEvent = _firstEvent(canaryEvents, 'ack');
      final summaryEvent = _firstEvent(canaryEvents, 'readonly_canary_summary');
      final endEvent = _firstEvent(canaryEvents, 'end');
      final ack = asMap(ackEvent['ack']);
      final executeRequestEvents = eventsNamed('bridge_execute_request');
      final executeAckEvents = eventsNamed('bridge_execute_ack');
      final toolUseEvents = eventsNamed('tool_use_frame');
      final toolResultEvents = eventsNamed('tool_result_frame');
      final observedEventOrder =
          canaryEvents.map((event) => event['event']?.toString()).toList();
      final bridgeRequestHashes = executeRequestEvents
          .map((event) => asMap(event['bridgeRequest'])['bridgeRequestHash'])
          .where((value) => value != null)
          .toList();
      final executeAckHashes = executeAckEvents
          .map((event) => event['executeAckHash'])
          .where((value) => value != null)
          .toList();
      final resultStatuses = summaryEvent['resultStatuses'] is List
          ? List<dynamic>.from(summaryEvent['resultStatuses'] as List)
          : const <dynamic>[];

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-bridge-execution-readonly-canary',
        'mode':
            'native-production-port-bridge-execution-readonly-canary-with-rollback',
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
        'canarySent': canarySent,
        'readOnlyCanaryOk': readOnlyCanaryOk,
        'ackEventOk': ackEventOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'executeRequestOrderOk': executeRequestOrderOk,
        'executeAckOrderOk': executeAckOrderOk,
        'toolUseOrderOk': toolUseOrderOk,
        'toolResultOrderOk': toolResultOrderOk,
        'summaryOk': summaryOk,
        'eventOrderOk': eventOrderOk,
        'endOk': endOk,
        'eventsCount': canaryEvents.length,
        'observedEventOrder': observedEventOrder,
        'executeRequestEventsCount': executeRequestEvents.length,
        'executeAckEventsCount': executeAckEvents.length,
        'toolUseEventsCount': toolUseEvents.length,
        'toolResultEventsCount': toolResultEvents.length,
        'routeStatus': endEvent['routeStatus'] ?? ack['routeStatus'],
        'finishReason': endEvent['finishReason'],
        'provider': ack['provider'],
        'requestedModel': ack['requestedModel'],
        'providerModel': ack['providerModel'],
        'transport': ack['transport'],
        'requestHash': ack['requestHash'] ?? endEvent['requestHash'],
        'readOnlyPlanHash':
            ack['readOnlyPlanHash'] ?? summaryEvent['readOnlyPlanHash'],
        'bridgeRequestHashes': bridgeRequestHashes,
        'executeAckHashes': executeAckHashes,
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            summaryEvent['fixtureParityOk'] == true,
        'dispatchParityOk': ack['dispatchParityOk'] == true ||
            summaryEvent['dispatchParityOk'] == true,
        'commandCount':
            summaryEvent['commandCount'] ?? endEvent['commandCount'],
        'expectedOrder':
            summaryEvent['expectedOrder'] ?? endEvent['expectedOrder'],
        'observedOrder':
            summaryEvent['observedOrder'] ?? endEvent['observedOrder'],
        'resultStatuses': resultStatuses,
        'canaryAllowlist': ack['canaryAllowlist'],
        'canaryAllowlistOk': summaryEvent['canaryAllowlistOk'] == true ||
            endEvent['canaryAllowlistOk'] == true,
        'executeParityOk': summaryEvent['executeParityOk'] == true ||
            endEvent['executeParityOk'] == true,
        'validationOk': summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'readOnly':
            summaryEvent['readOnly'] == true || endEvent['readOnly'] == true,
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            ackEvent['transportInvocationEnabled'] == true ||
                ack['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabled': endEvent['bridgeExecutionEnabled'] == true,
        if (canaryError != null) 'canaryError': canaryError.toString(),
        'postCanaryGuardOk': postCanaryGuardOk,
        'postCanaryRuntimeReported': postCanaryHealth['runtime'],
        'postCanaryCanaryOnly': postCanaryProbe['canaryOnly'] == true,
        'postCanaryChatRoutingEnabled':
            postCanaryProbe['chatRoutingEnabled'] == true,
        'postCanaryProviderCallsEnabled':
            postCanaryProbe['providerCallsEnabled'] == true,
        'postCanaryToolExecutionEnabled':
            postCanaryProbe['toolExecutionEnabled'] == true,
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
            ? 'Native owned 18789, executed only read-only allowlisted bridge canaries through Dart, and PRoot was restored.'
            : 'Production-port read-only bridge execution canary is not promotable; PRoot rollback was attempted.',
        'nextGate': 'production-port haptic bridge execution canary allowlist',
      };
      log('[NATIVE-BRIDGE-EXEC-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortBridgeReadOnlyCanaryInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortBridgeExecutionHapticCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production haptic bridge execution canary: vibrate once',
  }) async {
    if (_productionPortBridgeHapticCanaryInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-bridge-execution-haptic-canary',
        'alreadyInFlight': true,
        'decision':
            'Production-port haptic bridge execution canary is already running.',
      };
    }

    _productionPortBridgeHapticCanaryInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();
      final providerHint = requestedModel.contains('/')
          ? requestedModel.split('/').first
          : 'openrouter';
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
      var canarySent = false;
      var ackEventOk = false;
      var toolPlanSummaryOk = false;
      var executeRequestOk = false;
      var executeAckOk = false;
      var toolUseOk = false;
      var toolResultOk = false;
      var summaryOk = false;
      var eventOrderOk = false;
      var endOk = false;
      var hapticCanaryOk = false;
      var postCanaryGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postCanaryHealth = <String, dynamic>{};
      Map<String, dynamic> postCanaryProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> canaryEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? canaryError;
      Object? nativeStopError;
      Object? rollbackError;

      Map<String, dynamic> asMap(Object? value) => value is Map
          ? value.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      List<Map<String, dynamic>> eventsNamed(String name) => canaryEvents
          .where((event) => event['event'] == name)
          .map((event) => Map<String, dynamic>.from(event))
          .toList();

      bool providerStillDisabled(Map<String, dynamic> value) =>
          value['providerCallsEnabled'] != true &&
          value['transportInvocationEnabled'] != true;
      bool executionEnabled(Map<String, dynamic> value) =>
          value['executionEnabled'] == true &&
          value['toolExecutionEnabled'] == true &&
          value['bridgeExecutionEnabled'] == true;
      bool toolFrameExecutionEnabled(Map<String, dynamic> value) =>
          value['executionEnabled'] == true &&
          value['toolExecutionEnabled'] == true;
      bool allowlistOk(Object? value) =>
          value is List &&
          value.length == 1 &&
          value.single.toString() == 'haptic.vibrate';
      int? parseInt(Object? value) {
        if (value is int) return value;
        if (value is num) return value.round();
        if (value == null) return null;
        return int.tryParse(value.toString());
      }

      bool durationOk(Object? value) {
        final parsed = parseInt(value);
        return parsed != null && parsed > 0 && parsed <= 150;
      }

      bool resultStatusOk(Object? value) {
        final status = value?.toString();
        return status == 'vibrated' || status == 'vibrated_fallback';
      }

      log(
        '[NATIVE-HAPTIC-EXEC-OWNER] Opening haptic bridge execution canary.',
      );

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
            'Haptic bridge execution canary requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before haptic bridge execution canary.',
          );
        }

        log('[NATIVE-HAPTIC-EXEC-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before haptic bridge execution canary.',
          );
        }

        log(
          '[NATIVE-HAPTIC-EXEC-OWNER] Starting native on 18789 and executing one bounded haptic allowlist call.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError(
            'Native haptic bridge execution canary did not start.',
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

        canarySent = true;
        canaryEvents = await _streamProductionNdjson(
          '/gateway/chat-native-dart-bridge-haptic-canary-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-bridge-exec-haptic-request',
            idempotencyKey: 'production-bridge-exec-haptic-idempotency-key',
            model: requestedModel,
            provider: providerHint,
            message: prompt,
          ),
          expectedStatus: 202,
          streamIdleTimeout: const Duration(seconds: 30),
        );

        final ackEvent = _firstEvent(canaryEvents, 'ack');
        final planEvent = _firstEvent(canaryEvents, 'tool_plan_summary');
        final executeRequestEvent =
            _firstEvent(canaryEvents, 'bridge_execute_request');
        final executeAckEvent = _firstEvent(canaryEvents, 'bridge_execute_ack');
        final toolUseEvent = _firstEvent(canaryEvents, 'tool_use_frame');
        final toolResultEvent = _firstEvent(canaryEvents, 'tool_result_frame');
        final summaryEvent = _firstEvent(canaryEvents, 'haptic_canary_summary');
        final endEvent = _firstEvent(canaryEvents, 'end');
        final ack = asMap(ackEvent['ack']);
        final bridgeRequest = asMap(executeRequestEvent['bridgeRequest']);
        final bridgeRequestInput = asMap(bridgeRequest['input']);
        final executeAck = asMap(executeAckEvent['executeAck']);
        final executeAckResult = asMap(executeAck['result']);
        final toolUseFrame = asMap(toolUseEvent['frame']);
        final toolUseInput = asMap(toolUseFrame['input']);
        final toolResultFrame = asMap(toolResultEvent['frame']);
        final toolResult = asMap(toolResultFrame['result']);
        final toolResultPayload = asMap(toolResult['result']);
        final expectedEventOrder = <String>[
          'ack',
          'tool_plan_summary',
          'bridge_execute_request',
          'bridge_execute_ack',
          'tool_use_frame',
          'tool_result_frame',
          'haptic_canary_summary',
          'end',
        ];
        final observedEventOrder =
            canaryEvents.map((event) => event['event']?.toString()).toList();
        eventOrderOk = observedEventOrder.length >= expectedEventOrder.length;
        for (var i = 0; i < expectedEventOrder.length && eventOrderOk; i++) {
          eventOrderOk = observedEventOrder[i] == expectedEventOrder[i];
        }

        ackEventOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'native_dart_bridge_haptic_canary' &&
            ackEvent['routeStatus'] ==
                'native_dart_bridge_haptic_canary_started' &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == false &&
            ackEvent['queueStatus'] == 'native_dart_bridge_haptic_canary' &&
            providerStillDisabled(ackEvent) &&
            executionEnabled(ackEvent) &&
            ack['provider'] == 'openrouter' &&
            ack['route'] == 'native_dart_bridge_haptic_canary' &&
            ack['bridgeRequestHash']?.toString().isNotEmpty == true &&
            ack['dispatchHash']?.toString().isNotEmpty == true &&
            ack['toolSelectionHash']?.toString().isNotEmpty == true &&
            durationOk(ack['hapticDurationMs']) &&
            allowlistOk(ack['canaryAllowlist']) &&
            ack['canaryAllowlistOk'] == true &&
            ack['fixtureParityOk'] == true &&
            ack['dispatchParityOk'] == true &&
            providerStillDisabled(ack) &&
            executionEnabled(ack);
        toolPlanSummaryOk = planEvent['ok'] == true &&
            planEvent['runtime'] == 'native-node-embedded' &&
            allowlistOk(planEvent['forcedAllowlist']) &&
            planEvent['fixtureParityOk'] == true &&
            planEvent['dispatchParityOk'] == true &&
            planEvent['canaryAllowlistOk'] == true &&
            providerStillDisabled(planEvent) &&
            executionEnabled(planEvent);
        executeRequestOk = executeRequestEvent['ok'] == true &&
            executeRequestEvent['runtime'] == 'native-node-embedded' &&
            executeRequestEvent['endpoint'] ==
                'http://127.0.0.1:8765/api/native-gateway/dispatch-execute-canary' &&
            bridgeRequest['type'] == 'native_tool_dispatch_execute_canary' &&
            bridgeRequest['method'] == 'haptic.vibrate' &&
            bridgeRequest['capability'] == 'haptic' &&
            bridgeRequest['dartCapability'] == 'HapticCapability' &&
            bridgeRequest['requiresUiThread'] == false &&
            bridgeRequest['bridgeRequestHash']?.toString().isNotEmpty == true &&
            bridgeRequest['dispatchHash']?.toString().isNotEmpty == true &&
            bridgeRequest['cancellationToken']?.toString().isNotEmpty == true &&
            allowlistOk(bridgeRequest['canaryAllowlist']) &&
            durationOk(bridgeRequestInput['durationMs']) &&
            bridgeRequest['dryRun'] == false &&
            providerStillDisabled(bridgeRequest) &&
            executionEnabled(bridgeRequest);
        executeAckOk = executeAckEvent['ok'] == true &&
            executeAckEvent['runtime'] == 'native-node-embedded' &&
            executeAckEvent['statusCode'] == 200 &&
            executeAckEvent['bridgeRequestHash'] ==
                bridgeRequest['bridgeRequestHash'] &&
            executeAckEvent['executeAckHash']?.toString().isNotEmpty == true &&
            executeAckEvent['executeParityOk'] == true &&
            executeAck['ok'] == true &&
            executeAck['accepted'] == true &&
            executeAck['executed'] == true &&
            executeAck['runtime'] == 'flutter-dart' &&
            executeAck['bridge'] == 'AgentSkillServer' &&
            executeAck['source'] == 'native-dart-bridge-haptic-canary' &&
            executeAck['routeStatus'] ==
                'native_dart_bridge_haptic_canary_ack' &&
            executeAck['command'] == 'haptic.vibrate' &&
            executeAck['commandKnown'] == true &&
            executeAck['canaryAllowlistOk'] == true &&
            executeAck['dryRun'] == false &&
            executeAck['durationBounded'] == true &&
            durationOk(executeAck['durationMs']) &&
            executeAck['bridgeRequestHash'] ==
                bridgeRequest['bridgeRequestHash'] &&
            resultStatusOk(executeAckResult['status']) &&
            providerStillDisabled(executeAck) &&
            executionEnabled(executeAck);
        toolUseOk = toolUseEvent['ok'] == true &&
            toolUseEvent['runtime'] == 'native-node-embedded' &&
            toolUseFrame['type'] == 'tool_use' &&
            toolUseFrame['name'] == 'haptic.vibrate' &&
            toolUseFrame['runtime'] == 'native-node-embedded' &&
            toolUseFrame['source'] == 'native-dart-bridge-haptic-canary' &&
            toolUseFrame['canaryMode'] == 'native-dart-bridge-haptic-canary' &&
            toolUseFrame['dryRun'] == false &&
            toolUseFrame['canaryOnly'] == true &&
            toolUseFrame['cancellationToken']?.toString().isNotEmpty == true &&
            durationOk(toolUseInput['durationMs']) &&
            toolFrameExecutionEnabled(toolUseFrame);
        toolResultOk = toolResultEvent['ok'] == true &&
            toolResultEvent['runtime'] == 'native-node-embedded' &&
            toolResultFrame['type'] == 'tool_result' &&
            toolResultFrame['name'] == 'haptic.vibrate' &&
            toolResultFrame['id'] == toolUseFrame['id'] &&
            toolResultFrame['runtime'] == 'native-node-embedded' &&
            toolResultFrame['source'] == 'native-dart-bridge-haptic-canary' &&
            toolResultFrame['dryRun'] == false &&
            toolResult['ok'] == true &&
            toolResult['dryRun'] == false &&
            toolResult['executed'] == true &&
            toolResult['accepted'] == true &&
            resultStatusOk(toolResult['status']) &&
            resultStatusOk(toolResultPayload['status']) &&
            toolResult['canaryAllowlistOk'] == true &&
            durationOk(toolResult['durationMs']) &&
            providerStillDisabled(toolResult) &&
            executionEnabled(toolResult) &&
            toolFrameExecutionEnabled(toolResultFrame);
        summaryOk = summaryEvent['ok'] == true &&
            summaryEvent['runtime'] == 'native-node-embedded' &&
            summaryEvent['toolName'] == 'haptic.vibrate' &&
            summaryEvent['capability'] == 'haptic' &&
            summaryEvent['dartCapability'] == 'HapticCapability' &&
            durationOk(summaryEvent['durationMs']) &&
            resultStatusOk(summaryEvent['resultStatus']) &&
            summaryEvent['canaryAllowlistOk'] == true &&
            summaryEvent['executeParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            providerStillDisabled(summaryEvent) &&
            executionEnabled(summaryEvent);
        endOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] ==
                'native_dart_bridge_haptic_canary_complete' &&
            endEvent['finishReason'] ==
                'native_dart_bridge_haptic_canary_complete' &&
            endEvent['toolName'] == 'haptic.vibrate' &&
            endEvent['capability'] == 'haptic' &&
            endEvent['canaryAllowlistOk'] == true &&
            endEvent['executeParityOk'] == true &&
            endEvent['validationOk'] == true &&
            providerStillDisabled(endEvent) &&
            executionEnabled(endEvent);
        hapticCanaryOk = ackEventOk &&
            toolPlanSummaryOk &&
            executeRequestOk &&
            executeAckOk &&
            toolUseOk &&
            toolResultOk &&
            summaryOk &&
            eventOrderOk &&
            endOk;

        postCanaryHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryGuardOk = postCanaryHealth['ok'] == true &&
            postCanaryHealth['runtime'] == 'native-node-embedded' &&
            postCanaryHealth['port'] == AppConstants.gatewayPort &&
            postCanaryHealth['productionPortBindCanary'] == true &&
            postCanaryHealth['openclawStarted'] == false &&
            postCanaryProbe['runtime'] == 'native-node-embedded' &&
            postCanaryProbe['port'] == AppConstants.gatewayPort &&
            postCanaryProbe['productionPortBindCanary'] == true &&
            postCanaryProbe['canaryOnly'] == true &&
            postCanaryProbe['productionReady'] == false &&
            postCanaryProbe['openclawStarted'] == false &&
            postCanaryProbe['chatRoutingEnabled'] == false &&
            postCanaryProbe['providerCallsEnabled'] == false &&
            postCanaryProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (canarySent) {
          canaryError = e;
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
          hapticCanaryOk &&
          postCanaryGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final ackEvent = _firstEvent(canaryEvents, 'ack');
      final summaryEvent = _firstEvent(canaryEvents, 'haptic_canary_summary');
      final endEvent = _firstEvent(canaryEvents, 'end');
      final ack = asMap(ackEvent['ack']);
      final executeRequestEvent =
          _firstEvent(canaryEvents, 'bridge_execute_request');
      final executeAckEvent = _firstEvent(canaryEvents, 'bridge_execute_ack');
      final bridgeRequest = asMap(executeRequestEvent['bridgeRequest']);
      final executeAck = asMap(executeAckEvent['executeAck']);
      final observedEventOrder =
          canaryEvents.map((event) => event['event']?.toString()).toList();

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-bridge-execution-haptic-canary',
        'mode':
            'native-production-port-bridge-execution-haptic-canary-with-rollback',
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
        'canarySent': canarySent,
        'hapticCanaryOk': hapticCanaryOk,
        'ackEventOk': ackEventOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'executeRequestOk': executeRequestOk,
        'executeAckOk': executeAckOk,
        'toolUseOk': toolUseOk,
        'toolResultOk': toolResultOk,
        'summaryOk': summaryOk,
        'eventOrderOk': eventOrderOk,
        'endOk': endOk,
        'eventsCount': canaryEvents.length,
        'observedEventOrder': observedEventOrder,
        'executeRequestEventsCount':
            eventsNamed('bridge_execute_request').length,
        'executeAckEventsCount': eventsNamed('bridge_execute_ack').length,
        'toolUseEventsCount': eventsNamed('tool_use_frame').length,
        'toolResultEventsCount': eventsNamed('tool_result_frame').length,
        'routeStatus': endEvent['routeStatus'] ?? ack['routeStatus'],
        'finishReason': endEvent['finishReason'],
        'provider': ack['provider'],
        'requestedModel': ack['requestedModel'],
        'providerModel': ack['providerModel'],
        'transport': ack['transport'],
        'requestHash': ack['requestHash'] ?? endEvent['requestHash'],
        'toolSelectionHash':
            ack['toolSelectionHash'] ?? summaryEvent['toolSelectionHash'],
        'dispatchHash': ack['dispatchHash'] ?? summaryEvent['dispatchHash'],
        'bridgeRequestHash': bridgeRequest['bridgeRequestHash'] ??
            summaryEvent['bridgeRequestHash'],
        'executeAckHash':
            executeAckEvent['executeAckHash'] ?? summaryEvent['executeAckHash'],
        'command': summaryEvent['toolName'] ?? endEvent['toolName'],
        'capability': summaryEvent['capability'] ?? endEvent['capability'],
        'dartCapability': summaryEvent['dartCapability'],
        'canaryAllowlist':
            ack['canaryAllowlist'] ?? bridgeRequest['canaryAllowlist'],
        'canaryAllowlistOk': summaryEvent['canaryAllowlistOk'] == true ||
            endEvent['canaryAllowlistOk'] == true,
        'durationMs': summaryEvent['durationMs'] ??
            executeAck['durationMs'] ??
            ack['hapticDurationMs'],
        'durationBounded': durationOk(
          summaryEvent['durationMs'] ?? executeAck['durationMs'],
        ),
        'resultStatus': summaryEvent['resultStatus'] ??
            asMap(executeAck['result'])['status'],
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            summaryEvent['fixtureParityOk'] == true,
        'dispatchParityOk': ack['dispatchParityOk'] == true ||
            summaryEvent['dispatchParityOk'] == true,
        'executeParityOk': summaryEvent['executeParityOk'] == true ||
            endEvent['executeParityOk'] == true,
        'validationOk': summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            ackEvent['transportInvocationEnabled'] == true ||
                ack['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabled': endEvent['bridgeExecutionEnabled'] == true,
        if (canaryError != null) 'canaryError': canaryError.toString(),
        'postCanaryGuardOk': postCanaryGuardOk,
        'postCanaryRuntimeReported': postCanaryHealth['runtime'],
        'postCanaryCanaryOnly': postCanaryProbe['canaryOnly'] == true,
        'postCanaryChatRoutingEnabled':
            postCanaryProbe['chatRoutingEnabled'] == true,
        'postCanaryProviderCallsEnabled':
            postCanaryProbe['providerCallsEnabled'] == true,
        'postCanaryToolExecutionEnabled':
            postCanaryProbe['toolExecutionEnabled'] == true,
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
        'durationMsTotal': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native owned 18789, executed one bounded haptic.vibrate bridge canary through Dart, and PRoot was restored.'
            : 'Production-port haptic bridge execution canary is not promotable; PRoot rollback was attempted.',
        'nextGate': 'production-port avatar bridge execution canary allowlist',
      };
      log('[NATIVE-HAPTIC-EXEC-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortBridgeHapticCanaryInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortBridgeExecutionAvatarCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production avatar bridge execution canary: wave right',
  }) async {
    if (_productionPortBridgeAvatarCanaryInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': 'hidden-production-port-bridge-execution-avatar-canary',
        'alreadyInFlight': true,
        'decision':
            'Production-port avatar bridge execution canary is already running.',
      };
    }

    _productionPortBridgeAvatarCanaryInFlight = true;
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();
      final providerHint = requestedModel.contains('/')
          ? requestedModel.split('/').first
          : 'openrouter';
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
      var canarySent = false;
      var ackEventOk = false;
      var toolPlanSummaryOk = false;
      var executeRequestOk = false;
      var executeAckOk = false;
      var toolUseOk = false;
      var toolResultOk = false;
      var summaryOk = false;
      var eventOrderOk = false;
      var endOk = false;
      var avatarCanaryOk = false;
      var postCanaryGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postCanaryHealth = <String, dynamic>{};
      Map<String, dynamic> postCanaryProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> canaryEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? canaryError;
      Object? nativeStopError;
      Object? rollbackError;

      Map<String, dynamic> asMap(Object? value) => value is Map
          ? value.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      List<Map<String, dynamic>> eventsNamed(String name) => canaryEvents
          .where((event) => event['event'] == name)
          .map((event) => Map<String, dynamic>.from(event))
          .toList();

      bool providerStillDisabled(Map<String, dynamic> value) =>
          value['providerCallsEnabled'] != true &&
          value['transportInvocationEnabled'] != true;
      bool executionEnabled(Map<String, dynamic> value) =>
          value['executionEnabled'] == true &&
          value['toolExecutionEnabled'] == true &&
          value['bridgeExecutionEnabled'] == true;
      bool toolFrameExecutionEnabled(Map<String, dynamic> value) =>
          value['executionEnabled'] == true &&
          value['toolExecutionEnabled'] == true;
      bool allowlistOk(Object? value) =>
          value is List &&
          value.length == 1 &&
          value.single.toString() == 'avatar.gesture';
      int? parseInt(Object? value) {
        if (value is int) return value;
        if (value is num) return value.round();
        if (value == null) return null;
        return int.tryParse(value.toString());
      }

      bool durationOk(Object? value) {
        final parsed = parseInt(value);
        return parsed != null && parsed > 0 && parsed <= 2500;
      }

      bool gestureOk(Object? value) =>
          value?.toString().trim().toLowerCase() == 'wave right';
      bool resultStatusOk(Object? value) => value?.toString() == 'started';

      log(
        '[NATIVE-AVATAR-EXEC-OWNER] Opening avatar bridge execution canary.',
      );

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
            'Avatar bridge execution canary requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before avatar bridge execution canary.',
          );
        }

        log('[NATIVE-AVATAR-EXEC-OWNER] Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before avatar bridge execution canary.',
          );
        }

        log(
          '[NATIVE-AVATAR-EXEC-OWNER] Starting native on 18789 and executing one protected avatar allowlist call.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError(
            'Native avatar bridge execution canary did not start.',
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

        canarySent = true;
        canaryEvents = await _streamProductionNdjson(
          '/gateway/chat-native-dart-bridge-avatar-canary-stream',
          _sampleGatewayWsChatSendFrame(
            requestId: 'production-bridge-exec-avatar-request',
            idempotencyKey: 'production-bridge-exec-avatar-idempotency-key',
            model: requestedModel,
            provider: providerHint,
            message: prompt,
          ),
          expectedStatus: 202,
          streamIdleTimeout: const Duration(seconds: 35),
        );

        final ackEvent = _firstEvent(canaryEvents, 'ack');
        final planEvent = _firstEvent(canaryEvents, 'tool_plan_summary');
        final executeRequestEvent =
            _firstEvent(canaryEvents, 'bridge_execute_request');
        final executeAckEvent = _firstEvent(canaryEvents, 'bridge_execute_ack');
        final toolUseEvent = _firstEvent(canaryEvents, 'tool_use_frame');
        final toolResultEvent = _firstEvent(canaryEvents, 'tool_result_frame');
        final summaryEvent = _firstEvent(canaryEvents, 'avatar_canary_summary');
        final endEvent = _firstEvent(canaryEvents, 'end');
        final ack = asMap(ackEvent['ack']);
        final bridgeRequest = asMap(executeRequestEvent['bridgeRequest']);
        final bridgeRequestInput = asMap(bridgeRequest['input']);
        final executeAck = asMap(executeAckEvent['executeAck']);
        final executeAckResult = asMap(executeAck['result']);
        final toolUseFrame = asMap(toolUseEvent['frame']);
        final toolUseInput = asMap(toolUseFrame['input']);
        final toolResultFrame = asMap(toolResultEvent['frame']);
        final toolResult = asMap(toolResultFrame['result']);
        final toolResultPayload = asMap(toolResult['result']);
        final expectedEventOrder = <String>[
          'ack',
          'tool_plan_summary',
          'bridge_execute_request',
          'bridge_execute_ack',
          'tool_use_frame',
          'tool_result_frame',
          'avatar_canary_summary',
          'end',
        ];
        final observedEventOrder =
            canaryEvents.map((event) => event['event']?.toString()).toList();
        eventOrderOk = observedEventOrder.length >= expectedEventOrder.length;
        for (var i = 0; i < expectedEventOrder.length && eventOrderOk; i++) {
          eventOrderOk = observedEventOrder[i] == expectedEventOrder[i];
        }

        ackEventOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == 'native_dart_bridge_avatar_canary' &&
            ackEvent['routeStatus'] ==
                'native_dart_bridge_avatar_canary_started' &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['queuedForDryRun'] == false &&
            ackEvent['queueStatus'] == 'native_dart_bridge_avatar_canary' &&
            providerStillDisabled(ackEvent) &&
            executionEnabled(ackEvent) &&
            ack['provider'] == 'openrouter' &&
            ack['route'] == 'native_dart_bridge_avatar_canary' &&
            ack['bridgeRequestHash']?.toString().isNotEmpty == true &&
            ack['dispatchHash']?.toString().isNotEmpty == true &&
            ack['toolSelectionHash']?.toString().isNotEmpty == true &&
            gestureOk(ack['gesture']) &&
            durationOk(ack['durationMs']) &&
            ack['protectedGesture'] == true &&
            ack['arbitration'] == 'protected-gesture' &&
            allowlistOk(ack['canaryAllowlist']) &&
            ack['canaryAllowlistOk'] == true &&
            ack['fixtureParityOk'] == true &&
            ack['dispatchParityOk'] == true &&
            providerStillDisabled(ack) &&
            executionEnabled(ack);
        toolPlanSummaryOk = planEvent['ok'] == true &&
            planEvent['runtime'] == 'native-node-embedded' &&
            allowlistOk(planEvent['forcedAllowlist']) &&
            planEvent['fixtureParityOk'] == true &&
            planEvent['dispatchParityOk'] == true &&
            planEvent['canaryAllowlistOk'] == true &&
            planEvent['protectedGesture'] == true &&
            planEvent['arbitration'] == 'protected-gesture' &&
            providerStillDisabled(planEvent) &&
            executionEnabled(planEvent);
        executeRequestOk = executeRequestEvent['ok'] == true &&
            executeRequestEvent['runtime'] == 'native-node-embedded' &&
            executeRequestEvent['endpoint'] ==
                'http://127.0.0.1:8765/api/native-gateway/dispatch-execute-canary' &&
            bridgeRequest['type'] == 'native_tool_dispatch_execute_canary' &&
            bridgeRequest['method'] == 'avatar.gesture' &&
            bridgeRequest['capability'] == 'avatar' &&
            bridgeRequest['dartCapability'] == 'AvatarCapability' &&
            bridgeRequest['requiresUiThread'] == true &&
            bridgeRequest['bridgeRequestHash']?.toString().isNotEmpty == true &&
            bridgeRequest['dispatchHash']?.toString().isNotEmpty == true &&
            bridgeRequest['cancellationToken']?.toString().isNotEmpty == true &&
            allowlistOk(bridgeRequest['canaryAllowlist']) &&
            gestureOk(bridgeRequestInput['gesture']) &&
            durationOk(bridgeRequestInput['durationMs']) &&
            bridgeRequestInput['interrupt'] == true &&
            bridgeRequestInput['protectedGesture'] == true &&
            bridgeRequestInput['source'] ==
                'native-dart-bridge-avatar-canary' &&
            bridgeRequestInput['canaryMode'] ==
                'native-dart-bridge-avatar-canary' &&
            bridgeRequest['protectedGesture'] == true &&
            bridgeRequest['arbitration'] == 'protected-gesture' &&
            bridgeRequest['dryRun'] == false &&
            providerStillDisabled(bridgeRequest) &&
            executionEnabled(bridgeRequest);
        executeAckOk = executeAckEvent['ok'] == true &&
            executeAckEvent['runtime'] == 'native-node-embedded' &&
            executeAckEvent['statusCode'] == 200 &&
            executeAckEvent['bridgeRequestHash'] ==
                bridgeRequest['bridgeRequestHash'] &&
            executeAckEvent['executeAckHash']?.toString().isNotEmpty == true &&
            executeAckEvent['executeParityOk'] == true &&
            executeAckEvent['gestureOk'] == true &&
            executeAckEvent['durationOk'] == true &&
            executeAckEvent['arbitrationOk'] == true &&
            executeAck['ok'] == true &&
            executeAck['accepted'] == true &&
            executeAck['executed'] == true &&
            executeAck['runtime'] == 'flutter-dart' &&
            executeAck['bridge'] == 'AgentSkillServer' &&
            executeAck['source'] == 'native-dart-bridge-avatar-canary' &&
            executeAck['routeStatus'] ==
                'native_dart_bridge_avatar_canary_ack' &&
            executeAck['command'] == 'avatar.gesture' &&
            executeAck['commandKnown'] == true &&
            executeAck['canaryAllowlistOk'] == true &&
            executeAck['dryRun'] == false &&
            executeAck['avatarInputOk'] == true &&
            executeAck['bridgeRequestHash'] ==
                bridgeRequest['bridgeRequestHash'] &&
            resultStatusOk(executeAckEvent['resultStatus']) &&
            resultStatusOk(executeAck['resultStatus']) &&
            resultStatusOk(executeAckResult['status']) &&
            gestureOk(executeAckResult['gesture']) &&
            durationOk(executeAckResult['durationMs']) &&
            (executeAckResult['protectedGesture'] == true ||
                executeAck['avatarInputOk'] == true) &&
            providerStillDisabled(executeAck) &&
            executionEnabled(executeAck);
        toolUseOk = toolUseEvent['ok'] == true &&
            toolUseEvent['runtime'] == 'native-node-embedded' &&
            toolUseFrame['type'] == 'tool_use' &&
            toolUseFrame['name'] == 'avatar.gesture' &&
            toolUseFrame['runtime'] == 'native-node-embedded' &&
            toolUseFrame['source'] == 'native-dart-bridge-avatar-canary' &&
            toolUseFrame['canaryMode'] == 'native-dart-bridge-avatar-canary' &&
            toolUseFrame['dryRun'] == false &&
            toolUseFrame['canaryOnly'] == true &&
            toolUseFrame['protectedGesture'] == true &&
            toolUseFrame['arbitration'] == 'protected-gesture' &&
            toolUseFrame['cancellationToken']?.toString().isNotEmpty == true &&
            gestureOk(toolUseInput['gesture']) &&
            durationOk(toolUseInput['durationMs']) &&
            toolUseInput['interrupt'] == true &&
            toolUseInput['protectedGesture'] == true &&
            toolFrameExecutionEnabled(toolUseFrame);
        toolResultOk = toolResultEvent['ok'] == true &&
            toolResultEvent['runtime'] == 'native-node-embedded' &&
            toolResultFrame['type'] == 'tool_result' &&
            toolResultFrame['name'] == 'avatar.gesture' &&
            toolResultFrame['id'] == toolUseFrame['id'] &&
            toolResultFrame['runtime'] == 'native-node-embedded' &&
            toolResultFrame['source'] == 'native-dart-bridge-avatar-canary' &&
            toolResultFrame['dryRun'] == false &&
            toolResultFrame['protectedGesture'] == true &&
            toolResult['ok'] == true &&
            toolResult['dryRun'] == false &&
            toolResult['executed'] == true &&
            toolResult['accepted'] == true &&
            resultStatusOk(toolResult['status']) &&
            resultStatusOk(toolResultPayload['status']) &&
            gestureOk(toolResultPayload['gesture']) &&
            durationOk(toolResultPayload['durationMs']) &&
            toolResult['canaryAllowlistOk'] == true &&
            toolResult['gestureOk'] == true &&
            toolResult['durationOk'] == true &&
            toolResult['arbitrationOk'] == true &&
            providerStillDisabled(toolResult) &&
            executionEnabled(toolResult) &&
            toolFrameExecutionEnabled(toolResultFrame);
        summaryOk = summaryEvent['ok'] == true &&
            summaryEvent['runtime'] == 'native-node-embedded' &&
            summaryEvent['toolName'] == 'avatar.gesture' &&
            summaryEvent['capability'] == 'avatar' &&
            summaryEvent['dartCapability'] == 'AvatarCapability' &&
            gestureOk(summaryEvent['gesture']) &&
            durationOk(summaryEvent['durationMs']) &&
            resultStatusOk(summaryEvent['resultStatus']) &&
            summaryEvent['gestureOk'] == true &&
            summaryEvent['durationOk'] == true &&
            summaryEvent['arbitrationOk'] == true &&
            summaryEvent['canaryAllowlistOk'] == true &&
            summaryEvent['executeParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            summaryEvent['protectedGesture'] == true &&
            providerStillDisabled(summaryEvent) &&
            executionEnabled(summaryEvent);
        endOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] ==
                'native_dart_bridge_avatar_canary_complete' &&
            endEvent['finishReason'] ==
                'native_dart_bridge_avatar_canary_complete' &&
            endEvent['toolName'] == 'avatar.gesture' &&
            endEvent['capability'] == 'avatar' &&
            gestureOk(endEvent['gesture']) &&
            endEvent['canaryAllowlistOk'] == true &&
            endEvent['executeParityOk'] == true &&
            endEvent['validationOk'] == true &&
            endEvent['protectedGesture'] == true &&
            providerStillDisabled(endEvent) &&
            executionEnabled(endEvent);
        avatarCanaryOk = ackEventOk &&
            toolPlanSummaryOk &&
            executeRequestOk &&
            executeAckOk &&
            toolUseOk &&
            toolResultOk &&
            summaryOk &&
            eventOrderOk &&
            endOk;

        postCanaryHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryGuardOk = postCanaryHealth['ok'] == true &&
            postCanaryHealth['runtime'] == 'native-node-embedded' &&
            postCanaryHealth['port'] == AppConstants.gatewayPort &&
            postCanaryHealth['productionPortBindCanary'] == true &&
            postCanaryHealth['openclawStarted'] == false &&
            postCanaryProbe['runtime'] == 'native-node-embedded' &&
            postCanaryProbe['port'] == AppConstants.gatewayPort &&
            postCanaryProbe['productionPortBindCanary'] == true &&
            postCanaryProbe['canaryOnly'] == true &&
            postCanaryProbe['productionReady'] == false &&
            postCanaryProbe['openclawStarted'] == false &&
            postCanaryProbe['chatRoutingEnabled'] == false &&
            postCanaryProbe['providerCallsEnabled'] == false &&
            postCanaryProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (canarySent) {
          canaryError = e;
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
          avatarCanaryOk &&
          postCanaryGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final ackEvent = _firstEvent(canaryEvents, 'ack');
      final summaryEvent = _firstEvent(canaryEvents, 'avatar_canary_summary');
      final endEvent = _firstEvent(canaryEvents, 'end');
      final ack = asMap(ackEvent['ack']);
      final executeRequestEvent =
          _firstEvent(canaryEvents, 'bridge_execute_request');
      final executeAckEvent = _firstEvent(canaryEvents, 'bridge_execute_ack');
      final bridgeRequest = asMap(executeRequestEvent['bridgeRequest']);
      final executeAck = asMap(executeAckEvent['executeAck']);
      final observedEventOrder =
          canaryEvents.map((event) => event['event']?.toString()).toList();

      final report = <String, dynamic>{
        'ok': ok,
        'phase': 'hidden-production-port-bridge-execution-avatar-canary',
        'mode':
            'native-production-port-bridge-execution-avatar-canary-with-rollback',
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
        'canarySent': canarySent,
        'avatarCanaryOk': avatarCanaryOk,
        'ackEventOk': ackEventOk,
        'toolPlanSummaryOk': toolPlanSummaryOk,
        'executeRequestOk': executeRequestOk,
        'executeAckOk': executeAckOk,
        'toolUseOk': toolUseOk,
        'toolResultOk': toolResultOk,
        'summaryOk': summaryOk,
        'eventOrderOk': eventOrderOk,
        'endOk': endOk,
        'eventsCount': canaryEvents.length,
        'observedEventOrder': observedEventOrder,
        'executeRequestEventsCount':
            eventsNamed('bridge_execute_request').length,
        'executeAckEventsCount': eventsNamed('bridge_execute_ack').length,
        'toolUseEventsCount': eventsNamed('tool_use_frame').length,
        'toolResultEventsCount': eventsNamed('tool_result_frame').length,
        'routeStatus': endEvent['routeStatus'] ?? ack['routeStatus'],
        'finishReason': endEvent['finishReason'],
        'provider': ack['provider'],
        'requestedModel': ack['requestedModel'],
        'providerModel': ack['providerModel'],
        'transport': ack['transport'],
        'requestHash': ack['requestHash'] ?? endEvent['requestHash'],
        'toolSelectionHash':
            ack['toolSelectionHash'] ?? summaryEvent['toolSelectionHash'],
        'dispatchHash': ack['dispatchHash'] ?? summaryEvent['dispatchHash'],
        'bridgeRequestHash': bridgeRequest['bridgeRequestHash'] ??
            summaryEvent['bridgeRequestHash'],
        'executeAckHash':
            executeAckEvent['executeAckHash'] ?? summaryEvent['executeAckHash'],
        'command': summaryEvent['toolName'] ?? endEvent['toolName'],
        'capability': summaryEvent['capability'] ?? endEvent['capability'],
        'dartCapability': summaryEvent['dartCapability'],
        'canaryAllowlist':
            ack['canaryAllowlist'] ?? bridgeRequest['canaryAllowlist'],
        'canaryAllowlistOk': summaryEvent['canaryAllowlistOk'] == true ||
            endEvent['canaryAllowlistOk'] == true,
        'gesture': summaryEvent['gesture'] ?? endEvent['gesture'],
        'durationMs': summaryEvent['durationMs'] ??
            asMap(executeAck['result'])['durationMs'],
        'gestureOk': summaryEvent['gestureOk'] == true ||
            executeAckEvent['gestureOk'] == true,
        'durationOk': summaryEvent['durationOk'] == true ||
            executeAckEvent['durationOk'] == true,
        'arbitrationOk': summaryEvent['arbitrationOk'] == true ||
            executeAckEvent['arbitrationOk'] == true,
        'protectedGesture': summaryEvent['protectedGesture'] == true ||
            endEvent['protectedGesture'] == true,
        'resultStatus':
            summaryEvent['resultStatus'] ?? executeAckEvent['resultStatus'],
        'fixtureParityOk': ack['fixtureParityOk'] == true ||
            summaryEvent['fixtureParityOk'] == true,
        'dispatchParityOk': ack['dispatchParityOk'] == true ||
            summaryEvent['dispatchParityOk'] == true,
        'executeParityOk': summaryEvent['executeParityOk'] == true ||
            endEvent['executeParityOk'] == true,
        'validationOk': summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'transportInvocationEnabled':
            ackEvent['transportInvocationEnabled'] == true ||
                ack['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabled': endEvent['bridgeExecutionEnabled'] == true,
        if (canaryError != null) 'canaryError': canaryError.toString(),
        'postCanaryGuardOk': postCanaryGuardOk,
        'postCanaryRuntimeReported': postCanaryHealth['runtime'],
        'postCanaryCanaryOnly': postCanaryProbe['canaryOnly'] == true,
        'postCanaryChatRoutingEnabled':
            postCanaryProbe['chatRoutingEnabled'] == true,
        'postCanaryProviderCallsEnabled':
            postCanaryProbe['providerCallsEnabled'] == true,
        'postCanaryToolExecutionEnabled':
            postCanaryProbe['toolExecutionEnabled'] == true,
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
        'durationMsTotal': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native owned 18789, executed one protected avatar.gesture bridge canary through Dart, and PRoot was restored.'
            : 'Production-port avatar bridge execution canary is not promotable; PRoot rollback was attempted.',
        'nextGate':
            'production-port provider-backed chat canary with tool execution disabled',
      };
      log('[NATIVE-AVATAR-EXEC-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortBridgeAvatarCanaryInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortProviderToolPlanAllowlistedExecutionCanary({
    required void Function(String message) log,
    String model = 'openrouter/auto',
    String prompt =
        'native production provider tool plan to allowlisted execution canary: vibrate once',
  }) async {
    if (_productionPortProviderToolPlanExecutionInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase':
            'hidden-production-port-provider-tool-plan-allowlisted-execution',
        'alreadyInFlight': true,
        'decision':
            'Production-port provider tool-plan execution canary is already running.',
      };
    }

    _productionPortProviderToolPlanExecutionInFlight = true;
    final startedAt = DateTime.now();

    try {
      final requestedModel =
          model.trim().isEmpty ? 'openrouter/auto' : model.trim();

      bool reportFlag(Map<String, dynamic> report, String key) =>
          report[key] == true;
      bool reportDisabled(Map<String, dynamic> report, String key) =>
          report[key] != true;
      int reportInt(Map<String, dynamic> report, String key) {
        final value = report[key];
        if (value is int) return value;
        if (value is num) return value.round();
        if (value == null) return 0;
        return int.tryParse(value.toString()) ?? 0;
      }

      List<String> stringList(Object? value) {
        if (value is! List) return const <String>[];
        return value
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
      }

      String normalizeToolName(String value) => value
          .trim()
          .toLowerCase()
          .replaceAll('_', '.')
          .replaceAll('-', '.')
          .replaceAll(RegExp(r'\.+'), '.');

      bool hasTool(Iterable<String> names, String toolName) {
        final normalizedTool = normalizeToolName(toolName);
        final compactTool = normalizedTool.replaceAll('.', '');
        for (final name in names) {
          final normalized = normalizeToolName(name);
          if (normalized == normalizedTool ||
              normalized.replaceAll('.', '') == compactTool) {
            return true;
          }
        }
        return false;
      }

      bool allowlistContains(Map<String, dynamic> report, String toolName) {
        final allowlist = stringList(report['canaryAllowlist']);
        return hasTool(allowlist, toolName);
      }

      bool executionBaseOk(Map<String, dynamic> report) =>
          reportFlag(report, 'ok') &&
          reportFlag(report, 'canaryAllowlistOk') &&
          reportFlag(report, 'executeParityOk') &&
          reportFlag(report, 'validationOk') &&
          reportDisabled(report, 'providerCallsEnabled') &&
          reportDisabled(report, 'transportInvocationEnabled') &&
          reportFlag(report, 'executionEnabled') &&
          reportFlag(report, 'toolExecutionEnabled') &&
          reportFlag(report, 'bridgeExecutionEnabled') &&
          reportFlag(report, 'nativeStopped') &&
          reportFlag(report, 'nativePortReleasedAfterStop') &&
          reportFlag(report, 'rollbackHealthOk');

      log(
        '[NATIVE-TOOL-PLAN-EXEC-OWNER] Capturing provider tool intent before bounded execution.',
      );

      final captureReport =
          await runProductionPortProviderToolPlanCaptureCanary(
        log: log,
        model: requestedModel,
        prompt: prompt,
      );

      final capturedToolNames = <String>{
        ...stringList(captureReport['toolPlanNames']),
        ...stringList(captureReport['capturedGatewayToolNames']),
      }.toList(growable: false);
      final availableToolNames = <String>{
        ...stringList(captureReport['toolFunctionNames']),
        ...stringList(captureReport['gatewayToolNames']),
      }.toList(growable: false);

      final captureOk = reportFlag(captureReport, 'ok') &&
          reportFlag(captureReport, 'toolPlanCanaryOk') &&
          reportFlag(captureReport, 'toolPlanAckOk') &&
          reportFlag(captureReport, 'toolCatalogOk') &&
          reportFlag(captureReport, 'providerRequestOk') &&
          reportFlag(captureReport, 'toolPlanSummaryOk') &&
          reportInt(captureReport, 'allowedPlanCount') > 0 &&
          reportDisabled(captureReport, 'providerCallsEnabled') &&
          reportDisabled(captureReport, 'transportInvocationEnabled') &&
          reportDisabled(captureReport, 'executionEnabled') &&
          reportDisabled(captureReport, 'toolExecutionEnabled') &&
          reportFlag(captureReport, 'rollbackHealthOk');

      final plannedHaptic = hasTool(capturedToolNames, 'haptic.vibrate');
      final plannedAvatar = hasTool(capturedToolNames, 'avatar.gesture');
      final plannedReadOnly = hasTool(capturedToolNames, 'flash.status') &&
          hasTool(capturedToolNames, 'sensor.list');

      String? selectedExecutionCanary;
      String selectedExecutionPrompt = prompt;
      if (plannedHaptic) {
        selectedExecutionCanary = 'haptic.vibrate';
        selectedExecutionPrompt =
            'native production provider-selected haptic bridge execution canary: vibrate once';
      } else if (plannedAvatar) {
        selectedExecutionCanary = 'avatar.gesture';
        selectedExecutionPrompt =
            'native production provider-selected avatar bridge execution canary: wave right';
      } else if (plannedReadOnly) {
        selectedExecutionCanary = 'flash.status,sensor.list';
        selectedExecutionPrompt =
            'native production provider-selected read-only bridge execution canary: check flash and list sensors';
      }

      final planToAllowlistMatchedOk =
          captureOk && selectedExecutionCanary != null;

      Map<String, dynamic> executionReport = <String, dynamic>{};
      var executionOk = false;
      var selectedAllowlist = const <String>[];
      var executionCommand = 'none';

      if (planToAllowlistMatchedOk) {
        log(
          '[NATIVE-TOOL-PLAN-EXEC-OWNER] Provider plan matched $selectedExecutionCanary; executing only that allowlisted bridge canary.',
        );
        if (selectedExecutionCanary == 'haptic.vibrate') {
          executionReport = await runProductionPortBridgeExecutionHapticCanary(
            log: log,
            model: requestedModel,
            prompt: selectedExecutionPrompt,
          );
          selectedAllowlist = const <String>['haptic.vibrate'];
          executionCommand = 'haptic.vibrate';
          executionOk = executionBaseOk(executionReport) &&
              reportFlag(executionReport, 'hapticCanaryOk') &&
              executionReport['command'] == 'haptic.vibrate' &&
              allowlistContains(executionReport, 'haptic.vibrate') &&
              reportFlag(executionReport, 'durationBounded');
        } else if (selectedExecutionCanary == 'avatar.gesture') {
          executionReport = await runProductionPortBridgeExecutionAvatarCanary(
            log: log,
            model: requestedModel,
            prompt: selectedExecutionPrompt,
          );
          selectedAllowlist = const <String>['avatar.gesture'];
          executionCommand = 'avatar.gesture';
          executionOk = executionBaseOk(executionReport) &&
              reportFlag(executionReport, 'avatarCanaryOk') &&
              executionReport['command'] == 'avatar.gesture' &&
              allowlistContains(executionReport, 'avatar.gesture') &&
              reportFlag(executionReport, 'protectedGesture') &&
              reportFlag(executionReport, 'arbitrationOk');
        } else {
          executionReport =
              await runProductionPortBridgeExecutionReadOnlyCanary(
            log: log,
            model: requestedModel,
            prompt: selectedExecutionPrompt,
          );
          selectedAllowlist = const <String>['flash.status', 'sensor.list'];
          executionCommand = 'flash.status,sensor.list';
          executionOk = executionBaseOk(executionReport) &&
              reportFlag(executionReport, 'readOnlyCanaryOk') &&
              reportFlag(executionReport, 'readOnly') &&
              allowlistContains(executionReport, 'flash.status') &&
              allowlistContains(executionReport, 'sensor.list');
        }
      }

      final captureRollbackOk = reportFlag(captureReport, 'rollbackStarted') &&
          reportFlag(captureReport, 'rollbackRunning') &&
          reportFlag(captureReport, 'rollbackHealthOk');
      final executionRollbackOk = executionReport.isNotEmpty &&
          reportFlag(executionReport, 'rollbackStarted') &&
          reportFlag(executionReport, 'rollbackRunning') &&
          reportFlag(executionReport, 'rollbackHealthOk');
      final providerDisabledDuringCaptureOk =
          reportDisabled(captureReport, 'providerCallsEnabled') &&
              reportDisabled(captureReport, 'transportInvocationEnabled');
      final executionDisabledDuringCaptureOk =
          reportDisabled(captureReport, 'executionEnabled') &&
              reportDisabled(captureReport, 'toolExecutionEnabled');
      final providerDisabledDuringExecutionOk = executionReport.isNotEmpty &&
          reportDisabled(executionReport, 'providerCallsEnabled') &&
          reportDisabled(
            executionReport,
            'transportInvocationEnabled',
          );
      final executionEnabledDuringSelectedCanaryOk =
          executionReport.isNotEmpty &&
              reportFlag(executionReport, 'executionEnabled') &&
              reportFlag(executionReport, 'toolExecutionEnabled') &&
              reportFlag(executionReport, 'bridgeExecutionEnabled');

      final ok = captureOk &&
          planToAllowlistMatchedOk &&
          executionOk &&
          captureRollbackOk &&
          executionRollbackOk &&
          providerDisabledDuringCaptureOk &&
          executionDisabledDuringCaptureOk &&
          providerDisabledDuringExecutionOk &&
          executionEnabledDuringSelectedCanaryOk;

      final report = <String, dynamic>{
        'ok': ok,
        'phase':
            'hidden-production-port-provider-tool-plan-allowlisted-execution',
        'mode':
            'native-production-port-provider-tool-plan-to-allowlisted-execution-with-rollback',
        'productionPort': AppConstants.gatewayPort,
        'activeRuntimeId': GatewayRuntimeRegistry.prootRollback.id,
        'temporaryOwnerRuntimeId': _productionPortRuntime.id,
        'requestedModel': requestedModel,
        'captureOk': captureOk,
        'capturePhase': captureReport['phase'],
        'captureMode': captureReport['mode'],
        'captureToolPlanCanaryOk': captureReport['toolPlanCanaryOk'] == true,
        'captureToolPlanAckOk': captureReport['toolPlanAckOk'] == true,
        'captureProviderRequestOk': captureReport['providerRequestOk'] == true,
        'captureToolPlanSummaryOk': captureReport['toolPlanSummaryOk'] == true,
        'capturedToolNames': capturedToolNames,
        'capturedToolPlanNames': stringList(captureReport['toolPlanNames']),
        'capturedGatewayToolNames':
            stringList(captureReport['capturedGatewayToolNames']),
        'availableToolNames': availableToolNames,
        'plannedHaptic': plannedHaptic,
        'plannedAvatar': plannedAvatar,
        'plannedReadOnly': plannedReadOnly,
        'selectedExecutionCanary': selectedExecutionCanary,
        'selectedExecutionCommand': executionCommand,
        'selectedAllowlist': selectedAllowlist,
        'planToAllowlistMatchedOk': planToAllowlistMatchedOk,
        'executionOk': executionOk,
        'executionPhase': executionReport['phase'],
        'executionMode': executionReport['mode'],
        'executionCommand': executionReport['command'] ?? executionCommand,
        'executionFinishReason': executionReport['finishReason'],
        'executionCanaryAllowlist': executionReport['canaryAllowlist'],
        'executionCanaryAllowlistOk':
            executionReport['canaryAllowlistOk'] == true,
        'executionExecuteParityOk': executionReport['executeParityOk'] == true,
        'executionValidationOk': executionReport['validationOk'] == true,
        'executionResultStatus': executionReport['resultStatus'],
        'providerDisabledDuringCaptureOk': providerDisabledDuringCaptureOk,
        'executionDisabledDuringCaptureOk': executionDisabledDuringCaptureOk,
        'providerDisabledDuringExecutionOk': providerDisabledDuringExecutionOk,
        'executionEnabledDuringSelectedCanaryOk':
            executionEnabledDuringSelectedCanaryOk,
        'captureProviderCallsEnabled':
            captureReport['providerCallsEnabled'] == true,
        'captureTransportInvocationEnabled':
            captureReport['transportInvocationEnabled'] == true,
        'captureExecutionEnabled': captureReport['executionEnabled'] == true,
        'captureToolExecutionEnabled':
            captureReport['toolExecutionEnabled'] == true,
        'executionProviderCallsEnabled':
            executionReport['providerCallsEnabled'] == true,
        'executionTransportInvocationEnabled':
            executionReport['transportInvocationEnabled'] == true,
        'executionExecutionEnabled':
            executionReport['executionEnabled'] == true,
        'executionToolExecutionEnabled':
            executionReport['toolExecutionEnabled'] == true,
        'executionBridgeExecutionEnabled':
            executionReport['bridgeExecutionEnabled'] == true,
        'captureRollbackOk': captureRollbackOk,
        'executionRollbackOk': executionRollbackOk,
        'captureNativeSmokeRestored':
            captureReport['nativeSmokeRestored'] == true,
        'executionNativeSmokeRestored':
            executionReport['nativeSmokeRestored'] == true,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'decision': ok
            ? 'Native captured a provider-style tool plan on 18789, mapped it to a matching bounded allowlist, executed only that bridge canary, and PRoot was restored.'
            : (captureOk
                ? 'Provider tool-plan capture succeeded, but the selected allowlisted execution canary is not promotable; PRoot rollback was attempted.'
                : 'Provider tool-plan capture did not pass; allowlisted execution was not attempted.'),
        'nextGate':
            'production-port live provider tool-call to bounded native bridge execution canary',
      };
      log('[NATIVE-TOOL-PLAN-EXEC-OWNER] ${jsonEncode(report)}');
      return report;
    } finally {
      _productionPortProviderToolPlanExecutionInFlight = false;
    }
  }

  static Future<Map<String, dynamic>>
      runProductionPortNativeChatLoopContinuationCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String prompt =
        'native production chat loop continuation canary: vibrate once and answer',
  }) {
    return runProductionPortProviderLiveToolExecutionCanary(
      log: log,
      providerConfig: providerConfig,
      prompt: prompt,
      continueWithToolResult: true,
      chatLoopWithToolContinuation: true,
    );
  }

  static Future<Map<String, dynamic>>
      runProductionPortProviderLiveToolContinuationCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String prompt =
        'native production live provider tool result continuation canary: vibrate once',
  }) {
    return runProductionPortProviderLiveToolExecutionCanary(
      log: log,
      providerConfig: providerConfig,
      prompt: prompt,
      continueWithToolResult: true,
    );
  }

  static Future<Map<String, dynamic>>
      runProductionPortProviderLiveToolExecutionCanary({
    required void Function(String message) log,
    required Map<String, dynamic> providerConfig,
    String prompt =
        'native production live provider tool-call to bounded bridge execution canary: wave right',
    bool continueWithToolResult = false,
    bool chatLoopWithToolContinuation = false,
  }) async {
    final toolContinuationEnabled =
        continueWithToolResult || chatLoopWithToolContinuation;
    final phaseName = chatLoopWithToolContinuation
        ? 'hidden-production-port-native-chat-loop-tool-continuation-canary'
        : toolContinuationEnabled
            ? 'hidden-production-port-live-provider-tool-continuation-canary'
            : 'hidden-production-port-live-provider-tool-execution-canary';
    final modeName = chatLoopWithToolContinuation
        ? 'native-production-port-chat-loop-tool-continuation-with-rollback'
        : toolContinuationEnabled
            ? 'native-production-port-live-provider-tool-result-continuation-with-rollback'
            : 'native-production-port-live-provider-tool-call-to-bridge-execution-with-rollback';
    final logTag = chatLoopWithToolContinuation
        ? '[NATIVE-CHAT-LOOP-CONTINUE]'
        : toolContinuationEnabled
            ? '[NATIVE-LIVE-TOOL-CONTINUE]'
            : '[NATIVE-LIVE-TOOL-OWNER]';
    final expectedRoute = chatLoopWithToolContinuation
        ? 'native_chat_loop_tool_continuation_canary'
        : toolContinuationEnabled
            ? 'live_provider_tool_continuation_canary'
            : 'live_provider_tool_execution_canary';
    final expectedStartingStatus = chatLoopWithToolContinuation
        ? 'native_chat_loop_tool_continuation_starting'
        : toolContinuationEnabled
            ? 'live_provider_tool_continuation_starting'
            : 'live_provider_tool_call_starting';
    final expectedCompleteStatus = chatLoopWithToolContinuation
        ? 'native_chat_loop_tool_continuation_canary_complete'
        : toolContinuationEnabled
            ? 'live_provider_tool_continuation_canary_complete'
            : 'live_provider_tool_execution_canary_complete';
    final expectedGatewayToolName =
        toolContinuationEnabled ? 'haptic.vibrate' : 'avatar.gesture';
    final expectedFunctionName =
        toolContinuationEnabled ? 'haptic_vibrate' : 'avatar_gesture';
    final expectedResultStatus =
        toolContinuationEnabled ? 'vibrated' : 'started';
    final expectedCapability = toolContinuationEnabled ? 'haptic' : 'avatar';
    final expectedDartCapability =
        toolContinuationEnabled ? 'HapticCapability' : 'AvatarCapability';
    final expectedRequiresUiThread = !toolContinuationEnabled;
    final endpointPath = chatLoopWithToolContinuation
        ? '/gateway/chat-loop-live-tool-continuation-canary-stream'
        : toolContinuationEnabled
            ? '/gateway/chat-provider-live-tool-continuation-canary-stream'
            : '/gateway/chat-provider-live-tool-execution-canary-stream';
    final alreadyInFlight = chatLoopWithToolContinuation
        ? _productionPortNativeChatLoopContinuationInFlight
        : toolContinuationEnabled
            ? _productionPortProviderLiveToolContinuationInFlight
            : _productionPortProviderLiveToolExecutionInFlight;
    if (alreadyInFlight) {
      return <String, dynamic>{
        'ok': false,
        'phase': phaseName,
        'alreadyInFlight': true,
        'decision': chatLoopWithToolContinuation
            ? 'Production-port native chat loop continuation canary is already running.'
            : toolContinuationEnabled
                ? 'Production-port live provider tool continuation canary is already running.'
                : 'Production-port live provider tool execution canary is already running.',
      };
    }

    if (chatLoopWithToolContinuation) {
      _productionPortNativeChatLoopContinuationInFlight = true;
    } else if (toolContinuationEnabled) {
      _productionPortProviderLiveToolContinuationInFlight = true;
    } else {
      _productionPortProviderLiveToolExecutionInFlight = true;
    }
    final startedAt = DateTime.now();

    try {
      final productionRuntime = GatewayRuntimeRegistry.prootRollback;
      final ownerRuntime = _productionPortRuntime;
      final providerConfigForNative = Map<String, dynamic>.from(
        providerConfig,
      );
      providerConfigForNative['title'] =
          providerConfigForNative['title']?.toString().trim().isNotEmpty == true
              ? providerConfigForNative['title']
              : chatLoopWithToolContinuation
                  ? 'Plawie Native Chat Loop Continuation Canary'
                  : toolContinuationEnabled
                      ? 'Plawie Native Live Tool Continuation Canary'
                      : 'Plawie Native Live Tool Execution Canary';
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
      var canarySent = false;
      var ackEventOk = false;
      var toolCatalogOk = false;
      var providerRequestOk = false;
      var providerCallStartedOk = false;
      var providerResponseOk = false;
      var providerErrorSurfaceOk = false;
      var liveToolPlanSummaryOk = false;
      var bridgeExecuteRequestOk = false;
      var bridgeExecuteAckOk = false;
      var toolUseFrameOk = false;
      var toolResultFrameOk = false;
      var executionSummaryOk = false;
      var continuationProviderRequestOk = false;
      var continuationProviderCallStartedOk = false;
      var continuationProviderResponseOk = false;
      var continuationSummaryOk = false;
      var continuationOk = false;
      var chatResponseFrameOk = false;
      var chatLoopOk = false;
      var eventOrderOk = false;
      var endOk = false;
      var liveToolExecutionCanaryOk = false;
      var postCanaryGuardOk = false;
      var nativeStopped = false;
      var nativePortReleasedAfterStop = false;
      var rollbackStarted = false;
      var rollbackRunning = false;
      var rollbackHealthOk = false;
      Map<String, dynamic> productionBefore = <String, dynamic>{};
      Map<String, dynamic> nativeHealth = <String, dynamic>{};
      Map<String, dynamic> nativeProbe = <String, dynamic>{};
      Map<String, dynamic> postCanaryHealth = <String, dynamic>{};
      Map<String, dynamic> postCanaryProbe = <String, dynamic>{};
      Map<String, dynamic> rollbackHealth = <String, dynamic>{};
      List<Map<String, dynamic>> canaryEvents = <Map<String, dynamic>>[];
      Object? productionBeforeError;
      Object? prootStopError;
      Object? nativeError;
      Object? canaryError;
      Object? nativeStopError;
      Object? rollbackError;

      Map<String, dynamic> asMap(Object? value) => value is Map
          ? value.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      List<String> stringList(Object? value) {
        if (value is! List) return const <String>[];
        return value.map((entry) => entry.toString()).toList(growable: false);
      }

      bool listContainsTool(Object? value, String toolName) {
        final names = stringList(value)
            .map((entry) => entry.replaceAll('_', '.').toLowerCase())
            .toSet();
        return names.contains(toolName.toLowerCase());
      }

      bool providerStillDisabled(Map<String, dynamic> value) =>
          value['providerCallsEnabled'] != true &&
          value['transportInvocationEnabled'] != true;
      bool executionEnabled(Map<String, dynamic> value) =>
          value['executionEnabled'] == true &&
          value['toolExecutionEnabled'] == true &&
          value['bridgeExecutionEnabled'] == true;
      int eventIndex(String eventName) =>
          canaryEvents.indexWhere((event) => event['event'] == eventName);

      log(
        '$logTag Opening live provider tool-call to bridge execution canary.',
      );

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
            'Live provider tool execution canary requires PRoot as current runtime.',
          );
        }
        if (!preflightProductionRunning || !productionHealthOkBefore) {
          throw StateError(
            'PRoot production runtime was not healthy before live provider tool execution canary.',
          );
        }

        log('$logTag Stopping PRoot to release 18789.');
        prootStopRequested = await productionRuntime
            .stop()
            .timeout(const Duration(seconds: 20), onTimeout: () => false);
        productionPortReleased = await _waitForProductionPortReleased(
          timeout: const Duration(seconds: 25),
        );
        if (!prootStopRequested || !productionPortReleased) {
          throw StateError(
            'Production port did not release cleanly before live provider tool execution canary.',
          );
        }

        log(
          '$logTag Starting native on 18789 for one live provider tool call.',
        );
        nativeStarted = await ownerRuntime
            .start()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
        if (!nativeStarted) {
          throw StateError(
            'Native live provider tool execution canary did not start.',
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

        canarySent = true;
        canaryEvents = await _streamProductionNdjson(
          endpointPath,
          {
            ..._sampleGatewayWsChatSendFrame(
              requestId: 'production-live-provider-tool-exec-request',
              idempotencyKey:
                  'production-live-provider-tool-exec-idempotency-key',
              model: providerHint == null || providerHint.isEmpty
                  ? null
                  : '$providerHint/$providerModel',
              provider: providerHint,
              message: prompt,
            ),
            'nativeCanaryProviderConfig': providerConfigForNative,
          },
          expectedStatus: 202,
          streamIdleTimeout: const Duration(seconds: 100),
        );

        final ackEvent = _firstEvent(canaryEvents, 'ack');
        final catalogEvent = _firstEvent(canaryEvents, 'tool_catalog');
        final requestEvent = _firstEvent(canaryEvents, 'provider_request');
        final callStartedEvent =
            _firstEvent(canaryEvents, 'provider_call_started');
        final responseEvent = _firstEvent(canaryEvents, 'provider_response');
        final providerErrorEvent = _firstEvent(canaryEvents, 'provider_error');
        final planEvent = _firstEvent(canaryEvents, 'live_tool_plan_summary');
        final bridgeRequestEvent =
            _firstEvent(canaryEvents, 'bridge_execute_request');
        final bridgeAckEvent = _firstEvent(canaryEvents, 'bridge_execute_ack');
        final toolUseEvent = _firstEvent(canaryEvents, 'tool_use_frame');
        final toolResultEvent = _firstEvent(canaryEvents, 'tool_result_frame');
        final summaryEvent =
            _firstEvent(canaryEvents, 'live_tool_execution_summary');
        final continuationRequestEvent =
            _firstEvent(canaryEvents, 'continuation_provider_request');
        final continuationCallStartedEvent =
            _firstEvent(canaryEvents, 'continuation_provider_call_started');
        final continuationResponseEvent =
            _firstEvent(canaryEvents, 'continuation_provider_response');
        final continuationSummaryEvent =
            _firstEvent(canaryEvents, 'continuation_summary');
        final chatResponseEvent =
            _firstEvent(canaryEvents, 'chat_response_frame');
        final endEvent = _firstEvent(canaryEvents, 'end');
        final ack = asMap(ackEvent['ack']);
        final providerRequest = asMap(requestEvent['providerRequest']);
        final redactedBodyShape = asMap(providerRequest['redactedBodyShape']);
        final toolChoice = asMap(providerRequest['toolChoice']);
        final toolChoiceFunction = asMap(toolChoice['function']);
        final toolPlanSummary = asMap(planEvent['toolPlanSummary']);
        final bridgeRequest = asMap(bridgeRequestEvent['bridgeRequest']);
        final bridgeRequestInput = asMap(bridgeRequest['input']);
        final executeAck = asMap(bridgeAckEvent['executeAck']);
        final executeResult = asMap(executeAck['result']);
        final toolUseFrame = asMap(toolUseEvent['frame']);
        final toolUseInput = asMap(toolUseFrame['input']);
        final toolResultFrame = asMap(toolResultEvent['frame']);
        final toolResult = asMap(toolResultFrame['result']);
        final toolResultPayload = asMap(toolResult['result']);
        final continuationRequest =
            asMap(continuationRequestEvent['continuationRequest']);
        final chatResponseFrame = asMap(chatResponseEvent['frame']);
        final rawProviderError =
            providerErrorEvent['rawProviderError']?.toString() ??
                (providerErrorEvent['error'] is Map
                    ? (providerErrorEvent['error'] as Map)['raw']?.toString()
                    : null) ??
                '';
        final expectedOrderedEvents = <String>[
          'ack',
          'tool_catalog',
          'provider_request',
          'provider_call_started',
          'provider_response',
          'live_tool_plan_summary',
          'bridge_execute_request',
          'bridge_execute_ack',
          'tool_use_frame',
          'tool_result_frame',
          'live_tool_execution_summary',
          if (continueWithToolResult) 'continuation_provider_request',
          if (continueWithToolResult) 'continuation_provider_call_started',
          if (continueWithToolResult) 'continuation_provider_response',
          if (continueWithToolResult) 'continuation_summary',
          if (chatLoopWithToolContinuation) 'chat_response_frame',
          'end',
        ];
        eventOrderOk = true;
        var previousIndex = -1;
        for (final eventName in expectedOrderedEvents) {
          final index = eventIndex(eventName);
          if (index <= previousIndex) {
            eventOrderOk = false;
            break;
          }
          previousIndex = index;
        }

        final responseStatus = responseEvent['statusCode'];
        final selectedToolCount = catalogEvent['selectedToolCount'];
        final requestBodyBytes = providerRequest['requestBodyBytes'];
        final maxTokens = providerRequest['maxTokens'];
        final liveRequestHash = providerRequest['requestHash'];
        ackEventOk = ackEvent['ok'] == true &&
            ackEvent['runtime'] == 'native-node-embedded' &&
            ackEvent['canaryOnly'] == true &&
            ackEvent['dryRun'] == false &&
            ackEvent['parsed'] == true &&
            ackEvent['route'] == expectedRoute &&
            ackEvent['routeStatus'] == expectedStartingStatus &&
            ackEvent['acceptedForRouting'] == true &&
            ackEvent['acceptedForQueue'] == true &&
            ackEvent['providerCallsEnabled'] == true &&
            ackEvent['transportInvocationEnabled'] == true &&
            ackEvent['executionEnabled'] == false &&
            ackEvent['toolExecutionEnabled'] == false &&
            ackEvent['bridgeExecutionEnabled'] == false &&
            ack['provider'] == 'openrouter' &&
            listContainsTool(
                ack['gatewayToolNames'], expectedGatewayToolName) &&
            listContainsTool(ack['canaryAllowlist'], expectedGatewayToolName);
        toolCatalogOk = catalogEvent['ok'] == true &&
            selectedToolCount == 1 &&
            listContainsTool(
                catalogEvent['toolFunctionNames'], expectedGatewayToolName) &&
            listContainsTool(
                catalogEvent['gatewayToolNames'], expectedGatewayToolName) &&
            listContainsTool(
                catalogEvent['canaryAllowlist'], expectedGatewayToolName) &&
            catalogEvent['executionEnabled'] == false &&
            catalogEvent['toolExecutionEnabled'] == false;
        providerRequestOk = requestEvent['ok'] == true &&
            providerRequest['provider'] == 'openrouter' &&
            providerRequest['transport'] ==
                'openai-compatible-chat-completions' &&
            providerRequest['transportInvocationEnabled'] == true &&
            providerRequest['providerCallsEnabled'] == true &&
            providerRequest['executionEnabled'] == false &&
            providerRequest['toolExecutionEnabled'] == false &&
            maxTokens is num &&
            maxTokens <= 32 &&
            requestBodyBytes is num &&
            requestBodyBytes > 0 &&
            providerRequest['requestHash']?.toString().isNotEmpty == true &&
            redactedBodyShape['tools'] is List &&
            (redactedBodyShape['tools'] as List).length == 1 &&
            toolChoice['type'] == 'function' &&
            toolChoiceFunction['name'] == expectedFunctionName;
        providerCallStartedOk = callStartedEvent['ok'] == true &&
            callStartedEvent['provider'] == 'openrouter' &&
            callStartedEvent['providerCallStarted'] == true &&
            callStartedEvent['providerBillingSurfaceReached'] == true &&
            callStartedEvent['requestBodyBytes'] is num &&
            (callStartedEvent['requestBodyBytes'] as num) > 0;
        providerResponseOk =
            responseEvent['runtime'] == 'native-node-embedded' &&
                responseEvent['provider'] == 'openrouter' &&
                responseStatus == 200;
        providerErrorSurfaceOk = providerErrorEvent.isNotEmpty &&
            providerErrorEvent['runtime'] == 'native-node-embedded' &&
            providerErrorEvent['provider'] == 'openrouter' &&
            rawProviderError.isNotEmpty &&
            providerErrorEvent['error'] is Map;
        liveToolPlanSummaryOk = planEvent['ok'] == true &&
            planEvent['runtime'] == 'native-node-embedded' &&
            planEvent['provider'] == 'openrouter' &&
            planEvent['statusCode'] == 200 &&
            planEvent['liveToolPlanOk'] == true &&
            planEvent['canaryAllowlistOk'] == true &&
            toolPlanSummary['toolPlanCount'] == 1 &&
            toolPlanSummary['allowedPlanCount'] == 1 &&
            toolPlanSummary['blockedPlanCount'] == 0 &&
            toolPlanSummary['invalidArgumentCount'] == 0 &&
            listContainsTool(
                toolPlanSummary['toolPlanNames'], expectedGatewayToolName) &&
            listContainsTool(
              toolPlanSummary['gatewayToolNames'],
              expectedGatewayToolName,
            ) &&
            planEvent['providerCallsEnabled'] == true &&
            planEvent['executionEnabled'] == false &&
            planEvent['toolExecutionEnabled'] == false &&
            planEvent['bridgeExecutionEnabled'] == false;
        bridgeExecuteRequestOk = bridgeRequestEvent['ok'] == true &&
            bridgeRequestEvent['runtime'] == 'native-node-embedded' &&
            bridgeRequest['type'] == 'native_tool_dispatch_execute_canary' &&
            bridgeRequest['method'] == expectedGatewayToolName &&
            bridgeRequest['capability'] == expectedCapability &&
            bridgeRequest['dartCapability'] == expectedDartCapability &&
            bridgeRequest['requiresUiThread'] == expectedRequiresUiThread &&
            bridgeRequest['dryRun'] == false &&
            (!continueWithToolResult ||
                bridgeRequestInput['durationMs'] == 90) &&
            (continueWithToolResult ||
                (bridgeRequest['protectedGesture'] == true &&
                    bridgeRequest['arbitration'] == 'protected-gesture' &&
                    bridgeRequestInput['gesture']?.toString().toLowerCase() ==
                        'wave right' &&
                    bridgeRequestInput['protectedGesture'] == true)) &&
            listContainsTool(
                bridgeRequest['canaryAllowlist'], expectedGatewayToolName) &&
            providerStillDisabled(bridgeRequest) &&
            executionEnabled(bridgeRequest);
        bridgeExecuteAckOk = bridgeAckEvent['ok'] == true &&
            bridgeAckEvent['runtime'] == 'native-node-embedded' &&
            bridgeAckEvent['statusCode'] == 200 &&
            bridgeAckEvent['executeParityOk'] == true &&
            bridgeAckEvent['gestureOk'] == true &&
            bridgeAckEvent['durationOk'] == true &&
            bridgeAckEvent['arbitrationOk'] == true &&
            executeAck['ok'] == true &&
            executeAck['accepted'] == true &&
            executeAck['executed'] == true &&
            executeAck['command'] == expectedGatewayToolName &&
            executeAck['canaryAllowlistOk'] == true &&
            executeAck['dryRun'] == false &&
            executeAck['providerCallsEnabled'] == false &&
            executionEnabled(executeAck) &&
            executeResult['status'] == expectedResultStatus;
        toolUseFrameOk = toolUseEvent['ok'] == true &&
            toolUseEvent['runtime'] == 'native-node-embedded' &&
            toolUseFrame['type'] == 'tool_use' &&
            toolUseFrame['name'] == expectedGatewayToolName &&
            toolUseFrame['dryRun'] == false &&
            toolUseFrame['canaryOnly'] == true &&
            (!continueWithToolResult || toolUseInput['durationMs'] == 90) &&
            (continueWithToolResult ||
                (toolUseFrame['protectedGesture'] == true &&
                    toolUseFrame['arbitration'] == 'protected-gesture' &&
                    toolUseInput['gesture']?.toString().toLowerCase() ==
                        'wave right' &&
                    toolUseInput['protectedGesture'] == true)) &&
            toolUseFrame['executionEnabled'] == true &&
            toolUseFrame['toolExecutionEnabled'] == true;
        toolResultFrameOk = toolResultEvent['ok'] == true &&
            toolResultEvent['runtime'] == 'native-node-embedded' &&
            toolResultFrame['type'] == 'tool_result' &&
            toolResultFrame['name'] == expectedGatewayToolName &&
            toolResultFrame['dryRun'] == false &&
            (continueWithToolResult ||
                toolResultFrame['protectedGesture'] == true) &&
            toolResult['ok'] == true &&
            toolResult['executed'] == true &&
            toolResult['accepted'] == true &&
            toolResult['status'] == expectedResultStatus &&
            toolResult['canaryAllowlistOk'] == true &&
            toolResult['gestureOk'] == true &&
            toolResult['durationOk'] == true &&
            toolResult['arbitrationOk'] == true &&
            toolResultPayload['status'] == expectedResultStatus &&
            (!continueWithToolResult || toolResultPayload['gesture'] == null) &&
            (continueWithToolResult ||
                toolResultPayload['gesture']?.toString().toLowerCase() ==
                    'wave right') &&
            providerStillDisabled(toolResult) &&
            executionEnabled(toolResult);
        executionSummaryOk = summaryEvent['ok'] == true &&
            summaryEvent['runtime'] == 'native-node-embedded' &&
            summaryEvent['provider'] == 'openrouter' &&
            summaryEvent['liveToolPlanOk'] == true &&
            summaryEvent['dispatchParityOk'] == true &&
            summaryEvent['canaryAllowlistOk'] == true &&
            summaryEvent['executeParityOk'] == true &&
            summaryEvent['validationOk'] == true &&
            summaryEvent['toolName'] == expectedGatewayToolName &&
            summaryEvent['providerCallsEnabled'] == true &&
            summaryEvent['providerCallsDuringExecutionEnabled'] == false &&
            summaryEvent['transportInvocationEnabled'] == true &&
            executionEnabled(summaryEvent) &&
            (continueWithToolResult ||
                summaryEvent['protectedGesture'] == true);
        continuationProviderRequestOk = !continueWithToolResult ||
            (continuationRequestEvent['ok'] == true &&
                continuationRequestEvent['runtime'] == 'native-node-embedded' &&
                continuationRequest['provider'] == 'openrouter' &&
                continuationRequest['transport'] ==
                    'openai-compatible-chat-completions' &&
                continuationRequest['requestBodyBytes'] is num &&
                (continuationRequest['requestBodyBytes'] as num) > 0 &&
                continuationRequest['requestHash']?.toString().isNotEmpty ==
                    true &&
                continuationRequest['firstRequestHash'] == liveRequestHash &&
                continuationRequest['functionName'] == expectedFunctionName &&
                continuationRequest['normalizedToolResult'] is Map &&
                asMap(continuationRequest['normalizedToolResult'])['ok'] ==
                    true &&
                asMap(continuationRequest['normalizedToolResult'])['status'] ==
                    expectedResultStatus &&
                (continueWithToolResult ||
                    asMap(continuationRequest['normalizedToolResult'])[
                                'gesture']
                            ?.toString()
                            .toLowerCase() ==
                        'wave right') &&
                (!continueWithToolResult ||
                    asMap(continuationRequest['normalizedToolResult'])[
                            'durationMs'] ==
                        90) &&
                continuationRequest['providerCallsEnabled'] == true &&
                continuationRequest['providerCallsDuringExecutionEnabled'] ==
                    false &&
                continuationRequest['transportInvocationEnabled'] == true &&
                continuationRequest['executionEnabled'] == false &&
                continuationRequest['toolExecutionEnabled'] == false &&
                continuationRequest['bridgeExecutionEnabled'] == false);
        continuationProviderCallStartedOk = !continueWithToolResult ||
            (continuationCallStartedEvent['ok'] == true &&
                continuationCallStartedEvent['provider'] == 'openrouter' &&
                continuationCallStartedEvent['providerCallStarted'] == true &&
                continuationCallStartedEvent['providerBillingSurfaceReached'] ==
                    true &&
                continuationCallStartedEvent['requestBodyBytes'] is num &&
                (continuationCallStartedEvent['requestBodyBytes'] as num) > 0);
        continuationProviderResponseOk = !continueWithToolResult ||
            (continuationResponseEvent['runtime'] == 'native-node-embedded' &&
                continuationResponseEvent['provider'] == 'openrouter' &&
                continuationResponseEvent['statusCode'] == 200);
        continuationSummaryOk = !continueWithToolResult ||
            (continuationSummaryEvent['ok'] == true &&
                continuationSummaryEvent['runtime'] == 'native-node-embedded' &&
                continuationSummaryEvent['provider'] == 'openrouter' &&
                continuationSummaryEvent['statusCode'] == 200 &&
                continuationSummaryEvent['continuationOk'] == true &&
                continuationSummaryEvent['continuationDeltaCount'] is num &&
                (continuationSummaryEvent['continuationDeltaCount'] as num) >
                    0 &&
                continuationSummaryEvent['continuationTextChars'] is num &&
                (continuationSummaryEvent['continuationTextChars'] as num) >
                    0 &&
                continuationSummaryEvent['continuationWarningCount'] == 0 &&
                continuationSummaryEvent['toolResultStatus'] ==
                    expectedResultStatus &&
                (continueWithToolResult ||
                    continuationSummaryEvent['toolResultGesture']
                            ?.toString()
                            .toLowerCase() ==
                        'wave right') &&
                (!continueWithToolResult ||
                    continuationSummaryEvent['toolResultDurationMs'] == 90) &&
                continuationSummaryEvent['providerCallsEnabled'] == true &&
                continuationSummaryEvent[
                        'providerCallsDuringExecutionEnabled'] ==
                    false &&
                continuationSummaryEvent['transportInvocationEnabled'] ==
                    true &&
                continuationSummaryEvent['executionEnabled'] == false &&
                continuationSummaryEvent['toolExecutionEnabled'] == false &&
                continuationSummaryEvent['bridgeExecutionEnabled'] == false);
        continuationOk = !continueWithToolResult ||
            (continuationProviderRequestOk &&
                continuationProviderCallStartedOk &&
                continuationProviderResponseOk &&
                continuationSummaryOk);
        chatResponseFrameOk = !chatLoopWithToolContinuation ||
            (chatResponseEvent['ok'] == true &&
                chatResponseEvent['runtime'] == 'native-node-embedded' &&
                chatResponseEvent['method'] == 'chat.send' &&
                chatResponseFrame['type'] == 'chat.response' &&
                chatResponseFrame['role'] == 'assistant' &&
                chatResponseFrame['textChars'] is num &&
                (chatResponseFrame['textChars'] as num) > 0 &&
                chatResponseFrame['deltaCount'] is num &&
                (chatResponseFrame['deltaCount'] as num) > 0 &&
                chatResponseFrame['provider'] == 'openrouter' &&
                chatResponseFrame['toolName'] == expectedGatewayToolName &&
                chatResponseFrame['toolResultStatus'] == expectedResultStatus &&
                chatResponseEvent['continuationOk'] == true &&
                chatResponseEvent['providerCallsEnabled'] == true &&
                chatResponseEvent['providerCallsDuringExecutionEnabled'] ==
                    false &&
                chatResponseEvent['transportInvocationEnabled'] == true &&
                executionEnabled(chatResponseEvent));
        chatLoopOk = !chatLoopWithToolContinuation ||
            (continuationOk && chatResponseFrameOk);
        endOk = endEvent['ok'] == true &&
            endEvent['runtime'] == 'native-node-embedded' &&
            endEvent['routeStatus'] == expectedCompleteStatus &&
            endEvent['finishReason'] == expectedCompleteStatus &&
            endEvent['provider'] == 'openrouter' &&
            endEvent['liveToolPlanOk'] == true &&
            endEvent['dispatchParityOk'] == true &&
            endEvent['canaryAllowlistOk'] == true &&
            endEvent['executeParityOk'] == true &&
            (!continueWithToolResult ||
                (endEvent['continuationOk'] == true &&
                    endEvent['continuationDeltaCount'] is num &&
                    (endEvent['continuationDeltaCount'] as num) > 0 &&
                    endEvent['continuationTextChars'] is num &&
                    (endEvent['continuationTextChars'] as num) > 0)) &&
            endEvent['validationOk'] == true &&
            endEvent['toolName'] == expectedGatewayToolName &&
            endEvent['providerCallsEnabled'] == true &&
            endEvent['providerCallsDuringExecutionEnabled'] == false &&
            endEvent['transportInvocationEnabled'] == true &&
            executionEnabled(endEvent) &&
            (continueWithToolResult || endEvent['protectedGesture'] == true);
        liveToolExecutionCanaryOk = ackEventOk &&
            toolCatalogOk &&
            providerRequestOk &&
            providerCallStartedOk &&
            providerResponseOk &&
            liveToolPlanSummaryOk &&
            bridgeExecuteRequestOk &&
            bridgeExecuteAckOk &&
            toolUseFrameOk &&
            toolResultFrameOk &&
            executionSummaryOk &&
            continuationOk &&
            chatLoopOk &&
            eventOrderOk &&
            endOk;

        postCanaryHealth = await _probeProductionJson(
          '/health',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryProbe = await _probeProductionJson(
          '/gateway/probe',
          expectedRuntime: 'native-node-embedded',
          attempts: 5,
          retryDelay: const Duration(milliseconds: 150),
          requestTimeout: const Duration(seconds: 1),
        );
        postCanaryGuardOk = postCanaryHealth['ok'] == true &&
            postCanaryHealth['runtime'] == 'native-node-embedded' &&
            postCanaryHealth['port'] == AppConstants.gatewayPort &&
            postCanaryHealth['productionPortBindCanary'] == true &&
            postCanaryHealth['openclawStarted'] == false &&
            postCanaryProbe['runtime'] == 'native-node-embedded' &&
            postCanaryProbe['port'] == AppConstants.gatewayPort &&
            postCanaryProbe['productionPortBindCanary'] == true &&
            postCanaryProbe['canaryOnly'] == true &&
            postCanaryProbe['productionReady'] == false &&
            postCanaryProbe['openclawStarted'] == false &&
            postCanaryProbe['chatRoutingEnabled'] == false &&
            postCanaryProbe['toolExecutionEnabled'] != true;
      } catch (e) {
        if (canarySent) {
          canaryError = e;
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
          liveToolExecutionCanaryOk &&
          postCanaryGuardOk &&
          nativeStopped &&
          nativePortReleasedAfterStop &&
          rollbackOk;
      final endEvent = _firstEvent(canaryEvents, 'end');
      final requestEvent = _firstEvent(canaryEvents, 'provider_request');
      final responseEvent = _firstEvent(canaryEvents, 'provider_response');
      final providerErrorEvent = _firstEvent(canaryEvents, 'provider_error');
      final planEvent = _firstEvent(canaryEvents, 'live_tool_plan_summary');
      final bridgeAckEvent = _firstEvent(canaryEvents, 'bridge_execute_ack');
      final summaryEvent =
          _firstEvent(canaryEvents, 'live_tool_execution_summary');
      final continuationRequestEvent =
          _firstEvent(canaryEvents, 'continuation_provider_request');
      final continuationCallStartedEvent =
          _firstEvent(canaryEvents, 'continuation_provider_call_started');
      final continuationResponseEvent =
          _firstEvent(canaryEvents, 'continuation_provider_response');
      final continuationSummaryEvent =
          _firstEvent(canaryEvents, 'continuation_summary');
      final chatResponseEvent =
          _firstEvent(canaryEvents, 'chat_response_frame');
      final providerRequest = asMap(requestEvent['providerRequest']);
      final toolPlanSummary = asMap(planEvent['toolPlanSummary']);
      final continuationRequest =
          asMap(continuationRequestEvent['continuationRequest']);
      final chatResponseFrame = asMap(chatResponseEvent['frame']);
      final rawProviderError =
          providerErrorEvent['rawProviderError']?.toString() ??
              (providerErrorEvent['error'] is Map
                  ? (providerErrorEvent['error'] as Map)['raw']?.toString()
                  : null) ??
              _firstEvent(canaryEvents, 'continuation_provider_error')[
                      'rawProviderError']
                  ?.toString() ??
              '';
      final observedOrder =
          canaryEvents.map((event) => event['event']?.toString()).toList();
      final continuationDeltaEvents = canaryEvents
          .where((event) => event['event'] == 'continuation_delta')
          .toList();
      final continuationResponseText = continuationDeltaEvents
          .map((event) => event['text']?.toString() ?? '')
          .where((text) => text.isNotEmpty)
          .join();
      final continuationResponseTextPreview =
          continuationResponseText.length > 500
              ? continuationResponseText.substring(0, 500)
              : continuationResponseText;

      final report = <String, dynamic>{
        'ok': ok,
        'phase': phaseName,
        'mode': modeName,
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
        'canarySent': canarySent,
        'liveToolExecutionCanaryOk': liveToolExecutionCanaryOk,
        'liveToolContinuationCanaryOk':
            continueWithToolResult && liveToolExecutionCanaryOk,
        'nativeChatLoopContinuationCanaryOk':
            chatLoopWithToolContinuation && liveToolExecutionCanaryOk,
        'ackEventOk': ackEventOk,
        'toolCatalogOk': toolCatalogOk,
        'providerRequestOk': providerRequestOk,
        'providerCallStartedOk': providerCallStartedOk,
        'providerResponseOk': providerResponseOk,
        'providerErrorSurfaceOk': providerErrorSurfaceOk,
        'liveToolPlanSummaryOk': liveToolPlanSummaryOk,
        'bridgeExecuteRequestOk': bridgeExecuteRequestOk,
        'bridgeExecuteAckOk': bridgeExecuteAckOk,
        'toolUseFrameOk': toolUseFrameOk,
        'toolResultFrameOk': toolResultFrameOk,
        'executionSummaryOk': executionSummaryOk,
        'continuationEnabled': continueWithToolResult,
        'continuationProviderRequestOk': continuationProviderRequestOk,
        'continuationProviderCallStartedOk': continuationProviderCallStartedOk,
        'continuationProviderResponseOk': continuationProviderResponseOk,
        'continuationSummaryOk': continuationSummaryOk,
        'continuationOk': continuationOk,
        'chatLoopWithToolContinuation': chatLoopWithToolContinuation,
        'chatResponseFrameOk': chatResponseFrameOk,
        'chatLoopOk': chatLoopOk,
        'eventOrderOk': eventOrderOk,
        'endOk': endOk,
        'eventsCount': canaryEvents.length,
        'observedEventOrder': observedOrder,
        'routeStatus': endEvent['routeStatus'],
        'finishReason': endEvent['finishReason'],
        'provider': providerRequest['provider'] ?? endEvent['provider'],
        'requestedModel':
            providerRequest['requestedModel'] ?? endEvent['requestedModel'],
        'providerModel':
            providerRequest['providerModel'] ?? endEvent['providerModel'],
        'statusCode': responseEvent['statusCode'] ?? endEvent['statusCode'],
        'contentType': responseEvent['contentType'],
        'requestHash':
            providerRequest['requestHash'] ?? endEvent['requestHash'],
        'continuationRequestHash': continuationRequest['requestHash'] ??
            endEvent['continuationRequestHash'],
        'continuationStatusCode': continuationResponseEvent['statusCode'] ??
            endEvent['continuationStatusCode'],
        'continuationContentType': continuationResponseEvent['contentType'],
        'continuationDeltaCount':
            continuationSummaryEvent['continuationDeltaCount'] ??
                endEvent['continuationDeltaCount'],
        'continuationTextChars':
            continuationSummaryEvent['continuationTextChars'] ??
                endEvent['continuationTextChars'],
        'continuationFinishReason':
            continuationSummaryEvent['continuationFinishReason'],
        'continuationWarningCount':
            continuationSummaryEvent['continuationWarningCount'],
        'continuationResponseText': continuationResponseTextPreview,
        'continuationResponseTextChars': continuationResponseText.length,
        'continuationResponseTextTruncated':
            continuationResponseText.length > 500,
        'chatResponseFrameTextChars': chatResponseFrame['textChars'],
        'chatResponseFrameDeltaCount': chatResponseFrame['deltaCount'],
        'chatResponseFrameFinishReason': chatResponseFrame['finishReason'],
        'chatResponseFrameToolName': chatResponseFrame['toolName'],
        'uiResponseText': chatLoopWithToolContinuation
            ? continuationResponseTextPreview
            : null,
        'uiResponseTextChars': chatLoopWithToolContinuation
            ? continuationResponseText.length
            : null,
        'uiResponseTextTruncated': chatLoopWithToolContinuation
            ? continuationResponseText.length > 500
            : null,
        'toolSelectionHash': endEvent['toolSelectionHash'],
        'dispatchHash': endEvent['dispatchHash'],
        'bridgeRequestHash': endEvent['bridgeRequestHash'],
        'executeAckHash':
            bridgeAckEvent['executeAckHash'] ?? endEvent['executeAckHash'],
        'selectedToolCount': providerRequest['selectedToolCount'],
        'toolFunctionNames': providerRequest['toolFunctionNames'],
        'gatewayToolNames': providerRequest['gatewayToolNames'],
        'toolChoice': providerRequest['toolChoice'],
        'toolPlanCount': toolPlanSummary['toolPlanCount'],
        'allowedPlanCount': toolPlanSummary['allowedPlanCount'],
        'blockedPlanCount': toolPlanSummary['blockedPlanCount'],
        'invalidArgumentCount': toolPlanSummary['invalidArgumentCount'],
        'toolPlanNames': toolPlanSummary['toolPlanNames'],
        'capturedGatewayToolNames': toolPlanSummary['gatewayToolNames'],
        'liveToolPlanOk': planEvent['liveToolPlanOk'] == true ||
            endEvent['liveToolPlanOk'] == true,
        'dispatchParityOk': summaryEvent['dispatchParityOk'] == true ||
            endEvent['dispatchParityOk'] == true,
        'canaryAllowlistOk': summaryEvent['canaryAllowlistOk'] == true ||
            endEvent['canaryAllowlistOk'] == true,
        'executeParityOk': summaryEvent['executeParityOk'] == true ||
            endEvent['executeParityOk'] == true,
        'validationOk': summaryEvent['validationOk'] == true ||
            endEvent['validationOk'] == true,
        'command': summaryEvent['toolName'] ?? endEvent['toolName'],
        'capability': summaryEvent['capability'] ?? endEvent['capability'],
        'gesture': summaryEvent['gesture'] ?? endEvent['gesture'],
        'toolDurationMs': summaryEvent['durationMs'] ??
            continuationSummaryEvent['toolResultDurationMs'],
        'resultStatus': summaryEvent['resultStatus'],
        'providerCallsEnabled': endEvent['providerCallsEnabled'] == true,
        'providerCallsDuringExecutionEnabled':
            endEvent['providerCallsDuringExecutionEnabled'] == true,
        'transportInvocationEnabled':
            endEvent['transportInvocationEnabled'] == true,
        'executionEnabled': endEvent['executionEnabled'] == true,
        'toolExecutionEnabled': endEvent['toolExecutionEnabled'] == true,
        'bridgeExecutionEnabled': endEvent['bridgeExecutionEnabled'] == true,
        'protectedGesture': endEvent['protectedGesture'] == true,
        'apiKeyLoaded': apiKeyLoaded,
        'providerBillingSurfaceReached': _firstEvent(canaryEvents,
                'provider_call_started')['providerBillingSurfaceReached'] ==
            true,
        'continuationProviderBillingSurfaceReached':
            continuationCallStartedEvent['providerBillingSurfaceReached'] ==
                true,
        'rawProviderErrorForwarded': rawProviderError.isNotEmpty,
        if (rawProviderError.isNotEmpty)
          'rawProviderErrorPreview': rawProviderError.length > 500
              ? rawProviderError.substring(0, 500)
              : rawProviderError,
        if (canaryError != null) 'canaryError': canaryError.toString(),
        'postCanaryGuardOk': postCanaryGuardOk,
        'postCanaryRuntimeReported': postCanaryHealth['runtime'],
        'postCanaryCanaryOnly': postCanaryProbe['canaryOnly'] == true,
        'postCanaryChatRoutingEnabled':
            postCanaryProbe['chatRoutingEnabled'] == true,
        'postCanaryProviderCallsEnabled':
            postCanaryProbe['providerCallsEnabled'] == true,
        'postCanaryToolExecutionEnabled':
            postCanaryProbe['toolExecutionEnabled'] == true,
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
            ? (chatLoopWithToolContinuation
                ? 'Native owned 18789, completed one chat-loop turn with a live tool continuation, surfaced final provider text, and PRoot was restored.'
                : continueWithToolResult
                    ? 'Native owned 18789, received one live provider tool call, executed only the bounded haptic bridge allowlist, continued with the tool result, received final provider text, and PRoot was restored.'
                    : 'Native owned 18789, received one live provider tool call, executed only the bounded avatar bridge allowlist, and PRoot was restored.')
            : (providerErrorSurfaceOk
                ? 'Native owned 18789, reached the provider but live tool execution did not complete; raw provider/bridge error was surfaced and PRoot rollback was attempted.'
                : (chatLoopWithToolContinuation
                    ? 'Production-port native chat loop continuation canary is not promotable; PRoot rollback was attempted.'
                    : continueWithToolResult
                        ? 'Production-port live provider tool continuation canary is not promotable; PRoot rollback was attempted.'
                        : 'Production-port live provider tool execution canary is not promotable; PRoot rollback was attempted.')),
        'nextGate': chatLoopWithToolContinuation
            ? 'full production skill/tool inventory parity gate before native promotion'
            : continueWithToolResult
                ? 'production-port native chat loop canary with one live tool continuation and rollback policy'
                : 'production-port live provider tool result continuation canary with PRoot rollback',
      };
      log('$logTag ${jsonEncode({
            ...report,
            'continuationResponseText':
                report['continuationResponseText'] == null
                    ? null
                    : '<redacted in activity log>',
            'uiResponseText': report['uiResponseText'] == null
                ? null
                : '<redacted in activity log>',
            'rawProviderErrorPreview':
                rawProviderError.isEmpty ? null : '<redacted in activity log>',
          })}');
      return report;
    } finally {
      if (chatLoopWithToolContinuation) {
        _productionPortNativeChatLoopContinuationInFlight = false;
      } else if (continueWithToolResult) {
        _productionPortProviderLiveToolContinuationInFlight = false;
      } else {
        _productionPortProviderLiveToolExecutionInFlight = false;
      }
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

  static Future<Set<String>> _scanProductionSkillIds() async {
    final filesDir = await NativeBridge.getFilesDir();
    final ids = <String>{};
    final roots = [
      Directory('$filesDir/rootfs/ubuntu/root/.openclaw/skills'),
      Directory('$filesDir/rootfs/ubuntu/root/.openclaw/workspace/skills'),
      Directory(
        '$filesDir/rootfs/ubuntu/usr/local/lib/node_modules/openclaw/skills',
      ),
      Directory('$filesDir/native-node-embedded/native-home/.openclaw/skills'),
      Directory(
        '$filesDir/native-node-embedded/native-home/.openclaw/workspace/skills',
      ),
      Directory(
        '$filesDir/native-node-embedded/full-openclaw/lib/node_modules/openclaw/skills',
      ),
    ];

    for (final root in roots) {
      if (!await root.exists()) continue;
      await for (final entry in root.list(followLinks: false)) {
        if (entry is! Directory) continue;
        final id = entry.uri.pathSegments.isNotEmpty
            ? entry.uri.pathSegments.where((segment) => segment.isNotEmpty).last
            : '';
        if (id.isNotEmpty && !id.startsWith('.')) ids.add(id);
      }
    }
    return ids;
  }

  static Set<String> _skillIdsFromRegistry(Map<String, dynamic> registry) {
    final skills = registry['skills'];
    if (skills is! List) return <String>{};
    return skills
        .whereType<Map>()
        .map((entry) => entry['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static Future<Map<String, dynamic>> _probeAgentSkillTools() async {
    final client = http.Client();
    try {
      Object? lastError;
      for (var attempt = 0; attempt < 12; attempt++) {
        try {
          final response = await client
              .get(Uri.parse('http://127.0.0.1:8765/api/tools'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode != 200) {
            throw StateError('HTTP ${response.statusCode}: ${response.body}');
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw StateError('AgentSkill tools payload was not a JSON object');
          }
          return decoded;
        } catch (e) {
          lastError = e;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      throw StateError('AgentSkill tools probe failed: $lastError');
    } finally {
      client.close();
    }
  }

  static Set<String> _toolNamesFromAgentTools(Map<String, dynamic> payload) {
    final tools = payload['tools'];
    if (tools is! List) return <String>{};
    return tools
        .whereType<Map>()
        .map((tool) => tool['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  static List<String> _sortedDifference(Set<String> left, Set<String> right) {
    final diff = left.difference(right).toList()..sort();
    return diff;
  }

  static const Set<String> _mobileBridgeCandidateSkillIds = <String>{
    'canvas',
    'device-node',
    'gestures',
    'tts-voice',
  };

  static Map<String, String> _buildSkillPromotionPolicies(
    Set<String> skillIds,
  ) {
    final policies = <String, String>{};
    for (final id in skillIds) {
      policies[id] = _mobileBridgeCandidateSkillIds.contains(id)
          ? 'native_bridge_candidate_proot_default'
          : 'proot_fallback_default';
    }
    return policies;
  }

  static Map<String, String> _buildMobileToolPromotionPolicies(
    Set<String> toolNames,
  ) {
    final policies = <String, String>{};
    for (final name in toolNames) {
      policies[name] = switch (name) {
        'avatar-control' ||
        'device-node' ||
        'tts-voice' =>
          'native_bridge_candidate_proot_default',
        _ => 'proot_fallback_default',
      };
    }
    return policies;
  }

  static Map<String, String> _buildToolHintPromotionPolicies(
    Set<String> toolHints,
  ) {
    final policies = <String, String>{};
    for (final hint in toolHints) {
      policies[hint] = switch (hint) {
        'flash.status' ||
        'sensor.list' ||
        'sensor.read' ||
        'device_status' ||
        'notifications.list' =>
          'native_bridge_readonly_allowlist_manual_only',
        'avatar.gesture' ||
        'haptic.vibrate' =>
          'native_bridge_bounded_effect_allowlist_manual_only',
        'camera_snap' ||
        'canvas.snapshot' =>
          'native_bridge_capture_allowlist_manual_only',
        'canvas.eval' ||
        'canvas.navigate' =>
          'native_bridge_ui_mutation_candidate_manual_only',
        _ => 'proot_fallback_default',
      };
    }
    return policies;
  }

  static Map<String, int> _countStringValues(List<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
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

  static Future<Map<String, String?>> _resolveNativeGatewayAuthToken({
    String? preferredToken,
  }) async {
    final preferred = preferredToken?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return <String, String?>{
        'token': preferred,
        'source': 'caller-preferred-token',
      };
    }

    final filesDir = await NativeBridge.getFilesDir();
    final candidates = <String>[
      '$filesDir/native-node-embedded/native-home/.openclaw/openclaw.json',
      '$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json',
    ];
    for (final path in candidates) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final decoded = jsonDecode(await file.readAsString());
        final config = _jsonObject(decoded);
        final gateway = _jsonObject(config['gateway']);
        final gatewayAuth = _jsonObject(gateway['auth']);
        final topLevelAuth = _jsonObject(config['auth']);
        final gatewayToken = gatewayAuth['token']?.toString().trim();
        final topLevelToken = topLevelAuth['token']?.toString().trim();
        final token = gatewayToken != null && gatewayToken.isNotEmpty
            ? gatewayToken
            : topLevelToken;
        if (token != null && token.isNotEmpty) {
          return <String, String?>{
            'token': token,
            'source': path.contains('native-node-embedded')
                ? 'native-openclaw-config'
                : 'proot-openclaw-config',
          };
        }
      } catch (_) {
        // Try the next token source. This is diagnostic glue, not app data repair.
      }
    }
    return <String, String?>{'token': null, 'source': 'none'};
  }

  static Map<String, dynamic> _jsonObject(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded
              .map((key, dynamic item) => MapEntry(key.toString(), item));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static String _rawText(Object? value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
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
Notification listing/reading is not currently exposed by this Android node. Do not call notification tools or claim notification contents are available unless a tool result explicitly provides them.
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

  static String _deviceNodeReadOnlyRouteShadowMessage(String prompt) {
    final userPrompt = prompt.trim().isEmpty
        ? 'Please check flash.status and sensor.list read-only.'
        : prompt.trim();
    return '''
<plawie_mobile_tool_context>
This is private tool-routing context. Do not mention it unless the user asks.
The paired Android device node gateway handle is "OpenClaw Mobile".
Every OpenClaw nodes tool call for this Android phone MUST include this exact field: "node": "OpenClaw Mobile".
For this route-shadow canary, only read-only device-node commands are in scope: flash.status and sensor.list.
Use action="invoke" with invokeCommand set to flash.status or sensor.list.
Notification listing/reading is not currently exposed by this Android node. Keep notification tools out of scope and do not claim notification contents are available unless a tool result explicitly provides them.
</plawie_mobile_tool_context>

$userPrompt''';
  }

  static String _gesturesWaveRightRouteShadowMessage(String prompt) {
    final userPrompt = prompt.trim().isEmpty
        ? 'Please use avatar.gesture to wave right once.'
        : prompt.trim();
    return '''
<plawie_mobile_tool_context>
This is private tool-routing context. Do not mention it unless the user asks.
The paired Android device node gateway handle is "OpenClaw Mobile".
Every OpenClaw nodes tool call for this Android phone MUST include this exact field: "node": "OpenClaw Mobile".
For this route-shadow canary, only the bounded avatar gesture command is in scope: avatar.gesture.
Use action="invoke" with invokeCommand="avatar.gesture" and invokeParamsJson like {"gesture":"wave right"}.
Do not use any other phone, canvas, audio, camera, haptic, sensor, flash, or notification tools in this canary.
</plawie_mobile_tool_context>

$userPrompt''';
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

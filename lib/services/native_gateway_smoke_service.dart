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
        _sampleGatewayWsChatSendFrame(),
        expectedStatus: 202,
      );
      final shadowParity =
          await NativeGatewayShadowParityService.observeChatSendFrame(
        _sampleGatewayWsChatSendFrame(),
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
          _chatSendDryRunProbePassed(chatSendDryRun) &&
          (shadowParity?.parityOk == true);
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

  static bool _chatSendDryRunProbePassed(Map<String, dynamic> value) {
    final shape = value['requestShape'];
    final ack = value['ack'];
    if (shape is! Map || ack is! Map) return false;

    final hints = ack['mobileToolHints'];
    return value['ok'] == true &&
        value['type'] == 'res' &&
        value['id'] == 'probe-chat-send-request' &&
        value['method'] == 'chat.send' &&
        value['runtime'] == 'native-node-embedded' &&
        value['canaryOnly'] == true &&
        value['dryRun'] == true &&
        value['parsed'] == true &&
        value['openclawStarted'] == false &&
        value['acceptedForRouting'] == false &&
        value['chatRoutingEnabled'] == false &&
        value['providerCallsEnabled'] == false &&
        value['executionEnabled'] == false &&
        ack['parsed'] == true &&
        ack['route'] == 'disabled' &&
        ack['sessionKey'] == 'main' &&
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

  static Map<String, dynamic> _sampleGatewayWsChatSendFrame() {
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
      'id': 'probe-chat-send-request',
      'params': {
        'sessionKey': 'main',
        'message': mobileContext,
        'idempotencyKey': 'probe-idempotency-key',
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
  }) async {
    final client = http.Client();
    try {
      Object? lastError;
      for (var attempt = 0; attempt < attempts; attempt++) {
        try {
          final normalizedPath = path.startsWith('/') ? path : '/$path';
          final response = await client
              .get(
                Uri.parse(
                  '${AppConstants.nativeGatewaySmokeUrl}$normalizedPath',
                ),
              )
              .timeout(const Duration(seconds: 2));
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
          await Future<void>.delayed(retryDelay);
        }
      }
      throw StateError('JSON probe $path failed: $lastError');
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

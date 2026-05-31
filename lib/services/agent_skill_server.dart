import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'preferences_service.dart';
import 'skills_service.dart';
import 'tts_service.dart';
import 'gateway_service.dart';
import 'gateway_tool_catalog.dart';
import 'native_gateway_smoke_service.dart';
import 'capabilities/avatar_capability.dart';
import 'capabilities/flash_capability.dart';
import 'capabilities/sensor_capability.dart';
import 'capabilities/vibration_capability.dart';

class _NativeGatewayDryRunArgumentValidation {
  final bool ok;
  final String code;
  final String message;

  const _NativeGatewayDryRunArgumentValidation({
    required this.ok,
    required this.code,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'code': code,
        'message': message,
      };
}

/// Local HTTP Server that listens on 127.0.0.1:8765 for OpenClaw Native Skills.
/// The gateway AI agent POSTs to these endpoints to control the Android app.
///
/// Routes:
///   GET  /battery                    — legacy battery stub
///   GET  /api/tools                  — full tools catalog from SkillsService
///   GET  /api/skills/list            — all skills list
///   POST /api/tools/execute          — generic tool executor: {name, input} → routes to correct handler
///   POST /api/avatar/control         — change VRM, gestures, emotions (avatar-control skill)
///   POST /api/avatar/equip           — legacy equip alias
///   POST /api/tts/control            — switch TTS engine/voice, speak text (tts-voice skill)
///   POST /api/device/control         — vibrate, flashlight, battery, sensors (device-node skill)
///   POST /twilio/*                   — twilio-voice skill proxy
///   POST /cards/*                    — agent-card skill proxy
///   POST /marketplace/*              — molt-launch skill proxy
///   POST /sentinel/*                 — valeo-sentinel skill proxy
class AgentSkillServer {
  // Singleton — main() starts the server; ChatScreen accesses the same instance
  // to wire up onAvatarChanged/onGesturePlayed/onEmotionSet callbacks so that
  // agent-triggered avatar changes reflect immediately in the live UI.
  static final AgentSkillServer instance = AgentSkillServer._internal();
  factory AgentSkillServer() => instance;
  AgentSkillServer._internal();

  HttpServer? _server;
  Future<void>? _startFuture;
  final AvatarCapability _avatarCapability = AvatarCapability();
  final FlashCapability _flashCapability = FlashCapability();
  final SensorCapability _sensorCapability = SensorCapability();
  final VibrationCapability _vibrationCapability = VibrationCapability();

  // Callbacks — set by ChatScreen so avatar changes are reflected in live UI
  void Function(String avatarFile)? onAvatarChanged;
  Future<Map<String, dynamic>> Function(Map<String, dynamic> request)?
      onAvatarGestureRequested;
  void Function(String gesture)? onGesturePlayed;
  void Function(String emotion)? onEmotionSet;
  void Function(String mode)? onGestureModeChanged;

  Future<void> start() {
    if (_server != null) return Future.value();
    return _startFuture ??= _startWithRetry();
  }

  Future<void> _startWithRetry() async {
    if (_server != null) return;
    const maxAttempts = 6;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          8765,
          shared: true,
        );
        debugPrint('AgentSkillServer listening on 127.0.0.1:8765');
        _server!.listen(_handleRequest);
        return;
      } catch (e) {
        debugPrint(
            'AgentSkillServer bind attempt $attempt/$maxAttempts failed: $e');
        if (attempt == maxAttempts) break;
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }
    }
    _startFuture = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    if (request.method == 'GET' && path == '/battery') {
      _handleBattery(request);
    } else if (request.method == 'GET' && path == '/api/tools') {
      _handleToolsCatalog(request);
    } else if (request.method == 'GET' && path == '/api/skills/list') {
      _handleSkillsList(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/dispatch-dry-run') {
      await _handleNativeGatewayDispatchDryRun(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/dispatch-cancel-dry-run') {
      await _handleNativeGatewayDispatchCancelDryRun(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/dispatch-execute-canary') {
      await _handleNativeGatewayDispatchExecuteCanary(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-port-bind-canary') {
      await _handleNativeGatewayProductionPortBindCanary(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-port-bind-soak') {
      await _handleNativeGatewayProductionPortBindSoak(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/runtime-owner-canary') {
      await _handleNativeGatewayRuntimeOwnerCanary(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-route-owner-dry-run') {
      await _handleNativeGatewayProductionRouteOwnerDryRun(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-provider-envelope-dry-run') {
      await _handleNativeGatewayProductionProviderEnvelopeDryRun(request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-provider-request-builder-dry-run') {
      await _handleNativeGatewayProductionProviderRequestBuilderDryRun(request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-provider-transport-shim-dry-run') {
      await _handleNativeGatewayProductionProviderTransportShimDryRun(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-provider-live-canary') {
      await _handleNativeGatewayProductionProviderLiveCanary(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-provider-backed-chat-canary') {
      await _handleNativeGatewayProductionProviderBackedChatCanary(request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-provider-stream-parser-parity') {
      await _handleNativeGatewayProductionProviderStreamParserParity(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-provider-tool-plan-capture') {
      await _handleNativeGatewayProductionProviderToolPlanCapture(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-tool-dispatch-dry-run') {
      await _handleNativeGatewayProductionToolDispatchDryRun(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-dart-bridge-dry-run') {
      await _handleNativeGatewayProductionDartBridgeDryRun(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-dart-bridge-ordering-cancel') {
      await _handleNativeGatewayProductionDartBridgeOrderingCancel(request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-bridge-execution-readonly-canary') {
      await _handleNativeGatewayProductionBridgeExecutionReadOnlyCanary(
          request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-bridge-execution-haptic-canary') {
      await _handleNativeGatewayProductionBridgeExecutionHapticCanary(request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-bridge-execution-avatar-canary') {
      await _handleNativeGatewayProductionBridgeExecutionAvatarCanary(request);
    } else if (request.method == 'POST' && path == '/api/tools/execute') {
      await _handleToolsExecute(request);
    } else if (request.method == 'POST' && path == '/api/avatar/control') {
      await _handleAvatarControl(request);
    } else if (request.method == 'POST' && path == '/api/avatar/equip') {
      await _handleAvatarEquip(request); // legacy alias
    } else if (request.method == 'POST' && path == '/api/tts/control') {
      await _handleTtsControl(request);
    } else if (request.method == 'POST' && path == '/api/device/control') {
      await _handleDeviceControl(request);
    } else if (path.startsWith('/twilio')) {
      await _handleTwilio(request);
    } else if (path.startsWith('/cards')) {
      await _handleAgentCard(request);
    } else if (path.startsWith('/marketplace')) {
      await _handleMoltLaunch(request);
    } else if (path.startsWith('/sentinel')) {
      await _handleValeo(request);
    } else {
      _sendNotFound(request);
    }
  }

  Future<void> _handleNativeGatewayProductionPortBindCanary(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final report =
          await NativeGatewaySmokeService.runProductionPortBindCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionPortBindSoak(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(rawBody) as Map<String, dynamic>;
      final rawCycles = body['cycles'];
      final cycles = rawCycles is num
          ? rawCycles.toInt()
          : int.tryParse(rawCycles?.toString() ?? '') ?? 3;
      final report = await NativeGatewaySmokeService.runProductionPortBindSoak(
        cycles: cycles,
        log: (message) => debugPrint('[GATEWAY] $message'),
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayRuntimeOwnerCanary(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(rawBody) as Map<String, dynamic>;
      final rawHoldSeconds = body['holdSeconds'];
      final holdSeconds = rawHoldSeconds is num
          ? rawHoldSeconds.toInt()
          : int.tryParse(rawHoldSeconds?.toString() ?? '') ?? 5;
      final report = await NativeGatewaySmokeService.runRuntimeOwnerCanary(
        holdSeconds: holdSeconds,
        log: (message) => debugPrint('[GATEWAY] $message'),
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionRouteOwnerDryRun(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      await utf8.decoder.bind(request).join();
      final report =
          await NativeGatewaySmokeService.runProductionPortRouteOwnerDryRun(
        log: (message) => debugPrint('[GATEWAY] $message'),
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionProviderEnvelopeDryRun(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      await utf8.decoder.bind(request).join();
      final report = await NativeGatewaySmokeService
          .runProductionPortProviderEnvelopeDryRun(
        log: (message) => debugPrint('[GATEWAY] $message'),
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionProviderRequestBuilderDryRun(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      await utf8.decoder.bind(request).join();
      final report = await NativeGatewaySmokeService
          .runProductionPortProviderRequestBuilderDryRun(
        log: (message) => debugPrint('[GATEWAY] $message'),
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionProviderTransportShimDryRun(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      await utf8.decoder.bind(request).join();
      final report = await NativeGatewaySmokeService
          .runProductionPortProviderTransportShimDryRun(
        log: (message) => debugPrint('[GATEWAY] $message'),
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionProviderLiveCanary(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();
      final explicitConfig = args['providerConfig'] is Map
          ? Map<String, dynamic>.from(args['providerConfig'] as Map)
          : null;
      final providerConfig = explicitConfig ??
          await GatewayService().resolveNativeProviderLiveCanaryConfig(
            model: model,
          );

      if (providerConfig == null) {
        _sendJson(
            request,
            {
              'ok': false,
              'error': 'openrouter_provider_config_unavailable',
              'message':
                  'No OpenRouter model/API key is configured for native live canary.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report =
          await NativeGatewaySmokeService.runProductionPortProviderLiveCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: providerConfig,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production provider live canary'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionProviderBackedChatCanary(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();
      final explicitConfig = args['providerConfig'] is Map
          ? Map<String, dynamic>.from(args['providerConfig'] as Map)
          : null;
      final providerConfig = explicitConfig ??
          await GatewayService().resolveNativeProviderLiveCanaryConfig(
            model: model,
          );

      if (providerConfig == null) {
        _sendJson(
            request,
            {
              'ok': false,
              'error': 'openrouter_provider_config_unavailable',
              'message':
                  'No OpenRouter model/API key is configured for native provider-backed chat canary.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report = await NativeGatewaySmokeService
          .runProductionPortProviderBackedChatCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: providerConfig,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production provider-backed chat canary with tool execution disabled'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionProviderStreamParserParity(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();
      final explicitConfig = args['providerConfig'] is Map
          ? Map<String, dynamic>.from(args['providerConfig'] as Map)
          : null;
      final providerConfig = explicitConfig ??
          await GatewayService().resolveNativeProviderLiveCanaryConfig(
            model: model,
          );

      if (providerConfig == null) {
        _sendJson(
            request,
            {
              'ok': false,
              'error': 'openrouter_provider_config_unavailable',
              'message':
                  'No OpenRouter model/API key is configured for native stream parser parity.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report = await NativeGatewaySmokeService
          .runProductionPortProviderStreamParserParityCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: {
          ...providerConfig,
          'title': 'Plawie Native Stream Parser Parity',
        },
        prompt: prompt == null || prompt.isEmpty
            ? 'native production provider stream parser parity'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionProviderToolPlanCapture(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();

      final report = await NativeGatewaySmokeService
          .runProductionPortProviderToolPlanCaptureCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production provider tool plan capture: wave right and vibrate once'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionToolDispatchDryRun(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();

      final report =
          await NativeGatewaySmokeService.runProductionPortToolDispatchDryRun(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production tool dispatch dry-run: wave right and vibrate once'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionDartBridgeDryRun(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();

      final report =
          await NativeGatewaySmokeService.runProductionPortDartBridgeDryRun(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production Dart bridge dry-run: wave right and vibrate once'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionDartBridgeOrderingCancel(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();

      final report = await NativeGatewaySmokeService
          .runProductionPortDartBridgeOrderingCancelDryRun(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production Dart bridge ordering/cancel dry-run: wave right and vibrate once'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionBridgeExecutionReadOnlyCanary(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();

      final report = await NativeGatewaySmokeService
          .runProductionPortBridgeExecutionReadOnlyCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production read-only bridge execution canary: check flash and list sensors'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionBridgeExecutionHapticCanary(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();

      final report = await NativeGatewaySmokeService
          .runProductionPortBridgeExecutionHapticCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production haptic bridge execution canary: vibrate once'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleNativeGatewayProductionBridgeExecutionAvatarCanary(
    HttpRequest request,
  ) async {
    if (!NativeGatewaySmokeService.diagnosticsEnabled) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': 'native_gateway_diagnostics_disabled',
          },
          statusCode: HttpStatus.forbidden);
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      Map<String, dynamic> args = <String, dynamic>{};
      if (body.trim().isNotEmpty) {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          args = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      final prompt = args['prompt']?.toString().trim();
      final model = args['model']?.toString().trim();

      final report = await NativeGatewaySmokeService
          .runProductionPortBridgeExecutionAvatarCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production avatar bridge execution canary: wave right'
            : prompt,
      );
      _sendJson(request, report);
    } catch (e) {
      _sendJson(
          request,
          {
            'ok': false,
            'error': e.toString(),
          },
          statusCode: HttpStatus.internalServerError);
    }
  }

  // ── Legacy battery stub ───────────────────────────────────────────────────
  void _handleBattery(HttpRequest request) {
    _sendJson(request, {'level': 85, 'isCharging': true});
  }

  void _handleToolsCatalog(HttpRequest request) {
    final catalog = SkillsService().getToolsCatalog();
    _sendJson(request, {'tools': catalog});
  }

  void _handleSkillsList(HttpRequest request) {
    final skills = SkillsService().getSkillsList();
    _sendJson(request, {'skills': skills.map((s) => s.toJson()).toList()});
  }

  // ── Native Gateway Bridge Dry Run ─────────────────────────────────────────
  Future<void> _handleNativeGatewayDispatchDryRun(HttpRequest request) async {
    try {
      final body = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      final frame = body['toolUseFrame'] is Map
          ? Map<String, dynamic>.from(body['toolUseFrame'] as Map)
          : <String, dynamic>{};
      final rawCommand = (body['method'] ??
              body['command'] ??
              body['toolName'] ??
              frame['name'])
          ?.toString()
          .trim();
      final command = _canonicalNativeGatewayCommand(rawCommand);
      final input = body['input'] is Map
          ? Map<String, dynamic>.from(body['input'] as Map)
          : frame['input'] is Map
              ? Map<String, dynamic>.from(frame['input'] as Map)
              : <String, dynamic>{};
      final dryRun = body['dryRun'] == true;
      final executionEnabled = body['executionEnabled'] == true ||
          body['toolExecutionEnabled'] == true ||
          body['bridgeExecutionEnabled'] == true;
      final commandKnown = command != null &&
          GatewayToolCatalog.mobileNodeAllowCommands.contains(command);
      final argumentValidation =
          _validateNativeGatewayDryRunArguments(command, input);
      final accepted =
          dryRun && !executionEnabled && commandKnown && argumentValidation.ok;

      _sendJson(request, {
        'ok': accepted,
        'accepted': accepted,
        'dryRun': true,
        'runtime': 'flutter-dart',
        'bridge': 'AgentSkillServer',
        'source': 'native-dart-bridge-dry-run',
        'routeStatus': accepted
            ? 'native_dart_bridge_dry_run_ack'
            : 'native_dart_bridge_dry_run_rejected',
        'command': command ?? rawCommand ?? 'unknown',
        'rawCommand': rawCommand,
        'commandKnown': commandKnown,
        'capability': _capabilityForCommand(command),
        'dartCapability': body['dartCapability']?.toString() ??
            _dartCapabilityForCommand(command),
        'requiresUiThread': body['requiresUiThread'] == true,
        'inputKeys': input.keys.map((key) => key.toString()).toList()..sort(),
        'argumentValidation': argumentValidation.toJson(),
        'requestHash': body['requestHash'],
        'dispatchHash': body['dispatchHash'],
        'bridgeRequestHash': body['bridgeRequestHash'],
        'orderIndex': body['orderIndex'],
        'orderCount': body['orderCount'],
        'orderingKey': body['orderingKey'],
        'cancellationToken': body['cancellationToken'],
        'callId': body['callId'],
        'runId': body['runId'],
        'nativeSessionId': body['nativeSessionId'],
        'wouldDispatchTo': _dartCapabilityForCommand(command),
        'skippedReason': 'native_dart_bridge_dry_run_only',
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'bridgeExecutionEnabled': false,
        'receivedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _sendError(request, 'native_dart_bridge_dry_run_failed: $e');
    }
  }

  Future<void> _handleNativeGatewayDispatchCancelDryRun(
    HttpRequest request,
  ) async {
    try {
      final body = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      final dryRun = body['dryRun'] == true;
      final executionEnabled = body['executionEnabled'] == true ||
          body['toolExecutionEnabled'] == true ||
          body['bridgeExecutionEnabled'] == true;
      final targetRunId = body['targetRunId']?.toString().trim();
      final targetBridgeRequestHash =
          body['targetBridgeRequestHash']?.toString().trim();
      final cancellationToken = body['cancellationToken']?.toString().trim();
      final cancelAccepted = dryRun &&
          !executionEnabled &&
          targetRunId != null &&
          targetRunId.isNotEmpty &&
          targetBridgeRequestHash != null &&
          targetBridgeRequestHash.isNotEmpty;

      _sendJson(request, {
        'ok': cancelAccepted,
        'cancelAccepted': cancelAccepted,
        'cancelRequested': true,
        'cancelApplied': false,
        'dryRun': true,
        'runtime': 'flutter-dart',
        'bridge': 'AgentSkillServer',
        'source': 'native-dart-bridge-ordering-cancel',
        'routeStatus': cancelAccepted
            ? 'native_dart_bridge_cancel_dry_run_ack'
            : 'native_dart_bridge_cancel_dry_run_rejected',
        'cancellationState': cancelAccepted
            ? 'recorded_dry_run_no_active_execution'
            : 'rejected',
        'reason': body['reason']?.toString() ?? 'native bridge dry-run cancel',
        'targetRunId': targetRunId,
        'targetRequestId': body['targetRequestId'],
        'targetCallId': body['targetCallId'],
        'targetBridgeRequestHash': targetBridgeRequestHash,
        'targetDispatchHash': body['targetDispatchHash'],
        'orderIndex': body['orderIndex'],
        'orderCount': body['orderCount'],
        'cancellationToken': cancellationToken,
        'cancelRequestHash': body['cancelRequestHash'],
        'targetWasExecuting': false,
        'skippedReason': 'native_dart_bridge_cancel_dry_run_only',
        'providerCallsEnabled': false,
        'executionEnabled': false,
        'toolExecutionEnabled': false,
        'bridgeExecutionEnabled': false,
        'receivedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _sendError(request, 'native_dart_bridge_cancel_dry_run_failed: $e');
    }
  }

  Future<void> _handleNativeGatewayDispatchExecuteCanary(
    HttpRequest request,
  ) async {
    try {
      final body = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      final frame = body['toolUseFrame'] is Map
          ? Map<String, dynamic>.from(body['toolUseFrame'] as Map)
          : <String, dynamic>{};
      final rawCommand = (body['method'] ??
              body['command'] ??
              body['toolName'] ??
              frame['name'])
          ?.toString()
          .trim();
      final command = _canonicalNativeGatewayCommand(rawCommand);
      final input = body['input'] is Map
          ? Map<String, dynamic>.from(body['input'] as Map)
          : frame['input'] is Map
              ? Map<String, dynamic>.from(frame['input'] as Map)
              : <String, dynamic>{};
      final allowlist = body['canaryAllowlist'] is List
          ? (body['canaryAllowlist'] as List)
              .map((value) => value.toString())
              .toList()
          : const <String>[];
      final canaryMode = body['canaryMode']?.toString();
      final dryRunDisabled =
          body.containsKey('dryRun') && body['dryRun'] == false;
      final executionRequested = body['executionEnabled'] == true &&
          body['toolExecutionEnabled'] == true &&
          body['bridgeExecutionEnabled'] == true;
      final providerCallsDisabled = body['providerCallsEnabled'] != true;
      final commandKnown = command != null &&
          GatewayToolCatalog.mobileNodeAllowCommands.contains(command);
      final argumentValidation =
          _validateNativeGatewayDryRunArguments(command, input);
      final hapticCanary = canaryMode == 'native-dart-bridge-haptic-canary';
      final readOnlyCanary = canaryMode == 'native-dart-bridge-readonly-canary';
      final avatarCanary = canaryMode == 'native-dart-bridge-avatar-canary';
      final canaryAllowlistOk = _nativeGatewayExecuteCanaryAllowlistOk(
        canaryMode,
        allowlist,
        command,
      );
      final durationValidation = hapticCanary
          ? _nativeGatewayHapticCanaryDuration(
              input['durationMs'] ?? input['duration_ms'],
            )
          : null;
      final avatarGesture =
          avatarCanary ? _nativeGatewayAvatarCanaryGesture(input) : null;
      final avatarDurationMs = avatarCanary
          ? _nativeGatewayAvatarCanaryDuration(
              input['durationMs'] ?? input['duration_ms'],
            )
          : null;
      final patternRejected = input.containsKey('pattern');
      final hapticInputOk =
          !hapticCanary || (durationValidation != null && !patternRejected);
      final readOnlyInputOk = !readOnlyCanary || input.isEmpty;
      final avatarInputOk = !avatarCanary ||
          (avatarGesture == 'wave right' &&
              avatarDurationMs != null &&
              input['interrupt'] == true &&
              input['protectedGesture'] == true &&
              input['source'] == 'native-dart-bridge-avatar-canary' &&
              input['canaryMode'] == 'native-dart-bridge-avatar-canary');
      final commandAllowedForMode =
          _nativeGatewayExecuteCanaryCommandAllowed(canaryMode, command);
      final accepted = dryRunDisabled &&
          executionRequested &&
          providerCallsDisabled &&
          commandAllowedForMode &&
          commandKnown &&
          argumentValidation.ok &&
          canaryAllowlistOk &&
          hapticInputOk &&
          readOnlyInputOk &&
          avatarInputOk;

      var executed = false;
      var result = <String, dynamic>{};
      Map<String, dynamic>? error;
      if (accepted) {
        final frame = await _executeNativeGatewayCanaryCommand(
          command,
          hapticDurationMs: durationValidation,
          avatarGesture: avatarGesture,
          avatarDurationMs: avatarDurationMs,
        );
        executed = frame.isOk;
        if (frame.payload != null) {
          result = Map<String, dynamic>.from(frame.payload!);
        }
        if (frame.error != null) {
          error = Map<String, dynamic>.from(frame.error!);
        }
      }
      final routePrefix = avatarCanary
          ? 'native_dart_bridge_avatar_canary'
          : readOnlyCanary
              ? 'native_dart_bridge_readonly_canary'
              : 'native_dart_bridge_haptic_canary';
      final resultStatus =
          result['status']?.toString() ?? (executed ? 'ok' : 'not_executed');

      _sendJson(request, {
        'ok': accepted && executed,
        'accepted': accepted,
        'executed': executed,
        'dryRun': false,
        'runtime': 'flutter-dart',
        'bridge': 'AgentSkillServer',
        'source': canaryMode,
        'canaryMode': canaryMode,
        'routeStatus': accepted && executed
            ? '${routePrefix}_ack'
            : '${routePrefix}_rejected',
        'command': command ?? rawCommand ?? 'unknown',
        'rawCommand': rawCommand,
        'commandKnown': commandKnown,
        'capability': _capabilityForCommand(command),
        'dartCapability': body['dartCapability']?.toString() ??
            _dartCapabilityForCommand(command),
        'requiresUiThread': body['requiresUiThread'] == true,
        'canaryAllowlist': allowlist,
        'canaryAllowlistOk': canaryAllowlistOk,
        'inputKeys': input.keys.map((key) => key.toString()).toList()..sort(),
        'argumentValidation': argumentValidation.toJson(),
        'durationMs': durationValidation,
        'durationBounded': hapticCanary &&
            durationValidation != null &&
            durationValidation > 0 &&
            durationValidation <= 150,
        'avatarGesture': avatarGesture,
        'avatarDurationMs': avatarDurationMs,
        'avatarInputOk': avatarInputOk,
        'patternRejected': patternRejected,
        'readOnlyInputOk': readOnlyInputOk,
        'result': result,
        'resultStatus': resultStatus,
        if (error != null) 'error': error,
        'requestHash': body['requestHash'],
        'dispatchHash': body['dispatchHash'],
        'bridgeRequestHash': body['bridgeRequestHash'],
        'cancellationToken': body['cancellationToken'],
        'callId': body['callId'],
        'runId': body['runId'],
        'nativeSessionId': body['nativeSessionId'],
        'wouldDispatchTo': _dartCapabilityForCommand(command),
        'providerCallsEnabled': false,
        'executionEnabled': accepted,
        'toolExecutionEnabled': accepted,
        'bridgeExecutionEnabled': accepted,
        'receivedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _sendError(request, 'native_dart_bridge_execute_canary_failed: $e');
    }
  }

  int? _nativeGatewayHapticCanaryDuration(dynamic value) {
    if (value == null) return 90;
    final parsed = value is int
        ? value
        : value is num
            ? value.round()
            : int.tryParse(value.toString());
    if (parsed == null || parsed <= 0) return null;
    if (parsed > 150) return 150;
    if (parsed < 10) return 10;
    return parsed;
  }

  String? _nativeGatewayAvatarCanaryGesture(Map<String, dynamic> input) {
    final value =
        (input['gesture'] ?? input['name'] ?? input['value'] ?? input['text'])
            ?.toString()
            .trim()
            .toLowerCase();
    if (value == null || value.isEmpty) return null;
    return value == 'wave' ? 'wave right' : value;
  }

  int? _nativeGatewayAvatarCanaryDuration(dynamic value) {
    final parsed = value is int
        ? value
        : value is num
            ? value.round()
            : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed < 500) return null;
    if (parsed > 2500) return 2500;
    return parsed;
  }

  bool _nativeGatewayExecuteCanaryAllowlistOk(
    String? canaryMode,
    List<String> allowlist,
    String? command,
  ) {
    if (canaryMode == 'native-dart-bridge-haptic-canary') {
      return allowlist.length == 1 &&
          allowlist.single == 'haptic.vibrate' &&
          command == 'haptic.vibrate';
    }

    if (canaryMode == 'native-dart-bridge-avatar-canary') {
      return allowlist.length == 1 &&
          allowlist.single == 'avatar.gesture' &&
          command == 'avatar.gesture';
    }

    if (canaryMode == 'native-dart-bridge-readonly-canary') {
      const expected = {'flash.status', 'sensor.list'};
      final actual = allowlist.toSet();
      return actual.length == expected.length &&
          actual.containsAll(expected) &&
          command != null &&
          expected.contains(command);
    }

    return false;
  }

  bool _nativeGatewayExecuteCanaryCommandAllowed(
    String? canaryMode,
    String? command,
  ) {
    if (canaryMode == 'native-dart-bridge-haptic-canary') {
      return command == 'haptic.vibrate';
    }
    if (canaryMode == 'native-dart-bridge-avatar-canary') {
      return command == 'avatar.gesture';
    }
    if (canaryMode == 'native-dart-bridge-readonly-canary') {
      return command == 'flash.status' || command == 'sensor.list';
    }
    return false;
  }

  Future<dynamic> _executeNativeGatewayCanaryCommand(
    String command, {
    int? hapticDurationMs,
    String? avatarGesture,
    int? avatarDurationMs,
  }) {
    switch (command) {
      case 'haptic.vibrate':
        return _vibrationCapability.handle(
          'haptic.vibrate',
          {'durationMs': hapticDurationMs ?? 90},
        );
      case 'avatar.gesture':
        return _avatarCapability.handle(
          'avatar.gesture',
          {
            'gesture': avatarGesture ?? 'wave right',
            'durationMs': avatarDurationMs ?? 1800,
            'interrupt': true,
            'protectedGesture': true,
            'source': 'native-dart-bridge-avatar-canary',
            'canaryMode': 'native-dart-bridge-avatar-canary',
          },
        );
      case 'flash.status':
        return _flashCapability.handle('flash.status', const {});
      case 'sensor.list':
        return _sensorCapability.handle('sensor.list', const {});
      default:
        throw StateError('Unsupported native gateway canary command: $command');
    }
  }

  String? _canonicalNativeGatewayCommand(String? command) {
    if (command == null || command.isEmpty) return null;
    const aliases = {
      'avatar_gesture': 'avatar.gesture',
      'avatar_mode': 'avatar.mode',
      'avatar_model': 'avatar.model',
      'avatar_status': 'avatar.status',
      'gesture.wave': 'avatar.gesture',
      'gestures.wave': 'avatar.gesture',
      'wave': 'avatar.gesture',
      'camera_snap': 'camera.snap',
      'camera_clip': 'camera.clip',
      'camera_list': 'camera.list',
      'canvas_navigate': 'canvas.navigate',
      'canvas_eval': 'canvas.eval',
      'canvas_snapshot': 'canvas.snapshot',
      'flash_on': 'flash.on',
      'flash_off': 'flash.off',
      'flash_toggle': 'flash.toggle',
      'flash_status': 'flash.status',
      'torch.on': 'flash.on',
      'torch.off': 'flash.off',
      'torch.toggle': 'flash.toggle',
      'torch.status': 'flash.status',
      'torch_on': 'flash.on',
      'torch_off': 'flash.off',
      'torch_toggle': 'flash.toggle',
      'torch_status': 'flash.status',
      'location_get': 'location.get',
      'screen_record': 'screen.record',
      'sensor_read': 'sensor.read',
      'sensor_list': 'sensor.list',
      'haptic_vibrate': 'haptic.vibrate',
      'vibrate': 'haptic.vibrate',
    };
    final normalized = command.trim();
    return aliases[normalized] ?? normalized;
  }

  _NativeGatewayDryRunArgumentValidation _validateNativeGatewayDryRunArguments(
    String? command,
    Map<String, dynamic> input,
  ) {
    switch (command) {
      case 'avatar.gesture':
        final gesture = (input['gesture'] ??
                input['name'] ??
                input['value'] ??
                input['text'])
            ?.toString()
            .trim();
        return _NativeGatewayDryRunArgumentValidation(
          ok: gesture != null && gesture.isNotEmpty,
          code:
              gesture != null && gesture.isNotEmpty ? 'ok' : 'missing_gesture',
          message: gesture != null && gesture.isNotEmpty
              ? 'avatar.gesture arguments are dispatchable'
              : 'avatar.gesture requires a gesture value',
        );
      case 'haptic.vibrate':
        final duration = input['durationMs'] ?? input['duration_ms'];
        final pattern = input['pattern'];
        final ok = duration == null ||
            duration is num ||
            int.tryParse(duration.toString()) != null ||
            pattern is List;
        return _NativeGatewayDryRunArgumentValidation(
          ok: ok,
          code: ok ? 'ok' : 'invalid_duration',
          message: ok
              ? 'haptic.vibrate arguments are dispatchable'
              : 'haptic.vibrate duration must be numeric',
        );
      case 'camera.snap':
      case 'camera.clip':
      case 'camera.list':
      case 'canvas.navigate':
      case 'canvas.eval':
      case 'canvas.snapshot':
      case 'flash.on':
      case 'flash.off':
      case 'flash.toggle':
      case 'flash.status':
      case 'location.get':
      case 'screen.record':
      case 'sensor.read':
      case 'sensor.list':
      case 'avatar.mode':
      case 'avatar.model':
      case 'avatar.status':
        return const _NativeGatewayDryRunArgumentValidation(
          ok: true,
          code: 'ok',
          message: 'arguments are dispatchable',
        );
      default:
        return const _NativeGatewayDryRunArgumentValidation(
          ok: false,
          code: 'unknown_command',
          message: 'command is not registered for native gateway dry-run',
        );
    }
  }

  String _capabilityForCommand(String? command) {
    if (command == null || !command.contains('.')) return 'unknown';
    return command.split('.').first;
  }

  String _dartCapabilityForCommand(String? command) {
    switch (_capabilityForCommand(command)) {
      case 'avatar':
        return 'AvatarCapability';
      case 'camera':
        return 'CameraCapability';
      case 'canvas':
        return 'CanvasCapability';
      case 'flash':
        return 'FlashCapability';
      case 'haptic':
        return 'VibrationCapability';
      case 'location':
        return 'LocationCapability';
      case 'screen':
        return 'ScreenCapability';
      case 'sensor':
        return 'SensorCapability';
      default:
        return 'UnknownCapability';
    }
  }

  // ── Generic tool executor ─────────────────────────────────────────────────
  // Called by the gateway when it dispatches a tool-use event to 127.0.0.1:8765.
  // Body: { "name": "<tool-id>", "input": { ...tool parameters... } }
  // Routes to the appropriate _process* method for device-native skills, or
  // falls through to SkillsService for custom YAML/partner skills.
  Future<void> _handleToolsExecute(HttpRequest request) async {
    try {
      final body = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      final name = body['name'] as String?;
      final input = (body['input'] as Map<String, dynamic>?) ?? {};

      if (name == null) return _sendError(request, 'Missing name parameter');

      switch (name) {
        case 'avatar-control':
          await _processAvatarControl(input, request);
        case 'tts-voice':
          await _processTtsControl(input, request);
        case 'device-node':
          await _processDeviceControl(input, request);
        default:
          final result =
              await SkillsService().executeSkill(name, parameters: input);
          _sendSkillResult(request, result);
      }
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  // ── Avatar Control ─────────────────────────────────────────────────────────
  Future<void> _handleAvatarControl(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      await _processAvatarControl(data, request);
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  Future<void> _processAvatarControl(
      Map<String, dynamic> data, HttpRequest request) async {
    final action = data['action'] as String? ?? 'get_status';

    switch (action) {
      case 'change_model':
        final model = data['model'] as String?;
        if (model == null) {
          return _sendError(request, 'Missing model parameter');
        }
        final filename = model.endsWith('.vrm') ? model : '$model.vrm';
        final prefs = PreferencesService();
        await prefs.init();
        prefs.selectedAvatar = filename;
        onAvatarChanged?.call(filename);
        _sendJson(request, {'success': true, 'model': filename});

      case 'play_gesture':
        final gesture = data['gesture'] as String?;
        if (gesture == null) {
          return _sendError(request, 'Missing gesture parameter');
        }
        final result = await _requestAvatarGesture({
          ...data,
          'gesture': gesture,
        });
        _sendJson(request, {'success': true, ...result});

      case 'play_vrma':
      case 'play_vrma_composite':
        final base = data['base']?.toString() ??
            data['gesture']?.toString() ??
            data['animation']?.toString();
        final layers = (data['layers'] as List?)
                ?.map((item) => item.toString())
                .where((item) => item.trim().isNotEmpty)
                .toList() ??
            const <String>[];
        final target = layers.isNotEmpty ? layers.first : base;
        if (target == null || target.trim().isEmpty) {
          return _sendError(request, 'Missing base/gesture/layers parameter');
        }
        final result = await _requestAvatarGesture({
          ...data,
          'gesture': target,
          'base': base,
          'layers': layers,
          'blendTime': data['blendTime'] ?? 0.4,
        });
        _sendJson(request, {'success': true, ...result});

      case 'set_emotion':
        final emotion = data['emotion'] as String?;
        if (emotion == null) {
          return _sendError(request, 'Missing emotion parameter');
        }
        onEmotionSet?.call(emotion);
        _sendJson(request, {'success': true, 'emotion': emotion});

      case 'set_mode':
        final mode = data['mode'] as String?;
        if (mode == null) {
          return _sendError(request, 'Missing mode parameter');
        }
        final validModes = ['normal', 'expressive', 'dance', 'subtle'];
        if (!validModes.contains(mode)) {
          return _sendError(
              request, 'Invalid mode. Valid: ${validModes.join(", ")}');
        }
        onGestureModeChanged?.call(mode);
        _sendJson(request, {'success': true, 'mode': mode});

      case 'get_status':
        final prefs = PreferencesService();
        await prefs.init();
        _sendJson(request, {'avatar': prefs.selectedAvatar});

      default:
        _sendError(request, 'Unknown avatar action: $action');
    }
  }

  Future<Map<String, dynamic>> _requestAvatarGesture(
      Map<String, dynamic> request) async {
    final callback = onAvatarGestureRequested;
    if (callback != null) {
      return callback(request);
    }
    final gesture = request['gesture']?.toString();
    if (gesture != null && gesture.isNotEmpty) {
      onGesturePlayed?.call(gesture);
      return {
        'status': 'queued',
        'gesture': gesture,
        'reason': 'Legacy avatar gesture callback was used.',
      };
    }
    return {
      'status': 'failed',
      'reason': 'Missing gesture parameter.',
    };
  }

  // Legacy /api/avatar/equip — kept for backward compat with old gateway skills
  Future<void> _handleAvatarEquip(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      final vrmId = data['vrm_id'] as String?;
      if (vrmId == null || vrmId.isEmpty) {
        return _sendError(request, 'Missing vrm_id');
      }
      final filename = vrmId.endsWith('.vrm') ? vrmId : '$vrmId.vrm';
      final prefs = PreferencesService();
      await prefs.init();
      prefs.selectedAvatar = filename;
      onAvatarChanged?.call(filename);
      _sendJson(request, {'success': true, 'message': 'Equipped $filename'});
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  // ── TTS Voice Control ──────────────────────────────────────────────────────
  Future<void> _handleTtsControl(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      await _processTtsControl(data, request);
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  Future<void> _processTtsControl(
      Map<String, dynamic> data, HttpRequest request) async {
    final action = data['action'] as String? ?? 'get_status';
    final prefs = PreferencesService();
    await prefs.init();

    switch (action) {
      case 'set_engine':
        // No-op: Local engines removed. App strictly uses Gateway TTS.
        _sendJson(request, {'success': true, 'engine': 'gateway'});

      case 'set_voice':
        // No-op: Voice selection is now handled on the Gateway side.
        _sendJson(request, {
          'success': true,
          'message': 'Voice changes should be handled in the Gateway config.'
        });

      case 'speak':
        final text = data['text'] as String?;
        if (text == null || text.isEmpty) {
          return _sendError(request, 'Missing text');
        }
        final tts = TtsService();
        unawaited(tts.speak(text));
        _sendJson(request, {'success': true, 'speaking': text});

      case 'stop':
        final tts = TtsService();
        await tts.stop();
        _sendJson(request, {'success': true});

      case 'get_status':
        _sendJson(request, {
          'engine': 'gateway',
          'voice': 'default',
        });

      default:
        _sendError(request, 'Unknown TTS action: $action');
    }
  }

  // ── Device Node Control ─────────────────────────────────────────────────────
  Future<void> _handleDeviceControl(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      await _processDeviceControl(data, request);
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  Future<void> _processDeviceControl(
      Map<String, dynamic> data, HttpRequest request) async {
    final action = data['action'] as String? ?? 'get_battery';

    switch (action) {
      case 'vibrate':
        final pattern = (data['pattern'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [0, 300];
        final frame = await _vibrationCapability.handle(
          'haptic.vibrate',
          {'pattern': pattern},
        );
        _sendNodeFrame(request, frame, fallback: {'pattern': pattern});

      case 'flashlight_on':
        final frame = await _flashCapability.handleWithPermission(
          'flash.on',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'flashlight_off':
        final frame = await _flashCapability.handleWithPermission(
          'flash.off',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'flashlight_toggle':
        final frame = await _flashCapability.handleWithPermission(
          'flash.toggle',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'get_battery':
        final level = await const MethodChannel('com.nxg.openclawproot/native')
                .invokeMethod<int>('getBatteryLevel') ??
            -1;
        final charging =
            await const MethodChannel('com.nxg.openclawproot/native')
                    .invokeMethod<bool>('isCharging') ??
                false;
        _sendJson(request, {'level': level, 'isCharging': charging});

      case 'get_location':
        _sendJson(request, {
          'note':
              'Use the gateway node capability: location.get for live GPS data',
          'command': 'location.get',
        });

      case 'read_sensor':
        final sensorType = data['sensor_type'] as String? ?? 'accelerometer';
        _sendJson(request, {
          'note':
              'Use the gateway node capability: sensor.read for live sensor data',
          'command': 'sensor.read',
          'sensor_type': sensorType,
        });

      case 'take_photo':
        _sendJson(request, {
          'note': 'Use the gateway node capability: camera.snap',
          'command': 'camera.snap',
        });

      default:
        _sendError(request, 'Unknown device action: $action');
    }
  }

  // ── Partner skill proxies (delegate to SkillsService → GatewaySkillProxy) ──

  Future<void> _handleTwilio(HttpRequest request) async {
    final method =
        request.uri.path.contains('webhook') ? 'get_status' : 'get_status';
    final result = await SkillsService()
        .executeSkill('twilio-voice', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleAgentCard(HttpRequest request) async {
    final method =
        request.uri.path.contains('create') ? 'create_card' : 'get_balance';
    final result = await SkillsService()
        .executeSkill('agent-card', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleMoltLaunch(HttpRequest request) async {
    final method =
        request.uri.path.contains('identity') ? 'get_identity' : 'get_rep';
    final result = await SkillsService()
        .executeSkill('molt-launch', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleValeo(HttpRequest request) async {
    final method =
        request.uri.path.contains('audit') ? 'get_audit' : 'get_budget';
    final result = await SkillsService()
        .executeSkill('valeo-sentinel', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _sendSkillResult(HttpRequest request, SkillResult result) {
    if (result.success && result.data is Map<String, dynamic>) {
      _sendJson(request, result.data as Map<String, dynamic>);
    } else if (result.success) {
      _sendJson(request, {'result': result.data});
    } else {
      _sendError(request, result.error ?? 'Unknown skill error');
    }
  }

  void _sendNodeFrame(
    HttpRequest request,
    dynamic frame, {
    Map<String, dynamic>? fallback,
  }) {
    if (frame.isError) {
      final error = frame.error;
      _sendError(request, error is Map ? jsonEncode(error) : '$error');
      return;
    }
    final payload = frame.payload;
    if (payload is Map<String, dynamic>) {
      _sendJson(request, {'success': true, ...payload});
    } else {
      _sendJson(request, {'success': true, ...?fallback});
    }
  }

  void _sendJson(
    HttpRequest request,
    Map<String, dynamic> data, {
    int statusCode = HttpStatus.ok,
  }) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data))
      ..close();
  }

  void _sendError(HttpRequest request, String error) {
    request.response
      ..statusCode = HttpStatus.badRequest
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': error}))
      ..close();
  }

  void _sendNotFound(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not Found')
      ..close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _startFuture = null;
  }
}

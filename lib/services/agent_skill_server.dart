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
import 'native_bridge.dart';
import 'native_gateway_smoke_service.dart';
import 'capabilities/avatar_capability.dart';
import 'capabilities/blog_watcher_capability.dart';
import 'capabilities/camera_capability.dart';
import 'capabilities/clawhub_capability.dart';
import 'capabilities/device_capability.dart';
import 'capabilities/flash_capability.dart';
import 'capabilities/github_capability.dart';
import 'capabilities/goplaces_capability.dart';
import 'capabilities/location_capability.dart';
import 'capabilities/meme_maker_capability.dart';
import 'capabilities/nano_pdf_capability.dart';
import 'capabilities/notion_capability.dart';
import 'capabilities/sensor_capability.dart';
import 'capabilities/session_logs_capability.dart';
import 'capabilities/summarize_capability.dart';
import 'capabilities/vibration_capability.dart';
import 'capabilities/weather_capability.dart';
import 'capabilities/xurl_capability.dart';

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
  final BlogWatcherCapability _blogWatcherCapability = BlogWatcherCapability();
  final CameraCapability _cameraCapability = CameraCapability();
  final ClawHubCapability _clawHubCapability = ClawHubCapability();
  final DeviceCapability _deviceCapability = DeviceCapability();
  final FlashCapability _flashCapability = FlashCapability();
  final GitHubCapability _githubCapability = GitHubCapability();
  final GoPlacesCapability _goPlacesCapability = GoPlacesCapability();
  final LocationCapability _locationCapability = LocationCapability();
  final MemeMakerCapability _memeMakerCapability = MemeMakerCapability();
  final NanoPdfCapability _nanoPdfCapability = NanoPdfCapability();
  final NotionCapability _notionCapability = NotionCapability();
  final SensorCapability _sensorCapability = SensorCapability();
  final SessionLogsCapability _sessionLogsCapability = SessionLogsCapability();
  final SummarizeCapability _summarizeCapability = SummarizeCapability();
  final VibrationCapability _vibrationCapability = VibrationCapability();
  final WeatherCapability _weatherCapability = WeatherCapability();
  final XurlCapability _xurlCapability = XurlCapability();

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
      await _handleBattery(request);
    } else if ((request.method == 'GET' || request.method == 'POST') &&
        (path == '/vibrate' || path == '/haptic/vibrate')) {
      await _handleLegacyVibrate(request);
    } else if (request.method == 'GET' && path == '/sensor') {
      await _handleLegacySensor(request);
    } else if (request.method == 'GET' && path == '/sensors') {
      await _handleLegacySensorList(request);
    } else if (request.method == 'GET' && path == '/location') {
      await _handleLegacyLocation(request);
    } else if (request.method == 'GET' && path == '/weather') {
      await _handleLegacyWeather(request);
    } else if (request.method == 'GET' && path == '/clawhub') {
      await _handleLegacyClawHub(request);
    } else if ((request.method == 'GET' || request.method == 'POST') &&
        path == '/meme') {
      await _handleLegacyMeme(request);
    } else if ((request.method == 'GET' || request.method == 'POST') &&
        (path == '/flashlight' ||
            path.startsWith('/flashlight/') ||
            path == '/torch' ||
            path.startsWith('/torch/'))) {
      await _handleLegacyFlashlight(request);
    } else if (request.method == 'GET' &&
        (path == '/device/status' || path == '/device/info')) {
      await _handleLegacyDeviceAction(request, 'device_status');
    } else if (request.method == 'GET' && path == '/device/health') {
      await _handleLegacyDeviceAction(request, 'device_health');
    } else if (request.method == 'GET' && path == '/device/permissions') {
      await _handleLegacyDeviceAction(request, 'device_permissions');
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
        path == '/api/native-gateway/production-chat-response-ui-canary') {
      await _handleNativeGatewayProductionChatResponseUiCanary(request);
    } else if (request.method == 'POST' &&
        path == '/api/native-gateway/production-chat-route-selection-canary') {
      await _handleNativeGatewayProductionChatRouteSelectionCanary(request);
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
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-provider-tool-plan-execution-canary') {
      await _handleNativeGatewayProductionProviderToolPlanExecutionCanary(
          request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-provider-live-tool-execution-canary') {
      await _handleNativeGatewayProductionProviderLiveToolExecutionCanary(
          request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-provider-live-tool-continuation-canary') {
      await _handleNativeGatewayProductionProviderLiveToolContinuationCanary(
          request);
    } else if (request.method == 'POST' &&
        path ==
            '/api/native-gateway/production-chat-loop-continuation-canary') {
      await _handleNativeGatewayProductionChatLoopContinuationCanary(request);
    } else if (request.method == 'POST' &&
        path == '/api/debug/app-native-chat-tool-smoke') {
      await _handleAppNativeChatToolSmoke(request);
    } else if (request.method == 'POST' && path == '/api/tools/execute') {
      await _handleToolsExecute(request);
    } else if (request.method == 'POST' && path == '/api/python/exec') {
      await _handleNativePythonExec(request);
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
    } else if (path.startsWith('/moonpay')) {
      await _handleMoonPay(request);
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

  Future<void> _handleNativeGatewayProductionChatResponseUiCanary(
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
                  'No OpenRouter model/API key is configured for native chat response UI canary.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report =
          await NativeGatewaySmokeService.runProductionPortChatResponseUiCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: providerConfig,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production chat response UI canary with PRoot rollback'
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

  Future<void> _handleNativeGatewayProductionChatRouteSelectionCanary(
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
      final requestedModel =
          model == null || model.isEmpty ? 'openrouter/auto' : model;
      final explicitConfig = args['providerConfig'] is Map
          ? Map<String, dynamic>.from(args['providerConfig'] as Map)
          : null;
      final providerConfig = explicitConfig ??
          await GatewayService().resolveNativeProviderLiveCanaryConfig(
            model: requestedModel,
          );

      if (providerConfig == null) {
        _sendJson(
            request,
            {
              'ok': false,
              'error': 'openrouter_provider_config_unavailable',
              'message':
                  'No OpenRouter model/API key is configured for native chat route selection canary.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report = await NativeGatewaySmokeService
          .runProductionPortNativeChatRouteSelectionCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: providerConfig,
        requestedModel: requestedModel,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production chat route selection canary with provider fallback'
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

  Future<void> _handleNativeGatewayProductionProviderToolPlanExecutionCanary(
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
          .runProductionPortProviderToolPlanAllowlistedExecutionCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        model: model == null || model.isEmpty ? 'openrouter/auto' : model,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production provider tool plan to allowlisted execution canary: vibrate once'
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

  Future<void> _handleNativeGatewayProductionProviderLiveToolExecutionCanary(
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
                  'No OpenRouter model/API key is configured for native live tool execution canary.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report = await NativeGatewaySmokeService
          .runProductionPortProviderLiveToolExecutionCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: providerConfig,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production live provider tool execution canary: wave right'
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

  Future<void> _handleNativeGatewayProductionProviderLiveToolContinuationCanary(
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
                  'No OpenRouter model/API key is configured for native live tool continuation canary.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report = await NativeGatewaySmokeService
          .runProductionPortProviderLiveToolContinuationCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: providerConfig,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production live provider tool result continuation canary: vibrate once'
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

  Future<void> _handleNativeGatewayProductionChatLoopContinuationCanary(
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
                  'No OpenRouter model/API key is configured for native chat loop continuation canary.',
            },
            statusCode: HttpStatus.badRequest);
        return;
      }

      final report = await NativeGatewaySmokeService
          .runProductionPortNativeChatLoopContinuationCanary(
        log: (message) => debugPrint('[GATEWAY] $message'),
        providerConfig: providerConfig,
        prompt: prompt == null || prompt.isEmpty
            ? 'native production chat loop continuation canary: vibrate once and answer'
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

  // ── Legacy skill-doc compatibility routes ────────────────────────────────
  Future<void> _handleBattery(HttpRequest request) async {
    await _processDeviceControl({'action': 'get_battery'}, request);
  }

  Future<void> _handleLegacyVibrate(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final durationMs = _intValue(
            body['durationMs'] ?? request.uri.queryParameters['durationMs']) ??
        220;
    final pattern = _intList(body['pattern']);
    await _processDeviceControl({
      'action': 'vibrate',
      'durationMs': durationMs,
      if (pattern != null) 'pattern': pattern,
    }, request);
  }

  Future<void> _handleLegacySensor(HttpRequest request) async {
    final type = request.uri.queryParameters['type'] ??
        request.uri.queryParameters['sensor'];
    await _processDeviceControl({
      'action': 'read_sensor',
      if (type != null) 'sensor_type': type,
    }, request);
  }

  Future<void> _handleLegacySensorList(HttpRequest request) async {
    await _processDeviceControl({'action': 'list_sensors'}, request);
  }

  Future<void> _handleLegacyLocation(HttpRequest request) async {
    await _processDeviceControl({'action': 'get_location'}, request);
  }

  Future<void> _handleLegacyFlashlight(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final pathParts = request.uri.path
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part.toLowerCase())
        .toList();
    final rawAction = (body['action'] ??
            request.uri.queryParameters['action'] ??
            (pathParts.length > 1 ? pathParts.last : 'toggle'))
        .toString()
        .trim()
        .toLowerCase();
    final action = switch (rawAction) {
      'on' || 'enable' || 'start' || 'true' => 'flashlight_on',
      'off' || 'disable' || 'stop' || 'false' => 'flashlight_off',
      'status' || 'state' || 'get_status' => 'flashlight_status',
      _ => 'flashlight_toggle',
    };
    await _processDeviceControl({'action': action}, request);
  }

  Future<void> _handleLegacyDeviceAction(
    HttpRequest request,
    String action,
  ) async {
    await _processDeviceControl({'action': action}, request);
  }

  Future<void> _handleLegacyWeather(HttpRequest request) async {
    await _processDeviceControl({
      'action': 'weather_current',
      ...request.uri.queryParameters,
    }, request);
  }

  Future<void> _handleLegacyClawHub(HttpRequest request) async {
    final query = request.uri.queryParameters;
    await _processDeviceControl({
      'action': query.containsKey('slug') || query.containsKey('id')
          ? 'clawhub_info'
          : 'clawhub_search',
      ...query,
    }, request);
  }

  Future<void> _handleLegacyMeme(HttpRequest request) async {
    final body = await _readJsonBody(request);
    await _processDeviceControl({
      'action': 'meme_maker_create',
      ...request.uri.queryParameters,
      ...body,
    }, request);
  }

  void _handleToolsCatalog(HttpRequest request) {
    final catalog = SkillsService().getToolsCatalog();
    _sendJson(request, {
      'tools': catalog,
      'callbackUrl': 'http://127.0.0.1:8765',
      'executeUrl': 'http://127.0.0.1:8765/api/tools/execute',
      'executionEnabled': true,
      'registrationRequired': true,
      'bridge': 'AgentSkillServer',
      'note':
          'These app-native skills are callable by Gateway chat only after the Gateway registers or otherwise imports their schemas.',
    });
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
      'avatar_sequence': 'avatar.sequence',
      'avatar_mode': 'avatar.mode',
      'avatar_model': 'avatar.model',
      'avatar_status': 'avatar.status',
      'gesture.wave': 'avatar.gesture',
      'gestures.wave': 'avatar.gesture',
      'wave': 'avatar.gesture',
      'blogwatcher': 'blogwatcher.check',
      'blogwatcher_check': 'blogwatcher.check',
      'blogwatcher.check': 'blogwatcher.check',
      'session-logs': 'session-logs.query',
      'session_logs': 'session-logs.query',
      'session_logs_query': 'session-logs.query',
      'session-logs.query': 'session-logs.query',
      'camsnap': 'camera.snap',
      'camera_snap': 'camera.snap',
      'camera_clip': 'camera.clip',
      'camera_list': 'camera.list',
      'clawhub_search': 'clawhub.search',
      'clawhub_info': 'clawhub.info',
      'github': 'github.user',
      'github_user': 'github.user',
      'github.user': 'github.user',
      'gh-issues': 'gh-issues.list',
      'gh_issues': 'gh-issues.list',
      'gh_issues_list': 'gh-issues.list',
      'gh-issues.list': 'gh-issues.list',
      'github_issues': 'gh-issues.list',
      'github.issues': 'gh-issues.list',
      'goplaces': 'goplaces.search',
      'goplaces_search': 'goplaces.search',
      'goplaces.search': 'goplaces.search',
      'google_places': 'goplaces.search',
      'places_search': 'goplaces.search',
      'notion': 'notion.search',
      'notion_search': 'notion.search',
      'notion.search': 'notion.search',
      'meme_maker_create': 'meme-maker.create',
      'meme-maker_create': 'meme-maker.create',
      'nano-pdf': 'nano-pdf.extract',
      'nano_pdf': 'nano-pdf.extract',
      'nano_pdf_extract': 'nano-pdf.extract',
      'nano-pdf.extract': 'nano-pdf.extract',
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
      'weather_current': 'weather.current',
      'weather_forecast': 'weather.forecast',
      'get_weather': 'weather.current',
      'summarize': 'summarize.text',
      'summarize_text': 'summarize.text',
      'summarize.text': 'summarize.text',
      'xurl': 'xurl.request',
      'xurl_request': 'xurl.request',
      'xurl.request': 'xurl.request',
      'device_health': 'device.health',
      'device_status': 'device.status',
      'device_info': 'device.info',
      'device_permissions': 'device.permissions',
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
      case 'avatar.sequence':
        final steps = input['steps'];
        final ok = steps is List && steps.isNotEmpty;
        return _NativeGatewayDryRunArgumentValidation(
          ok: ok,
          code: ok ? 'ok' : 'missing_steps',
          message: ok
              ? 'avatar.sequence arguments are dispatchable'
              : 'avatar.sequence requires a non-empty steps array',
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
      case 'xurl.request':
        final rawUrl = input['url']?.toString().trim();
        final uri =
            rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
        final method =
            input['method']?.toString().trim().toUpperCase() ?? 'GET';
        final methodOk =
            method == 'GET' || method == 'HEAD' || method == 'POST';
        final urlOk = uri != null &&
            uri.hasScheme &&
            uri.host.isNotEmpty &&
            (uri.scheme == 'http' || uri.scheme == 'https');
        final localPost = method == 'POST' &&
            uri != null &&
            XurlCapability.isLoopbackHostForPolicy(uri.host);
        return _NativeGatewayDryRunArgumentValidation(
          ok: urlOk && methodOk && !localPost,
          code: !urlOk
              ? 'invalid_url'
              : localPost
                  ? 'local_post_blocked'
                  : methodOk
                      ? 'ok'
                      : 'invalid_method',
          message: !urlOk
              ? 'xurl.request requires an absolute http or https URL'
              : localPost
                  ? 'xurl.request does not allow local control endpoint POSTs'
                  : methodOk
                      ? 'xurl.request arguments are dispatchable'
                      : 'xurl.request supports GET, HEAD, and POST',
        );
      case 'summarize.text':
        final text = (input['text'] ?? input['content'] ?? input['input'])
            ?.toString()
            .trim();
        final ok = text != null && text.isNotEmpty;
        return _NativeGatewayDryRunArgumentValidation(
          ok: ok,
          code: ok ? 'ok' : 'missing_text',
          message: ok
              ? 'summarize.text arguments are dispatchable'
              : 'summarize.text requires provided text',
        );
      case 'blogwatcher.check':
        final rawUrl = input['url']?.toString().trim();
        final uri =
            rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl);
        final ok = uri != null &&
            uri.hasScheme &&
            uri.host.isNotEmpty &&
            (uri.scheme == 'http' || uri.scheme == 'https');
        return _NativeGatewayDryRunArgumentValidation(
          ok: ok,
          code: ok ? 'ok' : 'invalid_url',
          message: ok
              ? 'blogwatcher.check arguments are dispatchable'
              : 'blogwatcher.check requires an absolute http or https URL',
        );
      case 'session-logs.query':
        final action = (input['action'] ?? 'list')
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll('_', '-');
        final query = input['query']?.toString().trim();
        final actionOk =
            action == 'list' || action == 'read' || action == 'search';
        final queryOk = action != 'search' || query?.isNotEmpty == true;
        return _NativeGatewayDryRunArgumentValidation(
          ok: actionOk && queryOk,
          code: !actionOk
              ? 'invalid_action'
              : queryOk
                  ? 'ok'
                  : 'missing_query',
          message: actionOk && queryOk
              ? 'session-logs.query arguments are dispatchable'
              : 'session-logs.query requires action list/read/search and a query for search',
        );
      case 'github.user':
        return const _NativeGatewayDryRunArgumentValidation(
          ok: true,
          code: 'ok',
          message: 'github.user arguments are dispatchable',
        );
      case 'gh-issues.list':
        final owner = input['owner']?.toString().trim();
        final repo = input['repo']?.toString().trim();
        final ok = owner != null &&
            owner.isNotEmpty &&
            repo != null &&
            repo.isNotEmpty;
        return _NativeGatewayDryRunArgumentValidation(
          ok: ok,
          code: ok ? 'ok' : 'missing_repository',
          message: ok
              ? 'gh-issues.list arguments are dispatchable'
              : 'gh-issues.list requires owner and repo',
        );
      case 'goplaces.search':
        final query = (input['query'] ?? input['textQuery'])?.toString().trim();
        final ok = query != null && query.isNotEmpty;
        return _NativeGatewayDryRunArgumentValidation(
          ok: ok,
          code: ok ? 'ok' : 'missing_query',
          message: ok
              ? 'goplaces.search arguments are dispatchable'
              : 'goplaces.search requires a query',
        );
      case 'notion.search':
        final query = (input['query'] ?? input['text'])?.toString().trim();
        final ok = query != null && query.isNotEmpty;
        return _NativeGatewayDryRunArgumentValidation(
          ok: ok,
          code: ok ? 'ok' : 'missing_query',
          message: ok
              ? 'notion.search arguments are dispatchable'
              : 'notion.search requires a query',
        );
      case 'nano-pdf.extract':
        final pdfBase64 =
            (input['pdfBase64'] ?? input['base64'] ?? input['pdf'])
                ?.toString()
                .trim();
        return _NativeGatewayDryRunArgumentValidation(
          ok: pdfBase64 != null && pdfBase64.isNotEmpty,
          code:
              pdfBase64 != null && pdfBase64.isNotEmpty ? 'ok' : 'missing_pdf',
          message: pdfBase64 != null && pdfBase64.isNotEmpty
              ? 'nano-pdf.extract arguments are dispatchable'
              : 'nano-pdf.extract requires pdfBase64 bytes',
        );
      case 'camera.snap':
      case 'camera.clip':
      case 'camera.list':
      case 'clawhub.search':
      case 'clawhub.info':
      case 'meme-maker.create':
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
      case 'weather.current':
      case 'weather.forecast':
      case 'avatar.mode':
      case 'avatar.model':
      case 'avatar.status':
      case 'device.health':
      case 'device.status':
      case 'device.info':
      case 'device.permissions':
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
      case 'blogwatcher':
        return 'BlogWatcherCapability';
      case 'session-logs':
        return 'SessionLogsCapability';
      case 'camera':
        return 'CameraCapability';
      case 'canvas':
        return 'CanvasCapability';
      case 'clawhub':
        return 'ClawHubCapability';
      case 'flash':
        return 'FlashCapability';
      case 'haptic':
        return 'VibrationCapability';
      case 'location':
        return 'LocationCapability';
      case 'meme-maker':
        return 'MemeMakerCapability';
      case 'nano-pdf':
        return 'NanoPdfCapability';
      case 'device':
        return 'DeviceCapability';
      case 'screen':
        return 'ScreenCapability';
      case 'sensor':
        return 'SensorCapability';
      case 'summarize':
        return 'SummarizeCapability';
      case 'weather':
        return 'WeatherCapability';
      case 'xurl':
        return 'XurlCapability';
      default:
        return 'UnknownCapability';
    }
  }

  Future<void> _handleAppNativeChatToolSmoke(HttpRequest request) async {
    try {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final prompt = body['prompt']?.toString().trim().isNotEmpty == true
          ? body['prompt'].toString()
          : 'vibrate once';
      final model = body['model']?.toString();
      final chunks = <String>[];
      var timedOut = false;

      await for (final chunk in GatewayService()
          .sendMessage(prompt, model: model)
          .timeout(const Duration(seconds: 20), onTimeout: (sink) {
        timedOut = true;
        sink.close();
      })) {
        chunks.add(chunk);
        if (chunks.length >= 32) break;
      }

      final toolUseSeen =
          chunks.any((chunk) => chunk.contains('\x00TOOL_USE:'));
      final toolResultSeen =
          chunks.any((chunk) => chunk.contains('\x00TOOL_RESULT:'));
      final visibleText = chunks
          .where((chunk) =>
              !chunk.contains('\x00TOOL_USE:') &&
              !chunk.contains('\x00TOOL_RESULT:'))
          .join();

      _sendJson(request, {
        'success': toolUseSeen && toolResultSeen,
        'prompt': prompt,
        'toolUseSeen': toolUseSeen,
        'toolResultSeen': toolResultSeen,
        'timedOut': timedOut,
        'visibleText': visibleText,
        'chunks': chunks.map(_jsonSafeChunk).toList(growable: false),
      });
    } catch (e) {
      _sendError(request, 'App-native chat tool smoke failed: $e');
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
        case 'blogwatcher':
        case 'blogwatcher_check':
        case 'blogwatcher.check':
          final frame = await _blogWatcherCapability.handle(
            'blogwatcher.check',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'session-logs':
        case 'session_logs':
        case 'session_logs_query':
        case 'session-logs.query':
          final frame = await _sessionLogsCapability.handle(
            'session-logs.query',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'github':
        case 'github_user':
        case 'github.user':
          final frame = await _githubCapability.handle(
            'github.user',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'gh-issues':
        case 'gh_issues':
        case 'gh_issues_list':
        case 'gh-issues.list':
        case 'github_issues':
        case 'github.issues':
          final frame = await _githubCapability.handle(
            'gh-issues.list',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'goplaces':
        case 'goplaces_search':
        case 'goplaces.search':
        case 'google_places':
        case 'places_search':
          final frame = await _goPlacesCapability.handle(
            'goplaces.search',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'notion':
        case 'notion_search':
        case 'notion.search':
          final frame = await _notionCapability.handle(
            'notion.search',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'nano-pdf':
        case 'nano_pdf':
        case 'nano_pdf_extract':
        case 'nano-pdf.extract':
          final frame = await _nanoPdfCapability.handle(
            'nano-pdf.extract',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'summarize':
        case 'summarize_text':
        case 'summarize.text':
          final frame = await _summarizeCapability.handle(
            'summarize.text',
            input,
          );
          _sendNodeFrame(request, frame, fallback: input);
        case 'camsnap':
        case 'camera_snap':
        case 'camera.snap':
          final facing = input['facing']?.toString().toLowerCase() == 'front'
              ? 'front'
              : 'back';
          final frame = await _cameraCapability.handleWithPermission(
            'camera.snap',
            {'facing': facing},
          );
          _sendNodeFrame(request, frame, fallback: {'facing': facing});
        case 'xurl':
        case 'xurl_request':
        case 'xurl.request':
          final frame = await _xurlCapability.handle('xurl.request', input);
          _sendNodeFrame(request, frame, fallback: input);
        default:
          final result =
              await SkillsService().executeSkill(name, parameters: input);
          _sendSkillResult(request, result);
      }
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  Future<void> _handleNativePythonExec(HttpRequest request) async {
    try {
      final body = await _readJsonBody(request);
      final result = await NativeBridge.runNativePython(body);
      _sendJson(request, result);
    } catch (e) {
      _sendJson(
        request,
        {
          'ok': false,
          'exitCode': 1,
          'stdout': '',
          'stderr': 'Native Python bridge failed: $e',
        },
        statusCode: HttpStatus.internalServerError,
      );
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
        final gesture = data['gesture']?.toString();
        if (gesture == null) {
          return _sendError(request, 'Missing gesture parameter');
        }
        final result = await _requestAvatarGesture({
          ...data,
          'gesture': gesture,
        });
        _sendAvatarGestureResult(request, result);

      case 'play_sequence':
        final steps = data['steps'];
        if (steps is! List || steps.isEmpty) {
          return _sendError(request, 'Missing steps parameter');
        }
        final result = await _requestAvatarGesture({
          ...data,
          'action': 'sequence',
          'steps': steps,
        });
        _sendAvatarGestureResult(request, result);

      case 'play_vrma':
      case 'play_vrma_composite':
        final explicitAsset = data['assetPath']?.toString() ??
            data['path']?.toString() ??
            data['vrmaPath']?.toString();
        final base = data['base']?.toString() ??
            data['gesture']?.toString() ??
            data['animation']?.toString();
        final layers = (data['layers'] as List?)
                ?.map((item) => item.toString())
                .where((item) => item.trim().isNotEmpty)
                .toList() ??
            const <String>[];
        final target = explicitAsset?.trim().isNotEmpty == true
            ? explicitAsset
            : layers.isNotEmpty
                ? layers.first
                : base;
        if (target == null || target.trim().isEmpty) {
          return _sendError(request, 'Missing base/gesture/layers parameter');
        }
        final result = await _requestAvatarGesture({
          ...data,
          'gesture': data['gesture']?.toString() ?? target,
          'assetPath': target,
          'base': base,
          'layers': layers,
          'blendTime': data['blendTime'] ?? 0.4,
        });
        _sendAvatarGestureResult(request, result);

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

  void _sendAvatarGestureResult(
    HttpRequest request,
    Map<String, dynamic> result,
  ) {
    final status = result['status']?.toString().toLowerCase();
    final success = status == 'started' || status == 'completed';
    _sendJson(request, {
      ...result,
      'success': success,
      'ok': success,
    });
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
        if (request['assetPath'] != null)
          'path': request['assetPath'].toString(),
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
        final pattern = _intList(data['pattern']);
        final durationMs = _intValue(data['durationMs']) ?? 220;
        final params = pattern == null
            ? {'durationMs': durationMs}
            : <String, dynamic>{'pattern': pattern};
        final frame = await _vibrationCapability.handle(
          'haptic.vibrate',
          params,
        );
        _sendNodeFrame(request, frame, fallback: params);

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

      case 'flashlight_status':
        final frame = await _flashCapability.handleWithPermission(
          'flash.status',
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

      case 'device_health':
        final frame = await _deviceCapability.handle(
          'device.health',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'device_status':
        final frame = await _deviceCapability.handle(
          'device.status',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'device_info':
        final frame = await _deviceCapability.handle(
          'device.info',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'device_permissions':
        final frame = await _deviceCapability.handle(
          'device.permissions',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'get_location':
        final frame = await _locationCapability.handleWithPermission(
          'location.get',
          const {},
        );
        _sendNodeFrame(request, frame);

      case 'xurl_request':
      case 'xurl':
      case 'xurl.request':
        final frame = await _xurlCapability.handle(
          'xurl.request',
          data,
        );
        _sendNodeFrame(request, frame, fallback: data);

      case 'weather_current':
      case 'get_weather':
      case 'weather_forecast':
        final frame = await _weatherCapability.handle(
          action == 'weather_forecast' ? 'weather.forecast' : 'weather.current',
          data,
        );
        _sendNodeFrame(request, frame);

      case 'clawhub_search':
      case 'clawhub_info':
        final frame = await _clawHubCapability.handle(
          action == 'clawhub_info' ? 'clawhub.info' : 'clawhub.search',
          data,
        );
        _sendNodeFrame(request, frame);

      case 'meme_maker_create':
        final frame = await _memeMakerCapability.handle(
          'meme-maker.create',
          data,
        );
        _sendNodeFrame(request, frame);

      case 'list_sensors':
      case 'read_sensor':
        final sensorType = data['sensor_type']?.toString().trim().toLowerCase();
        if (action == 'list_sensors' || sensorType == 'list') {
          final frame = await _sensorCapability.handleWithPermission(
            'sensor.list',
            const {},
          );
          return _sendNodeFrame(request, frame);
        }
        final sensor = switch (sensorType) {
          'gyro' => 'gyroscope',
          null || '' => 'accelerometer',
          _ => sensorType,
        };
        final frame = await _sensorCapability.handleWithPermission(
          'sensor.read',
          {'sensor': sensor},
        );
        _sendNodeFrame(request, frame, fallback: {'sensor': sensor});

      case 'camera_list':
      case 'camera_snap':
      case 'take_photo':
        if (action == 'camera_list') {
          final frame = await _cameraCapability.handleWithPermission(
            'camera.list',
            const {},
          );
          return _sendNodeFrame(request, frame);
        }
        final facing = data['facing']?.toString().toLowerCase() == 'front'
            ? 'front'
            : 'back';
        final frame = await _cameraCapability.handleWithPermission(
          'camera.snap',
          {'facing': facing},
        );
        _sendNodeFrame(request, frame, fallback: {'facing': facing});

      default:
        _sendError(request, 'Unknown device action: $action');
    }
  }

  // ── Partner skill routes (delegate to SkillsService gateway/native adapter) ──

  Future<void> _handleTwilio(HttpRequest request) async {
    await _handlePartnerSkill(
      request,
      skillId: 'twilio-voice',
      defaultMethod: 'get_status',
      pathMethods: const {
        'relay': 'set_relay',
        'transcription': 'set_transcription',
        'status': 'get_status',
        'webhook': 'get_status',
      },
    );
  }

  Future<void> _handleAgentCard(HttpRequest request) async {
    await _handlePartnerSkill(
      request,
      skillId: 'agent-card',
      defaultMethod: 'get_balance',
      pathMethods: const {
        'create': 'create_card',
        'refill': 'set_refill_policy',
        'balance': 'get_balance',
      },
    );
  }

  Future<void> _handleMoltLaunch(HttpRequest request) async {
    await _handlePartnerSkill(
      request,
      skillId: 'molt-launch',
      defaultMethod: 'get_identity',
      pathMethods: const {
        'identity': 'get_identity',
        'rep': 'get_rep',
        'reputation': 'get_rep',
        'register': 'register',
      },
    );
  }

  Future<void> _handleValeo(HttpRequest request) async {
    await _handlePartnerSkill(
      request,
      skillId: 'valeo-sentinel',
      defaultMethod: 'get_budget',
      pathMethods: const {
        'audit': 'get_audit',
        'policy': 'set_policy',
        'budget': 'get_budget',
      },
    );
  }

  Future<void> _handleMoonPay(HttpRequest request) async {
    await _handlePartnerSkill(
      request,
      skillId: 'moonpay',
      defaultMethod: 'get_portfolio',
      pathMethods: const {
        'portfolio': 'get_portfolio',
        'price': 'get_price',
        'swap': 'swap',
        'bridge': 'bridge',
        'buy': 'buy',
        'sell': 'sell',
        'dca': 'dca_list',
      },
    );
  }

  Future<void> _handlePartnerSkill(
    HttpRequest request, {
    required String skillId,
    required String defaultMethod,
    required Map<String, String> pathMethods,
  }) async {
    final body = await _readJsonBody(request);
    var method = body['method']?.toString().trim();
    if (method == null || method.isEmpty) {
      method = body['action']?.toString().trim();
    }
    if (method == null || method.isEmpty) {
      final path = request.uri.path.toLowerCase();
      for (final entry in pathMethods.entries) {
        if (path.contains(entry.key)) {
          method = entry.value;
          break;
        }
      }
    }
    method ??= defaultMethod;
    final result = await SkillsService().executeSkill(
      skillId,
      parameters: {...body, 'method': method},
    );
    _sendSkillResult(request, result);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    if (request.method != 'POST' &&
        request.method != 'PUT' &&
        request.method != 'PATCH') {
      return <String, dynamic>{};
    }
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<int>? _intList(dynamic value) {
    if (value is! List) return null;
    final result = <int>[];
    for (final item in value) {
      final parsed = _intValue(item);
      if (parsed == null) return null;
      result.add(parsed.clamp(0, 5000));
    }
    return result.isEmpty ? null : result;
  }

  String _jsonSafeChunk(String value) => value.replaceAll('\x00', r'\u0000');

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
      _sendJson(request, {'success': true, ..._sanitizeNodePayload(payload)});
    } else {
      _sendJson(request, {'success': true, ...?fallback});
    }
  }

  Map<String, dynamic> _sanitizeNodePayload(Map<String, dynamic> payload) {
    final copy = Map<String, dynamic>.from(payload);
    final base64 = copy.remove('base64')?.toString();
    if (base64 != null && base64.isNotEmpty) {
      copy['base64Omitted'] = true;
      copy['base64Bytes'] = base64.length;
      copy['attachedImage'] = true;
    }
    return copy;
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

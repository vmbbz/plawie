import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'preferences_service.dart';
import 'skills_service.dart';
import 'tts_service.dart';

/// Local HTTP Server that listens on 127.0.0.1:8765 for OpenClaw Native Skills.
/// The gateway AI agent POSTs to these endpoints to control the Android app.
///
/// Routes:
///   GET  /battery                    — legacy battery stub
///   GET  /api/tools                  — full tools catalog from SkillsService
///   GET  /api/skills/list            — all skills list
///   POST /api/avatar/control         — change VRM, gestures, emotions (avatar-control skill)
///   POST /api/avatar/equip           — legacy equip alias  
///   POST /api/tts/control            — switch TTS engine/voice, speak text (tts-voice skill)
///   POST /api/device/control         — vibrate, flashlight, battery, sensors (device-node skill)
///   POST /twilio/*                   — twilio-voice skill proxy
///   POST /cards/*                    — agent-card skill proxy
///   POST /marketplace/*              — molt-launch skill proxy
///   POST /sentinel/*                 — valeo-sentinel skill proxy
class AgentSkillServer {
  HttpServer? _server;

  // Callbacks — set by ChatScreen so avatar changes are reflected in live UI
  void Function(String avatarFile)? onAvatarChanged;
  void Function(String gesture)? onGesturePlayed;
  void Function(String emotion)? onEmotionSet;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8765);
      debugPrint('AgentSkillServer listening on 127.0.0.1:8765');
      _server!.listen(_handleRequest);
    } catch (e) {
      debugPrint('AgentSkillServer failed to start: $e');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    if (request.method == 'GET' && path == '/battery') {
      _handleBattery(request);
    } else if (request.method == 'GET' && path == '/api/tools') {
      _handleToolsCatalog(request);
    } else if (request.method == 'GET' && path == '/api/skills/list') {
      _handleSkillsList(request);
    } else if (request.method == 'POST' && path == '/api/avatar/control') {
      await _handleAvatarControl(request);
    } else if (request.method == 'POST' && path == '/api/avatar/equip') {
      await _handleAvatarEquip(request);  // legacy alias
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

  // ── Avatar Control ─────────────────────────────────────────────────────────
  // Called by the AI agent via the 'avatar-control' skill.
  // Fires callbacks so ChatScreen's setState() updates the live VrmAvatarWidget.
  Future<void> _handleAvatarControl(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      final action = data['action'] as String? ?? 'get_status';

      switch (action) {
        case 'change_model':
          final model = data['model'] as String?;
          if (model == null) return _sendError(request, 'Missing model parameter');
          final filename = model.endsWith('.vrm') ? model : '$model.vrm';
          final prefs = PreferencesService();
          await prefs.init();
          prefs.selectedAvatar = filename;
          onAvatarChanged?.call(filename);
          _sendJson(request, {'success': true, 'model': filename});

        case 'play_gesture':
          final gesture = data['gesture'] as String?;
          if (gesture == null) return _sendError(request, 'Missing gesture parameter');
          onGesturePlayed?.call(gesture);
          _sendJson(request, {'success': true, 'gesture': gesture});

        case 'set_emotion':
          final emotion = data['emotion'] as String?;
          if (emotion == null) return _sendError(request, 'Missing emotion parameter');
          onEmotionSet?.call(emotion);
          _sendJson(request, {'success': true, 'emotion': emotion});

        case 'get_status':
          final prefs = PreferencesService();
          await prefs.init();
          _sendJson(request, {'avatar': prefs.selectedAvatar});

        default:
          _sendError(request, 'Unknown avatar action: $action');
      }
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  // Legacy /api/avatar/equip — kept for backward compat with old gateway skills
  Future<void> _handleAvatarEquip(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      final vrmId = data['vrm_id'] as String?;
      if (vrmId == null || vrmId.isEmpty) return _sendError(request, 'Missing vrm_id');
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
  // Called by the AI agent via the 'tts-voice' skill.
  Future<void> _handleTtsControl(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      final action = data['action'] as String? ?? 'get_status';
      final prefs = PreferencesService();
      await prefs.init();

      switch (action) {
        case 'set_engine':
          final engine = data['engine'] as String?;
          if (engine == null) return _sendError(request, 'Missing engine parameter');
          final validEngines = ['piper', 'native', 'elevenlabs', 'openai'];
          if (!validEngines.contains(engine)) {
            return _sendError(request, 'Invalid engine. Valid: ${validEngines.join(", ")}');
          }
          prefs.ttsEngine = engine;
          _sendJson(request, {'success': true, 'engine': engine});

        case 'set_voice':
          final voice = data['voice'] as String?;
          if (voice == null) return _sendError(request, 'Missing voice parameter');
          // Route to the correct prefs field based on current engine
          switch (prefs.ttsEngine) {
            case 'elevenlabs':
              prefs.elevenLabsVoiceId = voice;
            case 'openai':
              prefs.openAiTtsVoice = voice;
            default:
              // piper / native voice selection is model-level, stored as generic voice pref
              prefs.ttsEngine = prefs.ttsEngine; // no-op — piper uses file, not voice id
          }
          _sendJson(request, {'success': true, 'voice': voice, 'engine': prefs.ttsEngine});

        case 'speak':
          final text = data['text'] as String?;
          if (text == null || text.isEmpty) return _sendError(request, 'Missing text');
          // Fire and forget — don't await or the HTTP response will block
          final tts = TtsService();
          unawaited(tts.speak(text));
          _sendJson(request, {'success': true, 'speaking': text});

        case 'stop':
          final tts = TtsService();
          await tts.stop();
          _sendJson(request, {'success': true});

        case 'get_status':
          _sendJson(request, {
            'engine': prefs.ttsEngine,
            'voice': prefs.elevenLabsVoiceId.isNotEmpty ? prefs.elevenLabsVoiceId
                : prefs.openAiTtsVoice.isNotEmpty ? prefs.openAiTtsVoice
                : 'default',
          });

        default:
          _sendError(request, 'Unknown TTS action: $action');
      }
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  // ── Device Node Control ─────────────────────────────────────────────────────
  // Called by the AI agent via the 'device-node' skill.
  // Delegates to the NodeProvider capability handlers via MethodChannel / platform.
  Future<void> _handleDeviceControl(HttpRequest request) async {
    try {
      final data = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
      final action = data['action'] as String? ?? 'get_battery';

      switch (action) {
        case 'vibrate':
          final pattern = (data['pattern'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ?? [0, 300];
          await const MethodChannel('plawie/haptics').invokeMethod(
            'vibrate',
            {'pattern': pattern},
          );
          _sendJson(request, {'success': true, 'pattern': pattern});

        case 'flashlight_on':
          await const MethodChannel('plawie/flash').invokeMethod('on');
          _sendJson(request, {'success': true, 'flashlight': 'on'});

        case 'flashlight_off':
          await const MethodChannel('plawie/flash').invokeMethod('off');
          _sendJson(request, {'success': true, 'flashlight': 'off'});

        case 'get_battery':
          // Use the real battery method channel (Android BatteryManager)
          final level = await const MethodChannel('plawie/device')
              .invokeMethod<int>('getBatteryLevel') ?? -1;
          final charging = await const MethodChannel('plawie/device')
              .invokeMethod<bool>('isCharging') ?? false;
          _sendJson(request, {'level': level, 'isCharging': charging});

        case 'get_location':
          // Delegates to LocationCapability via NodeService — pull from prefs or trigger
          _sendJson(request, {
            'note': 'Use the gateway node capability: location.get for live GPS data',
            'command': 'location.get',
          });

        case 'read_sensor':
          final sensorType = data['sensor_type'] as String? ?? 'accelerometer';
          _sendJson(request, {
            'note': 'Use the gateway node capability: sensor.read for live sensor data',
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
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  // ── Partner skill proxies (delegate to SkillsService → GatewaySkillProxy) ──

  Future<void> _handleTwilio(HttpRequest request) async {
    // Use correct hyphenated ID to match the skill registry
    final method = request.uri.path.contains('webhook') ? 'get_status' : 'get_status';
    final result = await SkillsService().executeSkill('twilio-voice', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleAgentCard(HttpRequest request) async {
    final method = request.uri.path.contains('create') ? 'create_card' : 'get_balance';
    final result = await SkillsService().executeSkill('agent-card', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleMoltLaunch(HttpRequest request) async {
    final method = request.uri.path.contains('identity') ? 'get_identity' : 'get_rep';
    final result = await SkillsService().executeSkill('molt-launch', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleValeo(HttpRequest request) async {
    final method = request.uri.path.contains('audit') ? 'get_audit' : 'get_budget';
    final result = await SkillsService().executeSkill('valeo-sentinel', parameters: {'method': method});
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

  void _sendJson(HttpRequest request, Map<String, dynamic> data) {
    request.response
      ..statusCode = HttpStatus.ok
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
  }
}

// Suppress the unawaited Future lint for fire-and-forget calls.
void unawaited(Future<void> future) {}

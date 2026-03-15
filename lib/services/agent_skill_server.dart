import 'dart:convert';
import 'dart:io';
import 'preferences_service.dart';
import 'skills_service.dart';

/// Local HTTP Server that listens on 127.0.0.1:8765 for OpenClaw Native Skills.
/// The Proot AI Agent uses these endpoints to control the Android phone.
class AgentSkillServer {
  HttpServer? _server;

  Future<void> start() async {
    if (_server != null) return;

    try {
      // Bind to 8765 as expected by battery.md and our new avatar skill
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8765);
      print('AgentSkillServer listening on 127.0.0.1:8765');

      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      });
    } catch (e) {
      print('AgentSkillServer failed to start: $e');
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
    } else if (request.method == 'POST' && path == '/api/avatar/equip') {
      await _handleAvatarEquip(request);
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

  void _handleBattery(HttpRequest request) {
    // Stub for now, returning a mock 85% charging for the battery.md skill
    _sendJson(request, {
      'level': 85,
      'isCharging': true,
    });
  }

  void _handleToolsCatalog(HttpRequest request) {
    final catalog = SkillsService().getToolsCatalog();
    _sendJson(request, {'tools': catalog});
  }

  void _handleSkillsList(HttpRequest request) {
    final skills = SkillsService().getSkillsList();
    final jsonList = skills.map((s) => s.toJson()).toList();
    _sendJson(request, {'skills': jsonList});
  }

  Future<void> _handleAvatarEquip(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      final vrmId = data['vrm_id'] as String?;
      if (vrmId == null || vrmId.isEmpty) {
        return _sendError(request, 'Missing vrm_id');
      }

      // Ensure the avatar has .vrm extension
      final avatarFileName = vrmId.endsWith('.vrm') ? vrmId : '$vrmId.vrm';

      // Update the global preference for the avatar
      final prefs = PreferencesService();
      await prefs.init();
      prefs.selectedAvatar = avatarFileName;

      _sendJson(request, {
        'success': true,
        'message': 'Equipped $avatarFileName successfully',
      });
    } catch (e) {
      _sendError(request, e.toString());
    }
  }

  Future<void> _handleTwilio(HttpRequest request) async {
    final method = request.uri.path == '/twilio/webhook' ? 'get_status' : 'get_status';
    final result = await SkillsService().executeSkill('twilio_voice', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleAgentCard(HttpRequest request) async {
    final method = request.uri.path == '/cards/create' ? 'create_card' : 'get_balance';
    final result = await SkillsService().executeSkill('agent_card', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleMoltLaunch(HttpRequest request) async {
    final method = request.uri.path == '/marketplace/identity' ? 'register' : 'get_rep';
    final result = await SkillsService().executeSkill('molt_launch', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  Future<void> _handleValeo(HttpRequest request) async {
    final method = request.uri.path == '/sentinel/audit' ? 'get_audit' : 'get_budget';
    final result = await SkillsService().executeSkill('valeo_sentinel', parameters: {'method': method});
    _sendSkillResult(request, result);
  }

  void _sendSkillResult(HttpRequest request, SkillResult result) {
    if (result.success) {
      _sendJson(request, result.data as Map<String, dynamic>);
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

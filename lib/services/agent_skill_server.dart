import 'dart:convert';
import 'dart:io';
import 'preferences_service.dart';

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
    } else if (request.method == 'POST' && path == '/api/avatar/equip') {
      await _handleAvatarEquip(request);
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

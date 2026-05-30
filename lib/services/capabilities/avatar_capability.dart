import 'dart:async';

import '../../models/node_frame.dart';
import '../agent_skill_server.dart';
import '../avatar_gesture_catalog.dart';
import '../preferences_service.dart';
import 'capability_handler.dart';

class AvatarCapability extends CapabilityHandler {
  @override
  String get name => 'avatar';

  @override
  List<String> get commands => ['gesture', 'mode', 'model', 'status'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    switch (command) {
      case 'avatar.gesture':
        return _gesture(params);
      case 'avatar.mode':
        return _mode(params);
      case 'avatar.model':
        return _model(params);
      case 'avatar.status':
        return _status();
      default:
        return NodeFrame.response('', error: {
          'code': 'UNKNOWN_COMMAND',
          'message': 'Unknown avatar command: $command',
        });
    }
  }

  Future<NodeFrame> _gesture(Map<String, dynamic> params) async {
    final rawGesture = params['gesture'] ??
        params['name'] ??
        params['value'] ??
        params['text'];
    if (rawGesture == null || rawGesture.toString().trim().isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'avatar.gesture requires a gesture name.',
      });
    }
    final gesture = AvatarGestureCatalog.normalize(rawGesture);

    final requestCallback = AgentSkillServer.instance.onAvatarGestureRequested;
    final legacyCallback = AgentSkillServer.instance.onGesturePlayed;
    if (requestCallback == null && legacyCallback == null) {
      return NodeFrame.response('', error: {
        'code': 'AVATAR_NOT_READY',
        'message': 'Avatar UI is not ready. Open the Chat screen and retry.',
      });
    }

    if (requestCallback != null) {
      try {
        var durationMs =
            _intParam(params, ['durationMs', 'duration_ms', 'duration']);
        if (durationMs == null && gesture.toLowerCase().contains('dance')) {
          durationMs = 60000;
        } else if (durationMs == null && _isSittingGesture(gesture)) {
          durationMs = 30000;
        }
        final interrupt = _boolParam(params, ['interrupt']) ??
            (_isSittingGesture(gesture) ? true : null);
        final result = await requestCallback({
          'gesture': gesture,
          if (durationMs != null) 'durationMs': durationMs,
          if (interrupt != null) 'interrupt': interrupt,
          if (params['protectedGesture'] == true) 'protectedGesture': true,
          if (params['source'] != null) 'source': params['source'].toString(),
          if (params['canaryMode'] != null)
            'canaryMode': params['canaryMode'].toString(),
        }).timeout(const Duration(seconds: 9));
        return NodeFrame.response('', payload: {
          'status': result['status'] ?? 'queued',
          'gesture': result['gesture'] ?? gesture,
          ...result,
        });
      } on TimeoutException {
        return NodeFrame.response('', payload: {
          'status': 'queued',
          'gesture': gesture,
          'reason': 'Avatar renderer did not confirm start before timeout.',
        });
      }
    }

    legacyCallback?.call(gesture);
    return NodeFrame.response('', payload: {
      'status': 'queued',
      'gesture': gesture,
      'reason': 'Legacy avatar gesture callback was used.',
    });
  }

  bool _isSittingGesture(String gesture) {
    final lower = gesture.toLowerCase();
    return lower.contains('sit') || lower.contains('seated');
  }

  int? _intParam(Map<String, dynamic> params, List<String> keys) {
    for (final key in keys) {
      final value = params[key];
      if (value == null) continue;
      if (value is int) return value;
      if (value is num) return value.round();
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool? _boolParam(Map<String, dynamic> params, List<String> keys) {
    for (final key in keys) {
      final value = params[key];
      if (value == null) continue;
      if (value is bool) return value;
      final lower = value.toString().trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return null;
  }

  Future<NodeFrame> _mode(Map<String, dynamic> params) async {
    final mode = (params['mode'] ?? params['name'] ?? params['value'])
        ?.toString()
        .trim()
        .toLowerCase();
    const validModes = {'normal', 'expressive', 'dance', 'subtle'};
    if (mode == null || mode.isEmpty || !validModes.contains(mode)) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_PARAM',
        'message': 'avatar.mode requires one of: ${validModes.join(", ")}.',
      });
    }

    final callback = AgentSkillServer.instance.onGestureModeChanged;
    if (callback == null) {
      return NodeFrame.response('', error: {
        'code': 'AVATAR_NOT_READY',
        'message': 'Avatar UI is not ready. Open the Chat screen and retry.',
      });
    }

    callback(mode);
    return NodeFrame.response('', payload: {
      'status': 'set',
      'mode': mode,
    });
  }

  Future<NodeFrame> _model(Map<String, dynamic> params) async {
    final raw = (params['model'] ?? params['avatar'] ?? params['name'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_PARAM',
        'message': 'avatar.model requires a model filename.',
      });
    }

    final filename = raw.endsWith('.vrm') ? raw : '$raw.vrm';
    final prefs = PreferencesService();
    await prefs.init();
    prefs.selectedAvatar = filename;
    AgentSkillServer.instance.onAvatarChanged?.call(filename);
    return NodeFrame.response('', payload: {
      'status': 'set',
      'model': filename,
    });
  }

  Future<NodeFrame> _status() async {
    final prefs = PreferencesService();
    await prefs.init();
    return NodeFrame.response('', payload: {
      'avatar': prefs.selectedAvatar,
      'uiReady': AgentSkillServer.instance.onGesturePlayed != null,
    });
  }
}

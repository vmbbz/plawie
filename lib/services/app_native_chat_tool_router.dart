import 'dart:convert';

import '../models/node_frame.dart';
import 'avatar_gesture_catalog.dart';
import 'capabilities/avatar_capability.dart';
import 'capabilities/blog_watcher_capability.dart';
import 'capabilities/camera_capability.dart';
import 'capabilities/clawhub_capability.dart';
import 'capabilities/device_capability.dart';
import 'capabilities/discord_capability.dart';
import 'capabilities/flash_capability.dart';
import 'capabilities/github_capability.dart';
import 'capabilities/gifgrep_capability.dart';
import 'capabilities/goplaces_capability.dart';
import 'capabilities/location_capability.dart';
import 'capabilities/meme_maker_capability.dart';
import 'capabilities/mcporter_capability.dart';
import 'capabilities/nano_pdf_capability.dart';
import 'capabilities/notion_capability.dart';
import 'capabilities/sensor_capability.dart';
import 'capabilities/session_logs_capability.dart';
import 'capabilities/slack_capability.dart';
import 'capabilities/summarize_capability.dart';
import 'capabilities/trello_capability.dart';
import 'capabilities/vibration_capability.dart';
import 'capabilities/weather_capability.dart';
import 'capabilities/xurl_capability.dart';
import 'skills_service.dart';

class AppNativeChatToolExecution {
  final String toolName;
  final Map<String, dynamic> input;
  final Map<String, dynamic> result;
  final bool ok;
  final String visibleText;

  const AppNativeChatToolExecution({
    required this.toolName,
    required this.input,
    required this.result,
    required this.ok,
    required this.visibleText,
  });

  String get toolUseChunk => '\x00TOOL_USE:$toolName:${jsonEncode(input)}\x00';

  String get toolResultChunk =>
      '\x00TOOL_RESULT:$toolName:${jsonEncode(result)}\x00';
}

class _AppNativeToolPlan {
  final String toolName;
  final String command;
  final Map<String, dynamic> input;

  const _AppNativeToolPlan({
    required this.toolName,
    required this.command,
    required this.input,
  });
}

class AppNativeChatToolRouter {
  static final AppNativeChatToolRouter instance =
      AppNativeChatToolRouter._internal();

  AppNativeChatToolRouter._internal({
    BlogWatcherCapability? blogWatcher,
    DiscordCapability? discord,
    GitHubCapability? github,
    GifgrepCapability? gifgrep,
    GoPlacesCapability? goplaces,
    McPorterCapability? mcporter,
    NotionCapability? notion,
    SessionLogsCapability? sessionLogs,
    SlackCapability? slack,
    TrelloCapability? trello,
    XurlCapability? xurl,
  })  : _blogWatcher = blogWatcher ?? BlogWatcherCapability(),
        _discord = discord ?? DiscordCapability(),
        _github = github ?? GitHubCapability(),
        _gifgrep = gifgrep ?? GifgrepCapability(),
        _goplaces = goplaces ?? GoPlacesCapability(),
        _mcporter = mcporter ?? McPorterCapability(),
        _notion = notion ?? NotionCapability(),
        _sessionLogs = sessionLogs ?? SessionLogsCapability(),
        _slack = slack ?? SlackCapability(),
        _trello = trello ?? TrelloCapability(),
        _xurl = xurl ?? XurlCapability();

  factory AppNativeChatToolRouter.forTesting({
    BlogWatcherCapability? blogWatcher,
    DiscordCapability? discord,
    GitHubCapability? github,
    GifgrepCapability? gifgrep,
    GoPlacesCapability? goplaces,
    McPorterCapability? mcporter,
    NotionCapability? notion,
    SessionLogsCapability? sessionLogs,
    SlackCapability? slack,
    TrelloCapability? trello,
    XurlCapability? xurl,
  }) =>
      AppNativeChatToolRouter._internal(
        blogWatcher: blogWatcher,
        discord: discord,
        github: github,
        gifgrep: gifgrep,
        goplaces: goplaces,
        mcporter: mcporter,
        notion: notion,
        sessionLogs: sessionLogs,
        slack: slack,
        trello: trello,
        xurl: xurl,
      );

  final AvatarCapability _avatar = AvatarCapability();
  final BlogWatcherCapability _blogWatcher;
  final CameraCapability _camera = CameraCapability();
  final ClawHubCapability _clawHub = ClawHubCapability();
  final DeviceCapability _device = DeviceCapability();
  final DiscordCapability _discord;
  final FlashCapability _flash = FlashCapability();
  final GitHubCapability _github;
  final GifgrepCapability _gifgrep;
  final GoPlacesCapability _goplaces;
  final LocationCapability _location = LocationCapability();
  final MemeMakerCapability _memeMaker = MemeMakerCapability();
  final McPorterCapability _mcporter;
  final NanoPdfCapability _nanoPdf = NanoPdfCapability();
  final NotionCapability _notion;
  final SensorCapability _sensor = SensorCapability();
  final SessionLogsCapability _sessionLogs;
  final SlackCapability _slack;
  final SummarizeCapability _summarize = SummarizeCapability();
  final TrelloCapability _trello;
  final VibrationCapability _vibration = VibrationCapability();
  final WeatherCapability _weather = WeatherCapability();
  final XurlCapability _xurl;

  int? parseDurationMsForTesting(
    String text, {
    int minMs = 50,
    int maxMs = 5000,
  }) =>
      _durationMs(text.toLowerCase(), minMs: minMs, maxMs: maxMs);

  List<Map<String, dynamic>>? parseAvatarSequenceForTesting(String text) =>
      _avatarSequence(text.toLowerCase());

  String? requiredToolCommandForTesting(String message) {
    final plan = _requiredToolPlan(message);
    return plan?.command;
  }

  Map<String, dynamic>? requiredGatewayNodeTarget(String message) {
    final plan = _requiredToolPlan(message);
    if (plan == null) return null;
    final input = _gatewayNodeInput(plan);
    return {
      'tool': 'nodes',
      'appNativeToolName': plan.toolName,
      'command': plan.command,
      'nodesInput': input,
    };
  }

  Future<AppNativeChatToolExecution?> tryExecute(
    String message, {
    required bool directGatewayRegistrationAvailable,
    bool forceLocalFallback = false,
  }) async {
    if (directGatewayRegistrationAvailable && !forceLocalFallback) return null;
    final plan = _plan(message);
    if (plan == null) return null;

    final result = await _execute(plan);
    final ok = _resultOk(plan, result);
    return AppNativeChatToolExecution(
      toolName: plan.toolName,
      input: plan.input,
      result: result,
      ok: ok,
      visibleText: _visibleText(plan, result, ok),
    );
  }

  Future<AppNativeChatToolExecution?> tryExecuteRequiredToolIntent(
    String message,
  ) async {
    final plan = _requiredToolPlan(message);
    if (plan == null) return null;

    final result = await _execute(plan);
    final ok = _resultOk(plan, result);
    return AppNativeChatToolExecution(
      toolName: plan.toolName,
      input: plan.input,
      result: result,
      ok: ok,
      visibleText: _visibleText(plan, result, ok),
    );
  }

  _AppNativeToolPlan? _requiredToolPlan(String message) {
    final plan = _plan(message);
    if (plan == null || !_isRequiredMobileCommand(plan)) return null;
    final input = <String, dynamic>{
      ...plan.input,
      'source': 'gateway-required-tool-intent',
    };
    return _AppNativeToolPlan(
      toolName: plan.toolName,
      command: plan.command,
      input: input,
    );
  }

  bool _isRequiredMobileCommand(_AppNativeToolPlan plan) {
    return switch (plan.command) {
      'avatar.gesture' ||
      'avatar.sequence' ||
      'blogwatcher.check' ||
      'discord.me' ||
      'slack.me' ||
      'slack.post' ||
      'haptic.vibrate' ||
      'flash.on' ||
      'flash.off' ||
      'flash.toggle' ||
      'flash.status' ||
      'camera.snap' ||
      'camera.list' ||
      'location.get' ||
      'device.health' ||
      'device.status' ||
      'device.info' ||
      'device.permissions' ||
      'sensor.list' ||
      'sensor.read' ||
      'weather.current' ||
      'weather.forecast' ||
      'clawhub.search' ||
      'clawhub.info' ||
      'github.user' ||
      'gh-issues.list' ||
      'goplaces.search' ||
      'gifgrep.status' ||
      'gifgrep.search' ||
      'gifgrep.still' ||
      'gifgrep.sheet' ||
      'mcporter.health' ||
      'notion.search' ||
      'meme-maker.create' ||
      'nano-pdf.extract' ||
      'session-logs.query' ||
      'summarize.text' ||
      'trello.boards' ||
      'xurl.request' =>
        true,
      _ => false,
    };
  }

  Map<String, dynamic> _gatewayNodeInput(_AppNativeToolPlan plan) {
    switch (plan.command) {
      case 'camera.snap':
        return {
          'action': 'camera_snap',
          'facing': plan.input['facing'] ?? 'back',
          'quality': 85,
        };
      case 'camera.list':
        return const {'action': 'camera_list'};
      case 'location.get':
        return const {'action': 'location_get'};
      case 'device.health':
        return const {'action': 'device_health'};
      case 'device.status':
      case 'device.info':
        return const {'action': 'device_status'};
      case 'device.permissions':
        return const {'action': 'device_permissions'};
      case 'sensor.list':
        return const {'action': 'invoke', 'invokeCommand': 'sensor.list'};
      case 'sensor.read':
        return {
          'action': 'invoke',
          'invokeCommand': 'sensor.read',
          'invokeParamsJson': jsonEncode({
            'sensor': plan.input['sensor_type'] ?? 'accelerometer',
          }),
        };
      case 'haptic.vibrate':
        return {
          'action': 'invoke',
          'invokeCommand': 'haptic.vibrate',
          'invokeParamsJson': jsonEncode({
            'durationMs': plan.input['durationMs'] ?? 220,
          }),
        };
      case 'weather.current':
      case 'weather.forecast':
      case 'blogwatcher.check':
      case 'discord.me':
      case 'github.user':
      case 'gh-issues.list':
      case 'goplaces.search':
      case 'gifgrep.status':
      case 'gifgrep.search':
      case 'gifgrep.still':
      case 'gifgrep.sheet':
      case 'notion.search':
      case 'nano-pdf.extract':
      case 'session-logs.query':
      case 'summarize.text':
      case 'trello.boards':
      case 'xurl.request':
        return {
          'action': 'invoke',
          'invokeCommand': plan.command,
          'invokeParamsJson': jsonEncode(plan.input),
        };
      case 'flash.on':
      case 'flash.off':
      case 'flash.toggle':
      case 'flash.status':
        return {
          'action': 'invoke',
          'invokeCommand': plan.command,
        };
      case 'avatar.gesture':
        final params = Map<String, dynamic>.from(plan.input)
          ..remove('action')
          ..remove('source');
        return {
          'action': 'invoke',
          'invokeCommand': 'avatar.gesture',
          'invokeParamsJson': jsonEncode(params),
        };
      case 'avatar.sequence':
        return {
          'action': 'invoke',
          'invokeCommand': 'avatar.sequence',
          'invokeParamsJson': jsonEncode({
            'interruptCurrent': plan.input['interruptCurrent'] ?? true,
            'steps': plan.input['steps'] ?? const [],
          }),
        };
      default:
        return {
          'action': 'invoke',
          'invokeCommand': plan.command,
          if (plan.input.isNotEmpty) 'invokeParamsJson': jsonEncode(plan.input),
        };
    }
  }

  _AppNativeToolPlan? _plan(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (_isToolInventoryQuestion(lower) || _explicitlyDisablesTools(lower)) {
      return null;
    }

    final tts = _ttsText(trimmed);
    if (tts != null) {
      return _AppNativeToolPlan(
        toolName: 'tts-voice',
        command: 'speak',
        input: {'action': 'speak', 'text': tts},
      );
    }

    final sequence = _avatarSequence(lower);
    if (sequence != null) {
      return _AppNativeToolPlan(
        toolName: 'avatar-control',
        command: 'avatar.sequence',
        input: {
          'action': 'play_sequence',
          'interruptCurrent': true,
          'source': 'app-native-chat-router',
          'steps': sequence,
        },
      );
    }

    final gesture = _gestureName(lower);
    if (gesture != null) {
      final resolved = AvatarGestureCatalog.resolve(gesture);
      final durationMs = _durationMs(lower, minMs: 250, maxMs: 120000);
      return _AppNativeToolPlan(
        toolName: 'avatar-control',
        command: 'avatar.gesture',
        input: {
          'action': 'play_gesture',
          'gesture': resolved.gesture,
          'assetPath': resolved.assetPath,
          'source': 'app-native-chat-router',
          'interrupt': true,
          if (durationMs != null) 'durationMs': durationMs,
        },
      );
    }

    if (_containsAny(lower, const ['vibrate', 'buzz', 'haptic'])) {
      final durationMs = _durationMs(lower) ?? 220;
      return _AppNativeToolPlan(
        toolName: 'device-node',
        command: 'haptic.vibrate',
        input: {'action': 'vibrate', 'durationMs': durationMs},
      );
    }

    if (_containsAny(lower, const ['flashlight', 'torch', 'flash light'])) {
      final action = lower.contains('off')
          ? 'flashlight_off'
          : lower.contains('status') || lower.contains('state')
              ? 'flashlight_status'
              : lower.contains('toggle') || lower.contains('switch')
                  ? 'flashlight_toggle'
                  : lower.contains('on')
                      ? 'flashlight_on'
                      : null;
      if (action != null) {
        final command = switch (action) {
          'flashlight_on' => 'flash.on',
          'flashlight_off' => 'flash.off',
          'flashlight_toggle' => 'flash.toggle',
          _ => 'flash.status',
        };
        return _AppNativeToolPlan(
          toolName: 'device-node',
          command: command,
          input: {'action': action},
        );
      }
    }

    if (lower.contains('battery') &&
        _containsAny(lower, const [
          'level',
          'percent',
          'percentage',
          'status',
          'how much',
          'what is',
          'check',
          'get',
        ])) {
      return const _AppNativeToolPlan(
        toolName: 'device-node',
        command: 'battery.status',
        input: {'action': 'get_battery'},
      );
    }

    final sensor = _sensorName(lower);
    if (sensor != null) {
      return _AppNativeToolPlan(
        toolName: 'device-node',
        command: sensor == 'list' ? 'sensor.list' : 'sensor.read',
        input: sensor == 'list'
            ? {'action': 'read_sensor', 'sensor_type': 'list'}
            : {'action': 'read_sensor', 'sensor_type': sensor},
      );
    }

    if (_wantsCamera(lower)) {
      final facing = _containsAny(lower, const ['selfie', 'front camera'])
          ? 'front'
          : 'back';
      final explicitCamsnap = RegExp(r'\bcamsnap\b').hasMatch(lower);
      return _AppNativeToolPlan(
        toolName: explicitCamsnap ? 'camsnap' : 'device-node',
        command: lower.contains('list') ? 'camera.list' : 'camera.snap',
        input: lower.contains('list')
            ? {'action': 'camera_list'}
            : {
                'action': explicitCamsnap ? 'camera_snap' : 'take_photo',
                'facing': facing,
              },
      );
    }

    if (_wantsLocation(lower)) {
      return const _AppNativeToolPlan(
        toolName: 'device-node',
        command: 'location.get',
        input: {'action': 'get_location'},
      );
    }

    if (_wantsDeviceHealth(lower)) {
      return const _AppNativeToolPlan(
        toolName: 'device-node',
        command: 'device.health',
        input: {'action': 'device_health'},
      );
    }

    final weatherLocation = _weatherLocation(trimmed);
    if (weatherLocation != null) {
      final forecast = lower.contains('forecast') ||
          lower.contains('tomorrow') ||
          lower.contains('next few days');
      return _AppNativeToolPlan(
        toolName: 'weather',
        command: forecast ? 'weather.forecast' : 'weather.current',
        input: {
          'city': weatherLocation,
          'source': 'app-native-chat-router',
          if (forecast) 'days': 3,
        },
      );
    }

    final gifgrepPlan = _gifgrepPlan(trimmed);
    if (gifgrepPlan != null) return gifgrepPlan;

    final blogWatcherPlan = _blogWatcherPlan(trimmed);
    if (blogWatcherPlan != null) return blogWatcherPlan;

    final discordPlan = _discordPlan(trimmed);
    if (discordPlan != null) return discordPlan;

    final slackPlan = _slackPlan(trimmed);
    if (slackPlan != null) return slackPlan;

    final githubPlan = _githubPlan(trimmed);
    if (githubPlan != null) return githubPlan;

    final goplacesPlan = _goplacesPlan(trimmed);
    if (goplacesPlan != null) return goplacesPlan;

    final mcporterPlan = _mcporterPlan(trimmed);
    if (mcporterPlan != null) return mcporterPlan;

    final notionPlan = _notionPlan(trimmed);
    if (notionPlan != null) return notionPlan;

    final trelloPlan = _trelloPlan(trimmed);
    if (trelloPlan != null) return trelloPlan;

    final sessionLogsPlan = _sessionLogsPlan(trimmed);
    if (sessionLogsPlan != null) return sessionLogsPlan;

    final nanoPdfPlan = _nanoPdfPlan(trimmed);
    if (nanoPdfPlan != null) return nanoPdfPlan;

    final xurlPlan = _xurlPlan(trimmed);
    if (xurlPlan != null) return xurlPlan;

    final summarizePlan = _summarizePlan(trimmed);
    if (summarizePlan != null) return summarizePlan;

    final clawHubPlan = _clawHubPlan(trimmed);
    if (clawHubPlan != null) return clawHubPlan;

    final memePlan = _memePlan(trimmed);
    if (memePlan != null) return memePlan;

    if (lower.contains('device') && lower.contains('permission')) {
      return const _AppNativeToolPlan(
        toolName: 'device-node',
        command: 'device.permissions',
        input: {'action': 'device_permissions'},
      );
    }

    if (lower.contains('device') &&
        _containsAny(lower, const ['status', 'info', 'state'])) {
      return const _AppNativeToolPlan(
        toolName: 'device-node',
        command: 'device.status',
        input: {'action': 'device_status'},
      );
    }

    final bundledSkillPlan = _bundledSkillPlan(lower);
    if (bundledSkillPlan != null) return bundledSkillPlan;

    return null;
  }

  Future<Map<String, dynamic>> _execute(_AppNativeToolPlan plan) async {
    try {
      switch (plan.command) {
        case 'avatar.gesture':
          return _skillResultToMap(await SkillsService().executeSkill(
            'avatar-control',
            parameters: plan.input,
          ));
        case 'avatar.sequence':
          return _frameToMap(await _avatar.handle(
            'avatar.sequence',
            plan.input,
          ));
        case 'haptic.vibrate':
          final frame = await _vibration.handle(
            'haptic.vibrate',
            {'durationMs': plan.input['durationMs'] ?? 220},
          );
          return _frameToMap(frame);
        case 'flash.on':
        case 'flash.off':
        case 'flash.toggle':
        case 'flash.status':
          final frame = await _flash.handleWithPermission(
            plan.command,
            const {},
          );
          return _frameToMap(frame);
        case 'battery.status':
          return _skillResultToMap(await SkillsService().executeSkill(
            'device-node',
            parameters: const {'action': 'get_battery'},
          ));
        case 'sensor.list':
          return _frameToMap(await _sensor.handleWithPermission(
            'sensor.list',
            const {},
          ));
        case 'sensor.read':
          return _frameToMap(await _sensor.handleWithPermission(
            'sensor.read',
            {'sensor': plan.input['sensor_type'] ?? 'accelerometer'},
          ));
        case 'weather.current':
        case 'weather.forecast':
          return _frameToMap(await _weather.handle(
            plan.command,
            plan.input,
          ));
        case 'blogwatcher.check':
          return _frameToMap(await _blogWatcher.handle(
            plan.command,
            plan.input,
          ));
        case 'discord.me':
          return _frameToMap(await _discord.handle(
            plan.command,
            plan.input,
          ));
        case 'slack.me':
        case 'slack.post':
          return _frameToMap(await _slack.handle(
            plan.command,
            plan.input,
          ));
        case 'github.user':
        case 'gh-issues.list':
          return _frameToMap(await _github.handle(
            plan.command,
            plan.input,
          ));
        case 'goplaces.search':
          return _frameToMap(await _goplaces.handle(
            plan.command,
            plan.input,
          ));
        case 'gifgrep.status':
        case 'gifgrep.search':
        case 'gifgrep.still':
        case 'gifgrep.sheet':
          return _frameToMap(await _gifgrep.handle(
            plan.command,
            plan.input,
          ));
        case 'mcporter.health':
          return _frameToMap(await _mcporter.handle(
            plan.command,
            plan.input,
          ));
        case 'notion.search':
          return _frameToMap(await _notion.handle(
            plan.command,
            plan.input,
          ));
        case 'session-logs.query':
          return _frameToMap(await _sessionLogs.handle(
            plan.command,
            plan.input,
          ));
        case 'clawhub.search':
        case 'clawhub.info':
          return _frameToMap(await _clawHub.handle(
            plan.command,
            plan.input,
          ));
        case 'meme-maker.create':
          return _frameToMap(await _memeMaker.handle(
            plan.command,
            plan.input,
          ));
        case 'nano-pdf.extract':
          return _frameToMap(await _nanoPdf.handle(
            plan.command,
            plan.input,
          ));
        case 'summarize.text':
          return _frameToMap(await _summarize.handle(
            plan.command,
            plan.input,
          ));
        case 'trello.boards':
          return _frameToMap(await _trello.handle(
            plan.command,
            plan.input,
          ));
        case 'xurl.request':
          return _frameToMap(await _xurl.handle(
            plan.command,
            plan.input,
          ));
        case 'camera.list':
          return _frameToMap(await _camera.handleWithPermission(
            'camera.list',
            const {},
          ));
        case 'camera.snap':
          final frame = await _camera.handleWithPermission(
            'camera.snap',
            {'facing': plan.input['facing'] ?? 'back'},
          );
          return _frameToMap(frame);
        case 'location.get':
          return _frameToMap(await _location.handleWithPermission(
            'location.get',
            const {},
          ));
        case 'device.status':
        case 'device.info':
        case 'device.permissions':
        case 'device.health':
          return _frameToMap(await _device.handle(
            plan.command,
            const {},
          ));
        case 'speak':
          return _skillResultToMap(await SkillsService().executeSkill(
            'tts-voice',
            parameters: plan.input,
          ));
        default:
          if (SkillsService().getSkill(plan.toolName) != null) {
            return _skillResultToMap(await SkillsService().executeSkill(
              plan.toolName,
              parameters: plan.input,
            ));
          }
          return {
            'ok': false,
            'error': {
              'code': 'UNKNOWN_APP_NATIVE_PLAN',
              'message': 'No app-native executor for ${plan.command}.',
            },
          };
      }
    } catch (e) {
      return {
        'ok': false,
        'error': {'code': 'APP_NATIVE_TOOL_ERROR', 'message': '$e'},
      };
    }
  }

  Map<String, dynamic> _frameToMap(NodeFrame frame) {
    if (frame.isError) {
      return {
        'ok': false,
        'error': frame.error ?? {'message': 'Unknown capability error'},
      };
    }
    final payload = Map<String, dynamic>.from(frame.payload ?? const {});
    final sanitized = _sanitizePayload(payload);
    return {'ok': true, ...sanitized};
  }

  Map<String, dynamic> _skillResultToMap(SkillResult result) {
    if (!result.success) {
      return {
        'ok': false,
        'error': {'message': result.error ?? 'Unknown skill error'},
      };
    }
    if (result.data is Map) {
      final payload = Map<String, dynamic>.from(result.data as Map);
      final payloadOk = payload['ok'] != false && payload['success'] != false;
      return {
        ...payload,
        'ok': payloadOk,
      };
    }
    return {'ok': true, 'result': result.data};
  }

  bool _resultOk(_AppNativeToolPlan plan, Map<String, dynamic> result) {
    final transportOk = result['ok'] == true || result['success'] == true;
    if (plan.command != 'avatar.gesture' && plan.command != 'avatar.sequence') {
      return transportOk;
    }
    final status = result['status']?.toString().toLowerCase();
    return transportOk && (status == 'started' || status == 'completed');
  }

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final copy = Map<String, dynamic>.from(payload);
    final b64 = copy.remove('base64')?.toString();
    if (b64 != null && b64.isNotEmpty) {
      copy['base64Bytes'] = b64.length;
      copy['base64Omitted'] = true;
    }
    return copy;
  }

  String _visibleText(
    _AppNativeToolPlan plan,
    Map<String, dynamic> result,
    bool ok,
  ) {
    if (plan.command == 'avatar.gesture' || plan.command == 'avatar.sequence') {
      return _avatarGestureVisibleText(plan, result, ok);
    }
    if (!ok) {
      final message = _errorMessageFromResult(result);
      return 'I tried to use ${plan.toolName}, but it failed: $message';
    }
    switch (plan.command) {
      case 'haptic.vibrate':
        return 'Done. I used device-node to vibrate the phone.';
      case 'flash.on':
        return 'Done. I turned the flashlight on.';
      case 'flash.off':
        return 'Done. I turned the flashlight off.';
      case 'flash.toggle':
        return 'Done. I toggled the flashlight.';
      case 'flash.status':
        return 'Flashlight status: ${result['on'] == true ? 'on' : 'off'}.';
      case 'battery.status':
        final level = result['level'];
        final charging =
            result['isCharging'] == true ? 'charging' : 'not charging';
        return 'Battery is ${level ?? 'unknown'}% and $charging.';
      case 'sensor.list':
        return 'Sensor list retrieved.';
      case 'sensor.read':
        return 'Sensor reading retrieved: ${_compactJson(result)}';
      case 'weather.current':
      case 'weather.forecast':
        return result['summary']?.toString().trim().isNotEmpty == true
            ? 'Weather: ${result['summary']}.'
            : 'Weather retrieved.';
      case 'blogwatcher.check':
        final count = result['itemCount'] ?? 0;
        final title = result['feedTitle']?.toString().trim();
        return 'Blogwatcher checked${title?.isNotEmpty == true ? ' $title' : ''}: $count item(s).';
      case 'discord.me':
        final username = result['username']?.toString().trim();
        return username?.isNotEmpty == true
            ? 'Discord bot status retrieved for $username.'
            : 'Discord bot status retrieved.';
      case 'slack.me':
        final team = result['team']?.toString().trim();
        final user = result['user']?.toString().trim();
        if (team?.isNotEmpty == true && user?.isNotEmpty == true) {
          return 'Slack bot status retrieved for $user in $team.';
        }
        return 'Slack bot status retrieved.';
      case 'slack.post':
        final channel = result['channel']?.toString().trim();
        return channel?.isNotEmpty == true
            ? 'Slack message posted to $channel.'
            : 'Slack message posted.';
      case 'github.user':
        final login = result['login']?.toString().trim();
        return login?.isNotEmpty == true
            ? 'GitHub profile retrieved for $login.'
            : 'GitHub profile retrieved.';
      case 'gh-issues.list':
        final repository = result['repository']?.toString().trim();
        final count = result['count'] ?? 0;
        return 'GitHub issues retrieved${repository?.isNotEmpty == true ? ' for $repository' : ''}: $count item(s).';
      case 'goplaces.search':
        final query = result['query']?.toString().trim();
        final count = result['count'] ?? 0;
        return 'Google Places search${query?.isNotEmpty == true ? ' for $query' : ''}: $count place(s).';
      case 'gifgrep.status':
        return 'gifgrep is installed and ready (${result['version'] ?? 'version available'}).';
      case 'gifgrep.search':
        return 'gifgrep found ${result['count'] ?? 0} result(s) for ${result['query'] ?? plan.input['query']}.';
      case 'gifgrep.still':
      case 'gifgrep.sheet':
        return 'gifgrep created ${result['outputPath'] ?? 'a PNG output'}.';
      case 'mcporter.health':
        final status = result['status']?.toString().trim();
        return status?.isNotEmpty == true
            ? 'MCPorter status: $status.'
            : 'MCPorter health retrieved.';
      case 'notion.search':
        final query = result['query']?.toString().trim();
        final count = result['count'] ?? 0;
        return 'Notion search${query?.isNotEmpty == true ? ' for $query' : ''}: $count result(s).';
      case 'session-logs.query':
        final action = result['action']?.toString();
        return switch (action) {
          'read' =>
            'Session logs read ${result['returnedMessageCount'] ?? 0} message(s).',
          'search' =>
            'Session logs found ${result['matchCount'] ?? 0} match(es).',
          _ =>
            'Session logs listed ${result['returnedSessionCount'] ?? 0} session(s).',
        };
      case 'clawhub.search':
        final count = result['count'];
        return 'ClawHub search retrieved${count == null ? '' : ' $count result(s)'}.';
      case 'clawhub.info':
        final skill = result['skill'];
        if (skill is Map) {
          final name = skill['name'] ?? skill['slug'] ?? 'skill';
          return 'ClawHub metadata retrieved for $name.';
        }
        return 'ClawHub metadata retrieved.';
      case 'meme-maker.create':
        final bytes = result['pngBytes'];
        return 'Meme image generated${bytes == null ? '' : ' ($bytes bytes)'}.';
      case 'nano-pdf.extract':
        return 'nano-pdf extracted ${result['chars'] ?? 0} character(s) from the PDF text layer.';
      case 'summarize.text':
        final summary = result['summary']?.toString().trim();
        return summary?.isNotEmpty == true
            ? 'Summary: $summary'
            : 'Summary generated.';
      case 'trello.boards':
        final count = result['count'] ?? 0;
        return 'Trello board summary retrieved: $count board(s).';
      case 'xurl.request':
        final statusCode = result['statusCode'] ?? 'unknown';
        final method = result['method'] ?? plan.input['method'] ?? 'GET';
        final bytes = result['bytes'];
        return 'xurl $method ${plan.input['url']} -> HTTP $statusCode${bytes == null ? '' : ' ($bytes bytes)'}.';
      case 'camera.list':
        return 'Camera list retrieved.';
      case 'camera.snap':
        return 'Done. I took a photo and attached it to this reply.';
      case 'location.get':
        return _locationVisibleText(result);
      case 'device.health':
        return _deviceHealthVisibleText(result);
      case 'device.status':
      case 'device.info':
        return 'Device status retrieved.';
      case 'device.permissions':
        return 'Device permissions retrieved.';
      case 'avatar.gesture':
        return 'Done. I triggered the ${plan.input['gesture']} avatar gesture.';
      case 'avatar.sequence':
        return 'Done. I started the avatar sequence.';
      case 'speak':
        return 'Done. I spoke the requested text.';
      default:
        if (result['status'] == 'CONFIG_REQUIRED') {
          final actionRequired = result['actionRequired']?.toString().trim();
          final message = result['message']?.toString().trim();
          return '${_skillLabel(plan.toolName)} is installed, but not configured yet. ${actionRequired?.isNotEmpty == true ? actionRequired : message ?? ''}'
              .trim();
        }
        if (result['status'] == 'WALLET_NOT_CONNECTED') {
          final message = result['message']?.toString().trim();
          return message?.isNotEmpty == true
              ? message!
              : 'Base wallet is not connected.';
        }
        return 'Done. I used ${plan.toolName}.';
    }
  }

  String _avatarGestureVisibleText(
    _AppNativeToolPlan plan,
    Map<String, dynamic> result,
    bool ok,
  ) {
    final gesture =
        (result['gesture'] ?? plan.input['gesture'] ?? 'sequence').toString();
    final status = result['status']?.toString().toLowerCase() ?? '';
    if (plan.command == 'avatar.sequence') {
      final count =
          result['stepCount'] ?? (plan.input['steps'] as List?)?.length;
      if (ok) {
        return 'Done. I started the avatar sequence${count == null ? '' : ' ($count steps)'}.';
      }
      return 'I tried to start the avatar sequence, but it failed: ${_errorMessageFromResult(result)}';
    }
    if (ok) {
      return 'Done. I started the $gesture avatar gesture.';
    }
    if (status == 'queued') {
      return 'I sent the $gesture avatar gesture, but the renderer has not confirmed playback yet.';
    }
    if (status == 'skipped') {
      return 'I skipped the $gesture avatar gesture: ${_errorMessageFromResult(result)}';
    }
    return 'I tried to play the $gesture avatar gesture, but it failed: ${_errorMessageFromResult(result)}';
  }

  String _errorMessageFromResult(Map<String, dynamic> result) {
    final error = result['error'];
    if (error is Map) return error['message']?.toString() ?? error.toString();
    final direct = error?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final key in const ['reason', 'message', 'status']) {
      final value = result[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Unknown error';
  }

  String _locationVisibleText(Map<String, dynamic> result) {
    final lat = result['lat'];
    final lng = result['lng'];
    final accuracy = result['accuracy'];
    final address = _addressText(result);
    final coordinates = lat != null && lng != null ? '$lat, $lng' : null;
    if (address != null && coordinates != null) {
      final accuracyText = accuracy == null ? '' : ' (accuracy ~$accuracy m)';
      return 'Current location: $address. Coordinates: $coordinates$accuracyText.';
    }
    if (coordinates != null) {
      final accuracyText = accuracy == null ? '' : ' (accuracy ~$accuracy m)';
      return 'Current location retrieved: $coordinates$accuracyText.';
    }
    return 'Location retrieved.';
  }

  String? _addressText(Map<String, dynamic> result) {
    final direct = result['address']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final parts = <String>[];
    for (final key in const [
      'street',
      'subLocality',
      'locality',
      'city',
      'administrativeArea',
      'country',
    ]) {
      final value = result[key]?.toString().trim();
      if (value != null && value.isNotEmpty && !parts.contains(value)) {
        parts.add(value);
      }
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  String _deviceHealthVisibleText(Map<String, dynamic> result) {
    final nativeCount = result['nativeSkillCount'];
    final prootCount = result['prootSkillCount'];
    final gateCount = result['skillGateCount'];
    final readiness = result['skillReadiness'];
    final permissions = result['permissions'];
    final parts = <String>['Device health check completed'];
    if (nativeCount != null) parts.add('native skills: $nativeCount');
    if (prootCount != null) parts.add('PRoot skills: $prootCount');
    if (gateCount != null) parts.add('skill gates: $gateCount');
    if (readiness is Map && readiness.isNotEmpty) {
      parts.add(
          'readiness: ${_compactJson(Map<String, dynamic>.from(readiness))}');
    }
    if (permissions is Map && permissions.isNotEmpty) {
      final camera = permissions['camera'];
      final location = permissions['location'];
      final microphone = permissions['microphone'];
      parts.add(
          'permissions: camera=$camera, location=$location, microphone=$microphone');
    }
    return '${parts.join('; ')}.';
  }

  String _compactJson(Map<String, dynamic> value) {
    final encoded = jsonEncode(_sanitizePayload(value));
    return encoded.length <= 180 ? encoded : '${encoded.substring(0, 177)}...';
  }

  bool _isToolInventoryQuestion(String lower) {
    return RegExp(
      r'\b(what|which|list|show|tell me)\b.{0,24}\b(tools|skills|abilities|capabilities)\b',
    ).hasMatch(lower);
  }

  bool _explicitlyDisablesTools(String lower) {
    return lower.contains('do not use tools') ||
        lower.contains("don't use tools") ||
        lower.contains('without using tools') ||
        lower.contains('no tools');
  }

  bool _containsAny(String lower, List<String> values) {
    return values.any(lower.contains);
  }

  int? _durationMs(
    String lower, {
    int minMs = 50,
    int maxMs = 5000,
  }) {
    final match = RegExp(
            r'\b(\d{1,4})\s*(ms|millisecond|milliseconds|s|sec|secs|second|seconds|m|min|mins|minute|minutes)\b')
        .firstMatch(lower);
    if (match == null) return null;
    final amount = int.tryParse(match.group(1) ?? '');
    if (amount == null) return null;
    final unit = match.group(2) ?? 'ms';
    final isMinuteUnit = unit == 'm' ||
        unit == 'min' ||
        unit == 'mins' ||
        unit.startsWith('minute');
    final ms = isMinuteUnit
        ? amount * 60000
        : unit.startsWith('s')
            ? amount * 1000
            : amount;
    return ms.clamp(minMs, maxMs).toInt();
  }

  String? _gestureName(String lower) {
    final gestureIntent = _containsAny(lower, const [
      'avatar',
      'gesture',
      'wave',
      'dance',
      'bow',
      'spin',
      'sit',
      'sitting',
      'pose',
      'peacesign',
      'peace sign',
      'squat',
      'fight',
    ]);
    if (!gestureIntent) return null;
    if (_containsAny(
        lower, const ['what gesture', 'which gesture', 'list gesture'])) {
      return null;
    }

    final bowMatch = RegExp(r'\bbow(?:ing)?\s*(0?[1-5])\b').firstMatch(lower);
    if (bowMatch != null) {
      return 'bowing ${int.parse(bowMatch.group(1)!)}';
    }

    final candidates = AvatarGestureCatalog.toolGestureNames.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final candidate in candidates) {
      final c = candidate.toLowerCase();
      if (RegExp('(^|[^a-z0-9])${RegExp.escape(c)}([^a-z0-9]|\$)')
          .hasMatch(lower)) {
        return AvatarGestureCatalog.normalize(candidate);
      }
    }
    if (lower.contains('wave')) return 'wave right';
    if (lower.contains('dance')) return 'dance';
    if (lower.contains('bow')) return 'bowing 1';
    if (lower.contains('spin')) return 'spin';
    if (lower.contains('sit')) return 'sitting';
    if (lower.contains('pose')) return 'pose';
    return null;
  }

  List<Map<String, dynamic>>? _avatarSequence(String lower) {
    final normalized = lower
        .replaceAll(RegExp(r'\bafter that\b|\bafterwards\b|\bafter,\b'), 'then')
        .replaceAll(RegExp(r'\band then\b'), 'then');
    if (!RegExp(r'\b(then|next)\b').hasMatch(normalized)) return null;
    final parts = normalized
        .split(RegExp(r'\b(?:then|next)\b'))
        .map((part) => part.trim().replaceAll(RegExp(r'^[,.;:\s]+'), ''))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) return null;

    final steps = <Map<String, dynamic>>[];
    for (final part in parts) {
      final gesture = _gestureName(part);
      if (gesture == null) continue;
      final resolved = AvatarGestureCatalog.resolve(gesture);
      final durationMs = _durationMs(part, minMs: 250, maxMs: 120000);
      steps.add({
        'gesture': resolved.gesture,
        'assetPath': resolved.assetPath,
        'source': 'app-native-chat-router',
        if (durationMs != null) 'durationMs': durationMs,
      });
    }
    return steps.length >= 2 ? steps : null;
  }

  String? _sensorName(String lower) {
    if (lower.contains('sensor') && lower.contains('list')) return 'list';
    for (final name in const [
      'accelerometer',
      'gyroscope',
      'gyro',
      'magnetometer',
      'barometer',
    ]) {
      if (lower.contains(name)) {
        return name == 'gyro' ? 'gyroscope' : name;
      }
    }
    if (lower.contains('sensor') &&
        _containsAny(lower, const ['read', 'get', 'check'])) {
      return 'accelerometer';
    }
    return null;
  }

  bool _wantsCamera(String lower) {
    if (!_containsAny(lower, const [
      'camsnap',
      'camera',
      'photo',
      'picture',
      'selfie',
      'snapshot'
    ])) {
      return false;
    }
    if (_containsAny(
        lower, const ['do you have', 'can you use', 'available'])) {
      return false;
    }
    return _containsAny(
        lower, const ['take', 'snap', 'capture', 'shoot', 'list', 'show']);
  }

  bool _wantsLocation(String lower) {
    return lower.contains('where am i') ||
        lower.contains('where are we') ||
        lower.contains('where we are') ||
        lower.contains('current location') ||
        lower.contains('my location') ||
        lower.contains('gps location') ||
        (lower.contains('location') &&
            _containsAny(lower, const ['get', 'check', 'tell me']));
  }

  bool _wantsDeviceHealth(String lower) {
    return lower.contains('healthcheck') ||
        lower.contains('health check') ||
        lower.contains('device health') ||
        lower.contains('phone health') ||
        lower.contains('health status') ||
        lower.contains('system health') ||
        lower.contains('diagnostic') ||
        lower.contains('diagnostics');
  }

  String? _weatherLocation(String message) {
    final lower = message.toLowerCase();
    if (!_containsAny(lower, const ['weather', 'forecast'])) return null;

    final patterns = [
      RegExp(
        r'\b(?:weather|forecast)\s+(?:in|for|at|near)\s+([a-z0-9 .,\-]{2,70})',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:in|for|at|near)\s+([a-z0-9 .,\-]{2,70})\s+(?:weather|forecast)\b',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      final cleaned = _cleanWeatherLocation(match?.group(1));
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  String? _cleanWeatherLocation(String? value) {
    if (value == null) return null;
    var cleaned = value
        .replaceAll(RegExp(r'[?.!]+$'), '')
        .replaceAll(
          RegExp(
            r'\b(today|now|currently|please|thanks|thank you|tomorrow|this week|next few days)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    cleaned = cleaned.replaceAll(RegExp(r'[,.\-\s]+$'), '').trim();
    if (cleaned.length < 2) return null;
    return cleaned;
  }

  _AppNativeToolPlan? _xurlPlan(String message) {
    final lower = message.toLowerCase();
    if (!RegExp(r'\bxurl\b').hasMatch(lower)) return null;
    final match = RegExp(
      r'\bxurl\b\s+(?:(GET|HEAD|POST)\s+)?(\S+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;

    final method = (match.group(1) ?? 'GET').toUpperCase();
    final rawUrl = match.group(2);
    final url = _cleanXurlUrl(rawUrl);
    if (url == null) return null;
    final body = _xurlBody(message.substring(match.end));

    return _AppNativeToolPlan(
      toolName: 'xurl',
      command: 'xurl.request',
      input: {
        'url': url,
        'method': method,
        'source': 'app-native-chat-router',
        if (body != null) 'body': body,
      },
    );
  }

  _AppNativeToolPlan? _blogWatcherPlan(String message) {
    final match = RegExp(
      r'^\s*blogwatcher\s*:?\s+(\S+)',
      caseSensitive: false,
    ).firstMatch(message);
    final url = _cleanXurlUrl(match?.group(1));
    if (url == null) return null;
    final limitMatch = RegExp(
      r'\blimit\s+(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(message);
    final limit = int.tryParse(limitMatch?.group(1) ?? '');
    return _AppNativeToolPlan(
      toolName: 'blogwatcher',
      command: 'blogwatcher.check',
      input: {
        'url': url,
        'source': 'app-native-chat-router',
        if (limit != null) 'limit': limit,
      },
    );
  }

  _AppNativeToolPlan? _discordPlan(String message) {
    final match = RegExp(
      r'^\s*discord(?:\s+(?:bot\s+)?(?:status|me|user))?\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;
    return const _AppNativeToolPlan(
      toolName: 'discord',
      command: 'discord.me',
      input: {
        'action': 'me',
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _slackPlan(String message) {
    final postMatch = RegExp(
      r'^\s*slack\s+(?:post|send|message)\s+(?:(#[A-Za-z0-9._-]+|[CDG][A-Za-z0-9]+)\s*:?\s+)?(.+?)\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (postMatch != null) {
      final channel = postMatch.group(1)?.trim();
      final text = (postMatch.group(2) ?? '').trim();
      if (text.isEmpty) return null;
      return _AppNativeToolPlan(
        toolName: 'slack',
        command: 'slack.post',
        input: {
          'action': 'post',
          'text': text,
          if (channel != null && channel.isNotEmpty) 'channel': channel,
          'source': 'app-native-chat-router',
        },
      );
    }

    final statusMatch = RegExp(
      r'^\s*slack(?:\s+(?:bot\s+)?(?:status|me|user))?\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (statusMatch == null) return null;
    return const _AppNativeToolPlan(
      toolName: 'slack',
      command: 'slack.me',
      input: {
        'action': 'me',
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _githubPlan(String message) {
    final userMatch = RegExp(
      r'^\s*github\s+(?:user|me|profile|whoami)\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (userMatch != null) {
      return const _AppNativeToolPlan(
        toolName: 'github',
        command: 'github.user',
        input: {
          'action': 'user',
          'source': 'app-native-chat-router',
        },
      );
    }

    final issuesMatch = RegExp(
      r'^\s*(?:gh[-\s]?issues|github\s+issues)\s+([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)(?:\s+(open|closed|all))?(?:\s+limit\s+(\d{1,2}))?\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (issuesMatch == null) return null;
    final owner = issuesMatch.group(1);
    final repo = issuesMatch.group(2);
    if (owner == null || repo == null) return null;
    return _AppNativeToolPlan(
      toolName: 'gh-issues',
      command: 'gh-issues.list',
      input: {
        'owner': owner,
        'repo': repo,
        if (issuesMatch.group(3) != null) 'state': issuesMatch.group(3),
        if (issuesMatch.group(4) != null)
          'limit': int.tryParse(issuesMatch.group(4)!),
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _goplacesPlan(String message) {
    final match = RegExp(
      r'^\s*(?:goplaces|google\s+places|places)\s*:?\s+(.+?)\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;
    var query = (match.group(1) ?? '').trim();
    final limitMatch = RegExp(
      r'\blimit\s+(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(query);
    final limit = int.tryParse(limitMatch?.group(1) ?? '');
    query = query
        .replaceFirst(
          RegExp(r'\blimit\s+\d{1,2}\b', caseSensitive: false),
          '',
        )
        .trim();
    if (query.isEmpty) return null;
    return _AppNativeToolPlan(
      toolName: 'goplaces',
      command: 'goplaces.search',
      input: {
        'query': query,
        if (limit != null) 'limit': limit,
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _mcporterPlan(String message) {
    final match = RegExp(
      r'^\s*mcporter(?:\s+(?:health|status))?\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;
    return const _AppNativeToolPlan(
      toolName: 'mcporter',
      command: 'mcporter.health',
      input: {
        'action': 'health',
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _notionPlan(String message) {
    final match = RegExp(
      r'^\s*notion(?:\s+search)?\s*:?\s+(.+?)\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;
    var query = (match.group(1) ?? '').trim();
    final limitMatch = RegExp(
      r'\blimit\s+(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(query);
    final limit = int.tryParse(limitMatch?.group(1) ?? '');
    final objectMatch = RegExp(
      r'\b(?:object|type)\s+(page|pages|data[-\s_]?source|database|databases)\b',
      caseSensitive: false,
    ).firstMatch(query);
    final object = objectMatch?.group(1);
    query = query
        .replaceFirst(
          RegExp(r'\blimit\s+\d{1,2}\b', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(
            r'\b(?:object|type)\s+(?:page|pages|data[-\s_]?source|database|databases)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (query.isEmpty) return null;
    return _AppNativeToolPlan(
      toolName: 'notion',
      command: 'notion.search',
      input: {
        'query': query,
        if (object != null) 'object': object,
        if (limit != null) 'limit': limit,
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _trelloPlan(String message) {
    final match = RegExp(
      r'^\s*trello(?:\s+(?:boards|summary))?(?:\s+limit\s+(\d{1,2}))?\s*$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;
    final limit = int.tryParse(match.group(1) ?? '');
    return _AppNativeToolPlan(
      toolName: 'trello',
      command: 'trello.boards',
      input: {
        'action': 'boards',
        if (limit != null) 'limit': limit,
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _sessionLogsPlan(String message) {
    final match = RegExp(
      r'^\s*session[-\s]logs\s*:?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) return null;
    final body = (match.group(1) ?? '').trim();
    final lowerBody = body.toLowerCase();
    final limitMatch = RegExp(
      r'\blimit\s+(\d{1,3})\b',
      caseSensitive: false,
    ).firstMatch(body);
    final limit = int.tryParse(limitMatch?.group(1) ?? '');
    final input = <String, dynamic>{
      'action': 'list',
      'source': 'app-native-chat-router',
      if (limit != null) 'limit': limit,
    };

    if (lowerBody.startsWith('search ')) {
      final query = body
          .substring('search'.length)
          .replaceFirst(
              RegExp(r'\blimit\s+\d{1,3}\b', caseSensitive: false), '')
          .trim();
      if (query.isEmpty) return null;
      input['action'] = 'search';
      input['query'] = query;
    } else if (lowerBody.startsWith('read') ||
        lowerBody.startsWith('show') ||
        lowerBody.startsWith('active')) {
      input['action'] = 'read';
      final idMatch = RegExp(
        r'\b(?:id|session)\s+([A-Za-z0-9._:-]+)\b',
        caseSensitive: false,
      ).firstMatch(body);
      final sessionId = idMatch?.group(1);
      if (sessionId != null && sessionId.isNotEmpty) {
        input['sessionId'] = sessionId;
      }
    }

    return _AppNativeToolPlan(
      toolName: 'session-logs',
      command: 'session-logs.query',
      input: input,
    );
  }

  _AppNativeToolPlan? _nanoPdfPlan(String message) {
    final match = RegExp(
      r'^\s*nano[-\s]pdf\s+(?:base64\s+)?(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(message);
    final pdfBase64 = match?.group(1)?.trim();
    if (pdfBase64 == null || pdfBase64.isEmpty) return null;
    if (pdfBase64.length > 70000) return null;
    return _AppNativeToolPlan(
      toolName: 'nano-pdf',
      command: 'nano-pdf.extract',
      input: {
        'pdfBase64': pdfBase64,
        'source': 'app-native-chat-router',
      },
    );
  }

  _AppNativeToolPlan? _summarizePlan(String message) {
    final match = RegExp(
      r'^\s*summarize(?:\s+(?:this|text))?\s*[:\-]\s*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(message);
    final text = match?.group(1)?.trim();
    if (text == null || text.isEmpty) return null;
    return _AppNativeToolPlan(
      toolName: 'summarize',
      command: 'summarize.text',
      input: {
        'text': text,
        'source': 'app-native-chat-router',
      },
    );
  }

  String? _cleanXurlUrl(String? value) {
    if (value == null) return null;
    var cleaned = value.trim();
    while (cleaned.isNotEmpty && _isLeadingXurlTrimChar(cleaned[0])) {
      cleaned = cleaned.substring(1);
    }
    while (cleaned.isNotEmpty &&
        _isTrailingXurlTrimChar(cleaned[cleaned.length - 1])) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isEmpty) return null;
    return cleaned;
  }

  bool _isLeadingXurlTrimChar(String char) =>
      char == '<' || char == '(' || char == '"' || char == "'";

  bool _isTrailingXurlTrimChar(String char) =>
      char == '>' ||
      char == ')' ||
      char == '"' ||
      char == "'" ||
      char == ',' ||
      char == '.';

  String? _xurlBody(String trailing) {
    final match = RegExp(
      r'\bbody\s*=\s*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(trailing);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    if ((raw.startsWith('"') && raw.endsWith('"')) ||
        (raw.startsWith("'") && raw.endsWith("'"))) {
      return raw.substring(1, raw.length - 1);
    }
    return raw;
  }

  _AppNativeToolPlan? _clawHubPlan(String message) {
    final lower = message.toLowerCase();
    if (!_containsAny(lower, const ['clawhub', 'skill registry'])) {
      return null;
    }
    final infoMatch = RegExp(
      r'\b(?:info|details|metadata)\s+(?:for|about)?\s*([a-z0-9._-]{2,80})',
      caseSensitive: false,
    ).firstMatch(message);
    final searchMatch = RegExp(
      r'\b(?:search|find)\s+(?:clawhub\s+)?(?:for\s+)?([a-z0-9 ._-]{2,80})',
      caseSensitive: false,
    ).firstMatch(message);
    final explicitSlug = infoMatch?.group(1)?.trim();
    if (explicitSlug != null && explicitSlug.isNotEmpty) {
      return _AppNativeToolPlan(
        toolName: 'clawhub',
        command: 'clawhub.info',
        input: {
          'slug': explicitSlug,
          'source': 'app-native-chat-router',
        },
      );
    }
    final query = _cleanWeatherLocation(searchMatch?.group(1));
    if (query != null) {
      return _AppNativeToolPlan(
        toolName: 'clawhub',
        command: 'clawhub.search',
        input: {
          'query': query,
          'source': 'app-native-chat-router',
        },
      );
    }
    return null;
  }

  _AppNativeToolPlan? _memePlan(String message) {
    final lower = message.toLowerCase();
    if (!lower.contains('meme')) return null;
    final top = _quotedOrTrailing(
      message,
      RegExp(r'\btop(?:\s+text)?\s*[:=]\s*"?([^"\n]+)"?', caseSensitive: false),
    );
    final bottom = _quotedOrTrailing(
      message,
      RegExp(r'\bbottom(?:\s+text)?\s*[:=]\s*"?([^"\n]+)"?',
          caseSensitive: false),
    );
    final fallback = message
        .replaceAll(
            RegExp(r'\b(make|create|generate|a|an|the)\b',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'\bmeme\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if ((top == null || top.isEmpty) &&
        (bottom == null || bottom.isEmpty) &&
        fallback.length < 2) {
      return null;
    }
    return _AppNativeToolPlan(
      toolName: 'meme-maker',
      command: 'meme-maker.create',
      input: {
        'source': 'app-native-chat-router',
        if (top != null && top.isNotEmpty) 'topText': top,
        'bottomText': bottom?.isNotEmpty == true ? bottom : fallback,
      },
    );
  }

  _AppNativeToolPlan? _gifgrepPlan(String message) {
    final lower = message.toLowerCase();
    if (!RegExp(r'\bgifgrep\b').hasMatch(lower)) return null;

    final localAction = lower.contains(RegExp(r'\bstill\b'))
        ? 'still'
        : lower.contains(RegExp(r'\bsheet\b'))
            ? 'sheet'
            : null;
    if (localAction != null) {
      final quotedPath =
          RegExp(r'''["']([^"']+\.gif)["']''', caseSensitive: false)
              .firstMatch(message)
              ?.group(1);
      final plainPath = RegExp(
        r'''((?:~?/|/)[^\s"'<>]+\.gif)''',
        caseSensitive: false,
      ).firstMatch(message)?.group(1);
      final inputPath = (quotedPath ?? plainPath)?.trim();
      if (inputPath == null || inputPath.isEmpty) {
        return _AppNativeToolPlan(
          toolName: 'gifgrep',
          command: 'gifgrep.$localAction',
          input: const {},
        );
      }
      return _AppNativeToolPlan(
        toolName: 'gifgrep',
        command: 'gifgrep.$localAction',
        input: {
          'inputPath': inputPath,
          'source': 'app-native-chat-router',
        },
      );
    }

    final statusIntent = _containsAny(lower, const [
      'installed',
      'installation',
      'dependency',
      'dependencies',
      'ready',
      'status',
      'version',
      'available',
    ]);
    if (statusIntent &&
        !_containsAny(lower, const ['search', 'find', 'look for'])) {
      return const _AppNativeToolPlan(
        toolName: 'gifgrep',
        command: 'gifgrep.status',
        input: {'source': 'app-native-chat-router'},
      );
    }

    var query = RegExp(
          r'\b(?:search(?:\s+for)?|find|look\s+for)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(message)?.group(1) ??
        message;
    query = query
        .replaceAll(
          RegExp(
            r'\b(?:using|with)\s+(?:the\s+)?gifgrep(?:\s+skill)?\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\bgifgrep\b', caseSensitive: false), ' ')
        .replaceAll(
            RegExp(r'\b(?:use|run|skill|please|me)\b', caseSensitive: false),
            ' ')
        .replaceAll(
            RegExp(r'\b(?:a|some)\s+gifs?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bgifs?\b$', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[?.!]+$'), '')
        .trim();
    query = query
        .replaceFirst(RegExp(r'^(?:a|an|some)\s+', caseSensitive: false), '')
        .trim();
    return _AppNativeToolPlan(
      toolName: 'gifgrep',
      command: query.isEmpty ? 'gifgrep.status' : 'gifgrep.search',
      input: {
        if (query.isNotEmpty) 'query': query,
        'max': 5,
        'source': 'auto',
      },
    );
  }

  String? _quotedOrTrailing(String message, RegExp pattern) {
    final match = pattern.firstMatch(message);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.replaceAll(RegExp(r'[?.!]+$'), '').trim();
  }

  _AppNativeToolPlan? _bundledSkillPlan(String lower) {
    if (_containsAny(lower, const [
      'avatar overlay',
      'avatar_overlay',
      'picture in picture',
      'pip mode',
      'floating avatar',
    ])) {
      return const _AppNativeToolPlan(
        toolName: 'avatar_overlay',
        command: 'avatar_overlay.enter',
        input: {},
      );
    }

    if (_containsAny(lower, const [
      'twilio',
      'conversationrelay',
      'conversation relay',
      'agent calls',
      'voice calls',
    ])) {
      final method = lower.contains('transcription')
          ? 'set_transcription'
          : lower.contains('relay')
              ? 'set_relay'
              : 'get_status';
      return _AppNativeToolPlan(
        toolName: 'twilio-voice',
        command: 'twilio-voice.$method',
        input: {
          'method': method,
          if (method != 'get_status') 'enabled': _enabledIntent(lower),
        },
      );
    }

    if (_containsAny(lower, const [
      'agentcard',
      'agent card',
      'agent-card',
      'virtual card',
      'card balance',
      'spend limit',
    ])) {
      final method =
          lower.contains('refill') ? 'set_refill_policy' : 'get_balance';
      return _AppNativeToolPlan(
        toolName: 'agent-card',
        command: 'agent-card.$method',
        input: {
          'method': method,
          if (method != 'get_balance') 'enabled': _enabledIntent(lower),
        },
      );
    }

    if (_containsAny(lower, const [
      'moltlaunch',
      'molt launch',
      'molt-launch',
      'agent work',
      'work skill',
      'job marketplace',
    ])) {
      final method = lower.contains('register')
          ? 'register'
          : _containsAny(lower, const ['rep', 'reputation', 'jobs', 'payout'])
              ? 'get_rep'
              : 'get_identity';
      return _AppNativeToolPlan(
        toolName: 'molt-launch',
        command: 'molt-launch.$method',
        input: {'method': method},
      );
    }

    if (_containsAny(lower, const [
      'valeo',
      'sentinel',
      'valeo-sentinel',
      'valeo sentinel',
      'x402',
      'budget policy',
      'spending policy',
    ])) {
      final method = lower.contains('audit')
          ? 'get_audit'
          : _containsAny(lower, const ['enable', 'disable', 'active', 'policy'])
              ? 'set_policy'
              : 'get_budget';
      return _AppNativeToolPlan(
        toolName: 'valeo-sentinel',
        command: 'valeo-sentinel.$method',
        input: {
          'method': method,
          if (method == 'set_policy') 'active': _enabledIntent(lower),
        },
      );
    }

    if (_containsAny(lower, const [
      'moonpay',
      'moon pay',
      'crypto portfolio',
      'dca strategy',
      'dca strategies',
    ])) {
      final method = lower.contains('price')
          ? 'get_price'
          : lower.contains('dca')
              ? 'dca_list'
              : lower.contains('swap')
                  ? 'swap'
                  : lower.contains('bridge')
                      ? 'bridge'
                      : lower.contains('buy')
                          ? 'buy'
                          : lower.contains('sell')
                              ? 'sell'
                              : 'get_portfolio';
      return _AppNativeToolPlan(
        toolName: 'moonpay',
        command: 'moonpay.$method',
        input: {
          'method': method,
          if (method == 'get_price') 'tokens': _cryptoTokens(lower),
        },
      );
    }

    if (_containsAny(lower, const [
      'base-chain',
      'base chain',
      'base wallet',
      'base balance',
      'usdc balance',
      'eth balance',
      'wallet address',
    ])) {
      final action = lower.contains('history')
          ? 'get_history'
          : lower.contains('address')
              ? 'get_address'
              : lower.contains('sepolia') || lower.contains('mainnet')
                  ? 'switch_network'
                  : 'get_balance';
      return _AppNativeToolPlan(
        toolName: 'base-chain',
        command: 'base-chain.$action',
        input: {
          'action': action,
          if (action == 'switch_network')
            'network': lower.contains('sepolia') ? 'sepolia' : 'mainnet',
        },
      );
    }

    return null;
  }

  bool _enabledIntent(String lower) {
    if (_containsAny(lower, const ['disable', 'off', 'pause', 'stop'])) {
      return false;
    }
    return true;
  }

  List<String> _cryptoTokens(String lower) {
    final tokens = <String>[];
    for (final token in const ['BTC', 'ETH', 'SOL', 'USDC', 'BASE']) {
      if (lower.contains(token.toLowerCase())) tokens.add(token);
    }
    return tokens.isEmpty ? const ['ETH', 'BTC', 'SOL', 'USDC'] : tokens;
  }

  String _skillLabel(String skillId) {
    return switch (skillId) {
      'avatar_overlay' => 'Avatar Overlay',
      'twilio-voice' => 'Twilio Voice',
      'agent-card' => 'AgentCard',
      'molt-launch' => 'MoltLaunch',
      'valeo-sentinel' => 'Valeo Sentinel',
      'moonpay' => 'MoonPay',
      'base-chain' => 'Base Chain',
      _ => skillId,
    };
  }

  String? _ttsText(String text) {
    final lower = text.toLowerCase();
    if (!_containsAny(
        lower, const ['speak aloud', 'say aloud', 'read aloud', 'tts'])) {
      return null;
    }
    final quoted = RegExp(r'["“](.+?)["”]').firstMatch(text)?.group(1);
    if (quoted != null && quoted.trim().isNotEmpty) return quoted.trim();
    final match = RegExp(
      r'\b(?:speak aloud|say aloud|read aloud|tts)\b[:,]?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.length > 400 ? value.substring(0, 400) : value;
  }
}

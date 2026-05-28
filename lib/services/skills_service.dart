import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';
import 'gateway_skill_proxy.dart';
import 'base_service.dart';
import 'gateway_service.dart';
import 'avatar_gesture_catalog.dart';
import '../constants/openclaw_paths.dart';

/// Skills System — Thin UI + Native Bridge architecture.
/// This service acts as the UI manager and execution router for on-device native skills,
/// while delegating heavy lifting (marketplace, YAML, workspace) to the OpenClaw PRoot CLI.
class SkillsService {
  static final SkillsService _instance = SkillsService._internal();
  factory SkillsService() => _instance;
  SkillsService._internal();

  final Logger _logger = Logger();
  final Map<String, Skill> _skills = {};
  final StreamController<SkillsEvent> _eventController =
      StreamController.broadcast();
  final PreferencesService _prefs = PreferencesService();

  Stream<SkillsEvent> get events => _eventController.stream;
  Map<String, Skill> get skills => Map.unmodifiable(_skills);

  Future<void> initialize() async {
    try {
      _logger.i('Initializing Skills System (Simplified)...');

      await _prefs.init();

      // Load bundled native skills (superpowers)
      _loadBundledNativeSkills();

      // Startup MUST be read-mostly and deterministic.
      // Running `skills update --all` / `chat new-session` on boot mutates
      // skills/plugins config and can trigger gateway hot-reload churn.
      // We only do lightweight native registration here.
      await _registerNativeSkills();

      _logger
          .i('Skills System initialized with ${_skills.length} native skills');
    } catch (e) {
      _logger.e('Failed to initialize Skills System: $e');
    }
  }

  /// One-source-of-truth awareness: updates PRoot workspace and refreshes agent session.
  Future<void> ensureAgentAwareness({bool fullSync = false}) async {
    _logger.i('Ensuring agent awareness of skills...');
    // Only run workspace-mutating commands when explicitly requested
    // (e.g. after install/uninstall from the Skills UI).
    if (fullSync) {
      await _runSkillCommandBestEffort(
        'refresh tracked workspace skills',
        '$kOpenClawCommand skills update --all',
        timeout: 120,
      );

      await _runSkillCommandBestEffort(
        'start a fresh agent session',
        '$kOpenClawCommand chat new-session --silent',
        timeout: 30,
      );
    }

    // Push native capabilities to the gateway WebSocket even if CLI refreshes
    // were unavailable; bundled hardware skills are synced by BootstrapManager.
    await _registerNativeSkills();
    _logger.i('Agent awareness synchronized.');
  }

  Future<void> _runSkillCommandBestEffort(
    String description,
    String command, {
    int timeout = 60,
  }) async {
    try {
      await NativeBridge.runInProot(command, timeout: timeout);
    } catch (e) {
      _logger.w('Could not $description: $e');
    }
  }

  void _loadBundledNativeSkills() {
    final bundled = [
      _createAvatarControlSkill(),
      _createTtsVoiceSkill(),
      _createDeviceNodeSkill(),
      _createAvatarOverlaySkill(),
      _createBaseChainSkill(),
      // Partner proxies
      _createTwilioSkill(),
      _createAgentCardSkill(),
      _createMoltLaunchSkill(),
      _createValeoSkill(),
      _createMoonPaySkill(),
    ];
    for (final s in bundled) {
      _skills[s.id] = s;
    }
  }

  /// Execute a skill — routing to either native code, local HTTP server, or Gateway proxy.
  Future<SkillResult> executeSkill(
    String skillId, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? context,
  }) async {
    final skill = _skills[skillId];
    if (skill == null) return SkillResult.error('Skill not found: $skillId');
    if (!skill.enabled) return SkillResult.error('Skill is disabled: $skillId');

    try {
      _eventController.add(SkillsEvent.skillExecuting(skillId));
      final result =
          await _executeSkillLogic(skill, parameters ?? {}, context ?? {});
      _eventController.add(SkillsEvent.skillExecuted(skillId, result));
      return result;
    } catch (e) {
      _logger.e('Execution failed: $e');
      _eventController.add(SkillsEvent.skillError(skillId, e.toString()));
      return SkillResult.error(e.toString());
    }
  }

  Future<SkillResult> _executeSkillLogic(Skill skill,
      Map<String, dynamic> params, Map<String, dynamic> ctx) async {
    switch (skill.category) {
      case 'avatar':
        return await _executeAvatarControlSkill(skill, params, ctx);
      case 'tts':
        return await _executeTtsVoiceSkill(skill, params, ctx);
      case 'device':
        return await _executeDeviceNodeSkill(skill, params, ctx);
      case 'system':
        return await _executeAvatarPipSkill(skill, params, ctx);
      case 'base':
        return await _executeBaseChainSkill(skill, params, ctx);
      case 'twilio':
        return await _executeTwilioSkill(skill, params, ctx);
      case 'agentcard':
        return await _executeAgentCardSkill(skill, params, ctx);
      case 'moltlaunch':
        return await _executeMoltLaunchSkill(skill, params, ctx);
      case 'valeo':
        return await _executeValeoSkill(skill, params, ctx);
      case 'moonpay':
        return await _executeMoonPaySkill(skill, params, ctx);
      default:
        return SkillResult.error('No executor for category: ${skill.category}');
    }
  }

  /// Installs a skill via the OpenClaw CLI and triggers a forensic awareness sync.
  Future<bool> installSkill(String id, {bool silent = false}) async {
    try {
      if (!silent) _broadcast(SkillsEvent.skillInstalling(id));

      final result =
          await NativeBridge.runInProot('$kOpenClawCommand skills install $id');

      if (result.contains('Error')) {
        throw Exception(result);
      }

      await ensureAgentAwareness(fullSync: true);

      if (!silent) _broadcast(SkillsEvent.skillInstalled(id));
      return true;
    } catch (e) {
      if (!silent) _broadcast(SkillsEvent.skillError(id, e.toString()));
      return false;
    }
  }

  /// Uninstalls a skill via the OpenClaw CLI and triggers a forensic awareness sync.
  Future<bool> uninstallSkill(String id, {bool silent = false}) async {
    try {
      final result = await NativeBridge.runInProot(
          '$kOpenClawCommand skills uninstall $id');

      if (result.contains('Error')) {
        throw Exception(result);
      }

      await ensureAgentAwareness(fullSync: true);

      if (!silent) _broadcast(SkillsEvent.skillUninstalled(id));
      return true;
    } catch (e) {
      if (!silent) _broadcast(SkillsEvent.skillError(id, e.toString()));
      return false;
    }
  }

  void _broadcast(SkillsEvent event) => _eventController.add(event);

  /// Fetch full skill details (YAML info) from the PRoot workspace.
  Future<Map<String, dynamic>?> getSkillDetails(String id) async {
    try {
      final output = await NativeBridge.runInProot(
          '$kOpenClawCommand skills info $id --json');
      if (output.trim().isEmpty) return null;
      return jsonDecode(output) as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Failed to fetch details for $id: $e');
      return null;
    }
  }

  /// Fetches an "Epic" skill profile, trying local SKILL.md first (Bootstrap-backed)
  /// before falling back to the CLI info.
  Future<Map<String, dynamic>> getSkillProfile(String id) async {
    // 1. Try local SKILL.md (Forensic sync guaranteed by BootstrapManager.kt)
    final profile = await _readLocalSkillProfile(id);
    if (profile != null) return profile;

    // 2. Fallback: ClawHub lookup via CLI
    try {
      final result = await NativeBridge.runInProot(
          '$kOpenClawCommand skills info $id --json');
      final decoded = json.decode(result) as Map<String, dynamic>;
      return {
        ...decoded,
        'verified': decoded['source'] == 'official',
        'iconUrl': decoded['icon'] ?? decoded['image_url'],
        'tools': decoded['capabilities'] as List? ??
            ['Autonomous Execution', 'Agent Logic Integration'],
        'examples': decoded['examples'] ??
            'Try: "Hey Plawie, use ${decoded['name'] ?? id}"',
      };
    } catch (_) {
      return {
        'id': id,
        'name': id.toUpperCase(),
        'description': 'A community skill from the ClawHub marketplace.',
        'verified': false,
        'tools': ['Plugin Capabilities'],
        'examples': 'Say "Plawie, activate $id"',
      };
    }
  }

  Future<Map<String, dynamic>?> _readLocalSkillProfile(String id) async {
    try {
      // BootstrapManager copies SKILL.md to /root/.openclaw/skills/[id]/SKILL.md
      final content = await NativeBridge.runInProot(
          'cat /root/.openclaw/skills/$id/SKILL.md 2>/dev/null');
      if (content.trim().isEmpty) return null;

      return {
        'id': id,
        'name': id.replaceAll('-', ' ').toUpperCase(),
        'description': content,
        'verified': true,
        'tools': [
          'Native Hardware Access',
          'Low-latency Execution',
          'Offline Capability'
        ],
        'examples': 'Say "Plawie, trigger $id"',
      };
    } catch (_) {
      return null;
    }
  }

  // ── Mappings and Executors (Kept for runtime functionality) ───────────────

  Future<SkillResult> _executeAvatarControlSkill(Skill skill,
      Map<String, dynamic> params, Map<String, dynamic> ctx) async {
    final body = Map<String, dynamic>.from(params);
    String action = params['action'] ?? 'get_status';

    if (action == 'play_gesture' || action == 'play_vrma') {
      String? raw = params['gesture'] ??
          params['animation'] ??
          params['value'] ??
          params['text'];
      if (raw != null) {
        final base = AvatarGestureCatalog.fullBodyPathForText(raw);
        final layers = AvatarGestureCatalog.limbPathsForText(raw);
        body['action'] = 'play_vrma_composite';
        body['base'] = base;
        body['layers'] = layers;
        body['blendTime'] = 0.4;
        action = 'play_vrma_composite';
        _eventController.add(SkillsEvent.gesturePlayed(
          base: base.split('/').last,
          layers: layers.map((p) => p.split('/').last).toList(),
        ));
      }
    }
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/avatar/control'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Avatar fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Avatar unreachable: $e');
    }
  }

  Future<SkillResult> _executeTtsVoiceSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tts/control'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'action': p['action'] ?? 'get_status', ...p}))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('TTS fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('TTS unreachable: $e');
    }
  }

  Future<SkillResult> _executeDeviceNodeSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/device/control'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'action': p['action'] ?? 'get_battery', ...p}))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Device fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Device unreachable: $e');
    }
  }

  Future<SkillResult> _executeAvatarPipSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      await const MethodChannel('vrm/pip_mode')
          .invokeMethod('enterPictureInPictureMode');
      return SkillResult.success({'message': 'PiP mode active'});
    } catch (e) {
      return SkillResult.error('PiP fail: $e');
    }
  }

  Future<SkillResult> _executeTwilioSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute(
          'twilio-voice', p['method'] ?? 'get_status',
          params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) {
      return SkillResult.error(e.toString());
    }
  }

  Future<SkillResult> _executeAgentCardSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute(
          'agent-card', p['method'] ?? 'get_balance',
          params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) {
      return SkillResult.error(e.toString());
    }
  }

  Future<SkillResult> _executeMoltLaunchSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute(
          'molt-launch', p['method'] ?? 'get_rep',
          params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) {
      return SkillResult.error(e.toString());
    }
  }

  Future<SkillResult> _executeValeoSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute(
          'valeo-sentinel', p['method'] ?? 'get_budget',
          params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) {
      return SkillResult.error(e.toString());
    }
  }

  Future<SkillResult> _executeMoonPaySkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute(
          'moonpay', p['method'] ?? 'get_portfolio',
          params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) {
      return SkillResult.error(e.toString());
    }
  }

  Future<SkillResult> _executeBaseChainSkill(
      Skill skill, Map<String, dynamic> p, Map<String, dynamic> ctx) async {
    final action = p['action'] ?? 'get_balance';
    final svc = BaseService();
    if (!svc.isConnected && action != 'switch_network') {
      return SkillResult.error('Wallet not connected');
    }
    try {
      switch (action) {
        case 'get_address':
          return SkillResult.success({'address': svc.address});
        case 'get_balance':
          await svc.refreshBalance();
          return SkillResult.success({
            'eth': svc.ethBalance.toString(),
            'usdc': svc.usdcBalance.toString()
          });
        case 'send_eth':
          final tx = await svc.sendEth(p['to'], Decimal.parse(p['amount']));
          return SkillResult.success({'txHash': tx});
        case 'send_usdc':
          final tx = await svc.sendUsdc(p['to'], Decimal.parse(p['amount']));
          return SkillResult.success({'txHash': tx});
        case 'resolve_basename':
          final addr = await svc.resolveBasename(p['name']);
          return SkillResult.success({'address': addr});
        case 'get_history':
          final txs = await svc.fetchHistory(limit: p['limit'] ?? 10);
          return SkillResult.success({'transactions': txs});
        case 'switch_network':
          await svc.setNetwork(sepolia: p['network'] == 'sepolia');
          return SkillResult.success({'network': svc.networkName});
        default:
          return SkillResult.error('Unknown action: $action');
      }
    } catch (e) {
      return SkillResult.error(e.toString());
    }
  }

  // ── Skill Creators ────────────────────────────────────────────────────────

  Skill _createAvatarControlSkill() => Skill(
      id: 'avatar-control',
      name: 'Avatar Control',
      description: 'Control 3D avatar gestures and emotions.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'avatar',
      tags: ['3d'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createTtsVoiceSkill() => Skill(
      id: 'tts-voice',
      name: 'Voice Control',
      description: 'Switch TTS voices.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'tts',
      tags: ['voice'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createDeviceNodeSkill() => Skill(
      id: 'device-node',
      name: 'Device Tools',
      description: 'Access flashlight, battery, and sensors.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'device',
      tags: ['hardware'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createAvatarOverlaySkill() => Skill(
      id: 'avatar_overlay',
      name: 'Floating Avatar',
      description: 'Minimize avatar to transparent widget.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'system',
      tags: ['ui'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createBaseChainSkill() => Skill(
      id: 'base-chain',
      name: 'Base Wallet',
      description: 'EVM wallet for Base L2.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'base',
      tags: ['crypto'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createTwilioSkill() => Skill(
      id: 'twilio-voice',
      name: 'Twilio Voice',
      description: 'Voice calls via Twilio.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'twilio',
      tags: ['voice'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createAgentCardSkill() => Skill(
      id: 'agent-card',
      name: 'AgentCard',
      description: 'Virtual cards for AI spending.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'agentcard',
      tags: ['finance'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createMoltLaunchSkill() => Skill(
      id: 'molt-launch',
      name: 'MoltLaunch',
      description: 'AI gig marketplace.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'moltlaunch',
      tags: ['market'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createValeoSkill() => Skill(
      id: 'valeo-sentinel',
      name: 'Valeo Budget',
      description: 'Compliance and spending limits.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'valeo',
      tags: ['budget'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createMoonPaySkill() => Skill(
      id: 'moonpay',
      name: 'MoonPay',
      description: 'Crypto onramp/offramp.',
      version: '1.0.0',
      author: 'MoonPay',
      category: 'moonpay',
      tags: ['finance'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);

  Future<void> _registerNativeSkills() async {
    try {
      final gateway = GatewayService();
      if (gateway.state.isRunning) await gateway.reregisterSkills();
    } catch (_) {}
  }

  /// Returns the definitions of all enabled native skills for gateway registration.
  List<Map<String, dynamic>> getToolsCatalog() {
    return _skills.values
        .where((s) => s.enabled)
        .map(_toolDefinitionForSkill)
        .toList();
  }

  Map<String, dynamic> _toolDefinitionForSkill(Skill skill) {
    switch (skill.id) {
      case 'avatar-control':
        return {
          'name': skill.id,
          'description':
              'Control Plawie avatar model, facial emotion, speaking style, and exact VRMA full-body or limb gestures.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': [
                  'play_gesture',
                  'play_vrma',
                  'set_emotion',
                  'set_mode',
                  'change_model',
                  'get_status',
                ],
                'description':
                    'Use play_gesture for animation, set_emotion for face, set_mode for speaking style.'
              },
              'gesture': {
                'type': 'string',
                'enum': AvatarGestureCatalog.toolGestureNames,
                'description':
                    'Exact gesture name. Examples: dance, spin, greeting, wave right, cheerful wave left, bowing 4, exaggerated wave right.'
              },
              'emotion': {
                'type': 'string',
                'enum': [
                  'neutral',
                  'happy',
                  'sad',
                  'angry',
                  'surprised',
                  'relaxed',
                  'thinking',
                  'excited',
                ],
              },
              'mode': {
                'type': 'string',
                'enum': ['normal', 'expressive', 'dance', 'subtle'],
              },
              'model': {
                'type': 'string',
                'description': 'Avatar VRM file, for example gemini.vrm.',
              },
            },
            'required': ['action'],
          },
        };
      case 'tts-voice':
        return {
          'name': skill.id,
          'description':
              'Speak text aloud or inspect voice status. Gateway talk mode handles cloud speech; native TTS handles local speech.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['speak', 'stop', 'get_status', 'set_voice'],
              },
              'text': {
                'type': 'string',
                'description': 'Text to speak when action is speak.',
              },
              'voice': {'type': 'string'},
            },
            'required': ['action'],
          },
        };
      case 'device-node':
        return {
          'name': skill.id,
          'description':
              'Use Android hardware: battery, haptics, flashlight, and sensors.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': [
                  'get_battery',
                  'vibrate',
                  'flashlight_on',
                  'flashlight_off',
                  'flashlight_toggle',
                  'read_sensor',
                  'take_photo',
                  'get_location',
                ],
              },
              'sensor_type': {
                'type': 'string',
                'enum': [
                  'accelerometer',
                  'gyroscope',
                  'magnetometer',
                  'barometer'
                ],
              },
              'pattern': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description': 'Haptic pattern in milliseconds.',
              },
            },
            'required': ['action'],
          },
        };
      default:
        return skill.toToolDefinition();
    }
  }

  /// Returns the list of all registered native skills.
  List<Skill> getSkillsList() {
    return _skills.values.toList();
  }

  /// Returns a specific skill by its ID.
  Skill? getSkill(String id) {
    return _skills[id];
  }
}

class Skill {
  final String id, name, description, version, author, category, source, body;
  final List<String> tags;
  final DateTime createdAt;
  final bool enabled;
  Skill(
      {required this.id,
      required this.name,
      required this.description,
      required this.version,
      required this.author,
      required this.category,
      required this.tags,
      required this.source,
      required this.createdAt,
      required this.enabled,
      this.body = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'author': author,
        'category': category,
        'tags': tags,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
        'enabled': enabled,
        'body': body,
      };

  Map<String, dynamic> toToolDefinition() => {
        'name': id,
        'description': description,
        'input_schema': {'type': 'object', 'properties': {}}
      };
}

enum SkillsEventType {
  loaded,
  executing,
  executed,
  error,
  installed,
  uninstalled,
  toggled,
  installing,
  gesturePlayed
}

class SkillsEvent {
  final SkillsEventType type;
  final String? skillId;
  final dynamic result;
  final String? error;
  final String? base;
  final List<String>? layers;
  SkillsEvent(
      {required this.type,
      this.skillId,
      this.result,
      this.error,
      this.base,
      this.layers});
  factory SkillsEvent.skillLoaded(String id) =>
      SkillsEvent(type: SkillsEventType.loaded, skillId: id);
  factory SkillsEvent.skillExecuting(String id) =>
      SkillsEvent(type: SkillsEventType.executing, skillId: id);
  factory SkillsEvent.skillExecuted(String id, dynamic res) =>
      SkillsEvent(type: SkillsEventType.executed, skillId: id, result: res);
  factory SkillsEvent.skillError(String id, String err) =>
      SkillsEvent(type: SkillsEventType.error, skillId: id, error: err);
  factory SkillsEvent.skillInstalling(String id) =>
      SkillsEvent(type: SkillsEventType.installing, skillId: id);
  factory SkillsEvent.skillInstalled(String id) =>
      SkillsEvent(type: SkillsEventType.installed, skillId: id);
  factory SkillsEvent.skillUninstalled(String id) =>
      SkillsEvent(type: SkillsEventType.uninstalled, skillId: id);
  factory SkillsEvent.gesturePlayed(
          {required String base, required List<String> layers}) =>
      SkillsEvent(
          type: SkillsEventType.gesturePlayed, base: base, layers: layers);
}

class SkillResult {
  final bool success;
  final dynamic data;
  final String? error;
  SkillResult({required this.success, this.data, this.error});
  factory SkillResult.success(dynamic d) => SkillResult(success: true, data: d);
  factory SkillResult.error(String e) => SkillResult(success: false, error: e);
}

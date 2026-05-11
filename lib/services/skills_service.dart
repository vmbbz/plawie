import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import '../constants.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';
import 'gateway_skill_proxy.dart';
import 'base_service.dart';
import 'gateway_service.dart';
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
  final StreamController<SkillsEvent> _eventController = StreamController.broadcast();
  final PreferencesService _prefs = PreferencesService();

  Stream<SkillsEvent> get events => _eventController.stream;
  Map<String, Skill> get skills => Map.unmodifiable(_skills);

  Future<void> initialize() async {
    try {
      _logger.i('Initializing Skills System (Simplified)...');
      
      await _prefs.init();
      
      // Load bundled native skills (superpowers)
      _loadBundledNativeSkills();
      
      // Ensure agent awareness of these and workspace skills
      await ensureAgentAwareness();
      
      _logger.i('Skills System initialized with ${_skills.length} native skills');
    } catch (e) {
      _logger.e('Failed to initialize Skills System: $e');
    }
  }

  /// One-source-of-truth awareness: updates PRoot workspace and refreshes agent session.
  Future<void> ensureAgentAwareness() async {
    _logger.i('Ensuring agent awareness of skills...');
    try {
      // 1. Update PRoot workspace tools
      await NativeBridge.runInProot('$kOpenClawCommand skills update --all --yes');
      
      // 2. Install core/native stubs if missing
      await NativeBridge.runInProot('$kOpenClawCommand skills install gestures voice device-node --yes');
      
      // 3. Force a new session so the agent picks up tool changes
      await NativeBridge.runInProot('$kOpenClawCommand chat new-session --silent');
      
      // 4. Push native capabilities to the gateway WebSocket
      await _registerNativeSkills();
      
      _logger.i('Agent awareness synchronized.');
    } catch (e) {
      _logger.e('Failed to sync agent awareness: $e');
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
      final result = await _executeSkillLogic(skill, parameters ?? {}, context ?? {});
      _eventController.add(SkillsEvent.skillExecuted(skillId, result));
      return result;
    } catch (e) {
      _logger.e('Execution failed: $e');
      _eventController.add(SkillsEvent.skillError(skillId, e.toString()));
      return SkillResult.error(e.toString());
    }
  }

  Future<SkillResult> _executeSkillLogic(Skill skill, Map<String, dynamic> params, Map<String, dynamic> ctx) async {
    switch (skill.category) {
      case 'avatar': return await _executeAvatarControlSkill(skill, params, ctx);
      case 'tts': return await _executeTtsVoiceSkill(skill, params, ctx);
      case 'device': return await _executeDeviceNodeSkill(skill, params, ctx);
      case 'system': return await _executeAvatarPipSkill(skill, params, ctx);
      case 'base': return await _executeBaseChainSkill(skill, params, ctx);
      case 'twilio': return await _executeTwilioSkill(skill, params, ctx);
      case 'agentcard': return await _executeAgentCardSkill(skill, params, ctx);
      case 'moltlaunch': return await _executeMoltLaunchSkill(skill, params, ctx);
      case 'valeo': return await _executeValeoSkill(skill, params, ctx);
      case 'moonpay': return await _executeMoonPaySkill(skill, params, ctx);
      default: return SkillResult.error('No executor for category: ${skill.category}');
    }
  }
  /// Installs a skill via the OpenClaw CLI and triggers a forensic awareness sync.
  Future<bool> installSkill(String id, {bool silent = false}) async {
    try {
      if (!silent) _broadcast(SkillsEvent.skillInstalling(id));
      
      final result = await NativeBridge.runInProot('$kOpenClawCommand skills install $id --yes');
      
      if (result.contains('Error')) {
        throw Exception(result);
      }

      await ensureAgentAwareness();
      
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
      final result = await NativeBridge.runInProot('$kOpenClawCommand skills uninstall $id --yes');
      
      if (result.contains('Error')) {
        throw Exception(result);
      }

      await ensureAgentAwareness();
      
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
      final output = await NativeBridge.runInProot('$kOpenClawCommand skills info $id --json');
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
      final result = await NativeBridge.runInProot('$kOpenClawCommand skills info $id --json');
      final decoded = json.decode(result) as Map<String, dynamic>;
      return {
        ...decoded,
        'verified': decoded['source'] == 'official',
        'iconUrl': decoded['icon'] ?? decoded['image_url'],
        'tools': decoded['capabilities'] as List? ?? ['Autonomous Execution', 'Agent Logic Integration'],
        'examples': decoded['examples'] ?? 'Try: "Hey Plawie, use ${decoded['name'] ?? id}"',
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
      final content = await NativeBridge.runInProot('cat /root/.openclaw/skills/$id/SKILL.md 2>/dev/null');
      if (content.trim().isEmpty) return null;
      
      return {
        'id': id,
        'name': id.replaceAll('-', ' ').toUpperCase(),
        'description': content,
        'verified': true,
        'tools': ['Native Hardware Access', 'Low-latency Execution', 'Offline Capability'],
        'examples': 'Say "Plawie, trigger $id"',
      };
    } catch (_) {
      return null;
    }
  }

  // ── Mappings and Executors (Kept for runtime functionality) ───────────────

  final Map<String, String> _fullBodyMap = {
    'dance': 'assets/vrm/animations/gesture_dance.vrma',
    'spin': 'assets/vrm/animations/gesture_spin.vrma',
    'greeting': 'assets/vrm/animations/gesture_greeting.vrma',
    'squat': 'assets/vrm/animations/gesture_squat.vrma',
    'fight': 'assets/vrm/animations/gesture_fight.vrma',
    'cute': 'assets/vrm/animations/gesture_cute.vrma',
    'elegant': 'assets/vrm/animations/gesture_elegant.vrma',
    'peacesign': 'assets/vrm/animations/gesture_peacesign.vrma',
    'pose': 'assets/vrm/animations/gesture_pose.vrma',
    'powerful': 'assets/vrm/animations/gesture_powerful.vrma',
    'ready': 'assets/vrm/animations/gesture_ready.vrma',
    'shoot': 'assets/vrm/animations/gesture_shoot.vrma',
    'talk': 'assets/vrm/animations/gesture_talk.vrma',
    'dance_picatrix': 'assets/vrm/animations/dance_picatrix.vrma',
    'idle': 'assets/vrm/animations/idle_loop.vrma',
  };

  final Map<String, String> _limbMap = {
    'cheerful wave left': 'assets/vrm/animations/limbs/Cheerful_Wave_Left_01.vrma',
    'cheerful wave right': 'assets/vrm/animations/limbs/Cheerful_Wave_Right_01.vrma',
    'light wave left': 'assets/vrm/animations/limbs/Light_Wave_Left_01.vrma',
    'light wave right': 'assets/vrm/animations/limbs/Light_Wave_Right_01.vrma',
    'excited wave left': 'assets/vrm/animations/limbs/Excited_Wave_Left_01.vrma',
    'excited wave right': 'assets/vrm/animations/limbs/Excited_Wave_Right_01.vrma',
    'shy wave left': 'assets/vrm/animations/limbs/Shy_Wave_Left_01.vrma',
    'shy wave right': 'assets/vrm/animations/limbs/Shy_Wave_Right_01.vrma',
    'bowing': 'assets/vrm/animations/limbs/Bowing_01.vrma',
    'bowing 2': 'assets/vrm/animations/limbs/Bowing_02.vrma',
    'bowing 3': 'assets/vrm/animations/limbs/Bowing_03.vrma',
    'both wave cheer': 'assets/vrm/animations/limbs/Both_Wave_Cheer_01.vrma',
    'both wave cheer 2': 'assets/vrm/animations/limbs/Both_Wave_Cheer_02.vrma',
    'chill sit': 'assets/vrm/animations/limbs/Chill_Sit_Wave_01.vrma',
    'cross leg sit': 'assets/vrm/animations/limbs/Cross_Leg_Sitting_Wave_01.vrma',
    'excited sit': 'assets/vrm/animations/limbs/Excited_Sitting_Wave_01.vrma',
    'sitting wave': 'assets/vrm/animations/limbs/Sitting_Both_Wave_01.vrma',
    'sitting wave left': 'assets/vrm/animations/limbs/Sitting_Wave_Left_01.vrma',
    'sitting wave right': 'assets/vrm/animations/limbs/Sitting_Wave_Right_01.vrma',
    'exaggerated wave': 'assets/vrm/animations/limbs/Exaggerated_Wave_Both_01.vrma',
    'exaggerated wave left': 'assets/vrm/animations/limbs/Exaggerated_Wave_Left_01.vrma',
    'exaggerated wave right': 'assets/vrm/animations/limbs/Exaggerated_Wave_Right_01.vrma',
    'fearful wave': 'assets/vrm/animations/limbs/Fearful_Wave_01.vrma',
    'stylized wave': 'assets/vrm/animations/limbs/Stylized_Wave_Left_01.vrma',
    'stylized wave right': 'assets/vrm/animations/limbs/Stylized_Wave_Right_01.vrma',
    'both wave': 'assets/vrm/animations/limbs/Wave_Both_01.vrma',
    'wave left': 'assets/vrm/animations/limbs/Wave_Left_01.vrma',
    'wave right': 'assets/vrm/animations/limbs/Wave_Right_01.vrma',
  };

  Future<SkillResult> _executeAvatarControlSkill(Skill skill, Map<String, dynamic> params, Map<String, dynamic> ctx) async {
    final body = Map<String, dynamic>.from(params);
    String action = params['action'] ?? 'get_status';

    if (action == 'play_gesture' || action == 'play_vrma') {
      String? raw = params['gesture'] ?? params['animation'] ?? params['value'] ?? params['text'];
      if (raw != null) {
        final lower = raw.toLowerCase();
        String base = 'assets/vrma/cute.vrma';
        List<String> layers = [];
        for (var e in _fullBodyMap.entries) { if (lower.contains(e.key)) { base = e.value; break; } }
        for (var e in _limbMap.entries) { if (lower.contains(e.key)) { layers.add(e.value); } }
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
      final resp = await http.post(Uri.parse('http://127.0.0.1:8765/api/avatar/control'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return SkillResult.success(jsonDecode(resp.body));
      return SkillResult.error('Avatar fail: ${resp.statusCode}');
    } catch (e) { return SkillResult.error('Avatar unreachable: $e'); }
  }

  Future<SkillResult> _executeTtsVoiceSkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http.post(Uri.parse('http://127.0.0.1:8765/api/tts/control'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'action': p['action'] ?? 'get_status', ...p}))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return SkillResult.success(jsonDecode(resp.body));
      return SkillResult.error('TTS fail: ${resp.statusCode}');
    } catch (e) { return SkillResult.error('TTS unreachable: $e'); }
  }

  Future<SkillResult> _executeDeviceNodeSkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http.post(Uri.parse('http://127.0.0.1:8765/api/device/control'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'action': p['action'] ?? 'get_battery', ...p}))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return SkillResult.success(jsonDecode(resp.body));
      return SkillResult.error('Device fail: ${resp.statusCode}');
    } catch (e) { return SkillResult.error('Device unreachable: $e'); }
  }

  Future<SkillResult> _executeAvatarPipSkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      await const MethodChannel('vrm/pip_mode').invokeMethod('enterPictureInPictureMode');
      return SkillResult.success({'message': 'PiP mode active'});
    } catch (e) { return SkillResult.error('PiP fail: $e'); }
  }

  Future<SkillResult> _executeTwilioSkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute('twilio-voice', p['method'] ?? 'get_status', params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) { return SkillResult.error(e.toString()); }
  }

  Future<SkillResult> _executeAgentCardSkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute('agent-card', p['method'] ?? 'get_balance', params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) { return SkillResult.error(e.toString()); }
  }

  Future<SkillResult> _executeMoltLaunchSkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute('molt-launch', p['method'] ?? 'get_rep', params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) { return SkillResult.error(e.toString()); }
  }

  Future<SkillResult> _executeValeoSkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute('valeo-sentinel', p['method'] ?? 'get_budget', params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) { return SkillResult.error(e.toString()); }
  }

  Future<SkillResult> _executeMoonPaySkill(Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final data = await GatewaySkillProxy().execute('moonpay', p['method'] ?? 'get_portfolio', params: Map.from(p)..remove('method'));
      return SkillResult.success(data);
    } catch (e) { return SkillResult.error(e.toString()); }
  }

  Future<SkillResult> _executeBaseChainSkill(Skill skill, Map<String, dynamic> p, Map<String, dynamic> ctx) async {
    final action = p['action'] ?? 'get_balance';
    final svc = BaseService();
    if (!svc.isConnected && action != 'switch_network') return SkillResult.error('Wallet not connected');
    try {
      switch (action) {
        case 'get_address': return SkillResult.success({'address': svc.address});
        case 'get_balance': await svc.refreshBalance(); return SkillResult.success({'eth': svc.ethBalance.toString(), 'usdc': svc.usdcBalance.toString()});
        case 'send_eth': final tx = await svc.sendEth(p['to'], Decimal.parse(p['amount'])); return SkillResult.success({'txHash': tx});
        case 'send_usdc': final tx = await svc.sendUsdc(p['to'], Decimal.parse(p['amount'])); return SkillResult.success({'txHash': tx});
        case 'resolve_basename': final addr = await svc.resolveBasename(p['name']); return SkillResult.success({'address': addr});
        case 'get_history': final txs = await svc.fetchHistory(limit: p['limit'] ?? 10); return SkillResult.success({'transactions': txs});
        case 'switch_network': await svc.setNetwork(sepolia: p['network'] == 'sepolia'); return SkillResult.success({'network': svc.networkName});
        default: return SkillResult.error('Unknown action: $action');
      }
    } catch (e) { return SkillResult.error(e.toString()); }
  }

  // ── Skill Creators ────────────────────────────────────────────────────────

  Skill _createAvatarControlSkill() => Skill(id: 'avatar-control', name: 'Avatar Control', description: 'Control 3D avatar gestures and emotions.', version: '1.0.0', author: 'OpenClaw', category: 'avatar', tags: ['3d'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createTtsVoiceSkill() => Skill(id: 'tts-voice', name: 'Voice Control', description: 'Switch TTS voices.', version: '1.0.0', author: 'OpenClaw', category: 'tts', tags: ['voice'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createDeviceNodeSkill() => Skill(id: 'device-node', name: 'Device Tools', description: 'Access flashlight, battery, and sensors.', version: '1.0.0', author: 'OpenClaw', category: 'device', tags: ['hardware'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createAvatarOverlaySkill() => Skill(id: 'avatar_overlay', name: 'Floating Avatar', description: 'Minimize avatar to transparent widget.', version: '1.0.0', author: 'OpenClaw', category: 'system', tags: ['ui'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createBaseChainSkill() => Skill(id: 'base-chain', name: 'Base Wallet', description: 'EVM wallet for Base L2.', version: '1.0.0', author: 'OpenClaw', category: 'base', tags: ['crypto'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createTwilioSkill() => Skill(id: 'twilio-voice', name: 'Twilio Voice', description: 'Voice calls via Twilio.', version: '1.0.0', author: 'OpenClaw', category: 'twilio', tags: ['voice'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createAgentCardSkill() => Skill(id: 'agent-card', name: 'AgentCard', description: 'Virtual cards for AI spending.', version: '1.0.0', author: 'OpenClaw', category: 'agentcard', tags: ['finance'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createMoltLaunchSkill() => Skill(id: 'molt-launch', name: 'MoltLaunch', description: 'AI gig marketplace.', version: '1.0.0', author: 'OpenClaw', category: 'moltlaunch', tags: ['market'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createValeoSkill() => Skill(id: 'valeo-sentinel', name: 'Valeo Budget', description: 'Compliance and spending limits.', version: '1.0.0', author: 'OpenClaw', category: 'valeo', tags: ['budget'], source: 'bundled', createdAt: DateTime.now(), enabled: true);
  Skill _createMoonPaySkill() => Skill(id: 'moonpay', name: 'MoonPay', description: 'Crypto onramp/offramp.', version: '1.0.0', author: 'MoonPay', category: 'moonpay', tags: ['finance'], source: 'bundled', createdAt: DateTime.now(), enabled: true);

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
        .map((s) => s.toToolDefinition())
        .toList();
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
  Skill({required this.id, required this.name, required this.description, required this.version, required this.author, required this.category, required this.tags, required this.source, required this.createdAt, required this.enabled, this.body = ''});
  
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

  Map<String, dynamic> toToolDefinition() => {'name': id, 'description': description, 'input_schema': {'type': 'object', 'properties': {}}};
}

enum SkillsEventType { loaded, executing, executed, error, installed, uninstalled, toggled, installing, gesturePlayed }
class SkillsEvent {
  final SkillsEventType type; final String? skillId; final dynamic result; final String? error; final String? base; final List<String>? layers;
  SkillsEvent({required this.type, this.skillId, this.result, this.error, this.base, this.layers});
  factory SkillsEvent.skillLoaded(String id) => SkillsEvent(type: SkillsEventType.loaded, skillId: id);
  factory SkillsEvent.skillExecuting(String id) => SkillsEvent(type: SkillsEventType.executing, skillId: id);
  factory SkillsEvent.skillExecuted(String id, dynamic res) => SkillsEvent(type: SkillsEventType.executed, skillId: id, result: res);
  factory SkillsEvent.skillError(String id, String err) => SkillsEvent(type: SkillsEventType.error, skillId: id, error: err);
  factory SkillsEvent.skillInstalling(String id) => SkillsEvent(type: SkillsEventType.installing, skillId: id);
  factory SkillsEvent.skillInstalled(String id) => SkillsEvent(type: SkillsEventType.installed, skillId: id);
  factory SkillsEvent.skillUninstalled(String id) => SkillsEvent(type: SkillsEventType.uninstalled, skillId: id);
  factory SkillsEvent.gesturePlayed({required String base, required List<String> layers}) => SkillsEvent(type: SkillsEventType.gesturePlayed, base: base, layers: layers);
}

class SkillResult {
  final bool success; final dynamic data; final String? error;
  SkillResult({required this.success, this.data, this.error});
  factory SkillResult.success(dynamic d) => SkillResult(success: true, data: d);
  factory SkillResult.error(String e) => SkillResult(success: false, error: e);
}

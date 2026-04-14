import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'preferences_service.dart';
import 'gateway_skill_proxy.dart';

/// Skills System with YAML frontmatter and dynamic loading
/// Inspired by SeekerClaw's skills architecture
class SkillsService {
  static final SkillsService _instance = SkillsService._internal();
  factory SkillsService() => _instance;
  SkillsService._internal();

  final Logger _logger = Logger();
  final Map<String, Skill> _skills = {};
  final StreamController<SkillsEvent> _eventController = StreamController.broadcast();
  final PreferencesService _prefs = PreferencesService();
  String? _skillsDirectory;

  Stream<SkillsEvent> get events => _eventController.stream;
  Map<String, Skill> get skills => Map.unmodifiable(_skills);

  Future<void> initialize() async {
    try {
      _logger.i('Initializing Skills System...');
      
      // Initialize preferences
      await _prefs.init();
      
      // Get skills directory
      final appDir = await getApplicationDocumentsDirectory();
      _skillsDirectory = path.join(appDir.path, 'skills');
      
      // Create skills directory if it doesn't exist
      await Directory(_skillsDirectory!).create(recursive: true);
      
      // Load bundled skills
      await _loadBundledSkills();
      
      // Load custom skills
      await _loadCustomSkills();
      
      _logger.i('Skills System initialized with ${_skills.length} skills');
    } catch (e) {
      _logger.e('Failed to initialize Skills System: $e');
      rethrow;
    }
  }

  /// Load bundled skills.
  ///
  /// ONLY real skills live here:
  ///   • Custom device-native skills → execute via AgentSkillServer HTTP bridge (127.0.0.1:8765)
  ///   • Partner integration skills  → execute via GatewaySkillProxy WebSocket RPC
  ///
  /// DO NOT add stubs that return fake data — the gateway handles generic tasks (weather,
  /// calculator, search, etc.) natively via its own skill ecosystem.
  Future<void> _loadBundledSkills() async {
    try {
      final bundledSkills = [
        // ── Custom device-native skills (app-specific, not in ClawHub) ──────
        _createAvatarControlSkill(),   // Switch VRM model, trigger gestures
        _createTtsVoiceSkill(),         // Switch TTS engine / voice
        _createDeviceNodeSkill(),       // Vibrate, flashlight, battery, sensors
        // ── Legacy PiP overlay (retained — unique MethodChannel trick) ──────
        _createAvatarOverlaySkill(),
        // ── Partner integrations (real GatewaySkillProxy calls) ─────────────
        _createTwilioSkill(),
        _createAgentCardSkill(),
        _createMoltLaunchSkill(),
        _createValeoSkill(),
        _createMoonPaySkill(),
      ];

      for (final skill in bundledSkills) {
        _skills[skill.id] = skill;
        _eventController.add(SkillsEvent.skillLoaded(skill.id));
      }

      _logger.i('Loaded ${bundledSkills.length} bundled skills');
    } catch (e) {
      _logger.e('Failed to load bundled skills: $e');
    }
  }

  /// Load custom skills from directory
  Future<void> _loadCustomSkills() async {
    if (_skillsDirectory == null) return;

    try {
      final skillsDir = Directory(_skillsDirectory!);
      if (!await skillsDir.exists()) return;

      await for (final entity in skillsDir.list()) {
        if (entity is File && entity.path.endsWith('.yaml')) {
          await _loadSkillFromFile(entity);
        } else if (entity is File && entity.path.endsWith('.zip')) {
          await _loadSkillFromZip(entity);
        }
      }

      _logger.i('Loaded custom skills from directory');
    } catch (e) {
      _logger.e('Failed to load custom skills: $e');
    }
  }

  /// Load skill from YAML file
  Future<void> _loadSkillFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final skill = _parseSkillFromYaml(content, file.path);
      
      if (skill != null) {
        _skills[skill.id] = skill;
        _eventController.add(SkillsEvent.skillLoaded(skill.id));
        _logger.d('Loaded skill: ${skill.id}');
      }
    } catch (e) {
      _logger.e('Failed to load skill from ${file.path}: $e');
    }
  }

  /// Load skill from ZIP archive
  Future<void> _loadSkillFromZip(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        if (file.name.endsWith('.yaml') && !file.isFile) continue;
        
        final content = utf8.decode(file.content as List<int>);
        final skill = _parseSkillFromYaml(content, file.name);
        
        if (skill != null) {
          _skills[skill.id] = skill;
          _eventController.add(SkillsEvent.skillLoaded(skill.id));
          _logger.d('Loaded skill from ZIP: ${skill.id}');
        }
      }
    } catch (e) {
      _logger.e('Failed to load skill from ZIP ${zipFile.path}: $e');
    }
  }

  /// Parse skill from YAML content
  Skill? _parseSkillFromYaml(String content, String source) {
    try {
      final yaml = loadYaml(content);
      
      if (yaml is! Map) return null;
      
      final frontmatter = yaml['frontmatter'] as Map?;
      if (frontmatter == null) return null;

      // Validate required fields
      if (!frontmatter.containsKey('id') || !frontmatter.containsKey('name')) {
        return null;
      }

      // Check version and integrity
      final version = frontmatter['version'] as String? ?? '1.0.0';
      final expectedHash = frontmatter['sha256'] as String?;
      
      if (expectedHash != null) {
        final actualHash = sha256.convert(utf8.encode(content)).toString();
        if (actualHash != expectedHash) {
          _logger.w('Skill integrity check failed for ${frontmatter['id']}');
          return null;
        }
      }

      final skill = Skill(
        id: frontmatter['id'] as String,
        name: frontmatter['name'] as String,
        description: frontmatter['description'] as String? ?? '',
        version: version,
        author: frontmatter['author'] as String? ?? 'Unknown',
        category: frontmatter['category'] as String? ?? 'general',
        tags: _parseStringList(frontmatter['tags']),
        requirements: _parseRequirements(frontmatter['requirements']),
        body: yaml['body'] as String? ?? content,
        source: source,
        createdAt: DateTime.now(),
        enabled: frontmatter['enabled'] as bool? ?? true,
      );

      return skill;
    } catch (e) {
      _logger.e('Failed to parse skill from YAML: $e');
      return null;
    }
  }

  /// Parse string list from YAML
  List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  /// Parse skill requirements
  List<SkillRequirement> _parseRequirements(dynamic value) {
    if (value == null) return [];
    
    final requirements = <SkillRequirement>[];
    
    if (value is Map) {
      for (final entry in value.entries) {
        requirements.add(SkillRequirement(
          type: entry.key,
          value: entry.value.toString(),
        ));
      }
    } else if (value is List) {
      for (final item in value) {
        if (item is String) {
          requirements.add(SkillRequirement(
            type: 'general',
            value: item,
          ));
        }
      }
    }
    
    return requirements;
  }

  /// Execute a skill
  Future<SkillResult> executeSkill(
    String skillId, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? context,
  }) async {
    final skill = _skills[skillId];
    if (skill == null) {
      return SkillResult.error('Skill not found: $skillId');
    }

    if (!skill.enabled) {
      return SkillResult.error('Skill is disabled: $skillId');
    }

    // Check requirements
    final requirementsCheck = await _checkRequirements(skill.requirements);
    if (!requirementsCheck.success) {
      return SkillResult.error('Requirements not met: ${requirementsCheck.error}');
    }

    try {
      _eventController.add(SkillsEvent.skillExecuting(skillId));
      
      // Execute skill based on type
      final result = await _executeSkillLogic(skill, parameters ?? {}, context ?? {});
      
      _eventController.add(SkillsEvent.skillExecuted(skillId, result));
      return result;
    } catch (e) {
      _logger.e('Failed to execute skill $skillId: $e');
      _eventController.add(SkillsEvent.skillError(skillId, e.toString()));
      return SkillResult.error(e.toString());
    }
  }

  /// Execute skill logic based on category.
  Future<SkillResult> _executeSkillLogic(
    Skill skill,
    Map<String, dynamic> parameters,
    Map<String, dynamic> context,
  ) async {
    switch (skill.category) {
      // ── Custom device-native ──────────────────────────────────────────────
      case 'avatar':
        return await _executeAvatarControlSkill(skill, parameters, context);
      case 'tts':
        return await _executeTtsVoiceSkill(skill, parameters, context);
      case 'device':
        return await _executeDeviceNodeSkill(skill, parameters, context);
      // ── Legacy PiP (system category, specific id) ─────────────────────────
      case 'system':
        return await _executeAvatarPipSkill(skill, parameters, context);
      // ── Partner integrations ──────────────────────────────────────────────
      case 'twilio':
        return await _executeTwilioSkill(skill, parameters, context);
      case 'agentcard':
        return await _executeAgentCardSkill(skill, parameters, context);
      case 'moltlaunch':
        return await _executeMoltLaunchSkill(skill, parameters, context);
      case 'valeo':
        return await _executeValeoSkill(skill, parameters, context);
      case 'moonpay':
        return await _executeMoonPaySkill(skill, parameters, context);
      default:
        return SkillResult.error('No executor for category: ${skill.category}');
    }
  }

  /// Check skill requirements
  Future<RequirementsCheck> _checkRequirements(List<SkillRequirement> requirements) async {
    for (final requirement in requirements) {
      switch (requirement.type) {
        case 'network':
          // Check network connectivity
          try {
            final response = await http.get(Uri.parse('https://www.google.com'));
            if (response.statusCode != 200) {
              return RequirementsCheck.failed('Network connectivity required');
            }
          } catch (e) {
            return RequirementsCheck.failed('Network connectivity required');
          }
          break;
        
        case 'api_key':
          // Check for required API keys
          // This would integrate with the API key detection service
          break;
        
        case 'permission':
          // Check for required permissions
          // This would integrate with permission handling
          break;
        
        default:
          // General requirements check
          break;
      }
    }
    
    return RequirementsCheck.success();
  }

  /// Install skill from URL
  Future<bool> installSkillFromUrl(String url) async {
    try {
      _logger.i('Installing skill from URL: $url');
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download skill: ${response.statusCode}');
      }

      final skill = _parseSkillFromYaml(response.body, url);
      if (skill == null) {
        throw Exception('Invalid skill format');
      }

      // Save skill to local directory
      if (_skillsDirectory != null) {
        final skillFile = File(path.join(_skillsDirectory!, '${skill.id}.yaml'));
        await skillFile.writeAsString(response.body);
      }

      _skills[skill.id] = skill;
      _eventController.add(SkillsEvent.skillInstalled(skill.id));
      
      _logger.i('Successfully installed skill: ${skill.id}');
      return true;
    } catch (e) {
      _logger.e('Failed to install skill from URL: $e');
      _eventController.add(SkillsEvent.skillError('install', e.toString()));
      return false;
    }
  }

  /// Uninstall skill
  Future<bool> uninstallSkill(String skillId) async {
    try {
      final skill = _skills[skillId];
      if (skill == null) return false;

      // Remove from memory
      _skills.remove(skillId);

      // Remove file if it's a custom skill
      if (_skillsDirectory != null && skill.source.startsWith(_skillsDirectory!)) {
        final skillFile = File(skill.source);
        if (await skillFile.exists()) {
          await skillFile.delete();
        }
      }

      _eventController.add(SkillsEvent.skillUninstalled(skillId));
      _logger.i('Uninstalled skill: $skillId');
      return true;
    } catch (e) {
      _logger.e('Failed to uninstall skill $skillId: $e');
      return false;
    }
  }


  /// Get skills by category
  List<Skill> getSkillsByCategory(String category) {
    return _skills.values
        .where((skill) => skill.category == category)
        .toList();
  }

  /// Search skills
  List<Skill> searchSkills(String query) {
    final lowerQuery = query.toLowerCase();
    
    return _skills.values.where((skill) {
      return skill.name.toLowerCase().contains(lowerQuery) ||
             skill.description.toLowerCase().contains(lowerQuery) ||
             skill.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // ── Custom device-native skill executors ─────────────────────────────────
  // These call 127.0.0.1:8765 (AgentSkillServer) which is the HTTP bridge
  // between the gateway agent and the Flutter app's live UI state.

  /// Avatar Control — change VRM model, trigger gestures, set emotions.
  /// POST /api/avatar/control with {action, value} JSON.
  Future<SkillResult> _executeAvatarControlSkill(
    Skill skill,
    Map<String, dynamic> parameters,
    Map<String, dynamic> context,
  ) async {
    final action = parameters['action'] as String? ?? 'get_status';
    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8765/api/avatar/control'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': action, ...parameters..remove('action')}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return SkillResult.success(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return SkillResult.error('Avatar control failed: HTTP ${response.statusCode}');
    } catch (e) {
      return SkillResult.error('Avatar skill unreachable: $e');
    }
  }

  /// TTS Voice Control — switch engine, change voice, speak text.
  /// POST /api/tts/control with {action, engine?, voice?, text?} JSON.
  Future<SkillResult> _executeTtsVoiceSkill(
    Skill skill,
    Map<String, dynamic> parameters,
    Map<String, dynamic> context,
  ) async {
    final action = parameters['action'] as String? ?? 'get_status';
    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8765/api/tts/control'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': action, ...parameters..remove('action')}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return SkillResult.success(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return SkillResult.error('TTS control failed: HTTP ${response.statusCode}');
    } catch (e) {
      return SkillResult.error('TTS skill unreachable: $e');
    }
  }

  /// Device Node Control — vibrate, flashlight, battery, sensors.
  /// POST /api/device/control with {action, ...params} JSON.
  Future<SkillResult> _executeDeviceNodeSkill(
    Skill skill,
    Map<String, dynamic> parameters,
    Map<String, dynamic> context,
  ) async {
    final action = parameters['action'] as String? ?? 'get_battery';
    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8765/api/device/control'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': action, ...parameters..remove('action')}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return SkillResult.success(jsonDecode(response.body) as Map<String, dynamic>);
      }
      return SkillResult.error('Device control failed: HTTP ${response.statusCode}');
    } catch (e) {
      return SkillResult.error('Device skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeAvatarPipSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    try {
      await const MethodChannel('vrm/pip_mode').invokeMethod('enterPictureInPictureMode');
      return SkillResult.success({'message': 'Entered Picture-in-Picture mode successfully.'});
    } catch (e) {
      return SkillResult.error('Failed to enter PiP mode: \$e');
    }
  }



  /// Execute Twilio Voice skill via Gateway.
  /// Response fields per Twilio REST API: phone_number (E.164), status, concurrent_sessions,
  /// inbound_count, total_duration_h, transcription_enabled, relay_enabled,
  /// call_logs: [{sid, from, to, direction, duration, status, summary, date_created}]
  Future<SkillResult> _executeTwilioSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    final method = parameters['method'] ?? 'get_status';
    final proxy = GatewaySkillProxy();
    if (!proxy.isAttached) {
      // Offline fallback — realistic field names matching Twilio REST API
      switch (method) {
        case 'get_status':
          return SkillResult.success({
            'phone_number': '',
            'status': 'disconnected',
            'concurrent_sessions': 0,
            'inbound_count': 0,
            'total_duration_h': 0,
            'transcription_enabled': false,
            'relay_enabled': false,
            'call_logs': [],
          });
        default:
          return SkillResult.error('Gateway not connected');
      }
    }
    try {
      final data = await proxy.execute('twilio-voice', method,
          params: Map<String, dynamic>.from(parameters)..remove('method'));
      return SkillResult.success(data);
    } on SkillProxyException catch (e) {
      return SkillResult.error(e.message);
    }
  }

  /// Execute AgentCard.ai skill via Gateway.
  /// Official product: Visa virtual card by AgentCard.ai (agentcard.ai) — private beta.
  /// CLI: agentcard cards create --amount X / agentcard cards details [id]
  /// Response fields: id, last4, balance (cents), spendLimit (cents), status (OPEN|PAUSED|TERMINATED),
  ///   expiryMonth, expiryYear, network ('Visa'), autoRefill (bool), cardholderName
  Future<SkillResult> _executeAgentCardSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    final method = parameters['method'] ?? 'get_balance';
    final proxy = GatewaySkillProxy();
    if (!proxy.isAttached) {
      switch (method) {
        case 'get_balance':
          return SkillResult.success({
            'id': '',
            'last4': '----',
            'balance': 0,
            'spendLimit': 0,
            'status': 'DISCONNECTED',
            'expiryMonth': '--',
            'expiryYear': '----',
            'network': 'Visa',
            'autoRefill': false,
          });
        default:
          return SkillResult.error('Gateway not connected');
      }
    }
    try {
      final data = await proxy.execute('agent-card', method,
          params: Map<String, dynamic>.from(parameters)..remove('method'));
      return SkillResult.success(data);
    } on SkillProxyException catch (e) {
      return SkillResult.error(e.message);
    }
  }

  /// Execute MoltLaunch skill via Gateway.
  /// MoltLaunch / Molt.ID: Solana-based AI agent job marketplace (moltdotid/AutoPilot-Molt-CLI).
  /// Identity = NFT public key on Solana. Jobs are on-chain transactions via Multiclaw tx-queue API.
  /// get_identity fields: wallet_pubkey, display_name, verified, jobs_count, reputation_score (0.0-1.0)
  /// get_rep fields: reputation_score, total_jobs_completed, pending_payouts (lamports), active_gig_list[]
  ///   gig: { title, status (in_progress|pending_review|bidding|completed), price (lamports), currency }
  Future<SkillResult> _executeMoltLaunchSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    final method = parameters['method'] ?? 'get_rep';
    final proxy = GatewaySkillProxy();
    if (!proxy.isAttached) {
      switch (method) {
        case 'get_identity':
          return SkillResult.success({
            'wallet_pubkey': '',
            'display_name': '',
            'verified': false,
            'jobs_count': 0,
            'reputation_score': 0.0,
          });
        case 'get_rep':
          return SkillResult.success({
            'reputation_score': 0.0,
            'total_jobs_completed': 0,
            'pending_payouts': 0,
            'active_gig_list': [],
          });
        default:
          return SkillResult.error('Gateway not connected');
      }
    }
    try {
      final data = await proxy.execute('molt-launch', method,
          params: Map<String, dynamic>.from(parameters)..remove('method'));
      return SkillResult.success(data);
    } on SkillProxyException catch (e) {
      return SkillResult.error(e.message);
    }
  }

  /// Execute Valeo Sentinel skill via Gateway.
  /// Valeo.cash Sentinel: x402 payment protocol compliance & budget enforcement for AI agents.
  /// Budget caps: per_call_limit, hourly_limit, daily_limit, lifetime_limit (all in USD cents).
  /// Audit log fields per Valeo docs: agentId, team, endpoint, tx_hash, timing, action, amount_cents, result.
  /// result values: 'approved' | 'blocked' | 'pending'
  Future<SkillResult> _executeValeoSkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    final method = parameters['method'] ?? 'get_budget';
    final proxy = GatewaySkillProxy();
    if (!proxy.isAttached) {
      switch (method) {
        case 'get_budget':
          return SkillResult.success({
            'budget_cap': 0,
            'current_spend': 0,
            'sentinel_active': false,
            'policy_id': '--',
            'per_call_limit': 0,
            'hourly_limit': 0,
            'daily_limit': 0,
            'lifetime_limit': 0,
            'audit_log': [],
          });
        default:
          return SkillResult.error('Gateway not connected');
      }
    }
    try {
      final data = await proxy.execute('valeo-sentinel', method,
          params: Map<String, dynamic>.from(parameters)..remove('method'));
      return SkillResult.success(data);
    } on SkillProxyException catch (e) {
      return SkillResult.error(e.message);
    }
  }



  /// Execute MoonPay Agents skill via Gateway MCP server.
  /// MoonPay runs as an MCP server (mp mcp) inside OpenClaw.
  /// Skills install automatically via `mp skill install` to ~/.claude/skills/.
  ///
  /// Agent prompt: tell the agent it has moonpay.* MCP tools available:
  ///   get_portfolio, get_price, swap, bridge, buy, sell, dca_list, dca_create
  ///
  /// Full setup:
  ///   npm install -g @moonpay/cli
  ///   mp login && mp wallet create MyWallet
  ///   Configure in openclaw.yaml: mcp.servers → [name: moonpay, command: mp, args: [mcp]]
  Future<SkillResult> _executeMoonPaySkill(Skill skill, Map<String, dynamic> parameters, Map<String, dynamic> context) async {
    final method = parameters['method'] ?? 'get_portfolio';
    final proxy = GatewaySkillProxy();
    if (!proxy.isAttached) {
      // Offline fallback with realistic MoonPay field shapes
      switch (method) {
        case 'get_portfolio':
          return SkillResult.success({
            'wallets': [],
            'total_usd_value': 0.0,
          });
        case 'get_price':
          return SkillResult.success({
            'prices': [
              {'token': 'ETH', 'usd': 0.0, 'change_24h': 0.0},
              {'token': 'BTC', 'usd': 0.0, 'change_24h': 0.0},
              {'token': 'SOL', 'usd': 0.0, 'change_24h': 0.0},
              {'token': 'USDC', 'usd': 1.0, 'change_24h': 0.0},
            ],
          });
        case 'dca_list':
          return SkillResult.success({'strategies': []});
        default:
          return SkillResult.error('Gateway not connected');
      }
    }
    try {
      final data = await proxy.execute('moonpay', method,
          params: Map<String, dynamic>.from(parameters)..remove('method'));
      return SkillResult.success(data);
    } on SkillProxyException catch (e) {
      return SkillResult.error(e.message);
    }
  }

  // ── Custom device-native skill creators ──────────────────────────────────

  Skill _createAvatarControlSkill() {
    return Skill(
      id: 'avatar-control',
      name: 'Avatar Control',
      description: 'Control the 3D live avatar: switch VRM models, trigger gestures and emotions.',
      version: '1.0.0',
      author: 'Custom',
      category: 'avatar',
      tags: ['avatar', 'vrm', 'gesture', '3d', 'emotion', 'animation'],
      requirements: [],
      body: '3D avatar control skill. Calls AgentSkillServer on 127.0.0.1:8765/api/avatar/control.',
      source: 'custom',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('avatar-control'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['change_model', 'play_gesture', 'set_emotion', 'get_status'],
            'description': 'Avatar action to perform.',
          },
          'model': {
            'type': 'string',
            'description': 'VRM filename to load (e.g. "clawbot_v2.vrm"). Required for change_model.',
          },
          'gesture': {
            'type': 'string',
            'enum': ['wave', 'nod', 'shake', 'bow', 'idle', 'thinking', 'excited'],
            'description': 'Gesture to play. Required for play_gesture.',
          },
          'emotion': {
            'type': 'string',
            'enum': ['happy', 'sad', 'neutral', 'surprised', 'angry'],
            'description': 'Facial expression to set. Required for set_emotion.',
          },
        },
        'required': ['action'],
      },
    );
  }

  Skill _createTtsVoiceSkill() {
    return Skill(
      id: 'tts-voice',
      name: 'TTS Voice Control',
      description: 'Switch the TTS engine (Piper / ElevenLabs / OpenAI / Native) or change the active voice.',
      version: '1.0.0',
      author: 'Custom',
      category: 'tts',
      tags: ['tts', 'voice', 'speech', 'piper', 'elevenlabs', 'openai'],
      requirements: [],
      body: 'TTS voice control skill. Calls AgentSkillServer on 127.0.0.1:8765/api/tts/control.',
      source: 'custom',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('tts-voice'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['set_engine', 'set_voice', 'speak', 'stop', 'get_status'],
            'description': 'TTS action to perform.',
          },
          'engine': {
            'type': 'string',
            'enum': ['piper', 'native', 'elevenlabs', 'openai'],
            'description': 'TTS engine to switch to. Required for set_engine.',
          },
          'voice': {
            'type': 'string',
            'description': 'Voice ID or name. For ElevenLabs: voice_id. For OpenAI: alloy/echo/fable/onyx/nova/shimmer.',
          },
          'text': {
            'type': 'string',
            'description': 'Text to speak aloud. Required for speak.',
          },
        },
        'required': ['action'],
      },
    );
  }

  Skill _createDeviceNodeSkill() {
    return Skill(
      id: 'device-node',
      name: 'Device Control',
      description: 'Control device hardware: vibrate, flashlight, read sensors, get battery. Powered by the Node capabilities layer.',
      version: '1.0.0',
      author: 'Custom',
      category: 'device',
      tags: ['device', 'vibrate', 'haptic', 'flashlight', 'battery', 'sensor', 'location', 'camera'],
      requirements: [],
      body: 'Device node skill. Calls AgentSkillServer on 127.0.0.1:8765/api/device/control.',
      source: 'custom',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('device-node'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': [
              'vibrate', 'flashlight_on', 'flashlight_off',
              'get_battery', 'get_location', 'read_sensor', 'take_photo',
            ],
            'description': 'Device action. vibrate triggers haptic, get_battery returns level/charging status.',
          },
          'pattern': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'Vibration pattern in ms [delay, on, off, on…]. Used with vibrate.',
          },
          'sensor_type': {
            'type': 'string',
            'enum': ['accelerometer', 'gyroscope', 'magnetometer', 'barometer'],
            'description': 'Sensor to read. Required for read_sensor.',
          },
        },
        'required': ['action'],
      },
    );
  }

  // ── Bundled skill creators ─────────────────────────────────────────────────

  Skill _createAvatarOverlaySkill() {
    return Skill(
      id: 'avatar_overlay',
      name: 'Floating Transparent Avatar',
      description: 'Shrink the agent avatar into a transparent floating widget on the home screen.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'system',
      tags: ['overlay', 'floating', 'minimize', 'widget', 'shrink', 'transparent'],
      requirements: [],
      body: '''# Floating Avatar Skill

## Description
Shrinks the avatar into a true transparent floating widget, allowing you to use other apps while talking.

## Usage
- "Minimize to floating widget"
- "Show floating transparent avatar"
- "Pop out"

## Requirements
- SYSTEM_ALERT_WINDOW permission.

## Returns
- Status of Overlay transition.
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true,

    );
  }

  Skill _createTwilioSkill() {
    return Skill(
      id: 'twilio-voice',
      name: 'Twilio AI Voice',
      description: 'Engage in real-time voice conversations via Twilio ConversationRelay',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'twilio',
      tags: ['voice', 'telephony', 'twilio', 'call'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: 'Full Twilio functional skill for AI voice bridging.',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('twilio-voice'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'method': {
            'type': 'string',
            'enum': ['get_status', 'send_message'],
            'description': 'The twilio operation to perform'
          },
          'to': {'type': 'string', 'description': 'Recipient phone number'},
          'body': {'type': 'string', 'description': 'Message body'}
        },
        'required': ['method']
      },
    );
  }

  Skill _createAgentCardSkill() {
    return Skill(
      id: 'agent-card',
      name: 'AgentCard Payments',
      description: 'Issue virtual cards and manage spending budgets',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'agentcard',
      tags: ['payments', 'visa', 'mastercard', 'finance'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: 'AgentCard restorative skill for programmatic financial actions.',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('agent-card'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'method': {
            'type': 'string',
            'enum': ['get_balance', 'create_card'],
            'description': 'Payment management operation'
          }
        },
        'required': ['method']
      },
    );
  }

  Skill _createMoltLaunchSkill() {
    return Skill(
      id: 'molt-launch',
      name: 'MoltLaunch Marketplace',
      description: 'Coordinate tasks and build reputation on-chain',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'moltlaunch',
      tags: ['marketplace', 'gigs', 'reputation', 'base'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: 'MoltLaunch workplace skill for agent task coordination.',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('molt-launch'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'method': {
            'type': 'string',
            'enum': ['get_rep', 'post_job'],
            'description': 'Marketplace coordination operation'
          },
          'job_details': {'type': 'string', 'description': 'Details for post_job'}
        },
        'required': ['method']
      },
    );
  }

  Skill _createValeoSkill() {
    return Skill(
      id: 'valeo-sentinel',
      name: 'Valeo Sentinel',
      description: 'Budget enforcement and compliance for payments',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'valeo',
      tags: ['compliance', 'budget', 'audit', 'valeo'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: 'Valeo Sentinel budget skill for payment safety.',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('valeo-sentinel'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'method': {
            'type': 'string',
            'enum': ['get_budget', 'set_policy'],
            'description': 'Compliance and budget operation'
          },
          'policy_id': {'type': 'string', 'description': 'Policy ID for set_policy'}
        },
        'required': ['method']
      },
    );
  }

  Skill _createMoonPaySkill() {
    return Skill(
      id: 'moonpay',
      name: 'MoonPay Agents',
      description: 'Give your agent a verified bank account and 30+ financial skills — buy, sell, swap, bridge, DCA, and live prices via the MoonPay CLI MCP server.',
      version: '1.0.0',
      author: 'MoonPay',
      category: 'moonpay',
      tags: ['moonpay', 'crypto', 'finance', 'swap', 'buy', 'sell', 'bridge', 'dca', 'portfolio'],
      requirements: [SkillRequirement(type: 'network', value: 'internet')],
      body: '''# MoonPay Agents Skill

Your agent can call these MCP tools once MoonPay CLI is configured:
  moonpay.get_portfolio — wallet balances across all chains
  moonpay.get_price { token } — live USD price + 24h change
  moonpay.swap { from_token, to_token, amount } — on-chain swap
  moonpay.bridge { token, from_chain, to_chain, amount } — cross-chain bridge
  moonpay.buy { token, amount_usd } — fiat onramp
  moonpay.sell { token, amount } — fiat offramp
  moonpay.dca_list — active DCA strategies
  moonpay.dca_create { token, amount_usd, frequency } — new DCA strategy

Setup: npm install -g @moonpay/cli → mp login → mp wallet create MyWallet
Config: openclaw.yaml → mcp.servers → [name: moonpay, command: mp, args: [mcp]]

Agent instruction: "You have the MoonPay MCP toolkit. Always confirm with user before executing swaps/buys/bridges."
''',
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: _prefs.isSkillEnabled('moonpay'),
      parametersSchema: {
        'type': 'object',
        'properties': {
          'method': {
            'type': 'string',
            'enum': [
              'get_portfolio', 'get_price', 'swap', 'bridge',
              'buy', 'sell', 'dca_list', 'dca_create',
            ],
            'description': 'The MoonPay operation. get_portfolio for balances, swap/bridge for on-chain, buy/sell for fiat, dca_* for strategies.',
          },
          'token': {'type': 'string', 'description': 'Token symbol (ETH, BTC, SOL, USDC…)'},
          'from_token': {'type': 'string', 'description': 'Source token for swap/bridge'},
          'to_token': {'type': 'string', 'description': 'Target token for swap'},
          'from_chain': {'type': 'string', 'description': 'Source chain for bridge'},
          'to_chain': {'type': 'string', 'description': 'Destination chain for bridge'},
          'amount': {'type': 'number', 'description': 'Token amount for swap/bridge/sell'},
          'amount_usd': {'type': 'number', 'description': 'USD amount for buy/dca_create'},
          'frequency': {
            'type': 'string',
            'enum': ['daily', 'weekly', 'biweekly', 'monthly'],
            'description': 'Purchase frequency for dca_create',
          },
          'tokens': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Batch token list for get_price',
          },
        },
        'required': ['method'],
      },
    );
  }

  Skill? getSkill(String id) => _skills[id];

  /// Get list of skills for UI
  List<Skill> getSkillsList() => _skills.values.toList();

  /// Get simplified tools catalog for Agent Discovery (Claude format)
  List<Map<String, dynamic>> getToolsCatalog() {
    return _skills.values
        .where((s) => s.enabled)
        .map((s) => s.toToolDefinition())
        .toList();
  }

  /// Toggle skill enablement and persist it
  Future<void> toggleSkill(String skillId, bool enabled) async {
    final skill = _skills[skillId];
    if (skill == null) return;

    final updatedSkill = skill.copyWith(enabled: enabled);
    _skills[skillId] = updatedSkill;
    
    await _prefs.setSkillEnabled(skillId, enabled);
    _eventController.add(SkillsEvent.skillToggled(skillId, enabled));
    
    _logger.i('Skill $skillId ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Dispose skills service
  Future<void> dispose() async {
    await _eventController.close();
  }
}

/// Skill model
class Skill {
  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String category;
  final List<String> tags;
  final List<SkillRequirement> requirements;
  final String body;
  final String source;
  final DateTime createdAt;
  final bool enabled;
  final Map<String, dynamic>? parametersSchema;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.category,
    required this.tags,
    required this.requirements,
    required this.body,
    required this.source,
    required this.createdAt,
    required this.enabled,
    this.parametersSchema,
  });

  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? version,
    String? author,
    String? category,
    List<String>? tags,
    List<SkillRequirement>? requirements,
    String? body,
    String? source,
    DateTime? createdAt,
    bool? enabled,
    Map<String, dynamic>? parametersSchema,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      requirements: requirements ?? this.requirements,
      body: body ?? this.body,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      enabled: enabled ?? this.enabled,
      parametersSchema: parametersSchema ?? this.parametersSchema,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'version': version,
      'author': author,
      'category': category,
      'tags': tags,
      'source': source,
      'enabled': enabled,
      'parametersSchema': parametersSchema,
    };
  }

  /// Converts to Claude tool definition format
  Map<String, dynamic> toToolDefinition() {
    return {
      'name': id,
      'description': description,
      'input_schema': parametersSchema ?? {
        'type': 'object',
        'properties': {},
      },
    };
  }
}

/// Skill Requirement model
class SkillRequirement {
  final String type;
  final String value;

  SkillRequirement({
    required this.type,
    required this.value,
  });
}

/// Skill Result model
class SkillResult {
  final bool success;
  final dynamic data;
  final String? error;

  SkillResult({required this.success, this.data, this.error});

  factory SkillResult.success(dynamic data) {
    return SkillResult(success: true, data: data);
  }

  factory SkillResult.error(String error) {
    return SkillResult(success: false, error: error);
  }
}

/// Requirements Check model
class RequirementsCheck {
  final bool success;
  final String? error;

  RequirementsCheck({required this.success, this.error});

  factory RequirementsCheck.success() {
    return RequirementsCheck(success: true);
  }

  factory RequirementsCheck.failed(String error) {
    return RequirementsCheck(success: false, error: error);
  }
}

/// Skills Event model
class SkillsEvent {
  final SkillsEventType type;
  final String? skillId;
  final SkillResult? result;
  final String? error;

  SkillsEvent({
    required this.type,
    this.skillId,
    this.result,
    this.error,
  });

  factory SkillsEvent.skillLoaded(String skillId) =>
      SkillsEvent(type: SkillsEventType.loaded, skillId: skillId);

  factory SkillsEvent.skillExecuting(String skillId) =>
      SkillsEvent(type: SkillsEventType.executing, skillId: skillId);

  factory SkillsEvent.skillExecuted(String skillId, SkillResult result) =>
      SkillsEvent(type: SkillsEventType.executed, skillId: skillId, result: result);

  factory SkillsEvent.skillError(String skillId, String error) =>
      SkillsEvent(type: SkillsEventType.error, skillId: skillId, error: error);

  factory SkillsEvent.skillInstalled(String skillId) =>
      SkillsEvent(type: SkillsEventType.installed, skillId: skillId);

  factory SkillsEvent.skillUninstalled(String skillId) =>
      SkillsEvent(type: SkillsEventType.uninstalled, skillId: skillId);

  factory SkillsEvent.skillToggled(String skillId, bool enabled) =>
      SkillsEvent(type: SkillsEventType.toggled, skillId: skillId);
}

/// Skills Event Type enum
enum SkillsEventType {
  loaded,
  executing,
  executed,
  error,
  installed,
  uninstalled,
  toggled,
}

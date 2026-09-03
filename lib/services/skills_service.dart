import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'preferences_service.dart';
import 'gateway_skill_proxy.dart';
import 'openclaw_service.dart';
import 'native_bridge.dart';
import 'base_service.dart';
import 'sibyl_memory_service.dart';
import 'guardian_policy_engine.dart';
import 'gateway_service.dart';
import 'skill_workspace.dart';
import 'avatar_gesture_catalog.dart';
import 'clawhub_service.dart';
import '../constants/openclaw_paths.dart';
import 'native_clawhub_skill_installer.dart';
import 'gifgrep_contract.dart';
import 'external_financial_skill_policy.dart';

/// Skills System — Thin UI + Native Bridge architecture.
/// This service acts as the UI manager and execution router for on-device native
/// skills, while delegating marketplace/package mutation to the selected
/// Gateway owner. Native owner can read bundled/already-installed skills but
/// performs ClawHub skill mutation through direct native workspace installs
/// instead of opening a mobile OpenClaw shell.
class SkillsService {
  static final SkillsService _instance = SkillsService._internal();
  factory SkillsService() => _instance;
  SkillsService._internal();

  final Logger _logger = Logger();
  final Map<String, Skill> _skills = {};
  final StreamController<SkillsEvent> _eventController =
      StreamController.broadcast();
  final PreferencesService _prefs = PreferencesService();

  static const Map<String, String> _skillIdAliases = {
    'avatar_control': 'avatar-control',
    'avatar control': 'avatar-control',
    'tts_voice': 'tts-voice',
    'tts voice': 'tts-voice',
    'device_node': 'device-node',
    'device node': 'device-node',
    'avatar-overlay': 'avatar_overlay',
    'avatar overlay': 'avatar_overlay',
    'base_chain': 'base-chain',
    'base chain': 'base-chain',
    'base_wallet': 'base-chain',
    'base wallet': 'base-chain',
    'twilio': 'twilio-voice',
    'twilio_voice': 'twilio-voice',
    'twilio voice': 'twilio-voice',
    'agent_card': 'agent-card',
    'agentcard': 'agent-card',
    'agent card': 'agent-card',
    'molt_launch': 'molt-launch',
    'moltlaunch': 'molt-launch',
    'molt launch': 'molt-launch',
    'valeo': 'valeo-sentinel',
    'valeo_sentinel': 'valeo-sentinel',
    'valeo sentinel': 'valeo-sentinel',
    'moon pay': 'moonpay',
    'blogwatcher_check': 'blogwatcher',
    'blogwatcher.check': 'blogwatcher',
    'discord_me': 'discord',
    'discord me': 'discord',
    'discord.me': 'discord',
    'discord_status': 'discord',
    'discord status': 'discord',
    'discord.status': 'discord',
    'eightctl_status': 'eightctl',
    'eightctl.status': 'eightctl',
    'eightctl whoami': 'eightctl',
    'eightctl_whoami': 'eightctl',
    'eightctl.whoami': 'eightctl',
    'eightctl device info': 'eightctl',
    'eightctl_device_info': 'eightctl',
    'eightctl.device-info': 'eightctl',
    'session_logs': 'session-logs',
    'session_logs_query': 'session-logs',
    'session-logs.query': 'session-logs',
    'nano_pdf': 'nano-pdf',
    'nano_pdf_extract': 'nano-pdf',
    'nano-pdf.extract': 'nano-pdf',
    'camera_snap': 'camsnap',
    'camera snap': 'camsnap',
    'camera.snapshot': 'camsnap',
    'camera snap skill': 'camsnap',
    'xurl_request': 'xurl',
    'xurl.request': 'xurl',
    'summarize_text': 'summarize',
    'summarize.text': 'summarize',
    'trello_boards': 'trello',
    'trello boards': 'trello',
    'trello.boards': 'trello',
    'github_user': 'github',
    'github user': 'github',
    'github.user': 'github',
    'gh_issues': 'gh-issues',
    'gh issues': 'gh-issues',
    'gh_issues_list': 'gh-issues',
    'gh-issues.list': 'gh-issues',
    'github_issues': 'gh-issues',
    'github issues': 'gh-issues',
    'goplaces_search': 'goplaces',
    'goplaces.search': 'goplaces',
    'google_places': 'goplaces',
    'google places': 'goplaces',
    'places_search': 'goplaces',
    'mcporter_health': 'mcporter',
    'mcporter health': 'mcporter',
    'mcporter.health': 'mcporter',
    'mcporter_status': 'mcporter',
    'mcporter status': 'mcporter',
    'mcporter.status': 'mcporter',
    'notion_search': 'notion',
    'notion search': 'notion',
    'notion.search': 'notion',
    'openai_whisper_api': 'openai-whisper-api',
    'openai whisper api': 'openai-whisper-api',
    'openai-whisper-api.transcribe': 'openai-whisper-api',
    'openai_whisper_api_transcribe': 'openai-whisper-api',
    'slack_me': 'slack',
    'slack me': 'slack',
    'slack.me': 'slack',
    'slack_status': 'slack',
    'slack status': 'slack',
    'slack.status': 'slack',
    'slack_post': 'slack',
    'slack post': 'slack',
    'slack.post': 'slack',
    '1password_vaults': '1password',
    '1password.vaults': '1password',
    'onepassword': '1password',
    'onepassword_vaults': '1password',
    'onepassword.vaults': '1password',
    'op': '1password',
    'op_vaults': '1password',
    'op.vaults': '1password',
    'gemini_models': 'gemini',
    'gemini.models': 'gemini',
    'gemini_status': 'gemini',
    'gemini.status': 'gemini',
    'gemini_generate': 'gemini',
    'gemini.generate': 'gemini',
    'sag_voices': 'sag',
    'sag.voices': 'sag',
    'sag_status': 'sag',
    'sag.status': 'sag',
    'sag_speak': 'sag',
    'sag.speak': 'sag',
    'sag_tts': 'sag',
    'sag.tts': 'sag',
    'spotify': 'spotify-player',
    'spotify_player': 'spotify-player',
    'spotify profile': 'spotify-player',
    'spotify_profile': 'spotify-player',
    'spotify.profile': 'spotify-player',
    'spotify-player.profile': 'spotify-player',
    'spotify currently playing': 'spotify-player',
    'spotify_currently_playing': 'spotify-player',
    'spotify.currently-playing': 'spotify-player',
    'spotify-player.currently-playing': 'spotify-player',
  };

  Stream<SkillsEvent> get events => _eventController.stream;
  Map<String, Skill> get skills => Map.unmodifiable(_skills);

  String _canonicalSkillId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    return _skillIdAliases[lower] ?? lower;
  }

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
  ///
  /// Workstream A + C interconnection (One-Go plan):
  /// - Paths given to the agent/gateway must use the result of workspaceRelativeSkillDoc(id)
  ///   (never bundle package paths under full-openclaw or node_modules/openclaw/skills).
  /// - On fullSync we also surface receipt-based provisioning state so the gateway knows
  ///   many asset lanes can now be skipped on future restarts (directly mitigates Flaw 3 storms).
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
      await OpenClawCommandService.runCliForActiveOwner(
        command,
        timeout: timeout,
      );
    } catch (e) {
      _logger.w('Could not $description: $e');
    }
  }

  void _loadBundledNativeSkills() {
    final bundled = [
      _createAvatarControlSkill(),
      _createTtsVoiceSkill(),
      _createDeviceNodeSkill(),
      _createBlogWatcherSkill(),
      _createGifgrepSkill(),
      _createDiscordSkill(),
      _createEightCtlSkill(),
      _createSlackSkill(),
      _createOnePasswordSkill(),
      _createGeminiSkill(),
      _createSessionLogsSkill(),
      _createNanoPdfSkill(),
      _createCamsnapSkill(),
      _createGithubSkill(),
      _createGhIssuesSkill(),
      _createGoPlacesSkill(),
      _createMcPorterSkill(),
      _createNotionSkill(),
      _createSagSkill(),
      _createSpotifySkill(),
      _createOpenAiWhisperApiSkill(),
      _createAvatarOverlaySkill(),
      _createBaseChainSkill(),
      // Partner proxies
      _createTwilioSkill(),
      _createAgentCardSkill(),
      _createMoltLaunchSkill(),
      _createValeoSkill(),
      _createMoonPaySkill(),
      _createXurlSkill(),
      _createSummarizeSkill(),
      _createTrelloSkill(),
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
    final canonicalSkillId = _canonicalSkillId(skillId);
    final skill = _skills[canonicalSkillId];
    if (skill == null) {
      return SkillResult.error('Skill not found: $skillId');
    }
    if (!skill.enabled) {
      return SkillResult.error('Skill is disabled: $canonicalSkillId');
    }

    try {
      _eventController.add(SkillsEvent.skillExecuting(canonicalSkillId));
      final result =
          await _executeSkillLogic(skill, parameters ?? {}, context ?? {});
      _eventController.add(SkillsEvent.skillExecuted(canonicalSkillId, result));
      return result;
    } catch (e) {
      _logger.e('Execution failed: $e');
      _eventController
          .add(SkillsEvent.skillError(canonicalSkillId, e.toString()));
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
      case 'feed':
        return await _executeBlogWatcherSkill(skill, params, ctx);
      case 'gifgrep':
        return await _executeGifgrepSkill(skill, params, ctx);
      case 'discord':
        return await _executeDiscordSkill(skill, params, ctx);
      case 'eightctl':
        return await _executeEightCtlSkill(skill, params, ctx);
      case 'slack':
        return await _executeSlackSkill(skill, params, ctx);
      case 'session':
        return await _executeSessionLogsSkill(skill, params, ctx);
      case 'pdf':
        return await _executeNanoPdfSkill(skill, params, ctx);
      case 'device':
        return await _executeDeviceNodeSkill(skill, params, ctx);
      case 'camera':
        return await _executeCamsnapSkill(skill, params, ctx);
      case 'github':
        return await _executeGithubSkill(skill, params, ctx);
      case 'places':
        return await _executeGoPlacesSkill(skill, params, ctx);
      case 'mcporter':
        return await _executeMcPorterSkill(skill, params, ctx);
      case 'notion':
        return await _executeNotionSkill(skill, params, ctx);
      case 'openai':
        return await _executeOpenAiWhisperApiSkill(skill, params, ctx);
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
      case 'http':
        return await _executeHttpSkill(skill, params, ctx);
      case 'summary':
        return await _executeSummarizeSkill(skill, params, ctx);
      case 'trello':
        return await _executeTrelloSkill(skill, params, ctx);
      default:
        return SkillResult.error('No executor for category: ${skill.category}');
    }
  }

  /// Installs a skill via the OpenClaw CLI and triggers a forensic awareness sync.
  Future<bool> installSkill(String id, {bool silent = false}) async {
    final report = await installSkillDetailed(id, silent: silent);
    return report.ok;
  }

  Future<SkillInstallReport> installSkillDetailed(
    String id, {
    bool silent = false,
  }) async {
    final installBlock = ExternalFinancialSkillPolicy.installBlockReason(id);
    if (installBlock != null) {
      if (!silent) _broadcast(SkillsEvent.skillError(id, installBlock));
      return SkillInstallReport(
        ok: false,
        id: id,
        message: 'error: $installBlock',
        error: installBlock,
      );
    }
    try {
      if (!silent) _broadcast(SkillsEvent.skillInstalling(id));
      final nativeOwner = await OpenClawCommandService.isNativeOwnerSelected();
      _logger.i(
          'Installing skill $id via ${nativeOwner ? 'native' : 'PRoot'} owner');

      if (nativeOwner) {
        final result = await NativeClawHubSkillInstaller.instance
            .install(id)
            .timeout(const Duration(seconds: 90));
        if (!result.ok) {
          throw UnsupportedError(
              result.error ?? 'Native skill install failed.');
        }
        await ensureAgentAwareness(fullSync: false);
        if (!silent) _broadcast(SkillsEvent.skillInstalled(id));
        final provisioningMessage =
            _nativeProvisioningInstallMessage(result.provisioning);
        return SkillInstallReport(
          ok: true,
          id: result.slug,
          message: result.alreadyInstalled
              ? 'Native workspace skill ${result.slug} is already installed$provisioningMessage'
              : 'Installed native workspace skill ${result.slug}@${result.version ?? 'latest'}$provisioningMessage',
          targetPath: result.targetPath,
          provisioning: result.provisioning,
        );
      }

      final result = await OpenClawCommandService.runCliForActiveOwner(
        '$kOpenClawCommand skills install $id',
      );

      if (result.contains('Error')) {
        throw Exception(result);
      }

      await ensureAgentAwareness(fullSync: true);

      if (!silent) _broadcast(SkillsEvent.skillInstalled(id));
      return SkillInstallReport(
        ok: true,
        id: id,
        message: result,
      );
    } catch (e) {
      if (!silent) _broadcast(SkillsEvent.skillError(id, e.toString()));
      _logger.e('Skill install failed for $id: $e');
      return SkillInstallReport(
        ok: false,
        id: id,
        message: 'error: $e',
        error: e.toString(),
      );
    }
  }

  String _nativeProvisioningInstallMessage(Map<String, dynamic>? provisioning) {
    if (provisioning == null) return '';
    final counts = provisioning['summaryCounts'];
    final blocked = provisioning['blockedCount'];
    if (counts is! Map) return '';
    final ready = counts['ready'] ?? 0;
    final satisfied = counts['satisfied'] ?? 0;
    final blockedCount = blocked is num ? blocked.toInt() : 0;
    if (blockedCount == 0) {
      return ' (Native readiness ok: ready=$ready satisfied=$satisfied)';
    }
    final summary = counts.entries
        .where((entry) => entry.key != 'ready' && entry.key != 'satisfied')
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    return summary.isEmpty
        ? ' (Native provisioning requires attention)'
        : ' (Native provisioning needs attention: $summary)';
  }

  /// Uninstalls a skill via the OpenClaw CLI and triggers a forensic awareness sync.
  Future<bool> uninstallSkill(String id, {bool silent = false}) async {
    try {
      if (await OpenClawCommandService.isNativeOwnerSelected()) {
        final result = await NativeClawHubSkillInstaller.instance.uninstall(id);
        if (!result.ok) {
          throw UnsupportedError(
            result.error ?? 'Native skill uninstall failed.',
          );
        }
        await ensureAgentAwareness(fullSync: false);
        if (!silent) _broadcast(SkillsEvent.skillUninstalled(id));
        return true;
      }

      final result = await OpenClawCommandService.runCliForActiveOwner(
        '$kOpenClawCommand skills uninstall $id',
      );

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
      if (await OpenClawCommandService.isNativeOwnerSelected()) {
        final api = await ClawHubService.instance.infoFromApi(id);
        if (api == null) return null;
        return {
          'id': api.slug,
          'slug': api.slug,
          'name': api.name,
          'description': api.description,
          'version': api.version,
          'author': api.author,
          'source': 'clawhub',
        };
      }

      final output = await OpenClawCommandService.runCliForActiveOwner(
        '$kOpenClawCommand skills info $id --json',
      );
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
    if (profile != null) {
      // Workstream A safeguard: ensure any profile handed to agents/UI includes the
      // canonical workspace-relative doc path (never a bundle absolute path).
      final safeProfile = Map<String, dynamic>.from(profile);
      safeProfile['docPath'] = workspaceRelativeSkillDoc(id);
      safeProfile['workspaceDoc'] = workspaceRelativeSkillDoc(id);
      return safeProfile;
    }

    // 2. Fallback: ClawHub lookup. Native owner uses REST only; PRoot
    // rollback may use the OpenClaw CLI because the shell is intentionally
    // available in that owner.
    try {
      if (await OpenClawCommandService.isNativeOwnerSelected()) {
        final detail = await ClawHubService.instance.infoFromApi(id);
        if (detail != null) {
          final base = {
            'id': detail.slug,
            'name': detail.name,
            'description': detail.description,
            'verified': detail.ownerHandle != null,
            'iconUrl': detail.ownerAvatarUrl,
            'tools': ['ClawHub Skill', 'Gateway Skill Package'],
            'examples': 'Try: "Hey Plawie, use ${detail.name}"',
          };
          // Workstream A: always include safe relative doc path for agent / usage context
          return {
            ...base,
            'docPath': workspaceRelativeSkillDoc(id),
            'workspaceDoc': workspaceRelativeSkillDoc(id),
          };
        }
        throw StateError('ClawHub profile unavailable for $id');
      }

      final result = await OpenClawCommandService.runCliForActiveOwner(
        '$kOpenClawCommand skills info $id --json',
      );
      final decoded = json.decode(result) as Map<String, dynamic>;
      final base = {
        ...decoded,
        'verified': decoded['source'] == 'official',
        'iconUrl': decoded['icon'] ?? decoded['image_url'],
        'tools': decoded['capabilities'] as List? ??
            ['Autonomous Execution', 'Agent Logic Integration'],
        'examples': decoded['examples'] ??
            'Try: "Hey Plawie, use ${decoded['name'] ?? id}"',
      };
      return {
        ...base,
        'docPath': workspaceRelativeSkillDoc(id),
        'workspaceDoc': workspaceRelativeSkillDoc(id),
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
      final content = await _readLocalSkillMarkdown(id);
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

  Future<String> _readLocalSkillMarkdown(String id) async {
    final filesDir = await NativeBridge.getFilesDir();
    final nativeOwner = await OpenClawCommandService.isNativeOwnerSelected();
    final prootPaths = <String>[
      '$filesDir/rootfs/ubuntu/root/.openclaw/skills/$id/SKILL.md',
      '$filesDir/rootfs/ubuntu/root/.openclaw/workspace/skills/$id/SKILL.md',
      '$filesDir/rootfs/ubuntu/usr/local/lib/node_modules/openclaw/skills/$id/SKILL.md',
    ];
    final nativePaths = <String>[
      '$filesDir/native-node-embedded/native-home/.openclaw/skills/$id/SKILL.md',
      '$filesDir/native-node-embedded/native-home/.openclaw/workspace/skills/$id/SKILL.md',
      // NOTE: This bundle-absolute path MUST never be exposed to the agent
      // context. It is used ONLY for internal existence checks.
      // All agent-facing paths go through SkillWorkspace.relativeDoc().
      '$filesDir/native-node-embedded/full-openclaw/lib/node_modules/openclaw/skills/$id/SKILL.md',
    ];
    final ordered = nativeOwner
        ? <String>[...nativePaths, ...prootPaths]
        : <String>[...prootPaths, ...nativePaths];

    for (final path in ordered) {
      final file = File(path);
      if (!await file.exists()) continue;
      final content = await file.readAsString();
      if (content.trim().isNotEmpty) return content;
    }

    return '';
  }

  /// Returns the canonical, *agent-safe* relative doc path.
  /// Always `skills/<id>/SKILL.md` — never a bundle absolute path.
  String workspaceRelativeSkillDoc(String id) => SkillWorkspace.relativeDoc(id);

  /// Absolute path under the mutable workspace for execution/cwd.
  /// Agent context code MUST use the relative form from workspaceRelativeSkillDoc.
  Future<String> nativeWorkspaceSkillDir(String id) async {
    final filesDir = await NativeBridge.getFilesDir();
    return '$filesDir/native-node-embedded/native-home/.openclaw/workspace/skills/$id';
  }

  // ── Mappings and Executors (Kept for runtime functionality) ───────────────

  Future<SkillResult> _executeAvatarControlSkill(Skill skill,
      Map<String, dynamic> params, Map<String, dynamic> ctx) async {
    final body = Map<String, dynamic>.from(params);
    String action = params['action'] ?? 'get_status';

    if (action == 'play_gesture' || action == 'play_vrma') {
      String? raw = params['assetPath'] ??
          params['path'] ??
          params['vrmaPath'] ??
          params['gesture'] ??
          params['animation'] ??
          params['value'] ??
          params['text'];
      if (raw != null) {
        final resolved = AvatarGestureCatalog.resolve(raw);
        body['action'] = 'play_gesture';
        body['gesture'] = resolved.gesture;
        body['assetPath'] =
            params['assetPath']?.toString().trim().isNotEmpty == true
                ? params['assetPath'].toString()
                : resolved.assetPath;
        body['source'] = params['source'] ?? 'skills-service';
        action = 'play_gesture';
        _eventController.add(SkillsEvent.gesturePlayed(
          base: resolved.assetPath.split('/').last,
          layers: const <String>[],
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

  Future<SkillResult> _executeBlogWatcherSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Blogwatcher fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Blogwatcher unreachable: $e');
    }
  }

  Future<SkillResult> _executeGifgrepSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Gifgrep fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Gifgrep unreachable: $e');
    }
  }

  Future<SkillResult> _executeDiscordSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Discord skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Discord skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeEightCtlSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 35));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('eightctl skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('eightctl skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeSlackSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Slack skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Slack skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeSessionLogsSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Session logs fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Session logs unreachable: $e');
    }
  }

  Future<SkillResult> _executeNanoPdfSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('nano-pdf fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('nano-pdf unreachable: $e');
    }
  }

  Future<SkillResult> _executeCamsnapSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Camsnap fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Camsnap unreachable: $e');
    }
  }

  Future<SkillResult> _executeGithubSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('GitHub skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('GitHub skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeGoPlacesSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Google Places skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Google Places skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeMcPorterSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('MCPorter skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('MCPorter skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeNotionSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Notion skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Notion skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeOpenAiWhisperApiSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 70));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error(
          'OpenAI Whisper API skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('OpenAI Whisper API skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeTrelloSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Trello skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Trello skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeHttpSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('HTTP skill fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('HTTP skill unreachable: $e');
    }
  }

  Future<SkillResult> _executeSummarizeSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    try {
      final resp = await http
          .post(Uri.parse('http://127.0.0.1:8765/api/tools/execute'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'name': s.id, 'input': p}))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return SkillResult.success(jsonDecode(resp.body));
      }
      return SkillResult.error('Summarize fail: ${resp.statusCode}');
    } catch (e) {
      return SkillResult.error('Summarize unreachable: $e');
    }
  }

  Future<SkillResult> _executeAvatarPipSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    final action =
        p['action']?.toString() ?? p['method']?.toString() ?? 'enter';
    if (action == 'get_status' || action == 'status') {
      return SkillResult.success({
        'available': true,
        'status': 'READY',
        'message': 'Avatar overlay PiP channel is registered.',
      });
    }
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
    return _executeGatewayOrNativePartnerSkill(
      skillId: 'twilio-voice',
      defaultMethod: 'get_status',
      params: p,
      nativeAdapter: _twilioNativeAdapter,
    );
  }

  Future<SkillResult> _executeAgentCardSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    final method = p['method']?.toString().trim().isNotEmpty == true
        ? p['method'].toString().trim()
        : 'get_balance';
    if (!ExternalFinancialSkillPolicy.canExecuteAgentCardMethod(method)) {
      return SkillResult.error(
        ExternalFinancialSkillPolicy.executionBlockReason(
          provider: 'AgentCard',
          method: method,
        ),
      );
    }
    return _executeGatewayOrNativePartnerSkill(
      skillId: 'agent-card',
      defaultMethod: 'get_balance',
      params: p,
      nativeAdapter: _agentCardNativeAdapter,
    );
  }

  Future<SkillResult> _executeMoltLaunchSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    return _executeGatewayOrNativePartnerSkill(
      skillId: 'molt-launch',
      defaultMethod: 'get_identity',
      params: p,
      nativeAdapter: _moltLaunchNativeAdapter,
    );
  }

  Future<SkillResult> _executeValeoSkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    return _executeGatewayOrNativePartnerSkill(
      skillId: 'valeo-sentinel',
      defaultMethod: 'get_budget',
      params: p,
      nativeAdapter: _valeoNativeAdapter,
    );
  }

  Future<SkillResult> _executeMoonPaySkill(
      Skill s, Map<String, dynamic> p, Map<String, dynamic> c) async {
    final method = p['method']?.toString().trim().isNotEmpty == true
        ? p['method'].toString().trim()
        : 'get_portfolio';
    if (!ExternalFinancialSkillPolicy.canExecuteMoonPayMethod(method)) {
      return SkillResult.error(
        ExternalFinancialSkillPolicy.executionBlockReason(
          provider: 'MoonPay',
          method: method,
        ),
      );
    }
    return _executeGatewayOrNativePartnerSkill(
      skillId: 'moonpay',
      defaultMethod: 'get_portfolio',
      params: p,
      nativeAdapter: _moonPayNativeAdapter,
    );
  }

  String _skillPageRuntimeError(Object error) {
    final message =
        error is SkillProxyException ? error.message : error.toString();
    if (message.contains('direct skill page execution')) {
      return message;
    }
    return message.replaceFirst(RegExp(r'^SkillProxyException:\s*'), '');
  }

  Future<SkillResult> _executeGatewayOrNativePartnerSkill({
    required String skillId,
    required String defaultMethod,
    required Map<String, dynamic> params,
    required FutureOr<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> params,
    ) nativeAdapter,
  }) async {
    final method = params['method']?.toString().trim().isNotEmpty == true
        ? params['method'].toString().trim()
        : defaultMethod;
    final cleanParams = Map<String, dynamic>.from(params)..remove('method');
    final proxy = GatewaySkillProxy();

    if (proxy.isAttached && proxy.canExecuteGatewaySkills) {
      try {
        final data = await proxy.execute(
          skillId,
          method,
          params: cleanParams,
        );
        return SkillResult.success({
          ...data,
          'skill': skillId,
          'method': method,
          'runtime': 'gateway-skills.execute',
          'gatewaySkillRpcAvailable': true,
        });
      } catch (e) {
        final message = _skillPageRuntimeError(e);
        final shouldFallback =
            message.contains('direct skill page execution') ||
                message.contains('unknown method') ||
                message.contains('skills.execute') ||
                message.contains('not attached');
        if (!shouldFallback) return SkillResult.error(message);
      }
    }

    final data = await nativeAdapter(method, cleanParams);
    return SkillResult.success({
      'skill': skillId,
      'method': method,
      'runtime': 'native-partner-adapter',
      'gatewaySkillRpcAvailable': proxy.canExecuteGatewaySkills,
      ...data,
    });
  }

  Map<String, dynamic> _partnerConfigRequired({
    required String skillId,
    required String method,
    required String provider,
    String? actionRequired,
  }) =>
      {
        'configured': false,
        'connected': false,
        'status': 'CONFIG_REQUIRED',
        'provider': provider,
        'message':
            '$provider is installed as a Plawie skill, but service credentials or its Gateway skill runtime are not configured on this device.',
        'actionRequired': actionRequired ??
            'Open Bot Management > Skills, configure $provider, then retry $skillId.$method.',
      };

  Map<String, dynamic> _twilioNativeAdapter(
      String method, Map<String, dynamic> params) {
    final configured = _partnerConfigRequired(
      skillId: 'twilio-voice',
      method: method,
      provider: 'Twilio Voice',
      actionRequired:
          'Configure Twilio Account SID, Auth Token, phone number, and ConversationRelay webhook.',
    );
    return {
      ...configured,
      'phone_number': '',
      'concurrent_sessions': 0,
      'inbound_count': 0,
      'total_duration_h': 0,
      'transcription_enabled': false,
      'relay_enabled': false,
      'call_logs': const <Map<String, dynamic>>[],
      'requestedEnabled': params['enabled'],
    };
  }

  Map<String, dynamic> _agentCardNativeAdapter(
      String method, Map<String, dynamic> params) {
    final configured = _partnerConfigRequired(
      skillId: 'agent-card',
      method: method,
      provider: 'AgentCard',
      actionRequired:
          'Connect an AgentCard account before card balance, refill, or spend controls can execute.',
    );
    return {
      ...configured,
      'id': '',
      'last4': '----',
      'balance': 0,
      'spendLimit': 0,
      'expiryMonth': '--',
      'expiryYear': '----',
      'network': 'Visa',
      'autoRefill': false,
      'cardholderName': '',
      'requestedEnabled': params['enabled'],
    };
  }

  Future<Map<String, dynamic>> _moltLaunchNativeAdapter(
      String method, Map<String, dynamic> params) async {
    final base = BaseService();
    await base.initialize();
    final hasWallet =
        base.isConnected && (base.address?.trim().isNotEmpty ?? false);
    final config = _partnerConfigRequired(
      skillId: 'molt-launch',
      method: method,
      provider: 'MoltLaunch',
      actionRequired: hasWallet
          ? 'Register this Base wallet with MoltLaunch before accepting jobs.'
          : 'Connect or create a Base wallet before registering with MoltLaunch.',
    );
    if (method == 'get_rep') {
      return {
        ...config,
        'wallet_address': base.address ?? '',
        'reputation': 0,
        'total_jobs_completed': 0,
        'pending_payouts_eth': 0.0,
        'active_gig_list': const <Map<String, dynamic>>[],
      };
    }
    return {
      ...config,
      'wallet_address': base.address ?? '',
      'display_name': '',
      'agent_id': '',
      'verified': false,
      'reputation': 0,
    };
  }

  Map<String, dynamic> _valeoNativeAdapter(
      String method, Map<String, dynamic> params) {
    final config = _partnerConfigRequired(
      skillId: 'valeo-sentinel',
      method: method,
      provider: 'Valeo Sentinel',
      actionRequired:
          'Configure a Valeo Sentinel policy before budget enforcement can approve or block spend.',
    );
    return {
      ...config,
      'budget_cap': 0,
      'current_spend': 0,
      'sentinel_active': false,
      'policy_id': '--',
      'per_call_limit': 0,
      'hourly_limit': 0,
      'daily_limit': 0,
      'lifetime_limit': 0,
      'audit_log': const <Map<String, dynamic>>[],
      'requestedActive': params['active'],
    };
  }

  Map<String, dynamic> _moonPayNativeAdapter(
      String method, Map<String, dynamic> params) {
    final config = _partnerConfigRequired(
      skillId: 'moonpay',
      method: method,
      provider: 'MoonPay',
      actionRequired:
          'Install/configure the MoonPay CLI or Gateway MCP connector before portfolio, price, swap, bridge, buy, sell, or DCA methods can run.',
    );
    return switch (method) {
      'get_price' => {
          ...config,
          'prices': const <Map<String, dynamic>>[],
          'tokens': params['tokens'] ?? params['token'],
        },
      'dca_list' => {
          ...config,
          'strategies': const <Map<String, dynamic>>[],
        },
      _ => {
          ...config,
          'wallets': const <Map<String, dynamic>>[],
          'total_usd': 0,
          'operation': method,
        },
    };
  }

  Future<SkillResult> _executeBaseChainSkill(
      Skill skill, Map<String, dynamic> p, Map<String, dynamic> ctx) async {
    final action = p['action'] ?? 'get_balance';
    final svc = BaseService();
    await svc.initialize();
    final memorySvc = SibylMemoryService();
    await memorySvc.initialize();

    if (!svc.isConnected && action != 'switch_network' && action != 'get_policy' && action != 'set_policy') {
      return SkillResult.success({
        'configured': false,
        'connected': false,
        'status': 'WALLET_NOT_CONNECTED',
        'message':
            'The Plawie wallet is not connected. Create or import it before using wallet actions.',
        'network': svc.networkName,
        'address': '',
        'eth': '0',
        'stablecoin': const <String, String>{'symbol': '', 'balance': '0'},
        'usdc': '0',
        'transactions': const <Map<String, dynamic>>[],
      });
    }
    try {
      switch (action) {
        case 'get_address':
          return SkillResult.success({'address': svc.address});
        case 'get_balance':
          await svc.refreshBalance();
          return SkillResult.success({
            'network': svc.networkName,
            'chainId': svc.chainId,
            'eth': svc.ethBalance.toString(),
            'stablecoin': {
              'symbol': svc.stablecoinSymbol,
              'balance': svc.stablecoinBalance.toString(),
            },
            'usdc': svc.usdcBalance.toString(),
          });
        case 'get_policy':
          final policy = memorySvc.activePolicy;
          final dailySpent = await memorySvc.getDailySpentUsdc();
          return SkillResult.success({
            'policy': policy.toJson(),
            'dailySpentUsdc': dailySpent,
            'summary': policy.toPromptSummary(),
          });
        case 'set_policy':
          final dailyLimit = double.tryParse(p['daily_limit']?.toString() ?? '50') ?? 50.0;
          final singleLimit = double.tryParse(p['single_limit']?.toString() ?? '25') ?? 25.0;
          final recipients = (p['allowed_recipients'] as List?)
                  ?.map((e) => e.toString().toLowerCase().trim())
                  .toList() ??
              <String>[];
          final newPolicy = GuardianPolicy(
            dailyLimitUsdc: dailyLimit,
            singleTxLimitUsdc: singleLimit,
            allowedRecipients: recipients,
          );
          await memorySvc.savePolicy(newPolicy);
          return SkillResult.success({
            'status': 'POLICY_SAVED',
            'policy': newPolicy.toJson(),
            'summary': newPolicy.toPromptSummary(),
          });
        case 'send_eth':
        case 'send_usdc':
        case 'send_usdg':
          final recipient = p['to'].toString();
          final amountDecimal = Decimal.parse(p['amount'].toString());
          final amountUsdc = amountDecimal.toDouble();

          // 1. Guardian Policy Engine Check
          final engine = GuardianPolicyEngine(memoryService: memorySvc);
          final policyResult = await engine.evaluateTransaction(
            action: action,
            recipient: recipient,
            amountUsdc: amountUsdc,
          );

          if (!policyResult.isAllowed) {
            await memorySvc.journalTransaction(BaseTxJournalEntry(
              txHash: '',
              action: action,
              recipient: recipient,
              amountUsdc: amountUsdc,
              status: 'blocked',
              policyDecisionReason: policyResult.reason,
            ));
            return SkillResult.error(policyResult.reason);
          }

          // 2. Visible UI Human Approval Check
          final approval = ctx['baseTransferApproval'];
          if (approval is! BaseTransferApproval) {
            return SkillResult.error(
                'HUMAN_APPROVAL_REQUIRED: Policy check passed (${policyResult.reason}). Please confirm the transfer in the visible Base wallet UI.');
          }

          // 3. Execute Transfer
          final String txHash;
          if (action == 'send_eth') {
            txHash = await svc.sendEth(
              recipient,
              amountDecimal,
              approval: approval,
            );
          } else {
            txHash = await svc.sendUsdc(
              recipient,
              amountDecimal,
              approval: approval,
            );
          }

          // 4. Journal Executed Transaction in Sibyl Memory
          await memorySvc.journalTransaction(BaseTxJournalEntry(
            txHash: txHash,
            action: action,
            recipient: recipient,
            amountUsdc: amountUsdc,
            status: 'executed',
            policyDecisionReason: policyResult.reason,
          ));

          return SkillResult.success({
            'txHash': txHash,
            'status': 'EXECUTED',
            'policyEvaluation': policyResult.toJson(),
          });
        case 'resolve_basename':
          final addr = await svc.resolveBasename(p['name']);
          return SkillResult.success({'address': addr});
        case 'get_history':
          final txs = await svc.fetchHistory(limit: p['limit'] ?? 10);
          return SkillResult.success({'transactions': txs});
        case 'switch_network':
          final requested = p['network']?.toString().trim().toLowerCase();
          final network = switch (requested) {
            'mainnet' || 'base' || 'base_mainnet' => WalletNetwork.baseMainnet,
            'sepolia' || 'base_sepolia' => WalletNetwork.baseSepolia,
            'robinhood' ||
            'robinhood_mainnet' =>
              WalletNetwork.robinhoodMainnet,
            _ => throw const FormatException(
                'Choose mainnet, sepolia, or robinhood.',
              ),
          };
          await svc.setWalletNetwork(network);
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
      description: 'Control Gateway Talk voice output.',
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
      description:
          'Access Android battery, haptics, flashlight, camera, location, and sensors.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'device',
      tags: ['hardware'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createBlogWatcherSkill() => Skill(
      id: 'blogwatcher',
      name: 'blogwatcher',
      description:
          'Check RSS or Atom feeds with a bounded app-native HTTP adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'feed',
      tags: ['rss', 'atom', 'feed'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createGifgrepSkill() => Skill(
      id: 'gifgrep',
      name: 'gifgrep',
      description:
          'Search GIFs through the verified Android CLI or render local GIF stills and sheets without a provider key.',
      version: '0.3.0',
      author: 'OpenClaw',
      category: 'gifgrep',
      tags: ['gif', 'search', 'image', 'cli'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createDiscordSkill() => Skill(
      id: 'discord',
      name: 'discord',
      description:
          'Read Discord bot status metadata with a bounded app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'discord',
      tags: ['discord', 'bot', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createEightCtlSkill() => Skill(
      id: 'eightctl',
      name: 'eightctl',
      description:
          'Read Eight Sleep account and device status through the managed Android CLI adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'eightctl',
      tags: ['eight-sleep', 'eightctl', 'cli', 'status'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createSlackSkill() => Skill(
      id: 'slack',
      name: 'slack',
      description:
          'Read Slack bot identity or post bounded channel messages with an app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'slack',
      tags: ['slack', 'bot', 'channel', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createOnePasswordSkill() => Skill(
      id: '1password',
      name: '1password',
      description:
          'Read 1Password Connect vault metadata with an app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'http',
      tags: ['1password', 'connect', 'vaults', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createGeminiSkill() => Skill(
      id: 'gemini',
      name: 'gemini',
      description:
          'List Gemini models or generate bounded text with the app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'http',
      tags: ['gemini', 'google', 'models', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createMcPorterSkill() => Skill(
      id: 'mcporter',
      name: 'mcporter',
      description:
          'Read configured MCPorter health metadata with an app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'mcporter',
      tags: ['mcporter', 'mcp', 'health', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createOpenAiWhisperApiSkill() => Skill(
      id: 'openai-whisper-api',
      name: 'openai-whisper-api',
      description:
          'Transcribe supplied audio bytes with the OpenAI transcription API.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'openai',
      tags: ['openai', 'whisper', 'transcription', 'audio'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createSagSkill() => Skill(
      id: 'sag',
      name: 'sag',
      description:
          'List ElevenLabs voices or synthesize bounded speech with the app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'http',
      tags: ['sag', 'elevenlabs', 'speech', 'tts', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createSpotifySkill() => Skill(
      id: 'spotify-player',
      name: 'spotify-player',
      description:
          'Read Spotify profile and playback metadata with the app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'http',
      tags: ['spotify', 'music', 'profile', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createSessionLogsSkill() => Skill(
      id: 'session-logs',
      name: 'session-logs',
      description:
          'Query app-owned chat session logs with bounded previews and metadata.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'session',
      tags: ['chat', 'session', 'logs'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createNanoPdfSkill() => Skill(
      id: 'nano-pdf',
      name: 'nano-pdf',
      description:
          'Extract bounded text from small text-based PDFs supplied as bytes.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'pdf',
      tags: ['pdf', 'text', 'extract'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createCamsnapSkill() => Skill(
      id: 'camsnap',
      name: 'camsnap',
      description: 'Capture an Android camera still through app-native tools.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'camera',
      tags: ['camera', 'hardware'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createGithubSkill() => Skill(
      id: 'github',
      name: 'github',
      description:
          'Read authenticated GitHub profile metadata with an app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'github',
      tags: ['github', 'rest'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createGhIssuesSkill() => Skill(
      id: 'gh-issues',
      name: 'gh-issues',
      description:
          'List bounded GitHub repository issues with an app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'github',
      tags: ['github', 'issues'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createGoPlacesSkill() => Skill(
      id: 'goplaces',
      name: 'goplaces',
      description:
          'Search Google Places with a bounded app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'places',
      tags: ['google', 'places', 'maps'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createNotionSkill() => Skill(
      id: 'notion',
      name: 'notion',
      description:
          'Search Notion workspace metadata with a bounded app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'notion',
      tags: ['notion', 'workspace', 'rest'],
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
      name: 'AgentCard connector',
      description:
          'Read-only status connector for a separate external virtual card account.',
      version: '1.0.0',
      author: 'Plawie connector',
      category: 'agentcard',
      tags: ['finance', 'read-only', 'external-custody'],
      source: 'bundled-read-only-adapter',
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
      name: 'MoonPay read-only connector',
      description:
          'Read-only portfolio connector for a separate external MoonPay CLI wallet.',
      version: '1.0.0',
      author: 'Plawie connector',
      category: 'moonpay',
      tags: ['finance', 'read-only', 'external-custody'],
      source: 'bundled-read-only-adapter',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createXurlSkill() => Skill(
      id: 'xurl',
      name: 'xurl',
      description: 'Make app-native HTTP requests for GET, HEAD, or POST.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'http',
      tags: ['http', 'network'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createSummarizeSkill() => Skill(
      id: 'summarize',
      name: 'summarize',
      description:
          'Summarize provided text locally with a bounded extractive adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'summary',
      tags: ['summary', 'text'],
      source: 'bundled',
      createdAt: DateTime.now(),
      enabled: true);
  Skill _createTrelloSkill() => Skill(
      id: 'trello',
      name: 'trello',
      description:
          'Read Trello board summaries with a bounded app-native REST adapter.',
      version: '1.0.0',
      author: 'OpenClaw',
      category: 'trello',
      tags: ['trello', 'boards', 'rest'],
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
              'Control Plawie avatar model, facial emotion, speaking style, and exact VRMA gestures. Root/full-body gestures and limb/interaction gestures are separate catalogs.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': [
                  'play_gesture',
                  'play_vrma',
                  'play_vrma_composite',
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
                    'Exact gesture name. Root/full-body examples: dance, spin, greeting, squat, fight, cute, elegant, pose. Limb/interaction examples: wave right, wave left, both wave, bowing 4, sitting, cross leg sit. When the user asks what limb gestures exist, list only limb/interaction names.'
              },
              'durationMs': {
                'type': 'integer',
                'minimum': 250,
                'maximum': 120000,
                'description':
                    'Optional gesture playback duration in milliseconds.'
              },
              'assetPath': {
                'type': 'string',
                'description':
                    'Internal resolved VRMA asset path. Normally omit and use gesture.'
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
              'Speak text aloud or inspect voice status. Gateway Talk handles speech; Android system TTS is a narrow fallback when talk.speak is unavailable or temporarily fails.',
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
              'Use Android hardware: battery, haptics, flashlight, camera, location, and sensors.',
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
                  'flashlight_status',
                  'list_sensors',
                  'read_sensor',
                  'camera_list',
                  'take_photo',
                  'get_location',
                ],
              },
              'sensor_type': {
                'type': 'string',
                'enum': [
                  'list',
                  'accelerometer',
                  'gyroscope',
                  'gyro',
                  'magnetometer',
                  'barometer'
                ],
              },
              'durationMs': {
                'type': 'integer',
                'minimum': 50,
                'maximum': 5000,
                'description': 'Simple haptic duration in milliseconds.',
              },
              'pattern': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description': 'Haptic pattern in milliseconds.',
              },
              'facing': {
                'type': 'string',
                'enum': ['back', 'front'],
                'description': 'Camera facing direction for take_photo.',
              },
            },
            'required': ['action'],
          },
        };
      case 'blogwatcher':
        return {
          'name': skill.id,
          'description':
              'Check RSS or Atom feeds with a bounded app-native HTTP adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'format': 'uri',
                'description': 'Absolute public RSS or Atom feed URL.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 20,
                'description': 'Maximum feed items to return.',
              },
              'knownIds': {
                'type': 'array',
                'items': {'type': 'string'},
                'description': 'Optional item ids or links already seen.',
              },
            },
            'required': ['url'],
          },
        };
      case 'gifgrep':
        return {
          'name': skill.id,
          'description': skill.description,
          'input_schema': GifgrepContract.inputSchema(),
        };
      case 'discord':
        return {
          'name': skill.id,
          'description':
              'Read Discord bot status metadata through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['me', 'status'],
                'description':
                    'Use me or status to read the configured bot metadata.',
              },
            },
            'required': ['action'],
          },
        };
      case 'slack':
        return {
          'name': skill.id,
          'description':
              'Read Slack bot identity or post bounded channel messages through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['me', 'status', 'post'],
                'description':
                    'Use me/status to read bot identity or post to send a channel message.',
              },
              'channel': {
                'type': 'string',
                'description':
                    'Optional Slack channel id or name. Defaults to configured channels.slack.',
              },
              'text': {
                'type': 'string',
                'description': 'Message text. Required when action is post.',
              },
            },
            'required': ['action'],
          },
        };
      case '1password':
        return {
          'name': skill.id,
          'description':
              'Read 1Password Connect vault metadata through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['vaults', 'status'],
                'description':
                    'Use vaults or status to list configured vault metadata.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 50,
                'description': 'Maximum vaults to return.',
              },
            },
            'required': ['action'],
          },
        };
      case 'eightctl':
        return {
          'name': skill.id,
          'description':
              'Read Eight Sleep status using the verified Android eightctl CLI pack.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['status', 'whoami', 'device-info'],
                'description':
                    'Use status for account/device readiness, whoami for account metadata, or device-info for device details.',
              },
            },
            'required': ['action'],
          },
        };
      case 'gemini':
        return {
          'name': skill.id,
          'description':
              'List Gemini models or generate bounded text through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['models', 'status', 'generate'],
                'description':
                    'Use models/status for a safe read, or generate for a bounded generation call.',
              },
              'prompt': {
                'type': 'string',
                'description': 'Text prompt. Required when action is generate.',
              },
              'model': {
                'type': 'string',
                'description': 'Gemini model id. Defaults to gemini-2.0-flash.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 50,
                'description': 'Maximum models to return for models/status.',
              },
            },
            'required': ['action'],
          },
        };
      case 'mcporter':
        return {
          'name': skill.id,
          'description':
              'Read MCPorter health metadata through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['health', 'status'],
                'description':
                    'Use health or status to check the configured MCPorter endpoint.',
              },
            },
            'required': ['action'],
          },
        };
      case 'openai-whisper-api':
        return {
          'name': skill.id,
          'description':
              'Transcribe supplied audio bytes through the OpenAI transcription API.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'audioBase64': {
                'type': 'string',
                'description':
                    'Base64-encoded audio bytes. Maximum 25 MB after decoding.',
              },
              'filename': {
                'type': 'string',
                'description':
                    'Audio filename with extension, for example clip.wav.',
              },
              'model': {
                'type': 'string',
                'enum': [
                  'gpt-4o-mini-transcribe',
                  'gpt-4o-transcribe',
                  'whisper-1'
                ],
                'description':
                    'OpenAI transcription model. Defaults to gpt-4o-mini-transcribe.',
              },
              'language': {
                'type': 'string',
                'description': 'Optional ISO-639-1 language code.',
              },
              'prompt': {
                'type': 'string',
                'description':
                    'Optional short prompt to guide transcription style.',
              },
            },
            'required': ['audioBase64'],
          },
        };
      case 'session-logs':
        return {
          'name': skill.id,
          'description':
              'Query app-owned chat session logs with bounded previews and metadata.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['list', 'read', 'search'],
                'description':
                    'List sessions, read a session, or search message previews.',
              },
              'sessionId': {
                'type': 'string',
                'description':
                    'Optional app chat session id. Defaults to active for read.',
              },
              'query': {
                'type': 'string',
                'description': 'Search text. Required when action is search.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 100,
                'description':
                    'Maximum sessions, messages, or matches to return.',
              },
              'maxMessageChars': {
                'type': 'integer',
                'minimum': 40,
                'maximum': 2000,
                'description': 'Maximum characters per message preview.',
              },
            },
            'required': ['action'],
          },
        };
      case 'nano-pdf':
        return {
          'name': skill.id,
          'description':
              'Extract bounded text from small text-based PDFs supplied as bytes.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'pdfBase64': {
                'type': 'string',
                'description':
                    'Base64-encoded PDF bytes. Small text-based PDFs only.',
              },
              'maxChars': {
                'type': 'integer',
                'minimum': 80,
                'maximum': 20000,
                'description': 'Maximum extracted text characters to return.',
              },
            },
            'required': ['pdfBase64'],
          },
        };
      case 'camsnap':
        return {
          'name': skill.id,
          'description':
              'Capture a still photo through the Android camera capability.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'facing': {
                'type': 'string',
                'enum': ['back', 'front'],
                'description': 'Camera facing direction. Defaults to back.',
              },
              'quality': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 100,
                'description':
                    'Requested JPEG quality hint. The app may clamp or ignore it.',
              },
            },
            'required': [],
          },
        };
      case 'github':
        return {
          'name': skill.id,
          'description':
              'Read authenticated GitHub user profile metadata through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['user'],
                'description': 'Use user to read the authenticated profile.',
              },
            },
            'required': ['action'],
          },
        };
      case 'gh-issues':
        return {
          'name': skill.id,
          'description':
              'List bounded GitHub repository issues through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'owner': {
                'type': 'string',
                'description': 'GitHub repository owner or organization.',
              },
              'repo': {
                'type': 'string',
                'description': 'GitHub repository name.',
              },
              'state': {
                'type': 'string',
                'enum': ['open', 'closed', 'all'],
                'description': 'Issue state. Defaults to open.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 20,
                'description': 'Maximum issues to return.',
              },
            },
            'required': ['owner', 'repo'],
          },
        };
      case 'goplaces':
        return {
          'name': skill.id,
          'description':
              'Search Google Places through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Place search text, for example coffee nearby.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 10,
                'description': 'Maximum places to return.',
              },
              'languageCode': {
                'type': 'string',
                'description': 'Optional BCP-47 language code.',
              },
              'regionCode': {
                'type': 'string',
                'description': 'Optional CLDR region code.',
              },
              'includedType': {
                'type': 'string',
                'description': 'Optional Places type filter.',
              },
            },
            'required': ['query'],
          },
        };
      case 'notion':
        return {
          'name': skill.id,
          'description':
              'Search Notion workspace pages and data sources through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'Search text for Notion workspace results.',
              },
              'object': {
                'type': 'string',
                'enum': ['page', 'data_source'],
                'description':
                    'Optional Notion object filter. Defaults to all searchable objects.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 10,
                'description': 'Maximum results to return.',
              },
              'startCursor': {
                'type': 'string',
                'description': 'Optional Notion pagination cursor.',
              },
            },
            'required': ['query'],
          },
        };
      case 'sag':
        return {
          'name': skill.id,
          'description':
              'List ElevenLabs voices or synthesize bounded speech through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['voices', 'status', 'speak'],
                'description':
                    'Use voices/status for a safe read, or speak to synthesize speech.',
              },
              'text': {
                'type': 'string',
                'description': 'Text to synthesize. Required for speak.',
              },
              'voiceId': {
                'type': 'string',
                'description': 'ElevenLabs voice id returned by sag.voices.',
              },
              'modelId': {
                'type': 'string',
                'description':
                    'Optional ElevenLabs model id. Defaults to eleven_multilingual_v2.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 50,
                'description': 'Maximum voices to return.',
              },
            },
            'required': ['action'],
          },
        };
      case 'spotify-player':
        return {
          'name': skill.id,
          'description':
              'Read Spotify profile or currently playing metadata through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['profile', 'status', 'currently-playing'],
                'description':
                    'Use profile/status for account metadata, or currently-playing for playback metadata.',
              },
            },
            'required': ['action'],
          },
        };
      case 'base-chain':
        return _methodToolDefinition(
          skill,
          description:
              'Use the secured local EVM wallet for Base address, balances, history, spending policy management (set_policy / get_policy), and explicit transfers.',
          methods: const [
            'get_address',
            'get_balance',
            'get_history',
            'resolve_basename',
            'switch_network',
            'send_eth',
            'send_usdc',
            'send_usdg',
            'set_policy',
            'get_policy',
          ],
          extraProperties: const {
            'to': {
              'type': 'string',
              'description': 'Destination wallet address or Basename.',
            },
            'name': {
              'type': 'string',
              'description': 'Basename or address to resolve.',
            },
            'amount': {
              'type': 'string',
              'description': 'Token amount as a decimal string.',
            },
            'daily_limit': {
              'type': 'string',
              'description': 'Maximum cumulative daily spending limit in USDC.',
            },
            'single_limit': {
              'type': 'string',
              'description': 'Maximum single transaction spending limit in USDC.',
            },
            'allowed_recipients': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'List of approved recipient wallet addresses or basenames.',
            },
            'network': {
              'type': 'string',
              'enum': ['mainnet', 'sepolia', 'robinhood'],
            },
            'limit': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 50,
            },
          },
          actionKey: 'action',
        );
      case 'avatar_overlay':
        return _methodToolDefinition(
          skill,
          description:
              'Control or inspect the floating avatar picture-in-picture overlay.',
          methods: const ['get_status', 'enter'],
          actionKey: 'action',
        );
      case 'twilio-voice':
        return _methodToolDefinition(
          skill,
          description:
              'Inspect or configure Twilio ConversationRelay voice-call status.',
          methods: const ['get_status', 'set_relay', 'set_transcription'],
          extraProperties: const {
            'enabled': {'type': 'boolean'},
          },
        );
      case 'agent-card':
        return _methodToolDefinition(
          skill,
          description:
              'Read AgentCard balance/status for a separately configured external account. Plawie cannot create, refill, or spend from it.',
          methods: ExternalFinancialSkillPolicy.agentCardReadMethods,
        );
      case 'molt-launch':
        return _methodToolDefinition(
          skill,
          description:
              'Inspect or register MoltLaunch Base-chain agent identity and work reputation.',
          methods: const ['get_identity', 'get_rep', 'register'],
        );
      case 'valeo-sentinel':
        return _methodToolDefinition(
          skill,
          description:
              'Inspect Valeo Sentinel budget policy, audit log, or policy active state.',
          methods: const ['get_budget', 'get_audit', 'set_policy'],
          extraProperties: const {
            'active': {'type': 'boolean'},
          },
        );
      case 'moonpay':
        return _methodToolDefinition(
          skill,
          description:
              'Read portfolio, token-price, or DCA status from a separately configured external MoonPay CLI wallet. Writes are not exposed.',
          methods: ExternalFinancialSkillPolicy.moonPayReadMethods,
          extraProperties: const {
            'token': {'type': 'string'},
            'tokens': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        );
      case 'xurl':
        return {
          'name': skill.id,
          'description':
              'Make an app-native HTTP request to an absolute http or https URL.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'format': 'uri',
                'description': 'Absolute http or https URL to request.',
              },
              'method': {
                'type': 'string',
                'enum': ['GET', 'HEAD', 'POST'],
                'description': 'HTTP method. Defaults to GET.',
              },
              'headers': {
                'type': 'object',
                'additionalProperties': {'type': 'string'},
                'description': 'Optional request headers.',
              },
              'body': {
                'type': 'string',
                'description': 'Optional request body for POST.',
              },
            },
            'required': ['url'],
          },
        };
      case 'summarize':
        return {
          'name': skill.id,
          'description':
              'Summarize provided text locally with a bounded extractive adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description': 'Text to summarize.',
              },
              'maxSentences': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 8,
                'description': 'Maximum sentences in the summary.',
              },
              'maxChars': {
                'type': 'integer',
                'minimum': 80,
                'maximum': 2000,
                'description': 'Maximum summary characters.',
              },
            },
            'required': ['text'],
          },
        };
      case 'trello':
        return {
          'name': skill.id,
          'description':
              'Read bounded Trello board summaries through the app-native REST adapter.',
          'input_schema': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['boards', 'summary'],
                'description':
                    'Use boards or summary to read configured member boards.',
              },
              'filter': {
                'type': 'string',
                'enum': ['open', 'closed', 'all'],
                'description': 'Board filter. Defaults to open.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 20,
                'description': 'Maximum boards to return.',
              },
            },
            'required': ['action'],
          },
        };
      default:
        return skill.toToolDefinition();
    }
  }

  Map<String, dynamic> _methodToolDefinition(
    Skill skill, {
    required String description,
    required List<String> methods,
    Map<String, dynamic> extraProperties = const {},
    String actionKey = 'method',
  }) {
    return {
      'name': skill.id,
      'description': description,
      'input_schema': {
        'type': 'object',
        'properties': {
          actionKey: {
            'type': 'string',
            'enum': methods,
          },
          ...extraProperties,
        },
        'required': [actionKey],
      },
    };
  }

  /// Returns the list of all registered native skills.
  List<Skill> getSkillsList() {
    return _skills.values.toList();
  }

  /// Returns a specific skill by its ID.
  Skill? getSkill(String id) {
    return _skills[_canonicalSkillId(id)];
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

class SkillInstallReport {
  final bool ok;
  final String id;
  final String message;
  final String? error;
  final String? targetPath;
  final Map<String, dynamic>? provisioning;

  const SkillInstallReport({
    required this.ok,
    required this.id,
    required this.message,
    this.error,
    this.targetPath,
    this.provisioning,
  });
}

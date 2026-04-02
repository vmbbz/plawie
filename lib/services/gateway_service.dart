import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import '../models/agent_info.dart';
import 'gateway_connection.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';
import 'local_llm_service.dart';

/// Ollama Modelfile TEMPLATE directive for Qwen2.5 instruct models.
/// Sourced from the official Ollama Qwen2.5 model card template.
/// Includes {{ .Tools }} support so the gateway agent loop can send
/// function schemas and the model returns structured tool_call JSON.
const _kQwen25OllamaTemplate = r'''
TEMPLATE """{{- if .Messages }}
{{- if or .System .Tools }}<|im_start|>system
{{- if .System }}
{{ .System }}
{{- end }}
{{- if .Tools }}

# Tools

You may call one or more functions to assist with the user query.

You are provided with function signatures within <tools></tools> XML tags:

<tools>
{{- range .Tools }}
{"type": "function", "function": {{ .Function }}}
{{- end }}
</tools>

For each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:

<tool_call>
{"name": <function-name>, "arguments": <args-json-object>}
</tool_call>
{{- end }}<|im_end|>
{{ end }}
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 -}}
{{- if eq .Role "user" }}<|im_start|>user
{{ .Content }}<|im_end|>
{{ else if eq .Role "assistant" }}<|im_start|>assistant
{{ if .Content }}{{ .Content }}
{{- else if .ToolCalls }}
{{- range .ToolCalls }}
<tool_call>
{"name": "{{ .Function.Name }}", "arguments": {{ .Function.Arguments }}}
</tool_call>
{{- end }}
{{- end }}{{- if not $last }}<|im_end|>
{{ end }}
{{- else if eq .Role "tool" }}<|im_start|>user
<tool_response>
{{ .Content }}
</tool_response><|im_end|>
{{ end }}
{{- end }}
{{- else }}
{{- if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
{{ end }}"""
PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
PARAMETER num_ctx 4096
PARAMETER num_thread 4
''';

class GatewayService {
  static final GatewayService _instance = GatewayService._internal();
  factory GatewayService() => _instance;
  GatewayService._internal();

  Timer? _healthTimer;
  StreamSubscription? _logSubscription;
  GatewayConnection? _connection;
  bool _healthCheckInFlight = false;
  bool _rpcDiscoveryDone = false; // RPC discovery runs once after first WS connect
  final _stateController = StreamController<GatewayState>.broadcast();
  GatewayState _state = const GatewayState();
  bool _isStarting = false;
  bool _isStopping = false;
  static final _tokenUrlRegex = RegExp(r'https?://(?:localhost|127\.0\.0\.1):\d+/[^\s]*[#?]token=[0-9a-fA-F\-]+');
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');

  /// Strip ANSI, box-drawing chars, and whitespace to reconstruct URLs
  /// split by terminal line wrapping or TUI borders.
  static String _cleanForUrl(String text) {
    return text
        .replaceAll(AppConstants.ansiEscape, '')
        .replaceAll(_boxDrawing, '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  Stream<GatewayState> get stateStream => _stateController.stream;
  GatewayState get state => _state;

  void _updateState(GatewayState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  /// List of methods supported by the current gateway connection.
  List<String> get supportedMethods => _connection?.supportedMethods ?? [];

  /// Check if the gateway is already running (e.g. after app restart)
  /// and sync the UI state accordingly.  If not running but auto-start
  /// is enabled, start it automatically.
  /// Check if the gateway is already running (e.g. after app restart)
  /// and sync the UI state accordingly.
  Future<void> init() async {
    final prefs = PreferencesService();
    await prefs.init();
    // Sequence: _attachOrStart first, THEN _probeOllamaOnInit.
    // Both issue PRoot commands; running them concurrently jams the PRoot
    // command queue and causes the auth-token probe to appear hung.
    // Using .then() keeps init() non-blocking (splash screen stays fast)
    // while guaranteeing no overlapping PRoot work.
    unawaited(_attachOrStart(autoStart: prefs.autoStartGateway)
        .then((_) => unawaited(_probeOllamaOnInit())));
  }

  /// Called once at init. If Ollama is already running (e.g. survived app restart),
  /// emit the correct state and re-sync models so the chat dropdown is populated.
  Future<void> _probeOllamaOnInit() async {
    try {
      final running = await NativeBridge.isOllamaRunning();
      if (!running) return;
      _updateState(_state.copyWith(
        isOllamaRunning: true,
        logs: [..._state.logs, '[INFO] Ollama Hub already running — syncing models...'],
      ));
      await syncLocalModelsWithOllama();
    } catch (_) {}
  }

  /// Unified entry point for starting or attaching to the gateway.
  /// Prevents double-spawns and handles self-healing.
  Future<void> _attachOrStart({bool autoStart = false, bool forceStart = false}) async {
    // LOCK: Prevent concurrent start/stop cycles
    if (_isStarting || _isStopping) return;

    final prefs = PreferencesService();
    await prefs.init();

    // 1. ALWAYS check if already running and attach if so
    final alreadyRunning = await NativeBridge.isGatewayRunning();

    if (alreadyRunning) {
      if (_state.status == GatewayStatus.running) return; // Already fully attached

      _updateState(_state.copyWith(
        status: GatewayStatus.starting,
        logs: [..._state.logs, '[INFO] Gateway process detected, attaching...'],
      ));

      // Fix the config on disk (removes stale keys, ensures required fields),
      // then run openclaw doctor --fix as a belt-and-suspenders pass in case
      // any keys survived our manual sanitisation, then reload.
      try {
        await _configureGateway();
        await NativeBridge.runInProot(
          'openclaw doctor --fix 2>/dev/null || true',
          timeout: 10,
        );
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && '
          'openclaw reload 2>/dev/null || true',
          timeout: 5,
        );
      } catch (_) {}

      // After openclaw reload the gateway may issue a new token — wipe the
      // cache and existing WS object so _checkHealth() re-probes fresh.
      _connection?.dispose();
      _connection = null;
      _cachedToken = null;
      _lastTokenFetch = null;

      _subscribeLogs();
      _startHealthCheck();
      unawaited(_checkHealth());
      unawaited(fetchAuthenticatedDashboardUrl(force: true).catchError((_) => null));
      return;
    }

    // 2. Not running. POLICY: Should we spawn a NEW one?
    if (!autoStart && !forceStart) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[DEBUG] Gateway not running. Auto-start is off.']
      ));
      return;
    }

    final savedUrl = prefs.dashboardUrl;

    // Attempting a fresh start
    _isStarting = true;
    _rpcDiscoveryDone = false; // ensure discovery runs on this new session
    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      clearError: true,
      logs: [..._state.logs, '[INFO] Starting gateway...'],
      dashboardUrl: savedUrl,
    ));

    try {
      await NativeBridge.acquirePartialWakeLock();
      await _configureGateway();
      await Future.delayed(const Duration(milliseconds: 300));

      final success = await NativeBridge.startGateway();

      if (!success) {
        throw Exception('Native start failed.');
      }

      // Warn user if battery optimization is active — Android can kill PRoot.
      // Fire-and-forget: showing the dialog must NOT block _startHealthCheck().
      // If requestBatteryOptimization() uses startActivityForResult it can wait
      // indefinitely, stalling the health timer from ever starting.
      unawaited(() async {
        try {
          final isOptimized = await NativeBridge.isBatteryOptimized();
          if (isOptimized) {
            _updateState(_state.copyWith(
              logs: [..._state.logs, '[WARN] Battery Optimization is ACTIVE — may kill gateway in background.'],
            ));
            await NativeBridge.requestBatteryOptimization();
          }
        } catch (_) {}
      }());

      await Future.delayed(const Duration(milliseconds: 500));
      _subscribeLogs();
      _startHealthCheck();
      // Probe immediately — same as the attach path — so we don't wait a full
      // 15s timer tick before discovering the gateway is already responding.
      unawaited(_checkHealth());
      unawaited(fetchAuthenticatedDashboardUrl(force: true).catchError((_) => null));
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to start: $e',
        logs: [..._state.logs, '[ERROR] Failed to start: $e'],
      ));
    } finally {
      _isStarting = false;
    }
  }

  Future<void> start() async {
    await _attachOrStart(forceStart: true);
  }

  void _subscribeLogs() {
    _logSubscription?.cancel();
    _logSubscription = NativeBridge.gatewayLogStream.listen((log) {
      final logs = [..._state.logs, log];
      if (logs.length > 500) {
        logs.removeRange(0, logs.length - 500);
      }
      String? dashboardUrl;
      final cleanLog = _cleanForUrl(log);
      final urlMatch = _tokenUrlRegex.firstMatch(cleanLog);
      if (urlMatch != null) {
        dashboardUrl = urlMatch.group(0);
        final prefs = PreferencesService();
        prefs.init().then((_) => prefs.dashboardUrl = dashboardUrl);
        _updateState(_state.copyWith(logs: logs, dashboardUrl: dashboardUrl));
      } else {
        _updateState(_state.copyWith(logs: logs));
      }
    });
  }

  /// Helper to get the host-side path to the openclaw config file.
  /// Must match the PRoot ubuntu rootfs: $filesDir/rootfs/ubuntu/root/...
  Future<String> _openClawConfigPath() async {
    final filesDir = await NativeBridge.getFilesDir();
    return '$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json';
  }

  /// Direct Dart-native config read/write (bypasses proot overhead)
  Future<Map<String, dynamic>> _readConfig() async {
    try {
      final file = File(await _openClawConfigPath());
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[GatewayService] Config read error: $e');
    }
    return {};
  }

  Future<void> _writeConfig(Map<String, dynamic> config) async {
    try {
      final path = await _openClawConfigPath();
      final file = File(path);
      
      // Ensure directory exists
      final dir = Directory(file.parent.path);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      await file.writeAsString(jsonEncode(config));
    } catch (e) {
      debugPrint('[GatewayService] Config write error: $e');
    }
  }

  /// Direct I/O: configure gateway binding and node per AidanPark optimization
  Future<void> _configureGateway() async {
    final config = await _readConfig();
    
    config['gateway'] ??= {};
    config['gateway']['nodes'] ??= {};
    config['gateway']['nodes']['denyCommands'] = [];
    config['gateway']['nodes']['allowCommands'] = [
      'camera.snap', 'camera.clip', 'camera.list',
      'canvas.navigate', 'canvas.eval', 'canvas.snapshot',
      'flash.on', 'flash.off', 'flash.toggle', 'flash.status',
      'location.get',
      'screen.record',
      'sensor.read', 'sensor.list',
      'haptic.vibrate',
    ];
    config['gateway']['mode'] = 'local';
    
    // Enable the OpenAI-compatible REST endpoints on port 18789.
    config['gateway']['http'] ??= {};
    config['gateway']['http']['endpoints'] ??= {};
    config['gateway']['http']['endpoints']['chatCompletions'] ??= {};
    config['gateway']['http']['endpoints']['chatCompletions']['enabled'] = true;

    // Ollama Default Provider — always ensure models array is present.
    config['models'] ??= {};
    config['models']['providers'] ??= {};
    config['models']['providers']['ollama'] ??= <String, dynamic>{};
    final ollama = config['models']['providers']['ollama'] as Map<String, dynamic>;
    ollama['baseUrl'] ??= 'http://127.0.0.1:11434';
    ollama['apiKey'] ??= 'ollama-local';
    ollama['api'] ??= 'ollama';
    // Schema requires models to always be an array. Fix any existing entry missing it.
    ollama['models'] ??= <Map<String, dynamic>>[];

    // Remove keys that have never been part of the OpenClaw schema.
    // These were written by earlier builds and must be stripped so the gateway
    // passes schema validation instead of running in best-effort mode.
    final agentsDefaults = config['agents']?['defaults'];
    if (agentsDefaults is Map) {
      agentsDefaults.remove('provider');          // not in agents.defaults schema
    }
    final skills = config['skills'];
    if (skills is Map) {
      skills.remove('discovery');                 // not in skills schema
      skills.remove('mode');                      // not in skills schema
      skills.remove('sync');                      // not in skills schema
      if (skills.isEmpty) config.remove('skills'); // don't leave empty block
    }

    await _writeConfig(config);
  }

  /// Register Ollama as the gateway provider and optionally set it as primary.
  ///
  /// [syncedModels] — list of Ollama model names (e.g. "qwen2-5-0-5b:latest")
  /// that were successfully synced. Written to openclaw.json so the gateway
  /// exposes them on /v1/models. Pass empty list to skip updating the model list.
  Future<void> configureOllama({
    String baseUrl = 'http://127.0.0.1:11434',
    String? primaryModel,
    bool setAsPrimary = true,
    List<String> syncedModels = const [],
  }) async {
    final config = await _readConfig();
    config['models'] ??= {};
    config['models']['providers'] ??= {};
    final ollamaConfig = <String, dynamic>{
      'baseUrl': baseUrl,
      'apiKey': 'ollama-local',
      'api': 'ollama',
      // Schema requires models to always be an array (never undefined).
      'models': syncedModels.map((n) => {'id': n, 'name': n}).toList(),
    };

    config['models']['providers']['ollama'] = ollamaConfig;

    if (setAsPrimary && primaryModel != null) {
      config['agents'] ??= {};
      config['agents']['defaults'] ??= {};
      config['agents']['defaults']['model'] ??= {};
      final fullModel = primaryModel.startsWith('ollama/') ? primaryModel : 'ollama/$primaryModel';
      config['agents']['defaults']['model']['primary'] = fullModel;
      // Persist to Flutter prefs so the chat screen restores it on next open.
      final prefs = PreferencesService();
      await prefs.init();
      prefs.configuredModel = fullModel;
    }

    await _writeConfig(config);
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[INFO] Ollama provider configured at $baseUrl'],
    ));
  }

  /// Probe the Ollama server directly via HTTP.
  Future<bool> checkOllamaHealth({String baseUrl = 'http://127.0.0.1:11434'}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Internal Ollama Management (Integrated Sandbox) ─────────────────

  Future<bool> isInternalOllamaInstalled() async {
    return await NativeBridge.isOllamaInstalled();
  }

  Future<bool> isInternalOllamaRunning() async {
    return await NativeBridge.isOllamaRunning();
  }

  Future<bool> startInternalOllama() async {
    final success = await NativeBridge.startOllama();
    _updateState(_state.copyWith(
      isOllamaRunning: success,
      logs: [..._state.logs, success
          ? '[INFO] Ollama Hub starting — waiting for ready signal...'
          : '[WARN] Ollama start returned failure.'],
    ));
    if (success) {
      // Poll health in the background; auto-sync once Ollama responds.
      unawaited(_waitForOllamaHealthThenSync());
    }
    return success;
  }

  /// Polls :11434 every 3 s for up to 30 s, then triggers model sync.
  /// Runs fire-and-forget after startInternalOllama().
  Future<void> _waitForOllamaHealthThenSync() async {
    const maxAttempts = 10;
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (await checkOllamaHealth()) {
        _updateState(_state.copyWith(
          isOllamaRunning: true,
          logs: [..._state.logs, '[INFO] Ollama Hub ready — auto-syncing models...'],
        ));
        await syncLocalModelsWithOllama();
        return;
      }
    }
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[WARN] Ollama Hub did not respond after 30 s — check logs.'],
    ));
  }

  /// Extracts diagnostic logs from the integrated Ollama hub.
  Future<String> _getOllamaLogsInternal() async {
    try {
      final logs = await NativeBridge.runInProot(
        'cat /root/.openclaw/ollama.log 2>/dev/null || echo "[No Hub logs found]"',
        timeout: 5,
      );
      final lines = logs.split('\n');
      if (lines.length <= 100) return logs;
      return lines.sublist(lines.length - 100).join('\n');
    } catch (e) {
      return 'Failed to fetch hub logs: $e';
    }
  }

  Future<String> getOllamaLogs() => _getOllamaLogsInternal();

  /// Removes Ollama registrations that belong to OUR GGUFs but use a stale
  /// name format (e.g., dots replaced with dashes from a previous build).
  /// Identified by stripping all punctuation and comparing the result.
  Future<void> _cleanupStaleOllamaRegistrations(Set<String> canonicalNames) async {
    final registered = await _getRegisteredOllamaModels();
    for (final name in registered) {
      if (canonicalNames.contains(name)) continue; // already canonical — keep
      final stripped = name.replaceAll(RegExp(r'[.\-_:]'), '').toLowerCase();
      final isOurs = canonicalNames.any(
        (c) => c.replaceAll(RegExp(r'[.\-_:]'), '').toLowerCase() == stripped,
      );
      if (!isOurs) continue;
      // Old-format registration for a model we own — delete it.
      try {
        await http
            .delete(
              Uri.parse('http://127.0.0.1:11434/api/delete'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'model': name}),
            )
            .timeout(const Duration(seconds: 10));
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[HUB] Removed stale registration: $name'],
        ));
      } catch (_) {}
    }
  }

  Future<void> syncLocalModelsWithOllama() async {
    final catalog = LocalLlmService().catalog;

    // Safety check: is Ollama actually reachable?
    if (!await isInternalOllamaRunning()) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[ERROR] Cannot sync: Integrated Hub is OFFLINE.'],
      ));
      return;
    }

    // Log Ollama version for diagnostics.
    final version = await getOllamaVersion();
    if (version != null) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[INFO] Ollama version: $version'],
      ));
    }

    _updateState(_state.copyWith(
      logs: [..._state.logs, '[INFO] Scanning for local GGUF models...'],
    ));

    // Compute canonical names for all downloaded GGUFs, then clean up any
    // old-format registrations (from previous builds with different naming).
    final canonicalNames = <String>{};
    for (final m in catalog) {
      if (await LocalLlmService().isModelDownloaded(m)) {
        canonicalNames.add(_toOllamaModelName(m.id));
      }
    }
    await _cleanupStaleOllamaRegistrations(canonicalNames);

    // Pre-fetch registered models to skip re-hashing on every startup.
    final registered = await _getRegisteredOllamaModels();

    int synced = 0;
    final syncedModelNames = <String>[]; // collect for gateway config + state emit

    for (final model in catalog) {
      if (await LocalLlmService().isModelDownloaded(model)) {
        final ollamaName = _toOllamaModelName(model.id);
        // Always re-create: ensures num_ctx/num_thread params from the current
        // Modelfile are applied. ollama create reuses the existing GGUF blob
        // (no re-hashing) so this is fast.
        if (registered.contains(ollamaName)) {
          _updateState(_state.copyWith(
            logs: [..._state.logs, '[HUB] Refreshing $ollamaName params...'],
          ));
        }
        try {
          final success = await _createOllamaModelFromGguf(
            ollamaName, model.prootModelPath,
            supportsToolCalls: model.supportsToolCalls,
          );
          if (success) {
            synced++;
            syncedModelNames.add(ollamaName);
            _updateState(_state.copyWith(
              logs: [..._state.logs, '[INFO] Registered ${model.id} as $ollamaName.'],
            ));
          } else {
            _updateState(_state.copyWith(
              logs: [..._state.logs, '[WARN] Hub rejected $ollamaName (catalog: ${model.id}).'],
            ));
          }
        } catch (e) {
          _updateState(_state.copyWith(
            logs: [..._state.logs, '[ERROR] Sync error for ${model.id}: $e'],
          ));
        }
      }
    }

    _updateState(_state.copyWith(
      logs: [..._state.logs, '[INFO] Hub Sync Done. $synced models available.'],
    ));

    // Write synced models into openclaw.json and emit to state.
    // Auto-select the first synced model only if the user isn't already on a
    // local model — avoids silently hijacking an explicit cloud preference.
    if (syncedModelNames.isNotEmpty) {
      final prefs = PreferencesService();
      await prefs.init();
      final currentModel = prefs.configuredModel ?? '';
      final alreadyLocal = currentModel.startsWith('ollama/') ||
          currentModel.startsWith('local-llm/');

      await configureOllama(
        syncedModels: syncedModelNames,
        primaryModel: alreadyLocal ? null : syncedModelNames.first,
        setAsPrimary: !alreadyLocal,
      );

      _updateState(_state.copyWith(
        isOllamaRunning: true,
        ollamaHubModels: syncedModelNames,
      ));
    }
  }

  /// Converts a catalog model ID to a valid Ollama model name.
  ///
  /// Ollama validates names via round-trip: ParseNameBestEffort(name).String()
  /// must equal the original input. Short names like "model:latest" fail because
  /// Ollama fills in the registry prefix, making String() return
  /// "registry.ollama.ai/library/model:latest" which doesn't match "model:latest".
  ///
  /// Strategy: split on the quantization suffix (e.g. "-q4_k_m") to produce
  /// a proper model:tag pair. Dots are preserved because Ollama natively uses
  /// them (e.g. qwen2.5:7b). Underscores are kept in the tag (valid there).
  ///
  /// Examples:
  ///   qwen2.5-0.5b-instruct-q4_k_m  →  qwen2.5-0.5b-instruct:q4_k_m
  ///   qwen2.5-1.5b-instruct-q4_k_m  →  qwen2.5-1.5b-instruct:q4_k_m
  String _toOllamaModelName(String catalogId) {
    final id = catalogId.toLowerCase();
    // Find the quantization suffix: last occurrence of "-q<digit>" pattern.
    final qMatch = RegExp(r'-q(\d)').allMatches(id).lastOrNull;
    if (qMatch != null) {
      final modelPart = id.substring(0, qMatch.start);
      final tagPart = id.substring(qMatch.start + 1); // strip leading '-'
      return '$modelPart:$tagPart';
    }
    // Fallback: no quantization marker found — use id as model name, local as tag.
    return '$id:local';
  }

  /// Returns the set of model names already registered in the running Ollama instance.
  Future<Set<String>> _getRegisteredOllamaModels() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:11434/api/tags'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = data['models'] as List? ?? [];
        return models.map((m) => m['name'] as String).toSet();
      }
    } catch (_) {}
    return {};
  }

  /// Returns the Ollama server version string, or null on failure.
  Future<String?> getOllamaVersion() async {
    try {
      final r = await http
          .get(Uri.parse('http://127.0.0.1:11434/api/version'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        return (jsonDecode(r.body) as Map<String, dynamic>)['version'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Removes a catalog model from the Ollama Hub registry.
  /// Safe to call even if Ollama is offline (silently no-ops).
  /// Wire this up in deleteModel() when model deletion is implemented.
  Future<void> deregisterOllamaModel(String catalogId) async {
    if (!await isInternalOllamaRunning()) return;
    final ollamaName = _toOllamaModelName(catalogId);
    try {
      await http.delete(
        Uri.parse('http://127.0.0.1:11434/api/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'model': ollamaName}),
      ).timeout(const Duration(seconds: 10));
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[INFO] Deregistered $ollamaName from Hub.'],
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[WARN] Could not deregister $ollamaName: $e'],
      ));
    }
  }

  /// Searches the Ollama model registry for available models.
  /// Returns a list of model metadata maps with keys: name, description, pulls, tags.
  Future<List<Map<String, dynamic>>> fetchOllamaRegistryModels(String query) async {
    try {
      final uri = Uri.parse('https://ollama.com/api/search').replace(
        queryParameters: {'q': query, 'sort': 'popular'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body);
        if (list is List) {
          return list.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Register a local GGUF file with the integrated Ollama Hub.
  ///
  /// APPROACH: Write a minimal Modelfile to the PRoot filesystem from Dart, then run
  /// `ollama create` CLI inside PRoot pointing at that file. This avoids:
  ///   - HTTP API path resolution failure (PRoot ptrace doesn't translate HTTP socket paths)
  ///   - /dev/stdin unreliability in non-interactive PRoot (heredoc stdin gets no data)
  ///
  /// The Modelfile is written to $filesDir/rootfs/ubuntu/tmp/ (Android host FS), which
  /// appears as /tmp/ inside PRoot — accessible by the Ollama CLI process.
  Future<bool> _createOllamaModelFromGguf(String name, String ggufPath, {bool supportsToolCalls = false}) async {
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[HUB] Registering $name...'],
    ));
    File? tempModelfile;
    try {
      // Write Modelfile to the rootfs /tmp directory.
      // Dart writes to the Android host path; PRoot sees it at /tmp/oc_mf.
      final filesDir = await NativeBridge.getFilesDir();
      final safeName = name.replaceAll(':', '_').replaceAll('/', '_');
      tempModelfile = File('$filesDir/rootfs/ubuntu/tmp/oc_mf_$safeName');
      // For tool-capable models inject the Qwen2.5 chat template so Ollama
      // registers the {{ .Tools }} marker and allows the gateway agent loop
      // to pass function schemas without receiving HTTP 400.
      final modelfileContent = supportsToolCalls
          ? 'FROM $ggufPath\n$_kQwen25OllamaTemplate'
          : 'FROM $ggufPath\nPARAMETER num_ctx 2048\nPARAMETER num_thread 4\n';
      await tempModelfile.writeAsString(modelfileContent);

      final prootModelfilePath = '/tmp/oc_mf_$safeName';

      // Verify the GGUF is visible from inside PRoot before calling ollama.
      // Helps confirm the bind mount is working; emits a clear log if not.
      final checkResult = await NativeBridge.runInProot(
        'test -f "$ggufPath" && echo "GGUF_OK" || echo "GGUF_MISSING: $ggufPath"',
        timeout: 10,
      ).catchError((_) => 'CHECK_FAILED');
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[DEBUG] model file check: ${checkResult.trim()}'],
      ));

      final result = await NativeBridge.runInProot(
        'OLLAMA_HOST=127.0.0.1:11434 ollama create "$name" -f "$prootModelfilePath"',
        timeout: 180,
      );

      final lower = result.toLowerCase();
      final success = lower.contains('success') && !lower.contains('error:');
      if (success) {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[HUB] $name — success'],
        ));
      } else {
        final trimmed = result.trim().split('\n').take(8).join(' | ');
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[DEBUG] ollama create output: $trimmed'],
        ));
      }
      return success;
    } catch (e) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[DEBUG] ollama create failed: $e'],
      ));
      return false;
    } finally {
      // Clean up temp Modelfile regardless of outcome.
      try { await tempModelfile?.delete(); } catch (_) {}
    }
  }

  /// Pull a model from the Ollama library into the integrated hub.
  Stream<double> pullOllamaModel(String name) async* {
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[INFO] Pulling Ollama model: $name'],
    ));

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('http://127.0.0.1:11434/api/pull'));
      request.body = jsonEncode({'name': name});
      
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Pull failed: ${response.statusCode}');
      }

      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final data = jsonDecode(line);
          if (data['status'] == 'success') {
            _updateState(_state.copyWith(
              logs: [..._state.logs, '[INFO] Successfully pulled $name'],
            ));
            yield 1.0;
          } else if (data['total'] != null && data['completed'] != null) {
            yield data['completed'].toDouble() / data['total'].toDouble();
          }
        } catch (_) {}
      }
    } catch (e) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[ERROR] Pull failed for $name: $e'],
      ));
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Called after a successful `ollama pull` to add the model to hub state
  /// so it appears in the chat dropdown immediately without a full re-sync.
  void registerPulledModel(String modelName) {
    if (!_state.ollamaHubModels.contains(modelName)) {
      _updateState(_state.copyWith(
        ollamaHubModels: [..._state.ollamaHubModels, modelName],
        logs: [..._state.logs, '[HUB] Registered pulled model: $modelName'],
      ));
      unawaited(configureOllama(syncedModels: _state.ollamaHubModels));
    }
  }

  Future<bool> stopInternalOllama() async {
    final success = await NativeBridge.stopOllama();
    // Clear hub models from state so the chat dropdown removes ollama/ entries.
    _updateState(_state.copyWith(
      isOllamaRunning: false,
      ollamaHubModels: const [],
      logs: [..._state.logs, '[INFO] Ollama Hub stopped.'],
    ));
    return success;
  }

  Future<void> installInternalOllama({Function(double)? onProgress}) async {
    const url = 'https://github.com/ollama/ollama/releases/download/v0.19.0/ollama-linux-arm64.tar.zst';
    int attempts = 0;
    
    while (attempts < 3) {
      attempts++;
      final client = http.Client();
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[INFO] Downloading internal Ollama binary (ARM64) [Attempt $attempts/3]...'],
      ));

      try {
        final request = http.Request('GET', Uri.parse(url));
        final response = await client.send(request);
        
        if (response.statusCode != 200) {
          throw Exception('Download failed: ${response.statusCode}');
        }

        final contentLength = response.contentLength ?? 0;
        int downloaded = 0;
        
        final tempFile = File('${Directory.systemTemp.path}/ollama_dl.tar.zst');
        if (await tempFile.exists()) await tempFile.delete();
        final sink = tempFile.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (contentLength > 0 && onProgress != null) {
            onProgress(downloaded / contentLength);
          }
        }
        await sink.close();

        _updateState(_state.copyWith(
          logs: [..._state.logs, '[INFO] Binary downloaded. Calling native installer...'],
        ));

        final success = await NativeBridge.installOllama(tempFile.path);
        if (!success) throw Exception('Native installation failed.');

        _updateState(_state.copyWith(
          logs: [..._state.logs, '[INFO] Internal Ollama installed successfully.'],
        ));
        return; // Success!
      } catch (e) {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[WARNING] Attempt $attempts failed: $e'],
        ));
        if (attempts >= 3) {
           _updateState(_state.copyWith(
            logs: [..._state.logs, '[ERROR] All download attempts failed.'],
          ));
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * attempts));
      } finally {
        client.close();
      }
    }
  }

  /// Direct I/O: Persist the selected model (no proot overhead).
  /// If [reload] is true, triggers an openclaw reload to make it active immediately.
  Future<void> persistModel(String model, {bool reload = false}) async {
    final config = await _readConfig();
    config['agents'] ??= {};
    config['agents']['defaults'] ??= {};
    config['agents']['defaults']['model'] ??= {};
    config['agents']['defaults']['model']['primary'] = model;
    await _writeConfig(config);

    if (reload) {
      invalidateTokenCache();
      disconnectWebSocket();
      try {
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && '
          'openclaw reload 2>/dev/null || true',
          timeout: 5
        );
      } catch (_) {}
    }
  }

  /// Map a provider name to its default model string (provider/model).
  /// Public so GatewayProvider can call it during configureAndStart.
  String getModelForProvider(String provider) {
    switch (_normalizeProvider(provider)) {
      case 'google': return 'google/gemini-3.1-pro-preview';
      case 'anthropic': return 'anthropic/claude-opus-4.6';
      case 'openai': return 'openai/gpt-4o';
      case 'groq': return 'groq/llama-3.1-405b';
      case 'ollama': return 'ollama/qwen2.5:0.5b';
      default: return provider;
    }
  }

  /// Normalize provider names to OpenClaw internal identifiers.
  /// Handles both human names ('gemini', 'claude') and env-key format
  /// IDs from the setup screen ('GEMINI_API_KEY', 'ANTHROPIC_API_KEY').
  String _normalizeProvider(String provider) {
    final p = provider.toLowerCase();
    if (p.contains('claude') || p.contains('anthropic')) return 'anthropic';
    if (p.contains('openai')) return 'openai';
    if (p.contains('gemini') || p.contains('google')) return 'google';
    if (p.contains('groq')) return 'groq';
    if (p.contains('ollama')) return 'ollama';
    return p;
  }

  /// Get the standard environment variable name for a provider's API key.
  String _getEnvKeyForProvider(String provider) {
    switch (_normalizeProvider(provider)) {
      case 'anthropic': return 'ANTHROPIC_API_KEY';
      case 'openai': return 'OPENAI_API_KEY';
      case 'google': return 'GOOGLE_API_KEY';
      case 'groq': return 'GROQ_API_KEY';
      default: return '';
    }
  }

  /// Write an API key (Direct I/O — avoids proot / node-e overhead)
  Future<void> configureApiKey(String provider, String key) async {
    final openClawProvider = _normalizeProvider(provider);
    final envKey = _getEnvKeyForProvider(provider);

    final List<Map<String, dynamic>> defaultModels;
    if (openClawProvider == 'google') {
      defaultModels = [{'id': 'gemini-3.1-pro-preview', 'name': 'Gemini 3.1 Pro Preview'}];
    } else if (openClawProvider == 'anthropic') {
      defaultModels = [{'id': 'claude-opus-4.6', 'name': 'Claude Opus 4.6'}];
    } else if (openClawProvider == 'openai') {
      defaultModels = [{'id': 'gpt-4o', 'name': 'GPT-4o'}];
    } else if (openClawProvider == 'groq') {
      defaultModels = [{'id': 'llama-3.1-405b', 'name': 'Llama 3.1 405B'}];
    } else {
      defaultModels = [{'id': 'default', 'name': 'Default Model'}];
    }

    // 1. Update openclaw.json
    final config = await _readConfig();
    config['env'] ??= {};
    config['env']['vars'] ??= {};
    if (envKey.isNotEmpty) config['env']['vars'][envKey] = key;

    config['models'] ??= {};
    config['models']['providers'] ??= {};
    final prov = config['models']['providers'][openClawProvider] ?? {};
    config['models']['providers'][openClawProvider] = {
      ...prov,
      'apiKey': key,
      'models': prov['models'] ?? defaultModels,
    };
    if (openClawProvider == 'google' && config['models']['providers']['google']['baseUrl'] == null) {
      config['models']['providers']['google']['baseUrl'] = "https://generativelanguage.googleapis.com/v1beta";
    }
    await _writeConfig(config);

    // 2. Update agent auth-profiles.json
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final authPath = '$filesDir/rootfs/ubuntu/root/.openclaw/agents/main/agent/auth-profiles.json';
      final authFile = File(authPath);
      Map<String, dynamic> auth = {};
      
      if (await authFile.exists()) {
        auth = jsonDecode(await authFile.readAsString());
      } else {
        await Directory(authFile.parent.path).create(recursive: true);
      }
      
      auth['providers'] ??= {};
      (auth['providers'][openClawProvider] ??= {})['apiKey'] = key;
      await authFile.writeAsString(jsonEncode(auth));
    } catch (e) {
      debugPrint('[GatewayService] Auth patch error: $e');
    }
  }

  /// Explicitly query the OpenClaw CLI for the Dashboard URL containing the auth token.
  /// This is required because OpenClaw 2.x no longer prints the token in startup logs automatically.
  Future<String?> fetchAuthenticatedDashboardUrl({bool force = false}) async {
    // If we already have a tokenized URL and aren't forcing, return it immediately
    if (!force && _state.dashboardUrl != null && _state.dashboardUrl!.contains('token=')) {
      return _state.dashboardUrl;
    }

    _updateState(_state.copyWith(
      logs: [..._state.logs, '[DEBUG] Probing gateway config for auth token...']
    ));

    // STEP 1: Try reading token directly from config file.
    // This is isolated in its own try/catch so proot errors don't produce a false [ERROR] log.
    String? token;
    try {
      token = await retrieveTokenFromConfig();
    } catch (_) {
      // Silently swallow — proot may throw uv_interface_addresses errors on some devices.
      // We'll fall through to the CLI probe below.
    }

    if (token != null && token.isNotEmpty) {
      final prefs = PreferencesService();
      await prefs.init();
      // Construct the authenticated URL
      final baseUrl = _state.dashboardUrl ?? AppConstants.gatewayUrl;
      
      // Sanitize the baseUrl: brutally strip out any fragments (#) or query params (?)
      // This prevents malformed URLs from stacking parameters (e.g. /#token=.../?token=...&token=...)
      var sanitizedBaseUrl = baseUrl.split('#').first.split('?').first;
      
      // Remove any trailing slashes to unify exact domain formatting
      while (sanitizedBaseUrl.endsWith('/')) {
        sanitizedBaseUrl = sanitizedBaseUrl.substring(0, sanitizedBaseUrl.length - 1);
      }
      
      // A clean gateway dashboard URL requires /?token=
      final urlWithToken = '$sanitizedBaseUrl/?token=$token';
      prefs.dashboardUrl = urlWithToken;
      _updateState(_state.copyWith(
        dashboardUrl: urlWithToken,
        logs: [..._state.logs, '[INFO] Gateway auth token acquired from config.'],
      ));
      return urlWithToken;
    }

    // STEP 2: Fallback to CLI dashboard probe WITH bionic-bypass (fixes the MAC error)
    try {
      final output = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && openclaw dashboard --no-open',
        timeout: 10
      );
      final urlMatch = _tokenUrlRegex.firstMatch(output);

      if (urlMatch != null) {
        final url = urlMatch.group(0);
        final prefs = PreferencesService();
        await prefs.init();
        prefs.dashboardUrl = url;
        _updateState(_state.copyWith(
          dashboardUrl: url,
          logs: [..._state.logs, '[INFO] Gateway auth token acquired via CLI.'],
        ));
        return url;
      } else {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[WARN] Dashboard probe failed to find token. Ensure openclaw is starting correctly.']
        ));
      }
    } catch (e) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[WARN] CLI dashboard probe failed: $e']
      ));
    }

    return _state.dashboardUrl;
  }

  String? _cachedToken;
  DateTime? _lastTokenFetch;

  /// Direct I/O: Retrieve token from config file (instant, no proot)
  Future<String?> retrieveTokenFromConfig({bool force = false}) async {
    if (!force && _cachedToken != null && _lastTokenFetch != null &&
        DateTime.now().difference(_lastTokenFetch!).inMinutes < 5) {
      return _cachedToken;
    }

    final config = await _readConfig();
    
    // MERGED: Robust multi-path token discovery while maintaining host-side file I/O speed.
    final token = config['gateway']?['auth']?['token'] as String? ??
                 config['gateway']?['token'] as String? ??
                 config['gateway']?['apiKey'] as String? ??
                 config['auth']?['token'] as String?;
    
    if (token != null && token.isNotEmpty) {
      _cachedToken = token;
      _lastTokenFetch = DateTime.now();
      return token;
    }
    // FALLBACK: Extract from dashboard URL if config is missing it
    if (_state.dashboardUrl != null && _state.dashboardUrl!.contains('token=')) {
      final uri = Uri.parse(_state.dashboardUrl!.replaceAll('#', '?')); // fragment to query
      final urlToken = uri.queryParameters['token'];
      if (urlToken != null && urlToken.isNotEmpty) {
        _cachedToken = urlToken;
        _lastTokenFetch = DateTime.now();
        return urlToken;
      }
    }

    return null;
  }



  /// Reset the RPC discovery flag so the next health-check tick re-runs
  /// `health`, `skills.list`, and `capabilities.list`. Call this after
  /// installing/uninstalling a skill or any time the user wants a fresh read.
  void refreshRpcDiscovery() {
    _rpcDiscoveryDone = false;
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[INFO] RPC discovery refreshed — will re-query on next tick'],
    ));
  }

  Future<void> stop() async {
    if (_isStopping) return;
    _isStopping = true;
    _rpcDiscoveryDone = false; // reset so next start re-runs discovery
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    // Tear down WS and invalidate token cache BEFORE stopping the process.
    // The next session generates a fresh token; keeping the old one causes
    // _checkHealth() on re-start to authenticate with a stale token → WS
    // handshake fails → gateway appears hung for up to 5 min (cache TTL).
    _connection?.dispose();
    _connection = null;
    _cachedToken = null;
    _lastTokenFetch = null;

    try {
      await NativeBridge.stopGateway();
      // Use copyWith so Ollama Hub state (isOllamaRunning, ollamaHubModels) is
      // preserved — the gateway stopping does NOT stop Ollama. Clearing these
      // here would make the chat dropdown lose its LOCAL HUB entries.
      _updateState(_state.copyWith(
        status: GatewayStatus.stopped,
        isWebsocketConnected: false,
        clearError: true,
        clearStartedAt: true,
        clearDashboardUrl: true,
        clearDetailedHealth: true,
        logs: [..._state.logs, '[INFO] Gateway stopped'],
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to stop: $e',
      ));
    } finally {
      _isStopping = false;
    }
  }

  void _startHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.healthCheckIntervalMs),
      (_) => _checkHealth(),
    );
  }

  /// Ensure the WebSocket is connected. Creates the connection object if
  /// needed, wires up the state listener, resets backoff, and connects.
  /// Returns true if the WS is (or became) connected.
  Future<bool> _ensureWebSocket(String token) async {
    if (_connection?.state == GatewayConnectionState.connected) return true;

    if (_connection == null) {
      _connection = GatewayConnection();
      _connection!.stateStream.listen((wsState) {
        final connected = wsState == GatewayConnectionState.connected;
        _updateState(_state.copyWith(
          isWebsocketConnected: connected,
          logs: connected
              ? [..._state.logs, '[INFO] WebSocket connected (session: ${_connection?.mainSessionKey ?? 'pending'})']
              : _state.logs,
        ));
      });
    }

    _connection!.resetReconnectCounter();
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[INFO] Connecting WebSocket...'],
    ));
    final ok = await _connection!.connect(token);
    if (ok) {
      _updateState(_state.copyWith(
        isWebsocketConnected: true,
        logs: [..._state.logs, '[INFO] WebSocket handshake complete (session: ${_connection!.mainSessionKey ?? 'main'})'],
      ));
    } else {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[WARN] WebSocket connect failed — will retry on next health tick'],
      ));
    }
    return ok;
  }

  Future<void> _checkHealth() async {
    // ── Re-entrancy guard ────────────────────────────────────────────────
    // Prevent overlapping health ticks. Each tick can involve PRoot calls
    // and WS handshakes that take several seconds. Without this guard,
    // timer ticks pile up and cause cascading stalls.
    if (_healthCheckInFlight) return;
    _healthCheckInFlight = true;

    try {
      // ── 1. Fast HTTP probe ─────────────────────────────────────────────
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode < 500) {
        // Mark gateway as running on first successful probe
        if (_state.status != GatewayStatus.running) {
          _updateState(_state.copyWith(
            status: GatewayStatus.running,
            startedAt: _state.startedAt ?? DateTime.now(),
            logs: [..._state.logs, '[INFO] Gateway is healthy'],
          ));
          // After gateway (re)start, re-probe Ollama in case it was already
          // running when the gateway stopped (stop() no longer clears
          // isOllamaRunning, but after a process restart we must re-confirm).
          if (!_state.isOllamaRunning) {
            unawaited(Future(() async {
              if (await checkOllamaHealth()) {
                unawaited(syncLocalModelsWithOllama());
              }
            }));
          }
        }

        // ── 2. Single token retrieval (with timeout) ─────────────────────
        String? token;
        try {
          token = await retrieveTokenFromConfig()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          _updateState(_state.copyWith(
            logs: [..._state.logs, '[WARN] Token retrieval timed out — skipping WS/RPC this tick'],
          ));
          return; // Skip WS + RPC work; next tick will retry
        }

        if (token == null || token.isEmpty) {
          // Actively probe for token in background so it's ready before the next tick
          unawaited(fetchAuthenticatedDashboardUrl(force: true));
          return;
        }

        // ── 3. Ensure WebSocket is connected (single consolidated path) ──
        if (_connection?.state != GatewayConnectionState.connected) {
          await _ensureWebSocket(token);
        }

        // ── 4. RPC discovery (health, skills, capabilities) ─────────────
        // Runs ONCE after the first successful WS connect, then skips on
        // subsequent ticks. Each RPC has an 8s timeout (was 30s) so a
        // slow-booting gateway can't stall the health loop for 90s.
        if (_connection?.state == GatewayConnectionState.connected &&
            !_rpcDiscoveryDone) {
          _rpcDiscoveryDone = true; // set first so a timeout doesn't re-run

          try {
            final healthResult = await invoke('health')
                .timeout(const Duration(seconds: 8));
            final healthData = healthResult.containsKey('payload')
                ? healthResult['payload']
                : healthResult;
            if (healthData != null &&
                (healthData['ok'] == true || healthData['health'] != null)) {
              _updateState(_state.copyWith(
                detailedHealth: healthData,
                logs: [..._state.logs, '[INFO] Health RPC: ok=${healthData['ok'] ?? healthData['health']}'],
              ));
            }
          } catch (_) {
            // Non-fatal — health RPC may not be supported on all gateways
          }

          try {
            final skillsResult = await invoke('skills.list')
                .timeout(const Duration(seconds: 8));
            final skillsData = skillsResult.containsKey('payload')
                ? skillsResult['payload']
                : skillsResult;
            if (skillsData != null &&
                (skillsResult['ok'] == true || skillsData is List)) {
              final rawList = skillsData is List
                  ? skillsData
                  : (skillsData['skills'] ?? skillsData['items'] ?? []);
              final parsedSkills = <Map<String, dynamic>>[];
              final parsedIds = <String>{};
              for (final skill in rawList as List) {
                if (skill is Map) {
                  final mapped = Map<String, dynamic>.from(skill);
                  parsedSkills.add(mapped);
                  final id = (mapped['id'] ?? mapped['name'] ?? mapped['skillId'])?.toString().toLowerCase() ?? '';
                  if (id.isNotEmpty) parsedIds.add(id);
                } else if (skill is String) {
                  parsedSkills.add({'id': skill, 'name': skill});
                  parsedIds.add(skill.toLowerCase());
                }
              }
              _updateState(_state.copyWith(
                activeSkills: parsedSkills,
                logs: [..._state.logs, '[INFO] Active skills: ${parsedIds.isEmpty ? 'none' : parsedIds.join(', ')}'],
              ));
            }
          } catch (_) {}

          try {
            final capResult = await invoke('capabilities.list')
                .timeout(const Duration(seconds: 8));
            final capData = capResult.containsKey('payload')
                ? capResult['payload']
                : capResult;
            if (capData != null &&
                (capResult['ok'] == true || capData is List)) {
              final rawList = capData is List
                  ? capData
                  : (capData['capabilities'] ??
                      capData['tools'] ??
                      capData['items'] ??
                      []);
              final caps = <String>[];
              for (final cap in rawList as List) {
                final name = (cap is Map
                        ? (cap['name'] ?? cap['id'])
                        : cap)
                    ?.toString() ?? '';
                if (name.isNotEmpty) caps.add(name);
              }
              _updateState(_state.copyWith(
                capabilities: caps,
                logs: [..._state.logs, '[INFO] Capabilities: ${caps.isEmpty ? 'none' : caps.join(', ')}'],
              ));
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // HTTP HEAD failed — check if gateway process is still alive
      final isRunning = await NativeBridge.isGatewayRunning();
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          logs: [..._state.logs, '[WARN] Gateway process not running'],
        ));

        // SELF-HEALING: Auto-restart if dead and policy allows
        final prefs = PreferencesService();
        await prefs.init();
        if (prefs.autoStartGateway) {
          unawaited(_attachOrStart(autoStart: true));
        }
      }
    } finally {
      _healthCheckInFlight = false;
    }
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }


  /// Send a message using the persistent WebSocket connection.
  ///
  /// Uses auto-reconnecting GatewayConnection. Falls back to per-message
  /// connection if the persistent one isn't available.
  Stream<String> sendMessage(String message, {
    String? model,
    List<Map<String, dynamic>>? conversationHistory,
  }) async* {
    model = await _resolveModel(model);

    // Retrieve auth token
    String? token;
    try {
      token = await retrieveTokenFromConfig();
    } catch (_) {}

    // Lazy recovery: if not cached yet, do one live CLI probe before giving up.
    // By the time the user sends their first message the gateway is always stable.
    if (token == null || token.isEmpty) {
      try {
        await fetchAuthenticatedDashboardUrl(force: true);
        token = await retrieveTokenFromConfig();
      } catch (_) {}
    }

    if (token == null || token.isEmpty) {
      yield '[Error] No gateway auth token available.\n'
            'Please ensure the gateway has started and the token is saved in openclaw.json.';
      return;
    }

    // Local-llm: bypass the gateway entirely — run inference via fllama NDK.
    if (model.startsWith('local-llm')) {
      yield* LocalLlmService().chat(conversationHistory ?? [], message);
      return;
    }

    // Ollama Hub routing: always bypass the gateway agent loop.
    // The gateway's embedded agent injects a 26K system prompt that overloads
    // small LLMs on mobile (OOM, hang, retry storm, overheating).
    // Route directly to Ollama at :11434 — clean conversation history only.
    if (model.startsWith('ollama/')) {
      final ollamaModel = model.substring('ollama/'.length);
      yield* sendMessageHttp(message,
          model: ollamaModel,
          directUrl: 'http://127.0.0.1:11434/v1/chat/completions',
          conversationHistory: conversationHistory);
      return;
    }

    // Cloud models: use the WebSocket chat.send RPC.
    final wsOk = await _ensureWebSocket(token);
    if (!wsOk) {
      yield* sendMessageHttp(message, model: model, token: token,
          conversationHistory: conversationHistory);
      return;
    }

    final requestId = const Uuid().v4();
    final chunkController = StreamController<String>();

    // Use sessionKey from gateway handshake, or default to 'main'
    final sessionKey = _connection!.mainSessionKey ?? 'main';

    final responseStream = _connection!.sendRequest({
      'method': 'chat.send',
      'params': {
        'sessionKey': sessionKey,
        'message': message,
        'idempotencyKey': const Uuid().v4(),
        'timeoutMs': 90000,
      },
      'id': requestId,
    });

    late StreamSubscription frameSub;
    frameSub = responseStream.listen(
      (frame) {
        try {
          final type = frame['type'] as String?;

          // 1. Gateway Native 'error' bounds:
          // The gateway directly passes unrecoverable provider failures (like rate limits)
          // as a root frame with type: "error" and payload: { message: ... }
          if (type == 'error') {
            final payload = frame['payload'] as Map<String, dynamic>?;
            final errMsg = payload?['message'] as String? ?? 'API Error encountered';
            chunkController.add('[Error] $errMsg');
            if (!chunkController.isClosed) chunkController.close();
            return;
          }

          // Ultimate Fallback: Intercept ANY frame that natively carries an 'error' field
          // to guarantee the UI reflects it, regardless of the event nesting layer.
          if (frame.containsKey('error') && frame['error'] != null) {
            final errObj = frame['error'];
            final errStr = errObj is Map ? (errObj['message']?.toString() ?? errObj.toString()) : errObj.toString();
            if (errStr.toLowerCase().contains('rate limit') || errStr.toLowerCase().contains('api') || errStr.toLowerCase().contains('invalid')) {
              chunkController.add('[Error] $errStr');
              if (!chunkController.isClosed) chunkController.close();
              return;
            }
          }

          // Response to our chat.send request — this is just an ACK.
          // The gateway responds with ok:true + runId when streaming starts.
          // Actual text comes via 'agent' events.
          if (type == 'res' && frame['id'] == requestId) {
            final ok = frame['ok'] as bool? ?? false;
            if (!ok) {
              // chat.send was rejected
              final error = frame['error'] as Map<String, dynamic>?;
              final msg = error?['message'] as String? ?? 'chat.send failed';
              chunkController.add('[Error] $msg');
              if (!chunkController.isClosed) chunkController.close();
            }
            // ok:true → streaming has started, wait for agent events
            return;
          }

          // Chat events — terminal state signals
          if (type == 'event' && frame['event'] == 'chat') {
            final Map<String, dynamic> data = (frame['payload'] as Map<String, dynamic>?)
                ?? (frame['data'] as Map<String, dynamic>?)
                ?? frame; 

            final state = data['state'] as String?;
            if (state == 'final' || state == 'aborted' || state == 'error') {
              if (!chunkController.isClosed) chunkController.close();
            }
          }

          // Agent events — streaming text deltas and lifecycle errors
          if (type == 'event' && frame['event'] == 'agent') {
            final payload = frame['payload'] as Map<String, dynamic>?;
            final innerData = payload?['data'] as Map<String, dynamic>? ?? frame['data'] as Map<String, dynamic>?;

            // Extract stream from payload or frame
            final stream = (payload?['stream'] ?? frame['stream']) as String?;

            if (stream == 'assistant') {
              // Text delta from the AI
              final text = (innerData?['text'] ?? payload?['text'] ?? frame['text']) as String?;
              if (text != null && text.isNotEmpty) {
                chunkController.add(text);
              }
            } else if (stream == 'lifecycle') {
              // Lifecycle events (start, error, end)
              final phase = (innerData?['phase'] ?? payload?['phase'] ?? frame['phase']) as String?;
              if (phase == 'error') {
                final error = (innerData?['error'] ?? payload?['error'] ?? frame['error'])?.toString() ?? 'Unknown API error';
                chunkController.add('[Error] $error');
                if (!chunkController.isClosed) chunkController.close();
              }
            } else if (stream == 'error') {
               // Gateway stream=error: provider failure, seq gap, or disabledUntil cooldown.
               final rawErr = (innerData?['error'] ?? payload?['error'] ?? payload?['reason'] ?? frame['reason'] ?? frame['error'])?.toString() ?? '';
               final error = rawErr.isNotEmpty ? rawErr : 'Provider unavailable — if using local LLM, the model may still be loading. Try again in a moment.';
               chunkController.add('[Error] $error');
               if (!chunkController.isClosed) chunkController.close();
            }
          }
        } catch (_) {}
      },
      onError: (e) {
        if (!chunkController.isClosed) {
          chunkController.addError(e);
          chunkController.close();
        }
      },
      onDone: () {
        if (!chunkController.isClosed) chunkController.close();
      },
    );

    // Yield chunks
    try {
      await for (final chunk in chunkController.stream
          .timeout(const Duration(seconds: 90))) {
        yield chunk;
      }
    } on TimeoutException {
      yield '[Error] Gateway chat timed out after 90 seconds.';
    } catch (e) {
      yield '[Error] WebSocket chat error: $e';
    } finally {
      frameSub.cancel();
    }
  }

  /// Invoke a generic RPC method on the gateway.
  Future<Map<String, dynamic>> invoke(String method, [Map<String, dynamic>? params]) async {
    if (_connection == null || _connection!.state != GatewayConnectionState.connected) {
      // Need token to connect
      String? token;
      try {
        token = await retrieveTokenFromConfig();
      } catch (_) {}
      
      if (token == null || token.isEmpty) {
        throw Exception('Gateway not connected and no auth token available.');
      }
      
      _connection ??= GatewayConnection();
      final ok = await _connection!.connect(token);
      if (!ok) throw Exception('Failed to connect to gateway.');
    }

    final requestId = const Uuid().v4();
    final responseStream = _connection!.sendRequest({
      'method': method,
      'params': params ?? {},
      'id': requestId,
    });

    final frame = await responseStream.first.timeout(const Duration(seconds: 30));
    return frame;
  }

  /// HTTP fallback: POST to /v1/chat/completions with STREAMING support.
  /// 
  /// Used for specific model overrides (like Local LLM) where the WS RPC
  /// parameters are too rigid. Now supports real-time text deltas.
  Stream<String> sendMessageHttp(String message, {
    String? model,
    String? token,
    List<Map<String, dynamic>>? conversationHistory,
    String? directUrl, // if set, bypass the gateway and POST directly to this URL
  }) async* {
    model = await _resolveModel(model);

    final url = directUrl ?? '${AppConstants.gatewayUrl}/v1/chat/completions';
    final isDirectLlama = directUrl != null;

    // For direct llama-server calls, no gateway token or openclaw headers needed.
    if (!isDirectLlama) {
      token ??= await retrieveTokenFromConfig();
      if (token == null || token.isEmpty) {
        yield '[Error] No auth token for model routing.';
        return;
      }
    }

    final messages = conversationHistory != null && conversationHistory.isNotEmpty
        ? [...conversationHistory, {'role': 'user', 'content': message}]
        : [{'role': 'user', 'content': message}];

    final effectiveModel = isDirectLlama ? 'local-llm' : model;

    final client = http.Client();
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (!isDirectLlama && token != null) 'Authorization': 'Bearer $token',
      };
      final request = http.Request('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..body = jsonEncode({
          'model': effectiveModel,
          'messages': messages,
          'stream': true,
        });

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 90));

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        yield '[Error] HTTP ${streamedResponse.statusCode}: $body';
        return;
      }

      // Process the SSE stream: "data: { ... }"
      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final delta = (json['choices'] as List?)?[0]?['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {
            // Malformed chunk or heartbeat, skip
          }
        }
      }
    } on TimeoutException {
      yield '[Error] Chat stream timed out.';
    } catch (e) {
      yield '[Error] Connection failed: $e';
    } finally {
      client.close();
    }
  }

  /// Vision message via fllama — no HTTP server required.
  ///
  /// [imageBase64] – raw base64 string (no data-URI prefix).
  /// [prompt]      – user text; falls back to a generic describe prompt.
  Stream<String> sendVisionMessage(
    String prompt,
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) async* {
    final effectivePrompt =
        prompt.trim().isEmpty ? 'Describe what you see in this image.' : prompt.trim();
    final imageBytes = base64Decode(imageBase64);
    yield* LocalLlmService().analyseVideoFrames([imageBytes], effectivePrompt);
  }

  // ── Dynamic Agent & Session Discovery ──────────────────────────────────────

  /// Fetches the list of available OpenClaw agents from the gateway.
  /// Returns an empty list (not an error) if the gateway is unreachable or
  /// the RPC is unsupported by the installed OpenClaw version.
  Future<List<AgentInfo>> fetchAgents() async {
    try {
      final frame = await invoke('agents.list');
      final defaultId = frame['defaultAgent'] as String?;
      final raw = frame['agents'];
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map((j) => AgentInfo.fromJson(j, defaultId: defaultId))
          .toList();
    } catch (_) {
      // Gateway not connected, RPC not supported, or parse error — degrade gracefully
      return [];
    }
  }

  /// Fetches the list of active sessions from the gateway.
  /// Returns an empty list on failure.
  Future<List<Map<String, dynamic>>> fetchSessions() async {
    try {
      final frame = await invoke('sessions.list');
      final raw = frame['sessions'];
      if (raw is! List) return [];
      return raw.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  // ── Cloud Video Vision (Gemini inline video) ────────────────────────────────

  /// Sends a short MP4 clip to the gateway for Gemini video understanding.
  /// Falls back gracefully if the model doesn't support video.
  ///
  /// [mp4Base64] – raw base64-encoded MP4 bytes (no data-URI prefix).
  /// [prompt]    – user's question about the video.
  Stream<String> sendCloudVideoMessage(
    String prompt,
    String mp4Base64,
  ) async* {
    String? token;
    try {
      token = await retrieveTokenFromConfig();
    } catch (_) {}

    if (token == null || token.isEmpty) {
      yield '[Error] No auth token — cannot send video to gateway.';
      return;
    }

    final effectivePrompt =
        prompt.trim().isEmpty ? 'Describe what is happening in this video.' : prompt.trim();

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'model': PreferencesService().configuredModel ?? 'google/gemini-2.0-flash',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:video/mp4;base64,$mp4Base64',
                      },
                    },
                    {'type': 'text', 'text': effectivePrompt},
                  ],
                },
              ],
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content =
              (choices[0]['message'] as Map?)?['content'] as String?;
          if (content != null) {
            yield content;
            return;
          }
        }
        yield '[Error] Empty response from video analysis.';
      } else {
        yield '[Error] Cloud video failed (HTTP ${response.statusCode}). '
            'Make sure you are using a Gemini model.';
      }
    } on TimeoutException {
      yield '[Error] Video analysis timed out.';
    } catch (e) {
      yield '[Error] Cloud video error: $e';
    }
  }

  /// Sends an image to the gateway for Google/OpenAI/Anthropic cloud vision.
  ///
  /// [imageBase64] – raw base64-encoded bytes (no data-URI prefix).
  /// [prompt]      – user's question about the image.
  Stream<String> sendCloudImageMessage(
    String prompt,
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) async* {
    String? token;
    try {
      token = await retrieveTokenFromConfig();
    } catch (_) {}

    if (token == null || token.isEmpty) {
      yield '[Error] No auth token — cannot send image to gateway.';
      return;
    }

    final effectivePrompt =
        prompt.trim().isEmpty ? 'Describe what you see in this image.' : prompt.trim();

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'model': PreferencesService().configuredModel ?? 'google/gemini-2.0-flash',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:$mimeType;base64,$imageBase64',
                      },
                    },
                    {'type': 'text', 'text': effectivePrompt},
                  ],
                },
              ],
              // Vision endpoints handle non-streamed robustly. Gateway supports streaming eventually.
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content =
              (choices[0]['message'] as Map?)?['content'] as String?;
          if (content != null) {
            yield content;
            return;
          }
        }
        yield '[Error] Empty response from vision analysis.';
      } else {
        yield '[Error] Cloud vision failed (HTTP ${response.statusCode}). '
            'Make sure you are using a vision-capable proxy model.';
      }
    } on TimeoutException {
      yield '[Error] Vision analysis timed out.';
    } catch (e) {
      yield '[Error] Cloud vision error: $e';
    }
  }
  
  /// Resolves the intended model ID, falling back to preferences then openclaw.json defaults.
  Future<String> _resolveModel(String? model) async {
    if (model != null && model.isNotEmpty) return model;
    
    final prefs = PreferencesService();
    await prefs.init();
    final configured = prefs.configuredModel;
    if (configured != null && configured.isNotEmpty) return configured;
    
    final config = await _readConfig();
    final primary = config['agents']?['defaults']?['model']?['primary'] as String?;
    if (primary != null && primary.isNotEmpty) return primary;
    
    return 'google/gemini-3.1-pro-preview'; // Final hard fallback
  }

  /// Disconnect the persistent WS connection so the next sendMessage() opens a
  /// fresh session — picking up any gateway config change (e.g. local-llm reload).
  void disconnectWebSocket() {
    _connection?.dispose();
    _connection = null;
  }

  /// Clear the cached auth token so the next request re-probes for a fresh one.
  /// Call this after openclaw reload/restart, which generates a new token.
  void invalidateTokenCache() {
    _cachedToken = null;
    _lastTokenFetch = null;
    _updateState(_state.copyWith(clearDashboardUrl: true));
  }

  void dispose() {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _connection?.dispose();
    _stateController.close();
  }
}

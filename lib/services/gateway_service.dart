import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import '../models/agent_info.dart';
import 'gateway_connection.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';
import 'local_llm_service.dart';

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
  bool _isSyncing = false; // guard against concurrent syncLocalModelsWithOllama calls
  // Set to true after _clearStaleSessions() runs, reset on WS disconnect.
  // Prevents wiping sessions on every sendMessage (was causing "new LLM every few messages").
  bool _sessionCleanedThisConnection = false;
  final _chatActivityController = StreamController<String>.broadcast();
  final List<String> _activityBuffer = []; // replay buffer for late subscribers

  // Cached Android files directory — avoids a platform channel call on every config I/O.
  String? _filesDir;
  // Prevents concurrent @buape/carbon targeted-fix attempts.
  bool _isFixingDep = false;
  // Guards the one-time pairing-required recovery per session.
  bool _pairingResolveAttempted = false;

  // Pre-compiled regex for stale-name normalisation — allocated once, reused in tight loops.
  static final _staleNamePattern = RegExp(r'[.\-_:]');

  /// Live stream of human-readable chat and hub events for the Agent Hub panel.
  /// Emits: Flutter-side send/receive events + parsed Ollama server signals.
  Stream<String> get chatActivityStream => _chatActivityController.stream;

  /// Last ≤40 activity events — use to seed the panel when the screen opens.
  List<String> get recentActivity => List.unmodifiable(_activityBuffer);

  /// Get dynamic context size based on model capabilities
  /// Allows powerful devices to use higher contexts while keeping mobile safe
  int _getDynamicContextSize(String modelId) {
    // Use substring matching so full model IDs like
    // 'qwen2.5-0.5b-instruct:q4_k_m' match the short keys below.
    // Map Ollama model IDs to their context windows
    final modelContexts = {
      'qwen2.5-0.5b': 2048,
      'qwen2.5-1.5b': 2048,
      'qwen2.5-3b': 4096,
      'qwen2.5-7b': 8192,
      'smollm2-135m': 2048,
      'smollm2-360m': 2048,
      'smollm2-1.7b': 4096,
      'llava-1.5-7b': 4096,
      'qwen2-vl-2b': 2048,
      'qwen2-vl-7b': 4096,
    };
    for (final entry in modelContexts.entries) {
      if (modelId.contains(entry.key)) return entry.value;
    }
    // 2048 is safer than 1024 — gives tool schemas enough room
    return 2048;
  }

  /// Dynamic Modelfile template. TEMPLATE block is required — without it Ollama
  /// falls back to a broken default format and generates 0 tokens.
  /// [modelName] is used to select the correct chat template and stop tokens.
  String _buildModelfileTemplate(String ggufPath, int contextSize, {String modelName = ''}) {
    final name = modelName.toLowerCase();

    // Llama 3.x format
    if (name.contains('llama3') || name.contains('llama-3')) {
      return '''FROM $ggufPath
TEMPLATE """{{ if .System }}<|start_header_id|>system<|end_header_id|>
{{ .System }}<|eot_id|>
{{ end }}{{ if .Tools }}<|start_header_id|>system<|end_header_id|>
{{ .Tools }}<|eot_id|>
{{ end }}{{ if .Prompt }}<|start_header_id|>user<|end_header_id|>
{{ .Prompt }}<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>
{{ end }}{{ .Response }}<|eot_id|>"""
PARAMETER stop "<|eot_id|>"
PARAMETER stop "<|start_header_id|>"
PARAMETER num_ctx $contextSize
PARAMETER num_gpu 0
PARAMETER num_thread 4
PARAMETER num_batch 512
''';
    }

    // Default: ChatML format (Qwen2.5, SmolLM2, Phi, Gemma, etc.)
    return '''FROM $ggufPath
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Tools }}<|im_start|>system
{{ .Tools }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant
{{ end }}{{ .Response }}<|im_end|>"""
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|endoftext|>"
PARAMETER num_ctx $contextSize
PARAMETER num_gpu 0
PARAMETER num_thread 4
PARAMETER num_batch 512
''';
  }

  /// Buffer + broadcast a single activity event.
  void _addActivity(String event) {
    _activityBuffer.add(event);
    if (_activityBuffer.length > 40) _activityBuffer.removeAt(0);
    _chatActivityController.add(event);
  }

  /// Update the background repair status.
  void setRepairing(bool value, {String? message, double? progress}) {
    _updateState(_state.copyWith(
      isRepairing: value,
      repairMessage: message,
      repairProgress: progress,
    ));
  }

  /// Add a log entry to the gateway state from external services (like repair).
  void addLog(String message) {
    final logs = [..._state.logs, message];
    if (logs.length > 500) {
      logs.removeRange(0, logs.length - 500);
    }
    _updateState(_state.copyWith(logs: logs));
  }

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

  /// Parse any `grep <Key> /proc/meminfo` line into MB.
  /// Input looks like: "MemAvailable:    1054204 kB"
  static int _parseMemKbLineToMb(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    final kb = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return kb ~/ 1024;
  }

  /// Convenience alias used specifically for MemAvailable lines.
  static int _parseMemAvailableMb(String raw) => _parseMemKbLineToMb(raw);

  /// List of methods supported by the current gateway connection.
  List<String> get supportedMethods => _connection?.supportedMethods ?? [];

  /// Validate gateway process health before marking as healthy
  Future<void> _validateGatewayProcess() async {
    try {
      final result = await NativeBridge.runInProot('pgrep -f openclaw || echo "not_running"', timeout: 5);
      if (result.trim() == 'not_running') {
        _addActivity('[HEALTH] Gateway process not found - marking as stopped');
        _updateState(_state.copyWith(status: GatewayStatus.stopped));
      } else {
        _addActivity('[HEALTH] Gateway process validated and running');
      }
    } catch (_) {
      _addActivity('[HEALTH] Could not validate gateway process');
    }
  }

  /// Check if gateway is already running (e.g. after app restart)
  /// and sync UI state accordingly.  If not running but auto-start
  /// is enabled, start it automatically.
  /// Check if gateway is already running (e.g. after app restart)
  /// and sync UI state accordingly.
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
      // Append log in-place on a capped list; no O(n) spread clone per line.
      final logs = _state.logs.length < 500
          ? [..._state.logs, log]
          : [..._state.logs.sublist(_state.logs.length - 499), log];

      // Auto-Heal: targeted @buape/carbon fix (fastest recovery, no full reinstall)
      if (!_isFixingDep && log.contains("Cannot find module '@buape/carbon'")) {
        _isFixingDep = true;
        _addActivity('[SYS] Missing @buape/carbon — running targeted fix...');
        unawaited(() async {
          try {
            await NativeBridge.runInProot(
              'cd /usr/local/lib/node_modules/openclaw && '
              'npm install --no-save --no-audit --no-fund @buape/carbon 2>/dev/null && '
              'openclaw doctor --fix 2>/dev/null || true',
              timeout: 120,
            );
            _addActivity('[SYS] @buape/carbon fixed — restarting gateway...');
            await NativeBridge.runInProot(
              'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && '
              'openclaw reload 2>/dev/null || true',
              timeout: 10,
            );
          } catch (_) {
            _addActivity('[SYS] Dep fix failed — use Settings → Repair for full reinstall');
          } finally {
            _isFixingDep = false;
          }
        }());
      } else if (log.contains('Error: Cannot find module') || log.contains('SyntaxError:')) {
        // Broader module error — surface it so the user knows to run Repair
        _addActivity('[SYS] Critical error detected — use Settings → Repair Gateway if gateway fails to start');
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

      // Parse key Ollama server log lines into human-readable hub events.
      // Skip verbose startup spam (print_info:, load:, load_tensors:, etc.)
      if (log.contains('llama runner started')) {
        final m = RegExp(r'started in ([\d.]+) seconds').firstMatch(log);
        if (m != null) {
          _addActivity('[HUB] Model ready in ${m.group(1)}s');
        }
      } else if (log.contains('n_ctx =') && !log.contains('n_ctx_train')) {
        final m = RegExp(r'n_ctx = (\d+)').firstMatch(log);
        if (m != null) {
          _addActivity('[HUB] Context: ${m.group(1)} tokens');
        }
      } else if (log.contains('KV buffer size')) {
        final m = RegExp(r'size = ([\d.]+) MiB').firstMatch(log);
        if (m != null) {
          _addActivity('[HUB] KV cache: ${m.group(1)} MiB');
        }
      } else if (log.contains('[GIN]') && log.contains('chat/completions')) {
        // GIN format: "| 200 | 2.3s |" or "| 500 | 1m30s |"
        final m = RegExp(r'\|\s*(\d+)\s*\|\s*([^\|]+)\s*\|').firstMatch(log);
        if (m != null) {
          final code = m.group(1);
          final dur = m.group(2)?.trim();
          _addActivity(
            '[HUB] ${code == '200' ? '✓' : '✗'} HTTP $code ($dur)',
          );
        }
      } else if (log.contains('aborting completion')) {
        _addActivity('[HUB] ⚠ Inference aborted (client disconnected)');
      }
      // Intentionally skip: GET /api/tags (health-check noise),
      // print_info:, load:, load_tensors:, llama_model_loader: (verbose startup spam)
    });
  }

  /// Cached accessor for the Android app files directory.
  /// Platform channel is hit only on the first call; subsequent calls are instant.
  Future<String> _getFilesDir() async =>
      _filesDir ??= await NativeBridge.getFilesDir();

  /// Helper to get the host-side path to the openclaw config file.
  /// Must match the PRoot ubuntu rootfs: $filesDir/rootfs/ubuntu/root/...
  Future<String> _openClawConfigPath() async {
    return '${await _getFilesDir()}/rootfs/ubuntu/root/.openclaw/openclaw.json';
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
    
    // ENODEV FIX: Use official OpenClaw config schema
    // Prevent eth0 ENODEV errors with valid network binding
    config['gateway']['bind'] = 'loopback';  // localhost-only binding
    
    // DISCOVERY FIX: Disable mDNS/Bonjour using official schema
    config['discovery'] ??= {};
    config['discovery']['mdns'] ??= {};
    config['discovery']['mdns']['mode'] = 'off';  // disable mDNS/Bonjour
    
    // WIDE-AREA FIX: Disable DNS-SD discovery
    config['discovery']['wideArea'] ??= {};
    config['discovery']['wideArea']['enabled'] = false;
    
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
      agentsDefaults.remove('tools');             // not in agents.defaults schema
      agentsDefaults.remove('timeoutMs');         // not in agents.defaults schema
    }
    final skills = config['skills'];
    if (skills is Map) {
      skills.remove('discovery');                 // not in skills schema
      skills.remove('mode');                      // not in skills schema
      skills.remove('sync');                      // not in skills schema
      if (skills.isEmpty) config.remove('skills'); // don't leave empty block
    }
    // Remove invalid Ollama provider keys written by earlier builds (v2026.3.x).
    // These broke gateway schema validation, causing config reload to be skipped.
    final ollamaProvider = config['models']?['providers']?['ollama'];
    if (ollamaProvider is Map) {
      ollamaProvider.remove('defaultContextWindow'); // not in gateway schema
      ollamaProvider.remove('contextWindow');        // not in gateway schema
      final ollamaModels = ollamaProvider['models'];
      if (ollamaModels is List) {
        for (final m in ollamaModels) {
          if (m is Map) m.remove('contextWindow');   // not in model entry schema
        }
      }
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
    bool isCloudModel = false,
  }) async {
    final config = await _readConfig();
    config['models'] ??= {};
    config['models']['providers'] ??= {};
    // IMPORTANT: Only write keys that are in the OpenClaw gateway schema.
    // 'defaultContextWindow' and per-model 'contextWindow' are NOT valid schema
    // keys — writing them causes "[reload] config reload skipped (invalid config)"
    // which makes the gateway ignore ALL config changes including context caps.
    // Context window is enforced via: (1) Modelfile PARAMETER num_ctx at
    // `ollama create` time, and (2) patchSessionMetadata before each chat.send.
    final ollamaConfig = <String, dynamic>{
      'baseUrl': baseUrl,
      'apiKey': 'ollama-local',
      'api': 'ollama',
      'models': syncedModels.map((n) => <String, dynamic>{
        'id': n,
        'name': n,
      }).toList(),
    };

    config['models']['providers']['ollama'] = ollamaConfig;

    if (setAsPrimary && primaryModel != null) {
      config['agents'] ??= {};
      config['agents']['defaults'] ??= {};
      config['agents']['defaults']['model'] ??= {};
      final fullModel = primaryModel.startsWith('ollama/') ? primaryModel : 'ollama/$primaryModel';
      config['agents']['defaults']['model']['primary'] = fullModel;

      // CRITICAL: Set mobile-optimized system prompt for local models
      // This prevents hallucinations and reduces token usage from 27K to ~800
      if (primaryModel.startsWith('ollama/') || primaryModel.startsWith('local-llm/')) {
        config['agents']['defaults']['systemPrompt'] = 
            'You are OpenClaw, an AI assistant with access to Android device controls, sensors, and apps. '
            'You can make calls, send messages, control device settings, read sensors, browse web, and use system apps. '
            'Be concise but thorough. Use tools when they directly help the user. '
            'You are running on Android with limited battery and screen space.';
        
        final promptLength = config['agents']['defaults']['systemPrompt'].length;
        _addActivity('[CONFIG] Mobile system prompt applied (${promptLength} chars)');
        _addActivity('[CONFIG] Prompt content preview: "${config['agents']['defaults']['systemPrompt'].substring(0, 50)}..."');
      }

      // NOTE: agents.defaults.tools and agents.defaults.timeoutMs are NOT valid
      // OpenClaw schema keys — writing them breaks the gateway config validation.
      // Tool dispatch is controlled by the model's own capability declaration.

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
        // Clear stale session files before syncing. Aborted runs pile up
        // assistant/error messages that inflatethe conversation history
        // (messages=45+) and push total context beyond num_ctx=4096.
        await _clearStaleSessions();
        await syncLocalModelsWithOllama();
        return;
      }
    }
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[WARN] Ollama Hub did not respond after 30 s — check logs.'],
    ));
  }

  /// Truncate the gateway agent session JSONL file so aborted / timed-out
  /// runs don't accumulate and inflate the message count (user:18 + assistant:27
  /// etc.) that the Node.js engine forwards in every request.
  Future<void> _clearStaleSessions() async {
    // Run at most once per WS session — reset by stateStream listener on disconnect.
    // Prevents wiping context on every message (was the "new LLM every few messages" bug).
    if (_sessionCleanedThisConnection) return;
    _sessionCleanedThisConnection = true;

    try {
      final filesDir = await _getFilesDir();
      final sessionsDir = '$filesDir/rootfs/ubuntu/root/.openclaw/agents/main/sessions';
      final dir = Directory(sessionsDir);
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.jsonl')) {
          final bytes = await entity.length();
          // Only clear files > 512 KB — anything smaller is healthy conversation history.
          // Old threshold was 10 KB which cleared sessions after just 3-4 messages.
          if (bytes > 524288) {
            await entity.writeAsString('');
            _updateState(_state.copyWith(
              logs: [..._state.logs,
                '[HUB] Cleared stale session (${(bytes / 1024).toStringAsFixed(1)} KB): ${entity.uri.pathSegments.last}'],
            ));
          }
        }
      }
    } catch (e) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[WARN] Session cleanup error: $e'],
      ));
    }
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
    // Pre-compute normalised canonical set once rather than inside the inner loop.
    final normalisedCanonicals = {
      for (final c in canonicalNames) c.replaceAll(_staleNamePattern, '').toLowerCase(): c,
    };
    for (final name in registered) {
      if (canonicalNames.contains(name)) continue; // already canonical — keep
      final stripped = name.replaceAll(_staleNamePattern, '').toLowerCase();
      final isOurs = normalisedCanonicals.containsKey(stripped);
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
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _syncLocalModelsWithOllamaInternal();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncLocalModelsWithOllamaInternal() async {
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

    // Single pass: determine which models are downloaded (avoids double file-stat per model).
    final llmSvc = LocalLlmService();
    final downloadedToolModels = <dynamic>[];
    for (final m in catalog) {
      if (m.supportsToolCalls && await llmSvc.isModelDownloaded(m)) {
        downloadedToolModels.add(m);
      }
    }

    // Compute canonical names for cleanup, then clean up stale registrations.
    final canonicalNames = {for (final m in downloadedToolModels) _toOllamaModelName(m.id as String)};
    await _cleanupStaleOllamaRegistrations(canonicalNames);

    // Pre-fetch registered models to skip re-hashing on every startup.
    final registered = await _getRegisteredOllamaModels();

    int synced = 0;
    final syncedModelNames = <String>[]; // collect for gateway config + state emit

    for (final model in downloadedToolModels) {
      final ollamaName = _toOllamaModelName(model.id as String);
      // Always re-create: ensures num_ctx params from the current
      // Modelfile are applied. ollama create reuses the existing GGUF blob
      // (no re-hashing) so this is fast.
      if (registered.contains(ollamaName)) {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[HUB] Refreshing $ollamaName params...'],
        ));
      }
      try {
        final success = await _createOllamaModelFromGguf(
          ollamaName, model.prootModelPath as String,
          supportsToolCalls: model.supportsToolCalls as bool,
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

    _updateState(_state.copyWith(
      logs: [..._state.logs, '[INFO] Hub Sync Done. $synced models available.'],
    ));

    // Write synced models into openclaw.json and emit to state.
    // Auto-select the first synced model only if the user isn't already on a
    // local model — avoids silently hijacking an explicit cloud preference.
    // Exception: if prefs say "already local" but openclaw.json primary is
    // missing or pointing at cloud (e.g., after a gateway restart wipes config),
    // we must still write the primary — otherwise the gateway uses a cloud model.
    if (syncedModelNames.isNotEmpty) {
      final prefs = PreferencesService();
      await prefs.init();
      final currentModel = prefs.configuredModel ?? '';
      final alreadyLocal = currentModel.startsWith('ollama/') ||
          currentModel.startsWith('local-llm/');

      // Check if openclaw.json primary is in sync with the user's preference.
      final liveConfig = await _readConfig();
      final jsonPrimary = liveConfig['agents']?['defaults']?['model']?['primary'] as String?;
      final jsonPrimaryIsLocal = jsonPrimary != null &&
          (jsonPrimary.startsWith('ollama/') || jsonPrimary.startsWith('local-llm/'));

      // Force-write the primary if the JSON config doesn't reflect it — this
      // repairs drift after gateway restarts that regenerate openclaw.json.
      final needsPrimaryWrite = !alreadyLocal || !jsonPrimaryIsLocal;
      final primaryToWrite = alreadyLocal ? currentModel : syncedModelNames.first;

      await configureOllama(
        syncedModels: syncedModelNames,
        primaryModel: needsPrimaryWrite ? primaryToWrite : null,
        setAsPrimary: needsPrimaryWrite,
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
      // Write Modelfile to the rootfs /tmp directory with dynamic context sizing
      // Dart writes to the Android host path; PRoot sees it at /tmp/oc_mf.
      final filesDir = await _getFilesDir();
      final safeName = name.replaceAll(':', '_').replaceAll('/', '_');
      tempModelfile = File('$filesDir/rootfs/ubuntu/tmp/oc_mf_$safeName');
      
      // Get dynamic context size based on model capabilities
      final contextSize = _getDynamicContextSize(name);
      final modelfileContent = _buildModelfileTemplate(ggufPath, contextSize, modelName: name);
      await tempModelfile.writeAsString(modelfileContent);
      
      // Verify Modelfile contains correct context size
      if (modelfileContent.contains('PARAMETER num_ctx $contextSize')) {
        _addActivity('[HUB] Modelfile created with num_ctx=$contextSize for $name');
      } else {
        _addActivity('[HUB] WARNING: Modelfile missing num_ctx=$contextSize for $name');
      }

      final prootModelfilePath = '/tmp/oc_mf_$safeName';

      // isModelDownloaded() on the host FS already confirmed the GGUF exists —
      // no redundant PRoot file-check needed here.
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
      final filesDir = await _getFilesDir();
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
  /// OpenClaw never writes its runtime token to openclaw.json — it only appears in startup
  /// logs (captured by _subscribeLogs) or via `openclaw dashboard --no-open`.
  /// When attaching to an already-running gateway, no fresh startup logs exist, so we
  /// MUST call the CLI to retrieve the live token.
  Future<String?> fetchAuthenticatedDashboardUrl({bool force = false}) async {
    // Fast path: token already captured from startup logs or a prior CLI call.
    if (!force && _state.dashboardUrl != null && _state.dashboardUrl!.contains('token=')) {
      return _state.dashboardUrl;
    }

    // ── Primary: call `openclaw dashboard --no-open` to get the live token ──
    // This is the ONLY reliable source when attaching to an already-running gateway
    // (no startup logs replay) or after the token was not yet emitted to logs.
    try {
      final output = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'openclaw dashboard --no-open 2>/dev/null || true',
        timeout: 8,
      );
      // Output contains a line like:
      //   http://127.0.0.1:18789/?token=<uuid>
      // or with a fragment:
      //   http://127.0.0.1:18789/#token=<uuid>
      final cleanOutput = _cleanForUrl(output);
      final urlMatch = _tokenUrlRegex.firstMatch(cleanOutput);
      if (urlMatch != null) {
        final dashboardUrl = urlMatch.group(0)!;
        // Extract and cache the raw token for WebSocket / HTTP auth.
        final tokenUri = Uri.parse(dashboardUrl.replaceAll('#', '?'));
        final liveToken = tokenUri.queryParameters['token'];
        if (liveToken != null && liveToken.isNotEmpty) {
          _cachedToken = liveToken;
          _lastTokenFetch = DateTime.now();
        }
        final prefs = PreferencesService();
        await prefs.init();
        prefs.dashboardUrl = dashboardUrl;
        _updateState(_state.copyWith(
          dashboardUrl: dashboardUrl,
          logs: [..._state.logs, '[INFO] Gateway auth token retrieved via dashboard CLI.'],
        ));
        return dashboardUrl;
      }
    } catch (_) {
      // CLI call failed — fall through to config-file probe
    }

    // ── Secondary: read token from openclaw.json (rarely present, but try) ──
    String? token = await retrieveTokenFromConfig();
    if (token != null && token.isNotEmpty) {
      final prefs = PreferencesService();
      await prefs.init();
      // Use ?token= as expected by Control UI v2026.3.11
      final urlWithToken = '${AppConstants.gatewayUrl}/?token=$token';
      prefs.dashboardUrl = urlWithToken;
      _updateState(_state.copyWith(
        dashboardUrl: urlWithToken,
        logs: [..._state.logs, '[INFO] Gateway auth token from config (fallback).'],
      ));
      return urlWithToken;
    }

    return _state.dashboardUrl;
  }

  String? _cachedToken;
  DateTime? _lastTokenFetch;

  /// Direct I/O: Retrieve token from config file (instant, no proot)
  Future<String?> retrieveTokenFromConfig({bool force = false}) async {
    if (!force && _cachedToken != null && _lastTokenFetch != null &&
        DateTime.now().difference(_lastTokenFetch!).inSeconds < 60) {
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
  /// `health` and `skills.status`. Call this after
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
        if (connected) _pairingResolveAttempted = false; // Reset on success
        if (!connected) _sessionCleanedThisConnection = false; // Allow cleanup on next reconnect
        _updateState(_state.copyWith(
          isWebsocketConnected: connected,
          logs: connected
              ? [..._state.logs, '[INFO] WebSocket connected (session: ${_connection?.mainSessionKey ?? 'pending'})']
              : _state.logs,
        ));
      });
      _connection!.pairingRequiredStream.listen((_) => _handleOperatorPairingRequired());
      // Reset backoff only for brand-new connection objects, not on every
      // health tick — otherwise the exponential backoff never accumulates.
      _connection!.resetReconnectCounter();
    }
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

  /// Called when the gateway closes the operator WS with 1008 (pairing required).
  /// Deletes the stale device record via PRoot so the next connect is treated
  /// as a new device and succeeds with the gateway auth token alone.
  Future<void> _handleOperatorPairingRequired() async {
    if (_pairingResolveAttempted) return;
    _pairingResolveAttempted = true;
    final deviceId = _connection?.deviceId ?? '';
    _addActivity('[INFO] Pairing required — clearing stale operator device record...');
    try {
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        '(openclaw devices remove $deviceId 2>/dev/null || openclaw devices clear --yes 2>/dev/null || true)',
        timeout: 5,
      );
      // Clear persisted deviceToken — it belongs to the now-deleted record.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(GatewayConnection.prefDeviceToken);
      _addActivity('[INFO] Operator device record cleared — reconnecting fresh');
    } catch (e) {
      _addActivity('[WARN] Could not clear operator device record: $e');
    }
    // Dispose connection so _ensureWebSocket creates a fresh one next tick.
    _connection?.dispose();
    _connection = null;
  }

  Future<void> _checkHealth() async {
    // ── Re-entrancy guard ────────────────────────────────────────────────
    // Prevent overlapping health ticks. Each tick can involve PRoot calls
    // and WS handshakes that take several seconds. Without this guard,
    // timer ticks pile up and cause cascading stalls.
    if (_healthCheckInFlight) return;
    _healthCheckInFlight = true;
    
    // Add process validation before health checks
    unawaited(_validateGatewayProcess());

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
          // Eagerly warm the dashboard auth token in the background so that
          // opening WebDashboardScreen feels instant (token is already cached).
          unawaited(fetchAuthenticatedDashboardUrl(force: false).catchError((_) => null));
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

          // Skills discovery via skills.status (the correct RPC — skills.list does not exist).
          // capabilities.list also does not exist; device capabilities are declared at
          // connect-time via caps/commands/permissions in the handshake params, not via RPC.
          // Guard with supportedMethods so unknown-method log noise is avoided on older
          // gateway versions and the call auto-enables when the gateway declares it.
          final supported = _connection?.supportedMethods ?? const <String>[];

          if (supported.contains('skills.status')) {
            try {
              final skillsResult = await invoke('skills.status')
                  .timeout(const Duration(seconds: 8));
              final skillsData = skillsResult.containsKey('payload')
                  ? skillsResult['payload']
                  : skillsResult;
              if (skillsData != null &&
                  (skillsResult['ok'] == true || skillsData is Map || skillsData is List)) {
                // skills.status returns {skills: SkillInfo[]} — each entry has
                // name, skillKey, description, eligible, disabled, etc.
                final rawList = skillsData is List
                    ? skillsData
                    : (skillsData['skills'] ?? skillsData['items'] ?? []);
                final parsedSkills = <Map<String, dynamic>>[];
                final parsedIds = <String>{};
                Iterable iterableList;
                if (rawList is List) {
                  iterableList = rawList;
                } else if (rawList is Map) {
                  iterableList = rawList.values;
                } else {
                  iterableList = [];
                }

                for (final skill in iterableList) {
                  if (skill is Map) {
                    final mapped = Map<String, dynamic>.from(skill);
                    parsedSkills.add(mapped);
                    final id = (mapped['skillKey'] ?? mapped['name'] ?? mapped['id'])?.toString().toLowerCase() ?? '';
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
          }
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


  /// Route a chat message to the correct backend based on model prefix.
  ///
  /// • local-llm/ → fllama NDK (on-device inference, no network, no gateway)
  /// • ollama/    → WS chat.send → gateway → Ollama :11434 (dashboard visible).
  ///                Modelfile PARAMETER num_ctx 2048 should cap context.
  ///                Watch hub logs: n_ctx=4096 = stable; n_ctx=32768 = gateway
  ///                is overriding it (fundamental gateway limitation).
  ///                WS fallback: direct :11434 with options.num_ctx when WS fails.
  /// • cloud      → WS chat.send → gateway agent loop → visible in dashboard
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

    // All other models (ollama/ and cloud) use WS chat.send → gateway.
    // If WS is unavailable, ollama/ falls back to direct :11434 so inference
    // still works; cloud falls back to HTTP gateway proxy.
    final isOllama = model.startsWith('ollama/');
    // Cloud Ollama requires `ollama signin` on the device (or OLLAMA_API_KEY env var).
    // If auth is missing, Ollama returns 401 "not allowed" — surface this early.
    if (isOllama && model.contains(':cloud')) {
      _addActivity('[CHAT] ☁ Cloud Ollama model — requires `ollama signin` on device (or OLLAMA_API_KEY). If you see "not allowed", run: ollama signin');
    }
    // Cloud Ollama models (e.g. qwen3-coder:480b-cloud) are proxied by the
    // local Ollama daemon to ollama.com — they need different handling:
    // no context cap, no mobile system prompt, no cold-start logic.
    final isCloudOllama = isOllama && model.contains(':cloud');
    final isLocalOllama = isOllama && !isCloudOllama;

    // For local Ollama: proactively clear bloated session files so the gateway
    // doesn't forward a wall of stale history on every request.
    // Fire-and-forget — don't block the message on disk I/O.
    if (isLocalOllama) unawaited(_clearStaleSessions());

    // For local Ollama: memory snapshot + cold-start detection.
    // Fix 4+5: read /proc/meminfo directly (no PRoot spawn) and use the
    // /api/ps result to extend the WS timeout for cold starts.
    bool ollamaColdStart = true; // assume cold until /api/ps says otherwise
    if (isLocalOllama) {
      try {
        // /proc/meminfo is readable directly from Android — no PRoot needed.
        final meminfo = await File('/proc/meminfo').readAsString()
            .catchError((_) => '');
        final totalMb = _parseMemKbLineToMb(
            meminfo.split('\n').firstWhere((l) => l.startsWith('MemTotal:'), orElse: () => ''));
        final availMb = _parseMemAvailableMb(
            meminfo.split('\n').firstWhere((l) => l.startsWith('MemAvailable:'), orElse: () => ''));
        final swapMb = _parseMemKbLineToMb(
            meminfo.split('\n').firstWhere((l) => l.startsWith('SwapFree:'), orElse: () => ''));
        _addActivity('[MEM] Total: ${totalMb}MB | Available: ${availMb}MB | Swap: ${swapMb}MB');
        if (availMb < 1100) {
          _addActivity('[MEM] ⚠ Only ${availMb}MB free — need ~1.1GB for Qwen2.5-1.5B. Inference may crash.');
        } else if (availMb < 1500) {
          _addActivity('[MEM] △ ${availMb}MB free — tight but may work');
        }
      } catch (_) {}
      // Check what Ollama has loaded — also determines cold-start timeout.
      try {
        final psResp = await http.get(Uri.parse('http://127.0.0.1:11434/api/ps'))
            .timeout(const Duration(seconds: 3));
        if (psResp.statusCode == 200) {
          final psData = jsonDecode(psResp.body) as Map<String, dynamic>?;
          final loadedModels = psData?['models'] as List?;
          if (loadedModels != null && loadedModels.isNotEmpty) {
            final names = loadedModels.map((m) => (m as Map)['name'] ?? '?').join(', ');
            _addActivity('[MEM] Ollama loaded: $names');
            ollamaColdStart = false; // model is already in memory
          } else {
            _addActivity('[MEM] Ollama: no model cached (cold start — using extended timeout)');
          }
        }
      } catch (_) {}
    }
    final wsOk = await _ensureWebSocket(token);
    if (wsOk) {
      // HOT-SWITCHING: If user changed model, update gateway config
      final changes = await _syncModelToConfig(model);
      if (changes.isNotEmpty) {
        _addActivity('[CHAT] Updating gateway config: $changes');
      }
      // Context window for local Ollama is controlled by the Modelfile
      // PARAMETER num_ctx written at `ollama create` time by _buildModelfileTemplate.
      // sessions.patch rejects 'contextWindow' and 'systemPrompt' as invalid fields
      // in this gateway version — removed to eliminate error noise in gateway logs.
    } else {
      if (isLocalOllama) {
        // WS fallback: direct local Ollama — no dashboard, but inference still works.
        final ollamaModel = model.substring('ollama/'.length);
        _addActivity('[CHAT] ⚠ WS unavailable — direct fallback for $ollamaModel');
        yield* sendMessageHttp(message,
            model: ollamaModel,
            directUrl: 'http://127.0.0.1:11434/v1/chat/completions',
            conversationHistory: conversationHistory,
            ollamaOptions: {'num_ctx': _getDynamicContextSize(ollamaModel)});
      } else {
        // Cloud Ollama fallback: route via HTTP gateway proxy (same as cloud models).
        yield* sendMessageHttp(message, model: model, token: token,
            conversationHistory: conversationHistory);
      }
      return;
    }

    _addActivity('[CHAT] → Sending to $model');

    final requestId = const Uuid().v4();
    final chunkController = StreamController<String>();

    // Use sessionKey from gateway handshake, or default to 'main'
    final sessionKey = _connection!.mainSessionKey ?? 'main';

    // Cold-start (model not yet in RAM) gets 3 min; warm gets 2 min; cloud 90 s.
    // Local Ollama: extended timeout for cold-start model loading.
    // Cloud Ollama: treat like any cloud model (90s) — no local load delay.
    final timeoutMs = isLocalOllama ? (ollamaColdStart ? 180000 : 120000) : 90000;

    final responseStream = _connection!.sendRequest({
      'method': 'chat.send',
      'params': {
        'sessionKey': sessionKey,
        'message': message,
        'idempotencyKey': const Uuid().v4(),
        'timeoutMs': timeoutMs,
      },
      'id': requestId,
    });

    bool firstToken = true;
    // activeRunId: initially from chat.send ACK, then corrected to the actual
    // run ID seen in event agent phase=start (queued messages get a different runId).
    String? activeRunId;
    // runStarted: gates event chat state=final so a stale final from a prior run
    // (which may complete after our Flutter timeout) cannot close the next request's
    // stream before any content arrives.
    bool runStarted = false;
    late StreamSubscription frameSub;
    frameSub = responseStream.listen(
      (frame) {
        try {
          final type = frame['type'] as String?;

          // Gateway-level error (e.g. rate limit, provider failure)
          if (type == 'error') {
            final payload = frame['payload'] as Map<String, dynamic>?;
            final errMsg = payload?['message'] as String? ?? 'API Error encountered';
            _addActivity('[CHAT] ✗ $errMsg');
            if (!chunkController.isClosed) {
              chunkController.add('[Error] $errMsg');
              chunkController.close();
            }
            return;
          }

          // Any frame carrying a root-level 'error' field
          if (frame.containsKey('error') && frame['error'] != null) {
            final errObj = frame['error'];
            final errStr = errObj is Map ? (errObj['message']?.toString() ?? errObj.toString()) : errObj.toString();
            if (errStr.toLowerCase().contains('rate limit') || errStr.toLowerCase().contains('api') || errStr.toLowerCase().contains('invalid')) {
              _addActivity('[CHAT] ✗ $errStr');
              if (!chunkController.isClosed) {
                chunkController.add('[Error] $errStr');
                chunkController.close();
              }
              return;
            }
          }

          // ACK from chat.send — ok:true means streaming started; ok:false means rejected
          if (type == 'res' && frame['id'] == requestId) {
            final ok = frame['ok'] as bool? ?? false;
            if (!ok) {
              final error = frame['error'] as Map<String, dynamic>?;
              final msg = error?['message'] as String? ?? 'chat.send failed';
              _addActivity('[CHAT] ✗ $msg');
              if (!chunkController.isClosed) {
                chunkController.add('[Error] $msg');
                chunkController.close();
              }
            } else {
              activeRunId = frame['runId'] as String?;
              _addActivity('[CHAT] ← Gateway accepted (streaming...)');
            }
            return;
          }

          // Agent-initiated messages (continuous streaming)
          if (type == 'event' && frame['event'] == 'agent.message') {
            final payload = frame['payload'] as Map<String, dynamic>?;
            final message = payload?['text'] as String?;
            if (message != null && message.isNotEmpty) {
              _addActivity('[CHAT] ← Agent initiated: $message');
              if (!chunkController.isClosed) {
                chunkController.add(message);
              }
            }
            return;
          }

          // Chat lifecycle events (final / aborted / error → close stream)
          if (type == 'event' && frame['event'] == 'chat') {
            final Map<String, dynamic> data = (frame['payload'] as Map<String, dynamic>?)
                ?? (frame['data'] as Map<String, dynamic>?)
                ?? frame;
            final state = data['state'] as String?;
            // Guard: only close on final/aborted once our agent run has started.
            // event chat frames don't carry a run ID, so we use runStarted (set from
            // event agent phase=start) as the signal that this session event is ours.
            // Without this, a stale chat=final from run N closing after our 240s Flutter
            // timeout would silently close run N+1's stream before content arrives.
            if ((state == 'final' || state == 'aborted' || state == 'error') &&
                (runStarted || !firstToken)) {
              if (!chunkController.isClosed) {
                if (isOllama) _addActivity('[CHAT] ✓ Hub stream finished (state: $state)');
                chunkController.close();
              }
            }
          }

          // Agent events — streaming text deltas and lifecycle
          if (type == 'event' && frame['event'] == 'agent') {
            final payload = frame['payload'] as Map<String, dynamic>?;
            final agentRun = frame['run'] as String? ?? payload?['run'] as String?;
            final innerData = payload?['data'] as Map<String, dynamic>?
                ?? frame['data'] as Map<String, dynamic>?;
            final stream = (payload?['stream'] ?? frame['stream']) as String?;

            if (stream == 'assistant') {
              // Filter text from runs other than ours (activeRunId updated from phase=start)
              if (activeRunId != null && agentRun != null && agentRun != activeRunId) return;
              final text = (innerData?['text'] ?? payload?['text'] ?? frame['text']) as String?;
              if (text != null && text.isNotEmpty) {
                if (firstToken) {
                  firstToken = false;
                  _addActivity('[CHAT] ✓ First token received');
                }
                chunkController.add(text);
              }
            } else if (stream == 'lifecycle') {
              final phase = (innerData?['phase'] ?? payload?['phase'] ?? frame['phase']) as String?;
              if (phase == 'start' && !runStarted) {
                // For queued messages the ACK runId differs from the actual run ID in events.
                // Capture the real run ID from the first phase=start we see after our ACK.
                if (agentRun != null) activeRunId = agentRun;
                runStarted = true;
              } else if (phase == 'error') {
                if (activeRunId != null && agentRun != null && agentRun != activeRunId) return;
                final rawError = (innerData?['error'] ?? payload?['error'] ?? frame['error'])
                    ?.toString() ?? 'Unknown API error';
                final String error;
                if (rawError.toLowerCase().contains('does not support tools')) {
                  error = 'This model does not support tool use. '
                      'Tap the TOOLS button in the model selector to disable it, then try again.';
                } else {
                  error = rawError;
                }
                _addActivity('[CHAT] ✗ $error');
                if (!chunkController.isClosed) {
                  chunkController.add('[Error] $error');
                  chunkController.close();
                }
              }
            } else if (stream == 'error') {
              // Internal gateway sequencing noise (e.g. reason=seq gap after a retry).
              // Real provider errors surface through stream=lifecycle phase=error.
              final reason = (payload?['reason'] ?? frame['reason']) as String?;
              if (reason == 'seq gap') return;
              if (activeRunId != null && agentRun != null && agentRun != activeRunId) return;
              final rawErr = (innerData?['error'] ?? payload?['error'] ?? payload?['reason']
                  ?? frame['reason'] ?? frame['error'])?.toString() ?? '';
              final error = rawErr.isNotEmpty ? rawErr
                  : 'Provider unavailable — if using local LLM, the model may still be loading. Try again in a moment.';
              _addActivity('[CHAT] ✗ $error');
              if (!chunkController.isClosed) {
                chunkController.add('[Error] $error');
                chunkController.close();
              }
            }
          }
        } catch (_) {}
      },
      onError: (e) {
        if (!chunkController.isClosed) {
          // Always convert to a string message — never propagate raw stream errors.
          // StateError('WebSocket disconnected') from _onDisconnect would otherwise
          // surface as "[Error: Bad state: ...]" via the catch block.
          final msg = (e is StateError)
              ? '[Error] Gateway connection lost. Please try again.'
              : '[Error] WebSocket error: $e';
          chunkController.add(msg);
          chunkController.close();
        }
      },
      onDone: () {
        if (!chunkController.isClosed) chunkController.close();
      },
    );

    try {
      final streamTimeoutSec = isLocalOllama ? 600 : 90;
      await for (final chunk in chunkController.stream
          .timeout(Duration(seconds: streamTimeoutSec))) {
        yield chunk;
      }
      _addActivity('[CHAT] ✓ Complete');
    } on TimeoutException {
      if (isLocalOllama) {
        _addActivity('[CHAT] ✗ Timed out after 600 s');
        yield '[Error] Ollama timed out (600 s). The model runner may have crashed — '
              'check hub logs for OOM errors.';
      } else {
        yield '[Error] Gateway chat timed out after 90 seconds.';
      }
    } catch (e) {
      _addActivity('[CHAT] ✗ $e');
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
    Map<String, dynamic>? ollamaOptions, // Ollama-specific inference options (e.g. num_ctx)
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

    // Always use the actual model name. The old 'local-llm' override was for
    // llama-server, but that path exits early before reaching here. directUrl
    // now exclusively means Ollama direct routing, which needs the real name.
    final effectiveModel = model;

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
          if (ollamaOptions != null) 'options': ollamaOptions,
          // Keep model loaded indefinitely — prevents 3-4 s reload on every message.
          if (isDirectLlama) 'keep_alive': -1,
        });

      // Ollama on mobile can be slow; give it 4 minutes before giving up (matches WS path).
      final timeoutDuration = isDirectLlama
          ? const Duration(seconds: 240)
          : const Duration(seconds: 90);

      if (isDirectLlama) {
        _addActivity('[CHAT] → Sending to $effectiveModel');
      }

      final streamedResponse = await client.send(request).timeout(timeoutDuration);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        if (isDirectLlama) {
          _addActivity('[CHAT] ✗ HTTP ${streamedResponse.statusCode}');
        }
        yield '[Error] HTTP ${streamedResponse.statusCode}: $body';
        return;
      }

      if (isDirectLlama) {
        _addActivity('[CHAT] ← Ollama accepted (HTTP 200)');
      }

      // Process the SSE stream.
      // Handles two formats:
      //   SSE (OpenAI-compat):  data: {"choices":[{"delta":{"content":"..."}}]}
      //   NDJSON (Ollama native): {"message":{"role":"assistant","content":"..."}}
      bool firstChunk = true;
      int rawChunks = 0;
      final List<String> rawSamples = [];
      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;
        rawChunks++;
        if (isDirectLlama && rawChunks <= 3) rawSamples.add(chunk.length > 120 ? chunk.substring(0, 120) : chunk);

        String? rawJson;
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6).trim();
          if (data == '[DONE]') break;
          rawJson = data;
        } else if (chunk.startsWith('{')) {
          // Ollama native NDJSON — no SSE envelope
          rawJson = chunk;
        }

        if (rawJson == null) continue;

        try {
          final json = jsonDecode(rawJson) as Map<String, dynamic>;

          // OpenAI-compat streaming: choices[0].delta.content
          final delta = (json['choices'] as List?)?[0]?['delta']?['content'] as String?;
          // OpenAI-compat non-streaming (single chunk): choices[0].message.content
          final messageContent = (json['choices'] as List?)?[0]?['message']?['content'] as String?;
          // Ollama native NDJSON: message.content + done flag
          final nativeContent = (json['message'] as Map?)?['content'] as String?;
          final done = json['done'] as bool? ?? false;

          final token = (delta != null && delta.isNotEmpty)
              ? delta
              : (messageContent != null && messageContent.isNotEmpty)
                  ? messageContent
                  : (nativeContent != null && nativeContent.isNotEmpty)
                      ? nativeContent
                      : null;

          if (token != null) {
            if (firstChunk && isDirectLlama) {
              firstChunk = false;
              _addActivity('[CHAT] ✓ First token received');
            }
            yield token;
          }

          if (done) break; // Ollama native signals end with done:true
        } catch (e) {
          // Malformed chunk or heartbeat, skip silently unless debug
          debugPrint('[GatewayService] SSE parse error: $e (raw: $rawJson)');
        }
      }
      if (isDirectLlama) {
        _addActivity('[CHAT] ✓ Stream complete ($rawChunks chunks)');
        if (firstChunk) {
          for (int i = 0; i < rawSamples.length; i++) {
            _addActivity('[CHAT] raw[$i]: ${rawSamples[i]}');
          }
        }
      }
    } on TimeoutException {
      if (isDirectLlama) {
        _addActivity('[CHAT] ✗ Timed out after 240 s');
        yield '[Error] Ollama timed out (240 s). '
              'The device may be thermally throttled — try a shorter message or wait for it to cool.';
      } else {
        yield '[Error] Gateway chat timed out.';
      }
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
  
  
  /// Ensure agents.defaults.model.primary in openclaw.json matches the
  /// user-selected [model]. Returns a map of changed metadata if the
  /// config was updated, allowing for hot-sync via sessions.patch.
  Future<Map<String, dynamic>> _syncModelToConfig(String model) async {
    final Map<String, dynamic> changedMetadata = {};
    final config = await _readConfig();
    
    config['agents'] ??= {};
    config['agents']['defaults'] ??= {};
    config['agents']['defaults']['model'] ??= {};
    
    final current = config['agents']['defaults']['model']['primary'] as String?;
    bool needsSync = false;
    
    if (current != model) {
      config['agents']['defaults']['model']['primary'] = model;
      needsSync = true;
    }
    
    if (needsSync) {
      await _writeConfig(config);
      _addActivity('[MODEL] syncToConfig: $model');
      
      changedMetadata['primaryModel'] = model;
    }
    
    return changedMetadata;
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
    _chatActivityController.close();
  }
}

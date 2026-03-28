import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import '../models/agent_info.dart';
import 'gateway_connection.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

class GatewayService {
  static final GatewayService _instance = GatewayService._internal();
  factory GatewayService() => _instance;
  GatewayService._internal();

  Timer? _healthTimer;
  StreamSubscription? _logSubscription;
  GatewayConnection? _connection;
  bool _healthCheckInFlight = false;
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
    // 9a9614a Optimization: Do not block splash screen during auto-start
    unawaited(_attachOrStart(autoStart: prefs.autoStartGateway));
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
        // (savedUrl should be retrieved here if needed, but prefs.init already happened)
        logs: [..._state.logs, '[INFO] Gateway process detected, attaching...'],
      ));

      _subscribeLogs();
      _startHealthCheck();
      unawaited(_validateGatewayProcess()); 
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
    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      clearError: true,
      logs: [..._state.logs, '[INFO] Starting gateway...'],
      dashboardUrl: savedUrl,
    ));

    try {
      await NativeBridge.acquirePartialWakeLock();
      await _configureGateway();
      await Future.delayed(const Duration(milliseconds: 800));

      final success = await NativeBridge.startGateway();
      
      if (!success) {
        throw Exception('Native start failed.');
      }
      
      await Future.delayed(const Duration(seconds: 1));
      _subscribeLogs();
      _startHealthCheck();
      // Use unawaited to avoid blocking the main startup sequence
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

  /// NEW: Validate that the gateway process is actually ready to serve requests
  Future<void> _validateGatewayProcess() async {
    const maxAttempts = 6; // 30 seconds total
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 5));
      
      try {
        // Check if gateway process is still running
        final isRunning = await NativeBridge.isGatewayRunning();
        if (!isRunning) {
          _updateState(_state.copyWith(
            status: GatewayStatus.stopped,
            logs: [..._state.logs, '[WARN] Gateway process died during validation'],
          ));
          return;
        }

        // Check if gateway is responding to HTTP requests
        final response = await http.head(Uri.parse(AppConstants.gatewayUrl))
            .timeout(const Duration(seconds: 3));
        
        if (response.statusCode < 500) {
          _updateState(_state.copyWith(
            logs: [..._state.logs, '[INFO] Gateway process validated and responding'],
          ));
          return;
        }
      } catch (_) {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[DEBUG] Gateway validation attempt ${i + 1}/$maxAttempts'],
        ));
      }
    }
    
    _updateState(_state.copyWith(
      logs: [..._state.logs, '[WARN] Gateway validation failed - process may be stuck'],
    ));
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

  /// Helper to get the host-side path to the openclaw config file
  Future<String> _openClawConfigPath() async {
    final appSupportDir = await getApplicationSupportDirectory();
    return '${appSupportDir.path}/rootfs/root/.openclaw/openclaw.json';
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
    
    config['skills'] ??= {};
    config['skills']['discovery'] = "http://127.0.0.1:8765/api/tools";
    config['skills']['mode'] = "auto";
    config['skills']['sync'] = "mirror";

    config['gateway']['openaiCompat'] ??= {};
    config['gateway']['openaiCompat']['enabled'] = true;

    await _writeConfig(config);
  }

  /// Direct I/O: Persist the selected model (no proot overhead).
  Future<void> persistModel(String model) async {
    final config = await _readConfig();
    config['agents'] ??= {};
    config['agents']['defaults'] ??= {};
    config['agents']['defaults']['model'] ??= {};
    config['agents']['defaults']['model']['primary'] = model;
    await _writeConfig(config);
  }

  /// Map a provider name to its default model string (provider/model).
  /// Public so GatewayProvider can call it during configureAndStart.
  String getModelForProvider(String provider) {
    switch (_normalizeProvider(provider)) {
      case 'google': return 'google/gemini-3.1-pro-preview';
      case 'anthropic': return 'anthropic/claude-opus-4.6';
      case 'openai': return 'openai/gpt-4o';
      case 'groq': return 'groq/llama-3.1-405b';
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
      final appSupportDir = await getApplicationSupportDirectory();
      final authPath = '${appSupportDir.path}/rootfs/root/.openclaw/agents/main/agent/auth-profiles.json';
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



  Future<void> stop() async {
    if (_isStopping) return;
    _isStopping = true;
    _healthTimer?.cancel();
    _logSubscription?.cancel();

    try {
      await NativeBridge.stopGateway();
      _updateState(GatewayState(
        status: GatewayStatus.stopped,
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

        // ── 4. RPC discovery (health, skills, capabilities) with logging ─
        if (_connection?.state == GatewayConnectionState.connected) {
          try {
            final healthResult = await invoke('health');
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
            final skillsResult = await invoke('skills.list');
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
            final capResult = await invoke('capabilities.list');
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
  Stream<String> sendMessage(String message, {String? model}) async* {
    model = await _resolveModel(model);

    // SEAMLESS ROUTING: Use the OpenAI-compatible HTTP path for specific model overrides.
    // This supports per-message model selection (including Local LLM) with full streaming,
    // avoiding the rigid parameter constraints of the main WebSocket RPC.
    if (model.startsWith('local-llm') || model.contains('/')) {
      yield* sendMessageHttp(message, model: model);
      return;
    }

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

    // Use persistent connection with auto-reconnect
    if (_connection == null) {
      _connection = GatewayConnection();
      _connection!.stateStream.listen((wsState) {
        _updateState(_state.copyWith(
          isWebsocketConnected: wsState == GatewayConnectionState.connected,
        ));
      });
    }

    if (_connection!.state != GatewayConnectionState.connected) {
      final ok = await _connection!.connect(token);
      if (!ok) {
        // Fallback to HTTP if WS fails
        yield* sendMessageHttp(message, model: model, token: token);
        return;
      }
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
               // Gateway stream=error (e.g. seq gap / unknown provider error)
               final error = (innerData?['error'] ?? payload?['error'] ?? payload?['reason'] ?? frame['reason'] ?? frame['error'])?.toString() ?? 'Unknown API stream error';
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
  Stream<String> sendMessageHttp(String message, {String? model, String? token}) async* {
    model = await _resolveModel(model);
    token ??= await retrieveTokenFromConfig();
    if (token == null || token.isEmpty) {
      yield '[Error] No auth token for model routing.';
      return;
    }

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode({
          'model': model,
          'messages': [{'role': 'user', 'content': message}],
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

  /// Vision message: POST directly to llama-server :8081 using the OpenAI
  /// multimodal content format (image_url + text).  Only works when a
  /// multimodal model (LLaVA, Qwen2-VL) is loaded and running on :8081.
  ///
  /// [imageBase64] – raw base64 string (no data-URI prefix).
  /// [mimeType]    – e.g. "image/jpeg" (default).
  /// [prompt]      – user text; falls back to a generic describe prompt.
  Stream<String> sendVisionMessage(
    String prompt,
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) async* {
    final dataUri = 'data:$mimeType;base64,$imageBase64';
    final effectivePrompt =
        prompt.trim().isEmpty ? 'Describe what you see in this image.' : prompt.trim();

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'local-llm',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {'url': dataUri},
                    },
                    {'type': 'text', 'text': effectivePrompt},
                  ],
                },
              ],
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = (choices[0]['message'] as Map?)?['content'] as String?;
          if (content != null) {
            yield content;
            return;
          }
        }
        yield '[Error] Empty vision response from local model.';
      } else {
        yield '[Error] Vision request failed (HTTP ${response.statusCode}). '
            'Make sure a vision model (LLaVA or Qwen2-VL) is running.';
      }
    } on TimeoutException {
      yield '[Error] Vision request timed out. The model may still be loading — try again in a moment.';
    } catch (e) {
      yield '[Error] Vision error: $e';
    }
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

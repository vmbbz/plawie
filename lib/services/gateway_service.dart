import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import 'gateway_connection.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

class GatewayService {
  Timer? _healthTimer;
  StreamSubscription? _logSubscription;
  GatewayConnection? _connection;
  final _stateController = StreamController<GatewayState>.broadcast();
  GatewayState _state = const GatewayState();
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
  Future<void> init() async {
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    final alreadyRunning = await NativeBridge.isGatewayRunning();
    if (alreadyRunning) {
      // PROD FIX: If already running, DO NOT call start().
      // Just attach to the existing process.
      _updateState(_state.copyWith(
        status: GatewayStatus.starting, // Transitioning to attached state
        dashboardUrl: savedUrl,
        logs: [..._state.logs, '[INFO] Gateway process detected, reconnecting...'],
      ));

      _subscribeLogs();
      _startHealthCheck();
      
      // Proactively try to get the token from the existing process
      await fetchAuthenticatedDashboardUrl(force: true);
    } else {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[DEBUG] GatewayService.init: alreadyRunning=$alreadyRunning, autoStartGateway=${prefs.autoStartGateway}']
      ));
      if (prefs.autoStartGateway) {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[INFO] Auto-starting gateway...'],
        ));
        // Don't await here to avoid blocking splash screen if initialization takes time
        start();
      }
    }
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
      }
      _updateState(_state.copyWith(logs: logs, dashboardUrl: dashboardUrl));
    });
  }

  /// Patch /root/.openclaw/openclaw.json to clear denyCommands, set allowCommands,
  /// and configure gateway host/port (automates binding — no CLI `--binding` flag needed).
  Future<void> _configureGateway() async {
    const allowCommands = [
      'camera.snap', 'camera.clip', 'camera.list',
      'canvas.navigate', 'canvas.eval', 'canvas.snapshot',
      'flash.on', 'flash.off', 'flash.toggle', 'flash.status',
      'location.get',
      'screen.record',
      'sensor.read', 'sensor.list',
      'haptic.vibrate',
    ];
    
    final allowJson = jsonEncode(allowCommands);
    
    // Node.js script to merge configurations
    var script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.gateway) c.gateway = {};
if (!c.gateway.nodes) c.gateway.nodes = {};
c.gateway.nodes.denyCommands = [];
c.gateway.nodes.allowCommands = $allowJson;
c.gateway.mode = "local";
// Enable OpenAI-compatible HTTP endpoint for fallback chat
if (!c.gateway.openaiCompat) c.gateway.openaiCompat = {};
c.gateway.openaiCompat.enabled = true;
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';

    try {
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && node -e ${_shellEscape(script)}',
        timeout: 15,
      );
      // Clean up any stale/invalid keys from previous versions
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && openclaw doctor --fix',
        timeout: 15,
      );
    } catch (_) {
      // Non-fatal
    }
  }

  /// Persist the selected model using OpenClaw CLI (schema-safe).
  /// Sets the primary model via `openclaw config set` and runs doctor to validate.
  Future<void> persistModel(String model) async {
    try {
      // Set primary model via official CLI (avoids schema violations from manual JSON)
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && openclaw config set agents.defaults.model.primary "$model"',
        timeout: 15,
      );
    } catch (_) {
      // Fallback: direct JSON patch if CLI not available
      final script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {}; try { c = JSON.parse(fs.readFileSync(p,"utf8")); } catch {}
if (!c.agents) c.agents = {};
if (!c.agents.defaults) c.agents.defaults = {};
if (!c.agents.defaults.model) c.agents.defaults.model = {};
c.agents.defaults.model.primary = "$model";
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && node -e ${_shellEscape(script)}',
        timeout: 15,
      );
    }

    // Always run doctor --fix to clean up any invalid keys
    try {
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && openclaw doctor --fix',
        timeout: 15,
      );
    } catch (_) {}
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

  /// Write an API key + ensure models array (pure Node.js — no flaky CLI)
  Future<void> configureApiKey(String provider, String key) async {
    final openClawProvider = _normalizeProvider(provider);
    final envKey = _getEnvKeyForProvider(provider);

    String modelsJson;
    if (openClawProvider == 'google') {
      modelsJson = '[ { "id": "gemini-3.1-pro-preview", "name": "Gemini 3.1 Pro Preview" } ]';
    } else if (openClawProvider == 'anthropic') {
      modelsJson = '[ { "id": "claude-opus-4.6", "name": "Claude Opus 4.6" } ]';
    } else if (openClawProvider == 'openai') {
      modelsJson = '[ { "id": "gpt-4o", "name": "GPT-4o" } ]';
    } else if (openClawProvider == 'groq') {
      modelsJson = '[ { "id": "llama-3.1-405b", "name": "Llama 3.1 405B" } ]';
    } else {
      modelsJson = '[ { "id": "default", "name": "Default Model" } ]';
    }

    final script = '''
const fs = require("fs");
const path = require("path");

function updateJson(p, updater) {
  try {
    let c = {};
    if (fs.existsSync(p)) c = JSON.parse(fs.readFileSync(p, "utf8"));
    else {
      const dir = path.dirname(p);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    }
    updater(c);
    fs.writeFileSync(p, JSON.stringify(c, null, 2));
  } catch (e) { console.error(e.message); }
}

// 1. Global config
updateJson("/root/.openclaw/openclaw.json", (c) => {
  if (!c.env) c.env = {};
  if (!c.env.vars) c.env.vars = {};
  if ("$envKey") c.env.vars["$envKey"] = "$key";

  if (!c.models) c.models = {};
  if (!c.models.providers) c.models.providers = {};
  const prov = c.models.providers["$openClawProvider"] || {};
  c.models.providers["$openClawProvider"] = {
    ...prov,
    apiKey: "$key",
    models: prov.models || $modelsJson
  };
  if ("$openClawProvider" === "google" && !c.models.providers.google.baseUrl) {
    c.models.providers.google.baseUrl = "https://generativelanguage.googleapis.com/v1beta";
  }
});

// 2. Agent auth-profiles
const agentAuthPath = "/root/.openclaw/agents/main/agent/auth-profiles.json";
updateJson(agentAuthPath, (c) => {
  if (!c.providers) c.providers = {};
  c.providers["$openClawProvider"] = { ...(c.providers["$openClawProvider"] || {}), apiKey: "$key" };
});
''';

    await NativeBridge.runInProot(
      'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && node -e ${_shellEscape(script)}',
      timeout: 15,
    );
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

  /// Use Node.js to read the token directly from the openclaw.json config file.
  Future<String?> retrieveTokenFromConfig({bool force = false}) async {
    // Use cache if available and fresh (under 5 mins)
    if (!force && _cachedToken != null && _lastTokenFetch != null &&
        DateTime.now().difference(_lastTokenFetch!).inMinutes < 5) {
      return _cachedToken;
    }

    const script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
try {
  const c = JSON.parse(fs.readFileSync(p, "utf8"));
  if (c.gateway && c.gateway.auth && c.gateway.auth.token) {
    process.stdout.write(c.gateway.auth.token);
  }
} catch (e) {}
''';
    try {
      final token = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && node -e ${_shellEscape(script)}',
        timeout: 5,
      );
      final trimmedToken = token.trim();
      if (trimmedToken.isNotEmpty) {
        _cachedToken = trimmedToken;
        _lastTokenFetch = DateTime.now();
        return trimmedToken;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Escape a string for use as a single-quoted shell argument.
  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  Future<void> start() async {
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      clearError: true,
      logs: [..._state.logs, '[INFO] Starting gateway...'],
      dashboardUrl: savedUrl,
    ));

    try {
      // PRODUCTION UPGRADE: Acquire wake lock to prevent Android PPK
      await NativeBridge.acquirePartialWakeLock();
      
      await _configureGateway();
      // Android 14+ requires the activity to be fully visible before
      // startForegroundService(). Reduced delay for perceived speed.
      await Future.delayed(const Duration(milliseconds: 800));

      final success = await NativeBridge.startGateway();
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[DEBUG] GatewayService.start: NativeBridge.startGateway success=$success'],
      ));

      // PROD UPGRADE: Proactive Check for Battery Optimization
      try {
        final isOptimized = await NativeBridge.isBatteryOptimized();
        if (isOptimized) {
          _updateState(_state.copyWith(
            logs: [..._state.logs, '[WARN] Battery Optimization is ACTIVE. This may kill the server in the background.'],
          ));
          await NativeBridge.requestBatteryOptimization();
        }
      } catch (_) {}

      if (!success) {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[WARN] Native start failed, attempting doctor fix...'],
        ));
        try {
          await NativeBridge.runInProot(
            'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && openclaw doctor --fix',
            timeout: 30,
          );
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 500));
        final retrySuccess = await NativeBridge.startGateway();
        if (!retrySuccess) throw Exception('Native start failed after doctor fix');
      }
      
      await Future.delayed(const Duration(seconds: 1)); // Give tmux/proot time (reduced from 3s)
      _subscribeLogs();
      _startHealthCheck();
      
      // Proactively acquire auth token
      await fetchAuthenticatedDashboardUrl(force: true);
    } catch (e) {
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Failed to start: $e',
        logs: [..._state.logs, '[ERROR] Failed to start: $e'],
      ));
    }
  }

  Future<void> stop() async {
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
    }
  }

  void _startHealthCheck() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.healthCheckIntervalMs),
      (_) => _checkHealth(),
    );
  }

  Future<void> _checkHealth() async {
    try {
      final response = await http
          .head(Uri.parse(AppConstants.gatewayUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode < 500) {
        if (_state.status != GatewayStatus.running) {
          _updateState(_state.copyWith(
            status: GatewayStatus.running,
            startedAt: _state.startedAt ?? DateTime.now(),
            logs: [..._state.logs, '[INFO] Gateway is healthy'],
          ));
        }

        // 2. Fetch detailed RPC health
        if (_connection?.state == GatewayConnectionState.connected) {
          try {
            final healthResult = await invoke('health');
            if (healthResult['ok'] == true) {
              _updateState(_state.copyWith(detailedHealth: healthResult['payload']));
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // Still starting or temporarily unreachable
      final isRunning = await NativeBridge.isGatewayRunning();
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          logs: [..._state.logs, '[WARN] Gateway process not running'],
        ));
        _healthTimer?.cancel();
      }
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
  Stream<String> sendMessage(String message, {String model = 'google/gemini-3.1-pro-preview'}) async* {
    // Retrieve auth token
    String? token;
    try {
      token = await retrieveTokenFromConfig();
    } catch (_) {}

    if (token == null || token.isEmpty) {
      yield '[Error] No gateway auth token available.\n'
            'Please ensure the gateway has started and the token is saved in openclaw.json.';
      return;
    }

    // Use persistent connection with auto-reconnect
    if (_connection == null) {
      _connection = GatewayConnection();
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
      
      if (_connection == null) _connection = GatewayConnection();
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

  /// HTTP fallback: POST to /v1/chat/completions (OpenAI-compatible endpoint).
  ///
  /// Used when WebSocket connection fails. Simpler but doesn't support streaming.
  Stream<String> sendMessageHttp(String message, {String model = 'google/gemini-3.1-pro-preview', String? token}) async* {
    token ??= await retrieveTokenFromConfig();
    if (token == null || token.isEmpty) {
      yield '[Error] No auth token for HTTP fallback.';
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': message},
          ],
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = (choices[0]['message'] as Map?)?['content'] as String?;
          if (content != null) {
            yield content;
          } else {
            yield '[Error] Empty response from HTTP endpoint.';
          }
        } else {
          yield '[Error] No choices in HTTP response.';
        }
      } else {
        yield '[Error] HTTP ${response.statusCode}: ${response.body}';
      }
    } on TimeoutException {
      yield '[Error] HTTP chat timed out after 90 seconds.';
    } catch (e) {
      yield '[Error] HTTP chat error: $e';
    }
  }

  void dispose() {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _connection?.dispose();
    _stateController.close();
  }
}

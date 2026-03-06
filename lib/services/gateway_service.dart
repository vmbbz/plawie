import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

class GatewayService {
  Timer? _healthTimer;
  StreamSubscription? _logSubscription;
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

  /// Check if the gateway is already running (e.g. after app restart)
  /// and sync the UI state accordingly.  If not running but auto-start
  /// is enabled, start it automatically.
  Future<void> init() async {
    final prefs = PreferencesService();
    await prefs.init();
    final savedUrl = prefs.dashboardUrl;

    final alreadyRunning = await NativeBridge.isGatewayRunning();
    if (alreadyRunning) {
      // Write allowCommands config so the next gateway restart picks it up,
      // and in case the running gateway supports config hot-reload.
      await _configureGateway();
      _updateState(_state.copyWith(
        status: GatewayStatus.starting,
        dashboardUrl: savedUrl,
        logs: [..._state.logs, '[INFO] Gateway process detected, reconnecting...'],
      ));

      _subscribeLogs();
      _startHealthCheck();
    } else if (prefs.autoStartGateway) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[INFO] Auto-starting gateway...'],
      ));
      await start();
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
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';

    try {
      await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 15,
      );
    } catch (_) {
      // Non-fatal
    }
  }

  /// Persist the selected model to openclaw.json
  Future<void> persistModel(String model) async {
    final script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
let c = {}; try { c = JSON.parse(fs.readFileSync(p,"utf8")); } catch {}
c.agents = c.agents || {}; c.agents.defaults = c.agents.defaults || {};
c.agents.defaults.model = { ...(c.agents.defaults.model || {}), primary: "$model" };
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    await NativeBridge.runInProot(
      'node -e ${_shellEscape(script)}',
      timeout: 15,
    );
  }

  /// Normalize provider names to OpenClaw internal identifiers.
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

  /// Write an API key directly to openclaw.json and sync with agent auth stores.
  Future<void> configureApiKey(String provider, String key) async {
    final openClawProvider = _normalizeProvider(provider);
    final envKey = _getEnvKeyForProvider(provider);
    
    final script = '''
const fs = require("fs");
const path = require("path");

function updateJson(p, updater) {
  try {
    let c = {};
    if (fs.existsSync(p)) {
      c = JSON.parse(fs.readFileSync(p, "utf8"));
    } else {
      const dir = path.dirname(p);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    }
    updater(c);
    fs.writeFileSync(p, JSON.stringify(c, null, 2));
    return true;
  } catch (e) {
    console.error("Failed to update " + p + ": " + e.message);
    return false;
  }
}

// 1. Update global openclaw.json
updateJson("/root/.openclaw/openclaw.json", (c) => {
  if (!c.env) c.env = {};
  if ("$envKey") c.env["$envKey"] = "$key";
  
  // World-Class Fix: AI providers belong in models.providers, NOT secrets.providers
  if (!c.models) c.models = {};
  if (!c.models.providers) c.models.providers = {};
  
  // Ensure we don't overwrite the whole provider object if it exists (preserve baseUrl/models)
  const existingProvider = c.models.providers["$openClawProvider"] || {};
  c.models.providers["$openClawProvider"] = {
    ...existingProvider,
    apiKey: "$key"
  };

  // Add default baseUrl for Google if not present
  if ("$openClawProvider" === "google" && !c.models.providers.google.baseUrl) {
    c.models.providers.google.baseUrl = "https://generativelanguage.googleapis.com/v1beta";
  }
});

// 2. Update agent auth-profiles.json for the 'main' agent
const agentAuthPath = "/root/.openclaw/agents/main/agent/auth-profiles.json";
updateJson(agentAuthPath, (c) => {
  if (!c.providers) c.providers = {};
  // Per fixes.md, ensure we preserve existing provider metadata (additive update)
  c.providers["$openClawProvider"] = { ...(c.providers["$openClawProvider"] || {}), apiKey: "$key" };
});
''';
    await NativeBridge.runInProot(
      'node -e ${_shellEscape(script)}',
      timeout: 15,
    );

    // World-Class Fix: Ensure the models array exists for this provider
    await _ensureModelsArray(provider);
  }

  /// Ensures every provider has the required models array (fixes the exact error)
  Future<void> _ensureModelsArray(String provider) async {
    final openClawProvider = _normalizeProvider(provider);

    String modelId;
    String modelName;

    switch (openClawProvider) {
      case 'google':
        modelId = 'gemini-3.1-pro-preview';
        modelName = 'Gemini 3.1 Pro Preview';
        break;
      case 'anthropic':
        modelId = 'claude-opus-4.6';
        modelName = 'Claude Opus 4.6';
        break;
      case 'groq':
        modelId = 'llama-3.1-405b';
        modelName = 'Llama 3.1 405B';
        break;
      case 'openai':
        modelId = 'gpt-4o';
        modelName = 'GPT-4o';
        break;
      default:
        modelId = 'default';
        modelName = 'Default Model';
    }

    await NativeBridge.runInProot('''
      openclaw models add --provider $openClawProvider --id $modelId --name "$modelName" || true
      openclaw doctor --fix
    ''', timeout: 15);
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
      final urlWithToken = baseUrl.contains('?')
          ? '$baseUrl&token=$token'
          : '$baseUrl/?token=$token';
      prefs.dashboardUrl = urlWithToken;
      _updateState(_state.copyWith(
        dashboardUrl: urlWithToken,
        logs: [..._state.logs, '[INFO] Gateway auth token acquired from config.'],
      ));
      return urlWithToken;
    }

    // STEP 2: Fallback to CLI dashboard probe if config read fails or token is missing.
    try {
      final output = await NativeBridge.runInProot('openclaw dashboard --no-open', timeout: 10);
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
        'node -e ${_shellEscape(script)}',
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
      final success = await NativeBridge.startGateway();
      if (!success) {
        _updateState(_state.copyWith(
          logs: [..._state.logs, '[WARN] Native start failed, attempting doctor fix...'],
        ));
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw doctor --fix',
          timeout: 10000
        );
        final retrySuccess = await NativeBridge.startGateway();
        if (!retrySuccess) throw Exception('Native start failed after doctor fix');
      }
      
      await Future.delayed(const Duration(seconds: 3)); // Give tmux/proot time
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

      if (response.statusCode < 500 && _state.status != GatewayStatus.running) {
        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          startedAt: DateTime.now(),
          logs: [..._state.logs, '[INFO] Gateway is healthy'],
        ));
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

  /// Exact user-requested logic for gateway probe and auto-fix
  Future<void> probeGateway() async {
    try {
      final probe = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw config --show'
      );
      if (probe.contains('models: Invalid input')) {
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw models add --provider google --id gemini-3.1-pro-preview --name "Gemini 3.1 Pro Preview"'
        );
      }
      if (probe.contains('Invalid config') || probe.contains('Invalid input')) {
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw doctor --fix'
        );
        // Retry probe or log success
      }
    } catch (e) {
      // Log PlatformException(PROOT_ERROR) and retry with fix handled in start()
    }
  }

  /// Send a message to the OpenClaw gateway and stream the response.
  ///
  /// Uses the OpenClaw WebSocket protocol:
  ///   → {"method":"chat.send","params":{"message":"...","model":"..."},"id":"<uuid>"}
  ///   ← {"type":"res","id":"<uuid>","result":{"runId":"...","status":"started"}}
  ///   ← {"type":"event","event":"chat","data":{"delta":"...","done":false}}
  ///   ← {"type":"event","event":"chat","data":{"done":true}}
  Stream<String> sendMessage(String message, {String model = 'clawa'}) async* {
    // Retrieve auth token — required for WS auth.
    String? token;
    try {
      token = await retrieveTokenFromConfig();
    } catch (_) {}

    if (token == null || token.isEmpty) {
      yield '[Error] No gateway auth token available.\n'
            'Please ensure the gateway has started and the token is saved in openclaw.json.';
      return;
    }

    final wsUri = Uri.parse('${AppConstants.gatewayWsUrl}/?token=$token');
    WebSocketChannel? channel;

    try {
      channel = WebSocketChannel.connect(wsUri);
      await channel.ready;
    } catch (e) {
      yield '[Error] Cannot connect to gateway WebSocket: $e';
      return;
    }

    final requestId = const Uuid().v4();
    final requestPayload = jsonEncode({
      'method': 'chat.send',
      'params': {
        'message': message,
        'model': model,
      },
      'id': requestId,
    });

    // We use a StreamController to bridge from the WS listen callback to an async* stream.
    final chunkController = StreamController<String>();

    // Wait for hello-ok before sending the request
    final Completer<void> handshakeCompleter = Completer<void>();
    
    late StreamSubscription wsSubscription;
    wsSubscription = channel.stream.listen(
      (raw) {
        try {
          final frame = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = frame['type'] as String?;

          // Handle handshake
          if (type == 'hello-ok') {
            if (!handshakeCompleter.isCompleted) handshakeCompleter.complete();
            return;
          }

          // Ack for our request
          if (type == 'res' && frame['id'] == requestId) {
            final status = (frame['result'] as Map?)?['status'];
            if (status == 'ok' || status == null) {
              // Synchronous response — gateway ran inline, treat result text as full reply
              final text = (frame['result'] as Map?)?['text'] as String?;
              if (text != null && text.isNotEmpty) {
                chunkController.add(text);
              }
              chunkController.close();
              return;
            }
            // status == 'started' → streaming response, wait for chat events below
            return;
          }

          // Streaming chat events from the agent
          if (type == 'event' && frame['event'] == 'chat') {
            final data = frame['data'] as Map<String, dynamic>?;
            if (data != null) {
              final delta = data['delta'] as String?;
              if (delta != null && delta.isNotEmpty) {
                chunkController.add(delta);
              }
              // Also handle non-streaming 'text' field (full response at once)
              final text = data['text'] as String?;
              if (text != null && text.isNotEmpty && delta == null) {
                chunkController.add(text);
              }
              if (data['done'] == true) {
                chunkController.close();
              }
            }
            return;
          }

          // hello-ok and other events are expected; ignore them silently
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

    try {
      // Wait for hello-ok with 2s timeout
      await handshakeCompleter.future.timeout(const Duration(seconds: 2));
    } catch (_) {
      // Fallback if hello-ok doesn't arrive as expected, but try sending anyway
    }
    
    channel.sink.add(requestPayload);

    // Yield chunks as they arrive
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
      wsSubscription.cancel();
      channel.sink.close();
    }
  }

  void dispose() {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _stateController.close();
  }
}

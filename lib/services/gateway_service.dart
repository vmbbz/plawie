import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  /// Write an API key directly to openclaw.json — bypasses the CLI `onboard` command.
  /// [provider] is the JSON key (e.g. "claudeApiKey", "geminiApiKey", etc.)
  /// [key] is the raw API key string.
  Future<void> configureApiKey(String provider, String key) async {
    final script = '''
const fs = require("fs");
const dir = "/root/.openclaw";
const p = dir + "/openclaw.json";
try { fs.mkdirSync(dir, { recursive: true }); } catch {}
let c = {};
try { c = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
if (!c.env) c.env = {};
c.env["$provider"] = "$key";
fs.writeFileSync(p, JSON.stringify(c, null, 2));
''';
    await NativeBridge.runInProot(
      'node -e ${_shellEscape(script)}',
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

    try {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[DEBUG] Probing gateway config for auth token...']
      ));

      final token = await retrieveTokenFromConfig();
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
          logs: [..._state.logs, '[INFO] Gateway auth token acquired from config.']
        ));
        return urlWithToken;
      }

      // Fallback to CLI dashboard probe if config read fails or token is missing
      final output = await NativeBridge.runInProot('openclaw dashboard --no-open', timeout: 10);
      final urlMatch = _tokenUrlRegex.firstMatch(output);
      
      if (urlMatch != null) {
        final url = urlMatch.group(0);
        final prefs = PreferencesService();
        await prefs.init();
        prefs.dashboardUrl = url;
        _updateState(_state.copyWith(
          dashboardUrl: url,
          logs: [..._state.logs, '[INFO] Gateway auth token acquired via CLI.']
        ));
        return url;
      } else {
         _updateState(_state.copyWith(
          logs: [..._state.logs, '[WARN] Dashboard probe failed to find token. Ensure openclaw is starting correctly.']
        ));
      }
    } catch (e) {
      _updateState(_state.copyWith(
        logs: [..._state.logs, '[ERROR] Failed to probe dashboard: $e']
      ));
    }
    return _state.dashboardUrl;
  }

  /// Use Node.js to read the token directly from the openclaw.json config file.
  Future<String?> retrieveTokenFromConfig() async {
    const script = '''
const fs = require("fs");
const p = "/root/.openclaw/openclaw.json";
try {
  const c = JSON.parse(fs.readFileSync(p, "utf8"));
  if (c.gateway && c.gateway.auth && c.gateway.auth.token) {
    console.log(c.gateway.auth.token);
  }
} catch (e) {}
''';
    try {
      final token = await NativeBridge.runInProot(
        'node -e ${_shellEscape(script)}',
        timeout: 5,
      );
      return token.trim();
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
        throw Exception('Native start failed');
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

  /// Send a message to the OpenClaw gateway and stream the response.
  /// Attempts OpenAI-style v1 endpoint first, with fallback to Ollama api style.
  Stream<String> sendMessage(String message, {String model = 'clawa'}) async* {
    final endpoints = [
      '${AppConstants.gatewayUrl}/v1/chat/completions',
      '${AppConstants.gatewayUrl}/api/chat',
    ];

    String? lastError;
    
    for (final endpointUrl in endpoints) {
      final isOllama = endpointUrl.contains('/api/chat');
      final url = Uri.parse(endpointUrl);
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': message}
          ],
          'stream': true,
        });

      final client = http.Client();
      try {
        final response = await client.send(request).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 404) {
          lastError = '404 Not Found at $endpointUrl';
          continue; // Try next endpoint
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          yield '[Error] Unauthorized: Gateway token missing or invalid.\n'
                'Please open the Dashboard URL from the Settings page to refresh the token,\n'
                'or run: openclaw doctor --generate-gateway-token';
          return;
        }

        if (response.statusCode != 200) {
          final body = await response.stream.bytesToString();
          yield '[Error] $endpointUrl returned ${response.statusCode}\nBody: $body';
          return;
        }

        final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
        await for (final line in stream) {
          if (line.isEmpty) continue;
          
          final cleanLine = line.startsWith('data: ') ? line.substring(6) : line;
          if (cleanLine == '[DONE]') break;

          try {
            final json = jsonDecode(cleanLine);
            
            // OpenAI Format: choices[0].delta.content
            if (json['choices'] != null && 
                json['choices'] is List && 
                json['choices'].isNotEmpty &&
                json['choices'][0]['delta'] != null &&
                json['choices'][0]['delta']['content'] != null) {
              yield json['choices'][0]['delta']['content'] as String;
            } 
            // Ollama Format: message.content
            else if (json['message'] != null && json['message']['content'] != null) {
              yield json['message']['content'] as String;
            }
            // Ollama /api/generate fallback
            else if (json['response'] != null) {
              yield json['response'] as String;
            }
          } catch (_) {}
        }
        return; // Success, stop trying endpoints
      } catch (e) {
        lastError = 'Connection error at $endpointUrl: $e';
      } finally {
        client.close();
      }
    }

    yield '[Error] All endpoints failed.\nLast error: $lastError';
  }

  void dispose() {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _stateController.close();
  }
}

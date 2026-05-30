import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/gateway_state.dart';
import '../models/agent_info.dart';
import 'gateway_connection.dart';
import 'gateway_runtime.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';
import 'local_llm_service.dart';
import 'model_provider_catalog.dart';
import 'gateway_tool_catalog.dart';
import 'native_gateway_smoke_service.dart';
import 'native_gateway_shadow_parity_service.dart';
import '../constants/openclaw_paths.dart';
import 'skills_service.dart';
import 'diagnostic_service.dart';
import 'node_service.dart';
import 'tts_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class _FastCloudRoute {
  final String provider;
  final String model;
  final String apiKey;
  final String url;

  const _FastCloudRoute({
    required this.provider,
    required this.model,
    required this.apiKey,
    required this.url,
  });
}

class TalkSpeakPlayback {
  final bool played;
  final bool allowNativeFallback;
  final String? errorMessage;

  const TalkSpeakPlayback({
    required this.played,
    required this.allowNativeFallback,
    this.errorMessage,
  });
}

class GatewayService {
  static const List<String> localControlUiAllowedOrigins = <String>[
    'http://127.0.0.1:18789',
    'http://localhost:18789',
  ];
  static const bool _nativePrimaryCanaryDiagnosticsEnabled =
      bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_PRIMARY_CANARY_DIAGNOSTICS',
    defaultValue: false,
  );
  static const String _mobileChatSessionPrefix = 'mobile:chat:';
  static const String _defaultAuthProfileName = 'default';

  static final GatewayService _instance = GatewayService._internal();
  factory GatewayService() => _instance;
  GatewayService._internal();

  Timer? _healthTimer;
  StreamSubscription? _logSubscription;
  StreamSubscription<Map<String, dynamic>>? _gatewayEventSubscription;
  final GatewayRuntime _runtime = GatewayRuntimeRegistry.current;
  GatewayConnection? _connection;
  bool _healthCheckInFlight = false;
  bool _rpcDiscoveryDone =
      false; // RPC discovery runs once after first WS connect
  DateTime?
      _httpWaitingSince; // set when HTTP probe first fails during starting
  final _stateController = StreamController<GatewayState>.broadcast();
  GatewayState _state = const GatewayState();
  bool _isStarting = false;
  bool _isStopping = false;
  final _chatActivityController = StreamController<String>.broadcast();
  final List<String> _activityBuffer = []; // replay buffer for late subscribers

  // Cached Android files directory — avoids a platform channel call on every config I/O.
  String? _filesDir;

  /// Fires when the gateway tts tool produces audio ready to play on the device.
  /// Passes the HTTP URL to the MP3 (served by the gateway's HTTP server).
  Function(String audioUrl)? onGatewayTtsAudio;
  // Prevents concurrent @buape/carbon targeted-fix attempts.
  bool _isFixingDep = false;
  // Guards the one-time pairing-required recovery per session.
  bool _pairingResolveAttempted = false;

  // Failure tracking for proactive auto-healing
  int _consecutiveFailures = 0;
  bool _isAutoHealingInProgress = false;
  bool _dashboardPairingApprovalInFlight = false;
  DateTime? _lastDashboardPairingApprovalAttemptAt;
  final Set<String> _autoApprovedDashboardRequestIds = <String>{};
  DateTime? _lastHardeningSweepAt;
  DateTime? _gatewaySettleUntil;
  DateTime? _lastProcessValidationAt;
  DateTime? _lastDisconnectContextAt;
  DateTime? _lastNodeAutoConnectAttemptAt;
  DateTime? _lastWsConnectAttemptAt;
  DateTime? _talkSpeakUnavailableUntil;
  bool _talkSpeakBackoffAllowsNativeFallback = false;
  DateTime? _lastLocalInferenceHealthSkipAt;
  DateTime? _lastHungGatewayRestartAt;
  DateTime? _lastStartupHealthKickAt;
  DateTime? _gatewayConfigTransitionUntil;
  String? _gatewayConfigTransitionReason;
  int _consecutiveProcessValidationMisses = 0;
  bool _processValidationInFlight = false;
  bool _nodeAutoConnectInFlight = false;
  bool _hungGatewayRestartInFlight = false;
  bool _modelAliasRepairInFlight = false;
  bool _runtimeLogged = false;
  static const Duration _runtimeHardeningCooldown = Duration(minutes: 10);
  static const Duration _gatewaySettleWindow = Duration(seconds: 90);
  static const Duration _processValidationInterval = Duration(seconds: 90);
  static const Duration _startupHealthKickCooldown = Duration(seconds: 4);
  static const Duration _gatewayHealthProbeTimeout = Duration(seconds: 45);
  static const Duration _disconnectContextCooldown = Duration(seconds: 20);
  static const Duration _nodeAutoConnectCooldown = Duration(seconds: 20);
  static const Duration _wsConnectRetryCooldown = Duration(seconds: 8);
  static const Duration _talkSpeakUnavailableBackoff = Duration(minutes: 5);
  static const Duration _hungGatewayRestartCooldown = Duration(seconds: 90);
  static const int _hungGatewayForcedRestartFailures = 6;
  static const int _healthFailureRestartThreshold = 6;
  static const Duration _startupPassiveHealGrace = Duration(seconds: 150);
  static const Duration _localInferenceHealthSkipLogCooldown =
      Duration(seconds: 60);
  static const Duration _dashboardPairingApprovalCooldown =
      Duration(seconds: 8);
  static const Duration _gatewayConfigReloadSettle = Duration(seconds: 8);
  static const Duration _gatewayConfigSoftSettle = Duration(seconds: 3);
  static const Duration _gatewaySessionPatchSettle = Duration(seconds: 5);
  static const Duration _gatewayChatLaneSettleTimeout = Duration(seconds: 240);
  static const Duration _gatewayStaleChatRecoverySettle =
      Duration(seconds: 180);

  /// Live stream of human-readable chat and gateway events.
  Stream<String> get chatActivityStream => _chatActivityController.stream;

  /// Last ≤40 activity events — use to seed the panel when the screen opens.
  List<String> get recentActivity => List.unmodifiable(_activityBuffer);

  /// Buffer + broadcast a single activity event.
  void _addActivity(String event) {
    debugPrint('[GATEWAY] $event'); // logcat visibility
    _activityBuffer.add(event);
    if (_activityBuffer.length > 120) {
      _activityBuffer.removeRange(0, _activityBuffer.length - 120);
    }
    _chatActivityController.add(event);
  }

  void _kickStartupHealthProbe(String reason) {
    final now = DateTime.now();
    final lastKick = _lastStartupHealthKickAt;
    if (lastKick != null &&
        now.difference(lastKick) < _startupHealthKickCooldown) {
      return;
    }
    _lastStartupHealthKickAt = now;
    debugPrint('[GATEWAY] Startup health probe kick ($reason)');
    unawaited(_checkHealth());
  }

  void _beginGatewayConfigTransition(
    String reason, {
    Duration minimumSettle = _gatewayConfigReloadSettle,
    bool allowShorten = false,
  }) {
    final until = DateTime.now().add(minimumSettle);
    if (allowShorten ||
        _gatewayConfigTransitionUntil == null ||
        until.isAfter(_gatewayConfigTransitionUntil!)) {
      _gatewayConfigTransitionUntil = until;
    }
    _gatewayConfigTransitionReason = reason;
    _rpcDiscoveryDone = false;
    _updateState(_state.copyWith(isInteractiveReady: false));
    _addActivity(
        '[Gateway] Applying $reason; chat is paused until Gateway settles.');
  }

  void _logRuntimeOnce() {
    if (_runtimeLogged) return;
    _runtimeLogged = true;
    _addActivity('[RUNTIME] Gateway runtime: ${_runtime.label}');
  }

  bool get _hasGatewayConfigTransition {
    final until = _gatewayConfigTransitionUntil;
    if (until != null && DateTime.now().isBefore(until)) return true;
    return _gatewayConfigTransitionReason != null &&
        (!_state.isInteractiveReady ||
            _connection?.state != GatewayConnectionState.connected);
  }

  void _clearGatewayConfigTransitionIfReady() {
    final until = _gatewayConfigTransitionUntil;
    final minimumSettled = until == null || !DateTime.now().isBefore(until);
    final wsReady = _connection?.state == GatewayConnectionState.connected;
    if (minimumSettled && wsReady && _state.isInteractiveReady) {
      if (!_state.isWebsocketConnected) {
        _updateState(_state.copyWith(isWebsocketConnected: true));
      }
      _gatewayConfigTransitionUntil = null;
      _gatewayConfigTransitionReason = null;
    }
  }

  Future<String?> _waitForGatewayChatLaneReady(
    String? token, {
    Duration timeout = _gatewayChatLaneSettleTimeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    final transitionReason = _gatewayConfigTransitionReason;
    if (_hasGatewayConfigTransition) {
      _addActivity('[CHAT] Waiting for Gateway to settle'
          '${transitionReason == null ? '' : ' after $transitionReason'}...');
    }

    while (DateTime.now().isBefore(deadline)) {
      final until = _gatewayConfigTransitionUntil;
      if (until != null && DateTime.now().isBefore(until)) {
        final delay = until.difference(DateTime.now());
        await Future.delayed(
          delay > const Duration(milliseconds: 750)
              ? const Duration(milliseconds: 750)
              : delay,
        );
        continue;
      }

      try {
        final running = await _runtime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
        if (!running) {
          await attachOrStart(autoStart: true, forceStart: false)
              .timeout(const Duration(seconds: 25));
        }
      } catch (_) {}

      try {
        token ??= await retrieveTokenFromConfig(force: true)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
      } catch (_) {}

      if (token != null && token.isNotEmpty) {
        try {
          await _ensureWebSocket(token).timeout(const Duration(seconds: 20));
        } catch (_) {}
      }

      try {
        await _checkHealth().timeout(const Duration(seconds: 25));
      } catch (_) {}

      _clearGatewayConfigTransitionIfReady();
      final wsReady = _connection?.state == GatewayConnectionState.connected;
      if (wsReady && _state.isInteractiveReady) {
        return token;
      }

      // If no explicit config transition is active, avoid turning an ordinary
      // transient health lag into a long blocking wait. The caller can still
      // attempt normal WS repair below.
      if (!_hasGatewayConfigTransition &&
          _state.status != GatewayStatus.starting) {
        return token;
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    return null;
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

  /// Send an audio file to the gateway for transcription (STT)
  Future<String?> transcribeAudio(File audioFile) async {
    try {
      final dashboardUrl = await fetchAuthenticatedDashboardUrl();
      if (dashboardUrl == null) throw Exception('No gateway dashboard URL');

      final uri = Uri.parse(dashboardUrl);
      final token = uri.queryParameters['token'];
      if (token == null) throw Exception('No gateway token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.gatewayUrl}/talk/stt'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files
          .add(await http.MultipartFile.fromPath('audio', audioFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['text']?.toString();
      } else {
        debugPrint('STT Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('STT Exception: $e');
      return null;
    }
  }

  // Matches terminal Dashboard URL: supports localhost, 127.0.0.1, 0.0.0.0, and arbitrary IP addresses.
  static final _tokenUrlRegex =
      RegExp(r'https?://[a-zA-Z0-9\.\-]+:\d+/[^\s]*[#?]token=[^\s&]+');
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
  Stream<Map<String, dynamic>> get gatewayEventStream =>
      _connection?.eventStream ?? const Stream<Map<String, dynamic>>.empty();

  static String authProfileIdForProvider(String provider) =>
      '${provider.trim().toLowerCase()}:$_defaultAuthProfileName';

  /// Adds the config-side auth profile metadata OpenClaw 2026.x expects.
  ///
  /// The secret itself lives in `auth-profiles.json`; this top-level block tells
  /// the gateway which provider/profile/mode should be considered at runtime.
  static void ensureProviderAuthConfigBlock(
    Map<String, dynamic> config,
    String provider, {
    String mode = 'api_key',
  }) {
    final normalizedProvider = provider.trim().toLowerCase();
    if (normalizedProvider.isEmpty) return;
    final profileId = authProfileIdForProvider(normalizedProvider);

    if (config['auth'] is! Map) config['auth'] = <String, dynamic>{};
    final auth = config['auth'] as Map;

    if (auth['profiles'] is! Map) auth['profiles'] = <String, dynamic>{};
    final profiles = auth['profiles'] as Map;
    profiles[profileId] = <String, dynamic>{
      'provider': normalizedProvider,
      'mode': mode,
    };

    if (auth['order'] is! Map) auth['order'] = <String, dynamic>{};
    final order = auth['order'] as Map;
    final existingOrder = order[normalizedProvider];
    final nextOrder = <String>[
      profileId,
      if (existingOrder is List)
        ...existingOrder
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty && value != profileId),
    ];
    order[normalizedProvider] = nextOrder;
  }

  static bool _configCredentialLooksSet(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty && trimmed != 'null';
    }
    if (value is Map || value is List) return value.isNotEmpty;
    return false;
  }

  static bool _configHasProviderCredential(
    Map<String, dynamic> config,
    String provider,
  ) {
    final normalized = provider.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final providerConfig = config['models']?['providers']?[normalized];
    if (providerConfig is Map &&
        _configCredentialLooksSet(providerConfig['apiKey'])) {
      return true;
    }

    final envKey = ModelProviderCatalog.envKeyForProvider(normalized);
    final envVars = config['env']?['vars'];
    if (envKey.isNotEmpty &&
        envVars is Map &&
        _configCredentialLooksSet(envVars[envKey])) {
      return true;
    }

    final auth = config['auth'];
    final profiles = auth is Map ? auth['profiles'] : null;
    if (profiles is Map &&
        profiles.containsKey(authProfileIdForProvider(normalized))) {
      return true;
    }

    return false;
  }

  static String _preferredSpeechProviderForConfig(Map<String, dynamic> config) {
    final primary =
        config['agents']?['defaults']?['model']?['primary']?.toString() ?? '';
    final primaryProvider =
        primary.contains('/') ? primary.split('/').first.toLowerCase() : '';

    const keyedSpeechProviders = <String>{
      'openrouter',
      'openai',
      'google',
      'xai',
    };

    if (keyedSpeechProviders.contains(primaryProvider)) {
      // Trust the selected model lane. Secrets can live in auth-profiles.json
      // or SecretRef storage, so this top-level config may not visibly contain
      // the API key even though the Gateway can resolve it at runtime.
      return primaryProvider;
    }

    for (final provider in keyedSpeechProviders) {
      if (_configHasProviderCredential(config, provider)) return provider;
    }

    // Official no-key fallback. Best-effort, but far better than an
    // unconfigured Talk stack that spams talk.speak errors.
    return 'microsoft';
  }

  /// Configure the OpenClaw speech-output half of Talk.
  ///
  /// Chat/model provider auth does not automatically make `talk.speak` usable.
  /// OpenClaw keeps separate config surfaces for Messages TTS and Talk speech,
  /// so Plawie must keep both in sync during setup + hardening.
  ///
  /// `auto` remains off because the Flutter chat explicitly calls `talk.speak`;
  /// enabling Auto-TTS here would risk double speech.
  static void ensureGatewayTalkTtsConfig(Map<String, dynamic> config) {
    config['messages'] ??= <String, dynamic>{};
    final messages = config['messages'];
    if (messages is! Map) return;

    messages['tts'] ??= <String, dynamic>{};
    final tts = messages['tts'];
    if (tts is! Map) return;

    final currentAuto = tts['auto'];
    if (currentAuto is! String || currentAuto.trim().isEmpty) {
      tts['auto'] = 'off';
    }

    tts['providers'] ??= <String, dynamic>{};
    final providers = tts['providers'];
    if (providers is! Map) return;

    Map<String, dynamic> asStringKeyedMap(Map source) {
      return source.map((key, value) => MapEntry(key.toString(), value));
    }

    void mergeProviderDefaults(String id, Map<String, dynamic> defaults) {
      final existing = providers[id];
      providers[id] = <String, dynamic>{
        ...defaults,
        if (existing is Map) ...existing,
      };
    }

    mergeProviderDefaults('openrouter', <String, dynamic>{
      'model': 'hexgrad/kokoro-82m',
      'voice': 'af_alloy',
      'responseFormat': 'mp3',
    });
    mergeProviderDefaults('openai', <String, dynamic>{
      'model': 'gpt-4o-mini-tts',
      'voice': 'alloy',
    });
    mergeProviderDefaults('google', <String, dynamic>{
      'model': 'gemini-3.1-flash-tts-preview',
      'voiceName': 'Kore',
    });
    mergeProviderDefaults('xai', <String, dynamic>{
      'voiceId': 'eve',
      'language': 'en',
      'responseFormat': 'mp3',
    });
    mergeProviderDefaults('microsoft', <String, dynamic>{
      'enabled': true,
      'voice': 'en-US-MichelleNeural',
      'lang': 'en-US',
      'outputFormat': 'audio-24khz-48kbitrate-mono-mp3',
      'rate': '+0%',
      'pitch': '+0%',
    });

    final currentProvider = tts['provider']?.toString().trim() ?? '';
    if (currentProvider.isEmpty || !providers.containsKey(currentProvider)) {
      tts['provider'] = _preferredSpeechProviderForConfig(config);
    }

    final resolvedTtsProvider = tts['provider']?.toString().trim() ?? '';

    // Keep Talk speech provider config aligned with messages.tts so
    // talk.speak doesn't fail with "talk provider not configured".
    config['talk'] ??= <String, dynamic>{};
    final talk = config['talk'];
    if (talk is! Map) return;

    talk['providers'] ??= <String, dynamic>{};
    final talkProviders = talk['providers'];
    if (talkProviders is! Map) return;

    for (final entry in providers.entries) {
      final providerId = entry.key.toString().trim();
      if (providerId.isEmpty) continue;
      final sourceConfig = entry.value;
      final existingConfig = talkProviders[providerId];
      if (sourceConfig is Map) {
        talkProviders[providerId] = <String, dynamic>{
          ...asStringKeyedMap(sourceConfig),
          if (existingConfig is Map) ...asStringKeyedMap(existingConfig),
        };
      } else if (!talkProviders.containsKey(providerId)) {
        talkProviders[providerId] = sourceConfig;
      }
    }

    final currentTalkProvider = talk['provider']?.toString().trim() ?? '';
    if (currentTalkProvider.isEmpty ||
        !talkProviders.containsKey(currentTalkProvider)) {
      if (resolvedTtsProvider.isNotEmpty &&
          talkProviders.containsKey(resolvedTtsProvider)) {
        talk['provider'] = resolvedTtsProvider;
      } else if (talkProviders.containsKey('microsoft')) {
        talk['provider'] = 'microsoft';
      } else if (talkProviders.isNotEmpty) {
        talk['provider'] = talkProviders.keys.first.toString();
      }
    }
  }

  /// True when the connected gateway explicitly advertises [method].
  bool supportsMethod(String method) =>
      (_connection?.supportedMethods ?? const <String>[]).contains(method);

  Future<bool> approveLocalDashboardPairingRequest(String requestId) {
    return _autoApproveDashboardPairingRequest(requestId, source: 'webview');
  }

  bool get _isInGatewaySettleWindow {
    final settleUntil = _gatewaySettleUntil;
    return settleUntil != null && DateTime.now().isBefore(settleUntil);
  }

  void _markGatewaySettleWindow() {
    _gatewaySettleUntil = DateTime.now().add(_gatewaySettleWindow);
  }

  Future<void> _runRuntimeHardeningSweep() async {
    if (_isInGatewaySettleWindow) return;
    final lastSweep = _lastHardeningSweepAt;
    if (lastSweep != null &&
        DateTime.now().difference(lastSweep) < _runtimeHardeningCooldown) {
      return;
    }
    await _verifyGatewayConfigHardened(reason: 'runtime-health-check');
  }

  Future<void> _logGatewayDisconnectContext() async {
    final now = DateTime.now();
    final last = _lastDisconnectContextAt;
    if (last != null && now.difference(last) < _disconnectContextCooldown) {
      return;
    }
    _lastDisconnectContextAt = now;
    try {
      final running = await _runtime.isRunning();
      final contextMessage = running
          ? '[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).'
          : '[HEALTH] WS dropped and gateway process is down.';
      _updateState(_state.copyWith(logs: [..._state.logs, contextMessage]));
    } catch (_) {}
  }

  String _describeWsClose(int? closeCode, String closeReasonRaw) {
    if (closeReasonRaw.isNotEmpty) return closeReasonRaw;
    switch (closeCode) {
      case 1005:
        return 'no-status-received';
      case 1006:
        return 'abnormal-closure';
      case 1008:
        return 'policy-rejected';
      default:
        return 'unknown';
    }
  }

  /// Validate gateway process health before marking as healthy
  Future<void> _validateGatewayProcess() async {
    final now = DateTime.now();
    if (_processValidationInFlight) return;
    if (_lastProcessValidationAt != null &&
        now.difference(_lastProcessValidationAt!) <
            _processValidationInterval) {
      return;
    }
    _processValidationInFlight = true;
    _lastProcessValidationAt = now;
    try {
      final running = await _runtime.isRunning();
      if (!running) {
        _consecutiveProcessValidationMisses++;
        if (_consecutiveProcessValidationMisses >= 2 &&
            _state.status == GatewayStatus.running) {
          _addActivity(
              '[HEALTH] Gateway process missing on repeated checks; marking stopped');
          _updateState(_state.copyWith(status: GatewayStatus.stopped));
        }
      } else {
        _consecutiveProcessValidationMisses = 0;
      }
    } catch (_) {
      // Non-fatal: process validation is a secondary safety net.
    } finally {
      _processValidationInFlight = false;
    }
  }

  /// Check if gateway is already running (e.g. after app restart)
  /// and sync UI state accordingly.
  Future<void> init() async {
    _logRuntimeOnce();
    unawaited(NativeGatewaySmokeService.runStartupSelfTestIfEnabled(
      log: _addActivity,
    ));
    final isComplete = await NativeBridge.isBootstrapComplete();
    if (!isComplete) {
      _addActivity('[SYS] Bootstrap incomplete. Awaiting setup...');
      return;
    }

    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.setupInProgress) {
      _addActivity('[SYS] Setup in progress. Deferring gateway automation.');
      return;
    }

    await _migrateLegacyDaemonModelDefaults(prefs);
    await _migrateLegacyModelIds(prefs);

    // Initialize file directory early
    await getFilesDir();
    await _ensureWorkspaceHeartbeatFile();

    // SELF-HEALING: Ensure binary wrappers are fresh on every startup.
    try {
      final diag = await NativeBridge.runInProot(
        'export PATH=\$PATH:/usr/local/bin:/usr/bin; echo "--- /usr/local/bin ---"; ls -F /usr/local/bin; echo "--- /usr/bin ---"; ls -F /usr/bin/open* /usr/bin/npm* 2>/dev/null || true',
        timeout: 10,
      );
      debugPrint('[GATEWAY] Path Diagnostic:\n$diag');
      await NativeBridge.createBinWrappers('openclaw');
      await NativeBridge.ensureAgentSkillsAwareness();
    } catch (e) {
      debugPrint('[GATEWAY] Self-healing error: $e');
    }

    // Gateway startup. No longer probes Ollama models on startup to prevent
    // 20s+ event loop stalls that break Node pairing.
    unawaited(attachOrStart(autoStart: prefs.autoStartGateway));
  }

  Future<void> _migrateLegacyDaemonModelDefaults(
      PreferencesService prefs) async {
    final provider = (prefs.apiProvider ?? '').trim().toLowerCase();
    final configuredModel = (prefs.configuredModel ?? '').trim();
    if (!configuredModel.startsWith('ollama/')) return;

    const fallback = ModelProviderCatalog.defaultCloudFallbackModel;
    prefs.configuredModel = fallback;
    if (provider.isEmpty || provider.contains('ollama')) {
      prefs.apiProvider = 'google';
    }
    _addActivity(
        '[MIGRATION] Deprecated Ollama route $configuredModel detected; switching to $fallback');

    final running = await _runtime.isRunning();
    if (running) return;

    try {
      final config = await _readConfig();
      final primary = config['agents']?['defaults']?['model']?['primary'];
      final isLegacyDaemonPrimary =
          primary is String && primary.startsWith('ollama/');
      if (!isLegacyDaemonPrimary) return;
      config['agents'] ??= {};
      config['agents']['defaults'] ??= {};
      config['agents']['defaults']['model'] ??= {};
      config['agents']['defaults']['model']['primary'] = fallback;
      await _writeConfig(config);
    } catch (_) {
      // Best effort migration; prefs fallback still prevents cloud default selection.
    }
  }

  Future<void> _migrateLegacyModelIds(PreferencesService prefs) async {
    final configuredModel = (prefs.configuredModel ?? '').trim();
    if (configuredModel.isNotEmpty) {
      final canonical =
          ModelProviderCatalog.canonicalizeModelId(configuredModel);
      if (canonical != configuredModel) {
        prefs.configuredModel = canonical;
        _addActivity(
            '[MIGRATION] Updated legacy model id $configuredModel -> $canonical');
      }
    }

    try {
      final running = await _runtime.isRunning();
      if (running) return;
      final config = await _readConfig();
      final primary = config['agents']?['defaults']?['model']?['primary'];
      if (primary is! String || primary.trim().isEmpty) return;
      final canonicalPrimary =
          ModelProviderCatalog.canonicalizeModelId(primary);
      if (canonicalPrimary == primary) return;
      config['agents'] ??= {};
      config['agents']['defaults'] ??= {};
      config['agents']['defaults']['model'] ??= {};
      config['agents']['defaults']['model']['primary'] = canonicalPrimary;
      await _writeConfig(config);
      _addActivity(
          '[MIGRATION] Updated gateway primary model id $primary -> $canonicalPrimary');
    } catch (_) {
      // Best effort migration; prefs drives the next model persist anyway.
    }
  }

  Future<void> _writeApiKeyAuthProfile({
    required String provider,
    required String key,
  }) async {
    final normalizedProvider = provider.trim().toLowerCase();
    final normalizedKey = key.trim();
    if (normalizedProvider.isEmpty || normalizedKey.isEmpty) return;

    try {
      final filesDir = await getFilesDir();
      final authFile = File(
        '$filesDir/rootfs/ubuntu/root/.openclaw/agents/main/agent/auth-profiles.json',
      );
      await Directory(authFile.parent.path).create(recursive: true);

      Map<String, dynamic> store = <String, dynamic>{};
      if (await authFile.exists()) {
        final raw = await authFile.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) store = _deepCastMap(decoded);
        }
      }

      store['version'] = 1;
      if (store['profiles'] is! Map) {
        store['profiles'] = <String, dynamic>{};
      }

      final profiles = store['profiles'] as Map;
      final profileId = authProfileIdForProvider(normalizedProvider);
      final existing = profiles[profileId];
      final profile = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};

      profile['type'] = 'api_key';
      profile['provider'] = normalizedProvider;
      profile['key'] = normalizedKey;
      // If a previous build wrote this profile as a token, remove stale fields
      // so the current API-key resolver sees one unambiguous credential shape.
      profile.remove('token');
      profile.remove('tokenRef');
      profiles[profileId] = profile;

      await _writeStringAtomically(authFile, _canonicalJsonSignature(store));
    } catch (e) {
      debugPrint('[GatewayService] Auth profile patch error: $e');
    }
  }

  /// New Auto-Healing Logic: Detects critical failures in logs and attempts recovery.
  void _handleGatewayAutoHeal(String log) {
    if (_isFixingDep) return;

    if (log.contains('queued_work_without_active_run')) {
      _beginGatewayConfigTransition(
        'stale chat lane recovery',
        minimumSettle: _gatewayStaleChatRecoverySettle,
      );
      _addActivity(
        '[CHAT] Gateway reported stale queued work; holding new chat sends.',
      );
    } else if (log
        .contains('stuck session recovery outcome: status=released')) {
      _beginGatewayConfigTransition(
        'stale chat lane recovery released',
        minimumSettle: const Duration(seconds: 20),
        allowShorten: true,
      );
      _addActivity(
        '[CHAT] Gateway stale lane released; waiting briefly before new sends.',
      );
    }

    // 1. Missing specific dependencies
    if (log.contains("Cannot find module '@buape/carbon'")) {
      _runTargetedFix('@buape/carbon');
    } else if (log.contains("Cannot find module 'openclaw'")) {
      // This implies the package is missing from node_modules but binary was called
      _runTargetedFix('openclaw', isGlobal: true);
    } else if (log.contains("Error: Cannot find module") &&
        !log.contains("node_modules")) {
      // Generic module error that doesn't specify a path - likely a broken install
      _addActivity(
          '[SYS] Detected missing module. If gateway fails, please run Repair in Settings.');
    }

    // 2. Syntax Errors (corrupted downloads)
    if (log.contains('SyntaxError:')) {
      _addActivity(
          '[SYS] Gateway syntax error detected (possible corruption).');
    }

    // 3. Legacy model alias fallback warning from gateway.
    // If we ever see this at runtime, force-canonicalize primary model so the
    // next boot does not drift back to an unintended provider.
    if (log.contains('Model "openclaw" specified without provider')) {
      unawaited(_repairLegacyPrimaryModelAlias());
    }
  }

  Future<void> _repairLegacyPrimaryModelAlias() async {
    if (_modelAliasRepairInFlight) return;
    _modelAliasRepairInFlight = true;
    try {
      final config = await _readConfig();
      final currentPrimary =
          config['agents']?['defaults']?['model']?['primary'];
      if (currentPrimary is! String || currentPrimary.trim().isEmpty) return;
      final canonical =
          ModelProviderCatalog.canonicalizeModelId(currentPrimary);
      if (canonical == currentPrimary) return;

      config['agents'] ??= <String, dynamic>{};
      config['agents']['defaults'] ??= <String, dynamic>{};
      config['agents']['defaults']['model'] ??= <String, dynamic>{};
      config['agents']['defaults']['model']['primary'] = canonical;
      await _writeConfig(config);

      _addActivity(
          '[SYS] Repaired legacy model id "$currentPrimary" -> "$canonical".');
    } catch (e) {
      _addActivity('[SYS] Model alias repair failed (non-fatal): $e');
    } finally {
      _modelAliasRepairInFlight = false;
    }
  }

  Future<void> _runTargetedFix(String packageName,
      {bool isGlobal = false}) async {
    if (_isFixingDep) return;
    _isFixingDep = true;
    _addActivity('[SYS] Auto-Healing: Fixing missing $packageName...');

    try {
      if (isGlobal) {
        await NativeBridge.runInProot(
          'export PATH=\$PATH:/usr/local/bin:/usr/bin && '
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
          'npm install -g $packageName --no-audit --no-fund && '
          'openclaw doctor --fix 2>/dev/null || true',
          timeout: 300,
        );
      } else {
        await NativeBridge.runInProot(
          'export PATH=\$PATH:/usr/local/bin:/usr/bin && '
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
          'cd /usr/local/lib/node_modules/openclaw && '
          'npm install --no-save --no-audit --no-fund $packageName 2>/dev/null && '
          'openclaw doctor --fix 2>/dev/null || true',
          timeout: 120,
        );
      }
      _addActivity(
          '[SYS] $packageName fixed — gateway will pick up changes on reconnect');
    } catch (e) {
      _addActivity('[SYS] Auto-heal failed: $e. Manual repair required.');
    } finally {
      _isFixingDep = false;
    }
  }

  /// Proactive Auto-Heal: Runs diagnostics and attempts targeted fixes without a full setup.
  Future<void> _triggerPassiveAutoHeal() async {
    if (_isAutoHealingInProgress) return;
    _isAutoHealingInProgress = true;
    _addActivity('[SYS] Proactive Auto-Healing: Identifying the issue...');

    try {
      final diag = await DiagnosticService.runGatewayDiagnostics();

      // Case 1: Missing OpenClaw package
      if (diag['openclaw_package'] == 'MISSING') {
        _addActivity(
            '[SYS] OpenClaw package missing — attempting targeted install...');
        await _runTargetedFix('openclaw', isGlobal: true);
        _consecutiveFailures = 0; // Allow a fresh chance
        return;
      }

      // Case 2: Missing Node.js
      if (diag['node_binary'] == 'MISSING') {
        _addActivity(
            '[SYS] Node.js binary missing. Please run "Setup" from the Home screen.');
        _updateState(_state.copyWith(
            status: GatewayStatus.error, errorMessage: 'Node.js missing'));
        return;
      }

      // Case 3: Invalid Config
      if (diag['config_health'] == 'INVALID_OR_MISSING') {
        _addActivity('[SYS] Configuration corrupted — rewriting defaults...');
        await NativeBridge.runInProot(
          'export PATH=\$PATH:/usr/local/bin:/usr/bin && export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw doctor --fix 2>/dev/null || true',
          timeout: 10,
        );
        await _configureGateway(); // our overrides run after doctor so they aren't undone
        _consecutiveFailures = 0;
        return;
      }

      // Case 4: Process not running but port closed
      if (diag['gateway_process'] == 'NOT_RUNNING' &&
          _state.status == GatewayStatus.running) {
        _addActivity('[SYS] Gateway process died — attempting restart...');
        unawaited(start());
        _consecutiveFailures = 0;
        return;
      }

      _addActivity(
          '[SYS] Could not identify a fixable issue. Please use Settings -> Repair.');
    } catch (e) {
      _addActivity('[SYS] Passive heal error: $e');
    } finally {
      _isAutoHealingInProgress = false;
    }
  }

  Future<bool> _isGatewayListenerAlive({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final token = await retrieveTokenFromConfig()
          .timeout(const Duration(seconds: 1), onTimeout: () => null);
      final response = await _probeGatewayHealth(
        token: token,
        timeout: timeout,
      );
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _attachToExistingGatewayAfterStartFailure(String reason) async {
    var gatewayLooksAlive = false;
    try {
      gatewayLooksAlive = await checkHealth()
          .timeout(const Duration(seconds: 6), onTimeout: () => false);
    } catch (_) {}

    if (!gatewayLooksAlive) {
      try {
        gatewayLooksAlive = await _runtime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
      } catch (_) {}
    }

    if (!gatewayLooksAlive) {
      gatewayLooksAlive = await _isGatewayListenerAlive(
        timeout: const Duration(seconds: 2),
      );
    }

    if (!gatewayLooksAlive) return false;

    _addActivity(
        '[INFO] Gateway already listening; attaching instead of failing start.');
    _rpcDiscoveryDone = false;
    _connection?.dispose();
    _connection = null;
    _cachedToken = null;
    _lastTokenFetch = null;
    NodeService().clearCachedToken();

    await fetchAuthenticatedDashboardUrl(force: true).catchError((_) => null);
    _consecutiveFailures = 0;
    _httpWaitingSince = null;
    _markGatewaySettleWindow();
    _subscribeLogs();
    _startHealthCheck();

    _updateState(_state.copyWith(
      status: GatewayStatus.running,
      clearError: true,
      startedAt: _state.startedAt ?? DateTime.now(),
      isReady: gatewayLooksAlive,
      isInteractiveReady: false,
      logs: [
        ..._state.logs,
        '[INFO] Attached to existing gateway after start collision: $reason',
      ],
    ));
    unawaited(_checkHealth());
    return true;
  }

  /// Unified entry point for starting or attaching to the gateway.
  /// Prevents double-spawns and handles self-healing.
  Future<void> attachOrStart(
      {bool autoStart = false, bool forceStart = false}) async {
    _logRuntimeOnce();
    // LOCK: Prevent concurrent start/stop cycles
    if (_isStarting || _isStopping) return;

    final prefs = PreferencesService();
    await prefs.init();
    final isComplete = await NativeBridge.isBootstrapComplete();
    if (!isComplete && !(prefs.setupInProgress && forceStart)) {
      if (prefs.setupInProgress) {
        _addActivity('[SYS] Setup in progress. Gateway start deferred.');
      } else {
        _addActivity('[SYS] Bootstrap incomplete. Gateway cannot start.');
      }
      return;
    }

    // 1. ALWAYS check if already running and attach if so. Android process
    // discovery can miss the PRoot child even while :18789 is already bound,
    // so the HTTP listener is also an ownership signal.
    final processRunning = await _runtime.isRunning();
    final listenerRunning = await _isGatewayListenerAlive();
    final alreadyRunning = processRunning || listenerRunning;

    if (alreadyRunning && listenerRunning) {
      // FAST PATH: already healthy → skip config write + doctor + reload
      if (_state.status != GatewayStatus.running) {
        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          startedAt: _state.startedAt ?? DateTime.now(),
          clearError: true,
        ));
      }
      _subscribeLogs();
      _startHealthCheck();
      _markGatewaySettleWindow();
      unawaited(_checkHealth());
      unawaited(
          fetchAuthenticatedDashboardUrl(force: true).catchError((_) => null));
      unawaited(_runRuntimeHardeningSweep());
      return;
    }

    if (alreadyRunning) {
      if (_state.status == GatewayStatus.running) {
        return; // Already fully attached
      }

      debugPrint('[GATEWAY] Existing gateway detected — attaching...');
      _rpcDiscoveryDone = false;
      _updateState(_state.copyWith(
        status: GatewayStatus.starting,
        isInteractiveReady: false,
        logs: [
          ..._state.logs,
          '[INFO] Existing gateway detected, attaching...'
        ],
      ));

      // Attach path should be non-mutating.
      // Running config/doctor writes while the gateway is already booting can
      // trigger avoidable reload/restart churn during first handshake.

      // Wipe the cache so we don't use a stale token from a previous run
      _connection?.dispose();
      _connection = null;
      _cachedToken = null;
      _lastTokenFetch = null;
      NodeService().clearCachedToken();

      // Attach path is intentionally non-mutating. Any config write while a
      // live gateway is booting can trigger a reload/restart and wipe the
      // just-established websocket/pairing state.
      await _verifyGatewayConfigHardened(reason: 'attach-existing');

      // Re-probe token after hardening to avoid stale cache.
      await fetchAuthenticatedDashboardUrl(force: true).catchError((_) => null);

      _addActivity(
          '[INFO] Gateway token confirmed; waiting for HTTP readiness...');

      _consecutiveFailures = 0;
      _httpWaitingSince =
          null; // clear so elapsed time is accurate for this boot
      _markGatewaySettleWindow();
      _subscribeLogs();
      _startHealthCheck();
      unawaited(_checkHealth());
      return;
    }

    // 2. Not running. POLICY: Should we spawn a NEW one?
    if (!autoStart && !forceStart) {
      debugPrint(
          '[GATEWAY] Not running. Auto-start is off (autoStartGateway=${prefs.autoStartGateway})');
      _updateState(_state.copyWith(logs: [
        ..._state.logs,
        '[DEBUG] Gateway not running. Auto-start is off.'
      ]));
      return;
    }

    final savedUrl = prefs.dashboardUrl;

    // Attempting a fresh start
    _isStarting = true;
    _rpcDiscoveryDone = false; // ensure discovery runs on this new session
    debugPrint('[GATEWAY] Starting gateway process...');
    _updateState(_state.copyWith(
      status: GatewayStatus.starting,
      isInteractiveReady: false,
      clearError: true,
      logs: [..._state.logs, '[INFO] Starting gateway...'],
      dashboardUrl: savedUrl,
    ));

    try {
      // FIXED: Check battery optimization BEFORE starting gateway
      final isOptimized = await NativeBridge.isBatteryOptimized();
      if (isOptimized) {
        _updateState(_state.copyWith(
          logs: [
            ..._state.logs,
            '[WARN] Battery Optimization is ACTIVE — may kill gateway in background.'
          ],
        ));
        // Request optimization but don't wait for it (non-blocking)
        unawaited(NativeBridge.requestBatteryOptimization().catchError((_) {}));
      }

      await NativeBridge.acquirePartialWakeLock();
      await _configureGateway();

      await Future.delayed(const Duration(milliseconds: 300));
      final success = await _runtime.start(
        allowDuringSetup: prefs.setupInProgress && forceStart,
      );

      if (!success) {
        throw Exception('Native start failed.');
      }

      // Start foreground service to keep AI agent alive in background
      unawaited(startForegroundService());

      // Warn user if battery optimization is active — Android can kill PRoot.
      // Fire-and-forget: showing the dialog must NOT block _startHealthCheck().
      // If requestBatteryOptimization() uses startActivityForResult it can wait
      // indefinitely, stalling the health timer from ever starting.
      unawaited(() async {
        try {
          final isOptimized = await NativeBridge.isBatteryOptimized();
          if (isOptimized) {
            _updateState(_state.copyWith(
              logs: [
                ..._state.logs,
                '[WARN] Battery Optimization is ACTIVE — may kill gateway in background.'
              ],
            ));
            await NativeBridge.requestBatteryOptimization();
          }
        } catch (_) {}
      }());

      await Future.delayed(const Duration(milliseconds: 500));

      // Wipe cache and ensure we have the fresh token from the new process
      _cachedToken = null;
      _lastTokenFetch = null;
      NodeService().clearCachedToken();

      await _verifyGatewayConfigHardened(reason: 'post-start');

      // Force token re-acquisition after start so the connection never
      // uses stale auth from a previous process.
      await fetchAuthenticatedDashboardUrl(force: true).catchError((_) => null);

      _consecutiveFailures = 0;
      _httpWaitingSince =
          null; // clear so elapsed time is accurate for this boot
      _markGatewaySettleWindow();
      _subscribeLogs();
      _startHealthCheck();
      unawaited(_checkHealth());
    } catch (e) {
      final attached =
          await _attachToExistingGatewayAfterStartFailure(e.toString());
      if (attached) return;
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
    await attachOrStart(forceStart: true);
  }

  /// Explicitly await the gateway reaching a healthy/running state.
  /// Useful for setup wizards to prevent users from landing on a "Disconnected" screen.
  Future<void> waitForStartup(
      {Duration timeout = const Duration(seconds: 120)}) async {
    final startTime = DateTime.now();

    // 1. Wait for the gateway process to exist.
    // Do not depend only on the 15s health timer to flip status->running:
    // that adds avoidable startup lag and can push setup into false 180s timeouts.
    while (true) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException(
            'Gateway process failed to start after ${timeout.inSeconds}s');
      }
      if (_state.status == GatewayStatus.running) break;
      final processAlive = await _runtime
          .isRunning()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      final listenerAlive = processAlive
          ? false
          : await _isGatewayListenerAlive(
              timeout: const Duration(seconds: 2),
            );
      if (processAlive || listenerAlive) {
        _updateState(_state.copyWith(
          status: GatewayStatus.running,
          startedAt: _state.startedAt ?? DateTime.now(),
        ));
        break;
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }

    // 2. Wait for HTTP /health success (server listening)
    bool listening = false;
    while (!listening) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException(
            'Gateway health check timed out after ${timeout.inSeconds}s');
      }
      try {
        final token = await retrieveTokenFromConfig()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        final resp = await _probeGatewayHealth(
          token: token,
          timeout: const Duration(seconds: 6),
        );
        if (resp.statusCode < 500) {
          listening = true;
          if (_state.status != GatewayStatus.running) {
            _updateState(_state.copyWith(
              status: GatewayStatus.running,
              startedAt: _state.startedAt ?? DateTime.now(),
            ));
          }
          debugPrint('✅ Gateway port listening');
        }
      } catch (_) {}
      if (!listening) await Future.delayed(const Duration(seconds: 1));
    }

    // 3. Wait for "ready" state (all sidecars/channels started).
    // Uses a 30s sub-deadline: if HTTP /health already passed (step 2) but the
    // "ready" log signal was missed (e.g. ANSI codes prevented string match),
    // we break rather than spinning for the full 180s timeout.
    final readyDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (!_state.isReady) {
      if (DateTime.now().isAfter(readyDeadline)) {
        debugPrint(
            '[GATEWAY] Ready signal sub-timeout — HTTP health confirmed, proceeding.');
        break;
      }
      if (DateTime.now().difference(startTime) > timeout) {
        throw TimeoutException(
            'Gateway startup timed out after ${timeout.inSeconds}s');
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('✅ Gateway is fully READY');

    // 4. Wait for the operator websocket, health RPC, and default skills.
    // HTTP readiness alone is not enough for setup completion: the fresh-install
    // regressions showed the app landing on Home while OpenClaw had only loaded
    // memory-core and the control websocket was still cycling.
    final operationalDeadline = DateTime.now().add(const Duration(seconds: 90));
    Object? lastOperationalError;
    var minimalReadinessStreak = 0;
    while (DateTime.now().isBefore(operationalDeadline)) {
      if (DateTime.now().difference(startTime) > timeout) {
        break;
      }
      try {
        final token = await retrieveTokenFromConfig(force: true)
            .timeout(const Duration(seconds: 5));
        if (token != null && token.isNotEmpty) {
          await _ensureWebSocket(token).timeout(const Duration(seconds: 20));
        }
        if (_state.isWebsocketConnected) {
          await _checkHealth().timeout(const Duration(seconds: 20));
        }
        if (_state.isInteractiveReady) {
          debugPrint(
              '✅ Gateway operational: websocket, RPC, skills/tools ready');
          return;
        }

        final wsReady = _state.isWebsocketConnected ||
            _connection?.state == GatewayConnectionState.connected;
        final healthReady = _state.detailedHealth != null;
        if (_state.isReady && wsReady && healthReady) {
          minimalReadinessStreak++;
          if (minimalReadinessStreak >= 2) {
            unawaited(_ensureNodeConnectedAfterGatewayReady(
              reason: 'startup-minimal-ready',
              allowDuringWarmup: true,
            ));
            debugPrint(
                '✅ Gateway minimally operational (ws+health); interactive discovery still warming, proceeding.');
            return;
          }
        } else {
          minimalReadinessStreak = 0;
        }
      } catch (e) {
        lastOperationalError = e;
      }
      await Future.delayed(const Duration(seconds: 2));
    }

    throw TimeoutException(
      'Gateway operational readiness timed out '
      '(ws=${_state.isWebsocketConnected}, '
      'interactive=${_state.isInteractiveReady}, '
      'health=${_state.detailedHealth != null}, '
      'skills=${_state.activeSkills?.length ?? 0}, '
      'last=$lastOperationalError)',
    );
  }

  void _subscribeLogs() {
    _logSubscription?.cancel();
    _logSubscription = _runtime.logStream.listen((log) {
      // Append log in-place on a capped list; no O(n) spread clone per line.
      final logs = _state.logs.length < 500
          ? [..._state.logs, log]
          : [..._state.logs.sublist(_state.logs.length - 499), log];

      _handleGatewayAutoHeal(log);
      _maybeAutoApproveDashboardPairingFromLog(log);

      // Detect "ready" signal to flip isReady flag.
      // Strip ANSI codes first: gateway logs like "[36m[gateway][39m [36mready[39m"
      // prevent a direct contains('[gateway] ready') match.
      final strippedLog = log.replaceAll(AppConstants.ansiEscape, '');
      final becameReady = !_state.isReady &&
          (strippedLog.contains('[gateway] ready') ||
              strippedLog.contains('gateway ready') ||
              log.contains('http server listening') ||
              strippedLog.contains('http server listening'));
      if (strippedLog.contains('[gateway] ready') ||
          strippedLog.contains('gateway ready') ||
          log.contains('http server listening') ||
          strippedLog.contains('http server listening')) {
        _httpWaitingSince = null;
        _consecutiveFailures = 0;
        _updateState(_state.copyWith(
          isReady: true,
          status: GatewayStatus.running,
          startedAt: _state.startedAt ?? DateTime.now(),
        ));
        if (becameReady) {
          _kickStartupHealthProbe('ready-log');
        }
      }

      // Detect restart signals to reset ready flag
      if (log.contains('signal SIGUSR1 received') ||
          log.contains('restarting')) {
        if (_gatewayConfigTransitionReason == null) {
          _beginGatewayConfigTransition('gateway restart');
        }
        _rpcDiscoveryDone = false;
        _updateState(_state.copyWith(
          isReady: false,
          isInteractiveReady: false,
        ));
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

  /// Cached accessor for the Android app files directory.
  /// Platform channel is hit only on the first call; subsequent calls are instant.
  Future<String> getFilesDir() async =>
      _filesDir ??= await NativeBridge.getFilesDir();

  /// Helper to get the host-side path to the openclaw config file.
  /// Must match the PRoot ubuntu rootfs: $filesDir/rootfs/ubuntu/root/...
  Future<String> _openClawConfigPath() async {
    return '${await getFilesDir()}/rootfs/ubuntu/root/.openclaw/openclaw.json';
  }

  Future<void> _ensureWorkspaceHeartbeatFile() async {
    try {
      final workspace = Directory(
        '${await getFilesDir()}/rootfs/ubuntu/root/.openclaw/workspace',
      );
      await workspace.create(recursive: true);

      final heartbeat = File('${workspace.path}/HEARTBEAT.md');
      if (await heartbeat.exists()) return;

      await heartbeat.writeAsString('''
# Plawie Heartbeat

HEARTBEAT_OK

This file exists so OpenClaw's default heartbeat prompt can read workspace
context without producing a missing-file error. Plawie does not schedule
autonomous workspace tasks here. If nothing else is configured, reply
HEARTBEAT_OK.
''');
      _addActivity('[SYS] Workspace HEARTBEAT.md initialized.');
    } catch (e) {
      debugPrint('[GatewayService] HEARTBEAT.md init skipped: $e');
    }
  }

  /// Recursively casts a `Map<dynamic,dynamic>` (as returned by jsonDecode)
  /// to `Map<String,dynamic>`. Required because jsonDecode on Android/Dart
  /// returns `Map<dynamic,dynamic>` even when all keys are strings.
  Map<String, dynamic> _deepCastMap(Map<dynamic, dynamic> raw) {
    return raw.map((k, v) {
      if (v is Map) return MapEntry(k.toString(), _deepCastMap(v));
      if (v is List) return MapEntry(k.toString(), _deepCastList(v));
      return MapEntry(k.toString(), v);
    });
  }

  List<dynamic> _deepCastList(List<dynamic> raw) {
    return raw.map((v) {
      if (v is Map) return _deepCastMap(v);
      if (v is List) return _deepCastList(v);
      return v;
    }).toList();
  }

  /// Direct Dart-native config read/write (bypasses proot overhead)
  Future<Map<String, dynamic>> _readConfig() async {
    for (int i = 0; i < 3; i++) {
      try {
        final file = File(await _openClawConfigPath());
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.trim().isEmpty) {
            await Future.delayed(const Duration(milliseconds: 200));
            continue;
          }
          final decoded = jsonDecode(content);
          if (decoded is Map) return _deepCastMap(decoded);
        }
        break;
      } catch (e) {
        debugPrint('[GatewayService] Config read attempt ${i + 1} error: $e');
        await Future.delayed(const Duration(milliseconds: 200));
      }
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

      _ensurePersistentGatewayToken(config);
      _applyExplicitAuthMode(config);
      _syncLocalGatewayRemoteCredentials(config);
      final nextSignature = _canonicalJsonSignature(config);

      if (await file.exists()) {
        try {
          final existingRaw = await file.readAsString();
          if (existingRaw.trim().isNotEmpty) {
            final decoded = jsonDecode(existingRaw);
            if (decoded is Map) {
              final currentSignature = _canonicalJsonSignature(
                _deepCastMap(decoded),
              );
              if (currentSignature == nextSignature) {
                return;
              }
            }
          }
        } catch (_) {
          // If parse/read fails, we still write the repaired config.
        }
      }

      await _writeStringAtomically(file, nextSignature);
    } catch (e) {
      debugPrint('[GatewayService] Config write error: $e');
    }
  }

  Future<void> _writeStringAtomically(File file, String content) async {
    final tmp =
        File('${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    await tmp.writeAsString(content, flush: true);
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await file.writeAsString(content, flush: true);
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  String _canonicalJsonSignature(Map<String, dynamic> value) {
    final normalized = _normalizeForStableCompare(value);
    return jsonEncode(normalized);
  }

  dynamic _normalizeForStableCompare(dynamic value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, dynamic>();
      value.forEach((key, child) {
        sorted['$key'] = _normalizeForStableCompare(child);
      });
      return sorted;
    }
    if (value is List) {
      return value.map(_normalizeForStableCompare).toList();
    }
    return value;
  }

  Future<void> _writeEnvFile(String key, String value) async {
    try {
      final configPath = await _openClawConfigPath();
      final envPath = configPath.replaceAll('openclaw.json', '.env');
      final file = File(envPath);

      String content = '';
      if (await file.exists()) {
        content = await file.readAsString();
      }

      final lines = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty && !l.startsWith('$key='))
          .toList();
      lines.add('$key=$value');

      await file.writeAsString(lines.join('\n'));
    } catch (e) {
      debugPrint('[GatewayService] .env write error: $e');
    }
  }

  /// Direct I/O: configure gateway binding and node settings.
  Future<void> _configureGateway() async {
    await _ensureWorkspaceHeartbeatFile();
    final config = await _readConfig();

    // Safety check: if read failed but file exists, abort to prevent clobbering auth tokens
    if (config.isEmpty) {
      final file = File(await _openClawConfigPath());
      if (await file.exists()) {
        debugPrint(
            '[GatewayService] Aborting configureGateway: Config read returned empty while file exists.');
        return;
      }
    }
    config['gateway'] ??= {};
    config['gateway']['nodes'] ??= {};
    config['gateway']['nodes']['pairing'] ??= {};
    config['gateway']['nodes']['pairing']
        ['autoApproveCidrs'] = ['127.0.0.1/32']; // Auto-approve localhost only
    config['gateway']['nodes']['denyCommands'] = [];
    config['gateway']['nodes']['allowCommands'] =
        GatewayToolCatalog.mobileNodeAllowCommands.toList(growable: false);
    config['gateway']['mode'] = 'local';

    // Keep Control UI origins explicit and loopback-only.
    // Our WS clients set Origin: http://127.0.0.1:18789, so wildcard entries
    // are unnecessary and broader than the current docs recommend.
    config['gateway']['controlUi'] ??= {};
    config['gateway']['controlUi']['allowedOrigins'] =
        localControlUiAllowedOrigins;
    (config['gateway']['controlUi'] as Map).remove(
      'dangerouslyAllowHostHeaderOriginFallback',
    );
    config['gateway']['auth'] ??= {};
    (config['gateway']['auth'] as Map).remove('unauthenticatedLocalhost');
    _applyExplicitAuthMode(config);

    // ENODEV FIX: Use official OpenClaw config schema
    // Prevent eth0 ENODEV errors with valid network binding
    config['gateway']['bind'] = 'loopback'; // Use proper OpenClaw enum value
    config['gateway']['port'] = AppConstants.gatewayPort; // Force port 18789

    // DISCOVERY FIX: Disable mDNS/Bonjour using official schema
    config['discovery'] ??= {};
    config['discovery']['mdns'] ??= {};
    config['discovery']['mdns']['mode'] = 'off'; // disable mDNS/Bonjour

    // WIDE-AREA FIX: Disable DNS-SD discovery
    config['discovery']['wideArea'] ??= {};
    config['discovery']['wideArea']['enabled'] = false;

    // Enable the OpenAI-compatible REST endpoints on port 18789.
    config['gateway']['http'] ??= {};
    config['gateway']['http']['endpoints'] ??= {};
    config['gateway']['http']['endpoints']['chatCompletions'] ??= {};
    config['gateway']['http']['endpoints']['chatCompletions']['enabled'] = true;

    // OpenClaw 2026.5.x uses a strict gateway schema. Older builds wrote
    // gateway.startup and gateway.sidecars mobile-tuning keys; the current
    // gateway rejects those at startup, so remove them aggressively.
    (config['gateway'] as Map).remove('startup');
    (config['gateway'] as Map).remove('sidecars');

    // Provider cleanup. Remove stale daemon/proxy model routes from old builds
    // so returning installs cannot accidentally revive a removed runtime.
    _ensureCatalogProviderDefaults(config);
    _removeLegacyOllamaConfig(config);
    ensureGatewayTalkTtsConfig(config);

    // Remove keys that have never been part of the OpenClaw schema.
    // These were written by earlier builds and must be stripped so the gateway
    // passes schema validation instead of running in best-effort mode.
    final agentsDefaults = config['agents']?['defaults'];
    if (agentsDefaults is Map) {
      agentsDefaults.remove('skipBootstrap');
      agentsDefaults.remove('provider'); // not in agents.defaults schema
      agentsDefaults.remove('tools'); // not in agents.defaults schema
      agentsDefaults.remove('timeoutMs'); // not in agents.defaults schema
      agentsDefaults.remove(
          'systemPrompt'); // not in agents.defaults schema — causes "Unrecognized keys" reload failure
    }
    final skills = config['skills'];
    if (skills is Map) {
      skills.remove('discovery'); // not in skills schema
      skills.remove('mode'); // not in skills schema
      skills.remove('sync'); // not in skills schema
      if (skills.isEmpty) config.remove('skills'); // don't leave empty block
    }

    // Keep the gateway out of the unrestricted/full tool universe on Android.
    // The mobile default uses official groups plus stable primitives so device
    // actions remain available without loading every plugin/provider tool.
    GatewayToolCatalog.applyDefaultMobilePolicy(config);
    ensureGatewayTalkTtsConfig(config);
    final gatewayConfig = config['gateway'];
    if (gatewayConfig is Map) {
      gatewayConfig.remove('startup');
      gatewayConfig.remove('sidecars');
    }
    final modelsConfig = config['models'];
    if (modelsConfig is Map) {
      _ensureCatalogProviderDefaults(config);
      modelsConfig['pricing'] ??= <String, dynamic>{};
      final pricing = modelsConfig['pricing'];
      if (pricing is Map) {
        pricing['enabled'] = false;
      } else {
        modelsConfig['pricing'] = <String, dynamic>{'enabled': false};
      }
    }
    _removeLegacyOllamaConfig(config);
    ensureGatewayTalkTtsConfig(config);

    // Canonicalize legacy primary ids (for example "openclaw") before the
    // gateway reads config. Invalid/alias ids trigger startup warnings and can
    // resolve to an unintended provider.
    final primary = config['agents']?['defaults']?['model']?['primary'];
    config['agents'] ??= {};
    config['agents']['defaults'] ??= {};
    if (config['agents']['defaults'] is Map) {
      (config['agents']['defaults'] as Map).remove('skipBootstrap');
    }
    config['agents']['defaults']['model'] ??= {};
    if (primary is String && primary.trim().isNotEmpty) {
      config['agents']['defaults']['model']['primary'] =
          ModelProviderCatalog.canonicalizeModelId(primary);
    } else {
      config['agents']['defaults']['model']['primary'] =
          ModelProviderCatalog.defaultCloudFallbackModel;
    }
    final timeoutSeconds = config['agents']['defaults']['timeoutSeconds'];
    if (timeoutSeconds is! num || timeoutSeconds < 240) {
      config['agents']['defaults']['timeoutSeconds'] = 240;
    }

    // NOTE: agents.defaults.systemPrompt is NOT a valid gateway schema field.
    // The gateway rejects it with "Unrecognized keys" and breaks config hot-reload.
    // Device skills are registered via skills.register RPC at connect time instead.

    // Remove invalid TTS persona "model" keys — gateway schema rejects them.
    // openclaw onboard writes these defaults; must be stripped before gateway reads config.
    final ttsPersonas = (config['messages'] as Map?)?['tts']?['personas'];
    if (ttsPersonas is Map) {
      for (final p in ttsPersonas.values) {
        if (p is Map) (p as Map<String, dynamic>).remove('model');
      }
    }

    await _writeConfig(config);
  }

  void _applyExplicitAuthMode(Map<String, dynamic> config) {
    config['gateway'] ??= {};
    final gateway = config['gateway'];
    if (gateway is! Map) return;

    final auth = gateway['auth'];
    if (auth is! Map) return;

    final token = auth['token'];
    final password = auth['password'];
    final currentMode = auth['mode'];

    if (currentMode is String && currentMode.isNotEmpty) return;

    if (token is String && token.isNotEmpty) {
      auth['mode'] = 'token';
      return;
    }
    if (password is String && password.isNotEmpty) {
      auth['mode'] = 'password';
    }
  }

  void _ensurePersistentGatewayToken(Map<String, dynamic> config) {
    config['gateway'] ??= {};
    final gateway = config['gateway'];
    if (gateway is! Map) return;

    final mode = gateway['mode'];
    if (mode is String && mode.isNotEmpty && mode != 'local') return;

    gateway['auth'] ??= {};
    final auth = gateway['auth'];
    if (auth is! Map) return;

    final token = auth['token'];
    if (token is String && token.isNotEmpty) return;
    final password = auth['password'];
    if (password is String && password.isNotEmpty) return;

    // Keep a stable persisted token to prevent runtime-token churn on every reboot.
    final generated = 'plawie-${const Uuid().v4().replaceAll('-', '')}';
    auth['token'] = generated;
    auth['mode'] = 'token';
  }

  void _syncLocalGatewayRemoteCredentials(Map<String, dynamic> config) {
    config['gateway'] ??= {};
    final gateway = config['gateway'];
    if (gateway is! Map) return;

    final mode = gateway['mode'];
    if (mode is String && mode.isNotEmpty && mode != 'local') return;

    gateway['auth'] ??= {};
    final auth = gateway['auth'];
    if (auth is! Map) return;

    gateway['remote'] ??= {};
    final remote = gateway['remote'];
    if (remote is! Map) return;

    final token = auth['token'];
    if (token is String && token.isNotEmpty) {
      remote['token'] = token;
    } else {
      remote.remove('token');
    }

    final password = auth['password'];
    if (password is String && password.isNotEmpty) {
      remote['password'] = password;
    } else {
      remote.remove('password');
    }
  }

  Future<void> persistModel(String model) async {
    final canonical = ModelProviderCatalog.canonicalizeModelId(model);
    if (ModelProviderCatalog.isDirectLocalModelId(canonical)) {
      _addActivity(
          '[MODEL] Selected direct NDK model $canonical without changing gateway primary.');
      return;
    }
    final config = await _readConfig();
    config['agents'] ??= {};
    config['agents']['defaults'] ??= {};
    if (config['agents']['defaults'] is Map) {
      (config['agents']['defaults'] as Map).remove('skipBootstrap');
    }
    config['agents']['defaults']['model'] ??= {};
    config['agents']['defaults']['model']['primary'] = canonical;
    _ensureCatalogProviderDefaults(config);
    try {
      if (await _runtime.isRunning()) {
        _beginGatewayConfigTransition(
          'model selection update',
          minimumSettle: _gatewayConfigSoftSettle,
        );
      }
    } catch (_) {}
    await _writeConfig(config);
  }

  Future<bool> hasProviderCredential(String provider) async {
    final normalized = _normalizeProvider(provider);

    try {
      final config = await _readConfig();
      final providerConfig = config['models']?['providers']?[normalized];
      if (providerConfig is Map) {
        final apiKey = providerConfig['apiKey'];
        if (_credentialValueLooksSet(apiKey)) return true;
      }

      final envKey = _getEnvKeyForProvider(normalized);
      final envVars = config['env']?['vars'];
      if (envVars is Map && _credentialValueLooksSet(envVars[envKey])) {
        return true;
      }

      final authFile = File(
        '${await getFilesDir()}/rootfs/ubuntu/root/.openclaw/agents/main/agent/auth-profiles.json',
      );
      if (!await authFile.exists()) return false;
      final raw = await authFile.readAsString();
      if (raw.trim().isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final profiles = decoded['profiles'];
      if (profiles is! Map) return false;
      final profile = profiles[authProfileIdForProvider(normalized)];
      if (profile is! Map) return false;
      return _credentialValueLooksSet(profile['key']) ||
          _credentialValueLooksSet(profile['token']) ||
          _credentialValueLooksSet(profile['keyRef']) ||
          _credentialValueLooksSet(profile['tokenRef']);
    } catch (_) {
      return false;
    }
  }

  bool _credentialValueLooksSet(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty && trimmed != 'null';
    }
    if (value is Map || value is List) return value.isNotEmpty;
    return false;
  }

  void _removeLegacyOllamaConfig(Map<String, dynamic> config) {
    final models = config['models'];
    if (models is Map) {
      models.remove('startup');
      final providers = models['providers'];
      if (providers is Map) providers.remove('ollama');
    }
    final auth = config['auth'];
    if (auth is Map) {
      final profiles = auth['profiles'];
      if (profiles is Map) profiles.remove('ollama:default');
      final order = auth['order'];
      if (order is Map) order.remove('ollama');
    }
    config.remove('ollama');
  }

  void _ensureCatalogProviderDefaults(Map<String, dynamic> config) {
    if (config['models'] is! Map) config['models'] = <String, dynamic>{};
    final models = config['models'] as Map;
    if (models['providers'] is! Map) {
      models['providers'] = <String, dynamic>{};
    }
    final providers = models['providers'] as Map;
    for (final provider in ModelProviderCatalog.providers) {
      // plawie_ndk is written exclusively by configureNdkGatewayBridge().
      // Merging it here with generic defaults can clobber the gateway-validated
      // 'api' field or overwrite the baseUrl on unrelated config writes.
      // Always re-merge it with the correct defaults so a stale on-disk
      // 'openai' value is healed on every write cycle.
      if (provider.id == ModelProviderCatalog.plawieNdkProviderId) {
        final existing = providers[provider.id];
        if (existing is Map) {
          // Only heal — never inject when the block doesn't exist yet.
          providers[provider.id] = ModelProviderCatalog.mergeProviderConfig(
            provider.id,
            existing,
          );
        }
        continue;
      }
      final existing = providers[provider.id];
      providers[provider.id] = ModelProviderCatalog.mergeProviderConfig(
        provider.id,
        existing is Map ? existing : null,
      );
    }
  }

  /// Map a provider name to its default model string (provider/model).
  /// Public so GatewayProvider can call it during configureAndStart.
  String getModelForProvider(String provider) {
    return ModelProviderCatalog.defaultModelForProvider(provider);
  }

  /// Normalize provider names to OpenClaw internal identifiers.
  /// Handles human names, provider IDs, and legacy env-key IDs.
  String _normalizeProvider(String provider) {
    return ModelProviderCatalog.apiProviderForSetupId(provider);
  }

  /// Get the standard environment variable name for a provider's API key.
  String _getEnvKeyForProvider(String provider) {
    return ModelProviderCatalog.envKeyForProvider(provider);
  }

  /// Write an API key (Direct I/O — avoids proot / node-e overhead)
  Future<void> configureApiKey(
    String provider,
    String key, {
    bool runBackgroundOnboard = true,
  }) async {
    final openClawProvider = _normalizeProvider(provider);
    final envKey = _getEnvKeyForProvider(provider);

    final defaultModels =
        ModelProviderCatalog.defaultModelsForProvider(openClawProvider);

    // Generate a secure gateway token if we don't have one
    final prefs = PreferencesService();
    await prefs.init();
    String gatewayToken = prefs.gatewayToken;
    if (gatewayToken.isEmpty) {
      gatewayToken = const Uuid().v4();
      prefs.gatewayToken = gatewayToken;
    }

    // Use official 'onboard' CLI for production-ready config
    // We pass sensitive keys via environment variables to enable SecretRef storage
    final onboardCmd = [
      'export PATH=\$PATH:/usr/local/bin:/usr/bin',
      'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js"',
      'export OPENCLAW_GATEWAY_TOKEN="$gatewayToken"',
      'export OPENCLAW_PROVIDER_KEY="$key"',
      'openclaw onboard --non-interactive',
      '--mode local',
      '--auth-choice custom-api-key',
      '--custom-base-url "${openClawProvider == 'google' ? "https://generativelanguage.googleapis.com/v1beta" : ""}"',
      '--custom-model-id "${defaultModels.first['id']}"',
      '--custom-api-key-ref-env OPENCLAW_PROVIDER_KEY', // Use SecretRef for API Key
      '--gateway-auth token',
      '--gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN', // Use SecretRef for Gateway Token
      '--accept-risk'
    ].join(' && ');

    // HYBRID PATH:
    // 1. Manual patch first (instant) — ensures app is usable immediately
    final config = await _readConfig();
    config['env'] ??= {};
    config['env']['vars'] ??= {};
    if (envKey.isNotEmpty) config['env']['vars'][envKey] = key;
    // Per OpenClaw docs: gateway.mode must always be set explicitly in local mode
    config['gateway'] ??= {};
    config['gateway']['mode'] = 'local';
    config['models'] ??= {};
    config['models']['providers'] ??= {};
    final prov = config['models']['providers'][openClawProvider];
    config['models']['providers'][openClawProvider] =
        ModelProviderCatalog.mergeProviderConfig(
      openClawProvider,
      prov is Map ? prov : null,
      apiKey: key,
    );
    ensureProviderAuthConfigBlock(config, openClawProvider);
    ensureGatewayTalkTtsConfig(config);

    // Keep the local Control UI origin list explicit and minimal.
    config['gateway'] ??= {};
    config['gateway']['controlUi'] ??= {};
    config['gateway']['controlUi']['allowedOrigins'] =
        localControlUiAllowedOrigins;
    (config['gateway']['controlUi'] as Map).remove(
      'dangerouslyAllowHostHeaderOriginFallback',
    );
    config['gateway']['auth'] ??= {};
    (config['gateway']['auth'] as Map).remove('unauthenticatedLocalhost');
    _applyExplicitAuthMode(config);

    var gatewayRunningForCredentialChange = false;
    try {
      gatewayRunningForCredentialChange = await _runtime.isRunning();
      if (gatewayRunningForCredentialChange) {
        _beginGatewayConfigTransition('provider credential update');
      }
    } catch (_) {}

    await _writeConfig(config);
    _addActivity('[Gateway] Fast-path API key config complete.');

    // 2. Official 'onboard' CLI in background (for long-term integrity/SecretRefs)
    // Optional: setup bootstrap can disable this to avoid post-start config churn.
    if (runBackgroundOnboard) {
      // We do NOT await this, preventing the 5-minute UI deadlock.
      unawaited(NativeBridge.runInProot(onboardCmd, timeout: 60).then((_) {
        _addActivity('[Gateway] Background onboarding CLI complete.');
      }).catchError((e) {
        _addActivity('[Gateway] Background onboarding CLI failed: $e');
      }));
    }

    // 2. Update agent auth-profiles.json in the current canonical format.
    await _writeApiKeyAuthProfile(provider: openClawProvider, key: key);

    // 3. Update .env for CLI compatibility
    if (envKey.isNotEmpty) {
      await _writeEnvFile(envKey, key);
    }

    // 4. Trigger reload only when a gateway process is running.
    try {
      final running = await _runtime.isRunning();
      if (running) {
        if (!gatewayRunningForCredentialChange) {
          _beginGatewayConfigTransition('provider credential update');
        }
        await NativeBridge.runInProot(
          'export PATH=\$PATH:/usr/local/bin:/usr/bin && export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
          'openclaw reload || openclaw gateway config apply',
          timeout: 10,
        );
        _addActivity(
            '[Gateway] Reload requested; credential changes may briefly restart Gateway.');
        invalidateTokenCache();
        disconnectWebSocket();
      }
    } catch (_) {}
  }

  /// Experimental provider wiring for the native fllama HTTP bridge.
  ///
  /// This is deliberately explicit and not used by first-run setup. It lets us
  /// test whether the Gateway can treat Plawie's NDK bridge as an
  /// OpenAI-compatible provider without reintroducing a PRoot daemon.
  Future<void> configureNdkGatewayBridge({
    bool setAsPrimary = true,
    bool reloadIfRunning = false,
  }) async {
    final provider = ModelProviderCatalog.plawieNdkProviderId;
    const bridgeKey = 'plawie-ndk-local';

    final config = await _readConfig();
    config['models'] ??= <String, dynamic>{};
    config['models']['providers'] ??= <String, dynamic>{};
    config['models']['providers'][provider] =
        ModelProviderCatalog.mergeProviderConfig(
      provider,
      null,
      apiKey: bridgeKey,
    );
    ensureProviderAuthConfigBlock(config, provider);

    if (setAsPrimary) {
      config['agents'] ??= <String, dynamic>{};
      config['agents']['defaults'] ??= <String, dynamic>{};
      config['agents']['defaults']['model'] ??= <String, dynamic>{};
      config['agents']['defaults']['model']['primary'] = '$provider/local-llm';

      final prefs = PreferencesService();
      await prefs.init();
      prefs.configuredModel = '$provider/local-llm';
    }

    var gatewayRunningForBridgeUpdate = false;
    if (reloadIfRunning) {
      try {
        gatewayRunningForBridgeUpdate = await _runtime.isRunning();
        if (gatewayRunningForBridgeUpdate) {
          _beginGatewayConfigTransition('NDK bridge provider update');
        }
      } catch (_) {}
    }

    await _writeConfig(config);
    await _writeApiKeyAuthProfile(provider: provider, key: bridgeKey);
    _addActivity(
      '[NDK-BRIDGE] Gateway provider configured at ${ModelProviderCatalog.plawieNdkBaseUrl}',
    );

    var reloadRunningGateway = gatewayRunningForBridgeUpdate;
    if (reloadIfRunning && !reloadRunningGateway) {
      try {
        reloadRunningGateway = await _runtime.isRunning();
      } catch (_) {}
    }

    if (reloadIfRunning && reloadRunningGateway) {
      if (!gatewayRunningForBridgeUpdate) {
        _beginGatewayConfigTransition('NDK bridge provider update');
      }
      await NativeBridge.runInProot(
        'export PATH=\$PATH:/usr/local/bin:/usr/bin && '
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'openclaw reload 2>/dev/null || true',
        timeout: 15,
      );
      disconnectWebSocket();
    }
  }

  Future<void> reregisterSkills() async {
    if (!_state.isRunning) return;
    // Only register device-native skills when the gateway advertises the RPC.
    // Calling this on newer gateways that omit skills.register can collapse the
    // broader tool context down to just Plawie's bundled skills.
    final supported = _connection?.supportedMethods ?? const <String>[];
    final methodAdvertised = supported.contains('skills.register');
    final discoveryUnknown = supported.isEmpty;
    if (!methodAdvertised && !discoveryUnknown) {
      _addActivity(
          '[SKILLS] skills.register not advertised; preserving gateway tool catalog');
      return;
    }
    try {
      final catalog = SkillsService().getToolsCatalog();
      if (catalog.isNotEmpty) {
        await invoke('skills.register', {
          'skills': catalog,
          'callbackUrl': 'http://127.0.0.1:8765',
        }).timeout(const Duration(seconds: 5));
        _addActivity(
          '[SKILLS] Registered ${catalog.length} device skills with gateway',
        );
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('unknown method') ||
          msg.contains('method unavailable') ||
          msg.contains('not supported')) {
        // Keep logging concise when the gateway explicitly omitted the method.
        if (methodAdvertised || supported.isEmpty) {
          _addActivity('[SKILLS] skills.register unavailable on this gateway');
        }
      } else {
        _addActivity('[SKILLS] skills.register failed: $e');
      }
    }
  }

  /// Explicitly query the OpenClaw CLI for the Dashboard URL containing the auth token.
  /// OpenClaw never writes its runtime token to openclaw.json — it only appears in startup
  /// logs (captured by _subscribeLogs) or via `openclaw dashboard --no-open`.
  /// When attaching to an already-running gateway, no fresh startup logs exist, so we
  /// MUST call the CLI to retrieve the live token.
  /// Explicitly query the OpenClaw CLI for the Dashboard URL containing the auth token.
  /// This is required because OpenClaw 2.x no longer prints the token in startup logs automatically.
  Future<String?> fetchAuthenticatedDashboardUrl({bool force = false}) async {
    // Dashboard auth must stay independent from optional local inference.
    // Legacy ollama/* selections are migrated elsewhere; opening the dashboard
    // should never start a heavyweight runtime.

    // If we already have a tokenized URL and aren't forcing, return it immediately
    if (!force &&
        _state.dashboardUrl != null &&
        _state.dashboardUrl!.contains('token=')) {
      return _state.dashboardUrl;
    }

    // STEP 0: Use the canvasHostUrl directly from the hello-ok handshake response.
    // Gateway v2026.x embeds a fully-authenticated URL in the connect payload — no CLI needed.
    final canvasUrl = _connection?.canvasHostUrl;
    if (canvasUrl != null && canvasUrl.isNotEmpty) {
      if (!force) {
        _updateState(_state.copyWith(
          dashboardUrl: canvasUrl,
          logs: [
            ..._state.logs,
            '[INFO] Web UI URL acquired from gateway handshake.'
          ],
        ));
        return canvasUrl;
      }
    }

    _updateState(_state.copyWith(logs: [
      ..._state.logs,
      '[DEBUG] Probing gateway config for auth token...'
    ]));

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
        sanitizedBaseUrl =
            sanitizedBaseUrl.substring(0, sanitizedBaseUrl.length - 1);
      }

      // A clean gateway dashboard URL requires /#token= for the SPA frontend
      final urlWithToken = '$sanitizedBaseUrl/#token=$token';
      prefs.dashboardUrl = urlWithToken;
      _updateState(_state.copyWith(
        dashboardUrl: urlWithToken,
        logs: [
          ..._state.logs,
          '[INFO] Gateway auth token acquired from config.'
        ],
      ));
      return urlWithToken;
    }

    // STEP 2: Fallback to CLI dashboard probe WITH bionic-bypass (fixes the MAC error)
    try {
      final output = await NativeBridge.runInProot(
          '$kOpenClawCommand dashboard --no-open',
          timeout: 10);
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
        _updateState(_state.copyWith(logs: [
          ..._state.logs,
          '[WARN] Dashboard probe failed to find token. Ensure openclaw is starting correctly.'
        ]));
      }
    } catch (e) {
      _updateState(_state.copyWith(
          logs: [..._state.logs, '[WARN] CLI dashboard probe failed: $e']));
    }

    return _state.dashboardUrl;
  }

  String? _cachedToken;
  DateTime? _lastTokenFetch;

  /// Direct I/O: Retrieve token from config file (instant, no proot)
  Future<String?> retrieveTokenFromConfig({bool force = false}) async {
    if (force) clearTokenCache();
    if (_cachedToken != null &&
        _lastTokenFetch != null &&
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
    if (_state.dashboardUrl != null &&
        _state.dashboardUrl!.contains('token=')) {
      final uri = Uri.parse(
          _state.dashboardUrl!.replaceAll('#', '?')); // fragment to query
      final urlToken = uri.queryParameters['token'];
      if (urlToken != null && urlToken.isNotEmpty) {
        _cachedToken = urlToken;
        _lastTokenFetch = DateTime.now();
        return urlToken;
      }
    }

    return null;
  }

  /// Clear the host-side token cache to force a fresh read from disk.
  void clearTokenCache() {
    _cachedToken = null;
    _lastTokenFetch = null;
  }

  /// Clear the operator device token from SharedPreferences and in-memory cache.
  /// Call this from the UI "Clear Cache" action so the next connect does a
  /// fresh identity handshake instead of reusing a potentially stale token.
  Future<void> clearDeviceToken({bool clearProtocol = false}) async {
    clearTokenCache();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(GatewayConnection.prefDeviceToken);
      if (clearProtocol) {
        await prefs.remove(GatewayConnection.prefWsProtocol);
      }
    } catch (_) {}
  }

  /// Reset the RPC discovery flag so the next health-check tick re-runs
  /// `health` and `skills.status`. Call this after
  /// installing/uninstalling a skill or any time the user wants a fresh read.
  void refreshRpcDiscovery() {
    _rpcDiscoveryDone = false;
    _updateState(_state.copyWith(
      isInteractiveReady: false,
      logs: [
        ..._state.logs,
        '[INFO] RPC discovery refreshed — will re-query on next tick'
      ],
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
    _gatewayEventSubscription?.cancel();
    _gatewayEventSubscription = null;
    _connection?.dispose();
    _connection = null;
    _cachedToken = null;
    NodeService().clearCachedToken();
    _lastTokenFetch = null;

    try {
      await _runtime.stop();
      for (var attempt = 0; attempt < 8; attempt++) {
        final stillRunning =
            await _runtime.isRunning().catchError((_) => false);
        if (!stillRunning) break;
        await Future.delayed(const Duration(milliseconds: 350));
      }
      _updateState(_state.copyWith(
        status: GatewayStatus.stopped,
        isWebsocketConnected: false,
        isInteractiveReady: false,
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
    final currentState = _connection?.state;
    if (currentState == GatewayConnectionState.connected) {
      if (!_state.isWebsocketConnected) {
        _updateState(_state.copyWith(isWebsocketConnected: true));
      }
      return true;
    }
    if (currentState == GatewayConnectionState.connecting ||
        currentState == GatewayConnectionState.handshaking) {
      return false;
    }
    final now = DateTime.now();
    final lastWsAttempt = _lastWsConnectAttemptAt;
    if (lastWsAttempt != null &&
        now.difference(lastWsAttempt) < _wsConnectRetryCooldown) {
      return false;
    }
    _lastWsConnectAttemptAt = now;

    if (_connection == null) {
      _connection = GatewayConnection();
      _connection!.stateStream.listen((wsState) {
        final connected = wsState == GatewayConnectionState.connected;
        final disconnected = wsState == GatewayConnectionState.disconnected;
        if (connected) {
          _pairingResolveAttempted = false; // Reset on success
          _lastWsConnectAttemptAt = null;
          if (!_rpcDiscoveryDone) {
            _kickStartupHealthProbe('ws-connected');
          }
        }
        final closeCode = _connection?.lastCloseCode;
        final closeReasonRaw = (_connection?.lastCloseReason ?? '').trim();
        final closeReason = _describeWsClose(closeCode, closeReasonRaw);
        if (disconnected) {
          _rpcDiscoveryDone =
              false; // Bug 1 fix: Reset RPC discovery flag on WS disconnect
          unawaited(_logGatewayDisconnectContext());
        }
        if (!connected && !disconnected) {
          // Transitional state (connecting/handshaking) — not a real disconnect.
          _updateState(_state.copyWith(
            isWebsocketConnected: false,
            isInteractiveReady: false,
          ));
          return;
        }
        _updateState(_state.copyWith(
          isWebsocketConnected: connected,
          isInteractiveReady: connected ? _rpcDiscoveryDone : false,
          logs: connected
              ? [
                  ..._state.logs,
                  '[INFO] WebSocket connected (session: ${_connection?.mainSessionKey ?? 'pending'})'
                ]
              : [
                  ..._state.logs,
                  '[WARN] WebSocket disconnected (closeCode=${closeCode ?? 'n/a'} reason=$closeReason)'
                ],
        ));
      });
      // Listen for 1008 pairing required events from the gateway
      _connection!.pairingRequiredStream
          .listen((requestId) => _handleOperatorPairingRequired(requestId));
      // Listen to gateway events for non-blocking operator/browser pairing UX.
      // Web Dashboard runs in a separate WebView client identity and may emit
      // device.pair.requested independently from this control channel.
      _gatewayEventSubscription?.cancel();
      _gatewayEventSubscription = _connection!.eventStream.listen(
        _handleGatewayEventFrame,
      );
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
        isInteractiveReady: _rpcDiscoveryDone,
        logs: [
          ..._state.logs,
          '[INFO] WebSocket handshake complete (session: ${_connection!.mainSessionKey ?? 'main'})'
        ],
      ));
    } else {
      _updateState(_state.copyWith(
        logs: [
          ..._state.logs,
          '[WARN] WebSocket connect failed — will retry on next health tick'
        ],
      ));
    }
    return ok;
  }

  void _handleGatewayEventFrame(Map<String, dynamic> frame) {
    final event = frame['event']?.toString() ?? '';
    if (event != 'device.pair.requested') return;

    final payload = frame['payload'];
    final requestId = _extractRequestIdFromDynamic(payload) ??
        _extractRequestIdFromDynamic(frame);
    if (requestId == null || requestId.isEmpty) return;

    // device.pair.* can include node requests in edge cases. The web dashboard
    // sometimes omits role metadata, so we reject explicit node roles but allow
    // operator/browser/unknown local UI requests and let requestId approval
    // preserve the gateway's requested role/scopes.
    final role =
        _extractStringFromDynamic(payload, const {'role', 'requestedRole'})
                ?.toLowerCase() ??
            '';
    if (role == 'node') return;
    if (role.isNotEmpty && role != 'operator' && role != 'browser') return;

    unawaited(_autoApproveDashboardPairingRequest(requestId, source: 'event')
        .then((_) => null));
  }

  String? _extractRequestIdFromDynamic(Object? value) {
    final uuidPattern = RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
    );

    String? visit(Object? node) {
      if (node is String) {
        final direct = node.trim();
        if (uuidPattern.hasMatch(direct.toLowerCase())) return direct;
        final match = RegExp(
          r'requestid[:=\s]+([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})',
          caseSensitive: false,
        ).firstMatch(node);
        return match?.group(1);
      }
      if (node is Map) {
        const keys = <String>{
          'requestId',
          'requestID',
          'request_id',
          'pairingRequestId',
          'pairing_request_id',
        };
        for (final entry in node.entries) {
          if (keys.contains('${entry.key}')) {
            final id = visit(entry.value);
            if (id != null) return id;
          }
        }
        for (final child in node.values) {
          final id = visit(child);
          if (id != null) return id;
        }
      }
      if (node is List) {
        for (final child in node) {
          final id = visit(child);
          if (id != null) return id;
        }
      }
      return null;
    }

    return visit(value);
  }

  String? _extractStringFromDynamic(Object? value, Set<String> keys) {
    String? visit(Object? node) {
      if (node is Map) {
        for (final entry in node.entries) {
          final key = '${entry.key}';
          if (keys.contains(key) && entry.value is String) {
            final v = (entry.value as String).trim();
            if (v.isNotEmpty) return v;
          }
        }
        for (final child in node.values) {
          final v = visit(child);
          if (v != null) return v;
        }
      } else if (node is List) {
        for (final child in node) {
          final v = visit(child);
          if (v != null) return v;
        }
      }
      return null;
    }

    return visit(value);
  }

  Future<bool> _autoApproveDashboardPairingRequest(
    String requestId, {
    required String source,
  }) async {
    final safeRequestId = requestId.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9-]{16,}$').hasMatch(safeRequestId)) return false;
    if (_autoApprovedDashboardRequestIds.contains(safeRequestId)) return true;

    final now = DateTime.now();
    final lastAttempt = _lastDashboardPairingApprovalAttemptAt;
    if (_dashboardPairingApprovalInFlight) return false;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _dashboardPairingApprovalCooldown) {
      return false;
    }

    _dashboardPairingApprovalInFlight = true;
    _lastDashboardPairingApprovalAttemptAt = now;
    try {
      _addActivity(
          '[PAIR] Dashboard requested browser approval ($safeRequestId via $source) — auto-approving...');
      var approved = await _tryApprovePairingViaRpc(safeRequestId);
      if (!approved) {
        // If the previous operator token was under-scoped, _tryApprovePairingViaRpc
        // clears it and schedules reconnect. Give that recovery a short window
        // before falling back to the CLI path.
        await Future.delayed(const Duration(milliseconds: 1800));
        approved = await _tryApprovePairingViaRpc(safeRequestId);
      }
      if (!approved) {
        await _approveOperatorPairingRequest(
          safeRequestId,
          skipRequestResolution: true,
        );
        approved = true;
      }
      _autoApprovedDashboardRequestIds.add(safeRequestId);
      _addActivity(
          '[PAIR] Dashboard browser approval succeeded ($safeRequestId).');
      return true;
    } catch (e) {
      _addActivity(
          '[WARN] Dashboard browser auto-approval failed ($safeRequestId): $e');
      return false;
    } finally {
      _dashboardPairingApprovalInFlight = false;
    }
  }

  void _maybeAutoApproveDashboardPairingFromLog(String rawLog) {
    final stripped = rawLog.replaceAll(AppConstants.ansiEscape, '');
    final lower = stripped.toLowerCase();
    if (!lower.contains('pairing required: device is not approved yet')) return;
    if (!lower.contains('origin=http://127.0.0.1:18789')) return;
    if (!lower.contains('remote=127.0.0.1')) return;
    if (!lower.contains('wv)') && !lower.contains('mozilla/5.0')) return;

    final requestId = _extractRequestIdFromDynamic(stripped);
    if (requestId == null || requestId.isEmpty) return;
    unawaited(_autoApproveDashboardPairingRequest(requestId, source: 'log')
        .then((_) => null));
  }

  Future<bool> _tryApprovePairingViaRpc(String requestId) async {
    final conn = _connection;
    if (conn == null || conn.state != GatewayConnectionState.connected) {
      return false;
    }

    try {
      final frame = await invoke('device.pair.approve', {
        'requestId': requestId,
      }).timeout(const Duration(seconds: 10));
      if (frame['ok'] == true) return true;
      final payload = frame['payload'];
      if (payload is Map && payload['ok'] == true) return true;
      final missingScope = _missingOperatorApprovalScope(frame);
      if (missingScope != null) {
        await _recoverOperatorScopeForPairing(missingScope);
      }
    } catch (e) {
      final missingScope = _missingOperatorApprovalScope(e);
      if (missingScope != null) {
        await _recoverOperatorScopeForPairing(missingScope);
      }
    }
    return false;
  }

  String? _missingOperatorApprovalScope(Object? value) {
    String text;
    if (value is String) {
      text = value;
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = value.toString();
      }
    }
    final lower = text.toLowerCase();
    if (lower.contains('missing scope: operator.admin')) {
      return 'operator.admin';
    }
    if (lower.contains('missing scope: operator.pairing')) {
      return 'operator.pairing';
    }
    return null;
  }

  Future<void> _recoverOperatorScopeForPairing(String missingScope) async {
    _addActivity(
        '[PAIR] Operator token lacks $missingScope; clearing cached token for scope refresh.');
    _gatewayEventSubscription?.cancel();
    _gatewayEventSubscription = null;
    _connection?.disconnect();
    _connection = null;
    await clearDeviceToken();
    unawaited(Future.delayed(
      const Duration(milliseconds: 750),
      () => _checkHealth(),
    ));
  }

  /// Called when the gateway closes the operator WS with 1008 (pairing required).
  Future<void> _handleOperatorPairingRequired([String? requestId]) async {
    if (_pairingResolveAttempted) return;
    _pairingResolveAttempted = true;
    final pairingConnection = _connection;
    final deviceId = pairingConnection?.deviceId ?? '';
    _gatewayEventSubscription?.cancel();
    _gatewayEventSubscription = null;
    pairingConnection?.disconnect();
    _connection = null;
    await clearDeviceToken();

    if (requestId != null && requestId.isNotEmpty) {
      _addActivity(
          '[INFO] Pairing required (1008) — auto-approving operator $requestId...');
      try {
        await _approveOperatorPairingRequest(requestId, deviceId: deviceId);
        await Future.delayed(const Duration(milliseconds: 1500));
        _addActivity('[INFO] Operator device approved successfully');
      } catch (e) {
        _addActivity('[WARN] Operator auto-approve failed: $e');
        _addActivity(
            '[WARN] Keeping existing operator pairing record; skipping automatic remove/clear.');
      }
    } else {
      _addActivity(
          '[WARN] Pairing required without requestId; skipping automatic remove/clear.');
    }

    pairingConnection?.dispose();
    _connection = null;
    _pairingResolveAttempted = false;
    unawaited(Future.delayed(
      const Duration(milliseconds: 750),
      () => _checkHealth(),
    ));
  }

  Future<void> _approveOperatorPairingRequest(
    String requestId, {
    String? deviceId,
    bool skipRequestResolution = false,
  }) async {
    final safeRequestId = requestId.trim();
    if (!RegExp(r'^[a-f0-9-]{16,}$').hasMatch(safeRequestId)) {
      throw Exception('Invalid pairing request id: $requestId');
    }
    final token = await retrieveTokenFromConfig(force: true);
    final localGatewayUrl =
        'ws://${AppConstants.gatewayHost}:${AppConstants.gatewayPort}';
    final resolvedRequestId = skipRequestResolution
        ? safeRequestId
        : await _resolvePendingDeviceRequestId(
              fallbackRequestId: safeRequestId,
              deviceId: deviceId,
              role: 'operator',
              gatewayUrl: localGatewayUrl,
              token: token,
            ) ??
            safeRequestId;
    try {
      await NativeBridge.runInProot(
        'openclaw devices approve $resolvedRequestId --json',
        timeout: 40,
      );
    } catch (e) {
      if (token == null || token.isEmpty) rethrow;
      // Scope-upgrade means CLI's stored session is under-scoped; admin token
      // has operator.admin rights and can approve regardless.
      if (_isPairingApprovalBlockedError(e)) {
        _addActivity(
            '[WARN] CLI session under-scoped for approval — retrying with admin token...');
      } else {
        _addActivity(
            '[INFO] Operator approval failed ($e); retrying with explicit gateway auth...');
      }
      final retryRequestId = skipRequestResolution
          ? resolvedRequestId
          : await _resolvePendingDeviceRequestId(
                fallbackRequestId: safeRequestId,
                deviceId: deviceId,
                role: 'operator',
                gatewayUrl: localGatewayUrl,
                token: token,
              ) ??
              resolvedRequestId;
      await NativeBridge.runInProot(
        'openclaw devices approve $retryRequestId '
        '--url ${NativeBridge.shellQuote(localGatewayUrl)} '
        '--token ${NativeBridge.shellQuote(token)} '
        '--json',
        timeout: 40,
      );
    }
  }

  bool _isPairingApprovalBlockedError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('scope upgrade pending approval') ||
        message.contains(
            'device is asking for more scopes than currently approved') ||
        message.contains('invalid scope for requested roles');
  }

  Future<String?> _resolvePendingDeviceRequestId({
    required String fallbackRequestId,
    required String? gatewayUrl,
    required String? token,
    String? deviceId,
    String? role,
  }) async {
    try {
      final explicitArgs = token != null && token.isNotEmpty
          ? ' --url ${NativeBridge.shellQuote(gatewayUrl ?? 'ws://${AppConstants.gatewayHost}:${AppConstants.gatewayPort}')}'
              ' --token ${NativeBridge.shellQuote(token)}'
          : '';
      final output = await NativeBridge.runInProot(
        'openclaw devices list --json$explicitArgs',
        timeout: 20,
      );
      return NativeBridge.extractPendingDeviceRequestId(
        output,
        requestedId: fallbackRequestId,
        deviceId: deviceId,
        role: role,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkHealth() async {
    // ── Re-entrancy guard ────────────────────────────────────────────────
    // Prevent overlapping health ticks. Each tick can involve PRoot calls
    // and WS handshakes that take several seconds. Without this guard,
    // timer ticks pile up and cause cascading stalls.
    if (_healthCheckInFlight) return;

    if (LocalLlmService().isInferring) {
      final now = DateTime.now();
      final last = _lastLocalInferenceHealthSkipAt;
      if (last == null ||
          now.difference(last) > _localInferenceHealthSkipLogCooldown) {
        _lastLocalInferenceHealthSkipAt = now;
        _updateState(_state.copyWith(logs: [
          ..._state.logs,
          '[HEALTH] Skipping gateway probe while NDK local inference is active'
        ]));
      }
      return;
    }

    _healthCheckInFlight = true;

    // Add process validation before health checks
    unawaited(_validateGatewayProcess());

    try {
      // ── 1. Fast HTTP probe ─────────────────────────────────────────────
      // Current OpenClaw answers the authenticated /health route reliably.
      // HEAD / can hang behind the dashboard/router on Android PRoot, which
      // produced scary false "probe failed" logs even while the gateway was
      // live and WS clients were paired.
      String? token;
      try {
        token = await retrieveTokenFromConfig()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
      } catch (_) {}

      final response = await _probeGatewayHealth(
        token: token,
        timeout: _gatewayHealthProbeTimeout,
      );

      if (response.statusCode < 500) {
        unawaited(NativeGatewaySmokeService.runCanaryComparisonIfEnabled(
          log: _addActivity,
          productionHealth: _decodeObject(response.body),
        ));
        _consecutiveFailures = 0; // Success — reset failure counter

        // ── 2. Single token retrieval (with timeout) ─────────────────────
        if (token == null || token.isEmpty) {
          try {
            token = await retrieveTokenFromConfig()
                .timeout(const Duration(seconds: 5));
          } catch (_) {
            _updateState(_state.copyWith(
              logs: [
                ..._state.logs,
                '[WARN] Token retrieval timed out — skipping WS/RPC this tick'
              ],
            ));
            return; // Skip WS + RPC work; next tick will retry
          }
        }

        if (token == null || token.isEmpty) {
          // Actively probe for token in background so it's ready before the next tick
          unawaited(fetchAuthenticatedDashboardUrl(force: true));
          return;
        }

        // Mark running only after both checks pass: config token is readable
        // and the HTTP listener is answering. A token alone is not readiness.
        if (_state.status != GatewayStatus.running) {
          _httpWaitingSince =
              null; // HTTP is up — clear the startup wait tracker
          _updateState(_state.copyWith(
            status: GatewayStatus.running,
            startedAt: DateTime.now(),
            logs: [..._state.logs, '[INFO] Gateway is healthy'],
          ));
          // Eagerly warm the dashboard auth token in the background so that
          // opening WebDashboardScreen feels instant (token is already cached).
          unawaited(fetchAuthenticatedDashboardUrl(force: false)
              .catchError((_) => null));
        }

        if (_pairingResolveAttempted) {
          return;
        }

        final startedAt = _state.startedAt;
        final startupAge = startedAt == null
            ? Duration.zero
            : DateTime.now().difference(startedAt);
        if (!_state.isReady && startupAge < const Duration(seconds: 20)) {
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
          final supported = _connection?.supportedMethods ?? const <String>[];
          var healthRpcSucceeded = !supported.contains('health');
          var skillsDiscoverySatisfied = !supported.contains('skills.status');

          if (supported.contains('health')) {
            try {
              final healthResult =
                  await invoke('health').timeout(const Duration(seconds: 8));
              final healthData = healthResult.containsKey('payload')
                  ? healthResult['payload']
                  : healthResult;
              if (healthData != null &&
                  (healthData['ok'] == true || healthData['health'] != null)) {
                _updateState(_state.copyWith(
                  detailedHealth: healthData,
                  logs: [
                    ..._state.logs,
                    '[INFO] Health RPC: ok=${healthData['ok'] ?? healthData['health']}'
                  ],
                ));
                healthRpcSucceeded = true;
              }
            } catch (_) {
              // Non-fatal — health RPC may not be supported on all gateways
            }
          }

          // Skills discovery via skills.status (the correct RPC — skills.list does not exist).
          // capabilities.list also does not exist; device capabilities are declared at
          // connect-time via caps/commands/permissions in the handshake params, not via RPC.
          // Guard with supportedMethods so unknown-method log noise is avoided on older
          // gateway versions and the call auto-enables when the gateway declares it.
          if (supported.contains('skills.status')) {
            try {
              final skillsResult = await invoke('skills.status')
                  .timeout(const Duration(seconds: 8));
              final skillsData = skillsResult.containsKey('payload')
                  ? skillsResult['payload']
                  : skillsResult;
              if (skillsData != null &&
                  (skillsResult['ok'] == true ||
                      skillsData is Map ||
                      skillsData is List)) {
                // skills.status returns {skills: SkillInfo[]} — each entry has
                // name, skillKey, description, eligible, disabled, etc.
                final rawList = skillsData is List
                    ? skillsData
                    : (skillsData['skills'] ?? skillsData['items'] ?? []);
                final parsedSkills = <Map<String, dynamic>>[];
                final parsedIds = <String>{};
                for (final skill in rawList as List) {
                  if (skill is Map) {
                    final mapped = Map<String, dynamic>.from(skill);
                    parsedSkills.add(mapped);
                    final id =
                        (mapped['skillKey'] ?? mapped['name'] ?? mapped['id'])
                                ?.toString()
                                .toLowerCase() ??
                            '';
                    if (id.isNotEmpty) parsedIds.add(id);
                  } else if (skill is String) {
                    parsedSkills.add({'id': skill, 'name': skill});
                    parsedIds.add(skill.toLowerCase());
                  }
                }
                _updateState(_state.copyWith(
                  activeSkills: parsedSkills,
                  logs: [
                    ..._state.logs,
                    '[INFO] Active skills: ${parsedIds.isEmpty ? 'none' : parsedIds.join(', ')}'
                  ],
                ));
                // Do not block interactive readiness on a non-empty list.
                // Empty results can be transient while sidecars finish loading.
                skillsDiscoverySatisfied = true;
              }
            } catch (_) {
              // Keep node/tool readiness from stalling if skills.status lags.
              skillsDiscoverySatisfied = true;
            }
          } else {
            // Older gateways may not expose skills.status. Do not block
            // discovery forever if the method is genuinely absent.
            skillsDiscoverySatisfied = true;
          }

          // Capabilities discovery: map the bounded Android tool policy back
          // to the primitive switches shown by the UI.
          try {
            final cfg = await _readConfig();
            if (cfg['tools'] is Map && cfg['tools']['allow'] is List) {
              final rawAllow =
                  List<dynamic>.from(cfg['tools']['allow'] as List<dynamic>);
              final toolsList = GatewayToolCatalog.normalizeAllowList(
                rawAllow,
              );
              if (toolsList.isEmpty && rawAllow.isNotEmpty) {
                // Repair drifted allowlists (e.g. old plugin-only ids) so the
                // gateway retains a known-good mobile tool policy.
                GatewayToolCatalog.applyDefaultMobilePolicy(cfg);
                await _writeConfig(cfg);
                _updateState(_state.copyWith(
                  capabilities:
                      GatewayToolCatalog.primitiveIds.toList(growable: false),
                ));
                _addActivity(
                    '[TOOLS] Repaired invalid tools.allow entries with mobile defaults.');
              } else {
                _updateState(_state.copyWith(capabilities: toolsList));
              }
            } else {
              _updateState(_state.copyWith(
                capabilities:
                    GatewayToolCatalog.primitiveIds.toList(growable: false),
              ));
            }
          } catch (_) {
            _updateState(_state.copyWith(
              capabilities:
                  GatewayToolCatalog.primitiveIds.toList(growable: false),
            ));
          }

          // Re-register device skills so the AI always has the current enabled set.
          try {
            await reregisterSkills();
          } catch (_) {}

          _rpcDiscoveryDone = healthRpcSucceeded && skillsDiscoverySatisfied;
          _updateState(_state.copyWith(
            isInteractiveReady: _rpcDiscoveryDone,
          ));
          if (_rpcDiscoveryDone) {
            _addActivity(
                '[INFO] Gateway RPC discovery complete; node auto-connect released.');
            _clearGatewayConfigTransitionIfReady();
          } else {
            _addActivity(
                '[INFO] Gateway RPC discovery still warming; retrying on next health tick.');
          }
        }

        if (_rpcDiscoveryDone) {
          unawaited(_ensureNodeConnectedAfterGatewayReady(
            reason: 'gateway-rpc-ready',
          ));
        } else {
          // Warm fallback: if WS + HTTP are already healthy, allow node reconnect
          // attempts while skills discovery catches up.
          final wsConnected =
              _connection?.state == GatewayConnectionState.connected ||
                  _state.isWebsocketConnected;
          if (_state.isReady && wsConnected && _state.detailedHealth != null) {
            unawaited(_ensureNodeConnectedAfterGatewayReady(
              reason: 'gateway-minimal-ready',
              allowDuringWarmup: true,
            ));
          }
        }
      }
    } catch (e) {
      _consecutiveFailures++;
      if (_state.status == GatewayStatus.starting) {
        // Gateway is intentionally booting — show progress, not error spam.
        // Its own health-monitor declares startup-grace: 60s, so we match that
        // before firing auto-heal. No new timer: this runs on the existing 15s tick.
        _httpWaitingSince ??= DateTime.now();
        final elapsed = DateTime.now().difference(_httpWaitingSince!).inSeconds;
        _addActivity('[INFO] Gateway starting up... (${elapsed}s)');

        final processAlive = await _runtime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
        final listenerAlive = processAlive
            ? false
            : await _isGatewayListenerAlive(
                timeout: const Duration(seconds: 2),
              );
        if (!processAlive && !listenerAlive && elapsed >= 10) {
          _rpcDiscoveryDone = false;
          _addActivity(
              '[HEALTH] Gateway startup process disappeared; restarting cleanly.');
          _updateState(_state.copyWith(
            status: GatewayStatus.stopped,
            isWebsocketConnected: false,
            isInteractiveReady: false,
          ));
          unawaited(attachOrStart(autoStart: true, forceStart: true));
          return;
        }

        if (elapsed > _startupPassiveHealGrace.inSeconds &&
            !_isAutoHealingInProgress) {
          _triggerPassiveAutoHeal();
        }
      } else if (_state.status == GatewayStatus.running) {
        final wsAlive = _connection?.state == GatewayConnectionState.connected;
        final processAlive = await _runtime
            .isRunning()
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
        final listenerAlive = processAlive
            ? false
            : await _isGatewayListenerAlive(
                timeout: const Duration(seconds: 2),
              );
        if (wsAlive && (processAlive || listenerAlive)) {
          _consecutiveFailures = 0;
          _addActivity(
              '[HEALTH] HTTP probe slow, but WebSocket/process are alive; treating gateway as busy.');
          return;
        }

        _addActivity(
            '[HEALTH] Probe failed ($_consecutiveFailures/$_healthFailureRestartThreshold): ${e.toString().split('\n').first}');
        if (_consecutiveFailures >= _healthFailureRestartThreshold &&
            !_isAutoHealingInProgress) {
          if (processAlive || listenerAlive) {
            unawaited(_restartHungGatewayAfterHealthFailures(
              reason: 'health-timeout',
              failureCount: _consecutiveFailures,
            ));
          } else {
            _triggerPassiveAutoHeal();
          }
        }
      }

      // HTTP HEAD failed — check if gateway process is still alive
      final processRunning = await _runtime.isRunning();
      final listenerRunning = processRunning
          ? false
          : await _isGatewayListenerAlive(
              timeout: const Duration(seconds: 2),
            );
      final isRunning = processRunning || listenerRunning;
      if (!isRunning && _state.status != GatewayStatus.stopped) {
        _updateState(_state.copyWith(
          status: GatewayStatus.stopped,
          isWebsocketConnected: false,
          isInteractiveReady: false,
          logs: [..._state.logs, '[WARN] Gateway process not running'],
        ));

        // SELF-HEALING: Auto-restart if dead and policy allows
        final prefs = PreferencesService();
        await prefs.init();
        if (prefs.autoStartGateway) {
          unawaited(attachOrStart(autoStart: true));
        }
      }
    } finally {
      _healthCheckInFlight = false;
    }
  }

  Future<bool> checkHealth() async {
    try {
      final token = await retrieveTokenFromConfig()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      final response = await _probeGatewayHealth(
        token: token,
        timeout: _gatewayHealthProbeTimeout,
      );
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic>? _decodeObject(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<http.Response> _probeGatewayHealth({
    String? token,
    Duration timeout = _gatewayHealthProbeTimeout,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 1)
      ..maxConnectionsPerHost = 1;
    try {
      final request = await client
          .getUrl(Uri.parse('${AppConstants.gatewayUrl}/health'))
          .timeout(timeout);
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 2), onTimeout: () => '');
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name] = values.join(',');
      });
      return http.Response(
        body,
        response.statusCode,
        headers: headers,
        request: http.Request(
          'GET',
          Uri.parse('${AppConstants.gatewayUrl}/health'),
        ),
      );
    } finally {
      // Future.timeout does not cancel the underlying socket by itself. Force
      // close so repeated failed health probes cannot accumulate loopback
      // sockets and slowly poison long idle sessions.
      client.close(force: true);
    }
  }

  Future<void> _restartHungGatewayAfterHealthFailures({
    required String reason,
    required int failureCount,
  }) async {
    if (_hungGatewayRestartInFlight || _isStarting || _isStopping) return;
    final now = DateTime.now();
    final lastRestart = _lastHungGatewayRestartAt;
    if (lastRestart != null) {
      final restartAge = now.difference(lastRestart);
      if (restartAge < _hungGatewayRestartCooldown &&
          failureCount < _hungGatewayForcedRestartFailures) {
        _addActivity('[HEALTH] Gateway still timing out, restart cooling down '
            '(${restartAge.inSeconds}s/${_hungGatewayRestartCooldown.inSeconds}s).');
        return;
      }
      if (restartAge < _hungGatewayRestartCooldown &&
          failureCount >= _hungGatewayForcedRestartFailures) {
        _addActivity('[HEALTH] Gateway remained unresponsive after '
            '$failureCount probes; overriding restart cooldown.');
      }
    }

    _hungGatewayRestartInFlight = true;
    _lastHungGatewayRestartAt = now;
    _addActivity('[HEALTH] Gateway process is alive but HTTP is unresponsive '
        '($failureCount failures, $reason). Restarting gateway cleanly...');
    try {
      await stop();
      await Future.delayed(const Duration(seconds: 2));
      await start();
      _consecutiveFailures = 0;
      _addActivity('[HEALTH] Gateway restart requested after HTTP stall.');
    } catch (e) {
      _addActivity('[HEALTH] Gateway restart after HTTP stall failed: $e');
      _updateState(_state.copyWith(
        status: GatewayStatus.error,
        errorMessage: 'Gateway restart failed after HTTP stall: $e',
      ));
    } finally {
      _hungGatewayRestartInFlight = false;
    }
  }

  Future<void> _ensureNodeConnectedAfterGatewayReady({
    required String reason,
    bool allowDuringWarmup = false,
  }) async {
    if (_nodeAutoConnectInFlight) return;
    final wsConnected =
        _connection?.state == GatewayConnectionState.connected ||
            _state.isWebsocketConnected;
    if (!wsConnected) {
      return;
    }
    if (!allowDuringWarmup &&
        (!_rpcDiscoveryDone || !_state.isInteractiveReady)) {
      return;
    }
    if (allowDuringWarmup && !_state.isReady) {
      return;
    }
    final now = DateTime.now();
    final lastAttempt = _lastNodeAutoConnectAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _nodeAutoConnectCooldown) {
      return;
    }
    _nodeAutoConnectInFlight = true;
    _lastNodeAutoConnectAttemptAt = now;
    try {
      final prefs = PreferencesService();
      await prefs.init();
      if (!prefs.nodeEnabled) return;

      final node = NodeService();
      await node.init();
      if (node.state.isConnecting) return;

      if (!(node.state.isPaired &&
          node.isConnected &&
          !node.isConnectionStale)) {
        _addActivity(
            '[NODE] Gateway ready; ensuring node is connected ($reason)');
      }
      try {
        final running = await NativeBridge.isNodeServiceRunning();
        if (!running) {
          await NativeBridge.startNodeService();
        }
      } catch (_) {
        await NativeBridge.startNodeService();
      }
      await node.connect();
    } catch (e) {
      _addActivity('[NODE] Auto-connect deferred: $e');
    } finally {
      _nodeAutoConnectInFlight = false;
    }
  }

  String _formatGatewayProviderError(String rawError, {String? model}) {
    final normalized = rawError.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return 'Gateway/provider returned an empty error payload.';
    }
    return normalized;
  }

  String _rawGatewayErrorText(Object? value,
      {String fallback = 'Unknown API error'}) {
    if (value == null) return fallback;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty || trimmed.toLowerCase() == 'null'
          ? fallback
          : trimmed;
    }
    try {
      return jsonEncode(value);
    } catch (_) {
      final text = value.toString().trim();
      return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
    }
  }

  bool _looksLikeMobileNodeToolRequest(String message) {
    final lower = message.toLowerCase();
    const toolHints = <String>[
      'tool',
      'skill',
      'phone',
      'device',
      'node',
      'android',
      'avatar',
      'gesture',
      'wave',
      'bow',
      'bowing',
      'dance',
      'spin',
      'peacesign',
      'peace sign',
      'camera',
      'photo',
      'picture',
      'selfie',
      'flashlight',
      'torch',
      'vibrate',
      'haptic',
      'sensor',
      'accelerometer',
      'gyro',
      'gyroscope',
      'location',
      'gps',
      'screen',
      'canvas',
      'notification',
      'notifications',
      'browser',
      'snapshot',
      'javascript',
      'open http',
      'open https',
    ];
    return toolHints.any(lower.contains);
  }

  Future<String?> _resolveMobileNodeHandleForToolRouting() async {
    const gatewayNodeHandle = 'OpenClaw Mobile';

    try {
      final node = NodeService();
      await node.init();
      final stateId = node.state.deviceId?.trim() ?? '';
      if (stateId.isNotEmpty) return gatewayNodeHandle;
    } catch (_) {}

    try {
      final prefs = PreferencesService();
      await prefs.init();
      final prefId = prefs.nodeIdentityDeviceId?.trim() ?? '';
      if (prefId.isNotEmpty) return gatewayNodeHandle;
    } catch (_) {}

    try {
      final pairedFile = File(
        '${await getFilesDir()}/rootfs/ubuntu/root/.openclaw/devices/paired.json',
      );
      if (!await pairedFile.exists()) return null;

      final decoded = jsonDecode(await pairedFile.readAsString());
      final nodeId = _findPairedAndroidNodeId(decoded);
      if (nodeId != null && nodeId.isNotEmpty) return gatewayNodeHandle;
    } catch (_) {}

    return null;
  }

  String? _findPairedAndroidNodeId(Object? value) {
    if (value is Map) {
      final map = value.map((key, val) => MapEntry('$key', val));

      final deviceId = (map['deviceId'] as String?)?.trim();
      final platform = (map['platform'] as String?)?.toLowerCase().trim();
      final role = (map['role'] as String?)?.toLowerCase().trim();
      final clientMode = (map['clientMode'] as String?)?.toLowerCase().trim();
      final clientId = (map['clientId'] as String?)?.toLowerCase().trim();
      final displayName = (map['displayName'] as String?)?.toLowerCase().trim();
      final roles = map['roles'];
      final hasNodeRole = role == 'node' ||
          clientMode == 'node' ||
          clientId == 'node-host' ||
          (roles is List &&
              roles.map((r) => '$r'.toLowerCase()).contains('node'));
      final isAndroidNode = platform == 'android' &&
          hasNodeRole &&
          deviceId != null &&
          deviceId.isNotEmpty;
      if (isAndroidNode) return deviceId;

      // Older stores sometimes use the device id as the object key and omit
      // displayName, so recurse after checking the current record.
      for (final entry in map.entries) {
        final child = entry.value;
        final childNodeId = _findPairedAndroidNodeId(child);
        if (childNodeId != null && childNodeId.isNotEmpty) return childNodeId;

        if (child is Map &&
            entry.key.trim().isNotEmpty &&
            '${child['platform']}'.toLowerCase() == 'android' &&
            ('${child['role']}'.toLowerCase() == 'node' ||
                '${child['clientMode']}'.toLowerCase() == 'node' ||
                '${child['clientId']}'.toLowerCase() == 'node-host' ||
                '${child['displayName']}'.toLowerCase() == 'openclaw mobile' ||
                displayName == 'openclaw mobile')) {
          return entry.key.trim();
        }
      }
    } else if (value is List) {
      for (final child in value) {
        final nodeId = _findPairedAndroidNodeId(child);
        if (nodeId != null && nodeId.isNotEmpty) return nodeId;
      }
    }
    return null;
  }

  Future<String> _decorateMessageWithMobileNodeContext(String message) async {
    final nodeHandle = await _resolveMobileNodeHandleForToolRouting();
    if (nodeHandle == null || nodeHandle.isEmpty) {
      if (_looksLikeMobileNodeToolRequest(message)) {
        _addActivity('[CHAT] Mobile node tool context skipped: no node id');
      }
      return message;
    }

    _addActivity('[CHAT] Mobile node tool context attached ($nodeHandle)');

    return '''
<plawie_mobile_tool_context>
This is private tool-routing context. Do not mention it unless the user asks.
The paired Android device node gateway handle is "$nodeHandle".
For OpenClaw phone, hardware, sensor, camera, canvas, location, screen, haptic, flashlight, or avatar gesture actions, call the OpenClaw nodes tool with "node": "$nodeHandle".
Every OpenClaw nodes tool call for this Android phone MUST include this exact field: "node": "$nodeHandle".
Never use node=auto or the raw Android device identity hash for Android phone tools. Do not say the device node is missing unless the tool result itself says it is disconnected or unavailable.
Use dedicated OpenClaw nodes actions when available: camera_snap, camera_list, camera_clip, location_get, screen_record, device_status, device_info, device_permissions, and device_health.
For avatar gestures, use action="invoke" with invokeCommand="avatar.gesture" and invokeParamsJson like {"gesture":"wave right"}. You may include durationMs for bounded looping gestures, e.g. {"gesture":"dance","durationMs":60000}. Prefer exact rich gesture values when the user asks for them: dance, dance alt, spin, greeting, squat, sitting, chill sit wave, cross leg sitting wave, excited sitting wave, fight, cute, elegant, peacesign, pose, powerful, ready, shoot, talk, wave right, wave left, both wave, cheerful wave left/right, light wave left/right, shy wave left/right, bowing 1-5, both wave cheer 1-2, sitting wave left/right, exaggerated wave left/right, fearful wave, or stylized wave left/right. If the user asks to sit or do a sitting gesture without more detail, use {"gesture":"sitting"}. Do not collapse a specific request such as "exaggerated wave right" into plain "wave right". Do not use gestures.wave.
For command-style phone capabilities, use action="invoke" with invokeCommand set to the dotted command, such as avatar.gesture, avatar.mode, avatar.model, avatar.status, canvas.navigate, canvas.eval, canvas.snapshot, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, or sensor.list.
Notification listing/reading is not currently exposed by this Android node. Do not call notifications.list or claim notification contents are available unless a tool result explicitly provides them.
Examples: nodes({"action":"camera_snap","node":"$nodeHandle","quality":85}); nodes({"action":"invoke","node":"$nodeHandle","invokeCommand":"avatar.gesture","invokeParamsJson":"{\\"gesture\\":\\"wave right\\"}"}); nodes({"action":"invoke","node":"$nodeHandle","invokeCommand":"avatar.gesture","invokeParamsJson":"{\\"gesture\\":\\"dance\\",\\"durationMs\\":60000}"}); nodes({"action":"invoke","node":"$nodeHandle","invokeCommand":"haptic.vibrate","invokeParamsJson":"{\\"durationMs\\":150}"}); nodes({"action":"invoke","node":"$nodeHandle","invokeCommand":"flash.status"}).
If a tool plan would use node=auto, replace it with node="$nodeHandle" before calling the tool.
If the user asks what tools or phone abilities are available, include these Android node tools as available when the node is connected.
</plawie_mobile_tool_context>

$message''';
  }

  String? _nativePrimaryCanaryPayload(String message, String model) {
    if (!_nativePrimaryCanaryDiagnosticsEnabled) return null;

    final trimmedLeft = message.trimLeft();
    const prefixes = <String>[
      '/native-canary ',
      '/native ',
    ];
    for (final prefix in prefixes) {
      if (trimmedLeft.toLowerCase().startsWith(prefix)) {
        return trimmedLeft.substring(prefix.length).trimLeft();
      }
    }

    if (model == 'plawie/native-node-probe') {
      return message;
    }
    return null;
  }

  String? _nativeStreamingCanaryPayload(String message) {
    if (!_nativePrimaryCanaryDiagnosticsEnabled) return null;

    final trimmedLeft = message.trimLeft();
    const prefix = '/native-stream ';
    if (trimmedLeft.toLowerCase().startsWith(prefix)) {
      return trimmedLeft.substring(prefix.length).trimLeft();
    }
    return null;
  }

  String? _nativeRoutingSkeletonPayload(String message) {
    if (!_nativePrimaryCanaryDiagnosticsEnabled) return null;

    final trimmedLeft = message.trimLeft();
    const prefix = '/native-route ';
    if (trimmedLeft.toLowerCase().startsWith(prefix)) {
      return trimmedLeft.substring(prefix.length).trimLeft();
    }
    return null;
  }

  String? _nativeProviderShellPayload(String message) {
    if (!_nativePrimaryCanaryDiagnosticsEnabled) return null;

    final trimmedLeft = message.trimLeft();
    const prefix = '/native-provider ';
    if (trimmedLeft.toLowerCase().startsWith(prefix)) {
      return trimmedLeft.substring(prefix.length).trimLeft();
    }
    return null;
  }

  String? _nativeProviderBuilderPayload(String message) {
    if (!_nativePrimaryCanaryDiagnosticsEnabled) return null;

    final trimmedLeft = message.trimLeft();
    const prefix = '/native-provider-build ';
    if (trimmedLeft.toLowerCase().startsWith(prefix)) {
      return trimmedLeft.substring(prefix.length).trimLeft();
    }
    return null;
  }

  String? _nativeTransportShimPayload(String message) {
    if (!_nativePrimaryCanaryDiagnosticsEnabled) return null;

    final trimmedLeft = message.trimLeft();
    const prefix = '/native-transport ';
    if (trimmedLeft.toLowerCase().startsWith(prefix)) {
      return trimmedLeft.substring(prefix.length).trimLeft();
    }
    return null;
  }

  String? _nativeProviderLivePayload(String message) {
    if (!_nativePrimaryCanaryDiagnosticsEnabled) return null;

    final trimmedLeft = message.trimLeft();
    const prefix = '/native-live ';
    if (trimmedLeft.toLowerCase().startsWith(prefix)) {
      return trimmedLeft.substring(prefix.length).trimLeft();
    }
    return null;
  }

  Map<String, dynamic> _nativeCanaryChatSendFrame({
    required String message,
    required String sessionKey,
    String? model,
    String? provider,
  }) {
    final params = <String, dynamic>{
      'sessionKey': sessionKey,
      'message': message,
      'idempotencyKey': const Uuid().v4(),
      'timeoutMs': 300000,
    };
    if (model != null && model.trim().isNotEmpty) {
      params['model'] = model.trim();
    }
    if (provider != null && provider.trim().isNotEmpty) {
      params['provider'] = provider.trim();
    }

    return <String, dynamic>{
      'type': 'req',
      'method': 'chat.send',
      'params': params,
      'id': const Uuid().v4(),
    };
  }

  Stream<String> _sendNativePrimaryCanaryMessage(
    String message, {
    required String model,
    String? sessionKey,
  }) async* {
    final canaryMessage = _nativePrimaryCanaryPayload(message, model);
    if (canaryMessage == null) return;
    if (canaryMessage.trim().isEmpty) {
      yield '[Error] Native canary needs a message after /native-canary.';
      return;
    }

    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    final outboundMessage =
        await _decorateMessageWithMobileNodeContext(canaryMessage);
    final chatSendFrame = _nativeCanaryChatSendFrame(
      message: outboundMessage,
      sessionKey: resolvedSessionKey,
    );

    _addActivity(
      '[NATIVE-PRIMARY-CANARY] -> Sending directly to embedded Node '
      '(routing disabled)',
    );
    final ack =
        await NativeGatewayShadowParityService.sendPrimaryCanaryChatSendFrame(
            chatSendFrame,
            log: _addActivity);
    if (ack == null) {
      yield '[Error] Native primary canary is unavailable in this build or '
          'the embedded Node parser is not running.';
      return;
    }

    final parsed = ack['parsed'] == true;
    final hashMatches = ack['hashMatches'] == true;
    final route = ack['route']?.toString() ?? 'unknown';
    final queueStatus = ack['queueStatus']?.toString() ?? 'unknown';
    final nativeSessionId = ack['nativeSessionId']?.toString() ?? 'unknown';
    final runId = ack['runId']?.toString() ?? 'unknown';
    final messageChars = ack['messageChars']?.toString() ?? 'unknown';
    final hints = ack['mobileToolHints'] is List
        ? (ack['mobileToolHints'] as List).join(', ')
        : '';

    if (parsed && hashMatches && route == 'disabled') {
      _addActivity('[NATIVE-PRIMARY-CANARY] ✓ Parsed by native dry-run');
    } else {
      _addActivity('[NATIVE-PRIMARY-CANARY] ✗ Unexpected ACK shape');
    }

    yield [
      'Native canary dry-run ACK',
      '',
      'parsed: $parsed',
      'route: $route',
      'queue: $queueStatus',
      'hashMatches: $hashMatches',
      'session: $nativeSessionId',
      'run: $runId',
      'messageChars: $messageChars',
      if (hints.isNotEmpty) 'toolHints: $hints',
      '',
      'No provider call or tool execution ran. This turn bypassed PRoot and '
          'only proved the UI-to-embedded-Node chat frame lane.',
    ].join('\n');
  }

  Stream<String> _sendNativeStreamingCanaryMessage(
    String message, {
    String? sessionKey,
  }) async* {
    final canaryMessage = _nativeStreamingCanaryPayload(message);
    if (canaryMessage == null) return;
    if (canaryMessage.trim().isEmpty) {
      yield '[Error] Native stream canary needs a message after /native-stream.';
      return;
    }

    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    final outboundMessage =
        await _decorateMessageWithMobileNodeContext(canaryMessage);
    final chatSendFrame = _nativeCanaryChatSendFrame(
      message: outboundMessage,
      sessionKey: resolvedSessionKey,
    );

    _addActivity(
      '[NATIVE-STREAM-CANARY] -> Opening embedded Node dry-run stream',
    );

    var sawAck = false;
    await for (final event
        in NativeGatewayShadowParityService.streamPrimaryCanaryChatSendFrame(
      chatSendFrame,
      log: _addActivity,
    )) {
      final eventType = event['event']?.toString();
      if (eventType == 'ack') {
        sawAck = true;
        final ack = event['ack'] is Map
            ? Map<String, dynamic>.from(event['ack'] as Map)
            : <String, dynamic>{};
        final parsed = ack['parsed'] == true;
        final hashMatches = ack['hashMatches'] == true;
        final route = ack['route']?.toString() ?? 'unknown';
        final queueStatus = ack['queueStatus']?.toString() ?? 'unknown';
        final runId = ack['runId']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-STREAM-CANARY] ✓ Stream ACK received');
        yield [
          'Native stream canary started',
          '',
          'parsed: $parsed',
          'route: $route',
          'queue: $queueStatus',
          'hashMatches: $hashMatches',
          'run: $runId',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'delta') {
        final text = event['text']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
        continue;
      }

      if (eventType == 'end') {
        _addActivity('[NATIVE-STREAM-CANARY] ✓ Stream complete');
        return;
      }

      if (eventType == 'error') {
        final raw = _rawGatewayErrorText(event['error'] ?? event);
        _addActivity('[NATIVE-STREAM-CANARY] ✗ $raw');
        yield '[Error] $raw';
        return;
      }
    }

    if (!sawAck) {
      yield '[Error] Native stream canary ended before ACK.';
    }
  }

  Stream<String> _sendNativeRoutingSkeletonMessage(
    String message, {
    String? sessionKey,
  }) async* {
    final routeMessage = _nativeRoutingSkeletonPayload(message);
    if (routeMessage == null) return;
    if (routeMessage.trim().isEmpty) {
      yield '[Error] Native routing skeleton needs a message after /native-route.';
      return;
    }

    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    final outboundMessage =
        await _decorateMessageWithMobileNodeContext(routeMessage);
    final chatSendFrame = _nativeCanaryChatSendFrame(
      message: outboundMessage,
      sessionKey: resolvedSessionKey,
    );

    _addActivity(
      '[NATIVE-ROUTE-SKELETON] -> Opening embedded Node routing skeleton',
    );

    var sawAck = false;
    await for (final event
        in NativeGatewayShadowParityService.streamRoutingSkeletonChatSendFrame(
      chatSendFrame,
      log: _addActivity,
    )) {
      final eventType = event['event']?.toString();
      if (eventType == 'ack') {
        sawAck = true;
        final ack = event['ack'] is Map
            ? Map<String, dynamic>.from(event['ack'] as Map)
            : <String, dynamic>{};
        final parsed = ack['parsed'] == true;
        final hashMatches = ack['hashMatches'] == true;
        final route = ack['route']?.toString() ?? 'unknown';
        final routeStatus = ack['routeStatus']?.toString() ?? 'unknown';
        final queueStatus = ack['queueStatus']?.toString() ?? 'unknown';
        final runId = ack['runId']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-ROUTE-SKELETON] OK ACK received');
        yield [
          'Native routing skeleton started',
          '',
          'parsed: $parsed',
          'route: $route',
          'routeStatus: $routeStatus',
          'queue: $queueStatus',
          'hashMatches: $hashMatches',
          'run: $runId',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'route_plan') {
        final plan = event['routePlan'] is Map
            ? Map<String, dynamic>.from(event['routePlan'] as Map)
            : <String, dynamic>{};
        final providerGate = plan['providerCallGate'] is Map
            ? Map<String, dynamic>.from(plan['providerCallGate'] as Map)
            : <String, dynamic>{};
        final toolGate = plan['toolExecutionGate'] is Map
            ? Map<String, dynamic>.from(plan['toolExecutionGate'] as Map)
            : <String, dynamic>{};
        final cancellation = plan['cancellation'] is Map
            ? Map<String, dynamic>.from(plan['cancellation'] as Map)
            : <String, dynamic>{};
        final routeStatus = plan['routeStatus']?.toString() ?? 'unknown';
        final providerGateStatus =
            providerGate['enabled'] == true ? 'enabled' : 'disabled';
        final toolGateStatus =
            toolGate['enabled'] == true ? 'enabled' : 'disabled';
        final cancelEndpoint =
            cancellation['endpoint']?.toString() ?? 'unavailable';
        _addActivity('[NATIVE-ROUTE-SKELETON] OK route plan received');
        yield [
          'Native route plan',
          '',
          'routeStatus: $routeStatus',
          'providerGate: $providerGateStatus',
          'toolGate: $toolGateStatus',
          'cancel: $cancelEndpoint',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'provider_gate') {
        final gate = event['gate'] is Map
            ? Map<String, dynamic>.from(event['gate'] as Map)
            : <String, dynamic>{};
        final reason = gate['reason']?.toString() ?? 'provider gate closed';
        _addActivity('[NATIVE-ROUTE-SKELETON] provider gate closed: $reason');
        continue;
      }

      if (eventType == 'tool_gate') {
        final gate = event['gate'] is Map
            ? Map<String, dynamic>.from(event['gate'] as Map)
            : <String, dynamic>{};
        final reason = gate['reason']?.toString() ?? 'tool gate closed';
        _addActivity('[NATIVE-ROUTE-SKELETON] tool gate closed: $reason');
        continue;
      }

      if (eventType == 'delta') {
        final text = event['text']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
        continue;
      }

      if (eventType == 'cancelled') {
        _addActivity('[NATIVE-ROUTE-SKELETON] cancelled');
        yield '[Cancelled] Native routing skeleton run cancelled.';
        return;
      }

      if (eventType == 'end') {
        _addActivity('[NATIVE-ROUTE-SKELETON] OK skeleton complete');
        return;
      }

      if (eventType == 'error') {
        final raw = _rawGatewayErrorText(event['error'] ?? event);
        _addActivity('[NATIVE-ROUTE-SKELETON] ERROR $raw');
        yield '[Error] $raw';
        return;
      }
    }

    if (!sawAck) {
      yield '[Error] Native routing skeleton ended before ACK.';
    }
  }

  Stream<String> _sendNativeProviderShellMessage(
    String message, {
    required String model,
    String? sessionKey,
  }) async* {
    final providerMessage = _nativeProviderShellPayload(message);
    if (providerMessage == null) return;
    if (providerMessage.trim().isEmpty) {
      yield '[Error] Native provider shell needs a message after /native-provider.';
      return;
    }

    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    final outboundMessage =
        await _decorateMessageWithMobileNodeContext(providerMessage);
    final providerHint =
        model.contains('/') ? model.split('/').first.trim() : null;
    final chatSendFrame = _nativeCanaryChatSendFrame(
      message: outboundMessage,
      sessionKey: resolvedSessionKey,
      model: model,
      provider: providerHint,
    );

    _addActivity(
      '[NATIVE-PROVIDER-SHELL] -> Opening embedded Node provider shell',
    );

    var sawAck = false;
    await for (final event
        in NativeGatewayShadowParityService.streamProviderShellChatSendFrame(
      chatSendFrame,
      log: _addActivity,
    )) {
      final eventType = event['event']?.toString();
      if (eventType == 'ack') {
        sawAck = true;
        final ack = event['ack'] is Map
            ? Map<String, dynamic>.from(event['ack'] as Map)
            : <String, dynamic>{};
        final parsed = ack['parsed'] == true;
        final hashMatches = ack['hashMatches'] == true;
        final routeStatus = ack['routeStatus']?.toString() ?? 'unknown';
        final provider = ack['provider']?.toString() ?? 'unknown';
        final requestedModel = ack['requestedModel']?.toString() ?? 'unknown';
        final transport = ack['transport']?.toString() ?? 'unknown';
        final envelopeHash = ack['envelopeHash']?.toString() ?? 'unknown';
        final runId = ack['runId']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-PROVIDER-SHELL] OK ACK received');
        yield [
          'Native provider shell started',
          '',
          'parsed: $parsed',
          'routeStatus: $routeStatus',
          'hashMatches: $hashMatches',
          'provider: $provider',
          'model: $requestedModel',
          'transport: $transport',
          'envelopeHash: $envelopeHash',
          'run: $runId',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'provider_envelope') {
        final envelope = event['envelope'] is Map
            ? Map<String, dynamic>.from(event['envelope'] as Map)
            : <String, dynamic>{};
        final provider = envelope['provider']?.toString() ?? 'unknown';
        final requestedModel =
            envelope['requestedModel']?.toString() ?? 'unknown';
        final providerModel =
            envelope['providerModel']?.toString() ?? 'unknown';
        final transport = envelope['transport']?.toString() ?? 'unknown';
        final endpoint = envelope['endpointRedacted']?.toString() ?? 'unknown';
        final outbound =
            envelope['outboundNetworkEnabled'] == true ? 'enabled' : 'disabled';
        _addActivity('[NATIVE-PROVIDER-SHELL] OK provider envelope received');
        yield [
          'Native provider envelope',
          '',
          'provider: $provider',
          'requestedModel: $requestedModel',
          'providerModel: $providerModel',
          'transport: $transport',
          'endpoint: $endpoint',
          'outboundNetwork: $outbound',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'provider_gate') {
        final gate = event['gate'] is Map
            ? Map<String, dynamic>.from(event['gate'] as Map)
            : <String, dynamic>{};
        final reason = gate['reason']?.toString() ?? 'provider gate closed';
        _addActivity('[NATIVE-PROVIDER-SHELL] provider gate closed: $reason');
        continue;
      }

      if (eventType == 'provider_error_contract') {
        final provider = event['provider']?.toString() ?? 'unknown';
        _addActivity(
          '[NATIVE-PROVIDER-SHELL] provider error contract ready: $provider',
        );
        continue;
      }

      if (eventType == 'delta') {
        final text = event['text']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
        continue;
      }

      if (eventType == 'end') {
        _addActivity('[NATIVE-PROVIDER-SHELL] OK shell complete');
        return;
      }

      if (eventType == 'error') {
        final raw = _rawGatewayErrorText(event['error'] ?? event);
        _addActivity('[NATIVE-PROVIDER-SHELL] ERROR $raw');
        yield '[Error] $raw';
        return;
      }
    }

    if (!sawAck) {
      yield '[Error] Native provider shell ended before ACK.';
    }
  }

  Stream<String> _sendNativeProviderBuilderMessage(
    String message, {
    required String model,
    String? sessionKey,
  }) async* {
    final builderMessage = _nativeProviderBuilderPayload(message);
    if (builderMessage == null) return;
    if (builderMessage.trim().isEmpty) {
      yield '[Error] Native provider builder needs a message after /native-provider-build.';
      return;
    }

    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    final outboundMessage =
        await _decorateMessageWithMobileNodeContext(builderMessage);
    final providerHint =
        model.contains('/') ? model.split('/').first.trim() : null;
    final chatSendFrame = _nativeCanaryChatSendFrame(
      message: outboundMessage,
      sessionKey: resolvedSessionKey,
      model: model,
      provider: providerHint,
    );

    _addActivity(
      '[NATIVE-PROVIDER-BUILDER] -> Opening embedded Node provider request builder',
    );

    var sawAck = false;
    await for (final event in NativeGatewayShadowParityService
        .streamProviderRequestBuilderChatSendFrame(
      chatSendFrame,
      log: _addActivity,
    )) {
      final eventType = event['event']?.toString();
      if (eventType == 'ack') {
        sawAck = true;
        final ack = event['ack'] is Map
            ? Map<String, dynamic>.from(event['ack'] as Map)
            : <String, dynamic>{};
        final parsed = ack['parsed'] == true;
        final hashMatches = ack['hashMatches'] == true;
        final routeStatus = ack['routeStatus']?.toString() ?? 'unknown';
        final provider = ack['provider']?.toString() ?? 'unknown';
        final requestedModel = ack['requestedModel']?.toString() ?? 'unknown';
        final transport = ack['transport']?.toString() ?? 'unknown';
        final headersHash = ack['headersHash']?.toString() ?? 'unknown';
        final bodyHash = ack['bodyHash']?.toString() ?? 'unknown';
        final requestHash = ack['requestHash']?.toString() ?? 'unknown';
        final validationOk = ack['validationOk'] == true;
        final runId = ack['runId']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-PROVIDER-BUILDER] OK ACK received');
        yield [
          'Native provider request builder started',
          '',
          'parsed: $parsed',
          'routeStatus: $routeStatus',
          'hashMatches: $hashMatches',
          'provider: $provider',
          'model: $requestedModel',
          'transport: $transport',
          'headersHash: $headersHash',
          'bodyHash: $bodyHash',
          'requestHash: $requestHash',
          'validationOk: $validationOk',
          'run: $runId',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'provider_request') {
        final builder = event['requestBuilder'] is Map
            ? Map<String, dynamic>.from(event['requestBuilder'] as Map)
            : <String, dynamic>{};
        final provider = builder['provider']?.toString() ?? 'unknown';
        final providerModel = builder['providerModel']?.toString() ?? 'unknown';
        final endpoint = builder['endpointRedacted']?.toString() ?? 'unknown';
        final stopBefore = builder['stopBefore']?.toString() ?? 'unknown';
        final transportInvocation =
            builder['transportInvocationEnabled'] == true
                ? 'enabled'
                : 'disabled';
        _addActivity('[NATIVE-PROVIDER-BUILDER] OK request builder received');
        yield [
          'Native normalized provider request',
          '',
          'provider: $provider',
          'providerModel: $providerModel',
          'endpoint: $endpoint',
          'transportInvocation: $transportInvocation',
          'stopBefore: $stopBefore',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'request_validation') {
        final validationOk = event['validationOk'] == true;
        final configStatus = event['providerConfigStatus'] is Map
            ? Map<String, dynamic>.from(event['providerConfigStatus'] as Map)
            : <String, dynamic>{};
        final mode = configStatus['mode']?.toString() ?? 'unknown';
        final apiKeyLoaded = configStatus['apiKeyLoaded'] == true;
        _addActivity(
          '[NATIVE-PROVIDER-BUILDER] validation received: $validationOk',
        );
        yield [
          'Native request validation',
          '',
          'validationOk: $validationOk',
          'configMode: $mode',
          'apiKeyLoaded: $apiKeyLoaded',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'transport_gate') {
        final gate = event['gate'] is Map
            ? Map<String, dynamic>.from(event['gate'] as Map)
            : <String, dynamic>{};
        final reason = gate['reason']?.toString() ?? 'transport gate closed';
        _addActivity(
            '[NATIVE-PROVIDER-BUILDER] transport gate closed: $reason');
        continue;
      }

      if (eventType == 'provider_error_contract') {
        final provider = event['provider']?.toString() ?? 'unknown';
        _addActivity(
          '[NATIVE-PROVIDER-BUILDER] provider error contract ready: $provider',
        );
        continue;
      }

      if (eventType == 'delta') {
        final text = event['text']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
        continue;
      }

      if (eventType == 'end') {
        _addActivity('[NATIVE-PROVIDER-BUILDER] OK builder complete');
        return;
      }

      if (eventType == 'error') {
        final raw = _rawGatewayErrorText(event['error'] ?? event);
        _addActivity('[NATIVE-PROVIDER-BUILDER] ERROR $raw');
        yield '[Error] $raw';
        return;
      }
    }

    if (!sawAck) {
      yield '[Error] Native provider request builder ended before ACK.';
    }
  }

  Stream<String> _sendNativeTransportShimMessage(
    String message, {
    required String model,
    String? sessionKey,
  }) async* {
    final shimMessage = _nativeTransportShimPayload(message);
    if (shimMessage == null) return;
    if (shimMessage.trim().isEmpty) {
      yield '[Error] Native transport shim needs a message after /native-transport.';
      return;
    }

    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    final outboundMessage = await _decorateMessageWithMobileNodeContext(
      shimMessage,
    );
    final providerHint =
        model.contains('/') ? model.split('/').first.trim() : null;
    final chatSendFrame = _nativeCanaryChatSendFrame(
      message: outboundMessage,
      sessionKey: resolvedSessionKey,
      model: model,
      provider: providerHint,
    );

    _addActivity(
      '[NATIVE-TRANSPORT-SHIM] -> Opening embedded Node transport shim',
    );

    var sawAck = false;
    await for (final event in NativeGatewayShadowParityService
        .streamProviderTransportShimChatSendFrame(
      chatSendFrame,
      log: _addActivity,
    )) {
      final eventType = event['event']?.toString();
      if (eventType == 'ack') {
        sawAck = true;
        final ack = event['ack'] is Map
            ? Map<String, dynamic>.from(event['ack'] as Map)
            : <String, dynamic>{};
        final parsed = ack['parsed'] == true;
        final hashMatches = ack['hashMatches'] == true;
        final routeStatus = ack['routeStatus']?.toString() ?? 'unknown';
        final provider = ack['provider']?.toString() ?? 'unknown';
        final requestedModel = ack['requestedModel']?.toString() ?? 'unknown';
        final transport = ack['transport']?.toString() ?? 'unknown';
        final requestHash = ack['requestHash']?.toString() ?? 'unknown';
        final transportHash = ack['transportHash']?.toString() ?? 'unknown';
        final abortStage = ack['abortStage']?.toString() ?? 'unknown';
        final validationOk = ack['validationOk'] == true;
        final socketOpened = ack['socketOpened'] == true;
        final bytesWritten = ack['requestBytesWritten']?.toString() ?? '0';
        final billingSurface = ack['providerBillingSurfaceReached'] == true;
        final runId = ack['runId']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-TRANSPORT-SHIM] OK ACK received');
        yield [
          'Native transport shim started',
          '',
          'parsed: $parsed',
          'routeStatus: $routeStatus',
          'hashMatches: $hashMatches',
          'provider: $provider',
          'model: $requestedModel',
          'transport: $transport',
          'requestHash: $requestHash',
          'transportHash: $transportHash',
          'validationOk: $validationOk',
          'abortStage: $abortStage',
          'socketOpened: $socketOpened',
          'bytesWritten: $bytesWritten',
          'billingSurface: $billingSurface',
          'run: $runId',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'transport_shim') {
        final shim = event['transportShim'] is Map
            ? Map<String, dynamic>.from(event['transportShim'] as Map)
            : <String, dynamic>{};
        final provider = shim['provider']?.toString() ?? 'unknown';
        final transport = shim['transport']?.toString() ?? 'unknown';
        final stopBefore = shim['stopBefore']?.toString() ?? 'unknown';
        final transportHash = shim['transportHash']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-TRANSPORT-SHIM] OK shim received');
        yield [
          'Native transport object',
          '',
          'provider: $provider',
          'transport: $transport',
          'transportHash: $transportHash',
          'stopBefore: $stopBefore',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'abort_contract') {
        final abort = event['abortContract'] is Map
            ? Map<String, dynamic>.from(event['abortContract'] as Map)
            : <String, dynamic>{};
        final probe = event['networkProbe'] is Map
            ? Map<String, dynamic>.from(event['networkProbe'] as Map)
            : <String, dynamic>{};
        final abortedLocally = abort['abortedLocally'] == true;
        final abortStage = abort['abortStage']?.toString() ?? 'unknown';
        final socketOpened = probe['socketOpened'] == true;
        final requestBytesWritten =
            probe['requestBytesWritten']?.toString() ?? '0';
        final billingSurface = probe['providerBillingSurfaceReached'] == true;
        _addActivity(
          '[NATIVE-TRANSPORT-SHIM] abort contract received: $abortStage',
        );
        yield [
          'Native transport abort',
          '',
          'abortedLocally: $abortedLocally',
          'abortStage: $abortStage',
          'socketOpened: $socketOpened',
          'bytesWritten: $requestBytesWritten',
          'billingSurface: $billingSurface',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'transport_gate') {
        final gate = event['gate'] is Map
            ? Map<String, dynamic>.from(event['gate'] as Map)
            : <String, dynamic>{};
        final reason = gate['reason']?.toString() ?? 'transport gate closed';
        _addActivity('[NATIVE-TRANSPORT-SHIM] gate closed: $reason');
        continue;
      }

      if (eventType == 'shim_validation') {
        final validationOk = event['validationOk'] == true;
        _addActivity(
          '[NATIVE-TRANSPORT-SHIM] validation received: $validationOk',
        );
        continue;
      }

      if (eventType == 'delta') {
        final text = event['text']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
        continue;
      }

      if (eventType == 'end') {
        _addActivity('[NATIVE-TRANSPORT-SHIM] OK shim complete');
        return;
      }

      if (eventType == 'error') {
        final raw = _rawGatewayErrorText(event['error'] ?? event);
        _addActivity('[NATIVE-TRANSPORT-SHIM] ERROR $raw');
        yield '[Error] $raw';
        return;
      }
    }

    if (!sawAck) {
      yield '[Error] Native transport shim ended before ACK.';
    }
  }

  Stream<String> _sendNativeProviderLiveMessage(
    String message, {
    required String model,
    String? sessionKey,
  }) async* {
    final liveMessage = _nativeProviderLivePayload(message);
    if (liveMessage == null) return;
    if (liveMessage.trim().isEmpty) {
      yield '[Error] Native provider live canary needs a message after /native-live.';
      return;
    }

    final route = await _resolveFastCloudRoute(model);
    if (route == null || route.provider != 'openrouter') {
      yield '[Error] Native provider live canary currently supports only '
          'OpenRouter models with a configured API key.';
      return;
    }

    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    final providerModel = route.model.trim();
    final canaryProviderModel = providerModel == 'openrouter/auto'
        ? ModelProviderCatalog.defaultCloudFallbackModel
            .substring('${route.provider}/'.length)
        : providerModel;
    final requestedModel = canaryProviderModel.startsWith('${route.provider}/')
        ? canaryProviderModel
        : '${route.provider}/$canaryProviderModel';
    final chatSendFrame = _nativeCanaryChatSendFrame(
      message: liveMessage.trim(),
      sessionKey: resolvedSessionKey,
      model: requestedModel,
      provider: route.provider,
    );
    final providerConfig = <String, dynamic>{
      'provider': route.provider,
      'apiKey': route.apiKey,
      'endpoint': route.url,
      'model': canaryProviderModel,
      'maxTokens': 32,
      'timeoutMs': 45000,
      'referer': 'https://github.com/vmbbz/plawie',
      'title': 'Plawie Native Canary',
    };

    _addActivity(
      '[NATIVE-PROVIDER-LIVE] -> Opening embedded Node provider live canary',
    );

    var sawAck = false;
    await for (final event in NativeGatewayShadowParityService
        .streamProviderLiveCanaryChatSendFrame(
      chatSendFrame,
      providerConfig: providerConfig,
      log: _addActivity,
    )) {
      final eventType = event['event']?.toString();
      if (eventType == 'ack') {
        sawAck = true;
        final ack = event['ack'] is Map
            ? Map<String, dynamic>.from(event['ack'] as Map)
            : <String, dynamic>{};
        final parsed = ack['parsed'] == true;
        final hashMatches = ack['hashMatches'] == true;
        final routeStatus = ack['routeStatus']?.toString() ?? 'unknown';
        final provider = ack['provider']?.toString() ?? 'unknown';
        final providerModel = ack['providerModel']?.toString() ?? 'unknown';
        final requestHash = ack['requestHash']?.toString() ?? 'unknown';
        final validationOk = ack['validationOk'] == true;
        final maxTokens = ack['maxTokens']?.toString() ?? 'unknown';
        final bodyBytes = ack['requestBodyBytes']?.toString() ?? 'unknown';
        final runId = ack['runId']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-PROVIDER-LIVE] OK ACK received');
        yield [
          'Native provider live canary started',
          '',
          'parsed: $parsed',
          'routeStatus: $routeStatus',
          'hashMatches: $hashMatches',
          'provider: $provider',
          'providerModel: $providerModel',
          'requestHash: $requestHash',
          'validationOk: $validationOk',
          'maxTokens: $maxTokens',
          'bodyBytes: $bodyBytes',
          'run: $runId',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'provider_request') {
        final providerRequest = event['providerRequest'] is Map
            ? Map<String, dynamic>.from(event['providerRequest'] as Map)
            : <String, dynamic>{};
        final provider = providerRequest['provider']?.toString() ?? 'unknown';
        final providerModel =
            providerRequest['providerModel']?.toString() ?? 'unknown';
        final requestHash =
            providerRequest['requestHash']?.toString() ?? 'unknown';
        final maxTokens = providerRequest['maxTokens']?.toString() ?? 'unknown';
        final promptChars =
            providerRequest['promptChars']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-PROVIDER-LIVE] OK request received');
        yield [
          'Native live provider request',
          '',
          'provider: $provider',
          'providerModel: $providerModel',
          'requestHash: $requestHash',
          'maxTokens: $maxTokens',
          'promptChars: $promptChars',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'provider_gate') {
        final gate = event['gate'] is Map
            ? Map<String, dynamic>.from(event['gate'] as Map)
            : <String, dynamic>{};
        final reason = gate['reason']?.toString() ?? 'provider gate closed';
        _addActivity('[NATIVE-PROVIDER-LIVE] gate closed: $reason');
        continue;
      }

      if (eventType == 'provider_call_started') {
        final bytes = event['requestBodyBytes']?.toString() ?? 'unknown';
        _addActivity(
          '[NATIVE-PROVIDER-LIVE] provider call started, bodyBytes=$bytes',
        );
        yield [
          'Native provider call started',
          '',
          'bodyBytes: $bytes',
          'billingSurface: ${event['providerBillingSurfaceReached'] == true}',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'provider_response') {
        final statusCode = event['statusCode']?.toString() ?? 'unknown';
        final firstByteMs = event['firstByteMs']?.toString() ?? 'unknown';
        _addActivity('[NATIVE-PROVIDER-LIVE] provider response $statusCode');
        yield [
          'Native provider response',
          '',
          'statusCode: $statusCode',
          'firstByteMs: $firstByteMs',
          '',
        ].join('\n');
        continue;
      }

      if (eventType == 'delta') {
        final text = event['text']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
        continue;
      }

      if (eventType == 'provider_error') {
        final raw = _rawGatewayErrorText(
          event['rawProviderError'] ?? event['error'] ?? event,
        );
        _addActivity('[NATIVE-PROVIDER-LIVE] ERROR $raw');
        yield '[Error] $raw';
        return;
      }

      if (eventType == 'provider_parse_warning') {
        final raw = _rawGatewayErrorText(event['warning'] ?? event);
        _addActivity('[NATIVE-PROVIDER-LIVE] parse warning $raw');
        continue;
      }

      if (eventType == 'end') {
        final ok = event['ok'] == true;
        final finishReason = event['finishReason']?.toString() ?? 'unknown';
        final firstTokenMs = event['firstTokenMs']?.toString() ?? 'none';
        final durationMs = event['durationMs']?.toString() ?? 'unknown';
        final textChars = event['textChars']?.toString() ?? '0';
        _addActivity(
          '[NATIVE-PROVIDER-LIVE] ${ok ? 'OK' : 'ERROR'} complete: $finishReason',
        );
        if (ok) {
          yield [
            '',
            'Native provider live canary complete',
            '',
            'finishReason: $finishReason',
            'firstTokenMs: $firstTokenMs',
            'durationMs: $durationMs',
            'textChars: $textChars',
          ].join('\n');
        }
        return;
      }

      if (eventType == 'error') {
        final raw = _rawGatewayErrorText(event['error'] ?? event);
        _addActivity('[NATIVE-PROVIDER-LIVE] ERROR $raw');
        yield '[Error] $raw';
        return;
      }
    }

    if (!sawAck) {
      yield '[Error] Native provider live canary ended before ACK.';
    }
  }

  /// Route a chat message to the correct backend based on model prefix.
  ///
  /// • local model routes → fllama NDK (on-device inference, no network, no gateway)
  /// • cloud/provider models → gateway chat.send (tool-capable lane)
  /// • tool/agent cloud → WS chat.send → gateway agent loop
  Stream<String> sendMessage(
    String message, {
    String? model,
    List<Map<String, dynamic>>? conversationHistory,
    String? sessionKey,
  }) async* {
    model = await _resolveModel(model);

    if (_nativeProviderLivePayload(message) != null) {
      yield* _sendNativeProviderLiveMessage(
        message,
        model: model,
        sessionKey: sessionKey,
      );
      return;
    }

    if (_nativeTransportShimPayload(message) != null) {
      yield* _sendNativeTransportShimMessage(
        message,
        model: model,
        sessionKey: sessionKey,
      );
      return;
    }

    if (_nativeProviderBuilderPayload(message) != null) {
      yield* _sendNativeProviderBuilderMessage(
        message,
        model: model,
        sessionKey: sessionKey,
      );
      return;
    }

    if (_nativeProviderShellPayload(message) != null) {
      yield* _sendNativeProviderShellMessage(
        message,
        model: model,
        sessionKey: sessionKey,
      );
      return;
    }

    if (_nativeRoutingSkeletonPayload(message) != null) {
      yield* _sendNativeRoutingSkeletonMessage(
        message,
        sessionKey: sessionKey,
      );
      return;
    }

    if (_nativeStreamingCanaryPayload(message) != null) {
      yield* _sendNativeStreamingCanaryMessage(
        message,
        sessionKey: sessionKey,
      );
      return;
    }

    if (_nativePrimaryCanaryPayload(message, model) != null) {
      yield* _sendNativePrimaryCanaryMessage(
        message,
        model: model,
        sessionKey: sessionKey,
      );
      return;
    }

    // Local-llm: bypass the gateway entirely. Do this before token lookup,
    // autostart, WS setup, or provider sync so NDK mode stays lightweight and
    // cannot accidentally trigger OpenClaw plugin hooks while the phone is
    // already doing local inference.
    if (ModelProviderCatalog.isDirectLocalModelId(model)) {
      yield* LocalLlmService().chat(conversationHistory ?? [], message);
      return;
    }

    // Default behavior: keep cloud traffic on the gateway lane so tool/skill
    // execution is always available and diagnostics stay consistent.
    // A manual fast lane is still possible via the "/fast " prefix.
    if (_shouldUseFastCloudChat(message, model)) {
      final route = await _resolveFastCloudRoute(model);
      if (route != null) {
        yield* _sendFastCloudMessage(
          route: route,
          message: message,
          conversationHistory: conversationHistory,
        );
        return;
      }
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
      // Auto-start: try starting the gateway if it's not running.
      _addActivity('[CHAT] No gateway token — attempting auto-start...');
      try {
        await start();
        // Wait for gateway to stabilize
        await Future.delayed(const Duration(seconds: 5));
        token = await retrieveTokenFromConfig();
      } catch (_) {}
    }

    if (token == null || token.isEmpty) {
      yield '[Error] Gateway is not running.\n\n'
          'The Agent Hub (gateway) needs to be started before you can chat.\n\n'
          '**Start the Gateway from Home or run setup repair**, '
          'then try again.';
      return;
    }

    token = await _waitForGatewayChatLaneReady(token);
    if (token == null || token.isEmpty) {
      yield '[Error] Gateway is applying provider/model changes.\n\n'
          'Please wait a moment and send again. Your message was not sent '
          'into the Gateway while it was reloading.';
      return;
    }

    // Cloud/provider models must use WS chat.send -> gateway. That is the
    // only lane that carries OpenClaw session/tool/node context correctly.
    var wsOk = await _ensureWebSocket(token);
    Map<String, dynamic> modelSyncChanges = <String, dynamic>{};
    if (wsOk) {
      // HOT-SWITCHING: If user changed model, update gateway config
      final changes = await _syncModelToConfig(model);
      if (changes.isNotEmpty) {
        _addActivity('[CHAT] Updating gateway config: $changes');
        modelSyncChanges = changes;
      }
    } else {
      _addActivity('[CHAT] WebSocket unavailable; repairing gateway lane...');
      try {
        await attachOrStart(autoStart: true, forceStart: false);
        await Future.delayed(const Duration(milliseconds: 750));
        wsOk = await _ensureWebSocket(token);
      } catch (_) {
        wsOk = false;
      }
      if (!wsOk) {
        yield '[Error] Gateway WebSocket is still connecting.\n\n'
            'Please wait a moment and try again. Plawie did not use the '
            'fallback HTTP chat route because it bypasses OpenClaw tools and '
            'mobile node context.';
        return;
      }

      final changes = await _syncModelToConfig(model);
      if (changes.isNotEmpty) {
        _addActivity(
            '[CHAT] Updating gateway config after WS repair: $changes');
        modelSyncChanges = changes;
      }
      _addActivity('[CHAT] WebSocket lane repaired; continuing.');
    }

    // Session routing priority:
    // 1) explicit sessionKey from caller (per-chat session binding)
    // 2) agent/<id> model route
    // 3) isolated mobile default (never agent:main:main)
    final requestedSessionKey =
        (sessionKey != null && sessionKey.trim().isNotEmpty)
            ? sessionKey.trim()
            : model.startsWith('agent/')
                ? model.substring(6)
                : 'main';
    final resolvedSessionKey =
        _normalizeMobileChatSessionKey(requestedSessionKey);
    if (resolvedSessionKey != requestedSessionKey) {
      _addActivity('[SESS] normalized mobile chat session: '
          '$requestedSessionKey -> $resolvedSessionKey');
    }

    if (modelSyncChanges.isNotEmpty) {
      await _patchActiveGatewaySessionModel(
        modelSyncChanges,
        sessionKey: resolvedSessionKey,
      );
      token = await _waitForGatewayChatLaneReady(token);
      if (token == null || token.isEmpty) {
        yield '[Error] Gateway is applying the selected model/provider.\n\n'
            'Please retry in a moment. Your message was not sent during the '
            'Gateway reload window.';
        return;
      }
      wsOk = await _ensureWebSocket(token);
      if (!wsOk) {
        yield '[Error] Gateway WebSocket is reconnecting after the model/provider update.\n\n'
            'Please retry in a moment. Your message was not sent during the '
            'Gateway reload window.';
        return;
      }
    }

    _addActivity(
        '[SESS] gateway main=${_connection?.mainSessionKey ?? 'pending'}; '
        'chat=$resolvedSessionKey');
    _addActivity('[CHAT] → Sending to $model');

    const timeoutMs = 300000;
    const noFirstTokenTimeout = Duration(seconds: 90);
    const relevantInactivityTimeout = Duration(minutes: 3);
    final requestId = const Uuid().v4();
    final chunkController = StreamController<String>();
    final requestStartedAt = DateTime.now();
    var lastRelevantGatewayActivityAt = requestStartedAt;
    Timer? inactivityWatchdog;

    void markRelevantGatewayActivity() {
      lastRelevantGatewayActivityAt = DateTime.now();
    }

    void finishChatWithError(String message) {
      if (chunkController.isClosed) return;
      chunkController.add('[Error] $message');
      chunkController.close();
    }

    final outboundMessage =
        await _decorateMessageWithMobileNodeContext(message);

    final chatSendFrame = <String, dynamic>{
      'type': 'req',
      'method': 'chat.send',
      'params': {
        'sessionKey': resolvedSessionKey,
        'message': outboundMessage,
        'idempotencyKey': const Uuid().v4(),
        'timeoutMs': timeoutMs,
      },
      'id': requestId,
    };

    unawaited(NativeGatewayShadowParityService.observeChatSendFrame(
      chatSendFrame,
      log: _addActivity,
    ));

    unawaited(NativeGatewayShadowParityService.sendDirectCanaryChatSendFrame(
      chatSendFrame,
      log: _addActivity,
    ));

    final responseStream = _connection!.sendRequest(chatSendFrame);

    bool firstToken = true;
    // activeRunId: initially from chat.send ACK, then corrected to the actual
    // run ID seen in event agent phase=start (queued messages get a different runId).
    String? activeRunId;
    // runStarted: gates event chat state=final so a stale final from a prior run
    // (which may complete after our Flutter timeout) cannot close the next request's
    // stream before any content arrives.
    bool runStarted = false;
    var assistantSnapshot = '';
    bool isActiveRunFrame(String? agentRun) {
      return activeRunId == null || agentRun == null || agentRun == activeRunId;
    }

    String assistantDelta(String text) {
      if (text.isEmpty) return '';
      if (assistantSnapshot.isEmpty) {
        assistantSnapshot = text;
        return text;
      }
      if (text == assistantSnapshot || assistantSnapshot.endsWith(text)) {
        return '';
      }
      if (text.startsWith(assistantSnapshot)) {
        final delta = text.substring(assistantSnapshot.length);
        assistantSnapshot = text;
        return delta;
      }

      // Some gateway/model transports stream true deltas instead of snapshots.
      // Preserve those while still de-duping the cumulative OpenClaw stream.
      assistantSnapshot += text;
      return text;
    }

    inactivityWatchdog = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (chunkController.isClosed) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final idleFor = now.difference(lastRelevantGatewayActivityAt);
      if (firstToken && idleFor > noFirstTokenTimeout) {
        _addActivity('[CHAT] ✗ No assistant response for '
            '${noFirstTokenTimeout.inSeconds}s');
        _beginGatewayConfigTransition(
          'chat no-first-token recovery',
          minimumSettle: _gatewayStaleChatRecoverySettle,
        );
        disconnectWebSocket();
        finishChatWithError(
          'Gateway accepted the turn but produced no assistant response after '
          '${noFirstTokenTimeout.inSeconds} seconds. Plawie is holding the '
          'Gateway chat lane while it recovers, so retries do not enter a '
          'stale queue. Please resend after the Gateway settles.',
        );
        timer.cancel();
        return;
      }
      if (idleFor <= relevantInactivityTimeout) return;
      _addActivity('[CHAT] ✗ No relevant gateway chat activity for '
          '${relevantInactivityTimeout.inSeconds}s');
      finishChatWithError(
        'Gateway chat timed out after '
        '${relevantInactivityTimeout.inSeconds} seconds with no relevant chat '
        'activity. Retry or switch provider/model.',
      );
      timer.cancel();
    });

    late StreamSubscription frameSub;
    frameSub = responseStream.listen(
      (frame) {
        try {
          final type = frame['type'] as String?;

          // Gateway-level error (e.g. rate limit, provider failure)
          if (type == 'error') {
            markRelevantGatewayActivity();
            final payload = frame['payload'] as Map<String, dynamic>?;
            final rawMsg = _rawGatewayErrorText(
              payload?['message'] ?? payload ?? frame,
              fallback: 'API Error encountered',
            );
            final errMsg = _formatGatewayProviderError(rawMsg, model: model);
            _addActivity('[CHAT] ✗ $errMsg');
            finishChatWithError(errMsg);
            return;
          }

          // Any frame carrying a root-level 'error' field
          if (frame.containsKey('error') && frame['error'] != null) {
            final errObj = frame['error'];
            final errStr = _rawGatewayErrorText(errObj);
            if (errStr.toLowerCase().contains('rate limit') ||
                errStr.toLowerCase().contains('api') ||
                errStr.toLowerCase().contains('invalid') ||
                errStr.toLowerCase().contains('billing') ||
                errStr.toLowerCase().contains('credit') ||
                errStr.toLowerCase().contains('insufficient balance') ||
                errStr.toLowerCase().contains('balance exhausted')) {
              markRelevantGatewayActivity();
              final errMsg = _formatGatewayProviderError(errStr, model: model);
              _addActivity('[CHAT] ✗ $errMsg');
              finishChatWithError(errMsg);
              return;
            }
          }

          // ACK from chat.send — ok:true means streaming started; ok:false means rejected
          if (type == 'res' && frame['id'] == requestId) {
            markRelevantGatewayActivity();
            final ok = frame['ok'] as bool? ?? false;
            if (!ok) {
              final error = frame['error'] as Map<String, dynamic>?;
              final msg = _formatGatewayProviderError(
                _rawGatewayErrorText(error?['message'] ?? error,
                    fallback: 'chat.send failed'),
                model: model,
              );
              _addActivity('[CHAT] ✗ $msg');
              finishChatWithError(msg);
            } else {
              activeRunId = frame['runId'] as String?;
              _addActivity('[CHAT] ← Gateway accepted (streaming...)');
            }
            return;
          }

          // AGENT-INITIATED MESSAGES — added in commit 6fa6200.
          // The OpenClaw gateway can push {type:'event', event:'agent.message',
          // payload:{text:'…'}} frames when an agent proactively sends a message
          // (e.g. reminders, follow-up questions, alerts triggered by a skill).
          // We route these through the same chunkController as user-initiated replies
          // so the chat UI handles them identically — no special path needed.
          // NOTE: This requires gateway support for 'agent.message' events.
          // If your gateway version doesn't emit them, this block is a no-op.
          if (type == 'event' && frame['event'] == 'agent.message') {
            final payload = frame['payload'] as Map<String, dynamic>?;
            final message = payload?['text'] as String?;
            if (message != null && message.isNotEmpty) {
              markRelevantGatewayActivity();
              _addActivity('[CHAT] ← Agent initiated: $message');
              if (!chunkController.isClosed) {
                chunkController.add(message);
              }
            }
            return;
          }

          // Chat lifecycle events (final / aborted / error → close stream)
          if (type == 'event' && frame['event'] == 'chat') {
            final Map<String, dynamic> data =
                (frame['payload'] as Map<String, dynamic>?) ??
                    (frame['data'] as Map<String, dynamic>?) ??
                    frame;
            final state = data['state'] as String?;
            // Guard: only close on final/aborted once our agent run has started.
            // event chat frames don't carry a run ID, so we use runStarted (set from
            // event agent phase=start) as the signal that this session event is ours.
            // Without this, a stale chat=final from run N closing after our 240s Flutter
            // timeout would silently close run N+1's stream before content arrives.
            if ((state == 'final' || state == 'aborted' || state == 'error') &&
                (runStarted || !firstToken)) {
              markRelevantGatewayActivity();
              if (!chunkController.isClosed) {
                chunkController.close();
              }
            } else if ((state == 'aborted' || state == 'error') &&
                firstToken &&
                !runStarted) {
              markRelevantGatewayActivity();
              final rawError = _rawGatewayErrorText(
                data['error'] ?? data['reason'] ?? data['message'] ?? state,
              );
              final msg = _formatGatewayProviderError(rawError, model: model);
              _addActivity('[CHAT] ✗ $msg');
              finishChatWithError(msg);
            }
          }

          // Agent events — streaming text deltas and lifecycle
          if (type == 'event' && frame['event'] == 'agent') {
            final payload = frame['payload'] as Map<String, dynamic>?;
            final agentRun =
                frame['run'] as String? ?? payload?['run'] as String?;
            final innerData = payload?['data'] as Map<String, dynamic>? ??
                frame['data'] as Map<String, dynamic>?;
            final stream = (payload?['stream'] ?? frame['stream']) as String?;

            if (stream == 'assistant') {
              // Filter text from runs other than ours (activeRunId updated from phase=start)
              if (!isActiveRunFrame(agentRun)) {
                return;
              }
              final text = (innerData?['text'] ??
                  payload?['text'] ??
                  frame['text']) as String?;
              if (text != null && text.isNotEmpty) {
                markRelevantGatewayActivity();
                final delta = assistantDelta(text);
                if (delta.isEmpty) return;
                if (firstToken) {
                  firstToken = false;
                  _addActivity('[CHAT] ✓ First token received');
                }
                chunkController.add(delta);
              }
            } else if (stream == 'tool_use') {
              if (!isActiveRunFrame(agentRun)) {
                return;
              }
              markRelevantGatewayActivity();
              assistantSnapshot =
                  ''; // Reset snapshot on tool use so next assistant turn gets correctly de-duplicated
              final name = (innerData?['name'] ??
                      payload?['name'] ??
                      frame['name']) as String? ??
                  '';
              final input = innerData?['input'] ?? payload?['input'];
              if (name.isNotEmpty && !chunkController.isClosed) {
                chunkController
                    .add('\x00TOOL_USE:$name:${jsonEncode(input ?? {})}\x00');
              }
            } else if (stream == 'tool_result') {
              if (!isActiveRunFrame(agentRun)) {
                return;
              }
              markRelevantGatewayActivity();
              assistantSnapshot =
                  ''; // Reset snapshot on tool result so next assistant turn gets correctly de-duplicated
              final name = (innerData?['name'] ??
                      payload?['name'] ??
                      frame['name']) as String? ??
                  'tool';
              final result = innerData?['result'] ??
                  payload?['result'] ??
                  innerData?['output'] ??
                  payload?['output'];

              // Gateway TTS: intercept tts tool results that contain a MEDIA: path.
              // The gateway sherpa-onnx-tts skill returns a plain string like:
              //   "MEDIA:/tmp/openclaw/tts-xxxxx/voice-xxxxxxxxxx.mp3"
              // Convert to an HTTP URL served by the gateway's media endpoint.
              if (name == 'tts') {
                final mediaStr =
                    result is String ? result : result?.toString() ?? '';
                _addActivity('[TTS] gateway audio result: $mediaStr');
                if (mediaStr.startsWith('MEDIA:')) {
                  final relativePath =
                      mediaStr.substring('MEDIA:/tmp/openclaw/'.length);
                  final audioUrl =
                      'http://${AppConstants.gatewayHost}:${AppConstants.gatewayPort}/__openclaw__/media/$relativePath';
                  _addActivity('[TTS] serving audio at $audioUrl');

                  // Primary: route through unified TtsService facade
                  TtsService().speakUrl(audioUrl);

                  // Optional: trigger UI callback if any
                  onGatewayTtsAudio?.call(audioUrl);
                  // Don't forward tts tool result to the chat stream — it's audio, not display text.
                  return;
                }
              }

              if (!chunkController.isClosed) {
                chunkController.add(
                    '\x00TOOL_RESULT:$name:${jsonEncode(result ?? {})}\x00');
              }
            } else if (stream == 'lifecycle') {
              final phase = (innerData?['phase'] ??
                  payload?['phase'] ??
                  frame['phase']) as String?;
              if (phase == 'start' && !runStarted) {
                // For queued messages the ACK runId differs from the actual run ID in events.
                // Capture the real run ID from the first phase=start we see after our ACK.
                if (agentRun != null) activeRunId = agentRun;
                runStarted = true;
                assistantSnapshot = '';
                markRelevantGatewayActivity();
              } else if (phase == 'error') {
                if (!isActiveRunFrame(agentRun)) {
                  return;
                }
                markRelevantGatewayActivity();
                final rawError = _rawGatewayErrorText(
                  innerData?['error'] ?? payload?['error'] ?? frame['error'],
                );
                final error =
                    _formatGatewayProviderError(rawError, model: model);
                _addActivity('[CHAT] ✗ $error');
                if (!chunkController.isClosed) {
                  chunkController.add('[Error] $error');
                  chunkController.close();
                }
              } else if (phase == 'end') {
                if (!isActiveRunFrame(agentRun)) {
                  return;
                }
                markRelevantGatewayActivity();
                final rawEndSignal = (innerData?['error'] ??
                            payload?['error'] ??
                            innerData?['reason'] ??
                            payload?['reason'] ??
                            frame['error'] ??
                            frame['reason'])
                        ?.toString()
                        .trim() ??
                    '';
                final normalizedEndSignal = rawEndSignal.toLowerCase();
                final hasMeaningfulEndSignal = rawEndSignal.isNotEmpty &&
                    normalizedEndSignal != 'null' &&
                    normalizedEndSignal != 'completed' &&
                    normalizedEndSignal != 'run_completed';
                final endedWithError = innerData?['isError'] == true ||
                    payload?['isError'] == true ||
                    frame['isError'] == true ||
                    innerData?['aborted'] == true ||
                    payload?['aborted'] == true ||
                    frame['aborted'] == true ||
                    hasMeaningfulEndSignal;
                if (firstToken && endedWithError && !chunkController.isClosed) {
                  final msg = _formatGatewayProviderError(
                    rawEndSignal.isEmpty ? 'Unknown API error' : rawEndSignal,
                    model: model,
                  );
                  _addActivity('[CHAT] ✗ $msg');
                  chunkController.add('[Error] $msg');
                }
                if (!chunkController.isClosed) {
                  chunkController.close();
                }
              }
            } else if (stream == 'error') {
              // Internal gateway sequencing noise (e.g. reason=seq gap after a retry).
              // Real provider errors surface through stream=lifecycle phase=error.
              final reason = (payload?['reason'] ?? frame['reason']) as String?;
              if (reason == 'seq gap') return;
              if (!isActiveRunFrame(agentRun)) {
                return;
              }
              markRelevantGatewayActivity();
              final rawErr = _rawGatewayErrorText(
                innerData?['error'] ??
                    payload?['error'] ??
                    payload?['reason'] ??
                    frame['reason'] ??
                    frame['error'],
                fallback: '',
              );
              final isAuthError = reason == 'auth' ||
                  rawErr.toLowerCase().contains('auth') ||
                  rawErr.toLowerCase().contains('surface_error');
              if (isAuthError) {
                final authMsg = _formatGatewayProviderError(
                  rawErr.isEmpty ? 'Cloud model authentication error.' : rawErr,
                  model: model,
                );
                _addActivity('[CHAT] ✗ $authMsg');
                if (!chunkController.isClosed) {
                  chunkController.add('[Error] $authMsg');
                  chunkController.close();
                }
                return;
              }
              final error = _formatGatewayProviderError(rawErr, model: model);
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
      await for (final chunk in chunkController.stream) {
        yield chunk;
      }
      _addActivity('[CHAT] ✓ Complete');
    } catch (e) {
      _addActivity('[CHAT] ✗ $e');
      yield '[Error] WebSocket chat error: $e';
    } finally {
      inactivityWatchdog.cancel();
      frameSub.cancel();
    }
  }

  /// Invoke a generic RPC method on the gateway.
  Future<Map<String, dynamic>> invoke(String method,
      [Map<String, dynamic>? params]) async {
    if (_connection == null ||
        _connection!.state != GatewayConnectionState.connected) {
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

    final frame = await responseStream
        .firstWhere(
          (f) => f['type'] == 'res' || f['type'] == 'error',
        )
        .timeout(const Duration(seconds: 30));
    return frame;
  }

  Map<String, dynamic> _extractRpcPayload(Map<String, dynamic> frame) {
    if (frame['type'] == 'error') {
      final payload = frame['payload'];
      if (payload is Map<String, dynamic>) {
        final msg = payload['message']?.toString() ?? payload.toString();
        throw Exception(msg);
      }
      throw Exception(payload?.toString() ?? 'Gateway RPC error');
    }

    final ok = frame['ok'] as bool? ?? false;
    if (!ok) {
      final directMessage = frame['errorMessage']?.toString();
      if (directMessage != null && directMessage.isNotEmpty) {
        throw Exception(directMessage);
      }

      final error = frame['error'];
      if (error is Map<String, dynamic>) {
        final msg = error['message']?.toString() ?? error.toString();
        throw Exception(msg);
      }
      final directCode = frame['errorCode']?.toString();
      if (directCode != null && directCode.isNotEmpty) {
        throw Exception(directCode);
      }
      throw Exception(error?.toString() ?? 'Gateway RPC rejected');
    }

    final payload = frame['payload'];
    if (payload is Map<String, dynamic>) return payload;
    return <String, dynamic>{};
  }

  String _normalizeMobileChatSessionKey(String key) {
    final trimmed = key.trim();
    const canonicalAgentMainPrefix = 'agent:main:';
    if (trimmed.startsWith(canonicalAgentMainPrefix)) {
      final unscoped = trimmed.substring(canonicalAgentMainPrefix.length);
      if (unscoped.startsWith(_mobileChatSessionPrefix)) {
        return unscoped;
      }
    }
    return trimmed;
  }

  /// Resolve (or create) a stable gateway session key for one local chat thread.
  Future<String> resolveOrCreateGatewaySessionKey({
    required String localSessionId,
    String? existingSessionKey,
    bool forceNew = false,
  }) async {
    // Keep the gateway runtime on its proven default session lane. The app's
    // visible chat threading is already handled by Flutter persistence; asking
    // this OpenClaw build to dispatch arbitrary mobile session keys can leave a
    // queued message without an active run.
    return 'main';
  }

  /// Synthesize speech through modern gateway Talk RPC (`talk.speak`).
  ///
  /// Policy:
  /// - Cloud/Gateway mode should use Talk voice as the primary path.
  /// - Native fallback is allowed only when `talk.speak` is unavailable on this
  ///   gateway version (method unavailable / unknown method).
  Future<TalkSpeakPlayback> speakTextViaTalk(String text) async {
    final input = text.trim();
    if (input.isEmpty) {
      return const TalkSpeakPlayback(
        played: false,
        allowNativeFallback: false,
      );
    }

    final unavailableUntil = _talkSpeakUnavailableUntil;
    if (unavailableUntil != null && DateTime.now().isBefore(unavailableUntil)) {
      return TalkSpeakPlayback(
        played: false,
        allowNativeFallback: _talkSpeakBackoffAllowsNativeFallback,
      );
    }

    final prefs = PreferencesService();
    await prefs.init();
    final selectedVoiceId = prefs.gatewayVoiceId.trim();
    final speed = prefs.ttsSpeed.clamp(0.5, 2.0);
    final hasSpeedOverride = prefs.hasTtsSpeedOverride;

    try {
      final frame = await invoke('talk.speak', {
        'text': input,
        'outputFormat': 'mp3',
        if (hasSpeedOverride && (speed - 1.0).abs() > 0.01) 'speed': speed,
        if (selectedVoiceId.isNotEmpty) 'voiceId': selectedVoiceId,
      });
      final payload = _extractTalkSpeakPayload(frame);
      final audioBase64 = payload['audioBase64'] as String?;
      if (audioBase64 == null || audioBase64.isEmpty) {
        return const TalkSpeakPlayback(
          played: false,
          allowNativeFallback: false,
          errorMessage: 'talk.speak returned empty audio payload.',
        );
      }
      final audioBytes = base64Decode(audioBase64);
      await TtsService().speakBytes(audioBytes);
      return const TalkSpeakPlayback(
        played: true,
        allowNativeFallback: false,
      );
    } catch (e) {
      final err = e.toString();
      final lower = err.toLowerCase();
      if (lower.contains('talk_unconfigured') ||
          lower.contains('talk provider not configured')) {
        const message =
            'Gateway Talk provider is not configured. Configure an OpenClaw Talk/TTS provider before testing Gateway Voice.';
        _talkSpeakUnavailableUntil =
            DateTime.now().add(_talkSpeakUnavailableBackoff);
        _talkSpeakBackoffAllowsNativeFallback = false;
        _addActivity('[TTS] $message');
        return const TalkSpeakPlayback(
          played: false,
          allowNativeFallback: false,
          errorMessage: message,
        );
      }
      final methodUnavailable = lower.contains('unknown method') ||
          lower.contains('method unavailable') ||
          lower.contains('reason=method_unavailable');
      if (methodUnavailable) {
        _talkSpeakUnavailableUntil =
            DateTime.now().add(_talkSpeakUnavailableBackoff);
        _talkSpeakBackoffAllowsNativeFallback = true;
        _addActivity(
            '[TTS] talk.speak unavailable; suppressing retries for ${_talkSpeakUnavailableBackoff.inMinutes}m');
        return const TalkSpeakPlayback(
          played: false,
          allowNativeFallback: true,
        );
      }
      _addActivity('[TTS] talk.speak failed: $e');
      return TalkSpeakPlayback(
        played: false,
        allowNativeFallback: false,
        errorMessage: err,
      );
    }
  }

  Map<String, dynamic> _extractTalkSpeakPayload(Map<String, dynamic> frame) {
    if (frame['type'] == 'error') {
      final payload = frame['payload'];
      final msg = payload is Map
          ? (payload['message']?.toString() ?? payload.toString())
          : (payload?.toString() ?? 'talk.speak error');
      final reason = payload is Map
          ? (payload['details']?['reason'] ??
                  payload['data']?['details']?['reason'])
              ?.toString()
          : null;
      throw Exception(
        reason == null || reason.isEmpty ? msg : '$msg (reason=$reason)',
      );
    }

    final ok = frame['ok'] as bool? ?? false;
    if (!ok) {
      final err = frame['error'];
      if (err is Map) {
        final msg = err['message']?.toString() ?? err.toString();
        final reason =
            (err['details']?['reason'] ?? err['data']?['details']?['reason'])
                ?.toString();
        throw Exception(
          reason == null || reason.isEmpty ? msg : '$msg (reason=$reason)',
        );
      }
      throw Exception(frame['errorMessage']?.toString() ??
          err?.toString() ??
          'talk.speak rejected');
    }

    final payload = frame['payload'];
    if (payload is Map<String, dynamic>) return payload;
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getTalkCatalog() async {
    final frame = await invoke('talk.catalog', {});
    return _extractRpcPayload(frame);
  }

  Future<Map<String, dynamic>> getTtsProviders() async {
    final frame = await invoke('tts.providers', {});
    return _extractRpcPayload(frame);
  }

  Future<Map<String, dynamic>> getTtsPersonas() async {
    final frame = await invoke('tts.personas', {});
    return _extractRpcPayload(frame);
  }

  Future<Map<String, dynamic>> setTtsProvider(String providerId) async {
    final normalizedProvider = providerId.trim();
    final frame =
        await invoke('tts.setProvider', {'provider': normalizedProvider});
    final payload = _extractRpcPayload(frame);

    // Keep Talk's active provider aligned with TTS selection so talk.speak
    // remains configured on gateways that validate talk.* separately.
    await _syncTalkProviderSelectionInConfig(normalizedProvider);
    return payload;
  }

  Future<void> _syncTalkProviderSelectionInConfig(String providerId) async {
    if (providerId.isEmpty) return;
    try {
      final config = await _readConfig();
      ensureGatewayTalkTtsConfig(config);

      final talk = config['talk'];
      if (talk is! Map) return;
      final talkProviders = talk['providers'];
      if (talkProviders is! Map || !talkProviders.containsKey(providerId)) {
        return;
      }

      final current = talk['provider']?.toString().trim() ?? '';
      if (current == providerId) return;
      talk['provider'] = providerId;
      await _writeConfig(config);
    } catch (e) {
      _addActivity('[TTS] Talk provider sync skipped: $e');
    }
  }

  Future<Map<String, dynamic>> setTtsPersona(String? personaId) async {
    final normalized = (personaId ?? '').trim().toLowerCase();
    final frame = await invoke('tts.setPersona', {
      'persona':
          normalized.isEmpty || normalized == 'default' ? null : normalized,
    });
    return _extractRpcPayload(frame);
  }

  Future<Map<String, dynamic>> createTalkRealtimeRelaySession({
    String? provider,
    String? model,
    String? voice,
  }) async {
    final frame = await invoke('talk.session.create', {
      'mode': 'realtime',
      'transport': 'gateway-relay',
      'brain': 'agent-consult',
      if (provider != null && provider.isNotEmpty) 'provider': provider,
      if (model != null && model.isNotEmpty) 'model': model,
      if (voice != null && voice.isNotEmpty) 'voice': voice,
    });
    return _extractRpcPayload(frame);
  }

  Future<void> appendTalkSessionAudio({
    required String sessionId,
    required String audioBase64,
    double? timestamp,
  }) async {
    await invoke('talk.session.appendAudio', {
      'sessionId': sessionId,
      'audioBase64': audioBase64,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  Future<void> cancelTalkSessionTurn(String sessionId, {String? reason}) async {
    await invoke('talk.session.cancelTurn', {
      'sessionId': sessionId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> closeTalkSession(String sessionId) async {
    await invoke('talk.session.close', {'sessionId': sessionId});
  }

  String _gatewayHttpModel(String model) {
    final trimmed = model.trim();
    if (trimmed.startsWith('openclaw/')) return trimmed;
    if (trimmed.startsWith('agent/')) {
      final agentId = trimmed.substring('agent/'.length).trim();
      return agentId.isEmpty ? 'openclaw' : 'openclaw/$agentId';
    }
    // The gateway's OpenAI-compatible proxy intentionally accepts OpenClaw
    // agent routes, not provider ids such as openrouter/openrouter/free.
    return 'openclaw';
  }

  bool _shouldUseFastCloudChat(String message, String model) {
    // Production policy: cloud chat stays on gateway by default so tools and
    // skills remain available in one consistent execution lane.
    //
    // Local chat is handled separately by explicit local-llm model routing
    // gated through Local Chat Mode in preferences.
    return false;
  }

  Future<_FastCloudRoute?> _resolveFastCloudRoute(String model) async {
    final canonical = ModelProviderCatalog.canonicalizeModelId(model);
    final option = ModelProviderCatalog.modelById(canonical);
    final provider = option?.providerId ??
        (canonical.contains('/') ? canonical.split('/').first : '');
    if (provider != 'openrouter') return null;

    try {
      final config = await _readConfig();
      final apiKey = _extractProviderApiKey(config, provider);
      if (apiKey == null || apiKey.isEmpty) return null;

      final providerConfig = config['models']?['providers']?[provider];
      final baseUrl =
          providerConfig is Map ? providerConfig['baseUrl']?.toString() : null;
      final providerPrefix = '$provider/';
      final modelId =
          option?.providerModelId ?? canonical.substring(providerPrefix.length);
      return _FastCloudRoute(
        provider: provider,
        model: modelId,
        apiKey: apiKey,
        url:
            '${(baseUrl == null || baseUrl.isEmpty) ? 'https://openrouter.ai/api/v1' : baseUrl}/chat/completions',
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractProviderApiKey(Map<String, dynamic> config, String provider) {
    final providerConfig = config['models']?['providers']?[provider];
    if (providerConfig is Map) {
      final key = providerConfig['apiKey']?.toString().trim();
      if (key != null && key.isNotEmpty) return key;
    }

    final envKey = ModelProviderCatalog.envKeyForProvider(provider);
    final envVars = config['env']?['vars'];
    if (envVars is Map && envKey.isNotEmpty) {
      final key = envVars[envKey]?.toString().trim();
      if (key != null && key.isNotEmpty) return key;
    }
    return null;
  }

  List<Map<String, dynamic>> _boundedFastCloudMessages(
    String message,
    List<Map<String, dynamic>>? conversationHistory,
  ) {
    final bounded = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            'You are Plawie, a warm concise mobile AI companion. Reply directly and keep answers useful.',
      }
    ];

    final history = conversationHistory ?? const <Map<String, dynamic>>[];
    final recent =
        history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final item in recent) {
      final role = item['role']?.toString();
      final content = item['content']?.toString();
      if ((role == 'user' || role == 'assistant') &&
          content != null &&
          content.trim().isNotEmpty) {
        bounded.add({
          'role': role,
          'content':
              content.length > 1800 ? content.substring(0, 1800) : content,
        });
      }
    }
    bounded.add({'role': 'user', 'content': message});
    return bounded;
  }

  Stream<String> _sendFastCloudMessage({
    required _FastCloudRoute route,
    required String message,
    List<Map<String, dynamic>>? conversationHistory,
  }) async* {
    final client = http.Client();
    try {
      _addActivity('[CHAT] → Fast cloud lane ${route.provider}/${route.model}');
      final request = http.Request('POST', Uri.parse(route.url))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${route.apiKey}',
          'HTTP-Referer': 'https://github.com/vmbbz/plawie',
          'X-Title': 'Plawie',
        })
        ..body = jsonEncode({
          'model': route.model,
          'messages': _boundedFastCloudMessages(message, conversationHistory),
          'stream': true,
        });

      final response =
          await client.send(request).timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        _addActivity('[CHAT] ✗ Fast cloud HTTP ${response.statusCode}');
        yield '[Error] Cloud provider error ${response.statusCode}: $body';
        return;
      }

      var sawText = false;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 45))) {
        if (line.isEmpty || !line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        try {
          final decoded = jsonDecode(data);
          if (decoded is! Map<String, dynamic>) continue;
          final choices = decoded['choices'];
          if (choices is! List || choices.isEmpty) continue;
          final choice = choices.first;
          if (choice is! Map) continue;
          final delta = choice['delta'];
          final messageObj = choice['message'];
          final content = (delta is Map ? delta['content'] : null) ??
              (messageObj is Map ? messageObj['content'] : null);
          if (content is String && content.isNotEmpty) {
            if (!sawText) {
              sawText = true;
              _addActivity('[CHAT] ✓ Fast cloud first token');
            }
            yield content;
          }
        } catch (_) {
          // Ignore malformed provider keepalive chunks.
        }
      }
      _addActivity('[CHAT] ✓ Fast cloud complete');
    } on TimeoutException {
      yield '[Error] Cloud provider timed out. Try again in a moment.';
    } catch (e) {
      yield '[Error] Fast cloud chat failed: $e';
    } finally {
      client.close();
    }
  }

  /// HTTP fallback: POST to /v1/chat/completions with STREAMING support.
  ///
  /// Used for specific model overrides (like Local LLM) where the WS RPC
  /// parameters are too rigid. Now supports real-time text deltas.
  Stream<String> sendMessageHttp(
    String message, {
    String? model,
    String? token,
    List<Map<String, dynamic>>? conversationHistory,
    String?
        directUrl, // if set, bypass the gateway and POST directly to this URL
  }) async* {
    model = await _resolveModel(model);

    final url = directUrl ?? '${AppConstants.gatewayUrl}/v1/chat/completions';
    final isDirectEndpoint = directUrl != null;

    // For direct local bridge calls, no gateway token or openclaw headers needed.
    if (!isDirectEndpoint) {
      token ??= await retrieveTokenFromConfig();
      if (token == null || token.isEmpty) {
        yield '[Error] No auth token for model routing.';
        return;
      }
    }

    final messages =
        conversationHistory != null && conversationHistory.isNotEmpty
            ? [
                ...conversationHistory,
                {'role': 'user', 'content': message}
              ]
            : [
                {'role': 'user', 'content': message}
              ];

    final effectiveModel = isDirectEndpoint ? model : _gatewayHttpModel(model);

    final client = http.Client();
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (!isDirectEndpoint && token != null)
          'Authorization': 'Bearer $token',
      };
      final request = http.Request('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..body = jsonEncode({
          'model': effectiveModel,
          'messages': messages,
          'stream': true,
          if (isDirectEndpoint) 'keep_alive': -1,
        });

      final timeoutDuration = isDirectEndpoint
          ? const Duration(seconds: 240)
          : const Duration(seconds: 240);

      if (isDirectEndpoint) {
        _addActivity('[CHAT] → Sending to $effectiveModel');
      }

      final streamedResponse =
          await client.send(request).timeout(timeoutDuration);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        if (isDirectEndpoint) {
          _addActivity('[CHAT] ✗ HTTP ${streamedResponse.statusCode}');
        }
        yield '[Error] HTTP ${streamedResponse.statusCode}: $body';
        return;
      }

      if (isDirectEndpoint) {
        _addActivity('[CHAT] ← Local bridge accepted (HTTP 200)');
      }

      // Process the SSE stream.
      // Handles OpenAI-compatible SSE and simple NDJSON bridge streams.
      bool firstChunk = true;
      int rawChunks = 0;
      final List<String> rawSamples = [];
      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;
        rawChunks++;
        if (isDirectEndpoint && rawChunks <= 3) {
          rawSamples.add(chunk.length > 120 ? chunk.substring(0, 120) : chunk);
        }

        String? rawJson;
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6).trim();
          if (data == '[DONE]') break;
          rawJson = data;
        } else if (chunk.startsWith('{')) {
          rawJson = chunk;
        }

        if (rawJson == null) continue;

        try {
          final json = jsonDecode(rawJson) as Map<String, dynamic>;

          // OpenAI-compat streaming: choices[0].delta.content
          final delta =
              (json['choices'] as List?)?[0]?['delta']?['content'] as String?;
          // OpenAI-compat non-streaming (single chunk): choices[0].message.content
          final messageContent =
              (json['choices'] as List?)?[0]?['message']?['content'] as String?;
          final nativeContent =
              (json['message'] as Map?)?['content'] as String?;
          final done = json['done'] as bool? ?? false;

          final token = (delta != null && delta.isNotEmpty)
              ? delta
              : (messageContent != null && messageContent.isNotEmpty)
                  ? messageContent
                  : (nativeContent != null && nativeContent.isNotEmpty)
                      ? nativeContent
                      : null;

          if (token != null) {
            if (firstChunk && isDirectEndpoint) {
              firstChunk = false;
              _addActivity('[CHAT] ✓ First token received');
            }
            yield token;
          }

          if (done) break;
        } catch (e) {
          // Malformed chunk or heartbeat, skip silently unless debug
          debugPrint('[GatewayService] SSE parse error: $e (raw: $rawJson)');
        }
      }
      if (isDirectEndpoint) {
        _addActivity('[CHAT] ✓ Stream complete ($rawChunks chunks)');
        if (firstChunk) {
          for (int i = 0; i < rawSamples.length; i++) {
            _addActivity('[CHAT] raw[$i]: ${rawSamples[i]}');
          }
        }
      }
    } on TimeoutException {
      if (isDirectEndpoint) {
        _addActivity('[CHAT] ✗ Timed out after 240 s');
        yield '[Error] Local bridge timed out (240 s). '
            'The device may be under heavy load — try a shorter message or wait for it to cool.';
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
    final effectivePrompt = prompt.trim().isEmpty
        ? 'Describe what you see in this image.'
        : prompt.trim();
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
    token = await _waitForGatewayChatLaneReady(token);
    if (token == null || token.isEmpty) {
      yield '[Error] Gateway is applying provider/model changes. '
          'Video was not sent during the reload window.';
      return;
    }

    final effectivePrompt = prompt.trim().isEmpty
        ? 'Describe what is happening in this video.'
        : prompt.trim();

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'model': _gatewayHttpModel(await _resolveModel(null)),
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
    token = await _waitForGatewayChatLaneReady(token);
    if (token == null || token.isEmpty) {
      yield '[Error] Gateway is applying provider/model changes. '
          'Image was not sent during the reload window.';
      return;
    }

    final effectivePrompt = prompt.trim().isEmpty
        ? 'Describe what you see in this image.'
        : prompt.trim();

    try {
      final response = await http
          .post(
            Uri.parse('${AppConstants.gatewayUrl}/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'model': _gatewayHttpModel(await _resolveModel(null)),
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
    // DO NOT sync agent models to the global defaults.
    // Agents have their own IDs and config; writing 'agent/id' to the global primary
    // would corrupt the default provider model setting.
    if (model.startsWith('agent/')) return {};

    final Map<String, dynamic> changedMetadata = {};
    final config = await _readConfig();
    _ensureCatalogProviderDefaults(config);

    config['agents'] ??= {};
    config['agents']['defaults'] ??= {};
    if (config['agents']['defaults'] is Map) {
      (config['agents']['defaults'] as Map).remove('skipBootstrap');
    }
    config['agents']['defaults']['model'] ??= {};

    final current = config['agents']['defaults']['model']['primary'] as String?;
    bool needsSync = false;

    if (current != model) {
      config['agents']['defaults']['model']['primary'] = model;
      needsSync = true;
    }

    if (needsSync) {
      try {
        if (await _runtime.isRunning()) {
          _beginGatewayConfigTransition(
            'chat model hot-switch',
            minimumSettle: _gatewayConfigSoftSettle,
          );
        }
      } catch (_) {}
      await _writeConfig(config);
      _addActivity('[MODEL] syncToConfig: $model');

      changedMetadata['primaryModel'] = model;
    }

    return changedMetadata;
  }

  Future<void> _patchActiveGatewaySessionModel(
    Map<String, dynamic> changedMetadata, {
    String sessionKey = 'main',
  }) async {
    if (changedMetadata.isEmpty || _connection == null) return;
    _beginGatewayConfigTransition(
      'active gateway session patch',
      minimumSettle: _gatewaySessionPatchSettle,
    );
    try {
      await _connection!.patchSessionMetadata(
        changedMetadata,
        sessionKey: sessionKey,
      );
      _addActivity(
        '[MODEL] active gateway session patched ($sessionKey): $changedMetadata',
      );
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      _addActivity('[MODEL] active session model patch skipped: $e');
    }
    disconnectWebSocket();
    await Future.delayed(_gatewaySessionPatchSettle);
  }

  /// Resolves the intended model ID, falling back to preferences then
  /// openclaw.json defaults.
  Future<String> _resolveModel(String? model) async {
    String m = model ?? '';
    final prefs = PreferencesService();
    await prefs.init();
    if (m.isEmpty) {
      m = prefs.configuredModel ?? '';
    }
    if (m.isEmpty) {
      final config = await _readConfig();
      m = config['agents']?['defaults']?['model']?['primary'] as String? ?? '';
    }
    if (m.isEmpty) {
      m = ModelProviderCatalog.defaultCloudFallbackModel;
    }
    m = ModelProviderCatalog.canonicalizeModelId(m);

    // Force cloud/gateway lane unless the user explicitly enabled local chat
    // from the Local LLM page.
    if (ModelProviderCatalog.isDirectLocalModelId(m) &&
        !prefs.localChatModeEnabled) {
      final lastCloud = prefs.lastCloudModel;
      final fallback = (lastCloud != null && lastCloud.isNotEmpty)
          ? ModelProviderCatalog.canonicalizeModelId(lastCloud)
          : ModelProviderCatalog.defaultCloudFallbackModel;
      if (!ModelProviderCatalog.isDirectLocalModelId(fallback)) {
        m = fallback;
      } else {
        m = ModelProviderCatalog.defaultCloudFallbackModel;
      }
    }
    return m;
  }

  /// Disconnect the persistent WS connection so the next sendMessage() opens a
  /// fresh session — picking up any gateway config change (e.g. local-llm reload).
  void disconnectWebSocket() {
    _rpcDiscoveryDone = false;
    _connection?.dispose();
    _connection = null;
    _updateState(_state.copyWith(
      isWebsocketConnected: false,
      isInteractiveReady: false,
    ));
  }

  /// Clear the cached auth token so the next request re-probes for a fresh one.
  /// Call this after openclaw reload/restart, which generates a new token.
  void invalidateTokenCache() {
    _cachedToken = null;
    _lastTokenFetch = null;
    _updateState(_state.copyWith(clearDashboardUrl: true));
  }

  /// Polished background keep-alive using flutter_foreground_task.
  /// Ensures the OpenClaw gateway survives Android memory management.
  Future<void> startForegroundService() async {
    try {
      await FlutterForegroundTask.startService(
        notificationTitle: "OpenClaw Gateway Running",
        notificationText: "Keeping AI agent alive in background",
        callback: () async {},
      );
      _addActivity(
          '[SYS] Foreground service started (better battery + stability)');
    } catch (e) {
      _addActivity('[SYS] Foreground service not available: $e');
    }
  }

  void dispose() {
    _healthTimer?.cancel();
    _logSubscription?.cancel();
    _gatewayEventSubscription?.cancel();
    _connection?.dispose();
    _stateController.close();
    _chatActivityController.close();
  }

  Future<void> _verifyGatewayConfigHardened({required String reason}) async {
    try {
      final config = await _readConfig();
      if (_isGatewayConfigHardened(config)) {
        _lastHardeningSweepAt = DateTime.now();
        return;
      }
      _addActivity(
        '[WARN] Gateway config is not fully hardened ($reason). '
        'Skipping live rewrite to avoid startup reload churn; next explicit start/setup will repair it.',
      );
    } catch (e) {
      _addActivity('[WARN] Gateway config verification failed ($reason): $e');
    }
  }

  bool _isGatewayConfigHardened(Map<String, dynamic> config) {
    final gateway = config['gateway'];
    if (gateway is! Map) return false;

    final origins = (gateway['controlUi']?['allowedOrigins'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final hasLoopbackOrigins =
        localControlUiAllowedOrigins.every(origins.contains) &&
            !origins.contains('*');

    final auth = gateway['auth'];
    final remote = gateway['remote'];
    final authMode = auth is Map ? auth['mode'] : null;
    final authToken = auth is Map ? auth['token'] : null;
    final authPassword = auth is Map ? auth['password'] : null;
    final hasPersistentAuth = (authToken is String && authToken.isNotEmpty) ||
        (authPassword is String && authPassword.isNotEmpty);
    final remoteToken = remote is Map ? remote['token'] : null;
    final remotePassword = remote is Map ? remote['password'] : null;
    final remoteCredentialsAligned = ((authToken is! String ||
            authToken.isEmpty ||
            remoteToken == authToken) &&
        (authPassword is! String ||
            authPassword.isEmpty ||
            remotePassword == authPassword));

    final discovery = config['discovery'];
    final agentsDefaults = config['agents']?['defaults'];
    final hasNoBootstrapBypass =
        agentsDefaults is! Map || agentsDefaults['skipBootstrap'] != true;
    final models = config['models'];
    final providers = models is Map ? models['providers'] : null;
    final hasCatalogProviders = providers is Map &&
        ModelProviderCatalog.providers
            .every((provider) => providers.containsKey(provider.id));
    final authRoot = config['auth'];
    final authProfiles = authRoot is Map ? authRoot['profiles'] : null;
    final authOrder = authRoot is Map ? authRoot['order'] : null;
    final hasNoLegacyOllamaAuth =
        (authProfiles is! Map || !authProfiles.containsKey('ollama:default')) &&
            (authOrder is! Map || !authOrder.containsKey('ollama'));
    final messages = config['messages'];
    final tts = messages is Map ? messages['tts'] : null;
    final ttsProvider = tts is Map ? tts['provider'] : null;
    final ttsProviders = tts is Map ? tts['providers'] : null;
    final hasMessagesTtsProvider = tts is Map &&
        ttsProvider is String &&
        ttsProvider.trim().isNotEmpty &&
        ttsProviders is Map &&
        ttsProviders.containsKey(ttsProvider.trim());
    final talk = config['talk'];
    final talkProvider = talk is Map ? talk['provider'] : null;
    final talkProviders = talk is Map ? talk['providers'] : null;
    final hasActiveTalkProvider = talk is Map &&
        talkProvider is String &&
        talkProvider.trim().isNotEmpty &&
        talkProviders is Map &&
        talkProviders.containsKey(talkProvider.trim());

    return gateway['mode'] == 'local' &&
        gateway['bind'] == 'loopback' &&
        gateway['port'] == AppConstants.gatewayPort &&
        hasLoopbackOrigins &&
        hasPersistentAuth &&
        (authMode == 'token' || authMode == 'password') &&
        remoteCredentialsAligned &&
        discovery is Map &&
        discovery['mdns']?['mode'] == 'off' &&
        discovery['wideArea']?['enabled'] == false &&
        models is Map &&
        providers is Map &&
        hasCatalogProviders &&
        !providers.containsKey('ollama') &&
        !models.containsKey('startup') &&
        !gateway.containsKey('startup') &&
        !gateway.containsKey('sidecars') &&
        hasMessagesTtsProvider &&
        hasActiveTalkProvider &&
        hasNoBootstrapBypass &&
        hasNoLegacyOllamaAuth &&
        !config.containsKey('ollama');
  }

  /// INDUSTRIAL HARDENING: Use config patch (official, reliable way to set arrays)
  /// with optional runtime reload.
  Future<void> hardenGatewayConfigViaCli({
    bool allowReload = true,
    String reason = 'runtime',
  }) async {
    // The BootstrapService handles pre-start hardening now, but we perform
    // a defensive check here to ensure the active gateway is always hardened.

    try {
      final config = await _readConfig();
      if (_isGatewayConfigHardened(config)) {
        debugPrint('✅ Hardening already present. Skipping reload.');
        return;
      }
    } catch (_) {}

    // Runtime sweeps should not run too frequently.
    if (reason == 'runtime-health-check') {
      final lastSweep = _lastHardeningSweepAt;
      if (lastSweep != null &&
          DateTime.now().difference(lastSweep) < _runtimeHardeningCooldown) {
        return;
      }
    }

    // 1. Initial immediate sweep
    await _applyHardeningPatch(allowReload: allowReload);

    // 2. Short delay to ensure write is finished
    await Future.delayed(const Duration(milliseconds: 600));
    _lastHardeningSweepAt = DateTime.now();

    debugPrint(
        '✅ Hardening sweep complete (reason=$reason, reload=${allowReload ? 'on' : 'off'})');
  }

  Future<void> _applyHardeningPatch({required bool allowReload}) async {
    final currentConfig = await _readConfig();
    _ensurePersistentGatewayToken(currentConfig);
    _applyExplicitAuthMode(currentConfig);
    _syncLocalGatewayRemoteCredentials(currentConfig);
    currentConfig['models'] ??= <String, dynamic>{};
    final models = currentConfig['models'];
    if (models is Map) {
      models['pricing'] ??= <String, dynamic>{};
      final pricing = models['pricing'];
      if (pricing is Map) {
        pricing['enabled'] = false;
      } else {
        models['pricing'] = <String, dynamic>{'enabled': false};
      }
    }
    ensureGatewayTalkTtsConfig(currentConfig);
    final primary = currentConfig['agents']?['defaults']?['model']?['primary'];
    currentConfig['agents'] ??= {};
    currentConfig['agents']['defaults'] ??= {};
    if (currentConfig['agents']['defaults'] is Map) {
      (currentConfig['agents']['defaults'] as Map).remove('skipBootstrap');
    }
    if (primary is String && primary.trim().isNotEmpty) {
      currentConfig['agents']['defaults']['model'] ??= {};
      currentConfig['agents']['defaults']['model']['primary'] =
          ModelProviderCatalog.canonicalizeModelId(primary);
    }
    final agentsDefaults = currentConfig['agents']['defaults'];
    if (agentsDefaults is Map) {
      final timeoutSeconds = agentsDefaults['timeoutSeconds'];
      if (timeoutSeconds is! num || timeoutSeconds < 240) {
        agentsDefaults['timeoutSeconds'] = 240;
      }
    }
    GatewayToolCatalog.applyDefaultMobilePolicy(currentConfig);
    _ensureCatalogProviderDefaults(currentConfig);
    final currentGateway = currentConfig['gateway'];
    if (currentGateway is Map) {
      currentGateway.remove('startup');
      currentGateway.remove('sidecars');
    }
    _removeLegacyOllamaConfig(currentConfig);
    await _writeConfig(currentConfig);

    final gatewayAuth =
        currentConfig['gateway']?['auth'] as Map<String, dynamic>?;
    final gatewayRemote =
        currentConfig['gateway']?['remote'] as Map<String, dynamic>?;
    final authPatch = <String, dynamic>{};
    final remotePatch = <String, dynamic>{};
    final currentToken = gatewayAuth?['token'];
    final currentPassword = gatewayAuth?['password'];
    final currentMode = gatewayAuth?['mode'];
    if (currentToken is String && currentToken.isNotEmpty) {
      authPatch['token'] = currentToken;
    }
    if (currentPassword is String && currentPassword.isNotEmpty) {
      authPatch['password'] = currentPassword;
    }
    if (currentMode is String && currentMode.isNotEmpty) {
      authPatch['mode'] = currentMode;
    } else if (authPatch.containsKey('token')) {
      authPatch['mode'] = 'token';
    } else if (authPatch.containsKey('password')) {
      authPatch['mode'] = 'password';
    }
    final remoteToken = gatewayRemote?['token'];
    final remotePassword = gatewayRemote?['password'];
    if (remoteToken is String && remoteToken.isNotEmpty) {
      remotePatch['token'] = remoteToken;
    }
    if (remotePassword is String && remotePassword.isNotEmpty) {
      remotePatch['password'] = remotePassword;
    }

    final patchJson = '''
{
  "gateway": {
    ${authPatch.isNotEmpty ? '"auth": ${jsonEncode(authPatch)},' : ''}
    ${remotePatch.isNotEmpty ? '"remote": ${jsonEncode(remotePatch)},' : ''}
    "controlUi": {
      "allowedOrigins": ${jsonEncode(localControlUiAllowedOrigins)}
    },
    "nodes": {
      "pairing": {
        "autoApproveCidrs": ["127.0.0.1/32"]
      },
      "denyCommands": [],
      "allowCommands": ${jsonEncode(GatewayToolCatalog.mobileNodeAllowCommands.toList(growable: false))}
    },
    "http": { "endpoints": { "chatCompletions": { "enabled": true } } },
    "mode": "local",
    "bind": "loopback",
    "port": 18789
  },
  "discovery": {
    "mdns": {
      "mode": "off"
    },
    "wideArea": {
      "enabled": false
    }
  }
}
''';

    try {
      final alreadyRunning = await _runtime.isRunning();
      final shouldReload =
          allowReload && alreadyRunning && !_isInGatewaySettleWindow;
      final reloadSuffix =
          shouldReload ? ' && openclaw reload 2>/dev/null' : '';

      await NativeBridge.runInProot(
        'cat > /tmp/harden.json << \'EOF\'\n'
        '$patchJson\n'
        'EOF && '
        'openclaw config patch --file /tmp/harden.json && '
        'rm -f /tmp/harden.json'
        '$reloadSuffix',
        timeout: 60,
      );

      if (shouldReload) {
        // Short grace period for the gateway to process the SIGUSR1 (reload)
        // and for WebSocket listeners to recover.
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      debugPrint(
          '✅ Hardening sweep (config patch${shouldReload ? ' + reload' : ''}) applied successfully');
      _addActivity(
          '[SYS] Industrial-grade CLI hardening applied${shouldReload ? ' and reloaded' : ''}.');
    } catch (e) {
      debugPrint('⚠️ Hardening sweep failed (non-fatal): $e');
    }
  }
}

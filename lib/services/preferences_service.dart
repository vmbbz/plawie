import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const _keyAutoStart = 'auto_start_gateway';
  static const _keySetupComplete = 'setup_complete';
  static const _keyFirstRun = 'first_run';
  static const _keyDashboardUrl = 'dashboard_url';
  static const _keyNodeEnabled = 'node_enabled';
  static const _keyNodeDeviceToken = 'node_device_token';
  static const _keyNodeIdentityDeviceId = 'node_identity_device_id';
  static const _keyNodeGatewayHost = 'node_gateway_host';
  static const _keyNodeGatewayPort = 'node_gateway_port';
  static const _keyNodePublicKey = 'node_ed25519_public';
  static const _keyNodeGatewayToken = 'node_gateway_token';
  static const _keyGatewayToken = 'gateway_token';
  static const _keyLastApprovedRequestId = 'last_approved_request_id';
  static const _keySetupInProgress = 'setup_in_progress';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    if (_prefs == null) {
      throw StateError(
          'PreferencesService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  bool get autoStartGateway => _p.getBool(_keyAutoStart) ?? true;
  set autoStartGateway(bool value) => _p.setBool(_keyAutoStart, value);

  bool get setupComplete => _p.getBool(_keySetupComplete) ?? false;
  set setupComplete(bool value) => _p.setBool(_keySetupComplete, value);

  bool get setupInProgress => _p.getBool(_keySetupInProgress) ?? false;
  set setupInProgress(bool value) => _p.setBool(_keySetupInProgress, value);

  bool get isFirstRun => _p.getBool(_keyFirstRun) ?? true;
  set isFirstRun(bool value) => _p.setBool(_keyFirstRun, value);

  String? get dashboardUrl => _p.getString(_keyDashboardUrl);
  set dashboardUrl(String? value) {
    if (value != null) {
      _p.setString(_keyDashboardUrl, value);
    } else {
      _p.remove(_keyDashboardUrl);
    }
  }

  bool get nodeEnabled => _p.getBool(_keyNodeEnabled) ?? true;
  set nodeEnabled(bool value) => _p.setBool(_keyNodeEnabled, value);

  String? get nodeDeviceToken => _p.getString(_keyNodeDeviceToken);
  set nodeDeviceToken(String? value) {
    if (value != null) {
      _p.setString(_keyNodeDeviceToken, value);
    } else {
      _p.remove(_keyNodeDeviceToken);
    }
  }

  String? get nodeIdentityDeviceId => _p.getString(_keyNodeIdentityDeviceId);
  set nodeIdentityDeviceId(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyNodeIdentityDeviceId, value);
    } else {
      _p.remove(_keyNodeIdentityDeviceId);
    }
  }

  String? get nodeGatewayHost => _p.getString(_keyNodeGatewayHost);
  set nodeGatewayHost(String? value) {
    if (value != null) {
      _p.setString(_keyNodeGatewayHost, value);
    } else {
      _p.remove(_keyNodeGatewayHost);
    }
  }

  String? get nodePublicKey => _p.getString(_keyNodePublicKey);

  String? get nodeGatewayToken => _p.getString(_keyNodeGatewayToken);
  set nodeGatewayToken(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyNodeGatewayToken, value);
    } else {
      _p.remove(_keyNodeGatewayToken);
    }
  }

  String get gatewayToken => _p.getString(_keyGatewayToken) ?? '';
  set gatewayToken(String value) => _p.setString(_keyGatewayToken, value);

  int? get nodeGatewayPort {
    final val = _p.getInt(_keyNodeGatewayPort);
    return val;
  }

  set nodeGatewayPort(int? value) {
    if (value != null) {
      _p.setInt(_keyNodeGatewayPort, value);
    } else {
      _p.remove(_keyNodeGatewayPort);
    }
  }

  /// The selected VRM avatar filename
  String get selectedAvatar => _p.getString('selectedAvatar') ?? 'gemini.vrm';
  set selectedAvatar(String value) => _p.setString('selectedAvatar', value);

  /// Selected AI provider (claude, gemini, openai, groq)
  String? get apiProvider => _p.getString('api_provider');
  set apiProvider(String? value) {
    if (value != null) {
      _p.setString('api_provider', value);
    } else {
      _p.remove('api_provider');
    }
  }

  /// User-chosen agent name
  String get agentName => _p.getString('agent_name') ?? 'Plawie';
  set agentName(String value) => _p.setString('agent_name', value);

  /// Whether an API key has been configured
  bool get apiKeyConfigured => _p.getBool('api_key_configured') ?? false;
  set apiKeyConfigured(bool value) => _p.setBool('api_key_configured', value);

  /// The configured primary model (e.g. 'google/gemini-3.1-pro-preview')
  String? get configuredModel => _p.getString('configured_model');
  set configuredModel(String? value) {
    if (value != null) {
      _p.setString('configured_model', value);
    } else {
      _p.remove('configured_model');
    }
  }

  /// Skill Enablement Persistence
  bool isSkillEnabled(String skillId) =>
      _p.getBool('skill_enabled_$skillId') ?? false;

  /// Like [isSkillEnabled] but with a caller-specified default.
  /// Core device skills (avatar-control, tts-voice, device-node) pass
  /// `defaultValue: true` so they're discoverable by the AI out-of-the-box.
  bool isSkillEnabledOrDefault(String skillId, {bool defaultValue = false}) =>
      _p.getBool('skill_enabled_$skillId') ?? defaultValue;

  Future<void> setSkillEnabled(String skillId, bool enabled) =>
      _p.setBool('skill_enabled_$skillId', enabled);

  // ── Voice & Speech ──────────────────────────────────────────────────────────

  /// Speech speed multiplier (0.5–2.0). Default 1.2 to match competitor default.
  double get ttsSpeed => _p.getDouble('tts_speed') ?? 1.2;
  set ttsSpeed(double value) => _p.setDouble('tts_speed', value);

  /// Auto-restart STT after TTS finishes
  bool get continuousMode => _p.getBool('continuous_mode') ?? false;
  set continuousMode(bool value) => _p.setBool('continuous_mode', value);

  /// Silence timeout in seconds before auto-submitting (1–15)
  int get silenceTimeoutSeconds => _p.getInt('silence_timeout_seconds') ?? 5;
  set silenceTimeoutSeconds(int value) =>
      _p.setInt('silence_timeout_seconds', value);

  /// Current voice persona name (provider-agnostic)
  String get currentTtsPersona =>
      _p.getString('current_tts_persona') ?? 'default';
  set currentTtsPersona(String value) =>
      _p.setString('current_tts_persona', value);

  // ── Wake Word ───────────────────────────────────────────────────────────────

  /// Wake word mode: 'off' | 'foreground' | 'always'
  String get wakeWordMode => _p.getString('wake_word_mode') ?? 'off';
  set wakeWordMode(String value) => _p.setString('wake_word_mode', value);

  // ── TTS Engine & Offline Models ──────────────────────────────────────────────

  /// Selected TTS Engine: 'gateway' (Cloud) | 'offline' (Sherpa-ONNX)
  String get ttsEngine => _p.getString('tts_engine') ?? 'gateway';
  set ttsEngine(String value) => _p.setString('tts_engine', value);

  /// Currently active offline voice model ID (e.g. 'en_US-lessac-high')
  String get offlineVoiceModel =>
      _p.getString('offline_voice_model') ?? 'en_US-lessac-high';
  set offlineVoiceModel(String value) =>
      _p.setString('offline_voice_model', value);

  // ── Local LLM ───────────────────────────────────────────────────────────────

  /// CPU thread count for local fllama inference.
  /// Default 4: conservative for mainstream phones and safer for thermals.
  static const _keyLlmThreads = 'llm_thread_count';
  int get llmThreadCount => _p.getInt(_keyLlmThreads) ?? 4;
  set llmThreadCount(int v) => _p.setInt(_keyLlmThreads, v);

  String? get lastApprovedRequestId => _p.getString(_keyLastApprovedRequestId);
  set lastApprovedRequestId(String? value) {
    if (value != null) {
      _p.setString(_keyLastApprovedRequestId, value);
    } else {
      _p.remove(_keyLastApprovedRequestId);
    }
  }

  bool get isSkillsEquippedNotified =>
      _p.getBool('skills_equipped_notified') ?? false;
  Future<void> setSkillsEquippedNotified(bool value) =>
      _p.setBool('skills_equipped_notified', value);

  // ── Pre-install setup (provider/key collected before rootfs is ready) ────────

  /// Provider chosen in SetupFlowScreen before installation begins.
  /// Consumed by bootstrap_service and cleared after baking into gateway config.
  String? get pendingProvider => _p.getString('pending_provider');
  set pendingProvider(String? value) {
    if (value != null) {
      _p.setString('pending_provider', value);
    } else {
      _p.remove('pending_provider');
    }
  }

  /// API key entered in SetupFlowScreen before installation begins.
  /// Consumed by bootstrap_service and cleared after baking into gateway config.
  String? get pendingApiKey => _p.getString('pending_api_key');
  set pendingApiKey(String? value) {
    if (value != null) {
      _p.setString('pending_api_key', value);
    } else {
      _p.remove('pending_api_key');
    }
  }
}

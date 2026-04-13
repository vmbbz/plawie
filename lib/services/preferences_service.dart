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
  static const _keyNodeGatewayHost = 'node_gateway_host';
  static const _keyNodeGatewayPort = 'node_gateway_port';
  static const _keyNodePublicKey = 'node_ed25519_public';
  static const _keyNodeGatewayToken = 'node_gateway_token';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    if (_prefs == null) {
      throw StateError('PreferencesService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  bool get autoStartGateway => _p.getBool(_keyAutoStart) ?? false;
  set autoStartGateway(bool value) => _p.setBool(_keyAutoStart, value);

  bool get setupComplete => _p.getBool(_keySetupComplete) ?? false;
  set setupComplete(bool value) => _p.setBool(_keySetupComplete, value);

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
  bool isSkillEnabled(String skillId) => _p.getBool('skill_enabled_$skillId') ?? false;
  Future<void> setSkillEnabled(String skillId, bool enabled) => _p.setBool('skill_enabled_$skillId', enabled);

  // ── Voice & Speech ──────────────────────────────────────────────────────────

  /// TTS engine: 'piper' | 'native' | 'elevenlabs' | 'openai'
  String get ttsEngine => _p.getString('tts_engine') ?? 'piper';
  set ttsEngine(String value) => _p.setString('tts_engine', value);

  /// Speech speed multiplier (0.5–2.0). Default 1.2 to match competitor default.
  double get ttsSpeed => _p.getDouble('tts_speed') ?? 1.2;
  set ttsSpeed(double value) => _p.setDouble('tts_speed', value);

  /// Auto-restart STT after TTS finishes
  bool get continuousMode => _p.getBool('continuous_mode') ?? false;
  set continuousMode(bool value) => _p.setBool('continuous_mode', value);

  /// Silence timeout in seconds before auto-submitting (1–15)
  int get silenceTimeoutSeconds => _p.getInt('silence_timeout_seconds') ?? 5;
  set silenceTimeoutSeconds(int value) => _p.setInt('silence_timeout_seconds', value);

  /// ElevenLabs API key
  String? get elevenLabsApiKey => _p.getString('elevenlabs_api_key');
  set elevenLabsApiKey(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString('elevenlabs_api_key', value);
    } else {
      _p.remove('elevenlabs_api_key');
    }
  }

  /// ElevenLabs voice ID
  String get elevenLabsVoiceId => _p.getString('elevenlabs_voice_id') ?? 'EXAVITQu4vr4xnSDxMaL';

  set elevenLabsVoiceId(String value) => _p.setString('elevenlabs_voice_id', value);

  // ── Wake Word ───────────────────────────────────────────────────────────────

  /// Wake word mode: 'off' | 'foreground' | 'always'
  String get wakeWordMode => _p.getString('wake_word_mode') ?? 'off';
  set wakeWordMode(String value) => _p.setString('wake_word_mode', value);

  // ── Cloud TTS API Keys ──────────────────────────────────────────────────────

  /// OpenAI API key (used for TTS — separate from the gateway-injected key)
  String? get openAiApiKey => _p.getString('openai_api_key_tts');
  set openAiApiKey(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString('openai_api_key_tts', value);
    } else {
      _p.remove('openai_api_key_tts');
    }
  }

  /// OpenAI TTS voice (alloy, echo, shimmer, fable, onyx, nova, coral)
  String get openAiTtsVoice => _p.getString('openai_tts_voice') ?? 'coral';
  set openAiTtsVoice(String value) => _p.setString('openai_tts_voice', value);

  /// OpenAI TTS model
  String get openAiTtsModel => _p.getString('openai_tts_model') ?? 'gpt-4o-mini-tts';
  set openAiTtsModel(String value) => _p.setString('openai_tts_model', value);
}

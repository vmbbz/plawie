import 'package:shared_preferences/shared_preferences.dart';

/// The local LLM inference backend the user has selected.
/// - ollama: PRoot-based CPU inference (default, works everywhere)
/// - mlc: Native GPU-accelerated inference via MLC-LLM (requires compiled model)
enum LocalLlmBackend { ollama, mlc }

class PreferencesService {
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
  static const _keySelectedModel = 'selected_model';
  static const _keyLlmProvider = 'llm_provider';
  static const _keyLocalBackend = 'local_backend';
  static const _keyMlcModelId = 'mlc_model_id';
  static const _keyLlmConfigured = 'llm_configured';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get autoStartGateway => _prefs.getBool(_keyAutoStart) ?? false;
  set autoStartGateway(bool value) => _prefs.setBool(_keyAutoStart, value);

  bool get setupComplete => _prefs.getBool(_keySetupComplete) ?? false;
  set setupComplete(bool value) {
    _prefs.setBool(_keySetupComplete, value);
    // notifyListeners(); // If we decide to mixin ChangeNotifier later
  }

  bool get isLlmConfigured => _prefs.getBool(_keyLlmConfigured) ?? false;
  set isLlmConfigured(bool value) {
    _prefs.setBool(_keyLlmConfigured, value);
  }

  bool get isFirstRun => _prefs.getBool(_keyFirstRun) ?? true;
  set isFirstRun(bool value) => _prefs.setBool(_keyFirstRun, value);

  String? get dashboardUrl => _prefs.getString(_keyDashboardUrl);
  set dashboardUrl(String? value) {
    if (value != null) {
      _prefs.setString(_keyDashboardUrl, value);
    } else {
      _prefs.remove(_keyDashboardUrl);
    }
  }

  bool get nodeEnabled => _prefs.getBool(_keyNodeEnabled) ?? false;
  set nodeEnabled(bool value) => _prefs.setBool(_keyNodeEnabled, value);

  String? get nodeDeviceToken => _prefs.getString(_keyNodeDeviceToken);
  set nodeDeviceToken(String? value) {
    if (value != null) {
      _prefs.setString(_keyNodeDeviceToken, value);
    } else {
      _prefs.remove(_keyNodeDeviceToken);
    }
  }

  String? get nodeGatewayHost => _prefs.getString(_keyNodeGatewayHost);
  set nodeGatewayHost(String? value) {
    if (value != null) {
      _prefs.setString(_keyNodeGatewayHost, value);
    } else {
      _prefs.remove(_keyNodeGatewayHost);
    }
  }

  String? get nodePublicKey => _prefs.getString(_keyNodePublicKey);

  String? get nodeGatewayToken => _prefs.getString(_keyNodeGatewayToken);
  set nodeGatewayToken(String? value) {
    if (value != null && value.isNotEmpty) {
      _prefs.setString(_keyNodeGatewayToken, value);
    } else {
      _prefs.remove(_keyNodeGatewayToken);
    }
  }

  int? get nodeGatewayPort {
    final val = _prefs.getInt(_keyNodeGatewayPort);
    return val;
  }
  set nodeGatewayPort(int? value) {
    if (value != null) {
      _prefs.setInt(_keyNodeGatewayPort, value);
    } else {
      _prefs.remove(_keyNodeGatewayPort);
    }
  }

  String get selectedModel => _prefs.getString(_keySelectedModel) ?? 'gemma3:1b';
  set selectedModel(String value) => _prefs.setString(_keySelectedModel, value);

  String get llmProvider => _prefs.getString(_keyLlmProvider) ?? 'ollama';
  set llmProvider(String value) => _prefs.setString(_keyLlmProvider, value);

  // --- MLC-LLM Hybrid Backend Preferences ---

  /// Which local inference backend to use: Ollama (PRoot CPU) or MLC (Native GPU)
  LocalLlmBackend get localBackend {
    final idx = _prefs.getInt(_keyLocalBackend) ?? 0;
    return LocalLlmBackend.values[idx.clamp(0, LocalLlmBackend.values.length - 1)];
  }
  set localBackend(LocalLlmBackend value) => _prefs.setInt(_keyLocalBackend, value.index);

  /// The MLC model identifier (e.g. 'gemma-3-1b-it-q4f16_1-MLC')
  /// The MLC model identifier (e.g. 'gemma-3-1b-it-q4f16_1-MLC')
  String get mlcModelId => _prefs.getString(_keyMlcModelId) ?? 'gemma-3-1b-it-q4f16_1-MLC';
  set mlcModelId(String value) => _prefs.setString(_keyMlcModelId, value);

  /// The selected VRM avatar filename
  String get selectedAvatar => _prefs.getString('selectedAvatar') ?? 'gemini.vrm';
  set selectedAvatar(String value) => _prefs.setString('selectedAvatar', value);
}

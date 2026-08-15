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
  static const _keyGatewayRuntimeOwner = 'gateway_runtime_owner';
  static const _keyNativeGatewayDefaultCutoverApplied =
      'native_gateway_default_cutover_applied';
  static const _keyLastApprovedRequestId = 'last_approved_request_id';
  static const _keySetupInProgress = 'setup_in_progress';
  static const _keyNodeCommandContractHash = 'node_command_contract_hash';
  static const _keyLocalChatModeEnabled = 'local_chat_mode_enabled';
  static const _keyLastCloudModel = 'last_cloud_model';
  static const _keyImmersiveUiEnabled = 'immersive_ui_enabled';
  static const _keyPendingSetupId = 'pending_setup_id';
  static const _keyPendingSetupModel = 'pending_setup_model';
  static const _keyPendingApiKeyReference = 'pending_api_key_reference';
  static const _keyPendingSetupState = 'pending_setup_state';
  static const _keyPendingSetupReceiptId = 'pending_setup_receipt_id';
  static const _keyLastProviderSetupReceiptId =
      'last_provider_setup_receipt_id';
  static const _keyDynamicModelCatalogSnapshot =
      'dynamic_model_catalog_snapshot_v1';
  static const _keyAiPaymentProvider = 'ai_payment_provider';
  static const _keyX402PaymentReceipts = 'x402_payment_receipts_v1';
  static const _keyCommerceReceipts = 'commerce_receipts_v1';

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

  bool get immersiveUiEnabled => _p.getBool(_keyImmersiveUiEnabled) ?? false;
  set immersiveUiEnabled(bool value) =>
      _p.setBool(_keyImmersiveUiEnabled, value);

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

  String? get nodeCommandContractHash =>
      _p.getString(_keyNodeCommandContractHash);
  set nodeCommandContractHash(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyNodeCommandContractHash, value);
    } else {
      _p.remove(_keyNodeCommandContractHash);
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

  static const gatewayRuntimeOwnerProot = 'proot';
  static const gatewayRuntimeOwnerNativeProduction =
      'native-node-full-gateway-production';

  String get gatewayRuntimeOwner =>
      _p.getString(_keyGatewayRuntimeOwner) ??
      gatewayRuntimeOwnerNativeProduction;
  set gatewayRuntimeOwner(String value) {
    final normalized = value.trim().isEmpty
        ? gatewayRuntimeOwnerNativeProduction
        : value.trim();
    _p.setString(_keyGatewayRuntimeOwner, normalized);
  }

  bool get nativeGatewayDefaultCutoverApplied =>
      _p.getBool(_keyNativeGatewayDefaultCutoverApplied) ?? false;

  Future<bool> applyNativeGatewayDefaultCutoverIfNeeded() async {
    if (nativeGatewayDefaultCutoverApplied || !setupComplete) return false;

    final current = _p.getString(_keyGatewayRuntimeOwner);
    final shouldPromote =
        current == null || current == gatewayRuntimeOwnerProot;
    if (shouldPromote) {
      await _p.setString(
        _keyGatewayRuntimeOwner,
        gatewayRuntimeOwnerNativeProduction,
      );
    }
    await _p.setBool(_keyNativeGatewayDefaultCutoverApplied, true);
    return shouldPromote;
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

  /// Wallet-funded AI provider selected independently from BYOK providers.
  /// This is non-secret routing metadata; wallet keys never enter preferences.
  String? get aiPaymentProvider => _p.getString(_keyAiPaymentProvider);
  set aiPaymentProvider(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      _p.setString(_keyAiPaymentProvider, value.trim().toLowerCase());
    } else {
      _p.remove(_keyAiPaymentProvider);
    }
  }

  /// Redacted x402 settlement receipts. Signatures, challenges, payment
  /// headers, private keys, and provider authentication never belong here.
  List<String> get x402PaymentReceipts =>
      _p.getStringList(_keyX402PaymentReceipts) ?? const <String>[];

  Future<void> setX402PaymentReceipts(List<String> receipts) =>
      _p.setStringList(_keyX402PaymentReceipts, receipts);

  /// Redacted, local commerce operation records. These are operational
  /// receipts only; they are not a platform revenue ledger.
  List<String> get commerceReceipts =>
      _p.getStringList(_keyCommerceReceipts) ?? const <String>[];

  Future<void> setCommerceReceipts(List<String> receipts) =>
      _p.setStringList(_keyCommerceReceipts, receipts);

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

  bool get localChatModeEnabled =>
      _p.getBool(_keyLocalChatModeEnabled) ?? false;
  set localChatModeEnabled(bool value) =>
      _p.setBool(_keyLocalChatModeEnabled, value);

  String? get lastCloudModel => _p.getString(_keyLastCloudModel);
  set lastCloudModel(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyLastCloudModel, value);
    } else {
      _p.remove(_keyLastCloudModel);
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

  /// Speech speed multiplier (0.5–2.0). Keep provider-native speech at 1.0
  /// unless the user explicitly changes it; some streamed providers artifact
  /// when every request is forced through a speed override.
  bool get hasTtsSpeedOverride => _p.containsKey('tts_speed');
  double get ttsSpeed => _p.getDouble('tts_speed') ?? 1.0;
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

  String get gatewayVoiceId => _p.getString('gateway_voice_id') ?? '';
  set gatewayVoiceId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _p.remove('gateway_voice_id');
    } else {
      _p.setString('gateway_voice_id', trimmed);
    }
  }

  // ── Wake Word ───────────────────────────────────────────────────────────────

  /// Wake word mode: 'off' | 'foreground' | 'always'
  String get wakeWordMode => _p.getString('wake_word_mode') ?? 'off';
  set wakeWordMode(String value) => _p.setString('wake_word_mode', value);

  // ── TTS Engine & Offline Models ──────────────────────────────────────────────

  /// Selected TTS engine. Android GTM normalizes this to 'gateway'; 'offline'
  /// is retained only for old preferences and future local voice packs.
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

  /// Legacy plaintext API-key slot used by releases before the secure setup
  /// handoff. Only ProviderSetupService may read it during one-time migration.
  String? get legacyPendingApiKey => _p.getString('pending_api_key');
  set legacyPendingApiKey(String? value) {
    if (value != null) {
      _p.setString('pending_api_key', value);
    } else {
      _p.remove('pending_api_key');
    }
  }

  String? get pendingSetupId => _p.getString(_keyPendingSetupId);
  set pendingSetupId(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyPendingSetupId, value);
    } else {
      _p.remove(_keyPendingSetupId);
    }
  }

  String? get pendingSetupModel => _p.getString(_keyPendingSetupModel);
  set pendingSetupModel(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyPendingSetupModel, value);
    } else {
      _p.remove(_keyPendingSetupModel);
    }
  }

  String? get pendingApiKeyReference =>
      _p.getString(_keyPendingApiKeyReference);
  set pendingApiKeyReference(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyPendingApiKeyReference, value);
    } else {
      _p.remove(_keyPendingApiKeyReference);
    }
  }

  String? get pendingSetupState => _p.getString(_keyPendingSetupState);
  set pendingSetupState(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyPendingSetupState, value);
    } else {
      _p.remove(_keyPendingSetupState);
    }
  }

  String? get pendingSetupReceiptId => _p.getString(_keyPendingSetupReceiptId);
  set pendingSetupReceiptId(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyPendingSetupReceiptId, value);
    } else {
      _p.remove(_keyPendingSetupReceiptId);
    }
  }

  String? get lastProviderSetupReceiptId =>
      _p.getString(_keyLastProviderSetupReceiptId);
  set lastProviderSetupReceiptId(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyLastProviderSetupReceiptId, value);
    } else {
      _p.remove(_keyLastProviderSetupReceiptId);
    }
  }

  /// Non-secret, versioned provider/model metadata cache.
  String? get dynamicModelCatalogSnapshotJson =>
      _p.getString(_keyDynamicModelCatalogSnapshot);
  set dynamicModelCatalogSnapshotJson(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(_keyDynamicModelCatalogSnapshot, value);
    } else {
      _p.remove(_keyDynamicModelCatalogSnapshot);
    }
  }
}

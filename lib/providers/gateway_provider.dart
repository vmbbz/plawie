import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gateway_state.dart';
import '../models/agent_info.dart';
import '../models/setup_state.dart';
import '../services/gateway_service.dart' as svc;
import '../services/gateway_skill_proxy.dart';
import '../services/bootstrap_service.dart';
import '../services/model_provider_catalog.dart';
import '../services/dynamic_model_catalog.dart';
import '../services/skill_provisioning_service.dart';

class GatewayProvider extends ChangeNotifier {
  final svc.GatewayService _gatewayService = svc.GatewayService();
  StreamSubscription? _subscription;
  GatewayState _state = const GatewayState();

  GatewayState get state => _state;
  Stream<Map<String, dynamic>> get gatewayEventStream =>
      _gatewayService.gatewayEventStream;

  /// The list of methods supported by the current gateway connection.
  List<String> get supportedMethods => _gatewayService.supportedMethods;

  /// Detailed health metrics from the gateway RPC.
  Map<String, dynamic>? get detailedHealth => _state.detailedHealth;

  /// Native dependency provisioning results for installed/default skills.
  Map<String, dynamic>? get skillProvisioning => _state.skillProvisioning;

  /// Android default skill readiness summary for GTM launch gates.
  Map<String, dynamic>? get androidDefaultReadiness =>
      _state.androidDefaultReadiness;

  /// Active skills reported by the gateway.
  List<Map<String, dynamic>>? get activeSkills => _state.activeSkills;

  /// Send a message to the OpenClaw gateway and stream the response.
  Stream<String> sendMessage(
    String message, {
    String model = ModelProviderCatalog.defaultCloudFallbackModel,
    List<Map<String, dynamic>>? conversationHistory,
    String? sessionKey,
    bool explicitToolCompatibilityProbe = false,
  }) {
    return _gatewayService.sendMessage(message,
        model: model,
        conversationHistory: conversationHistory,
        sessionKey: sessionKey,
        explicitToolCompatibilityProbe: explicitToolCompatibilityProbe);
  }

  /// Send an image + optional text directly to the local vision model on :8081.
  /// Requires a multimodal model (LLaVA, Qwen2-VL) to be active and ready.
  Stream<String> sendVisionMessage(
    String prompt,
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) {
    return _gatewayService.sendVisionMessage(prompt, imageBase64,
        mimeType: mimeType);
  }

  /// Sends an image to the gateway for Gemini/GPT-4o cloud vision.
  Stream<String> sendCloudImageMessage(
    String prompt,
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) {
    return _gatewayService.sendCloudImageMessage(prompt, imageBase64,
        mimeType: mimeType);
  }

  /// Fetch available OpenClaw agents from the gateway at runtime.
  /// Returns an empty list silently if the gateway is not yet connected.
  Future<List<AgentInfo>> fetchAgents() => _gatewayService.fetchAgents();

  /// Fetch active sessions from the gateway.
  Future<List<Map<String, dynamic>>> fetchSessions() =>
      _gatewayService.fetchSessions();

  /// Send a short MP4 clip to the gateway for Gemini video understanding.
  Stream<String> sendCloudVideoMessage(String prompt, String mp4Base64) =>
      _gatewayService.sendCloudVideoMessage(prompt, mp4Base64);

  GatewayProvider() {
    _subscription = _gatewayService.stateStream.listen((state) {
      _state = state;
      notifyListeners();
    });
    // Wire the GatewaySkillProxy singleton so all skill pages can call
    // gateway.invoke('skills.execute', ...) without needing BuildContext.
    GatewaySkillProxy().attach(this);
    // Check if gateway is already running (e.g. after app restart)
    _gatewayService.init();
  }

  Future<void> start() async {
    await _gatewayService.start();
  }

  Future<void> stop() async {
    await _gatewayService.stop();
  }

  Future<bool> checkHealth() async {
    return _gatewayService.checkHealth();
  }

  /// Write API key, persist model, THEN start the gateway.
  /// All config must be written before start() so the gateway reads the correct values.
  /// Note: agentName is kept as parameter for UI compatibility but OpenClaw schema
  /// does not support agents.defaults.name, so it is not persisted.
  Future<void> configureAndStart({
    required String provider,
    required String apiKey,
    String? agentName,
  }) async {
    // Step 1: Write API key to config files
    await _gatewayService.configureApiKey(provider, apiKey);
    // Step 2: Set the correct primary model for this provider
    await _gatewayService.persistModel(
      _gatewayService.getModelForProvider(provider),
    );
    // Step 3: Start the gateway (it will read the freshly-written config)
    await _gatewayService.start();
  }

  /// Write an API key without starting the gateway.
  Future<void> configureApiKey(
    String provider,
    String key, {
    bool runBackgroundOnboard = true,
  }) async {
    await _gatewayService.configureApiKey(
      provider,
      key,
      runBackgroundOnboard: runBackgroundOnboard,
    );
  }

  Future<SkillProvisioningReport> configureAndroidDefaultSkill({
    required String skillId,
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
    SkillProvisioningProgressCallback? onProgress,
  }) async {
    final report = await SkillProvisioningService.instance.auditAndProvision(
      skillId: skillId,
      envValues: envValues,
      configValues: configValues,
      onProgress: onProgress,
    );
    if (report.reloadRecommended) {
      await _gatewayService.applyActiveOwnerConfigChange(
        'Android skill config: $skillId',
      );
    }
    _gatewayService.refreshRpcDiscovery();
    unawaited(_gatewayService.checkHealth());
    return report;
  }

  Future<SkillProvisioningReport> configureOptionalNativeEnvironment({
    required String skillId,
    Map<String, String> values = const <String, String>{},
    List<String> clearKeys = const <String>[],
  }) async {
    final report =
        await SkillProvisioningService.instance.applyOptionalNativeEnvironment(
      skillId: skillId,
      values: values,
      clearKeys: clearKeys,
    );
    if (report.reloadRecommended) {
      await _gatewayService.applyActiveOwnerConfigChange(
        'Optional Native skill config: $skillId',
      );
    }
    _gatewayService.refreshRpcDiscovery();
    unawaited(_gatewayService.checkHealth());
    return report;
  }

  /// Retrieve the authenticated Dashboard URL containing the ?token= query parameter.
  Future<String?> fetchAuthenticatedDashboardUrl() {
    return _gatewayService.fetchAuthenticatedDashboardUrl();
  }

  /// Persist the selected model to openclaw.json.
  Future<void> persistModel(String model) async {
    await _gatewayService.persistModel(model);
  }

  /// Persist a model obtained from the dynamic provider catalog through the
  /// same credential and native-runtime policy as the Gateway service.
  Future<void> persistDynamicModel(DynamicModelRecord model) async {
    await _gatewayService.persistDynamicModel(model);
  }

  /// Force a re-fetch of the authenticated Dashboard URL.
  Future<String?> refreshDashboardUrl() {
    return _gatewayService.fetchAuthenticatedDashboardUrl(force: true);
  }

  Future<bool> approveLocalDashboardPairingRequest(String requestId) {
    return _gatewayService.approveLocalDashboardPairingRequest(requestId);
  }

  /// Invoke a generic RPC method on the gateway.
  Future<Map<String, dynamic>> invoke(String method,
      [Map<String, dynamic>? params]) {
    return _gatewayService.invoke(method, params);
  }

  Future<String> resolveOrCreateGatewaySessionKey({
    required String localSessionId,
    String? existingSessionKey,
    bool forceNew = false,
  }) {
    return _gatewayService.resolveOrCreateGatewaySessionKey(
      localSessionId: localSessionId,
      existingSessionKey: existingSessionKey,
      forceNew: forceNew,
    );
  }

  Future<svc.TalkSpeakPlayback> speakTextViaTalk(String text) =>
      _gatewayService.speakTextViaTalk(text);

  Future<Map<String, dynamic>> getTalkCatalog() =>
      _gatewayService.getTalkCatalog();

  Future<Map<String, dynamic>> getTtsProviders() =>
      _gatewayService.getTtsProviders();

  Future<Map<String, dynamic>> getTtsPersonas() =>
      _gatewayService.getTtsPersonas();

  Future<Map<String, dynamic>> setTtsProvider(String providerId) =>
      _gatewayService.setTtsProvider(providerId);

  Future<Map<String, dynamic>> setTtsPersona(String? personaId) =>
      _gatewayService.setTtsPersona(personaId);

  Future<Map<String, dynamic>> createTalkRealtimeRelaySession({
    String? sessionKey,
    String? language,
    String? provider,
    String? model,
    String? voice,
  }) {
    return _gatewayService.createTalkRealtimeRelaySession(
      sessionKey: sessionKey,
      language: language,
      provider: provider,
      model: model,
      voice: voice,
    );
  }

  Future<void> appendTalkSessionAudio({
    required String sessionId,
    required String audioBase64,
    double? timestamp,
  }) {
    return _gatewayService.appendTalkSessionAudio(
      sessionId: sessionId,
      audioBase64: audioBase64,
      timestamp: timestamp,
    );
  }

  Future<void> cancelTalkSessionTurn(String sessionId, {String? reason}) =>
      _gatewayService.cancelTalkSessionTurn(sessionId, reason: reason);

  Future<void> closeTalkSession(String sessionId) =>
      _gatewayService.closeTalkSession(sessionId);

  /// Force a WebSocket disconnection to trigger a fresh handshake on next send.
  void disconnectWebSocket() {
    _gatewayService.disconnectWebSocket();
  }

  /// Reset the RPC discovery flag so health and skills.status
  /// are re-queried on the next health-check tick (~15 s).
  void refreshRpcDiscovery() {
    _gatewayService.refreshRpcDiscovery();
  }

  /// Research and repair any gateway corruption programmatically in the background.
  void repairAndRestart() {
    if (_state.isRepairing) return;

    // Fire and forget background repair
    unawaited(() async {
      _gatewayService.setRepairing(true,
          message: 'Starting repair...', progress: 0.0);
      try {
        final bootstrap = BootstrapService();
        bool hasError = false;

        await bootstrap.repairOpenClaw(onProgress: (state) {
          _gatewayService.addLog('[REPAIR] ${state.message}');
          _gatewayService.setRepairing(
            true,
            message: state.message,
            progress: state.progress,
          );
          if (state.step == SetupStep.error) {
            hasError = true;
          }
        });

        // Restart only if repair finished without error
        if (!hasError) {
          await start();
        }
      } catch (e) {
        _gatewayService.addLog('[ERROR] Background repair failed: $e');
      } finally {
        _gatewayService.setRepairing(false, message: '', progress: 0.0);
      }
    }());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _gatewayService.dispose();
    super.dispose();
  }
}

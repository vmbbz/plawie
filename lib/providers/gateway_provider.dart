import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gateway_state.dart';
import '../models/agent_info.dart';
import '../services/gateway_service.dart' as svc;
import '../services/gateway_skill_proxy.dart';

class GatewayProvider extends ChangeNotifier {
  final svc.GatewayService _gatewayService = svc.GatewayService();
  StreamSubscription? _subscription;
  GatewayState _state = const GatewayState();

  GatewayState get state => _state;

  /// The list of methods supported by the current gateway connection.
  List<String> get supportedMethods => _gatewayService.supportedMethods;

  /// Detailed health metrics from the gateway RPC.
  Map<String, dynamic>? get detailedHealth => _state.detailedHealth;

  /// Active skills reported by the gateway.
  List<Map<String, dynamic>>? get activeSkills => _state.activeSkills;

  /// Send a message to the OpenClaw gateway and stream the response.
  Stream<String> sendMessage(String message, {
    String model = 'google/gemini-3.1-pro-preview',
    List<Map<String, dynamic>>? conversationHistory,
  }) {
    return _gatewayService.sendMessage(message,
        model: model, conversationHistory: conversationHistory);
  }

  /// Send an image + optional text directly to the local vision model on :8081.
  /// Requires a multimodal model (LLaVA, Qwen2-VL) to be active and ready.
  Stream<String> sendVisionMessage(
    String prompt,
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) {
    return _gatewayService.sendVisionMessage(prompt, imageBase64, mimeType: mimeType);
  }

  /// Sends an image to the gateway for Gemini/GPT-4o cloud vision.
  Stream<String> sendCloudImageMessage(
    String prompt,
    String imageBase64, {
    String mimeType = 'image/jpeg',
  }) {
    return _gatewayService.sendCloudImageMessage(prompt, imageBase64, mimeType: mimeType);
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
  Future<void> configureApiKey(String provider, String key) async {
    await _gatewayService.configureApiKey(provider, key);
  }

  /// Retrieve the authenticated Dashboard URL containing the ?token= query parameter.
  Future<String?> fetchAuthenticatedDashboardUrl() {
    return _gatewayService.fetchAuthenticatedDashboardUrl();
  }

  /// Persist the selected model to openclaw.json.
  Future<void> persistModel(String model) async {
    await _gatewayService.persistModel(model);
  }

  /// Force a re-fetch of the authenticated Dashboard URL.
  Future<String?> refreshDashboardUrl() {
    return _gatewayService.fetchAuthenticatedDashboardUrl(force: true);
  }

  /// Invoke a generic RPC method on the gateway.
  Future<Map<String, dynamic>> invoke(String method, [Map<String, dynamic>? params]) {
    return _gatewayService.invoke(method, params);
  }

  /// Force a WebSocket disconnection to trigger a fresh handshake on next send.
  void disconnectWebSocket() {
    _gatewayService.disconnectWebSocket();
  }


  @override
  void dispose() {
    _subscription?.cancel();
    _gatewayService.dispose();
    super.dispose();
  }
}

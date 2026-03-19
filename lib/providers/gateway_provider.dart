import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gateway_state.dart';
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

  /// Send a message to the OpenClaw gateway and stream the response
  Stream<String> sendMessage(String message, {String model = 'google/gemini-3.1-pro-preview'}) {
    return _gatewayService.sendMessage(message, model: model);
  }

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


  @override
  void dispose() {
    _subscription?.cancel();
    _gatewayService.dispose();
    super.dispose();
  }
}

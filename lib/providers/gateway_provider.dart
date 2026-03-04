import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gateway_state.dart';
import '../services/gateway_service.dart' as svc;

class GatewayProvider extends ChangeNotifier {
  final svc.GatewayService _gatewayService = svc.GatewayService();
  StreamSubscription? _subscription;
  GatewayState _state = const GatewayState();

  GatewayState get state => _state;

  /// Send a message to the OpenClaw gateway and stream the SSE response
  Stream<String> sendMessage(String message) {
    return _gatewayService.sendMessage(message);
  }

  GatewayProvider() {
    _subscription = _gatewayService.stateStream.listen((state) {
      _state = state;
      notifyListeners();
    });
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

  /// Write an API key to openclaw.json and start the gateway.
  /// This is the single entry point for the onboarding wizard.
  Future<void> configureAndStart({
    required String provider,
    required String apiKey,
    String? agentName,
  }) async {
    await _gatewayService.configureApiKey(provider, apiKey);
    await _gatewayService.start();
  }

  /// Write an API key without starting the gateway.
  Future<void> configureApiKey(String provider, String key) async {
    await _gatewayService.configureApiKey(provider, key);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _gatewayService.dispose();
    super.dispose();
  }
}

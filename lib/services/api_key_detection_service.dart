import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'native_bridge.dart';

/// Intelligent detection of API keys and gateway status
/// Provides smart UI suggestions based on current state
class ApiKeyDetectionService {
  final Logger _logger = Logger();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // State streams
  final _stateController = StreamController<ApiState>.broadcast();
  Stream<ApiState> get apiStateStream => _stateController.stream;
  
  ApiState _currentState = ApiState.checking;
  ApiState get currentState => _currentState;
  
  // API key storage keys
  static const String _claudeKey = 'claude_api_key';
  static const String _groqKey = 'groq_api_key';
  static const String _openrouterKey = 'openrouter_api_key';
  
  Future<void> initialize() async {
    await _checkApiKeys();
    await _checkGatewayStatus();
  }
  
  /// Check if any API keys are configured
  Future<void> _checkApiKeys() async {
    try {
      final claudeKey = await _storage.read(key: _claudeKey);
      final groqKey = await _storage.read(key: _groqKey);
      final openrouterKey = await _storage.read(key: _openrouterKey);
      
      final hasClaude = claudeKey?.isNotEmpty == true;
      final hasGroq = groqKey?.isNotEmpty == true;
      final hasOpenRouter = openrouterKey?.isNotEmpty == true;
      
      if (hasClaude || hasGroq || hasOpenRouter) {
        _updateState(ApiState.configured);
      } else {
        _updateState(ApiState.noKeys);
      }
      
      _logger.i('API Keys - Claude: $hasClaude, Groq: $hasGroq, OpenRouter: $hasOpenRouter');
    } catch (e) {
      _logger.e('Error checking API keys: $e');
      _updateState(ApiState.error);
    }
  }
  
  /// Check gateway running status
  Future<void> _checkGatewayStatus() async {
    try {
      final isRunning = await NativeBridge.isGatewayRunning();
      
      if (_currentState == ApiState.configured) {
        if (isRunning) {
          _updateState(ApiState.gatewayRunning);
        } else {
          _updateState(ApiState.configuredGatewayDown);
        }
      }
      
      _logger.i('Gateway status: ${isRunning ? "running" : "down"}');
    } catch (e) {
      _logger.e('Error checking gateway status: $e');
    }
  }
  
  /// Store API key
  Future<void> setApiKey(String provider, String apiKey) async {
    try {
      final key = _getKeyForProvider(provider);
      await _storage.write(key: key, value: apiKey);
      await _checkApiKeys();
      await _checkGatewayStatus();
    } catch (e) {
      _logger.e('Error storing API key: $e');
      _updateState(ApiState.error);
    }
  }
  
  /// Get stored API key
  Future<String?> getApiKey(String provider) async {
    final key = _getKeyForProvider(provider);
    return await _storage.read(key: key);
  }
  
  /// Auto-start gateway if API keys are configured
  Future<bool> autoStartGateway() async {
    try {
      if (_currentState == ApiState.configuredGatewayDown) {
        final success = await NativeBridge.startGateway();
        if (success) {
          await Future.delayed(const Duration(seconds: 3));
          await _checkGatewayStatus();
        }
        return success;
      }
      return false;
    } catch (e) {
      _logger.e('Error auto-starting gateway: $e');
      return false;
    }
  }
  
  /// Get recommended action based on current state
  RecommendedAction getRecommendedAction() {
    switch (_currentState) {
      case ApiState.noKeys:
        return RecommendedAction.addApiKey;
      case ApiState.configuredGatewayDown:
        return RecommendedAction.startGateway;
      case ApiState.gatewayRunning:
        return RecommendedAction.useGateway;
      case ApiState.configured:
        return RecommendedAction.startGateway;
      case ApiState.checking:
        return RecommendedAction.waiting;
      case ApiState.error:
        return RecommendedAction.troubleshoot;
    }
  }
  
  /// Get user-friendly message for current state
  String getStatusMessage() {
    switch (_currentState) {
      case ApiState.noKeys:
        return 'No API keys configured. Add credits to get started!';
      case ApiState.configuredGatewayDown:
        return 'API keys configured, but gateway is offline. Starting automatically...';
      case ApiState.gatewayRunning:
        return 'Gateway is running and ready to use!';
      case ApiState.configured:
        return 'API keys configured. Starting gateway...';
      case ApiState.checking:
        return 'Checking configuration...';
      case ApiState.error:
        return 'Configuration error. Please check your setup.';
    }
  }
  
  void _updateState(ApiState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }
  
  String _getKeyForProvider(String provider) {
    switch (provider.toLowerCase()) {
      case 'claude':
        return _claudeKey;
      case 'groq':
        return _groqKey;
      case 'openrouter':
        return _openrouterKey;
      default:
        throw ArgumentError('Unknown provider: $provider');
    }
  }
  
  void dispose() {
    _stateController.close();
  }
}

enum ApiState {
  checking,
  noKeys,
  configured,
  configuredGatewayDown,
  gatewayRunning,
  error,
}

enum RecommendedAction {
  addApiKey,
  startGateway,
  useGateway,
  waiting,
  troubleshoot,
}

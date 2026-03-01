import 'dart:developer' as developer;
import 'native_bridge.dart';
import 'preferences_service.dart';

/// Manages the MLC-LLM native GPU inference engine lifecycle.
///
/// MLC-LLM runs **outside** PRoot on the Android host, using OpenCL/Vulkan
/// for hardware-accelerated inference. It exposes an OpenAI-compatible HTTP
/// server on 127.0.0.1:8000 so that OpenClaw (inside PRoot) can connect
/// to it identically to how it connects to Ollama.
class MlcService {
  static void _log(String message, {Object? error}) {
    developer.log(message, name: 'MlcService', error: error);
  }

  /// Start the native MLC engine with the user's selected model.
  /// This launches the engine + NanoHTTPD OpenAI proxy on :8000.
  static Future<void> startMlcEngine() async {
    try {
      final prefs = PreferencesService();
      await prefs.init();
      await NativeBridge.startMLCEngine(modelId: prefs.mlcModelId);
      _log('MLC engine started with model: ${prefs.mlcModelId}');
    } catch (e) {
      _log('Failed to start MLC engine', error: e);
      rethrow;
    }
  }

  /// Stop the MLC engine and its HTTP proxy.
  static Future<void> stopMlcEngine() async {
    try {
      await NativeBridge.stopMLCEngine();
      _log('MLC engine stopped');
    } catch (e) {
      _log('Failed to stop MLC engine', error: e);
    }
  }

  /// Check if the MLC engine is currently running.
  static Future<bool> isRunning() async {
    try {
      return await NativeBridge.isMLCRunning();
    } catch (_) {
      return false;
    }
  }
}

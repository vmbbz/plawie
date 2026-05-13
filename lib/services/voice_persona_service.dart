import 'package:flutter/foundation.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

/// Voice Persona service — uses official OpenClaw CLI for persona management.
/// Personas are provider-agnostic; the gateway maps them to ElevenLabs/OpenAI/Piper voices.
class VoicePersonaService {
  static final VoicePersonaService _instance = VoicePersonaService._internal();
  factory VoicePersonaService() => _instance;
  VoicePersonaService._internal();

  static const List<String> commonPersonas = [
    'default',
    'friendly',
    'warm',
    'professional',
    'authoritative',
    'casual',
    'enthusiastic',
    'whispering',
  ];

  /// Set the current voice persona (affects all future TTS)
  Future<void> setPersona(String persona) async {
    try {
      debugPrint('VoicePersonaService: Switching to persona: $persona');
      
      // 1. Update the OpenClaw config via CLI
      await NativeBridge.runInProot(
        'openclaw config set messages.tts.persona "$persona"',
      );
      
      // 2. Persist in Flutter preferences for immediate UI state recovery
      final prefs = PreferencesService();
      prefs.currentTtsPersona = persona;

      // 3. Hot-reload the gateway so it takes effect immediately
      await NativeBridge.runInProot('openclaw reload');
      
      debugPrint('VoicePersonaService: Persona "$persona" applied successfully.');
    } catch (e) {
      debugPrint('VoicePersonaService: Failed to set persona: $e');
    }
  }

  /// Get current persona (local cache for speed, syncs with gateway on set)
  String getCurrentPersonaSync() {
    return PreferencesService().currentTtsPersona;
  }

  /// Switch between Cloud (Gateway) and Offline (Sherpa-ONNX) TTS
  Future<void> setTtsEngine(String engine) async {
    try {
      debugPrint('VoicePersonaService: Switching TTS engine to: $engine');
      
      final provider = engine == 'offline' ? 'sherpa-onnx' : 'elevenlabs'; // default cloud provider
      
      await NativeBridge.runInProot(
        'openclaw config set messages.tts.provider "$provider"',
      );
      
      PreferencesService().ttsEngine = engine;
      await NativeBridge.runInProot('openclaw reload');
    } catch (e) {
      debugPrint('VoicePersonaService: Failed to set TTS engine: $e');
    }
  }

  /// Configure the gateway to use a specific offline model file
  Future<void> applyOfflineModel(String modelId) async {
    try {
      final modelPath = '/root/.openclaw/models/tts/$modelId.onnx';
      debugPrint('VoicePersonaService: Applying offline model: $modelPath');
      
      // Map the persona to use this local file
      await NativeBridge.runInProot(
        'openclaw config set messages.tts.personas.default.model "$modelPath"',
      );
      
      PreferencesService().offlineVoiceModel = modelId;
      await NativeBridge.runInProot('openclaw reload');
    } catch (e) {
      debugPrint('VoicePersonaService: Failed to apply offline model: $e');
    }
  }
}

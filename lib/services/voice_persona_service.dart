import 'package:flutter/foundation.dart';
import 'gateway_service.dart';
import 'openclaw_service.dart';
import 'preferences_service.dart';
import 'voice_model_service.dart';

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

      // 1. Persist the active owner's OpenClaw config without assuming PRoot.
      await OpenClawCommandService.setConfigValue(
        'messages.tts.persona',
        persona,
      );

      // 2. Persist in Flutter preferences for immediate UI state recovery
      final prefs = PreferencesService();
      prefs.currentTtsPersona = persona;

      // 3. Apply through the live Gateway RPC when available.
      try {
        await GatewayService().setTtsPersona(persona);
      } catch (_) {
        await OpenClawCommandService.reloadGateway(
          reason: 'TTS persona update',
        );
      }

      debugPrint(
          'VoicePersonaService: Persona "$persona" applied successfully.');
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

      final provider = engine == 'offline'
          ? 'sherpa-onnx'
          : 'elevenlabs'; // default cloud provider

      await OpenClawCommandService.setConfigValue(
        'messages.tts.provider',
        provider,
      );

      PreferencesService().ttsEngine = engine;
      try {
        await GatewayService().setTtsProvider(provider);
      } catch (_) {
        await OpenClawCommandService.reloadGateway(
          reason: 'TTS provider update',
        );
      }
    } catch (e) {
      debugPrint('VoicePersonaService: Failed to set TTS engine: $e');
    }
  }

  /// Configure the gateway to use a specific offline model file
  Future<void> applyOfflineModel(String modelId) async {
    try {
      final modelPath =
          await VoiceModelService().gatewayModelPathForActiveOwner(modelId);
      debugPrint('VoicePersonaService: Applying offline model: $modelPath');

      // Map the persona to use this local file.
      await OpenClawCommandService.setConfigValue(
        'messages.tts.personas.default.model',
        modelPath,
      );

      PreferencesService().offlineVoiceModel = modelId;
      await OpenClawCommandService.reloadGateway(
        reason: 'offline TTS model update',
      );
    } catch (e) {
      debugPrint('VoicePersonaService: Failed to apply offline model: $e');
    }
  }
}

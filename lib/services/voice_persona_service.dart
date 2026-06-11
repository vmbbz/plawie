import 'package:flutter/foundation.dart';
import 'gateway_service.dart';
import 'openclaw_service.dart';
import 'preferences_service.dart';
import 'voice_model_service.dart';

/// Voice Persona service.
/// Personas are provider-agnostic; the Gateway Talk catalog maps them to the
/// active speech provider.
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

  /// Normalize legacy engine selections to the production Gateway Talk lane.
  ///
  /// Older builds exposed an Offline/Sherpa toggle before the Android runtime
  /// and model pack were release-ready. The GTM Android build keeps that lane
  /// parked, so this method preserves the public caller surface while repairing
  /// stale preferences/config toward Gateway voice.
  Future<void> setTtsEngine(String engine) async {
    try {
      final normalized = engine.trim().toLowerCase();
      if (normalized != 'gateway') {
        debugPrint(
            'VoicePersonaService: "$engine" TTS engine is not installed in this Android build; using Gateway.');
      }
      PreferencesService().ttsEngine = 'gateway';
      await GatewayService().hardenGatewayConfigViaCli(
        allowReload: false,
        reason: 'gateway voice engine selected',
      );
    } catch (e) {
      debugPrint('VoicePersonaService: Failed to set TTS engine: $e');
    }
  }

  /// Configure a specific offline model file.
  ///
  /// This is retained for future/post-GTM local voice packs, but is no longer
  /// exposed as a fresh-user Android release path.
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

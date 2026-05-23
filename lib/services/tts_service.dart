import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'audio_playback_service.dart';
import 'preferences_service.dart';
import 'voice_persona_service.dart';

/// Lean TTS facade — now 100% relies on OpenClaw Gateway TTS.
/// The gateway handles text → MP3 generation and returns a playable URL.
/// This class manages the centralized AudioPlaybackService to bridge
/// gateway audio with UI hooks (like VRM lip-sync).
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  TtsService._internal() {
    _playback.onStart = () => onStart?.call();
    _playback.onComplete = () => onComplete?.call();
  }

  final AudioPlaybackService _playback = AudioPlaybackService();
  final VoicePersonaService _personaService = VoicePersonaService();
  static const MethodChannel _nativeTtsChannel =
      MethodChannel('plawie/native_tts');
  bool _nativeSpeaking = false;

  /// Fires when TTS starts speaking (used by VRM lip-sync).
  Function? onStart;

  /// Fires when TTS finishes speaking (used by VRM + continuous mode).
  Function? onComplete;

  // ── Voice Persona Support ──────────────────────────────────────────────────

  /// Set the character/mood of the gateway's voice
  Future<void> setVoicePersona(String persona) async {
    await _personaService.setPersona(persona);
  }

  /// Get the active persona name
  String get currentPersona => _personaService.getCurrentPersonaSync();

  /// List of personas recognized by the OpenClaw gateway
  List<String> get availablePersonas => VoicePersonaService.commonPersonas;

  /// Direct text speaking for local/offline paths.
  ///
  /// Gateway talk mode still uses [speakBytes]/[speakUrl]. Local NDK mode has no
  /// gateway TTS stream, so this falls back to Android's native TextToSpeech
  /// engine and keeps the same onStart/onComplete hooks for avatar lip sync.
  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    debugPrint('TtsService: Speaking via native Android TTS: $clean');
    _nativeSpeaking = true;
    onStart?.call();
    try {
      await _nativeTtsChannel.invokeMethod('speak', {
        'text': clean,
        'speed': PreferencesService().ttsSpeed,
      });
    } catch (e) {
      debugPrint('TtsService: Native TTS failed: $e');
    } finally {
      _nativeSpeaking = false;
      onComplete?.call();
    }
  }

  /// Play a direct MP3 URL from the Gateway
  Future<void> speakUrl(String url) async {
    debugPrint('TtsService: Playing gateway audio: $url');
    await _playback.playUrl(url);
  }

  /// Play direct synthesized bytes from gateway talk.speak / tts.convert.
  Future<void> speakBytes(Uint8List bytes) async {
    debugPrint(
        'TtsService: Playing gateway audio bytes (${bytes.length} bytes)');
    await _playback.playBytes(bytes);
  }

  Future<void> stop() async {
    _nativeSpeaking = false;
    try {
      await _nativeTtsChannel.invokeMethod('stop');
    } catch (_) {}
    await _playback.stop();
  }

  bool get isReady => true; // Gateway path is always ready

  bool get isSpeaking => _playback.isPlaying || _nativeSpeaking;

  /// Deprecated: Local engines removed in v2.0-beta.1 cleanup
  bool get isUsingFallback => false;
  Future<bool> isModelDownloaded() async => true;
  Future<void> init({bool forceDownload = false}) async {}
  set onDownloadProgress(Function(double)? fn) {}
}

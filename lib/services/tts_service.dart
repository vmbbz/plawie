import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'audio_playback_service.dart';
import 'preferences_service.dart';
import 'voice_persona_service.dart';

/// Invalidates synthesized audio that belongs to an older playback request.
///
/// Gateway synthesis is asynchronous, so a stopped sentence can otherwise
/// arrive late and restart after the user has begun a newer turn.
@visibleForTesting
class TtsPlaybackGenerationGate {
  int _generation = 0;

  int get generation => _generation;

  bool claim(int expectedGeneration) {
    if (expectedGeneration != _generation) return false;
    _generation++;
    return true;
  }

  void invalidate() {
    _generation++;
  }
}

/// Lean TTS facade — now 100% relies on OpenClaw Gateway TTS.
/// The gateway handles text → MP3 generation and returns a playable URL.
/// This class manages the centralized AudioPlaybackService to bridge
/// gateway audio with UI hooks (like VRM lip-sync).
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  TtsService._internal() {
    _playback.onStart = _notifyStart;
    _playback.onComplete = _notifyComplete;
  }

  final AudioPlaybackService _playback = AudioPlaybackService();
  final VoicePersonaService _personaService = VoicePersonaService();
  final TtsPlaybackGenerationGate _playbackGate =
      TtsPlaybackGenerationGate();
  static const MethodChannel _nativeTtsChannel =
      MethodChannel('plawie/native_tts');
  bool _nativeSpeaking = false;

  /// Fires when TTS starts speaking (used by VRM lip-sync).
  Function? onStart;

  /// Fires when TTS finishes speaking (used by VRM + continuous mode).
  Function? onComplete;
  final List<VoidCallback> _startListeners = [];
  final List<VoidCallback> _completeListeners = [];

  void addStartListener(VoidCallback listener) {
    if (!_startListeners.contains(listener)) _startListeners.add(listener);
  }

  void removeStartListener(VoidCallback listener) {
    _startListeners.remove(listener);
  }

  void addCompleteListener(VoidCallback listener) {
    if (!_completeListeners.contains(listener)) {
      _completeListeners.add(listener);
    }
  }

  void removeCompleteListener(VoidCallback listener) {
    _completeListeners.remove(listener);
  }

  void _notifyStart() {
    onStart?.call();
    for (final listener in List<VoidCallback>.from(_startListeners)) {
      listener();
    }
  }

  void _notifyComplete() {
    onComplete?.call();
    for (final listener in List<VoidCallback>.from(_completeListeners)) {
      listener();
    }
  }

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
  Future<bool> speak(
    String text, {
    int? expectedGeneration,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    final generation = expectedGeneration ?? _playbackGate.generation;
    if (!_playbackGate.claim(generation)) return false;
    debugPrint('TtsService: Speaking via native Android TTS: $clean');
    _nativeSpeaking = true;
    _notifyStart();
    try {
      await _nativeTtsChannel.invokeMethod('speak', {
        'text': clean,
        'speed': PreferencesService().ttsSpeed,
      });
    } catch (e) {
      debugPrint('TtsService: Native TTS failed: $e');
    } finally {
      _nativeSpeaking = false;
      _notifyComplete();
    }
    return true;
  }

  /// Play a direct MP3 URL from the Gateway
  Future<bool> speakUrl(
    String url, {
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? _playbackGate.generation;
    if (!_playbackGate.claim(generation)) return false;
    debugPrint('TtsService: Playing gateway audio: $url');
    await _playback.playUrl(url);
    return true;
  }

  /// Play direct synthesized bytes from gateway talk.speak / tts.convert.
  Future<bool> speakBytes(
    Uint8List bytes, {
    int? expectedGeneration,
  }) async {
    final generation = expectedGeneration ?? _playbackGate.generation;
    if (!_playbackGate.claim(generation)) return false;
    debugPrint(
        'TtsService: Playing gateway audio bytes (${bytes.length} bytes)');
    await _playback.playBytes(bytes);
    return true;
  }

  Future<void> stop() async {
    _playbackGate.invalidate();
    _nativeSpeaking = false;
    try {
      await _nativeTtsChannel.invokeMethod('stop');
    } catch (_) {}
    await _playback.stop();
  }

  bool get isReady => true; // Gateway path is always ready

  bool get isSpeaking => _playback.isPlaying || _nativeSpeaking;

  int get playbackGeneration => _playbackGate.generation;

  /// Deprecated: Local engines removed in v2.0-beta.1 cleanup
  bool get isUsingFallback => false;
  Future<bool> isModelDownloaded() async => true;
  Future<void> init({bool forceDownload = false}) async {}
  set onDownloadProgress(Function(double)? fn) {}
}

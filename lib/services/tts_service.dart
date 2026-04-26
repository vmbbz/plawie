import 'preferences_service.dart';
import 'engines/tts_engine.dart';
import 'engines/kokoro_tts_engine.dart';
import 'engines/native_tts_engine.dart';
import 'engines/elevenlabs_tts_engine.dart';
import 'engines/openai_tts_engine.dart';

/// Facade that delegates TTS to whichever engine the user has selected.
/// Exposes the same onStart / onComplete callbacks that VRM lip-sync and
/// continuous mode rely on.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final _prefs = PreferencesService();

  // Cached engine instances — created lazily, reused across calls
  final KokoroTtsEngine _kokoro = KokoroTtsEngine();
  NativeTtsEngine? _native;
  ElevenLabsTtsEngine? _elevenlabs;
  OpenAiTtsEngine? _openai;

  /// Fires when TTS starts speaking (for VRM mouth animation).
  Function? onStart;

  /// Fires when TTS finishes speaking (for continuous mode + VRM reset).
  Function? onComplete;

  /// Download progress callback — only meaningful when engine == 'kokoro'.
  Function(double)? onDownloadProgress;

  /// Returns true if the user's preferred engine is Kokoro, but it's not ready
  /// and we're currently falling back to Native TTS.
  bool get isUsingFallback {
    final preferred = _prefs.ttsEngine;
    return preferred == 'kokoro' && !_kokoro.isReady;
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  bool get isReady => _activeEngine.isReady;

  double get speed => _prefs.ttsSpeed;

  Future<void> speak(String text) async {
    final engine = _activeEngine;
    if (isUsingFallback) {
      print('TtsService: Kokoro not ready, falling back to Native TTS');
    }
    engine.onStart = () => onStart?.call();
    engine.onComplete = () => onComplete?.call();
    await engine.speak(text, speed: speed);
  }

  Future<void> stop() async {
    await _activeEngine.stop();
  }

  // ── Kokoro pass-throughs (ChatScreen uses these for model download) ──────────

  Future<bool> isModelDownloaded() => _kokoro.isModelDownloaded();

  Future<void> init({bool forceDownload = false}) {
    _kokoro.onDownloadProgress = onDownloadProgress;
    _kokoro.sid = _prefs.kokoroVoiceSid;
    return _kokoro.init(forceDownload: forceDownload);
  }

  /// Re-runs Kokoro init without re-downloading. Returns true if Kokoro is now ready.
  /// Call after a successful download to verify the sherpa-onnx engine loaded.
  Future<bool> reinitializeKokoro() async {
    _kokoro.sid = _prefs.kokoroVoiceSid;
    await _kokoro.init();
    return _kokoro.isReady;
  }

  /// Update the active Kokoro voice mid-session (called from voice picker in Settings).
  void updateKokoroVoice(int sid) {
    _prefs.kokoroVoiceSid = sid;
    _kokoro.sid = sid;
  }

  // ── Engine resolution ────────────────────────────────────────────────────────

  TtsEngine get _activeEngine {
    final preferred = _prefs.ttsEngine;

    // Explicit engines: no fallback
    if (preferred == 'native') return _native ??= NativeTtsEngine();
    if (preferred == 'elevenlabs') {
      final key = _prefs.elevenLabsApiKey ?? '';
      final voice = _prefs.elevenLabsVoiceId;
      if (_elevenlabs?.apiKey != key || _elevenlabs?.voiceId != voice) {
        _elevenlabs = ElevenLabsTtsEngine(apiKey: key, voiceId: voice);
      }
      return _elevenlabs!;
    }
    if (preferred == 'openai') {
      final key = _prefs.openAiApiKey ?? '';
      final voice = _prefs.openAiTtsVoice;
      final model = _prefs.openAiTtsModel;
      if (_openai?.voice != voice || _openai?.model != model) {
        _openai = OpenAiTtsEngine(apiKey: key, voice: voice, model: model);
      }
      return _openai!;
    }

    // Default/Kokoro: Fall back to native if model not yet downloaded
    if (preferred == 'kokoro' && !_kokoro.isReady) {
      return _native ??= NativeTtsEngine();
    }

    return _kokoro;
  }
}

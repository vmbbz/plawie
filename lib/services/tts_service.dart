import 'preferences_service.dart';
import 'engines/tts_engine.dart';
import 'engines/piper_tts_engine.dart';
import 'engines/native_tts_engine.dart';
import 'engines/elevenlabs_tts_engine.dart';
import 'engines/openai_tts_engine.dart';

/// Facade that delegates TTS to whichever engine the user has selected.
/// Drop-in replacement for PiperTtsService — exposes the same onStart /
/// onComplete callbacks that VRM lip-sync and continuous mode rely on.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final _prefs = PreferencesService();

  // Cached engine instances — created lazily, reused across calls
  final PiperTtsEngine _piper = PiperTtsEngine();
  NativeTtsEngine? _native;
  ElevenLabsTtsEngine? _elevenlabs;
  OpenAiTtsEngine? _openai;

  /// Fires when TTS starts speaking (for VRM mouth animation).
  Function? onStart;

  /// Fires when TTS finishes speaking (for continuous mode + VRM reset).
  Function? onComplete;

  /// Download progress callback — only meaningful when engine == 'piper'.
  Function(double)? onDownloadProgress;

  // ── Public API (mirrors PiperTtsService) ────────────────────────────────────

  bool get isReady => _activeEngine.isReady;

  double get speed => _prefs.ttsSpeed;

  Future<void> speak(String text) async {
    final engine = _activeEngine;
    engine.onStart = () => onStart?.call();
    engine.onComplete = () => onComplete?.call();
    await engine.speak(text, speed: speed);
  }

  Future<void> stop() async {
    await _activeEngine.stop();
  }

  // ── Piper pass-throughs (ChatScreen uses these for model download) ──────────

  Future<bool> isModelDownloaded() => _piper.isModelDownloaded();

  Future<void> init({bool forceDownload = false}) {
    _piper.onDownloadProgress = onDownloadProgress;
    return _piper.init(forceDownload: forceDownload);
  }

  // ── Engine resolution ────────────────────────────────────────────────────────

  TtsEngine get _activeEngine {
    switch (_prefs.ttsEngine) {
      case 'native':
        return _native ??= NativeTtsEngine();
      case 'elevenlabs':
        final key = _prefs.elevenLabsApiKey ?? '';
        final voice = _prefs.elevenLabsVoiceId;
        // Recreate if key/voice changed
        if (_elevenlabs?.apiKey != key || _elevenlabs?.voiceId != voice) {
          _elevenlabs = ElevenLabsTtsEngine(apiKey: key, voiceId: voice);
        }
        return _elevenlabs!;
      case 'openai':
        final key = _prefs.openAiApiKey ?? '';
        final voice = _prefs.openAiTtsVoice;
        final model = _prefs.openAiTtsModel;
        if (_openai?.voice != voice || _openai?.model != model) {
          _openai = OpenAiTtsEngine(apiKey: key, voice: voice, model: model);
        }
        return _openai!;
      case 'piper':
      default:
        return _piper;
    }
  }
}

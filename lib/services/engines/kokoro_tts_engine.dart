import '../kokoro_tts_service.dart';
import 'tts_engine.dart';

/// Wraps KokoroTtsService (sherpa-onnx Kokoro, fully offline).
class KokoroTtsEngine implements TtsEngine {
  final KokoroTtsService _kokoro = KokoroTtsService();

  @override
  String get id => 'kokoro';

  @override
  String get label => 'Kokoro (Offline)';

  @override
  bool get isReady => _kokoro.isReady;

  @override
  Function? onStart;

  @override
  Function? onComplete;

  KokoroTtsEngine() {
    _kokoro.onStart = () => onStart?.call();
    _kokoro.onComplete = () => onComplete?.call();
  }

  @override
  Future<void> speak(String text, {double speed = 1.0}) async {
    // Wire callbacks each call in case they were reassigned externally
    _kokoro.onStart = () => onStart?.call();
    _kokoro.onComplete = () => onComplete?.call();
    _kokoro.speed = speed;
    await _kokoro.speak(text);
  }

  @override
  Future<void> stop() => _kokoro.stop();

  /// Pass-through: init the underlying Kokoro model.
  Future<bool> isModelDownloaded() => _kokoro.isModelDownloaded();
  Future<void> init({bool forceDownload = false}) => _kokoro.init(forceDownload: forceDownload);
  set onDownloadProgress(Function(double)? fn) => _kokoro.onDownloadProgress = fn;

  /// Set the Kokoro speaker ID (0–10 for kokoro-en-v0_19).
  set sid(int v) => _kokoro.sid = v;
}

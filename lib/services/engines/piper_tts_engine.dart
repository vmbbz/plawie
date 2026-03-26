import '../piper_tts_service.dart';
import 'tts_engine.dart';

/// Wraps the existing PiperTtsService (sherpa-onnx VITS, fully offline).
class PiperTtsEngine implements TtsEngine {
  final PiperTtsService _piper = PiperTtsService();

  @override
  String get id => 'piper';

  @override
  String get label => 'Piper (Offline)';

  @override
  bool get isReady => _piper.isReady;

  @override
  Function? onStart;

  @override
  Function? onComplete;

  PiperTtsEngine() {
    _piper.onStart = () => onStart?.call();
    _piper.onComplete = () => onComplete?.call();
  }

  @override
  Future<void> speak(String text, {double speed = 1.0}) async {
    // Wire callbacks each call in case they were reassigned externally
    _piper.onStart = () => onStart?.call();
    _piper.onComplete = () => onComplete?.call();
    _piper.speed = speed;
    await _piper.speak(text);
  }

  @override
  Future<void> stop() => _piper.stop();

  /// Pass-through: init the underlying Piper model.
  Future<bool> isModelDownloaded() => _piper.isModelDownloaded();
  Future<void> init({bool forceDownload = false}) => _piper.init(forceDownload: forceDownload);
  set onDownloadProgress(Function(double)? fn) => _piper.onDownloadProgress = fn;
}

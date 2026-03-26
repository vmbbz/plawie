import 'package:flutter_tts/flutter_tts.dart';
import 'tts_engine.dart';

/// Uses Android/iOS built-in TTS voices via flutter_tts.
/// Zero new dependencies — flutter_tts is already in pubspec.yaml.
class NativeTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  @override
  String get id => 'native';

  @override
  String get label => 'Device TTS';

  @override
  bool get isReady => _ready;

  @override
  Function? onStart;

  @override
  Function? onComplete;

  NativeTtsEngine() {
    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setErrorHandler((_) => onComplete?.call());
    _ready = true;
  }

  @override
  Future<void> speak(String text, {double speed = 1.0}) async {
    // flutter_tts setSpeechRate accepts 0.0–1.0; clamp and scale from our 0.5–2.0 range
    final rate = (speed / 2.0).clamp(0.25, 1.0);
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  /// Returns all TTS engines installed on the device.
  Future<List<String>> getEngines() async {
    final engines = await _tts.getEngines;
    return List<String>.from(engines as List? ?? []);
  }

  Future<void> setEngine(String engine) => _tts.setEngine(engine);
}

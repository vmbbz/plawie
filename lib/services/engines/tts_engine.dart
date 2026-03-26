/// Abstract interface all TTS engines must implement.
abstract class TtsEngine {
  String get id;
  String get label;
  bool get isReady;

  Future<void> speak(String text, {double speed = 1.0});
  Future<void> stop();

  /// Called when the engine starts speaking (for VRM lip-sync).
  Function? onStart;

  /// Called when the engine finishes speaking (for continuous mode / VRM reset).
  Function? onComplete;
}

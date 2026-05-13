import 'package:flutter/foundation.dart';
import 'audio_playback_service.dart';

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

  /// Fires when TTS starts speaking (used by VRM lip-sync).
  Function? onStart;

  /// Fires when TTS finishes speaking (used by VRM + continuous mode).
  Function? onComplete;

  /// No-op for direct text speaking — gateway handles actual generation
  /// via tool calls and returns a URL to [speakUrl].
  Future<void> speak(String text) async {
    debugPrint('TtsService: Gateway TTS generation requested for: $text');
    // Note: The actual MP3 will arrive via GatewayService -> speakUrl()
  }

  /// Play a direct MP3 URL from the Gateway
  Future<void> speakUrl(String url) async {
    debugPrint('TtsService: Playing gateway audio: $url');
    await _playback.playUrl(url);
  }

  Future<void> stop() async {
    await _playback.stop();
  }

  bool get isReady => true; // Gateway path is always ready
  
  bool get isSpeaking => _playback.isPlaying;

  /// Deprecated: Local engines removed in v2.0-beta.1 cleanup
  bool get isUsingFallback => false;
  Future<bool> isModelDownloaded() async => true;
  Future<void> init({bool forceDownload = false}) async {}
  set onDownloadProgress(Function(double)? fn) {}
}

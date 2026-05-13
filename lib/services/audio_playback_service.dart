import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralized audio manager for OpenClaw.
/// Handles both Gateway MP3 URLs and local TTS engine output.
/// Provides hooks for VRM lip-sync (onStart / onComplete).
class AudioPlaybackService {
  static final AudioPlaybackService _instance = AudioPlaybackService._internal();
  factory AudioPlaybackService() => _instance;
  AudioPlaybackService._internal() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  
  // Callbacks for UI/VRM synchronization (e.g. lip-sync)
  VoidCallback? onStart;
  VoidCallback? onComplete;

  void _init() {
    _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );

    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.playing) {
        onStart?.call();
      } else if (state == PlayerState.completed || state == PlayerState.stopped) {
        onComplete?.call();
      }
    });
  }

  /// Play audio from a URL (e.g., from the OpenClaw Gateway media server)
  Future<void> playUrl(String url) async {
    try {
      debugPrint('AudioPlaybackService: Playing URL: $url');
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('AudioPlaybackService Error (playUrl): $e');
      onComplete?.call();
    }
  }

  /// Play audio from a local file path (e.g., from Kokoro or Native TTS)
  Future<void> playFile(String path) async {
    try {
      debugPrint('AudioPlaybackService: Playing File: $path');
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('AudioPlaybackService Error (playFile): $e');
      onComplete?.call();
    }
  }

  /// Play audio from raw bytes (e.g., from Kokoro)
  Future<void> playBytes(Uint8List bytes) async {
    try {
      debugPrint('AudioPlaybackService: Playing bytes (${bytes.length} bytes)');
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('AudioPlaybackService Error (playBytes): $e');
      onComplete?.call();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    onComplete?.call();
  }

  void dispose() {
    _player.dispose();
  }
}

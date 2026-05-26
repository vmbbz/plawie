import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Centralized audio manager for OpenClaw.
/// Handles both Gateway MP3 URLs and local TTS engine output.
/// Provides hooks for VRM lip-sync (onStart / onComplete).
class AudioPlaybackService {
  static final AudioPlaybackService _instance =
      AudioPlaybackService._internal();
  factory AudioPlaybackService() => _instance;
  AudioPlaybackService._internal() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _hasActivePlayback = false;
  bool get isPlaying => _isPlaying;

  // Callbacks for UI/VRM synchronization (e.g. lip-sync)
  VoidCallback? onStart;
  VoidCallback? onComplete;

  void _init() {
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
    _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );

    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        _isPlaying = true;
        _hasActivePlayback = true;
        onStart?.call();
      } else if (state == PlayerState.completed) {
        _markComplete();
      } else if (state == PlayerState.stopped) {
        // Programmatic stops happen while replacing audio sources. The caller
        // decides whether that stop means "speech is done" via stop().
        _isPlaying = false;
      }
    });
  }

  void _markComplete() {
    final shouldNotify = _hasActivePlayback || _isPlaying;
    _isPlaying = false;
    _hasActivePlayback = false;
    if (shouldNotify) {
      onComplete?.call();
    }
  }

  /// Play audio from a URL (e.g., from the OpenClaw Gateway media server)
  Future<void> playUrl(String url) async {
    try {
      debugPrint('AudioPlaybackService: Playing URL: $url');
      _hasActivePlayback = true;
      if (_isPlaying) {
        await _player.stop();
      }
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('AudioPlaybackService Error (playUrl): $e');
      _markComplete();
    }
  }

  /// Play audio from a local file path (e.g., from Kokoro or Native TTS)
  Future<void> playFile(String path) async {
    try {
      debugPrint('AudioPlaybackService: Playing File: $path');
      _hasActivePlayback = true;
      if (_isPlaying) {
        await _player.stop();
      }
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('AudioPlaybackService Error (playFile): $e');
      _markComplete();
    }
  }

  /// Play audio from raw bytes (e.g., from Kokoro)
  Future<void> playBytes(Uint8List bytes) async {
    try {
      debugPrint('AudioPlaybackService: Playing bytes (${bytes.length} bytes)');
      _hasActivePlayback = true;
      if (_isPlaying) {
        await _player.stop();
      }
      await _player.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('AudioPlaybackService Error (playBytes): $e');
      _markComplete();
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _markComplete();
  }

  void dispose() {
    _player.dispose();
  }
}

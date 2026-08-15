import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Small lifecycle-safe wrapper around Android's platform SpeechRecognizer.
///
/// The Gateway realtime Talk path remains preferred. This wrapper is the
/// official-client-style fallback for installations without a configured
/// realtime provider; it returns recognized text for the existing chat submit
/// pipeline instead of requiring the Gateway's optional `/talk/stt` route.
class NativeSpeechInputService {
  // Samsung/Google recognition on some South African firmware exposes
  // en-ZA as the system locale even when its downloadable speech pack is not
  // installed. Plawie currently speaks English, so prefer the broadly
  // available US English model for the short command recognizer instead of
  // silently entering a no-speech failure loop.
  static const _preferredEnglishLocale = 'en_US';

  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _available = false;
  bool _listening = false;
  String _latestText = '';
  Completer<String?>? _stopCompleter;
  Timer? _safetyTimer;
  void Function(String status)? _onStatus;
  void Function(String message)? _onError;
  void Function(String? text)? _onFinished;
  bool _finishedNotified = false;

  bool get isListening => _listening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String message)? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    if (_initialized) return _available;

    _available = await _speech.initialize(
      onStatus: _handleStatus,
      onError: (error) => _handleError(error.errorMsg),
    );
    _initialized = true;
    return _available;
  }

  Future<bool> start({
    void Function(String status)? onStatus,
    void Function(String message)? onError,
    void Function(String? text)? onFinished,
  }) async {
    final available = await initialize(onStatus: onStatus, onError: onError);
    if (!available || _listening) return available;

    _onFinished = onFinished;
    _finishedNotified = false;
    _latestText = '';
    _stopCompleter = null;
    try {
      await _speech.listen(
        onResult: (result) {
          _latestText = result.recognizedWords.trim();
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: _preferredEnglishLocale,
          // Leave enough room for the wake phrase to hand off to the command
          // without closing the recognizer during the user's natural pause.
          // The safety timer below still bounds a broken recognizer.
          pauseFor: Duration(seconds: 5),
          listenFor: Duration(seconds: 45),
        ),
      );
    } catch (_) {
      _listening = false;
      rethrow;
    }
    // The plugin receives the platform `listening` status asynchronously, so
    // checking SpeechToText.isListening immediately can report false even
    // though Android has accepted the recognition request.
    _listening = true;
    _safetyTimer?.cancel();
    _safetyTimer = Timer(const Duration(seconds: 50), () {
      if (!_listening) return;
      _onStatus?.call('timeout');
      unawaited(stop(timeout: const Duration(seconds: 1)));
    });
    return true;
  }

  Future<String?> stop({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    if (!_listening && !_speech.isListening) {
      return _latestText.isEmpty ? null : _latestText;
    }

    final completer = Completer<String?>();
    _stopCompleter = completer;
    try {
      await _speech.stop();
    } catch (error) {
      _handleError(error.toString());
    }
    _listening = false;

    // speech_to_text.stop() asks the platform recognizer to deliver its final
    // result, but the platform callback can arrive after stop() returns. Do
    // not complete here or a final phrase can be lost between those two
    // callbacks. The timeout keeps a broken recognition service from holding
    // the chat UI indefinitely and returns the latest partial result.
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _stopCompleter = null;
          return _latestText.isEmpty ? null : _latestText;
        },
      );
    } finally {
      if (identical(_stopCompleter, completer)) {
        _stopCompleter = null;
      }
    }
  }

  Future<void> cancel() async {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _stopCompleter = null;
    _latestText = '';
    _listening = false;
    try {
      await _speech.cancel();
    } catch (error) {
      _handleError(error.toString());
    }
  }

  Future<void> dispose() async {
    await cancel();
    _onStatus = null;
    _onError = null;
    _onFinished = null;
    _initialized = false;
    _available = false;
  }

  void _handleStatus(String status) {
    _listening = _speech.isListening || status == 'listening';
    _onStatus?.call(status);
    if (status == 'done' || status == 'notListening') {
      _safetyTimer?.cancel();
      _safetyTimer = null;
      _listening = false;
      _completeStopIfNeeded();
      _notifyFinished();
    }
  }

  void _handleError(String message) {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _listening = false;
    _onError?.call(message);
    _completeStopIfNeeded();
    _notifyFinished();
  }

  void _completeStopIfNeeded() {
    final completer = _stopCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(_latestText.isEmpty ? null : _latestText);
    _stopCompleter = null;
  }

  void _notifyFinished() {
    if (_finishedNotified) return;
    _finishedNotified = true;
    _onFinished?.call(_latestText.isEmpty ? null : _latestText);
  }
}

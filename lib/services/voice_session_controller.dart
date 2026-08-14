/// State and generation guards shared by voice surfaces.
///
/// The controller deliberately does not own a recorder, WebView, or Gateway
/// connection. It only owns the lifecycle facts that those surfaces need to
/// agree on. A new generation invalidates delayed callbacks from an older
/// turn, which prevents a completed TTS callback from reopening a microphone
/// session after the user has stopped or changed surfaces.
enum VoiceSessionPhase {
  idle,
  starting,
  listening,
  thinking,
  speaking,
  paused,
  reconnecting,
  stopped,
  error,
}

enum VoiceCaptureOwner { none, chat, pip, wakeWord, service }

enum VoiceSessionSurface { fullScreen, pip, overlay, notification, none }

class VoiceSessionState {
  const VoiceSessionState({
    this.phase = VoiceSessionPhase.idle,
    this.captureOwner = VoiceCaptureOwner.none,
    this.surface = VoiceSessionSurface.fullScreen,
    this.generation = 0,
    this.muted = false,
    this.statusReason,
  });

  final VoiceSessionPhase phase;
  final VoiceCaptureOwner captureOwner;
  final VoiceSessionSurface surface;
  final int generation;
  final bool muted;
  final String? statusReason;

  bool get captureActive =>
      phase == VoiceSessionPhase.starting ||
      phase == VoiceSessionPhase.listening;

  VoiceSessionState copyWith({
    VoiceSessionPhase? phase,
    VoiceCaptureOwner? captureOwner,
    VoiceSessionSurface? surface,
    int? generation,
    bool? muted,
    Object? statusReason = _unchanged,
  }) {
    return VoiceSessionState(
      phase: phase ?? this.phase,
      captureOwner: captureOwner ?? this.captureOwner,
      surface: surface ?? this.surface,
      generation: generation ?? this.generation,
      muted: muted ?? this.muted,
      statusReason: identical(statusReason, _unchanged)
          ? this.statusReason
          : statusReason as String?,
    );
  }
}

const Object _unchanged = Object();

class VoiceSessionController {
  VoiceSessionState _state = const VoiceSessionState();

  VoiceSessionState get state => _state;

  /// Starts a capture generation, or returns null when a capture is already
  /// starting/active. The caller must pass the returned generation to every
  /// async completion that can mutate voice state.
  int? beginCapture({
    required VoiceCaptureOwner owner,
    required VoiceSessionSurface surface,
  }) {
    if (_state.captureActive) return null;

    final generation = _state.generation + 1;
    _state = _state.copyWith(
      phase: VoiceSessionPhase.starting,
      captureOwner: owner,
      surface: surface,
      generation: generation,
      statusReason: null,
    );
    return generation;
  }

  bool isCurrent(int generation) => _state.generation == generation;

  bool markListening(int generation) {
    return _replaceIfCurrent(
      generation,
      phase: VoiceSessionPhase.listening,
      statusReason: null,
    );
  }

  bool markSpeaking(int generation) {
    return _replaceIfCurrent(
      generation,
      phase: VoiceSessionPhase.speaking,
      statusReason: null,
    );
  }

  bool markThinking(int generation) {
    return _replaceIfCurrent(
      generation,
      phase: VoiceSessionPhase.thinking,
      statusReason: null,
    );
  }

  bool updateSurface(VoiceSessionSurface surface) {
    _state = _state.copyWith(surface: surface);
    return true;
  }

  /// Invalidates all callbacks from the previous generation.
  int invalidate({
    VoiceSessionPhase phase = VoiceSessionPhase.idle,
    String? reason,
  }) {
    final generation = _state.generation + 1;
    _state = _state.copyWith(
      phase: phase,
      captureOwner: VoiceCaptureOwner.none,
      generation: generation,
      statusReason: reason,
    );
    return generation;
  }

  bool _replaceIfCurrent(
    int generation, {
    VoiceSessionPhase? phase,
    VoiceCaptureOwner? captureOwner,
    VoiceSessionSurface? surface,
    bool? muted,
    Object? statusReason = _unchanged,
  }) {
    if (!isCurrent(generation)) return false;
    _state = _state.copyWith(
      phase: phase,
      captureOwner: captureOwner,
      surface: surface,
      muted: muted,
      statusReason: statusReason,
    );
    return true;
  }
}

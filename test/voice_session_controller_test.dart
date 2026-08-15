import 'package:clawa/services/voice_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture generation starts with its surface and owner', () {
    final controller = VoiceSessionController();

    final generation = controller.beginCapture(
      owner: VoiceCaptureOwner.pip,
      surface: VoiceSessionSurface.pip,
    );

    expect(generation, 1);
    expect(controller.state.phase, VoiceSessionPhase.starting);
    expect(controller.state.captureOwner, VoiceCaptureOwner.pip);
    expect(controller.state.surface, VoiceSessionSurface.pip);
    expect(controller.state.captureActive, isTrue);
  });

  test('a second capture cannot take ownership while one is active', () {
    final controller = VoiceSessionController();
    final first = controller.beginCapture(
      owner: VoiceCaptureOwner.chat,
      surface: VoiceSessionSurface.fullScreen,
    );

    expect(
      controller.beginCapture(
        owner: VoiceCaptureOwner.pip,
        surface: VoiceSessionSurface.pip,
      ),
      isNull,
    );
    expect(controller.isCurrent(first!), isTrue);
  });

  test('invalidating a session rejects stale async completions', () {
    final controller = VoiceSessionController();
    final first = controller.beginCapture(
      owner: VoiceCaptureOwner.chat,
      surface: VoiceSessionSurface.fullScreen,
    )!;

    controller.invalidate(
      phase: VoiceSessionPhase.paused,
      reason: 'PiP surface changed',
    );

    expect(controller.isCurrent(first), isFalse);
    expect(controller.markListening(first), isFalse);
    expect(controller.state.phase, VoiceSessionPhase.paused);
    expect(controller.state.captureOwner, VoiceCaptureOwner.none);
    expect(controller.state.statusReason, 'PiP surface changed');
  });

  test('surface changes preserve the active generation', () {
    final controller = VoiceSessionController();
    final generation = controller.beginCapture(
      owner: VoiceCaptureOwner.chat,
      surface: VoiceSessionSurface.fullScreen,
    )!;

    controller.updateSurface(VoiceSessionSurface.pip);

    expect(controller.isCurrent(generation), isTrue);
    expect(controller.state.surface, VoiceSessionSurface.pip);
    expect(controller.markListening(generation), isTrue);
    expect(controller.state.phase, VoiceSessionPhase.listening);
  });

  test('voice phases expose stable user-facing labels', () {
    expect(VoiceSessionPhase.starting.userLabel, 'Starting microphone');
    expect(VoiceSessionPhase.transcribing.userLabel, 'Transcribing');
    expect(VoiceSessionPhase.noTranscript.userLabel, 'No transcript');
    expect(VoiceSessionPhase.speaking.userLabel, 'Speaking');
  });

  test('stale phase updates cannot overwrite a newer generation', () {
    final controller = VoiceSessionController();
    final first = controller.beginCapture(
      owner: VoiceCaptureOwner.chat,
      surface: VoiceSessionSurface.fullScreen,
    )!;

    controller.invalidate(phase: VoiceSessionPhase.transcribing);

    expect(
      controller.setPhaseIfCurrent(first, VoiceSessionPhase.sent),
      isFalse,
    );
    expect(controller.state.phase, VoiceSessionPhase.transcribing);
  });

  test('does not allow a new capture while the previous turn is busy', () {
    final controller = VoiceSessionController();
    final generation = controller.beginCapture(
      owner: VoiceCaptureOwner.chat,
      surface: VoiceSessionSurface.fullScreen,
    );
    expect(generation, isNotNull);
    controller.markListening(generation!);
    controller.setPhase(VoiceSessionPhase.thinking);

    expect(
      controller.beginCapture(
        owner: VoiceCaptureOwner.pip,
        surface: VoiceSessionSurface.pip,
      ),
      isNull,
    );

    controller.invalidate();
    expect(
      controller.beginCapture(
        owner: VoiceCaptureOwner.wakeWord,
        surface: VoiceSessionSurface.fullScreen,
      ),
      isNotNull,
    );
  });

  test('a no-transcript wake turn releases ownership for the next wake turn', () {
    final controller = VoiceSessionController();
    final first = controller.beginCapture(
      owner: VoiceCaptureOwner.wakeWord,
      surface: VoiceSessionSurface.fullScreen,
    )!;
    controller.markListening(first);

    controller.invalidate(
      phase: VoiceSessionPhase.noTranscript,
      reason: 'Fallback recognizer returned no text',
    );

    expect(controller.state.captureActive, isFalse);
    expect(controller.state.captureOwner, VoiceCaptureOwner.none);
    expect(
      controller.beginCapture(
        owner: VoiceCaptureOwner.wakeWord,
        surface: VoiceSessionSurface.fullScreen,
      ),
      isNotNull,
    );
  });
}

import 'package:clawa/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects synthesized playback after a stop invalidates its generation', () {
    final gate = TtsPlaybackGenerationGate();
    final pendingGeneration = gate.generation;

    gate.invalidate();

    expect(gate.claim(pendingGeneration), isFalse);
  });

  test('only one concurrent playback can claim the same generation', () {
    final gate = TtsPlaybackGenerationGate();
    final sharedGeneration = gate.generation;

    expect(gate.claim(sharedGeneration), isTrue);
    expect(gate.claim(sharedGeneration), isFalse);
  });
}

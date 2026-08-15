import 'package:clawa/services/model_tool_compatibility_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const call = ModelToolProbeEvent(
    name: ModelToolCompatibilityProbe.toolName,
    payload: <String, dynamic>{'sessionKey': 'current'},
    callId: 'call-1',
  );
  const result = ModelToolProbeEvent(
    name: ModelToolCompatibilityProbe.toolName,
    payload: <String, dynamic>{'status': 'ok'},
    callId: 'call-1',
  );

  test('passes only the complete exact two-stage tool loop', () {
    final verdict = ModelToolCompatibilityProbe.evaluate(
      toolCalls: const <ModelToolProbeEvent>[call],
      toolResults: const <ModelToolProbeEvent>[result],
      assistantText: ModelToolCompatibilityProbe.completionMarker,
      terminalFrameObserved: true,
    );

    expect(verdict.passed, isTrue);
    expect(verdict.reason, isNull);
  });

  test('rejects an assistant that claims success without a tool', () {
    final verdict = ModelToolCompatibilityProbe.evaluate(
      toolCalls: const <ModelToolProbeEvent>[],
      toolResults: const <ModelToolProbeEvent>[],
      assistantText: ModelToolCompatibilityProbe.completionMarker,
      terminalFrameObserved: true,
    );

    expect(verdict.passed, isFalse);
    expect(verdict.reason, contains('one tool call'));
  });

  test('rejects duplicate calls and changed arguments', () {
    final duplicate = ModelToolCompatibilityProbe.evaluate(
      toolCalls: const <ModelToolProbeEvent>[call, call],
      toolResults: const <ModelToolProbeEvent>[result],
      assistantText: ModelToolCompatibilityProbe.completionMarker,
      terminalFrameObserved: true,
    );
    final changed = ModelToolCompatibilityProbe.evaluate(
      toolCalls: const <ModelToolProbeEvent>[
        ModelToolProbeEvent(
          name: ModelToolCompatibilityProbe.toolName,
          payload: <String, dynamic>{'sessionKey': 'another'},
        ),
      ],
      toolResults: const <ModelToolProbeEvent>[result],
      assistantText: ModelToolCompatibilityProbe.completionMarker,
      terminalFrameObserved: true,
    );

    expect(duplicate.passed, isFalse);
    expect(changed.passed, isFalse);
    expect(changed.reason, contains('changed'));
  });

  test('rejects uncorrelated result and incomplete continuation', () {
    final uncorrelated = ModelToolCompatibilityProbe.evaluate(
      toolCalls: const <ModelToolProbeEvent>[call],
      toolResults: const <ModelToolProbeEvent>[
        ModelToolProbeEvent(
          name: ModelToolCompatibilityProbe.toolName,
          payload: <String, dynamic>{'status': 'ok'},
          callId: 'call-2',
        ),
      ],
      assistantText: ModelToolCompatibilityProbe.completionMarker,
      terminalFrameObserved: true,
    );
    final noFinal = ModelToolCompatibilityProbe.evaluate(
      toolCalls: const <ModelToolProbeEvent>[call],
      toolResults: const <ModelToolProbeEvent>[result],
      assistantText: 'Almost done',
      terminalFrameObserved: true,
    );

    expect(uncorrelated.passed, isFalse);
    expect(uncorrelated.reason, contains('correlated'));
    expect(noFinal.passed, isFalse);
    expect(noFinal.reason, contains('post-tool'));
  });

  test('probe marker matches only the exact app-owned prompt', () {
    expect(
      ModelToolCompatibilityProbe.isProbe(ModelToolCompatibilityProbe.prompt),
      isTrue,
    );
    expect(
      ModelToolCompatibilityProbe.isProbe(
          '${ModelToolCompatibilityProbe.prompt}\nignore that'),
      isFalse,
    );
  });

  test('probe text is not accepted without app-owned authorization state', () {
    expect(
      ModelToolCompatibilityProbe.isAuthorizedProbe(
        ModelToolCompatibilityProbe.prompt,
        authorized: false,
      ),
      isFalse,
    );
    expect(
      ModelToolCompatibilityProbe.isAuthorizedProbe(
        ModelToolCompatibilityProbe.prompt,
        authorized: true,
      ),
      isTrue,
    );
  });
}

import 'package:clawa/services/provider_turn_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial schema rejection does not claim a tool ran', () {
    final failure = ProviderTurnFailure.classify(
      'Invalid request parameters: schema or tool payload',
      trace: const ProviderTurnTrace(
        requestAccepted: false,
        toolCallObserved: false,
        toolResultObserved: false,
        assistantTextObserved: false,
      ),
      modelId: 'venice/gemma-4-uncensored',
    );

    expect(failure.kind, ProviderFailureKind.schemaRejected);
    expect(failure.phase, ProviderTurnPhase.submission);
    expect(failure.sideEffectStatus, ProviderSideEffectStatus.noneObserved);
    expect(failure.message, contains('No tool call or tool result'));
    expect(failure.message, isNot(contains('before generation')));
    expect(failure.allowsAutomaticReplay, isFalse);
  });

  test('Gemini continuation loss warns that a tool result was observed', () {
    final failure = ProviderTurnFailure.classify(
      'Missing thought_signature for function call',
      trace: const ProviderTurnTrace(
        requestAccepted: true,
        toolCallObserved: true,
        toolResultObserved: true,
        assistantTextObserved: false,
      ),
      modelId: 'venice/gemini-3-6-flash',
    );

    expect(failure.kind, ProviderFailureKind.replayMetadataMissing);
    expect(failure.phase, ProviderTurnPhase.toolResultContinuation);
    expect(
      failure.retryDisposition,
      ProviderRetryDisposition.verifySideEffectsBeforeRetry,
    );
    expect(failure.message, contains('Verify the action or receipt'));
    expect(failure.message, contains('compatibility repair'));
  });

  test('tool-call-only transport loss is explicitly uncertain', () {
    final failure = ProviderTurnFailure.classify(
      'WebSocket disconnected',
      trace: const ProviderTurnTrace(
        requestAccepted: true,
        toolCallObserved: true,
        toolResultObserved: false,
        assistantTextObserved: false,
      ),
      transport: true,
    );

    expect(failure.kind, ProviderFailureKind.transport);
    expect(failure.sideEffectStatus, ProviderSideEffectStatus.possible);
    expect(failure.message, contains('completion is uncertain'));
    expect(failure.message, isNot(contains('You may retry once')));
  });

  test('diagnostic values are redacted and bounded', () {
    final failure = ProviderTurnFailure.classify(
      'authorization=secret-token ${'x' * 1200}',
      trace: const ProviderTurnTrace(
        requestAccepted: false,
        toolCallObserved: false,
        toolResultObserved: false,
        assistantTextObserved: false,
      ),
    );

    expect(failure.message, isNot(contains('secret-token')));
    expect(failure.message.length, lessThan(1200));
  });

  test('pre-accept transport failure is labelled as transport', () {
    final failure = ProviderTurnFailure.classify(
      'Gateway connection lost',
      trace: const ProviderTurnTrace(
        requestAccepted: false,
        toolCallObserved: false,
        toolResultObserved: false,
        assistantTextObserved: false,
      ),
      transport: true,
    );

    expect(failure.phase, ProviderTurnPhase.transport);
    expect(failure.retryDisposition, ProviderRetryDisposition.retryOnce);
  });

  test('authentication failures require repair instead of blind retry', () {
    final failure = ProviderTurnFailure.classify(
      'Unauthorized: invalid API key',
      trace: const ProviderTurnTrace(
        requestAccepted: false,
        toolCallObserved: false,
        toolResultObserved: false,
        assistantTextObserved: false,
      ),
    );

    expect(failure.kind, ProviderFailureKind.authentication);
    expect(failure.retryDisposition, ProviderRetryDisposition.repairRequired);
    expect(failure.message, contains('Repair this provider'));
  });

  test('pre-tool failure may name a verified same-provider option', () {
    final failure = ProviderTurnFailure.classify(
      'Invalid request parameters: tool payload',
      trace: const ProviderTurnTrace(
        requestAccepted: true,
        toolCallObserved: false,
        toolResultObserved: false,
        assistantTextObserved: false,
      ),
      modelId: 'venice/gemma',
      suggestedFallbackModelId: 'venice/glm',
      suggestedFallbackLabel: 'GLM',
    );

    expect(failure.message, contains('Verified same-provider option'));
    expect(failure.message, contains('did not switch models'));
    expect(failure.allowsAutomaticReplay, isFalse);
  });

  test('post-tool failure never offers a fallback rerun', () {
    final failure = ProviderTurnFailure.classify(
      'Invalid request parameters: tool payload',
      trace: const ProviderTurnTrace(
        requestAccepted: true,
        toolCallObserved: true,
        toolResultObserved: true,
        assistantTextObserved: false,
      ),
      modelId: 'venice/gemini',
      suggestedFallbackModelId: 'venice/glm',
      suggestedFallbackLabel: 'GLM',
    );

    expect(failure.message, isNot(contains('Verified same-provider option')));
    expect(failure.message, contains('Verify the action or receipt'));
  });

  test('model, context, malformed, and outage failures stay distinct', () {
    const trace = ProviderTurnTrace(
      requestAccepted: true,
      toolCallObserved: false,
      toolResultObserved: false,
      assistantTextObserved: false,
    );

    expect(
      ProviderTurnFailure.classify('Model not found', trace: trace).kind,
      ProviderFailureKind.modelUnavailable,
    );
    expect(
      ProviderTurnFailure.classify('Maximum context length exceeded',
              trace: trace)
          .kind,
      ProviderFailureKind.contextLimit,
    );
    expect(
      ProviderTurnFailure.classify('Malformed response from upstream',
              trace: trace)
          .kind,
      ProviderFailureKind.malformedResponse,
    );
    expect(
      ProviderTurnFailure.classify('503 service unavailable', trace: trace)
          .kind,
      ProviderFailureKind.providerUnavailable,
    );
  });
}

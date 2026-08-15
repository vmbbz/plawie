enum ProviderTurnPhase {
  preflight,
  submission,
  providerGeneration,
  toolCall,
  toolResultContinuation,
  finalResponse,
  transport,
}

enum ProviderSideEffectStatus {
  noneObserved,
  possible,
  toolResultObserved,
}

enum ProviderFailureKind {
  schemaRejected,
  replayMetadataMissing,
  authentication,
  payment,
  rateLimit,
  modelUnavailable,
  contextLimit,
  malformedResponse,
  providerUnavailable,
  timeout,
  transport,
  providerRejected,
}

enum ProviderRetryDisposition {
  retryOnce,
  askBeforeSwitching,
  verifySideEffectsBeforeRetry,
  repairRequired,
}

/// Sanitized facts accumulated by Plawie around one Gateway chat turn.
class ProviderTurnTrace {
  const ProviderTurnTrace({
    required this.requestAccepted,
    required this.toolCallObserved,
    required this.toolResultObserved,
    required this.assistantTextObserved,
  });

  final bool requestAccepted;
  final bool toolCallObserved;
  final bool toolResultObserved;
  final bool assistantTextObserved;

  ProviderTurnPhase get phase {
    if (!requestAccepted) return ProviderTurnPhase.submission;
    if (assistantTextObserved) return ProviderTurnPhase.finalResponse;
    if (toolResultObserved) return ProviderTurnPhase.toolResultContinuation;
    if (toolCallObserved) return ProviderTurnPhase.toolCall;
    return ProviderTurnPhase.providerGeneration;
  }

  ProviderSideEffectStatus get sideEffectStatus {
    if (toolResultObserved) return ProviderSideEffectStatus.toolResultObserved;
    if (toolCallObserved) return ProviderSideEffectStatus.possible;
    return ProviderSideEffectStatus.noneObserved;
  }
}

/// Typed, provider-neutral error contract. It never contains prompts, tool
/// arguments/results, credentials, signatures, or payment proofs.
class ProviderTurnFailure {
  const ProviderTurnFailure({
    required this.kind,
    required this.phase,
    required this.sideEffectStatus,
    required this.retryDisposition,
    required this.message,
    this.modelId,
    this.suggestedFallbackModelId,
    this.suggestedFallbackLabel,
  });

  final ProviderFailureKind kind;
  final ProviderTurnPhase phase;
  final ProviderSideEffectStatus sideEffectStatus;
  final ProviderRetryDisposition retryDisposition;
  final String message;
  final String? modelId;
  final String? suggestedFallbackModelId;
  final String? suggestedFallbackLabel;

  /// Provider turns are never replayed silently. Even a safe initial rejection
  /// is returned to the user so they choose whether to retry or switch.
  bool get allowsAutomaticReplay => false;

  factory ProviderTurnFailure.classify(
    String rawError, {
    required ProviderTurnTrace trace,
    String? modelId,
    bool timeout = false,
    bool transport = false,
    String? suggestedFallbackModelId,
    String? suggestedFallbackLabel,
  }) {
    final sanitized = _sanitize(rawError);
    final lower = sanitized.toLowerCase();
    final sideEffects = trace.sideEffectStatus;
    final kind = timeout
        ? ProviderFailureKind.timeout
        : transport
            ? ProviderFailureKind.transport
            : _kindFromError(lower);
    final phase = transport &&
            !trace.requestAccepted &&
            trace.sideEffectStatus == ProviderSideEffectStatus.noneObserved
        ? ProviderTurnPhase.transport
        : trace.phase;
    final retry = sideEffects != ProviderSideEffectStatus.noneObserved
        ? ProviderRetryDisposition.verifySideEffectsBeforeRetry
        : kind == ProviderFailureKind.replayMetadataMissing ||
                kind == ProviderFailureKind.authentication ||
                kind == ProviderFailureKind.payment
            ? ProviderRetryDisposition.repairRequired
            : kind == ProviderFailureKind.schemaRejected ||
                    kind == ProviderFailureKind.modelUnavailable
                ? ProviderRetryDisposition.askBeforeSwitching
                : ProviderRetryDisposition.retryOnce;

    return ProviderTurnFailure(
      kind: kind,
      phase: phase,
      sideEffectStatus: sideEffects,
      retryDisposition: retry,
      modelId: modelId?.trim().isEmpty == false ? modelId!.trim() : null,
      suggestedFallbackModelId:
          suggestedFallbackModelId?.trim().isEmpty == false
              ? suggestedFallbackModelId!.trim()
              : null,
      suggestedFallbackLabel: suggestedFallbackLabel?.trim().isEmpty == false
          ? suggestedFallbackLabel!.trim()
          : null,
      message: _messageFor(
        sanitized,
        kind: kind,
        phase: phase,
        sideEffects: sideEffects,
        retry: retry,
        modelId: modelId,
        suggestedFallbackModelId: suggestedFallbackModelId,
        suggestedFallbackLabel: suggestedFallbackLabel,
      ),
    );
  }
}

ProviderFailureKind _kindFromError(String lower) {
  if (lower.contains('thought_signature') ||
      lower.contains('thought signature') ||
      lower.contains('missing signature')) {
    return ProviderFailureKind.replayMetadataMissing;
  }
  if (lower.contains('request schema') ||
      lower.contains('tool payload') ||
      lower.contains('schema or tool') ||
      lower.contains('invalid request parameter')) {
    return ProviderFailureKind.schemaRejected;
  }
  if (lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('authentication') ||
      lower.contains('invalid api key')) {
    return ProviderFailureKind.authentication;
  }
  if (lower.contains('billing') ||
      lower.contains('credit') ||
      lower.contains('insufficient balance') ||
      lower.contains('balance exhausted') ||
      lower.contains('payment required')) {
    return ProviderFailureKind.payment;
  }
  if (lower.contains('rate limit') || lower.contains('too many requests')) {
    return ProviderFailureKind.rateLimit;
  }
  if (lower.contains('model not found') ||
      lower.contains('unknown model') ||
      lower.contains('model unavailable') ||
      lower.contains('model is unavailable') ||
      lower.contains('model has been deprecated') ||
      lower.contains('model does not exist')) {
    return ProviderFailureKind.modelUnavailable;
  }
  if (lower.contains('context length') ||
      lower.contains('context window') ||
      lower.contains('maximum context') ||
      lower.contains('max context') ||
      lower.contains('too many tokens')) {
    return ProviderFailureKind.contextLimit;
  }
  if (lower.contains('malformed response') ||
      lower.contains('invalid json response') ||
      lower.contains('failed to parse provider response') ||
      lower.contains('empty error payload')) {
    return ProviderFailureKind.malformedResponse;
  }
  if (lower.contains('service unavailable') ||
      lower.contains('upstream unavailable') ||
      lower.contains('provider unavailable') ||
      lower.contains('provider overloaded') ||
      RegExp(r'\b50[234]\b').hasMatch(lower)) {
    return ProviderFailureKind.providerUnavailable;
  }
  return ProviderFailureKind.providerRejected;
}

String _messageFor(
  String raw, {
  required ProviderFailureKind kind,
  required ProviderTurnPhase phase,
  required ProviderSideEffectStatus sideEffects,
  required ProviderRetryDisposition retry,
  String? modelId,
  String? suggestedFallbackModelId,
  String? suggestedFallbackLabel,
}) {
  final details = <String>[
    raw,
    if (modelId?.trim().isNotEmpty == true)
      'Selected model: ${modelId!.trim()}.',
    'Failure stage: ${_phaseLabel(phase)}.',
  ];

  if (sideEffects == ProviderSideEffectStatus.toolResultObserved) {
    details.add(
      'A tool result was observed before this failure. Verify the action or '
      'receipt before retrying; Plawie will not replay this turn automatically.',
    );
  } else if (sideEffects == ProviderSideEffectStatus.possible) {
    details.add(
      'A tool call was emitted, but completion is uncertain. Verify possible '
      'side effects before retrying; Plawie will not replay automatically.',
    );
  } else {
    details.add('No tool call or tool result was observed by Plawie.');
  }

  if (kind == ProviderFailureKind.replayMetadataMissing) {
    details.add(
      'The provider route lost required continuation metadata. This model '
      'needs a compatibility repair before another tool turn.',
    );
  } else if (kind == ProviderFailureKind.schemaRejected) {
    details.add(
      'The provider rejected this route\'s tool request. You may keep the '
      'model for chat, test compatibility, or explicitly choose another '
      'verified model.',
    );
  } else if (kind == ProviderFailureKind.authentication) {
    details.add(
      'Repair this provider\'s credentials before retrying. Plawie will not '
      'switch providers or replay the turn automatically.',
    );
  } else if (kind == ProviderFailureKind.payment) {
    details.add(
      'Refresh this provider\'s balance or funding state before retrying. '
      'Plawie will not switch providers or replay the turn automatically.',
    );
  } else if (kind == ProviderFailureKind.modelUnavailable) {
    details.add(
      'This exact model route is unavailable or retired. Refresh the live '
      'catalog, then explicitly choose an available model. Plawie did not '
      'change the selection or resend the turn.',
    );
  } else if (kind == ProviderFailureKind.contextLimit) {
    details.add(
      'The selected route could not accept this turn within its context '
      'limit. Plawie did not trim conversation history or switch models.',
    );
  } else if (kind == ProviderFailureKind.malformedResponse) {
    details.add(
      'The provider returned a response the Gateway could not safely parse. '
      'No provider-specific payload was reused.',
    );
  } else if (kind == ProviderFailureKind.providerUnavailable) {
    details.add(
      'The selected provider route is temporarily unavailable. You may retry '
      'once; Plawie will not switch providers automatically.',
    );
  } else if (retry == ProviderRetryDisposition.retryOnce) {
    details.add('You may retry once. Provider switching is never automatic.');
  }
  final fallbackId = suggestedFallbackModelId?.trim() ?? '';
  if (fallbackId.isNotEmpty &&
      sideEffects == ProviderSideEffectStatus.noneObserved &&
      (kind == ProviderFailureKind.schemaRejected ||
          kind == ProviderFailureKind.modelUnavailable ||
          kind == ProviderFailureKind.providerRejected)) {
    final fallbackLabel = suggestedFallbackLabel?.trim();
    details.add(
      'Verified same-provider option: '
      '${fallbackLabel?.isNotEmpty == true ? fallbackLabel : fallbackId} '
      '($fallbackId). Plawie did not switch models or resend your message. '
      'Choose it from the model picker only if you want to retry.',
    );
  }
  return details.join('\n\n');
}

String _phaseLabel(ProviderTurnPhase phase) => switch (phase) {
      ProviderTurnPhase.preflight => 'before submission',
      ProviderTurnPhase.submission => 'Gateway submission',
      ProviderTurnPhase.providerGeneration => 'provider generation',
      ProviderTurnPhase.toolCall => 'after tool-call emission',
      ProviderTurnPhase.toolResultContinuation => 'tool-result continuation',
      ProviderTurnPhase.finalResponse => 'final assistant response',
      ProviderTurnPhase.transport => 'Gateway transport',
    };

String _sanitize(String rawError) {
  var value = rawError.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.isEmpty || value.toLowerCase() == 'null') {
    value = 'Gateway/provider returned an empty error payload.';
  }
  value = value.replaceAllMapped(
    RegExp(
      r'\b(api[-_ ]?key|token|secret|password|authorization|signature)\b\s*[:=]\s*[^,\s]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=[redacted]',
  );
  return value.length <= 900 ? value : '${value.substring(0, 899)}…';
}

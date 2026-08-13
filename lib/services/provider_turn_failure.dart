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
  });

  final ProviderFailureKind kind;
  final ProviderTurnPhase phase;
  final ProviderSideEffectStatus sideEffectStatus;
  final ProviderRetryDisposition retryDisposition;
  final String message;
  final String? modelId;

  /// Provider turns are never replayed silently. Even a safe initial rejection
  /// is returned to the user so they choose whether to retry or switch.
  bool get allowsAutomaticReplay => false;

  factory ProviderTurnFailure.classify(
    String rawError, {
    required ProviderTurnTrace trace,
    String? modelId,
    bool timeout = false,
    bool transport = false,
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
            : kind == ProviderFailureKind.schemaRejected
                ? ProviderRetryDisposition.askBeforeSwitching
                : ProviderRetryDisposition.retryOnce;

    return ProviderTurnFailure(
      kind: kind,
      phase: phase,
      sideEffectStatus: sideEffects,
      retryDisposition: retry,
      modelId: modelId?.trim().isEmpty == false ? modelId!.trim() : null,
      message: _messageFor(
        sanitized,
        kind: kind,
        phase: phase,
        sideEffects: sideEffects,
        retry: retry,
        modelId: modelId,
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
  return ProviderFailureKind.providerRejected;
}

String _messageFor(
  String raw, {
  required ProviderFailureKind kind,
  required ProviderTurnPhase phase,
  required ProviderSideEffectStatus sideEffects,
  required ProviderRetryDisposition retry,
  String? modelId,
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
  } else if (retry == ProviderRetryDisposition.retryOnce) {
    details.add('You may retry once. Provider switching is never automatic.');
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

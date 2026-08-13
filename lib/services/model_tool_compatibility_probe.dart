import 'dart:convert';

/// Foreground-only, side-effect-free proof that one exact model can complete
/// both halves of an OpenClaw tool turn.
///
/// The probe deliberately uses OpenClaw's existing read-only `session_status`
/// tool instead of adding a permanent diagnostic tool to every normal model
/// request. This keeps the production tool schema unchanged while still
/// exercising schema acceptance, tool choice, result replay, and final text.
class ModelToolCompatibilityProbe {
  const ModelToolCompatibilityProbe._();

  static const String toolName = 'session_status';
  static const String completionMarker = 'PLAWIE TOOL COMPATIBILITY VERIFIED';
  static const String prompt = '''
[PLAWIE_EXPLICIT_TOOL_COMPATIBILITY_PROBE_V1]
This is a user-approved, side-effect-free compatibility test.
Call the session_status tool exactly once with this exact input:
{"sessionKey":"current"}
Do not call any other tool. After the tool result returns, reply with exactly:
PLAWIE TOOL COMPATIBILITY VERIFIED
''';

  static bool isProbe(String value) => value.trim() == prompt.trim();

  /// Prompt text is not authority. Only the app-owned foreground action may
  /// opt a turn into receipt evaluation.
  static bool isAuthorizedProbe(
    String value, {
    required bool authorized,
  }) =>
      authorized && isProbe(value);

  static ModelToolProbeVerdict evaluate({
    required List<ModelToolProbeEvent> toolCalls,
    required List<ModelToolProbeEvent> toolResults,
    required String assistantText,
    required bool terminalFrameObserved,
  }) {
    if (!terminalFrameObserved) {
      return const ModelToolProbeVerdict.failed(
        'The Gateway stream did not reach a terminal frame.',
      );
    }
    if (toolCalls.length != 1) {
      return ModelToolProbeVerdict.failed(
        'Expected one tool call but observed ${toolCalls.length}.',
      );
    }
    if (toolResults.length != 1) {
      return ModelToolProbeVerdict.failed(
        'Expected one tool result but observed ${toolResults.length}.',
      );
    }
    final call = toolCalls.single;
    final result = toolResults.single;
    if (call.name != toolName || result.name != toolName) {
      return const ModelToolProbeVerdict.failed(
        'The model selected a tool outside the compatibility contract.',
      );
    }
    if (!_hasExactInput(call.payload)) {
      return const ModelToolProbeVerdict.failed(
        'The model changed the bounded compatibility input.',
      );
    }
    if (!_hasResult(result.payload)) {
      return const ModelToolProbeVerdict.failed(
        'The read-only tool returned no result.',
      );
    }
    final callId = call.callId?.trim();
    final resultId = result.callId?.trim();
    if (callId?.isNotEmpty == true &&
        resultId?.isNotEmpty == true &&
        callId != resultId) {
      return const ModelToolProbeVerdict.failed(
        'The tool result was not correlated to the emitted call.',
      );
    }
    if (assistantText.trim() != completionMarker) {
      return const ModelToolProbeVerdict.failed(
        'The provider did not complete the post-tool response contract.',
      );
    }
    return const ModelToolProbeVerdict.passed();
  }

  static bool _hasExactInput(Object? payload) {
    final map = _asMap(payload);
    return map != null &&
        map.length == 1 &&
        map['sessionKey']?.toString() == 'current';
  }

  static bool _hasResult(Object? payload) {
    if (payload == null) return false;
    if (payload is String) return payload.trim().isNotEmpty;
    if (payload is Iterable) return payload.isNotEmpty;
    if (payload is Map) return payload.isNotEmpty;
    return true;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}

class ModelToolProbeEvent {
  const ModelToolProbeEvent({
    required this.name,
    required this.payload,
    this.callId,
  });

  final String name;
  final Object? payload;
  final String? callId;
}

class ModelToolProbeVerdict {
  const ModelToolProbeVerdict._({required this.passed, this.reason});

  const ModelToolProbeVerdict.passed() : this._(passed: true);
  const ModelToolProbeVerdict.failed(String reason)
      : this._(passed: false, reason: reason);

  final bool passed;
  final String? reason;
}

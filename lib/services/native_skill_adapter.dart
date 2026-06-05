import 'skill_execution_descriptor.dart';

typedef NativePythonRunner = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);

class NativeSkillExecutionRequest {
  final SkillExecutionDescriptor descriptor;
  final List<SkillExecutionAction> actions;
  final Duration timeout;

  const NativeSkillExecutionRequest({
    required this.descriptor,
    required this.actions,
    this.timeout = const Duration(seconds: 90),
  });
}

class NativeSkillAdapterResult {
  final bool ok;
  final Map<String, dynamic>? data;
  final Map<String, dynamic> raw;
  final String? error;
  final int durationMs;

  const NativeSkillAdapterResult({
    required this.ok,
    required this.raw,
    required this.durationMs,
    this.data,
    this.error,
  });
}

abstract class NativeSkillAdapter {
  bool canExecute(SkillExecutionDescriptor descriptor);

  Future<NativeSkillAdapterResult> execute(
    NativeSkillExecutionRequest request,
  );
}

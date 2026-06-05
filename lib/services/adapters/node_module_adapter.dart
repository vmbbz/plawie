import '../native_skill_adapter.dart';
import '../skill_execution_descriptor.dart';

class NodeModuleAdapter implements NativeSkillAdapter {
  final NativeNodeRunner? nodeRunner;

  const NodeModuleAdapter({this.nodeRunner});

  @override
  bool canExecute(SkillExecutionDescriptor descriptor) {
    return descriptor.runtime == SkillExecutionRuntime.node &&
        descriptor.mode == SkillExecutionMode.nodeModule &&
        descriptor.entrypoint.trim().isNotEmpty;
  }

  @override
  Future<NativeSkillAdapterResult> execute(
    NativeSkillExecutionRequest request,
  ) async {
    final descriptor = request.descriptor;
    if (!canExecute(descriptor)) {
      return NativeSkillAdapterResult(
        ok: false,
        raw: const <String, dynamic>{},
        durationMs: 0,
        error:
            'Unsupported skill descriptor: ${descriptor.runtime.name}/${descriptor.mode.name}',
      );
    }
    final runner = nodeRunner;
    if (runner == null) {
      return NativeSkillAdapterResult(
        ok: false,
        raw: const <String, dynamic>{
          'errorCode': 'native_node_runner_missing',
        },
        durationMs: 0,
        error:
            'Native Node module execution requires a registered NativeNodeRunner; PRoot was not used.',
      );
    }

    final startedAt = DateTime.now();
    final raw = await runner({
      'cwd': descriptor.rootPath,
      'entrypoint': descriptor.entrypoint,
      'skillId': descriptor.skillId,
      'actions': request.actions.map((action) => action.toJson()).toList(),
    }).timeout(
      request.timeout,
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'error': '${descriptor.skillId} timed out after '
            '${request.timeout.inSeconds} seconds.',
      },
    );
    final completedAt = DateTime.now();
    final ok = raw['ok'] == true;
    final data = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw['payload'] is Map
            ? Map<String, dynamic>.from(raw['payload'] as Map)
            : null;

    return NativeSkillAdapterResult(
      ok: ok && data != null,
      data: data,
      raw: raw,
      error: ok && data != null
          ? null
          : raw['error']?.toString() ?? 'Native Node skill returned no data.',
      durationMs: completedAt.difference(startedAt).inMilliseconds,
    );
  }
}

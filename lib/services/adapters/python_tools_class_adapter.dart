import 'dart:async';
import 'dart:convert';

import '../native_skill_adapter.dart';
import '../skill_execution_descriptor.dart';

class PythonToolsClassAdapter implements NativeSkillAdapter {
  final NativePythonRunner pythonRunner;
  final String pythonHome;
  final String sitePackages;

  const PythonToolsClassAdapter({
    required this.pythonRunner,
    required this.pythonHome,
    required this.sitePackages,
  });

  @override
  bool canExecute(SkillExecutionDescriptor descriptor) {
    return descriptor.runtime == SkillExecutionRuntime.python &&
        descriptor.mode == SkillExecutionMode.pythonToolsClass &&
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

    final scriptDir = _scriptDir(descriptor);
    final payload = <String, dynamic>{
      'cwd': descriptor.rootPath,
      'args': ['-c', _pythonProgram(request)],
      'pythonPaths': [sitePackages, scriptDir],
      'env': {
        'OPENCLAW_NATIVE_PYTHON_HOME': pythonHome,
        'OPENCLAW_NATIVE_PYTHON_SITE_PACKAGES': sitePackages,
      },
    };

    final startedAt = DateTime.now();
    final raw = await pythonRunner(payload).timeout(
      request.timeout,
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'exitCode': 124,
        'stdout': '',
        'stderr':
            '${descriptor.skillId} timed out after ${request.timeout.inSeconds} seconds.',
      },
    );
    final completedAt = DateTime.now();
    final ok = raw['ok'] == true || raw['exitCode'] == 0;
    final decoded = _decodeJsonFromStdout(raw['stdout']);
    final error =
        ok && decoded != null ? null : _nativePythonError(raw, decoded == null);

    return NativeSkillAdapterResult(
      ok: ok && decoded != null,
      data: decoded,
      raw: raw,
      error: error,
      durationMs: completedAt.difference(startedAt).inMilliseconds,
    );
  }

  static String _pythonProgram(NativeSkillExecutionRequest request) {
    final descriptor = request.descriptor;
    final module = _moduleName(descriptor.entrypoint);
    final className = descriptor.className ?? 'Tools';
    final actionsJson = jsonEncode(
      request.actions.map((action) => action.toJson()).toList(),
    );
    return '''
import asyncio, json, os, sys
from $module import $className

actions = json.loads(${jsonEncode(actionsJson)})

async def main():
    tools = $className()
    output = {}
    for action in actions:
        method_name = action["method"]
        args = action.get("args") or {}
        method = getattr(tools, method_name)
        output[action["label"]] = await method(**args)
    print(json.dumps(output, ensure_ascii=False))

asyncio.run(main())
''';
  }

  static String _scriptDir(SkillExecutionDescriptor descriptor) {
    final normalized = descriptor.entrypoint.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    if (slash <= 0) return descriptor.rootPath;
    return '${descriptor.rootPath}/${normalized.substring(0, slash)}';
  }

  static String _moduleName(String entrypoint) {
    final normalized = entrypoint.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    return fileName.replaceFirst(RegExp(r'\.py$'), '');
  }

  static Map<String, dynamic>? _decodeJsonFromStdout(dynamic stdoutValue) {
    final stdout = stdoutValue?.toString().trim() ?? '';
    if (stdout.isEmpty) return null;
    for (final line in stdout.split('\n').reversed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static String _nativePythonError(
    Map<String, dynamic> raw,
    bool decodedMissing,
  ) {
    final stderr = raw['stderr']?.toString().trim() ?? '';
    final stdout = raw['stdout']?.toString().trim() ?? '';
    if (stderr.isNotEmpty) return _trimForDiagnostics(stderr, maxChars: 1200);
    if (stdout.isNotEmpty && decodedMissing) {
      return 'Skill returned non-JSON output: ${_trimForDiagnostics(stdout)}';
    }
    return 'Native Python exited with code ${raw['exitCode'] ?? 'unknown'}.';
  }

  static String _trimForDiagnostics(String value, {int maxChars = 1600}) {
    final compact = value.trim();
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars)}...';
  }
}

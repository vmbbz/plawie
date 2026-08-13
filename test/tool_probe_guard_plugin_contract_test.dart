import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:clawa/services/model_tool_compatibility_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pluginRoot = 'assets/openclaw/plugins/plawie-tool-probe-guard';

  test('guard is dependency-free and pinned to the supported Gateway line',
      () async {
    final package = jsonDecode(
      await File('$pluginRoot/package.json').readAsString(),
    ) as Map<String, dynamic>;
    final manifest = jsonDecode(
      await File('$pluginRoot/openclaw.plugin.json').readAsString(),
    ) as Map<String, dynamic>;
    final openclaw = package['openclaw']! as Map<String, dynamic>;

    expect(package['private'], isTrue);
    expect(package, isNot(contains('dependencies')));
    expect(openclaw['extensions'], <String>['./index.js']);
    expect(
      (openclaw['compat']! as Map<String, dynamic>)['pluginApi'],
      '>=2026.7.1 <2026.8.0',
    );
    expect(manifest['id'], 'plawie-tool-probe-guard');
  });

  test('guard binds exact probe runs and blocks every non-status tool',
      () async {
    final source = await File('$pluginRoot/index.js').readAsString();

    expect(source, contains('before_agent_run'));
    expect(source, contains('before_tool_call'));
    expect(source, contains('agent_end'));
    expect(source, contains('event?.toolName !== ALLOWED_TOOL'));
    expect(source, contains('params.sessionKey === "current"'));
    expect(source, contains('block: true'));
    expect(source, contains('MAX_TRACKED_RUNS = 8'));
    expect(source, contains('RUN_TTL_MS = 10 * 60 * 1000'));
    expect(source, isNot(contains('fetch(')));
    expect(source, isNot(contains('writeFile')));
  });

  test('Gateway guard and Flutter use the same exact probe prompt', () async {
    final source = await File('$pluginRoot/index.js').readAsString();
    final match = RegExp(
      r'const PROBE_PROMPT = `([\s\S]*?)`;',
    ).firstMatch(source);

    expect(match, isNotNull);
    String normalize(String value) => value.replaceAll('\r\n', '\n').trim();
    expect(
      normalize(match!.group(1)!),
      normalize(ModelToolCompatibilityProbe.prompt),
    );
  });

  test('Android bootstrap pins every guard asset hash', () async {
    final native = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NativeNodeEmbeddedService.kt',
    ).readAsString();

    for (final name in <String>[
      'index.js',
      'openclaw.plugin.json',
      'package.json',
    ]) {
      final bytes = await File('$pluginRoot/$name').readAsBytes();
      expect(native, contains(sha256.convert(bytes).toString()));
    }
    expect(native, contains('PLAWIE_TOOL_PROBE_GUARD_PLUGIN_ID'));
    expect(native, contains('provisionVerifiedOpenClawPlugin'));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pluginRoot = 'assets/openclaw/plugins/plawie-venice-compat';

  test('plugin is dependency-free and pinned to the supported Gateway line',
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
    expect(openclaw['providers'], <String>['venice']);
    expect(
      (openclaw['compat']! as Map<String, dynamic>)['pluginApi'],
      '>=2026.7.1 <2026.8.0',
    );
    expect(manifest['id'], 'plawie-venice-compat');
    expect(manifest['providers'], <String>['venice']);
  });

  test('plugin delegates to official hooks and is exact Venice-Gemini scoped',
      () async {
    final source = await File('$pluginRoot/index.js').readAsString();

    expect(source, contains('buildProviderReplayFamilyHooks'));
    expect(source, contains('family: "passthrough-gemini"'));
    expect(source, contains('buildProviderToolCompatFamilyHooks("gemini")'));
    expect(source, contains('String(context?.provider || "")'));
    expect(source, contains('!== PROVIDER_ID'));
    expect(source, contains(r'/^gemini(?:[-/.]|$)/'));
    expect(source, isNot(contains('fetch(')));
    expect(source, isNot(contains('thought_signature:')));
    expect(source, isNot(contains('blockrun')));
  });

  test(
      'Android bootstrap pins every plugin asset hash and activates atomically',
      () async {
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
    expect(native, contains('provisionVerifiedOpenClawPlugins'));
    expect(native, contains('.staging'));
    expect(native, contains('staging.renameTo(target)'));
    expect(native, contains('PLAWIE_VENICE_COMPAT_PLUGIN_MAX_GATEWAY_VERSION'));
  });
}

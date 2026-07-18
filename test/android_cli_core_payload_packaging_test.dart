import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android executable dependency packs are remote and verified', () async {
    final manifest = jsonDecode(
      await File('android-arm64-v8a.json').readAsString(),
    ) as Map<String, dynamic>;
    final packs = (manifest['packs'] as List).cast<Map>();
    final byId = <String, Map>{
      for (final pack in packs) pack['id'].toString(): pack,
    };
    const expectedIds = <String>{
      'android-whisper-runtime',
      'android-tts-runtime',
      'android-cli-core-pack',
      'android-vision-media-pack',
      'android-audio-runtime-pack',
      'android-terminal-pack',
      'android-agent-cli-pack',
    };

    expect(byId.keys, containsAll(expectedIds));
    for (final id in expectedIds) {
      final pack = byId[id]!;
      expect(pack['source'], 'remote', reason: id);
      expect(pack['url'], startsWith('https://github.com/'), reason: id);
      expect(pack['sha256'].toString(), matches(RegExp(r'^[a-f0-9]{64}$')),
          reason: id);
      expect(pack['signature'], isA<Map>(), reason: id);
      expect((pack['files'] as List), isNotEmpty, reason: id);
    }
  });

  test('APK no longer declares removed executable dependency payloads',
      () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final nativeBootstrap = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/'
      'NativeNodeEmbeddedService.kt',
    ).readAsString();

    for (final obsoletePath in [
      'assets/openclaw/cli-core/bin/',
      'assets/openclaw/vision-media/bin/',
      'assets/openclaw/audio-runtime/bin/',
      'assets/openclaw/terminal/bin/',
      'assets/openclaw/terminal/lib/',
    ]) {
      expect(pubspec, isNot(contains(obsoletePath)));
      expect(nativeBootstrap, isNot(contains(obsoletePath)));
    }
  });

  test('the retained APK Python debug wheel remains packaged', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final bootstrap = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/'
      'NativeNodeEmbeddedService.kt',
    ).readAsString();

    expect(pubspec, contains('assets/openclaw/python-debug-runtime/wheels/'));
    expect(bootstrap, contains('PYTHON_DEBUG_WHEEL_ASSET_DIR'));
    expect(bootstrap, contains('copyPythonDebugWheelAssets'));
  });
}

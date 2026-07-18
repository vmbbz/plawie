import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap pins compatible Node and OpenClaw releases', () async {
    final constants = await File('lib/constants.dart').readAsString();
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final nativeBootstrap = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/BootstrapManager.kt',
    ).readAsString();

    expect(constants, contains("nodeVersion = '22.22.3'"));
    expect(bootstrap, contains("_requiredOpenClawVersion = '2026.7.1'"));
    expect(bootstrap, contains('openclaw@2026.7.1'));
    expect(nativeBootstrap, contains('requiredOpenClawVersion = "2026.7.1"'));
    expect(nativeBootstrap, contains('minimumNodeVersion = listOf(22, 22, 3)'));
  });

  test('npm repair removes stale global launchers before installing', () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final nativeBootstrap = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/BootstrapManager.kt',
    ).readAsString();

    for (final source in [bootstrap, nativeBootstrap]) {
      expect(source, contains('/usr/local/bin/openclaw'));
      expect(source, contains('rm -rf /usr/local/lib/node_modules/openclaw'));
    }
  });

  test('fresh setup gates completion on dependency-pack verification',
      () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final provisioning = await File(
      'lib/services/skill_provisioning_service.dart',
    ).readAsString();

    expect(bootstrap, contains('final packsReady ='));
    expect(bootstrap, contains('if (!packsReady)'));
    expect(provisioning, contains('onProgress(pack.id, 1.0);'));
  });

  test('remote dependency packs require pinned Ed25519 verification', () async {
    final provisioning = await File(
      'lib/services/skill_provisioning_service.dart',
    ).readAsString();
    final signingKeys =
        await File('lib/services/signing_keys.dart').readAsString();
    final signingDocs = await File('docs/SIGNING_KEYS.md').readAsString();

    expect(provisioning, contains('_verifyDependencyPackSignature'));
    expect(provisioning, contains('Ed25519().verify'));
    expect(provisioning, contains('kDependencyPackSigningKeyId'));
    expect(signingKeys, contains("kDependencyPackPublicKey = r'''"));
    expect(signingDocs, isNot(contains('BEGIN PRIVATE KEY')));
  });
}

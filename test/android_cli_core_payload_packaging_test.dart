import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec declares the Android CLI-core bin asset directory', () async {
    final pubspec = await File('pubspec.yaml').readAsString();

    expect(pubspec, contains('assets/openclaw/cli-core/bin/'));
  });

  test('Native bootstrap extracts CLI-core assets into provisioning bin',
      () async {
    final bootstrap = await File(
      'android/app/src/main/kotlin/com/nxg/openclawproot/'
      'NativeNodeEmbeddedService.kt',
    ).readAsString();

    expect(
      bootstrap,
      contains(
        'CLI_CORE_BIN_ASSET_DIR = '
        '"flutter_assets/assets/openclaw/cli-core/bin"',
      ),
    );
    expect(
      bootstrap,
      contains('copyCliCoreBinAssets(File(workDir(applicationContext), "provisioning/bin"))'),
    );
    expect(bootstrap, contains('assets.list(CLI_CORE_BIN_ASSET_DIR)'));
    expect(bootstrap, contains('target.setExecutable(true, false)'));
  });
}

import 'dart:io';
import 'dart:typed_data';

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
      contains(
          'copyCliCoreBinAssets(File(workDir(applicationContext), "provisioning/bin"))'),
    );
    expect(bootstrap, contains('assets.list(CLI_CORE_BIN_ASSET_DIR)'));
    expect(bootstrap, contains('target.setExecutable(true, false)'));
  });

  test('OpenHue APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('openhue');
  });

  test('Eightctl APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('eightctl');
  });

  test('Sonos APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('sonos');
  });

  test('OpenHue payload has pinned build provenance', () async {
    const openHueCommit = '08e940a9cd1c49c2da0a714dc8bb07ee60e9cd21';
    const goArchiveSha =
        '3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345';
    const payloadSha =
        '281cf0c17f593a32fe83571db7f467c956cd92a1b4bded26f6c8a8408f0ba3f9';

    final script =
        await File('scripts/cli_core/build_openhue_android_arm64.ps1')
            .readAsString();
    final docs =
        await File('docs/CLI_CORE_OPENHUE_ANDROID_PAYLOAD.md').readAsString();

    expect(script, contains(openHueCommit));
    expect(script.toLowerCase(), contains(goArchiveSha));
    expect(script, contains(r"$env:GOOS = 'android'"));
    expect(script, contains(r"$env:GOARCH = 'arm64'"));
    expect(script, contains(r"$env:CGO_ENABLED = '0'"));
    expect(docs, contains(openHueCommit));
    expect(docs.toLowerCase(), contains(payloadSha));
  });

  test('Eightctl payload has pinned build provenance', () async {
    const eightctlCommit = '2f2c73f0a529e9138707a237135fcaadfe56617e';
    const goArchiveSha =
        '3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345';
    const payloadSha =
        '8242e7624b6c0e3c9bd1fa932b515f8d589c47be09940da9032230f75d88d755';

    final script =
        await File('scripts/cli_core/build_eightctl_android_arm64.ps1')
            .readAsString();
    final docs =
        await File('docs/CLI_CORE_EIGHTCTL_ANDROID_PAYLOAD.md').readAsString();

    expect(script, contains(eightctlCommit));
    expect(script.toLowerCase(), contains(goArchiveSha));
    expect(script, contains(r"$env:GOOS = 'android'"));
    expect(script, contains(r"$env:GOARCH = 'arm64'"));
    expect(script, contains(r"$env:CGO_ENABLED = '0'"));
    expect(docs, contains(eightctlCommit));
    expect(docs.toLowerCase(), contains(payloadSha));
  });

  test('Sonos payload has pinned build provenance', () async {
    const sonosCommit = '87f409ab218a19a03cad630458258b291c365d8b';
    const goArchiveSha =
        '3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345';
    const payloadSha =
        '411713ad1cd0e6841db7f5a6583d9d2f1767c1ef8c5f1cf143a666d5717ee8b5';

    final script = await File('scripts/cli_core/build_sonos_android_arm64.ps1')
        .readAsString();
    final docs =
        await File('docs/CLI_CORE_SONOS_ANDROID_PAYLOAD.md').readAsString();

    expect(script, contains(sonosCommit));
    expect(script.toLowerCase(), contains(goArchiveSha));
    expect(script, contains(r"$env:GOOS = 'android'"));
    expect(script, contains(r"$env:GOARCH = 'arm64'"));
    expect(script, contains(r"$env:CGO_ENABLED = '0'"));
    expect(docs, contains(sonosCommit));
    expect(docs.toLowerCase(), contains(payloadSha));
  });
}

Future<void> expectAndroidArm64ElfPayload(String binaryName) async {
  final payload = File('assets/openclaw/cli-core/bin/$binaryName');

  expect(await payload.exists(), isTrue);
  final bytes = await payload.readAsBytes();
  expect(bytes.length, greaterThan(1024 * 1024));
  expect(String.fromCharCodes(bytes.take(2)), isNot('#!'));
  expect(bytes[0], 0x7f);
  expect(bytes[1], 0x45);
  expect(bytes[2], 0x4c);
  expect(bytes[3], 0x46);
  expect(bytes[4], 2, reason: 'ELF64');
  expect(bytes[5], 1, reason: 'little endian');

  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect(data.getUint16(18, Endian.little), 183, reason: 'AArch64');
}

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
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
          'val provisioningBin = File(workDir(applicationContext), "provisioning/bin")'),
    );
    expect(bootstrap, contains('copyCliCoreBinAssets(provisioningBin)'));
    expect(bootstrap, contains('copyBundledBinAssets(CLI_CORE_BIN_ASSET_DIR'));
    expect(bootstrap, contains('target.setExecutable(true, false)'));
  });

  test('Native bootstrap extracts vision-media assets into provisioning bin',
      () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final bootstrap = await File(
      'android/app/src/main/kotlin/com/nxg/openclawproot/'
      'NativeNodeEmbeddedService.kt',
    ).readAsString();

    expect(pubspec, contains('assets/openclaw/vision-media/bin/'));
    expect(bootstrap, contains('VISION_MEDIA_BIN_ASSET_DIR'));
    expect(
        bootstrap, contains('flutter_assets/assets/openclaw/vision-media/bin'));
    expect(
      bootstrap,
      contains(
          'val provisioningBin = File(workDir(applicationContext), "provisioning/bin")'),
    );
    expect(
      bootstrap,
      contains('copyVisionMediaBinAssets(provisioningBin)'),
    );
  });

  test('OpenHue APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('openhue');
  });

  test('Eightctl APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('eightctl');
  });

  test('Himalaya APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('himalaya');
  });

  test('Sonos APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('sonos');
  });

  test('Blu APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('blu');
  });

  test('Wacli APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayload('wacli');
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

  test('Himalaya payload has pinned Rust build provenance', () async {
    const himalayaCommit = '1b70c4e0eaa72dee48353f0211e6cc0f0776fe98';
    const rustupInitSha =
        '86478e53f769379d7f0ebfa7c9aa97cb76ca92233f79aa2cc0dbee2efaac73c7';

    final script =
        await File('scripts/cli_core/build_himalaya_android_arm64.ps1')
            .readAsString();
    final docs =
        await File('docs/CLI_CORE_HIMALAYA_ANDROID_PAYLOAD.md').readAsString();
    final payloadSha =
        await sha256File(File('assets/openclaw/cli-core/bin/himalaya'));

    expect(script, contains(himalayaCommit));
    expect(script.toLowerCase(), contains(rustupInitSha));
    expect(script, contains('1.93.0'));
    expect(script, contains('aarch64-linux-android'));
    expect(script, contains(r'$env:CC_aarch64_linux_android'));
    expect(script, contains(r'Remove-Item Env:CC'));
    expect(docs, contains(himalayaCommit));
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

  test('Blu payload has pinned build provenance', () async {
    const bluCommit = 'b5ba7d004448f945acff8ea56034cfe4138be5b6';
    const goArchiveSha =
        '3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345';
    const payloadSha =
        '9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442';

    final script = await File('scripts/cli_core/build_blu_android_arm64.ps1')
        .readAsString();
    final docs =
        await File('docs/CLI_CORE_BLU_ANDROID_PAYLOAD.md').readAsString();

    expect(script, contains(bluCommit));
    expect(script.toLowerCase(), contains(goArchiveSha));
    expect(script, contains(r"$env:GOOS = 'android'"));
    expect(script, contains(r"$env:GOARCH = 'arm64'"));
    expect(script, contains(r"$env:CGO_ENABLED = '0'"));
    expect(docs, contains(bluCommit));
    expect(docs.toLowerCase(), contains(payloadSha));
  });

  test('Wacli payload has pinned cgo build provenance', () async {
    const wacliCommit = 'be2d22fe9d8ca99bf4c027708ae494e9035fe489';
    const goArchiveSha =
        '3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345';

    final script = await File('scripts/cli_core/build_wacli_android_arm64.ps1')
        .readAsString();
    final docs =
        await File('docs/CLI_CORE_WACLI_ANDROID_PAYLOAD.md').readAsString();
    final payloadSha =
        await sha256File(File('assets/openclaw/cli-core/bin/wacli'));

    expect(script, contains(wacliCommit));
    expect(script.toLowerCase(), contains(goArchiveSha));
    expect(script, contains(r"$env:GOOS = 'android'"));
    expect(script, contains(r"$env:GOARCH = 'arm64'"));
    expect(script, contains(r"$env:CGO_ENABLED = '1'"));
    expect(script, contains(r'$env:CC'));
    expect(script, contains('aarch64-linux-android'));
    expect(script, contains('-tags'));
    expect(script, contains('sqlite_fts5'));
    expect(docs, contains(wacliCommit));
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

Future<String> sha256File(File file) async {
  final bytes = await file.readAsBytes();
  return crypto.sha256.convert(bytes).toString();
}

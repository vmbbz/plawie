import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

  test('Native bootstrap extracts Python debug wheel assets into provisioning',
      () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final bootstrap = await File(
      'android/app/src/main/kotlin/com/nxg/openclawproot/'
      'NativeNodeEmbeddedService.kt',
    ).readAsString();

    expect(pubspec, contains('assets/openclaw/python-debug-runtime/wheels/'));
    expect(bootstrap, contains('PYTHON_DEBUG_WHEEL_ASSET_DIR'));
    expect(
      bootstrap,
      contains('flutter_assets/assets/openclaw/python-debug-runtime/wheels'),
    );
    expect(bootstrap, contains('copyPythonDebugWheelAssets'));
    expect(
      bootstrap,
      contains('provisioning/python-debug/wheels'),
    );
    expect(bootstrap, contains('pythonDebugWheelCount'));
  });

  test('Native bootstrap declares terminal pack bin and lib asset lanes',
      () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final bootstrap = await File(
      'android/app/src/main/kotlin/com/nxg/openclawproot/'
      'NativeNodeEmbeddedService.kt',
    ).readAsString();

    expect(pubspec, contains('assets/openclaw/terminal/bin/'));
    expect(pubspec, contains('assets/openclaw/terminal/lib/'));
    expect(bootstrap, contains('TERMINAL_BIN_ASSET_DIR'));
    expect(bootstrap, contains('TERMINAL_LIB_ASSET_DIR'));
    expect(
      bootstrap,
      contains('flutter_assets/assets/openclaw/terminal/bin'),
    );
    expect(
      bootstrap,
      contains('flutter_assets/assets/openclaw/terminal/lib'),
    );
    expect(bootstrap, contains('copyTerminalBinAssets'));
    expect(bootstrap, contains('copyTerminalLibAssets'));
    expect(bootstrap, contains('provisioning/terminal/bin'));
    expect(bootstrap, contains('provisioning/terminal/lib'));
    expect(bootstrap, contains('terminalBinCount'));
    expect(bootstrap, contains('terminalLibCount'));
  });

  test('Native bootstrap declares audio runtime bin asset lane', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final bootstrap = await File(
      'android/app/src/main/kotlin/com/nxg/openclawproot/'
      'NativeNodeEmbeddedService.kt',
    ).readAsString();

    expect(pubspec, contains('assets/openclaw/audio-runtime/bin/'));
    expect(bootstrap, contains('AUDIO_RUNTIME_BIN_ASSET_DIR'));
    expect(
      bootstrap,
      contains('flutter_assets/assets/openclaw/audio-runtime/bin'),
    );
    expect(bootstrap, contains('copyAudioRuntimeBinAssets'));
    expect(bootstrap, contains('provisioning/audio-runtime/bin'));
    expect(bootstrap, contains('audioRuntimeBinCount'));
  });

  test('Tmux terminal APK payload is a real Android arm64 pack', () async {
    const tmuxPayloadSha =
        '9db38fdb4178abd13d19a32f40d265b61473694487e5c6ffc60e43ba11f1ca96';
    const libSha = <String, String>{
      'libandroid-glob.so':
          'e47405b23e40aea9bd5aad4c3cbf518065cba8ef1c4e24c8aae7fd77e10fe850',
      'libandroid-support.so':
          '739cf829511d71dafd6c67fdbb70f3f0c6048642ea2e1967790ee961fde14430',
      'libevent_core-2.1.so':
          '3e5697cf20492127371704d935ef8c7538a6ea82a6dd0fc9b427f8a55b8001f3',
      'libncursesw.so.6':
          '795f855f5a988d9e89116847b2c9aa03720cedbc02026259ca735be25398c4c5',
    };

    final tmux = File('assets/openclaw/terminal/bin/tmux');
    await expectAndroidArm64ElfPayloadAt(tmux, minBytes: 900 * 1024);
    expect(await sha256File(tmux), tmuxPayloadSha);

    for (final entry in libSha.entries) {
      final library = File('assets/openclaw/terminal/lib/${entry.key}');
      await expectAndroidArm64ElfPayloadAt(library, minBytes: 7 * 1024);
      expect(await sha256File(library), entry.value);
    }
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

  test('FFmpeg APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayloadAt(
      File('assets/openclaw/vision-media/bin/ffmpeg'),
    );
  });

  test('Songsee APK payload is a real Android arm64 ELF executable', () async {
    await expectAndroidArm64ElfPayloadAt(
      File('assets/openclaw/audio-runtime/bin/songsee'),
      minBytes: 2 * 1024 * 1024,
    );
  });

  test('Songsee payload has pinned build provenance', () async {
    const songseeCommit = '41d27ea22771ba447bdfb8b6adac2e6599601634';
    const songseeVersion = 'v0.1.1-10-g41d27ea';
    const goArchiveSha =
        '6dad204d42719795f22067553b2b042c0e710b32c5a00f6c67892865167fdfd0';
    final payload = File('assets/openclaw/audio-runtime/bin/songsee');
    final script =
        await File('scripts/audio_runtime/build_songsee_android_arm64.ps1')
            .readAsString();
    final docs =
        await File('docs/ANDROID_AUDIO_RUNTIME_SONGSEE_PAYLOAD.md')
            .readAsString();
    final payloadSha = await sha256File(payload);

    expect(script, contains(songseeCommit));
    expect(script, contains(songseeVersion));
    expect(script.toLowerCase(), contains(goArchiveSha));
    expect(script, contains(r"$env:GOOS = 'android'"));
    expect(script, contains(r"$env:GOARCH = 'arm64'"));
    expect(script, contains(r"$env:CGO_ENABLED = '0'"));
    expect(script, contains('./cmd/songsee'));
    expect(script, contains('assets\\openclaw\\audio-runtime\\bin\\songsee'));
    expect(docs, contains('android-audio-runtime'));
    expect(docs, contains(songseeCommit));
    expect(docs, contains(songseeVersion));
    expect(docs.toLowerCase(), contains(payloadSha));
    expect(docs, contains('MIT License'));
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

  test('FFmpeg payload has pinned LGPL Android build provenance', () async {
    const ffmpegVersion = '8.1.1';
    const sourceSha =
        'b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3';

    final script =
        await File('scripts/vision_media/build_ffmpeg_android_arm64.sh')
            .readAsString();
    final docs = await File('docs/ANDROID_VISION_MEDIA_FFMPEG_PAYLOAD.md')
        .readAsString();
    final notices =
        await File('docs/THIRD_PARTY_NOTICES_FFMPEG.md').readAsString();
    final payloadSha =
        await sha256File(File('assets/openclaw/vision-media/bin/ffmpeg'));

    expect(script, contains('ffmpeg-$ffmpegVersion.tar.xz'));
    expect(script.toLowerCase(), contains(sourceSha));
    expect(script, contains('--target-os=android'));
    expect(script, contains('--arch=aarch64'));
    expect(script, contains('--enable-cross-compile'));
    expect(script, contains('--disable-gpl'));
    expect(script, contains('--disable-nonfree'));
    expect(script, isNot(contains('--enable-gpl')));
    expect(script, isNot(contains('--enable-nonfree')));
    expect(script, contains('aarch64-linux-android'));
    expect(docs, contains('FFmpeg $ffmpegVersion'));
    expect(docs.toLowerCase(), contains(sourceSha));
    expect(docs.toLowerCase(), contains(payloadSha));
    expect(docs, contains('LGPL'));
    expect(notices, contains('FFmpeg'));
    expect(notices, contains('LGPL'));
  });

  test('Debugpy APK wheel payload has pinned provenance', () async {
    const debugpyVersion = '1.8.21';
    final wheel = File('assets/openclaw/python-debug-runtime/wheels/'
        'debugpy-$debugpyVersion-py2.py3-none-any.whl');
    final script =
        await File('scripts/python_debug/build_debugpy_android_runtime.ps1')
            .readAsString();
    final docs = await File('docs/ANDROID_PYTHON_DEBUG_RUNTIME_PAYLOAD.md')
        .readAsString();

    expect(await wheel.exists(), isTrue);
    final bytes = await wheel.readAsBytes();
    expect(bytes.length, greaterThan(100 * 1024));
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((file) => file.name).toSet();

    expect(names, contains('debugpy/__init__.py'));
    expect(names, contains('debugpy-$debugpyVersion.dist-info/METADATA'));
    expect(script, contains('debugpy==$debugpyVersion'));
    expect(script, contains('sha256'));
    expect(docs, contains('debugpy $debugpyVersion'));
    expect(docs.toLowerCase(), contains(await sha256File(wheel)));
  });

  test('Tmux payload has pinned Termux package provenance', () async {
    const termuxTmuxDebSha =
        'd52ab2155b036d03b47cfb824be41e9fe4fe67b80b457716d81faa38ec1c7319';
    const termuxNcursesDebSha =
        'f44bbfdc3d42ec0217bffa978309390e59cea5a48a9a83226d4a496c42ad0b99';
    const termuxLibeventDebSha =
        '9db37dd4a000ae43eff4e87422e5280be9b6348581702f582d2fe8bddc0f4572';
    const termuxSupportDebSha =
        'f2f145d6135ad4843ac9670153be3e3944dc1e6f1736d46d2306c28f2b86f517';
    const termuxGlobDebSha =
        '2276ae8adedf0db76c2f4ffc94cc4cceb2f4f5d78e021b54e2e046d1233e7826';

    final docs =
        await File('docs/ANDROID_TERMINAL_TMUX_PAYLOAD.md').readAsString();
    final notices =
        await File('docs/THIRD_PARTY_NOTICES_TMUX.md').readAsString();
    final service = await File('lib/services/skill_provisioning_service.dart')
        .readAsString();

    expect(docs, contains('Termux package version: 3.6b'));
    expect(docs, contains('Runtime-reported version: tmux 3.6a'));
    expect(docs.toLowerCase(), contains(termuxTmuxDebSha));
    expect(docs.toLowerCase(), contains(termuxNcursesDebSha));
    expect(docs.toLowerCase(), contains(termuxLibeventDebSha));
    expect(docs.toLowerCase(), contains(termuxSupportDebSha));
    expect(docs.toLowerCase(), contains(termuxGlobDebSha));
    expect(docs, contains('libncursesw.so.6'));
    expect(docs, contains('LD_LIBRARY_PATH'));
    expect(notices, contains('tmux'));
    expect(notices, contains('libevent'));
    expect(notices, contains('ncurses'));
    expect(service, contains("termux-tmux-3.6b-apk-v1"));
  });
}

Future<void> expectAndroidArm64ElfPayload(String binaryName) async {
  await expectAndroidArm64ElfPayloadAt(
    File('assets/openclaw/cli-core/bin/$binaryName'),
  );
}

Future<void> expectAndroidArm64ElfPayloadAt(
  File payload, {
  int minBytes = 1024 * 1024,
}) async {
  expect(await payload.exists(), isTrue);
  final bytes = await payload.readAsBytes();
  expect(bytes.length, greaterThan(minBytes));
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

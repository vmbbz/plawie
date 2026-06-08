# Sonos Android CLI-Core Payload

This document records the third real `android-cli-core-pack` payload bundled
for APK provisioning. It is not a placeholder, shim, script stub, or fake
readiness marker.

## Payload

```text
skill id: sonoscli
asset: assets/openclaw/cli-core/bin/sonos
source: https://github.com/steipete/sonoscli
source commit: 87f409ab218a19a03cad630458258b291c365d8b
source describe: v0.3.1
toolchain: go1.26.4 windows/amd64
toolchain archive sha256: 3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
payload bytes: 10813736
payload sha256: 411713ad1cd0e6841db7f5a6583d9d2f1767c1ef8c5f1cf143a666d5717ee8b5
verified format: ELF64 little-endian AArch64
```

## Rebuild

```powershell
.\scripts\cli_core\build_sonos_android_arm64.ps1 -InstallAsset
```

The script downloads the pinned Go archive if needed, verifies its SHA-256,
checks out the pinned `sonoscli` release commit, builds the real Go CLI for
Android arm64, verifies the output is an ELF64 AArch64 executable, and only then
copies it into the APK asset path when `-InstallAsset` is supplied.

## Current Limits

This payload proves the APK can carry and provision a real `sonos` binary for
the `sonoscli` skill on Android arm64. It does not prove local Sonos discovery,
multicast/SSDP behavior, fallback subnet scanning, speaker control, SMAPI
service auth, YouTube playback, `yt-dlp`, or `ffmpeg`.

The no-secret smoke target is:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/sonos --version

expected output:
sonos 0.3.1
```

Host/APK proof on 2026-06-08:

```text
.\scripts\cli_core\build_sonos_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
411713ad1cd0e6841db7f5a6583d9d2f1767c1ef8c5f1cf143a666d5717ee8b5

flutter test test/android_cli_core_payload_packaging_test.dart
Result: 8/8 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 39/39 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/sonos
length 10813736, sha256
411713ad1cd0e6841db7f5a6583d9d2f1767c1ef8c5f1cf143a666d5717ee8b5
```

Device proof for `sonos --version` and any LAN discovery/control smoke is still
pending. During this round `adb devices -l` returned no connected devices after
the earlier ADB drop.

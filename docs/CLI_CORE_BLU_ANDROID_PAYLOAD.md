# Blu Android CLI-Core Payload

This document records the fourth real `android-cli-core-pack` payload bundled
for APK provisioning. It is not a placeholder, shim, script stub, or fake
readiness marker.

## Payload

```text
skill id: blucli
asset: assets/openclaw/cli-core/bin/blu
source: https://github.com/steipete/blucli
source commit: b5ba7d004448f945acff8ea56034cfe4138be5b6
source describe: v0.1.4
toolchain: go1.26.4 windows/amd64
toolchain archive sha256: 3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
payload bytes: 8257832
payload sha256: 9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442
verified format: ELF64 little-endian AArch64
```

## Rebuild

```powershell
.\scripts\cli_core\build_blu_android_arm64.ps1 -InstallAsset
```

The script downloads the pinned Go archive if needed, verifies its SHA-256,
checks out the pinned `blucli` release commit, builds the real Go CLI for
Android arm64, verifies the output is an ELF64 AArch64 executable, and only then
copies it into the APK asset path when `-InstallAsset` is supplied.

## Current Limits

This payload proves the APK can carry and provision a real `blu` binary for the
`blucli` skill on Android arm64. It does not prove BluOS device discovery, mDNS,
LSDP fallback behavior, player control, Spotify OAuth, or any real-device
network path.

The no-secret smoke target is:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/blu --version

expected output:
v0.1.4
```

Host/APK proof on 2026-06-08:

```text
.\scripts\cli_core\build_blu_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442

flutter test test/android_cli_core_payload_packaging_test.dart
Result: 10/10 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 41/41 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/blu
length 8257832, sha256
9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442
```

Device proof for `blu --version` and BluOS discovery/control smoke is still
pending. During this round `adb devices -l` returned no connected devices after
the earlier ADB drop.

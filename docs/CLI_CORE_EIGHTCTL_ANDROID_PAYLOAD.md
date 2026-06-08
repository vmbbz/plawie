# Eightctl Android CLI-Core Payload

This document records the second real `android-cli-core-pack` payload bundled
for APK provisioning. It is not a placeholder, shim, script stub, or fake
readiness marker.

## Payload

```text
asset: assets/openclaw/cli-core/bin/eightctl
source: https://github.com/steipete/eightctl
source commit: 2f2c73f0a529e9138707a237135fcaadfe56617e
source describe: 2f2c73f
toolchain: go1.26.4 windows/amd64
toolchain archive sha256: 3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
payload bytes: 10158376
payload sha256: 8242e7624b6c0e3c9bd1fa932b515f8d589c47be09940da9032230f75d88d755
verified format: ELF64 little-endian AArch64
```

## Rebuild

```powershell
.\scripts\cli_core\build_eightctl_android_arm64.ps1 -InstallAsset
```

The script downloads the pinned Go archive if needed, verifies its SHA-256,
checks out the pinned `eightctl` commit, builds the real Go CLI for Android
arm64, verifies the output is an ELF64 AArch64 executable, and only then copies
it into the APK asset path when `-InstallAsset` is supplied.

## Current Limits

This payload proves the APK can carry and provision a real `eightctl` binary on
Android arm64. It does not prove Eight Sleep account login, device ownership,
cloud API stability, or successful pod control. Those remain functional gates
that require user-supplied Eight Sleep credentials and a real account/device.

The no-secret smoke target is:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/eightctl version

expected output:
2f2c73f
```

Host/APK proof on 2026-06-08:

```text
.\scripts\cli_core\build_eightctl_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
8242e7624b6c0e3c9bd1fa932b515f8d589c47be09940da9032230f75d88d755

flutter test test/android_cli_core_payload_packaging_test.dart
Result: 6/6 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 37/37 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/eightctl
length 10158376, sha256
8242e7624b6c0e3c9bd1fa932b515f8d589c47be09940da9032230f75d88d755
```

Device proof for `eightctl version` is still pending. During this round the
phone disappeared from ADB during `adb install -r`; after `adb kill-server`,
`adb start-server`, and a wait/recheck, `adb devices -l` returned no connected
devices.

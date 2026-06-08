# Himalaya Android CLI-Core Payload

This document records the sixth real `android-cli-core-pack` payload bundled
for APK provisioning. It is not a placeholder, shim, script stub, or fake
readiness marker.

## Payload

```text
skill id: himalaya
asset: assets/openclaw/cli-core/bin/himalaya
source: https://github.com/pimalaya/himalaya
source commit: 1b70c4e0eaa72dee48353f0211e6cc0f0776fe98
source describe: v1.2.0
rust toolchain: 1.93.0
rustup: 1.29.0
rustup-init sha256: 86478e53f769379d7f0ebfa7c9aa97cb76ca92233f79aa2cc0dbee2efaac73c7
android ndk: 29.0.14206865
android api: 29
build target: aarch64-linux-android
features: upstream default
c compiler: aarch64-linux-android29-clang.cmd
payload bytes: 28958664
payload sha256: 83c900e58ff0ab931187fea7c49a36a29343e291ea8179b876c37bfbb34d572b
verified format: ELF64 little-endian AArch64
```

## Rebuild

```powershell
.\scripts\cli_core\build_himalaya_android_arm64.ps1 -InstallAsset
```

The script downloads the pinned rustup-init bootstrapper if needed, verifies
its SHA-256, installs an isolated Rust toolchain under `.tmp`, adds the
`aarch64-linux-android` target, checks out the pinned Himalaya release commit,
forces Rust `1.93.0` despite upstream's older `rust-toolchain.toml`, builds the
real Rust CLI for Android arm64, verifies the output is an ELF64 AArch64
executable, and only then copies it into the APK asset path when
`-InstallAsset` is supplied.

The script intentionally sets only target-specific Android C compiler variables
and removes global `CC`, `TARGET_CC`, and `AR`, because host build scripts can
otherwise pick up the Android compiler and fail while compiling Windows-host
build dependencies.

## Current Limits

This payload proves the APK can carry and provision a real `himalaya` binary
for Android arm64 with upstream default features. It does not prove user mail
account configuration, IMAP/SMTP connectivity, OAuth/browser flows, PGP command
workflows, or Maildir storage behavior on a real Android device.

The no-secret smoke target is:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/himalaya --version

expected output includes:
himalaya 1.2.0
```

Host build proof on 2026-06-08:

```text
.\scripts\cli_core\build_himalaya_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
83c900e58ff0ab931187fea7c49a36a29343e291ea8179b876c37bfbb34d572b

flutter test test/android_cli_core_payload_packaging_test.dart --no-pub
Result: 14/14 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart --no-pub
Result: 45/45 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/himalaya
length 28958664, sha256
83c900e58ff0ab931187fea7c49a36a29343e291ea8179b876c37bfbb34d572b
```

Device no-secret proof on 2026-06-09:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/himalaya --version

himalaya v1.2.0 +maildir +wizard +smtp +pgp-commands +sendmail +imap
build: android  aarch64
git: v1.2.0, rev 1b70c4e0eaa72dee48353f0211e6cc0f0776fe98
```

`/device/health` reports `himalaya` as `ready`, with runtime and provisioning
status both `ready`, and no missing pack/bin fields. Account discovery and
configured mail workflow smoke are still pending against real user mail
configuration.

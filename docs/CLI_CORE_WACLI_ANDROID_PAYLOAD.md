# Wacli Android CLI-Core Payload

This document records the fifth real `android-cli-core-pack` payload bundled
for APK provisioning. It is not a placeholder, shim, script stub, or fake
readiness marker.

## Payload

```text
skill id: wacli
asset: assets/openclaw/cli-core/bin/wacli
source: https://github.com/openclaw/wacli
source commit: be2d22fe9d8ca99bf4c027708ae494e9035fe489
source describe: v0.11.0-10-gbe2d22f
toolchain: go1.26.4 windows/amd64
toolchain archive sha256: 3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345
android ndk: 29.0.14206865
android api: 29
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=1
c compiler: aarch64-linux-android29-clang.cmd
cgo cflags: -Wno-error=missing-braces
go build tags: sqlite_fts5
payload bytes: 21713936
payload sha256: 63d36f54e82d8a2e76b2ef9ae44fe41b3c0bc0474ea19b9f31aae39ab9b43453
verified format: ELF64 little-endian AArch64
```

## Rebuild

```powershell
.\scripts\cli_core\build_wacli_android_arm64.ps1 -InstallAsset
```

The script downloads the pinned Go archive if needed, verifies its SHA-256,
checks out the pinned `wacli` commit, discovers a local Android NDK, builds the
real Go CLI for Android arm64 with cgo and SQLite FTS5 enabled, verifies the
output is an ELF64 AArch64 executable, and only then copies it into the APK
asset path when `-InstallAsset` is supplied.

Unlike the first four CLI-core payloads, `wacli` cannot use
`CGO_ENABLED=0`: upstream depends on `github.com/mattn/go-sqlite3`, so the APK
payload is built with the Android NDK C compiler.

## Current Limits

This payload proves the APK can carry and provision a real `wacli` binary for
Android arm64. It does not prove WhatsApp QR pairing, account auth persistence,
message sync, media download behavior, or send/control behavior on a real
device account.

The no-secret smoke target is:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/wacli version

expected output:
v0.11.0-10-gbe2d22f
```

Host build proof on 2026-06-08:

```text
.\scripts\cli_core\build_wacli_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
63d36f54e82d8a2e76b2ef9ae44fe41b3c0bc0474ea19b9f31aae39ab9b43453

flutter test test/android_cli_core_payload_packaging_test.dart --no-pub
Result: 12/12 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart --no-pub
Result: 43/43 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/wacli
length 21713936, sha256
63d36f54e82d8a2e76b2ef9ae44fe41b3c0bc0474ea19b9f31aae39ab9b43453
```

Device no-secret proof on 2026-06-09:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/wacli version

v0.11.0-10-gbe2d22f
```

`/device/health` reports `wacli` as `ready`, with runtime and provisioning
status both `ready`, and no missing pack/bin fields. `wacli auth status`, QR
pairing, and account workflow smoke are still pending against a real account.

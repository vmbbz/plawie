# OpenHue Android CLI-Core Payload

This document records the first real `android-cli-core-pack` payload bundled
for APK provisioning. It is not a placeholder, shim, script stub, or fake
readiness marker.

## Payload

```text
asset: assets/openclaw/cli-core/bin/openhue
source: https://github.com/openhue/openhue-cli
source commit: 08e940a9cd1c49c2da0a714dc8bb07ee60e9cd21
source describe: 0.24-1-g08e940a
toolchain: go1.26.4 windows/amd64
toolchain archive sha256: 3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345
build date: 2026-06-08T00:00:00Z
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
payload bytes: 11206952
payload sha256: 281cf0c17f593a32fe83571db7f467c956cd92a1b4bded26f6c8a8408f0ba3f9
verified format: ELF64 little-endian AArch64
```

## Rebuild

```powershell
.\scripts\cli_core\build_openhue_android_arm64.ps1 -InstallAsset
```

The script downloads the pinned Go archive if needed, verifies its SHA-256,
checks out the pinned OpenHue commit, builds the real Go CLI for Android arm64,
verifies the output is an ELF64 AArch64 executable, and only then copies it into
the APK asset path when `-InstallAsset` is supplied.

## Current Limits

This payload proves the APK can carry, extract, provision, and execute a real
`openhue` binary on Android arm64.

Device proof on Samsung SM-A556E:

```text
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/openhue version

#  Version      0.24-1-g08e940a
#   Commit      https://github.com/openhue/openhue-cli/commit/08e940a9cd1c49c2da0a714dc8bb07ee60e9cd21
# Built at      2026-06-08T00:00:00Z
```

`/device/health` after install reports `openhue` as `ready`, with runtime and
provisioning status both `ready`, and no missing pack/bin fields. The remaining
functional gates are Hue bridge pairing, local network discovery, multicast
behavior, and bridge API credentials on a user's device.

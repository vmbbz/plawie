# Android Vision Media Gifgrep Payload

This document records the APK-local `android-vision-media-runtime` Gifgrep
payload used by `gifgrep`. It is not a placeholder, shim, script stub, or fake
readiness marker.

## Payload

```text
asset: assets/openclaw/vision-media/bin/gifgrep
runtime lane: android-vision-media-runtime
provided binary: gifgrep
source: https://github.com/steipete/gifgrep
source commit: 72e2cf8fe685e7baa0535c04c3cf2e238ebfd0bc
source describe: 72e2cf8
upstream version: 0.3.0
toolchain: go1.25.5 windows/amd64
toolchain archive sha256: ae756cce1cb80c819b4fe01b0353807178f532211b47f72d7fa77949de054ebb
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=1
DNS mode: native build retained for local/status execution; provider HTTP uses
the app-native Android network stack
payload bytes: 8718160
payload sha256: 5fcd1be3ddd9b7708dfb0a29f1fdfdb33ff5fe9bca242089998bfcaf998b3691
verified format: ELF64 little-endian AArch64
license: MIT License
```

## Rebuild

```powershell
.\scripts\vision_media\build_gifgrep_android_arm64.ps1 `
  -DnsMode native `
  -AndroidNdkRoot '<Android NDK root>' `
  -InstallAsset
```

The script downloads the pinned Go archive if needed, verifies its SHA-256,
checks out the pinned Gifgrep commit, builds the real Go CLI for Android arm64,
verifies the output is an ELF64 AArch64 executable, and only then copies it into
the APK asset path when `-InstallAsset` is supplied. Native DNS is required for
Android: a pure-Go build reads an app-visible resolver address of `[::1]:53`,
where Android has no DNS listener, and fails before reaching provider APIs.

## Current Limits

The real Android binary supplies `gifgrep --version` and provider-backed online
search. Device forensics on 2026-07-26 found that the shipped upstream 0.3.0
binary does **not** implement the `still` or `sheet` subcommands described by
the installed OpenClaw skill document: both invocations are parsed as search
and reject their image flags.

Plawie keeps the skill contract truthful by implementing local `still` and
`sheet` in the app's Dart image runtime. They decode in a worker isolate, accept
only GIFs in app-owned storage, enforce byte/dimension/frame/pixel limits, and
write PNG outputs back inside app-owned storage. Those local operations do not
require network provider API keys.

Chat users can import a GIF through the chat `⋯` menu. Android copies it into
the bounded app-owned gifgrep storage area (20 MB maximum), records the latest
imported path, and the deterministic router supplies that path when the user
asks for a still frame, thumbnail, storyboard, montage, or contact sheet.

Provider search is separate user configuration:

```text
GIPHY_API_KEY: required only for --source giphy
KLIPY_API_KEY: required only for --source klipy or --source tenor
```

Those keys are not hard launch gates for local GIF processing. The Skills UI and
gateway configuration lanes should continue to treat provider keys as optional
mode-specific configuration instead of making the whole skill unavailable.

## Android execution contract

The managed binary must not be launched by the Gateway shell. Android SELinux
rejects direct `execute_no_trans` for downloaded ELF files in app data even when
the executable bit is present. Plawie exposes only these bounded Android node
commands:

```text
gifgrep.status
gifgrep.search
gifgrep.still
gifgrep.sheet
```

`gifgrep.status` and `gifgrep.search` execute through
`NativeBridge.runManagedCli`, which validates the binary allowlist and launches
the verified arm64 ELF through `/system/bin/linker64`. `gifgrep.still` and
`gifgrep.sheet` execute in the bounded app-native Dart image adapter instead.
Online provider requests use the app-native Dart `HttpClient`, which delegates
hostname resolution to Android's network stack. This avoids the upstream
pure-Go resolver selecting the app sandbox's unusable `[::1]:53` address.
The space-delimited command `gifgrep search` remains intentionally disallowed.
The required-tool router runs explicit gifgrep requests before model inference
and returns the deterministic result directly, so the agent must not attempt
npm, Go, Homebrew, chmod, PRoot installation, or a second node invocation.

`gifgrep.search` reports `GIFGREP_PROVIDER_CONFIG_REQUIRED` when neither
provider key is configured. That means the runtime is installed but an optional
online-search mode needs user configuration. `gifgrep.still` and
`gifgrep.sheet` remain key-free and constrain files to app-owned storage.

The Android-facing contract is defined in
`lib/services/gifgrep_contract.dart`. It is used for the registered tool schema,
mobile prompt guidance, and deterministic chat intent aliases. A missing
provider key is a configuration event, not an installation failure: chat opens
the gifgrep provider configuration sheet, and Bot Management > Skills exposes
the same optional configuration action. Saving keys updates only the Native
OpenClaw `.env`; local still/sheet work remains available when both keys are
empty. Generated still/sheet PNGs are published through the app media bus so
the chat UI can attach and render them rather than only displaying an internal
path.

Debug APK packaging proof on 2026-06-10:

```text
apk: build/app/outputs/flutter-apk/app-debug.apk
entry: assets/flutter_assets/assets/openclaw/vision-media/bin/gifgrep
entry bytes: 8782177
entry sha256: 431e81de8d46d6fad4b0ca1dbd76e7ce2efb8ca5dd6a9b495be303c60f937098
```

Historical device proof recorded on 2026-06-10 with `RZCX30KA9AW` / Samsung
`SM-A556E`:

```text
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk: Success

Native bootstrap manifest:
visionMediaBinCount: 2

/device/health gifgrep:
runtimeStatus: ready
provisioningStatus: ready
ready: true

/device/health video-frames:
ready: true

managed .openclaw/bin/gifgrep --version:
gifgrep 0.3.0

managed .openclaw/bin/gifgrep --help:
reported as including search, tui, still, and sheet

managed .openclaw/bin/gifgrep sha256:
431e81de8d46d6fad4b0ca1dbd76e7ce2efb8ca5dd6a9b495be303c60f937098

provisioning/bin/gifgrep sha256:
431e81de8d46d6fad4b0ca1dbd76e7ce2efb8ca5dd6a9b495be303c60f937098

historically reported local GIF-to-PNG smoke:
input: animexample2.gif, 2145 bytes
command: gifgrep still --at=0s input.gif -o still.png --quiet
output: still.png, 772 bytes
command: gifgrep sheet input.gif --frames=4 --cols=2 -o sheet.png --quiet
output: sheet.png, 2573 bytes
PNG header for both outputs: 89 50 4e 47 0d 0a 1a 0a
```

The 2026-07-26 audit supersedes the historical interpretation above: direct
device execution proved that `still --at` and `sheet --frames` are not accepted
by the actual 0.3.0 CLI. Current release proof must exercise the Dart-backed
node commands, not claim those PNGs came from CLI subcommands.

## License Posture

Gifgrep is distributed under the MIT License. Preserve
`docs/THIRD_PARTY_NOTICES_GIFGREP.md` and this provenance document with release
third-party notices or source/provenance materials.

## Required Release Smokes

Before final release, repeat on the signed release APK:

```text
.openclaw/bin/gifgrep --version
.openclaw/bin/gifgrep --help
gifgrep.status through the Android node
gifgrep.search through the Android node (result or exact provider-key gate)
gifgrep.still against an app-owned tiny.gif (Dart runtime)
gifgrep.sheet against an app-owned tiny.gif (Dart runtime)
/device/health: gifgrep ready
/device/health: video-frames still ready
```

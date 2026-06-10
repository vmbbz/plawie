# Android Audio Runtime Songsee Payload

This document records the first real APK-local `android-audio-runtime` payload.
It is not a placeholder, shim, script stub, or fake readiness marker.

## Payload

```text
asset: assets/openclaw/audio-runtime/bin/songsee
runtime lane: android-audio-runtime
provided binary: songsee
source: https://github.com/steipete/songsee
source commit: 41d27ea22771ba447bdfb8b6adac2e6599601634
source describe: v0.1.1-10-g41d27ea
toolchain: go1.25.4 windows/amd64
toolchain archive sha256: 6dad204d42719795f22067553b2b042c0e710b32c5a00f6c67892865167fdfd0
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
payload bytes: 4718945
payload sha256: 98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab
verified format: ELF64 little-endian AArch64
license: MIT License
```

## Rebuild

```powershell
.\scripts\audio_runtime\build_songsee_android_arm64.ps1 -InstallAsset
```

The script downloads the pinned Go archive if needed, verifies its SHA-256,
checks out the pinned Songsee commit, builds the real Go CLI for Android arm64,
verifies the output is an ELF64 AArch64 executable, and only then copies it into
the APK asset path when `-InstallAsset` is supplied.

## Current Limits

This payload proves the APK can carry, extract, provision, and execute a real
`songsee` binary on Android arm64.

Debug APK packaging proof on 2026-06-10:

```text
apk: build/app/outputs/flutter-apk/app-debug.apk
entry: assets/flutter_assets/assets/openclaw/audio-runtime/bin/songsee
entry bytes: 4718945
entry sha256: 98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab
```

Songsee has built-in WAV and MP3 decoding. Its broader "anything ffmpeg can
handle" path still requires an `ffmpeg` binary on `PATH` or an explicit
`--ffmpeg` path. OpenClaw already has an APK-local FFmpeg payload under the
`android-vision-media-runtime` lane, but this phase only advertises `songsee`.
It does not claim `spotify-player`, `spogo`, or any other audio-runtime binary.

Device proof on 2026-06-10 with `RZCX30KA9AW` / Samsung `SM-A556E`:

```text
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk: Success

/device/health songsee:
runtimeStatus: ready
provisioningStatus: ready
ready: true

/device/health spotify-player:
ready: false
provisioningStatus: missing_binary
dependencyGateMessage: No Native dependency pack advertises binary "spogo" for arm64-v8a.

managed .openclaw/bin/songsee --version:
v0.1.1-10-g41d27ea

managed .openclaw/bin/songsee --help:
Usage: songsee <input> [flags]

managed .openclaw/bin/songsee sha256:
98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab

provisioning/audio-runtime/bin/songsee sha256:
98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab

tiny WAV-to-PNG smoke:
input: 1 second 440 Hz mono WAV, 88244 bytes
command: songsee songsee-tiny.wav --format png --output songsee-smoke.png --width 320 --height 180 --quiet
output: songsee-smoke.png, 35894 bytes
PNG header: 89 50 4e 47 0d 0a 1a 0a
```

## License Posture

Songsee is distributed under the MIT License. Preserve
`docs/THIRD_PARTY_NOTICES_SONGSEE.md` and this provenance document with release
third-party notices or source/provenance materials.

## Required Release Smokes

Before final release, repeat on the signed release APK:

```text
.openclaw/bin/songsee --version
.openclaw/bin/songsee --help
.openclaw/bin/songsee tiny.wav --format png --output tiny.png
/device/health: songsee ready
/device/health: spotify-player still blocked
```

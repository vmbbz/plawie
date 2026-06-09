# Android FFmpeg Video Frames Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `video-frames` from pack-gated to real Android-ready by bundling a proven Android arm64 `ffmpeg` payload and extracting frames through the Native managed-bin path instead of PRoot.

**Architecture:** Build a minimal LGPL-only FFmpeg executable from pinned official source with Android NDK arm64, install it into `assets/openclaw/vision-media/bin/ffmpeg`, and prove the asset with ELF/provenance tests. Replace the video extractor's PRoot shell call with a bounded app-native `runManagedFfmpeg` method channel that runs only `.openclaw/bin/ffmpeg` against app-owned temp files.

**Tech Stack:** Flutter/Dart, Android Kotlin MethodChannel, Android NDK/Clang, FFmpeg source release, existing OpenClaw dependency-pack/readiness services.

---

### Task 1: Native FFmpeg Extractor Path

**Files:**
- Modify: `lib/utils/video_frame_extractor.dart`
- Modify: `lib/services/native_bridge.dart`
- Modify: `android/app/src/main/kotlin/com/nxg/openclawproot/MainActivity.kt`
- Create: `test/video_frame_extractor_test.dart`

- [x] **Step 1: Write failing Dart extractor tests**

Test that `VideoFrameExtractor.extractFrames`:

```text
uses app-owned temp paths
passes bounded args to a native ffmpeg runner
does not call or reference PRoot paths
returns JPEG bytes created by the runner
```

- [x] **Step 2: Run RED**

Run:

```powershell
flutter test test/video_frame_extractor_test.dart --no-pub
```

Expected before implementation: compile/fail because the extractor has no injectable native runner and still imports `NativeBridge.runInProot`.

- [x] **Step 3: Implement app-native extractor**

Add an injectable `NativeFfmpegRunner`, write MP4 inputs under app-owned temp directories, call `NativeBridge.runManagedFfmpeg`, read generated JPEGs, and clean up the run directory.

- [x] **Step 4: Implement bounded Android runner**

Add `NativeBridge.runManagedFfmpeg(args, timeoutSeconds)` and a Kotlin `runManagedFfmpeg` method that resolves only:

```text
filesDir/native-node-embedded/native-home/.openclaw/bin/ffmpeg
```

It must use `ProcessBuilder(listOf(ffmpeg) + args)`, never a shell, enforce a timeout, capture stdout/stderr, and return `{exitCode, stdout, stderr, binaryPath}`.

### Task 2: FFmpeg Payload Build And Provenance

**Files:**
- Create: `scripts/vision_media/build_ffmpeg_android_arm64.sh`
- Create: `docs/ANDROID_VISION_MEDIA_FFMPEG_PAYLOAD.md`
- Create: `docs/THIRD_PARTY_NOTICES_FFMPEG.md`
- Create after successful build: `assets/openclaw/vision-media/bin/ffmpeg`
- Modify: `test/android_cli_core_payload_packaging_test.dart`

- [x] **Step 1: Add failing payload/provenance tests**

Add tests that require:

```text
assets/openclaw/vision-media/bin/ffmpeg exists
file is ELF64 little-endian AArch64
payload is larger than 1 MiB
payload is not a shell script
build script pins FFmpeg 8.1.1 source SHA256
build script disables gpl and nonfree
payload docs contain the actual payload SHA256
```

- [x] **Step 2: Run RED**

Run:

```powershell
flutter test test/android_cli_core_payload_packaging_test.dart --plain-name "FFmpeg" --no-pub
```

Expected before payload: fail because `ffmpeg` is absent.

- [x] **Step 3: Add build script**

Script requirements:

```text
source: https://ffmpeg.org/releases/ffmpeg-8.1.1.tar.xz
source sha256: b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3
target: aarch64-linux-android
Android API: 29
configure flags include --disable-gpl --disable-nonfree
configure flags keep GPL/nonfree external libraries disabled
```

- [x] **Step 4: Build and install payload**

Run from WSL/Linux with a Linux-host Android NDK. If missing, use the existing guarded helper:

```bash
PLAWIE_ALLOW_NETWORK=1 ./scripts/native_node/prepare_android_ndk_linux.sh
ANDROID_NDK_HOME="$HOME/.plawie/android/android-ndk-r28c" \
  PLAWIE_ALLOW_NETWORK=1 \
  INSTALL_ASSET=1 \
  ./scripts/vision_media/build_ffmpeg_android_arm64.sh
```

- [x] **Step 5: Update provenance docs**

Record source URL, source SHA256, build flags, NDK/API, payload byte length, payload SHA256, license mode, and exact smoke commands.

### Task 3: Device Proof And Count Update

**Files:**
- Modify after proof: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`
- Modify after proof: `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md`

- [x] **Step 1: Run host verification**

Run:

```powershell
flutter test test/video_frame_extractor_test.dart test/android_cli_core_payload_packaging_test.dart test/skill_provisioning_service_test.dart --no-pub
flutter analyze lib/utils/video_frame_extractor.dart lib/services/native_bridge.dart test/video_frame_extractor_test.dart test/android_cli_core_payload_packaging_test.dart
git diff --check
```

- [x] **Step 2: Run device smoke at milestone**

After APK install/provisioning, prove:

```text
.openclaw/bin/ffmpeg -version
video-frames tiny fixture extraction returns JPEG frames
/device/health reports video-frames ready
gifgrep remains blocked
```

- [x] **Step 3: Update scorecard only after device proof**

Only after the device smoke passes, update the GTM scorecard from the current
truth to include `video-frames`. Do not move `gifgrep`.

- [ ] **Step 4: Commit and push**

Commit this phase in one or more significant rounds, excluding APK/temp/build artifacts outside the approved ffmpeg payload and docs.

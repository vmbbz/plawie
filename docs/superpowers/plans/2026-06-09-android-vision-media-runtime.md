# Android Vision Media Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare an honest APK-local `android-vision-media-runtime` lane where a real Android arm64 `ffmpeg` payload can move `video-frames` without moving `gifgrep`.

**Architecture:** Reuse the Phase 5A dependency-pack verifier. Add a dedicated vision-media asset directory copied into Native provisioning bin, advertise an APK-provided dependency pack only when `ffmpeg` exists, and keep `gifgrep` blocked until a real `gifgrep` binary exists. Do not include placeholder ffmpeg binaries.

**Tech Stack:** Flutter/Dart provisioning services and tests, Android Kotlin asset bootstrap, existing dependency-pack manifest/readiness model.

---

### Task 1: APK Asset Lane

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/kotlin/com/nxg/openclawproot/NativeNodeEmbeddedService.kt`
- Modify: `test/android_cli_core_payload_packaging_test.dart`
- Create: `assets/openclaw/vision-media/bin/.gitkeep`

- [x] **Step 1: Write the failing packaging test**

Add assertions that:

```dart
expect(pubspec, contains('assets/openclaw/vision-media/bin/'));
expect(bootstrap, contains('VISION_MEDIA_BIN_ASSET_DIR = '));
expect(bootstrap, contains('"flutter_assets/assets/openclaw/vision-media/bin"'));
expect(bootstrap, contains('copyVisionMediaBinAssets(File(workDir(applicationContext), "provisioning/bin"))'));
```

- [x] **Step 2: Run RED**

Run:

```powershell
flutter test test/android_cli_core_payload_packaging_test.dart --plain-name "Native bootstrap extracts vision-media assets into provisioning bin" --no-pub
```

Expected before implementation: fail because the asset dir/copy function does not exist.

- [x] **Step 3: Implement the asset lane**

Add `assets/openclaw/vision-media/bin/` to `pubspec.yaml`, create `.gitkeep`,
add `VISION_MEDIA_BIN_ASSET_DIR`, and copy that directory into the same
`provisioning/bin` target as CLI-core.

### Task 2: Vision-Media Pack Resolver

**Files:**
- Modify: `lib/services/skill_provisioning_service.dart`
- Modify: `test/skill_provisioning_service_test.dart`

- [x] **Step 1: Write failing provisioning tests**

Add tests that prove:

```text
ffmpeg from a bundled provisioning bin installs as android-vision-media-runtime
ffmpeg missing explains assets/openclaw/vision-media/bin/ffmpeg
gifgrep does not become ready when only ffmpeg exists
```

- [x] **Step 2: Run RED**

Run:

```powershell
flutter test test/skill_provisioning_service_test.dart --plain-name "vision media" --no-pub
```

Expected before implementation: fail because no APK-provided vision-media pack exists.

- [x] **Step 3: Implement resolver**

Add constants:

```dart
_androidVisionMediaPackId = 'android-vision-media-runtime'
_androidVisionMediaPackVersion = 'apk-bundled-v1'
_androidVisionMediaPackBins = {'ffmpeg'}
```

Add `_apkProvidedVisionMediaPack(layout)` to the dependency-pack catalog. It
must advertise only bundled binaries actually present. It must not advertise
`gifgrep` until a real `gifgrep` payload is added.

### Task 3: Docs And Verification

**Files:**
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`
- Modify: `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md`

- [x] **Step 1: Update docs**

Document the Phase 5C asset/resolver lane:

```text
assets/openclaw/vision-media/bin/ffmpeg
android-vision-media-runtime advertises ffmpeg only
video-frames can move after real payload + smoke
gifgrep remains blocked
```

- [x] **Step 2: Run verification**

Run:

```powershell
flutter test test/android_cli_core_payload_packaging_test.dart test/skill_provisioning_service_test.dart --no-pub
flutter analyze lib/services/skill_provisioning_service.dart test/skill_provisioning_service_test.dart test/android_cli_core_payload_packaging_test.dart
git diff --check
```

Expected: tests pass, analyzer reports no issues, diff check is clean.

- [ ] **Step 3: Commit and push**

Commit only the Phase 5C files and push `native-node-gateway-research`.

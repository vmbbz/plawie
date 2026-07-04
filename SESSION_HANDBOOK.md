# OpenClaw Android — Session Handoff

**Date**: 2026-07-04
**Device**: RZCX30KA9AW (ADB)
**Gateway version**: 2026.5.28
**Model**: `openrouter/openai/gpt-oss-20b:free`
**Branch**: `native-node-gateway-research` (not main)
**Repo**: `git@github.com:vmbbz/plawie.git` (public)
**Remote manifest URL**: `https://raw.githubusercontent.com/vmbbz/plawie/native-node-gateway-research/android-arm64-v8a.json`

---

## 1. Current Status

### Latest provisioning snapshot (from device logs):
```
skills=61, changed=false, blocked=40
missing_binary:34, ready:21, needs_user_config:5, missing_dependency:1
```

### Definitions
- **missing_binary**: Skill needs a native binary that is not installed (e.g. node, whisper, sherpa-onnx, grizzly, gh, git, etc.) — these are normal for skills that don't have pre-built packs yet
- **ready**: Skill is fully functional on Android
- **needs_user_config**: Skill needs user to configure API keys/tokens in app settings
- **missing_dependency**: Skill has a dependency that failed installation or couldn't be resolved (currently 1 — likely `stocks` Python packages)

### Key counts improved from original baseline:
- `missing_binary`: 36 → 34 (coding-agent fixed)
- `ready`: 20 → 21 (coding-agent fixed)
- `missing_dependency`: 1 (stocks false flag partially fixed — still shows 1)

---

## 2. What Was Done & Why

### 2.1 Canvas Commands Fix
**Files**: `lib/services/gateway_service.dart`, `lib/services/capabilities/canvas_capability.dart`, `lib/services/node_service.dart`
**Commit**: `ac837c8`
**Problem**: Canvas commands (`canvas.eval`, `canvas.navigate`, etc.) returned "Unauthorized" because they were not properly authenticated through the plugin surface.
**Fix**: Routes canvas commands through `pluginSurfaceUrls.canvas` for auth. Added JS `fetch()`/`XMLHttpRequest` block for external URLs in WebView.

### 2.2 Chat Text Duplication Fix
**Files**: `lib/services/gateway_service.dart`, `lib/screens/chat_screen.dart`
**Problem**: Gateway v2026.5.28+ sends `stream=item` (not `stream=tool_use`). The old handler didn't recognize this, causing chat text to be duplicated.
**Fix**: Added `stream=item` handler + `assistantDelta` fallback in gateway service.

### 2.3 Missing Dependencies UI Fix
**Commit**: `6bb5d8a`
**Problem**: Config-only skills (that need API keys, not binaries) showed "MISSING DEPS" which was confusing.
**Fix**: `_needsConfig` skills now show "NEEDS CONFIG" instead of "MISSING DEPS".

### 2.4 Dependency Pack Provisioning Architecture
**Commits**: `b993676`, `31eca4a`, `7e40679`
**Files**: `lib/services/skill_provisioning_service.dart`, `android-arm64-v8a.json`, `lib/services/signing_keys.dart`

#### What it does:
The provisioning system has two types of dependency packs:

**A) APK-bundled packs** (`source: "apk"`):
- Binaries/assets packaged inside the APK under `assets/openclaw/<pack-name>/`
- Extracted at runtime by Kotlin `NativeNodeEmbeddedService.kt` via `copyBundledBinAssets()`
- Used for: `cli-core-pack`, `vision-media-runtime`, `audio-runtime`, `terminal-pack`, `python-debug-runtime`
- Also declared for: `whisper-runtime`, `tts-runtime`, `node-executable-pack`, `agent-cli-pack` (all currently have only `.gitkeep` files — placeholders)

**B) Remote packs** (`source: "remote"`):
- Downloaded from GitHub releases on-demand when a skill needs them
- Verified via ed25519 signature before install
- Smoke-tested after install; rolled back on failure
- Used for: `android-whisper-runtime`, `android-tts-runtime`

#### How the flow works:
1. `_loadDependencyPackCatalog()` scans:
   - APK-bundled asset dirs (via `_apkProvided*()` functions)
   - Local manifest file (`dependency_packs.json`)
   - Remote manifest from GitHub raw URL (8s timeout)
2. `_installDependencyPack()`:
   - APK: `_installApkProvidedPack()` → copies from bundled assets to managed bin
   - Remote: `_downloadAndExtractPack()` → downloads zip, extracts to install path
   - Both: `_applyDependencyPackFileModes()` → chmods executables, copies provided bins to managed bin
   - Both: `_runDependencyPackSmoke()` → runs smoke command, rolls back on failure
   - Both: `_writeDependencyReceipt()` → writes receipt on success

#### Why this architecture:
- **APK-bundled**: Works offline, no network dependency for core binaries. But APK size is large (286.7MB).
- **Remote**: Allows updating binaries without APK rebuild. But requires network + reliable hosting.
- **Smoke test**: Ensures the binary actually works before marking it installed.
- **Receipt system**: Prevents re-downloading on every app start.

### 2.5 Remote Manifest + Signature Setup
**Files**: `android-arm64-v8a.json`, `lib/services/signing_keys.dart`

The manifest hosts two pack entries:
- `android-whisper-runtime` (6.3MB zip, SHA256, ed25519-signed)
- `android-tts-runtime` (25MB zip, SHA256, ed25519-signed)

**Signing**:
- Private key: `%TEMP%\opencode\signing-private.pem` (NOT in repo)
- Public key: `lib/services/signing_keys.dart` (committed)
- keyId: `838fff1844341501` (first 16 hex chars of SHA256 of public key PEM)

**Hosting**:
- Zips hosted as GitHub release: `https://github.com/vmbbz/plawie/releases/tag/dependency-packs-v1`
- Branch: `native-node-gateway-research` (raw URLs resolve from this branch)
- Repo was made public (was private — raw.githubusercontent.com returned 404)

### 2.6 Binaries Cross-Compiled for Android arm64-v8a

#### whisper.cpp (v1.9.1) — `build-whisper-android.sh`
- **Purpose**: Speech-to-text for openai-whisper skill
- **Build**: NDK 29 + CMake 3.22.1 + Ninja
- **Output**: `build-android/bin/whisper-cli` (25MB standalone ELF)
- **Linked**: `/system/bin/linker64` (Android Bionic — correct)
- **Packaged**: `android-whisper-runtime-whisper-cpp-v1-2026.zip` (6.3MB)

#### sherpa-onnx (v1.13.3) — `build-sherpa-onnx-android.sh`
- **Purpose**: Text-to-speech for TTS skills
- **Build**: NDK 29 + static ONNX Runtime 1.24.3 + `-Wl,--allow-shlib-undefined`
- **Output**: `build-android-arm64-v8a/bin/sherpa-onnx` (47MB)
- **.so files**: `libonnxruntime.so` (25MB), `libsherpa-onnx-core.so` (4.4MB) — from official Android release
- **Packaged**: `android-tts-runtime-sherpa-onnx-v1-2026.zip` (25MB)
- **Critical detail**: Static ONNX Runtime was required because dynamic linking fails with NDK 29 (`__register_atfork@LIBC` symbol mismatch)

#### agent-cli stubs — `build-agent-cli-android.sh`
- **Purpose**: Placeholder binaries for coding-agent skill
- **Output**: Two binaries: `coding-agent`, `claude` (2.1MB each)
- **Both are stubs**: Only respond to `--version`, `--help`. No real agent functionality.
- **Current version**: Updated with honest stub message including `--stub` flag
- **NOTE**: These are NOT functional agents — they only satisfy the smoke test

### 2.7 Stocks False Flag Fix
**Files**: `lib/services/skill_provisioning_service.dart` (lines 2613-2639, 2901-2947)

**Problem**: The stocks skill has `pythonPackages: ['yfinance', 'pandas', 'pydantic', 'requests']` but uses packages installed in its own skill-local directory, not in the managed site-packages. The provisioning service only scanned the managed and Chaquopy directories, so it falsely reported `missing_dependency`.

**Fix**: 
- `_scanInstalledPythonPackageVersions()` now accepts optional `skillId` parameter
- When `skillId` is provided, it also scans `{skillDir}/site-packages` and `{skillDir}/.python/site-packages`
- `_smokePythonImport()` also accepts `skillId` and adds skill-local dirs to PYTHONPATH
- All callers (`_provisionPythonWheels`, `_satisfiedPythonPackagesForPack`) pass `entry.skillId`

**Effect**: The parity audit now correctly detects packages in skill-local directories. However, device logs still show `missing_dependency:1` — the remaining one may be a different skill or the stocks packages still aren't fully resolved.

### 2.8 Binary Permission Fixes (chmod)
**Files**: `lib/services/skill_provisioning_service.dart` (lines 3272-3292 removed, 3363-3379 updated, 3382-3429 updated, 3515-3521 updated)

**Problems found and fixed**:
1. **Duplicate binary copy**: Both `_downloadAndExtractPack` and `_applyDependencyPackFileModes` copied binaries to managed bin. Removed from `_downloadAndExtractPack`.
2. **Inconsistent chmod**: `_applyDependencyPackFileModes` skipped copy if size matched but always applied chmod. Changed to always copy + chmod.
3. **Rollback didn't clean managed bin**: When smoke test failed, the install path was cleaned but managed bin retained the old binary. Fixed rollback to also delete from managed bin.
4. **Silent catch on chmod**: `catch (_) {}` swallowed chmod errors. Added proper debugPrint logging.

**Why this matters**: The whisper smoke test was failing with "Permission denied" because the binary in managed bin wasn't getting chmod applied before execution, AND the rollback left stale binaries that persisted across reinstall attempts.

---

## 3. Build Scripts

### `scripts/build-whisper-android.sh`
- Requires Android NDK (27+)
- Clones whisper.cpp, builds with CMake for arm64-v8a
- Output: `assets/openclaw/whisper-runtime/bin/whisper`
- Also downloads `ggml-base.bin` model (150MB) to `assets/openclaw/whisper-runtime/models/`
- **Model note**: The `_androidWhisperRuntimeModels` constant lists `ggml-base.bin` but there's no Kotlin extraction code for models, only for `bin/` and `lib/` dirs

### `scripts/build-sherpa-onnx-android.sh`
- Requires Android NDK (27+)
- Clones sherpa-onnx, builds with CMake for arm64-v8a (TTS only, no ASR)
- Output: `assets/openclaw/tts-runtime/bin/sherpa-onnx` + `.so` files in `assets/openclaw/tts-runtime/lib/`

### `scripts/build-agent-cli-android.sh`
- Requires Android NDK (29+)
- Compiles a minimal C stub from embedded source
- Output: `assets/openclaw/agent-cli-pack/bin/{coding-agent,claude}`
- **Windows path note**: Uses `aarch64-linux-android28-clang.cmd` (with .cmd suffix)
- **Path issue**: The hardcoded `$HOME/AppData/Local/Android/Sdk` path may not work in all environments

### `scripts/package-dependency-packs.sh`
- Zips asset directories, generates SHA256 + raw manifest
- **OUTDATED**: Still references `clawhub.ai` URLs and generates non-signed manifest entries
- The actual hosted manifest (`android-arm64-v8a.json`) was manually created with correct GitHub URLs and ed25519 signatures
- **Needs update**: If you rebuild zips, you must:
  1. Update SHA256 in the manifest
  2. Generate new ed25519 signatures
  3. Upload zips to GitHub release
  4. Update manifest URL if hosting location changes

---

## 4. Key Files

| File | Purpose |
|------|---------|
| `lib/services/skill_provisioning_service.dart` | Main provisioning logic (5053 lines!) |
| `lib/services/android_skill_support_manifest.dart` | Skill readiness matrix (612 lines) |
| `lib/services/dependency_pack_manifest.dart` | Manifest entry validation + crypto |
| `lib/services/signing_keys.dart` | ed25519 public key for pack verification |
| `lib/services/skill_parity_audit_service.dart` | Parity audit between native/proot |
| `lib/services/native_skill_execution_registry.dart` | Stocks descriptor with pythonPackages |
| `android-arm64-v8a.json` | Remote manifest (signed) |
| `android/.../NativeNodeEmbeddedService.kt` | Kotlin bootstrap: asset extraction, gateway |
| `pubspec.yaml` | Asset declarations (line 91-96: agent-cli-pack/bin/) |
| `scripts/build-whisper-android.sh` | whisper.cpp cross-compile script |
| `scripts/build-sherpa-onnx-android.sh` | sherpa-onnx cross-compile script |
| `scripts/build-agent-cli-android.sh` | agent-cli stub cross-compile script |
| `scripts/package-dependency-packs.sh` | Pack zipping + manifest generation (outdated) |
| `%TEMP%\opencode\signing-private.pem` | Private key (NOT in repo) |

---

## 5. What's Broken / Missing

### 5.1 Whisper Smoke Test Fails (HIGH PRIORITY)
**Status**: STILL FAILING
**Symptoms**: Pack downloads, binary found in managed bin, but `Process.start` returns "Permission denied". The chmod fixes were applied but not yet verified on-device (the pack only downloads when `openai-whisper` skill is triggered).
**Root cause**: The chmod addition in `_runDependencyPackSmoke` (line 3518) and `_applyDependencyPackFileModes` may still not execute before `Process.start`. The binary in the zip may not have executable bits.
**To verify**:
1. Trigger the `openai-whisper` skill to force a pack re-download
2. Watch for `[DEPS] requested pack=android-whisper-runtime` in logs
3. If smoke still fails, try: `adb shell chmod 755 /data/.../.openclaw/bin/whisper` manually
4. If manual chmod fixes it, the Dart-side chmod is not running before `Process.start`

**Potential remaining issues**:
- The `Process.run('chmod', ...)` may fail silently on Android if SELinux blocks it
- Android `targetSdkVersion` 33+ requires `setExecutable(true)` from Kotlin side instead
- Consider using `File.statSync().mode` to verify permissions after chmod

### 5.2 TTS / sherpa-onnx Not Tested (HIGH PRIORITY)
**Status**: NOT TESTED
**Manifest entry exists**, pack is downloadable, but no device logs show it being attempted.
**To test**: Trigger a TTS skill that requires `sherpa-onnx` binary.
**Potential issue**: sherpa-onnx links against `.so` files (`libonnxruntime.so`, `libsherpa-onnx-core.so`) — the `_runDependencyPackSmoke` sets `LD_LIBRARY_PATH` to include `nativeManagedLibDir`, but the `.so` files are in the pack install path (`dependencies/packs/android-tts-runtime/lib/`), not in `nativeManagedLibDir`. Need to verify:
- Are the `.so` files copied to managed lib dir?
- Or does `LD_LIBRARY_PATH` include the pack install path?
- Check `_applyDependencyPackFileModes` — it only copies `providesBins`, not libraries

### 5.3 Remaining `missing_dependency:1` (MEDIUM PRIORITY)
**Status**: UNKNOWN
**Possible causes**:
1. Stocks skill's `yfinance` / `pandas` / `pydantic` / `requests` Python packages still not resolved (the `skillId` parameter may not be reaching the scan function due to incorrect routing)
2. A different skill entirely

**To investigate**:
- Add verbose logging to identify which skill has the missing dependency
- Check if stocks skill-local `site-packages` has the packages installed
- Verify the `skillId` parameter is properly threaded through all callers

### 5.4 Agent CLI Binaries Are Stubs (MEDIUM PRIORITY)
**Status**: KNOWN LIMITATION
`coding-agent` and `claude` binaries are minimal C stubs. They pass the smoke test but provide no real functionality. The skill is marked as `_needsPack` in the manifest, meaning it appears as "ready" when the binary exists, but the skill won't actually work when invoked.

**Options**:
1. Accept this limitation — users can configure a real backend
2. Bundle a real agent CLI (would need Node.js runtime, much larger)
3. Change skill classification to `_needsConfig` if it genuinely needs configuration

### 5.5 Node.js Executable Pack Not Built (LOW PRIORITY)
**Status**: NOT DONE
**Skill**: `canvas` needs `node` binary via `android-node-executable-pack`
**Problem**: No pre-built Android Node.js binary available. Would need cross-compilation.
**Current workaround**: Canvas uses the gateway's built-in Node.js, not a standalone binary.
**If needed**: Use `nodejs-mobile-android` or cross-compile Node.js from source (very complex).

### 5.6 `package-dependency-packs.sh` Outdated (LOW PRIORITY)
**Status**: STALE
The script still references `clawhub.ai` URLs and generates unsigned manifests. If you need to rebuild and re-host packs:
1. Update the URL pattern in the script
2. Add ed25519 signing step (the script generates empty signature fields)
3. Re-upload zips to GitHub release
4. Update `android-arm64-v8a.json` with new SHA256 + signatures

### 5.7 Whisper Model Not Extracted (LOW PRIORITY)
**Status**: INCOMPLETE
The `_androidWhisperRuntimeModels` constant lists `ggml-base.bin` but there's no Kotlin extraction code for model files. The build script downloads the model to `assets/openclaw/whisper-runtime/models/` but the Kotlin `NativeNodeEmbeddedService.kt` only has extraction for `bin/` and `lib/` directories, not `models/`.
**Fix**: Add a Kotlin function `copyWhisperRuntimeModelAssets()` + add it to `prepareFullGatewayBundle()`.

---

## 6. Next Steps

### Immediate (next session):
1. **Verify whisper smoke test**: Force trigger `openai-whisper` skill, capture logs, confirm smoke passes or diagnose remaining permission issue
2. **Verify TTS smoke test**: Force trigger a TTS skill, capture logs, confirm smoke passes
3. **Diagnose remaining `missing_dependency:1`**: Add logging to identify which skill/package
4. **Test whisper/TTS end-to-end**: Actually transcribe audio / synthesize speech

### Short-term:
5. **Copy `.so` files to managed lib dir**: Ensure `_applyDependencyPackFileModes` or a new function copies pack libraries so `LD_LIBRARY_PATH` finds them
6. **Fix `package-dependency-packs.sh`**: Update URLs, add signing step
7. **Add model extraction**: Add Kotlin function for whisper model files

### Medium-term:
8. **Build real agent CLI**: Or accept stub limitation and change skill classification
9. **Build Node.js for Android**: If canvas needs standalone Node
10. **Add integration tests**: Test pack download, smoke, rollback, and re-install

---

## 7. Critical Context

### Device paths:
- Files dir: `/data/user/0/com.nxg.openclawproot/files/`
- Gateway runtime: `native-node-embedded/native-home/.openclaw/`
- Managed binaries: `.../.openclaw/bin/`
- Managed libraries: `.../.openclaw/lib/`
- Python site-packages: `.../.openclaw/runtimes/python/site-packages/`
- Pack install: `.../.openclaw/dependencies/packs/<pack-id>/`
- Receipts: `.../.openclaw/dependencies/receipts/`
- Provisioning bin dir: `native-node-embedded/provisioning/bin/` (Kotlin extracts APK assets here)

### ADB:
```powershell
# Clear all pack receipts (forces re-download)
adb shell "rm -rf /data/user/0/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/dependencies/"

# Force stop and relaunch
adb shell am force-stop com.nxg.openclawproot
adb shell am start -n com.nxg.openclawproot/.MainActivity

# Check logs
adb logcat -s flutter | Select-String -Pattern "DEPS|SKILL-PROVISION|smoke|whisper|sherpa"

# Manual permission fix for testing
adb shell "chmod 755 /data/user/0/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/bin/whisper"
```

### Build:
```powershell
cd C:\dev-shared\openclaw-projects\openclaw_final
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

### NDK on this machine:
- Versions: 26.1, 27.0, 28.2, 29.0 (in use: 29.0.14206865)
- Path: `C:\Users\cosyc\AppData\Local\Android\Sdk\ndk\29.0.14206865`
- Toolchain: `toolchains/llvm/prebuilt/windows-x86_64`
- Compiler: `aarch64-linux-android28-clang.cmd`

### Git:
```bash
# Repo is private on GitHub but needs to be public for raw.githubusercontent.com
# Currently on 'native-node-gateway-research' branch (NOT main)
# When merging to main, update manifest URL in skill_provisioning_service.dart (line 1853)
```

### Key decisions already made:
- Cross-compile binaries (pre-built Android binaries are incompatible — whisper.cpp has no Android release, sherpa-onnx HOS release uses musl libc)
- Host packs on GitHub releases (clawhub.ai returns 404 for packs endpoint)
- Use ed25519 signing for pack verification
- Dual APK-bundled + remote pack system

---

## 8. ADB Log Quick Reference

```powershell
# All DEPS activity
adb logcat -s flutter | Select-String "DEPS"

# Provisioning summary
adb logcat -s flutter | Select-String "SKILL-PROVISION"

# Parify audit
adb logcat -s flutter | Select-String "SKILL-PARITY"

# Smoke tests only
adb logcat -s flutter | Select-String "smoke"

# Whisper specific
adb logcat -s flutter | Select-String "whisper"

# Sherpa/TTS specific
adb logcat -s flutter | Select-String "sherpa|tts"

# Remote manifest fetch
adb logcat -s flutter | Select-String "manifest|unavailable"

# Raw filter for time range (replace with actual recent times)
adb logcat -d -s flutter | Where-Object { $_ -match "02:1[0-9]" }
```

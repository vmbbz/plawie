# Android Python Debug Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `python-debugpy` clean-fresh Android ready by bundling and proving a real APK-local `debugpy` wheel through the existing Native Python bridge.

**Architecture:** Add an APK asset lane for `assets/openclaw/python-debug-runtime/wheels/`, copy it during Native Gateway bootstrap into app-owned provisioning storage, and let `SkillProvisioningService` advertise `android-python-debug-runtime` only when a real `debugpy` wheel is present. Provisioning installs the wheel into `.openclaw/runtimes/python/site-packages`, smokes `import debugpy` through `NativeBridge.runNativePython`, writes receipts, and updates GTM counts only after device proof.

**Tech Stack:** Flutter/Dart, Android Kotlin asset bootstrap, Chaquopy Python bridge, Python wheel metadata, existing dependency-pack receipts.

---

### Task 1: APK Python Debug Asset Lane

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/kotlin/com/nxg/openclawproot/NativeNodeEmbeddedService.kt`
- Modify: `test/android_cli_core_payload_packaging_test.dart`

- [x] **Step 1: Write failing asset-lane test**

Add a test requiring:

```text
pubspec declares assets/openclaw/python-debug-runtime/wheels/
NativeNodeEmbeddedService has PYTHON_DEBUG_WHEEL_ASSET_DIR
NativeNodeEmbeddedService copies that asset dir into provisioning/python-debug/wheels
bootstrap manifest reports pythonDebugWheelCount
```

- [x] **Step 2: Run RED**

Run:

```powershell
flutter test test/android_cli_core_payload_packaging_test.dart --plain-name "Python debug" --no-pub
```

Expected before implementation: fail because the wheel asset lane is absent.

- [x] **Step 3: Implement bootstrap copy**

Add a safe recursive wheel-asset copier that accepts only file names ending in
`.whl`, rejects names containing slash, backslash, colon, `..`, or leading dot,
and copies into:

```text
filesDir/native-node-embedded/provisioning/python-debug/wheels/
```

The bootstrap manifest must record:

```text
pythonDebugWheelAssetDir
pythonDebugWheelCount
```

### Task 2: Real Debugpy Wheel Payload

**Files:**
- Create: `scripts/python_debug/build_debugpy_android_runtime.ps1`
- Create: `assets/openclaw/python-debug-runtime/wheels/debugpy-1.8.21-py2.py3-none-any.whl`
- Create: `docs/ANDROID_PYTHON_DEBUG_RUNTIME_PAYLOAD.md`
- Modify: `test/android_cli_core_payload_packaging_test.dart`

- [x] **Step 1: Add failing provenance tests**

Add tests that require:

```text
debugpy wheel asset exists
wheel name starts debugpy-1.8.21-
wheel contains debugpy/__init__.py
wheel contains debugpy-1.8.21.dist-info/METADATA
payload docs contain the wheel SHA256
build script pins debugpy 1.8.21 and verifies SHA256
```

- [x] **Step 2: Run RED**

Run:

```powershell
flutter test test/android_cli_core_payload_packaging_test.dart --plain-name "debugpy" --no-pub
```

Expected before payload: fail because the wheel asset and provenance docs are absent.

- [x] **Step 3: Build/pin the wheel payload**

Download `debugpy==1.8.21` as a wheel into `.tmp/python-debug-runtime`,
compute SHA256, verify the wheel metadata name/version, then copy the wheel to
the asset lane. Do not unpack it into git.

- [x] **Step 4: Write provenance docs**

Record:

```text
package: debugpy 1.8.21
asset: assets/openclaw/python-debug-runtime/wheels/debugpy-1.8.21-py2.py3-none-any.whl
sha256: exact wheel hash
source: PyPI wheel download
install target: .openclaw/runtimes/python/site-packages
smoke: python -c "import debugpy; print(debugpy.__version__)"
```

### Task 3: Provisioning Resolver And Real Wheel Install

**Files:**
- Modify: `lib/services/skill_provisioning_service.dart`
- Modify: `test/skill_provisioning_service_test.dart`

- [x] **Step 1: Write failing provisioning test**

Add a test where `python-debugpy` requires `python3` and `debugpy`; create:

```text
native-node-embedded/provisioning/python-debug/wheels/debugpy-1.8.21-py2.py3-none-any.whl
```

The test must assert:

```text
python-core installs first
android-python-debug-runtime is selected
debugpy package files are extracted into runtimes/python/site-packages
debugpy-1.8.21.dist-info/METADATA exists
dependency receipt android-python-debug-runtime.json exists
python wheel receipt debugpy.json exists
snapshot after provisioning marks python-debugpy ready
```

- [x] **Step 2: Run RED**

Run:

```powershell
flutter test test/skill_provisioning_service_test.dart --plain-name "debugpy" --no-pub
```

Expected before implementation: fail because no APK debugpy pack is advertised or installed.

- [x] **Step 3: Implement APK Python package pack**

Add constants:

```dart
_androidPythonDebugPackId = 'android-python-debug-runtime'
_androidPythonDebugPackVersion = 'debugpy-1.8.21-apk-v1'
_androidPythonDebugPackages = {'debugpy'}
```

Add provisioning roots:

```text
native-node-embedded/provisioning/python-debug/wheels
native-node-embedded/bundled-python-debug/wheels
native-node-embedded/full-openclaw/provisioning/python-debug/wheels
```

Add `_apkProvidedPythonDebugPack(layout)` that advertises `debugpy` only when a safe `debugpy-*.whl` exists in one of those roots.

- [x] **Step 4: Install actual APK wheel**

For APK packs with `providesPythonPackages`, install the real bundled wheel:

```text
decode Zip wheel
verify METADATA Name/Version
extract safely into runtimes/python/site-packages
smoke import through NativeBridge.runNativePython on Android
write python-wheels/debugpy.json receipt
```

Do not use the old fake marker path for `android-python-debug-runtime`.

### Task 4: Device Proof And Scorecard

**Files:**
- Modify after proof: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`
- Modify after proof: `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md`
- Modify after proof: `docs/ANDROID_PYTHON_DEBUG_RUNTIME_PAYLOAD.md`

- [x] **Step 1: Host verification**

Run:

```powershell
flutter test test/android_cli_core_payload_packaging_test.dart test/skill_provisioning_service_test.dart test/skill_parity_audit_service_test.dart --no-pub
flutter analyze lib/services/skill_provisioning_service.dart test/skill_provisioning_service_test.dart test/android_cli_core_payload_packaging_test.dart --no-pub
git diff --check
```

- [ ] **Step 2: Build and install milestone APK**

Run:

```powershell
flutter build apk --debug --no-pub
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p com.nxg.openclawproot -c android.intent.category.LAUNCHER 1
```

- [x] **Step 3: Device smoke**

Prove:

```text
provisioning/python-debug/wheels contains debugpy wheel
.openclaw/runtimes/python/site-packages/debugpy exists
.openclaw/runtimes/python/site-packages/debugpy-1.8.21.dist-info/METADATA exists
/api/python/exec import debugpy -> 1.8.21
/device/health python-debugpy ready true
```

- [x] **Step 4: Update scorecard after proof**

Only after device proof, update:

```text
clean floor: 25/51 -> 26/51
installed-device Android-relevant ready: 26/51 -> 26/51 or 27/51
```

If the existing device already counted `python-debugpy`, keep installed-device
unchanged and explicitly explain that this phase moved the clean-fresh floor,
not the existing-device headline.

- [x] **Step 5: Commit and push**

Stage only source, tests, docs, script, and the approved wheel payload. Do not
stage APKs, `.tmp`, build reports, gateway logs, or unrelated local files.

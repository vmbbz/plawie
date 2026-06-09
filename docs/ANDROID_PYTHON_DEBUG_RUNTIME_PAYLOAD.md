# Android Python Debug Runtime Payload

This document records the provenance for the APK-local
`android-python-debug-runtime` payload used by `python-debugpy`.

## Payload

```text
package: debugpy 1.8.21
asset: assets/openclaw/python-debug-runtime/wheels/debugpy-1.8.21-py2.py3-none-any.whl
payload bytes: 5352888
payload sha256: b1e37d333663c8851516a47364ef473da127f9caebe4417e6df6f5825a7e9a92
runtime lane: android-python-debug-runtime
provided Python package: debugpy
install target: .openclaw/runtimes/python/site-packages
```

## Source

```text
project: debugpy
version: 1.8.21
source index: https://pypi.org/simple/debugpy/
wheel url: https://files.pythonhosted.org/packages/95/51/67e7cf11a53e40694f720457d5b3a1cdaaa3d5a9a633e482f225456b93ff/debugpy-1.8.21-py2.py3-none-any.whl
wheel sha256: b1e37d333663c8851516a47364ef473da127f9caebe4417e6df6f5825a7e9a92
```

## Build / Fetch

```powershell
powershell -ExecutionPolicy Bypass -File scripts/python_debug/build_debugpy_android_runtime.ps1 -InstallAsset
```

The helper downloads the pinned wheel, verifies SHA-256, confirms the wheel
contains `debugpy/__init__.py`, and confirms wheel metadata declares
`Name: debugpy` and `Version: 1.8.21`.

## Runtime Contract

The APK bootstrap copies the wheel to:

```text
filesDir/native-node-embedded/provisioning/python-debug/wheels/
```

`SkillProvisioningService` advertises `android-python-debug-runtime` only when
a compatible `debugpy` wheel exists in the app-owned provisioning roots. The
pack installer extracts the wheel into:

```text
filesDir/native-node-embedded/native-home/.openclaw/runtimes/python/site-packages
```

It then writes:

```text
dependencies/receipts/android-python-debug-runtime.json
dependencies/receipts/python-wheels/debugpy.json
```

## Host Evidence

Verified on 2026-06-09:

```text
script: scripts/python_debug/build_debugpy_android_runtime.ps1 -InstallAsset
script result: sha256 verified, metadata verified, asset installed
payload bytes: 5352888
payload sha256: b1e37d333663c8851516a47364ef473da127f9caebe4417e6df6f5825a7e9a92

host tests:
test/android_cli_core_payload_packaging_test.dart
test/skill_provisioning_service_test.dart
test/skill_parity_audit_service_test.dart

Android build:
flutter build apk --debug --no-pub
```

## Device Evidence

Verified on Samsung SM-A556E / `RZCX30KA9AW` on 2026-06-09:

```text
install: adb install -r -d build/app/outputs/flutter-apk/app-debug.apk -> Success
wheel: files/native-node-embedded/provisioning/python-debug/wheels/debugpy-1.8.21-py2.py3-none-any.whl
site-packages: files/native-node-embedded/native-home/.openclaw/runtimes/python/site-packages/debugpy
dist-info: files/native-node-embedded/native-home/.openclaw/runtimes/python/site-packages/debugpy-1.8.21.dist-info
pack receipt: dependencies/receipts/android-python-debug-runtime.json
wheel receipt: dependencies/receipts/python-wheels/debugpy.json, smokePassed true
/api/python/exec: import debugpy -> 1.8.21
/device/health: python-debugpy ready true
```

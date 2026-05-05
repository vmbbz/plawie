# Audit: OpenClaw Bootstrap Process

This document tracks the meticulous audit of the bootstrap/installation process for the OpenClaw Android app.

## Status Summary
- **Current Issue**: `BIN_WRAPPER_ERROR` caused by missing `openclaw` package during wrapper creation.
- **Root Cause Identification**: `BootstrapService.dart` relies on `command -v openclaw` to decide whether to install. If a binary wrapper exists but the package directory is missing (e.g. after a partial cleanup or failed install), it skips installation and fails at `createBinWrappers`.

## Change Analysis (since aa1cb0f)
- Commit `aa1cb0f` (TTS/mouth animations) was reported as "fine".
- `BootstrapService.dart` and `NativeBridge.dart` have not changed in the Dart layer since that commit.
- The failure likely stems from an edge case in the state check or a change in the environment/tarball content.

## Implementation Audit: Standard Practices

### 1. Robust State Verification
- **Current**: Checks `command -v openclaw`.
- **Finding**: Inadequate. Does not verify the integrity of the package directory.
- **Recommendation**: Implement a check for `usr/local/lib/node_modules/openclaw/package.json` directly.

### 2. Mandatory Installation Safeguards
- **Current**: Optional install based on `command -v`.
- **Finding**: If the package is corrupted, it doesn't auto-repair.
- **Recommendation**: The recently added `_ensureOpenClawPackageExists` helper is a step in the right direction but should be integrated into the main flow more cleanly.

### 3. Google Play Store Readiness
- **Requirements**:
    - Fast first run.
    - Robust error handling (no obscure PlatformExceptions).
    - Offline fallback where possible.
- **Observation**: `npm install` takes 10-15 minutes. This is a bad UX for Play Store users.
- **Strategy**: Pre-bundling the package in the rootfs tarball would be ideal, but for now, the "ensure" check is necessary.

## Reference Code Analysis

### BootstrapManager.kt
- `isBootstrapComplete()` (lines 49-57): Checks for `openclaw/package.json`.
- `createBinWrappers()` (lines 735-740): Throws if `package.json` is missing.

### BootstrapService.dart
- `runFullSetup()` (lines 101-310): The main flow. **MAJOR FINDING**: This method always performs a full download and extraction of the rootfs, even if only a small part (like the `openclaw` package) is missing. This is extremely inefficient for mobile users.
- `repairOpenClaw()` (lines 314-349): Manual repair logic exists but is not auto-triggered.

### DiagnosticService.dart
- `runGatewayDiagnostics()` (lines 7-51): Uses `command -v openclaw`.
- **Finding**: Like the bootstrap process, this can give a false positive if a broken wrapper exists.
- **Recommendation**: Update to check for the package directory or `package.json` directly.

## Incremental Bootstrap Analysis
Currently, the bootstrap process is "all or nothing". A robust implementation for the Play Store should be incremental:
1. **Verify Base System**: Is the rootfs extracted and is bash working? (If no, extract).
2. **Verify Node.js**: Is node installed and working? (If no, extract node tarball).
3. **Verify OpenClaw**: Is the package present and the wrappers working? (If no, npm install).

This would allow the app to fix a missing `openclaw` package without re-downloading the entire Ubuntu rootfs.

## Proposed "Robust" Implementation
1.  **Immediate**: Ensure `_ensureOpenClawPackageExists` is used correctly (Done).
2.  **Short-term**: Update `DiagnosticService.dart` to perform deeper checks.
3.  **Short-term**: Refactor `runFullSetup` to be incremental/idempotent.
4.  **Long-term**: Pre-bundle `openclaw` in the remote rootfs tarball for a faster "out-of-the-box" experience on the Play Store.

## Self-Healing Architecture
To ensure the app "always works" for mass adoption, we propose the following architecture:
- **Proactive Health Checks**: Every time the app resumes, verify the integrity of the rootfs and critical packages in the background.
- **Micro-Repairs**: Instead of a full reinstall, have a library of "micro-repair" scripts that can fix common issues (missing dependencies, corrupted config, broken symlinks).
- **Graceful Degradation**: If a high-quality model (like Kokoro TTS) fails to load, automatically fallback to a native engine without crashing.

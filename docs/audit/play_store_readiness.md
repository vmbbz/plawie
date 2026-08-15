# Audit: Google Play Store Readiness

> **Superseded (2026-08-10):** This early audit describes the former PRoot-first
> bootstrap and recommends bundling or remotely extracting runtime payloads.
> Plawie is now native-first, PRoot is user-demand fallback, and current Google
> Play policy requires a separate code-delivery and payments design. Use
> `docs/superpowers/plans/2026-08-10-google-play-wallet-keeperhub-release-plan.md`
> as the authoritative release plan. This file remains only as historical
> context and must not drive implementation.

This document evaluates the current bootstrap process against the requirements for a successful Google Play Store release.

## Key Challenges

### 1. Slow Initial Setup
- **Observation**: The current flow downloads a large rootfs (~100-200MB) and then runs `npm install -g openclaw` which can take another 10-15 minutes.
- **Risk**: High user churn during setup. Play Store users expect apps to be "ready to use" within seconds or a few minutes.
- **Recommendation**:
    - **Pre-bundle OpenClaw**: Update the rootfs tarball at `AppConstants.getRootfsUrl()` to already include the `openclaw` package and its dependencies.
    - **Partial Updates**: If pre-bundling isn't possible, use a zipped version of the `node_modules/openclaw` directory that can be extracted quickly, instead of running `npm install`.

### 2. Network Reliability
- **Observation**: `npm install` is highly dependent on network stability and npm registry availability.
- **Risk**: Setup failures due to transient network issues, which are common on mobile devices.
- **Recommendation**:
    - **Retry Logic**: Implement robust retry logic for the `npm install` command (which we've started with `_ensureOpenClawPackageExists`).
    - **Offline Assets**: Bundle the most critical assets within the APK if possible.

### 3. Native Compatibility
- **Observation**: The app uses `proot` which relies on `ptrace` and `seccomp`.
- **Risk**: Some Android versions or manufacturer skins (e.g. Samsung Knox, newer Android 14/15 restrictions) might block or restrict these low-level system calls.
- **Recommendation**:
    - **Diagnostic Tool**: Expand the `diagnostic_service.dart` to check for `ptrace` availability and other proot requirements early in the setup.
    - **Bionic Bypass**: Ensure the `bionic-bypass.js` is always up to date as it's critical for Node.js compatibility on Android.

## Meticulous Audit Findings

### File: BootstrapManager.kt
- **Strength**: Pure Java extraction (Apache Commons) is more reliable than forking `tar` on Android.
- **Weakness**: `createBinWrappers` is very strict. It throws an error if the package is missing, but it doesn't offer a way to "fix" it natively.
- **Recommendation**: Add a `hasPackage(name: String): Boolean` method to the native bridge to avoid redundant shell calls like `command -v`.

### File: BootstrapService.dart
- **Strength**: Clear step-by-step progress reporting.
- **Weakness**: `repairOpenClaw` is a manual process.
- **Recommendation**: If `isBootstrapComplete()` returns false during app launch, it should automatically enter a "Repair/Resume" mode instead of just failing or showing a generic error.

## Action Plan for Robustness
1.  **Immediate**: Ensure `_ensureOpenClawPackageExists` is used correctly (Done).
2.  **Short-term**: Update the remote rootfs tarball to include `openclaw` pre-installed.
3.  **Short-term**: Modify `BootstrapManager.kt` to be more descriptive in its errors and provide better status checks.

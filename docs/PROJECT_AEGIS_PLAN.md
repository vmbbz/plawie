# 🛡️ Project Aegis: Technical Implementation Plan
**Status:** DRAFT / PRE-IMPLEMENTATION (Phase 1 Start Tonight)
**Architecture:** Hybrid glibc-Wrapper (AidanPark Evolution)

## 🎯 Objective
Replace the legacy 1.5GB PRoot Ubuntu environment with a lightweight, high-performance glibc-runner bridge. Reduce storage footprint by 80% and gateway boot time by 90%.

---

## 🏗️ Phase 1: Native & Bootstrap Refactor (Tonight)

### 1. Kotlin Layer (Process Management)
- **Target**: `android/app/src/main/kotlin/com/nxg/openclawproot/ProcessManager.kt`
- **Action**: Implement `buildGlibcCommand()`. 
- **Logic**: Use `ld-linux-aarch64.so.1` to execute the Node.js binary directly from app-internal storage.
- **Goal**: Eliminate `ptrace` (PRoot) syscall interception.

### 2. Bootstrap Layer (Asset Management)
- **Target**: `android/app/src/main/kotlin/com/nxg/openclawproot/BootstrapManager.kt`
- **Action**: Add logic to handle the `glibc-bridge.tar.gz` (Atomic 200MB package).
- **Migration**: Check for existing `/rootfs` and provide a `purgeLegacyRootfs()` method to reclaim ~1.5GB.

### 3. Dart Layer (Bridge Interface)
- **Target**: `lib/services/native_bridge.dart`
- **Action**: Generalize `runInProot()` to `runNativeCommand()`.
- **Logic**: The bridge will now intelligently route commands to the glibc loader.

---

## 🏗️ Phase 2: OpenClaw Compatibility (Post-Migration)

### 1. The Bionic Bridge
- Ensure `bionic-bypass.js` is updated to handle DNS and Socket translation for the native glibc environment.
- Verify `OLLAMA_HOST` routing is preserved across the new bridge.

### 2. Monitoring & Watchdog
- Update the `GatewayService` watchdog to poll at **1-second intervals** initially, as boot will be near-instant.

---

## 📊 Performance Targets
| Metric | PRoot (Old) | Aegis (New) |
| :--- | :--- | :--- |
| **Asset Download** | ~700 MB | **~180 MB** |
| **Disk Footprint** | ~1.8 GB | **<300 MB** |
| **Cold Boot** | 120–240s | **<10s** |
| **CPU Overhead** | ~15% (Ptrace) | **~0% (Native)** |

---

## ⚠️ Known Risks
- **Library Mismatch**: Ensuring the glibc shim includes all `libssl`, `libcrypto`, and `libstdc++` dependencies required by Node.js 22.
- **Permission Scope**: Ensuring the `ld.so` has execution permissions on Android 14+ (Targeting `/data/user/0/com.nxg.openclawproot/files/`).

# 🛡️ Project Aegis: Phase 1 (v2.1.0-beta.1)

Welcome to the future of Plawie. The v2.1.0 update marks the most significant architectural evolution since the project's inception. We have successfully migrated from a legacy PRoot-based Ubuntu rootfs to a high-performance **Aegis Native glibc Engine**.

## ⚡ Key Highlights
- **Sub-10s Cold Boot**: Native glibc execution eliminates container overhead, launching the OpenClaw gateway almost instantly.
- **1.5GB Storage Reclamation**: By removing the heavy Ubuntu rootfs, we've reduced the device storage footprint by ~80%.
- **Atomic Infrastructure**: A streamlined bootstrap process that extracts pre-bundled Node.js and glibc modules in under 60 seconds.
- **Native Kernel Access**: Direct communication with the Android kernel through the `glibc-compat.js` shim, improving battery efficiency and system stability.

## 🛠️ Phase 1 Changes
- **Native Bridge**: Replaced `ptrace`-based execution with direct `ld.so` loading.
- **Storage Purge**: Automated deletion of the legacy rootfs upon first boot into Aegis mode.
- **Binary Parity**: Official Node.js v22 LTS binaries bundled for native arm64 execution.
- **Aegis Status Watchdog**: Real-time monitoring of the native bridge status from the Flutter UI.

## ⚠️ Pre-release Information
This is a **Beta** release of the Aegis Native Engine. 
- Existing users will experience a "One-Time Migration" where the 1.5GB rootfs is purged.
- Performance and battery life are significantly improved compared to v2.0.0.

---
*Project Aegis: Minimal Footprint. Maximum Power.*

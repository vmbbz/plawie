<p align="center">
  <img src="assets/images/release_banner_v2.jpg" alt="Plawie v2.0" width="800"/>
</p>

# 🌌 Plawie v2.0.0-beta.1 — "The Hardened Milestone"

> [!IMPORTANT]
> This release marks the transition of Plawie from an engineering prototype into a **hardened, production-ready autonomous agent platform**. We have focused on **Precision Stability**, **Granular Security**, and a **World-Class User Experience**.

---

## 🛰️ The Big Leap
This release re-engineers the core of Plawie. We've moved away from experimental "hacker" setups to a refined, automatic environment that manages itself. Whether you are running complex tool-calling agents or simple local chat, Plawie v2.0 provides the most stable Linux-on-Android gateway ever built.

---

## 🚀 Major Highlights

### 🛡️ 1. Granular "Pro" Storage Model (Play Store Compliant)
We have refactored our storage engine to move away from aggressive "All Files" requirements by default.
- **Sandboxed by Default**: Plawie now operates in a high-performance sandbox, ensuring privacy and compliance.
- **Pro Storage Opt-in**: Access **Settings > Storage & Files** to enable "All Files Access". This bind-mounts your phone's `/sdcard` directly into the PRoot Ubuntu environment for seamless model and file management.

### 🔄 2. Intelligent Auto-Repair Engine (Self-Healing)
No more silent failures or corrupted environments.
- **Proactive Watchdog**: A background monitor detects missing dependencies or stale configurations on startup.
- **Surgical Self-Healing**: If a configuration error is detected, Plawie automatically patches `openclaw.json` and `tools.allow` in under 3 seconds.

### ⚡ 3. Hardened Bootstrap (Instant Setup)
Initial setup time has been reduced by **~95%** (from 15 minutes to under 40 seconds).
- **Pre-bundled Core**: OpenClaw's heavy `node_modules` are now pre-extracted from an atomic APK tarball.
- **Multi-threaded Downloader**: Remaining assets are acquired via a parallel HTTP Range downloader, saturating your connection for maximum speed.

### 🍃 4. Ephemeral Build Lifecycle (-800 MB Savings)
We've optimized the disk footprint to keep your phone clean.
- **JIT Compilers**: Heavy tools (`g++`, `python3`) are installed only when needed for native module compilation.
- **Automatic Purge**: Once the environment is optimized, all build tools and caches are surgically removed, saving nearly **1 GB** of storage.

---

## 🏗️ Technical Architecture

| Component | Status | Purpose |
| :--- | :---: | :--- |
| **PRoot Ubuntu 24.04** | `HARDENED` | Standardized execution layer |
| **Node.js v22.22.2** | `STABLE` | High-performance gateway engine |
| **Foreground Service** | `PERSISTENT` | Zero-drop background execution |
| **Storage Bridge** | `OPT-IN` | Granular SAF /sdcard access |

---

## 📄 Installation & Migration
1. **Download**: Grab the `app-release.apk` from the GitHub Releases page.
2. **Launch**: Plawie will automatically detect your existing environment.
3. **Migrate**: The **Auto-Repair Engine** will automatically sanitize your legacy configurations for v2.0 compatibility.

---

<p align="center">
  <sub><i>"Run OpenClaw fully local. Private, always-on, and under your absolute control."</i></sub><br/>
  <b>Plawie — The World's Most Powerful Autonomous Agent Experience for Android.</b>
</p>

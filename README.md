<div align="center">

# 🐾 CLAWA

### *AI in Your Pocket*

**The world's first fully local AI agent running natively on Android.**
No cloud. No subscriptions. No data leaving your device. Ever.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-12+-3DDC84?style=for-the-badge&logo=android)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/Powered_by-OpenClaw-FF6B6B?style=for-the-badge)](https://github.com/cosychiruka/clawa)

---

*Clawa runs a complete Ubuntu Linux environment inside your Android phone,*
*boots a full Node.js AI agent (OpenClaw), and accelerates inference with native GPU power.*
*It's not a wrapper. It's not an API call. It's the real thing, in your pocket.*

</div>

---

## 🏗️ Architecture

```
┌──────────────── YOUR ANDROID PHONE ─────────────────┐
│                                                     │
│  ┌── Flutter App (Premium UI)                       │
│  │    └─ Settings: Ollama | MLC (GPU) | Cloud       │
│  │                                                  │
│  ├── MLC-LLM Engine (Native GPU) ──────────────┐   │
│  │    └─ OpenCL/Vulkan → Adreno/Mali            │   │
│  │    └─ OpenAI proxy on 127.0.0.1:8000     ◄───┤   │
│  │                                              │   │
│  ├── PRoot Ubuntu 24.04 (Guest OS) ─────────────┤   │
│  │    └─ Node.js 22                             │   │
│  │    └─ OpenClaw Agent (tools, memory, APIs)   │   │
│  │    └─ Ollama (CPU fallback) on :11434    ◄───┤   │
│  │                                              │   │
│  ├── ClawaForegroundService ────────────────────┤   │
│  │    └─ WakeLock + PPK resistance              │   │
│  │    └─ tmux daemon lifecycle                  │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

Clawa uses a **split-architecture** that separates the AI agent (Node.js + OpenClaw inside PRoot) from the LLM inference engine (native Android GPU). This means:

- **OpenClaw** handles tools, memory, Telegram/WhatsApp integrations, and background tasks
- **MLC-LLM** handles GPU-accelerated token generation at 8–25+ tokens/sec
- **Ollama** serves as a CPU fallback for maximum compatibility
- **Cloud providers** (Gemini, Claude) are available when local isn't enough

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🧠 **Fully Local AI** | Complete LLM inference on-device — no API keys, no cloud, no data leaks |
| ⚡ **GPU Acceleration** | Native MLC-LLM engine with OpenCL/Vulkan for 3–5× faster inference |
| 🐧 **Real Linux** | Full Ubuntu 24.04 with Node.js 22 running inside PRoot |
| 🤖 **OpenClaw Agent** | Tool use, persistent memory, web browsing, code execution |
| 📱 **Background Mode** | Foreground service with WakeLock keeps the agent alive 24/7 |
| 🔄 **tmux Daemon** | Ollama survives app restarts, device sleep, and session crashes |
| 🌐 **Cloud Fallback** | Gemini, Claude, and custom OpenAI-compatible endpoints |
| 💬 **Messaging** | Telegram and WhatsApp integration via OpenClaw |
| 🔒 **Privacy First** | Zero telemetry. Everything stays on your device |
| 🎛️ **Backend Selector** | Choose between Ollama (CPU), MLC (GPU), or Cloud in Settings |

---

## 🚀 Quick Start

### Prerequisites
- Android 12+ (API 31+) device with 6GB+ RAM
- ~4GB free storage for Ubuntu + model weights

### Install
1. Download the latest APK from [Releases](https://github.com/cosychiruka/clawa/releases)
2. Install and open Clawa
3. The setup wizard will automatically:
   - Download Ubuntu 24.04 base (~30MB)
   - Install Node.js 22 LTS
   - Install OpenClaw agent
   - Download and configure your chosen LLM model

### First Run
After setup completes, tap **Start Gateway** to boot the OpenClaw agent. The agent is reachable via:
- **Built-in chat interface** in the app
- **Web dashboard** at `http://localhost:18789`
- **Telegram/WhatsApp** via OpenClaw integrations

---

## 🎛️ Inference Backends

### 🟢 Ollama (Default — CPU)
Works on every Android device. Runs inside PRoot with tmux daemonization.
- **Speed:** 2–5 tokens/sec
- **Compatibility:** Universal
- **Model:** `gemma3:1b` (default)

### 🔵 MLC-LLM (Native GPU — Recommended)
Runs outside PRoot directly on Android's GPU via OpenCL.
- **Speed:** 8–25+ tokens/sec on flagship phones
- **GPU support:** Qualcomm Adreno, ARM Mali
- **Model:** Pre-compiled MLC models (gemma, phi, llama)

### ☁️ Cloud (Gemini / Claude)
For users who prefer cloud APIs or need larger models.
- **Speed:** Network-dependent
- **Models:** Gemini Pro, Claude 3, custom endpoints

---

## 🛠️ Development

### Build from Source
```bash
# Clone
git clone https://github.com/cosychiruka/clawa.git
cd clawa

# Dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Project Structure
```
lib/
├── main.dart                    # Entry point
├── app.dart                     # App configuration
├── constants.dart               # Version, URLs, ports
├── models/                      # Data models
├── providers/                   # State management
├── screens/                     # UI screens
│   ├── dashboard_screen.dart    # Main dashboard
│   ├── terminal_screen.dart     # Built-in terminal
│   ├── settings_screen.dart     # Backend selector
│   └── setup_wizard_screen.dart # Bootstrap wizard
├── services/
│   ├── bootstrap_service.dart   # PRoot + Ollama setup
│   ├── mlc_service.dart         # MLC-LLM lifecycle
│   ├── native_bridge.dart       # Flutter ↔ Kotlin bridge
│   ├── gateway_service.dart     # OpenClaw gateway
│   └── preferences_service.dart # Settings + backend enum
└── widgets/                     # Reusable UI components

android/app/src/main/kotlin/com/nxg/openclawproot/
├── MainActivity.kt              # MethodChannel handler
├── ProcessManager.kt            # PRoot command builder
├── ClawaForegroundService.kt    # Background lifecycle
└── mlc/
    ├── MLCEngineManager.kt      # Native GPU engine
    └── LocalOpenAIServer.kt     # OpenAI-compatible proxy
```

### MLC-LLM Setup (For GPU Acceleration)
```bash
# On your dev machine (Linux/Mac):
pip install mlc_llm
git clone https://github.com/mlc-ai/mlc-llm && cd mlc-llm

# Compile model for Android
mlc_llm package --config mlc-package-config.json

# Copy output to your project
cp -r dist/lib/mlc4j android/app/libs/mlc4j
```

Recommended models for `mlc-package-config.json`:
- `HF://mlc-ai/gemma-3-1b-it-q4f16_1-MLC` (fastest, ~500MB)
- `HF://mlc-ai/phi-3.5-mini-instruct-q4f16_1-MLC` (balanced)
- `HF://mlc-ai/Llama-3.2-3B-Instruct-q4f16_1-MLC` (most capable)

---

## 📋 Technical Notes

### Android Phantom Process Killer (PPK)
Android 12+ aggressively kills background processes. Clawa mitigates this with a foreground service, but for best results on heavy workloads:
```bash
adb shell device_config put activity_manager max_phantom_processes 2147483647
```

### PRoot Performance
PRoot uses `ptrace` to intercept syscalls, adding ~15-30% overhead. This is why we offer the MLC native GPU path for inference — it bypasses PRoot entirely.

### GPU Bind Mounts
Clawa conditionally binds GPU device nodes (`/dev/kgsl-3d0`, `/dev/mali0`, `/dev/dri`) into PRoot when they exist. These enable experimental Vulkan passthrough but are **not required** — the MLC engine handles GPU acceleration natively.

---

## 🗺️ Roadmap

- [x] PRoot Ubuntu environment with Node.js
- [x] OpenClaw agent integration
- [x] Ollama LLM server (CPU)
- [x] tmux daemonization & lifecycle management
- [x] Foreground service (PPK resistance)
- [x] MLC-LLM native GPU engine
- [x] OpenAI-compatible proxy (SSE streaming)
- [x] Backend selector (Ollama / MLC / Cloud)
- [ ] 3D VRM animated avatar interface
- [ ] Voice input/output (TTS + STT)
- [ ] Model download manager (on-device)
- [ ] Multi-agent orchestration

---

## 📄 License

MIT © [cosychiruka](https://github.com/cosychiruka)

---

<div align="center">

**Built with 🔥 by the Clawa team**

*Running AI locally isn't the future — it's right now, in your pocket.*

</div>

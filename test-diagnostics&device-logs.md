# Plawie / OpenClaw Android — Help & Diagnostics

## 🛡️ Architecture & Tech Stack Overview

### For Everyone (Non-Tech + Tech)

**Plawie** is a **fully offline-capable AI companion** that runs on any Android phone.  
You simply download the APK, install it, and it works — no cloud, no subscription, no internet required after setup.

Think of it as:
- A **powerful local brain** (LLM + memory + tools)
- A **voice-first interface** (talk to it, it talks back with lip-synced avatar)
- All running **entirely on your phone**

It feels like having a full Linux server + AI agent in your pocket, but packaged as a normal Android app that anyone can use.

---

### High-Level View (Non-Technical)

The app has two main layers that work together seamlessly:

1. **Flutter Front-End** (the beautiful Android UI you see)  
   - Handles chat, voice input (STT), voice output (TTS), VRM avatar lip-sync, settings, etc.  
   - Built with modern Flutter/Dart — fast, native-feeling, beautiful.

2. **Embedded OpenClaw Gateway** (the powerful Linux-based AI engine)  
   - Runs a complete Node.js + plugin system inside your phone.  
   - Manages the LLM (local Ollama or cloud fallback), memory, tools, voice personas, canvas, device controls, etc.  
   - All communication happens over a local WebSocket on `127.0.0.1:18789`.

The magic glue is **Proot** — a lightweight Linux compatibility layer that lets the full OpenClaw gateway run inside Android without rooting your phone.

**Result**: Peter and Joe just install the app and immediately get a private, offline AI companion with voice, memory, and real tools.

---

### Deep Technical Architecture (For Developers)

#### 1. **Overall Stack**

| Layer              | Technology                          | Purpose |
|--------------------|-------------------------------------|---------|
| **Frontend**       | Flutter + Dart                      | Native Android UI, WebSocket client, audio playback, VRM lip-sync |
| **Backend Engine** | OpenClaw (Node.js) + plugins        | LLM orchestration, tools, memory, TTS/STT, personas |
| **Runtime**        | Proot + pre-bundled rootfs          | Runs full Linux/Node.js binaries on Android without root |
| **LLM**            | Local Ollama (or cloud fallback)    | Fully offline reasoning |
| **Communication**  | Local WebSocket (`ws://127.0.0.1:18789`) | Zero-latency between Flutter and gateway |
| **Voice**          | Gateway `talk-voice` plugin + sherpa-onnx/piper | High-quality offline TTS + personas |
| **Audio I/O**      | Flutter `audioplayers` + `record`   | Playback of gateway MP3s + microphone STT |

#### 2. **Why Proot + Rootfs? (The Core Design Decision)**

- Android does **not** allow normal Linux binaries to run natively.
- **Proot** is a user-space chroot implementation. It intercepts syscalls and translates them so a full Linux environment can run inside Termux without root privileges.
- We ship a **pre-bundled rootfs** (`openclaw-node-modules.tar.gz`) containing:
  - Node.js + OpenClaw gateway
  - All plugins (`talk-voice`, `memory-core`, `device-pair`, etc.)
  - Sherpa-onnx/Piper TTS models
  - Ollama-compatible environment

**Why this is brilliant:**
- No root required → works on any Android device (even non-rooted phones).
- Full Linux compatibility → we get the **exact same OpenClaw** that runs on real Linux servers.
- Pre-bundled → Peter & Joe don’t wait for npm installs or model downloads on first run.
- Isolated → the gateway lives in its own filesystem sandbox.

#### 3. **Why Node.js for the Gateway?**

OpenClaw was originally built as a Node.js/TypeScript project. Using the **same gateway code** on Android gives us:
- Mature plugin ecosystem (browser, phone-control, voice, memory, etc.)
- Official CLI (`openclaw config set`, `doctor --fix`, `onboard`)
- Battle-tested WebSocket, TTS, and agent system
- Easy schema validation and hot-reload

We didn’t rewrite anything — we embedded the real thing.

#### 4. **Configuration & Reliability Layer (The Hardening You Built)**

All the recent work (`_hardenGatewayConfigViaCli`, guarded `_readConfig`, token-preserving patch, synchronized `_attachOrStart`) ensures:
- Fresh install always succeeds.
- `auth.token`, `allowedOrigins`, `autoApproveCidrs`, etc. survive `doctor --fix`, `onboard`, and restarts.
- No more token_mismatch or origin=n/a errors.

This is what makes the “download → install → works” promise real.

#### 5. **Data Flow Example (Voice Chat)**

1. User speaks → Flutter `record` package captures audio.
2. Audio sent to local Ollama (or gateway STT).
3. LLM generates reply.
4. Gateway TTS (`talk-voice` plugin) turns text into MP3 using chosen persona.
5. Gateway serves MP3 at `http://127.0.0.1:18789/__openclaw__/media/...`
6. Flutter receives URL via WebSocket → plays it + triggers VRM lip-sync.

---

## 🛠️ Diagnostics & Troubleshooting

### The Peter & Joe “Download → Install → Run” Flow
Exact chronological sequence after a fresh install:

1. **App launches** → `bootstrap_service.runFullSetup()`
2. **Rootfs + Node + OpenClaw installed** (pre-bundled preferred, fallback to download/npm).
3. **Gateway start** → `_attachOrStart()` (in GatewayService)
4. **Inside `_attachOrStart()`**:
   - Check if gateway already running → if not, start it.
   - `_configureGateway()` (guarded write)
   - `openclaw doctor --fix`
   - Full `openclaw onboard --non-interactive`
   - Awaited `_hardenGatewayConfigViaCli()` (token-preserving patch)
   - Health check + WebSocket attach
5. **Gateway becomes ready** → Control UI connects cleanly.

### Granular Progress Reporting
To improve the waiting experience, we now report the following stages:

| UI Message Shown          | What Is Actually Running Behind the Scenes                  |
|---------------------------|-------------------------------------------------------------|
| CONFIGURING API CREDENTIALS… | `openclaw onboard` + doctor --fix + hardening patch        |
| VERIFYING SETUP…          | Gateway start + plugin load + health check + WebSocket attach |

### One-Paragraph Pitch

> “Plawie is a fully offline AI companion built on Flutter + an embedded OpenClaw gateway. We use Proot to run a complete Linux/Node.js environment inside Android without rooting the device. This gives us the full power of OpenClaw’s agent system, voice personas, memory, and tools — all running locally with Ollama. The Flutter layer handles the beautiful UI and real-time voice/avatar sync. The result is an app that anyone can install and immediately talk to like a real assistant, with zero cloud dependency and complete privacy.”
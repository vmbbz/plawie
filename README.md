# Plawie — Your Pocket OpenClaw Companion

<div align="center">
  <img src="assets/app_icon_official.svg" alt="Plawie Logo" width="180"/>
  
  <br/>
  
  <h1>🌌 Plawie</h1>
  <h3>The World's Most Powerful Autonomous Agent Experience for Android</h3>
  
  **Local PRoot Gateway • Native Web3 • Immersive VRM Companion**
  
  <br/>

  [![License: MIT](https://img.shields.io/badge/License-MIT-00C853.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
  [![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B.svg?style=for-the-badge&logo=flutter)](https://flutter.dev)
  [![Node.js](https://img.shields.io/badge/Node.js-22+-339933.svg?style=for-the-badge&logo=node.js)](https://nodejs.org)
  [![Solana](https://img.shields.io/badge/Solana-Mainnet-9945FF.svg?style=for-the-badge&logo=solana)](https://solana.com)
</div>

---

## 📱 The Experience

Plawie isn't just an app; it's a living digital entity that exists within your device. It combines industrial-grade Linux automation with a premium, glassmorphic user interface.

<div align="center">
  <table>
    <tr>
      <td width="33%"><img src="assets/images/chat_main.jpg" alt="Chat Interface"/><br/><sub><b>Immersive Chat</b></sub></td>
      <td width="33%"><img src="assets/images/dashboard.jpg" alt="Main Dashboard"/><br/><sub><b>Real-time Dashboard</b></sub></td>
      <td width="33%"><img src="assets/images/avatar_gemini.jpg" alt="3D Avatar"/><br/><sub><b>Procedural VRM Companion</b></sub></td>
    </tr>
    <tr>
      <td width="33%"><img src="assets/images/agent_tools.jpg" alt="Agent Tools"/><br/><sub><b>35+ Native Skills</b></sub></td>
      <td width="33%"><img src="assets/images/local_llm.jpg" alt="Local LLM"/><br/><sub><b>Offline Inference</b></sub></td>
      <td width="33%"><img src="assets/images/agent_fleet.jpg" alt="Agent Fleet"/><br/><sub><b>Multi-Agent Workspace</b></sub></td>
    </tr>
  </table>
</div>

---

## 🧠 Industrial-Grade Mobile Architecture

Plawie represents a top 1% engineering achievement: a full **Ubuntu + Node.js OpenClaw environment** running entirely within a sandboxed **PRoot** layer directly on your phone.

### 🛡️ Production Reliability
- **Hardened Bootstrap (Instant-Install)**: Setup reduced from 15 minutes to **under 40 seconds** using pre-bundled assets and parallel multi-threaded downloading.
- **Proactive Self-Healing**: An intelligent watchdog monitor triggers a surgical "Auto-Repair" sequence in under 3 seconds if dependencies are missing.
- **Ephemeral Build Tools**: Heavy compilers (`g++`, `python3`) are installed only when needed and purged immediately, saving over **800 MB** of disk space.
- **Sticky Foreground Services**: The OpenClaw engine survives app closures and background pruning, ensuring 24/7 autonomous operation.

### 🔗 The Web3 Foundation
Plawie is your native Solana co-pilot. constructed and signed locally on your hardware:
- **Real Ed25519 Keypairs:** Secured in on-device storage.
- **DeFi Ready:** Swap tokens via direct Jupiter API integration.
- **MoonPay Integration:** Give your agent a bank account and 30+ financial skills via the `@moonpay/cli`.

---

## 🎙️ The Voice-First Pipeline

Plawie ships a complete, multi-engine voice stack for truly hands-free interaction:
- **4 TTS Engines** — Piper (offline), Android Native, ElevenLabs, or OpenAI TTS.
- **Continuous Mode** — The mic automatically restarts after the agent speaks.
- **Wake Word "Plawie"** — Activate your agent entirely offline using the Vosk ASR engine.

---

## 🏗️ Technical Deep Dive

```mermaid
graph TD
    subgraph "The Shell (Flutter)"
        A[Native Chat & UI] --> B[SkillsService]
        A --> D[TtsService]
        A --> W[Wake Word ASR]
    end

    subgraph "The Brain (PRoot + Node.js)"
        E[Ubuntu Sandbox] --> F[OpenClaw Gateway v22+]
        F --> G[35+ Device Skills]
        L[fllama NDK — Offline Inference]
    end

    subgraph "The Expression (Three.js)"
        H[Overlay Window] --> I[VRM Renderer]
        I --> J[Procedural Math]
    end

    A -- "RPC" --> F
    D -- "Visemes" --> I
```

### ⚡ Technology Stack
- **The Gateway:** PRoot + Ubuntu ARM64 + Node.js v22+.
- **The Local LLM:** [fllama](https://github.com/Telosnex/fllama) — Native ARM64 `.so` via NDK.
- **The Web3 Layer:** Native `solana` Dart SDK + Jupiter Ultra API.
- **The Expression:** WebGL bone-tracking renderer (Three.js).

---

## 📦 Deployment

### Build Instructions
```bash
# 1. Clone & install dependencies
git clone https://github.com/vmbbz/plawie.git
flutter pub get

# 2. Build for production (ARM64)
flutter build apk --release --target-platform android-arm64
```

---

<div align="center">
  <img src="assets/images/gateway_logs.jpg" alt="Gateway Logs" width="400"/>
  <br/>
  <strong>🌌 Your AI Agent. Your Rules. Your Reality. 🌌</strong>  
</div>

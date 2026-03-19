# Contributing to Plawie — OpenClaw on Android

Welcome to the edge of what's possible in mobile AI. Plawie is the first app to run a complete **OpenClaw AI gateway** natively on Android inside a PRoot Linux sandbox — no cloud, no root, total privacy.

We are looking for exceptional contributors across **Flutter**, **Three.js / VRM**, **Node.js / OpenClaw skills**, **Android native**, and **Web3 / on-chain tooling**.

---

## 🌟 What We're Building

Plawie is more than a chat app. It is a **pocket AI agent runtime** with:

- A full Ubuntu + Node.js OpenClaw server running inside PRoot on Android
- An Airi-style immersive companion powered by procedural Three.js VRM animation
- A multi-chain Web3 layer (ETH, Base, SOL, BTC, USDC via native Dart + MoonPay MCP)
- An extensible premium skills system (AgentCard, MoltLaunch, Valeo, Twilio, MoonPay)
- 24/7 background stability via Android Foreground Services + WorkManager heartbeat

---

## 🏗️ Technical Standards

### 1. Flutter / Dart
- **Architecture:** Multi-isolate. UI stays in the main isolate. Background overlay and the Node.js gateway live in their own sandboxes. Never block the main thread.
- **State Management:** `Provider` for all reactive UI. No setState in top-level widgets.
- **Analysis:** Run `flutter analyze` before every commit. Zero introduced warnings in `main`.
- **Naming:** Follow existing service / screen / provider file naming conventions exactly.

### 2. VRM + Three.js
- All procedural math must be `delta`-time-independent to maintain 60 fps on mid-range hardware.
- Wind / physics functions must be continuous (sum-of-sines) to prevent SpringBone jitter.
- New gesture clips go in `assets/vrm/gestures/` as `.vrma` files.
- Camera framing changes must preserve PIP behaviour (do not break `isPip` branch in `updateCameraFraming`).

### 3. Agent Skills
- Every new skill needs: a `_create*Skill()` creator in `skills_service.dart`, an `_execute*Skill()` executor routing via `GatewaySkillProxy`, and a detail page in `lib/screens/management/skills/`.
- Skills must declare a complete `parametersSchema` so Claude can call them correctly via Tool Use.
- Provide graceful offline fallbacks when the gateway is not connected.
- Add a `tooltip` string to the `_SkillEntry` in `skills_manager.dart` so users know what the agent can do.

### 4. Android Native / Background Services
- All PRoot and gateway process management stays in `GatewayService` and `GatewayConnection`.
- Battery optimisation exemption and WorkManager heartbeats are mandatory for any new background worker.
- Keep `NODE_OPTIONS=--max-old-space-size=256` (or lower) on all Node.js child processes.

### 5. Web3
- All on-chain calls must be non-blocking with full RPC error handling.
- MoonPay MCP commands must ask for user confirmation before any swap / buy / bridge.
- AgentCard and MoltLaunch operate on **Base (EVM / ETH)**. Solana DeFi uses Jupiter Ultra API.

---

## 🚀 Contribution Workflow

```bash
# 1. Fork + branch from main
git checkout -b feature/your-feature-name

# 2. Implement, then verify
flutter analyze

# 3. Commit with a clear conventional commit message
git commit -m "feat(skills): add X skill with Y capability"

# 4. Open a PR describing:
#    - What changed in the Gateway layer (Node.js / PRoot side)
#    - What changed in the Expression layer (Flutter / VRM side)
#    - Screenshot or recording of any UI change
```

---

## 🎨 Design Language — "2026 Glassmorphic Dark"

Plawie follows a strict premium design system:

| Rule | Detail |
|------|--------|
| **Dark-first** | OLED-optimised. Background: `#0A0F1E` to `#0D1B2A` |
| **Glassmorphism** | `BackdropFilter` blurs + `withValues(alpha: 0.04–0.12)` surfaces |
| **Gradients** | No flat colours. Use curated multi-stop gradients |
| **Typography** | `GoogleFonts.outfit()` for all display text |
| **Micro-animations** | Lerp all state transitions. Lerp factor: `delta * 3–6` |
| **Status colours** | Use `AppColors.statusGreen / statusGrey` — never raw `Colors.green` |

---

## 📦 Architecture Reference

- `ARCHITECTURE_REPORT.md` — core engine, gateway, PRoot diagram
- `UPGRADE_PLAN_v1.0.md` — roadmap and phased feature plan
- `PROMOTIONAL_PITCH.md` — brand voice and messaging guide

When adding a new system (e.g. local LLM layer, new sensor skill), create an `ARCHITECTURE_*.md` alongside these files and link it in the README.

---

## 🔬 Local LLM Research

We are actively investigating running lightweight local LLMs (Qwen, Kimi, Phi-3 Mini) **inside our PRoot sandbox** on device. See `ARCHITECTURE_LOCAL_LLM.md` (coming soon) for the research doc. If you have hands-on experience shipping Ollama, llama.cpp, or MLC-LLM on Android (without root), we want your findings in that doc.

---

## ⚖️ License

By contributing to Plawie, you agree that your contributions will be licensed under the **MIT License** (see `LICENSE`).

---

<div align="center">

**🌌 Plawie — Your AI Agent, Your Rules, Your Reality**

*Thank you for helping push the boundary of what runs in your pocket.*

</div>

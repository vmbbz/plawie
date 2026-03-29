# Contributing to Plawie — OpenClaw on Android

Welcome to the edge of what's possible in mobile AI. Plawie runs a complete **OpenClaw AI gateway** (Node.js + PRoot Ubuntu ARM64) alongside a **native llama.cpp inference engine** ([fllama](https://github.com/Telosnex/fllama) NDK plugin) — all inside a single Android APK, no root required.

We welcome contributors across **Flutter/Dart**, **Android NDK/C++**, **Three.js/VRM**, **Node.js/OpenClaw skills**, and **Web3/on-chain tooling**.

---

## What We're Building

Plawie is a pocket AI agent runtime with two independent compute planes:

| Plane | Technology | Role |
|-------|-----------|------|
| **Gateway** | Ubuntu PRoot + Node.js + OpenClaw | Cloud model routing, 35+ Android device skills, agent discovery |
| **Local LLM** | fllama NDK (llama.cpp ARM64) | On-device text + vision inference, multi-turn tool-use, no network |

On top of these sits a multi-chain Web3 layer (ETH/Base/SOL via native Dart + MoonPay MCP) and an immersive Airi-style VRM companion powered by Three.js.

---

## Architecture References

Before contributing, read the relevant doc:

| Doc | Covers |
|-----|--------|
| `ARCHITECTURE_LOCAL_LLM.md` | fllama NDK inference: API, model catalog, performance, GPU roadmap, every dead end we hit |
| `ARCHITECTURE_REPORT.md` | Core gateway, PRoot, WebSocket protocol, skill dispatch |
| `AVATAR_ARCHITECTURE.md` | Three.js VRM renderer, procedural animation math, lip-sync bridge |

When adding a new system, create an `ARCHITECTURE_<SYSTEM>.md` and link it here.

---

## Technical Standards

### 1. Flutter / Dart
- **Architecture:** Multi-isolate. UI stays in the main isolate. Background overlay and Node.js gateway live in their own sandboxes. Never block the main thread.
- **State management:** `Provider` for all reactive UI. No `setState` in top-level widgets.
- **Analysis:** `flutter analyze` must pass with zero warnings before every commit.
- **Naming:** Follow existing `service / screen / provider` file naming conventions exactly.

### 2. Local LLM / fllama NDK
- All inference calls go through `LocalLlmService` — never call fllama APIs directly from UI code.
- Use `fllamaInference(_buildInferenceRequest(...))` not `fllamaChat()`. The latter hard-codes `numThreads=2` and ignores the user's thread setting.
- Vision prompts must use the HTML `<img src="data:image/jpeg;base64,...">` format — bare data URIs are silently ignored by fllama's C++ parser.
- Tool dispatch goes through `_dispatchLocalTool()` in `LocalLlmService`. New local tools are registered in `_localTools` (static list) and dispatched in the switch statement.
- `_isInferring` and `_activeRequestId` are the cancel/overlap guards — respect them in any new inference path.
- Do not modify fllama source in the pub cache for production changes. Fork fllama and point `pubspec.yaml` to your fork instead.

### 3. VRM + Three.js
- All procedural math must be `delta`-time-independent to maintain 60 fps on mid-range hardware.
- Wind/physics functions must be continuous (sum-of-sines) to prevent SpringBone jitter.
- New gesture clips go in `assets/vrm/gestures/` as `.vrma` files.
- Camera framing changes must preserve PIP behaviour (do not break `isPip` branch in `updateCameraFraming`).

### 4. Agent Skills
- Every new skill needs: a `_create*Skill()` creator in `skills_service.dart`, an `_execute*Skill()` executor routing via `GatewaySkillProxy`, and a detail page in `lib/screens/management/skills/`.
- Skills must declare a complete `parametersSchema` so Claude can call them correctly via Tool Use.
- Provide graceful offline fallbacks when the gateway is not connected.
- Add a `tooltip` string to the `_SkillEntry` in `skills_manager.dart` so users know what the agent can do.

### 5. Android Native / Background Services
- All PRoot and gateway process management stays in `GatewayService` and `GatewayConnection`.
- Battery optimisation exemption and WorkManager heartbeats are mandatory for any new background worker.
- Keep `NODE_OPTIONS=--max-old-space-size=256` (or lower) on all Node.js child processes to prevent OOM on low-RAM devices.
- NDK version is pinned at `28.2.13676358` in `android/app/build.gradle.kts` — do not change it without testing fllama's native build.

### 6. Web3
- All on-chain calls must be non-blocking with full RPC error handling.
- MoonPay MCP commands must ask for user confirmation before any swap / buy / bridge.
- AgentCard and MoltLaunch operate on **Base (EVM / ETH)**. Solana DeFi uses Jupiter Ultra API.

---

## Contribution Workflow

```bash
# 1. Fork + branch from main
git checkout -b feature/your-feature-name

# 2. Implement, then verify
flutter analyze           # zero warnings required
flutter build apk --debug # must compile clean

# 3. Commit with conventional commit message
git commit -m "feat(local-llm): add X tool to _localTools dispatch"

# 4. Open a PR describing:
#    - Which compute plane is affected (Gateway / Local LLM / UI)
#    - What changed and why (link to architecture doc section if relevant)
#    - Screenshot or screen recording for any UI change
#    - Performance delta for any inference-path change (tok/s before/after)
```

---

## Design Language — "2026 Glassmorphic Dark"

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

## Local LLM — How to Contribute

`ARCHITECTURE_LOCAL_LLM.md` is the definitive engineering reference. It documents every dead end, exact error message, and root cause from months of iteration. **Read it before touching the inference stack.**

Current active work:

| Phase | Status | What's needed |
|-------|--------|--------------|
| **Phase 1 — fllama NDK** | ✅ Complete | Text, vision, tool-use all working |
| **Phase 2 — GPU/Vulkan** | 🔧 In progress | `GGML_VULKAN=ON` in fllama NDK build; requires LLVM + Vulkan SDK on build machine |
| **Phase 3 — Tokenizer trimming** | Queued | Replace chars-per-token approximation with `fllamaTokenize()` |
| **Phase 4 — Context optimization** | Queued | KV cache sharing, hot-swap without reload |

If you're contributing to Phase 2 (GPU), you'll need:
```bash
winget install LLVM.LLVM          # provides clang++ for vulkan-shaders-gen host build
# + LunarG Vulkan SDK from https://vulkan.lunarg.com (provides vulkan.hpp + FindVulkan CMake)
```

---

## License

By contributing to Plawie, you agree that your contributions will be licensed under the **MIT License** (see `LICENSE`).

---

<div align="center">

**Plawie — Your AI Agent, Your Rules, Your Reality**

*Thank you for helping push the boundary of what runs in your pocket.*

</div>

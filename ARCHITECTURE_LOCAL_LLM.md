# ARCHITECTURE: Local LLM Integration Strategy for Plawie

**Document type:** Research & Architecture Proposal  
**Author:** Antigravity (Google DeepMind Advanced Agentic Coding)  
**Date:** March 2026  
**Repo:** https://github.com/vmbbz/plawie  
**Status:** Draft — open for peer review and community audit

---

## Abstract

Plawie currently routes all LLM inference through cloud APIs (Claude, Gemini, GPT-4o) via the
OpenClaw Node.js gateway running inside a PRoot/Ubuntu sandbox on Android. This document
investigates the feasibility of running a **free, offline, on-device local LLM server** inside that
same PRoot environment, intercepting OpenClaw's default LLM provider and replacing it with a
localhost inference endpoint — no internet required, no API cost, total privacy.

The goal is not to replace cloud APIs permanently, but to offer local LLM as a free-tier fallback
that is reliable, lightweight, downloaded post-install (not bundled in the APK), and stable enough
for production use on mid-range Android hardware.

---

## 1. How OpenClaw Selects Its LLM Provider

OpenClaw reads model configuration from `~/.openclaw/openclaw.json`. The relevant section:

```json
{
  "models": {
    "providers": {
      "mode": "merge",
      "providers": [
        {
          "id": "local-llm",
          "baseUrl": "http://127.0.0.1:8081/v1",
          "api": "openai-completions",
          "apiKey": "local",
          "models": [
            {
              "id": "qwen2.5-1.5b-instruct",
              "name": "Qwen 2.5 1.5B (Local)",
              "contextWindow": 32768,
              "maxTokens": 4096,
              "cost": { "input": 0, "output": 0 }
            }
          ]
        }
      ]
    }
  }
}
```

Key facts confirmed from openclaw.ai documentation:
- `baseUrl` **must end with `/v1`**
- `api` value for OpenAI-compatible servers: `"openai-completions"`
- Any OpenAI-compatible HTTP server listening on 127.0.0.1 works out of the box
- `mode: "merge"` preserves cloud providers alongside the local one
- Cost can be set to `0` for local models

This means any inference server that serves the `/v1/chat/completions` endpoint can be swapped
in **with zero changes to OpenClaw's core code** — only `openclaw.json` needs a new provider block.

---

## 2. The PRoot Environment Constraint

Plawie's stack:

```
Android OS
└── Flutter (Dart) — main app process
    └── PRoot/Ubuntu layer (no root required)
        └── Node.js 20+ — OpenClaw gateway + skills server
            └── [PROPOSED] llama-server — listening on 127.0.0.1:8081
```

The PRoot container is a real Linux userland (Ubuntu 22.04 LTS via proot-distro). It shares the
Android kernel but provides a full glibc environment. This matters because:

- Ollama ships a statically-linked Go binary that includes llama.cpp — **it works inside PRoot**
  but its GPU acceleration layer (which uses CUDA/ROCm) does not apply on Android. CPU-only.
- `llama-server` (from `llama.cpp`) compiles natively inside Termux/PRoot against Android's
  ARM64 architecture using clang. It is the most direct and reliable path.
- MLC-LLM requires a compiled Android native library and is better suited as a standalone APK
  approach, not embedded in PRoot.
- `llamafile` (Mozilla / Justine Tunney) is a single self-contained binary using APE format —
  it does not execute on Android without Termux by design, but works inside PRoot.

**Verdict: `llama-server` from `llama.cpp` is the optimal choice for the PRoot environment.**

---

## 3. Competing Apps That Shipped Local LLM on Android (2024–2025)

The following production implementations were identified during research:

| App / Project | Inference Engine | Notes |
|---------------|-----------------|-------|
| **MLC Chat** (mlc-ai/mlc-llm) | MLC-LLM (TVM backend) | APK + model download, NPU-aware on some devices. Supports Qwen2.5, Phi-3.5, Llama 3.2. https://github.com/mlc-ai/mlc-llm |
| **SmolChat** | llama.cpp via JNI | Open-source Android app, GGUF models downloaded in-app. Simple ChatGPT-style UI. https://github.com/shubham0204/SmolChat-Android |
| **LLM Hub** | llama.cpp + LiteRT + ONNX | Multi-backend Android app. https://github.com/timmyy123/LLM-Hub |
| **ToolNeuron** | llama.cpp (GGUF) | Offline AI with vision + image gen on Android. https://github.com/Siddhesh2377/ToolNeuron |
| **Google AI Edge Gallery** | LiteRT (Gemma 3n) | Experimental; Google's official on-device LLM showcase |
| **Ollama on Termux** | llama.cpp (via Ollama) | `pkg install ollama` in Termux — CPU only, no GPU. Works without root |
| **node-llama-cpp** | llama.cpp via Node.js bindings | Native Node.js binding for llama.cpp — directly compatible with our Node.js gateway inside PRoot. https://github.com/withcatai/node-llama-cpp |

**The most architecturally aligned option for Plawie is `node-llama-cpp`** — it runs directly inside
our existing Node.js gateway process as a module, eliminating the need for a separate process and
IPC overhead. The tradeoff is that native `.node` bindings must be compiled for Android ARM64 inside
our PRoot layer.

An alternative is to run `llama-server` as a separate child process (like we do with the OpenClaw
gateway itself) and point OpenClaw's provider config at `http://127.0.0.1:8081/v1`.

---

## 4. Recommended Local Inference Architecture

### Option A — Separate llama-server process (Recommended for stability)

```
GatewayService (Flutter)
├── spawns: openclaw gateway (Node.js) on :3000
└── spawns: llama-server (ARM64 binary) on :8081
    └── serves: GET /v1/models, POST /v1/chat/completions

openclaw.json → models.providers → baseUrl: "http://127.0.0.1:8081/v1"
```

**Pros:** Fully isolated. If the model crashes, OpenClaw keeps running. Clean separation.  
**Cons:** Two child processes. Memory footprint is higher. Startup latency ~3s for model load.

**How to install in PRoot (user runs once via OpenClaw terminal):**
```bash
# Inside PRoot Ubuntu via Plawie's built-in terminal
apt-get update && apt-get install -y cmake make g++ git
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --target llama-server -j4
# Binary: llama.cpp/build/bin/llama-server
```

**To launch (added to gateway startup in GatewayService.dart):**
```bash
./llama-server \
  --model ~/.openclaw/models/qwen2.5-1.5b-instruct-q4_k_m.gguf \
  --host 127.0.0.1 \
  --port 8081 \
  --n-gpu-layers 0 \
  --threads 4 \
  --ctx-size 4096 \
  --memory-f32 false
```

---

### Option B — node-llama-cpp inside OpenClaw gateway (Tighter integration)

OpenClaw's Node.js process loads `node-llama-cpp` directly. A small MCP skill or local HTTP
adapter proxies `/v1/chat/completions` to `node-llama-cpp`.

```javascript
// Inside openclaw gateway: local_llm_provider.js
import { getLlama, LlamaChatSession } from 'node-llama-cpp';
const llama = await getLlama();
const model = await llama.loadModel({ modelPath: '~/.openclaw/models/qwen2.5-1.5b-q4.gguf' });
```

**Pros:** One process. Deeper integration. Can expose as tool-use skill.  
**Cons:** Requires compiling `node-llama-cpp` native bindings for Android ARM64 inside PRoot.
This is non-trivial and may be fragile across Node.js versions.

---

## 5. Model Recommendations

All models must be in **GGUF format**. Download from Hugging Face — never bundled in the APK.

| Model | Size (Q4_K_M) | RAM Required | Tool Use | Recommended For |
|-------|---------------|--------------|----------|-----------------|
| `Qwen2.5-0.5B-Instruct` | ~350 MB | 1.5 GB | Limited | Minimum viable, very fast |
| **`Qwen2.5-1.5B-Instruct`** | ~1.0 GB | 3 GB | Good | **Recommended default** |
| `Phi-3-Mini-4k-Instruct` | ~2.2 GB | 4 GB | Good | Strong reasoning, slightly larger |
| `Qwen2.5-3B-Instruct` | ~1.9 GB | 4.5 GB | Excellent | Best quality on 8GB+ devices |
| `SmolLM2-1.7B-Instruct` | ~1.1 GB | 3 GB | Moderate | Speed-focused, HuggingFace-trained |

**Quantization recommendation:** `Q4_K_M` strikes the best quality/RAM balance on ARM64 CPU.
`Q6_K` gives noticeably better quality at ~30% larger file size — viable on 12GB+ devices.
Avoid `Q2_K` — quality degrades too much for coherent tool-use / function-calling.

**Tool-use / function-calling:** Qwen2.5-Instruct models have native tool-use format support
recognized by `llama-server`. The OpenClaw gateway can construct tool-call requests using the
standard OpenAI tool schema. Phi-3-Mini uses a different prompt format for tool calls and may
require a wrapper.

---

## 6. Model Download Strategy (Post-Install, Not in APK)

Following the same pattern Plawie already uses for Piper TTS voice models:

1. Add a "Local LLM" section to the Agent Settings page in the Flutter UI
2. Show a list of curated models (name, file size, RAM required, quality rating)
3. User taps "Download" — model downloads direct from Hugging Face CDN to
   `~/.openclaw/models/` inside the PRoot filesystem
4. After download, GatewayService restarts llama-server pointing to the new model file
5. openclaw.json is updated automatically with the local provider block

Model files live inside the PRoot layer, not in Flutter's app data directory, so they survive APK
updates and are accessible directly to llama-server and node-llama-cpp.

---

## 7. Recommended Device Specifications

Running a local 1.5B–3B parameter model requires significant sustained device resources. The user
should be clearly informed before attempting installation.

### Minimum (1.5B model, basic functionality)
- **SoC:** Snapdragon 7 Gen 1 / Dimensity 9000 or equivalent (2022+)
- **RAM:** 8 GB total (model needs ~3 GB; OS + Plawie + Node.js consume ~4 GB)
- **Storage:** 4 GB free (1 GB model + llama-server binary + scratch space)
- **Expected speed:** 4–8 tokens/second (CPU-only, no GPU offload)

### Recommended (1.5B–3B model, good performance)
- **SoC:** Snapdragon 8 Gen 1 / 8 Gen 2 or equivalent
- **RAM:** 12 GB total
- **Storage:** 8 GB free (room for multiple models)
- **Expected speed:** 10–20 tokens/second

### Optimal (3B–7B model, near-desktop performance)
- **SoC:** Snapdragon 8 Gen 3 / 8 Elite
- **RAM:** 16 GB total
- **Storage:** 16 GB free
- **Expected speed:** 15–30 tokens/second (potential Adreno GPU acceleration in future builds)

**Note on GPU offload:** As of early 2026, Qualcomm Adreno GPU acceleration via OpenCL in
`llama.cpp` is still experimental within PRoot (OpenCL ICD loader is not exposed cleanly through
the PRoot layer). GPU offload (`--n-gpu-layers N`) may work on some devices if the Adreno OpenCL
runtime is accessible. This is an area of active community investigation.

---

## 8. Risks and Open Questions

| Risk | Severity | Notes |
|------|----------|-------|
| PRoot kernel call overhead | Medium | PRoot adds ~5–15% CPU overhead vs native. Acceptable for inference. |
| ARM64 compilation inside PRoot | Medium | Requires build tools (~500 MB). One-time setup. |
| OpenClaw tool-use compatibility | Medium | llama-server tool_calls format needs validation against OpenClaw's parsing. |
| Model staleness | Low | GGUF format is stable. Models downloaded from HF are versioned. |
| Thermal throttling | High | Sustained inference at 100% CPU will thermal-throttle on many phones. Need to benchmark real-world sustained token throughput, not burst. |
| Background process survival | Medium | llama-server must be registered as a child of the gateway foreground service. Same WorkManager heartbeat applies. |

---

## 9. Phased Implementation Plan

**Phase 1 — Spike (1 week)**
- Manually install llama-server inside Plawie's PRoot layer on a test device
- Validate that `llama-server --port 8081` starts correctly and serves `/v1/chat/completions`
- Add a one-line provider block to `openclaw.json` and confirm OpenClaw routes to local model
- Measure token throughput on Snapdragon 8 Gen 1 and 8 Gen 3

**Phase 2 — Integration (2 weeks)**
- Add llama-server binary download to Plawie's onboarding flow (packaged as a pre-compiled
  ARM64 release binary from the llama.cpp GitHub Releases page)
- Add model download UI in Agent Settings (same component as TTS model chooser)
- Add local provider block auto-generation in `openclaw.json` after model download
- Register llama-server as a foreground service child process in `GatewayService.dart`

**Phase 3 — Polish (1 week)**
- Add local LLM status indicator in the dashboard (port health check)
- Add fallback logic: if local model fails to respond within 10s, route to cloud provider
- Add minimum device spec check before allowing download (RAM check via Flutter `device_info_plus`)
- Write user-facing setup guide in the Help screen

---

## 10. Alternative Approach: Separate Companion APK

If bundling llama-server inside the PRoot gateway proves too fragile, an alternative is to publish
a separate **"Plawie Local Brain"** APK that:
- Ships as a standalone Android service
- Uses MLC-LLM or llama.cpp JNI to run models natively with potential NPU access
- Exposes an HTTP server on `127.0.0.1:8081` that Plawie's OpenClaw gateway connects to

This is how apps like MLC Chat operate. The main Plawie app would check if "Plawie Local Brain"
is installed and configured before adding the local provider to `openclaw.json`. This is cleaner
architecturally but requires distributing two APKs.

**Recommendation:** Attempt Option A (PRoot llama-server) first. Fall back to the companion APK
approach only if PRoot compilation/stability proves untenable after Phase 1 spike results.

---

## 11. Conclusion and Call for Peer Review

The research indicates that running a local LLM inside Plawie's PRoot environment is **technically
feasible** using `llama-server` from `llama.cpp`, which can be compiled natively for ARM64 inside
the existing Ubuntu PRoot layer. The OpenClaw provider system supports localhost OpenAI-compatible
endpoints natively via `openclaw.json` with zero code changes to the gateway core.

The primary unknowns are: (1) sustained thermal performance on real devices under inference load,
(2) Adreno GPU offload availability through PRoot, and (3) OpenClaw's tool-use parsing
compatibility with `llama-server`'s function-calling schema. These should be resolved in Phase 1.

**Recommended starting model:** `Qwen2.5-1.5B-Instruct` at `Q4_K_M` quantization (~1 GB download).
**Recommended server:** `llama-server` from `llama.cpp` (https://github.com/ggerganov/llama.cpp).
**Minimum device:** 8 GB RAM, Snapdragon 8 Gen 1 or equivalent.

---

## Community Review Section

*If you have hands-on experience running local LLM inference on Android (with or without root,
inside/outside PRoot, with Termux, MLC-LLM, or custom setups), please add your findings below
using the same format. Include your device specs, model tested, token throughput, and any
stability notes. This document is a living reference and will be updated as new data comes in.*

---

### Review 1 — [Your Name / Handle]

**Date:**  
**Device:** [SoC, RAM, Android version]  
**Method:** [llama-server / Ollama / MLC-LLM / node-llama-cpp / other]  
**Model tested:** [name + quantization]  
**Token throughput:** [tokens/second]  
**Tool-use worked?:** [yes / no / partial — explain]  
**Stability notes:**  
**Findings:**  

---

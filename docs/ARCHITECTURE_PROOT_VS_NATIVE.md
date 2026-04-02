# Architecture: Local Inference + PRoot Gateway

**Document type:** Architecture reference
**Last updated:** 2026-04-02
**Status:** Reflects current production state.

---

## 1. Current Architecture

OpenClaw on Android is a **self-contained AI gateway** — no Termux, no root, no external app required. The APK bundles a complete Ubuntu ARM64 userland in app storage. Local inference runs on **two parallel paths** that share the same GGUF files.

```
Android App (Flutter)
  │
  ├─ Flutter UI (chat, local LLM screen, hub management, avatar, skills)
  │
  ├─ GatewayService (Dart)
  │     ├─ WebSocket client → port 18789 (chat.send, skills, agents)
  │     └─ HTTP client → port 18789 (/v1/models, /health)
  │
  ├─ LocalLlmService (Dart) — fllama NDK path
  │     └─ fllamaInference() → llama.cpp NDK (.so) → reads GGUF directly
  │           No gateway, no HTTP, no PRoot involved
  │
  ├─ NativeBridge (Dart → Kotlin → JNI)
  │     ├─ startGateway() → spawns PRoot process
  │     ├─ startOllama() / stopOllama() → Ollama server inside PRoot
  │     ├─ runInProot(cmd) → executes shell inside Ubuntu
  │     └─ isGatewayRunning() → checks PID
  │
  └─ PRoot Ubuntu ARM64 userland (in app files dir)
        ├─ /usr/local/bin/node        ← Node.js 22 ARM64
        ├─ /usr/local/bin/openclaw    ← OpenClaw gateway (npm global)
        ├─ /usr/local/bin/ollama      ← Ollama v0.19.0 ARM64
        ├─ /root/.openclaw/
        │     ├─ openclaw.json        ← gateway config (models, providers)
        │     ├─ agents/main/agent/
        │     │     └─ auth-profiles.json  ← provider auth + disabledUntil
        │     └─ models/              ← GGUF model files (shared with fllama NDK)
        ├─ port 18789 (127.0.0.1)     ← OpenClaw HTTP + WS
        └─ port 11434 (127.0.0.1)     ← Ollama HTTP (OpenAI-compatible)
```

---

## 2. Full Inference Routing Matrix

```
sendMessage() in gateway_service.dart
  │
  ├─ model.startsWith('local-llm/')
  │     └── LocalLlmService.chat()
  │           └── fllamaInference() NDK [llama.cpp C++]
  │                 reads GGUF directly from Android filesystem
  │                 ~50–200ms first token, bypasses gateway entirely
  │
  ├─ model.startsWith('ollama/')
  │     └── WebSocket :18789 → OpenClaw gateway
  │           → Ollama provider → http://127.0.0.1:11434
  │                 Full OpenClaw features: chat, tool calls, skills, agents
  │                 ~2–8s first token (PRoot + Ollama startup; warm: <1s)
  │
  └─ cloud model (google/*, anthropic/*, openai/*, groq/*)
        └── WebSocket :18789 → OpenClaw gateway
              → cloud provider API via gateway
```

| Model prefix | Path | First token | Capabilities |
|---|---|---|---|
| `local-llm/*` | fllama NDK | 50–200ms | Chat, vision (mmproj), tool calls |
| `ollama/*` | Ollama Hub via gateway | 2–8s (warm <1s) | Chat, tool calls, skills, agents, vision |
| `google/*` `anthropic/*` etc. | Cloud via gateway | Network latency | Full |

**Both local paths read the same GGUF file. No duplicate downloads.**

---

## 3. Going Fully Local

To route all chat through Ollama Hub instead of cloud providers:

1. Start the gateway, then start the Ollama Hub and wait for sync to complete.
2. In the chat model dropdown, select any `ollama/<model>` entry — these appear automatically after sync.
3. The gateway routes all `chat.send` calls to `http://127.0.0.1:11434`.

For background agent tasks to also use local Ollama, `configureOllama(setAsPrimary: true, primaryModel: '<name>')` sets `agents.defaults.provider = 'ollama'` in `openclaw.json`. This is opt-in — the user's active cloud provider is not changed silently.

For pure interactive speed (latency-sensitive chat), keep `local-llm/*` selected — the fllama NDK path is 10–40× faster to first token than Ollama Hub.

---

## 4. Ollama Hub: How Model Sync Works

**Problem:** Ollama's HTTP `/api/create` `from` field is interpreted relative to the Ollama server's file I/O syscalls. When Ollama runs inside PRoot, PRoot intercepts those syscalls — but the path string sent as JSON over the loopback socket is **not** PRoot-translated. Ollama receives the raw Android path and fails with "invalid model name" (GitHub Issue #9580 — misleading error masking a path resolution failure).

**Fix:** `_createOllamaModelFromGguf()` runs `ollama create` CLI directly inside PRoot via `NativeBridge.runInProot()`. That process inherits PRoot's ptrace context, so `/root/.openclaw/models/...` resolves correctly to the Android filesystem.

```
syncLocalModelsWithOllama()
  1. GET /api/tags → collect already-registered names (skip re-hashing)
  2. For each downloaded GGUF not yet registered:
       NativeBridge.runInProot(
         'OLLAMA_HOST=127.0.0.1:11434 ollama create "$name" -f /dev/stdin <<EOF\nFROM $path\nEOF'
       )
  3. configureOllama(syncedModels: [...]) → writes model list to openclaw.json
  4. emit GatewayState.ollamaHubModels → chat_screen.dart merges into dropdown
```

Hub Logs after a successful sync:
```
[INFO] Ollama version: 0.19.0
[INFO] Scanning for local GGUF models...
[HUB] Registering qwen2-5-0-5b-instruct-q4-k-m:latest...
[HUB] qwen2-5-0-5b-instruct-q4-k-m:latest — success
[INFO] Hub Sync Done. 2 models available.
[INFO] Ollama provider configured at http://127.0.0.1:11434
```

Second startup (skip-if-registered):
```
[INFO] qwen2.5-0.5b-instruct-q4_k_m already in Hub — skipping.
[INFO] Hub Sync Done. 2 models available.
```

---

## 5. Gateway Cold Boot Sequence

```
user taps Start
  ├─ _configureGateway()      write openclaw.json
  ├─ NativeBridge.startGateway()   spawn PRoot → Node.js → openclaw (~5-10s)
  ├─ _startHealthCheck() + immediate _checkHealth()
  │     poll HTTP HEAD :18789 every 15s
  └─ gateway HTTP responds (2–4 min total)
        ├─ retrieveTokenFromConfig()
        ├─ WebSocket connect → handshake → mainSessionKey
        └─ RPC discovery (health, skills, capabilities) — ONCE, 8s each
```

**Local LLM (fllama NDK) activation** (additional, after gateway running):
```
user taps Start on model card
  ├─ _patchOpenClawConfig(modelId)    write local-llm provider block
  ├─ _clearLocalLlmCooldown()         clear disabledUntil from auth-profiles.json
  ├─ GatewayService.disconnectWebSocket() + invalidateTokenCache()
  ├─ openclaw restart                 full Node.js restart (flushes in-memory state)
  │     node-llama-cpp initializes → loads GGUF into RAM (60–90s)
  └─ isServerHealthy() → passes → disconnectWebSocket() again → fresh WS session
```

**Ollama Hub activation** (parallel to gateway, independent):
```
user taps Start Hub
  ├─ NativeBridge.startOllama()   spawn Ollama inside PRoot (OLLAMA_HOST=127.0.0.1:11434)
  ├─ checkOllamaHealth() poll until :11434 responds
  └─ syncLocalModelsWithOllama()  register downloaded GGUFs via CLI
        → emits GatewayState.ollamaHubModels → chat dropdown updated
```

---

## 6. Known PRoot Limitations

### 6a. disabledUntil Cooldown Bug (OpenClaw Issue #13336)

OpenClaw's provider backoff misclassifies the 60–90s GGUF load time as a timeout/rate-limit. After 3 failures: backoff → 1h lockout.

**Fix:** `_clearLocalLlmCooldown()` removes `usageStats` / `disabledUntil` from `auth-profiles.json` before every restart. Requires `openclaw restart` (full process), not `reload` (keeps in-memory state).

### 6b. Stale WS Session After Restart

`openclaw restart` invalidates the previous session's `mainSessionKey`. Sending on the old session causes silent misrouting.

**Fix:** Double `disconnectWebSocket()` + `invalidateTokenCache()` — before restart and after health check passes.

### 6c. Battery Optimization Killing PRoot

Android kills background processes. PRoot runs as a background service. Aggressive power management (Xiaomi/Oppo/Vivo) kills it within 5–10 min of screen off.

**Mitigation:** `NativeBridge.requestBatteryOptimization()` — non-blocking dialog asking user to exempt the app. Gateway watchdog auto-restarts if `autoStartGateway` is enabled.

### 6d. Node.js Memory Pressure

V8 heap capped at 256MB (`--max-old-space-size=256`). node-llama-cpp tensor allocations happen outside V8 (native C++). A 1.5B Q4 model uses ~1.5GB RAM. Tight on 6GB devices.

### 6e. Cold Boot 2–4 Minutes

PRoot spawn + Node.js require chain + OpenClaw init + GGUF load = serial blocking ops.

**Mitigations:**
- `_rpcDiscoveryDone` flag: RPC calls (8s each × 3) run only once on first WS connect
- Immediate `unawaited(_checkHealth())` eliminates the first 15s polling wait
- Battery dialog made non-blocking

---

## 7. Comparison: Our Approach vs Alternatives

| | OpenClaw (PRoot) | AidanPark (Termux) | AnyClaw (trimmed userland) |
|---|---|---|---|
| Self-contained APK | ✅ Yes | ❌ Requires Termux | ✅ Yes |
| Setup download | ~700MB rootfs + Node | <100MB (glibc + npm) | ~50MB bundled |
| Gateway boot time | 2–4 min | 30–60s | 30–60s |
| PRoot syscall overhead | Yes (I/O ops) | None (native) | None (native) |
| Inference tok/s | Same (CPU-bound) | Same | Same |
| Android kill risk | High (background svc) | Medium | Low |
| Ollama Hub support | ✅ Full | Not implemented | Not implemented |
| fllama NDK path | ✅ Implemented | N/A | N/A |

**AidanPark's approach** (github.com/AidanPark/openclaw-android): Termux + glibc shim + prebuilt node-llama-cpp `.so` binaries. 3–4× faster gateway boot from eliminating PRoot's `require()` overhead. Not self-contained — requires Termux pre-installed.

**AnyClaw** (github.com/friuns2/openclaw-android-assistant): Closest to our architecture. Bundles a minimal trimmed Termux-derived userland (~5MB APK). Node.js 24, npm, SSL certs bundled. No PRoot.

---

## 8. Performance Estimates

| Metric | fllama NDK | Ollama Hub (PRoot) | Cloud |
|---|---|---|---|
| First token | 50–200ms | 2–8s (warm <1s) | Network dependent |
| Throughput (1.5B Q4) | 10–18 tok/s | 8–15 tok/s (+HTTP overhead) | N/A |
| Model load | 30–60s | Already loaded (Ollama daemon) | N/A |
| RAM with 1.5B model | ~1.5GB | ~1.5GB + 80MB Ollama daemon | ~80MB (no model) |
| Battery | Efficient | Higher (extra process) | Efficient |
| OpenAI API compat | No | Yes (via gateway) | Yes |
| Tool calls | Manual parsing | Gateway-native | Gateway-native |
| Skills / agents | No | Yes (full gateway) | Yes |

> PRoot adds <5% overhead to inference tok/s — CPU compute is not intercepted by ptrace. The overhead is in file I/O during startup, not during inference.

---

## 9. Files in the Local Inference Path

| File | Role |
|---|---|
| `lib/services/local_llm_service.dart` | Model catalog, GGUF path management, fllama NDK chat/vision |
| `lib/services/gateway_service.dart` | WS routing, `sendMessage()`, `syncLocalModelsWithOllama()`, `configureOllama()` |
| `lib/services/bootstrap_service.dart` | One-time setup: Ubuntu rootfs, Node.js, OpenClaw npm install |
| `lib/services/native_bridge.dart` | `startGateway()`, `startOllama()`, `runInProot()`, `isOllamaRunning()` |
| `lib/models/gateway_state.dart` | State model; `ollamaHubModels` surfaces synced Hub models to the UI |
| `lib/screens/chat_screen.dart` | Model picker dropdown; merges `ollama/*` entries after Hub sync |
| `lib/screens/management/local_llm_screen.dart` | Model download UI, Hub start/stop, Hub Logs |

---

## 10. Config Files Written at Runtime (Inside PRoot rootfs)

| Host path | PRoot path | Written by | Purpose |
|---|---|---|---|
| `$filesDir/rootfs/root/.openclaw/openclaw.json` | `/root/.openclaw/openclaw.json` | `_configureGateway()`, `configureOllama()`, `_patchOpenClawConfig()` | Gateway config, model providers, HTTP endpoints |
| `$filesDir/rootfs/root/.openclaw/agents/main/agent/auth-profiles.json` | `/root/.openclaw/agents/main/agent/auth-profiles.json` | OpenClaw (auto), `_clearLocalLlmCooldown()` | Provider auth tokens, disabledUntil state |
| `$filesDir/rootfs/etc/resolv.conf` | `/etc/resolv.conf` | `NativeBridge.writeResolv()` | DNS resolution inside PRoot |

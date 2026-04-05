# Architecture: Local Inference + PRoot Gateway

**Document type:** Architecture reference + deliberation log
**Last updated:** 2026-04-04
**Status:** Reflects current production state + settled design decisions.

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
  ├─ model.startsWith('ollama/')   ← WS routing (same as cloud)
  │     └── WebSocket :18789 → OpenClaw gateway
  │           → providers.ollama → http://127.0.0.1:11434
  │                 Full OpenClaw features: chat, tool calls, skills, agents
  │                 ~2–8s first token (PRoot + Ollama startup; warm: <1s)
  │     WS unavailable fallback:
  │           → sendMessageHttp() → direct :11434 (inference works, no dashboard)
  │
  └─ cloud model (google/*, anthropic/*, openai/*, groq/*)
        └── WebSocket :18789 → OpenClaw gateway
              → cloud provider API via gateway
```

| Model prefix | Path | First token | Capabilities |
|---|---|---|---|
| `local-llm/*` | fllama NDK | 50–200ms | Chat, vision (mmproj), tool calls |
| `ollama/*` | Ollama Hub via gateway WS | 2–8s (warm <1s) | Chat, tool calls, skills, agents, vision |
| `google/*` `anthropic/*` etc. | Cloud via gateway WS | Network latency | Full |

**Both local paths read the same GGUF file. No duplicate downloads.**

---

## 3. Ollama Routing: WS vs Direct HTTP — The Deliberation

### The question
"Why can't Ollama use the same WebSocket `chat.send` routing as cloud models?"

### Initial incorrect approach
An early session added an `ollama/` prefix check in `sendMessage()` that short-circuited to `sendMessageHttp()` with `directUrl: 'http://127.0.0.1:11434/v1/chat/completions'`. This bypassed the gateway entirely.

**Result:** Ollama worked (inference ran) but:
- Was invisible in the web dashboard — no session, no agent loop
- Lost skills, tool routing, and agent features
- Was mistakenly thought to be "cloud working" when the user was actually testing Ollama

### The critical correction
At commit `0fc3129` (working baseline), there was **no `ollama/` prefix check**. All non-`local-llm` models went through WS `chat.send`. Ollama WAS going through the gateway and DID appear in the dashboard.

The gateway reads `agents.defaults.model.primary` from `openclaw.json`. When that value is `ollama/qwen2.5-1.5b-instruct:q4_k_m`, the gateway routes `chat.send` to `providers.ollama.baseUrl` (`:11434`). This is the same dispatch path as cloud — the provider is inferred from the model name prefix, not from a separate field.

### Settled decision
**Ollama uses WS `chat.send` — identical path to cloud.** Only differences:
- `timeoutMs: 180000` vs cloud's `90000` (mobile inference is slower)
- WS unavailable fallback: direct `:11434` (inference still works, just loses dashboard)

### Why the gateway injects a 26K system prompt
The gateway agent loop injects its full system prompt on every `chat.send`, regardless of provider. This is not controllable by the Flutter side. With Ollama's default context window (`n_ctx = 2048`), the 26K prompt instantly overflows. This is why `PARAMETER num_ctx 4096` is set in the Qwen2.5 Modelfile — 4096 tokens is a stable KV cache size for our device class while leaving room for the conversation.

Context budget breakdown (4096 total):
- Gateway system prompt: ~26K tokens... but wait — the gateway truncates its own system prompt before sending. The actual context injected is ~1500–2000 tokens. `n_ctx 4096` gives the model ~2000–2500 tokens for the actual conversation.

### n_ctx observation test
Hub Logs after starting Ollama should show:
- `[HUB] Context: 4096` → Modelfile PARAMETER respected ✓
- `[HUB] Context: 32768` → Gateway or Ollama overriding the Modelfile ✗ (crash risk on low-RAM devices)

---

## 4. Model Selection: How Config Is Written

### `persistModel(model)` — the one write for both cloud and Ollama
```dart
// gateway_service.dart ~line 965
config['agents']['defaults']['model']['primary'] = model;
await _writeConfig(config);
```
Both cloud and Ollama model selection call this identically from `chat_screen.dart`:
```dart
unawaited(GatewayService().persistModel(model));  // writes openclaw.json
GatewayService().disconnectWebSocket();            // force fresh WS on next send
```
The gateway re-reads `primary` from disk on each `chat.send`. No restart needed.

### `configureOllama()` — written once at sync time
Writes the full `providers.ollama` block (baseUrl, models array) to `openclaw.json`. Called only by `syncLocalModelsWithOllama()`, NOT on model selection. If the providers block already exists with all synced models listed, only `primary` needs to change — which `persistModel()` does correctly.

### Why `agents.defaults.provider` is explicitly removed
```dart
// gateway_service.dart ~line 402
agentsDefaults.remove('provider');
```
`agents.defaults.provider` is not a valid OpenClaw schema field. The gateway infers the provider from the model name prefix (`ollama/` → Ollama, `google/` → Gemini, etc.). Writing this field causes the gateway to misroute or error. This was discovered during debugging and is now explicitly guarded.

---

## 5. Going Fully Local

To route all chat through Ollama Hub instead of cloud providers:

1. Start the gateway, then start the Ollama Hub and wait for sync to complete.
2. In the chat model dropdown, select any `ollama/<model>` entry — these appear automatically after sync.
3. The gateway routes all `chat.send` calls to `http://127.0.0.1:11434`.

For background agent tasks to also use local Ollama, `configureOllama(setAsPrimary: true, primaryModel: '<name>')` sets the primary in `openclaw.json`. This is opt-in — the user's active cloud provider is not changed silently.

For pure interactive speed (latency-sensitive chat), keep `local-llm/*` selected — the fllama NDK path is 10–40× faster to first token than Ollama Hub.

---

## 6. Ollama Hub: How Model Sync Works

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

**Model selection fix:** When syncing, skip models where `!model.supportsToolCalls` — this prevents the 0.5B Q4 model being selected as the gateway default when the user has 1.5B selected. The `_isSyncing` guard prevents concurrent sync calls from race-conditioning the model list.

---

## 7. Gateway Cold Boot Sequence

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

## 8. Live Activity Panel (Agent Hub Widget)

The Hub's "LIVE ACTIVITY" panel shows real-time chat/hub events without polling log files.

### Architecture
```
GatewayService._addActivity(event)
  ├─ appends to _activityBuffer (List<String>, max 40, in-memory, permanent)
  └─ broadcasts to _chatActivityController (StreamController.broadcast())

local_llm_screen initState():
  ├─ seed: _activityLogs.addAll(GatewayService().recentActivity)   ← buffer replay
  └─ subscribe: GatewayService().chatActivityStream.listen(...)     ← live events
```

**Critical design:** `StreamController.broadcast()` does NOT replay past events to new subscribers. Without the buffer seed, the panel is always blank on open because events fired while the screen was closed are lost. The `_activityBuffer` in `GatewayService` is permanent (persists for app lifetime) and is read on every screen open.

### Event types
| Prefix | Source | Meaning |
|---|---|---|
| `[HUB] Model ready in Xs` | Ollama server log | Model loaded successfully |
| `[HUB] Context: N tokens` | Ollama server log | n_ctx value — check for 4096 vs 32768 |
| `[HUB] KV cache: X MiB` | Ollama server log | Memory allocated for KV |
| `[HUB] ✓/✗ HTTP 200/500 (Xs)` | GIN HTTP log | Ollama handled/rejected a request |
| `[HUB] ⚠ Inference aborted` | Ollama server log | Client disconnected mid-generation |
| `[CHAT] → Sending to model` | Flutter/gateway_service | Message dispatched |
| `[CHAT] ← Gateway accepted` | WS ACK | Gateway started streaming |
| `[CHAT] ✓ First token received` | WS stream | First delta chunk arrived |
| `[CHAT] ✓ Complete` | WS stream close | Generation finished normally |
| `[CHAT] ✗ ...` | Any error path | Error with detail |
| `[CHAT] ⚠ WS unavailable` | sendMessage() | Fell back to direct :11434 |

---

## 9. AidanPark Investigation: Critical Finding

**Claim investigated:** AidanPark's openclaw-android replaces Ollama with node-llama-cpp for inference, making the app lighter and faster.

**Finding: The premise is wrong.**

### What node-llama-cpp actually does in OpenClaw
node-llama-cpp is used **exclusively for memory-search embeddings** — a 300MB embedding model for semantic retrieval. It is never in the inference path for chat. Chat inference in OpenClaw always goes through `models.providers` — configured as Ollama, llama-server, OpenAI, etc.

Source: openclaw issue #57390, openclaw model-providers docs. The `chat.send` WS RPC routes to whatever `providers.ollama.baseUrl` (or `providers.llamacpp.baseUrl`) is configured. node-llama-cpp is not in that path.

### What AidanPark actually does differently
He runs Node.js itself via **glibc-runner** (a 200MB Termux shim) instead of our full PRoot/Debian chroot (1–2GB). The inference still hits an external Ollama or llama-server process.

```
Our stack:
  Android → Bionic → PRoot (ptrace) → Debian/Ubuntu rootfs (1-2 GB) → glibc → Node.js → OpenClaw
             ↑ all syscalls intercepted by PRoot kernel emulation

AidanPark's stack:
  Android → Bionic → glibc ld.so shim (200 MB) → Node.js linux-arm64 binary → OpenClaw
             ↑ no ptrace; uses userland exec to load glibc's linker directly
```

The shim loads `ld-linux-aarch64.so.1` via userland exec, bypassing Android's Bionic linker. Node.js linux-arm64 prebuilt binaries load against this glibc environment.

### node-llama-cpp prebuilt binaries
`@node-llama-cpp/linux-arm64` v3.18.1 (confirmed on jsDelivr CDN):
```
llama-addon.node    793 KB
libggml.so           43 KB
libggml-base.so     653 KB
libggml-cpu.so      881 KB
libllama.so        2.89 MB
```
These are prebuilt against glibc and load fine inside our existing PRoot Debian rootfs (Debian provides native glibc — no shim needed). The restriction `npm install --ignore-scripts` in AidanPark's setup is because openclaw's postinstall tries to compile node-llama-cpp from source using Termux's cmake (Bionic-linked) which explodes in a glibc environment. Inside our PRoot Debian, this conflict doesn't exist.

### Trade-off table

| Factor | Switch to glibc-runner | Keep PRoot + Ollama |
|---|---|---|
| Rootfs size | ~200 MB (glibc shim only) | 1–2 GB (Debian rootfs) |
| First-time setup | ~3–10 min | ~20–30 min |
| PRoot ptrace overhead | None | ~10–15% CPU tax on all syscalls |
| Inference speed (1.5B) | ~11–13 t/s | ~9–12 t/s (same minus overhead) |
| Dashboard visibility | Same — 26K system prompt still injected | Same |
| External dependency | **Requires Termux as prerequisite** | Self-contained APK |
| Ollama dropped? | No — still runs external Ollama | No — same |
| WS routing fixed? | No | No |
| node-llama-cpp for inference? | Not possible (embeddings only) | Not possible |
| Build complexity | Rewrite entire bootstrap layer (~170 lines Kotlin) | Already done |

### Files that change if we switch (for reference, not doing this now)

| File | Change |
|---|---|
| `android/.../BootstrapManager.kt` | Replace rootfs download with glibc-runner package (~200 MB .deb) |
| `android/.../ProcessManager.kt` | `buildGatewayCommand()` — replace PRoot wrapper with glibc ld.so exec |
| `android/.../MainActivity.kt` | `runInProot` handler → `runInGlibc` |
| `lib/services/native_bridge.dart` | Rename `runInProot()` → `runCommand()`, update channel handler |
| `lib/services/gateway_service.dart` | `runInProot` call sites (12+) → `runCommand` (name only) |

Everything above the "how does Node.js start" layer is **identical**. All Dart routing, WS, model config, Ollama API calls — unchanged.

### Settled decision: stay on PRoot for now
- We don't own Termux. Making it a prerequisite is a regression for users.
- The storage saving (~1 GB) is meaningful but not blocking.
- The ~15% CPU saving is real but not the bottleneck (inference is CPU-bound regardless).
- The adoption risk (rewriting bootstrap layer, new failure modes) is not justified by the gain.
- **If/when we revisit:** the migration is well-understood and bounded. Come back to this when storage complaints from users become a P1 issue.

---

## 10. Known PRoot Limitations

### 10a. disabledUntil Cooldown Bug (OpenClaw Issue #13336)

OpenClaw's provider backoff misclassifies the 60–90s GGUF load time as a timeout/rate-limit. After 3 failures: backoff → 1h lockout.

**Fix:** `_clearLocalLlmCooldown()` removes `usageStats` / `disabledUntil` from `auth-profiles.json` before every restart. Requires `openclaw restart` (full process), not `reload` (keeps in-memory state).

### 10b. Stale WS Session After Restart

`openclaw restart` invalidates the previous session's `mainSessionKey`. Sending on the old session causes silent misrouting.

**Fix:** Double `disconnectWebSocket()` + `invalidateTokenCache()` — before restart and after health check passes.

### 10c. Battery Optimization Killing PRoot

Android kills background processes. PRoot runs as a background service. Aggressive power management (Xiaomi/Oppo/Vivo) kills it within 5–10 min of screen off.

**Mitigation:** `NativeBridge.requestBatteryOptimization()` — non-blocking dialog asking user to exempt the app. Gateway watchdog auto-restarts if `autoStartGateway` is enabled.

### 10d. Node.js Memory Pressure

V8 heap capped at 256MB (`--max-old-space-size=256`). node-llama-cpp tensor allocations happen outside V8 (native C++). A 1.5B Q4 model uses ~1.5GB RAM. Tight on 6GB devices.

### 10e. Cold Boot 2–4 Minutes

PRoot spawn + Node.js require chain + OpenClaw init + GGUF load = serial blocking ops.

**Mitigations:**
- `_rpcDiscoveryDone` flag: RPC calls (8s each × 3) run only once on first WS connect
- Immediate `unawaited(_checkHealth())` eliminates the first 15s polling wait
- Battery dialog made non-blocking

### 10f. Ollama 90s Timeout → Chat Failure

Default 90s HTTP timeout on chat requests. Mobile inference on a thermal-throttled device can take >90s for long completions.

**Fix:** `timeoutMs: 180000` in the WS `chat.send` params for `isOllama` models; 180s in `sendMessageHttp()` direct fallback path.

### 10g. Model Eviction Between Messages

Ollama default: evict model from memory after 5 minutes of inactivity. Next message triggers a 3–4s reload.

**Fix:** `keep_alive: -1` in the `sendMessageHttp()` direct fallback path body. In the WS path, the gateway controls Ollama — consider setting `OLLAMA_KEEP_ALIVE=-1` in Ollama's environment vars at startup (future improvement).

---

## 11. Comparison: Our Approach vs Alternatives

| | OpenClaw (PRoot) | AidanPark (glibc-runner) | AnyClaw (trimmed userland) |
|---|---|---|---|
| Self-contained APK | ✅ Yes | ❌ Requires Termux | ✅ Yes |
| Setup download | ~700MB rootfs + Node | <200MB (glibc + npm) | ~50MB bundled |
| Gateway boot time | 2–4 min | 30–60s | 30–60s |
| PRoot syscall overhead | Yes (~15% I/O) | None (native) | None (native) |
| Inference tok/s | Same (CPU-bound) | ~5–10% faster | Same |
| Android kill risk | High (background svc) | Medium | Low |
| Ollama Hub support | ✅ Full | Partial | Not implemented |
| fllama NDK path | ✅ Implemented | N/A | N/A |
| Termux dependency | None | Required | None |

**AidanPark's approach** (github.com/AidanPark/openclaw-android): Termux + glibc shim + node-llama-cpp for **embeddings** (NOT inference). ~3–4× faster gateway boot. Not self-contained.

**AnyClaw** (github.com/friuns2/openclaw-android-assistant): Closest to our architecture. Bundles a minimal trimmed Termux-derived userland (~5MB APK). Node.js 24, npm, SSL certs bundled. No PRoot. Worth tracking as a future migration path.

---

## 12. Performance Estimates

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
| Dashboard visible | No | Yes (via WS) | Yes |

> PRoot adds <5% overhead to inference tok/s — CPU compute is not intercepted by ptrace. The overhead is in file I/O during startup, not during inference.

---

## 13. Files in the Local Inference Path

| File | Role |
|---|---|
| `lib/services/local_llm_service.dart` | Model catalog, GGUF path management, fllama NDK chat/vision |
| `lib/services/gateway_service.dart` | WS routing, `sendMessage()`, `syncLocalModelsWithOllama()`, `configureOllama()`, `_addActivity()` |
| `lib/services/bootstrap_service.dart` | One-time setup: Ubuntu rootfs, Node.js, OpenClaw npm install |
| `lib/services/native_bridge.dart` | `startGateway()`, `startOllama()`, `runInProot()`, `isOllamaRunning()` |
| `lib/models/gateway_state.dart` | State model; `ollamaHubModels` surfaces synced Hub models to the UI |
| `lib/screens/chat_screen.dart` | Model picker dropdown; merges `ollama/*` entries after Hub sync |
| `lib/screens/management/local_llm_screen.dart` | Model download UI, Hub start/stop, Hub Logs, Live Activity panel |

---

## 14. Config Files Written at Runtime (Inside PRoot rootfs)

| Host path | PRoot path | Written by | Purpose |
|---|---|---|---|
| `$filesDir/rootfs/root/.openclaw/openclaw.json` | `/root/.openclaw/openclaw.json` | `_configureGateway()`, `configureOllama()`, `_patchOpenClawConfig()`, `persistModel()` | Gateway config, model providers, HTTP endpoints |
| `$filesDir/rootfs/root/.openclaw/agents/main/agent/auth-profiles.json` | `/root/.openclaw/agents/main/agent/auth-profiles.json` | OpenClaw (auto), `_clearLocalLlmCooldown()` | Provider auth tokens, disabledUntil state |
| `$filesDir/rootfs/etc/resolv.conf` | `/etc/resolv.conf` | `NativeBridge.writeResolv()` | DNS resolution inside PRoot |

---

## 15. Future Improvements (Prioritized)

| Priority | Item | Rationale |
|---|---|---|
| P1 | `OLLAMA_KEEP_ALIVE=-1` env var at Ollama startup | Eliminates model reload between messages in WS path (currently only fixed in direct path) |
| P1 | n_ctx observation test at boot | Hub logs should confirm `[HUB] Context: 4096` not 32768 |
| P2 | AnyClaw-style trimmed userland | ~1 GB storage saving, 3–4× faster boot, no Termux dependency. Bounded migration (bootstrap layer only) |
| P2 | WS reconnect backoff with jitter | Currently hard-disconnects; aggressive reconnect on unstable networks wastes battery |
| P3 | Whisper STT via fllama NDK | Already on roadmap; shares GGUF path with inference |
| P3 | Context compaction for long chats | Currently no pruning; long conversations hit n_ctx ceiling |
| P5 | LAN discovery for remote Ollama | Route `ollama/*` to LAN IP when device is on WiFi |

# Local LLM Architecture — Definitive Reference

> **Last updated:** 2026-04-10
> **Scope:** Everything about on-device inference in the Plawie/OpenClaw Android app.
> Engineers touching local LLM code must read this before making changes.

---

## Overview — Two Inference Modes

The app ships two completely separate local inference paths. They are **mutually exclusive** and each has a distinct use-case:

| Mode | Prefix | Inference | Tools | Skills | Dashboard | Memory |
|------|--------|-----------|-------|--------|-----------|--------|
| NDK Direct (fllama) | `local-llm/` | NDK llama.cpp | No | No | No | ~500 MB |
| Local LLM Hub (Ollama) | `ollama/` | Ollama daemon | Yes | Yes | Yes | ~500–1200 MB |

---

## Mode 1 — NDK Direct (fllama)

### What it is

GGUF models run **entirely inside the Flutter app** via a compiled llama.cpp NDK library (`libfllama.so`). Zero network, zero PRoot. The inference call goes:

```
Flutter Dart
  └─ LocalLlmService.chat()
       └─ fllama.dart (FFI bindings)
            └─ libfllama.so (NDK llama.cpp)
                 └─ GGUF model file (Android FS)
```

### Key characteristics

- **No OpenClaw gateway involvement** — `sendMessage()` returns early with `yield* LocalLlmService().chat(...)` before any WS code runs
- **No tool use** — the gateway agent loop never sees these messages; tools/skills do not execute
- **Private** — no network traffic, no logs visible in the dashboard
- **Model prefix:** `local-llm/<modelId>` (e.g. `local-llm/qwen2.5-0.5b-instruct:q4_k_m`)

### Model management

Models are tracked in `LocalLlmService` catalog. State machine:

```
idle → downloading → installing → starting → ready → idle (on stop)
                                           └─ error
```

`LocalLlmStatus.ready` → triggers chat screen to auto-switch to `local-llm/` model.
`LocalLlmStatus.idle` → triggers chat screen to fall back to `_cloudFallbackModel`.

### When to use

Private offline chat. No agentic features. The model speaks directly to the user.

---

## Mode 2 — Local LLM Hub (Ollama)

### What it is

Ollama runs as a background daemon managed by `NativeBridge` (Android native). The Flutter app registers GGUF models with Ollama using a custom **Modelfile**. The OpenClaw gateway routes `ollama/` messages to Ollama via its built-in Ollama provider.

```
Flutter Dart (chat.send via WS)
  └─ OpenClaw Gateway (Node.js, port 18789)
       └─ models.providers.ollama
            └─ HTTP POST http://127.0.0.1:11434/api/chat
                 └─ Ollama daemon
                      └─ GGUF model (loaded into memory)
```

### Key characteristics

- **Full gateway agent loop** — tools, skills, multi-step reasoning all work
- **Dashboard visible** — inference requests appear in the OpenClaw web dashboard
- **Requires Ollama running** — `NativeBridge.startOllama()` / `NativeBridge.stopOllama()`
- **Model prefix:** `ollama/<ollamaModelName>` (e.g. `ollama/qwen2.5-0.5b-instruct:q4_k_m`)
- **Cloud models** use the same prefix with `:cloud` tag (e.g. `ollama/qwen3-coder:480b-cloud`) — Ollama proxies these to ollama.com

### Gateway configuration

Written by `GatewayService.configureOllama()` into `openclaw.json`:

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://127.0.0.1:11434",
        "apiKey": "ollama-local",
        "api": "ollama",
        "defaultContextWindow": 4096,
        "models": [
          {
            "id": "qwen2.5-0.5b-instruct:q4_k_m",
            "name": "qwen2.5-0.5b-instruct:q4_k_m",
            "contextWindow": 2048
          }
        ]
      }
    }
  }
}
```

**`defaultContextWindow`** — caps ALL Ollama models at 4096 if no per-model entry exists.
**`contextWindow` per model** — the gateway passes this as `options.num_ctx` to Ollama's `/api/chat`.

---

## Modelfile — The Critical Detail

Every GGUF registered with Ollama gets a **Modelfile** created by `_buildModelfileTemplate()` in `gateway_service.dart`. This file is what makes inference work correctly.

### Why the Modelfile is mandatory

Without a TEMPLATE block, Ollama uses a broken generic format that produces **0 tokens**. The TEMPLATE must match the model's training chat format exactly.

### ChatML format (Qwen2.5, SmolLM2, Phi, Gemma, etc.)

```
FROM /path/to/model.gguf
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Tools }}<|im_start|>system
{{ .Tools }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant
{{ end }}{{ .Response }}<|im_end|>"""
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|endoftext|>"
PARAMETER num_ctx 2048
PARAMETER num_gpu 0
PARAMETER num_thread 1
PARAMETER num_batch 512
```

### Llama 3.x format

```
FROM /path/to/model.gguf
TEMPLATE """{{ if .System }}<|start_header_id|>system<|end_header_id|>
{{ .System }}<|eot_id|>
{{ end }}{{ if .Tools }}<|start_header_id|>system<|end_header_id|>
{{ .Tools }}<|eot_id|>
{{ end }}{{ if .Prompt }}<|start_header_id|>user<|end_header_id|>
{{ .Prompt }}<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>
{{ end }}{{ .Response }}<|eot_id|>"""
PARAMETER stop "<|eot_id|>"
PARAMETER stop "<|start_header_id|>"
PARAMETER num_ctx 4096
PARAMETER num_gpu 0
PARAMETER num_thread 1
PARAMETER num_batch 512
```

### `{{ .Tools }}` block — critical for tool use

Without `{{ .Tools }}` in the TEMPLATE, Ollama responds to any request that includes `tools` in the API body with:
> `"model does not support tools"`

This error propagates to the user as:
> "This model does not support tool use. Tap the TOOLS button..."

The `{{ .Tools }}` block injects the tool schemas as a second system message. Added April 2026.

### Hardware parameters

| Parameter | Value | Reason |
|-----------|-------|--------|
| `num_gpu 0` | CPU only | Mobile Android — no supported Vulkan/OpenCL GPU compute |
| `num_thread 1` | Single thread | Prevents thermal throttle crash on mobile |
| `num_batch 512` | Token batch | Balance between throughput and memory |

---

## Context Window Management — The OOM Problem

### Critical lesson learned (April 2026)

**Do not rely on the Modelfile's `num_ctx` alone.**

When the OpenClaw gateway calls Ollama's `/api/chat`, it passes `options.num_ctx` derived from the model's configured `contextWindow`. If `contextWindow` is not set in the gateway config, the gateway defaults to the model's training context (32768 for Qwen2.5). This request-level option **overrides** the Modelfile's `PARAMETER num_ctx`.

**Evidence from logs:**
```
PARAMETER num_ctx 1024     ← Modelfile (applied, confirmed by num_batch=512 working)
PARAMETER num_batch 512    ← Also from Modelfile ✓

llama_context: n_ctx = 32768   ← Gateway override wins!
llama_kv_cache: size = 384 MiB ← KV cache for full 32768 context
llama_context: CPU compute buffer size = 298.50 MiB
```

**Total RAM usage without fix:** ~1145 MB for a 0.5B model → OOM crash on mobile.

### Context size reference

| Model | `num_ctx` | KV Cache | Compute | Approx Total RAM |
|-------|-----------|----------|---------|-----------------|
| qwen2.5-0.5b | 2048 | 24 MB | 30 MB | ~517 MB |
| qwen2.5-1.5b | 2048 | 24 MB | 30 MB | ~600 MB |
| smolm2-135m | 2048 | 8 MB | 15 MB | ~200 MB |
| smolm2-360m | 2048 | 16 MB | 20 MB | ~350 MB |
| smolm2-1.7b | 4096 | 48 MB | 60 MB | ~1.2 GB |
| qwen2.5-3b | 4096 | 48 MB | 60 MB | ~1.8 GB |

**Rule of thumb:** 2048 context = ~24 MB KV cache. Every 2× in context = 2× KV cache.

### Three-layer defence against full-context allocation

**Layer 1 — Modelfile `PARAMETER num_ctx`:**
Set during `ollama create`. Acts as the DEFAULT when no request option overrides it.
Configured in `_buildModelfileTemplate()` via `_getDynamicContextSize()`.

**Layer 2 — Gateway config `contextWindow` per model:**
Written to `openclaw.json` in `configureOllama()`. The gateway passes this to Ollama as `options.num_ctx` in every `/api/chat` request. This is the authoritative override.

**Layer 3 — Session patch before chat.send:**
`patchSessionMetadata({'contextWindow': ctx})` is called in `sendMessage()` before every WS `chat.send` for `ollama/` models. Covers the runtime case where config drifts (e.g., gateway restart).

---

## `_getDynamicContextSize()` — Important Detail

**Location:** `lib/services/gateway_service.dart`

Uses **substring matching**, not exact key lookup. Model IDs are full names like `qwen2.5-0.5b-instruct:q4_k_m` — exact lookup on `'qwen2.5-0.5b'` would fail.

```dart
for (final entry in modelContexts.entries) {
  if (id.contains(entry.key)) return entry.value;
}
```

This is called in three places:
1. `_buildModelfileTemplate()` — sets `PARAMETER num_ctx` in Modelfile
2. `configureOllama()` — writes `contextWindow` per model to gateway config
3. `sendMessage()` — patches session `contextWindow` before each WS chat

---

## Model Name Mapping

GGUF files have long names like `qwen2.5-0.5b-instruct-q4_k_m.gguf`. The mapping to Ollama format:

```
qwen2.5-0.5b-instruct-q4_k_m.gguf
  → _toOllamaModelName() →
  qwen2.5-0.5b-instruct:q4_k_m
```

The PRoot path exposed to Ollama: `/storage/..../models/qwen2.5-0.5b-instruct-q4_k_m.gguf`
Mapped to a PRoot-visible path by `prootModelPath` in the catalog entry.

---

## Sync Flow — "Sync Installed GGUFs"

When user taps "Sync Installed GGUFs" in Local LLM settings:

1. `syncLocalModelsWithOllama()` scans `LocalLlmService.catalog` for downloaded models
2. For each downloaded model: calls `_createOllamaModelFromGguf(name, ggufPath)`
3. `_createOllamaModelFromGguf` writes a Modelfile to `/tmp/oc_mf_<name>` inside PRoot
4. Runs `ollama create "<name>" -f "<modelfilePath>"` via PRoot
5. `ollama create` reuses the existing GGUF blob (no re-hash) — fast
6. Logs `[HUB] Refreshing <name> params...` then `[HUB] <name> — success`
7. Calls `configureOllama(syncedModels: [...])` to update `openclaw.json`
8. Emits updated `ollamaHubModels` list to the gateway state stream → chat screen dropdown updates

**Always re-creates models on sync** — this is intentional. It ensures `num_ctx`, `{{ .Tools }}`, and other Modelfile parameters from the current code are applied. `ollama create` is idempotent and fast when the GGUF blob is unchanged.

**After any change to `_buildModelfileTemplate` or `_getDynamicContextSize`, the user must tap "Sync Installed GGUFs" to apply the new parameters to existing models.**

---

## Model Switching — Chat Screen Behaviour

### Prefix routing

| Selected model starts with | Route | Gateway involved |
|---------------------------|-------|-----------------|
| `local-llm/` | fllama NDK direct | No |
| `ollama/` (no `:cloud`) | WS → gateway → local Ollama | Yes |
| `ollama/...:cloud` | WS → gateway → ollama.com | Yes (Ollama proxies) |
| `google/`, `anthropic/`, etc. | WS → gateway → cloud API | Yes |

### Auto-start / auto-stop (chat screen)

When user selects an `ollama/` model and Ollama is NOT running:
- `_isOllamaAutoStarting = true` → subtitle shows amber "STARTING HUB..."
- `GatewayService().startInternalOllama()` is called automatically
- When `_gatewaySub` receives `gwState.isOllamaRunning == true`: `_isOllamaAutoStarting = false`
- Subtitle transitions: amber "STARTING HUB..." → purple "OLLAMA CLOUD" or cyan "LOCAL HUB"

When user switches from `ollama/` to a pure cloud model (`google/`, `anthropic/`, etc.):
- `GatewayService().stopInternalOllama()` called automatically (saves memory)
- `_ollamaStopFlash = true` for 1.8 s → subtitle briefly shows grey "HUB OFF"

### OLLAMA CLOUD models always visible

`_kCloudOllamaModels` are seeded into `_availableModels` on init regardless of Ollama state. The section header shows an amber "AUTO-START" badge when Ollama is not running. Selecting any cloud Ollama model triggers the same auto-start flow as local hub models.

Only LOCAL HUB models (`ollama/` without `:cloud`) are removed from `_availableModels` when Ollama stops. Cloud models stay permanent.

---

## WS Protocol — chat.send for Ollama Models

```dart
_connection!.sendRequest({
  'method': 'chat.send',
  'params': {
    'sessionKey': sessionKey,       // from handshake, default 'main'
    'message': message,
    'idempotencyKey': Uuid().v4(),
    'timeoutMs': ollamaColdStart ? 180000 : 120000,
  },
});
```

**Before every chat.send for ollama/ models:**
```dart
_connection!.patchSessionMetadata({'contextWindow': ctx});
```

**Timeout logic:**
- Cold start (model not in Ollama's `/api/ps`): 3 minutes
- Warm start (model already loaded): 2 minutes
- Cloud models: 90 seconds

**WS fallback (if WS unavailable):**
Direct HTTP to `http://127.0.0.1:11434/v1/chat/completions` with `options: {num_ctx: ctx}` explicitly in the request body.

---

## Error Messages — What They Mean

| Error | Root Cause | Fix |
|-------|-----------|-----|
| `llama runner process has terminated: %!w(\u003cnil\u003e)` | OOM — model loaded with too-large context | Re-sync GGUFs, fix `contextWindow` in gateway config |
| `This model does not support tool use` | Modelfile TEMPLATE missing `{{ .Tools }}` block | Re-sync GGUFs to regenerate Modelfile |
| `No response received. The model may still be loading` | Cold start timeout — model took >2 min to load | Try again; reduce model size |
| `Ollama API error 500: {...}` | Ollama internal error (often OOM or runner crash) | Check available RAM; reduce `num_ctx` |
| `[Chat] ✓ Hub stream finished (state: aborted)` | Client closed connection before stream completed | Usually timeout — increase `timeoutMs` |
| `Stream complete (2 chunks)` + blank response | Modelfile TEMPLATE missing (0 tokens generated) | Re-sync GGUFs to restore TEMPLATE |

---

## Memory Requirements by Model

Minimum free RAM at inference time (Android's MemAvailable in /proc/meminfo):

| Model | Minimum Free | Recommended Free |
|-------|-------------|-----------------|
| smolm2-135m | 250 MB | 400 MB |
| smolm2-360m | 400 MB | 600 MB |
| qwen2.5-0.5b | 550 MB | 800 MB |
| qwen2.5-1.5b | 700 MB | 1 GB |
| smolm2-1.7b | 1.2 GB | 1.5 GB |
| qwen2.5-3b | 1.8 GB | 2.2 GB |

The app logs a warning when available RAM < 1.1 GB (before a 1.5B model send):
```
[MEM] ⚠ Only 840MB free — need ~1.1GB for Qwen2.5-1.5B. Inference may crash.
```

---

## Key Files

| File | Role |
|------|------|
| `lib/services/gateway_service.dart` | Ollama lifecycle, Modelfile generation, context sizing, sync |
| `lib/services/local_llm_service.dart` | fllama NDK inference, model catalog, download/install |
| `lib/services/native_bridge.dart` | `startOllama()`, `stopOllama()`, `isOllamaRunning()`, `runInProot()` |
| `lib/screens/management/local_llm_screen.dart` | Local LLM Hub UI, sync button, direct diagnostics |
| `lib/screens/chat_screen.dart` | Model switching, auto-start/stop, subtitle bar transitions |

---

## Things That Must Never Change Without Understanding

1. **`PARAMETER num_batch 512`** — lowering this causes instability; raising risks OOM
2. **`PARAMETER num_gpu 0`** — Ollama GPU compute is not supported on Android ARM; removing this causes silent failures
3. **`PARAMETER num_thread 1`** — multi-thread inference on mobile causes thermal crash within 1–2 min
4. **`{{ .Tools }}` in TEMPLATE** — required for tool use; removing it silently breaks tools
5. **`_getDynamicContextSize` uses `contains` not exact match** — changing to exact match breaks all models (full model IDs never match short map keys)
6. **Three-layer context window defence** — all three layers (Modelfile, configureOllama, patchSessionMetadata) must stay in sync; removing any one allows OOM regression
7. **`await for` not `.listen()`** — streaming inference in the direct test panel must use `await for`; `.listen()` is fire-and-forget and returns immediately with blank output

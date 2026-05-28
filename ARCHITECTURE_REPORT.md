# Plawie Architecture Report

Last updated: 2026-05-28

This is the current architecture of Plawie as implemented in the app. Older
documents in the repo may still preserve incident history, but they should not
override this runtime contract.

## Executive Summary

Plawie is a Flutter Android app that runs a local OpenClaw Gateway inside an
embedded PRoot Linux userland, pairs that Gateway with native Android device
capabilities, and offers three model execution lanes:

| Lane | Model IDs | Runtime | Gateway | Tool path |
| --- | --- | --- | --- | --- |
| Cloud full Gateway | `google/...`, `anthropic/...`, `openai/...`, `xai/...`, `openrouter/...`, `groq/...` | OpenClaw Gateway in PRoot | Required | Gateway owns tool schemas, calls, execution, sessions, and Talk |
| Direct local NDK | `local-llm/...` | `fllama` / llama.cpp NDK in Flutter process | Bypassed | Dart local tools only; no Gateway skills |
| NDK Gateway bridge | `plawie_ndk/local-llm` | OpenAI-compatible HTTP bridge to `fllama` | Required | Gateway sends tools; bridge yields tool calls back to Gateway |

The current design is not an Ollama architecture. Ollama routes are legacy
migration guards only. No normal setup, chat, settings, or cloud-provider path
should start `ollama`, depend on `127.0.0.1:11434`, or use a PRoot
`llama-server`.

## Source Of Truth

| Area | Code |
| --- | --- |
| Model lanes, context windows, safe output caps | `lib/services/model_execution_policy.dart` |
| Provider/model catalog and UI labels | `lib/services/model_provider_catalog.dart` |
| Gateway startup, config hardening, cloud routing | `lib/services/gateway_service.dart` |
| Direct NDK model lifecycle and inference | `lib/services/local_llm_service.dart` |
| OpenAI-compatible local bridge | `lib/services/ndk_gateway_bridge_service.dart` |
| Local model management UI | `lib/screens/management/local_llm_screen.dart` |
| Chat model selection and display labels | `lib/screens/chat_screen.dart`, `lib/screens/settings_screen.dart` |

## Runtime Layers

```text
Android app process
  Flutter UI
  GatewayService
  LocalLlmService
  NdkGatewayBridgeService (:11435 when manually started)
  AgentSkillServer / capability bridge (:8765)

PRoot Linux userland
  Node.js
  OpenClaw Gateway (:18789)
  OpenClaw workspace, skills, sessions, provider config

Native Android
  Foreground service and wake behavior
  MethodChannel bridge
  Device capabilities: camera, canvas, flashlight, haptics, sensors, screen
```

The PRoot layer is still the production home for OpenClaw Gateway. The NDK layer
is the production home for private local inference. They are intentionally
separate so local inference pressure cannot become a requirement for Gateway
boot, pairing, dashboard readiness, or returning-user attach.

## Boot And Pairing Contract

Gateway readiness is staged:

1. Repair or install OpenClaw in PRoot.
2. Write hardened `openclaw.json` before first Gateway start.
3. Start or attach to Gateway on `127.0.0.1:18789`.
4. Wait for HTTP health and token availability.
5. Establish the operator WebSocket.
6. Wait for RPC health, skills status, and tool discovery when supported.
7. Release Android node auto-connect.
8. Approve local pairing/scopes.
9. Enter the app with Gateway, dashboard, and node ready.

Local model activation is deliberately after the Gateway baseline. It is not a
boot dependency.

## Model Execution Policy

`ModelExecutionPolicy` centralizes context and output limits. These values are
used as safe interactive budgets, not marketing claims about a provider's
absolute maximum.

The policy exists for four reasons:

1. Give OpenClaw enough room for system context, tool schemas, tool results, and
   reasoning without asking for impossible output sizes.
2. Keep local NDK requests inside phone-safe context and memory limits.
3. Give setup, settings, and chat menus the same understanding of each exposed
   model.
4. Let UI labels communicate capability without hardcoding one-off model names.

Tool labels mean:

| Label | Meaning |
| --- | --- |
| `FULL TOOLS` | Cloud Gateway lane with known tool-capable model metadata |
| `VARIABLE TOOLS` | Router, bridge, or provider-tier path where tools may work but depend on selected upstream/local model behavior or practical rate limits |
| `CHAT ONLY` | Model route should not be presented as a dependable tool-calling route |

These labels do not guarantee model intelligence. A model can have enough
context and still make poor tool decisions. A smaller model may call a simple
tool correctly after context compaction. The policy controls routing and safe
budgets; observed model behavior still has to be tested.

## Cloud Full Gateway Lane

Cloud chat stays on the Gateway path by default. `GatewayService.sendMessage()`
resolves the selected model and only bypasses Gateway for direct `local-llm/...`
IDs. `_shouldUseFastCloudChat()` currently returns false, keeping cloud traffic
inside OpenClaw so the user gets one consistent lane for:

- OpenClaw skills and tool schemas.
- Android node actions.
- Talk/TTS.
- Dashboard visibility.
- Session and run diagnostics.

Provider defaults come from `ModelProviderCatalog.providerConfigDefaults()` and
are merged into Gateway config. Known models carry `contextWindow` and
`maxTokens` values. Existing config is healed by `_mergeModelDefaults()` so a
stale provider block cannot keep dangerous output caps.

The recent OpenRouter/Kimi-style failure was not treated as "Kimi is too small."
The log pattern showed total requested tokens exceeded the provider context
because the Gateway/provider config asked for an enormous output budget. The
current fix is model-wide safe `maxTokens`, applied through the shared catalog.

Groq is a separate lesson: the Llama routes advertise large context windows, but
the observed on-demand key failed on tokens-per-minute before context was full.
Those routes stay in the cloud Gateway lane, but the catalog labels them
`VARIABLE TOOLS` and uses compact output caps because full Gateway tools need a
Groq tier with enough TPM for the system prompt and tool schemas.

## Direct Local NDK Lane

Direct local model IDs start with `local-llm/`. They bypass:

- Gateway token lookup.
- Gateway WebSocket setup.
- OpenClaw provider routing.
- Gateway Talk/TTS.
- Gateway tool schemas.

Flow:

```text
ChatScreen
  -> GatewayService.sendMessage()
  -> ModelProviderCatalog.isDirectLocalModelId()
  -> LocalLlmService.chat()
  -> fllamaInference()
  -> GGUF model file in app storage
```

`LocalLlmService` builds a compact local system prompt, trims history against
the active context window, converts OpenAI-like history maps into `fllama`
messages, and streams text back to the chat UI.

Local tool support is handled in Dart. When `fllama` returns `tool_calls`,
`LocalLlmService` accumulates streaming deltas, dispatches supported local tools,
adds tool result messages, and recurses with a depth limit of 3. This gives local
models a deterministic loop for phone/avatar actions without loading the full
OpenClaw Gateway prompt.

## NDK Gateway Bridge Lane

The bridge is manual and explicit. It is exposed as:

```text
Provider: plawie_ndk
Model:    plawie_ndk/local-llm
Base URL: http://127.0.0.1:11435/v1
Health:   GET  /v1/health
Models:   GET  /v1/models
Chat:     POST /v1/chat/completions
```

Flow:

```text
Gateway cloud-style agent request
  -> OpenAI-compatible provider plawie_ndk
  -> NdkGatewayBridgeService on 127.0.0.1:11435
  -> compact system prompt replaces large Gateway system prompt
  -> Gateway tools array is converted to native fllama Tool objects
  -> LocalLlmService.chat(..., tools, yieldToolCalls: true)
  -> bridge emits OpenAI SSE tool_calls chunk
  -> Gateway executes the real tool
  -> Gateway sends tool result in the next completion request
  -> bridge preserves recent assistant tool_calls and matching tool results
```

The bridge does not execute Gateway tools itself. It only translates between the
Gateway's OpenAI-compatible provider protocol and `fllama`'s native request
format. Gateway remains the tool executor.

The bridge also performs aggressive context compaction:

- Replaces the large Gateway system prompt with
  `ModelExecutionPolicy.ndkBridgeCompactPrompt(...)`.
- Keeps only a small recent message slice.
- Preserves recent assistant `tool_calls`.
- Preserves matching `tool` / `function` results and truncates large outputs.
- Adds a synthetic user instruction after a tool result so the local model
  answers from the result instead of repeating the same tool call.

## Ports

| Port | Owner | Purpose |
| --- | --- | --- |
| `18789` | OpenClaw Gateway | HTTP/WebSocket control plane |
| `8765` | Plawie app | Android capability bridge / AgentSkillServer |
| `11435` | Plawie app | Manual NDK Gateway bridge |
| `11434` | Legacy Ollama | Not used in the production path |
| `8081` | Legacy llama-server | Not used in the production path |

## Deprecated Paths

These are historical only:

- Embedded Ollama daemon inside PRoot.
- Ollama cloud proxy through a local daemon.
- PRoot `llama-server` on port `8081`.
- `node-llama-cpp` HTTP server inside PRoot.
- LAN Ollama/LM Studio discovery as a production setup path.

Remaining references should be clearly marked as incident history, migration
guards, or future proposals. They should not be described as current runtime
architecture.

## Verification Baseline

For architecture-level validation:

- Fresh setup does not expose Ollama.
- Cloud chat uses Gateway and does not hit `11434`.
- `local-llm/...` chat works with Gateway stopped or unhealthy.
- `plawie_ndk/local-llm` only appears after the user starts the bridge.
- Gateway config for known models includes safe `contextWindow` and `maxTokens`.
- Tool-call tests show either real Gateway tool chips/results or a precise
  model/provider limitation, not a hidden fallback.

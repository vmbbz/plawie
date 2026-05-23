# Local LLM Architecture

Last updated: 2026-05-23

## Decision

Plawie local inference is now NDK Direct only. Embedded Ollama Local and Ollama
Cloud are legacy implementation paths and are hidden from normal UI.

## Production Mode

| Mode | Prefix | Runtime | Gateway | Network | Intended use |
| --- | --- | --- | --- | --- | --- |
| NDK Direct | `local-llm/...` | fllama / llama.cpp NDK | No | No | Private/offline chat and direct app actions |
| Cloud Agent | `google/...`, `anthropic/...`, `openai/...`, `xai/...`, `openrouter/...`, `groq/...` | OpenClaw Gateway | Yes | Yes | Tools, skills, dashboard, multi-step agent workflows |

## Why Ollama Is Deprecated

The embedded Ollama daemon requires a large ARM64 runtime, adds another process
beside Flutter, PRoot, OpenClaw, and the paired node, and can push average phones
into memory pressure during chat. It also blurred the product promise because
Ollama Cloud still needed a local daemon proxy.

Current behavior:

- Fresh setup does not offer Ollama Local or Ollama Cloud.
- Chat/settings do not list `ollama/...` models.
- Stale `ollama/...` preferences migrate to the safe cloud fallback.
- Legacy daemon install/start/stop methods have been removed from Dart and
  Android. Remaining `ollama` references are migration/removal guards only.

## NDK Direct Flow

```text
Flutter Chat
  -> GatewayService.sendMessage()
  -> local-llm prefix detected
  -> LocalLlmService.chat()
  -> fllama / llama.cpp NDK
  -> GGUF model file in app storage
```

Important properties:

- No Gateway token lookup.
- No WebSocket connection.
- No `talk.speak` Gateway TTS call.
- No Ollama daemon, no `127.0.0.1:11434` dependency.
- App actions are handled directly by Dart capabilities when deterministic.

## Thread Policy

The safe default is 4 CPU threads. Older persisted values above 4 are clamped
back to 4 when the Local LLM page opens and inference is idle. Users can still
raise the slider manually, but the UI warns that high thread counts can slow
Flutter, Gateway health checks, and pairing.

## Capture UX

Camera and canvas captures from local tools attach to the assistant chat bubble.
They do not auto-open a full-screen hologram overlay, because that trapped the
user during local-tool tests.

## Experimental NDK Gateway Bridge

A local OpenAI-compatible HTTP bridge exists as an explicit experiment:

```text
Provider: plawie_ndk
Model:    plawie_ndk/local-llm
Base URL: http://127.0.0.1:11435/v1
GET  http://127.0.0.1:11435/v1/models
POST http://127.0.0.1:11435/v1/chat/completions
```

It is started manually from Local LLM -> Gateway Bridge Experiment and can then
write a temporary OpenClaw provider config. It is not part of fresh setup and is
not enabled by default.

Expected confidence signals:

- Local LLM model is `ready` before bridge use.
- Bridge status is `running`.
- `/v1/health` returns `ok: true`, `runtime: fllama`, and the active model ID.
- Gateway config contains `models.providers.plawie_ndk.baseUrl =
  http://127.0.0.1:11435/v1`.
- Gateway logs show a request to the `plawie_ndk/local-llm` model without
  trying `127.0.0.1:11434`.
- A chat turn either produces assistant text or returns a clear bridge HTTP
  error such as `model_not_ready`.

Do not promote it to a production default until it proves:

- Streaming Server-Sent Events match OpenAI-compatible expectations.
- Tool calls either round-trip through Gateway correctly or are explicitly
  disabled for bridge-routed local models.
- Startup/shutdown is lifecycle-safe.
- NDK inference does not compete with Gateway/node stability under memory
  pressure on 8 GB phones.

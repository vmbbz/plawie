# Plawie Model Provider and Help Roadmap

Last updated: 2026-05-22

## Current External Contract

OpenClaw's current model-provider docs describe provider/model routing as
`provider/model-id`, with examples such as `openai/gpt-5.5`,
`google/gemini-3.1-pro-preview`, `xai/grok-4.3`, and `ollama/llama3.2`.
OpenClaw also documents OpenAI-compatible custom providers through a local
`baseUrl`, which is the key contract for a future Plawie native NDK bridge.

Sources:

- OpenClaw model providers: https://documentation.openclaw.ai/concepts/model-providers
- OpenClaw xAI provider: https://docs.openclaw.ai/providers/xai
- OpenClaw local models: https://docs.openclaw.ai/gateway/local-models
- OpenClaw v2026.5.18 release: https://github.com/openclaw/openclaw/releases/tag/v2026.5.18
- Ollama OpenClaw integration: https://docs.ollama.com/integrations/openclaw

## Product Defaults

Use these paths in the app UI:

| User goal | Recommended path | What Plawie must do |
| --- | --- | --- |
| Free and private | NDK Direct local model | Run fllama in-process, no gateway dependency. |
| Free with full Gateway tools | Ollama Local Hub | Start embedded Ollama, route as `ollama/model`. |
| Big free-ish cloud models | Ollama Cloud | Start embedded Ollama first, then require `ollama signin`. |
| Premium best reasoning | Claude / Gemini / OpenAI | Store API key, write OpenClaw provider config, hot-reload gateway. |
| Grok users | xAI/Grok | Store `XAI_API_KEY`, route as `xai/grok-4.3`. |
| Lowest latency cloud | Groq | Store `GROQ_API_KEY`, route through Gateway provider. |

## Ollama Rule

All `ollama/...` models are Gateway-routed through the local Ollama daemon.
That includes `:cloud` models. The cloud tag changes where inference happens,
but the daemon still acts as the local authenticated proxy for OpenClaw.

Hard failure signature:

```text
provider=ollama ... model=...:cloud
endpoint=local route=local
ECONNREFUSED 127.0.0.1:11434
```

Fix:

1. Start embedded Ollama Hub.
2. Wait until `127.0.0.1:11434/api/tags` responds.
3. For `:cloud` models, verify Ollama sign-in.
4. Persist the selected model and reconnect the Gateway WebSocket.

## Chat Settings UX

The Chat page model menu should make routing obvious:

- `ON DEVICE`: Native fllama models. Fast, private, limited Gateway tool use.
- `LOCAL HUB`: Ollama models running through OpenClaw Gateway. Full tools.
- `OLLAMA CLOUD`: Ollama.com models. Requires local Hub plus Ollama sign-in.
- `CLOUD`: API-key providers such as Gemini, Claude, OpenAI, xAI, and Groq.

When a user picks an `ollama/...` model, Plawie should call the hardened
Ollama readiness routine, not just launch the binary. This prevents "selected
but not actually routable" states.

## Setup Flow

First-run setup should offer:

- Ollama Local: no key, free/offline-first, Gateway Hub installed during setup.
- Ollama Cloud: explain that sign-in happens later from Local LLM settings.
- xAI/Grok: API key, route to `xai/grok-4.3`.
- Gemini, Claude, OpenAI, Groq: API key.

Do not default first-run Ollama users to `:cloud`. It creates auth errors before
they have had a chance to sign in.

## Native NDK Bridge Plan

Goal: remove the heavy PRoot Ollama memory overhead for small local models while
still letting OpenClaw see a normal OpenAI-compatible provider.

Bridge contract:

```text
GET  http://127.0.0.1:11435/v1/models
POST http://127.0.0.1:11435/v1/chat/completions
POST http://127.0.0.1:11435/v1/responses   (later)
```

Implementation sketch:

1. Start a Dart/Android local HTTP server owned by `LocalLlmService`.
2. Translate OpenAI-compatible chat requests into fllama prompts.
3. Support non-streaming first, then SSE streaming.
4. Register an OpenClaw provider such as `plawie_ndk` with:

```json
{
  "models": {
    "providers": {
      "plawie_ndk": {
        "apiKey": "plawie-local",
        "baseUrl": "http://127.0.0.1:11435/v1",
        "models": [
          { "id": "qwen2.5-0.5b", "name": "Plawie NDK Qwen 0.5B" }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "plawie_ndk/qwen2.5-0.5b"
      }
    }
  }
}
```

Open question before implementation: confirm whether the installed OpenClaw
Gateway accepts arbitrary provider IDs with OpenAI-compatible `baseUrl`, or
whether it requires a known provider adapter. If arbitrary IDs are blocked, the
fallback is an isolated OpenAI-compatible profile instead of replacing the
global `openai` provider.

## Help Page Scope

The in-app Help page must be a user guide, not only an architecture page:

- What Plawie/OpenClaw is.
- Which model path to choose.
- How to use Chat settings.
- How Ollama Local and Ollama Cloud differ.
- How avatars, gestures, voice, Canvas, and device tools work.
- How to maintain the app after updates.
- How to interpret common errors.
- Where to update API keys and repair local inference.

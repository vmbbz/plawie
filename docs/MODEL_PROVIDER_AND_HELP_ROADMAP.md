# Plawie Model Provider Implementation

Last updated: 2026-05-22

This document is the implementation contract for model selection, provider keys,
Ollama Cloud, and future native NDK Gateway bridging in Plawie.

## Sources Checked

- OpenClaw model providers: https://documentation.openclaw.ai/concepts/model-providers
- OpenClaw xAI provider: https://docs.openclaw.ai/providers/xai
- OpenClaw OpenAI provider: https://docs.openclaw.ai/providers/openai
- OpenClaw local models: https://docs.openclaw.ai/gateway/local-models
- OpenClaw v2026.5.18 release: https://github.com/openclaw/openclaw/releases/tag/v2026.5.18
- Ollama OpenClaw integration: https://docs.ollama.com/integrations/openclaw

## Implemented Architecture

Model/provider knowledge is centralized in:

- `lib/services/model_provider_catalog.dart`

All user-facing model surfaces should use this catalog instead of hardcoded
provider lists:

- First-run setup: `lib/screens/setup_flow_screen.dart`
- Chat model menu: `lib/screens/chat_screen.dart`
- Settings model/API-key dialogs: `lib/screens/settings_screen.dart`
- Local LLM / Ollama Cloud page: `lib/screens/management/local_llm_screen.dart`
- Gateway config and credential routing: `lib/services/gateway_service.dart`
- Fresh-install hardening: `lib/services/bootstrap_service.dart`
- In-app guide: `lib/screens/help_screen.dart`

## Provider Defaults

| Provider | Default model | Credential | Runtime route |
| --- | --- | --- | --- |
| Google Gemini | `google/gemini-3.1-pro-preview` | `GOOGLE_API_KEY` | OpenClaw Gateway provider |
| Anthropic Claude | `anthropic/claude-opus-4-6` | `ANTHROPIC_API_KEY` | OpenClaw Gateway provider |
| OpenAI | `openai/gpt-5.4` | `OPENAI_API_KEY` | OpenClaw Gateway provider |
| xAI / Grok | `xai/grok-4` | `XAI_API_KEY` | OpenClaw Gateway provider |
| Groq | `groq/llama-3.3-70b-versatile` | `GROQ_API_KEY` | OpenClaw Gateway provider |
| Ollama Local | `ollama/qwen2.5:0.5b` | `ollama-local` placeholder | Embedded Ollama Hub at `127.0.0.1:11434`; one-time runtime download is ~1.30 GB |
| Ollama Cloud | `ollama/kimi-k2.5:cloud` | Ollama sign-in, no manual API key | Embedded Ollama Hub proxies to ollama.com; still needs the ~1.30 GB runtime |

Compatibility aliases are migrated by the app where safe:

| Legacy ID | Canonical ID |
| --- | --- |
| `anthropic/claude-opus-4.6` | `anthropic/claude-opus-4-6` |
| `anthropic/claude-sonnet-4.6` | `anthropic/claude-sonnet-4-6` |
| `xai/grok-4.3` | `xai/grok-4` |
| `groq/llama-3.1-405b` | `groq/llama-3.3-70b-versatile` |

## Routing Rules

| Selected model | Required preparation | Failure prevented |
| --- | --- | --- |
| `local-llm/...` | Start native fllama model in Local LLM | Avoids Gateway dependency for private/offline chat |
| `ollama/...` local | Confirm/install embedded Ollama Hub runtime, start Hub, wait for health | Prevents `ECONNREFUSED 127.0.0.1:11434` and surprise mobile-data use |
| `ollama/...:cloud` | Confirm/install embedded Ollama Hub runtime, start Hub, then require Ollama sign-in | Prevents confusing API-key prompts for Ollama Cloud |
| API-key cloud model | Verify provider credential exists before switching | Prevents silent Gateway provider failure |
| Dynamic OpenClaw agent | Persist model key and reconnect WS | Lets Gateway route by current agent config |

## Ollama Cloud Contract

Ollama Cloud is not a simple API-key provider in Plawie. It uses the local
Ollama daemon as an authenticated proxy. Therefore every `ollama/...` model,
including `:cloud`, requires the embedded Hub. The official ARM64 runtime used
by the current embedded path is about **1.30 GB**, so Plawie must ask before
downloading it and should recommend Wi-Fi.

Hard failure signature:

```text
provider=ollama ... model=...:cloud
endpoint=local route=local
ECONNREFUSED 127.0.0.1:11434
```

Correct flow:

1. Persist the chosen `ollama/...` model.
2. If the embedded runtime is missing, guide the user to Local LLM and ask before downloading it.
3. Start the embedded Ollama Hub if `127.0.0.1:11434` is down.
4. Wait for `/api/tags` health.
5. If the model has `:cloud`, verify Ollama sign-in.
6. Persist model to OpenClaw config and reconnect the Gateway WebSocket.

## Fresh Setup Contract

First-run setup now exposes these choices:

- On-device NDK/fllama: preferred lightweight local path; downloads only the chosen GGUF model.
- Ollama Local: no key, free/offline-first, but requires the optional ~1.30 GB Ollama Hub runtime before any Ollama model can run.
- Ollama Cloud: no manual key, but requires the optional ~1.30 GB Ollama Hub runtime plus sign-in from Local LLM -> Cloud.
- Gemini, Claude, OpenAI, Grok/xAI, Groq: API-key based Gateway providers.

Setup stores:

- `pendingProvider`: the selected setup provider, including `ollama_cloud` when the user explicitly chose cloud.
- `apiProvider`: normalized provider used by Settings and Gateway credentials.
- `configuredModel`: setup-safe gateway model. For Ollama Local/Ollama Cloud
  this is not an `ollama/...` model during fresh setup, because the optional
  Hub runtime may not exist yet.

Bootstrap then bakes provider config before the first Gateway start, preventing
post-start reload churn that can break pairing.

## Runtime Guardrails

Implemented guardrails:

- Chat model picker blocks known cloud provider models when the provider key is missing.
- Settings model picker also blocks known cloud provider models without credentials.
- Selecting any `ollama/...` model calls the hardened Ollama readiness path without silently downloading the heavy Hub runtime.
- Local LLM Cloud page starts/checks the Hub before activating `:cloud` models.
- Local LLM Cloud page launches Ollama sign-in instead of pretending a manual API key is needed.
- Bootstrap provider hardening preserves existing keys and writes defaults for every provider shown in the UI.

## Native NDK Gateway Bridge Status

Goal: expose native fllama as an OpenAI-compatible local provider so OpenClaw can
route through it without the PRoot Ollama memory overhead.

Planned bridge contract:

```text
GET  http://127.0.0.1:11435/v1/models
POST http://127.0.0.1:11435/v1/chat/completions
POST http://127.0.0.1:11435/v1/responses
```

Proposed provider config:

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
      "model": { "primary": "plawie_ndk/qwen2.5-0.5b" }
    }
  }
}
```

Do not enable this as a default Gateway provider yet. The app already has a
stable direct `local-llm/...` native path. The Gateway bridge must first prove:

- OpenClaw accepts arbitrary provider IDs with `baseUrl` on Android.
- Streaming Server-Sent Events match OpenAI-compatible expectations.
- Tool calls are passed back to Gateway instead of being consumed only by the local fllama path.
- Startup/shutdown is lifecycle-safe and does not compete with Ollama on memory.

Until that validation is complete, Plawie keeps native fllama as the direct
private path and Ollama Hub as the full Gateway tool-use path.

## Release Checklist

- Build APK after provider catalog changes.
- Fresh install with Ollama Local selected.
- Fresh install with Ollama Cloud selected, then sign in from Local LLM -> Cloud.
- App update with existing `ollama/kimi-k2.5:cloud` selection.
- Switch Chat menu from Gemini to Grok with no xAI key and confirm selection is blocked.
- Add xAI key in Settings, switch to Grok, and confirm Gateway chat route works.
- Switch to Ollama Cloud from Chat and confirm Hub readiness logs appear before chat.
- Confirm Help page explains model routing, provider keys, and recovery steps.

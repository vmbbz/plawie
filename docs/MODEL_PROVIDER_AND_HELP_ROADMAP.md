# Plawie Model Provider Implementation

Last updated: 2026-05-23

This document is the implementation contract for model selection, provider keys,
Gateway routing, and private offline inference in Plawie.

## Current Product Contract

Plawie now exposes two production inference paths:

| Mode | Model IDs | Runtime | Gateway | Best for |
| --- | --- | --- | --- | --- |
| Cloud Agent Mode | `google/...`, `anthropic/...`, `openai/...`, `xai/...`, `groq/...` | OpenClaw Gateway | Yes | Tools, skills, dashboard, multi-step agent work |
| Private Offline Mode | `local-llm/...` | fllama / llama.cpp NDK | No | Offline chat, privacy, lightweight direct app actions |

Embedded Ollama Local and Ollama Cloud are deprecated for the Play Store launch
path. They are hidden from setup, chat, and settings because the optional daemon
runtime is about 1.30 GB and can overwhelm average Android devices when combined
with Flutter, OpenClaw, and the paired node.

## Central Source

Model/provider knowledge is centralized in:

- `lib/services/model_provider_catalog.dart`

User-facing surfaces should use the catalog instead of hardcoded provider lists:

- First-run setup: `lib/screens/setup_flow_screen.dart`
- Chat model menu: `lib/screens/chat_screen.dart`
- Settings model/API-key dialogs: `lib/screens/settings_screen.dart`
- Local LLM page: `lib/screens/management/local_llm_screen.dart`
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

Compatibility aliases are migrated by the app where safe:

| Legacy ID | Canonical ID |
| --- | --- |
| `anthropic/claude-opus-4.6` | `anthropic/claude-opus-4-6` |
| `anthropic/claude-sonnet-4.6` | `anthropic/claude-sonnet-4-6` |
| `xai/grok-4.3` | `xai/grok-4` |
| `groq/llama-3.1-405b` | `groq/llama-3.3-70b-versatile` |
| any `ollama/...` | `google/gemini-3.1-pro-preview` |

## Routing Rules

| Selected model | Required preparation | Failure prevented |
| --- | --- | --- |
| `local-llm/...` | Start native fllama model in Local LLM | Avoids Gateway dependency for private/offline chat |
| API-key cloud model | Verify provider credential exists before switching | Prevents silent Gateway provider failure |
| Dynamic OpenClaw agent | Persist model key and reconnect WS | Lets Gateway route by current agent config |
| Legacy `ollama/...` | Migrate to safe cloud fallback | Prevents daemon autostart, `127.0.0.1:11434` errors, and surprise downloads |

## Fresh Setup Contract

First-run setup exposes Gateway cloud providers only:

- Gemini, Claude, OpenAI, Grok/xAI, Groq.
- Users may skip API-key setup and add a key later from Settings.
- Private Offline Mode is configured later from Local LLM by downloading a GGUF
  and selecting the resulting `local-llm/...` model in Chat.

Setup stores:

- `pendingProvider`: selected cloud provider.
- `apiProvider`: normalized provider used by Settings and Gateway credentials.
- `configuredModel`: setup-safe gateway model for first boot.

Bootstrap then bakes provider config before the first Gateway start, preventing
post-start reload churn that can break pairing.

## Runtime Guardrails

Implemented guardrails:

- Chat model picker blocks known cloud provider models when the provider key is missing.
- Settings model picker also blocks known cloud provider models without credentials.
- Stale `ollama/...` preferences migrate to the safe cloud fallback.
- Local LLM page no longer offers an Ollama runtime install path in normal UI.
- NDK local mode bypasses Gateway token lookup, WebSocket setup, and `talk.speak`.
- Camera/canvas captures attach to the chat bubble instead of forcing a full-screen overlay.

## Native NDK Gateway Bridge Status

Goal: expose native fllama as an OpenAI-compatible local provider so OpenClaw can
route through it without the PRoot Ollama memory overhead.

Do not enable this as a default Gateway provider yet. The app already has a
stable direct `local-llm/...` native path. The Gateway bridge must first prove:

- OpenClaw accepts the provider config on Android.
- Streaming Server-Sent Events match OpenAI-compatible expectations.
- Tool calls return to Gateway instead of being consumed only by local fllama.
- Startup/shutdown is lifecycle-safe and does not compete with Flutter/Gateway memory.

Until that validation is complete, Plawie keeps native fllama as the direct
private path and cloud providers as the full Gateway tool-use path.

## Release Checklist

- Fresh install with Gemini/Claude/OpenAI/Grok/Groq selected.
- App update with existing `ollama/kimi...` preference.
- Chat cloud model with missing key blocks clearly.
- Settings model picker lists cloud models plus active local-llm only.
- Local LLM page shows NDK/offline guidance only.
- NDK camera/canvas captures attach inline and do not trap the UI.
- Gateway/node logs remain stable when no NDK model is actively inferring.

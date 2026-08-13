# Plawie Model Provider Implementation

Last updated: 2026-08-05

This document is the implementation contract for model selection, provider keys,
Gateway routing, local NDK inference, and the manual NDK Gateway bridge.

## Forward Dynamic Provider Plan

The static catalog remains the compatibility baseline while the provider/model
migration is staged. The detailed forward plan for dynamic model discovery,
searchable provider grouping, account handoffs, context-preserving Gateway
selection, secure first-run provider/API-key setup, and human-approved x402 v2
Base payments is
[`DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md`](DYNAMIC_PROVIDER_MODEL_AND_X402_IMPLEMENTATION_PLAN.md).
Dynamic discovery must not delay native Gateway startup or change the existing
cloud Gateway, direct local NDK, compact bridge, or opt-in PRoot execution lanes.
The payment plan requires explicit UI approval plus device authentication for
every transaction and does not permit reusable agent spend permissions.

The approved completion architecture is
[`Native Wallet, Bridge, and Wallet-Funded Provider Completion Design`](superpowers/specs/2026-08-05-native-wallet-bridge-paid-provider-design.md).
Venice and BlockRun remain excluded from the current product contract below
until their context-preserving OpenClaw transports and payment acceptance tests
pass. Merely listing them in the payment catalog does not make them chat-ready.

## Current Product Contract

Plawie exposes three model execution lanes:

| Lane | Model IDs | Runtime | Gateway | Best for |
| --- | --- | --- | --- | --- |
| Cloud Agent Mode | `google/...`, `anthropic/...`, `openai/...`, `xai/...`, `openrouter/...`, `groq/...` | OpenClaw Gateway | Yes | Tools, skills, dashboard, Talk, multi-step agent work |
| Private Offline Mode | `local-llm/...` | fllama / llama.cpp NDK | No | Offline chat, privacy, local Dart actions |
| Compact NDK Bridge | `plawie_ndk/local-llm` | Gateway -> Dart bridge -> fllama | Yes | Manual experiment: local model through Gateway tool transport |

Embedded Ollama Local and Ollama Cloud are deprecated for the launch path. They
are hidden from setup, chat, and settings. Stale `ollama/...` model IDs migrate
to the safe catalog fallback.

The PRoot to embedded native Node migration changes only the Gateway owner for
Gateway-backed lanes. It does not remove Private Offline Mode. Users can still
download Qwen/Smol/GGUF models from Local LLM and run `local-llm/...` cost-free
on device through fllama.

## Central Sources

Provider and model knowledge is split deliberately:

| File | Responsibility |
| --- | --- |
| `lib/services/model_execution_policy.dart` | Execution lanes, tool policy, context windows, safe output caps, bridge limits |
| `lib/services/model_provider_catalog.dart` | Provider defaults, model IDs, labels, capability labels, config merge/healing |

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
| Google Gemini | `google/gemini-3.1-pro-preview` | `GOOGLE_API_KEY` | Gateway provider |
| Anthropic Claude | `anthropic/claude-opus-4-6` | `ANTHROPIC_API_KEY` | Gateway provider |
| OpenAI | `openai/gpt-5.4` | `OPENAI_API_KEY` | Gateway provider |
| xAI / Grok | `xai/grok-4` | `XAI_API_KEY` | Gateway provider |
| OpenRouter | `openrouter/openai/gpt-oss-20b:free` | `OPENROUTER_API_KEY` | Gateway provider |
| Groq | `groq/openai/gpt-oss-120b` | `GROQ_API_KEY` | Gateway provider |
| Plawie NDK bridge | `plawie_ndk/local-llm` | local placeholder key | Manual Gateway bridge |

Known model entries include `contextWindow` and `maxTokens` so Gateway/provider
requests leave room for system prompt, tool schemas, tool results, reasoning,
and normal assistant output.

## Capability Labels

The catalog exposes user-facing route labels:

| Label | Meaning |
| --- | --- |
| `FULL TOOLS` | Cloud Gateway lane and known tool-capable model metadata |
| `VARIABLE TOOLS` | Router or bridge route where actual tool support depends on selected upstream/local model behavior |
| `CHAT ONLY` | Do not present as a reliable tool-calling route |
| `ON DEVICE` | Direct `local-llm/...`, bypasses Gateway |
| `COMPACT BRIDGE` | Manual `plawie_ndk/local-llm` bridge |

The labels are guardrails, not model IQ scores. Tool success depends on context,
provider support, model formatting, and the model's ability to decide when to
use a tool.

## Catalog Highlights

Examples of current model metadata:

| Model | Context policy | Output policy | Tool policy |
| --- | --- | --- | --- |
| Gemini 3.1 Pro Preview | 1,048,576 | extended safe cap | reliable |
| GPT-5.4 | 1,050,000 | extended safe cap | reliable |
| GPT-4o | 128,000 | standard safe cap | reliable |
| Claude Opus/Sonnet 4.6 | 1,000,000 | extended safe cap | reliable |
| Grok 4 / 4.1 Fast | 1,000,000 / 2,000,000 | extended safe cap | reliable |
| Grok Code Fast 1 | 256,000 | standard safe cap | reliable |
| OpenRouter GPT-OSS 20B Free | 131,072 | compact safe cap | reliable metadata |
| OpenRouter Free Router | 200,000 | compact safe cap | disabled/chat only |
| OpenRouter Auto | 2,000,000 | standard safe cap | variable |
| Kimi K2.6 via OpenRouter | 262,144 | standard safe cap | reliable metadata |
| Groq GPT-OSS routes | 131,072 | compact safe cap | variable; full tools require enough Groq TPM |
| Plawie NDK bridge | 4,096 | 768 | variable |

## Compatibility Aliases

| Legacy ID | Canonical behavior |
| --- | --- |
| `anthropic/claude-opus-4.6` | `anthropic/claude-opus-4-6` |
| `anthropic/claude-sonnet-4.6` | `anthropic/claude-sonnet-4-6` |
| `xai/grok-4.3` | `xai/grok-4` |
| `groq/llama-3.3-70b-versatile` | `groq/openai/gpt-oss-120b` |
| `groq/llama-3.1-405b` | `groq/openai/gpt-oss-120b` |
| `groq/llama-3.1-8b-instant` | `groq/openai/gpt-oss-20b` |
| any `ollama/...` | `openrouter/openai/gpt-oss-20b:free` |

## Runtime Guardrails

Implemented guardrails:

- Setup exposes cloud Gateway providers only.
- Chat/settings block known cloud models when the provider key is missing.
- Stale `ollama/...` preferences migrate through catalog canonicalization.
- Local LLM page is NDK/offline focused.
- Direct `local-llm/...` bypasses Gateway token lookup, WebSocket setup, and
  Gateway Talk.
- Known provider config entries are healed with catalog `contextWindow` and
  `maxTokens` values.
- Cloud chat stays on Gateway by default so tools, node context, sessions,
  dashboard, and diagnostics remain aligned.

## NDK Gateway Bridge

The bridge registers:

```text
Provider ID: plawie_ndk
Model ID:    plawie_ndk/local-llm
Base URL:    http://127.0.0.1:11435/v1
API field:   openai-completions
```

It is started manually from Local LLM. `configureNdkGatewayBridge()` writes a
Gateway provider block using `ModelProviderCatalog.mergeProviderConfig()` so the
bridge always has the correct API type, base URL, context window, and max token
cap.

Under native Gateway ownership, the same bridge provider is consumed by
OpenClaw running under `libnode.so` on `18789`. Under PRoot rollback ownership,
the same provider is consumed by PRoot Gateway. The bridge itself stays a Dart
service on `11435` and should not depend on PRoot.

Bridge tool-call behavior is implemented:

1. Gateway sends OpenAI-style messages and `tools`.
2. Bridge compacts context and converts tools to native fllama `Tool` objects.
3. Local fllama yields OpenAI-shaped `tool_calls`.
4. Bridge returns those tool calls to Gateway.
5. Gateway executes the tool and sends the result back.
6. Bridge preserves the result and asks the model to answer from it.

It remains a manual route because small local models may still be unreliable at
complex tool planning.

## Release Checklist

- Fresh install with Gemini/Claude/OpenAI/Grok/OpenRouter/Groq selected.
- App update with existing `ollama/...` preference.
- Chat cloud model with missing key blocks clearly.
- Settings model picker lists catalog models plus active direct local model.
- Local LLM page shows NDK/offline guidance.
- Direct local model can chat without Gateway.
- Direct local model can chat when native Gateway is stopped or PRoot is absent.
- Gateway bridge starts only after explicit user action.
- Gateway bridge works under native Gateway ownership when the bridge server is
  running on `11435`.
- Bridge tool test shows either a real Gateway tool round trip or a clear model
  limitation.

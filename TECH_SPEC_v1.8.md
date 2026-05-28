# Plawie Technical Specification

Last updated: 2026-05-28

This replaces the older v1.8 roadmap that described a PRoot `llama-server`
architecture. That server path is not current. The app now uses OpenClaw
Gateway for agent workflows and native fllama for local inference.

## Product Architecture

```text
Flutter Android app
  UI: chat, avatar, voice, settings, Local LLM
  Services: GatewayService, LocalLlmService, NdkGatewayBridgeService
  Native bridge: Android capabilities and foreground lifecycle

PRoot Linux userland
  Node.js
  OpenClaw Gateway on 127.0.0.1:18789
  skills, tools, sessions, dashboard, provider config

Native local inference
  fllama / llama.cpp NDK
  GGUF models in app-accessible storage
```

## Model Lanes

| Lane | Model IDs | Runtime | Purpose |
| --- | --- | --- | --- |
| Cloud full Gateway | `google/...`, `anthropic/...`, `openai/...`, `xai/...`, `openrouter/...`, `groq/...` | OpenClaw Gateway | Full tools, skills, sessions, Talk, dashboard |
| Direct local NDK | `local-llm/...` | fllama NDK | Offline/private chat and local Dart actions |
| Compact bridge | `plawie_ndk/local-llm` | Gateway to Dart bridge to fllama | Experimental local model in Gateway tool loop |

Cloud models use Gateway by default. Direct HTTP fast cloud chat is not the
release default because it bypasses tools and diagnostics.

## Model Policy

`lib/services/model_execution_policy.dart` defines:

- Execution lanes.
- Tool policy labels.
- Known context windows for exposed install/chat models.
- Safe per-request output caps.
- NDK bridge context and history caps.
- Compact bridge prompts.

`lib/services/model_provider_catalog.dart` applies those values to provider
defaults and heals existing provider config. Setup, chat, and settings should
read from this catalog rather than hardcoding model lists.

The policy's role is routing and budget safety. It does not promise that every
model with context can use tools well. Tool success depends on model capability,
prompt size, provider support, and actual tool-call behavior.

## Provider Defaults

The catalog currently exposes:

- Google Gemini.
- Anthropic Claude.
- OpenAI GPT.
- xAI/Grok.
- OpenRouter, including a specific free GPT-OSS route, auto/router choices, and
  Kimi K2.6.
- Groq Llama routes.
- Manual `plawie_ndk/local-llm` bridge.

Known models carry `contextWindow` and `maxTokens`. This prevents provider
adapters from requesting output budgets that consume the full context window.
OpenRouter Auto is written as provider model id `openrouter/auto`, not bare
`auto`, so stale config is healed to the same router id the Gateway executes.
Groq routes use compact output caps and `VARIABLE TOOLS` labeling because
practical TPM limits can reject the full Gateway tool payload before the model's
advertised context window is exhausted.

## Local LLM

Direct local:

```text
local-llm/... -> LocalLlmService.chat() -> fllamaInference()
```

Bridge local:

```text
Gateway provider plawie_ndk
  -> NdkGatewayBridgeService :11435
  -> compact prompt and native fllama tools
  -> yielded OpenAI tool_calls
  -> Gateway executes tools
```

There is no current PRoot `llama-server`, Ollama daemon, LAN Ollama discovery,
or `127.0.0.1:11434` dependency.

## Tools And Skills

Tool ownership is layered:

| Layer | Owner | Config |
| --- | --- | --- |
| Gateway primitives | OpenClaw Gateway | `tools.profile`, `tools.allow`, `tools.deny` |
| npm/OpenClaw skills | OpenClaw skills runtime | Installed/loaded by Gateway |
| Android node capabilities | Plawie node/capability bridge | `gateway.nodes.allowCommands` and port `8765` |
| Direct local tools | Dart | `LocalLlmService` local tool loop |

Device commands such as camera, canvas, haptics, sensors, screen, and flashlight
must not be written into `tools.allow`. They belong to node command declarations
and node allow-command config.

## Voice

Gateway-routed chat should use the OpenClaw Talk contract when configured.
Direct local NDK chat can use local Android/native speech paths because it
bypasses Gateway.

Talk provider configuration is separate from chat provider configuration. A
working OpenRouter/Gemini/etc. chat key does not automatically configure Talk.

## Deprecated Technical Spec Items

The following older v1.8 proposals are no longer active implementation targets:

- PRoot `llama-server` on `:8081`.
- OpenAI vision payloads sent to local `llama-server`.
- PRoot ffmpeg frames into `llama-server`.
- LAN discovery for Ollama or LM Studio as a setup route.
- Ollama local/cloud model sync.

Future multimodal local work should start from fllama's actual multimodal API
and the current direct/bridge lanes, not from the removed HTTP server design.

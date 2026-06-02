# Local LLM Architecture

Last updated: 2026-06-02

## Decision

Plawie local inference is NDK/fllama based. Embedded Ollama and PRoot
`llama-server` paths are legacy incident history, not current architecture.

The PRoot to embedded native Node migration does not remove local LLM support.
Native `libnode.so` replaces the OpenClaw Gateway owner; fllama remains the
on-device inference engine.

| Mode | Prefix | Runtime | Gateway | Intended use |
| --- | --- | --- | --- | --- |
| NDK Direct | `local-llm/...` | fllama / llama.cpp NDK | No | Private/offline chat and local Dart actions |
| Cloud Agent | `google/...`, `anthropic/...`, `openai/...`, `xai/...`, `openrouter/...`, `groq/...` | OpenClaw Gateway | Yes | Full Gateway tools, skills, dashboard, Talk, sessions |
| NDK Gateway Bridge | `plawie_ndk/local-llm` | OpenAI-compatible bridge to fllama | Yes | Manual local-model experiment through Gateway tools |

## Current Local Flow

```text
Flutter Chat
  -> GatewayService.sendMessage()
  -> local-llm prefix detected
  -> LocalLlmService.chat()
  -> fllamaInference()
  -> GGUF model in app storage
```

Important properties:

- No Gateway token lookup.
- No Gateway WebSocket setup.
- No native `libnode.so` dependency.
- No Ollama daemon or `127.0.0.1:11434`.
- No PRoot `llama-server` or `127.0.0.1:8081`.
- Local tools are Dart-side actions with a depth-limited fllama tool loop.
- Costless/offline after the user downloads and activates a GGUF model.

## Context Policy

`lib/services/model_execution_policy.dart` owns shared context and output
budgets. Direct local fllama activation clamps context to a phone-safe 512-4096
range. The bridge advertises a 4096-token context and 768-token output cap to
Gateway so small local models do not receive cloud-scale prompts.

`LocalLlmService` also trims history, preserves assistant `tool_calls`, and
summarizes dropped history before inference.

## NDK Gateway Bridge

The bridge is explicit and manual:

```text
Provider: plawie_ndk
Model:    plawie_ndk/local-llm
Base URL: http://127.0.0.1:11435/v1
```

It replaces the large Gateway system prompt with a compact local prompt, converts
the Gateway `tools` array into native fllama `Tool` objects, and asks
`LocalLlmService.chat(..., yieldToolCalls: true)` to yield tool calls instead of
executing them locally.

With native Gateway ownership, the bridge shape becomes:

```text
OpenClaw Gateway under libnode.so on 18789
  -> provider plawie_ndk/local-llm
  -> http://127.0.0.1:11435/v1
  -> NdkGatewayBridgeService
  -> LocalLlmService / fllama
```

With PRoot rollback ownership, the bridge shape is the same except the Gateway
owner is PRoot. The bridge should not require PRoot; it only requires whichever
Gateway owner is active and the Dart bridge server on `11435`.

When a local model emits tool calls, the bridge returns standard OpenAI
`tool_calls` chunks to Gateway. Gateway executes the actual tool and sends the
tool result back on the next completion request. The bridge preserves that
tool-result context and asks the local model to answer from it.

## Release Boundary

Keep both local routes:

- `local-llm/...` for private/offline direct local chat;
- `plawie_ndk/local-llm` for manual Gateway-to-local-model experiments.

Do not remove fllama, the Local LLM page, or the NDK bridge as part of removing
PRoot. The removal target is the PRoot Gateway runtime and Ubuntu rootfs, not
costless on-device inference.

## Tool Reality

The shared policy system does not exist to promise that every model is good at
tools. It exists to route safely and keep prompt/output budgets realistic. Tool
success still depends on the selected model's instruction following, tool-call
format support, and available context.

## Deprecated

Fresh setup, chat, settings, and Gateway boot must not offer or start:

- Embedded Ollama Local.
- Ollama Cloud through a local daemon.
- `ollama/...` as a normal model choice.
- PRoot `llama-server`.

Remaining `ollama` references are migration/removal guards.

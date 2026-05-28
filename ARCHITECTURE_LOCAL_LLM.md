# Local LLM Architecture

Last updated: 2026-05-28

This document describes the current local-model architecture in Plawie. It
replaces the older PRoot `llama-server`, Node `node-llama-cpp`, and embedded
Ollama plans.

## Current Decision

Local inference is native NDK first:

| Route | Model ID | Runtime | Gateway | Status |
| --- | --- | --- | --- | --- |
| Direct local | `local-llm/...` | `fllama` / llama.cpp NDK | Bypassed | Production offline/private path |
| Gateway bridge | `plawie_ndk/local-llm` | Dart HTTP bridge to `fllama` | Required | Manual experiment with tool-call round trip |
| Ollama / llama-server | `ollama/...`, `:11434`, `:8081` | Legacy PRoot daemon/server | Legacy only | Removed from normal runtime |

The important split is not "local model vs cloud model." The split is
"Gateway-routed agent flow vs direct NDK flow."

## Source Files

| Concern | File |
| --- | --- |
| Context windows and output caps | `lib/services/model_execution_policy.dart` |
| Model IDs, labels, tool policy, provider defaults | `lib/services/model_provider_catalog.dart` |
| Direct local routing | `lib/services/gateway_service.dart` |
| NDK model download/activation/inference | `lib/services/local_llm_service.dart` |
| OpenAI-compatible NDK bridge | `lib/services/ndk_gateway_bridge_service.dart` |
| Local model UI and bridge controls | `lib/screens/management/local_llm_screen.dart` |

## Direct Local Flow

```text
Chat selected model: local-llm/<active-model-id>
  -> GatewayService.sendMessage()
  -> ModelProviderCatalog.isDirectLocalModelId() == true
  -> LocalLlmService.chat(history, userMessage)
  -> fllamaInference(OpenAiRequest)
  -> streamed text back to Flutter chat
```

Properties:

- No OpenClaw Gateway token lookup.
- No Gateway WebSocket setup.
- No Gateway provider config reload.
- No Gateway Talk/TTS call.
- No network required after the GGUF model is downloaded.
- Phone/avatar actions are handled by local Dart tools, not Gateway skills.

## Direct Local Context Packing

`LocalLlmService.chat()` builds the request:

1. Chooses explicit local tools for the turn or uses tools passed by the bridge.
2. Builds a compact system prompt with the attached tool names.
3. Trims history with `_trimHistory()`.
4. Preserves assistant messages that contain `tool_calls`.
5. Converts `assistant`, `tool`, `function`, `system`, and `user` history maps
   into native `fllama` `Message` objects.
6. Calls `_runChatTurn()`.

The active fllama context is clamped between 512 and 4096 tokens on activation.
The history budget reserves room for response tokens, tool schemas, and chat
template overhead. Tiny and small models get stricter caps so the user sees a
short answer instead of a context-overflow crash.

## Direct Local Tool Loop

`_runChatTurn()` sends native tools to fllama using `ToolChoice.auto`.

When streaming chunks include `tool_calls`:

1. The service accumulates the call name, arguments, and id across chunks.
2. If the finish reason is not `tool_calls`, the stream closes normally.
3. If tool calls are present and `yieldToolCalls` is false, Dart dispatches the
   local tool.
4. The assistant tool-call message and tool result messages are appended.
5. `_runChatTurn()` recurses with a depth limit of 3.

This is the production path for private local actions.

## NDK Gateway Bridge

The bridge is an OpenAI-compatible local provider:

```text
Provider: plawie_ndk
Model:    plawie_ndk/local-llm
Base URL: http://127.0.0.1:11435/v1
```

Endpoints:

```text
GET  /health
GET  /v1/health
GET  /v1/models
POST /v1/chat/completions
```

The bridge starts only when the user starts it from Local LLM. `GatewayService`
can then write a `plawie_ndk` provider block with:

```text
api: openai-completions
baseUrl: http://127.0.0.1:11435/v1
contextWindow: 4096
maxTokens: 768
```

## Bridge Context And Tool Transport

The Gateway sends cloud-style requests: a large system prompt, conversation
history, and an OpenAI `tools` array. Small local models cannot use that raw
prompt. `NdkGatewayBridgeService` therefore:

- Parses the `tools` array into native fllama `Tool` objects.
- Replaces the large system prompt with
  `ModelExecutionPolicy.ndkBridgeCompactPrompt(...)`.
- Preserves recent assistant `tool_calls`.
- Preserves matching `tool` / `function` results and adds missing tool names
  from the call id when possible.
- Truncates tool result content to the bridge cap.
- Keeps only the latest bounded message slice.

The bridge calls:

```dart
LocalLlmService().chat(
  history,
  userMessage,
  tools: tools,
  yieldToolCalls: true,
)
```

With `yieldToolCalls: true`, `LocalLlmService` does not execute the tool locally.
It emits a sentinel containing OpenAI-shaped `tool_calls`. The bridge converts
that sentinel into a standard OpenAI response:

- Streaming: `chat.completion.chunk` with `delta.tool_calls` and
  `finish_reason: tool_calls`.
- Non-streaming: `chat.completion` with `message.tool_calls` and
  `finish_reason: tool_calls`.

The Gateway receives that response, executes the real Gateway tool, and sends a
follow-up completion request containing the tool result. The bridge then asks
the local model to answer from that result.

## What The Bridge Does Not Do

- It does not execute Gateway tools in Dart.
- It does not send the full Gateway system prompt to the local model.
- It does not make small local models equal to cloud models.
- It does not run by default during setup or returning-user startup.

Tool behavior remains model-dependent. The bridge gives the model the transport
path for tool calls; it cannot make a 1.5B model reliably plan complex
multi-step agent work.

## Storage

The active local model path is a host Android filesystem path read by fllama.
PRoot paths such as `/root/.openclaw/models` are legacy compatibility context,
not a requirement for fllama itself.

## Legacy Paths

The following are historical and should not be revived without a fresh design
review:

- PRoot `llama-server` binary download or compile.
- PRoot `node-llama-cpp` HTTP server.
- Ollama daemon install/start/stop/sync.
- `127.0.0.1:11434` for normal chat.
- `127.0.0.1:8081` for normal chat.

## Verification

Minimum checks:

1. Direct local `local-llm/...` chat streams text with Gateway stopped.
2. Direct local tool request either performs a supported local action or returns
   a precise local-model limitation.
3. Starting the bridge opens `127.0.0.1:11435`.
4. `/v1/health` reports `runtime: fllama` and the active model id.
5. `plawie_ndk/local-llm` Gateway chat returns text through the Gateway lane.
6. A simple tool request through the bridge returns Gateway tool-call/result
   evidence when the selected local model emits a valid tool call.

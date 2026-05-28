# Local LLM Incident Report

Last updated: 2026-05-28

## Status

Resolved and superseded. The original March 2026 incident investigated a PRoot
`llama-server` local LLM design. That design is no longer current.

Current local architecture:

| Path | Runtime | Status |
| --- | --- | --- |
| Direct NDK | `LocalLlmService` -> fllama / llama.cpp NDK | Production local path |
| NDK Gateway bridge | `NdkGatewayBridgeService` on `127.0.0.1:11435` | Manual experiment with tool-call round trip |
| PRoot `llama-server` | Port `8081` | Removed from normal architecture |
| Embedded Ollama | Port `11434` | Removed from normal architecture |

## Original Incident Summary

The old local LLM plan tried to run an OpenAI-compatible local model server
inside PRoot and route Gateway requests to it. Multiple blockers made that path
unsuitable for phones:

- No reliable prebuilt Android/ARM64 `llama-server` asset.
- PRoot source builds were slow, fragile, and storage heavy.
- Shell execution contracts made install scripts easy to break.
- Corrupt binary stubs could pass weak `test -x` checks.
- Long downloads/clones were poor mobile UX.
- Running another local inference daemon beside Flutter, PRoot, OpenClaw, and
  the Android node increased memory pressure.

## Resolution

The app moved local inference into the Flutter process with fllama:

```text
local-llm/... -> LocalLlmService.chat() -> fllamaInference()
```

This removed:

- PRoot inference server lifecycle.
- Local HTTP server dependency for direct offline chat.
- `llama-server` binary install/compile.
- Ollama daemon install/start/stop/sync.

## Current Direct NDK Behavior

`LocalLlmService` now:

- Downloads and activates GGUF models for fllama.
- Clamps context to a phone-safe 512-4096 token range.
- Builds compact local prompts.
- Trims and summarizes history.
- Preserves assistant `tool_calls` and tool result messages.
- Uses native fllama tools for local actions.
- Recurses through local tool results with a depth limit of 3.

## Current Bridge Behavior

The bridge exists because the Gateway expects an OpenAI-compatible provider:

```text
Gateway -> http://127.0.0.1:11435/v1/chat/completions -> fllama
```

Unlike the old PRoot server plan, the bridge:

- Runs in Dart.
- Requires an already-ready fllama model.
- Replaces the large Gateway system prompt with a compact prompt.
- Converts Gateway `tools` into fllama native `Tool` objects.
- Uses `yieldToolCalls: true` so fllama tool calls go back to Gateway.
- Preserves Gateway tool results in the follow-up request.

Gateway remains the executor for bridge-routed tools.

## Lessons Kept

- Do not put local inference on the Gateway boot path.
- Do not assume a local server exists because a port or binary name is present.
- Keep output and context budgets explicit.
- Treat mobile memory pressure as a first-class architecture constraint.
- Keep direct local, bridge local, and cloud Gateway behavior visibly distinct.

## What Not To Reintroduce

- PRoot `llama-server` on port `8081`.
- Ollama daemon on port `11434`.
- Build-from-source model servers during setup.
- Hidden local daemon downloads.
- Cloud-scale Gateway prompts sent raw to small local models.

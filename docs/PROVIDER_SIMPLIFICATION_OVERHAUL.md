# Provider Simplification Overhaul

Last updated: 2026-05-28

## Decision

Plawie no longer presents embedded Ollama Local or Ollama Cloud as normal model
routes. The production contract is:

| Mode | Route | Runtime | Gateway | User promise |
| --- | --- | --- | --- | --- |
| Cloud Agent Mode | `google/`, `anthropic/`, `openai/`, `xai/`, `openrouter/`, `groq/` | OpenClaw Gateway | Yes | Full Gateway tools, skills, dashboard, BYO provider key |
| Private Offline Mode | `local-llm/...` | NDK fllama | No | Offline/private chat and direct local actions |
| Compact Bridge | `plawie_ndk/local-llm` | Gateway to fllama via `:11435` | Yes | Manual local-model experiment through Gateway tools |
| Legacy Ollama | `ollama/...` | Removed daemon route | No | Hidden from UI; stale prefs migrate |

## What Changed

- Provider and model metadata moved into `ModelProviderCatalog`.
- Context windows, output caps, and bridge limits moved into
  `ModelExecutionPolicy`.
- Setup exposes cloud Gateway providers only.
- Chat/settings use catalog models and capability labels.
- Known provider config is healed with safe `contextWindow` and `maxTokens`.
- Cloud chat stays on Gateway by default.
- Direct local NDK bypasses Gateway.
- The manual NDK bridge now has a real OpenAI-compatible tool-call round trip.

## Why

The old Ollama path created too many overlapping meanings:

- Local daemon vs cloud provider.
- Full Gateway agent vs lightweight local chat.
- Model context vs output token budget.
- Tool transport vs model ability to use tools.

The current structure makes the contract explicit. Users choose between full
Gateway power, private offline NDK, or the manual compact bridge experiment.

## Implementation Checklist

- [x] Remove Ollama Local and Ollama Cloud from first-run setup.
- [x] Remove Ollama models from chat/settings default pickers.
- [x] Migrate stale `ollama/...` preferences.
- [x] Centralize provider/model metadata.
- [x] Add safe output caps for exposed cloud models.
- [x] Add capability labels: `FULL TOOLS`, `VARIABLE TOOLS`, `CHAT ONLY`.
- [x] Keep cloud traffic on Gateway by default.
- [x] Keep `local-llm/...` as direct fllama.
- [x] Add manual `plawie_ndk/local-llm` bridge.
- [x] Bridge OpenAI tool calls back to Gateway instead of consuming them locally.

## Verification Matrix

| Scenario | Expected result |
| --- | --- |
| Fresh install, cloud provider selected | Gateway starts without Ollama |
| Returning user with stale `ollama/...` preference | App migrates to catalog fallback |
| Chat cloud model with missing key | User gets clear API-key guidance |
| Cloud model with tools | Request stays on Gateway |
| Direct NDK model active | Chat bypasses Gateway |
| NDK bridge active | Gateway routes to `plawie_ndk/local-llm` on `:11435` |
| Bridge tool request | Gateway receives OpenAI `tool_calls` and executes the tool if local model emits a valid call |

## Non-Goals

- Do not make the NDK bridge the default local route.
- Do not reintroduce embedded Ollama daemon setup.
- Do not label router/free models as reliable tool callers unless the specific
  selected upstream model is known.
- Do not let provider output caps grow to the full context window.

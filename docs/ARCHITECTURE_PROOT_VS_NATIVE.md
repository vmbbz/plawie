# PRoot vs Native Architecture

Last updated: 2026-05-23

## Current Split

| Layer | Runtime | Responsibility |
| --- | --- | --- |
| PRoot / OpenClaw | Node.js Gateway | Skills, tools, dashboard, sessions, cloud model providers |
| Native Android / Flutter | App + foreground service | UI, lifecycle, capability bridge, node pairing support |
| NDK fllama | llama.cpp native library | Private/offline local model inference via `local-llm/...` |

## Key Rule

Gateway stability comes first. Local inference must not be part of Gateway boot,
pairing, dashboard readiness, or returning-user attach.

## Provider Direction

- Cloud Agent Mode: OpenClaw Gateway routes to Gemini, Claude, OpenAI, Grok/xAI,
  OpenRouter, or Groq using user-provided API keys.
- Private Offline Mode: fllama runs GGUF models directly inside the app and
  bypasses Gateway.
- Embedded Ollama daemon paths are removed from normal runtime code because the
  runtime is too large and memory-heavy for the launch target. Remaining
  `ollama` references are migration/removal guards for returning installs.

## Future Exploration

A native OpenAI-compatible HTTP bridge on `127.0.0.1:11435` can be started from
Local LLM as an explicit experiment. It registers provider `plawie_ndk` with
model `plawie_ndk/local-llm`. It must prove streaming compatibility, tool-call
compatibility, and lifecycle safety before becoming a production route.

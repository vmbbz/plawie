# Audit: Gateway Full Runtime

Last updated: 2026-05-28

## Status

Historical scratch file replaced with current audit notes. The previous content
was a pasted bootstrap code sketch, not a reliable architecture document.

## Current Gateway Runtime Contract

- OpenClaw Gateway runs in PRoot on `127.0.0.1:18789`.
- Android capability bridge runs on `127.0.0.1:8765`.
- Cloud models stay on the Gateway lane by default.
- Direct local NDK models use `local-llm/...` and bypass Gateway.
- Manual NDK Gateway bridge uses `plawie_ndk/local-llm` on
  `127.0.0.1:11435/v1`.
- Ollama `11434` and PRoot `llama-server` `8081` are not production
  dependencies.

## Audit Checks

1. Gateway health and operator WebSocket complete before node pairing.
2. Default skills and tool discovery complete before releasing node auto-connect.
3. Provider config contains catalog-safe `contextWindow` and `maxTokens` values.
4. `tools.allow` contains only official groups/stable primitives.
5. Device commands are declared through node command policy, not `tools.allow`.
6. Direct local chat works without Gateway.
7. Bridge chat appears only after the user starts the bridge.

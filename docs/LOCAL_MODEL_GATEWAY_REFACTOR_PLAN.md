# Local Model Gateway Refactor Plan

Last updated: 2026-05-23

## Status

This older Ollama-centric refactor plan has been superseded by the provider
simplification overhaul.

Current decision:

- Cloud Agent Mode uses OpenClaw Gateway with BYO provider keys.
- Private Offline Mode uses direct NDK/fllama via `local-llm/...`.
- Embedded Ollama Local and Ollama Cloud are hidden from production UI.
- Stale `ollama/...` preferences migrate to the safe cloud fallback.
- A future NDK HTTP bridge may be researched, but it is not enabled by default.

Authoritative docs:

- `docs/PROVIDER_SIMPLIFICATION_OVERHAUL.md`
- `docs/MODEL_PROVIDER_AND_HELP_ROADMAP.md`
- `docs/LOCAL_LLM_ARCHITECTURE.md`
- `docs/OPENCLAW_BOOT_SEQUENCE.md`

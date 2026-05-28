# Local Model Gateway Refactor Outcome

Last updated: 2026-05-28

## Status

This older Ollama-centric refactor plan is complete and superseded by the
current model execution architecture.

Current outcome:

- Cloud Agent Mode uses OpenClaw Gateway with BYO provider keys.
- Private Offline Mode uses direct NDK/fllama via `local-llm/...`.
- A manual NDK HTTP bridge exists at `127.0.0.1:11435` as provider
  `plawie_ndk`, model `plawie_ndk/local-llm`.
- The bridge now supports OpenAI-style tool-call round trip: local fllama yields
  tool calls, Gateway executes them, and tool results are sent back into the
  next bridge turn.
- Embedded Ollama Local and Ollama Cloud are hidden from production UI.
- Stale `ollama/...` preferences migrate to a safe catalog model.

## Current Authoritative Docs

- `ARCHITECTURE_REPORT.md`
- `ARCHITECTURE_LOCAL_LLM.md`
- `docs/LOCAL_LLM_ARCHITECTURE.md`
- `docs/MODEL_PROVIDER_AND_HELP_ROADMAP.md`
- `docs/OPENCLAW_BOOT_SEQUENCE.md`

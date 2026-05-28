# PRoot vs Native Architecture

Last updated: 2026-05-28

Native Gateway replacement research now lives under
`docs/native-node-gateway/`. This document describes the current production
split; the research track documents the phased migration path and guardrails.

## Current Split

| Layer | Runtime | Responsibility |
| --- | --- | --- |
| PRoot / OpenClaw | Ubuntu userland + Node.js Gateway | Skills, tools, sessions, dashboard, cloud provider routing |
| Native Android / Flutter | App process + foreground service | UI, lifecycle, capability bridge, pairing orchestration |
| NDK fllama | llama.cpp native library | Private/offline local model inference |
| NDK Gateway bridge | Dart HTTP server on `127.0.0.1:11435` | Optional OpenAI-compatible bridge from Gateway to fllama |

## Key Rule

Gateway stability comes first. Local inference and the NDK bridge must not be
part of Gateway boot, pairing, dashboard readiness, or returning-user attach.

## Model Routes

| Route | Model IDs | Dependency |
| --- | --- | --- |
| Cloud full Gateway | cloud provider IDs | Requires Gateway and provider credentials |
| Direct local NDK | `local-llm/...` | Requires active fllama model, bypasses Gateway |
| Compact NDK bridge | `plawie_ndk/local-llm` | Requires Gateway, running bridge, and active fllama model |
| Legacy Ollama | `ollama/...` | Migrated away; not a normal route |

## Why The Split Exists

OpenClaw Gateway carries the heavy agent context: tools, sessions, skills,
dashboard, Talk, and node actions. fllama carries local GGUF inference inside
the app process. Combining them naively would send cloud-scale system prompts
to small on-device models and create memory pressure on phones.

The bridge is the controlled exception. It keeps Gateway in charge of tools but
compacts the prompt before forwarding to fllama. It is useful for experiments,
not for hiding the difference between a small local model and a cloud agent
model.

## Deprecated Paths

The app no longer treats these as production architecture:

- Embedded Ollama daemon in PRoot.
- Ollama Cloud via local daemon proxy.
- PRoot `llama-server` on port `8081`.
- Node `node-llama-cpp` HTTP server in PRoot.

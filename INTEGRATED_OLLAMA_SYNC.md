# Integrated Ollama Sync Path

Last updated: 2026-05-28

## Status

Superseded. This file used to describe an embedded Ollama daemon running inside
the PRoot Linux environment. That is no longer the current Plawie architecture.

## Current Runtime

| Need | Current implementation |
| --- | --- |
| Cloud agent chat | OpenClaw Gateway in PRoot routes to configured cloud providers |
| Private local chat | `fllama` / llama.cpp NDK reads GGUF models directly in the app process |
| Local model through Gateway | Manual `plawie_ndk` bridge on `127.0.0.1:11435/v1` |
| Tool execution | Gateway executes cloud/bridge tool calls; direct local executes local Dart tools |

## What Was Removed From The Normal Path

- Ollama daemon startup.
- Ollama model sync/manifest creation.
- `POST /api/create` Modelfile registration.
- `127.0.0.1:11434` as a required local provider.
- Hidden Ollama Local or Ollama Cloud choices in setup/chat/settings.

## Why It Changed

The Ollama daemon created a second local inference runtime beside Flutter,
PRoot, OpenClaw, and the Android node. On phones, that added memory pressure,
large downloads, unclear UX, and output/context behavior that was hard to make
safe for small models.

Current local inference uses fllama directly. It avoids a daemon, avoids the
Ollama REST proxy, and lets Plawie apply explicit context/output caps from
`lib/services/model_execution_policy.dart`.

## Migration Rule

Any stale `ollama/...` preference should be canonicalized to a safe catalog
model by `ModelProviderCatalog.canonicalizeModelId()`. New code should not add
Ollama routes back to normal setup, chat, or settings without a fresh design
review.

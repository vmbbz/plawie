# Native Provider Stream Parser Parity

Date: 2026-05-30

Status: explicit diagnostics canary

## Purpose

This phase proves that embedded Node can parse OpenAI-compatible provider
streams and normalize provider stream failure surfaces before native runtime
selection begins.

The production PRoot Gateway remains primary on `127.0.0.1:18789`. Embedded
Node remains isolated on `127.0.0.1:18790`.

## Canary Entry Point

Flutter exposes a hidden chat prefix:

```text
/native-stream-parity <message>
```

That prefix sends a production-shaped `chat.send` frame directly to embedded
Node:

```text
POST /gateway/chat-provider-stream-parser-parity-stream
```

The canary runs deterministic parser fixtures first, then performs one tiny
OpenRouter stream using the same native parser. When the UI is on
`openrouter/auto`, the canary uses the catalog's known OpenRouter free fallback
model so the test validates parser behavior rather than router selection.

## Parser Fixtures

The endpoint checks these parser surfaces before touching the provider network:

| Fixture | Proof |
| --- | --- |
| `openai-compatible-sse-chunks` | Parses role-only chunks, text chunks, finish reasons, `[DONE]`, and malformed chunk warnings |
| `provider-error-raw-forwarding` | Preserves raw provider error bodies while also exposing normalized error fields |
| `provider-timeout-normalization` | Converts abort/timeout failures into a stable `provider_timeout` frame |
| `provider-cancellation-contract` | Confirms cancellation maps to a cancelled frame with provider/tool execution disabled |

## Live Stream Proof

The live portion uses:

```text
stream: true
max_tokens: 32
temperature: 0
```

The expected success path is:

```text
ack
parser_fixture
error_fixture
timeout_fixture
cancellation_fixture
provider_request
provider_call_started
provider_response
delta
live_parser_summary
end
```

Provider errors must surface as `provider_error` with `rawProviderError`
preserved.

## Pass Condition

A `/native-stream-parity` turn passes when:

- The ACK hash matches the local redacted Dart frame hash.
- All deterministic fixtures report `parityOk: true`.
- The live provider response is HTTP 200.
- Native emits at least one parsed provider `delta`.
- The live parser summary reports `liveParityOk: true`.
- The final `end` reports `ok: true`.
- No Android/OpenClaw tool execution runs.

## Next Gate

The next phase is tool-call plan capture with execution still disabled. Native
may inspect provider tool-call intent, but it must not invoke Android tools,
OpenClaw tools, shell commands, browser automation, or production skills yet.

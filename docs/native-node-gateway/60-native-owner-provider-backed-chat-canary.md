# Native Owner Provider-Backed Chat Canary

This gate proves native Node can briefly own the production Gateway port
(`18789`), make one bounded OpenRouter chat-completions stream, return a real
chat response, and still keep tool schemas plus tool execution disabled.

This is stricter than the earlier live-provider plumbing gate. Provider errors
are still surfaced raw for diagnostics, but this gate is only green when the
provider returns `200`, at least one text delta arrives, no tool schema is sent,
and PRoot is restored afterward.

## Runtime Flow

1. Diagnostics stop native smoke on `18790`.
2. PRoot must be current runtime and healthy on `18789`.
3. Diagnostics stop PRoot and wait for `18789` to release.
4. Native starts on `18789` in production-port canary mode.
5. Native accepts a production-shaped `chat.send` frame at
   `/gateway/chat-provider-live-canary-stream`.
6. Native builds a tiny OpenRouter stream request with `max_tokens <= 32` and
   no tool schema fields.
7. Native performs exactly one provider call and parses streamed deltas.
8. Tool execution remains disabled for the full turn.
9. Native stops, the port is released, PRoot restarts, and native smoke is
   restored.

## Diagnostic API

```http
POST /api/native-gateway/production-provider-backed-chat-canary
```

Example:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production provider-backed chat canary with tool execution disabled"
}
```

## Hidden Chat Commands

```text
/native-chat-owner
/native-production-chat
/native-provider-chat-owner
/native-provider-backed-chat-owner
native-chat-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-provider-backed-chat-canary
mode: native-production-port-provider-backed-chat-with-tools-disabled-rollback
providerBackedChatCanaryOk: true
providerBackedChatOk: true
chatResponseOk: true
toolExecutionDisabledOk: true
requestHasToolSchemas: false
providerRequestOk: true
providerCallStartedOk: true
providerResponseOk: true
statusCode: 200
deltaCount: >0
textChars: >0
rawProviderErrorForwarded: false
postLiveGuardOk: true
rollbackHealthOk: true
nativeSmokeRestored: true
```

## Why This Matters

The previous gates proved owner handoff, parser parity, tool planning,
synthetic dispatch, bridge dry-runs, and three bounded bridge execution
allowlists. This gate proves native can now do the real provider-backed chat
part while still refusing tool execution. That separates "native can answer"
from "native can act", which keeps the promotion path reversible.

Next gate: production-port native chat response UI canary with PRoot rollback.

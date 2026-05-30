# Direct Native Canary Dry-Run

## Status

Implemented behind diagnostics flags. Production chat still routes through the
PRoot Gateway on `127.0.0.1:18789`.

## Purpose

The direct native canary lane sends real production-shaped `chat.send` frames to
embedded Node on `127.0.0.1:18790` without letting native answer the user,
execute tools, or call providers. This proves native can receive the same frame
dialect over HTTP while remaining parse-only.

## Endpoint

`POST /gateway/chat-send-canary`

The endpoint accepts the same redacted-safe `chat.send` envelope already used by
the shadow dry-run parser:

- `type: "req"`
- `method: "chat.send"`
- `id`
- `params.sessionKey`
- `params.message`
- `params.idempotencyKey`
- `params.timeoutMs`

Successful responses use HTTP `202` and include:

- `source: "direct-canary"`
- `canaryMode: "direct-dry-run"`
- `directCanary: true`
- `acceptedForRouting: false`
- `acceptedForQueue: true`
- `queuedForDryRun: true`
- `queueStatus: "parsed_disabled"`
- `providerCallsEnabled: false`
- `executionEnabled: false`
- an `ack` with the native session/run IDs and redacted metadata hash

## Dart Switch

The app only forwards real turns to this direct lane when built with:

```text
--dart-define=PLAWIE_NATIVE_GATEWAY_DIRECT_CANARY_DIAGNOSTICS=true
```

The forwarding is fire-and-forget. It does not block the production PRoot
request and does not alter the user-visible response stream.
Direct canary and shadow dry-run dedupe in separate native diagnostic lanes, so
the same production frame can be observed by both without false duplicate
marking.

Expected live log:

```text
[NATIVE-CANARY-DIRECT] ack: {"ok":true,"parsed":true,"route":"disabled","source":"direct-canary","canaryMode":"direct-dry-run","directCanary":true,...}
```

## Safety Gate

This phase is still not runtime selection. Native remains disallowed from:

- starting OpenClaw as the primary Gateway
- routing chat
- calling providers
- executing tools or skills
- replacing PRoot responses

Promotion to the next phase requires clean side-by-side live logs:

- PRoot accepts and completes the visible turn.
- Native shadow parity reports no metadata differences.
- Native dry-run ACK is queue-backed and route-disabled.
- Native direct canary ACK is queue-backed and route-disabled.

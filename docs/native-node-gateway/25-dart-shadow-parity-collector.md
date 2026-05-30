# Dart Shadow Parity Collector

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Result

Plawie's production PRoot sender path now has a diagnostics-only observer for
the outbound `chat.send` frame. It does not change routing and does not wait for
native Node.

The hook lives immediately before `GatewayConnection.sendRequest(...)` in
`GatewayService.sendMessage()`, after Plawie has attached the real mobile-node
tool context and before the PRoot Gateway receives the frame.

## Safety Contract

The observer is disabled unless one of these compile-time flags is true:

- `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS`
- `PLAWIE_NATIVE_GATEWAY_SHADOW_PARITY_DIAGNOSTICS`

When disabled, production behavior is unchanged.

When enabled, it:

- computes a redacted local metadata shape from the real Dart `chat.send` frame;
- logs counts, booleans, enum-like fields, tool-hint names, and a metadata hash;
- does not log raw user text;
- does not persist raw user text;
- does not route chat to native Node;
- optionally posts the frame to embedded Node only if the diagnostic probe is
  already running on `127.0.0.1:18790`;
- compares the embedded parser response against the local redacted shape;
- logs only hash and field-name differences.

If embedded Node is not running, the observer logs a throttled skip and the PRoot
chat send continues normally.

## Compared Fields

The local and native parser compare:

- request shape: `openclaw-ws-rpc-chat-send`;
- frame type and method;
- request id presence;
- params presence;
- session key;
- message character count;
- idempotency-key presence;
- timeout value;
- mobile-node context presence;
- extracted mobile node handle;
- notification-listing disabled guard;
- known mobile tool hints;
- `looksLikeProductionChatSend`;
- hard safety flags: `acceptedForRouting: false`,
  `providerCallsEnabled: false`, `executionEnabled: false`.

## Device Verification

The diagnostic startup self-test now runs the same observer while embedded Node
is alive. It requires a clean local-vs-native metadata match before declaring
embedded Node diagnostics passed.

This means the parser is tested both directly through `/gateway/ws-frame-shape`
and through the same Dart observer that production chat will use when the
diagnostic flag is enabled.

## Next Gate

Use this collector during real PRoot chat turns and capture a short diagnostic
trace:

- one normal text prompt;
- one avatar gesture request;
- one camera/device request;
- one provider error/rate-limit turn if available.

The trace should contain only redacted parity logs, not raw prompts. Native
routing remains disabled.

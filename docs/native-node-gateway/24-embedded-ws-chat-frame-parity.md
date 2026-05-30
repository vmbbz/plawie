# Embedded WebSocket Chat Frame Parity

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Result

The embedded Node lane can now parse the production WebSocket RPC frame shape
Plawie uses for cloud/tool-capable chat:

```json
{
  "type": "req",
  "method": "chat.send",
  "id": "...",
  "params": {
    "sessionKey": "main",
    "message": "...",
    "idempotencyKey": "...",
    "timeoutMs": 300000
  }
}
```

This is a shape probe only. The embedded lane still does not open a Gateway
WebSocket, does not start OpenClaw, does not route chat, does not call providers,
and does not execute tools.

## Probe Endpoint

`POST /gateway/ws-frame-shape` on `127.0.0.1:18790` reads a bounded JSON body
and returns:

- frame type and method;
- request id presence;
- session key;
- message length;
- idempotency-key presence;
- timeout value;
- whether Plawie's private mobile-node routing context is attached;
- the extracted gateway node handle;
- known mobile tool hints present in the private context;
- safety flags: `acceptedForRouting: false`, `providerCallsEnabled: false`,
  and `executionEnabled: false`.

## Device Verification

The diagnostic build posts a canary `chat.send` frame shaped like
`GatewayService.sendMessage()`:

- `type: req`;
- `method: chat.send`;
- `sessionKey: main`;
- `timeoutMs: 300000`;
- private `<plawie_mobile_tool_context>` attached;
- `mobileNodeHandle: OpenClaw Mobile`;
- hints for `camera_snap`, `avatar.gesture`, `haptic.vibrate`, and
  `notifications.list`.

The embedded lane returns `looksLikeProductionChatSend: true` while keeping
`acceptedForRouting: false`.

## Why This Gate Matters

The earlier `/v1/chat/completions` probe matches OpenAI-compatible HTTP
transport. Plawie's current production cloud/tool lane is stricter: it sends
`chat.send` over the Gateway WebSocket so the agent loop receives session,
tool, node, and mobile routing context.

This gate proves native Node can recognize that production frame before it is
trusted to run any part of the frame.

## Next Gate

Add a shadow parity collector that records production PRoot frame metadata from
the Dart sender path and compares it to the embedded parser output. The
collector should store counts and hashes only, not raw user messages, and must
remain diagnostics-gated.

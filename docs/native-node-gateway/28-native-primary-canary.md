# Native Primary Canary Dry-Run

## Status

Implemented behind diagnostics flags. This is still not production routing.

## Purpose

The primary native canary lets the chat UI send an explicit test turn directly
to embedded Node on `127.0.0.1:18790` instead of sending that turn through
PRoot. Native still only parses and ACKs the `chat.send` frame:

- no provider calls
- no tool execution
- no OpenClaw process start
- no replacement assistant answer

This proves the Flutter UI can speak to the embedded Node chat-frame lane
without depending on PRoot's WebSocket/session queue.

## Activation

Build with:

```text
--dart-define=PLAWIE_NATIVE_GATEWAY_PRIMARY_CANARY_DIAGNOSTICS=true
```

Then send a chat message with either prefix:

```text
/native-canary hello from the UI
/native hello from the UI
```

The prefix is removed before the frame is built. Normal messages still use the
production PRoot Gateway.

## Expected UI Result

The visible chat response is a structured dry-run ACK showing:

- `parsed: true`
- `route: disabled`
- `queue: parsed_disabled`
- `hashMatches: true`
- native session/run IDs
- message character count
- redacted mobile tool hints, if present

Expected diagnostics:

```text
[NATIVE-PRIMARY-CANARY] -> Sending directly to embedded Node (routing disabled)
[NATIVE-PRIMARY-CANARY] ack: {"ok":true,"parsed":true,"route":"disabled",...}
[NATIVE-PRIMARY-CANARY] ✓ Parsed by native dry-run
```

## Promotion Gate

This phase is successful when an explicit `/native-canary` turn returns a clean
ACK while PRoot remains available as fallback on `18789`.

The next promotion step is native routing design, not enabling providers in
this endpoint. Provider calls and tool execution stay disabled until the native
runtime owns a full Gateway-compatible routing loop and error stream.

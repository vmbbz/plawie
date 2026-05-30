# Native Stream Canary Dry-Run

## Status

Implemented behind diagnostics flags. This is still not production routing.

## Purpose

The native stream canary proves that Flutter can consume a response stream owned
by embedded Node on `127.0.0.1:18790`, without using PRoot's chat lane.

Native still does not call providers or execute tools. The streamed text is
synthetic and exists only to validate the UI/runtime contract:

- Flutter builds the production-shaped `chat.send` frame.
- Embedded Node parses and queue-ACKs the frame.
- Embedded Node returns newline-delimited stream events.
- Flutter renders the streamed deltas as the assistant response.

## Activation

Build with:

```text
--dart-define=PLAWIE_NATIVE_GATEWAY_PRIMARY_CANARY_DIAGNOSTICS=true
```

Then send:

```text
/native-stream hello native streaming lane
```

Normal messages still use the production PRoot Gateway. `/native-canary` still
returns the one-shot dry-run ACK.

## Endpoint

`POST /gateway/chat-send-canary-stream`

The endpoint returns `202` with `application/x-ndjson` and emits:

- `event: "ack"` with the same dry-run ACK metadata as direct canary
- `event: "delta"` synthetic assistant text chunks
- `event: "end"` with `finishReason: "dry_run_complete"`

## Safety Gate

Success means the UI can complete a native-owned streaming turn while all of the
following remain false:

- `acceptedForRouting`
- `providerCallsEnabled`
- `executionEnabled`

The next phase can start designing native's real routing loop, but provider and
tool execution must stay gated until native has a compatible error stream,
session lifecycle, cancellation path, and tool policy surface.

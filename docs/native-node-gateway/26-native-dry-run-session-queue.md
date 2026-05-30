# Native Dry-Run Session Queue

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Result

The embedded Node canary now keeps a diagnostics-only session and queue model
for real `chat.send` frames mirrored from PRoot.

This remains a dry-run lane:

- PRoot is still the production Gateway on `127.0.0.1:18789`;
- embedded Node stays on the canary port `127.0.0.1:18790`;
- chat routing is disabled;
- provider calls are disabled;
- tool execution is disabled;
- no raw prompts are persisted in diagnostics.

## Dry-Run ACK

`POST /gateway/chat-send-dry-run` now does more than parse the frame. For a
production-shaped `chat.send` request, it creates or reuses a native dry-run
session, records queue metadata, dedupes by idempotency key within the current
diagnostic lane, and returns a structured ACK with:

- `acceptedForQueue: true`;
- `queuedForDryRun: true`;
- `queueStatus: parsed_disabled`;
- `nativeSessionId`;
- `requestId`;
- `runId`;
- `queueDepthBefore` / `queueDepthAfter`;
- `pendingQueueDepth`;
- session accepted/completed/duplicate counters;
- the same redacted metadata hash used by the Dart shadow collector.

`acceptedForRouting` remains `false`.

## Diagnostics Endpoint

`GET /gateway/dry-run-sessions` returns a redacted queue/session snapshot:

- session count;
- pending queue depth;
- max observed queue depth;
- accepted/completed/duplicate totals;
- per-session counters and recent redacted request metadata.

The endpoint intentionally omits raw user text and idempotency-key values.
Lane-scoped dedupe means shadow dry-run and direct canary can observe the same
production turn without marking each other as duplicates.

## Device Verification

The Dart native smoke test now requires:

- `/gateway/chat-send-dry-run` to return a queue-backed dry-run ACK;
- `/gateway/dry-run-sessions` to report at least one completed dry-run frame;
- the live Dart shadow observer to receive a matching queue-backed dry-run ACK.

This proves native can maintain a Gateway-like request/session lane while PRoot
continues to perform the actual chat, provider, and tool work.

## Next Gate

The next promotion gate is a canary runtime switch that can send selected
diagnostic traffic directly to the native dry-run lane while still returning
disabled-route ACKs. Only after that is stable should native attempt any
provider or tool execution.

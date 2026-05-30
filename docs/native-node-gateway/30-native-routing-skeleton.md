# Native Routing Skeleton Canary

Date: 2026-05-30

Status: diagnostics-only canary

## Purpose

This phase proves that embedded Node can own the lifecycle shape of a real
`chat.send` turn without taking over provider calls or tool execution.

The production PRoot Gateway remains primary on `127.0.0.1:18789`. Embedded
Node remains isolated on `127.0.0.1:18790`.

## Canary Entry Point

Flutter exposes a hidden chat prefix:

```text
/native-route <message>
```

That prefix sends a production-shaped `chat.send` frame directly to embedded
Node:

```text
POST /gateway/chat-route-skeleton-stream
```

The response is an `application/x-ndjson` stream.

## Stream Contract

The skeleton emits these events:

| Event | Meaning |
| --- | --- |
| `ack` | Native parsed the `chat.send` frame and accepted a dry-run run ID |
| `route_plan` | Native built the route lifecycle plan and gate contract |
| `provider_gate` | Provider calls are explicitly blocked |
| `tool_gate` | Tool execution is explicitly blocked |
| `delta` | Synthetic native-owned response text for UI stream validation |
| `cancelled` | Optional cancellation result for an active skeleton run |
| `end` | Skeleton stream completed without provider/tool execution |
| `error` | Structured native error frame |

Cancellation is represented by:

```text
POST /gateway/chat-route-skeleton-cancel
```

with a JSON body containing `runId`.

## Safety Gates

This phase intentionally keeps these flags false:

```text
acceptedForRouting: false
chatRoutingEnabled: false
providerCallsEnabled: false
executionEnabled: false
```

The route plan includes provider/tool gates with reason strings, a cancellation
endpoint, and the expected error frame shape. No provider request is created and
no OpenClaw skill/tool can run from this lane.

## Pass Condition

A `/native-route` turn passes when:

- The chat UI receives `ack`, `route_plan`, synthetic `delta`, and `end`.
- The native ACK hash matches the local redacted Dart frame hash.
- Logs show `[NATIVE-ROUTE-SKELETON]` activity.
- Logs do not show normal `[CHAT] -> Sending to ...` for the same turn.
- Provider calls and tool execution remain disabled in every native event.

## Next Gate

After this canary remains stable across real turns, the next phase can add a
provider adapter shell that resolves model/provider configuration but still
stops before the outbound network call.

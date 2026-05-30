# Native Provider Transport Shim

Date: 2026-05-30

Status: diagnostics-only canary

## Purpose

This phase proves that embedded Node can construct the provider transport
object for a `chat.send` turn and abort locally before DNS, TLS, socket open,
request bytes, or provider billing.

The production PRoot Gateway remains primary on `127.0.0.1:18789`. Embedded
Node remains isolated on `127.0.0.1:18790`.

## Canary Entry Point

Flutter exposes a hidden chat prefix:

```text
/native-transport <message>
```

That prefix sends a production-shaped `chat.send` frame directly to embedded
Node, with the selected Flutter model attached as a canary-only hint:

```text
POST /gateway/chat-provider-transport-shim-stream
```

The response is an `application/x-ndjson` stream.

## Stream Contract

The transport shim emits these events:

| Event | Meaning |
| --- | --- |
| `ack` | Native parsed the `chat.send` frame and accepted a dry-run run ID |
| `transport_shim` | Native constructed the redacted provider transport object |
| `abort_contract` | Native reported local abort/signal and no-network proof |
| `transport_gate` | Native confirmed transport invocation remains disabled |
| `shim_validation` | Native reported shim validation results |
| `delta` | Synthetic native-owned response text for UI stream validation |
| `end` | Transport shim completed without network/provider/tool execution |
| `error` | Structured native error frame |

## Safety Proof

The native ACK and abort contract must prove:

```text
abortStage: before_dns
dnsLookupStarted: false
tlsHandshakeStarted: false
socketOpened: false
requestBytesWritten: 0
providerBillingSurfaceReached: false
transportInvocationEnabled: false
providerCallsEnabled: false
executionEnabled: false
```

The shim also emits `transportHash`, computed over the redacted transport
object, abort contract, request hashes, and no-network probe state.

## Pass Condition

A `/native-transport` turn passes when:

- The chat UI receives `ack`, `transport_shim`, `abort_contract`, synthetic
  `delta`, and `end`.
- The native ACK hash matches the local redacted Dart frame hash.
- Logs show `[NATIVE-TRANSPORT-SHIM]` activity.
- Logs do not show normal `[CHAT] -> Sending to ...` for the same turn.
- `validationOk` is true.
- Native aborts at `before_dns`.
- DNS, TLS, socket open, request bytes, provider billing, provider calls, and
  tool execution all remain false/zero.

## Remaining Gates

Estimated remaining migration gates after this phase:

1. Single-provider network canary with an explicit developer toggle and a tiny
   harmless prompt.
2. Native stream parser parity for provider chunks, errors, retries, and
   cancellation.
3. Tool-call plan capture with execution still disabled.
4. No-op tool execution shell that validates tool dispatch frames without
   invoking Android/OpenClaw tools.
5. Native tool bridge canary for one harmless local tool.
6. Runtime selection canary where native handles selected turns while PRoot
   remains fallback.
7. Broader parity soak across text, gestures, device/camera prompts, and
   provider-error cases.
8. Promotion gate for default runtime selection, rollback, and release notes.

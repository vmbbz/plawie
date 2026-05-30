# Native Provider Request Builder Dry-Run

Date: 2026-05-30

Status: diagnostics-only canary

## Purpose

This phase proves that embedded Node can build the final redacted provider
request contract for a `chat.send` turn without invoking `fetch`,
`http.request`, or any other outbound provider transport.

The production PRoot Gateway remains primary on `127.0.0.1:18789`. Embedded
Node remains isolated on `127.0.0.1:18790`.

## Canary Entry Point

Flutter exposes a hidden chat prefix:

```text
/native-provider-build <message>
```

That prefix sends a production-shaped `chat.send` frame directly to embedded
Node, with the selected Flutter model attached as a canary-only hint:

```text
POST /gateway/chat-provider-request-builder-stream
```

The response is an `application/x-ndjson` stream.

## Stream Contract

The request builder emits these events:

| Event | Meaning |
| --- | --- |
| `ack` | Native parsed the `chat.send` frame and accepted a dry-run run ID |
| `provider_request` | Native normalized the redacted endpoint, headers, and body |
| `request_validation` | Native reported header/body validation results |
| `transport_gate` | Native stopped before provider transport invocation |
| `provider_error_contract` | Native reported the raw-error forwarding contract |
| `delta` | Synthetic native-owned response text for UI stream validation |
| `end` | Request builder completed without provider/tool execution |
| `error` | Structured native error frame |

## Stable Hashes

The native ACK includes:

```text
headersHash
bodyHash
requestHash
```

These hashes are computed over redacted normalized request parts. They are the
gate for detecting accidental request-shape drift before any later transport
canary is allowed.

## Safety Gates

This phase intentionally keeps these flags false:

```text
acceptedForRouting: false
chatRoutingEnabled: false
providerCallsEnabled: false
executionEnabled: false
outboundNetworkEnabled: false
transportInvocationEnabled: false
```

The request builder never loads API keys. It represents authorization as a
redacted placeholder and reports `apiKeyLoaded: false` under
`providerConfigStatus`.

## Pass Condition

A `/native-provider-build` turn passes when:

- The chat UI receives `ack`, `provider_request`, `request_validation`,
  synthetic `delta`, and `end`.
- The native ACK hash matches the local redacted Dart frame hash.
- Logs show `[NATIVE-PROVIDER-BUILDER]` activity.
- Logs do not show normal `[CHAT] -> Sending to ...` for the same turn.
- `validationOk` is true.
- `transportInvocationEnabled` is false.
- Provider calls and tool execution remain disabled in every native event.

## Next Gate

After this canary remains stable, the next phase can add a transport shim canary
that constructs the provider transport object and immediately aborts locally,
still before DNS, TLS, or any provider billing surface.

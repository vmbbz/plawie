# Native Provider Adapter Shell

Date: 2026-05-30

Status: diagnostics-only canary

## Purpose

This phase proves that embedded Node can shape the provider/model adapter layer
for a `chat.send` turn without making an outbound provider request.

The production PRoot Gateway remains primary on `127.0.0.1:18789`. Embedded
Node remains isolated on `127.0.0.1:18790`.

## Canary Entry Point

Flutter exposes a hidden chat prefix:

```text
/native-provider <message>
```

That prefix sends a production-shaped `chat.send` frame directly to embedded
Node, with the selected Flutter model attached as a canary-only hint:

```text
POST /gateway/chat-provider-shell-stream
```

The response is an `application/x-ndjson` stream.

## Stream Contract

The provider shell emits these events:

| Event | Meaning |
| --- | --- |
| `ack` | Native parsed the `chat.send` frame and accepted a dry-run run ID |
| `provider_envelope` | Native built a redacted provider/model request envelope |
| `provider_gate` | Outbound provider network is explicitly blocked |
| `provider_error_contract` | Native reports the raw-error forwarding contract |
| `delta` | Synthetic native-owned response text for UI stream validation |
| `end` | Provider shell completed without provider/tool execution |
| `error` | Structured native error frame |

## Safety Gates

This phase intentionally keeps these flags false:

```text
acceptedForRouting: false
chatRoutingEnabled: false
providerCallsEnabled: false
executionEnabled: false
outboundNetworkEnabled: false
```

The provider envelope includes provider, requested model, provider model,
transport shape, redacted endpoint, redacted headers, redacted body shape, and
an `envelopeHash`. It does not include raw prompt text, API keys, or any
provider response body.

The provider error contract is explicit because the production UI should keep
showing useful raw provider/gateway failures rather than generic or misleading
fallback text.

## Pass Condition

A `/native-provider` turn passes when:

- The chat UI receives `ack`, `provider_envelope`, synthetic `delta`, and `end`.
- The native ACK hash matches the local redacted Dart frame hash.
- Logs show `[NATIVE-PROVIDER-SHELL]` activity.
- Logs do not show normal `[CHAT] -> Sending to ...` for the same turn.
- The envelope reports `outboundNetworkEnabled: false`.
- Provider calls and tool execution remain disabled in every native event.

## Next Gate

After this canary remains stable, the next phase can add a provider request
builder dry-run that accepts resolved provider configuration and validates
headers/body normalization while still returning before `fetch` or `http.request`.

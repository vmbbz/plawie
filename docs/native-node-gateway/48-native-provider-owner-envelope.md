# Native Provider Owner Envelope

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and build a redacted provider envelope from a production-shaped `chat.send`
frame while outbound provider network remains disabled.

This proves native can move one step beyond route planning on the real Gateway
port without spending credits or executing tools:

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a `chat.send` dry-run on
  `/gateway/chat-provider-shell-stream`.
- Native emits ordered `ack`, `provider_envelope`, `provider_gate`,
  `provider_error_contract`, and `end` events.
- The envelope is redacted and reports `outboundNetworkEnabled: false`.
- The provider error contract preserves raw provider error forwarding.
- Native is stopped.
- PRoot is restarted and health-checked.
- Native smoke on `18790` is restored.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-provider-envelope-dry-run
```

The endpoint uses a built-in redacted `chat.send` probe frame with
`openrouter/auto` as the provider/model hint. It does not send raw user prompts
and does not call a provider.

## Hidden Command

Diagnostics builds also expose:

```text
/native-provider-owner
```

Aliases:

```text
/native-production-provider
/native-provider-envelope
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-provider-envelope-dry-run
mode: native-production-port-provider-envelope-with-rollback
nativeInitialGuardOk: true
providerDryRunOk: true
providerAckOk: true
providerEnvelopeOk: true
providerGateOk: true
providerErrorContractOk: true
providerOrderOk: true
providerEndOk: true
postProviderGuardOk: true
rollbackHealthOk: true
```

The provider gate must remain non-networking:

```text
providerRouteStatus: blocked_before_outbound_provider
provider: openrouter
requestedModel: openrouter/auto
outboundNetworkEnabled: false
providerCallsEnabled: false
providerExecutionEnabled: false
```

## Boundary

This phase still does not promote native Node to production. It proves native
can own the production port long enough to build and validate a provider
envelope, but provider transport, billing, real chat routing, and general tool
execution remain disabled.

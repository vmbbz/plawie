# Native Provider Owner Transport

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and construct the provider transport shim while still aborting before any DNS,
TLS, socket, request bytes, provider billing, or tool execution.

This extends the production-port request-builder gate:

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a `chat.send` dry-run on
  `/gateway/chat-provider-transport-shim-stream`.
- Native emits ordered `ack`, `transport_shim`, `abort_contract`,
  `transport_gate`, `shim_validation`, and `end` events.
- Native proves `abortStage: before_dns`.
- DNS, TLS, socket open, request bytes, provider billing, provider calls, and
  general execution remain disabled.
- PRoot is restarted and health-checked.
- Native smoke on `18790` is restored.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-provider-transport-shim-dry-run
```

The endpoint uses a built-in redacted `chat.send` probe frame with
`openrouter/auto` as the provider/model hint. It does not send raw user prompts
and does not call a provider.

## Hidden Command

Diagnostics builds also expose:

```text
/native-transport-owner
```

Aliases:

```text
/native-production-transport
/native-provider-transport-owner
/native-transport-shim-owner
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-provider-transport-shim-dry-run
mode: native-production-port-provider-transport-with-rollback
nativeInitialGuardOk: true
transportDryRunOk: true
transportAckOk: true
transportShimOk: true
abortContractOk: true
transportGateOk: true
shimValidationOk: true
transportOrderOk: true
transportEndOk: true
postTransportGuardOk: true
rollbackHealthOk: true
```

The transport gate must remain non-networking:

```text
transportRouteStatus: aborted_before_dns
provider: openrouter
requestedModel: openrouter/auto
validationOk: true
abortStage: before_dns
abortedLocally: true
dnsLookupStarted: false
tlsHandshakeStarted: false
socketOpened: false
requestBytesWritten: 0
providerBillingSurfaceReached: false
transportInvocationEnabled: false
transportProviderCallsEnabled: false
transportExecutionEnabled: false
```

## Boundary

This phase still does not promote native Node to production. It proves native
can own the production port long enough to construct the transport object and
abort locally before provider network or billing surfaces are touched.

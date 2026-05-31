# Native Provider Owner Builder

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and normalize the final redacted provider request contract before any transport
invocation.

This proves native can move from provider envelope shaping to request-builder
normalization on the real Gateway port without DNS, TLS, provider billing, or
tool execution:

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a `chat.send` dry-run on
  `/gateway/chat-provider-request-builder-stream`.
- Native emits ordered `ack`, `provider_request`, `request_validation`,
  `transport_gate`, `provider_error_contract`, and `end` events.
- The request builder reports stable `headersHash`, `bodyHash`, and
  `requestHash` values.
- Validation passes with API key loading disabled.
- Native stops before `fetch` or `http.request`.
- PRoot is restarted and health-checked.
- Native smoke on `18790` is restored.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-provider-request-builder-dry-run
```

The endpoint uses a built-in redacted `chat.send` probe frame with
`openrouter/auto` as the provider/model hint. It does not send raw user prompts
and does not call a provider.

## Hidden Command

Diagnostics builds also expose:

```text
/native-builder-owner
```

Aliases:

```text
/native-production-builder
/native-provider-builder-owner
/native-provider-build-owner
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-provider-request-builder-dry-run
mode: native-production-port-provider-builder-with-rollback
nativeInitialGuardOk: true
builderDryRunOk: true
builderAckOk: true
providerRequestOk: true
requestValidationOk: true
transportGateOk: true
providerErrorContractOk: true
builderOrderOk: true
builderEndOk: true
postBuilderGuardOk: true
rollbackHealthOk: true
```

The request-builder gate must remain non-networking:

```text
builderRouteStatus: blocked_before_transport_invocation
provider: openrouter
requestedModel: openrouter/auto
validationOk: true
apiKeyLoaded: false
outboundNetworkEnabled: false
transportInvocationEnabled: false
builderProviderCallsEnabled: false
builderExecutionEnabled: false
```

## Boundary

This phase still does not promote native Node to production. It proves native
can own the production port long enough to normalize provider request headers
and body, but transport, billing, real chat routing, and general tool execution
remain disabled.

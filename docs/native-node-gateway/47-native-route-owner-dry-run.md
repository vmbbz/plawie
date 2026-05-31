# Native Route-Owner Dry-Run

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and accept one production-shaped `chat.send` frame through its routing skeleton.

This proves native can speak more of the production-port Gateway dialect while
still refusing all real execution:

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a `chat.send` dry-run on
  `/gateway/chat-route-skeleton-stream`.
- Native emits ordered `ack`, `route_plan`, `provider_gate`, `tool_gate`, and
  `end` events.
- Provider calls and tool execution remain disabled.
- Native is stopped.
- PRoot is restarted and health-checked.
- Native smoke on `18790` is restored.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-route-owner-dry-run
```

The endpoint uses a redacted built-in production-shaped `chat.send` probe frame.
It does not send raw user prompts and does not call a provider.

## Hidden Command

Diagnostics builds also expose:

```text
/native-route-owner
```

Aliases:

```text
/native-production-route
/native-owner-route
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-route-owner-dry-run
mode: native-production-port-route-skeleton-with-rollback
nativeInitialGuardOk: true
routeDryRunOk: true
routeAckOk: true
routePlanOk: true
routeProviderGateOk: true
routeToolGateOk: true
routeOrderOk: true
routeEndOk: true
postRouteGuardOk: true
rollbackHealthOk: true
```

The route gate must remain non-executing:

```text
routeStatus: blocked_before_provider
routeAcceptedForRouting: false
routeProviderCallsEnabled: false
routeExecutionEnabled: false
```

## Boundary

This phase still does not promote native Node to production. It proves native
can own the production port long enough to parse a production-shaped route
dry-run and block execution. Native provider calls, real chat routing, and
general tool execution remain disabled.

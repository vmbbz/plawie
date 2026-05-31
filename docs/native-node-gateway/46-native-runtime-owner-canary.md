# Native Runtime-Owner Canary

Date: 2026-05-31

## Goal

Temporarily let embedded native Node own the real production Gateway port
`18789` for a bounded diagnostics window, then automatically roll back to
PRoot.

This is stricter than the bind soak because native stays on the production port
long enough to prove guarded ownership remains stable:

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped to avoid stale dual binding.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native is probed every second while routing, providers, and tool execution
  remain disabled.
- Native is stopped.
- PRoot is restarted and health-checked.
- Native smoke on `18790` is restored.

## Diagnostics Endpoint

Diagnostics builds expose a direct local endpoint:

```text
POST /api/native-gateway/runtime-owner-canary
```

Body:

```json
{"holdSeconds": 5}
```

`holdSeconds` is clamped to `3..30` to keep the test bounded.

## Hidden Command

Diagnostics builds also expose:

```text
/native-runtime-owner
/native-runtime-owner 5
```

Aliases:

```text
/native-owner-canary
/native-owner
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-runtime-owner-canary
mode: native-temporary-owner-with-automatic-rollback
holdSeconds: 5
temporaryOwnerRuntimeId: native-node-production-port-canary
nativeInitialGuardOk: true
nativeOwnerProbesOk: true
ownerProbeFailures: []
rollbackHealthOk: true
```

Native guard flags must remain closed throughout the owner window:

```text
nativeProductionPortBindCanary: true
nativeCanaryOnly: true
nativeOpenClawStarted: false
nativeChatRoutingEnabled: false
nativeProviderCallsEnabled: false
nativeToolExecutionEnabled: false
```

## Boundary

This phase still does not promote native Node to production. It proves native
can temporarily own the production port under diagnostics control only. Native
provider calls, chat routing, and general tool execution remain disabled.

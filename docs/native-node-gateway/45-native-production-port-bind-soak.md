# Native Production-Port Bind Soak

Date: 2026-05-31

## Goal

Repeat the guarded production-port bind canary several times in one
diagnostics run.

This proves the handoff is not a one-off success:

- PRoot starts each cycle as the healthy production runtime on `18789`.
- Embedded native Node is forced out of stale smoke state before port handoff.
- PRoot is stopped and the production port is released.
- Native binds `18789` with routing, providers, and tool execution disabled.
- Native is stopped.
- PRoot is restarted and health-checked.
- Native smoke on `18790` is restored.

## Diagnostics Endpoint

Diagnostics builds expose a direct local endpoint:

```text
POST /api/native-gateway/production-port-bind-soak
```

Body:

```json
{"cycles": 3}
```

`cycles` is clamped to `1..5` to keep the test bounded.

## Hidden Command

Diagnostics builds also expose:

```text
/native-port-bind-soak
/native-port-bind-soak 3
```

Aliases:

```text
/native-production-port-soak
/native-production-soak
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-bind-soak
mode: repeat-stop-proot-bind-native-rollback-proot
cycles: 3
passedCycles: 3
failedCycle: null
finalProductionHealthOk: true
finalNativeSmokeHealthOk: true
```

Each cycle also contains the full production-port bind canary report, including
the native guard flags:

```text
nativeProductionPortBindCanary: true
nativeCanaryOnly: true
nativeOpenClawStarted: false
nativeChatRoutingEnabled: false
nativeProviderCallsEnabled: false
nativeToolExecutionEnabled: false
rollbackHealthOk: true
```

## Boundary

This phase still does not promote native Node to production. It only proves
repeatable guarded ownership and rollback. Native provider calls, chat routing,
and general tool execution remain disabled.

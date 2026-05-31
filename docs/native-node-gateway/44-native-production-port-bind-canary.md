# Native Production-Port Bind Canary

Date: 2026-05-31

## Goal

Prove embedded native Node can temporarily own the real Gateway port,
`127.0.0.1:18789`, without being allowed to route production traffic.

This is a guarded promotion gate, not a runtime switch:

- PRoot must be running and healthy before the canary starts.
- PRoot is explicitly stopped to release `18789`.
- Embedded native Node binds `18789` with `productionPortBindCanary: true`.
- Native still reports `canaryOnly: true`, `productionReady: false`,
  `openclawStarted: false`, `chatRoutingEnabled: false`, and
  `providerCallsEnabled: false`.
- Native is stopped immediately after the probe.
- PRoot is restarted and health-checked before the command returns.

## User Command

Diagnostics builds expose:

```text
/native-port-bind-canary
```

Aliases:

```text
/native-production-port
/native-production-bind
```

## Checks

The canary reports:

- PRoot preflight running and health state;
- production port release after PRoot stop;
- native start result on `18789`;
- native `/health` and `/gateway/probe` guard flags;
- native stop result;
- PRoot rollback start and health state;
- whether a previously running native smoke lane on `18790` was restored.

## Success Shape

Expected successful UI summary:

```text
Native production-port bind canary complete

activeRuntimeId: proot
canaryRuntimeId: native-node-production-port-canary
productionPort: 18789
preflightProductionRunning: true
productionHealthOkBefore: true
prootStopRequested: true
productionPortReleased: true
nativeStarted: true
nativeRunning: true
nativeHealthOk: true
nativePortReported: 18789
nativeProductionPortBindCanary: true
nativeCanaryOnly: true
nativeOpenClawStarted: false
nativeChatRoutingEnabled: false
nativeProviderCallsEnabled: false
nativeToolExecutionEnabled: false
nativeStopped: true
rollbackStarted: true
rollbackRunning: true
rollbackHealthOk: true
nextGate: native can own 18789 only after full routing/provider/tool parity gates
```

## Boundary

This phase proves port ownership and rollback mechanics only. It deliberately
does not make native Node the default runtime and does not allow ordinary chat,
provider calls, or general tool execution through native Node.

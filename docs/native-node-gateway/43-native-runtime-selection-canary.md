# Native Runtime Selection Canary

Date: 2026-05-31

## Goal

Prove that the app can reason about the active Gateway runtime before native
Node is allowed to own production traffic.

This is still a guardrail phase, not promotion:

- PRoot remains the active runtime on `127.0.0.1:18789`.
- Embedded native Node remains isolated on `127.0.0.1:18790`.
- Native chat routing, provider calls, and general tool execution remain
  disabled outside explicit canary endpoints.
- Fallback remains PRoot.

## User Command

Diagnostics builds expose:

```text
/native-runtime-select
```

Alias:

```text
/native-runtime-selection
```

## Checks

The canary reports:

- active runtime id and label;
- production runtime running state;
- production `/health` result when available;
- native embedded runtime running state;
- native `/health` and `/gateway/probe` result;
- port isolation between `18789` and `18790`;
- native `canaryOnly`, `chatRoutingEnabled`, and `providerCallsEnabled`
  guards;
- explicit PRoot fallback availability.

## Success Shape

Expected successful UI summary:

```text
Native runtime selection canary complete

activeRuntimeId: proot
fallbackRuntimeId: proot
fallbackOneActionAway: true
productionRunning: true
productionHealthOk: true
productionPort: 18789
canaryRuntimeId: native-node-embedded-smoke
nativeRunning: true
nativeHealthOk: true
nativeCanaryPort: 18790
portsIsolated: true
selectionGuardOk: true
nativeCanaryOnly: true
nativeOpenClawStarted: false
nativeChatRoutingEnabled: false
nativeProviderCallsEnabled: false
nativeToolExecutionEnabled: false
nextGate: native production-port bind only after explicit PRoot stop
```

## Boundary

This phase deliberately does not switch `GatewayService` to native Node for
ordinary chat. It only proves the runtime selector can see both lanes and that
the native lane is still isolated.

The next promotion gate is a stricter canary where PRoot is explicitly stopped
first and native proves it can bind the production port without config churn.

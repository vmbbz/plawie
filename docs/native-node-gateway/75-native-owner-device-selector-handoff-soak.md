# Phase 75: Device-Node Selector/Handoff Soak

## Goal

Prove the promoted `device-node` lane stays stable across repeated native
selector and provider tool-plan handoff cycles while PRoot remains the
production owner.

This is the first soak gate for the narrowed promotion lane. It does not widen
native routing and it does not enable provider transport.

## Hidden Commands

```text
/native-device-soak-owner
/native-device-soak-owner 3
/native-device-handoff-soak-owner
/native-device-selector-soak-owner
/native-device-tool-plan-soak-owner
/native-device-repeated-turn-soak-owner
native-device-soak-owner
```

The optional first number selects the cycle count. It is clamped to `1..5`.

## What It Checks

Each cycle runs the phase 74 handoff gate and verifies:

- native is selected only for `flash.status` + `sensor.list`;
- unsupported or mixed plans stay on PRoot fallback;
- chat-visible tool evidence remains present;
- provider calls and transport invocation remain disabled;
- cancellation policy keeps pre-commit cancellation on PRoot fallback;
- provider-error policy keeps native provider calls disabled and preserves raw
  error forwarding policy;
- bridge-error policy keeps unsupported bridge plans on PRoot fallback;
- hot-reload-style repetition leaves the runtime selector stable;
- PRoot health is live before and after the cycle;
- no device-node native in-flight flags leak after the cycle.

## Expected Chat Evidence

```text
phase: hidden-device-node-selector-handoff-soak
selectorHandoffSoakOk: true
cancellationParityOk: true
providerErrorPolicyOk: true
bridgeErrorPolicyOk: true
hotReloadRepeatOk: true
rollbackOk: true
finalProductionHealthOk: true
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
```

## Promotion Rule

This phase is green only if every requested cycle passes and the final
production runtime is still PRoot. Any failed cycle, missing UI evidence,
provider transport attempt, unsupported tool routed to native, or unhealthy
PRoot fallback blocks promotion.

## Result

Green on device `RZCX30KA9AW` with diagnostics build:

```text
phase: hidden-device-node-selector-handoff-soak
requestedCycles: 3
cycles: 3
passedCycles: 3
failedCycle: none
selectorHandoffSoakOk: true
cancellationParityOk: true
providerErrorPolicyOk: true
bridgeErrorPolicyOk: true
hotReloadRepeatOk: true
rollbackOk: true
finalProductionHealthOk: true
finalProductionRuntimeId: proot
toolPlanNames: ["flash.status","sensor.list"]
aggregateToolPanelEventsCount: 12
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
```

PRoot remained live on `127.0.0.1:18789` after the soak. The hidden native
lane stayed scoped to the promoted `device-node` read-only handoff path.

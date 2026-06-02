# Phase 74: Device-Node Provider Tool-Plan Handoff Canary

## Goal

Prove the promoted `device-node` native lane can accept a provider-style tool
plan handoff without broadening routing beyond the read-only allowlist.

This gate is deliberately narrow. It does not replace the general provider
tool-plan phases. It takes the green hidden runtime selector from phase 73 and
adds one more contract:

- `flash.status` and `sensor.list` may hand off to the native read-only bridge.
- A mixed or unsupported plan, such as `flash.status` plus `camera_snap`, stays
  on PRoot fallback.
- Provider calls, transport invocation, and default native routing remain
  disabled.

## Hidden Commands

```text
/native-device-tool-plan-owner
/native-device-provider-tool-plan-owner
/native-device-plan-owner
/native-device-tool-handoff-owner
/native-device-provider-handoff-owner
native-device-tool-plan-owner
```

## Expected Chat Evidence

The visible response should include:

```text
phase: hidden-device-node-provider-tool-plan-handoff-canary
selectorOk: true
providerToolPlanHandoffOk: true
fallbackProviderToolPlanOk: true
nativeExecutionOk: true
uiEvidenceOk: true
toolPanelEventsCount: 4
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
```

The chat UI should also show expandable tool call/result panels for:

```text
Tool flash.status
Tool sensor.list
```

## Promotion Rule

This phase is green only if the provider-style plan maps exactly to the
promoted `device-node` read-only bridge allowlist and the fallback probe remains
on PRoot. Any extra tool, write-capable tool, camera/tooling expansion, provider
network call, or missing UI tool evidence keeps native non-promotable.

## Result

Green on device `RZCX30KA9AW` with diagnostics build:

```text
phase: hidden-device-node-provider-tool-plan-handoff-canary
selectorOk: true
providerToolPlanHandoffOk: true
fallbackProviderToolPlanOk: true
nativeExecutionOk: true
uiEvidenceOk: true
toolPanelEventsCount: 4
toolPlanNames: ["flash.status","sensor.list"]
gatewayToolNames: ["flash.status","sensor.list"]
fallbackToolPlanNames: ["flash.status","camera_snap"]
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
```

PRoot remained primary on `127.0.0.1:18789`. The chat UI surfaced expandable
tool call/result evidence for `Tool flash.status` and `Tool sensor.list`.

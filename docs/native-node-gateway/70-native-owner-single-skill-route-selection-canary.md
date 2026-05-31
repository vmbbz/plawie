# Native Owner Single-Skill Route Selection Canary

This gate proves native route selection can choose exactly one promoted skill
lane, `device-node`, while PRoot remains the fallback for everything else.

It does not enable default native routing. It evaluates a controlled route
decision, confirms only the read-only `device-node` subset is eligible for the
native owner window, verifies non-promoted native bridge candidates still select
PRoot, then executes the selected native route and rolls back.

## Runtime Flow

1. Build a route decision for `device-node` with tool hints:
   `flash.status`, `sensor.list`.
2. Require selected runtime `native-node-production-port-canary`.
3. Require selected route `native-device-node-readonly-bridge-canary`.
4. Require fallback runtime `proot` and fallback route
   `proot-device-node-skill`.
5. Verify other mobile bridge candidates still select PRoot fallback.
6. Execute the single-skill native promotion canary for `device-node`.
7. Require read-only bridge execution only.
8. Require native to stop and PRoot health to return.

## Hidden Chat Commands

```text
/native-device-route-owner
/native-device-node-route-owner
/native-single-skill-route-owner
/native-skill-route-owner
/native-device-route-select-owner
native-device-route-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-single-skill-route-selection-canary
mode: single-skill-device-node-route-selection-with-proot-fallback
selectedSkillId: device-node
requestedToolHints: flash.status,sensor.list
routeSelectionPolicyOk: true
selectedRuntimeId: native-node-production-port-canary
selectedRoute: native-device-node-readonly-bridge-canary
fallbackRuntimeId: proot
fallbackRoute: proot-device-node-skill
fallbackOneActionAway: true
nonPromotedFallbackOk: true
fallbackArmedBeforeExecution: true
nativeRouteExecutedOk: true
singleSkillPolicyOk: true
promotionWindowOpened: true
readOnlyBridgeCanaryOk: true
expectedOrder: flash.status,sensor.list
observedOrder: flash.status,sensor.list
executionScopeOk: true
providerCallsEnabled: false
transportInvocationEnabled: false
providerCallsDisabledOk: true
defaultRouteStillOffOk: true
fallbackAfterCanaryOk: true
rollbackHealthOk: true
rollbackVerified: true
rollbackPolicyOk: true
routeSelectionCanaryOk: true
```

## Promotion Meaning

The previous phase proved `device-node` can be promoted inside a bounded native
owner window. This phase proves the selector itself can choose that lane without
accidentally promoting `canvas`, `gestures`, `tts-voice`, or default Gateway
routing.

Next gate: `device-node` real-turn route shadow canary with PRoot fallback still
armed.

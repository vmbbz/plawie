# Native Owner Device Route Shadow Canary

This gate proves a real `chat.send` shaped `device-node` turn can be mirrored
through native route shadowing while PRoot remains the live production Gateway.

It does not bind native to the production port. It starts or reuses the native
shadow runtime on `18790`, sends a redacted production-shaped `chat.send` frame
containing only the read-only `device-node` tool hints, compares Dart/native
parser parity, builds the native routing skeleton, and verifies the decision
would select the read-only native lane without executing it.

## Runtime Flow

1. Confirm PRoot is still selected as the production runtime on `18789`.
2. Start or reuse embedded native Node on the shadow diagnostics port `18790`.
3. Build a real `chat.send` shaped frame with tool hints:
   `flash.status`, `sensor.list`.
4. Run Dart/native parser and dry-run parity for the frame.
5. Run the native routing skeleton stream for the same frame.
6. Require provider calls, routing, and tool execution to remain disabled.
7. Require the paper route decision to select only the native
   `device-node` read-only lane.
8. Require all non-promoted mobile bridge candidates to remain on PRoot
   fallback.
9. Re-check PRoot health after the shadow route.

## Hidden Chat Commands

```text
/native-device-route-shadow-owner
/native-device-node-route-shadow-owner
/native-real-turn-route-shadow-owner
/native-device-real-turn-shadow-owner
/native-device-route-shadow
native-device-route-shadow-owner
```

## Expected Green Signal

```text
phase: hidden-device-node-real-turn-route-shadow-canary
mode: device-node-real-turn-route-shadow-with-proot-fallback-armed
selectedSkillId: device-node
primaryRuntimeId: proot
nativeRuntimeId: native-node-embedded
selectedRuntimeId: native-node-shadow-route-canary
selectedRoute: native-device-node-readonly-route-shadow
fallbackRuntimeId: proot
fallbackRoute: proot-device-node-skill
fallbackOneActionAway: true
prootRemainedPrimary: true
productionHealthOkBefore: true
productionHealthOkAfter: true
nativeHealthOk: true
nativeLeftRunningForShadow: true
realTurnFrameParsed: true
shadowParityOk: true
dryRunShadowOk: true
hashMatches: true
requestedToolHints: flash.status,sensor.list
localToolHints: flash.status,sensor.list
nativeToolHints: flash.status,sensor.list
dryRunToolHints: flash.status,sensor.list
routePlanToolHints: flash.status,sensor.list
realTurnToolHintsOk: true
readOnlyHintPoliciesOk: true
shadowRouteDecisionOk: true
routeStreamOrderOk: true
routeSkeletonOk: true
routeStatus: blocked_before_provider
providerGateBlocked: true
toolGateBlocked: true
nonPromotedFallbackOk: true
acceptedForRouting: false
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
providerCallsDisabled: true
nativeExecutionDisabled: true
fallbackStillArmed: true
```

## Promotion Meaning

The previous phase proved the selector can choose the `device-node` native lane
inside a bounded owner canary. This phase proves the same selector decision can
be made from a real `chat.send` shaped turn without touching the production
runtime owner.

Next gate: `device-node` real-turn native execution canary with explicit PRoot
fallback.

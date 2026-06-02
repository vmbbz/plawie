# Native Owner Device Real-Turn Execution Canary

This gate proves a real `chat.send` shaped `device-node` turn can move beyond
shadow routing and execute the native read-only bridge allowlist while PRoot
remains the live production Gateway.

It does not bind native to the production port and does not enable default
native routing. Native stays on the diagnostics port `18790`; PRoot stays on
`18789`; only the `flash.status` and `sensor.list` bridge calls are executed.

## Runtime Flow

1. Run the real-turn route-shadow prerequisite.
2. Confirm PRoot is still selected and healthy on `18789`.
3. Start or reuse embedded native Node on `18790`.
4. Build a real `chat.send` shaped frame containing only:
   `flash.status`, `sensor.list`.
5. Re-check Dart/native parser and dry-run parity for that frame.
6. Send the same frame to the native read-only bridge canary stream.
7. Execute only the allowlisted bridge calls through Dart.
8. Require provider calls and general routing to remain disabled.
9. Re-check PRoot health after native execution.

## Hidden Chat Commands

```text
/native-device-exec-owner
/native-device-execution-owner
/native-device-node-exec-owner
/native-device-real-turn-exec-owner
/native-device-route-exec-owner
native-device-exec-owner
```

The slash-first command is canonical. The no-slash form is only a convenience
alias for devices where typing `/` is awkward.

## Expected Green Signal

```text
phase: hidden-device-node-real-turn-native-execution-canary
mode: device-node-real-turn-native-readonly-execution-with-proot-fallback
routeShadowOk: true
selectedSkillId: device-node
primaryRuntimeId: proot
nativeRuntimeId: native-node-embedded
selectedRuntimeId: native-node-real-turn-execution-canary
selectedRoute: native-device-node-readonly-real-turn-execution
fallbackRuntimeId: proot
fallbackRoute: proot-device-node-skill
prootRemainedPrimary: true
nativeHealthOk: true
realTurnFrameParsed: true
shadowParityOk: true
dryRunShadowOk: true
requestedToolHints: flash.status,sensor.list
localToolHints: flash.status,sensor.list
nativeToolHints: flash.status,sensor.list
dryRunToolHints: flash.status,sensor.list
readOnlyExecutionOk: true
executionScope: read_only_bridge_allowlist
expectedOrder: flash.status,sensor.list
observedOrder: flash.status,sensor.list
canaryAllowlistOk: true
executeParityOk: true
validationOk: true
providerCallsEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
providerCallsDisabled: true
nativeExecutionScoped: true
fallbackStillArmed: true
toolPanelEventsCount: 4
```

The chat UI should also show expandable tool call/result panels for
`flash.status` and `sensor.list`. Logcat-only tool frames are not enough for
this gate because the user-visible OpenClaw tool evidence must remain intact.

## Promotion Meaning

The previous phase proved native could make the real-turn route decision on
paper. This phase proves native can safely execute the read-only `device-node`
subset from a real-turn-shaped frame without taking over production Gateway
ownership.

Next gate: wire `device-node` real-turn native execution into a hidden runtime
selector with automatic PRoot fallback.

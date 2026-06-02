# Native Owner Device Runtime Selector Canary

This gate wires the promoted `device-node` read-only lane into a hidden runtime
selector. It still does not make native the default runtime.

The selector may choose native only for the real-turn `device-node` allowlist:
`flash.status` and `sensor.list`. PRoot remains selected on the production port
and is the automatic fallback for any native failure or unsupported hint.

## Runtime Flow

1. Confirm PRoot is selected and healthy on `18789`.
2. Build a selector decision for the promoted `device-node` read-only lane.
3. Run the phase 72 native execution gate as the selected native candidate.
4. Preserve chat-visible tool call/result panels from the native execution.
5. Probe the fallback branch with a non-allowlisted hint decision and require
   that it selects PRoot without attempting native execution.
6. Re-check PRoot health after the selector attempt.

## Hidden Chat Commands

```text
/native-device-selector-owner
/native-device-runtime-selector-owner
/native-device-runtime-owner
/native-device-route-selector-owner
/native-device-select-owner
native-device-selector-owner
```

The slash-first command is canonical. The no-slash form is only a convenience
alias for devices where typing `/` is awkward.

## Expected Green Signal

```text
phase: hidden-device-node-runtime-selector-canary
mode: device-node-native-runtime-selector-with-proot-fallback
innerPhase: hidden-device-node-real-turn-native-execution-canary
selectedSkillId: device-node
primaryRuntimeId: proot
nativeRuntimeId: native-node-embedded
selectedRuntimeId: native-node-device-selector-canary
selectedRoute: native-device-node-readonly-real-turn-execution
fallbackRuntimeId: proot
fallbackRoute: proot-device-node-skill
fallbackOneActionAway: true
fallbackOnNativeFailure: true
selectorFallbackUsed: false
selectorFallbackReadyOk: true
automaticFallbackPolicyOk: true
prootRemainedPrimary: true
nativeSelectorPolicyOk: true
nativeExecutionAttempted: true
nativeExecutionOk: true
nativeReadOnlyResultOk: true
fallbackProbeOk: true
uiEvidenceOk: true
toolPanelEventsCount: 4
providerCallsEnabled: false
defaultNativeRoutingEnabled: false
```

## Promotion Meaning

The previous phase proved native can execute the bounded read-only bridge
allowlist from a real-turn-shaped frame. This phase proves the runtime selector
can choose that native lane and keep PRoot as the automatic fallback branch.

Next gate: bounded provider/tool plan handoff for the promoted `device-node`
lane.

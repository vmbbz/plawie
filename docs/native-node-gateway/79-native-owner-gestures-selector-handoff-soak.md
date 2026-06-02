# Phase 79: Gestures Selector/Handoff Soak

## Goal

Prove the promoted `gestures` lane stays stable across repeated protected
native-to-Dart avatar bridge cycles while PRoot remains the production owner.

This does not widen gesture support. Native remains limited to:

```text
skill: gestures
tool hint: avatar.gesture
gesture: wave right
```

## Hidden Commands

```text
/native-gestures-soak-owner
/native-gestures-soak-owner 2
/native-gesture-soak-owner
/native-gestures-handoff-soak-owner
/native-gestures-selector-soak-owner
/native-avatar-gesture-soak-owner
/native-avatar-gesture-handoff-owner
native-gestures-soak-owner
```

The optional first number selects the cycle count. It is clamped to `1..3`.

## What It Checks

Each cycle runs the protected gestures execution gate and verifies:

- route shadow remains green for `avatar.gesture wave right`;
- native executes only the protected `wave right` avatar bridge call;
- chat-visible tool-use and tool-result evidence remains present;
- provider calls and transport invocation remain disabled;
- cancellation before bridge commit stays on PRoot fallback;
- provider-error policy keeps native provider calls disabled;
- bridge-error policy keeps unsupported gestures and mixed tool plans on PRoot;
- hot-reload-style repetition leaves PRoot as the production runtime;
- PRoot health is live before and after the cycle;
- no gestures/native candidate in-flight flags leak after the cycle.

## Expected Chat Evidence

```text
phase: hidden-gestures-selector-handoff-soak
selectorHandoffSoakOk: true
protectedExecutionSoakOk: true
cancellationParityOk: true
providerErrorPolicyOk: true
bridgeErrorPolicyOk: true
hotReloadRepeatOk: true
rollbackOk: true
finalProductionHealthOk: true
selectedToolHint: avatar.gesture
selectedGesture: wave right
aggregateToolPanelEventsCount: 4
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
nativeExecutionScoped: true
```

## Promotion Rule

This phase is green only if every requested cycle passes and the final
production runtime is still PRoot. Any unsupported gesture routed to native,
missing tool evidence, provider transport attempt, unhealthy PRoot fallback, or
leaked in-flight flag blocks promotion.

## Device-Test Rule

Do not run:

```text
adb reverse tcp:8765 tcp:8765
```

Port `8765` is phone-owned by `AgentSkillServer`. Use `adb forward
tcp:8765 tcp:8765` only when host-side inspection is needed.

## Result

Green on USB device `RZCX30KA9AW`.

Validated commands:

```text
native-gestures-soak-owner 1
native-gestures-soak-owner 2
```

Final two-cycle evidence:

```text
phase: hidden-gestures-selector-handoff-soak
requestedCycles: 2
cycles: 2
passedCycles: 2
failedCycle: none
selectorHandoffSoakOk: true
protectedExecutionSoakOk: true
cancellationParityOk: true
providerErrorPolicyOk: true
bridgeErrorPolicyOk: true
hotReloadRepeatOk: true
rollbackOk: true
finalProductionHealthOk: true
finalProductionRuntimeId: proot
aggregateToolPanelEventsCount: 4
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
nativeExecutionScoped: true
```

PRoot remained the production runtime and fallback after every cycle. Native
executed only the protected `avatar.gesture wave right` lane.

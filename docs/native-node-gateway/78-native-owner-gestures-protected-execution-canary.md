# Phase 78: Gestures Protected Execution Canary

## Goal

Execute one bounded native-to-Dart avatar gesture from a real `chat.send`
shaped gestures turn while PRoot remains the production owner and fallback.

This is the first real execution gate for the `gestures` candidate. It is still
limited to:

```text
skill: gestures
tool hint: avatar.gesture
gesture: wave right
```

## Hidden Commands

```text
/native-gestures-exec-owner
/native-gesture-exec-owner
/native-gestures-execution-owner
/native-avatar-gesture-exec-owner
/native-avatar-gesture-execution-owner
/native-gesture-protected-owner
native-gestures-exec-owner
```

## What It Checks

- Phase 77 route shadow is still green.
- PRoot is healthy before and after the execution canary.
- Embedded native Node parses the real `chat.send` shaped frame.
- Dart/local, native parser, and native dry-run all agree on exactly
  `avatar.gesture`.
- Native sends one bridge execute request to Dart for `avatar.gesture`.
- The request uses `gesture: wave right`, protected gesture arbitration, and a
  bounded duration.
- Tool-use and tool-result frames are surfaced to the chat UI.
- Provider calls remain disabled.
- Execution is scoped only to this protected avatar bridge canary.
- PRoot fallback remains armed.

## Expected Chat Evidence

```text
phase: hidden-gestures-protected-execution-canary
routeShadowOk: true
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
prootRemainedPrimary: true
realTurnFrameParsed: true
shadowParityOk: true
dryRunShadowOk: true
realTurnToolHintsOk: true
ackEventOk: true
toolPlanSummaryOk: true
executeRequestOk: true
executeAckOk: true
toolUseOk: true
toolResultOk: true
summaryOk: true
eventOrderOk: true
endOk: true
protectedAvatarExecutionOk: true
toolPanelEventsCount: 2
uiEvidenceOk: true
gesture: wave right
gestureOk: true
protectedGesture: true
arbitration: protected-gesture
arbitrationOk: true
autoGestureSuppressionRequired: true
autoGestureSuppressionOk: true
providerCallsEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
providerCallsDisabled: true
nativeExecutionScoped: true
fallbackStillArmed: true
```

## Promotion Rule

This phase is green only if the protected gesture executes once, the chat UI
surfaces tool evidence, provider calls remain disabled, and PRoot remains
healthy as the active production runtime.

## Result

Green on device.

Observed command:

```text
native-gestures-exec-owner
```

Observed result:

```text
routeShadowOk: true
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
prootRemainedPrimary: true
productionHealthOkBefore: true
productionHealthOkAfter: true
nativeHealthOk: true
realTurnFrameParsed: true
shadowParityOk: true
dryRunShadowOk: true
hashMatches: true
ackEventOk: true
toolPlanSummaryOk: true
executeRequestOk: true
executeAckOk: true
toolUseOk: true
toolResultOk: true
summaryOk: true
eventOrderOk: true
endOk: true
protectedAvatarExecutionOk: true
toolPanelEventsCount: 2
uiEvidenceOk: true
command: avatar.gesture
gesture: wave right
gestureOk: true
durationMs: 1800
durationOk: true
resultStatus: started
protectedGesture: true
arbitration: protected-gesture
arbitrationOk: true
autoGestureSuppressionOk: true
canaryAllowlistOk: true
fixtureParityOk: true
dispatchParityOk: true
executeParityOk: true
validationOk: true
providerCallsEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
providerCallsDisabled: true
nativeExecutionScoped: true
fallbackStillArmed: true
observedEventOrder:
  ack, tool_plan_summary, bridge_execute_request, bridge_execute_ack,
  tool_use_frame, tool_result_frame, avatar_canary_summary, end
nextGate: gestures runtime selector and handoff soak with PRoot fallback armed
```

Important device-test note:

```text
Do not run adb reverse tcp:8765 tcp:8765 for this gate.
```

Port `8765` is owned by the phone-side `AgentSkillServer`. Reversing it can
steal or poison the app-native bridge listener and make `/api/tools` hang.
Use `adb forward tcp:8765 tcp:8765` only for host-side inspection.

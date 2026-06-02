# Phase 77: Gestures Route Shadow Canary

## Goal

Prove a real `chat.send` shaped gestures turn can be parsed and shadow-routed
by embedded native Node while PRoot remains the production owner.

This phase promotes no execution. It only allows native to select the
candidate route on paper for one bounded slice:

```text
skill: gestures
tool hint: avatar.gesture
gesture: wave right
```

## Hidden Commands

```text
/native-gestures-route-shadow-owner
/native-gesture-route-shadow-owner
/native-avatar-gesture-shadow-owner
/native-gestures-shadow-owner
/native-gesture-shadow-owner
native-gestures-route-shadow-owner
```

## What It Checks

- Phase 76 candidate selection is still green.
- PRoot is healthy before and after the canary.
- Embedded native Node parses the real `chat.send` shaped frame.
- Dart/local, native parser, and native dry-run all agree on exactly
  `avatar.gesture`.
- The route skeleton emits ordered `ack`, `route_plan`, provider gate, tool
  gate, and `end` events.
- Provider calls remain disabled.
- Native tool/bridge execution remains disabled.
- `canvas`, `tts-voice`, and unsupported gesture shapes stay on PRoot fallback.
- The next execution gate is still required before any visible gesture runs.

## Expected Chat Evidence

```text
phase: hidden-gestures-route-shadow-canary
candidateSelectionOk: true
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
realTurnFrameParsed: true
shadowParityOk: true
dryRunShadowOk: true
realTurnToolHintsOk: true
boundedEffectPolicyOk: true
gestureAllowlistOk: true
shadowRouteDecisionOk: true
routeSkeletonOk: true
providerGateBlocked: true
toolGateBlocked: true
fallbackPolicyOk: true
prootRemainedPrimary: true
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
nativeExecutionDisabled: true
fallbackStillArmed: true
```

## Promotion Rule

This phase is green only if native chooses the gestures route on paper for
`avatar.gesture wave right`, every unsupported branch remains on PRoot
fallback, and no native execution occurs.

## Result

Green on device `RZCX30KA9AW` with diagnostics build:

```text
phase: hidden-gestures-route-shadow-canary
mode: gestures-route-shadow-with-proot-fallback-armed
innerPhase: hidden-next-mobile-bridge-candidate-selection
candidateSelectionOk: true
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
selectedRuntimeId: native-node-gestures-route-shadow-canary
selectedRoute: native-gestures-avatar-gesture-wave-right-route-shadow
fallbackRuntimeId: proot
fallbackRoute: proot-gestures-skill
prootRemainedPrimary: true
productionHealthOkBefore: true
productionHealthOkAfter: true
nativeHealthOk: true
realTurnFrameParsed: true
shadowParityOk: true
dryRunShadowOk: true
hashMatches: true
requestedToolHints: ["avatar.gesture"]
localToolHints: ["avatar.gesture"]
nativeToolHints: ["avatar.gesture"]
dryRunToolHints: ["avatar.gesture"]
routePlanToolHints: ["avatar.gesture"]
realTurnToolHintsOk: true
boundedEffectPolicyOk: true
gestureAllowlistOk: true
shadowRouteDecisionOk: true
routeEvents: ["ack","route_plan","provider_gate","tool_gate","delta","delta","end"]
routeSkeletonOk: true
routeStatus: blocked_before_provider
providerGateBlocked: true
toolGateBlocked: true
fallbackPolicyOk: true
acceptedForRouting: false
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
providerCallsDisabled: true
nativeExecutionDisabled: true
fallbackStillArmed: true
```

PRoot remained live on `127.0.0.1:18789`. Native selected
`avatar.gesture wave right` only on paper; no visible gesture execution was
enabled in this phase.

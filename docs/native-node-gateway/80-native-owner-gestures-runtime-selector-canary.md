# Phase 80: Gestures Runtime Selector Canary

## Goal

Prove the hidden runtime selector can choose native for the already-soaked
`gestures` lane while keeping PRoot as the production default and rollback
target.

This phase does not widen gesture support. Native remains limited to:

```text
skill: gestures
tool hint: avatar.gesture
gesture: wave right
```

## Hidden Commands

```text
/native-gestures-selector-owner
/native-gesture-selector-owner
/native-gestures-runtime-selector-owner
/native-avatar-gesture-selector-owner
/native-avatar-gesture-runtime-selector-owner
/native-gesture-toggle-owner
native-gestures-selector-owner
```

## Runtime Flow

1. Confirm PRoot is selected and healthy on `18789`.
2. Arm a hidden selector-toggle fixture only for this canary.
3. Select native only for `avatar.gesture wave right`.
4. Run the protected gestures execution gate as the selected native candidate.
5. Probe unsupported gesture, mixed tool-plan, and cancel-before-commit fallback
   branches.
6. Restore the selector toggle to disabled.
7. Re-check PRoot health and require PRoot to remain primary.

## Expected Green Signal

```text
phase: hidden-gestures-runtime-selector-canary
mode: gestures-native-runtime-selector-toggle-with-proot-fallback
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
primaryRuntimeId: proot
nativeRuntimeId: native-node-embedded
selectedRuntimeId: native-node-gestures-selector-canary
selectedRoute: native-gestures-avatar-gesture-wave-right-selector-execution
executionCandidateRuntimeId: native-node-gestures-execution-canary
executionCandidateRoute: native-gestures-avatar-gesture-wave-right-protected-execution
fallbackRuntimeId: proot
fallbackRoute: proot-gestures-skill
selectorToggleOk: true
selectorPolicyOk: true
nativeExecutionOk: true
nativeGestureResultOk: true
unsupportedGestureFallbackOk: true
mixedToolFallbackOk: true
cancellationFallbackOk: true
fallbackProbeOk: true
automaticFallbackPolicyOk: true
prootRemainedPrimary: true
toolPanelEventsCount: 2
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
```

## Promotion Rule

The selector is promotable only if the toggle restores to disabled, native
executes the protected gesture lane with visible tool evidence, unsupported
gesture and mixed-tool requests select PRoot, and PRoot remains healthy before
and after the canary.

## Result

Green on USB device `RZCX30KA9AW`.

Validated command:

```text
native-gestures-selector-owner
```

Device evidence:

```text
phase: hidden-gestures-runtime-selector-canary
mode: gestures-native-runtime-selector-toggle-with-proot-fallback
innerPhase: hidden-gestures-protected-execution-canary
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
selectedRuntimeId: native-node-gestures-selector-canary
selectedRoute: native-gestures-avatar-gesture-wave-right-selector-execution
executionCandidateRuntimeId: native-node-gestures-execution-canary
executionCandidateRoute: native-gestures-avatar-gesture-wave-right-protected-execution
fallbackRuntimeId: proot
fallbackRoute: proot-gestures-skill
prootRemainedPrimary: true
productionHealthOkBefore: true
productionHealthOkAfter: true
selectorToggleOk: true
selectorPolicyOk: true
nativeExecutionAttempted: true
nativeExecutionOk: true
nativeGestureResultOk: true
unsupportedGestureFallbackOk: true
mixedToolFallbackOk: true
cancellationFallbackOk: true
fallbackProbeOk: true
automaticFallbackPolicyOk: true
toolPanelEventsCount: 2
uiEvidenceOk: true
providerCallsEnabled: false
transportInvocationEnabled: false
defaultNativeRoutingEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
nativeExecutionScoped: true
```

Final host health checks remained green for PRoot on `28789`, native Node on
`28790`, and the phone-owned `AgentSkillServer` bridge on `8765`.

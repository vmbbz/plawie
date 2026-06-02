# Phase 76: Next Mobile Bridge Candidate Selection

## Goal

Pick the next safest mobile bridge candidate after the green `device-node`
selector/handoff soak, without widening native routing or executing the new
candidate yet.

The selected candidate is `gestures`, limited to one bounded slice:
`avatar.gesture` with `wave right`.

## Hidden Commands

```text
/native-next-candidate-owner
/native-next-mobile-candidate-owner
/native-next-bridge-candidate-owner
/native-gestures-candidate-owner
/native-gestures-select-owner
native-next-candidate-owner
```

## Candidate Decision

`gestures` is the safest next bridge candidate because it has a small visible
avatar effect, no provider/network/storage/camera surface, and previous
protected avatar bridge evidence.

Deferred candidates:

- `canvas`: remains on PRoot fallback because it has snapshot/capture and
  navigation/eval UI mutation surface.
- `tts-voice`: remains on PRoot fallback because audible output needs a
  separate quiet/interruption policy.
- unsupported gesture shapes such as long dance requests remain on PRoot
  fallback.

## Expected Chat Evidence

```text
phase: hidden-next-mobile-bridge-candidate-selection
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
candidateSelectionOk: true
chosenFromScorecard: true
selectedToolHintPolicyOk: true
selectedDecisionOk: true
fallbackPolicyOk: true
prootRemainedPrimary: true
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
defaultNativeRoutingEnabled: false
```

## Promotion Rule

This phase is green only if the policy map is still complete, PRoot stays the
primary production runtime, provider calls and execution remain disabled, and
all non-selected bridge candidates are explicitly routed to PRoot fallback.

This phase does not execute `avatar.gesture`. The next gate must be a
controlled gestures route shadow canary for `avatar.gesture wave right` with
PRoot fallback armed.

## Result

Green on device `RZCX30KA9AW` with diagnostics build:

```text
phase: hidden-next-mobile-bridge-candidate-selection
mode: select-next-mobile-bridge-candidate-with-proot-fallback-policy
selectedSkillId: gestures
selectedToolHint: avatar.gesture
selectedGesture: wave right
selectedRuntimeId: native-node-gestures-candidate-canary
selectedRoute: native-gestures-avatar-gesture-wave-right-shadow
fallbackRuntimeId: proot
fallbackRoute: proot-gestures-skill
candidateSelectionOk: true
chosenFromScorecard: true
policyMapOk: true
inventoryParityOk: true
skillPolicyCoverageOk: true
mobileToolPolicyCoverageOk: true
toolHintPolicyCoverageOk: true
selectedCandidatePresent: true
selectedToolHintPolicyOk: true
selectedDecisionOk: true
fallbackPolicyOk: true
productionHealthOkBefore: true
productionHealthOkAfter: true
prootRemainedPrimary: true
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
defaultNativeRoutingEnabled: false
priorAvatarBridgeEvidenceOk: true
```

PRoot remained live on `127.0.0.1:18789`. The result selected `gestures` only
as the next candidate; no gesture execution was enabled in this phase.

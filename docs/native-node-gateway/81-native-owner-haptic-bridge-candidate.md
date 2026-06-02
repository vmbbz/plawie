# Phase 81: Haptic Bridge Candidate Selection

## Goal

Pick the next safest mobile bridge lane after `device-node` and `gestures`,
without widening native routing or executing the new lane yet.

The selected lane is:

```text
bridge lane: haptic
tool hint: haptic.vibrate
allowed slice: one short pulse, max 150ms, no pattern
```

## Hidden Commands

```text
/native-haptic-candidate-owner
/native-haptic-bridge-candidate-owner
/native-next-haptic-candidate-owner
/native-third-candidate-owner
/native-third-bridge-candidate-owner
/native-haptic-select-owner
native-haptic-candidate-owner
```

## Candidate Decision

`haptic.vibrate` is the safest next bridge lane because it is a tiny local
tactile effect, has no provider/network/storage/camera/audio surface, does not
mutate app UI, and already has earlier bridge execution evidence.

Deferred lanes:

- `notifications.list`: read-only but privacy-sensitive metadata.
- `sensor.read`: needs sensor-name allowlists and rate limits.
- `tts-voice`: audible output needs interruption and consent policy.
- `canvas`: capture/eval/navigation surface stays on PRoot.
- `camera_snap`: camera capture needs explicit privacy and storage policy.
- wider `gestures`: blocked until gesture asset/arbitration cleanup.

## Expected Chat Evidence

```text
phase: hidden-haptic-bridge-candidate-selection
selectedBridgeLaneId: haptic
selectedToolHint: haptic.vibrate
candidateSelectionOk: true
chosenFromScorecard: true
policyMapOk: true
inventoryParityOk: true
selectedToolHintPolicy: native_bridge_bounded_effect_allowlist_manual_only
selectedToolHintPolicyOk: true
selectedDecisionOk: true
fallbackPolicyOk: true
prootRemainedPrimary: true
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
defaultNativeRoutingEnabled: false
priorHapticBridgeEvidenceOk: true
```

## Promotion Rule

This phase is green only if the policy map remains complete, PRoot stays
healthy and primary, default native routing/execution remain disabled, and every
non-selected bridge lane explicitly stays on PRoot fallback.

This phase does not execute haptics. The next gate must be a controlled
`haptic.vibrate` route-shadow canary with execution disabled and PRoot fallback
armed.

## Result

Green on USB device `RZCX30KA9AW`.

Validated command:

```text
native-haptic-candidate-owner
```

Device evidence:

```text
phase: hidden-haptic-bridge-candidate-selection
mode: select-haptic-bridge-candidate-with-proot-fallback-policy
selectedBridgeLaneId: haptic
selectedSkillId: haptic-bridge
selectedToolHint: haptic.vibrate
selectedRuntimeId: native-node-haptic-candidate-canary
selectedRoute: native-haptic-vibrate-route-shadow
fallbackRuntimeId: proot
fallbackRoute: proot-mobile-bridge-fallback
candidateSelectionOk: true
chosenFromScorecard: true
policyMapOk: true
inventoryParityOk: true
skillPolicyCoverageOk: true
mobileToolPolicyCoverageOk: true
toolHintPolicyCoverageOk: true
selectedToolHintPolicy: native_bridge_bounded_effect_allowlist_manual_only
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
priorHapticBridgeEvidenceOk: true
```

Deferred lanes remained on PRoot fallback:

```text
gestures widening -> proot
notifications.list -> proot
sensor.read -> proot
tts.speak -> proot
canvas.eval/navigate/snapshot -> proot
camera_snap -> proot
```

Final host health checks remained green for PRoot on `28789`, native Node on
`28790`, and phone-owned AgentSkillServer on `8765`.

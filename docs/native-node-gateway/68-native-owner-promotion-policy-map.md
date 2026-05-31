# Native Owner Promotion Policy Map

This gate proves native promotion is policy-covered before any default routing
can be enabled. It does not promote native. It records a conservative routing
policy for every production skill, every bundled mobile tool, and every native
mobile tool hint while PRoot remains primary.

The policy principle is simple:

- Production skills stay on `proot_fallback_default` unless explicitly promoted.
- Mobile bridge candidates are marked as candidates only, not default native
  routes.
- Native tool hints are classified as read-only, bounded-effect,
  capture/manual, or UI-mutation/manual.
- Provider calls, general execution, and default native routing stay disabled.

## Runtime Flow

1. Verify PRoot is healthy on `18789`.
2. Start or reuse embedded native Node on `18790`.
3. Recheck production skill inventory parity.
4. Build a policy entry for every production skill ID.
5. Build a policy entry for every AgentSkillServer mobile tool.
6. Build a policy entry for every native mobile tool hint in a production
   `chat.send` shape.
7. Verify no unmapped skills/tools/hints remain.
8. Verify default native routing and execution are still disabled.

## Hidden Chat Commands

```text
/native-policy-owner
/native-promotion-policy-owner
/native-production-policy
/native-skill-tool-policy-owner
/native-promotion-map-owner
native-policy-owner
```

## Expected Green Signal

```text
phase: production-promotion-policy-map
mode: side-by-side-read-only-policy-map
primaryRuntimeId: proot
nativeRuntimeId: native-node-embedded
productionHealthOk: true
nativeHealthOk: true
nativeSafetyGatesOk: true
inventoryParityOk: true
productionSkillCount: 60
nativeSkillCount: 60
skillPolicyCoverageOk: true
skillPolicyCount: 60
missingSkillPolicyCount: 0
mobileToolPolicyCoverageOk: true
mobileToolCount: 10
mobileToolPolicyCount: 10
toolHintPolicyCoverageOk: true
mobileToolHintCount: 11
toolHintPolicyCount: 11
nativeDefaultRoutingEnabled: false
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
```

## Device Result

Debug diagnostics build on `RZCX30KA9AW`:

```text
inventoryParityOk: true
productionSkillCount: 60
nativeSkillCount: 60
skillPolicyCoverageOk: true
skillPolicyCount: 60
missingSkillPolicyCount: 0
mobileBridgeCandidateSkills: canvas, device-node, gestures, tts-voice
mobileToolPolicyCoverageOk: true
mobileToolCount: 10
mobileToolPolicyCount: 10
toolHintPolicyCoverageOk: true
mobileToolHintCount: 11
toolHintPolicyCount: 11
nativeDefaultRoutingEnabled: false
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
```

## Promotion Meaning

This phase moves the migration from "native can see the inventory" to "native
has an explicit safe policy for the inventory." It still keeps PRoot as the
production route. The policy map is a prerequisite for carefully promoting one
small lane at a time.

Next gate: single-skill native promotion canary with explicit rollback policy.

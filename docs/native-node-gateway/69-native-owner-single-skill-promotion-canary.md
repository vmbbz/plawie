# Native Owner Single-Skill Promotion Canary

This gate promotes exactly one skill, `device-node`, into a bounded native
owner window on the production port. It does not enable default native routing.
It proves that the promotion policy can open one narrow lane, execute only the
read-only bridge allowlist, and then roll back to healthy PRoot.

## Runtime Flow

1. Run the full production promotion policy map.
2. Verify `device-node` is a native bridge candidate.
3. Verify default native routing, provider calls, and general execution remain
   disabled before the owner window opens.
4. Stop PRoot and start native on `18789`.
5. Execute only `flash.status` and `sensor.list` through the Dart bridge.
6. Verify provider transport stayed disabled and native chat routing stayed
   disabled.
7. Stop native, release `18789`, and restart PRoot.
8. Treat rollback health as a required success condition.

## Hidden Chat Commands

```text
/native-single-skill-owner
/native-single-skill-promotion-owner
/native-device-node-owner
/native-device-skill-owner
/native-skill-owner
native-single-skill-owner
```

## Explicit Rollback Policy

```text
skillId: device-node
promotionMode: single_skill_native_canary
primaryRuntimeId: proot
temporaryOwnerRuntimeId: native-node-production-port-canary
rollbackRuntimeId: proot
rollbackRequired: true
allowedToolHints: flash.status,sensor.list
providerCallsEnabled: false
defaultNativeRoutingEnabled: false
executionScope: read_only_bridge_allowlist
```

Rollback is required on completion, policy precheck failure, native start
failure, canary failure, guard violation, timeout, or exception.

## Expected Green Signal

```text
phase: hidden-production-port-single-skill-promotion-canary
mode: single-skill-native-promotion-with-explicit-rollback
selectedSkillId: device-node
policyMapOk: true
inventoryParityOk: true
skillPolicyCoverageOk: true
mobileToolPolicyCoverageOk: true
toolHintPolicyCoverageOk: true
selectedSkillCandidateOk: true
singleSkillPolicyOk: true
nativeDefaultRoutingEnabled: false
promotionWindowOpened: true
readOnlyBridgeCanaryOk: true
canaryAllowlistOk: true
expectedOrder: flash.status,sensor.list
observedOrder: flash.status,sensor.list
orderScopeOk: true
executeParityOk: true
validationOk: true
providerCallsEnabled: false
transportInvocationEnabled: false
providerCallsDisabledDuringWindow: true
defaultRoutingDisabledDuringWindow: true
executionScope: read_only_bridge_allowlist
boundedBridgeExecutionOnly: true
postCanaryGuardOk: true
nativeStopped: true
nativePortReleasedAfterStop: true
rollbackStarted: true
rollbackRunning: true
rollbackHealthOk: true
rollbackVerified: true
```

## Promotion Meaning

This is the first real promotion-shaped gate after inventory and policy
coverage. It proves native can temporarily own one production skill lane without
becoming the default Gateway. The canary is intentionally narrower than full
`device-node`: only the read-only bridge subset is allowed.

Next gate: controlled single-skill route selection for `device-node` with PRoot
fallback still armed.

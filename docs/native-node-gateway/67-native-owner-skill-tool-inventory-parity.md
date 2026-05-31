# Native Owner Skill Tool Inventory Parity

This gate proves embedded native Node can inspect the same production skill
registry that PRoot uses, while PRoot remains the primary Gateway runtime.

It exists because native promotion must not accidentally narrow Plawie's real
OpenClaw capability surface. The previous chat-loop gates proved native can own
the transport briefly; this gate proves native can also see the full production
skill/tool inventory before any default routing is allowed.

## Runtime Flow

1. Verify PRoot is healthy on `18789`.
2. Start or reuse embedded native Node on `18790`.
3. Scan the real PRoot `~/.openclaw/skills` tree from Dart.
4. Ask native Node for its read-only `/gateway/skill-registry` scan.
5. Compare production skill IDs and native skill IDs exactly.
6. Probe the mobile AgentSkillServer `/api/tools` endpoint.
7. Verify core mobile bridge tools and native mobile tool hints are present.
8. Verify native remains canary-only, read-only, and provider/tool execution is
   disabled.

## Hidden Chat Commands

```text
/native-inventory-owner
/native-skill-tool-parity-owner
/native-production-inventory
/native-production-skill-tool-parity
/native-skills-tools-owner
native-inventory-owner
```

## Expected Green Signal

```text
phase: production-skill-tool-inventory-parity
mode: side-by-side-read-only
primaryRuntimeId: proot
nativeRuntimeId: native-node-embedded
productionHealthOk: true
nativeHealthOk: true
nativeSafetyGatesOk: true
skillRegistryOk: true
skillParityOk: true
productionSkillCount: >=50
nativeSkillCount: same as productionSkillCount
missingInNativeCount: 0
extraInNativeCount: 0
mobileToolEndpointOk: true
mobileToolCoreOk: true
mobileToolCount: >=10
mobileToolHintOk: true
mobileToolHintCount: >=11
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
```

## Device Result

Debug diagnostics build on `RZCX30KA9AW` after the OpenClaw `2026.5.28`
bundle refresh:

```text
productionHealthOk: true
nativeHealthOk: true
nativeSafetyGatesOk: true
skillRegistryOk: true
skillParityOk: true
productionSkillCount: 60
nativeSkillCount: 60
missingInNativeCount: 0
extraInNativeCount: 0
missingKnownSkills:
mobileToolEndpointOk: true
mobileToolCoreOk: true
mobileToolCount: 10
missingMobileTools:
mobileToolHintOk: true
mobileToolHintCount: 11
missingToolHints:
providerCallsEnabled: false
executionEnabled: false
toolExecutionEnabled: false
```

## Promotion Meaning

This gate does not route production traffic through native by default. It only
proves the native diagnostics runtime can see the production skill registry and
mobile bridge tool surface without executing providers or tools.

Next gate: promotion policy map for production skills/tools before any default
native routing.

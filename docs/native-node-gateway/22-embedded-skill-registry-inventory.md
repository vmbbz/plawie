# Embedded Skill Registry Inventory

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Result

The embedded Node lane can now inspect the real production PRoot skill registry
without executing tools or starting OpenClaw.

This answers the important boundary question: the four bundled markdown files
are only a canary bundle. The production PRoot lane currently has a much larger
skill tree, and embedded Node can see that tree read-only from the same app UID.

## Runtime Contract

Diagnostic flow:

```text
NativeNodeEmbeddedService
  -> copy mobile_skill_registry.js into preflight bundle
  -> pass PRoot paths into server.mjs
  -> embedded Node scans ~/.openclaw/skills read-only
  -> expose /gateway/skill-registry on 127.0.0.1:18790
```

Read-only inputs:

- `files/rootfs/ubuntu/root/.openclaw/skills`
- `files/rootfs/ubuntu/root/.openclaw/openclaw.json`

The scanner reads folder names and small markdown summaries. It does not import
skill code, does not invoke CLIs, does not call providers, and marks every skill
entry with `executionEnabled: false`.

## Probe Endpoint

`GET /gateway/skill-registry` returns:

```json
{
  "ok": true,
  "readOnly": true,
  "executionEnabled": false,
  "registrySource": "proot-openclaw-skills",
  "skillCount": 60,
  "countsByClass": {
    "shell-backed": 16,
    "desktop-only": 14,
    "external-service": 26,
    "android-native": 3,
    "openclaw-skill": 1
  },
  "canaryOnly": true,
  "openclawStarted": false,
  "chatRoutingEnabled": false
}
```

The classification is advisory. It is a safety inventory, not a final product
policy. The future mobile registry should refine these categories with explicit
metadata rather than relying only on text heuristics.

## Device Verification

Verified on Samsung SM-A556E / Android 14 with diagnostic build flag
`PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`:

- embedded Node copied seven canary/preflight assets with `missing=0`;
- `/gateway/probe` reported `productionSkillRegistryInspected: true`;
- `/gateway/probe` reported `productionSkillCount: 60`;
- `/gateway/capabilities` included registry summary counts;
- `/gateway/skill-registry` included known production entries such as
  `weather`, `canvas`, `device-node`, `gestures`, and `tts-voice`;
- diagnostics passed and the isolated native process stopped cleanly;
- production PRoot Gateway remained the only real Gateway runtime.

## Why This Gate Matters

This separates three ideas that were easy to blur:

- Canary skills: four tiny bundled markdown files used to prove asset loading.
- Production skills: the real `~/.openclaw/skills` registry currently served by
  PRoot/OpenClaw.
- Executable tools: actual Gateway/provider/node actions, still not enabled in
  the embedded lane.

The native lane can now describe the production skill universe without taking
agency over it. That is the right next step before attempting request routing.

## Next Gate

Build a request-shape parity probe:

- mirror OpenAI/OpenClaw request envelopes;
- preserve production port isolation on `18790`;
- reject chat with a structured canary error;
- compare model, tool, session, and registry fields against PRoot health and
  Gateway RPC discovery;
- do not bind `18789`, execute tools, or call providers.

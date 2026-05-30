# Embedded Gateway Bootstrap Probe

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Result

The embedded Node lane now exposes a small Gateway-shaped HTTP probe on
`127.0.0.1:18790` from the isolated `:native_node_smoke` process.

This is still a canary. It does not start OpenClaw, does not bind the
production Gateway port `18789`, does not route chat, does not call providers,
and does not load the full production skill registry.

## What Loaded

The native process copies and loads only a curated mobile preflight bundle:

- `android_bridge_tools.js`
- `mobile_gateway_probe.js`
- `skills/avatar_forge.md`
- `skills/battery.md`
- `skills/sensors.md`
- `skills/vibrate.md`

That means the observed `skillCount: 4` is intentional. Production PRoot still
owns the full OpenClaw `skills.md`/tool universe until a later parity phase
builds a real mobile registry loader.

## Probe Endpoints

The canary server exposes:

- `/health`
- `/preflight`
- `/gateway/probe`
- `/gateway/capabilities`
- `/v1/models`
- `/v1/chat/completions`

`/v1/chat/completions` intentionally returns a probe-only error instead of
running a model or provider request. This prevents accidental user traffic from
leaking into a partial runtime.

## Payload Contract

The probe reports these key invariants:

```json
{
  "runtime": "native-node-embedded",
  "probe": "mobile-openclaw-gateway-bootstrap",
  "gatewayShape": "openclaw-http-probe",
  "canaryOnly": true,
  "productionReady": false,
  "openclawStarted": false,
  "chatRoutingEnabled": false,
  "providerCallsEnabled": false,
  "fullSkillRegistryLoaded": false,
  "skillRegistryMode": "curated-mobile-preflight"
}
```

## Device Verification

Verified on Samsung SM-A556E / Android 14 with diagnostic build flag
`PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`:

- placeholder native Android smoke passed twice;
- embedded Node `v22.22.3` started through `node::Start`;
- six curated preflight assets were copied with `missing=0`;
- `/health` returned `preflight.passed: true`;
- `/gateway/probe` returned `status: ready`;
- `/gateway/capabilities` returned the four canary skills and three bridge
  tools;
- `/v1/models` returned only `plawie/native-node-probe` with chat/tool calls
  disabled;
- isolated process stopped after diagnostics;
- production PRoot Gateway startup remained untouched.

## Implementation Note

The first probe attempt used a top-level dynamic ESM import for the probe
module. On the embedded Android Node build, that path stalled before
`server.listen`. The probe module is now CommonJS and is loaded through
`createRequire`, matching the bridge-tool loader path already verified by the
preflight gate.

## Next Gate

The next useful phase is a mobile skill registry inventory:

- read the production PRoot `skills.md`/skills tree shape;
- define which skills are Android-safe, cloud-only, shell-only, or blocked;
- generate a mobile registry manifest without executing tools;
- prove that the embedded lane can report the full registry shape without
  starting real chat.

Only after that should the native lane attempt real OpenClaw request routing.

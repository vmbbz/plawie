# Embedded OpenClaw Preflight

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Result

The embedded Node lane now performs a safe OpenClaw-shaped preflight before any
real Gateway boot attempt.

This still does not start OpenClaw and still does not replace PRoot. It proves
that Android embedded Node `22.22.3` can load a curated mobile bundle, inspect
Plawie-owned OpenClaw assets, and report readiness from an isolated process.

## Runtime Contract

Diagnostic flow:

```text
Flutter diagnostics
  -> NativeNodeSmokeProcess
  -> NativeNodeEmbeddedService in :native_node_smoke
  -> copy small mobile OpenClaw assets into app files
  -> node::Start("plawie-native-node", server.mjs)
  -> http://127.0.0.1:18790/health
```

The service copies only small curated files:

- `assets/openclaw/android_bridge_tools.js`
- `assets/openclaw/skills/avatar_forge.md`
- `assets/openclaw/skills/battery.md`
- `assets/openclaw/skills/sensors.md`
- `assets/openclaw/skills/vibrate.md`

The large `assets/openclaw-node-modules.tar.gz` payload is not extracted during
this preflight. The script only checks that the asset exists.

## Health Payload

The `/health` response remains backward-compatible and now includes a nested
`preflight` object:

```json
{
  "ok": true,
  "runtime": "native-node-embedded",
  "node": "v22.22.3",
  "platform": "android",
  "arch": "arm64",
  "host": "127.0.0.1",
  "port": 18790,
  "productionGatewayPort": 18789,
  "openclawStarted": false,
  "preflight": {
    "passed": true,
    "kind": "mobile-openclaw-preflight",
    "engineOk": true,
    "minimumNode": "22.19.0",
    "skillCount": 4,
    "skillFiles": [
      "avatar_forge.md",
      "battery.md",
      "sensors.md",
      "vibrate.md"
    ],
    "bridgeToolsLoaded": true,
    "bridgeToolNames": [
      "get_battery",
      "read_sensor",
      "vibrate"
    ],
    "builtinModules": {
      "fs": true,
      "http": true,
      "crypto": true,
      "module": true
    },
    "intlOk": true,
    "nodeModulesTarAssetPresent": true,
    "missingAssets": [],
    "openclawStarted": false
  }
}
```

## Device Verification

Verified on Samsung SM-A556E / Android 14:

- diagnostic APK built with `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`;
- APK contained the new `android_bridge_tools.js` Flutter asset;
- native Android placeholder smoke passed;
- embedded Node copied five mobile OpenClaw preflight assets;
- embedded Node answered `/health` with `preflight.passed: true`;
- isolated `:native_node_smoke` process stopped after diagnostics;
- Flutter UI process remained alive;
- production PRoot Gateway startup continued afterward.

Observed payload facts:

- `node: v22.22.3`
- `platform: android`
- `arch: arm64`
- `skillCount: 4`
- `bridgeToolNames: get_battery, read_sensor, vibrate`
- `nodeModulesTarAssetPresent: true`
- `openclawStarted: false`

## Why This Gate Matters

The earlier `/health` test only proved that embedded Node could run an HTTP
server. This gate proves the first OpenClaw-facing surface:

- Android assets can become a real filesystem bundle for embedded Node.
- CommonJS bridge tooling can load under Node 22 on Android.
- Skills can be discovered from copied markdown files.
- Core built-in modules and Intl are available.
- Diagnostics can remain isolated from the production Gateway port.

## Next Gate

The next phase is a curated Gateway bootstrap probe, still on `18790`, that
loads a tiny app-owned OpenClaw mobile entry module and exposes basic Gateway
shape endpoints without importing the Linux PRoot `node_modules` tree.

Do not bind `18789`, route chat, start provider calls, or touch production
Gateway config until that canary passes.

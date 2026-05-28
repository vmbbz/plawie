# Phase 2 Native Smoke Runtime

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Purpose

Phase 2 validates native runtime lifecycle plumbing without touching the real
OpenClaw Gateway. The smoke runtime is intentionally isolated from production.

It must not:

- bind `127.0.0.1:18789`;
- run OpenClaw;
- route chat, dashboard, tools, skills, node pairing, or TTS;
- mutate Gateway config.

## Implementation

Native side:

- `NativeGatewaySmokeServer.kt`
- NanoHTTPD bound to `127.0.0.1:18790`
- endpoints:
  - `GET /health`
  - `GET /logs`
- MethodChannel hooks:
  - `startNativeGatewaySmokeRuntime`
  - `stopNativeGatewaySmokeRuntime`
  - `isNativeGatewaySmokeRuntimeRunning`
  - `getNativeGatewaySmokeRuntimeLogs`

Dart side:

- `NativeNodeGatewayRuntime`
- `NativeGatewaySmokeService`
- startup self-test gated by:

```text
--dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
```

Production default remains:

```text
GatewayRuntimeRegistry.current = ProotGatewayRuntime
```

## Health Contract

The smoke health payload must include:

```json
{
  "ok": true,
  "runtime": "native-gateway-smoke",
  "engine": "android-nanohttpd",
  "host": "127.0.0.1",
  "port": 18790,
  "productionGatewayPort": 18789,
  "openclawStarted": false,
  "nodeStarted": false
}
```

The `openclawStarted=false` and `nodeStarted=false` fields are deliberate.
They prevent this placeholder from being mistaken for a real native Node or
OpenClaw runtime.

## On-Device Result

Device: `RZCX30KA9AW`

Diagnostics build command:

```text
flutter build apk --debug --dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
```

Observed result:

- native smoke runtime started on `http://127.0.0.1:18790`;
- first `/health` probe succeeded;
- smoke runtime stopped cleanly;
- restart `/health` probe succeeded;
- smoke runtime stopped cleanly again;
- production PRoot Gateway then started normally;
- Gateway RPC discovery completed;
- Android node paired with protocol v4.

## Next Step

The next Phase 2 substep is dependency and packaging research for the real
native Node binary. The smoke endpoint should stay as the fallback diagnostic
until a real Node process can satisfy the same start/health/stop/restart
contract on a non-production port.

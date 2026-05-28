# Phase 1 Smoke Test

Last updated: 2026-05-28

Branch: `native-node-gateway-research`

## Build Under Test

- APK: debug
- App package: `com.nxg.openclawproot`
- Version observed on device: `versionName=2.2.1`, `versionCode=12`
- Device: `RZCX30KA9AW`

## Scope

This smoke test verifies the Phase 1 runtime abstraction only. It does not test
native Node. The active runtime must remain the production PRoot runtime.

## Result

Status: pass with observation

Confirmed:

- App launched after debug install.
- Runtime marker logged: `[RUNTIME] Gateway runtime: PRoot Gateway Runtime`.
- Gateway process started through `ProotGatewayRuntime`.
- Foreground service started.
- Gateway startup progress logs appeared.
- Startup health probes ran.
- Gateway RPC discovery completed.
- Node auto-connect was released after gateway readiness.
- Node declared 42 commands, including avatar, camera, canvas, flash, haptic,
  location, screen, and sensor commands.
- Node connect was accepted with protocol v4.
- Node paired and connected.
- No `FATAL EXCEPTION` or Flutter layout/runtime crash appeared in the targeted
  app log sample.

## Observation

During the soak, the node WebSocket disconnected once after the initial pair.
The first reconnect attempt timed out, then the next backoff cycle connected,
received a challenge, declared the same 42 commands, and paired again.

This looks like existing node reconnect/backoff behavior rather than a Phase 1
runtime abstraction regression. Keep it visible during Phase 2 because native
runtime work should not make this worse.

## Phase 2 Decision

Proceed to Phase 2 only with these constraints:

- Keep PRoot as the production Gateway on `127.0.0.1:18789`.
- Bind any native smoke runtime to a non-production port.
- Do not route chat, dashboard, node pairing, tools, or skills to native Node.
- Keep the runtime marker so logs identify the active implementation quickly.

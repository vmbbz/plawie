# Native Owner Dart Bridge Dry Run

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and prove it can send a dry-run tool dispatch request across the app boundary
to Dart, receive a structured Dart ACK, and emit bridge-backed synthetic
`tool_use` / `tool_result` frames.

This follows the production-port native tool dispatch dry-run gate. It remains
explicit, diagnostics-only, and followed by mandatory PRoot rollback.

## Flow

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a production-shaped `chat.send` canary on
  `/gateway/chat-native-dart-bridge-dry-run-stream`.
- Native builds the same safe tool plan and dispatch dry-run shape as the
  previous gate.
- Native POSTs a dry-run bridge request to Dart:

```text
127.0.0.1:8765/api/native-gateway/dispatch-dry-run
```

- Dart validates the command, argument shape, allowlist membership, and disabled
  execution flags.
- Native emits:

```text
bridge_request
bridge_ack
tool_use_frame
tool_result_frame
bridge_summary
```

- Native stops, releases `18789`, restarts PRoot, and restores native smoke.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-dart-bridge-dry-run
```

Optional body:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production Dart bridge dry-run: wave right and vibrate once"
}
```

No provider API key is required for this gate because no provider network call
is made.

## Hidden Command

Diagnostics builds also expose:

```text
/native-dart-bridge-owner
```

Aliases:

```text
/native-production-dart-bridge
/native-bridge-owner
/native-production-bridge
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-dart-bridge-dry-run
mode: native-production-port-dart-bridge-dry-run-with-rollback
bridgeDryRunOk: true
bridgeAckEventOk: true
toolPlanSummaryOk: true
dispatchPlanOk: true
bridgeRequestOk: true
bridgeAckOk: true
toolUseFrameOk: true
toolResultFrameOk: true
bridgeSummaryOk: true
bridgeOrderOk: true
bridgeEndOk: true
toolName: avatar.gesture
capability: avatar
dartBridgeOk: true
dartAccepted: true
commandKnown: true
bridgeAckReceived: true
skippedReason: native_dart_bridge_dry_run_only
providerCallsEnabled: false
transportInvocationEnabled: false
executionEnabled: false
toolExecutionEnabled: false
bridgeExecutionEnabled: false
rollbackHealthOk: true
```

## Boundary

This phase still does not promote native Node to production. Native crosses into
Dart only through the dry-run ACK endpoint. Provider calls, bridge execution,
and Android/OpenClaw capability execution remain disabled.

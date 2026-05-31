# Native Owner Dart Bridge Ordering Cancel

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own production port `18789` and prove the
native-to-Dart bridge preserves ordered dry-run dispatches and records a
dry-run cancellation without executing tools.

This follows the native owner Dart bridge dry-run gate. It remains explicit,
diagnostics-only, and followed by mandatory PRoot rollback.

## Flow

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a production-shaped `chat.send` canary on
  `/gateway/chat-native-dart-bridge-ordering-cancel-stream`.
- Native creates three ordered dry-run bridge dispatches.
- Native POSTs each dry-run dispatch to Dart:

```text
127.0.0.1:8765/api/native-gateway/dispatch-dry-run
```

- Native records bridge ACK order and synthetic `tool_use` / `tool_result`
  frame order.
- Native POSTs one dry-run cancellation to Dart:

```text
127.0.0.1:8765/api/native-gateway/dispatch-cancel-dry-run
```

- Dart ACKs the cancellation as recorded only, with no active execution.
- Native stops, releases `18789`, restarts PRoot, and restores native smoke.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-dart-bridge-ordering-cancel
```

Optional body:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production Dart bridge ordering/cancel dry-run: wave right and vibrate once"
}
```

No provider API key is required for this gate because no provider network call
is made.

## Hidden Command

Diagnostics builds also expose:

```text
/native-dart-bridge-order-owner
```

Aliases:

```text
/native-production-dart-bridge-order
/native-bridge-order-owner
/native-production-bridge-order
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-dart-bridge-ordering-cancel
mode: native-production-port-dart-bridge-ordering-cancel-with-rollback
orderingCancelOk: true
ackEventOk: true
orderPlanOk: true
bridgeRequestOrderOk: true
bridgeAckOrderOk: true
toolUseOrderOk: true
toolResultOrderOk: true
cancelRequestOk: true
cancelAckOk: true
orderingSummaryOk: true
eventOrderOk: true
orderingEndOk: true
finishReason: native_dart_bridge_ordering_cancel_complete
orderCount: 3
cancelOrderIndex: 1
observedBridgeOrder: [0, 1, 2]
observedResultOrder: [0, 1, 2]
orderingParityOk: true
cancellationParityOk: true
validationOk: true
cancelAccepted: true
cancelApplied: false
cancellationState: recorded_dry_run_no_active_execution
skippedReason: native_dart_bridge_cancel_dry_run_only
providerCallsEnabled: false
transportInvocationEnabled: false
executionEnabled: false
toolExecutionEnabled: false
bridgeExecutionEnabled: false
rollbackHealthOk: true
```

## Boundary

This phase still does not promote native Node to production. The bridge only
crosses into Dart through dry-run ACK endpoints. Provider calls, bridge
execution, and Android/OpenClaw capability execution remain disabled.

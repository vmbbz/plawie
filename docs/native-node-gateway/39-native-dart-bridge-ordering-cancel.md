# Phase 39 - Native Dart Bridge Ordering And Cancellation

Date: 2026-05-30

## Goal

Prove embedded Node can send multiple bridge dispatch dry-runs to Dart in a
stable order, then send a cancellation-shaped dry-run request for one queued
dispatch, without executing any Android capability.

This phase still does not replace PRoot and still does not move avatar,
camera, sensors, haptics, or other app-native tools.

## UI Trigger

Diagnostics builds expose:

```text
/native-dart-bridge-order <prompt>
```

Flutter sends a production-shaped `chat.send` frame to embedded Node on
`127.0.0.1:18790`.

## Native Endpoint

```text
POST /gateway/chat-native-dart-bridge-ordering-cancel-stream
```

The native endpoint:

- parses the real `chat.send` frame shape
- creates three ordered native bridge dispatch dry-runs
- gives each dispatch a distinct request ID, run ID, bridge request hash, and
  cancellation token
- POSTs each dispatch to Dart in order
- emits synthetic `tool_use` and `tool_result` frames in the same order
- POSTs a dry-run cancellation request for the middle dispatch
- verifies Dart records the cancellation without applying it to a real running
  capability

## Dart Bridge Endpoints

```text
POST /api/native-gateway/dispatch-dry-run
POST /api/native-gateway/dispatch-cancel-dry-run
```

The dispatch endpoint validates command shape, arguments, dry-run mode, and
disabled execution flags. The cancellation endpoint validates the target run
and bridge request hash, then returns:

```text
cancelAccepted: true
cancelRequested: true
cancelApplied: false
cancellationState: recorded_dry_run_no_active_execution
skippedReason: native_dart_bridge_cancel_dry_run_only
executionEnabled: false
toolExecutionEnabled: false
bridgeExecutionEnabled: false
```

## Pass Condition

A real phone smoke passes when chat/logcat show:

```text
orderCount: 3
expectedOrder: 0, 1, 2
observedBridgeOrder: 0, 1, 2
observedResultOrder: 0, 1, 2
uniqueRunIds: 3
orderingParityOk: true
cancellationParityOk: true
validationOk: true
cancellationState: recorded_dry_run_no_active_execution
skippedReason: native_dart_bridge_cancel_dry_run_only
providerCallsEnabled: false
toolExecutionEnabled: false
bridgeExecutionEnabled: false
Native bridge ordering/cancel dry-run complete
```

## Result

Embedded Node now proves the bridge control plane can preserve dispatch order
and represent cancellation state before any real Dart capability execution is
enabled.

## Next Gate

Add a single real capability canary with a tiny allowlist, probably
`haptic.vibrate` or a non-visual status command first. Keep it hidden,
developer-only, cancellable, and guarded by explicit runtime flags.

# Native Dart Bridge Read-Only Canary

## Purpose

This phase widens the native Node -> Dart bridge from one bounded haptic command
to two ordered read-only Android capability calls:

- `flash.status`
- `sensor.list`

The canary still does not enable provider routing, agent routing, or general
tool execution. Native Node owns parsing, queueing, provider-request shaping,
tool selection, bridge request construction, result-frame construction, and
parity checks. Dart executes only the exact allowlisted read-only commands.

## Manual Trigger

In a diagnostics build:

```text
/native-dart-bridge-readonly
```

Optional text after the command is accepted only to keep the test flowing
through a production-shaped `chat.send` frame. Native ignores the model's tool
choice and forces the read-only canary allowlist.

## Native Endpoint

```text
POST /gateway/chat-native-dart-bridge-readonly-canary-stream
```

The endpoint expects a production-shaped WebSocket `chat.send` frame and emits
NDJSON events:

- `ack`
- `tool_plan_summary`
- `bridge_execute_request`
- `bridge_execute_ack`
- `tool_use_frame`
- `tool_result_frame`
- `readonly_canary_summary`
- `end`
- `error`

## Safety Gates

Native sends only:

```json
["flash.status", "sensor.list"]
```

Dart accepts a request only when all of these are true:

- `canaryMode: native-dart-bridge-readonly-canary`
- `dryRun: false`
- `providerCallsEnabled: false`
- `executionEnabled: true`
- `toolExecutionEnabled: true`
- `bridgeExecutionEnabled: true`
- `canaryAllowlist` contains exactly `flash.status` and `sensor.list`
- `command` is one of the two allowlisted commands
- `input` is empty

The expected result shapes are:

- `flash.status`: result contains boolean `on`
- `sensor.list`: result contains a non-empty `sensors` array

## Success Criteria

Each UI or direct endpoint run should show:

```text
canaryAllowlistOk: true
executeParityOk: true
validationOk: true
providerCallsEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
finishReason: native_dart_bridge_readonly_canary_complete
```

Per-command ACKs should show:

```text
command: flash.status
resultStatus: ok
resultShapeOk: true
executeParityOk: true

command: sensor.list
resultStatus: ok
resultShapeOk: true
executeParityOk: true
```

This proves native can perform ordered real bridge execution for read-only
capabilities while the production PRoot Gateway remains primary.

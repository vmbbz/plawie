# Native Owner Bridge Execution Readonly Canary

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own production port `18789` and prove the
native-to-Dart bridge can execute a tiny read-only canary allowlist while
provider calls remain disabled.

This is the first production-port gate where bridge execution is intentionally
enabled. The allowlist is limited to:

```text
flash.status
sensor.list
```

## Flow

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a production-shaped `chat.send` canary on
  `/gateway/chat-native-dart-bridge-readonly-canary-stream`.
- Native forces two read-only bridge requests:

```text
flash.status
sensor.list
```

- Native POSTs each execute canary request to Dart:

```text
127.0.0.1:8765/api/native-gateway/dispatch-execute-canary
```

- Dart validates the canary mode, allowlist, command, arguments, and execution
  flags before executing.
- Native validates:
  - `flash.status` returns a boolean `on`
  - `sensor.list` returns a non-empty `sensors` list
- Native emits bridge ACKs and `tool_use` / `tool_result` frames.
- Native stops, releases `18789`, restarts PRoot, and restores native smoke.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-bridge-execution-readonly-canary
```

Optional body:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production read-only bridge execution canary: check flash and list sensors"
}
```

No provider API key is required for this gate because no provider network call
is made.

## Hidden Command

Diagnostics builds also expose:

```text
/native-bridge-exec-owner
```

Aliases:

```text
/native-production-bridge-exec
/native-readonly-exec-owner
/native-production-readonly-exec
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-bridge-execution-readonly-canary
mode: native-production-port-bridge-execution-readonly-canary-with-rollback
readOnlyCanaryOk: true
ackEventOk: true
toolPlanSummaryOk: true
executeRequestOrderOk: true
executeAckOrderOk: true
toolUseOrderOk: true
toolResultOrderOk: true
summaryOk: true
eventOrderOk: true
endOk: true
finishReason: native_dart_bridge_readonly_canary_complete
commandCount: 2
expectedOrder: [flash.status, sensor.list]
observedOrder: [flash.status, sensor.list]
canaryAllowlistOk: true
executeParityOk: true
validationOk: true
readOnly: true
providerCallsEnabled: false
transportInvocationEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
rollbackHealthOk: true
```

## Boundary

This phase enables bridge/tool execution only for the read-only canary
allowlist. Provider calls and transport invocation remain disabled. Native is
not promoted to production; PRoot is restored before the report is accepted.

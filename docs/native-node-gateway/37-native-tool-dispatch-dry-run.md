# Phase 37 - Native Tool Dispatch Dry Run

Date: 2026-05-30

## Goal

Move one gate beyond tool-plan capture: prove embedded Node can map a normalized
provider tool-call plan to Plawie's Android capability route and emit
Gateway-style `tool_use` / `tool_result` frames without executing the tool.

This phase still does not replace PRoot and does not touch Android
capabilities.

## UI Trigger

Diagnostics builds expose:

```text
/native-tool-dispatch <prompt>
```

The Flutter chat service sends a production-shaped `chat.send` frame to
embedded Node on `127.0.0.1:18790`.

## Native Endpoint

```text
POST /gateway/chat-tool-dispatch-dry-run-stream
```

The endpoint:

- parses the real `chat.send` frame shape
- selects native-safe mobile tool schemas
- captures a valid provider-style tool plan from a fixture
- maps the plan to a Dart/Android capability route
- emits a synthetic `tool_use` frame
- emits a synthetic `tool_result` frame with `dryRun: true`
- records `skippedReason: native_tool_execution_disabled`
- keeps `providerCallsEnabled`, `executionEnabled`, and
  `toolExecutionEnabled` false

## Pass Condition

A real phone smoke passes when chat/logcat show:

```text
fixtureParityOk: true
dispatchParityOk: true
validationOk: true
toolPlanCount: 1
allowedPlanCount: 1
blockedPlanCount: 0
toolName: avatar.gesture
capability: avatar
skippedReason: native_tool_execution_disabled
providerCallsEnabled: false
toolExecutionEnabled: false
Native tool dispatch dry-run complete
```

The chat UI should also receive synthetic tool-use and tool-result markers, so
the normal tool chip path is exercised without performing the action.

## Result

Embedded Node can now carry a tool-call from parsed provider intent into a
safe dispatch-shaped result frame. This proves the control-plane shape needed
for real tool dispatch while preserving the hard safety line: native does not
yet execute any Android capability.

## Next Gate

Add a native-to-Dart bridge canary that sends the synthetic dispatch request
across the app boundary and receives a dry-run Dart capability ACK. Real
capability execution remains disabled until that bridge proves ordering,
session IDs, cancellation, and result-frame parity.

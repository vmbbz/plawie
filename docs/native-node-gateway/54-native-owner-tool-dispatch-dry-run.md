# Native Owner Tool Dispatch Dry Run

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and prove it can map a captured provider tool plan into synthetic dispatch,
`tool_use`, and `tool_result` frames while real Android/OpenClaw execution
stays disabled.

This follows the production-port provider tool-plan capture gate. It remains
explicit, diagnostics-only, and followed by mandatory PRoot rollback.

## Flow

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a production-shaped `chat.send` canary on
  `/gateway/chat-tool-dispatch-dry-run-stream`.
- Native selects a bounded native-safe mobile tool schema set.
- Native captures a valid provider-style tool plan from a fixture.
- Native maps the plan to a Dart/Android capability route.
- Native emits synthetic:

```text
tool_dispatch_plan
tool_use_frame
tool_result_frame
dispatch_summary
```

- Native stops, releases `18789`, restarts PRoot, and restores native smoke.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-tool-dispatch-dry-run
```

Optional body:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production tool dispatch dry-run: wave right and vibrate once"
}
```

No provider API key is required for this gate because no provider network call
is made.

## Hidden Command

Diagnostics builds also expose:

```text
/native-dispatch-owner
```

Aliases:

```text
/native-tool-dispatch-owner
/native-production-dispatch
/native-production-tool-dispatch
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-tool-dispatch-dry-run
mode: native-production-port-tool-dispatch-dry-run-with-rollback
dispatchDryRunOk: true
dispatchAckOk: true
toolPlanSummaryOk: true
dispatchPlanOk: true
toolUseFrameOk: true
toolResultFrameOk: true
dispatchSummaryOk: true
dispatchOrderOk: true
dispatchEndOk: true
toolName: avatar.gesture
capability: avatar
toolResultDryRun: true
skippedReason: native_tool_execution_disabled
providerCallsEnabled: false
transportInvocationEnabled: false
executionEnabled: false
toolExecutionEnabled: false
rollbackHealthOk: true
```

`wouldExecute: true` means the route is dispatchable if a later gate enables
execution. It is not an execution flag. The hard safety flags above must remain
false.

## Boundary

This phase still does not promote native Node to production. Native maps intent
to dispatch-shaped frames only. Provider calls, Dart bridge execution, and
Android/OpenClaw capability execution remain disabled.

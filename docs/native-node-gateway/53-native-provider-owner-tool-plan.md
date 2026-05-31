# Native Provider Owner Tool Plan

Date: 2026-05-31

## Goal

Let embedded native Node temporarily own the production Gateway port `18789`
and prove provider tool-call plan capture while provider transport and Android
tool execution stay disabled.

This follows the production-port stream parser parity gate. It is still
explicit, diagnostics-only, and followed by mandatory PRoot rollback.

## Flow

- PRoot starts as the healthy production runtime on `18789`.
- Embedded native Node smoke on `18790` is stopped.
- PRoot is stopped and the production port is released.
- Native binds `18789` as a temporary owner.
- Native accepts a production-shaped `chat.send` canary on
  `/gateway/chat-provider-tool-plan-canary-stream`.
- Native selects a bounded native-safe mobile tool schema set.
- Native builds a redacted OpenAI-compatible provider request with `tools`
  attached.
- Native parses deterministic provider-style `tool_calls` fixtures:

```text
streaming_tool_fixture
message_tool_fixture
unknown_tool_fixture
malformed_arguments_fixture
```

- Native emits a normalized `tool_plan_summary`.
- Native stops, releases `18789`, restarts PRoot, and restores native smoke.

## Diagnostics Endpoint

Diagnostics builds expose:

```text
POST /api/native-gateway/production-provider-tool-plan-capture
```

Optional body:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production provider tool plan capture: wave right and vibrate once"
}
```

No provider API key is required for this gate because no provider network call
is made.

## Hidden Command

Diagnostics builds also expose:

```text
/native-tool-plan-owner
```

Aliases:

```text
/native-production-tool-plan
/native-provider-tool-plan-owner
/native-tool-plan-capture-owner
```

## Success Shape

Expected successful diagnostics report:

```text
ok: true
phase: hidden-production-port-provider-tool-plan-capture
mode: native-production-port-provider-tool-plan-capture-with-rollback
toolPlanAckOk: true
toolCatalogOk: true
providerRequestOk: true
streamingFixtureOk: true
messageFixtureOk: true
unknownFixtureOk: true
malformedFixtureOk: true
toolPlanSummaryOk: true
toolPlanOrderOk: true
toolPlanEndOk: true
providerCallsEnabled: false
transportInvocationEnabled: false
executionEnabled: false
toolExecutionEnabled: false
rollbackHealthOk: true
```

The positive fixtures must produce one allowed plan. The negative fixtures must
block unknown tools and malformed arguments before any dispatch boundary.

## Boundary

This phase still does not promote native Node to production. Native captures and
normalizes tool intent only. Provider calls, dispatch, and Android/OpenClaw tool
execution remain disabled.

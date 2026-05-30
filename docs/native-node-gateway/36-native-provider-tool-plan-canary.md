# Phase 36 - Native Provider Tool-Plan Canary

Date: 2026-05-30

## Goal

Prove embedded Node can attach native-safe mobile tool schemas and parse
OpenAI-compatible provider `tool_calls` into a normalized execution plan while
keeping all provider transport and Android tool execution disabled.

This phase does not replace PRoot and does not execute tools.

## UI Trigger

Diagnostics builds expose:

```text
/native-tool-plan <prompt>
```

The Flutter chat service sends a production-shaped `chat.send` frame directly
to embedded Node on `127.0.0.1:18790`.

## Native Endpoint

```text
POST /gateway/chat-provider-tool-plan-canary-stream
```

The endpoint:

- validates the real `chat.send` frame shape
- selects a bounded mobile tool schema set from the prompt and tool hints
- builds a redacted OpenAI-compatible provider request with `tools` attached
- parses streaming and non-streaming provider-style `tool_calls` fixtures
- rejects unknown tool names
- rejects malformed JSON tool arguments
- returns a normalized tool plan summary
- leaves `providerCallsEnabled`, `transportInvocationEnabled`,
  `executionEnabled`, and `toolExecutionEnabled` false

## Fixtures

The native parser currently validates:

- streamed tool call argument assembly
- message-level tool call parsing
- unknown tool rejection
- malformed argument rejection

The positive fixture captures a valid attached mobile tool plan. The negative
fixtures must be blocked before execution.

## Pass Condition

A real phone smoke passes when chat/logcat show:

```text
fixtureParityOk: true
validationOk: true
selectedToolCount > 0
toolPlanCount: 1
allowedPlanCount: 1
blockedPlanCount: 0
providerCallsEnabled: false
toolExecutionEnabled: false
Native tool plan canary complete
```

## Result

Embedded Node now owns the next canary gate after provider streaming: it can
understand provider tool-call intent and turn it into a safe, blocked execution
plan. This prepares the native runtime for future controlled tool dispatch
without letting native Node touch Android capabilities yet.

## Next Gate

Add a native tool-dispatch dry run that maps normalized tool plans to Dart/Android
capability names and returns synthetic `tool_result` frames, still with real
execution disabled.

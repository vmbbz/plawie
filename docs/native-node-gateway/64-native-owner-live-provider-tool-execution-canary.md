# Native Owner Live Provider Tool Execution Canary

This gate proves native Node can own the production port, ask the provider for a
real tool call, and execute only the bounded Dart bridge command that matches
the canary allowlist.

It is still diagnostics-only. PRoot remains the default runtime and rollback is
mandatory after the canary finishes or fails.

## Runtime Flow

1. Verify PRoot is healthy on `18789`.
2. Stop PRoot and wait for `18789` to release.
3. Start embedded native Node on `18789`.
4. Build a live OpenRouter request with exactly one forced tool schema:
   `avatar_gesture`.
5. Call the provider and parse the live `tool_calls` stream.
6. Require the parsed provider tool plan to normalize to `avatar.gesture`.
7. Execute only the bounded protected avatar bridge canary.
8. Require provider calls to stay disabled during bridge execution.
9. Stop native, release `18789`, restart PRoot, and restore native smoke.

## Diagnostic API

```http
POST /api/native-gateway/production-provider-live-tool-execution-canary
```

Example:

```json
{
  "model": "openrouter/openai/gpt-oss-20b:free",
  "prompt": "native production live provider tool execution canary: wave right"
}
```

## Hidden Chat Commands

```text
/native-live-tool-exec-owner
/native-production-live-tool-exec
/native-provider-live-tool-exec-owner
/native-live-provider-tool-exec-owner
/native-provider-tool-call-exec-owner
native-live-tool-exec-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-live-provider-tool-execution-canary
mode: native-production-port-live-provider-tool-call-to-bridge-execution-with-rollback
liveToolExecutionCanaryOk: true
providerRequestOk: true
providerCallStartedOk: true
providerResponseOk: true
liveToolPlanSummaryOk: true
bridgeExecuteRequestOk: true
bridgeExecuteAckOk: true
toolUseFrameOk: true
toolResultFrameOk: true
executionSummaryOk: true
eventOrderOk: true
endOk: true
liveToolPlanOk: true
dispatchParityOk: true
canaryAllowlistOk: true
executeParityOk: true
validationOk: true
command: avatar.gesture
gesture: wave right
providerCallsEnabled: true
providerCallsDuringExecutionEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
protectedGesture: true
rollbackHealthOk: true
```

## Why This Matters

The previous gate proved a provider-style tool plan could map to one
allowlisted execution canary. This gate removes the fixture: the provider must
return a live tool call, native must parse it, and only then may the bridge
execute the protected avatar canary.

Next gate: production-port live provider tool result continuation canary with
PRoot rollback.

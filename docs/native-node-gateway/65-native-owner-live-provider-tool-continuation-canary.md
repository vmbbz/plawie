# Native Owner Live Provider Tool Continuation Canary

This gate proves native Node can complete a full bounded tool loop while owning
the production port:

- request a live provider tool call
- execute only the matching bounded Dart bridge allowlist
- return the tool result to the provider
- receive final assistant text
- roll back production ownership to PRoot

It is still diagnostics-only. Native does not become the default runtime and it
does not unlock arbitrary tool execution.

## Runtime Flow

1. Verify PRoot is healthy on `18789`.
2. Stop PRoot and wait for `18789` to release.
3. Start embedded native Node on `18789`.
4. Force one live OpenRouter `haptic_vibrate` tool call.
5. Parse the live provider `tool_calls` stream.
6. Require the tool plan to normalize to `haptic.vibrate`.
7. Execute only the bounded haptic bridge canary.
8. Build a continuation request containing the assistant `tool_calls` frame and
   the Dart bridge `tool` result.
9. Call the provider again and require final streamed text.
10. Stop native, release `18789`, restart PRoot, and restore native smoke.

## Diagnostic API

```http
POST /api/native-gateway/production-provider-live-tool-continuation-canary
```

Example:

```json
{
  "model": "openrouter/openai/gpt-oss-20b:free",
  "prompt": "native production live provider tool result continuation canary: vibrate once"
}
```

## Hidden Chat Commands

```text
/native-live-tool-continue-owner
/native-live-tool-continuation-owner
/native-production-live-tool-continuation
/native-provider-live-tool-continuation-owner
/native-tool-result-continuation-owner
native-live-tool-continue-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-live-provider-tool-continuation-canary
mode: native-production-port-live-provider-tool-result-continuation-with-rollback
liveToolContinuationCanaryOk: true
liveToolPlanSummaryOk: true
bridgeExecuteAckOk: true
command: haptic.vibrate
resultStatus: vibrated
toolResultFrameOk: true
continuationProviderRequestOk: true
continuationProviderCallStartedOk: true
continuationProviderResponseOk: true
continuationSummaryOk: true
continuationOk: true
eventOrderOk: true
endOk: true
finishReason: live_provider_tool_continuation_canary_complete
executeParityOk: true
validationOk: true
providerCallsEnabled: true
providerCallsDuringExecutionEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
rollbackHealthOk: true
```

## Why This Matters

The previous gate stopped after native executed a live provider-selected tool.
This gate proves native can continue the provider conversation with the Dart
tool result, which is the first end-to-end native-owned chat loop skeleton.
The continuation canary uses `haptic.vibrate` instead of `avatar.gesture` so the
provider continuation proof is not blocked by avatar page readiness.

Next gate: production-port native chat loop canary with one live tool
continuation and rollback policy.

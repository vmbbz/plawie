# Native Owner Provider Tool-Plan Allowlisted Execution Canary

This gate proves native Node can connect two previously separate production-port
proofs:

- capture a provider-style tool-call plan while provider/tool execution is off
- map the captured tool intent to exactly one matching Dart bridge allowlist
- execute only that bounded canary command
- roll back production ownership to PRoot afterward

It is still diagnostics-only. Native does not become the default runtime and
does not run arbitrary provider-selected tools.

## Runtime Flow

1. Run the production-port provider tool-plan capture canary on `18789`.
2. Require provider calls, transport invocation, and tool execution to remain
   disabled during capture.
3. Read the captured tool names from the normalized provider fixture.
4. Select the matching bounded bridge execution canary:
   - `haptic.vibrate`
   - `avatar.gesture`
   - `flash.status` plus `sensor.list`
5. Run only that selected allowlisted bridge canary.
6. Require provider calls to remain disabled during bridge execution.
7. Require execution to be enabled only for the selected bridge canary.
8. Stop native, release `18789`, restart PRoot, and restore native smoke.

## Diagnostic API

```http
POST /api/native-gateway/production-provider-tool-plan-execution-canary
```

Example:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production provider tool plan to allowlisted execution canary: vibrate once"
}
```

## Hidden Chat Commands

```text
/native-tool-plan-exec-owner
/native-production-tool-plan-exec
/native-provider-tool-exec-owner
/native-provider-tool-plan-exec-owner
/native-tool-plan-allowlist-owner
native-tool-plan-exec-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-provider-tool-plan-allowlisted-execution
mode: native-production-port-provider-tool-plan-to-allowlisted-execution-with-rollback
captureOk: true
captureToolPlanCanaryOk: true
captureProviderRequestOk: true
planToAllowlistMatchedOk: true
selectedExecutionCanary: avatar.gesture
selectedAllowlist: ["avatar.gesture"]
executionOk: true
executionCanaryAllowlistOk: true
executionExecuteParityOk: true
executionValidationOk: true
providerDisabledDuringCaptureOk: true
executionDisabledDuringCaptureOk: true
providerDisabledDuringExecutionOk: true
executionEnabledDuringSelectedCanaryOk: true
captureProviderCallsEnabled: false
captureToolExecutionEnabled: false
executionProviderCallsEnabled: false
executionToolExecutionEnabled: true
executionBridgeExecutionEnabled: true
captureRollbackOk: true
executionRollbackOk: true
```

## Why This Matters

The prior gates proved tool-plan capture and bridge execution independently.
This gate proves the promotion logic between them: native must not just be able
to execute a hardcoded command, it must prove a captured provider-style tool
intent can be matched to a narrow allowlist before anything crosses into Dart.

Next gate: production-port live provider tool-call to bounded native bridge
execution canary.

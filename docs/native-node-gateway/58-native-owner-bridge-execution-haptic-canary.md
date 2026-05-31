# Native Owner Bridge Execution Haptic Canary

This gate proves native Node can briefly own the production Gateway port
(`18789`) and execute exactly one bounded non-read-only bridge command through
Dart:

- `haptic.vibrate`

Provider calls, transport invocation, full OpenClaw startup, and general tool
execution remain disabled. The haptic duration is forced by native to a tiny
bounded canary pulse and Dart rejects pattern-based input.

## Runtime Flow

1. Diagnostics stop native smoke on `18790`.
2. PRoot must be current runtime and healthy on `18789`.
3. Diagnostics stop PRoot and wait for `18789` to release.
4. Native starts on `18789` in production-port canary mode.
5. Native accepts a production-shaped `chat.send` frame at
   `/gateway/chat-native-dart-bridge-haptic-canary-stream`.
6. Native forces one `haptic.vibrate` bridge request with:
   - `canaryAllowlist: ["haptic.vibrate"]`
   - `durationMs: 90`
   - `dryRun: false`
   - `providerCallsEnabled: false`
   - `executionEnabled: true`
   - `toolExecutionEnabled: true`
   - `bridgeExecutionEnabled: true`
7. Dart executes only that exact canary through
   `/api/native-gateway/dispatch-execute-canary`.
8. Native emits tool-use/tool-result frames and a haptic summary.
9. Native stops, the port is released, PRoot restarts, and native smoke is
   restored.

## Diagnostic API

```http
POST /api/native-gateway/production-bridge-execution-haptic-canary
```

Example:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production haptic bridge execution canary: vibrate once"
}
```

## Hidden Chat Commands

```text
/native-haptic-exec-owner
/native-production-haptic-exec
/native-bridge-haptic-exec-owner
/native-production-bridge-haptic-exec
native-haptic-exec-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-bridge-execution-haptic-canary
mode: native-production-port-bridge-execution-haptic-canary-with-rollback
hapticCanaryOk: true
ackEventOk: true
toolPlanSummaryOk: true
executeRequestOk: true
executeAckOk: true
toolUseOk: true
toolResultOk: true
summaryOk: true
eventOrderOk: true
endOk: true
finishReason: native_dart_bridge_haptic_canary_complete
command: haptic.vibrate
durationBounded: true
canaryAllowlistOk: true
executeParityOk: true
validationOk: true
providerCallsEnabled: false
transportInvocationEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
postCanaryGuardOk: true
rollbackHealthOk: true
nativeSmokeRestored: true
```

## Why This Matters

The previous gate proved bounded read-only execution. This gate proves the same
native-owned production-port path can perform one tiny side-effecting local
capability call, while all broader routing and provider/tool execution remain
locked down.

Next gate: production-port avatar bridge execution canary allowlist.

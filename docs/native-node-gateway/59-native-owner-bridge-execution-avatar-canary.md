# Native Owner Bridge Execution Avatar Canary

This gate proves native Node can briefly own the production Gateway port
(`18789`) and execute exactly one protected visible bridge command through
Dart:

- `avatar.gesture`

Provider calls, transport invocation, full OpenClaw startup, and general tool
execution remain disabled. Native forces the gesture to a bounded canary:

- `gesture: "wave right"`
- `durationMs: 1800`
- `interrupt: true`
- `protectedGesture: true`

The Chat screen must be mounted before running this gate, because the avatar
gesture callback is owned by the live chat/avatar UI. If the app is still on the
Gateway dashboard, Dart should reject the bridge request with `AVATAR_NOT_READY`
and the production-port rollback should still complete.

## Runtime Flow

1. Diagnostics stop native smoke on `18790`.
2. PRoot must be current runtime and healthy on `18789`.
3. Diagnostics stop PRoot and wait for `18789` to release.
4. Native starts on `18789` in production-port canary mode.
5. Native accepts a production-shaped `chat.send` frame at
   `/gateway/chat-native-dart-bridge-avatar-canary-stream`.
6. Native sends one `avatar.gesture` bridge request to Dart through
   `/api/native-gateway/dispatch-execute-canary`.
7. Dart executes only the exact canary allowlist and protected gesture payload.
8. Native emits tool-use/tool-result frames plus `avatar_canary_summary`.
9. Native stops, the port is released, PRoot restarts, and native smoke is
   restored.

## Diagnostic API

```http
POST /api/native-gateway/production-bridge-execution-avatar-canary
```

Example:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production avatar bridge execution canary: wave right"
}
```

## Hidden Chat Commands

```text
/native-avatar-exec-owner
/native-production-avatar-exec
/native-bridge-avatar-exec-owner
/native-production-bridge-avatar-exec
native-avatar-exec-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-bridge-execution-avatar-canary
mode: native-production-port-bridge-execution-avatar-canary-with-rollback
avatarCanaryOk: true
ackEventOk: true
toolPlanSummaryOk: true
executeRequestOk: true
executeAckOk: true
toolUseOk: true
toolResultOk: true
summaryOk: true
eventOrderOk: true
endOk: true
finishReason: native_dart_bridge_avatar_canary_complete
command: avatar.gesture
gesture: wave right
durationOk: true
arbitrationOk: true
protectedGesture: true
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

The previous gates proved read-only execution and a tiny haptic side effect.
This gate proves the native-owned production-port bridge can safely trigger a
visible UI action while preserving gesture arbitration metadata and automatic
PRoot rollback.

Next gate: production-port provider-backed chat canary with tool execution
disabled.

# Native Dart Bridge Haptic Canary

This gate is the first real native-to-Dart capability execution from embedded
Node. It is intentionally tiny: one explicit hidden UI command, one allowlisted
local capability, one bounded haptic pulse, and no provider calls.

## Hidden Command

```text
/native-dart-bridge-haptic
```

Optional text after the command is accepted only as chat-frame context. Native
Node still forces the dispatch to `haptic.vibrate`.

## Native Endpoint

```text
POST /gateway/chat-native-dart-bridge-haptic-canary-stream
```

The endpoint accepts the same production-shaped `chat.send` frame used by the
earlier bridge gates, then:

- parses and queues the frame in the native canary lane
- forces a single tool selection: `haptic.vibrate`
- clamps the canary duration to a small fixed value
- sends a real execute-canary bridge request to Dart
- emits `tool_use` and `tool_result` frames with execution enabled
- leaves provider calls, transport routing, and broad tool execution disabled

## Dart Endpoint

```text
POST /api/native-gateway/dispatch-execute-canary
```

Dart accepts the request only when all guards pass:

- `canaryMode: native-dart-bridge-haptic-canary`
- `dryRun: false`
- `providerCallsEnabled: false`
- `executionEnabled: true`
- `toolExecutionEnabled: true`
- `bridgeExecutionEnabled: true`
- `canaryAllowlist: ["haptic.vibrate"]`
- command canonicalizes to `haptic.vibrate`
- no vibration pattern is supplied
- duration is bounded to `<= 150ms`

If accepted, Dart calls the existing `VibrationCapability` path and returns the
actual result status.

## Pass Condition

The phone smoke must show:

```text
command: haptic.vibrate
accepted: true
executed: true
canaryAllowlistOk: true
durationMs: 90
resultStatus: vibrated OR vibrated_fallback
providerCallsEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
executeParityOk: true
validationOk: true
Native bridge haptic canary complete
```

## Safety Notes

This is not general native tool routing. It cannot choose camera, sensor,
avatar, canvas, flash, provider, or arbitrary skill execution. It is a single
hard-coded canary bridge used to prove that embedded Node can execute one
bounded Android-side capability through the same Dart loopback bridge.

The next gate can widen the allowlist by one low-risk command or add a real
cancelable capability. Keep PRoot as primary until multiple live local
capabilities pass with stable telemetry and rollback behavior.

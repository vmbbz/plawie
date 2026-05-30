# Phase 38 - Native Dart Bridge Dry Run

Date: 2026-05-30

## Goal

Prove embedded Node can send a normalized tool dispatch request across the app
boundary to Dart and receive a structured dry-run ACK, without executing the
Android capability.

This phase still does not replace PRoot and still does not move the avatar,
camera, sensors, haptics, or other app-native tools.

## UI Trigger

Diagnostics builds expose:

```text
/native-dart-bridge <prompt>
```

Flutter sends a production-shaped `chat.send` frame to embedded Node on
`127.0.0.1:18790`.

## Native Endpoint

```text
POST /gateway/chat-native-dart-bridge-dry-run-stream
```

The native endpoint:

- parses the real `chat.send` frame shape
- builds the same native-safe tool plan and dispatch dry-run shape as phase 37
- POSTs a dry-run bridge request to Dart on
  `127.0.0.1:8765/api/native-gateway/dispatch-dry-run`
- receives a Dart `AgentSkillServer` ACK
- emits synthetic `tool_use` and `tool_result` frames
- keeps `providerCallsEnabled`, `executionEnabled`, `toolExecutionEnabled`,
  and `bridgeExecutionEnabled` false

## Dart Bridge Endpoint

```text
POST /api/native-gateway/dispatch-dry-run
```

The Dart endpoint validates:

- command canonicalization, such as `avatar_gesture` to `avatar.gesture`
- command membership in Plawie's mobile node allowlist
- minimal argument shape for commands that require required fields
- dry-run mode and disabled execution flags

It returns an ACK with:

```text
accepted: true
dryRun: true
commandKnown: true
skippedReason: native_dart_bridge_dry_run_only
executionEnabled: false
toolExecutionEnabled: false
bridgeExecutionEnabled: false
```

## Pass Condition

A real phone smoke passes when chat/logcat show:

```text
fixtureParityOk: true
dispatchParityOk: true
bridgeParityOk: true
validationOk: true
toolName: avatar.gesture
capability: avatar
accepted: true
commandKnown: true
skippedReason: native_dart_bridge_dry_run_only
providerCallsEnabled: false
toolExecutionEnabled: false
bridgeExecutionEnabled: false
Native-to-Dart bridge dry-run complete
```

## Result

Embedded Node can now cross from native runtime code into Dart with a
dispatch-shaped request and receive a deterministic dry-run capability ACK.
This proves the next control-plane boundary without granting native runtime
permission to execute app tools.

## Next Gate

Add bridge ordering and cancellation parity: multiple queued native bridge
dry-runs should keep run IDs, cancellation state, and result-frame ordering
stable before any real capability execution is enabled.

# Native Dart Bridge Avatar Canary

## Purpose

This phase widens real native Node -> Dart bridge execution to one visible UI
capability:

- `avatar.gesture`

The canary still does not enable provider routing, agent routing, or general
tool execution. Native Node forces one exact gesture payload and Dart rejects
anything outside that narrow contract.

## Manual Trigger

In a diagnostics build:

```text
/native-dart-bridge-avatar
```

Optional text after the command is accepted only to keep the request flowing
through a production-shaped `chat.send` frame. Native ignores model/tool choice
and forces the protected avatar canary.

## Native Endpoint

```text
POST /gateway/chat-native-dart-bridge-avatar-canary-stream
```

The endpoint expects a production-shaped WebSocket `chat.send` frame and emits
NDJSON events:

- `ack`
- `tool_plan_summary`
- `bridge_execute_request`
- `bridge_execute_ack`
- `tool_use_frame`
- `tool_result_frame`
- `avatar_canary_summary`
- `end`
- `error`

## Forced Payload

Native sends only:

```json
{
  "method": "avatar.gesture",
  "input": {
    "gesture": "wave right",
    "durationMs": 1800,
    "interrupt": true,
    "protectedGesture": true,
    "source": "native-dart-bridge-avatar-canary",
    "canaryMode": "native-dart-bridge-avatar-canary"
  },
  "canaryAllowlist": ["avatar.gesture"],
  "providerCallsEnabled": false,
  "executionEnabled": true,
  "toolExecutionEnabled": true,
  "bridgeExecutionEnabled": true
}
```

Dart accepts the request only when the canary mode, allowlist, command, gesture,
duration, interrupt flag, and protection marker all match.

## Gesture Arbitration

The VRM scene treats the canary as a protected gesture window. While protected,
automatic low-priority interjections such as ready/talk/dance auto-starts are
suppressed instead of interrupting the canary. Normal explicit gestures can
still queue after the protected command finishes.

## Success Criteria

Each UI or direct endpoint run should show:

```text
gesture: wave right
resultStatus: started
gestureOk: true
durationOk: true
arbitrationOk: true
canaryAllowlistOk: true
executeParityOk: true
validationOk: true
providerCallsEnabled: false
executionEnabled: true
toolExecutionEnabled: true
bridgeExecutionEnabled: true
finishReason: native_dart_bridge_avatar_canary_complete
```

This proves native can trigger a visible, protected UI capability while the
production PRoot Gateway remains primary.

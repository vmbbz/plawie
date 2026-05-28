# Current Gateway Contract

Last updated: 2026-05-28

This document defines what must stay true while native Node research happens.
It is the guardrail for every phase.

## Stable Production Sequence

The current production Gateway sequence is:

1. Install or repair OpenClaw in PRoot.
2. Write hardened config before the first Gateway start.
3. Start or attach to the Gateway process.
4. Wait for HTTP readiness on `127.0.0.1:18789`.
5. Retrieve/confirm authenticated dashboard token.
6. Establish the operator WebSocket.
7. Wait for RPC health, skills status, default skills, and tool discovery.
8. Release Android node auto-connect.
9. Pair/approve the Android node with declared commands.
10. Enter interactive app state with chat, dashboard, skills, tools, and node
    capabilities available.

Native Node work cannot reorder these steps.

## External Contract

The runtime implementation may change. These externally observed interfaces may
not change without a separate migration:

| Interface | Required behavior |
| --- | --- |
| Gateway HTTP | `http://127.0.0.1:18789` |
| Gateway WebSocket | Same origin/header/token behavior used by `GatewayConnection` |
| Dashboard URL | Authenticated URL with valid token |
| Node pairing | Android node connects after Gateway interactive readiness |
| Capability bridge | App bridge remains on `127.0.0.1:8765` |
| NDK bridge | Manual bridge remains on `127.0.0.1:11435` |
| Model routing | Cloud routes through Gateway; direct `local-llm/...` bypasses Gateway |
| Tool policy | Gateway owns cloud/full tool schemas and execution |
| Chat persistence | Flutter owns visible chat history |

## Code Ownership Boundaries

Current source-of-truth files:

| Area | Current owner |
| --- | --- |
| Gateway startup and config hardening | `lib/services/gateway_service.dart` |
| Native bridge process calls | `lib/services/native_bridge.dart` |
| Operator WebSocket protocol | `lib/services/gateway_connection.dart` |
| Android node pairing | `lib/providers/node_provider.dart`, `lib/services/node_service.dart` |
| Model policy | `lib/services/model_execution_policy.dart` |
| Model catalog | `lib/services/model_provider_catalog.dart` |
| Direct NDK inference | `lib/services/local_llm_service.dart` |
| NDK HTTP bridge | `lib/services/ndk_gateway_bridge_service.dart` |

The first engineering step should be extraction, not behavior change:

```dart
abstract interface class GatewayRuntime {
  Future<GatewayRuntimeStartResult> start(...);
  Future<GatewayRuntimeAttachResult> attach(...);
  Future<void> stop();
  Future<bool> isRunning();
  Stream<String> get logs;
}
```

`GatewayService` should call the interface. The initial implementation should
wrap the existing PRoot path exactly.

## Non-Goals During Research

- Replacing OpenClaw Gateway logic.
- Changing OpenClaw config schema.
- Reworking tools, skills, node capability names, or model budgets.
- Replacing the NDK/fllama local inference lane.
- Moving the dashboard to Flutter-native UI.
- Removing PRoot before native parity is proven.

## Regression Alarm Conditions

Stop native runtime work and repair the production path if any phase causes:

- Gateway boot loops or unexpected reloads.
- Node pairing before Gateway RPC/tool discovery is complete.
- Missing camera/avatar/haptic/sensor commands after pairing.
- Loss of dashboard token or WebSocket handshake.
- Model/provider changes triggering repeated Gateway restarts.
- NDK bridge activation without user action.
- Chat tool calls disappearing from cloud Gateway lane.
- PRoot fallback failing after native runtime errors.


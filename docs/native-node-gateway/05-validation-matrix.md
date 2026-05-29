# Native Gateway Validation Matrix

Last updated: 2026-05-29

The native runtime cannot become default until it passes this matrix.

## Boot And Attach

| Test | PRoot baseline | Native requirement |
| --- | --- | --- |
| Fresh install start | Gateway installs/configures/starts | Same external readiness states |
| Returning user attach | Attaches without config churn | Same |
| Stop/start loop | No orphan process on repeated toggles | Same |
| App restart attach | Detects running Gateway | Same |
| Gateway logs | Logs visible in app | Same or better |
| Dashboard token | Authenticated dashboard URL works | Same |
| Runtime artifact type | PRoot process is known | Native diagnostics identify executable-process vs embedded-libnode path |
| Missing native artifact | Not applicable | Missing executable or `libnode.so` reports a clean diagnostic skip |

## WebSocket And RPC

| Test | Requirement |
| --- | --- |
| Operator WebSocket connects | Same origin/auth behavior as current `GatewayConnection` |
| Protocol negotiation | Supported methods discovered |
| `rpc.health` | Returns healthy payload |
| Skills status | Active skills visible |
| Tool discovery | Mobile tool policy visible |
| Pairing recovery | Stale token/device recovery still works |

## Node Capabilities

| Capability | Required result |
| --- | --- |
| `device.status` / health | Returns current device info |
| Camera snap | Permission prompt and retry path work |
| Avatar gesture | Gesture command reaches `AgentSkillServer` |
| Haptic vibrate | Executes |
| Flash status/toggle | Executes where hardware supports it |
| Sensor list/read | Executes where permission/hardware supports it |
| Canvas navigate/eval/snapshot | Executes without breaking chat |
| Screen/video tools | Execute or fail with precise permission/hardware reason |

## Chat And Tools

| Test | Required result |
| --- | --- |
| Cloud text chat | Streams first token and final answer |
| Tool call chat | Shows tool-use and tool-result chips |
| Camera request | Model uses Android node tool with correct node handle |
| Avatar request | Model invokes exact gesture command |
| Weather/web-style request | Does not false-timeout while tools execute |
| Provider switch | Message is held during Gateway reload window |
| Rate-limit provider error | Surfaces precise provider error without Gateway restart loop |

## Model Routes

| Route | Required result |
| --- | --- |
| Cloud Gateway model | Uses Gateway runtime |
| Direct `local-llm/...` | Bypasses Gateway runtime |
| `plawie_ndk/local-llm` | Uses manual NDK bridge only when enabled |
| Legacy `ollama/...` | Migrates away, does not start Ollama |

## Lifecycle

| Scenario | Required result |
| --- | --- |
| Leave Chat during streamed turn | Turn continues and persists |
| Open Settings during streamed turn | Turn continues and TTS can play |
| Rotate during streamed turn | No layout crash; stream continues |
| Enter PiP | No invalid sizing crash |
| App foreground/background | No unexpected Gateway restart |
| Device lock/unlock | Runtime either survives or recovers with clear diagnostics |
| Embedded runtime crash | App and PRoot Gateway remain recoverable |

## Performance Metrics

Collect both PRoot and native values:

| Metric | Notes |
| --- | --- |
| Cold Gateway start time | Install complete to HTTP ready |
| Returning attach time | App launch to interactive ready |
| WebSocket handshake time | Token available to connected |
| Node pair time | Interactive ready to node connected |
| First-token latency | User send to first assistant chunk |
| Peak RSS/memory | Gateway + app |
| APK/AAB size delta | Per ABI |
| Stop/restart time | User stop/start loop |

# OpenClaw Startup Test Guide

Last updated: 2026-05-28

Use this guide when validating a fresh install, app update, gateway restart, or
local-model routing change. The goal is true interactive readiness, not merely
the first moment the HTTP port answers.

## Startup Sequence Under Test

1. Gateway process starts or attaches.
2. HTTP `/health` responds and auth token is available.
3. Operator WebSocket handshakes.
4. RPC `health` succeeds when exposed.
5. RPC `skills.status` returns default skills when exposed.
6. Hardened tool/model config is in place.
7. Only then does Plawie release node auto-connect.

This can move visible node pairing later, but it prevents the older failure mode
where the node connected while Gateway was still warming up.

## Test Matrix

| Test | Install state | Expected result |
| --- | --- | --- |
| App update | Existing data retained | Gateway attaches or starts without config churn; Node pairs after RPC discovery |
| Fresh install | App data cleared | Setup completes only after interactive readiness |
| Returning user restart | Close/reopen app | Existing token is reused; no forced Node token regeneration |
| Web dashboard | Open after Gateway ready | Dashboard connects or auto-approves local request |
| Cloud chat | Any catalog cloud model | Request stays on Gateway and no Ollama daemon starts |
| Direct local chat | Active `local-llm/...` model | Gateway is bypassed |
| NDK bridge | Manual bridge only | Gateway routes to `plawie_ndk/local-llm` on `:11435` |

## Expected Good Log Sequence

```text
[GATEWAY] Starting gateway process...
[GATEWAY] Gateway token confirmed; waiting for HTTP readiness...
[GATEWAY] Gateway is healthy
[GATEWAY] WebSocket handshake complete (session: ...)
[GATEWAY] Health RPC: ok=...
[GATEWAY] Active skills: ...
[GATEWAY] Gateway RPC discovery complete; node auto-connect released.
[NODE] Gateway ready; ensuring node is connected
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Challenge received
[NODE] Declaring commands: [...]
[NODE] Connect accepted
[NODE] Paired and connected
```

## Timing Targets

| Phase | Target | Notes |
| --- | --- | --- |
| HTTP healthy | Under 60 seconds cold, faster warm | PRoot and npm startup vary by phone |
| Interactive ready | Under 120 seconds cold | This is the real setup gate |
| Node pairing after interactive ready | Under 5 seconds | Pairing should be fast once released |
| Dashboard load after ready | Under 10 seconds | First WebView load may be slower |

If interactive readiness is slower than HTTP readiness by more than 30 seconds,
capture Gateway logs around skill loading and RPC discovery.

## Red Flags

- Node connects before `Gateway RPC discovery complete`.
- Node pairs with zero declared commands.
- Repeated invalid connect params, nonce failures, or `1006` loops after a
  successful pair.
- Gateway writes config or reloads repeatedly during setup.
- Skills list is empty after `Health RPC` succeeds.
- Any Ollama daemon or port `11434` activity during setup or cloud-provider chat.
- PRoot `llama-server` or port `8081` activity during normal chat.
- `plawie_ndk/local-llm` appears without the user starting the bridge.
- Gateway logs unknown `tools.allow` entries.
- Provider context errors show output tokens near the full model context.

## Phone-Side Commands

Replace the device id if needed:

```powershell
adb devices
adb -s RZCX30KA9AW logcat -c
adb -s RZCX30KA9AW shell monkey -p com.nxg.openclawproot 1
adb -s RZCX30KA9AW logcat -v time | Select-String -Pattern "GATEWAY|NODE|OpenClaw|WebSocket|skills|nonce|Health RPC"
```

Useful process/port check:

```powershell
adb -s RZCX30KA9AW shell pidof com.nxg.openclawproot
adb -s RZCX30KA9AW shell "ps -A | grep -E 'openclaw|proot|node|ollama'"
adb -s RZCX30KA9AW shell "cat /proc/net/tcp /proc/net/tcp6 | grep -E '4965|223D|2CAA|2CAB'"
```

Port hints:

- `18789` is OpenClaw Gateway HTTP/WebSocket.
- `8765` is Plawie device capability bridge.
- `11435` is the manual NDK Gateway bridge.
- `11434` should not be required.
- `8081` should not be required.

## Pass Criteria

The startup test passes only when:

1. Default Gateway skills appear in logs.
2. `Gateway RPC discovery complete` appears before Node pairing.
3. Node declares the expected command catalog before `Paired and connected`.
4. Web dashboard opens without permanent pairing drift.
5. Cloud chat uses the selected provider without starting any local daemon.
6. Direct local NDK chat bypasses Gateway.
7. Opening Chat does not create the canvas WebView until a canvas tool is used.

Fast-looking startup without these markers is a fail.

## NDK Direct Mode Tests

Run these before enabling the HTTP bridge:

| # | Phrase | Expected result |
| --- | --- | --- |
| 1 | `Reply with exactly one short sentence: NDK direct is alive.` | Local text response |
| 2 | `Explain in two bullets what you can and cannot do in offline mode.` | Does not claim full Gateway skills |
| 3 | `Wave at me, then answer in one sentence.` | Local avatar/TTS integration if available |

## NDK HTTP Bridge Tests

Run only after `11435` is listening and `/v1/health` reports `ok: true`.

| # | Phrase | Expected result |
| --- | --- | --- |
| 1 | `Reply with one sentence and include the active model name if you know it.` | Gateway routes to `plawie_ndk/local-llm` |
| 2 | `Do not use tools. Just say: bridge text path works.` | Text-only bridge success |
| 3 | `Try to vibrate the phone once, then tell me the real result.` | If local model emits valid `tool_calls`, Gateway executes haptic tool and sends result back |
| 4 | `Try a wave gesture, then answer from the tool result.` | Gateway tool call/result round trip or clear model limitation |

Bridge pass criteria:

- Port `11435` appears only after user action.
- Gateway provider is `plawie_ndk`.
- The bridge returns OpenAI-compatible SSE chunks.
- Tool-call turns show Gateway tool execution when the local model emits valid
  calls.
- Gateway pairing and Node WebSocket stay stable while the bridge is active.

For any failure, capture:

1. Phrase number.
2. Exact visible chat output.
3. Whether a tool chip appeared.
4. Gateway log lines around the turn.
5. Node log lines around the turn.
6. Bridge health payload.

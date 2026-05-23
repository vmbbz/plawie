# OpenClaw Startup Test Guide

Last updated: 2026-05-23

Use this guide when validating a fresh install, app update, or gateway restart.
The goal is to measure true interactive readiness, not just the first moment the
HTTP port answers.

## What Changed Since `fb0b8f5..3eab98e`

The `3eab98e` path looked faster because it allowed device-node auto-connect as
soon as gateway HTTP health or the gateway-ready log appeared.

Current production behavior is stricter:

1. Gateway process starts or attaches.
2. HTTP `/health` responds with an auth token available.
3. Operator WebSocket handshakes.
4. RPC `health` succeeds when the gateway exposes it.
5. RPC `skills.status` returns default skills when the gateway exposes it.
6. Tools/capabilities are read from hardened config.
7. Only then does Plawie release node auto-connect.

This can move the visible Node pairing later, but it prevents the old failure
pattern where Node connected during gateway warm-up, then immediately hit socket
closed, protocol, nonce, or missing-skill symptoms.

## Test Matrix

| Test | Install state | Expected result |
| --- | --- | --- |
| App update | Existing data retained | Gateway attaches or starts without config churn; Node pairs after RPC discovery. |
| Fresh install | App data cleared | Setup completes only after interactive readiness; Home opens with Gateway and Node stable. |
| Returning user restart | Close/reopen app | Existing token is reused; no forced Node token regeneration. |
| Web dashboard | Open after Gateway ready | Dashboard connects or auto-approves local request, then stays connected after refresh. |
| NDK local chat | Manual offline mode only | Gateway health checks may pause while inference is active, but Gateway must not restart. |

## Expected Good Log Sequence

```text
[GATEWAY] Starting gateway process...
[GATEWAY] Gateway starting up... (0s)
[GATEWAY] Gateway token confirmed; waiting for HTTP readiness...
[GATEWAY] Gateway is healthy
[GATEWAY] WebSocket handshake complete (session: ...)
[GATEWAY] Health RPC: ok=...
[GATEWAY] Active skills: ...
[GATEWAY] Gateway RPC discovery complete; node auto-connect released.
[NODE] Gateway ready; ensuring node is connected (gateway-rpc-ready)
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Connect accepted (protocol=v4, ...)
[NODE] Paired and connected
```

## Timing Targets

| Phase | Target | Notes |
| --- | --- | --- |
| HTTP healthy | Under 60 seconds cold, faster warm | PRoot and npm startup can vary by phone. |
| Interactive ready | Under 120 seconds cold | This is the real setup gate. |
| Node pairing after interactive ready | Under 5 seconds | Pairing should be fast once released. |
| Dashboard load after ready | Under 10 seconds | First WebView load may be slower, but should not require manual CLI pairing. |

If interactive readiness is slower than HTTP readiness by more than 30 seconds,
capture gateway logs around default skill loading and RPC discovery.

## Red Flags

- Node connects before `Gateway RPC discovery complete`.
- Repeated `[NODE] Local gateway still settling` after interactive-ready logs.
- Repeated `invalid connect params` or missing `nonce` after a successful pair.
- Gateway writes config or reloads repeatedly during first setup.
- Skills list is empty after `Health RPC` succeeds.
- Dashboard repeatedly requests different device IDs on the same local session.
- Any Ollama daemon or port `11434` activity during setup or cloud-provider chat.

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
adb -s RZCX30KA9AW shell "ps -A | grep -E 'openclaw|proot|node'"
adb -s RZCX30KA9AW shell "cat /proc/net/tcp /proc/net/tcp6 | grep -E '4955|223D|2C9A'"
```

Port hints:

- `18789` is OpenClaw Gateway HTTP/WebSocket.
- `8765` is Plawie device capability bridge.
- `11434` should not be required in the production cloud-provider path.
- `11435` is reserved for the manual experimental NDK bridge.

## Pass Criteria

The test passes only when:

1. Default Gateway skills appear in logs.
2. `Gateway RPC discovery complete` appears before Node pairing.
3. Node reaches `Paired and connected` once and stays stable.
4. Web dashboard opens without permanent pairing drift.
5. Chat uses the selected cloud provider without starting any local Ollama daemon.

Fast-looking startup without these markers is a fail. It is better to wait for
real readiness than to land users on a UI that immediately disconnects.

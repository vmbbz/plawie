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
[NODE] Declaring 15 commands: [...]
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
- Node pairs with `Declaring 0 commands`.
- Repeated `[NODE] Local gateway still settling` after interactive-ready logs.
- Repeated `invalid connect params` or missing `nonce` after a successful pair.
- Gateway writes config or reloads repeatedly during first setup.
- Skills list is empty after `Health RPC` succeeds.
- `ENOENT` for `/root/.openclaw/workspace/HEARTBEAT.md`.
- Dashboard repeatedly requests different device IDs on the same local session.
- Any Ollama daemon or port `11434` activity during setup or cloud-provider chat.
- Long-idle gateway stalls where `/health` times out repeatedly while the
  `openclaw` process is still alive.
- Loopback socket pile-up against port `18789` after repeated health timeouts.
- Chat idle memory over 1 GB PSS or graphics memory near 1 GB without active
  camera/canvas use.

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
adb -s RZCX30KA9AW shell "cat /proc/net/tcp /proc/net/tcp6 | grep -E '4965|223D|2CAA|2CAB'"
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
3. Node declares the expected command catalog before `Paired and connected`.
4. Web dashboard opens without permanent pairing drift.
5. Chat uses the selected cloud provider without starting any local Ollama daemon.
6. After a long idle soak, `/health` recovers quickly or the app performs a
   clean gateway restart instead of hanging indefinitely.
7. Opening Chat does not create the canvas WebView until a canvas tool is used.

Fast-looking startup without these markers is a fail. It is better to wait for
real readiness than to land users on a UI that immediately disconnects.

## Long-Idle Stability Checks

Run these after leaving the app idle for several hours:

```powershell
adb -s RZCX30KA9AW shell "dumpsys meminfo com.nxg.openclawproot | grep -E 'TOTAL PSS|Graphics|WebViews|Activities'"
adb -s RZCX30KA9AW shell "cat /proc/net/tcp /proc/net/tcp6 | grep -E '4965|223D|2CAA|2CAB' | wc -l"
adb -s RZCX30KA9AW logcat -d -v time -s flutter:I PlawieService:V | Select-String -Pattern "HEALTH|Probe failed|restart|Gateway recovered|Paired|Declaring"
```

Expected:

- Gateway `/health` is responsive or the watchdog restarts the gateway after
  sustained HTTP misses.
- Node reconnects only after `Gateway RPC discovery complete`.
- Chat idle should not hold a canvas WebView before the first canvas command.
- Memory should not remain in the 1 GB+ graphics/PSS range after closing camera,
  canvas, dashboard, or returning to Home.

## NDK Bridge Experiment

Run this only after the Gateway/Node baseline passes.

1. Open Local LLM.
2. Download or start the smallest available model first, usually Qwen 2.5 0.5B.
3. Confirm direct NDK chat works with model id `local-llm/...`.
4. In `Gateway Bridge Experiment`, tap `Start Bridge`.
5. Verify `http://127.0.0.1:11435/v1/health` reports the active fllama model.
6. Tap `Use In Gateway`.
7. Send one short chat message and watch gateway logs for `plawie_ndk/local-llm`.

Bridge pass criteria:

- Port `11435` appears only after the user starts the bridge.
- Gateway provider is `plawie_ndk`, model `plawie_ndk/local-llm`.
- A simple chat turn returns text or a clear bridge HTTP error.
- Gateway pairing and Node WebSocket stay stable while the bridge is active.

## Chat Tool Phrase Bank

Use these phrases after the Gateway/Node baseline is healthy. Run cloud-provider
Gateway tests first, then repeat the NDK bridge subset after enabling the manual
HTTP bridge.

### Baseline Sanity

| # | Phrase | Expected result |
| --- | --- | --- |
| 1 | `Say hello in one sentence, then tell me which model/provider you are using.` | Normal assistant response, no local daemon startup. |
| 2 | `List the phone tools you can use right now. Do not invent tools.` | Should mention available device tools or clearly say what it can access. |
| 3 | `Use one tool if available, then explain which tool you used.` | Chat bubble should show a tool call/result chip. |

### Avatar And Gestures

| # | Phrase | Expected result |
| --- | --- | --- |
| 4 | `Wave at me with your right hand, then say hello.` | Avatar plays `wave right` or a supported wave gesture. |
| 5 | `Do a greeting animation, then give me a cheerful one-line welcome.` | Avatar plays `greeting`; TTS or talk fallback speaks if enabled. |
| 6 | `Dance for two seconds, then stop in a ready pose.` | Avatar plays `dance`, then `ready` or returns to idle. |
| 7 | `Show a peace sign and say: tools are online.` | Avatar plays `peacesign`; speech path should fire. |
| 8 | `Bow politely, then explain what you just did.` | Avatar should map to `bowing` or a supported gesture. |
| 9 | `Use this exact inline animation marker in your reply: (gesture:shoot).` | Chat strips marker from visible text and avatar plays `shoot`. |

Supported high-confidence gestures include `greeting`, `dance`, `cute`,
`elegant`, `fight`, `peacesign`, `pose`, `powerful`, `ready`, `shoot`, `spin`,
`squat`, `talk`, `idle`, `wave left`, `wave right`, `both wave`, and `bowing`.

### Device Node Tools

| # | Phrase | Expected result |
| --- | --- | --- |
| 10 | `Vibrate the phone once briefly.` | `haptic.vibrate` call succeeds. |
| 11 | `Turn the flashlight on, wait one second, then turn it off.` | `flash.on` then `flash.off`; no stuck torch. |
| 12 | `Check whether the flashlight is currently on.` | `flash.status` result appears. |
| 13 | `Read the phone sensors and summarize accelerometer/gyro availability.` | `sensor.list` or `sensor.read` result appears. |
| 14 | `Get my approximate current location and summarize it without exposing exact coordinates unless needed.` | `location.get`; permission prompt or safe result. |
| 15 | `Take one photo with the camera and attach it to this chat.` | `camera.snap`; image appears inline and overlay can close. |
| 16 | `Record a very short screen clip if permission is available, then tell me whether it succeeded.` | `screen.record`; permission/success/failure is explicit. |

### Canvas / Browser Overlay

| # | Phrase | Expected result |
| --- | --- | --- |
| 17 | `Open https://example.com in canvas and tell me when it loads.` | Canvas panel opens and navigates. |
| 18 | `Take a snapshot of the current canvas page and attach it here.` | `canvas.snapshot`; image appears inline. |
| 19 | `Run JavaScript in the canvas to return document.title.` | `canvas.eval`; result should be `Example Domain` if still on example.com. |
| 20 | `Close or minimize anything you opened if you can, then confirm the canvas is no longer blocking chat.` | Overlay should not trap the UI. |

### Gateway Skills / Cloud Provider

| # | Phrase | Expected result |
| --- | --- | --- |
| 21 | `Use your normal OpenClaw skills to answer: what time is it roughly, and what tools did you consider?` | Gateway run completes without `tools.allow` warnings. |
| 22 | `Do not use the phone hardware. Just reason step by step in three bullets about how to test Plawie.` | Pure model response; no accidental tool call. |
| 23 | `If web/search tools are available, fetch one current fact. If not, say exactly that no web tool is available.` | Honest tool-awareness, no hallucinated browsing. |

### NDK Direct Mode

Run these before the HTTP bridge. This path is private/offline and does not use
Gateway tools.

| # | Phrase | Expected result |
| --- | --- | --- |
| 24 | `Reply with exactly one short sentence: NDK direct is alive.` | Fast local text response. |
| 25 | `Explain in two bullets what you can and cannot do in offline mode.` | Should not claim full Gateway skills. |
| 26 | `Wave at me, then answer in one sentence.` | Local avatar/TTS integration should work even without Gateway tools. |

### NDK HTTP Bridge To Gateway

Run these only after `11435` is listening and `/v1/health` responds.

| # | Phrase | Expected result |
| --- | --- | --- |
| 27 | `Reply with one sentence and include the active model name if you know it.` | Gateway routes to `plawie_ndk/local-llm`. |
| 28 | `Do not use tools. Just say: bridge text path works.` | Text-only bridge success. |
| 29 | `Try to vibrate the phone once. If tools are unavailable through this bridge, say so clearly.` | Reveals whether bridge tool calling is actually wired. |
| 30 | `Try a wave gesture. If you cannot call the avatar tool, include the text marker (gesture:greeting).` | Either tool call or inline fallback gesture. |

For any failure, capture:

1. Phrase number.
2. Exact visible chat output.
3. Whether a tool chip appeared.
4. Gateway log lines around the turn.
5. Node log lines around the turn.

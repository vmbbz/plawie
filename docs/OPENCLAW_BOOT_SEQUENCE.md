# OpenClaw Boot Sequence

Last updated: 2026-05-25

This is the production startup contract for Plawie on Android.

## Core Principle

Gateway boot and device pairing must never depend on optional local inference.
The stable sequence is:

1. Install/repair OpenClaw in PRoot.
2. Write one hardened config before the first Gateway start.
3. Start or attach to Gateway.
4. Wait for HTTP readiness and authenticated dashboard token.
5. Wait for operator WebSocket, RPC health, default skills, and tool discovery.
6. Release local device-node auto-connect.
7. Approve local pairing/scopes.
8. Enter the app with Gateway, Node, and dashboard ready.
9. Start model features only after the Gateway baseline is stable.

## Fresh Install

Setup collects:

- Cloud provider choice: Gemini, Claude, OpenAI, Grok/xAI, OpenRouter, or Groq.
- Optional API key.
- Agent name and basic settings.

Setup does not offer embedded Ollama Local or Ollama Cloud. Private offline NDK
models are downloaded later from Local LLM and are not part of Gateway readiness.

Pre-start hardening writes:

- `gateway.bind = loopback`
- `gateway.port = 18789`
- `gateway.mode = local`
- local persistent Gateway auth token
- local dashboard allowed origins
- A bounded Android `tools` policy by default: `profile: full` as the base,
  narrowed only by official groups/stable primitives for nodes, runtime,
  sessions, automation, messaging, files, web, and image.
- The Skills > Tools page can restore this mobile default with Enable All.
  Custom restrictions must be based on runtime-discovered tool IDs or official
  groups, never guessed skill/plugin slugs.
- model provider defaults for the providers exposed in UI
- schema cleanup for legacy invalid keys

## Returning User Startup

1. If bootstrap is incomplete or setup is in progress, do not start Gateway.
2. Migrate stale model IDs, including any old `ollama/...` preference, to the safe cloud fallback.
3. If Gateway is already healthy, attach without mutating config.
4. If Gateway is booting, attach and wait for readiness without causing reload churn.
5. If Gateway is stopped, start it after non-destructive hardening.
6. Once Gateway is interactively ready, reconnect Node and refresh dashboard token.

## Model Routing

| Selection | Runtime | Gateway dependency |
| --- | --- | --- |
| Plain cloud chat | OpenClaw Gateway agent loop | Required |
| Cloud tool/agent request | OpenClaw Gateway agent loop | Required |
| `local-llm/...` | fllama NDK | Bypassed |
| Legacy `ollama/...` | Migrated to fallback | Not started |

Cloud chat is Gateway-first by default. This keeps skills, tool visibility,
Talk/TTS, session memory, and node actions in one official OpenClaw lane.
Direct provider routing is not the release default because it bypasses the
Gateway surfaces users expect when they ask what tools or skills are available.

Every Gateway-routed mobile chat must bind to a mobile-owned session key such
as `mobile:chat:<localChatId>`. Flutter chat must never silently reuse
`main` or `agent:main:main`, because the global main lane is also used by
dashboard/operator flows and can create stale file locks under retry pressure.

If Gateway reports `file lock stale`, `stale_session_state`,
`queued_work_without_active_run`, or similar stale-session recovery logs, the
Chat screen should clear the stored mobile session key and ask the user to
resend instead of repeatedly pushing new work into the same poisoned lane.

NDK mode intentionally bypasses Gateway token lookup, WebSocket setup, and
Gateway TTS. This protects pairing and health checks when local inference is
heavy.

## Tool Policy

OpenClaw's official tool policy applies `tools.profile` first, then
`tools.allow` / `tools.deny`; `deny` wins. Plawie therefore uses `profile: full`
as the base and narrows it with official groups/stable primitives. `minimal`
cannot be used here because it exposes only `session_status`, and a later
allowlist for browser/canvas/nodes narrows that to zero callable tools.

The release default is a bounded mobile policy, not unrestricted/full:

```json
{
  "profile": "full",
  "allow": [
    "group:nodes",
    "group:runtime",
    "group:sessions",
    "group:automation",
    "group:messaging",
    "group:fs",
    "group:web",
    "image"
  ]
}
```

This keeps mobile node/web/file/session tools available while avoiding guessed
entries that OpenClaw warns about. Do not write device feature names such as
`camera`, `canvas`, `flash`, `torch`, `location`, `screen`, `sensor`, or
`haptic` into `tools.allow`; those are node-side commands/capabilities declared
by the Android node, not top-level Gateway tool IDs.

The Android node allow-command list must be explicit and include aliases used
by the Gateway/model, including `camera.*`, `canvas.*`, `flash.*`, `torch.*`,
`location.*`, `screen.*`, `sensor.*`, `haptic.vibrate`, and `vibrate`.

Healthy tool logs should not include:

```text
tools.allow allowlist contains unknown entries (canvas, memory, computer)
```

If that warning returns, the pre-start config writer and runtime hardener have
drifted again.

## Gateway Talk / TTS

Android Talk should follow the OpenClaw Talk contract:

- Local speech recognition captures the user.
- Gateway chat handles the model turn.
- `talk.speak` plays the reply through the configured Gateway Talk provider.

The app must not show Gateway Voice as ready when `talk.catalog`,
`talk.status`, or `providers.status` says the active provider is not configured.
In that state, the Test Gateway Voice button should be disabled with a clear
message. A raw snackbar such as this is an alarm, not a usable UX:

```text
talk.speak unavailable: talk provider not configured
```

Native Android system TTS is only a fallback when the `talk.speak` RPC is truly
unavailable. It is not a substitute for a missing Gateway Talk provider.

## Dashboard Pairing

The dashboard is another local client. It may request pairing/scopes separately
from the device node. Plawie should approve local dashboard requests when the
request ID is visible and Gateway is healthy, then refresh the WebView.

## Healthy Logs

Healthy startup should include:

```text
[GATEWAY] Process detected / starting
[GATEWAY] Gateway token confirmed; waiting for HTTP readiness
[GATEWAY] Health OK
[GATEWAY] WebSocket handshake complete
[GATEWAY] Health RPC: ok=...
[GATEWAY] Active skills: ...
[GATEWAY] Gateway RPC discovery complete; node auto-connect released.
[NODE] Connecting to 127.0.0.1:18789
[NODE] WebSocket connected, awaiting challenge
[NODE] Declaring commands
[NODE] Connect accepted
[NODE] Paired and connected
```

If Node logs appear before `Gateway RPC discovery complete`, the app is pairing
too early. That can look faster, but it is not production-ready because the
gateway may still be loading default skills or recovering its operator RPC
surface.

Expected local ports:

- `18789`: OpenClaw Gateway WebSocket/HTTP.
- `8765`: Plawie app capability bridge.

There should be no required `11434` Ollama listener in the production path.
The experimental NDK bridge, when manually enabled, uses `11435` and must not
start during setup or returning-user attach.

## Alarm Conditions

Investigate immediately if logs show:

- Gateway restarts repeatedly during first setup.
- Skills never load after Gateway health is OK.
- Node repeatedly loses nonce/challenge state after successful pairing.
- Dashboard keeps asking for a new request ID after auto-approval.
- Mobile chat uses `main` or `agent:main:main` instead of `mobile:chat:*`.
- Gateway logs `file lock stale`, `stale_session_state`,
  `queued_work_without_active_run`, or long-lived `processing` on a mobile chat
  session after the UI has already timed out.
- Gateway logs unknown `tools.allow` entries such as `canvas`, `memory`, or
  `computer`.
- Gateway Voice allows a test while Talk provider status is unconfigured.
- `node command not allowed` or `did not declare any supported commands` after
  pairing succeeds (this usually means stale command snapshot; trigger re-pair).
- Any code path tries to download/start Ollama during setup or dashboard open.
- The NDK bridge appears in Gateway logs without the user manually enabling the
  bridge experiment.

## Recovery Rules

- Prefer attach over restart when Gateway is already running.
- Do not write config while Gateway is settling unless the user explicitly repairs.
- Regenerate Node auth token only for real pairing loops; it intentionally resets active sessions.
- If node command declarations change between app versions, force a fresh
  node pairing so Gateway updates its stored command snapshot.
- Treat NDK memory pressure separately from Gateway stability.
- If a mobile chat session becomes stale, clear only that mobile chat session
  binding and resend into a fresh `mobile:chat:*` key. Do not restart Gateway as
  the first recovery step.

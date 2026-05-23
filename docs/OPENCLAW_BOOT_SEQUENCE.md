# OpenClaw Boot Sequence

Last updated: 2026-05-23

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
- `tools.allow = ["*"]`
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
| Cloud provider model | OpenClaw Gateway | Required |
| `local-llm/...` | fllama NDK | Bypassed |
| Legacy `ollama/...` | Migrated to fallback | Not started |

NDK mode intentionally bypasses Gateway token lookup, WebSocket setup, and
Gateway TTS. This protects pairing and health checks when local inference is
heavy.

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
- Any code path tries to download/start Ollama during setup or dashboard open.
- The NDK bridge appears in Gateway logs without the user manually enabling the
  bridge experiment.

## Recovery Rules

- Prefer attach over restart when Gateway is already running.
- Do not write config while Gateway is settling unless the user explicitly repairs.
- Regenerate Node auth token only for real pairing loops; it intentionally resets active sessions.
- Treat NDK memory pressure separately from Gateway stability.

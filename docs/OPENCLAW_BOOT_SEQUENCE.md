# OpenClaw Boot Sequence

Last updated: 2026-05-28

This is the production startup contract for Plawie on Android.

## Core Principle

Gateway boot and device pairing must never depend on optional local inference.
The stable sequence is:

1. Install or repair OpenClaw in PRoot.
2. Write one hardened config before the first Gateway start.
3. Start or attach to Gateway.
4. Wait for HTTP readiness and authenticated dashboard token.
5. Wait for operator WebSocket, RPC health, default skills, and tool discovery.
6. Release local device-node auto-connect.
7. Approve local pairing/scopes.
8. Enter the app with Gateway, Node, and dashboard ready.
9. Start local model features only after the Gateway baseline is stable.

## Fresh Install

Setup collects:

- Cloud provider choice: Gemini, Claude, OpenAI, Grok/xAI, OpenRouter, or Groq.
- Optional API key.
- Agent name and basic settings.

Setup does not offer embedded Ollama Local or Ollama Cloud. Private offline NDK
models are downloaded later from Local LLM.

Pre-start hardening writes:

- `gateway.bind = loopback`
- `gateway.port = 18789`
- `gateway.mode = local`
- local persistent Gateway auth token
- local dashboard allowed origins
- bounded Android tool policy
- model provider defaults from `ModelProviderCatalog`
- safe model `contextWindow` and `maxTokens` values
- schema cleanup for legacy invalid keys

## Returning User Startup

1. If bootstrap is incomplete or setup is in progress, do not start Gateway.
2. Migrate stale model IDs, including old `ollama/...` preferences, through the
   catalog.
3. If Gateway is already healthy, attach without config churn.
4. If Gateway is booting, attach and wait for readiness.
5. If Gateway is stopped, start it after non-destructive hardening.
6. Once Gateway is interactively ready, reconnect Node and refresh dashboard token.

## Model Routing

| Selection | Runtime | Gateway dependency |
| --- | --- | --- |
| Cloud provider model | OpenClaw Gateway agent loop | Required |
| `local-llm/...` | fllama NDK direct | Bypassed |
| `plawie_ndk/local-llm` | Gateway -> NDK bridge -> fllama | Required and manual |
| Legacy `ollama/...` | Catalog migration | Not started |

Cloud chat is Gateway-first by default. This keeps skills, tool visibility,
Talk/TTS, session behavior, node actions, and diagnostics in one lane. Direct
provider routing is not the release default.

## Gateway Chat Sessions

Current code keeps mobile Gateway chat on the proven default session lane. The
app preserves visible chat history locally; arbitrary mobile session keys are
not used by default because this OpenClaw build can accept them and then stall
with `queued_work_without_active_run`.

If upstream session dispatch changes, update the code and this document
together. Do not reintroduce per-chat Gateway session keys based only on a
successful `sessions.create` call.

## Model Policy

`ModelExecutionPolicy` and `ModelProviderCatalog` own model budgets. The boot
hardener should not invent model context/output values independently.

Known models get:

- `contextWindow`: provider/model request budget.
- `maxTokens`: safe per-request output cap.
- `toolPolicy`: reliable, variable, or disabled.

The policy prevents output-budget overflow and helps the UI explain expected
capability. It does not guarantee that a model is intelligent enough to use
tools correctly.

## Tool Policy

OpenClaw applies `tools.profile` first, then `tools.allow` / `tools.deny`.
`deny` wins. Plawie uses `profile: full` as the base and narrows it with
official groups/stable primitives:

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

Do not write device feature names such as `camera`, `canvas`, `flash`, `torch`,
`location`, `screen`, `sensor`, or `haptic` into `tools.allow`. Those are
node-side commands/capabilities declared by the Android node.

## Gateway Talk / TTS

Gateway-routed chat should use OpenClaw Talk when configured. Direct local NDK
chat can use native/local speech paths because it bypasses Gateway.

Chat provider configuration and Talk provider configuration are separate. Do not
show Gateway Voice as ready unless `talk.catalog`, `talk.status`, or
`providers.status` confirms the active Talk provider is configured.

## Ports

| Port | Purpose |
| --- | --- |
| `18789` | OpenClaw Gateway HTTP/WebSocket |
| `8765` | Plawie app capability bridge |
| `11435` | Manual NDK Gateway bridge |
| `11434` | Legacy Ollama, not required |
| `8081` | Legacy PRoot llama-server, not required |

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

## Alarm Conditions

Investigate immediately if logs show:

- Gateway restarts repeatedly during first setup.
- Skills never load after Gateway health is OK.
- Node connects before `Gateway RPC discovery complete`.
- Node pairs with zero declared commands.
- Gateway writes config or reloads repeatedly during first setup.
- Gateway logs unknown `tools.allow` entries such as `canvas`, `memory`, or
  `computer`.
- Gateway Voice allows a test while Talk provider status is unconfigured.
- Any path tries to download/start Ollama during setup or cloud-provider chat.
- The NDK bridge appears in Gateway logs without the user manually enabling it.
- A provider reports maximum-context errors where output tokens are near the
  full context window; fix catalog `maxTokens`, not the user's prompt first.

## Recovery Rules

- Prefer attach over restart when Gateway is already running.
- Do not write config while Gateway is settling unless the user explicitly repairs.
- Regenerate Node auth token only for real pairing loops.
- If node command declarations change between app versions, force fresh node
  pairing so Gateway updates its command snapshot.
- Treat NDK memory pressure separately from Gateway stability.
- If Gateway session dispatch stalls, keep chat on the default lane until
  upstream session behavior is proven stable.

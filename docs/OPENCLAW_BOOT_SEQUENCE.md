# OpenClaw Android Boot And Pairing Sequence

This document is the production sequence contract for Plawie/OpenClaw on Android.
It exists so setup, returning-user startup, pairing, dashboard access, and Ollama
routing stay aligned as OpenClaw Gateway security rules evolve.

## Core Invariants

- The gateway must be configured before it starts.
- Fresh setup must finish on the app home page with gateway health OK, operator WS connected, default skills discoverable, and the node either paired or actively completing first-pair recovery.
- Returning users must not need to delete app data. Cached gateway token, operator device token, node token, and dashboard URL must self-heal if stale.
- Runtime hardening must not rewrite config while the gateway is settling unless the user explicitly starts a repair path.
- Local Ollama must not ask users for a real API key. For loopback/local Ollama, OpenClaw uses the placeholder credential `ollama-local`.
- If the selected model is `ollama/...` (local or `:cloud`), returning-user startup must ensure the internal Ollama Hub is running before dashboard/webchat/chat can depend on it.
- Web dashboard pairing requires an operator connection with `operator.admin` on the current v2026.5.x gateway.

## Fresh Install Sequence

1. Stop any live gateway process before setup rewrites config.
2. Extract/install the Android runtime and PRoot assets.
3. Install or update `openclaw@latest` from npm. Do not use old bundled OpenClaw assets unless live install is impossible.
4. Run non-interactive OpenClaw onboarding only as a bootstrap helper.
5. Immediately re-harden config after onboarding because upstream defaults can add schema-invalid or mobile-hostile fields.
6. Generate and persist `gateway.auth.token` before first gateway start.
7. Mirror the same secret into `gateway.remote.token` for local dashboard/CLI compatibility.
8. Force local gateway mode:
   - `gateway.mode = local`
   - `gateway.bind = loopback`
   - `gateway.port = 18789`
   - `gateway.controlUi.allowedOrigins = ["http://127.0.0.1:18789", "http://localhost:18789"]`
9. Disable startup churn:
   - `gateway.startup.modelPrewarm = false`
   - `models.startup.modelPrewarm = false`
   - `gateway.startup.updateCheck = false`
   - browser and model-prewarm sidecars disabled
10. Configure provider defaults from the centralized model catalog:
   - Google: `google/gemini-3.1-pro-preview`
   - Anthropic: `anthropic/claude-opus-4-6`
   - OpenAI: `openai/gpt-5.4`
   - xAI/Grok: `xai/grok-4`
   - Groq: `groq/llama-3.3-70b-versatile`
   - Ollama Local: `ollama/qwen2.5:0.5b`
   - Ollama Cloud: `ollama/kimi-k2.5:cloud`
11. Configure local Ollama:
   - `models.providers.ollama.baseUrl = "http://127.0.0.1:11434"`
   - `models.providers.ollama.apiKey = "ollama-local"`
   - `models.providers.ollama.api = "ollama"`
   - primary model defaults to the setup-selected catalog model; API-key providers require credentials, Ollama Local uses `ollama-local`, and Ollama Cloud waits for user sign-in.
12. Write canonical model auth:
   - `openclaw.json auth.profiles.ollama:default = { provider: "ollama", mode: "api_key" }`
   - `auth-profiles.json profiles.ollama:default = { type: "api_key", provider: "ollama", key: "ollama-local" }`
13. Write default Gateway tool permissions:
   - `tools.allow = ["*"]`
   - UI expands the wildcard into the valid primitive tool list so Tools tab reflects the real backend state.
   - Individual lockdown writes an explicit allow list; invalid skill/device names are never written into `tools.allow`.
14. Clear node device token for first-pair path only during setup.
15. Start the gateway once.
16. Wait for operational readiness:
   - HTTP health OK
   - operator WebSocket connected
   - `skills.status` or equivalent RPC returns active skills
   - no schema reload failure
17. Start/attach the device node.
18. Approve first node pairing by request ID.
19. Navigate to app dashboard/home only after the gateway has settled enough to avoid post-start reload loops.

## Returning User Sequence

1. Check whether bootstrap is complete.
2. If gateway is already running and healthy:
   - do not rewrite `openclaw.json`
   - refresh the gateway token/dashboard URL
   - ensure local Ollama `auth-profiles.json` exists because this file can be repaired without restarting the gateway
   - if the persisted primary model starts with `ollama/` (including `:cloud`), start the internal Ollama Hub in the background when `127.0.0.1:11434` is not reachable
   - attach operator WebSocket
   - run passive hardening verification only
3. If gateway is running but not fully attached:
   - attach logs
   - clear stale in-memory token caches
   - do not run `openclaw doctor --fix` or config reload during the settle window
   - reconnect operator WS
4. If gateway is not running and autostart/force-start is allowed:
   - run `_configureGateway()`
   - write canonical Ollama auth profile
   - start gateway
   - wait for health, WS, and skills
5. If cached operator or node tokens are stale:
   - gateway returns `pairing required`
   - app clears only the affected token
   - app approves the pending request by request ID
   - app reconnects with the newly issued token

## Actors And Scopes

| Actor | Client ID | Role | Expected scopes | Purpose |
| --- | --- | --- | --- | --- |
| Flutter control plane | `openclaw-control-ui` | `operator` | `operator.admin`, `operator.read`, `operator.write`, `operator.approvals`, `operator.pairing`, `operator.talk.secrets` | App control, chat/session calls, approvals, dashboard pairing |
| Device node | `node-host` | `node` | usually empty on WS connect | Phone capabilities: camera, canvas, location, screen, sensors, haptics |
| Web dashboard/WebChat | `openclaw-control-ui` | browser/operator-like | approved by device pairing | Browser dashboard served from gateway |
| CLI helper | `cli` | operator | token/password derived | Setup, pairing approval, diagnostics |

`operator.admin` is requested by the Flutter operator WS because the current gateway rejects browser dashboard approvals with `missing scope: operator.admin`. Older cached operator tokens can trigger one scope-upgrade pairing cycle after update; the app must clear that cached token, approve by request ID, and reconnect once.

## Tool Permissions

Plawie defaults OpenClaw primitive tools to enabled with:

```json
{
  "tools": {
    "allow": ["*"]
  }
}
```

This is safe for Plawie's local-first runtime because the gateway is loopback
bound, token protected, and paired-device scoped. The powerful primitives
(`shell`, `computer`, `files`, `browser`) should not be exposed to arbitrary LAN
clients or unauthenticated dashboards.

The Skills Manager Tools tab expands `["*"]` into the concrete primitive tool
IDs so users see the real active state instead of a false "all disabled" UI.
The one-tap Enable All button writes `["*"]`. Individual toggles write an
explicit allow list. Device capabilities such as camera/location/sensors are
not written into `tools.allow`; they are node/custom-skill capabilities.

## Pairing Flows

### Operator Pairing

1. Flutter connects to the gateway WebSocket with the stable gateway token.
2. If the operator device is unknown or asks for upgraded scopes, gateway closes with `1008 pairing required`.
3. App extracts `requestId`.
4. App approves the request via CLI/shared token.
5. App reconnects and stores the operator device token.

### Node Pairing

1. Node connects without a cached node token on first install.
2. Gateway replies `NOT_PAIRED` with a `requestId`.
3. Node disconnects with `1008 pairing required`.
4. App approves the request.
5. Node reconnects with the issued device token.
6. Expected success line: `[NODE] Paired and connected`.

Node connect frames must include the current `connect.challenge` nonce. Reconnect
races can deliver the challenge before the node handshake waiter is installed; the
app caches that nonce briefly, clears it on disconnect, and refuses to send a
no-nonce `connect` frame. A successful `[NODE] Paired and connected` clears any
old nonce/protocol error from the Node UI.

### Web Dashboard Pairing

1. WebView loads the authenticated dashboard URL.
2. The dashboard browser identity may still need device pairing.
3. Gateway emits/logs `device.pair.requested`.
4. App auto-approves by `requestId` using the already-connected operator WS.
5. This requires `operator.admin`.
6. If the current operator token is missing `operator.admin` or `operator.pairing`, the app clears the cached operator token, reconnects with the expanded scope set, and retries.
7. The WebView schedules short reloads after approval so the user does not need to manually leave and return.

## Ollama Auth Rules

OpenClaw's current local Ollama behavior is:

- Local/LAN Ollama does not require a real user API key.
- The placeholder `ollama-local` is valid for loopback/private Ollama hosts.
- Ollama `:cloud` models also require the local Ollama daemon because the daemon proxies signed-in requests to ollama.com.
- Ollama `:cloud` needs `ollama signin` / Ollama account auth, not a manually entered API key.
- `ECONNREFUSED 127.0.0.1:11434` is a daemon reachability problem, not an API-key problem.
- Endpoint details belong in `models.providers.ollama`.
- Runtime credentials belong in the versioned `auth-profiles.json` store.
- Old flat auth stores such as `{ "providers": { "ollama": { "apiKey": "..." }}}` are not reliable runtime format.

The official Ollama `ollama launch openclaw` flow is useful for desktop/CLI
onboarding because Ollama can configure OpenClaw, pick a model, and start the
gateway. Plawie cannot rely on that interactive host flow inside Android PRoot,
so it writes the equivalent local provider/auth configuration itself and manages
the embedded Ollama daemon lifecycle. For cloud models, Plawie must still launch
the embedded daemon and guide the user through Ollama sign-in.

Required local files:

```json
{
  "auth": {
    "profiles": {
      "ollama:default": {
        "provider": "ollama",
        "mode": "api_key"
      }
    },
    "order": {
      "ollama": ["ollama:default"]
    }
  }
}
```

```json
{
  "version": 1,
  "profiles": {
    "ollama:default": {
      "type": "api_key",
      "provider": "ollama",
      "key": "ollama-local"
    }
  }
}
```

## Expected Client Counts

Client count is a live WebSocket count, not a device count.

| Count | Usually means |
| --- | --- |
| 1 | One operator/control connection during early setup |
| 2 | Operator UI plus another control/helper connection |
| 3 | Stable app runtime with operator + node + helper/control stream |
| 4 | Web dashboard/WebChat is open in addition to app runtime |

Temporary CLI probes and dashboard tabs can increase this briefly. The important check is whether the count settles after disconnects and whether health events keep flowing.

## Normal Transient Logs

These can appear during first-pair or gateway settle and are not automatically fatal:

- `pairing required: device is not approved yet`
- `close code=1008` during first operator/node/dashboard pairing
- node `NOT_PAIRED` before approval
- a small number of `handshake-timeout` logs while the gateway is still loading plugins
- `unknown-ip` in security audit logs from local CLI/helper flows where forwarded IP metadata is unavailable
- client count briefly rising when WebView or CLI helpers connect
- a single node reconnect waiting for a fresh `connect.challenge` nonce

## Hard Failures

These should not persist after setup:

- default skills never appear
- `No API key found for provider "ollama"` after canonical auth profile repair
- `missing scope: operator.pairing` after operator token refresh
- `missing scope: operator.admin` after operator token refresh
- repeated gateway restarts after setup says complete
- schema reload failures or `Unrecognized keys`
- event-loop delay warnings that never settle after plugins finish loading
- repeated node token nonce/protocol errors after a token refresh
- repeated `ECONNREFUSED 127.0.0.1:11434` after Ollama Hub autostart has been attempted
- `provider=ollama ... :cloud` plus `endpoint=local route=local` while the embedded daemon is stopped
- selecting Gemini/Claude/OpenAI/Grok/Groq model without the matching provider credential
- web dashboard stuck on pairing after operator WS has `operator.admin`

## Log Signatures To Watch

Healthy:

```text
[gateway] ready
Gateway is healthy
[INFO] WebSocket handshake complete
[INFO] Active skills: ...
[plugins] loaded 45 plugin(s)
[NODE] Paired and connected
webchat connected
```

Needs repair:

```text
missing scope: operator.pairing
missing scope: operator.admin
No API key found for provider "ollama"
connect ECONNREFUSED 127.0.0.1:11434
config reload skipped
File changed during read
protocol mismatch
```

## Code Owners

- Fresh install hardening: `lib/services/bootstrap_service.dart`
- Gateway config/auth/startup: `lib/services/gateway_service.dart`
- Operator WS handshake/scopes: `lib/services/gateway_connection.dart`
- Node WS pairing and node UI logs: `lib/services/node_service.dart`, `lib/services/node_ws_service.dart`, `lib/screens/node_screen.dart`
- Dashboard WebView pairing helper: `lib/screens/web_dashboard_screen.dart`
- Gateway provider facade: `lib/providers/gateway_provider.dart`

## Official References

- OpenClaw Ollama provider docs: https://docs.openclaw.ai/providers/ollama
- OpenClaw auth storage reference: https://github.com/openclaw/openclaw/blob/main/docs/gateway/configuration-reference.md#auth-storage
- OpenClaw operator scopes: https://docs.openclaw.ai/gateway/operator-scopes
- OpenClaw gateway-owned pairing: https://docs.openclaw.ai/gateway/pairing
- Ollama OpenClaw integration: https://docs.ollama.com/integrations/openclaw

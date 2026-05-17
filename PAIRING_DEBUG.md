# OpenClaw Android Pairing & Boot Architecture (Current Production)

**Status:** Canonical as-built flow (updated 2026-05-17)

This document is the source of truth for how pairing and gateway boot work in the current Android app.
It reflects the live implementation in `BootstrapService`, `GatewayService`, `GatewayConnection`, `NodeService`, and `NodeWsService`.

---

## What Was The Blocking Issue?

The blocker was a pairing/auth contract drift across startup and reconnect paths:

- some reconnect attempts were approving the wrong pending request,
- some flows were retrying without explicit gateway auth context,
- local gateway auth and remote credentials could drift,
- and stale/invalid node tokens stayed in the reconnect path after 1008 closures.

The shipped fix aligns all pairing paths to one requestId-driven approval contract and keeps local gateway auth synchronized before normal runtime traffic.

---

## Mermaid: Actual Boot + Pairing Flow

```mermaid
flowchart TD
    A[App Launch] --> B[BootstrapService.runFullSetup]
    B --> C[_fullPreStartConfigHardening]
    C --> D[Patch openclaw.json + CLI config set]
    D --> E[_syncLocalGatewayRemoteCredentials]
    E --> F[gateway.remote.token/password <- gateway.auth.* in local mode]
    F --> G[Remove permissive auth/origin fallback flags]
    G --> H[GatewayService.attachOrStart]

    H --> I[GatewayService.hardenGatewayConfigViaCli]
    I --> J[openclaw config patch + optional reload]

    J --> K[NodeService.connect]
    K --> L{prefs.nodeDeviceToken exists?}

    L -- No --> M[Send v3 connect frame as node-host platform=android]
    M --> N[Gateway may close 1008 pairing required + requestId]
    N --> O[_handleNodePairingRequired(requestId)]
    O --> P[openclaw devices approve requestId --json]
    P --> Q{plain approve failed?}
    Q -- Yes --> R[Retry approve with --url ws://127.0.0.1:18789 --token <gatewayAuthToken> --json]
    Q -- No --> S[Read approved token from nodes/paired.json or node.json]
    R --> S
    S --> T[Save prefs.nodeDeviceToken]
    T --> U[disconnect + reconnect]

    L -- Yes --> V[Send auth.deviceToken on connect]
    V --> W[Gateway hello-ok]

    U --> W
```

---

## Production Contract (What Must Always Stay True)

### 1) Pre-start hardening is mandatory

`BootstrapService` runs pre-start hardening before normal gateway runtime traffic:

- forces `gateway.bind=loopback`, `gateway.port=18789`, `gateway.mode=local`
- sets loopback-only control UI origins
- enforces node pairing defaults (`autoApproveCidrs=[127.0.0.1/32]`)
- removes dangerous permissive switches
- applies patch atomically via `openclaw config patch`

### 2) Auth mode and local remote credentials must remain aligned

Both bootstrap and runtime hardening call `_syncLocalGatewayRemoteCredentials`:

- if local mode and `gateway.auth.token` exists, set `gateway.remote.token` to match
- if local mode and `gateway.auth.password` exists, set `gateway.remote.password` to match
- remove remote credentials when matching auth source is absent

This prevents local CLI/device approval calls from drifting away from active gateway auth state.

### 3) Pairing is requestId-driven

When the node path gets a 1008 close with pairing-required context:

- extract `requestId`
- clear stale cached node token
- approve the exact pending request via CLI
- if plain approve fails, retry with explicit `--url` and `--token`
- persist the new approved token
- reconnect cleanly

### 4) Token persistence strategy

Node token sources in priority order:

1. `prefs.nodeDeviceToken` (runtime cache)
2. `~/.openclaw/nodes/paired.json`
3. `~/.openclaw/node.json`

The reconnect path always uses `auth.deviceToken` when available.

---

## Runtime Sequence Details

### Bootstrap stage

`BootstrapService.runFullSetup`:

- performs base setup/install
- executes `openclaw onboard --non-interactive` (non-fatal)
- re-hardens config after onboard
- runs `_fullPreStartConfigHardening`
- starts gateway with `GatewayService.attachOrStart`

### Gateway stage

`GatewayService.attachOrStart` + `_configureGateway` + `hardenGatewayConfigViaCli`:

- reasserts local bind + port + origin policy
- removes `unauthenticatedLocalhost`
- removes dangerous host-header origin fallback
- applies a hardening patch and reload when already running

### Node stage

`NodeService.connect`:

- opens websocket to `ws://127.0.0.1:18789`
- sends protocol v3 connect as:
  - `client.id = node-host`
  - `client.mode = node`
  - `platform = android`
- includes `auth.deviceToken` only when cached
- on first-time path, omits scopes to allow fresh pairing behavior

`NodeService._handleNodePairingRequired`:

- one-shot guard (`_pairingResolveAttempted`)
- clears cached token before approval
- approves requestId through CLI
- falls back to explicit `--url` + `--token` when needed
- stores approved token
- disconnects and reconnects

### Operator stage (separate from node pairing)

`GatewayConnection` maintains a separate operator WebSocket session (`client.id=openclaw-control-ui`).
If operator pairing is required, `GatewayService` handles it via the same requestId-driven CLI approval pattern and then reconnects the control plane.

---

## Files That Define This Contract

- `lib/services/bootstrap_service.dart`
- `lib/services/gateway_service.dart`
- `lib/services/gateway_connection.dart`
- `lib/services/node_service.dart`
- `lib/services/node_ws_service.dart`
- `lib/services/native_bridge.dart`
- `lib/services/preferences_service.dart`

---

## State Stores (Authoritative Paths)

- `~/.openclaw/openclaw.json`: gateway and model configuration
- `~/.openclaw/nodes/paired.json`: node pairing approvals/tokens
- `~/.openclaw/node.json`: node identity/token fallback store
- shared preferences key `node_device_token`: runtime token cache used for reconnect

---

## Known Good Log Signatures

Node flow signals:

- `[NODE] No cached node device token — using first-time pairing path`
- gateway close reason contains `pairing required` with `requestId`
- `[NODE] Device approved; received new node token (...)`
- `[NODE] Paired and connected`

Gateway flow signals:

- `device pairing auto-approved ... role=operator` (when auto-approval path applies)
- `hello-ok` after reconnect
- no repeated `INVALID_REQUEST errorMessage=unknown requestId` loops

---

## Quick Triage Checklist (When 1008 Reappears)

1. Confirm 1008 reason includes `pairing required` and requestId.
2. Confirm `openclaw devices approve <requestId> --json` succeeds.
3. If plain approval fails, verify explicit retry with `--url` and `--token` is executed.
4. Verify `prefs.nodeDeviceToken` is updated after approval.
5. Verify approved token exists in `~/.openclaw/nodes/paired.json` (or `node.json`).
6. Verify `gateway.remote.token` matches `gateway.auth.token` in local mode.
7. Verify permissive fallback flags are absent from active config.

---

## Recovery Commands (Manual Emergency Use)

Run inside PRoot shell:

```bash
openclaw devices list --json
openclaw devices approve <requestId> --json
openclaw devices approve <requestId> --url ws://127.0.0.1:18789 --token <gatewayToken> --json
```

Use explicit `--url` and `--token` when plain approval fails due active auth context mismatch.

---

## Notes For New Android Developers

If you are debugging pairing, do not bypass this contract with ad-hoc JSON edits or alternate approval routes.
Use the requestId-driven flow and keep auth synchronization in place; that is the path validated by production logs and the current implementation.

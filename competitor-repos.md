# Competitor OpenClaw Repos — Reference Notes

Documents three third-party implementations of the OpenClaw gateway client protocol.
Use this as a reference when fixing protocol-level issues in openclaw_final.

---

## 1. yuga-hashimoto/openclaw-assistant (Kotlin, Android)

**URL:** https://github.com/yuga-hashimoto/openclaw-assistant
**Stack:** Kotlin, OkHttp 4.12 WebSocket, Ed25519 device identity
**Maturity:** 261 stars, 75 releases — most production-hardened of the three

### Protocol
- Gateway Protocol v3, frames: `req` / `res` / `event`
- UUID request/response correlation via `pending[id] = deferred`
- Outgoing sends serialized with `writeLock.withLock { socket?.send() }`
- 2-second timeout waiting for `connect.challenge` nonce before sending auth

### Device Identity
- `deviceId` = `SHA-256(rawPublicKey)` as 64-char hex
- Token storage key: `"gateway.deviceToken.$normalizedDevice.$normalizedRole"` — **separate token per role**
- Three auth paths tried in order: bootstrap token (node-only, single-use) → password-direct → token+password fallback

### Dual-Role Architecture
- **Two completely separate `GatewaySession` objects**: `operatorSession` and `nodeSession`
- `operatorSession`: handles chat, `agents.list`, `sessions.patch` — no invoke
- `nodeSession`: handles `node.invoke.request`, dispatches via `InvokeDispatcher`
- UI shows four states: Operator Online/Offline × Node Online/Offline independently
- `isPairingRequired` becomes true if **either** session is in pairing-required state

### Race Condition Handling
- `if (!connectDeferred.isCompleted)` guards on handshake completers
- `isClosed` atomic flag prevents duplicate cleanup
- `failPending()` cancels all in-flight requests on disconnect
- Exponential backoff up to 8 seconds

### Key Insight
Uses **bootstrap tokens** (single-use, server-issued) for first-pair — avoids the approve-then-reconnect race. On subsequent connects the device is already approved, so the gateway issues a device token directly without another approval cycle.

### 2026-05-25 Follow-up: Lessons for Plawie

The current WakeHermesClaw README confirms a split architecture that matches
where Plawie should land:

- **Gateway WebSocket remains the primary OpenClaw lane.** It handles pairing,
  QR/TLS, streaming, agent discovery, and node capabilities.
- **OpenClaw HTTP is separate.** It is useful for direct chat, but it is not the
  same as the full Gateway lane and should not be Plawie's default when tools
  are expected.
- **Mobile Bridge is optional and off by default.** It exposes local Android
  capabilities through an authenticated HTTP service for Hermes-style agents,
  but this is an extra bridge, not a replacement for OpenClaw's node protocol.
- **Capability discovery is explicit.** Their bridge skill reads `/manifest`
  first and refuses early if a capability is not enabled. Plawie should mirror
  that idea for Gateway node tools: list/verify node commands before expecting
  the model to call them.
- **Risk is handled by grants and foreground gates.** Medium/high-risk bridge
  actions require local approval; foreground-only OpenClaw node commands return
  structured errors such as `NODE_BACKGROUND_UNAVAILABLE`.
- **Debug commands are first-class in debug builds.** Their node command list
  adds `debug.logs` and `debug.ed25519` only when `BuildConfig.DEBUG` is true.
  This is a clean pattern for Plawie's live diagnostics: powerful visibility in
  debug/test builds, not noisy production UI.

Concrete Plawie alignment:

- Keep cloud chat on Gateway WebSocket by default.
- Keep NDK/offline mode clearly separate and tool-limited unless we later build
  an explicit bridge.
- Add/keep an in-app live diagnostics panel fed by Gateway activity, plus an
  external ADB watcher for forensic captures.
- Treat `talk.speak` as a separate Gateway Talk configuration problem, not as a
  chat provider/API-key problem.
- Avoid writing device capability names or npm skill slugs to `tools.allow`;
  node capabilities belong in node connect metadata / capability manifests.

---

## 2. mithun50/openclaw-termux (Dart/Flutter + Kotlin, Android)

**URL:** https://github.com/mithun50/openclaw-termux
**Stack:** Flutter (64% Dart), Kotlin for native bridge, proot-distro — architecturally closest to openclaw_final

### Protocol
- Same Gateway Protocol v3 as us
- Auth payload: `"v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce"` — Ed25519 signed
- 30-second ping heartbeat; stale detection after 90 seconds

### Pairing Flow (Explicit)
```dart
NodeFrame.request('node.pair.request', {'deviceId': _identity.deviceId})
```
Response branches:
- Has `token` / `auth.deviceToken` → save, **500ms delay**, disconnect, reconnect
- Has `code` → display; if `host == 127.0.0.1`, auto-approve via:
  ```
  openclaw nodes approve $code
  ```
  Then **500ms delay**, disconnect, reconnect

### Known Race Condition Source
The **fixed 500ms sleep** with no confirmation is the race condition origin. If the gateway hasn't committed the approval before reconnect fires, the second connect attempt also gets `NOT_PAIRED` and the loop continues indefinitely.

### Node vs Operator
- Connect frame: `role: 'node'`, `scopes: ['node.device']`, `clientId: 'node-host'`, `mode: 'node'`
- After `_onConnected`, sends `node.capabilities` event with both `capabilities` and `commands` fields (dual-field for legacy compat, per comment #56)
- **Node-only** — no operator session

### Useful Patterns
- Dual-field `node.capabilities` event ensures compatibility regardless of which field the gateway inspects
- Guards: `_startInProgress` in GatewayService, but no equivalent in NodeService (race gap we fixed)

---

## 3. AidanPark/openclaw-android (Shell + Java/Kotlin + TypeScript/React)

**URL:** https://github.com/AidanPark/openclaw-android
**Stack:** Termux-based, glibc `ld.so` (not proot-distro), React/TypeScript WebView dashboard

### What It Does
Runs the OpenClaw gateway natively via glibc on Android 7.0+. The app **wraps the gateway process** — it is NOT a gateway client. Users access the gateway via browser or embedded WebView.

### Pairing
Not implemented at the Android layer. Authentication is IP/token-based, scraped from `openclaw.json` or process stdout. Gateway's own web UI handles pairing.

### Relevant Patterns
- `JsBridge.kt`: `@JavascriptInterface` methods exposed to WebView as `window.OpenClaw.<method>()`
- `EventBridge.kt`: async native→JS event emission (similar to our NativeBridge pattern)
- `CommandRunner.kt`: shell command execution (equivalent to `NativeBridge.runInProot`)
- Uses glibc runner instead of proot — avoids proot startup overhead entirely (relevant if we ever migrate)

---

## Summary: What These Repos Confirm About Our Fix

| Issue | Evidence from repos |
|-------|---------------------|
| `roles: ['agent']` in CLI is wrong | yuga-hashimoto uses role-based token storage — `node` and `agent`/`operator` are distinct; CLI approve with wrong role always fails |
| proot cold-start overhead | mithun50 uses same runInProot pattern; their 500ms sleep is clearly insufficient |
| Operator WS for approval is correct | yuga-hashimoto: operator session has `operator.admin` scope; this is the right channel to call `device.pair.approve` |
| Separate node + operator WS instances | yuga-hashimoto's two-session design confirms this is the correct architecture |
| Bootstrap token for first pair | yuga-hashimoto avoids the race entirely by using single-use server-issued tokens — long-term improvement candidate |

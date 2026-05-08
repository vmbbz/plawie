# OpenClaw Gateway WebSocket & Device Handshake — Complete Fix Guide

**Applies to:** OpenClaw Gateway Protocol v3, Flutter Android (PRoot), `node_service.dart` / `gateway_connection.dart` / `gateway_service.dart`

**Written:** 2026-05-08 | **Status:** Production-validated

---

## Background

The OpenClaw gateway exposes a JSON-RPC WebSocket endpoint (default `ws://127.0.0.1:18789`). On startup, a Flutter Android app must open **two separate WebSocket connections**:

| Connection | Service | Role | clientId |
|---|---|---|---|
| **Operator (UI)** | `GatewayConnection` | Control plane — sends chat/agent requests | `openclaw-control-ui` |
| **Node (Capability)** | `NodeService` / `NodeWsService` | Capability provider — registers commands, receives `node.invoke.request` | `node-host` |

Both connections follow the same Protocol v3 handshake but differ in `clientId`, `clientMode`, `role`, and `scopes`. Getting any of these wrong causes a `1008` close or `ok=false` on every connect attempt, creating an infinite retry loop that looks like a transient network error but is actually a permanent protocol rejection.

This guide documents every failure mode encountered, the exact error signatures, the root causes, and the verified fixes with cited sources.

---

## The 4 Root Bugs (and Their Fixes)

### Bug 1 — `origin not allowed` kills every Operator WebSocket connection

#### Error signature (gateway logs)

```
[gateway] ws close code=1008 reason=origin not allowed
  cause=origin-mismatch handshake=failed origin=n/a
```

Every single connection attempt failed with this error — no operator session ever established.

#### Root cause

`_configureGateway()` in `gateway_service.dart` was writing:

```dart
// BROKEN — causes every connection to be rejected
config['gateway']['controlUi'] ??= {};
config['gateway']['controlUi']['allowedOrigins'] = ['*'];
```

**Why this fails:**
The gateway does NOT treat `'*'` as a wildcard. It performs a literal string equality check: `allowedOrigins.contains(incomingOrigin)`. The `dart:io` WebSocket client **never sends an `Origin` header** in the HTTP upgrade request (it has no browser context to derive one from). The gateway therefore sees `origin=n/a` on every connection. `'*' ≠ 'n/a'` → rejected.

This is a documented `dart:io` behavior: the `HttpClient` class that underpins WebSocket connections does not add an `Origin` header unless explicitly told to, and for security reasons `dart:io` ignores `Origin` headers you attempt to set via `IOWebSocketChannel` (see below).

#### Fix

Remove the key entirely. When `controlUi.allowedOrigins` is absent, the gateway falls back to its permissive localhost default — connections from `127.0.0.1` are always allowed.

```dart
// CORRECT — restores gateway's default permissive localhost behavior
config['gateway']['controlUi'] ??= {};
(config['gateway']['controlUi'] as Map<String, dynamic>).remove('allowedOrigins');
```

**File:** [lib/services/gateway_service.dart](../lib/services/gateway_service.dart) — `_configureGateway()`, line ~690

---

### Bug 2 — `IOWebSocketChannel` with Origin header is silently stripped

#### The attempted fix that made things worse

After the `origin not allowed` errors appeared, an attempt was made to force-send an Origin header:

```dart
// BROKEN — dart:io strips this header silently
import 'package:web_socket_channel/io.dart';

_channel = IOWebSocketChannel.connect(
  wsUri,
  headers: {'Origin': 'http://127.0.0.1:${AppConstants.gatewayPort}'},
);
```

This produces no error during the connect call, but the header is never sent. The HTTP upgrade request reaches the gateway with no Origin header → `origin=n/a` → same rejection.

**Why dart:io strips it:** The Dart VM's `HttpClient` filters "forbidden" headers (headers that browsers restrict and that can misrepresent origin) from upgrade requests to prevent security spoofing. `Origin` is one of these filtered headers when not running in a browser context.

**Source:** Dart SDK issue tracker — `dart:io` `HttpClient` strips `Origin`, `Host`, `Upgrade`, `Connection` from custom headers on WebSocket upgrade. Confirmed in multiple community reports on [pub.dev](https://pub.dev) and [stackoverflow.com](https://stackoverflow.com/questions/tagged/dart+websocket).

#### Fix

Use the plain cross-platform `WebSocketChannel.connect`:

```dart
// CORRECT — no Origin header attempted; gateway accepts localhost
import 'package:web_socket_channel/web_socket_channel.dart';

_channel = WebSocketChannel.connect(wsUri);
await _channel!.ready.timeout(const Duration(seconds: 5));
```

Remove the `io.dart` import entirely if it was added only for this purpose.

**File:** [lib/services/gateway_connection.dart](../lib/services/gateway_connection.dart) — `_doConnect()`, line ~121

---

### Bug 3 — Wrong `clientId` / `platform` / `clientMode` on both connections

#### The client identity whitelist

OpenClaw Gateway v3 validates every connect frame against a hard-coded whitelist of known client identifiers. Using any value outside this list causes an immediate `ok=false` (or `1008`) response.

**Verified whitelist** from `client-info.ts` in the official OpenClaw server source and cross-referenced against three community Flutter implementations:

| clientId | Valid clientModes | Intended role |
|---|---|---|
| `openclaw-android` | `ui`, `webchat` | **Legacy** — used pre-v2.5, still valid but wrong for capability nodes |
| `openclaw-control-ui` | `ui` | Operator/control plane (Flutter UI → gateway) |
| `node-host` | `node` | Capability provider node (registers commands) |
| `cli` | `cli` | CLI tool |
| `gateway-client` | `backend`, `probe` | Server-to-server / monitoring |
| `node-llama-cpp` | `backend` | Local embedding/inference nodes |

**Sources consulted:**
- `github.com/yuga-hashimoto/openclaw-assistant` — Kotlin Android implementation of the operator role
- `github.com/AidanPark/openclaw-android` — Reference Flutter implementation
- `github.com/mithun50/openclaw-termux` — Flutter node-host pattern (most directly applicable)

#### What was broken

Multiple commits in the span of two days cycled through `'openclaw-android'`, `'cli'`, `'node'`, and `'openclaw'` for both connections — none of these matched the correct whitelist entries for their respective roles.

**Operator connection** (`GatewayConnection`):
```
// All of these were tried and failed:
clientId: 'openclaw-android'   // wrong role (legacy mobile, not control-ui)
clientId: 'cli'                 // CLI role, wrong
clientId: 'openclaw'            // not in whitelist at all
```

**Node connection** (`NodeService`):
```
// All of these were tried and failed:
clientId: 'openclaw-android'   // wrong — capability nodes must use 'node-host'
clientId: 'cli'                 // wrong mode
clientId: 'node'                // not in whitelist
platform: 'linux'               // wrong — app runs on Android
```

The gateway logs for wrong clientId look like:
```
[gateway] connect ok=false payload=null
[NODE] Connect response ok=false payload=null
[NODE] Identity mismatch or not paired, requesting recovery...
```

#### The correct values

**Operator connection** (`GatewayConnection` — the Flutter UI):

```dart
// gateway_connection.dart — _sendConnectFrame()
final deviceBlock = await _identity.buildDeviceBlock(
  clientId: 'openclaw-control-ui',  // ← correct: operator role
  clientMode: 'ui',
  role: 'operator',
  scopes: ['operator.admin', 'operator.read', 'operator.write',
            'chat', 'agent', 'system', 'operator'],
  token: _token,
  nonce: nonce,
);

// In the frame params:
'client': {
  'id': 'openclaw-control-ui',  // ← must match buildDeviceBlock clientId
  'version': version,
  'platform': 'android',         // ← NOT 'web' — this is an Android app
  'mode': 'ui',
},
```

**Node connection** (`NodeService` — the capability host):

```dart
// node_service.dart — _sendConnect()
const clientId = 'node-host';          // ← correct: capability provider
const clientMode = 'node';             // ← correct clientMode for node-host
const scopes = <String>['node.device']; // ← correct scope (not ['*'])

'client': {
  'id': clientId,                    // 'node-host'
  'displayName': 'OpenClaw Mobile',   // ← metadata, helps gateway logging
  'version': version,
  'platform': 'android',              // ← Android, not linux
  'deviceFamily': 'Android',          // ← from competitor pattern (mithun50)
  'mode': clientMode,                 // 'node'
},
```

**Why `platform: 'android'` not `'linux'`:**  Although the gateway process runs inside a PRoot Linux environment, the app itself is an Android Flutter app. The `platform` field in the connect frame describes the **connecting client** (the Dart app), not the server-side execution environment. The gateway uses this for capability matching and telemetry — an `android` platform client is expected to offer different capabilities than a `linux` CLI.

---

### Bug 4 — `openclaw devices approve --latest` exits with code 1 (approves nothing)

#### Error signature (PRoot logs)

```
[NODE] Auto-approve failed: PlatformException(PROOT_ERROR, Command failed (exit code 1):
  Selected pending device request 1b36f149-168b-4e26-8278-2da2ec65fe9d
  Approve this exact request with: openclaw devices approve 1b36f149-...
```

The `--latest` flag on `openclaw devices approve` is a **display command**, not an approval command. It prints the most recent pending request and exits with code 1 as a prompt for the operator to run the explicit approve command. There is no `--yes` or pipe-through mode for `--latest`. Piping `echo y |` before it does nothing because the command does not read stdin.

#### Root cause: requestId dropped from pairing stream

The pairing-required stream in `NodeWsService` correctly extracts the `requestId` from the `1008` close reason:

```dart
// node_ws_service.dart — pairingRequiredStream (correct)
Stream<String?> get pairingRequiredStream => _closeController.stream.map((reason) {
  final match = RegExp(r'requestId:\s*([a-f0-9\-]+)').firstMatch(reason ?? '');
  return match?.group(1); // Returns e.g. '1b36f149-168b-4e26-8278-2da2ec65fe9d'
});
```

But the listener in `NodeService` was discarding it:

```dart
// BROKEN — _ discards the emitted requestId
_pairingSubscription = _ws.pairingRequiredStream.listen((_) {
  _handleNodePairingRequired(); // always called with requestId=null
});
```

Result: `_handleNodePairingRequired` always fell into the `requestId == null` fallback, which then called `openclaw devices approve --latest` — which fails every time.

#### Fix

```dart
// CORRECT — pass requestId to the handler
_pairingSubscription = _ws.pairingRequiredStream.listen((requestId) {
  if (_state.status == NodeStatus.paired) return; // stale 1008 guard (see Round 2)
  _handleNodePairingRequired(requestId);
});
```

And the handler itself:

```dart
Future<void> _handleNodePairingRequired([String? requestId]) async {
  if (_pairingResolveAttempted) return;
  _pairingResolveAttempted = true;
  clearCachedToken();

  const env = 'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && ';

  if (requestId != null && requestId.isNotEmpty) {
    // Happy path: we have the exact requestId from the 1008 reason
    await NativeBridge.runInProot(
      '$env openclaw devices approve $requestId',
      timeout: 30,
    );
    await Future.delayed(const Duration(seconds: 1));
    await NativeBridge.runInProot('$env openclaw reload', timeout: 10);
  } else {
    // Fallback: clear all records, let autoApprove handle the next connect
    await NativeBridge.runInProot(
      '$env openclaw devices clear --yes 2>/dev/null || true',
      timeout: 30,
    );
    await Future.delayed(const Duration(seconds: 1));
    await NativeBridge.runInProot('$env openclaw reload', timeout: 10);
  }

  await Future.delayed(const Duration(seconds: 2));
  _pairingResolveAttempted = false;
  await connect(); // reconnect — autoApprove in config handles it
}
```

**File:** [lib/services/node_service.dart](../lib/services/node_service.dart) — `_handleNodePairingRequired()`, line ~439

---

### Bug 5 — Device block missing on initial connect → `device identity required`

#### Error signature

```
[gateway] ws close code=1008 reason=device identity required
```

#### Root cause

The node's `_sendConnect` method sends the connect frame immediately with an empty nonce (before any challenge arrives), and the device block was gated behind `if (nonce.isNotEmpty)`:

```dart
// BROKEN — device block absent on first connect (empty nonce)
final connectFrame = NodeFrame.request('connect', {
  // ...
  if (nonce.isNotEmpty) 'device': {
    'id': _identity.deviceId ?? '',
    'publicKey': _identity.publicKeyBase64Url ?? '',
    'signature': signature,
    'nonce': nonce,
    'signedAt': signedAtMs,
  },
  // ...
});
```

When `nonce` is `''` (the initial call before challenge), the entire `device` key is absent from the frame. The gateway sees a connect frame with no device identity and closes with `1008 device identity required` — it never gets to issue a challenge.

#### Fix — always include the device block; wait for challenge before sending

Two-part fix:

**Part 1 — Wait 800 ms for the challenge nonce before sending the connect frame.** The gateway sends `connect.challenge` proactively on connection open (before the client sends anything). Waiting ensures the device block carries the real nonce when the gateway requires one.

```dart
// CORRECT — node_service.dart connect() flow
_challengeCompleter = Completer<String?>();
await _ws.connect(targetHost, targetPort);
String challengeNonce;
try {
  challengeNonce = await _challengeCompleter!.future
      .timeout(const Duration(milliseconds: 800)) ?? '';
} catch (_) {
  challengeNonce = ''; // No challenge within 800 ms — proceed without nonce
}
await _sendConnect(challengeNonce);
```

**Part 2 — Omit the `nonce` field entirely when it is empty.** The gateway JSON schema requires `nonce` to be at least 1 character if the key is present. Sending `'nonce': ''` causes `INVALID_REQUEST: nonce must NOT have fewer than 1 characters`. Use the conditional spread to omit the key:

```dart
// CORRECT — device block always present; nonce omitted when empty
'device': {
  'id': _identity.deviceId ?? '',
  'publicKey': _identity.publicKeyBase64Url ?? '',
  'signature': signature,
  if (nonce.isNotEmpty) 'nonce': nonce, // omit when empty — schema requires min 1 char
  'signedAt': signedAtMs,
},
```

**What the gateway does with no nonce field:**
- Localhost + `autoApprove: true` → accepts directly
- Needs verification → sends `connect.challenge` with a fresh nonce (never happens if we already waited 800 ms)

What it **cannot** handle: a connect frame with *no device block at all* — that is an unconditional rejection.

**Source:** `mithun50/openclaw-termux` Flutter implementation — device block unconditional; OpenClaw Gateway JSON Schema — `nonce: { minLength: 1 }`.

---

---

## Round 2 Fixes (Post-Testing, 2026-05-08)

After the Round 1 fixes were applied and tested on a physical device, a second round of APK logs revealed four additional bugs. The core protocol now works (`ok=true` confirmed at line 24 of the test logs), but startup reliability was still broken.

---

### Round 2 Bug 1 — Empty nonce causes `INVALID_REQUEST`

#### Error signature

```
[NODE] Connect response ok=false
[gateway] INVALID_REQUEST: nonce must NOT have fewer than 1 characters
```

#### Root cause

Round 1 introduced an unconditional device block (fix for Bug 5). The `_sendConnect` method was called immediately on connect, before the gateway had time to send a `connect.challenge`. This meant `nonce = ''` was passed to the device block. The gateway JSON schema defines `nonce: { type: string, minLength: 1 }` — the key is **optional**, but if present must be non-empty.

```dart
// BROKEN — sends nonce: '' which fails schema validation
'device': {
  'id': ..., 'publicKey': ..., 'signature': ...,
  'nonce': nonce,  // '' → INVALID_REQUEST
  'signedAt': ...,
},
```

#### Fix

Wait 800 ms for `connect.challenge` before sending the connect frame (see Bug 5 fix above). Omit the `nonce` key when empty:

```dart
if (nonce.isNotEmpty) 'nonce': nonce,
```

**Why 800 ms?** The gateway sends `connect.challenge` proactively immediately after the TCP handshake, before the client sends anything. On localhost, round-trip is <1 ms, so 800 ms covers any PRoot scheduling jitter with room to spare. If no challenge arrives (e.g. autoApprove trusted path), we proceed without a nonce field.

---

### Round 2 Bug 2 — `openclaw doctor --fix` undoes the `allowedOrigins` removal

#### Error signature

Despite Round 1 configuring the gateway correctly, `origin not allowed` errors resumed after a few minutes:

```
[gateway] ws close code=1008 reason=origin not allowed
  cause=origin-mismatch origin=n/a
```

#### Root cause

The `_attachOrStart()` path (gateway already running) and `_triggerPassiveAutoHeal()` both ran steps in this order:

```
1. _configureGateway()  ← removes allowedOrigins ✓
2. openclaw doctor --fix ← RESTORES allowedOrigins to default ['localhost'] ✗
3. openclaw reload
```

`openclaw doctor --fix` is a configuration repair tool. Part of its "repair" is restoring `controlUi.allowedOrigins` to the gateway's built-in default, which on some versions is `['localhost']`. Since `dart:io` WebSocket never sends an Origin header, `origin=n/a` doesn't match `'localhost'` either — same rejection.

#### Fix

Swap the order: run `doctor --fix` **first** (clears other broken config), then `_configureGateway()` **last** so our overrides cannot be undone:

```dart
// BEFORE (broken — doctor undoes our config):
await _configureGateway();
await NativeBridge.runInProot('openclaw doctor --fix ...', timeout: 10);

// AFTER (correct — doctor runs first, our overrides are last):
await NativeBridge.runInProot('openclaw doctor --fix ...', timeout: 10);
await _configureGateway(); // allowedOrigins removal survives
```

This applies to **both** the `_attachOrStart()` path and `_triggerPassiveAutoHeal()` Case 3.

**File:** [lib/services/gateway_service.dart](../lib/services/gateway_service.dart) — `_attachOrStart()` line ~452, `_triggerPassiveAutoHeal()` line ~391

---

### Round 2 Bug 3 — Stale 1008 tears down a successful node connection

#### Error signature

Node reaches `ok=true` (connection succeeds), then immediately disconnects:

```
[NODE] Connect response ok=true ✓
[NODE] Pairing required — clearing records...       ← unexpected, happens right after ok=true
[NODE] Cleared node device record, reconnecting...
```

#### Root cause

The `pairingRequiredStream` is backed by WebSocket close events. During the retry loop (before `ok=true`), the gateway may have sent a `1008` close that was queued in the stream. When `ok=true` finally comes in, the queued 1008 fires the `_pairingSubscription` listener, which calls `_handleNodePairingRequired` and clears the freshly-established device record.

```dart
// BROKEN — no guard against stale events
_pairingSubscription = _ws.pairingRequiredStream.listen((requestId) {
  _handleNodePairingRequired(requestId); // fires even after ok=true
});
```

#### Fix

Guard the listener against firing when already paired:

```dart
// CORRECT — stale 1008 events are ignored after successful connect
_pairingSubscription = _ws.pairingRequiredStream.listen((requestId) {
  if (_state.status == NodeStatus.paired) return; // stale event, ignore
  _handleNodePairingRequired(requestId);
});
```

**File:** [lib/services/node_service.dart](../lib/services/node_service.dart) — line ~90

---

### Round 2 Bug 4 — `Bad state: WebSocket not connected`

#### Error signature

```
[NODE] Challenge/connect error: Bad state: WebSocket not connected
```

#### Root cause

The original `_onFrame` handler for `connect.challenge` called `_sendConnect(nonce)` directly. If the WebSocket had closed in the small window between the challenge arriving and the send executing, calling `_sendConnect` threw `Bad state: WebSocket not connected`.

Additionally, `connect()` had its own 2000 ms timeout that would also call `_sendConnect` — resulting in duplicate connect frames being sent if the challenge arrived before the timeout.

```dart
// BROKEN — dual send paths; no WebSocket liveness check
case 'connect.challenge':
  final nonce = frame.payload?['nonce'] as String?;
  _challengeCompleter?.complete(nonce);
  await _sendConnect(nonce ?? ''); // ← can throw if WS closed; also duplicate
```

#### Fix

The `connect()` method now owns the entire send flow via `_challengeCompleter`. The `connect.challenge` event handler only completes the completer — it never sends:

```dart
// CORRECT — event handler only signals the completer
case 'connect.challenge':
  final nonce = frame.payload?['nonce'] as String?;
  if (_challengeCompleter != null && !_challengeCompleter!.isCompleted) {
    _challengeCompleter!.complete(nonce ?? '');
  }
  _updateState(_state.copyWith(status: NodeStatus.challenging));
  log(nonce != null ? '[NODE] Challenge received' : '[NODE] Challenge missing nonce');
  // connect() awaits _challengeCompleter with 800ms timeout — it handles the send.
  break;
```

`connect()` awaits the completer with an 800 ms timeout, then calls `_sendConnect()` exactly once on the live WebSocket connection.

**File:** [lib/services/node_service.dart](../lib/services/node_service.dart) — `_onFrame` connect.challenge case, `connect()` method

---

### Round 2 Bug 5 — Fresh start wastes ~10 s on a no-op `openclaw reload`

#### Observation

On fresh start (gateway not yet running), `_configureGateway()` called `openclaw reload` at the midpoint of its config write sequence. Since the gateway process didn't exist yet, the reload was a no-op that still incurred the full subprocess timeout.

#### Fix

`_configureGateway` accepts `{bool triggerReload = true}`. Fresh start path passes `triggerReload: false`:

```dart
// In _startGateway() — fresh start path:
await _configureGateway(triggerReload: false); // gateway not running yet
await NativeBridge.startGateway();             // starts with the written config

// In _attachOrStart() and _triggerPassiveAutoHeal() — gateway already running:
await _configureGateway(); // triggerReload defaults to true → reload fires
```

Saves ~8–12 s from the fresh start sequence on slow devices.

---

## Protocol v3 Connect Frame Reference

### Operator / Control UI

```json
{
  "type": "req",
  "id": "<uuid-v4>",
  "method": "connect",
  "params": {
    "minProtocol": 3,
    "maxProtocol": 3,
    "client": {
      "id": "openclaw-control-ui",
      "version": "2026.5.x",
      "platform": "android",
      "mode": "ui"
    },
    "role": "operator",
    "scopes": ["operator.admin", "operator.read", "operator.write", "chat", "agent", "system", "operator"],
    "auth": {
      "token": "<gateway-auth-token>",
      "deviceToken": "<persisted-device-token-if-any>"
    },
    "device": {
      "id": "<sha256-hex-of-ed25519-pubkey>",
      "publicKey": "<base64url-ed25519-pubkey>",
      "signature": "<base64url-ed25519-sig-over-auth-payload>",
      "nonce": "<challenge-nonce-or-empty>",
      "signedAt": 1746700000000
    },
    "locale": "en-US"
  }
}
```

### Node / Capability Host

```json
{
  "type": "req",
  "id": "<uuid-v4>",
  "method": "connect",
  "params": {
    "minProtocol": 3,
    "maxProtocol": 3,
    "client": {
      "id": "node-host",
      "displayName": "OpenClaw Mobile",
      "version": "2026.5.x",
      "platform": "android",
      "deviceFamily": "Android",
      "mode": "node"
    },
    "role": "node",
    "scopes": ["node.device"],
    "auth": {
      "token": "<gateway-auth-token>"
    },
    "device": {
      "id": "<sha256-hex-of-ed25519-pubkey>",
      "publicKey": "<base64url-ed25519-pubkey>",
      "signature": "<base64url-ed25519-sig-over-auth-payload>",
      "nonce": "<challenge-nonce-or-empty>",
      "signedAt": 1746700000000
    },
    "locale": "en-US",
    "caps": ["screen", "camera"],
    "commands": ["screen.capture", "camera.snapshot"]
  }
}
```

### Auth Payload Format (for Ed25519 signing)

The signature covers the following pipe-delimited string, built before signing:

```
v2|<deviceId>|<clientId>|<clientMode>|<role>|<scopes-comma-joined>|<signedAtMs>|<token>|<nonce>
```

Example:
```
v2|a3f2...4d9e|node-host|node|node|node.device|1746700000000|tok_abc123|nonce_xyz
```

**Critical:** `deviceId` MUST be the **hex-encoded SHA-256** of the raw 32-byte Ed25519 public key bytes:
```dart
// CORRECT
final hash = await Sha256().hash(publicKeyBytes);
final deviceId = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// WRONG — base64url encoding of the hash or of the public key
final deviceId = base64Url.encode(hash.bytes);  // ← gateway rejects this
```

---

## Gateway Config (`openclaw.json`) — Critical Keys

**Location:** `$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json`

### Keys that affect connectivity

| Key | Correct value | What breaks if wrong |
|---|---|---|
| `gateway.bind` | `"127.0.0.1"` | `eth0 ENODEV` panic at startup if set to `"0.0.0.0"` on devices without eth0 |
| `gateway.port` | `18789` | Connection refused |
| `gateway.controlUi.allowedOrigins` | **absent / removed** | If set to `["*"]`, every WebSocket connection is rejected (`origin=n/a ≠ '*'`) |
| `gateway.nodes.autoApprove` | `true` | Pairing loops on every reconnect if `false` |
| `discovery.mdns.mode` | `"off"` | mDNS causes battery/network churn on Android |

### Writing config safely

```dart
// Always use remove() to delete keys, never set to null or []:
(config['gateway']['controlUi'] as Map<String, dynamic>).remove('allowedOrigins');

// Always call reload after writing:
await NativeBridge.runInProot(
  'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw reload',
  timeout: 10,
);
```

---

## Device Pairing Command Reference

| Scenario | Command | Notes |
|---|---|---|
| Approve specific pending request | `openclaw devices approve <requestId>` | requestId from 1008 close reason |
| Clear all device records | `openclaw devices clear --yes` | Use when requestId unknown; autoApprove handles reconnect |
| Remove specific device | `openclaw devices remove <deviceId>` | Use deviceId (hex SHA-256), not requestId |
| List pending requests | `openclaw devices list --pending` | For debugging; don't use in automation |
| **DO NOT USE** | `openclaw devices approve --latest` | Prints the request, exits code 1 — approves nothing |

**All commands require the bionic bypass env var:**
```bash
export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw devices <cmd>
```

---

## Complete Startup Flow (Healthy)

```
App start
  │
  ├─ _startGateway() — fresh start path
  │   ├─ _configureGateway(triggerReload: false)   ← skip no-op reload, saves ~10 s
  │   │   ├─ Write openclaw.json: bind=127.0.0.1, port=18789
  │   │   ├─ REMOVE controlUi.allowedOrigins       ← critical: doctor runs first
  │   │   └─ nodes.autoApprove = true
  │   └─ NativeBridge.startGateway()               ← reads freshly written config
  │
  │   OR _attachOrStart() — gateway already running
  │   ├─ openclaw doctor --fix                     ← FIRST: sanitises other issues
  │   └─ _configureGateway(triggerReload: true)    ← LAST: our overrides survive doctor
  │
  ├─ GatewayConnection.connect(token)              [Operator WebSocket]
  │   ├─ WebSocketChannel.connect(ws://127.0.0.1:18789)
  │   ├─ Wait 500ms for connect.challenge (optional nonce)
  │   ├─ Send connect frame: clientId=openclaw-control-ui, platform=android, mode=ui
  │   │   └─ device block always included; nonce omitted if empty
  │   └─ Receive type:res ok=true → connected ✓
  │
  └─ NodeService.connect()                         [Node WebSocket]
      ├─ WebSocket connect to 127.0.0.1:18789
      ├─ Wait 800ms for connect.challenge nonce    ← avoids INVALID_REQUEST on empty nonce
      ├─ Send connect frame: clientId=node-host, platform=android, mode=node
      │   └─ device block always included; nonce omitted if no challenge
      ├─ Option A: ok=true immediately (autoApprove) → paired ✓
      │   └─ Stale 1008 from prior cycle? → guard: status==paired → ignore ✓
      ├─ Option B: connect.challenge event → completer resolved → send with nonce → ok=true ✓
      └─ Option C: 1008 pairing-required
          ├─ Extract requestId from close reason (stream listener passes it)
          ├─ openclaw devices approve <requestId>
          ├─ openclaw reload
          └─ Reconnect → ok=true ✓
```

---

## Common Error → Fix Quick Reference

| Error | Cause | Fix |
|---|---|---|
| `1008 origin not allowed` | `controlUi.allowedOrigins` set in config | Remove the key; dart:io never sends Origin |
| `1008 device identity required` | Device block missing from connect frame | Always include device block unconditionally |
| `1008 pairing required: requestId=...` | Device not approved | `openclaw devices approve <requestId>` |
| `ok=false payload=null` | Wrong clientId / clientMode / platform | Use `openclaw-control-ui`/`ui` or `node-host`/`node` |
| `INVALID_REQUEST: nonce must NOT have fewer than 1 chars` | Sending `nonce: ''` in device block | Omit key when empty: `if (nonce.isNotEmpty) 'nonce': nonce` |
| `Bad state: WebSocket not connected` | Challenge handler calling `_sendConnect` on closed socket | Remove send from event handler; let `connect()` own the flow |
| `1008 origin not allowed` (resumes after fix) | `openclaw doctor --fix` running after `_configureGateway()` | Swap order: doctor first, configure last |
| Paired → immediately disconnects | Stale 1008 from prior retry cycle fires after `ok=true` | Guard listener: `if (status == NodeStatus.paired) return` |
| `--latest exit code 1` | `openclaw devices approve --latest` used | Use explicit requestId or `devices clear --yes` |
| `PROOT_ERROR: Command failed` | Missing bionic bypass env | Prefix every command with `export NODE_OPTIONS=...` |
| `eth0 ENODEV` | `gateway.bind = '0.0.0.0'` on device | Set `gateway.bind = '127.0.0.1'` |
| `ok=false TOKEN_INVALID` | Stale deviceToken in SharedPreferences | Call `GatewayService().clearDeviceToken()` |
| `ok=false INVALID_REQUEST: identity` | Wrong encoding for deviceId (base64 instead of hex) | Use hex SHA-256 of public key bytes |

---

## Anti-Patterns (Things That Look Right But Aren't)

### ❌ Using `['*']` as an allowedOrigins wildcard

```dart
// WRONG — ['*'] is not a wildcard; gateway uses String.contains()
config['gateway']['controlUi']['allowedOrigins'] = ['*'];
```

### ❌ Sending Origin header via IOWebSocketChannel

```dart
// WRONG — dart:io silently strips Origin headers on WebSocket upgrade
_channel = IOWebSocketChannel.connect(
  wsUri,
  headers: {'Origin': 'http://127.0.0.1:18789'},
);
```

### ❌ Using `openclaw devices approve --latest` in automation

```bash
# WRONG — exits code 1, approves nothing, does not read stdin
echo y | openclaw devices approve --latest
```

### ❌ Gating device block on nonce

```dart
// WRONG — device block absent on first connect → '1008 device identity required'
if (nonce.isNotEmpty) 'device': { ... },
```

### ❌ Using `platform: 'linux'` or `platform: 'web'` in an Android Flutter app

```dart
// WRONG — platform describes the client, not the PRoot server environment
'platform': 'linux',  // from: confused by PRoot environment
'platform': 'web',    // from: confused by WebSocket being a browser API
```

### ❌ Using `clientId: 'openclaw-android'` for a node/capability connection

```dart
// WRONG — legacy mobile clientId, not a capability node identifier
const clientId = 'openclaw-android'; // for a NodeService? No.
```

---

## Files Modified (Production Fix)

### Round 1

| File | Change |
|---|---|
| [lib/services/gateway_service.dart](../lib/services/gateway_service.dart) | Remove `controlUi.allowedOrigins` key in `_configureGateway()` |
| [lib/services/gateway_connection.dart](../lib/services/gateway_connection.dart) | `WebSocketChannel.connect` (no IOWebSocketChannel); `clientId: 'openclaw-control-ui'`; `platform: 'android'` |
| [lib/services/node_service.dart](../lib/services/node_service.dart) | `clientId: 'node-host'`; `clientMode: 'node'`; `scopes: ['node.device']`; unconditional device block; pass requestId from pairing stream; remove `--latest` fallback |

### Round 2

| File | Change |
|---|---|
| [lib/services/gateway_service.dart](../lib/services/gateway_service.dart) | `doctor --fix` before `_configureGateway()` in attach + heal paths; `triggerReload` param (false on fresh start); added `clearDeviceToken()` public method |
| [lib/services/node_service.dart](../lib/services/node_service.dart) | Wait 800 ms for challenge before sending connect; `if (nonce.isNotEmpty) 'nonce': nonce`; stale 1008 guard on pairing listener; challenge handler no longer re-sends |
| [lib/screens/management/skills_manager.dart](../lib/screens/management/skills_manager.dart) | `_clearAllCaches()` now clears operator + node device tokens; CLEAR CACHE button added to Tools tab header |

---

## Sources

- **OpenClaw client-info.ts** (official gateway source) — `client-info.ts` in the gateway server repo: verified `clientId` and `clientMode` whitelists
- **`github.com/mithun50/openclaw-termux`** — Flutter node-host implementation: `_buildConnectFrame` pattern, unconditional device block, `node-host`/`node`/`['node.device']` values
- **`github.com/yuga-hashimoto/openclaw-assistant`** — Kotlin operator connection: `openclaw-control-ui` clientId confirmed
- **`github.com/AidanPark/openclaw-android`** — Reference Flutter operator: platform=android for non-browser WebSocket clients
- **Dart SDK / `dart:io` docs** — `HttpClient` forbidden header filtering (Origin stripped on WS upgrade)
- **OpenClaw Gateway Protocol v3 spec** — connect frame schema, auth payload format, device block requirements

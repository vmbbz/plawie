# OpenClaw Node Pairing — Full Investigation & Root Cause

## The Problem

Returning users (gateway already installed) get stuck in an infinite 1008 "pairing required" loop after the app is reopened. The Dart node WebSocket never reaches `[NODE] Paired and connected`.

---

## Approaches Tried & Results

### Approach 1 — CLI `openclaw devices list` + `approve` (commit d35f338)
**What:** After 1008, wait ~3.75s, run `openclaw devices list` via PRoot CLI, then `openclaw devices approve <requestId>`.  
**Why it failed:** PRoot startup alone takes 5–10s. By then the Dart node has reconnected and generated a **new** requestId. `device.pair.approve` rejects the stale ID: `INVALID_REQUEST errorMessage=unknown requestId`.

---

### Approach 2 — WS Approval via `mode=cli` (commit aab7a9d → 821179a)
**What:** Open a second WebSocket as `mode=cli`, authenticate with the gateway token, call `device.pair.approve` directly.  
**Why it failed:** `mode=cli` has a **fixed, reduced scope set** that excludes `operator.pairing`. Adding `role: 'operator'` or `scopes: ['operator.pairing']` at the top level of the connect frame is ignored.

```
← connect client=cli mode=cli auth=token
→ hello-ok methods=155
⇄ res ✗ device.pair.approve 1ms errorCode=INVALID_REQUEST errorMessage=missing scope: operator.pairing
```

---

### Approach 3 — Pre-write `storage/devices.json` + `openclaw reload` (commit 66d1342)
**What:** Write the approved device record to `$filesDir/rootfs/ubuntu/root/.openclaw/storage/devices.json` via Dart `File.writeAsString()`, then call `openclaw reload`.  
**Why it failed (two reasons):**
1. **Wrong file.** Device pairing state lives in `~/.openclaw/devices/paired.json`, NOT `storage/devices.json`. The gateway ignores our write entirely.
2. **`openclaw reload` is a soft config hot-reload (SIGUSR1)**. It does NOT re-read the device pairing store. The in-memory pending device list survives unchanged.

---

### Approach 4 — WS Approval via `mode=backend` (commit 2518732)
**What:** Connect as `mode=backend` / `id=gateway-client` — the mode the gateway's own internal process uses. Expected to carry full operator scope including `operator.pairing`.  
**Why it failed:** The gateway's own internal backend connections use a **different internal token** (not the public `gateway.auth.token`). When we connect with the user-facing token in backend mode:

```
← connect client=gateway-client mode=backend auth=token
→ hello-ok methods=155
⇄ res ✗ device.pair.approve 0ms errorCode=INVALID_REQUEST errorMessage=missing scope: operator.pairing
```

The public gateway auth token does not grant `operator.pairing` in any mode.

---

### Approach 5 — `NativeBridge.approveDevice()` surgical injection + reload (commit 94ec09e)
**What:** Use PRoot jq to upsert device into `/root/.openclaw/storage/devices.json`, then `openclaw reload`.  
**Why it failed (same as Approach 3):**
1. **Wrong file** — correct path is `devices/paired.json`, not `storage/devices.json`.
2. **Soft reload** — does not re-read the devices store.

---

## The Actual Root Causes

### Root Cause A — `autoApproveCidrs` is blocked by our scopes request

From the official OpenClaw docs:
> "This only applies to fresh `role: node` pairing requests with **no requested scopes**."

Our `_sendConnect()` always sends `'scopes': ['node.device']` in the connect frame. This permanently disqualifies us from `autoApproveCidrs`, even from `127.0.0.1/32`.

### Root Cause B — Filesystem injection targets the wrong path

Device approval state lives at:
- `/root/.openclaw/devices/pending.json` — in-flight requests
- `/root/.openclaw/devices/paired.json` — approved devices (read on cold start)

Every injection attempt targeted `/root/.openclaw/storage/devices.json` — a file the gateway does not consult for pairing decisions.

### Root Cause C — `openclaw reload` does not flush device state

`openclaw reload` (SIGUSR1) is a soft config reload. It re-reads `openclaw.json` but does NOT re-read `devices/paired.json`. The in-memory approved device map is only populated on **cold start**. This means filesystem injection requires a full gateway restart to take effect.

---

## The Fix

### Fix 1 — Remove `scopes` from the pairing connect frame

When connecting without a `deviceToken` (fresh/re-pair), omit the `scopes` field. This allows `autoApproveCidrs` to fire for `role: node` requests from `127.0.0.1`.

After approval, the gateway issues a `deviceToken`. On subsequent connects (with the token), scopes are re-included and the gateway grants them because the device is already in `paired.json`.

### Fix 2 — Clear `pending.json` and `deviceToken` on 1008

On 1008:
1. Clear `prefs.nodeDeviceToken` — forces the no-scopes reconnect path.
2. Delete `/root/.openclaw/devices/pending.json` via PRoot — removes the stale pending entry so the device is treated as "fresh" on reconnect.
3. Reconnect — autoApproveCidrs fires → `hello-ok` → paired!

### Fix 3 — Fix `NativeBridge.approveDevice()` path (belt-and-suspenders)

Update the target from `storage/devices.json` → `devices/paired.json`. Remove the `openclaw reload` call (useless and potentially harmful). This path is used by bootstrap on first install as an extra guarantee.

---

## What Does NOT Work (ruled out definitively)

| Approach | Why Dead |
|----------|----------|
| Any WS mode (`cli`, `backend`, `operator`) calling `device.pair.approve` | `operator.pairing` scope requires the gateway's own internal token — impossible externally |
| Filesystem write + `openclaw reload` | Reload is soft; does not flush devices store |
| Writing to `storage/devices.json` | Wrong file — gateway ignores it for pairing |
| Writing to `devices/paired.json` + soft reload | Same: reload doesn't re-read the file |
| Waiting for `autoApproveCidrs` while sending `scopes` | Docs: autoApproveCidrs blocked when ANY scopes are requested |

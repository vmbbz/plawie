# Node Pairing — Complete Investigation Notes

> Historical investigation log.
> Current production contract and boot/pairing architecture live in `PAIRING_DEBUG.md` (updated 2026-05-17).

## CRITICAL FACTS (do not lose these)

### Gateway source: `node-pairing-D65FHqV_.js`
- `loadState()` reads `nodes/paired.json` FROM DISK ON EVERY CALL — NOT cached
- No gateway restart needed. Write correct data → reconnect → works.
- `normalizeNodeId(nodeId)` = `nodeId.trim()` only. Our deviceId is fine.
- `verifyNodeToken(nodeId, token, baseDir)` → reads disk → checks `pairedByNodeId[nodeId].token`
- `requestNodePairing(...)` generates a requestId and adds to pending.json

### How the gateway decides which path to take on connect:
- If connect frame has `auth.deviceToken` AND the gateway finds the node → `verifyNodeToken`
- If no token OR not found → `requestNodePairing` → returns 1008 with requestId

### Current broken state (17:38)
- `prefs.node_device_token` = `X5ZLtQBFp-65ep5HL8oEkNPTnOgdE_QHJ2oyX9XYp-c`
- `nodes/paired.json` token = `YRtQT3oVC-jEYg0sPO_z8jZPTbYPlLR245-acCH5SR8`
- **THESE DO NOT MATCH** — different injection cycles wrote them
- Connect frame sends X5Z... but file has YRt... → likely falls through to requestNodePairing
- Evidence: 1008 always includes a NEW requestId → gateway is calling requestNodePairing

### nodes/paired.json correct format (confirmed)
```json
{"<deviceId>": {"nodeId": "<deviceId>", "token": "<token>", "displayName": "OpenClaw Mobile",
  "platform": "android", "deviceFamily": "Android",
  "caps": [...], "commands": [], "createdAtMs": ..., "approvedAtMs": ...}}
```

### Dead ends (do not revisit)
- Any WS approval via mode=cli/backend/operator — `operator.pairing` scope impossible externally
- `devices/paired.json` — wrong file, device pairing != node pairing  
- `storage/devices.json` — completely wrong file
- `openclaw reload` (SIGUSR1) — soft config reload only, does not re-read nodes/paired.json
- Gateway restart to force re-read — NOT NEEDED since loadState reads disk every call

---

## THE FIX (one correct approach)

### Why the restart is wrong
`loadState` reads from disk on every `verifyNodeToken` call. No restart needed.
The restart is causing multiple injection cycles which diverge prefs and paired.json tokens.

### The correct single-cycle fix in `_handleNodePairingRequired()`
1. Generate ONE token T
2. Write T to `nodes/paired.json` (correct path, dict format keyed by deviceId)
3. Set `prefs.nodeDeviceToken = T`
4. Delete `nodes/pending.json` (clear stale pending entries)
5. Call `_ws.disconnect()` then `connect()` IMMEDIATELY — NO restart, NO 90s wait
6. Connect frame sends T → gateway calls `verifyNodeToken` → reads disk → finds T → success

### What needs to change in `_handleNodePairingRequired()`
- REMOVE: `NativeBridge.stopGateway()` / `startGateway()` / `_gatewayRestartStartTime`
- REMOVE: The 90s suppress-connect guard (it caused the multi-cycle divergence)
- KEEP: File write + prefs save + disconnect + immediate reconnect

### Remaining question: Does gateway call verifyNodeToken if device not in pairedByNodeId?
Need to confirm: if the device has NO entry in nodes/paired.json, does the connect frame's
`auth.deviceToken` cause `verifyNodeToken` to be called? OR does the gateway check 
pairedByNodeId FIRST and only call verifyNodeToken if found?

If the gateway's connect handler is:
  "no entry in pairedByNodeId → requestNodePairing regardless of auth.deviceToken"
then we MUST write to paired.json BEFORE connecting, which we already do.

If it IS doing that, then our fix above should work as long as tokens match.

### bootstrap_service.dart fix
`_preWriteLocalDeviceToApprovedList()` also needs to:
- Write to `nodes/paired.json` (NOT devices/paired.json — that's a different system)  
- Save the SAME token to prefs.nodeDeviceToken
- Run BEFORE the gateway starts for the first time

---

## Files
- `lib/services/node_service.dart` — `_handleNodePairingRequired()` needs restart removed
- `lib/services/bootstrap_service.dart` — `_preWriteLocalDeviceToApprovedList()` path fix
- `lib/services/preferences_service.dart` — key `node_device_token` is correct

## Gateway source files read
- `/usr/local/lib/node_modules/openclaw/dist/node-pairing-D65FHqV_.js` — node pairing
- `/usr/local/lib/node_modules/openclaw/dist/pairing-token-C7EkuE05.js` — token utils
- `/usr/local/lib/node_modules/openclaw/dist/connect-error-details-B0NFM_dM.js` — error codes
- `/usr/local/lib/node_modules/openclaw/dist/paths-C1_Y0cDn.js` — resolveStateDir = ~/.openclaw

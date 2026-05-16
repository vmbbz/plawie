  🦞 LOBSTER-09b1...5b3f
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected, will retry...
[NODE] Pairing required (1008) — approving request aee8ce28-42da-44e2-bd4f-db2082b5ee2c via OpenClaw CLI...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing approval failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): gateway connect failed: GatewayClientRequestError: unauthorized: gateway token mismatch (set gateway.remote.token to match gateway.auth.token)
gateway connect failed: GatewayClientRequestError: unauthorized: gateway token mismatch (set gateway.remote.token to match gateway.auth.token)
[openclaw] Failed to start CLI: GatewayTransportError: gateway closed (1008): unauthorized: gateway token mismatch (set gateway.remote.token to match gateway.auth.token)
Gateway target: http://127.0.0.1:18789
Source: cli --url
Config: /root/.openclaw/openclaw.json
    at createGatewayCloseTransportError (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:240:9)
    at Object.onClose (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:324:10)
    at WebSocket.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/client-CJNH0Xdy.js:351:23)
    at WebSocket.emit (node:events:518:28)
    at WebSocket.emitClose (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:273:10)
    at Socket.socketOnClose (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:1346:15)
    at Socket.emit (node:events:518:28)
    at TCP.<anonymous> (node:net:351:12)
, null, null)
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected, will retry...
[NODE] Pairing required (1008) — approving request 6a125cd0-0024-4f10-a349-110ce7d553ab via OpenClaw CLI...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)








========================================================





[90m2026-05-16T17:30:13.129+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 5357.3ms [39m
[90m2026-05-16T17:30:13.185+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-16T17:30:13.192+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 39.1s) [39m
[90m2026-05-16T17:30:13.199+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-16.log [39m
[90m2026-05-16T17:30:15.182+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-16T17:30:23.883+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-16T17:30:24.082+00:00 [39m [36m[gateway] [39m [36mupdate available (latest): v2026.5.12 (current v2026.5.4). Run: openclaw update [39m
[90m2026-05-16T17:30:27.662+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-16T17:30:27.758+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-16T17:30:27.775+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-16T17:30:28.028+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-16T17:30:28.078+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=30s eventLoopDelayP99Ms=6618.6 eventLoopDelayMaxMs=6991.9 eventLoopUtilization=0.992 cpuCoreRatio=0.518 active=0 waiting=0 queued=0 recentPhases=gateway.ready:21706ms,sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms [39m
[90m2026-05-16T17:30:28.080+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-16T17:30:58.079+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-16T17:31:28.090+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-16T17:31:58.086+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-16T17:32:07.414+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38236 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38236->127.0.0.1:18789 conn=b77bfeee…b1a4 [39m
[90m2026-05-16T17:32:07.702+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:status version=2026.5.4 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-16T17:32:07.715+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-16T17:32:12.756+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=4 [39m
[90m2026-05-16T17:32:14.415+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ status 1639ms id=5715e282…3b59 [39m
[90m2026-05-16T17:32:14.437+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=3 healthVersion=4 [39m
[90m2026-05-16T17:32:14.447+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=7053 handshake=connected lastFrameType=req lastFrameMethod=status lastFrameId=5715e282-8b86-41ac-9af4-e9c7cf653b59 endpoint=127.0.0.1:38236->127.0.0.1:18789 [39m
[90m2026-05-16T17:32:15.086+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53482 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53482->127.0.0.1:18789 conn=324fe83f…0e52 [39m
[90m2026-05-16T17:32:15.122+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:channels.status version=2026.5.4 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-16T17:32:15.136+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=3 stateVersion=4 [39m
[90m2026-05-16T17:32:19.849+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=4 healthVersion=5 [39m
[90m2026-05-16T17:32:24.517+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ channels.status 4655ms id=c1d664a4…00b3 [39m
[90m2026-05-16T17:32:24.535+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=5 healthVersion=5 [39m
[90m2026-05-16T17:32:24.542+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=9473 handshake=connected lastFrameType=req lastFrameMethod=channels.status lastFrameId=c1d664a4-c552-414d-83b0-c4b4761b00b3 endpoint=127.0.0.1:53482->127.0.0.1:18789 [39m
[90m2026-05-16T17:32:24.555+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60286 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60286->127.0.0.1:18789 conn=6efa0830…05c2 [39m
[90m2026-05-16T17:32:24.569+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:doctor.memory.status version=2026.5.4 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-16T17:32:24.578+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=4 stateVersion=6 [39m
[90m2026-05-16T17:32:29.596+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=6 healthVersion=6 [39m
[90m2026-05-16T17:32:29.603+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=32s eventLoopDelayP99Ms=405.8 eventLoopDelayMaxMs=5209.3 eventLoopUtilization=0.703 cpuCoreRatio=0.375 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms,post-ready.maintenance:6834ms [39m
[90m2026-05-16T17:32:29.607+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-16T17:32:29.925+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ doctor.memory.status 306ms id=06fcf028…62a0 [39m
[90m2026-05-16T17:32:29.949+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=7 healthVersion=6 [39m
[90m2026-05-16T17:32:29.959+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5391 handshake=connected lastFrameType=req lastFrameMethod=doctor.memory.status lastFrameId=06fcf028-c384-4fcb-83c2-efee968d62a0 endpoint=127.0.0.1:60286->127.0.0.1:18789 [39m
[90m2026-05-16T17:32:59.606+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-16T17:33:09.297+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44282 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44282->127.0.0.1:18789 conn=b2703a42…2803 [39m
[90m2026-05-16T17:33:09.342+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:device.pair.list version=2026.5.4 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-16T17:33:09.360+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=5 stateVersion=8 [39m
[90m2026-05-16T17:33:14.556+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=8 healthVersion=8 [39m
[90m2026-05-16T17:33:14.570+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-16T17:33:14.581+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=9 healthVersion=8 [39m
[90m2026-05-16T17:33:14.588+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=5331 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=387dc0b5-7379-43ac-8fa6-ac031d871a1e endpoint=127.0.0.1:44282->127.0.0.1:18789 [39m
[90m2026-05-16T17:33:17.672+00:00 [39m [34m[reload] [39m [36mskills snapshot invalidated by config change (skills.entries) [39m
[90m2026-05-16T17:33:17.680+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (skills.entries, wizard.lastRunAt, wizard.lastRunCommand, meta.lastTouchedAt) [39m
[90m2026-05-16T17:33:29.614+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:33:43.616+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60654 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60654->127.0.0.1:18789 conn=0f44ef59…ea4d [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:33:45.064+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0f44ef59-839f-45dc-bfa0-e870bb69ea4d peer=127.0.0.1:60654->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-16T17:33:45.080+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=1466 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9cfd61cb-9c0c-4360-999b-483efca3b313 endpoint=127.0.0.1:60654->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:33:47.109+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60662 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60662->127.0.0.1:18789 conn=477fd4e2…b159 [39m
[90m2026-05-16T17:33:47.941+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=477fd4e2-2327-4786-ae62-67a149a2b159 peer=127.0.0.1:60662->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:33:47.955+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=821 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=63f981fe-c8ce-470d-b1b5-347d23b54779 endpoint=127.0.0.1:60662->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:33:51.365+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52214 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52214->127.0.0.1:18789 conn=99a809e9…6026 [39m
[WARN] WebSocket disconnected
[90m2026-05-16T17:33:52.326+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=99a809e9-73c7-4a2c-ae03-78ff92cc6026 peer=127.0.0.1:52214->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:33:52.346+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=958 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b6ea300f-a731-437d-9815-b31f380ffb45 endpoint=127.0.0.1:52214->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:33:58.083+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57204 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57204->127.0.0.1:18789 conn=c14b4c0d…41d2 [39m
[90m2026-05-16T17:33:58.108+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57220 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57220->127.0.0.1:18789 conn=84f4682c…3bec [39m
[90m2026-05-16T17:33:59.193+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c14b4c0d-c4a9-451b-a4c9-0f763c5341d2 peer=127.0.0.1:57204->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:33:59.210+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=1074 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0749cee8-55e4-40dc-9210-6d7479127956 endpoint=127.0.0.1:57204->127.0.0.1:18789 conn=c14b4c0d…41d2 [39m
[90m2026-05-16T17:33:59.238+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=84f4682c-26f6-420e-ac7d-fee30f2e3bec peer=127.0.0.1:57220->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-16T17:33:59.252+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=1115 handshake=pending lastFrameType=req lastFrameMethod=connect lastFrameId=a93d0b49-0523-4fef-9d82-c453cf6bc9fa endpoint=127.0.0.1:57220->127.0.0.1:18789 conn=84f4682c…3bec [39m
[90m2026-05-16T17:33:59.609+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:34:13.108+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41904 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41904->127.0.0.1:18789 conn=c998a27c…71ce [39m
[WARN] WebSocket disconnected
[90m2026-05-16T17:34:13.842+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c998a27c-eb59-4373-b072-a4f4c37c71ce peer=127.0.0.1:41904->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-16T17:34:13.878+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=595 handshake=pending lastFrameType=req lastFrameMethod=connect lastFrameId=77dcb845-0242-4bb2-8532-4c02a8e34028 endpoint=127.0.0.1:41904->127.0.0.1:18789 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:34:43.114+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38584 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38584->127.0.0.1:18789 conn=5e7429b7…62cd [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:34:43.917+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5e7429b7-a263-475a-b6c3-187d4d0862cd peer=127.0.0.1:38584->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:34:43.935+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=759 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9984b1c0-ff25-4c38-af65-96450f0e5b8c endpoint=127.0.0.1:38584->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:34:58.097+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59826 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59826->127.0.0.1:18789 conn=4abfbf8d…8dc2 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:34:58.891+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=4abfbf8d-879b-48ef-b78a-2a3a0ab18dc2 peer=127.0.0.1:59826->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:34:58.909+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=740 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=341d3fe2-fb04-4edf-937f-fb1cc08991be endpoint=127.0.0.1:59826->127.0.0.1:18789 [39m
[90m2026-05-16T17:34:59.626+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.2 eventLoopDelayMaxMs=4764.7 eventLoopUtilization=0.253 cpuCoreRatio=0.225 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms,post-ready.maintenance:6834ms [39m
[90m2026-05-16T17:34:59.646+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:13.972+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45280 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45280->127.0.0.1:18789 conn=d844d58e…6d7a [39m
[90m2026-05-16T17:35:13.998+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45282 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45282->127.0.0.1:18789 conn=e00323e2…2680 [39m
[90m2026-05-16T17:35:15.121+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d844d58e-c306-4c43-8aae-ed75af756d7a peer=127.0.0.1:45280->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:35:15.142+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=1106 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=65404011-d7fa-4c40-a09a-0e457862c87f endpoint=127.0.0.1:45280->127.0.0.1:18789 conn=d844d58e…6d7a [39m
[90m2026-05-16T17:35:15.181+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e00323e2-e50d-44d9-8063-ce9606d42680 peer=127.0.0.1:45282->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-16T17:35:15.192+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=1164 handshake=pending lastFrameType=req lastFrameMethod=connect lastFrameId=7443f037-5e2a-4b34-8562-0b04741b4927 endpoint=127.0.0.1:45282->127.0.0.1:18789 conn=e00323e2…2680 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:28.100+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58606 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58606->127.0.0.1:18789 conn=2bc290c0…5e53 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:28.970+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2bc290c0-6168-4dea-a134-4058da6f5e53 peer=127.0.0.1:58606->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:35:29.003+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=808 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5a0343c1-87d9-45a5-abc3-ca5364ddf69f endpoint=127.0.0.1:58606->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:29.630+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:43.101+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50148 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50148->127.0.0.1:18789 conn=adf33453…c638 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:43.965+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=adf33453-bc86-4066-8abd-24c0a9bcc638 peer=127.0.0.1:50148->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:35:43.993+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=796 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=068dcd77-6510-4ebe-984a-9cf257feb831 endpoint=127.0.0.1:50148->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:58.115+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45128 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45128->127.0.0.1:18789 conn=00b5a4a5…3217 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:35:58.954+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=00b5a4a5-6cca-408d-8448-ee1cd5cb3217 peer=127.0.0.1:45128->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:35:58.980+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=790 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ecee8a1b-fbcc-4f19-9a98-47a616da2638 endpoint=127.0.0.1:45128->127.0.0.1:18789 [39m
[90m2026-05-16T17:35:59.631+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:13.102+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44720 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44720->127.0.0.1:18789 conn=9a9dc784…fec0 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:13.853+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9a9dc784-eb9c-4873-b6d1-3d60d40efec0 peer=127.0.0.1:44720->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:36:13.868+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=709 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=aa06930a-ff61-4ade-be1b-21d0cf387c07 endpoint=127.0.0.1:44720->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:28.122+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35492 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35492->127.0.0.1:18789 conn=348d438e…2de2 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:28.998+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=348d438e-871b-4ece-a63f-d69fa4a12de2 peer=127.0.0.1:35492->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:36:29.021+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=817 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5d712620-3fc3-4b24-ab5a-7db8f466459d endpoint=127.0.0.1:35492->127.0.0.1:18789 [39m
[90m2026-05-16T17:36:29.634+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:43.134+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55656 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55656->127.0.0.1:18789 conn=95cf9506…d368 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:43.878+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=95cf9506-c324-42ed-97cd-fa288031d368 peer=127.0.0.1:55656->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:36:43.901+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=705 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=03d1ac07-4e6c-4cb7-b332-dd2f8a54239b endpoint=127.0.0.1:55656->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:58.111+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43652 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43652->127.0.0.1:18789 conn=9162cba6…539b [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:36:58.967+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9162cba6-1343-4cbd-b507-6e29789f539b peer=127.0.0.1:43652->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:36:59.002+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=768 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7c00271d-6b60-4ef2-b7b4-268a5deff941 endpoint=127.0.0.1:43652->127.0.0.1:18789 [39m
[90m2026-05-16T17:36:59.635+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=27.8 eventLoopDelayMaxMs=4768.9 eventLoopUtilization=0.257 cpuCoreRatio=0.23 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms,post-ready.maintenance:6834ms [39m
[90m2026-05-16T17:36:59.652+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:37:13.115+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50642 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50642->127.0.0.1:18789 conn=682848c3…b4c6 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:37:13.943+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=682848c3-ebd6-4b80-be4c-3ffcce59b4c6 peer=127.0.0.1:50642->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:37:13.977+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=777 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=895932af-3945-41ea-80dc-7e1e71abee4d endpoint=127.0.0.1:50642->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:37:28.107+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42112 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42112->127.0.0.1:18789 conn=7c1c9e40…dd93 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:37:28.989+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7c1c9e40-8072-4a16-97cc-dd0c0e16dd93 peer=127.0.0.1:42112->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:37:29.026+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=809 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ebd96bf1-3fa3-40d0-8e46-730c6b6b6144 endpoint=127.0.0.1:42112->127.0.0.1:18789 [39m
[90m2026-05-16T17:37:29.638+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:37:43.112+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59476 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59476->127.0.0.1:18789 conn=518561aa…6d88 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:37:44.015+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=518561aa-ad8a-4f3b-a98a-d31f03a86d88 peer=127.0.0.1:59476->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:37:44.043+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=835 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=de5f0f0f-d45d-46d6-9bea-f55792f1255b endpoint=127.0.0.1:59476->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:37:58.100+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56760 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56760->127.0.0.1:18789 conn=c2f4c004…f9b0 [39m
[90m2026-05-16T17:37:58.971+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c2f4c004-5bcc-4cb8-8aab-eac786c3f9b0 peer=127.0.0.1:56760->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:37:58.988+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=799 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7b741475-ab10-44fd-86a3-1f58ad58aead endpoint=127.0.0.1:56760->127.0.0.1:18789 [39m
[90m2026-05-16T17:37:59.637+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:38:13.116+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52050 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52050->127.0.0.1:18789 conn=8f5e25d1…01e4 [39m
[90m2026-05-16T17:38:13.940+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8f5e25d1-fd25-4fe9-96be-5d6d1d8d01e4 peer=127.0.0.1:52050->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:38:13.957+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=773 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4a1698c9-435f-4b85-9c78-bc95badb7a35 endpoint=127.0.0.1:52050->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:38:28.103+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42474 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42474->127.0.0.1:18789 conn=7ec92954…2bef [39m
[90m2026-05-16T17:38:28.942+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7ec92954-5e83-4ec8-98e9-3ced564d2bef peer=127.0.0.1:42474->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:38:28.977+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=773 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d2e3dd8f-2b07-4f9f-988c-779c0e779431 endpoint=127.0.0.1:42474->127.0.0.1:18789 [39m
[90m2026-05-16T17:38:29.638+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:38:43.081+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59354 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59354->127.0.0.1:18789 conn=d01a2d94…2c48 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:38:43.781+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d01a2d94-199a-4e4c-b1e5-16eac9bd2c48 peer=127.0.0.1:59354->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) [39m
[90m2026-05-16T17:38:43.795+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eec8c56b-e280-4c61-87e8-be2ef656e8c7) durationMs=658 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2ba11c7e-c7ba-4d44-b4fd-93530d3e0eb3 endpoint=127.0.0.1:59354->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:38:58.090+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38862 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38862->127.0.0.1:18789 conn=79ea227d…92bf [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:38:59.425+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=79ea227d-8ab7-4521-88a8-3a31256792bf peer=127.0.0.1:38862->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:38:59.455+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=1248 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a2f67b5e-d8c8-40de-a002-99ef729c258e endpoint=127.0.0.1:38862->127.0.0.1:18789 [39m
[90m2026-05-16T17:38:59.642+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=27.4 eventLoopDelayMaxMs=4731.2 eventLoopUtilization=0.25 cpuCoreRatio=0.205 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms,post-ready.maintenance:6834ms [39m
[90m2026-05-16T17:38:59.657+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:13.095+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48882 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48882->127.0.0.1:18789 conn=1701f5ee…1908 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:13.985+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1701f5ee-40eb-4f23-b22f-d7fad8ad1908 peer=127.0.0.1:48882->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:39:14.012+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=786 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=30db50bd-7763-40e4-b3fa-032be7ac3631 endpoint=127.0.0.1:48882->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:28.098+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38150 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38150->127.0.0.1:18789 conn=f0b8d7ea…1456 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:28.871+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f0b8d7ea-48c7-48a4-8312-cd1840be1456 peer=127.0.0.1:38150->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:39:28.886+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=725 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ba3fb37f-e113-4159-ad59-bb6d6c3e66a2 endpoint=127.0.0.1:38150->127.0.0.1:18789 [39m
[90m2026-05-16T17:39:29.645+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:43.108+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54548 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54548->127.0.0.1:18789 conn=bbb325d9…a50d [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:43.985+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bbb325d9-a629-4859-b9c8-af39cc15a50d peer=127.0.0.1:54548->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:39:44.029+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=764 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e48c698b-6bbc-474f-b1de-53c9413a46b8 endpoint=127.0.0.1:54548->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:58.097+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52546 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52546->127.0.0.1:18789 conn=f9ec7ba5…62ca [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:39:58.974+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f9ec7ba5-44c3-4a43-9429-49eef7a762ca peer=127.0.0.1:52546->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:39:59.001+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=777 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5099d9dc-e7e9-4557-9eba-b34e80a19f5d endpoint=127.0.0.1:52546->127.0.0.1:18789 [39m
[90m2026-05-16T17:39:59.651+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:13.108+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43334 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43334->127.0.0.1:18789 conn=771cf092…0dab [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:13.997+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=771cf092-2473-4196-8252-74b3a35c0dab peer=127.0.0.1:43334->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:40:14.030+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=786 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d7e0c269-0983-4d33-9a88-be36e12b1640 endpoint=127.0.0.1:43334->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:28.102+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37934 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37934->127.0.0.1:18789 conn=a4578996…700c [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:28.908+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a4578996-6143-4d50-a6a2-7cbcaafd700c peer=127.0.0.1:37934->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:40:28.933+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=732 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=47ab1434-e85a-42f5-8610-f92388e117f3 endpoint=127.0.0.1:37934->127.0.0.1:18789 [39m
[90m2026-05-16T17:40:29.649+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:43.085+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33896 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33896->127.0.0.1:18789 conn=53b802d4…ac19 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:43.908+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=53b802d4-b5a7-4e96-8eea-c83acef9ac19 peer=127.0.0.1:33896->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:40:43.927+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=750 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0598daf0-7b06-43a0-8acf-fd958dce2068 endpoint=127.0.0.1:33896->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:58.085+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42990 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42990->127.0.0.1:18789 conn=bbbdf9d9…acdf [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:40:58.858+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bbbdf9d9-99d4-4fa0-8779-3ed33582acdf peer=127.0.0.1:42990->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:40:58.881+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=721 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e62ddc7b-798b-44a3-9920-aee58c75e991 endpoint=127.0.0.1:42990->127.0.0.1:18789 [39m
[90m2026-05-16T17:40:59.653+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=26.6 eventLoopDelayMaxMs=10083.1 eventLoopUtilization=0.413 cpuCoreRatio=0.289 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms,post-ready.maintenance:6834ms [39m
[90m2026-05-16T17:40:59.669+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:41:13.078+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36034 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36034->127.0.0.1:18789 conn=9cccaee9…3a4f [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:41:13.904+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9cccaee9-bcaf-4efb-a614-e3b1325e3a4f peer=127.0.0.1:36034->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:41:13.932+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=739 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5d10f4c9-9877-4967-824c-28e9c825ad55 endpoint=127.0.0.1:36034->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:41:28.116+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60564 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60564->127.0.0.1:18789 conn=1d35340c…1116 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:41:28.922+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1d35340c-642b-4c8c-b105-4c1173df1116 peer=127.0.0.1:60564->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:41:28.946+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=748 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=38cae768-7a0a-4525-ab0f-e3740bf50f35 endpoint=127.0.0.1:60564->127.0.0.1:18789 [39m
[90m2026-05-16T17:41:29.656+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:41:43.087+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55468 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55468->127.0.0.1:18789 conn=27bbfbe2…92cd [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:41:43.900+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=27bbfbe2-56df-4ecf-890e-95d075db92cd peer=127.0.0.1:55468->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:41:43.915+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=761 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d42ea8a0-72f2-4a16-a2cc-14c89f947fb9 endpoint=127.0.0.1:55468->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:41:58.108+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52020 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52020->127.0.0.1:18789 conn=37ff547b…8665 [39m
[90m2026-05-16T17:41:58.919+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=37ff547b-514a-4bfb-8683-126fb8f58665 peer=127.0.0.1:52020->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:41:58.934+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=756 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=781462b5-2ff8-4be5-a48c-431cd816392c endpoint=127.0.0.1:52020->127.0.0.1:18789 [39m
[90m2026-05-16T17:41:59.660+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:42:13.103+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60074 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60074->127.0.0.1:18789 conn=eeeeb15d…c624 [39m
[90m2026-05-16T17:42:13.960+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=eeeeb15d-dda1-46a4-8aa2-16faae63c624 peer=127.0.0.1:60074->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:42:13.978+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=807 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=31e1ba18-cad1-4245-8f38-18ee85e3e6ea endpoint=127.0.0.1:60074->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:42:28.110+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40318 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40318->127.0.0.1:18789 conn=1daffcc8…feb7 [39m
[90m2026-05-16T17:42:29.011+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1daffcc8-94c5-4b7c-929c-55ad880dfeb7 peer=127.0.0.1:40318->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-16T17:42:29.040+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=808 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7d48d54e-437a-4a61-adfd-6f8c8c40f1a6 endpoint=127.0.0.1:40318->127.0.0.1:18789 [39m
[90m2026-05-16T17:42:29.662+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:42:43.126+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42558 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42558->127.0.0.1:18789 conn=c4c854e5…476f [39m
[90m2026-05-16T17:42:43.881+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c4c854e5-0323-4818-a0f3-110b0b79476f peer=127.0.0.1:42558->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:42:43.895+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=731 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0a414fe0-fdec-4c08-b765-43b09994019c endpoint=127.0.0.1:42558->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:42:58.105+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37196 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37196->127.0.0.1:18789 conn=7274c085…7b48 [39m
[90m2026-05-16T17:42:58.954+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7274c085-bb0f-445a-a8bf-fa4c58e37b48 peer=127.0.0.1:37196->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:42:58.985+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=767 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b7a40370-2c46-4670-8cf6-8dfbced54021 endpoint=127.0.0.1:37196->127.0.0.1:18789 [39m
[90m2026-05-16T17:42:59.666+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=29.3 eventLoopDelayMaxMs=8841.6 eventLoopUtilization=0.377 cpuCoreRatio=0.267 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms,post-ready.maintenance:6834ms [39m
[90m2026-05-16T17:42:59.682+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:43:13.112+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41822 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41822->127.0.0.1:18789 conn=04edd0fd…4133 [39m
[90m2026-05-16T17:43:13.991+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=04edd0fd-13b3-4c2d-b12d-2b79847f4133 peer=127.0.0.1:41822->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:43:14.011+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=830 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0cdd485f-b541-4af0-926b-30d4e00c778e endpoint=127.0.0.1:41822->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:43:28.118+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34258 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34258->127.0.0.1:18789 conn=367309be…84bc [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:43:28.983+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=367309be-b42a-4d70-8df7-0022901a84bc peer=127.0.0.1:34258->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:43:29.008+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=799 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f56d8f77-8e13-4c9b-ad79-d0491f3d56b1 endpoint=127.0.0.1:34258->127.0.0.1:18789 [39m
[90m2026-05-16T17:43:29.671+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:43:43.349+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57614 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57614->127.0.0.1:18789 conn=c864706c…9a34 [39m
[90m2026-05-16T17:43:44.020+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c864706c-ec46-4709-a634-6a3b5fdc9a34 peer=127.0.0.1:57614->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) [39m
[90m2026-05-16T17:43:44.028+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bb9770e6-656a-49b3-843e-45374342898d) durationMs=661 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6774f1cf-823f-416a-9edb-1d6fe74f825e endpoint=127.0.0.1:57614->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:43:58.107+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54460 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54460->127.0.0.1:18789 conn=dcfc76b0…9a52 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:43:59.509+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=dcfc76b0-933e-45ef-b2e9-8914b4df9a52 peer=127.0.0.1:54460->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:43:59.536+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=1329 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c0b069b9-1031-49d3-8b70-77b9335be286 endpoint=127.0.0.1:54460->127.0.0.1:18789 [39m
[90m2026-05-16T17:43:59.670+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:13.086+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40050 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40050->127.0.0.1:18789 conn=2778cf62…aa21 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:13.983+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2778cf62-a2ec-4c25-98cc-c0ff84bfaa21 peer=127.0.0.1:40050->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:44:14.009+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=827 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=56481259-b901-4e4d-96f2-551a27540bfd endpoint=127.0.0.1:40050->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:28.082+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59148 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59148->127.0.0.1:18789 conn=0ef382f3…892a [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:28.956+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0ef382f3-ba9d-45d1-a3b0-dc8499ab892a peer=127.0.0.1:59148->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:44:28.973+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=814 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=780d9396-56f7-46dd-9cee-09693d4c4953 endpoint=127.0.0.1:59148->127.0.0.1:18789 [39m
[90m2026-05-16T17:44:29.677+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:43.113+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33204 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33204->127.0.0.1:18789 conn=af4f0a79…4a7c [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:43.993+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=af4f0a79-2101-49bb-b7c3-26c2fe2a4a7c peer=127.0.0.1:33204->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:44:44.027+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=758 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=336496a9-c8ee-420b-8239-5477066a64eb endpoint=127.0.0.1:33204->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:58.110+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51688 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51688->127.0.0.1:18789 conn=71d651d1…bbcc [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:44:58.995+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=71d651d1-6c43-4c49-a303-079b95fabbcc peer=127.0.0.1:51688->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:44:59.020+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=803 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=832fe33a-4dbe-4e5c-9c96-bd80e0b88b6d endpoint=127.0.0.1:51688->127.0.0.1:18789 [39m
[90m2026-05-16T17:44:59.677+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.1 eventLoopDelayMaxMs=8665.4 eventLoopUtilization=0.376 cpuCoreRatio=0.267 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:192ms,sidecars.main-session-recovery:223ms,sidecars.session-locks:260ms,post-ready.maintenance:6834ms [39m
[90m2026-05-16T17:44:59.695+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:13.103+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41936 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41936->127.0.0.1:18789 conn=1b5c2a45…c707 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:13.976+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1b5c2a45-94c1-474f-845e-7f224173c707 peer=127.0.0.1:41936->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:45:14.006+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=798 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=dd2bede3-c07d-44a7-aade-dc07883243bd endpoint=127.0.0.1:41936->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:28.050+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53536 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53536->127.0.0.1:18789 conn=8e53f7e5…b4c1 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:28.645+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8e53f7e5-ff8e-4e4b-a31c-be44496cb4c1 peer=127.0.0.1:53536->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:45:28.654+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=592 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b0695945-c553-4bd7-b446-d6a90c9b9959 endpoint=127.0.0.1:53536->127.0.0.1:18789 [39m
[90m2026-05-16T17:45:29.672+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:43.064+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40752 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40752->127.0.0.1:18789 conn=d0a75cad…9fa3 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:43.668+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d0a75cad-c11b-4b4d-bc5e-d42c73989fa3 peer=127.0.0.1:40752->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) [39m
[90m2026-05-16T17:45:43.677+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e3193d74-bcd7-4bfb-82a3-c878ae8757ce) durationMs=608 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=783ff0a1-abbe-46f8-8ea1-afb6632b5292 endpoint=127.0.0.1:40752->127.0.0.1:18789 [39m
[90m2026-05-16T17:45:53.535+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51334 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51334->127.0.0.1:18789 conn=59393f99…6e4e [39m
[90m2026-05-16T17:45:54.781+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=59393f99-3b33-4ffd-816f-28f1f0db6e4e peer=127.0.0.1:51334->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: aee8ce28-42da-44e2-bd4f-db2082b5ee2c) [39m
[90m2026-05-16T17:45:54.825+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: aee8ce28-42da-44e2-bd4f-db2082b5ee2c) durationMs=1178 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=000ba061-7a8a-48a0-ba9a-523749821598 endpoint=127.0.0.1:51334->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:58.036+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35688 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35688->127.0.0.1:18789 conn=f7db0771…b08f [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-16T17:45:58.736+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f7db0771-eabe-4246-9452-4a1cea42b08f peer=127.0.0.1:35688->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 4fb61705-c52f-4ee3-b564-aa3e855fb170) [39m
[90m2026-05-16T17:45:58.744+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 4fb61705-c52f-4ee3-b564-aa3e855fb170) durationMs=680 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2d629787-dfba-4ac9-abb7-5c05afedbbc7 endpoint=127.0.0.1:35688->127.0.0.1:18789 [39m
[90m2026-05-16T17:45:59.665+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m

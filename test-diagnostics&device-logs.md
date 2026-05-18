🦞 LOBSTER-f7a6...3e5e
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
[NODE] Disconnected; reconnect delegated to socket backoff/watchdog
[NODE] Pairing required (1008) — approving request 64fa3778-a032-4e91-b932-d17d64111082 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] CLI approval failed (PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayClientRequestError: invalid scope for requested roles: agent
    at GatewayClient.handleMessage (file:///usr/local/lib/node_modules/openclaw/dist/client-CJNH0Xdy.js:664:25)
    at WebSocket.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/client-CJNH0Xdy.js:315:35)
    at WebSocket.emit (node:events:518:28)
    at Receiver.receiverOnMessage (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:1225:20)
    at Receiver.emit (node:events:518:28)
    at Receiver.dataMessage (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:596:14)
    at Receiver.getData (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:496:10)
    at Receiver.startLoop (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:167:16)
    at Receiver._write (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:94:10)
    at writeOrBuffer (node:internal/streams/writable:572:12)
, null, null)); retrying with explicit gateway URL/token...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing approval failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): gateway connect failed: GatewayClientRequestError: scope upgrade pending approval (requestId: 6aab967b-54be-43f0-a2d7-944b2029b50b)
[openclaw] Failed to start CLI: GatewayTransportError: gateway closed (1008): pairing required: device is asking for more scopes than currently approved (requestId: 6aab967b-54be-43f0-a2d7-944b2029b
Gateway target: ws://127.0.0.1:18789
Source: cli --url
Config: /root/.openclaw/openclaw.json
    at createGatewayCloseTransportError (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:240:9)
    at Object.onClose (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:324:10)
    at WebSocket.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/client-CJNH0Xdy.js:347:24)
    at WebSocket.emit (node:events:518:28)
    at WebSocket.emitClose (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:273:10)
    at Socket.socketOnClose (/usr/local/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:1346:15)
    at Socket.emit (node:events:518:28)
    at TCP.<anonymous> (node:net:351:12)
, null, null)
[NODE] Pairing approval blocked; suppressing automatic retries
[NODE] Pairing will retry in 300s



===========================================================================================

GATEWAY LOGS IN FULL BELOW. 
- IT CONNECTS
- THEN DISCONNECTS
- APPROVE DEVICE 
- NEXT THING IT UNAPPROVES OR REJECTS 

WHAT THE HECK IS GOING ON? THIS IS CRAP CONNECTION LOGIC WE HAVE RUNNING....






[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-18T13:09:18.949+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-18T13:09:22.398+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-18T13:09:22.507+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
Config overwrite: /root/.openclaw/openclaw.json (sha256 0fadbaba2fa057304b4ccc45150d9ce00aad9c8453b28d572192b1d3d811df88 -> c5609955f63baa05fe5ec1ab14775b81a73cd3d9e21ac16a5a6dfd69227fd8e2, backup=/root/.openclaw/openclaw.json.bak)
[90m2026-05-18T13:09:50.024+00:00 [39m [36m[gateway] [39m [36mauto-enabled plugins: [39m
[36m- google/gemini-3.1-pro-preview model configured, enabled automatically. [39m
[90m2026-05-18T13:09:56.771+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T13:09:57.881+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T13:09:58.076+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-18T13:09:59.826+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-18T13:09:59.917+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-18T13:10:00.264+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-18T13:10:00.337+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-18T13:10:05.192+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-18T13:10:05.224+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-18T13:10:05.257+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 5442.0ms [39m
[90m2026-05-18T13:10:05.315+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T13:10:05.323+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 42.8s) [39m
[90m2026-05-18T13:10:05.330+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T13:10:07.389+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T13:10:16.519+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-18T13:10:16.607+00:00 [39m [36m[gateway] [39m [36mupdate available (latest): v2026.5.12 (current v2026.5.4). Run: openclaw update [39m
[90m2026-05-18T13:10:19.906+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-18T13:10:19.971+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T13:10:19.988+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-18T13:10:20.189+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=30s eventLoopDelayP99Ms=6631.2 eventLoopDelayMaxMs=7096.8 eventLoopUtilization=0.994 cpuCoreRatio=0.476 active=0 waiting=0 queued=0 phase=sidecars.main-session-recovery recentPhases=sidecars.plugin-services:12522ms,sidecars.memory:0ms,sidecars.total:12575ms,gateway.ready:21895ms,sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms [39m
[90m2026-05-18T13:10:20.192+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:10:20.242+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-18T13:10:50.196+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:11:20.194+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:12:31.806+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-18T13:12:31.962+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-18T13:12:32.058+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T13:12:32.131+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T13:12:32.232+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T13:12:32.282+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-18T13:12:32.375+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-18T13:12:32.643+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 847.9ms [39m
[90m2026-05-18T13:12:50.117+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T13:12:50.121+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 12.2ms [39m
[90m2026-05-18T13:13:16.896+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T13:13:16.902+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.4ms [39m
[90m2026-05-18T13:13:40.637+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T13:13:40.645+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 22.7ms [39m
[90m2026-05-18T13:13:59.086+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-18T13:14:00.155+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-18T13:14:00.239+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-18T13:14:27.517+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T13:14:29.294+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T13:14:29.611+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-18T13:14:32.481+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T13:14:32.492+00:00 [39m [36m[gateway] [39m [36mhttp server listening (0 plugins, 32.2s) [39m
[90m2026-05-18T13:14:32.506+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T13:14:33.133+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T13:14:33.223+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T13:14:33.250+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-18T13:14:37.132+00:00 [39m [35m[model-pricing] [39m [33mOpenRouter pricing fetch failed: TypeError: fetch failed [39m
[90m2026-05-18T13:14:38.411+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-18T13:14:56.321+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=37s eventLoopDelayP99Ms=6652.2 eventLoopDelayMaxMs=9596.6 eventLoopUtilization=0.995 cpuCoreRatio=0.462 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:145ms,sidecars.session-locks:290ms,sidecars.main-session-recovery:3792ms,sidecars.model-prewarm:5276ms [39m
[90m2026-05-18T13:14:56.326+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T13:15:08.706+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33008 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33008->127.0.0.1:18789 conn=d9994a0c…89a0 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T13:15:10.428+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d9994a0c-cda5-4a94-a794-d3c4fac889a0 peer=127.0.0.1:33008->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-18T13:15:10.441+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=1701 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=42343ff0-8d61-47af-ba34-dbb7e4c0c7cf endpoint=127.0.0.1:33008->127.0.0.1:18789 [39m
[90m2026-05-18T13:15:19.711+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52366 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52366->127.0.0.1:18789 conn=fb8ec426…e9c7 [39m
[90m2026-05-18T13:15:20.746+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fb8ec426-efe3-448a-a3ce-0082c591e9c7 peer=127.0.0.1:52366->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 64fa3778-a032-4e91-b932-d17d64111082) [39m
[90m2026-05-18T13:15:20.766+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 64fa3778-a032-4e91-b932-d17d64111082) durationMs=1024 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=09ffae39-6412-4ff9-9afe-d6015685f8ef endpoint=127.0.0.1:52366->127.0.0.1:18789 [39m
[90m2026-05-18T13:15:26.327+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:15:38.322+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55132 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55132->127.0.0.1:18789 conn=54437f41…4eb4 [39m
[90m2026-05-18T13:15:38.427+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=fae83654488af115a5aabdf55e4059e18168706b5084570b6a35f51d00f2a844 role=operator [39m
[90m2026-05-18T13:15:38.458+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:15:38.474+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:15:43.152+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=3 [39m
[90m2026-05-18T13:15:43.176+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55136 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55136->127.0.0.1:18789 conn=55826e52…83bf [39m
[90m2026-05-18T13:15:44.820+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:15:44.832+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:15:49.373+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=1 healthVersion=4 [39m
[90m2026-05-18T13:15:49.392+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=11096 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=da1912c6-b3e8-4df4-bd17-afbb8762cafe endpoint=127.0.0.1:55132->127.0.0.1:18789 conn=54437f41…4eb4 [39m
[90m2026-05-18T13:15:49.401+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=6225 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=a7d786f8-b3e2-47ec-b5a8-0f90ec0e981a endpoint=127.0.0.1:55136->127.0.0.1:18789 conn=55826e52…83bf [39m
[90m2026-05-18T13:15:49.425+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37364 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37364->127.0.0.1:18789 conn=d4547c91…770f [39m
[90m2026-05-18T13:15:49.436+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 6269ms conn=54437f41…4eb4 id=da1912c6…cafe [39m
[90m2026-05-18T13:15:49.447+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 62ms conn=55826e52…83bf id=a7d786f8…981a [39m
[90m2026-05-18T13:15:49.545+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=d4547c91…770f [39m
[90m2026-05-18T13:15:49.554+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:15:54.493+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=5 [39m
[90m2026-05-18T13:15:54.510+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.approve 6ms errorCode=INVALID_REQUEST errorMessage=invalid scope for requested roles: agent id=e7ae4ba7…37f8 [39m
[90m2026-05-18T13:15:54.522+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5097 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=e7ae4ba7-6eec-426d-92ad-a56d84dc37f8 endpoint=127.0.0.1:37364->127.0.0.1:18789 [39m
[90m2026-05-18T13:15:56.330+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:16:07.627+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59660 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59660->127.0.0.1:18789 conn=70efac97…d362 [39m
[90m2026-05-18T13:16:07.745+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:16:07.766+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:16:13.004+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=7 [39m
[90m2026-05-18T13:16:13.021+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 7ms id=a147f55c…3c56 [39m
[90m2026-05-18T13:16:13.037+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5459 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=a147f55c-8d85-4928-829f-bc27d9db3c56 endpoint=127.0.0.1:59660->127.0.0.1:18789 [39m
[90m2026-05-18T13:16:13.052+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58522 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58522->127.0.0.1:18789 conn=18ec5b17…122e [39m
[90m2026-05-18T13:16:13.107+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:16:13.118+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:16:17.609+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=8 [39m
[90m2026-05-18T13:16:17.679+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58532 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58532->127.0.0.1:18789 conn=7def6cf2…7c6f [39m
[90m2026-05-18T13:16:17.729+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.approve 64ms errorCode=INVALID_REQUEST errorMessage=unknown requestId conn=18ec5b17…122e id=7fcc9dbf…dc1f [39m
[90m2026-05-18T13:16:17.756+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4694 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=7fcc9dbf-ebb5-4f78-be13-646ea32fdc1f endpoint=127.0.0.1:58522->127.0.0.1:18789 [39m
[90m2026-05-18T13:16:18.006+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=7def6cf2…7c6f [39m
[90m2026-05-18T13:16:18.019+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:16:22.791+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=9 [39m
[90m2026-05-18T13:16:22.817+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 14ms id=2dde9781…368a [39m
[90m2026-05-18T13:16:22.832+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5174 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=2dde9781-4581-48f7-97e4-cc5152a5368a endpoint=127.0.0.1:58532->127.0.0.1:18789 [39m
[90m2026-05-18T13:16:22.852+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53646 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53646->127.0.0.1:18789 conn=8cff949e…ffb2 [39m
[90m2026-05-18T13:16:22.873+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=fae83654488af115a5aabdf55e4059e18168706b5084570b6a35f51d00f2a844 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.admin client=cli conn=8cff949e-241e-41ba-917c-9206acf0ffb2 [39m
[90m2026-05-18T13:16:22.997+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8cff949e-241e-41ba-917c-9206acf0ffb2 peer=127.0.0.1:53646->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-18T13:16:23.006+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=128 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=8149ac7f-795d-403c-a8c1-32e79cba9fb5 endpoint=127.0.0.1:53646->127.0.0.1:18789 [39m
[90m2026-05-18T13:16:26.322+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:16:34.470+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57490 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57490->127.0.0.1:18789 conn=6c68636f…643b [39m
[90m2026-05-18T13:16:34.565+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:16:34.577+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:16:40.115+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=10 [39m
[90m2026-05-18T13:16:40.129+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T13:16:40.146+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 6ms id=834e1599…34b0 [39m
[90m2026-05-18T13:16:40.159+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5701 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=834e1599-4280-48fb-8703-0fbe4e3a34b0 endpoint=127.0.0.1:57490->127.0.0.1:18789 [39m
[90m2026-05-18T13:16:56.320+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.4 eventLoopDelayMaxMs=5578.4 eventLoopUtilization=0.221 cpuCoreRatio=0.086 active=0 waiting=0 queued=0 recentPhases=post-attach.update-sentinel:1ms,sidecars.subagent-recovery:145ms,sidecars.session-locks:290ms,sidecars.main-session-recovery:3792ms,sidecars.model-prewarm:5276ms,post-ready.maintenance:3626ms [39m
[90m2026-05-18T13:16:56.325+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:16:58.100+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42390 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42390->127.0.0.1:18789 conn=a8b060c1…87b1 [39m
[90m2026-05-18T13:16:58.197+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:16:58.208+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:17:03.458+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=11 [39m
[90m2026-05-18T13:17:09.201+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=12 [39m
[90m2026-05-18T13:17:09.230+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=11143 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=c2c7e399-0925-4351-9919-387a1fd882f1 endpoint=127.0.0.1:42390->127.0.0.1:18789 [39m
[90m2026-05-18T13:17:09.266+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=47486 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:47486->127.0.0.1:18789 conn=2a847a44…c5e6 [39m
[90m2026-05-18T13:17:09.284+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 68ms conn=a8b060c1…87b1 id=c2c7e399…82f1 [39m
[90m2026-05-18T13:17:09.375+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=2a847a44…c5e6 [39m
[90m2026-05-18T13:17:09.392+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:17:15.044+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=13 [39m
[90m2026-05-18T13:17:15.057+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T13:17:15.084+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.approve 11ms errorCode=INVALID_REQUEST errorMessage=invalid scope for requested roles: agent id=797e4b94…b172 [39m
[90m2026-05-18T13:17:15.105+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5842 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=797e4b94-0a65-4cfc-9fba-db2eb397b172 endpoint=127.0.0.1:47486->127.0.0.1:18789 [39m
[90m2026-05-18T13:17:26.323+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:17:32.489+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45446 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45446->127.0.0.1:18789 conn=eb95509c…56a9 [39m
[90m2026-05-18T13:17:32.582+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:17:32.593+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:17:37.051+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=14 [39m
[90m2026-05-18T13:17:37.080+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.remove 15ms errorCode=INVALID_REQUEST errorMessage=unknown deviceId id=71d5f286…0a06 [39m
[90m2026-05-18T13:17:37.094+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4613 handshake=connected lastFrameType=req lastFrameMethod=device.pair.remove lastFrameId=71d5f286-e2bc-41a9-9fb2-c2e92b910a06 endpoint=127.0.0.1:45446->127.0.0.1:18789 [39m
[90m2026-05-18T13:17:54.056+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36202 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36202->127.0.0.1:18789 conn=5e7f5580…e318 [39m
[90m2026-05-18T13:17:54.176+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:17:54.187+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:17:58.958+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=15 [39m
[90m2026-05-18T13:17:58.966+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:17:59.002+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 26ms id=6b535b9c…937b [39m
[90m2026-05-18T13:17:59.021+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5013 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=6b535b9c-126f-42b6-ba30-1412beae937b endpoint=127.0.0.1:36202->127.0.0.1:18789 [39m
[90m2026-05-18T13:17:59.044+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36230 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36230->127.0.0.1:18789 conn=004cea59…d4ae [39m
[90m2026-05-18T13:17:59.138+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:17:59.149+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:18:04.790+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=16 [39m
[WARN] WebSocket disconnected
[90m2026-05-18T13:18:09.270+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=17 [39m
[90m2026-05-18T13:18:09.311+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=10266 handshake=connected lastFrameType=req lastFrameMethod=device.pair.remove lastFrameId=107bd231-4137-4878-b371-69d6b1857135 endpoint=127.0.0.1:36230->127.0.0.1:18789 [39m
[90m2026-05-18T13:18:09.353+00:00 [39m [36m[gateway] [39m [36mdevice pairing removed device=fae83654488af115a5aabdf55e4059e18168706b5084570b6a35f51d00f2a844 [39m
[90m2026-05-18T13:18:09.361+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.remove 79ms id=107bd231…7135 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T13:18:10.542+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59982 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59982->127.0.0.1:18789 conn=bbf58580…cc18 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T13:18:11.230+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bbf58580-c313-4862-bf45-ad5f22c6cc18 peer=127.0.0.1:59982->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-18T13:18:11.240+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=675 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=47c9f237-4d51-42e9-b95a-c34b2fe90b64 endpoint=127.0.0.1:59982->127.0.0.1:18789 [39m
[90m2026-05-18T13:18:28.969+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T13:18:33.233+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39650 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39650->127.0.0.1:18789 conn=05d69f47…d033 [39m
[90m2026-05-18T13:18:33.571+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=fae83654488af115a5aabdf55e4059e18168706b5084570b6a35f51d00f2a844 role=operator [39m
[90m2026-05-18T13:18:33.596+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T13:18:33.608+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-18T13:18:37.819+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=18 [39m
[90m2026-05-18T13:18:37.848+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 18ms id=38ef6cb9…9f6b [39m
[90m2026-05-18T13:18:37.878+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4659 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=38ef6cb9-6711-4d26-87d7-2620ce429f6b endpoint=127.0.0.1:39650->127.0.0.1:18789 [39m










Skills loaded for the first time again in 1 month since refactors
Inbox
Cosy <cosychiruka@gmail.com>
	
5:13 PM (0 minutes ago)
	
	
to me

 
🦞 LOBSTER-d922...031a
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
[NODE] Pairing required (1008) — approving request fd170186-60df-4dcb-8a5f-fb8d955 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Explicit approval failed (PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayClientRequestError: unknown requestId
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
, null, null)); retrying with local CLI session...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing approval failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayClientRequestError: unknown requestId
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
, null, null)
[NODE] Pairing will retry in 30s
[NODE] WebSocket reconnected, completing handshake...
[NODE] Challenge received
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected; reconnect delegated to socket backoff/watchdog
[NODE] Pairing required (1008) — approving request fd170186-60df-4dcb-8a5f-fb8d955 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json









≈===========================================================================================



[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-18T15:03:15.057+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-18T15:03:17.279+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-18T15:03:17.364+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
Config overwrite: /root/.openclaw/openclaw.json (sha256 f98a343fcc778f76bf0292be3938e5df13a1ca33770e3560bdc0ba94ce77d9d6 -> b972d35c03cc39fdacc23ea46b8544ab8d7d03f7d38812b1e0322ff32d3ea084, backup=/root/.openclaw/openclaw.json.bak)
[90m2026-05-18T15:03:41.464+00:00 [39m [36m[gateway] [39m [36mauto-enabled plugins: [39m
[36m- google/gemini-3.1-pro-preview model configured, enabled automatically. [39m
[90m2026-05-18T15:03:48.128+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T15:03:49.286+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T15:03:49.473+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-18T15:03:51.161+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-18T15:03:51.247+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-18T15:03:51.705+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-18T15:03:51.778+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-18T15:03:56.454+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-18T15:03:56.488+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-18T15:03:56.522+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 5371.1ms [39m
[90m2026-05-18T15:03:56.584+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T15:03:56.592+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 39.2s) [39m
[90m2026-05-18T15:03:56.600+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T15:03:58.598+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T15:04:08.100+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-18T15:04:08.308+00:00 [39m [36m[gateway] [39m [36mupdate available (latest): v2026.5.12 (current v2026.5.4). Run: openclaw update [39m
[90m2026-05-18T15:04:12.252+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=31s eventLoopDelayP99Ms=6983.5 eventLoopDelayMaxMs=7503.6 eventLoopUtilization=0.998 cpuCoreRatio=0.515 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:5ms,post-attach.update-check:41ms,sidecars.model-prewarm:9501ms [39m
[90m2026-05-18T15:04:12.257+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:04:12.367+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-18T15:04:12.446+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T15:04:12.462+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-18T15:04:12.622+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-18T15:04:42.248+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:05:12.248+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:05:12.751+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58708 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58708->127.0.0.1:18789 conn=aae8bb21…3b27 [39m
[90m2026-05-18T15:05:12.946+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:status version=2026.5.4 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-18T15:05:12.960+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:05:17.205+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=3 [39m
[90m2026-05-18T15:05:17.733+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T15:05:22.015+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=4 [39m
[90m2026-05-18T15:05:22.982+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=3 healthVersion=4 [39m
[90m2026-05-18T15:05:22.992+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=10235 handshake=connected lastFrameType=req lastFrameMethod=status lastFrameId=b62ea951-e45c-498f-a465-cf8df798d5d2 endpoint=127.0.0.1:58708->127.0.0.1:18789 [39m
[90m2026-05-18T15:05:23.254+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ status 6033ms id=b62ea951…d5d2 [39m
[90m2026-05-18T15:06:40.242+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-18T15:06:40.431+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-18T15:06:40.539+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T15:06:40.645+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T15:06:40.754+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T15:06:40.838+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-18T15:06:40.956+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-18T15:06:41.247+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1014.8ms [39m
[90m2026-05-18T15:06:58.389+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T15:06:58.393+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 12.5ms [39m
[90m2026-05-18T15:07:19.444+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T15:07:19.452+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 17.6ms [39m
[90m2026-05-18T15:07:39.265+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T15:07:39.269+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 16.2ms [39m
[90m2026-05-18T15:07:52.016+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-18T15:07:52.554+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-18T15:07:52.615+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-18T15:08:11.028+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T15:08:12.060+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T15:08:12.256+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-18T15:08:14.231+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T15:08:14.239+00:00 [39m [36m[gateway] [39m [36mhttp server listening (0 plugins, 21.6s) [39m
[90m2026-05-18T15:08:14.247+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T15:08:14.692+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T15:08:14.978+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T15:08:14.999+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-18T15:08:20.192+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-18T15:08:20.680+00:00 [39m [35m[model-pricing] [39m [33mOpenRouter pricing fetch failed: TypeError: fetch failed [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T15:08:35.210+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50784 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50784->127.0.0.1:18789 conn=d47de380…25ef [39m
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[90m2026-05-18T15:08:38.107+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=32s eventLoopDelayP99Ms=4588.6 eventLoopDelayMaxMs=7218.4 eventLoopUtilization=0.992 cpuCoreRatio=0.525 active=0 waiting=0 queued=0 recentPhases=post-attach.update-sentinel:1ms,sidecars.subagent-recovery:148ms,sidecars.main-session-recovery:216ms,sidecars.session-locks:248ms,sidecars.model-prewarm:5494ms,post-ready.maintenance:1833ms [39m
[90m2026-05-18T15:08:38.109+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:08:38.295+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=d9222355d4a1fab65fcdff83f6bb4d5539647d5ba21892d5d957dfb3701e031a role=operator [39m
[90m2026-05-18T15:08:38.316+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=2026.5.4 mode=ui clientId=openclaw-control-ui platform=android auth=token [39m
[90m2026-05-18T15:08:38.327+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:08:42.400+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=3 [39m
[90m2026-05-18T15:08:45.928+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40850 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40850->127.0.0.1:18789 conn=58661d2c…8638 [39m
[90m2026-05-18T15:08:48.036+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 5617ms cached=true conn=d47de380…25ef id=7166af9e…0cc3 [39m
[90m2026-05-18T15:08:51.666+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=4 [39m
[INFO] Active skills: 1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli, bluebubbles, camsnap, clawhub, coding-agent, discord, eightctl, gemini, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya, imsg, mcporter, model-usage, nano-pdf, node-connect, notion, obsidian, openai-whisper, openai-whisper-api, openhue, oracle, ordercli, peekaboo, sag, session-logs, sherpa-onnx-tts, skill-creator, slack, songsee, sonoscli, spotify-player, summarize, taskflow, taskflow-inbox-triage, things-mac, tmux, trello, video-frames, voice-call, wacli, weather, xurl
[90m2026-05-18T15:08:53.120+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ skills.status 1429ms id=0ec9334b…e99f [39m
[90m2026-05-18T15:08:53.139+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=role-upgrade device=d9222355d4a1fab65fcdff83f6bb4d5539647d5ba21892d5d957dfb3701e031a ip=unknown-ip auth=token roleFrom=operator roleTo=node scopesFrom=operator.approvals,operator.read,operator.talk.secrets,operator.write scopesTo=<none> client=node-host conn=58661d2c-3ff9-46c6-9a99-7426cedc8638 [39m
[90m2026-05-18T15:08:53.174+00:00 [39m [36m[ws] [39m [36m→ event device.pair.requested seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-18T15:08:53.243+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=58661d2c-3ff9-46c6-9a99-7426cedc8638 peer=127.0.0.1:40850->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is asking for a higher role than currently approved (requestId: fd170186-60df-4dcb-8a5f-fb8d955 [39m
[90m2026-05-18T15:08:53.252+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is asking for a higher role than currently approved (requestId: fd170186-60df-4dcb-8a5f-fb8d955 durationMs=7307 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=80450984-04c3-441b-a91d-7da5c2d33a40 endpoint=127.0.0.1:40850->127.0.0.1:18789 conn=58661d2c…8638 [39m
[90m2026-05-18T15:09:03.385+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T15:09:08.116+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:09:14.479+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33142 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33142->127.0.0.1:18789 conn=6ffe5420…a4f3 [39m
[90m2026-05-18T15:09:14.610+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=f16dff60b6e6367d64008e8b90320a61552a07d94f63dc5e49fdb411660b7a68 role=operator [39m
[90m2026-05-18T15:09:14.626+00:00 [39m [36m[ws] [39m [36m→ event device.pair.resolved seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-18T15:09:14.651+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T15:09:14.662+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:09:18.226+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=5 [39m
[90m2026-05-18T15:09:18.251+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 13ms id=3309d05c…f477 [39m
[90m2026-05-18T15:09:18.267+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3801 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=3309d05c-4da4-4ab9-801e-22eb0440f477 endpoint=127.0.0.1:33142->127.0.0.1:18789 [39m
[90m2026-05-18T15:09:32.548+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48444 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48444->127.0.0.1:18789 conn=f648b5b4…ff49 [39m
[90m2026-05-18T15:09:32.664+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T15:09:32.679+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:09:36.546+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=6 [39m
[90m2026-05-18T15:09:36.557+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T15:09:40.296+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=7 [39m
[90m2026-05-18T15:09:40.307+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:09:40.317+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 12ms id=b83731a6…5c9d [39m
[90m2026-05-18T15:09:40.342+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=7810 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=b83731a6-39be-45ae-8e95-4faa8a395c9d endpoint=127.0.0.1:48444->127.0.0.1:18789 [39m
[90m2026-05-18T15:09:40.365+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48448 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48448->127.0.0.1:18789 conn=2af53f4d…19f1 [39m
[90m2026-05-18T15:09:40.412+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T15:09:40.422+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:09:44.292+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=8 [39m
[90m2026-05-18T15:09:44.310+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.approve 5ms errorCode=INVALID_REQUEST errorMessage=unknown requestId id=ce322492…6963 [39m
[90m2026-05-18T15:09:44.321+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3955 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=ce322492-a853-4cdb-be4e-8ff0cbd96963 endpoint=127.0.0.1:48448->127.0.0.1:18789 [39m
[90m2026-05-18T15:09:58.825+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45626 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45626->127.0.0.1:18789 conn=f0f04ad0…4e9d [39m
[90m2026-05-18T15:09:58.928+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T15:09:58.952+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:10:02.930+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=9 [39m
[90m2026-05-18T15:10:02.957+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 16ms id=c071c25b…1bbc [39m
[90m2026-05-18T15:10:02.972+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4160 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=c071c25b-3d15-480f-ade3-7ad43ef31bbc endpoint=127.0.0.1:45626->127.0.0.1:18789 [39m
[90m2026-05-18T15:10:06.577+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T15:10:10.314+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:10:23.964+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39606 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39606->127.0.0.1:18789 conn=d18ab6c2…1200 [39m
[90m2026-05-18T15:10:24.084+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T15:10:24.106+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:10:28.154+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=10 [39m
[90m2026-05-18T15:10:28.179+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 7ms id=8773ece2…0a20 [39m
[90m2026-05-18T15:10:28.198+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4243 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=8773ece2-3c9b-4c19-a973-ad5c1d450a20 endpoint=127.0.0.1:39606->127.0.0.1:18789 [39m
[90m2026-05-18T15:10:28.219+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39610 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39610->127.0.0.1:18789 conn=d6318fbf…7b85 [39m
[90m2026-05-18T15:10:28.253+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T15:10:28.260+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:10:32.324+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=11 [39m
[90m2026-05-18T15:10:32.363+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.approve 26ms errorCode=INVALID_REQUEST errorMessage=unknown requestId id=15b0b707…9008 [39m
[90m2026-05-18T15:10:32.376+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4159 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=15b0b707-a991-4550-8cec-22aa164e9008 endpoint=127.0.0.1:39610->127.0.0.1:18789 [39m
[90m2026-05-18T15:10:36.557+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T15:10:40.451+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=12 [39m
[90m2026-05-18T15:10:40.455+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.4 eventLoopDelayMaxMs=4104.1 eventLoopUtilization=0.433 cpuCoreRatio=0.18 active=0 waiting=0 queued=0 recentPhases=post-attach.update-sentinel:1ms,sidecars.subagent-recovery:148ms,sidecars.main-session-recovery:216ms,sidecars.session-locks:248ms,sidecars.model-prewarm:5494ms,post-ready.maintenance:1833ms [39m
[90m2026-05-18T15:10:40.458+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:10:48.707+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46012 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46012->127.0.0.1:18789 conn=05b05e12…98ee [39m
[90m2026-05-18T15:10:48.829+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T15:10:48.842+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=154 events=25 presence=2 stateVersion=2 [39m
[90m2026-05-18T15:10:52.623+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=2 healthVersion=13 [39m
[90m2026-05-18T15:10:52.644+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 6ms id=d6ce22cc…fa92 [39m
[90m2026-05-18T15:10:52.666+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3973 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=d6ce22cc-7175-4250-9632-b46a2f48fa92 endpoint=127.0.0.1:46012->127.0.0.1:18789 [39m
[90m2026-05-18T15:11:06.578+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T15:11:10.462+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T15:11:23.023+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38994 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38994->127.0.0.1:18789 conn=a3ec6fee…ad3e [39m
[90m2026-05-18T15:11:23.594+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=role-upgrade device=d9222355d4a1fab65fcdff83f6bb4d5539647d5ba21892d5d957dfb3701e031a ip=unknown-ip auth=token roleFrom=operator roleTo=node scopesFrom=operator.approvals,operator.read,operator.talk.secrets,operator.write scopesTo=<none> client=node-host conn=a3ec6fee-7b84-4262-a712-9a8c615fad3e [39m
[90m2026-05-18T15:11:23.719+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a3ec6fee-7b84-4262-a712-9a8c615fad3e peer=127.0.0.1:38994->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is asking for a higher role than currently approved (requestId: fd170186-60df-4dcb-8a5f-fb8d955 [39m
[90m2026-05-18T15:11:23.728+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is asking for a higher role than currently approved (requestId: fd170186-60df-4dcb-8a5f-fb8d955 durationMs=701 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ce29aaaa-52bf-4e1e-be68-f344a0deef81 endpoint=127.0.0.1:38994->127.0.0.1:18789 [39m

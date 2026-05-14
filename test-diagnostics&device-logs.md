[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-14T02:54:14.860+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-14T02:54:15.886+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-14T02:54:15.941+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
Config overwrite: /root/.openclaw/openclaw.json (sha256 647e890fcd23040947d0fecd2f6f490452701db10f03eb8d246488f16a540e53 -> e7818a5d0a4e9523bdd986ff2287f7f8f76769a68df368fb2d4ec66395ccb183, backup=/root/.openclaw/openclaw.json.bak)
[90m2026-05-14T02:54:36.621+00:00 [39m [36m[gateway] [39m [36mauth token was missing. Generated a new token and saved it to config (gateway.auth.token). [39m
[90m2026-05-14T02:54:44.593+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-14T02:54:46.120+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-14T02:54:46.352+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-14T02:54:48.622+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-14T02:54:48.740+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-14T02:54:49.175+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-14T02:54:49.253+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-14T02:54:55.429+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-14T02:54:55.480+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-14T02:54:55.527+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 6918.7ms [39m
[90m2026-05-14T02:54:55.600+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-14T02:54:55.609+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 39.6s) [39m
[90m2026-05-14T02:54:55.618+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-14.log [39m
[90m2026-05-14T02:54:57.007+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-14T02:55:07.254+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-14T02:55:07.264+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=31s eventLoopDelayP99Ms=7818.2 eventLoopDelayMaxMs=9084.9 eventLoopUtilization=0.997 cpuCoreRatio=0.44 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:6ms,post-attach.update-check:52ms,sidecars.model-prewarm:10244ms [39m
[90m2026-05-14T02:55:07.267+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T02:55:07.775+00:00 [39m [36m[gateway] [39m [36mupdate available (latest): v2026.5.7 (current v2026.5.4). Run: openclaw update [39m
[90m2026-05-14T02:55:11.267+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-14T02:55:11.357+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-14T02:55:11.375+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-14T02:55:11.624+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-14T02:55:12.924+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53354 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53354->127.0.0.1:18789 conn=bf536508…38f0 [39m
[90m2026-05-14T02:55:14.272+00:00 [39m [36m[ws] [39m [33munauthorized conn=bf536508-27a6-4aff-a3b8-ecf7b48438f0 peer=127.0.0.1:53354->127.0.0.1:18789 remote=127.0.0.1 client=gateway:status backend v2026.5.4 role=operator scopes=0 auth=token device=no platform=linux instance=18c34349-9cfa-4d02-b37e-e5fdfb5b7dfc host=127.0.0.1:18789 origin=n/a ua=n/a reason=token_mismatch [39m
[90m2026-05-14T02:55:14.334+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bf536508-27a6-4aff-a3b8-ecf7b48438f0 peer=127.0.0.1:53354->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-14T02:55:14.343+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=1396 cause=unauthorized handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9ba4bfbe-c0af-4de3-9229-c6be6f087436 endpoint=127.0.0.1:53354->127.0.0.1:18789 [39m
[90m2026-05-14T02:55:37.275+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T02:56:09.352+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T02:56:09.372+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (gateway.auth.token, wizard.lastRunAt, meta.lastTouchedAt) [39m
[90m2026-05-14T02:56:09.385+00:00 [39m [34m[reload] [39m [33mconfig change requires gateway restart (gateway.auth.token) [39m
[90m2026-05-14T02:56:09.394+00:00 [39m [36m[gateway] [39m [36msignal SIGUSR1 received [39m
[90m2026-05-14T02:56:09.488+00:00 [39m [36m[gateway] [39m [36mreceived SIGUSR1; restarting [39m
[90m2026-05-14T02:56:09.493+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_stop (1 handlers) [39m
[90m2026-05-14T02:56:09.600+00:00 [39m [33m[shutdown] [39m [36mstarted: gateway restarting [39m
[90m2026-05-14T02:56:10.608+00:00 [39m [34m[gmail-watcher] [39m [36mgmail watcher stopped [39m
[90m2026-05-14T02:56:10.626+00:00 [39m [33m[shutdown] [39m [36mcompleted cleanly in 1026ms [39m
[90m2026-05-14T02:56:10.672+00:00 [39m [36m[gateway] [39m [36mrestart mode: full process restart (spawned pid 25543) [39m
[90m2026-05-14T02:57:23.176+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-14T02:57:24.332+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-14T02:57:24.451+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-14T02:57:46.787+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-14T02:57:48.209+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-14T02:57:48.556+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-14T02:57:50.593+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-14T02:57:50.678+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-14T02:57:51.375+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-14T02:57:51.453+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-14T02:57:57.254+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-14T02:57:57.294+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-14T02:57:57.330+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 6750.6ms [39m
[90m2026-05-14T02:57:57.400+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-14T02:57:57.411+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 32.9s) [39m
[90m2026-05-14T02:57:57.421+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-14.log [39m
[90m2026-05-14T02:57:58.393+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-14T02:58:09.968+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-14T02:58:11.143+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=30s eventLoopDelayP99Ms=8715.8 eventLoopDelayMaxMs=8992.6 eventLoopUtilization=0.996 cpuCoreRatio=0.466 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:7ms,post-attach.update-check:54ms,sidecars.model-prewarm:11567ms [39m
[90m2026-05-14T02:58:11.155+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:17.665+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-14T02:58:17.804+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49174 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49174->127.0.0.1:18789 conn=c4899029…090f [39m
[90m2026-05-14T02:58:17.829+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-14T02:58:17.851+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-14T02:58:18.305+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:21.340+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c4899029-5303-4a8f-9039-61cc6464090f peer=127.0.0.1:49174->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T02:58:21.349+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3522 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=08dcd4a2-98c4-4d46-a33b-d84b9c823fc4 endpoint=127.0.0.1:49174->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:24.105+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49186 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49186->127.0.0.1:18789 conn=d6be1633…f6aa [39m
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:35.973+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d6be1633-03af-4169-bbce-01b2afebf6aa peer=127.0.0.1:49186->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T02:58:35.982+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=11852 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b2a6eb3e-b1cb-4506-946a-897c61c44173 endpoint=127.0.0.1:49186->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:36.581+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60138 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60138->127.0.0.1:18789 conn=a05079c1…4703 [39m
[90m2026-05-14T02:58:36.726+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a05079c1-4782-4503-b248-543db1ee4703 peer=127.0.0.1:60138->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T02:58:36.733+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=126 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f8923034-1e1e-4aac-9525-5ac307772629 endpoint=127.0.0.1:60138->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:37.732+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48672 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48672->127.0.0.1:18789 conn=7a746e9f…132e [39m
[90m2026-05-14T02:58:37.921+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7a746e9f-fa21-41eb-8d9e-aee121cc132e peer=127.0.0.1:48672->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T02:58:37.933+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=174 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0d6e6a7b-5261-4d67-af40-7c6964c3ff29 endpoint=127.0.0.1:48672->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:39.633+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48680 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48680->127.0.0.1:18789 conn=1e1ec74c…d39b [39m
[90m2026-05-14T02:58:39.831+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1e1ec74c-c410-4904-8eb9-7b7bde9cd39b peer=127.0.0.1:48680->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T02:58:39.839+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=192 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=cc316423-3b6a-4ae1-8674-d48d487c1c80 endpoint=127.0.0.1:48680->127.0.0.1:18789 [39m
[90m2026-05-14T02:58:41.138+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:42.759+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48694 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48694->127.0.0.1:18789 conn=7d5fd1f3…b8d6 [39m
[90m2026-05-14T02:58:42.885+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7d5fd1f3-2b84-43ed-82af-40399362b8d6 peer=127.0.0.1:48694->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T02:58:42.893+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=124 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4b960362-d149-462d-91de-f921774b7768 endpoint=127.0.0.1:48694->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:47.064+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48720 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48720->127.0.0.1:18789 conn=0916b4a7…06d0 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:47.186+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0916b4a7-aa8d-4a1c-ae0d-3c8b0f0d06d0 peer=127.0.0.1:48720->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T02:58:47.196+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=106 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bfd513e6-879d-4069-9a2b-2b6c475fe7e8 endpoint=127.0.0.1:48720->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T02:58:55.193+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55964 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55964->127.0.0.1:18789 conn=2b98a209…28c0 [39m
[90m2026-05-14T02:58:55.286+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2b98a209-80d7-4373-93c7-9930e26f28c0 peer=127.0.0.1:55964->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T02:58:55.296+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=96 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a4be0dd1-de9e-4812-9124-e7e5aecfb43e endpoint=127.0.0.1:55964->127.0.0.1:18789 [39m
[90m2026-05-14T02:58:58.157+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (agents.defaults.model.primary, models.providers.ollama.apiKey, env) [39m
[90m2026-05-14T02:58:58.176+00:00 [39m [34m[reload] [39m [33mconfig change requires gateway restart (env) [39m
[90m2026-05-14T02:58:58.190+00:00 [39m [36m[gateway] [39m [36msignal SIGUSR1 received [39m
[90m2026-05-14T02:58:58.265+00:00 [39m [36m[gateway] [39m [36mreceived SIGUSR1; restarting [39m
[90m2026-05-14T02:58:58.270+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_stop (1 handlers) [39m
[90m2026-05-14T02:58:58.452+00:00 [39m [33m[shutdown] [39m [36mstarted: gateway restarting [39m
[90m2026-05-14T02:58:59.602+00:00 [39m [34m[gmail-watcher] [39m [36mgmail watcher stopped [39m
[90m2026-05-14T02:58:59.615+00:00 [39m [33m[shutdown] [39m [36mcompleted cleanly in 1163ms [39m
[90m2026-05-14T02:58:59.648+00:00 [39m [36m[gateway] [39m [36mrestart mode: full process restart (spawned pid 26883) [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:00:25.772+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-14T03:00:26.553+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-14T03:00:26.611+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
Config overwrite: /root/.openclaw/openclaw.json (sha256 69472595649969faea1128d1cdec42d31996fb16a84d2db9bfa9cc816729e036 -> d36d7df6539bf1a5f4d6b9ff7c5c55dda3068874e47c23b2ed25cd292dc26150, backup=/root/.openclaw/openclaw.json.bak)
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:00:54.781+00:00 [39m [36m[gateway] [39m [36mauto-enabled plugins: [39m
[36m- ollama/qwen2.5:0.5b model configured, enabled automatically. [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:01:07.345+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-14T03:01:08.832+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-14T03:01:09.192+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-14T03:01:11.014+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-14T03:01:11.103+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
[WARN] WebSocket disconnected
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-14T03:01:11.483+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-14T03:01:11.562+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
[WARN] WebSocket disconnected
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-14T03:01:16.376+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-14T03:01:16.409+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-14T03:01:16.447+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 5443.3ms [39m
[90m2026-05-14T03:01:16.498+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52824 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52824->127.0.0.1:18789 conn=519a0f72…bb3f [39m
[90m2026-05-14T03:01:16.738+00:00 [39m [36m[gateway] [39m [36magent model: ollama/qwen2.5:0.5b (thinking=medium, fast=off) [39m
[90m2026-05-14T03:01:16.746+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 50.1s) [39m
[90m2026-05-14T03:01:16.756+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-14.log [39m
[90m2026-05-14T03:01:19.004+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:01:41.853+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-14T03:01:41.860+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=47s eventLoopDelayP99Ms=7138.7 eventLoopDelayMaxMs=20115.9 eventLoopUtilization=0.998 cpuCoreRatio=0.438 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:6ms,post-attach.update-check:106ms,sidecars.model-prewarm:22846ms [39m
[90m2026-05-14T03:01:41.864+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:01:41.877+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=519a0f72-2720-4e78-8514-24a62b23bb3f peer=127.0.0.1:52824->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:01:41.898+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40402 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40402->127.0.0.1:18789 conn=a66536ac…375e [39m
[90m2026-05-14T03:01:42.009+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36666 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36666->127.0.0.1:18789 conn=05f849c4…6656 [39m
[90m2026-05-14T03:01:42.221+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=05f849c4-d241-4c93-b644-82db5f166656 peer=127.0.0.1:36666->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:01:42.231+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=201 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e31414a5-3f17-4b90-8e4c-f73b77ebdaa5 endpoint=127.0.0.1:36666->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:01:47.427+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-14T03:01:47.457+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40450 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40450->127.0.0.1:18789 conn=0caaa573…1bb0 [39m
[90m2026-05-14T03:01:47.594+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0caaa573-e4a8-42d3-bac7-92d8f04c1bb0 peer=127.0.0.1:40450->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:01:47.613+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=89 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f58bd18c-6517-46e2-9fad-bf7b80ac75eb endpoint=127.0.0.1:40450->127.0.0.1:18789 [39m
[90m2026-05-14T03:01:47.685+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-14T03:01:47.732+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-14T03:01:48.619+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:03.291+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=a66536ac-1f9c-4ca6-9cf4-5e908baf375e peer=127.0.0.1:40402->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:02:03.312+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40464 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40464->127.0.0.1:18789 conn=e2275508…c2f3 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:08.857+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38278 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38278->127.0.0.1:18789 conn=72fe0d90…de50 [39m
[90m2026-05-14T03:02:11.868+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:02:11.954+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=519a0f72-2720-4e78-8514-24a62b23bb3f peer=127.0.0.1:52824->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:02:11.980+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=55400 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:52824->127.0.0.1:18789 conn=519a0f72…bb3f [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:16.392+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56550 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56550->127.0.0.1:18789 conn=d536dd81…5ec0 [39m
[90m2026-05-14T03:02:16.668+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d536dd81-07b9-4deb-8430-154b1cd75ec0 peer=127.0.0.1:56550->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:02:16.687+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=244 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7d46e2bc-7db1-475c-a65e-4ad4ea4ccfb4 endpoint=127.0.0.1:56550->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:17.079+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56560 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56560->127.0.0.1:18789 conn=fcb769f0…fcf0 [39m
[90m2026-05-14T03:02:17.310+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fcb769f0-b93c-4ecb-a48f-27ff2f3cfcf0 peer=127.0.0.1:56560->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:02:17.331+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=199 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a43c5077-b1a4-42cc-8a3d-bf3b8a510d54 endpoint=127.0.0.1:56560->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:18.353+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=e2275508-b0ec-4d44-9913-b7058c0ec2f3 peer=127.0.0.1:40464->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:02:23.881+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=72fe0d90-4830-4139-bdeb-904e308fde50 peer=127.0.0.1:38278->127.0.0.1:18789 remote=127.0.0.1 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:25.320+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43484 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43484->127.0.0.1:18789 conn=d4d56d7f…cbcc [39m
[90m2026-05-14T03:02:25.550+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d4d56d7f-2cf0-42be-a3ed-10fcb5b4cbcc peer=127.0.0.1:43484->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:02:25.570+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=220 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=973f4e87-1d98-4317-88aa-512d225ddf85 endpoint=127.0.0.1:43484->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:32.083+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58292 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58292->127.0.0.1:18789 conn=25fd39c0…d721 [39m
[90m2026-05-14T03:02:32.259+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=25fd39c0-5278-41e7-96d0-bd4714ddd721 peer=127.0.0.1:58292->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:02:32.277+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=155 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=eb32a71d-093c-421f-8fed-521c877e09a1 endpoint=127.0.0.1:58292->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:33.390+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a66536ac-1f9c-4ca6-9cf4-5e908baf375e peer=127.0.0.1:40402->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:02:33.425+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=51410 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:40402->127.0.0.1:18789 conn=a66536ac…375e [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:40.305+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56564 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56564->127.0.0.1:18789 conn=e1578c2b…516a [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:40.530+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e1578c2b-d500-4d65-83fa-0517aec2516a peer=127.0.0.1:56564->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:02:40.556+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=211 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=14046405-8ba3-4fd1-b0d4-e2562e3f01f2 endpoint=127.0.0.1:56564->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:41.871+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:47.041+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56576 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56576->127.0.0.1:18789 conn=93e5cc3d…e03c [39m
[90m2026-05-14T03:02:47.131+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=93e5cc3d-5a97-4050-bd6e-3dd3bddae03c peer=127.0.0.1:56576->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:02:47.142+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=73 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b5169eb0-e893-4ef7-b1a7-25aca7d8d12e endpoint=127.0.0.1:56576->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:48.396+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e2275508-b0ec-4d44-9913-b7058c0ec2f3 peer=127.0.0.1:40464->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:02:48.407+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45055 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:40464->127.0.0.1:18789 conn=e2275508…c2f3 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:06.195+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52296 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52296->127.0.0.1:18789 conn=abe2ea6e…55f9 [39m
[90m2026-05-14T03:03:06.217+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=72fe0d90-4830-4139-bdeb-904e308fde50 peer=127.0.0.1:38278->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:03:06.228+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=57350 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:38278->127.0.0.1:18789 conn=72fe0d90…de50 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:08.172+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55272 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55272->127.0.0.1:18789 conn=8490308e…3dad [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:08.484+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8490308e-971f-4aac-b77a-bd4dbca53dad peer=127.0.0.1:55272->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:03:08.508+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=286 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d98c7c5f-de3f-4cac-8e40-9debbb204f81 endpoint=127.0.0.1:55272->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:11.869+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:16.475+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55284 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55284->127.0.0.1:18789 conn=cacc4623…d3b2 [39m
[90m2026-05-14T03:03:16.741+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=cacc4623-871e-4dfb-b3e2-064378f0d3b2 peer=127.0.0.1:55284->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:03:16.782+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=243 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f87e528e-d864-4610-b689-94dcead1eefd endpoint=127.0.0.1:55284->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:17.096+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55308 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55308->127.0.0.1:18789 conn=6f449811…9a5f [39m
[90m2026-05-14T03:03:17.289+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6f449811-346e-4322-9fec-061794819a5f peer=127.0.0.1:55308->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:03:17.311+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=169 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=de054f40-8efe-45fa-bf7f-09facf9b2814 endpoint=127.0.0.1:55308->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:21.221+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=abe2ea6e-21d0-4e5f-88b4-8318957855f9 peer=127.0.0.1:52296->127.0.0.1:18789 remote=127.0.0.1 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:25.303+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56564 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56564->127.0.0.1:18789 conn=722fb1c9…f9f1 [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:26.151+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=722fb1c9-e546-4d20-afdf-dbf266ddf9f1 peer=127.0.0.1:56564->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:03:26.184+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=827 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=56c8ce07-706b-465b-b5be-b891ff2086d2 endpoint=127.0.0.1:56564->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:32.099+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37194 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37194->127.0.0.1:18789 conn=de6567bd…e99d [39m
[90m2026-05-14T03:03:32.268+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=de6567bd-cac1-4310-b1b6-c6d0c332e99d peer=127.0.0.1:37194->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:03:32.291+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=154 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=66cc2feb-29fa-4f38-a530-e731773cb386 endpoint=127.0.0.1:37194->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:40.258+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50102 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50102->127.0.0.1:18789 conn=f7e0cafc…5610 [39m
[90m2026-05-14T03:03:40.447+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f7e0cafc-3253-4b07-b31a-ec27aaa15610 peer=127.0.0.1:50102->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:03:40.472+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=161 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3c6eb9f7-1903-48e4-b1ec-e88f61560a20 endpoint=127.0.0.1:50102->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:41.879+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:47.051+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50130 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50130->127.0.0.1:18789 conn=4c2eaca0…b366 [39m
[90m2026-05-14T03:03:47.168+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=4c2eaca0-8b01-4c65-bd49-fc7a17f8b366 peer=127.0.0.1:50130->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:03:47.182+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=102 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d7758db9-6e73-4766-8029-3f88890a92b6 endpoint=127.0.0.1:50130->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:51.276+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=abe2ea6e-21d0-4e5f-88b4-8318957855f9 peer=127.0.0.1:52296->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:03:51.310+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45046 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:52296->127.0.0.1:18789 conn=abe2ea6e…55f9 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:34.471+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=53s eventLoopDelayP99Ms=32.7 eventLoopDelayMaxMs=41372.6 eventLoopUtilization=0.805 cpuCoreRatio=0.408 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:04:34.483+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:04:34.539+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44382 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44382->127.0.0.1:18789 conn=927ba3f8…50af [39m
[90m2026-05-14T03:04:34.616+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56736 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56736->127.0.0.1:18789 conn=22c0d41f…5f6f [39m
[90m2026-05-14T03:04:34.687+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56474 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56474->127.0.0.1:18789 conn=1ebaddda…bed4 [39m
[90m2026-05-14T03:04:34.737+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58418 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58418->127.0.0.1:18789 conn=5c4459f3…44dd [39m
[90m2026-05-14T03:04:34.773+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58432 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58432->127.0.0.1:18789 conn=ae415cae…02c9 [39m
[90m2026-05-14T03:04:34.948+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5c4459f3-c452-4563-b990-ffeb876d44dd peer=127.0.0.1:58418->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:04:34.963+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=193 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=613773fa-5830-45aa-bf66-98fd3c78c42f endpoint=127.0.0.1:58418->127.0.0.1:18789 conn=5c4459f3…44dd [39m
[90m2026-05-14T03:04:35.009+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ae415cae-4d77-4532-9fec-cad2d70002c9 peer=127.0.0.1:58432->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:04:35.028+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=209 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a058ae8b-4025-44dc-a850-721f90a56331 endpoint=127.0.0.1:58432->127.0.0.1:18789 conn=ae415cae…02c9 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:42.999+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59672 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59672->127.0.0.1:18789 conn=76e9d987…461c [39m
[90m2026-05-14T03:04:43.296+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=76e9d987-9a56-46a6-aa14-6c9642cb461c peer=127.0.0.1:59672->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:04:43.336+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=280 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2bb96707-927f-405a-be0b-0ffd460619de endpoint=127.0.0.1:59672->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:47.097+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59690 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59690->127.0.0.1:18789 conn=899be3df…2eb2 [39m
[90m2026-05-14T03:04:47.317+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=899be3df-7bd9-44f6-9000-8e276ec82eb2 peer=127.0.0.1:59690->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:04:47.347+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=185 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6ad65b84-1963-4ed8-9d13-2dc14a5a25ed endpoint=127.0.0.1:59690->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:49.595+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=927ba3f8-8c16-4173-8e52-d96d8ac650af peer=127.0.0.1:44382->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:04:49.650+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=22c0d41f-ee90-4bdb-83df-a2a4f4cd5f6f peer=127.0.0.1:56736->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:04:49.719+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=1ebaddda-6dc1-4d3e-8a15-17d69c26bed4 peer=127.0.0.1:56474->127.0.0.1:18789 remote=127.0.0.1 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:02.775+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39792 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39792->127.0.0.1:18789 conn=61094ae4…d4d2 [39m
[90m2026-05-14T03:05:02.887+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=61094ae4-1ddd-45f2-aff3-a98de00bd4d2 peer=127.0.0.1:39792->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:02.896+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=101 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2499d571-ac25-4ada-bd3f-65581acda1c5 endpoint=127.0.0.1:39792->127.0.0.1:18789 [39m
[90m2026-05-14T03:05:04.479+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:17.066+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46008 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46008->127.0.0.1:18789 conn=22c5e1fe…8ae8 [39m
[90m2026-05-14T03:05:17.148+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=22c5e1fe-4b30-442d-ab8c-9f27a0678ae8 peer=127.0.0.1:46008->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:17.156+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=75 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bb184a1a-4048-483b-bcdd-4bcc4373d566 endpoint=127.0.0.1:46008->127.0.0.1:18789 [39m
[90m2026-05-14T03:05:19.671+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=927ba3f8-8c16-4173-8e52-d96d8ac650af peer=127.0.0.1:44382->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:05:19.697+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45097 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:44382->127.0.0.1:18789 conn=927ba3f8…50af [39m
[90m2026-05-14T03:05:19.752+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=22c0d41f-ee90-4bdb-83df-a2a4f4cd5f6f peer=127.0.0.1:56736->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:05:19.766+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45114 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:56736->127.0.0.1:18789 conn=22c0d41f…5f6f [39m
[90m2026-05-14T03:05:19.810+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1ebaddda-6dc1-4d3e-8a15-17d69c26bed4 peer=127.0.0.1:56474->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:05:19.826+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45106 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:56474->127.0.0.1:18789 conn=1ebaddda…bed4 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:32.093+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60172 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60172->127.0.0.1:18789 conn=5ec98ec3…2b78 [39m
[90m2026-05-14T03:05:32.302+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5ec98ec3-593a-4ce0-9119-0ad5e48c2b78 peer=127.0.0.1:60172->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:32.323+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=173 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bd2b8a0a-6046-4e2b-a5cb-81bcd924110a endpoint=127.0.0.1:60172->127.0.0.1:18789 [39m
[90m2026-05-14T03:05:34.474+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:47.090+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54768 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54768->127.0.0.1:18789 conn=5a34327f…32e2 [39m
[90m2026-05-14T03:05:47.306+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5a34327f-daca-4488-b942-ff43854632e2 peer=127.0.0.1:54768->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:47.331+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=183 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9f2322d6-e1ca-423f-9172-92a9ac96c969 endpoint=127.0.0.1:54768->127.0.0.1:18789 [39m
[90m2026-05-14T03:06:27.279+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:07:13.968+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=47s eventLoopDelayP99Ms=19058.9 eventLoopDelayMaxMs=19058.9 eventLoopUtilization=0.996 cpuCoreRatio=0.471 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:07:13.972+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:08:47.548+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-14T03:08:48.353+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-14T03:08:48.816+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-14T03:08:49.207+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-14T03:08:49.617+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-14T03:08:49.894+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-14T03:08:50.202+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-14T03:08:50.761+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 3247.2ms [39m
[90m2026-05-14T03:09:20.867+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-14T03:09:20.873+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 13.2ms [39m
[90m2026-05-14T03:09:51.542+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-14T03:09:51.546+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 14.5ms [39m
[90m2026-05-14T03:11:11.695+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-14T03:11:11.719+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 78.8ms [39m




(no subject)
Inbox
Cosy <cosychiruka@gmail.com>
	
5:28 AM (2 minutes ago)
	
	
to me
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:32.083+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58292 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58292->127.0.0.1:18789 conn=25fd39c0…d721 [39m
[90m2026-05-14T03:02:32.259+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=25fd39c0-5278-41e7-96d0-bd4714ddd721 peer=127.0.0.1:58292->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:02:32.277+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=155 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=eb32a71d-093c-421f-8fed-521c877e09a1 endpoint=127.0.0.1:58292->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:33.390+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a66536ac-1f9c-4ca6-9cf4-5e908baf375e peer=127.0.0.1:40402->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:02:33.425+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=51410 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:40402->127.0.0.1:18789 conn=a66536ac…375e [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:40.305+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56564 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56564->127.0.0.1:18789 conn=e1578c2b…516a [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:40.530+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e1578c2b-d500-4d65-83fa-0517aec2516a peer=127.0.0.1:56564->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:02:40.556+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=211 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=14046405-8ba3-4fd1-b0d4-e2562e3f01f2 endpoint=127.0.0.1:56564->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:41.871+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:02:47.041+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56576 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56576->127.0.0.1:18789 conn=93e5cc3d…e03c [39m
[90m2026-05-14T03:02:47.131+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=93e5cc3d-5a97-4050-bd6e-3dd3bddae03c peer=127.0.0.1:56576->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:02:47.142+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=73 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b5169eb0-e893-4ef7-b1a7-25aca7d8d12e endpoint=127.0.0.1:56576->127.0.0.1:18789 [39m
[90m2026-05-14T03:02:48.396+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e2275508-b0ec-4d44-9913-b7058c0ec2f3 peer=127.0.0.1:40464->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:02:48.407+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45055 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:40464->127.0.0.1:18789 conn=e2275508…c2f3 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:06.195+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52296 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52296->127.0.0.1:18789 conn=abe2ea6e…55f9 [39m
[90m2026-05-14T03:03:06.217+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=72fe0d90-4830-4139-bdeb-904e308fde50 peer=127.0.0.1:38278->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:03:06.228+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=57350 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:38278->127.0.0.1:18789 conn=72fe0d90…de50 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:08.172+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55272 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55272->127.0.0.1:18789 conn=8490308e…3dad [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:08.484+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8490308e-971f-4aac-b77a-bd4dbca53dad peer=127.0.0.1:55272->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:03:08.508+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=286 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d98c7c5f-de3f-4cac-8e40-9debbb204f81 endpoint=127.0.0.1:55272->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:11.869+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:16.475+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55284 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55284->127.0.0.1:18789 conn=cacc4623…d3b2 [39m
[90m2026-05-14T03:03:16.741+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=cacc4623-871e-4dfb-b3e2-064378f0d3b2 peer=127.0.0.1:55284->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:03:16.782+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=243 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f87e528e-d864-4610-b689-94dcead1eefd endpoint=127.0.0.1:55284->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:17.096+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55308 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55308->127.0.0.1:18789 conn=6f449811…9a5f [39m
[90m2026-05-14T03:03:17.289+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6f449811-346e-4322-9fec-061794819a5f peer=127.0.0.1:55308->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) [39m
[90m2026-05-14T03:03:17.311+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fe16c9df-8fe9-4948-a597-19ea753af484) durationMs=169 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=de054f40-8efe-45fa-bf7f-09facf9b2814 endpoint=127.0.0.1:55308->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:21.221+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=abe2ea6e-21d0-4e5f-88b4-8318957855f9 peer=127.0.0.1:52296->127.0.0.1:18789 remote=127.0.0.1 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:25.303+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56564 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56564->127.0.0.1:18789 conn=722fb1c9…f9f1 [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:26.151+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=722fb1c9-e546-4d20-afdf-dbf266ddf9f1 peer=127.0.0.1:56564->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:03:26.184+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=827 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=56c8ce07-706b-465b-b5be-b891ff2086d2 endpoint=127.0.0.1:56564->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:32.099+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37194 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37194->127.0.0.1:18789 conn=de6567bd…e99d [39m
[90m2026-05-14T03:03:32.268+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=de6567bd-cac1-4310-b1b6-c6d0c332e99d peer=127.0.0.1:37194->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:03:32.291+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=154 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=66cc2feb-29fa-4f38-a530-e731773cb386 endpoint=127.0.0.1:37194->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:40.258+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50102 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50102->127.0.0.1:18789 conn=f7e0cafc…5610 [39m
[90m2026-05-14T03:03:40.447+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f7e0cafc-3253-4b07-b31a-ec27aaa15610 peer=127.0.0.1:50102->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:03:40.472+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=161 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3c6eb9f7-1903-48e4-b1ec-e88f61560a20 endpoint=127.0.0.1:50102->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:41.879+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:03:47.051+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50130 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50130->127.0.0.1:18789 conn=4c2eaca0…b366 [39m
[90m2026-05-14T03:03:47.168+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=4c2eaca0-8b01-4c65-bd49-fc7a17f8b366 peer=127.0.0.1:50130->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:03:47.182+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=102 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d7758db9-6e73-4766-8029-3f88890a92b6 endpoint=127.0.0.1:50130->127.0.0.1:18789 [39m
[90m2026-05-14T03:03:51.276+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=abe2ea6e-21d0-4e5f-88b4-8318957855f9 peer=127.0.0.1:52296->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:03:51.310+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45046 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:52296->127.0.0.1:18789 conn=abe2ea6e…55f9 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:34.471+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=53s eventLoopDelayP99Ms=32.7 eventLoopDelayMaxMs=41372.6 eventLoopUtilization=0.805 cpuCoreRatio=0.408 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:04:34.483+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:04:34.539+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44382 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44382->127.0.0.1:18789 conn=927ba3f8…50af [39m
[90m2026-05-14T03:04:34.616+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56736 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56736->127.0.0.1:18789 conn=22c0d41f…5f6f [39m
[90m2026-05-14T03:04:34.687+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56474 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56474->127.0.0.1:18789 conn=1ebaddda…bed4 [39m
[90m2026-05-14T03:04:34.737+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58418 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58418->127.0.0.1:18789 conn=5c4459f3…44dd [39m
[90m2026-05-14T03:04:34.773+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58432 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58432->127.0.0.1:18789 conn=ae415cae…02c9 [39m
[90m2026-05-14T03:04:34.948+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5c4459f3-c452-4563-b990-ffeb876d44dd peer=127.0.0.1:58418->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:04:34.963+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=193 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=613773fa-5830-45aa-bf66-98fd3c78c42f endpoint=127.0.0.1:58418->127.0.0.1:18789 conn=5c4459f3…44dd [39m
[90m2026-05-14T03:04:35.009+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ae415cae-4d77-4532-9fec-cad2d70002c9 peer=127.0.0.1:58432->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:04:35.028+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=209 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a058ae8b-4025-44dc-a850-721f90a56331 endpoint=127.0.0.1:58432->127.0.0.1:18789 conn=ae415cae…02c9 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:42.999+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59672 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59672->127.0.0.1:18789 conn=76e9d987…461c [39m
[90m2026-05-14T03:04:43.296+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=76e9d987-9a56-46a6-aa14-6c9642cb461c peer=127.0.0.1:59672->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:04:43.336+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=280 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2bb96707-927f-405a-be0b-0ffd460619de endpoint=127.0.0.1:59672->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:47.097+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59690 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59690->127.0.0.1:18789 conn=899be3df…2eb2 [39m
[90m2026-05-14T03:04:47.317+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=899be3df-7bd9-44f6-9000-8e276ec82eb2 peer=127.0.0.1:59690->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:04:47.347+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=185 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6ad65b84-1963-4ed8-9d13-2dc14a5a25ed endpoint=127.0.0.1:59690->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[90m2026-05-14T03:04:49.595+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=927ba3f8-8c16-4173-8e52-d96d8ac650af peer=127.0.0.1:44382->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:04:49.650+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=22c0d41f-ee90-4bdb-83df-a2a4f4cd5f6f peer=127.0.0.1:56736->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:04:49.719+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=1ebaddda-6dc1-4d3e-8a15-17d69c26bed4 peer=127.0.0.1:56474->127.0.0.1:18789 remote=127.0.0.1 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:02.775+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39792 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39792->127.0.0.1:18789 conn=61094ae4…d4d2 [39m
[90m2026-05-14T03:05:02.887+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=61094ae4-1ddd-45f2-aff3-a98de00bd4d2 peer=127.0.0.1:39792->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:02.896+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=101 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2499d571-ac25-4ada-bd3f-65581acda1c5 endpoint=127.0.0.1:39792->127.0.0.1:18789 [39m
[90m2026-05-14T03:05:04.479+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:17.066+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46008 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46008->127.0.0.1:18789 conn=22c5e1fe…8ae8 [39m
[90m2026-05-14T03:05:17.148+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=22c5e1fe-4b30-442d-ab8c-9f27a0678ae8 peer=127.0.0.1:46008->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:17.156+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=75 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bb184a1a-4048-483b-bcdd-4bcc4373d566 endpoint=127.0.0.1:46008->127.0.0.1:18789 [39m
[90m2026-05-14T03:05:19.671+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=927ba3f8-8c16-4173-8e52-d96d8ac650af peer=127.0.0.1:44382->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:05:19.697+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45097 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:44382->127.0.0.1:18789 conn=927ba3f8…50af [39m
[90m2026-05-14T03:05:19.752+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=22c0d41f-ee90-4bdb-83df-a2a4f4cd5f6f peer=127.0.0.1:56736->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:05:19.766+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45114 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:56736->127.0.0.1:18789 conn=22c0d41f…5f6f [39m
[90m2026-05-14T03:05:19.810+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1ebaddda-6dc1-4d3e-8a15-17d69c26bed4 peer=127.0.0.1:56474->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:05:19.826+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45106 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:56474->127.0.0.1:18789 conn=1ebaddda…bed4 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:32.093+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60172 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60172->127.0.0.1:18789 conn=5ec98ec3…2b78 [39m
[90m2026-05-14T03:05:32.302+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5ec98ec3-593a-4ce0-9119-0ad5e48c2b78 peer=127.0.0.1:60172->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:32.323+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=173 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bd2b8a0a-6046-4e2b-a5cb-81bcd924110a endpoint=127.0.0.1:60172->127.0.0.1:18789 [39m
[90m2026-05-14T03:05:34.474+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:05:47.090+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54768 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54768->127.0.0.1:18789 conn=5a34327f…32e2 [39m
[90m2026-05-14T03:05:47.306+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5a34327f-daca-4488-b942-ff43854632e2 peer=127.0.0.1:54768->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) [39m
[90m2026-05-14T03:05:47.331+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f73d0872-84a1-40e0-af8c-d38aa47d4b63) durationMs=183 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9f2322d6-e1ca-423f-9172-92a9ac96c969 endpoint=127.0.0.1:54768->127.0.0.1:18789 [39m
[90m2026-05-14T03:06:27.279+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:07:13.968+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=47s eventLoopDelayP99Ms=19058.9 eventLoopDelayMaxMs=19058.9 eventLoopUtilization=0.996 cpuCoreRatio=0.471 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:07:13.972+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:08:47.548+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-14T03:08:48.353+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-14T03:08:48.816+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-14T03:08:49.207+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-14T03:08:49.617+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-14T03:08:49.894+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-14T03:08:50.202+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-14T03:08:50.761+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 3247.2ms [39m
[90m2026-05-14T03:09:20.867+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-14T03:09:20.873+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 13.2ms [39m
[90m2026-05-14T03:09:51.542+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-14T03:09:51.546+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 14.5ms [39m
[90m2026-05-14T03:11:11.695+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-14T03:11:11.719+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 78.8ms [39m
[90m2026-05-14T03:13:16.514+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-14T03:13:16.520+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 14.3ms [39m
[90m2026-05-14T03:13:50.262+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-14T03:13:50.267+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 14.5ms [39m
[90m2026-05-14T03:14:27.299+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=433s eventLoopDelayP99Ms=433254.8 eventLoopDelayMaxMs=433254.8 eventLoopUtilization=1 cpuCoreRatio=0.408 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:14:27.317+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:15:19.678+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:16:07.246+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:17:33.528+00:00 [39m [35m[plugins] [39m [90mloading amazon-bedrock from /usr/local/lib/node_modules/openclaw/dist/extensions/amazon-bedrock/index.js [39m
[90m2026-05-14T03:17:34.144+00:00 [39m [35m[plugins] [39m [90mloading amazon-bedrock-mantle from /usr/local/lib/node_modules/openclaw/dist/extensions/amazon-bedrock-mantle/index.js [39m
[90m2026-05-14T03:17:39.301+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-14T03:17:39.397+00:00 [39m [35m[plugins] [39m [90mloading anthropic-vertex from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic-vertex/index.js [39m
[90m2026-05-14T03:17:39.769+00:00 [39m [35m[plugins] [39m [90mloading arcee from /usr/local/lib/node_modules/openclaw/dist/extensions/arcee/index.js [39m
[90m2026-05-14T03:17:40.160+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-14T03:17:40.253+00:00 [39m [35m[plugins] [39m [90mloading cerebras from /usr/local/lib/node_modules/openclaw/dist/extensions/cerebras/index.js [39m
[90m2026-05-14T03:17:40.538+00:00 [39m [35m[plugins] [39m [90mloading chutes from /usr/local/lib/node_modules/openclaw/dist/extensions/chutes/index.js [39m
[90m2026-05-14T03:17:41.101+00:00 [39m [35m[plugins] [39m [90mloading cloudflare-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js [39m
[90m2026-05-14T03:17:41.701+00:00 [39m [35m[plugins] [39m [90mloading comfy from /usr/local/lib/node_modules/openclaw/dist/extensions/comfy/index.js [39m
[90m2026-05-14T03:17:42.089+00:00 [39m [35m[plugins] [39m [90mloading copilot-proxy from /usr/local/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js [39m
[90m2026-05-14T03:17:42.327+00:00 [39m [35m[plugins] [39m [90mloading deepinfra from /usr/local/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js [39m
[90m2026-05-14T03:17:42.849+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-14T03:17:42.873+00:00 [39m [35m[plugins] [39m [90mloading fal from /usr/local/lib/node_modules/openclaw/dist/extensions/fal/index.js [39m
[90m2026-05-14T03:17:42.993+00:00 [39m [35m[plugins] [39m [90mloading fireworks from /usr/local/lib/node_modules/openclaw/dist/extensions/fireworks/index.js [39m
[90m2026-05-14T03:17:43.129+00:00 [39m [35m[plugins] [39m [90mloading github-copilot from /usr/local/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js [39m
[90m2026-05-14T03:17:43.422+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-14T03:17:45.013+00:00 [39m [35m[plugins] [39m [90mloading groq from /usr/local/lib/node_modules/openclaw/dist/extensions/groq/index.js [39m
[90m2026-05-14T03:17:45.243+00:00 [39m [35m[plugins] [39m [90mloading huggingface from /usr/local/lib/node_modules/openclaw/dist/extensions/huggingface/index.js [39m
[90m2026-05-14T03:17:45.512+00:00 [39m [35m[plugins] [39m [90mloading kilocode from /usr/local/lib/node_modules/openclaw/dist/extensions/kilocode/index.js [39m
[90m2026-05-14T03:17:45.741+00:00 [39m [35m[plugins] [39m [90mloading kimi from /usr/local/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js [39m
[90m2026-05-14T03:17:46.182+00:00 [39m [35m[plugins] [39m [90mloading litellm from /usr/local/lib/node_modules/openclaw/dist/extensions/litellm/index.js [39m
[90m2026-05-14T03:17:46.644+00:00 [39m [35m[plugins] [39m [90mloading lmstudio from /usr/local/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js [39m
[90m2026-05-14T03:17:47.191+00:00 [39m [35m[plugins] [39m [90mloading microsoft-foundry from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js [39m
[90m2026-05-14T03:17:47.820+00:00 [39m [35m[plugins] [39m [90mloading minimax from /usr/local/lib/node_modules/openclaw/dist/extensions/minimax/index.js [39m
[90m2026-05-14T03:17:48.283+00:00 [39m [35m[plugins] [39m [90mloading mistral from /usr/local/lib/node_modules/openclaw/dist/extensions/mistral/index.js [39m
[90m2026-05-14T03:17:48.873+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-14T03:17:48.982+00:00 [39m [35m[plugins] [39m [90mloading nvidia from /usr/local/lib/node_modules/openclaw/dist/extensions/nvidia/index.js [39m
[90m2026-05-14T03:17:49.226+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-14T03:17:50.228+00:00 [39m [35m[plugins] [39m [90mloading openai from /usr/local/lib/node_modules/openclaw/dist/extensions/openai/index.js [39m
[90m2026-05-14T03:17:51.363+00:00 [39m [35m[plugins] [39m [90mloading opencode from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode/index.js [39m
[90m2026-05-14T03:17:51.617+00:00 [39m [35m[plugins] [39m [90mloading opencode-go from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js [39m
[90m2026-05-14T03:17:53.437+00:00 [39m [35m[plugins] [39m [90mloading openrouter from /usr/local/lib/node_modules/openclaw/dist/extensions/openrouter/index.js [39m
[90m2026-05-14T03:17:53.859+00:00 [39m [35m[plugins] [39m [90mloading qianfan from /usr/local/lib/node_modules/openclaw/dist/extensions/qianfan/index.js [39m
[90m2026-05-14T03:17:54.139+00:00 [39m [35m[plugins] [39m [90mloading qwen from /usr/local/lib/node_modules/openclaw/dist/extensions/qwen/index.js [39m
[90m2026-05-14T03:17:54.829+00:00 [39m [35m[plugins] [39m [90mloading sglang from /usr/local/lib/node_modules/openclaw/dist/extensions/sglang/index.js [39m
[90m2026-05-14T03:17:55.147+00:00 [39m [35m[plugins] [39m [90mloading stepfun from /usr/local/lib/node_modules/openclaw/dist/extensions/stepfun/index.js [39m
[90m2026-05-14T03:17:55.447+00:00 [39m [35m[plugins] [39m [90mloading synthetic from /usr/local/lib/node_modules/openclaw/dist/extensions/synthetic/index.js [39m
[90m2026-05-14T03:17:55.677+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-14T03:17:55.713+00:00 [39m [35m[plugins] [39m [90mloading together from /usr/local/lib/node_modules/openclaw/dist/extensions/together/index.js [39m
[90m2026-05-14T03:17:55.950+00:00 [39m [35m[plugins] [39m [90mloading venice from /usr/local/lib/node_modules/openclaw/dist/extensions/venice/index.js [39m
[90m2026-05-14T03:17:56.376+00:00 [39m [35m[plugins] [39m [90mloading vercel-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js [39m
[90m2026-05-14T03:17:56.725+00:00 [39m [35m[plugins] [39m [90mloading vllm from /usr/local/lib/node_modules/openclaw/dist/extensions/vllm/index.js [39m
[90m2026-05-14T03:17:57.149+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-14T03:17:57.289+00:00 [39m [35m[plugins] [39m [90mloading vydra from /usr/local/lib/node_modules/openclaw/dist/extensions/vydra/index.js [39m
[90m2026-05-14T03:17:57.859+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-14T03:17:57.963+00:00 [39m [35m[plugins] [39m [90mloading xiaomi from /usr/local/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js [39m
[90m2026-05-14T03:17:58.347+00:00 [39m [35m[plugins] [39m [90mloading zai from /usr/local/lib/node_modules/openclaw/dist/extensions/zai/index.js [39m
[90m2026-05-14T03:17:58.848+00:00 [39m [35m[plugins] [39m [90mloaded 48 plugin(s) (48 attempted) in 25431.3ms [39m
[90m2026-05-14T03:18:41.022+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_utilization interval=154s eventLoopDelayP99Ms=0 eventLoopDelayMaxMs=0 eventLoopUtilization=1 cpuCoreRatio=0.421 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:18:41.025+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:18:41.069+00:00 [39m [35m[plugins] [39m [90m[hooks] running before_agent_reply (1 handlers, first-claim wins) [39m
[90m2026-05-14T03:18:41.294+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57404 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57404->127.0.0.1:18789 conn=55006518…7f52 [39m
[90m2026-05-14T03:18:41.385+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42592 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42592->127.0.0.1:18789 conn=37bca3f3…fdae [39m
[90m2026-05-14T03:18:41.514+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44940 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44940->127.0.0.1:18789 conn=6daba5e9…8ec0 [39m
[90m2026-05-14T03:18:57.169+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=55006518-c158-4525-a737-b859cba57f52 peer=127.0.0.1:57404->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:18:57.191+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=37bca3f3-3018-4792-8478-3d4cc017fdae peer=127.0.0.1:42592->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:18:57.221+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=6daba5e9-f5df-4766-a072-e676b14a8ec0 peer=127.0.0.1:44940->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:18:57.274+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40428 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40428->127.0.0.1:18789 conn=304123c9…b191 [39m
[90m2026-05-14T03:18:57.534+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50286 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50286->127.0.0.1:18789 conn=cd110e19…22b4 [39m
[90m2026-05-14T03:18:57.738+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37788 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37788->127.0.0.1:18789 conn=f22c6995…2f2b [39m
[90m2026-05-14T03:18:57.914+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60274 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60274->127.0.0.1:18789 conn=1c91eccb…cbaf [39m
[90m2026-05-14T03:18:58.126+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=47114 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:47114->127.0.0.1:18789 conn=8a098b8c…13e4 [39m
[90m2026-05-14T03:19:50.738+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:19:50.757+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=304123c9-3a46-47b0-bd0b-7a617a0fb191 peer=127.0.0.1:40428->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:19:50.766+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=cd110e19-e8d3-4772-93f2-b3919be322b4 peer=127.0.0.1:50286->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:19:50.777+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=f22c6995-5eb9-4d43-8605-b7bdc02b2f2b peer=127.0.0.1:37788->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:19:50.788+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=1c91eccb-6a54-40de-9de9-1674d2a4cbaf peer=127.0.0.1:60274->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:19:50.799+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=8a098b8c-9e5a-4cbf-908f-800508e613e4 peer=127.0.0.1:47114->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:19:50.847+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6daba5e9-f5df-4766-a072-e676b14a8ec0 peer=127.0.0.1:44940->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:19:50.856+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=69320 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:44940->127.0.0.1:18789 conn=6daba5e9…8ec0 [39m
[90m2026-05-14T03:19:50.878+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=37bca3f3-3018-4792-8478-3d4cc017fdae peer=127.0.0.1:42592->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:19:50.887+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=69482 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:42592->127.0.0.1:18789 conn=37bca3f3…fdae [39m
[90m2026-05-14T03:19:50.973+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=55006518-c158-4525-a737-b859cba57f52 peer=127.0.0.1:57404->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:19:50.980+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=69605 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:57404->127.0.0.1:18789 conn=55006518…7f52 [39m
[90m2026-05-14T03:19:51.009+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8a098b8c-9e5a-4cbf-908f-800508e613e4 peer=127.0.0.1:47114->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-05-14T03:19:51.015+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=52888 cause=handshake-timeout handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=44d8966f-6268-4b35-9dff-59918ec1d8ed endpoint=127.0.0.1:47114->127.0.0.1:18789 conn=8a098b8c…13e4 [39m
[90m2026-05-14T03:19:51.038+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40712 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40712->127.0.0.1:18789 conn=ffb9675c…c2c2 [39m
[90m2026-05-14T03:19:51.056+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34254 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34254->127.0.0.1:18789 conn=8117ce54…638f [39m
[90m2026-05-14T03:21:32.951+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-14T03:21:32.960+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 16.0ms [39m
memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=200000 threshold=176000 isHeartbeat=true isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=95 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[90m2026-05-14T03:21:41.144+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=ffb9675c-3e04-419e-b5b2-60efe32cc2c2 peer=127.0.0.1:40712->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:21:41.153+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=8117ce54-a5b5-4e5a-b3b0-328436b9638f peer=127.0.0.1:34254->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:21:51.675+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=121s eventLoopDelayP99Ms=103884.5 eventLoopDelayMaxMs=103884.5 eventLoopUtilization=1 cpuCoreRatio=0.416 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:21:51.679+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:21:51.730+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1c91eccb-6a54-40de-9de9-1674d2a4cbaf peer=127.0.0.1:60274->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:21:51.742+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=173805 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:60274->127.0.0.1:18789 conn=1c91eccb…cbaf [39m
[90m2026-05-14T03:21:51.762+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f22c6995-5eb9-4d43-8605-b7bdc02b2f2b peer=127.0.0.1:37788->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:21:51.771+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=174035 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:37788->127.0.0.1:18789 conn=f22c6995…2f2b [39m
[90m2026-05-14T03:21:51.792+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=cd110e19-e8d3-4772-93f2-b3919be322b4 peer=127.0.0.1:50286->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:21:51.804+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=174283 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:50286->127.0.0.1:18789 conn=cd110e19…22b4 [39m
[90m2026-05-14T03:21:51.827+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=304123c9-3a46-47b0-bd0b-7a617a0fb191 peer=127.0.0.1:40428->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:21:51.838+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=174558 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:40428->127.0.0.1:18789 conn=304123c9…b191 [39m
[90m2026-05-14T03:21:51.890+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8117ce54-a5b5-4e5a-b3b0-328436b9638f peer=127.0.0.1:34254->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-05-14T03:21:51.898+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=120825 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:34254->127.0.0.1:18789 conn=8117ce54…638f [39m
[90m2026-05-14T03:21:57.975+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=session:agent:main:main queueSize=1 [39m
[90m2026-05-14T03:21:57.978+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=session:agent:main:main waitMs=4 queueSize=0 [39m
[90m2026-05-14T03:21:57.984+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=main queueSize=1 [39m
[90m2026-05-14T03:21:57.987+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=main waitMs=4 queueSize=0 [39m
[90m2026-05-14T03:21:59.118+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-14T03:21:59.132+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-14T03:21:59.149+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-14T03:21:59.166+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-14T03:21:59.183+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-14T03:21:59.200+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-14T03:21:59.207+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 96.7ms [39m
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-14T03:22:44.799+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=main durationMs=46806 error="Error: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-14T03:22:44.807+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=session:agent:main:main durationMs=46823 error="Error: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-14T03:22:44.871+00:00 [39m [34m[model-fallback/decision] [39m [33mmodel fallback decision: decision=candidate_failed requested=ollama/qwen2.5:0.5b candidate=ollama/qwen2.5:0.5b reason=auth next=none detail=No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. [39m
Embedded agent failed before reply: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. | No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir.
[90m2026-05-14T03:22:48.954+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T03:22:58.246+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ffb9675c-3e04-419e-b5b2-60efe32cc2c2 peer=127.0.0.1:40712->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:22:58.256+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=187191 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:40712->127.0.0.1:18789 conn=ffb9675c…c2c2 [39m
[90m2026-05-14T03:22:58.281+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43136 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43136->127.0.0.1:18789 conn=3659a005…1112 [39m
[90m2026-05-14T03:22:58.381+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36270 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36270->127.0.0.1:18789 conn=e5bb3f79…2cd2 [39m
[90m2026-05-14T03:22:58.462+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58926 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58926->127.0.0.1:18789 conn=da15916c…a60a [39m
[90m2026-05-14T03:22:59.158+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46704 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46704->127.0.0.1:18789 conn=f6860035…e958 [39m
[90m2026-05-14T03:22:59.392+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f6860035-0fb1-4694-8ba2-e590a63de958 peer=127.0.0.1:46704->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 9cb098c4-2416-4143-9d3a-20cf770992a1) [39m
[90m2026-05-14T03:22:59.418+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 9cb098c4-2416-4143-9d3a-20cf770992a1) durationMs=193 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a8a0f2fc-e487-41ff-90dd-53e92be2d4d6 endpoint=127.0.0.1:46704->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:23:02.056+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46728 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46728->127.0.0.1:18789 conn=d1beaeec…6477 [39m
[90m2026-05-14T03:23:02.153+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d1beaeec-3518-411c-a5b6-566d05686477 peer=127.0.0.1:46728->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 4b4c32de-db2a-4023-a0b2-79f1f6f13a8d) [39m
[90m2026-05-14T03:23:02.164+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 4b4c32de-db2a-4023-a0b2-79f1f6f13a8d) durationMs=81 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=891c370e-aacb-4ba8-80cf-99f51d11be92 endpoint=127.0.0.1:46728->127.0.0.1:18789 [39m
[90m2026-05-14T03:23:13.298+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=3659a005-bee0-4599-98a8-b879a0291112 peer=127.0.0.1:43136->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:23:13.388+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=e5bb3f79-eb96-4420-94ea-0ecbbef22cd2 peer=127.0.0.1:36270->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T03:23:13.473+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=da15916c-b6c3-443f-bf55-a149b262a60a peer=127.0.0.1:58926->127.0.0.1:18789 remote=127.0.0.1 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:23:17.021+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52774 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52774->127.0.0.1:18789 conn=eb84c826…9682 [39m
[90m2026-05-14T03:23:17.089+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=eb84c826-af8b-403b-bb6b-0cf0b7119682 peer=127.0.0.1:52774->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 11c3b362-373d-499d-be13-51926b9c363c) [39m
[90m2026-05-14T03:23:17.098+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 11c3b362-373d-499d-be13-51926b9c363c) durationMs=51 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=949a8ffd-a0d3-414f-bdb2-19d5d9f4f26a endpoint=127.0.0.1:52774->127.0.0.1:18789 [39m
[90m2026-05-14T03:23:18.956+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:23:32.018+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58852 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58852->127.0.0.1:18789 conn=c9d99416…5cce [39m
[90m2026-05-14T03:23:32.082+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c9d99416-fa63-4a8d-a7d0-00988cea5cce peer=127.0.0.1:58852->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: bf1df6fa-1d3c-4007-b581-dbd223e5da98) [39m
[90m2026-05-14T03:23:32.088+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: bf1df6fa-1d3c-4007-b581-dbd223e5da98) durationMs=51 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2ebc3b85-c21e-4f1d-bd33-c8144d93eba9 endpoint=127.0.0.1:58852->127.0.0.1:18789 [39m
[90m2026-05-14T03:23:43.363+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3659a005-bee0-4599-98a8-b879a0291112 peer=127.0.0.1:43136->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:23:43.384+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45030 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:43136->127.0.0.1:18789 conn=3659a005…1112 [39m
[90m2026-05-14T03:23:43.423+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e5bb3f79-eb96-4420-94ea-0ecbbef22cd2 peer=127.0.0.1:36270->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:23:43.433+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45017 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:36270->127.0.0.1:18789 conn=e5bb3f79…2cd2 [39m
[90m2026-05-14T03:23:43.488+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=da15916c-b6c3-443f-bf55-a149b262a60a peer=127.0.0.1:58926->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T03:23:43.494+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45022 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:58926->127.0.0.1:18789 conn=da15916c…a60a [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:23:47.071+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54764 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54764->127.0.0.1:18789 conn=af555ba6…958b [39m
[90m2026-05-14T03:23:47.237+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=af555ba6-04c8-42ce-86fa-6a1789dd958b peer=127.0.0.1:54764->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:23:47.262+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=122 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=53b6633d-3445-43ba-aa0a-8c50d906aee1 endpoint=127.0.0.1:54764->127.0.0.1:18789 [39m
[90m2026-05-14T03:23:48.960+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:24:02.053+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59744 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59744->127.0.0.1:18789 conn=44b30f39…bdc9 [39m
[90m2026-05-14T03:24:02.725+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=44b30f39-8fce-454f-87ba-6a052523bdc9 peer=127.0.0.1:59744->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:24:02.749+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=622 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=8137e447-7277-471c-9ca4-8141dd18b03f endpoint=127.0.0.1:59744->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:24:17.058+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34970 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34970->127.0.0.1:18789 conn=3a63fead…3dc0 [39m
[90m2026-05-14T03:24:17.204+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3a63fead-7217-467b-8230-209b2c4a3dc0 peer=127.0.0.1:34970->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 2846c9ae-2abf-43b9-9d0a-c0bf02472ae9) [39m
[90m2026-05-14T03:24:17.218+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 2846c9ae-2abf-43b9-9d0a-c0bf02472ae9) durationMs=125 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d33a6848-8c41-42a2-940c-205ca4beab76 endpoint=127.0.0.1:34970->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:24:32.034+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49654 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49654->127.0.0.1:18789 conn=ea6b88da…8e24 [39m
[90m2026-05-14T03:24:32.101+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ea6b88da-b0e6-413b-8ed6-f6bda93b8e24 peer=127.0.0.1:49654->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 41f1777f-fed7-4123-a1f7-f8b530536cc7) [39m
[90m2026-05-14T03:24:32.110+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 41f1777f-fed7-4123-a1f7-f8b530536cc7) durationMs=56 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d8bcbdf3-34c9-4907-beed-5b3fd9279432 endpoint=127.0.0.1:49654->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:24:47.048+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46646 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46646->127.0.0.1:18789 conn=49dc2566…26f3 [39m
[90m2026-05-14T03:24:47.142+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=49dc2566-8d81-4a01-b44f-7612a8c426f3 peer=127.0.0.1:46646->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: efc092c7-0a73-49eb-914c-7e7d41874099) [39m
[90m2026-05-14T03:24:47.157+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: efc092c7-0a73-49eb-914c-7e7d41874099) durationMs=75 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=08662635-ab16-47c3-8268-38c674708b30 endpoint=127.0.0.1:46646->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:25:02.047+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50332 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50332->127.0.0.1:18789 conn=eaaa0c1c…78ab [39m
[90m2026-05-14T03:25:02.137+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=eaaa0c1c-fc1c-4083-9c66-b62530d678ab peer=127.0.0.1:50332->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 4044f542-9821-4a16-bfa5-71e8e7027988) [39m
[90m2026-05-14T03:25:02.147+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 4044f542-9821-4a16-bfa5-71e8e7027988) durationMs=78 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6e449221-05ee-425d-8d3f-dfd6089f2676 endpoint=127.0.0.1:50332->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:25:17.076+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41186 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41186->127.0.0.1:18789 conn=f971ff6e…00f3 [39m
[90m2026-05-14T03:25:17.279+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f971ff6e-e56e-4c06-9897-8d393bf800f3 peer=127.0.0.1:41186->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 88b81a83-dc64-40a3-90d7-67320c383236) [39m
[90m2026-05-14T03:25:17.312+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 88b81a83-dc64-40a3-90d7-67320c383236) durationMs=150 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=932e6d9b-6d42-45ad-a794-6835e0f95d4f endpoint=127.0.0.1:41186->127.0.0.1:18789 [39m
[90m2026-05-14T03:25:18.965+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.6 eventLoopDelayMaxMs=9865 eventLoopUtilization=0.415 cpuCoreRatio=0.203 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:4ms,post-attach.update-sentinel:2ms,sidecars.subagent-recovery:716ms,sidecars.main-session-recovery:798ms,sidecars.session-locks:894ms,post-ready.maintenance:10349ms [39m
[90m2026-05-14T03:25:18.978+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:25:32.050+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45938 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45938->127.0.0.1:18789 conn=8b3fe31c…9f74 [39m
[90m2026-05-14T03:25:32.197+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8b3fe31c-3eb7-400c-b4d3-1d8e52df9f74 peer=127.0.0.1:45938->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:25:32.211+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=114 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d8d039f8-8f9a-40be-8992-48f0b3f33b57 endpoint=127.0.0.1:45938->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:25:47.104+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37028 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37028->127.0.0.1:18789 conn=fd6b4386…7158 [39m
[90m2026-05-14T03:25:47.314+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fd6b4386-4240-4352-b08d-9c3465cb7158 peer=127.0.0.1:37028->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: a21b3d95-3e99-4a89-90f5-6944896dd75c) [39m
[90m2026-05-14T03:25:47.344+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: a21b3d95-3e99-4a89-90f5-6944896dd75c) durationMs=160 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2d8080b4-89e4-4692-bc9d-6818f7621628 endpoint=127.0.0.1:37028->127.0.0.1:18789 [39m
[90m2026-05-14T03:25:48.965+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:26:02.049+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43610 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43610->127.0.0.1:18789 conn=3c44515c…0070 [39m
[90m2026-05-14T03:26:02.231+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3c44515c-5d79-43e3-82b6-42e61d740070 peer=127.0.0.1:43610->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:26:02.256+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=137 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=680ae60c-edb7-44f4-afdc-5f4fb486109a endpoint=127.0.0.1:43610->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:26:17.086+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35234 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35234->127.0.0.1:18789 conn=a060e151…fe37 [39m
[90m2026-05-14T03:26:17.322+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a060e151-a32a-414f-95ed-69f9a666fe37 peer=127.0.0.1:35234->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: dd06670c-b57b-4646-a146-b85cb74ce67b) [39m
[90m2026-05-14T03:26:17.349+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: dd06670c-b57b-4646-a146-b85cb74ce67b) durationMs=177 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=79b9b74c-2136-4676-a1b0-82babf8a31e1 endpoint=127.0.0.1:35234->127.0.0.1:18789 [39m
[90m2026-05-14T03:26:18.973+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:26:32.052+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38594 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38594->127.0.0.1:18789 conn=9aa90811…d7c1 [39m
[90m2026-05-14T03:26:32.136+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9aa90811-537f-4a0b-a0c1-fb2915e9d7c1 peer=127.0.0.1:38594->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 4baf2513-239a-4a52-a9bb-dddb11c62b6c) [39m
[90m2026-05-14T03:26:32.146+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 4baf2513-239a-4a52-a9bb-dddb11c62b6c) durationMs=79 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b3dc298a-ea0a-4a5f-8cef-63671dd16792 endpoint=127.0.0.1:38594->127.0.0.1:18789 [39m
[90m2026-05-14T03:26:49.893+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:27:02.048+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48678 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48678->127.0.0.1:18789 conn=dcfed115…0f66 [39m
[90m2026-05-14T03:27:02.130+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=dcfed115-2c64-4f86-8d91-111af8c10f66 peer=127.0.0.1:48678->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 24306317-6e03-4ac3-9c74-a0de3f8205fc) [39m
[90m2026-05-14T03:27:02.135+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 24306317-6e03-4ac3-9c74-a0de3f8205fc) durationMs=65 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f05a0e63-b59d-4666-9a69-ac0fafe0be7d endpoint=127.0.0.1:48678->127.0.0.1:18789 [39m
[90m2026-05-14T03:27:10.200+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40552 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40552->127.0.0.1:18789 conn=19d6b183…7a55 [39m
[90m2026-05-14T03:27:10.357+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=19d6b183-edcd-43c4-ad90-92a744e77a55 peer=127.0.0.1:40552->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: ca6d654a-7a8e-4da3-9de5-5219cd5096cd) [39m
[90m2026-05-14T03:27:10.376+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: ca6d654a-7a8e-4da3-9de5-5219cd5096cd) durationMs=134 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f3257ab4-38eb-448e-970b-34a383bb4a66 endpoint=127.0.0.1:40552->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:27:17.030+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40562 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40562->127.0.0.1:18789 conn=94e78f63…97b1 [39m
[90m2026-05-14T03:27:17.176+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=94e78f63-e378-4b2c-9579-951b428397b1 peer=127.0.0.1:40562->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:27:17.184+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=135 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a5b51562-031e-4331-8fb7-378eb4b37c17 endpoint=127.0.0.1:40562->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:27:32.024+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44514 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44514->127.0.0.1:18789 conn=5de33151…a803 [39m
[90m2026-05-14T03:27:32.094+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5de33151-cfe1-4808-8163-4bd41a77a803 peer=127.0.0.1:44514->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 2b7371bc-ccba-4952-aec0-110cfa41a8c7) [39m
[90m2026-05-14T03:27:32.103+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 2b7371bc-ccba-4952-aec0-110cfa41a8c7) durationMs=55 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d0cdc35f-49b1-4f92-90d8-18a1964a6acb endpoint=127.0.0.1:44514->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:27:47.054+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51942 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51942->127.0.0.1:18789 conn=c93b4662…45ac [39m
[90m2026-05-14T03:27:47.168+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c93b4662-585b-4d73-8b1d-54eb94a145ac peer=127.0.0.1:51942->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T03:27:47.186+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=95 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4ac93487-a0e9-47e9-8e5d-945f954fb291 endpoint=127.0.0.1:51942->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T03:28:02.082+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55400 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55400->127.0.0.1:18789 conn=6854d76c…4076 [39m
[90m2026-05-14T03:28:02.158+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6854d76c-541b-4718-8e1f-19b7c5284076 peer=127.0.0.1:55400->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 392829aa-06d3-478e-acb8-4e4d1e1b09ac) [39m
[90m2026-05-14T03:28:02.163+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 392829aa-06d3-478e-acb8-4e4d1e1b09ac) durationMs=86 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ccc68041-6525-4174-b339-d51635dd53a7 endpoint=127.0.0.1:55400->127.0.0.1:18789 [39m


======================================================================================

DEVICE NODE LOGS:::


(no subject)
Inbox
Cosy <cosychiruka@gmail.com>
	
5:27 AM (3 minutes ago)
	
	
to me

  🦞 LOBSTER-f646...4833
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connection failed: TimeoutException after 0:00:15.000000: Request timed out
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Disconnected, will retry...
[NODE] Challenge received
[NODE] Disconnected, will retry...
[NODE] Manually refreshing gateway token...
[NODE] Disconnected
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Manually refreshing gateway token...
[NODE] Disconnected
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connection failed: TimeoutException after 0:00:20.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — auto-approving device 9cb098c4-2416-4143-9d3a-20cf770992a1...
[NODE] Disconnected, will retry...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Auto-approve attempt 1 failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: Error: "pair" is a runtime slash command (/pair), not a CLI command. It is provided by the "device-pair" plugin. Use `/pair` in a chat session.
    at runCli (file:///usr/local/lib/node_modules/openclaw/dist/cli/run-main.js:451:46)
    at async runMainOrRootHelp (file:///usr/local/lib/node_modules/openclaw/dist/entry.js:411:3)
    at async file:///usr/local/lib/node_modules/openclaw/dist/entry.js:381:55
, null, null)
[NODE] Retrying approval in 2000ms...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Auto-approve attempt 2 failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: Error: "pair" is a runtime slash command (/pair), not a CLI command. It is provided by the "device-pair" plugin. Use `/pair` in a chat session.
    at runCli (file:///usr/local/lib/node_modules/openclaw/dist/cli/run-main.js:451:46)
    at async runMainOrRootHelp (file:///usr/local/lib/node_modules/openclaw/dist/entry.js:411:3)
    at async file:///usr/local/lib/node_modules/openclaw/dist/entry.js:381:55
, null, null)
[NODE] Retrying approval in 4000ms...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Auto-approve attempt 3 failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: Error: "pair" is a runtime slash command (/pair), not a CLI command. It is provided by the "device-pair" plugin. Use `/pair` in a chat session.
    at runCli (file:///usr/local/lib/node_modules/openclaw/dist/cli/run-main.js:451:46)
    at async runMainOrRootHelp (file:///usr/local/lib/node_modules/openclaw/dist/entry.js:411:3)
    at async file:///usr/local/lib/node_modules/openclaw/dist/entry.js:381:55
, null, null)
[NODE] Auto-approval failed after 3 attempts. Manual intervention may be needed.
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — auto-approving device ca6d654a-7a8e-4da3-9de5-5219cd5096cd...
[NODE] Disconnected, will retry...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)



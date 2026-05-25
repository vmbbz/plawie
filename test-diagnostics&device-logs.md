[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-18T22:46:10.353+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-18T22:46:10.463+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-18T22:46:10.537+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-18T22:46:15.711+00:00 [39m [36m[gateway] [39m [36mauto-enabled plugins for this runtime without writing config: [39m
[36m- google/gemini-3.1-pro-preview model configured, enabled automatically. [39m
[90m2026-05-18T22:46:15.735+00:00 [39m [36m[gateway] [39m [33mauth token was missing. Generated a runtime token for this startup without changing config; restart will generate a different token. Persist one with `openclaw config set gateway.auth.mode token` and `openclaw config set gateway.auth.token <token>`. [39m
[90m2026-05-18T22:46:22.166+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T22:46:23.671+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T22:46:38.502+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-18T22:46:38.920+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-18T22:46:38.931+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 534.4ms [39m
[90m2026-05-18T22:46:39.554+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T22:46:39.565+00:00 [39m [36m[gateway] [39m [36mhttp server listening (1 plugin: memory-core; 29.0s) [39m
[90m2026-05-18T22:46:39.576+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T22:46:39.933+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T22:46:40.099+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T22:46:40.137+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-18T22:46:41.079+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-18T22:46:47.640+00:00 [39m [36m[fetch-timeout] [39m [33mfetch timeout after 2500ms (elapsed 5068ms) timer delayed 2568ms, likely event-loop starvation operation=fetchWithTimeout url=https://registry.npmjs.org/openclaw/latest [39m
[90m2026-05-18T22:46:48.337+00:00 [39m [34m[reload] [39m [36mskills snapshot invalidated by config change (skills) [39m
[90m2026-05-18T22:46:48.346+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (gateway.auth.mode, gateway.auth.token, gateway.remote.token, gateway.tailscale, agents.defaults.workspace, agents.defaults.skipBootstrap, session, tools, skills, wizard, meta) [39m
[90m2026-05-18T22:46:48.398+00:00 [39m [34m[reload] [39m [33mconfig change requires gateway restart (gateway.auth.mode, gateway.auth.token, gateway.tailscale) [39m
[90m2026-05-18T22:46:48.408+00:00 [39m [36m[gateway] [39m [36msignal SIGUSR1 received [39m
[90m2026-05-18T22:46:48.445+00:00 [39m [36m[gateway] [39m [36mreceived SIGUSR1; restarting [39m
[90m2026-05-18T22:46:48.451+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_stop (1 handlers) [39m
[90m2026-05-18T22:46:48.521+00:00 [39m [33m[shutdown] [39m [36mstarted: gateway restarting [39m
[90m2026-05-18T22:46:48.569+00:00 [39m [34m[gmail-watcher] [39m [36mgmail watcher stopped [39m
[90m2026-05-18T22:46:48.584+00:00 [39m [33m[shutdown] [39m [36mcompleted cleanly in 62ms [39m
[90m2026-05-18T22:46:48.602+00:00 [39m [36m[gateway] [39m [36mrestart mode: in-process restart (unmanaged: use in-process restart to keep custom supervisor PID tracking stable) [39m
[90m2026-05-18T22:46:50.526+00:00 [39m [36m[gateway] [39m [36mauto-enabled plugins for this runtime without writing config: [39m
[36m- google/gemini-3.1-pro-preview model configured, enabled automatically. [39m
[90m2026-05-18T22:46:55.699+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T22:46:55.716+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T22:46:58.137+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T22:46:58.146+00:00 [39m [36m[gateway] [39m [36mhttp server listening (1 plugin: memory-core; 9.5s) [39m
[90m2026-05-18T22:46:58.155+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T22:46:58.458+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T22:46:58.768+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T22:46:58.791+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
 [90m2026-05-18T22:46:59.108+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-18T22:47:03.995+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-18T22:48:20.548+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.2 eventLoopDelayMaxMs=3946.8 eventLoopUtilization=0.156 cpuCoreRatio=0.073 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:331ms,post-attach.update-sentinel:330ms,sidecars.session-locks:333ms,post-ready.maintenance:2371ms,sidecars.model-prewarm:5536ms [39m
[90m2026-05-18T22:48:20.555+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:48:50.559+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:49:20.548+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:49:49.444+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43158 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43158->127.0.0.1:18789 conn=a6f8ccd7…c81a [39m
[90m2026-05-18T22:49:49.716+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-18T22:49:49.731+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=2 [39m
[90m2026-05-18T22:49:55.229+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=6 [39m
[90m2026-05-18T22:49:55.234+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:49:55.319+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ status 69ms id=cc3786be…d1d7 [39m
[90m2026-05-18T22:49:55.342+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=3 healthVersion=6 [39m
[90m2026-05-18T22:49:55.362+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5920 handshake=connected lastFrameType=req lastFrameMethod=status lastFrameId=cc3786be-5d14-4e30-a533-957e00bbd1d7 endpoint=127.0.0.1:43158->127.0.0.1:18789 [39m
[90m2026-05-18T22:50:05.901+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34684 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34684->127.0.0.1:18789 conn=8535138b…3abb [39m
[90m2026-05-18T22:50:05.918+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:channels.status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-18T22:50:05.931+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=3 stateVersion=4 [39m
[90m2026-05-18T22:50:10.290+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=4 healthVersion=8 [39m
[90m2026-05-18T22:50:10.304+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T22:50:10.329+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=5 healthVersion=8 [39m
[90m2026-05-18T22:50:10.343+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=4425 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=27296552-a717-4229-8c85-2686d6e32c97 endpoint=127.0.0.1:34684->127.0.0.1:18789 [39m
[90m2026-05-18T22:50:10.383+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44098 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44098->127.0.0.1:18789 conn=799bfa8c…55c3 [39m
[90m2026-05-18T22:50:10.409+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:doctor.memory.status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-18T22:50:10.422+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=4 stateVersion=6 [39m
[90m2026-05-18T22:50:15.471+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=6 healthVersion=9 [39m
[90m2026-05-18T22:50:15.867+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ doctor.memory.status 355ms id=c24cc35b…c9cb [39m
[90m2026-05-18T22:50:15.891+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=7 healthVersion=9 [39m
[90m2026-05-18T22:50:15.905+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5513 handshake=connected lastFrameType=req lastFrameMethod=doctor.memory.status lastFrameId=c24cc35b-3202-42bf-b819-d06d33e1c9cb endpoint=127.0.0.1:44098->127.0.0.1:18789 [39m
[90m2026-05-18T22:50:25.241+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=43.8 eventLoopDelayMaxMs=5494.5 eventLoopUtilization=0.54 cpuCoreRatio=0.239 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:331ms,post-attach.update-sentinel:330ms,sidecars.session-locks:333ms,post-ready.maintenance:2371ms,sidecars.model-prewarm:5536ms [39m
[90m2026-05-18T22:50:25.253+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:50:47.292+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45626 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45626->127.0.0.1:18789 conn=588dae22…cf9d [39m
[90m2026-05-18T22:50:47.318+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:device.pair.list version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-18T22:50:47.336+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=8 [39m
[90m2026-05-18T22:50:51.712+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=8 healthVersion=10 [39m
[90m2026-05-18T22:50:51.731+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 6ms id=87196f9c…14e5 [39m
[90m2026-05-18T22:50:51.747+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=9 healthVersion=10 [39m
[90m2026-05-18T22:50:51.759+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4495 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=87196f9c-9a9d-4f99-a35f-1f5f382214e5 endpoint=127.0.0.1:45626->127.0.0.1:18789 [39m
[90m2026-05-18T22:50:55.247+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[90m2026-05-18T22:51:10.762+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38432 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38432->127.0.0.1:18789 conn=5490bb6d…f514 [39m
[90m2026-05-18T22:51:10.806+00:00 [39m [34m[reload] [39m [36mskills snapshot invalidated by config change (skills.entries) [39m
[90m2026-05-18T22:51:10.819+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (gateway.nodes.denyCommands, gateway.nodes.allowCommands, gateway.http, discovery.wideArea, skills.entries, wizard.lastRunAt, wizard.lastRunCommand, meta.lastTouchedAt, plugins) [39m
[90m2026-05-18T22:51:10.837+00:00 [39m [34m[reload] [39m [33mconfig change requires gateway restart (gateway.nodes.denyCommands, gateway.nodes.allowCommands, gateway.http, discovery.wideArea) [39m
[90m2026-05-18T22:51:10.853+00:00 [39m [36m[gateway] [39m [36msignal SIGUSR1 received [39m
[90m2026-05-18T22:51:10.864+00:00 [39m [36m[gateway] [39m [36mreceived SIGUSR1; restarting [39m
[90m2026-05-18T22:51:10.866+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_stop (1 handlers) [39m
[90m2026-05-18T22:51:10.877+00:00 [39m [33m[shutdown] [39m [36mstarted: gateway restarting [39m
[90m2026-05-18T22:51:10.890+00:00 [39m [34m[gmail-watcher] [39m [36mgmail watcher stopped [39m
[WARN] WebSocket disconnected (closeCode=1002 reason=unknown)
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected (closeCode=1002 reason=unknown)
[90m2026-05-18T22:51:11.916+00:00 [39m [33m[shutdown] [39m [33mwebsocket server close exceeded 1000ms; forcing shutdown continuation with 1 tracked client(s) [39m
[90m2026-05-18T22:51:11.975+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5490bb6d-ce1a-415c-a90a-121a54a1f514 peer=127.0.0.1:38432->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-18T22:51:11.985+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=1172 handshake=pending endpoint=127.0.0.1:38432->127.0.0.1:18789 [39m
[90m2026-05-18T22:51:11.997+00:00 [39m [33m[shutdown] [39m [33mcompleted in 1120ms with warnings: websocket-server [39m
[90m2026-05-18T22:51:12.016+00:00 [39m [36m[gateway] [39m [36mrestart mode: in-process restart (unmanaged: use in-process restart to keep custom supervisor PID tracking stable) [39m
[WARN] WebSocket disconnected (closeCode=1002 reason=unknown)
[WARN] WebSocket disconnected (closeCode=1002 reason=unknown)
[WARN] WebSocket disconnected (closeCode=1002 reason=unknown)
[90m2026-05-18T22:51:20.493+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T22:51:20.534+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T22:51:23.404+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-18T22:51:23.412+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-18T22:51:23.429+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 38.9ms [39m
[90m2026-05-18T22:51:24.235+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T22:51:24.246+00:00 [39m [36m[gateway] [39m [36mhttp server listening (1 plugin: memory-core; 12.2s) [39m
[90m2026-05-18T22:51:24.257+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T22:51:24.600+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T22:51:24.925+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T22:51:24.953+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[WARN] WebSocket disconnected (closeCode=1002 reason=unknown)
[90m2026-05-18T22:51:25.373+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-18T22:51:25.703+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46076 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46076->127.0.0.1:18789 conn=c7c45111…befb [39m
[90m2026-05-18T22:51:25.723+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46092 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46092->127.0.0.1:18789 conn=44df879c…494d [39m
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).
[90m2026-05-18T22:51:30.370+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-18T22:51:30.805+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c7c45111-9265-4e0b-8d88-3c65f766befb peer=127.0.0.1:46076->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 4388373e-937c-483a-8a45-0c44f744012e) [39m
[90m2026-05-18T22:51:30.815+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 4388373e-937c-483a-8a45-0c44f744012e) durationMs=5090 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2b9f4f9e-1323-41f8-a7bd-9f949b337418 endpoint=127.0.0.1:46076->127.0.0.1:18789 conn=c7c45111…befb [39m
[90m2026-05-18T22:51:30.979+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=44df879c-4141-429f-9cc6-c5efabfa494d peer=127.0.0.1:46092->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: fc3ce989-a2f6-4178-b001-4ab888a6d7fe) [39m
[90m2026-05-18T22:51:31.022+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: fc3ce989-a2f6-4178-b001-4ab888a6d7fe) durationMs=5223 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=153e3c76-0e0c-4a4e-89b2-9676e57eba56 endpoint=127.0.0.1:46092->127.0.0.1:18789 conn=44df879c…494d [39m
[90m2026-05-18T22:51:44.363+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:51:45.624+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45054 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45054->127.0.0.1:18789 conn=6c86e57c…b060 [39m
[90m2026-05-18T22:51:45.651+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45056 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45056->127.0.0.1:18789 conn=86632453…4903 [39m
[90m2026-05-18T22:51:45.826+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=f8ede5b686d9cde3481644dd92fb301c46b5d5cf3f8857713839623b873f49a5 role=operator [39m
[90m2026-05-18T22:51:45.902+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token conn=6c86e57c…b060 [39m
[90m2026-05-18T22:51:45.917+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-18T22:51:48.887+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=13 [39m
[90m2026-05-18T22:51:48.916+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 12ms id=d7ac02fa…a0e8 [39m
[90m2026-05-18T22:51:48.936+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3338 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=d7ac02fa-36b1-4263-850f-ee0f4a87a0e8 endpoint=127.0.0.1:45054->127.0.0.1:18789 [39m
[90m2026-05-18T22:51:48.957+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token conn=86632453…4903 [39m
[90m2026-05-18T22:51:48.974+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-18T22:51:52.297+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=14 [39m
[90m2026-05-18T22:51:52.349+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 31ms id=e8653ac4…3952 [39m
[90m2026-05-18T22:51:52.367+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=6720 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=e8653ac4-1891-4c87-9022-e123f16a3952 endpoint=127.0.0.1:45056->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:00.146+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45882 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45882->127.0.0.1:18789 conn=3108b75a…7f04 [39m
[90m2026-05-18T22:52:00.322+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T22:52:00.337+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-18T22:52:03.670+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=15 [39m
[90m2026-05-18T22:52:03.695+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 9ms id=0a191a1e…fc51 [39m
[90m2026-05-18T22:52:03.715+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3588 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=0a191a1e-c512-4bb2-b4f7-d1839d4bfc51 endpoint=127.0.0.1:45882->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:03.734+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45888 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45888->127.0.0.1:18789 conn=1d17fcab…7ac0 [39m
[90m2026-05-18T22:52:03.752+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45900 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45900->127.0.0.1:18789 conn=4d7973df…7376 [39m
[90m2026-05-18T22:52:03.783+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=f8ede5b686d9cde3481644dd92fb301c46b5d5cf3f8857713839623b873f49a5 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.approvals,operator.pairing,operator.read,operator.talk.secrets,operator.write client=cli conn=1d17fcab-93e2-473a-9142-fe8134d27ac0 [39m
[90m2026-05-18T22:52:03.918+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T22:52:03.931+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-18T22:52:06.413+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=16 [39m
[90m2026-05-18T22:52:06.460+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1d17fcab-93e2-473a-9142-fe8134d27ac0 peer=127.0.0.1:45888->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-18T22:52:06.475+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=2712 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c93f00ff-d0ba-486e-b34e-6382aacff863 endpoint=127.0.0.1:45888->127.0.0.1:18789 conn=1d17fcab…7ac0 [39m
[90m2026-05-18T22:52:06.496+00:00 [39m [36m[gateway] [39m [31mrequest handler failed: JsonFileReadError: Failed to read JSON file: /root/.openclaw/devices/paired.json <- Error: File changed during read: /root/.openclaw/devices/paired.json [39m
[90m2026-05-18T22:52:06.512+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.list 82ms errorCode=UNAVAILABLE errorMessage=JsonFileReadError: Failed to read JSON file: /root/.openclaw/devices/paired.json <- Error: File changed during read: /root/.openclaw/devices/paired.json conn=4d7973df…7376 id=2a37cc88…2183 [39m
[90m2026-05-18T22:52:06.532+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=2777 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=2a37cc88-bfa1-4926-bb59-d3ed2a8c2183 endpoint=127.0.0.1:45900->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:06.549+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56684 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56684->127.0.0.1:18789 conn=3e20b84c…d9a2 [39m
[90m2026-05-18T22:52:06.621+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-18T22:52:06.638+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[90m2026-05-18T22:52:09.157+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=17 [39m
[90m2026-05-18T22:52:09.221+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56694 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56694->127.0.0.1:18789 conn=9fa4b24f…f4cf [39m
[90m2026-05-18T22:52:09.255+00:00 [39m [36m[gateway] [39m [36mdevice pairing approved device=acc52a345675075ce439c9559af3dc589346b0bda3deb328f3675edac1de351a role=node [39m
[90m2026-05-18T22:52:09.266+00:00 [39m [36m[ws] [39m [36m→ event device.pair.resolved seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-18T22:52:09.280+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.approve 108ms conn=3e20b84c…d9a2 id=d196c741…deb8 [39m
[90m2026-05-18T22:52:09.293+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=2746 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=d196c741-a0a0-493c-b262-255503e5deb8 endpoint=127.0.0.1:56684->127.0.0.1:18789 [39m
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[90m2026-05-18T22:52:09.905+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=2026.5.18 mode=ui clientId=openclaw-control-ui platform=android auth=token conn=9fa4b24f…f4cf [39m
[90m2026-05-18T22:52:09.921+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=6 stateVersion=10 [39m
[90m2026-05-18T22:52:12.240+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=18 [39m
[INFO] Health RPC: ok=true
[90m2026-05-18T22:52:13.725+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 1468ms cached=true id=2d0ceaea…5bc0 [39m
[90m2026-05-18T22:52:16.433+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=19 [39m
[90m2026-05-18T22:52:16.441+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=32s eventLoopDelayP99Ms=2522.9 eventLoopDelayMaxMs=4190.1 eventLoopUtilization=0.71 cpuCoreRatio=0.283 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T22:52:16.443+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Active skills: 1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli, camsnap, canvas, clawhub, coding-agent, diagram-maker, discord, eightctl, gemini, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya, imsg, mcporter, meme-maker, model-usage, nano-pdf, node-connect, node-inspect-debugger, notion, obsidian, openai-whisper, openai-whisper-api, openhue, oracle, ordercli, peekaboo, python-debugpy, sag, session-logs, sherpa-onnx-tts, skill-creator, slack, songsee, sonoscli, spike, spotify-player, summarize, taskflow, taskflow-inbox-triage, things-mac, tmux, trello, video-frames, voice-call, wacli, weather, xurl
[90m2026-05-18T22:52:17.862+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ skills.status 1404ms id=b99e1526…eddc [39m
[90m2026-05-18T22:52:17.885+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56702 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56702->127.0.0.1:18789 conn=fe8a423f…8b9c [39m
[90m2026-05-18T22:52:17.899+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58100 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58100->127.0.0.1:18789 conn=f85ec953…d8a1 [39m
[90m2026-05-18T22:52:18.497+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f85ec953-71b0-4670-a06f-6961dbe6d8a1 peer=127.0.0.1:58100->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:52:18.508+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=537 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=75b18e1f-8bb3-491f-94f3-4961fc11bac0 endpoint=127.0.0.1:58100->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:20.471+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58114 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58114->127.0.0.1:18789 conn=bd379943…c536 [39m
[90m2026-05-18T22:52:21.055+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bd379943-c7a8-4d23-b545-20a415ddc536 peer=127.0.0.1:58114->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:52:21.069+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=544 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1850994a-e3f8-473f-94b1-266a6dc54236 endpoint=127.0.0.1:58114->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:24.430+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56184 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56184->127.0.0.1:18789 conn=93ada999…2a9a [39m
[90m2026-05-18T22:52:24.984+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=93ada999-c9a1-462b-8c27-e8dba7a52a9a peer=127.0.0.1:56184->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:52:24.999+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=518 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d33de8ed-d015-4853-8f49-3b526234c808 endpoint=127.0.0.1:56184->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:26.976+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T22:52:30.510+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=20 [39m
[90m2026-05-18T22:52:30.742+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56198 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56198->127.0.0.1:18789 conn=b4efb8d8…125b [39m
[90m2026-05-18T22:52:31.288+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b4efb8d8-c3d3-4ec9-af11-94ad8863125b peer=127.0.0.1:56198->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:52:31.306+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=515 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=64d27d0f-3d05-4db7-8232-93742e3eed7e endpoint=127.0.0.1:56198->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:32.935+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=fe8a423f-01ee-44c4-ab4e-3750e3528b9c peer=127.0.0.1:56702->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-18T22:52:33.005+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fe8a423f-01ee-44c4-ab4e-3750e3528b9c peer=127.0.0.1:56702->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-05-18T22:52:33.018+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=15073 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:56702->127.0.0.1:18789 conn=fe8a423f…8b9c [39m
[90m2026-05-18T22:52:41.108+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53864 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53864->127.0.0.1:18789 conn=4f3c68d6…de62 [39m
[90m2026-05-18T22:52:41.666+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=4f3c68d6-6072-43dd-bb03-32b9100cde62 peer=127.0.0.1:53864->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:52:41.688+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=510 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=31f33ccd-f473-40c2-a138-26174d86a83c endpoint=127.0.0.1:53864->127.0.0.1:18789 [39m
[90m2026-05-18T22:52:46.444+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:52:56.632+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36086 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36086->127.0.0.1:18789 conn=d2f8e7ca…3472 [39m
[90m2026-05-18T22:52:56.967+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T22:52:57.157+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d2f8e7ca-8fb5-4344-9129-c74a89693472 peer=127.0.0.1:36086->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:52:57.176+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=483 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e7eb73d6-0c32-4e26-bf64-b3d3614d433d endpoint=127.0.0.1:36086->127.0.0.1:18789 [39m
[90m2026-05-18T22:53:00.982+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36100 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36100->127.0.0.1:18789 conn=908c831c…10e3 [39m
[90m2026-05-18T22:53:01.577+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=908c831c-95e9-464c-af4c-3b9acf9d10e3 peer=127.0.0.1:36100->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:53:01.593+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=550 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6dd514b1-d52e-4c5d-957c-7cafd547c7e5 endpoint=127.0.0.1:36100->127.0.0.1:18789 [39m
[90m2026-05-18T22:53:03.555+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36116 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36116->127.0.0.1:18789 conn=c20b925d…c908 [39m
[90m2026-05-18T22:53:04.610+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c20b925d-c41c-4674-b4d1-224cbd52c908 peer=127.0.0.1:36116->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-05-18T22:53:04.622+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=1067 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=035ca2b7-cd14-436c-9200-9d6a6764b423 endpoint=127.0.0.1:36116->127.0.0.1:18789 [39m
[90m2026-05-18T22:53:44.075+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-18T22:53:44.318+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-18T22:53:44.443+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T22:53:44.540+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T22:53:44.647+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T22:53:44.702+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-18T22:53:44.857+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-18T22:53:45.302+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1237.7ms [39m
[90m2026-05-18T22:54:06.804+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T22:54:06.809+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.2ms [39m
[90m2026-05-18T22:54:37.643+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T22:54:37.647+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 16.2ms [39m
[90m2026-05-18T22:55:05.592+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T22:55:05.599+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 13.2ms [39m
[90m2026-05-18T22:55:35.994+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-18T22:55:35.999+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.7ms [39m
[90m2026-05-18T22:56:04.312+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-18T22:56:04.315+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 11.6ms [39m
[90m2026-05-18T22:56:17.922+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=211s eventLoopDelayP99Ms=53.1 eventLoopDelayMaxMs=190723.4 eventLoopUtilization=0.924 cpuCoreRatio=0.435 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T22:56:17.924+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:56:17.937+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T22:56:20.773+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=21 [39m
[90m2026-05-18T22:56:22.671+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34634 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34634->127.0.0.1:18789 conn=31c3c6ba…ed1c [39m
[90m2026-05-18T22:56:22.718+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51792 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51792->127.0.0.1:18789 conn=c2d13fb6…055a [39m
[90m2026-05-18T22:56:45.350+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-18T22:56:45.367+00:00 [39m [35m[plugins] [39m [90mloading arcee from /usr/local/lib/node_modules/openclaw/dist/extensions/arcee/index.js [39m
[90m2026-05-18T22:56:45.433+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-18T22:56:45.450+00:00 [39m [35m[plugins] [39m [90mloading cerebras from /usr/local/lib/node_modules/openclaw/dist/extensions/cerebras/index.js [39m
[90m2026-05-18T22:56:45.506+00:00 [39m [35m[plugins] [39m [90mloading chutes from /usr/local/lib/node_modules/openclaw/dist/extensions/chutes/index.js [39m
[90m2026-05-18T22:56:45.602+00:00 [39m [35m[plugins] [39m [90mloading cloudflare-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js [39m
[90m2026-05-18T22:56:45.727+00:00 [39m [35m[plugins] [39m [90mloading comfy from /usr/local/lib/node_modules/openclaw/dist/extensions/comfy/index.js [39m
[90m2026-05-18T22:56:45.814+00:00 [39m [35m[plugins] [39m [90mloading copilot-proxy from /usr/local/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js [39m
[90m2026-05-18T22:56:45.851+00:00 [39m [35m[plugins] [39m [90mloading deepinfra from /usr/local/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js [39m
[90m2026-05-18T22:56:46.110+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T22:56:46.129+00:00 [39m [35m[plugins] [39m [90mloading fal from /usr/local/lib/node_modules/openclaw/dist/extensions/fal/index.js [39m
[90m2026-05-18T22:56:46.240+00:00 [39m [35m[plugins] [39m [90mloading fireworks from /usr/local/lib/node_modules/openclaw/dist/extensions/fireworks/index.js [39m
[90m2026-05-18T22:56:46.337+00:00 [39m [35m[plugins] [39m [90mloading github-copilot from /usr/local/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js [39m
[90m2026-05-18T22:56:46.486+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-18T22:56:46.794+00:00 [39m [35m[plugins] [39m [90mloading groq from /usr/local/lib/node_modules/openclaw/dist/extensions/groq/index.js [39m
[90m2026-05-18T22:56:46.847+00:00 [39m [35m[plugins] [39m [90mloading huggingface from /usr/local/lib/node_modules/openclaw/dist/extensions/huggingface/index.js [39m
[90m2026-05-18T22:56:46.936+00:00 [39m [35m[plugins] [39m [90mloading kilocode from /usr/local/lib/node_modules/openclaw/dist/extensions/kilocode/index.js [39m
[90m2026-05-18T22:56:47.021+00:00 [39m [35m[plugins] [39m [90mloading kimi from /usr/local/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js [39m
[90m2026-05-18T22:56:47.099+00:00 [39m [35m[plugins] [39m [90mloading litellm from /usr/local/lib/node_modules/openclaw/dist/extensions/litellm/index.js [39m
[90m2026-05-18T22:56:47.191+00:00 [39m [35m[plugins] [39m [90mloading lmstudio from /usr/local/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js [39m
[90m2026-05-18T22:56:47.323+00:00 [39m [35m[plugins] [39m [90mloading microsoft-foundry from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js [39m
[90m2026-05-18T22:56:47.463+00:00 [39m [35m[plugins] [39m [90mloading minimax from /usr/local/lib/node_modules/openclaw/dist/extensions/minimax/index.js [39m
[90m2026-05-18T22:56:47.697+00:00 [39m [35m[plugins] [39m [90mloading mistral from /usr/local/lib/node_modules/openclaw/dist/extensions/mistral/index.js [39m
[90m2026-05-18T22:56:47.839+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T22:56:47.860+00:00 [39m [35m[plugins] [39m [90mloading nvidia from /usr/local/lib/node_modules/openclaw/dist/extensions/nvidia/index.js [39m
[90m2026-05-18T22:56:47.951+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-18T22:56:48.240+00:00 [39m [35m[plugins] [39m [90mloading openai from /usr/local/lib/node_modules/openclaw/dist/extensions/openai/index.js [39m
[90m2026-05-18T22:56:48.967+00:00 [39m [35m[plugins] [39m [90mloading opencode from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode/index.js [39m
[90m2026-05-18T22:56:49.028+00:00 [39m [35m[plugins] [39m [90mloading opencode-go from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js [39m
[90m2026-05-18T22:56:49.702+00:00 [39m [35m[plugins] [39m [90mloading openrouter from /usr/local/lib/node_modules/openclaw/dist/extensions/openrouter/index.js [39m
[90m2026-05-18T22:56:49.933+00:00 [39m [35m[plugins] [39m [90mloading qianfan from /usr/local/lib/node_modules/openclaw/dist/extensions/qianfan/index.js [39m
[90m2026-05-18T22:56:49.991+00:00 [39m [35m[plugins] [39m [90mloading qwen from /usr/local/lib/node_modules/openclaw/dist/extensions/qwen/index.js [39m
[90m2026-05-18T22:56:50.118+00:00 [39m [35m[plugins] [39m [90mloading sglang from /usr/local/lib/node_modules/openclaw/dist/extensions/sglang/index.js [39m
[90m2026-05-18T22:56:50.191+00:00 [39m [35m[plugins] [39m [90mloading stepfun from /usr/local/lib/node_modules/openclaw/dist/extensions/stepfun/index.js [39m
[90m2026-05-18T22:56:50.252+00:00 [39m [35m[plugins] [39m [90mloading synthetic from /usr/local/lib/node_modules/openclaw/dist/extensions/synthetic/index.js [39m
[90m2026-05-18T22:56:50.325+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T22:56:50.341+00:00 [39m [35m[plugins] [39m [90mloading together from /usr/local/lib/node_modules/openclaw/dist/extensions/together/index.js [39m
[90m2026-05-18T22:56:50.429+00:00 [39m [35m[plugins] [39m [90mloading venice from /usr/local/lib/node_modules/openclaw/dist/extensions/venice/index.js [39m
[90m2026-05-18T22:56:50.540+00:00 [39m [35m[plugins] [39m [90mloading vercel-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js [39m
[90m2026-05-18T22:56:50.621+00:00 [39m [35m[plugins] [39m [90mloading vllm from /usr/local/lib/node_modules/openclaw/dist/extensions/vllm/index.js [39m
[90m2026-05-18T22:56:50.692+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-18T22:56:50.710+00:00 [39m [35m[plugins] [39m [90mloading vydra from /usr/local/lib/node_modules/openclaw/dist/extensions/vydra/index.js [39m
[90m2026-05-18T22:56:50.828+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-18T22:56:50.845+00:00 [39m [35m[plugins] [39m [90mloading xiaomi from /usr/local/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js [39m
[90m2026-05-18T22:56:50.949+00:00 [39m [35m[plugins] [39m [90mloading zai from /usr/local/lib/node_modules/openclaw/dist/extensions/zai/index.js [39m
[90m2026-05-18T22:56:51.023+00:00 [39m [35m[plugins] [39m [90mloaded 45 plugin(s) (45 attempted) in 5682.0ms [39m
[90m2026-05-18T22:56:51.068+00:00 [39m [35m[plugins] [39m [90m[hooks] running before_agent_reply (1 handlers, first-claim wins) [39m
[90m2026-05-18T22:56:53.635+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=31c3c6ba-2cca-4597-a639-ae18ef6ced1c peer=127.0.0.1:34634->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-18T22:56:53.650+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=c2d13fb6-21e2-49be-8eb8-096f89ae055a peer=127.0.0.1:51792->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-18T22:56:53.654+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:56:53.665+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T22:57:29.865+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-18T22:57:29.870+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.3ms [39m
2026-05-18T22:57:32.858+00:00 memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=200000 threshold=176000 isHeartbeat=true isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=98 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[90m2026-05-18T22:57:34.723+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=session:agent:main:main queueSize=1 [39m
[90m2026-05-18T22:57:34.725+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=session:agent:main:main waitMs=4 queueSize=0 [39m
[90m2026-05-18T22:57:34.730+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=main queueSize=1 [39m
[90m2026-05-18T22:57:34.732+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=main waitMs=2 queueSize=0 [39m
[90m2026-05-18T22:57:36.858+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-18T22:57:36.866+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-18T22:57:36.881+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 46.5ms [39m
[90m2026-05-18T22:58:04.484+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-18T22:58:04.487+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.2ms [39m
[90m2026-05-18T22:58:47.939+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=main durationMs=73191 error="Error: No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-18T22:58:47.949+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=session:agent:main:main durationMs=73215 error="Error: No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-18T22:58:48.095+00:00 [39m [34m[model-fallback/decision] [39m [33mmodel fallback decision: decision=candidate_failed requested=google/gemini-3.1-pro-preview candidate=google/gemini-3.1-pro-preview reason=auth next=none detail=No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. [39m
2026-05-18T22:58:48.101+00:00 Embedded agent failed before reply: No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. | No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir.
[90m2026-05-18T22:58:48.127+00:00 [39m [36m[ws] [39m [36m→ event heartbeat seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-18T22:58:50.936+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=22 [39m
[90m2026-05-18T22:58:50.943+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=117s eventLoopDelayP99Ms=114487.7 eventLoopDelayMaxMs=114487.7 eventLoopUtilization=1 cpuCoreRatio=0.388 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T22:58:50.946+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:58:50.955+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T22:58:51.042+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c2d13fb6-21e2-49be-8eb8-096f89ae055a peer=127.0.0.1:51792->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-18T22:58:51.061+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=148264 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:51792->127.0.0.1:18789 [39m
[90m2026-05-18T22:58:51.088+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=31c3c6ba-2cca-4597-a639-ae18ef6ced1c peer=127.0.0.1:34634->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-18T22:58:51.107+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=148405 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:34634->127.0.0.1:18789 conn=31c3c6ba…ed1c [39m
[90m2026-05-18T22:59:20.957+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:59:21.010+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T22:59:51.375+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=23 [39m
[90m2026-05-18T22:59:51.382+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T22:59:51.396+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:00:21.396+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:00:21.467+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:00:52.261+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=24 [39m
[90m2026-05-18T23:00:52.271+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=31s eventLoopDelayP99Ms=35.4 eventLoopDelayMaxMs=4125.1 eventLoopUtilization=0.262 cpuCoreRatio=0.158 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:00:52.273+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:00:52.285+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:01:22.670+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:01:22.681+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:01:52.030+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=25 [39m
[90m2026-05-18T23:01:52.675+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:01:52.711+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:02:22.674+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:02:22.708+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:02:51.443+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=26 [39m
[90m2026-05-18T23:02:52.676+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=26.2 eventLoopDelayMaxMs=3307.2 eventLoopUtilization=0.19 cpuCoreRatio=0.087 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:02:52.682+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:02:52.716+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:03:22.675+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:03:22.722+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:03:52.444+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=27 [39m
[90m2026-05-18T23:03:52.682+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:03:52.715+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:04:22.676+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:04:22.721+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:04:51.837+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=28 [39m
[90m2026-05-18T23:04:52.679+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.4 eventLoopDelayMaxMs=3701.5 eventLoopUtilization=0.199 cpuCoreRatio=0.082 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:04:52.686+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:04:52.723+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:05:22.713+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:05:22.763+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:05:51.289+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=29 [39m
[90m2026-05-18T23:05:52.680+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:05:52.767+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:06:23.234+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:06:23.256+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:06:51.025+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=30 [39m
[90m2026-05-18T23:06:53.233+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=26.9 eventLoopDelayMaxMs=2885.7 eventLoopUtilization=0.179 cpuCoreRatio=0.082 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:06:53.238+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:06:53.254+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:07:23.236+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:07:23.281+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:07:54.812+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=31 [39m
[90m2026-05-18T23:07:54.824+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:07:54.838+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:08:24.830+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:08:24.867+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:08:51.706+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=32 [39m
[90m2026-05-18T23:08:54.830+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=24.5 eventLoopDelayMaxMs=3556.8 eventLoopUtilization=0.2 cpuCoreRatio=0.094 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:08:54.839+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:08:54.877+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:09:24.835+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:09:24.893+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:09:52.769+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=33 [39m
[90m2026-05-18T23:09:54.846+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:09:54.882+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:10:24.844+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:10:24.901+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:10:51.826+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=34 [39m
[90m2026-05-18T23:10:54.846+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.9 eventLoopDelayMaxMs=3670 eventLoopUtilization=0.213 cpuCoreRatio=0.109 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:10:54.856+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:10:54.897+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:11:24.860+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:11:24.928+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:11:51.527+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=35 [39m
[90m2026-05-18T23:11:54.846+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:11:54.916+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:12:24.885+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:12:24.954+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:12:52.500+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=36 [39m
[90m2026-05-18T23:12:54.857+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=30.6 eventLoopDelayMaxMs=4341.1 eventLoopUtilization=0.245 cpuCoreRatio=0.102 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:12:54.868+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:12:54.968+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:13:24.845+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:13:24.924+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:13:51.133+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=37 [39m
[90m2026-05-18T23:13:54.861+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:13:54.955+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:14:24.866+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:14:24.952+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:14:51.869+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=38 [39m
[90m2026-05-18T23:14:54.871+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=33.6 eventLoopDelayMaxMs=3701.5 eventLoopUtilization=0.254 cpuCoreRatio=0.165 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:14:54.887+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:14:55.006+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:15:24.872+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:15:25.029+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:15:53.528+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=39 [39m
[90m2026-05-18T23:15:54.881+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:15:54.984+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:16:24.868+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:16:24.951+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:16:52.238+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=40 [39m
[90m2026-05-18T23:16:54.875+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.1 eventLoopDelayMaxMs=4055.9 eventLoopUtilization=0.216 cpuCoreRatio=0.105 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:16:54.884+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:16:54.968+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:17:24.876+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:17:24.979+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:17:51.536+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=41 [39m
[90m2026-05-18T23:17:54.875+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:17:54.971+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:18:24.877+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:18:24.973+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:18:52.660+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=42 [39m
[90m2026-05-18T23:18:54.877+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=31.2 eventLoopDelayMaxMs=4479.5 eventLoopUtilization=0.25 cpuCoreRatio=0.097 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:18:54.887+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:18:54.967+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:19:24.881+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:19:25.013+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:19:51.931+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=43 [39m
[90m2026-05-18T23:19:54.882+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:19:55.001+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:20:24.876+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:20:24.951+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:20:51.727+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=44 [39m
[90m2026-05-18T23:20:54.885+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=30.9 eventLoopDelayMaxMs=3521.1 eventLoopUtilization=0.209 cpuCoreRatio=0.096 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:20:54.899+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:20:54.957+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:21:24.890+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:21:24.994+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:21:51.489+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=45 [39m
[90m2026-05-18T23:21:54.893+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:21:54.984+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:22:24.899+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:22:24.991+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:22:52.875+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=46 [39m
[90m2026-05-18T23:22:54.894+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=34.6 eventLoopDelayMaxMs=4664.1 eventLoopUtilization=0.27 cpuCoreRatio=0.115 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:22:54.907+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:22:54.989+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:23:04.785+00:00 [39m [35m[plugins] [39m [90m[hooks] running before_agent_reply (1 handlers, first-claim wins) [39m
2026-05-18T23:23:41.333+00:00 memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=200000 threshold=176000 isHeartbeat=true isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=98 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[90m2026-05-18T23:23:42.374+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=session:agent:main:main queueSize=1 [39m
[90m2026-05-18T23:23:42.376+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=session:agent:main:main waitMs=3 queueSize=0 [39m
[90m2026-05-18T23:23:42.380+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=main queueSize=1 [39m
[90m2026-05-18T23:23:42.383+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=main waitMs=3 queueSize=0 [39m
[90m2026-05-18T23:24:53.565+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=main durationMs=71172 error="Error: No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-18T23:24:53.574+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=session:agent:main:main durationMs=71188 error="Error: No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-18T23:24:53.623+00:00 [39m [34m[model-fallback/decision] [39m [33mmodel fallback decision: decision=candidate_failed requested=google/gemini-3.1-pro-preview candidate=google/gemini-3.1-pro-preview reason=auth next=none detail=No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. [39m
2026-05-18T23:24:53.627+00:00 Embedded agent failed before reply: No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. | No API key found for provider "google". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir.
[90m2026-05-18T23:24:53.651+00:00 [39m [36m[ws] [39m [36m→ event heartbeat seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-18T23:24:53.661+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:24:53.672+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:24:56.520+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=47 [39m
[90m2026-05-18T23:25:23.673+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:25:23.723+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:25:56.994+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=48 [39m
[90m2026-05-18T23:25:57.010+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:26:23.676+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=34.5 eventLoopDelayMaxMs=1524.6 eventLoopUtilization=0.292 cpuCoreRatio=0.134 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:26:23.688+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:26:27.054+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:26:53.671+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:26:56.665+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=49 [39m
[90m2026-05-18T23:26:57.035+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:27:23.674+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:27:27.069+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:27:53.681+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:27:56.913+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=50 [39m
[90m2026-05-18T23:27:57.044+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:28:23.676+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=33 eventLoopDelayMaxMs=3225.4 eventLoopUtilization=0.224 cpuCoreRatio=0.106 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:28:23.687+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:28:27.038+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:28:53.680+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:28:56.793+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=51 [39m
[90m2026-05-18T23:28:57.051+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:29:23.680+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:29:27.071+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:29:53.677+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:29:56.956+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=52 [39m
[90m2026-05-18T23:29:57.023+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:30:23.678+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=32.4 eventLoopDelayMaxMs=3277.8 eventLoopUtilization=0.227 cpuCoreRatio=0.1 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:30:23.689+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:30:27.061+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:30:53.682+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:30:57.652+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=53 [39m
[90m2026-05-18T23:30:57.668+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:31:23.682+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:31:27.697+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:31:53.685+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:31:56.264+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=54 [39m
[90m2026-05-18T23:31:57.705+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:32:23.688+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=31.2 eventLoopDelayMaxMs=2569 eventLoopUtilization=0.205 cpuCoreRatio=0.102 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:32:23.699+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:32:27.711+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:32:53.687+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:32:57.098+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=55 [39m
[90m2026-05-18T23:32:57.738+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:33:23.698+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:33:27.723+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:33:53.696+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:33:57.525+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=56 [39m
[90m2026-05-18T23:33:57.705+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:34:23.694+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=33.9 eventLoopDelayMaxMs=3827.3 eventLoopUtilization=0.251 cpuCoreRatio=0.121 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:34:23.708+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:34:27.715+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:34:53.696+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:34:56.366+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=57 [39m
[90m2026-05-18T23:34:57.708+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:35:23.698+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:35:27.734+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:35:53.698+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:35:56.995+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=58 [39m
[90m2026-05-18T23:35:57.722+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:36:23.695+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=34.2 eventLoopDelayMaxMs=3292.5 eventLoopUtilization=0.293 cpuCoreRatio=0.132 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:36:23.707+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:36:27.722+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:36:53.695+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:36:57.143+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=59 [39m
[90m2026-05-18T23:36:57.725+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:37:23.698+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:37:27.718+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:37:53.705+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:37:57.341+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=60 [39m
[90m2026-05-18T23:37:57.737+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:38:23.700+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=33.6 eventLoopDelayMaxMs=3630.2 eventLoopUtilization=0.25 cpuCoreRatio=0.12 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:1ms,sidecars.restart-sentinel:340ms,post-attach.update-sentinel:339ms,sidecars.session-locks:342ms,post-ready.maintenance:1495ms,sidecars.model-prewarm:5769ms [39m
[90m2026-05-18T23:38:23.715+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:38:27.726+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:38:53.695+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:38:56.181+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=61 [39m
[90m2026-05-18T23:38:57.708+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T23:39:23.701+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T23:39:27.704+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m







============================================================================================================================================================================================================================================================================



NODE DEVICE LOGS IN FULL BELOW AS THEY ARE::









=========================================================================================







  🦞 LOBSTER-acc5...351a
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null error={code: NOT_PAIRED, message: pairing required: device is not approved yet, details: {code: PAIRING_REQUIRED, reason: not-paired, requestId: fc3ce989-a2f6-4178-b001-4ab888a6d7fe, remediationHint: Approve this device from the pending pairing requests., deviceId: acc52a345675075ce439c9559af3dc589346b0bda3deb328f3675edac1de351a, requestedRole: node, requestedScopes: []}}
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected (closeCode=1008 reason=pairing required: device is not approved yet (requestId: fc3ce989-a2f6-4178-b001-4ab888a6d7fe)); reconnect delegated to socket backoff/watchdog
[NODE] Pairing required (1008) — approving fc3ce989-a2f6-4178-b001-4ab888a6d7fe via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] Device approved; received new node token (SFnTZFe9...)
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Challenge received
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] WebSocket reconnected, completing handshake...
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Challenge received
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] WebSocket reconnected, completing handshake...
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Challenge received
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] WebSocket reconnected, completing handshake...
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Challenge received
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] WebSocket reconnected, completing handshake...
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Challenge received
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] WebSocket reconnected, completing handshake...
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Challenge received
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Challenge received
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] WebSocket reconnected, completing handshake...
[NODE] Using cached node device token: SFnTZFe9...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Challenge received
[NODE] Connect response ok=false payload=null error={code: INVALID_REQUEST, message: device nonce mismatch, details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}}
[NODE] Connect error: INVALID_REQUEST - device nonce mismatch
[NODE] Connect error details: {code: DEVICE_AUTH_NONCE_MISMATCH, reason: device-nonce-mismatch}
[NODE] Disconnected (closeCode=1008 reason=device nonce mismatch); reconnect delegated to socket backoff/watchdog
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:45.000000: Future not completed

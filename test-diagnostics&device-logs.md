Breakthrough in 200 ok health check and temporary device connection which then fails
Inbox
Cosy <cosychiruka@gmail.com>
	
7:00 PM (22 minutes ago)
	
	
to me
[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-17T16:51:49.156+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-17T16:51:50.349+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-17T16:51:50.439+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-17T16:52:11.844+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-17T16:52:13.494+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-17T16:52:13.790+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-17T16:52:15.965+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-17T16:52:16.077+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-17T16:52:16.606+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-17T16:52:16.722+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-17T16:52:21.712+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-17T16:52:21.769+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-17T16:52:21.808+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 5853.0ms [39m
[90m2026-05-17T16:52:21.884+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-17T16:52:21.892+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 31.4s) [39m
[90m2026-05-17T16:52:21.902+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-17.log [39m
[90m2026-05-17T16:52:22.808+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-17T16:52:32.205+00:00 [39m [36m[fetch-timeout] [39m [33mfetch timeout after 2500ms (elapsed 9179ms) timer delayed 6679ms, likely event-loop starvation operation=fetchWithTimeout url=https://registry.npmjs.org/openclaw/latest [39m
[90m2026-05-17T16:52:32.222+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-17T16:52:36.150+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-17T16:52:36.169+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=30s eventLoopDelayP99Ms=6866.1 eventLoopDelayMaxMs=7944 eventLoopUtilization=0.996 cpuCoreRatio=0.513 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:6ms,post-attach.update-check:67ms,sidecars.model-prewarm:9410ms [39m
[90m2026-05-17T16:52:36.172+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:52:36.232+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-17T16:52:36.248+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-17T16:52:36.487+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-17T16:52:38.310+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49210 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49210->127.0.0.1:18789 conn=a3b9cddc…e866 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-17T16:52:45.782+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a3b9cddc-d83c-48ae-9519-741dde70e866 peer=127.0.0.1:49210->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-17T16:52:45.789+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=7467 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2d476aca-0a4c-42e8-89f0-839f8e434a62 endpoint=127.0.0.1:49210->127.0.0.1:18789 [39m
[90m2026-05-17T16:52:48.544+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34752 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34752->127.0.0.1:18789 conn=10123970…9eb9 [39m
[90m2026-05-17T16:52:49.324+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=10123970-8821-4943-9bf3-33cbc56f9eb9 peer=127.0.0.1:34752->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 6ddf09f7-dbe7-49ea-bcee-f1b314d52f94) [39m
[90m2026-05-17T16:52:49.337+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 6ddf09f7-dbe7-49ea-bcee-f1b314d52f94) durationMs=755 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c21d5a8d-e337-419b-9a89-daaaf8843e45 endpoint=127.0.0.1:34752->127.0.0.1:18789 [39m
[90m2026-05-17T16:53:00.490+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56480 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56480->127.0.0.1:18789 conn=8710b400…1d8e [39m
[90m2026-05-17T16:53:00.684+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 role=operator [39m
[90m2026-05-17T16:53:00.727+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:53:00.742+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:53:05.686+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=3 [39m
[90m2026-05-17T16:53:05.703+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56496 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56496->127.0.0.1:18789 conn=83a3a14b…b9bb [39m
[90m2026-05-17T16:53:06.409+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:53:06.876+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:53:06.883+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:53:11.940+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=1 healthVersion=4 [39m
[90m2026-05-17T16:53:11.948+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-17T16:53:11.962+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=11489 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=be49c413-4097-4078-8d7a-2f3d8b9920db endpoint=127.0.0.1:56480->127.0.0.1:18789 conn=8710b400…1d8e [39m
[90m2026-05-17T16:53:11.971+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 6274ms id=be49c413…20db [39m
[90m2026-05-17T16:53:11.988+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 28ms conn=83a3a14b…b9bb id=35af0f74…de0f [39m
[90m2026-05-17T16:53:12.001+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=6296 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=35af0f74-8c3b-4ab9-9d53-fc84fb12de0f endpoint=127.0.0.1:56496->127.0.0.1:18789 [39m
[90m2026-05-17T16:53:25.803+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52248 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52248->127.0.0.1:18789 conn=3a5e01be…8448 [39m
[90m2026-05-17T16:53:25.935+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:53:25.947+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:53:30.976+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=5 [39m
[90m2026-05-17T16:53:31.005+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52262 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52262->127.0.0.1:18789 conn=03d2dd0a…cb11 [39m
[90m2026-05-17T16:53:31.019+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 23ms conn=3a5e01be…8448 id=b6e45b07…17d7 [39m
[90m2026-05-17T16:53:31.038+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5248 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=b6e45b07-a5e7-4474-b736-efc7b2f717d7 endpoint=127.0.0.1:52248->127.0.0.1:18789 [39m
[90m2026-05-17T16:53:31.097+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52266 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52266->127.0.0.1:18789 conn=3e9d9f7b…264b [39m
[90m2026-05-17T16:53:31.260+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=03d2dd0a…cb11 [39m
[90m2026-05-17T16:53:31.269+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:53:36.772+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=6 [39m
[90m2026-05-17T16:53:36.778+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:53:36.802+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=3e9d9f7b…264b [39m
[90m2026-05-17T16:53:36.810+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:53:42.911+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=1 healthVersion=7 [39m
[90m2026-05-17T16:53:48.624+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=1 healthVersion=8 [39m
[90m2026-05-17T16:53:48.638+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-17T16:53:48.646+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 11859ms conn=03d2dd0a…cb11 id=af8b3a32…8e85 [39m
[90m2026-05-17T16:53:48.655+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=17562 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=af1046b2-83d4-4b64-a167-0d4c9d25f706 endpoint=127.0.0.1:52266->127.0.0.1:18789 conn=3e9d9f7b…264b [39m
[90m2026-05-17T16:53:48.663+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=17660 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=af8b3a32-d4ff-4113-9e99-d57235a48e85 endpoint=127.0.0.1:52262->127.0.0.1:18789 conn=03d2dd0a…cb11 [39m
[90m2026-05-17T16:53:48.678+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49334 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49334->127.0.0.1:18789 conn=73eba81b…0ffb [39m
[90m2026-05-17T16:53:48.698+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=73eba81b-e180-4c76-a8d9-93424b060ffb peer=127.0.0.1:49334->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1006 reason=n/a [39m
[90m2026-05-17T16:53:48.716+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=15 handshake=pending endpoint=127.0.0.1:49334->127.0.0.1:18789 [39m
[90m2026-05-17T16:54:01.847+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46590 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46590->127.0.0.1:18789 conn=0a7f398f…daac [39m
[90m2026-05-17T16:54:01.934+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:54:01.948+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:54:06.882+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=9 [39m
[90m2026-05-17T16:54:06.886+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:54:06.900+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46604 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46604->127.0.0.1:18789 conn=e0b97d49…fbc1 [39m
[90m2026-05-17T16:54:06.917+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 22ms conn=0a7f398f…daac id=921e3d79…b083 [39m
[90m2026-05-17T16:54:06.939+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5107 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=921e3d79-e667-4628-8ff8-f27e102db083 endpoint=127.0.0.1:46590->127.0.0.1:18789 [39m
[90m2026-05-17T16:54:07.033+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=e0b97d49…fbc1 [39m
[90m2026-05-17T16:54:07.041+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:54:12.158+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=10 [39m
[90m2026-05-17T16:54:12.185+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 16ms id=dc0c2d05…bf82 [39m
[90m2026-05-17T16:54:12.201+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5298 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=dc0c2d05-c7e8-4c9c-9b7d-c5129d67bf82 endpoint=127.0.0.1:46604->127.0.0.1:18789 [39m
[90m2026-05-17T16:54:21.725+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57382 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57382->127.0.0.1:18789 conn=e93967f1…944d [39m
[90m2026-05-17T16:54:21.815+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:54:21.824+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:54:26.993+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=11 [39m
[90m2026-05-17T16:54:27.013+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42138 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42138->127.0.0.1:18789 conn=91f4d07f…7ae5 [39m
[90m2026-05-17T16:54:27.025+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 23ms conn=e93967f1…944d id=880d7ce3…3c59 [39m
[90m2026-05-17T16:54:27.038+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5315 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=880d7ce3-a1cc-40d5-83e6-9002c74f3c59 endpoint=127.0.0.1:57382->127.0.0.1:18789 [39m
[90m2026-05-17T16:54:27.056+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42146 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42146->127.0.0.1:18789 conn=a76ca222…230d [39m
[90m2026-05-17T16:54:27.078+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.admin client=cli conn=a76ca222-684f-4f95-8311-18585706230d [39m
[90m2026-05-17T16:54:27.127+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=91f4d07f…7ae5 [39m
[90m2026-05-17T16:54:27.137+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:54:33.003+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=12 [39m
[90m2026-05-17T16:54:33.019+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 5ms id=4d2b3330…4d47 [39m
[90m2026-05-17T16:54:33.046+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=6029 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=4d2b3330-b510-41bf-8ec5-a0d29f654d47 endpoint=127.0.0.1:42138->127.0.0.1:18789 [39m
[90m2026-05-17T16:54:33.068+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42150 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42150->127.0.0.1:18789 conn=058ce9ab…c508 [39m
[90m2026-05-17T16:54:33.090+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.admin client=cli conn=058ce9ab-f43e-4d61-bb2b-5f97e981c508 [39m
[90m2026-05-17T16:54:33.111+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a76ca222-684f-4f95-8311-18585706230d peer=127.0.0.1:42146->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-17T16:54:33.118+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=6047 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=475f2797-ad45-48b3-9e32-697013a62b14 endpoint=127.0.0.1:42146->127.0.0.1:18789 conn=a76ca222…230d [39m
[90m2026-05-17T16:54:33.232+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=058ce9ab-f43e-4d61-bb2b-5f97e981c508 peer=127.0.0.1:42150->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=pairing required: device is asking for more scopes than currently approved (requestId: 9ed0ba4c-cab8-432a-a678-114afaade [39m
[90m2026-05-17T16:54:33.241+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is asking for more scopes than currently approved (requestId: 9ed0ba4c-cab8-432a-a678-114afaade durationMs=152 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f2768d9a-be12-4d4a-9317-47993750145b endpoint=127.0.0.1:42150->127.0.0.1:18789 conn=058ce9ab…c508 [39m
[90m2026-05-17T16:54:33.361+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42156 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42156->127.0.0.1:18789 conn=3d503dd0…ca99 [39m
[90m2026-05-17T16:54:34.210+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3d503dd0-6796-486a-8966-1dcdcd99ca99 peer=127.0.0.1:42156->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: aba4b7f1-e68b-4630-a828-a6ec1fe74c25) [39m
[90m2026-05-17T16:54:34.226+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: aba4b7f1-e68b-4630-a828-a6ec1fe74c25) durationMs=799 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6f4fbf78-f4b1-4a48-bc14-77ec9214c7b3 endpoint=127.0.0.1:42156->127.0.0.1:18789 [39m
[90m2026-05-17T16:54:36.888+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=39.5 eventLoopDelayMaxMs=5888.8 eventLoopUtilization=0.576 cpuCoreRatio=0.244 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:76ms,sidecars.main-session-recovery:208ms,sidecars.session-locks:235ms,post-ready.maintenance:2872ms [39m
[90m2026-05-17T16:54:36.892+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:54:49.676+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55972 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55972->127.0.0.1:18789 conn=839b8d6f…9498 [39m
[90m2026-05-17T16:54:49.738+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:54:49.747+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:54:55.049+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=14 [39m
[90m2026-05-17T16:54:55.067+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55986 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55986->127.0.0.1:18789 conn=ae22b29f…60dc [39m
[90m2026-05-17T16:54:55.086+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ device.pair.remove 27ms errorCode=INVALID_REQUEST errorMessage=unknown deviceId conn=839b8d6f…9498 id=ed30cece…32c7 [39m
[90m2026-05-17T16:54:55.106+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5432 handshake=connected lastFrameType=req lastFrameMethod=device.pair.remove lastFrameId=ed30cece-e120-407f-bac9-abc3822032c7 endpoint=127.0.0.1:55972->127.0.0.1:18789 [39m
[90m2026-05-17T16:54:55.154+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=ae22b29f…60dc [39m
[90m2026-05-17T16:54:55.164+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:55:00.275+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=15 [39m
[90m2026-05-17T16:55:00.293+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 6ms id=21d08b6a…6165 [39m
[90m2026-05-17T16:55:00.306+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5240 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=21d08b6a-2827-48b7-8cf9-ea22b2fe6165 endpoint=127.0.0.1:55986->127.0.0.1:18789 [39m
[90m2026-05-17T16:55:06.888+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:55:10.059+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55802 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55802->127.0.0.1:18789 conn=3d15167a…242a [39m
[90m2026-05-17T16:55:10.253+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:55:10.277+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:55:16.416+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=16 [39m
[90m2026-05-17T16:55:16.438+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 8ms id=de89aee0…9bc0 [39m
[90m2026-05-17T16:55:16.450+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=6401 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=de89aee0-22af-4170-8b38-ae85ae009bc0 endpoint=127.0.0.1:55802->127.0.0.1:18789 [39m
[90m2026-05-17T16:55:16.469+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49918 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49918->127.0.0.1:18789 conn=6bcca407…95a9 [39m
[90m2026-05-17T16:55:16.514+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:55:16.521+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[WARN] WebSocket disconnected
[90m2026-05-17T16:55:21.551+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=17 [39m
[90m2026-05-17T16:55:21.560+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-17T16:55:21.575+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49934 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49934->127.0.0.1:18789 conn=817f279b…aa0a [39m
[90m2026-05-17T16:55:21.613+00:00 [39m [36m[gateway] [39m [36mdevice pairing removed device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 [39m
[90m2026-05-17T16:55:21.620+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.remove 51ms conn=6bcca407…95a9 id=c423459c…39b6 [39m
[90m2026-05-17T16:55:21.633+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5162 handshake=connected lastFrameType=req lastFrameMethod=device.pair.remove lastFrameId=c423459c-2db4-4b94-8952-66737c3339b6 endpoint=127.0.0.1:49918->127.0.0.1:18789 [39m
[90m2026-05-17T16:55:21.718+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 role=operator [39m
[90m2026-05-17T16:55:21.730+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=817f279b…aa0a [39m
[90m2026-05-17T16:55:21.739+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:55:26.853+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=18 [39m
[90m2026-05-17T16:55:26.880+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 17ms id=141c5782…f2b0 [39m
[90m2026-05-17T16:55:26.892+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5319 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=141c5782-da90-4f83-bb7a-ba813314f2b0 endpoint=127.0.0.1:49934->127.0.0.1:18789 [39m
[90m2026-05-17T16:55:26.913+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32870 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32870->127.0.0.1:18789 conn=d829dc6b…4cc6 [39m
[90m2026-05-17T16:55:26.933+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.admin client=cli conn=d829dc6b-9320-4696-9d0e-ce82ef4d4cc6 [39m
[90m2026-05-17T16:55:27.053+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d829dc6b-9320-4696-9d0e-ce82ef4d4cc6 peer=127.0.0.1:32870->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-17T16:55:27.062+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=128 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=789e69e2-4b9a-48c3-8fc0-dca1d8beddd3 endpoint=127.0.0.1:32870->127.0.0.1:18789 [39m
[90m2026-05-17T16:55:36.897+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-17T16:55:37.732+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41916 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41916->127.0.0.1:18789 conn=1d3d4110…39ba [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-17T16:55:38.518+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1d3d4110-2c62-407e-8abb-be38913d39ba peer=127.0.0.1:41916->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-17T16:55:38.526+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=765 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=253b9a1a-06f3-451c-950f-3de9e22b87fc endpoint=127.0.0.1:41916->127.0.0.1:18789 [39m
[90m2026-05-17T16:55:49.164+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33528 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33528->127.0.0.1:18789 conn=ac780599…6d09 [39m
[90m2026-05-17T16:55:49.248+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:55:49.258+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:55:54.446+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=20 [39m
[90m2026-05-17T16:55:54.454+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-17T16:55:54.479+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33548 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33548->127.0.0.1:18789 conn=0ec94a8a…0b97 [39m
[90m2026-05-17T16:55:54.488+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 24ms conn=ac780599…6d09 id=b6a6c2cd…63ee [39m
[90m2026-05-17T16:55:54.501+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5338 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=b6a6c2cd-ee71-422b-9b38-f41a785163ee endpoint=127.0.0.1:33528->127.0.0.1:18789 [39m
[90m2026-05-17T16:55:54.607+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=0ec94a8a…0b97 [39m
[90m2026-05-17T16:55:54.616+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:55:59.779+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=21 [39m
[90m2026-05-17T16:55:59.794+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 4ms id=d91cc485…031c [39m
[90m2026-05-17T16:55:59.808+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5326 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=d91cc485-ee62-4b9a-a835-8f42da25031c endpoint=127.0.0.1:33548->127.0.0.1:18789 [39m
[90m2026-05-17T16:56:06.891+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:56:09.618+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60238 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60238->127.0.0.1:18789 conn=e83abfa9…3de6 [39m
[90m2026-05-17T16:56:09.715+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:56:09.725+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:56:14.728+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=22 [39m
[90m2026-05-17T16:56:14.745+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 5ms id=2c6b1d0a…a9b9 [39m
[90m2026-05-17T16:56:14.758+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5139 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=2c6b1d0a-277a-4bac-90e6-43986765a9b9 endpoint=127.0.0.1:60238->127.0.0.1:18789 [39m
[90m2026-05-17T16:56:14.772+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60248 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60248->127.0.0.1:18789 conn=9fd0c7e3…7d6d [39m
[90m2026-05-17T16:56:14.790+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60254 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60254->127.0.0.1:18789 conn=0ebc414e…b8c7 [39m
[90m2026-05-17T16:56:14.800+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.admin client=cli conn=9fd0c7e3-fb92-4cec-aa4b-993bdb967d6d [39m
[90m2026-05-17T16:56:14.872+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-17T16:56:14.880+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:56:19.870+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=23 [39m
[90m2026-05-17T16:56:19.927+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9fd0c7e3-fb92-4cec-aa4b-993bdb967d6d peer=127.0.0.1:60248->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-17T16:56:19.942+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=5119 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b0c3fb9f-2a88-4eeb-9b46-3e2ba1a99d74 endpoint=127.0.0.1:60248->127.0.0.1:18789 conn=9fd0c7e3…7d6d [39m
[90m2026-05-17T16:56:19.988+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 81ms conn=0ebc414e…b8c7 id=fd7877da…365b [39m
[90m2026-05-17T16:56:20.002+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=5210 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=fd7877da-d4da-489a-8d99-0360f716365b endpoint=127.0.0.1:60254->127.0.0.1:18789 [39m
[90m2026-05-17T16:56:20.043+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34224 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34224->127.0.0.1:18789 conn=7cded90c…2058 [39m
[90m2026-05-17T16:56:20.059+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=cc570e52e705c4a9062884ba750712901e805a6b0c58cf1769ef2aac767c33b0 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.admin client=cli conn=7cded90c-f9b3-4c67-9d55-1a526af42058 [39m
[90m2026-05-17T16:56:20.117+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34226 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34226->127.0.0.1:18789 conn=15f1af80…2507 [39m
[90m2026-05-17T16:56:20.150+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7cded90c-f9b3-4c67-9d55-1a526af42058 peer=127.0.0.1:34224->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-17T16:56:20.157+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=97 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e6161dd7-c1e6-4495-8f05-87273a93a3a5 endpoint=127.0.0.1:34224->127.0.0.1:18789 conn=7cded90c…2058 [39m
[90m2026-05-17T16:56:20.788+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=15f1af80-939f-4e16-9d46-33550a3b2507 peer=127.0.0.1:34226->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 803688e4-7937-44c2-9db8-340ef624ffa2) [39m
[90m2026-05-17T16:56:20.797+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 803688e4-7937-44c2-9db8-340ef624ffa2) durationMs=664 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=044c904b-cfbb-4232-9840-287076d379f5 endpoint=127.0.0.1:34226->127.0.0.1:18789 conn=15f1af80…2507 [39m
[90m2026-05-17T16:56:36.804+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41660 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41660->127.0.0.1:18789 conn=a62445aa…18bc [39m
[90m2026-05-17T16:56:36.873+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41674 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41674->127.0.0.1:18789 conn=568aff0e…0282 [39m
[90m2026-05-17T16:56:36.903+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=36.8 eventLoopDelayMaxMs=5033.2 eventLoopUtilization=0.372 cpuCoreRatio=0.165 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:76ms,sidecars.main-session-recovery:208ms,sidecars.session-locks:235ms,post-ready.maintenance:2872ms [39m
[90m2026-05-17T16:56:36.906+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:56:36.970+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=a62445aa…18bc [39m
[90m2026-05-17T16:56:36.989+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:56:42.480+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=24 [39m
[90m2026-05-17T16:56:42.509+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=568aff0e…0282 [39m
[90m2026-05-17T16:56:42.516+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:56:47.742+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=1 healthVersion=25 [39m
[90m2026-05-17T16:56:54.919+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=1 healthVersion=26 [39m
[90m2026-05-17T16:56:54.930+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 12438ms conn=a62445aa…18bc id=f4886d95…eeac [39m
[90m2026-05-17T16:56:54.940+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=18080 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=3ea673cf-6777-44bb-a01a-f2f125df1121 endpoint=127.0.0.1:41674->127.0.0.1:18789 conn=568aff0e…0282 [39m
[90m2026-05-17T16:56:54.948+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=18166 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=f4886d95-995e-4c23-8c5b-547ebc18eeac endpoint=127.0.0.1:41660->127.0.0.1:18789 conn=a62445aa…18bc [39m
[90m2026-05-17T16:57:04.298+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49214 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49214->127.0.0.1:18789 conn=87ec5025…771c [39m
[90m2026-05-17T16:57:04.328+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49220 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49220->127.0.0.1:18789 conn=f326a0e6…9cd6 [39m
[90m2026-05-17T16:57:04.413+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=87ec5025…771c [39m
[90m2026-05-17T16:57:04.420+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:57:09.459+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=27 [39m
[90m2026-05-17T16:57:09.465+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-17T16:57:09.484+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=f326a0e6…9cd6 [39m
[90m2026-05-17T16:57:09.489+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-17T16:57:14.661+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=1 healthVersion=28 [39m









======================================================================



Node logs in full. Do not when Gateway starts it takes over 4 mins whilst just showing auth token acquired before it actually started any logs after. Device is disabled, I had to manually enable it after I saw logs start to move in the Gateway logs or just before::::







  🦞 LOBSTER-24f0...8646
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 35706
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 37366
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 35482
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 44108
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
[NODE] Disconnected, will retry in 5s...
[NODE] Pairing required (1008) — approving request 6ddf09f7-dbe7-49ea-bcee-f1b314d52f94 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Plain CLI approval failed; retrying with explicit gateway URL/token. Error: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayTransportError: gateway timeout after 10000ms
Gateway target: ws://127.0.0.1:18789
Source: local loopback
Config: /root/.openclaw/openclaw.json
Bind: loopback
    at createGatewayTimeoutTransportError (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:249:9)
    at Timeout.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:333:9)
    at listOnTimeout (node:internal/timers:588:17)
    at process.processTimers (node:internal/timers:523:7)
, null, null)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing approval failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): gateway connect failed: GatewayClientRequestError: scope upgrade pending approval (requestId: 9ed0ba4c-cab8-432a-a678-114afaade640)
[openclaw] Failed to start CLI: GatewayTransportError: gateway closed (1008): pairing required: device is asking for more scopes than currently approved (requestId: 9ed0ba4c-cab8-432a-a678-114afaade
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
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected, will retry in 5s...
[NODE] Pairing required (1008) — approving request aba4b7f1-e68b-4630-a828-a6ec1fe74c25 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Plain CLI approval failed; retrying with explicit gateway URL/token. Error: PlatformException(PROOT_ERROR, Command failed (exit code 1): gateway connect failed: GatewayClientRequestError: scope upgrade pending approval (requestId: 3e3f5e13-7f1a-490f-889f-098a00634964)
[openclaw] Failed to start CLI: Error: invalid scope for requested roles: agent
    at approvePairingWithFallback (file:///usr/local/lib/node_modules/openclaw/dist/devices-cli-4iFIdM7C.js:153:46)
    at async Command.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/devices-cli-4iFIdM7C.js:519:18)
    at async Command.parseAsync (/usr/local/lib/node_modules/openclaw/node_modules/commander/lib/command.js:1122:5)
    at async Object.measure (file:///usr/local/lib/node_modules/openclaw/dist/cli/run-main.js:109:12)
    at async runCli (file:///usr/local/lib/node_modules/openclaw/dist/cli/run-main.js:457:5)
    at async runMainOrRootHelp (file:///usr/local/lib/node_modules/openclaw/dist/entry.js:411:3)
    at async file:///usr/local/lib/node_modules/openclaw/dist/entry.js:381:55
, null, null)
[NODE] Pairing approval failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): gateway connect failed: GatewayClientRequestError: scope upgrade pending approval (requestId: 3e3f5e13-7f1a-490f-889f-098a00634964)
[openclaw] Failed to start CLI: GatewayTransportError: gateway closed (1008): pairing required: device is asking for more scopes than currently approved (requestId: 3e3f5e13-7f1a-490f-889f-098a00634
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
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected, will retry in 5s...
[NODE] Pairing required (1008) — approving request 803688e4-7937-44c2-9db8-340ef624ffa2 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
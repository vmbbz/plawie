Breakthrough Gateway handshake
Inbox
Cosy <cosychiruka@gmail.com>
	
11:34 PM (3 minutes ago)
	
	
to me
[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-18T21:13:09.331+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[90m2026-05-18T21:13:10.293+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-18T21:13:10.382+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-18T21:13:49.147+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[WARN] WebSocket disconnected
[90m2026-05-18T21:13:49.384+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T21:13:51.744+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-18T21:13:51.866+00:00 [39m [35m[plugins] [39m [90mloading canvas from /usr/local/lib/node_modules/openclaw/dist/extensions/canvas/index.js [39m
[90m2026-05-18T21:13:52.322+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
2026-05-18T21:13:52.353+00:00 Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-18T21:13:52.383+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-18T21:13:52.479+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-18T21:13:52.821+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-18T21:13:52.839+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
2026-05-18T21:13:52.887+00:00 Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-18T21:13:52.948+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
2026-05-18T21:13:53.055+00:00 Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-18T21:13:53.064+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1335.3ms [39m
[90m2026-05-18T21:13:53.103+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T21:13:53.112+00:00 [39m [36m[gateway] [39m [36mhttp server listening (7 plugins: browser, canvas, device-pair, file-transfer, memory-core, phone-control, talk-voice; 42.7s) [39m
[90m2026-05-18T21:13:53.119+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T21:13:53.831+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-18T21:13:57.447+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-18T21:13:57.736+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T21:13:57.816+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-18T21:13:58.113+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-18T21:13:59.166+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-18T21:14:27.607+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37830 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37830->127.0.0.1:18789 conn=b1e5b5be…5b57 [39m
[90m2026-05-18T21:14:27.991+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37840 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37840->127.0.0.1:18789 conn=2fdded55…b406 [39m
[90m2026-05-18T21:14:29.452+00:00 [39m [36m[ws] [39m [36m← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.12 mode=node clientId=node-host platform=android auth=token [39m
[90m2026-05-18T21:14:29.476+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=26 presence=2 stateVersion=2 [39m
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[90m2026-05-18T21:14:30.787+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=3 [39m
[90m2026-05-18T21:14:30.800+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:14:30.875+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=2026.5.12 mode=ui clientId=openclaw-control-ui platform=android auth=token conn=b1e5b5be…5b57 [39m
[90m2026-05-18T21:14:30.888+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=26 presence=3 stateVersion=3 [39m
[90m2026-05-18T21:14:32.252+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=4 [39m
[INFO] Health RPC: ok=true
[90m2026-05-18T21:14:34.256+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 1989ms cached=true id=7d0d6c11…0288 [39m
[90m2026-05-18T21:14:35.598+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=5 [39m
[INFO] Active skills: 1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli, browser-automation, camsnap, clawhub, coding-agent, discord, eightctl, gemini, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya, imsg, mcporter, model-usage, nano-pdf, node-connect, notion, obsidian, openai-whisper, openai-whisper-api, openhue, oracle, ordercli, peekaboo, sag, session-logs, sherpa-onnx-tts, skill-creator, slack, songsee, sonoscli, spotify-player, summarize, taskflow, taskflow-inbox-triage, things-mac, tmux, trello, video-frames, voice-call, wacli, weather, xurl
[90m2026-05-18T21:14:36.554+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ skills.status 937ms id=44a7e608…1d2c [39m
[90m2026-05-18T21:14:43.954+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=26.6 eventLoopDelayMaxMs=3347.1 eventLoopUtilization=0.293 cpuCoreRatio=0.213 active=0 waiting=0 queued=0 recentPhases=sidecars.main-session-recovery:21ms,sidecars.restart-sentinel:124ms,sidecars.session-locks:157ms,post-attach.update-sentinel:37ms,sidecars.model-prewarm:5334ms,post-ready.maintenance:455ms [39m
[90m2026-05-18T21:14:43.965+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:15:01.503+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=6 [39m
[90m2026-05-18T21:15:01.520+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:15:13.944+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:15:31.569+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:15:43.954+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:16:01.584+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=7 [39m
[90m2026-05-18T21:16:01.610+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:16:13.957+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:16:31.683+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:16:43.958+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:17:08.501+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=8 [39m
[90m2026-05-18T21:17:08.554+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:17:13.954+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=32.2 eventLoopDelayMaxMs=8682.2 eventLoopUtilization=0.373 cpuCoreRatio=0.172 active=0 waiting=0 queued=0 recentPhases=sidecars.main-session-recovery:21ms,sidecars.restart-sentinel:124ms,sidecars.session-locks:157ms,post-attach.update-sentinel:37ms,sidecars.model-prewarm:5334ms,post-ready.maintenance:455ms [39m
[90m2026-05-18T21:17:13.979+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:17:38.573+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:17:43.958+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:18:02.820+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=9 [39m
[90m2026-05-18T21:18:08.537+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:18:13.953+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:18:17.028+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ agents.list 48ms id=180fd16c…602b [39m
[90m2026-05-18T21:18:38.570+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:18:43.955+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:19:01.605+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=10 [39m
[90m2026-05-18T21:19:08.570+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:19:13.967+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.1 eventLoopDelayMaxMs=1772.1 eventLoopUtilization=0.138 cpuCoreRatio=0.069 active=0 waiting=0 queued=0 recentPhases=sidecars.main-session-recovery:21ms,sidecars.restart-sentinel:124ms,sidecars.session-locks:157ms,post-attach.update-sentinel:37ms,sidecars.model-prewarm:5334ms,post-ready.maintenance:455ms [39m
[90m2026-05-18T21:19:13.979+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:19:38.538+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:19:43.958+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:20:02.471+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=3 healthVersion=11 [39m
[90m2026-05-18T21:20:08.581+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:20:13.958+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:20:38.571+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-18T21:20:43.953+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:20:52.034+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46440 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46440->127.0.0.1:18789 conn=960fa02d…f36a [39m
[90m2026-05-18T21:20:52.153+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=eda3ce7f7d0ed0393f061fe919e336ba10a7ae9042cb1c12dd434563cf4d06c9 role=operator [39m
[90m2026-05-18T21:20:52.161+00:00 [39m [36m[ws] [39m [36m→ event device.pair.resolved seq=per-client clients=2 dropIfSlow=true [39m
[90m2026-05-18T21:20:52.178+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=2026.5.12 mode=webchat clientId=openclaw-control-ui platform=Linux aarch64 auth=token [39m
[90m2026-05-18T21:20:52.187+00:00 [39m [36m[ws] [39m [36mwebchat connected conn=960fa02d-c981-4b1b-bceb-e12c9ecdf36a remote=127.0.0.1 client=openclaw-control-ui webchat v2026.5.12 [39m
[90m2026-05-18T21:20:52.210+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=26 presence=2 stateVersion=4 [39m
[90m2026-05-18T21:20:53.555+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=3 presenceVersion=4 healthVersion=12 [39m
[90m2026-05-18T21:20:53.572+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ sessions.subscribe 4ms id=1963843c…332f [39m
[90m2026-05-18T21:20:53.584+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ agent.identity.get 16ms id=3b4b997a…50f3 [39m
[90m2026-05-18T21:20:53.980+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 410ms cached=true id=b949565f…648f [39m
[90m2026-05-18T21:20:54.381+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ agents.list 808ms id=816310b0…1395 [39m
[90m2026-05-18T21:20:56.200+00:00 [39m [36m[skills] [39m [90mSanitized skill command name "node-connect" to "/node_connect". [39m
[90m2026-05-18T21:20:56.203+00:00 [39m [36m[skills] [39m [90mSanitized skill command name "skill-creator" to "/skill_creator". [39m
[90m2026-05-18T21:20:56.205+00:00 [39m [36m[skills] [39m [90mSanitized skill command name "taskflow-inbox-triage" to "/taskflow_inbox_triage". [39m
[90m2026-05-18T21:20:56.894+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ commands.list 1529ms id=58be0e83…2785 [39m
[90m2026-05-18T21:20:56.910+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ chat.history 1550ms id=7bd1e77a…e357 [39m
[90m2026-05-18T21:20:56.949+00:00 [39m [36m[gateway] [39m [90msessions.list continuing without model catalog after 750ms [39m
[90m2026-05-18T21:20:56.978+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ sessions.list 1612ms id=2b829d12…1252 [39m
[90m2026-05-18T21:20:56.980+00:00 [39m [36m[gateway] [39m [90mmodels.list continuing without model catalog after 750ms [39m
[90m2026-05-18T21:20:56.998+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ models.list 1634ms id=61cb0c5d…d8bf [39m
[90m2026-05-18T21:21:01.327+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=3 presenceVersion=4 healthVersion=13 [39m
[90m2026-05-18T21:21:40.896+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-18T21:21:41.101+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-18T21:21:41.229+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T21:21:41.319+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T21:21:41.451+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T21:21:41.511+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-18T21:21:41.630+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-18T21:21:41.953+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1067.2ms [39m
[90m2026-05-18T21:21:55.447+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-18T21:21:55.452+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 17.8ms [39m
[90m2026-05-18T21:22:20.098+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-18T21:22:20.107+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 18.0ms [39m
[90m2026-05-18T21:22:40.308+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-18T21:22:40.313+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 12.4ms [39m
[90m2026-05-18T21:23:00.625+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-18T21:23:00.629+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.1ms [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T21:23:18.410+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-18T21:23:19.438+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-18T21:23:19.532+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T21:23:52.235+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-18T21:23:52.455+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-18T21:23:54.590+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-18T21:23:54.674+00:00 [39m [35m[plugins] [39m [90mloading canvas from /usr/local/lib/node_modules/openclaw/dist/extensions/canvas/index.js [39m
[90m2026-05-18T21:23:55.163+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
2026-05-18T21:23:55.189+00:00 Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-18T21:23:55.213+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-18T21:23:55.305+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-18T21:23:55.686+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-18T21:23:55.704+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
2026-05-18T21:23:55.731+00:00 Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-18T21:23:55.748+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
2026-05-18T21:23:55.787+00:00 Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-18T21:23:55.797+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1219.6ms [39m
[90m2026-05-18T21:23:55.839+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-18T21:23:55.847+00:00 [39m [36m[gateway] [39m [36mhttp server listening (7 plugins: browser, canvas, device-pair, file-transfer, memory-core, phone-control, talk-voice; 36.3s) [39m
[90m2026-05-18T21:23:55.856+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-18.log [39m
[90m2026-05-18T21:23:56.750+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-18T21:23:58.975+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-18T21:23:59.265+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49142 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49142->127.0.0.1:18789 conn=ac17f27a…3966 [39m
[90m2026-05-18T21:23:59.380+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-18T21:23:59.408+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-18T21:23:59.606+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[90m2026-05-18T21:24:00.493+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=2026.5.12 mode=ui clientId=openclaw-control-ui platform=android auth=token [39m
[90m2026-05-18T21:24:00.507+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=26 presence=2 stateVersion=2 [39m
[90m2026-05-18T21:24:04.682+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=3 [39m
[INFO] Health RPC: ok=true
[90m2026-05-18T21:24:06.853+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 1868ms cached=true id=6a0041a4…0095 [39m
[90m2026-05-18T21:24:08.207+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=4 [39m
[INFO] Active skills: 1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli, browser-automation, camsnap, clawhub, coding-agent, discord, eightctl, gemini, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya, imsg, mcporter, model-usage, nano-pdf, node-connect, notion, obsidian, openai-whisper, openai-whisper-api, openhue, oracle, ordercli, peekaboo, sag, session-logs, sherpa-onnx-tts, skill-creator, slack, songsee, sonoscli, spotify-player, summarize, taskflow, taskflow-inbox-triage, things-mac, tmux, trello, video-frames, voice-call, wacli, weather, xurl
[90m2026-05-18T21:24:09.265+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ skills.status 1004ms id=6ebcc810…246f [39m
[90m2026-05-18T21:24:33.034+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:25:03.025+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:25:06.120+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=5 [39m
[90m2026-05-18T21:25:18.010+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=24 eventLoopDelayMaxMs=3164.6 eventLoopUtilization=0.173 cpuCoreRatio=0.123 active=0 waiting=0 queued=0 recentPhases=sidecars.main-session-recovery:19ms,sidecars.restart-sentinel:115ms,sidecars.session-locks:137ms,post-attach.update-sentinel:50ms,sidecars.model-prewarm:3652ms,post-ready.maintenance:714ms [39m
[90m2026-05-18T21:25:18.022+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:25:33.027+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:25:48.009+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:26:03.009+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:26:04.809+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=6 [39m
[90m2026-05-18T21:26:18.013+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:26:33.022+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:26:48.011+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:27:03.020+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:27:06.637+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=7 [39m
[90m2026-05-18T21:27:18.009+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.6 eventLoopDelayMaxMs=3619.7 eventLoopUtilization=0.184 cpuCoreRatio=0.116 active=0 waiting=0 queued=0 recentPhases=sidecars.main-session-recovery:19ms,sidecars.restart-sentinel:115ms,sidecars.session-locks:137ms,post-attach.update-sentinel:50ms,sidecars.model-prewarm:3652ms,post-ready.maintenance:714ms [39m
[90m2026-05-18T21:27:18.014+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:27:32.981+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:27:48.012+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:28:03.022+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:28:04.739+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=8 [39m
[90m2026-05-18T21:28:18.018+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:28:33.104+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:28:48.020+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:29:03.046+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:29:09.986+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=9 [39m
[90m2026-05-18T21:29:18.037+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.9 eventLoopDelayMaxMs=6941.6 eventLoopUtilization=0.4 cpuCoreRatio=0.213 active=0 waiting=0 queued=0 recentPhases=sidecars.main-session-recovery:19ms,sidecars.restart-sentinel:115ms,sidecars.session-locks:137ms,post-attach.update-sentinel:50ms,sidecars.model-prewarm:3652ms,post-ready.maintenance:714ms [39m
[90m2026-05-18T21:29:18.054+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:29:32.990+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:29:48.027+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:30:03.053+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:30:10.950+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=10 [39m
[90m2026-05-18T21:30:18.028+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:30:33.029+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:30:48.020+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-18T21:31:03.021+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-18T21:31:05.467+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=11 [39m
[90m2026-05-18T21:31:18.029+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.5 eventLoopDelayMaxMs=2401.2 eventLoopUtilization=0.133 cpuCoreRatio=0.077 active=0 waiting=0 queued=0 recentPhases=sidecars.main-session-recovery:19ms,sidecars.restart-sentinel:115ms,sidecars.session-locks:137ms,post-attach.update-sentinel:50ms,sidecars.model-prewarm:3652ms,post-ready.maintenance:714ms [39m
[90m2026-05-18T21:31:18.039+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m






=====================================================================



Node Device Logs in full. It connected for about 5 mins stable fully connected. Then i saw it disconnect, and Gateway restrted again (NOT SURE WHAT HAPPENES THERE IS THIS OUR INTENDED DESIGN OR WE ARE STILL HAMMERING OUT ISSUES?)


FULL LOGS BELOW:



  🦞 LOBSTER-8372...7b07
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Using cached node device token: BSd4-_8F...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=true payload={type: hello-ok, protocol: 4, server: {version: 2026.5.12, connId: 2fdded55-ee3e-4df5-849a-d3bafcbdb406}, features: {methods: [health, diagnostics.stability, doctor.memory.status, doctor.memory.dreamDiary, doctor.memory.backfillDreamDiary, doctor.memory.resetDreamDiary, doctor.memory.resetGroundedShortTerm, doctor.memory.repairDreamingArtifacts, doctor.memory.dedupeDreamDiary, doctor.memory.remHarness, logs.tail, channels.status, channels.start, channels.stop, channels.logout, status, usage.status, usage.cost, tts.status, tts.providers, tts.personas, tts.enable, tts.disable, tts.convert, tts.setProvider, tts.setPersona, config.get, config.set, config.apply, config.patch, config.schema, config.schema.lookup, exec.approvals.get, exec.approvals.set, exec.approvals.node.get, exec.approvals.node.set, exec.approval.get, exec.approval.list, exec.approval.request, exec.approval.waitDecision, exec.approval.resolve, plugin.approval.list, plugin.approval.request, plugin.approval.waitDecision, plugin.approval.resolve, plugins.uiDescriptors, plugins.sessionAction, wizard.start, wizard.next, wizard.cancel, wizard.status, talk.catalog, talk.config, talk.client.create, talk.client.toolCall, talk.session.create, talk.session.join, talk.session.appendAudio, talk.session.startTurn, talk.session.endTurn, talk.session.cancelTurn, talk.session.cancelOutput, talk.session.submitToolResult, talk.session.close, talk.speak, talk.mode, commands.list, models.list, models.authStatus, tools.catalog, tools.effective, tools.invoke, tasks.list, tasks.get, tasks.cancel, environments.list, environments.status, agents.list, agents.create, agents.update, agents.delete, agents.files.list, agents.files.get, agents.files.set, artifacts.list, artifacts.get, artifacts.download, skills.status, skills.search, skills.detail, skills.bins, skills.upload.begin, skills.upload.chunk, skills.upload.commit, skills.install, skills.update, update.status, update.run, voicewake.get, voicewake.set, secrets.reload, secrets.resolve, voicewake.routing.get, voicewake.routing.set, sessions.list, sessions.subscribe, sessions.unsubscribe, sessions.messages.subscribe, sessions.messages.unsubscribe, sessions.preview, sessions.describe, sessions.compaction.list, sessions.compaction.get, sessions.compaction.branch, sessions.compaction.restore, sessions.create, sessions.send, sessions.abort, sessions.patch, sessions.pluginPatch, sessions.cleanup, sessions.reset, sessions.delete, sessions.compact, last-heartbeat, set-heartbeats, wake, node.pair.request, node.pair.list, node.pair.approve, node.pair.reject, node.pair.remove, node.pair.verify, device.pair.list, device.pair.approve, device.pair.reject, device.pair.remove, device.token.rotate, device.token.revoke, node.rename, node.list, node.describe, node.pluginSurface.refresh, node.pending.drain, node.pending.enqueue, node.invoke, node.pending.pull, node.pending.ack, node.invoke.result, node.event, cron.get, cron.list, cron.status, cron.add, cron.update, cron.remove, cron.run, cron.runs, gateway.identity.get, gateway.restart.preflight, gateway.restart.request, system-presence, system-event, message.action, send, agent, agent.identity.get, agent.wait, chat.history, chat.abort, chat.send, browser.request], events: [connect.challenge, agent, chat, session.message, session.tool, sessions.changed, presence, tick, talk.mode, talk.event, shutdown, health, heartbeat, cron, node.pair.requested, node.pair.resolved, node.invoke.request, device.pair.requested, device.pair.resolved, voicewake.changed, voicewake.routing.changed, exec.approval.requested, exec.approval.resolved, plugin.approval.requested, plugin.approval.resolved, update.available]}, snapshot: {presence: [{host: localhost, ip: 192.168.1.100, version: 2026.5.12, platform: linux 6.17.0-PRoot-Distro, deviceFamily: Linux, modelIdentifier: arm64, mode: gateway, reason: self, text: Gateway: localhost (192.168.1.100) · app 2026.5.12 · mode gateway · reason self, ts: 1779138869457}, {host: OpenClaw Mobile, version: 2026.5.12, platform: android, deviceFamily: Android, mode: node, deviceId: 8372a73d004c25d98262bdecdb362291c8f59baae2e127d757c9f4e69f5f7b07, roles: [node], scopes: [node.device], instanceId: 8372a73d004c25d98262bdecdb362291c8f59baae2e127d757c9f4e69f5f7b07, reason: connect, ts: 1779138869454, text: Node: OpenClaw Mobile · mode node}], health: {ok: true, ts: 1779138842209, durationMs: 1911, eventLoop: {degraded: true, reasons: [event_loop_utilization], intervalMs: 11265, delayP99Ms: 984.6, delayMaxMs: 984.6, utilization: 0.996, cpuCoreRatio: 0.552}, plugins: {loaded: [browser, canvas, device-pair, file-transfer, memory-core, phone-control, talk-voice], errors: []}, modelPricing: {state: ok, sources: []}, channels: {}, channelOrder: [], channelLabels: {}, heartbeatSeconds: 1800, defaultAgentId: main, agents: [{agentId: main, isDefault: true, heartbeat: {enabled: true, every: 30m, everyMs: 1800000, prompt: Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK., target: none, ackMaxChars: 300}, sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1779137466892, age: 1373406}]}}], sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1779137466892, age: 1373406}]}}, stateVersion: {presence: 2, health: 2}, uptimeMs: 85708, sessionDefaults: {defaultAgentId: main, mainKey: main, mainSessionKey: agent:main:main, scope: per-sender}}, pluginSurfaceUrls: {canvas: http://127.0.0.1:18789/__openclaw__/cap/WH3CaxAkSIhf8Jd_nDQ71MMB}, auth: {role: node, scopes: [node.device], deviceToken: BSd4-_8Ffs7z67vvqMZv3-feKCX-Vo_xHaKyFJFVphM, issuedAtMs: 1779138095984}, policy: {maxPayload: 26214400, maxBufferedBytes: 52428800, tickIntervalMs: 30000}} error=null
[NODE] Paired and connected
[NODE] Disconnected
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: HttpException: Connection reset by peer, uri = http://127.0.0.1:18789
Claude you missed the mark
Inbox
Cosy <cosychiruka@gmail.com>
	
Attachments2:01 AM (1 hour ago)
	
	
to me
[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[WARN] Dashboard probe failed to find token. Ensure openclaw is starting correctly.
[90m2026-05-14T23:56:43.612+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-14T23:56:44.247+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-14T23:56:44.308+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
Config overwrite: /root/.openclaw/openclaw.json (sha256 2d5d7528e9bad59dd49cbd6b42434ab7e67f1024e47a0f3735c1067e8c84e3dd -> fdd697f88cca1e6a5fa7f95f56af373861e07825f92038613bc153e49497525f, backup=/root/.openclaw/openclaw.json.bak)
[90m2026-05-14T23:56:59.380+00:00 [39m [36m[gateway] [39m [36mauth token was missing. Generated a new token and saved it to config (gateway.auth.token). [39m
[90m2026-05-14T23:57:05.065+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-14T23:57:06.178+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-14T23:57:06.470+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-14T23:57:08.700+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-14T23:57:08.713+00:00 [39m [36m[gateway] [39m [36mhttp server listening (0 plugins, 24.4s) [39m
[90m2026-05-14T23:57:08.722+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-14.log [39m
[90m2026-05-14T23:57:09.366+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-14T23:57:09.488+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-14T23:57:09.508+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-14T23:57:17.259+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-14T23:57:26.859+00:00 [39m [36m[gateway] [39m [36mupdate available (latest): v2026.5.12 (current v2026.5.4). Run: openclaw update [39m
[INFO] Gateway is healthy
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:27.682+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44350 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44350->127.0.0.1:18789 conn=bf0cc47e…66cc [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:29.443+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=30s eventLoopDelayP99Ms=5033.2 eventLoopDelayMaxMs=7713.3 eventLoopUtilization=0.997 cpuCoreRatio=0.57 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:2ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:259ms,sidecars.session-locks:294ms,sidecars.main-session-recovery:1363ms,sidecars.model-prewarm:7889ms [39m
[90m2026-05-14T23:57:29.446+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T23:57:29.592+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bf0cc47e-a2f5-47db-b728-f888620b66cc peer=127.0.0.1:44350->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:57:29.602+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=1893 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b923a79b-e2de-45da-99aa-3f2521edf84c endpoint=127.0.0.1:44350->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:32.202+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34012 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34012->127.0.0.1:18789 conn=0dea1c6b…7d38 [39m
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:38.014+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0dea1c6b-294c-40b9-b751-4b01668e7d38 peer=127.0.0.1:34012->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: f6f1c931-1371-4bfe-8241-f58a20562e97) [39m
[90m2026-05-14T23:57:38.024+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: f6f1c931-1371-4bfe-8241-f58a20562e97) durationMs=5793 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=09e7a87a-eafd-41c4-b040-b39d41f11ad2 endpoint=127.0.0.1:34012->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:41.079+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35022 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35022->127.0.0.1:18789 conn=1130eaad…1b24 [39m
[90m2026-05-14T23:57:41.306+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1130eaad-a512-466c-ab92-88355d461b24 peer=127.0.0.1:35022->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:57:41.315+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=204 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b284c1a9-7ef5-494a-a5ae-72fb89de3431 endpoint=127.0.0.1:35022->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:47.092+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35028 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35028->127.0.0.1:18789 conn=0e872359…1324 [39m
[90m2026-05-14T23:57:47.351+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0e872359-fc92-446f-aa78-97b800851324 peer=127.0.0.1:35028->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:57:47.362+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=238 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=073aff17-e4eb-41d6-9498-75e663086bdd endpoint=127.0.0.1:35028->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:56.062+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60388 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60388->127.0.0.1:18789 conn=d5e92623…fce8 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:57:56.262+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d5e92623-0ea2-45e7-9477-0f61de2dfce8 peer=127.0.0.1:60388->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:57:56.274+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=180 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3a1bbf17-fdd9-49cf-a81c-3b67a0678f5c endpoint=127.0.0.1:60388->127.0.0.1:18789 [39m
[90m2026-05-14T23:57:59.462+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T23:58:11.035+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37166 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37166->127.0.0.1:18789 conn=a0ba6b77…cdc7 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:58:11.180+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a0ba6b77-33b6-42d0-8be4-6679f3d5cdc7 peer=127.0.0.1:37166->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:58:11.195+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=124 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ccf616ca-5197-4cb1-9ee9-22ae5f77b795 endpoint=127.0.0.1:37166->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T23:58:26.027+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53646 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53646->127.0.0.1:18789 conn=61156fa0…0a73 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:58:26.192+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=61156fa0-bc6d-4719-9eed-cef3f5e10a73 peer=127.0.0.1:53646->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:58:26.216+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=163 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2d103e44-f4ad-4860-840a-314452c5c39a endpoint=127.0.0.1:53646->127.0.0.1:18789 [39m
[90m2026-05-14T23:58:29.446+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T23:58:29.474+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34432 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34432->127.0.0.1:18789 conn=24ee618b…38f8 [39m
[90m2026-05-14T23:58:29.610+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=24ee618b-6679-4a2c-b866-8917f42338f8 peer=127.0.0.1:34432->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 713707c2-c276-4fe2-8d71-1fa8c2374af4) [39m
[90m2026-05-14T23:58:29.618+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 713707c2-c276-4fe2-8d71-1fa8c2374af4) durationMs=126 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b87e7fa8-3abc-40f4-ad83-69676a7b6e5a endpoint=127.0.0.1:34432->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T23:58:41.055+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40880 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40880->127.0.0.1:18789 conn=80a11a2e…7892 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:58:41.189+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=80a11a2e-3f01-434c-991e-7e5b365e7892 peer=127.0.0.1:40880->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:58:41.199+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=136 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7bad2790-702f-431f-914d-fa950afe15e9 endpoint=127.0.0.1:40880->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:58:56.045+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33548 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33548->127.0.0.1:18789 conn=80601622…8cac [39m
[90m2026-05-14T23:58:56.125+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=80601622-6fba-4f65-9ce1-0b816f968cac peer=127.0.0.1:33548->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:58:56.134+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=82 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9af0265f-9086-4b59-97b9-70fa39065f48 endpoint=127.0.0.1:33548->127.0.0.1:18789 [39m
[90m2026-05-14T23:58:59.077+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39156 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39156->127.0.0.1:18789 conn=623bbebb…d99d [39m
[90m2026-05-14T23:58:59.210+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=623bbebb-65f5-4540-8bb2-5ff6e86cd99d peer=127.0.0.1:39156->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 14c613d9-05b6-42a9-a95e-de29a31123ae) [39m
[90m2026-05-14T23:58:59.223+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 14c613d9-05b6-42a9-a95e-de29a31123ae) durationMs=127 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=07eb579c-8888-4083-b6da-65f192e88d4c endpoint=127.0.0.1:39156->127.0.0.1:18789 [39m
[90m2026-05-14T23:58:59.463+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:59:11.019+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37364 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37364->127.0.0.1:18789 conn=c6d5ff55…618b [39m
[90m2026-05-14T23:59:11.102+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c6d5ff55-88b6-4312-a907-a33cc2ea618b peer=127.0.0.1:37364->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:59:11.111+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=83 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=112fea56-eb99-49f4-ba00-38909fb4388a endpoint=127.0.0.1:37364->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:59:26.058+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33322 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33322->127.0.0.1:18789 conn=e890c5b8…2a3a [39m
[90m2026-05-14T23:59:26.195+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e890c5b8-5cda-41d7-b49d-5881b51f2a3a peer=127.0.0.1:33322->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 3e9c8e00-981f-46de-b8e4-c18bf0fb2456) [39m
[90m2026-05-14T23:59:26.207+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 3e9c8e00-981f-46de-b8e4-c18bf0fb2456) durationMs=131 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=aa06b0e4-2c09-45a9-b89f-b7bb878f71f2 endpoint=127.0.0.1:33322->127.0.0.1:18789 [39m
[90m2026-05-14T23:59:29.454+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T23:59:29.956+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53658 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53658->127.0.0.1:18789 conn=1c927df5…64d4 [39m
[90m2026-05-14T23:59:30.055+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1c927df5-e323-4587-861e-b2a67ecc64d4 peer=127.0.0.1:53658->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: eca65473-acf3-420e-b36a-82283b1f6bbb) [39m
[90m2026-05-14T23:59:30.064+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: eca65473-acf3-420e-b36a-82283b1f6bbb) durationMs=101 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=66225343-b3ea-4d14-b2f0-4898f5e86843 endpoint=127.0.0.1:53658->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:59:41.017+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54884 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54884->127.0.0.1:18789 conn=f3218d2e…1cd4 [39m
[90m2026-05-14T23:59:41.122+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f3218d2e-06f4-46ba-941a-e3c4eb5a1cd4 peer=127.0.0.1:54884->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:59:41.132+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=85 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0109d621-db6b-4a3d-b646-ca4dbc90ec8c endpoint=127.0.0.1:54884->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T23:59:56.039+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33552 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33552->127.0.0.1:18789 conn=3bade1b6…ffa8 [39m
[90m2026-05-14T23:59:56.143+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3bade1b6-09d0-4911-b17b-82e90a56ffa8 peer=127.0.0.1:33552->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T23:59:56.154+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=94 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d088a3b0-31a4-4567-bbf9-00616607c68b endpoint=127.0.0.1:33552->127.0.0.1:18789 [39m
[90m2026-05-14T23:59:59.461+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.9 eventLoopDelayMaxMs=7377.8 eventLoopUtilization=0.291 cpuCoreRatio=0.155 active=0 waiting=0 queued=0 recentPhases=post-attach.update-sentinel:1ms,sidecars.subagent-recovery:259ms,sidecars.session-locks:294ms,sidecars.main-session-recovery:1363ms,sidecars.model-prewarm:7889ms,post-ready.maintenance:2151ms [39m
[90m2026-05-14T23:59:59.475+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-15T00:00:00.423+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50018 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50018->127.0.0.1:18789 conn=5fb5558a…9625 [39m
[90m2026-05-15T00:00:00.540+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5fb5558a-507d-4d57-bc68-8d20f05a9625 peer=127.0.0.1:50018->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 5a5714ca-1560-4011-ad8c-10ef6e0cd7c4) [39m
[90m2026-05-15T00:00:00.549+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 5a5714ca-1560-4011-ad8c-10ef6e0cd7c4) durationMs=125 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=8fb1fd80-85c8-412e-b6be-dc92a7c0db4c endpoint=127.0.0.1:50018->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-15T00:00:11.046+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52058 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52058->127.0.0.1:18789 conn=8a192334…7518 [39m
[90m2026-05-15T00:00:11.189+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8a192334-3990-4df9-b864-4660e62e7518 peer=127.0.0.1:52058->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-15T00:00:11.197+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=133 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=59fc9f43-e2b9-4659-88f1-d6c01ed7519e endpoint=127.0.0.1:52058->127.0.0.1:18789 [39m






=====================================================



  🦞 LOBSTER-b214...6136
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — clearing stale device record...
[NODE] Pairing required (1008) — clearing stale device record via filesystem...
[NODE] Disconnected, will retry...
[NODE] Device record cleared — will re-pair on next connect
[NODE] Reloading gateway to flush stale pairing state...
[NODE] Proactive approval sequence completed
[NODE] Cooldown finished. Attempting fresh connection...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — clearing stale device record...
[NODE] Pairing required (1008) — clearing stale device record via filesystem...
[NODE] Disconnected, will retry...
[NODE] Device record cleared — will re-pair on next connect
[NODE] Reloading gateway to flush stale pairing state...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Proactive approval sequence completed
[NODE] Cooldown finished. Attempting fresh connection...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — clearing stale device record...
[NODE] Pairing required (1008) — clearing stale device record via filesystem...
[NODE] Disconnected, will retry...
[NODE] Device record cleared — will re-pair on next connect
[NODE] Reloading gateway to flush stale pairing state...
[NODE] Proactive approval sequence completed
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Cooldown finished. Attempting fresh connection...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — clearing stale device record...
[NODE] Pairing required (1008) — clearing stale device record via filesystem...
[NODE] Disconnected, will retry...
[NODE] Device record cleared — will re-pair on next connect
[NODE] Reloading gateway to flush stale pairing state...
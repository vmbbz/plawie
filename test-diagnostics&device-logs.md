Cosy <cosychiruka@gmail.com>	Wed, May 6, 2026 at 10:35 PM
To: Cosy <cosychiruka@gmail.com>
[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway is healthy
[DEBUG] Probing gateway config for auth token...
[90m2026-05-06T20:26:42.463+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-06T20:26:43.283+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[INFO] Gateway auth token acquired from config.
[90m2026-05-06T20:26:43.332+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-06T20:26:56.476+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-06T20:26:57.223+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[INFO] Gateway auth token acquired from config.
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[90m2026-05-06T20:26:57.443+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-06T20:26:58.844+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-06T20:26:58.914+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-06T20:26:59.159+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-06T20:26:59.214+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-06T20:27:03.387+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-06T20:27:03.421+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-06T20:27:03.455+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 4620.9ms [39m
[90m2026-05-06T20:27:03.488+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49144 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49144->127.0.0.1:18789 conn=287d7ff5…310d [39m
[90m2026-05-06T20:27:03.603+00:00 [39m [36m[gateway] [39m [36magent model: ollama/qwen2.5:0.5b (thinking=medium, fast=off) [39m
[90m2026-05-06T20:27:03.609+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 20.2s) [39m
[90m2026-05-06T20:27:03.615+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-06.log [39m
[90m2026-05-06T20:27:04.298+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-06T20:27:04.373+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=287d7ff5-3c39-4275-87e2-76a67c27310d peer=127.0.0.1:49144->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:27:04.380+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=872 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=75698f2d-68ca-412d-ae96-f460acbf3bb6 endpoint=127.0.0.1:49144->127.0.0.1:18789 [39m
[90m2026-05-06T20:27:45.483+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-06T20:27:45.509+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=53s eventLoopDelayP99Ms=5981.1 eventLoopDelayMaxMs=39090.9 eventLoopUtilization=0.999 cpuCoreRatio=0.463 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:9ms,post-attach.update-check:103ms,sidecars.model-prewarm:41186ms [39m
[90m2026-05-06T20:27:45.519+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:27:45.774+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53062 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53062->127.0.0.1:18789 conn=77771f9c…46dd [39m
[90m2026-05-06T20:27:46.124+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53790 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53790->127.0.0.1:18789 conn=de804cdf…1c46 [39m
[90m2026-05-06T20:27:46.350+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=de804cdf-7b00-420e-a282-758cce121c46 peer=127.0.0.1:53790->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:27:46.359+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=218 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a68c07f4-9526-4f71-96e2-6a0b3c47f72a endpoint=127.0.0.1:53790->127.0.0.1:18789 [39m
[90m2026-05-06T20:27:46.608+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34214 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34214->127.0.0.1:18789 conn=bd1a4601…b5ac [39m
[90m2026-05-06T20:27:46.904+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bd1a4601-0922-4c51-a20b-9a86c8bbb5ac peer=127.0.0.1:34214->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:27:46.912+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=285 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=593d7659-9adc-4af5-abcc-65fe31944aa9 endpoint=127.0.0.1:34214->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[90m2026-05-06T20:27:50.229+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34224 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34224->127.0.0.1:18789 conn=06c66353…0d93 [39m
[90m2026-05-06T20:27:50.301+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-06T20:27:50.335+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=06c66353-f633-49c7-9d91-64d604390d93 peer=127.0.0.1:34224->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:27:50.341+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=99 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=faea85ad-261d-4130-8daf-180025987512 endpoint=127.0.0.1:34224->127.0.0.1:18789 [39m
[90m2026-05-06T20:27:50.373+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-06T20:27:50.391+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-06T20:27:50.488+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-06T20:27:51.888+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34230 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34230->127.0.0.1:18789 conn=ceb384e0…2951 [39m
[90m2026-05-06T20:27:52.179+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ceb384e0-8187-479c-b64b-8f1989f72951 peer=127.0.0.1:34230->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:27:52.186+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=278 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f0a79d4f-be01-494f-9294-e0e8293bd9ab endpoint=127.0.0.1:34230->127.0.0.1:18789 [39m
[90m2026-05-06T20:27:56.984+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57978 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57978->127.0.0.1:18789 conn=28df87f5…f0f8 [39m
[90m2026-05-06T20:28:00.440+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=28df87f5-1d57-4e4f-b9c3-3b0c2137f0f8 peer=127.0.0.1:57978->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:00.451+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=3445 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=99679d2f-863c-498f-81fa-a3c9707d7053 endpoint=127.0.0.1:57978->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:00.794+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=77771f9c-d62a-4c3f-b58c-f02940a946dd peer=127.0.0.1:53062->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-06T20:28:00.836+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=77771f9c-d62a-4c3f-b58c-f02940a946dd peer=127.0.0.1:53062->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-05-06T20:28:00.846+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=15056 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:53062->127.0.0.1:18789 conn=77771f9c…46dd [39m
[90m2026-05-06T20:28:03.394+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57994 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57994->127.0.0.1:18789 conn=03a4c45c…0bcc [39m
[90m2026-05-06T20:28:03.519+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=03a4c45c-2358-42da-b9e7-e2e756b90bcc peer=127.0.0.1:57994->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:03.540+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=92 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=eca38976-e339-471c-ac4e-baa611702491 endpoint=127.0.0.1:57994->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:07.817+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49852 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49852->127.0.0.1:18789 conn=07e47e47…cb0b [39m
[90m2026-05-06T20:28:08.053+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=fb6ea32c26fbc55b04663ca6aa80f5604114eb44e6c4cd62c3464cc7d5aced86 role=operator [39m
[90m2026-05-06T20:28:08.121+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.5 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-06T20:28:08.156+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-06T20:28:23.266+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=3 [39m
[90m2026-05-06T20:28:23.273+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:28:23.281+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-06T20:28:23.297+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=15513 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=7e3716bf-aa76-45bb-b8c5-fee86d6f1cd7 endpoint=127.0.0.1:49852->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:23.310+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49866 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49866->127.0.0.1:18789 conn=7fed3032…0e6a [39m
[90m2026-05-06T20:28:23.365+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7fed3032-1ca2-498d-8666-c6a729170e6a peer=127.0.0.1:49866->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:23.382+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=43 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7b068750-b99e-4a76-b540-d7be713dad40 endpoint=127.0.0.1:49866->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:24.721+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37554 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37554->127.0.0.1:18789 conn=1188f989…e980 [39m
[90m2026-05-06T20:28:24.872+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1188f989-ec22-4ce0-af9d-03cfe3bae980 peer=127.0.0.1:37554->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:24.887+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=94 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=af650d5b-c450-411a-88ba-6ddf61c85046 endpoint=127.0.0.1:37554->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:25.154+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37562 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37562->127.0.0.1:18789 conn=821047bd…3e4d [39m
[90m2026-05-06T20:28:25.254+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=821047bd-7b0c-4d19-a4b5-c1ef10153e4d peer=127.0.0.1:37562->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:25.275+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=60 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=791cae05-f3d7-4567-a591-67fd7413d02c endpoint=127.0.0.1:37562->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:25.841+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37568 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37568->127.0.0.1:18789 conn=c4ee3407…f996 [39m
[90m2026-05-06T20:28:25.977+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c4ee3407-d55c-43c8-ab24-4f2388b8f996 peer=127.0.0.1:37568->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:26.005+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=111 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=00f7956c-6446-4fbc-ab56-663aaff3d392 endpoint=127.0.0.1:37568->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:26.946+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37582 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37582->127.0.0.1:18789 conn=60f0f47d…6cf1 [39m
[90m2026-05-06T20:28:27.037+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=60f0f47d-049f-44ed-9bb1-7002a8636cf1 peer=127.0.0.1:37582->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:27.053+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=64 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=830c4a92-27fe-4db6-bf64-643136d04da9 endpoint=127.0.0.1:37582->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:28.739+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37594 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37594->127.0.0.1:18789 conn=403ba646…18c5 [39m
[90m2026-05-06T20:28:28.865+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=403ba646-6e9d-45f6-a251-7153eb3318c5 peer=127.0.0.1:37594->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:28.889+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=85 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=eea23de3-7112-4de0-8742-3d41db7ce434 endpoint=127.0.0.1:37594->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:31.759+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37598 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37598->127.0.0.1:18789 conn=acaad60c…2d44 [39m
[90m2026-05-06T20:28:31.836+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=acaad60c-06c1-4dbe-b22b-128c67f92d44 peer=127.0.0.1:37598->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:31.848+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=68 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=45d0174c-eb47-47ea-9bec-37a45ba28475 endpoint=127.0.0.1:37598->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:34.005+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46418 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46418->127.0.0.1:18789 conn=42f1449e…6c97 [39m
[90m2026-05-06T20:28:34.081+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.5 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-06T20:28:34.096+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-06T20:28:51.350+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=4 [39m
[90m2026-05-06T20:28:51.379+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=17376 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=610f49ad-817f-4f3a-8284-9cec53f6f1ec endpoint=127.0.0.1:46418->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:51.402+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46424 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46424->127.0.0.1:18789 conn=0468df51…b9cb [39m
[90m2026-05-06T20:28:52.060+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0468df51-8215-4c7f-b581-4aeb6604b9cb peer=127.0.0.1:46424->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:28:52.074+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=632 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d137d1f7-bdec-467c-a522-31e411b58a87 endpoint=127.0.0.1:46424->127.0.0.1:18789 [39m
[90m2026-05-06T20:28:59.058+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:28:59.102+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 7739ms conn=42f1449e…6c97 id=610f49ad…f1ec [39m
[90m2026-05-06T20:29:00.085+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49376 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49376->127.0.0.1:18789 conn=d183616c…891d [39m
[90m2026-05-06T20:29:00.232+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d183616c-5acf-434e-996b-24d64990891d peer=127.0.0.1:49376->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:00.259+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=126 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1b49a18c-9883-4f2e-8bbb-5feeb45859d4 endpoint=127.0.0.1:49376->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:08.210+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46610 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46610->127.0.0.1:18789 conn=f03ddb7e…46e7 [39m
[90m2026-05-06T20:29:08.334+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f03ddb7e-0d9b-4717-a642-9780649d46e7 peer=127.0.0.1:46610->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:08.351+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=97 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=dcf7c8d3-a9b5-4ef3-a419-66f0733fcb00 endpoint=127.0.0.1:46610->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:09.734+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46616 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46616->127.0.0.1:18789 conn=33b853f1…f750 [39m
[90m2026-05-06T20:29:09.845+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=33b853f1-93ce-4cfb-9dfa-d7337466f750 peer=127.0.0.1:46616->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:09.859+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=90 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=974cc9c5-080a-4a52-b5e8-4e1e30c234a9 endpoint=127.0.0.1:46616->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:10.167+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46630 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46630->127.0.0.1:18789 conn=94761fdc…1c6f [39m
[90m2026-05-06T20:29:10.254+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=94761fdc-6d18-4e28-b8ed-e76a512b1c6f peer=127.0.0.1:46630->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:10.264+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=58 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=899fb8b6-1b7e-4996-a3e2-fb92c2c9c617 endpoint=127.0.0.1:46630->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:10.860+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46640 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46640->127.0.0.1:18789 conn=7e8fb535…41dd [39m
[90m2026-05-06T20:29:10.982+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7e8fb535-3173-40c9-8b35-2bb4f0f241dd peer=127.0.0.1:46640->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:10.999+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=106 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=494d4ca0-d1a9-4310-a820-35c5db3651bf endpoint=127.0.0.1:46640->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:11.995+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46654 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46654->127.0.0.1:18789 conn=bab60354…53b3 [39m
[90m2026-05-06T20:29:12.148+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bab60354-d1b9-44de-a3fa-66500c6053b3 peer=127.0.0.1:46654->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:12.162+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=134 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b45965d7-08a0-4794-904b-83ad49f15a67 endpoint=127.0.0.1:46654->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:13.857+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57476 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57476->127.0.0.1:18789 conn=921ea193…c477 [39m
[90m2026-05-06T20:29:13.985+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=921ea193-5af8-4227-896c-b484b160c477 peer=127.0.0.1:57476->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:13.999+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=97 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4d694161-ad73-4d37-9a4d-d35bf7045cc0 endpoint=127.0.0.1:57476->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:16.691+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57492 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57492->127.0.0.1:18789 conn=7ce49171…fbd6 [39m
[90m2026-05-06T20:29:16.804+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7ce49171-fc58-4c8b-bb40-fa9a6712fbd6 peer=127.0.0.1:57492->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:16.814+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=90 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=17936b7e-493b-438a-a131-dadccc137f10 endpoint=127.0.0.1:57492->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:17.083+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57494 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57494->127.0.0.1:18789 conn=8e86f8be…38b7 [39m
[90m2026-05-06T20:29:17.114+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8e86f8be-45b8-4a4e-a64a-57561d3438b7 peer=127.0.0.1:57494->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:17.120+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=17 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=36bc5f5b-27f1-46ce-8c2b-eacb5397558e endpoint=127.0.0.1:57494->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:17.694+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57504 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57504->127.0.0.1:18789 conn=6ea7e9df…3ec9 [39m
[90m2026-05-06T20:29:17.724+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6ea7e9df-7c5d-461e-8e19-fcebe2923ec9 peer=127.0.0.1:57504->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:17.729+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=17 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9846074b-889d-4f12-a674-8aa1002f8f6a endpoint=127.0.0.1:57504->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:18.728+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57512 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57512->127.0.0.1:18789 conn=00809724…3dfb [39m
[90m2026-05-06T20:29:18.760+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=00809724-0045-40bf-ac2f-931714e03dfb peer=127.0.0.1:57512->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:18.766+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=23 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=57aa0db9-6441-41b8-8761-8a28f47ac99e endpoint=127.0.0.1:57512->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:20.479+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57520 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57520->127.0.0.1:18789 conn=5f8aa6da…5873 [39m
[90m2026-05-06T20:29:20.521+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5f8aa6da-02ac-4e50-b693-90da10835873 peer=127.0.0.1:57520->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:20.528+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=32 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d1b198cd-ae03-48e0-b257-2df20b89a443 endpoint=127.0.0.1:57520->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:23.460+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57536 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57536->127.0.0.1:18789 conn=57b76e80…386b [39m
[90m2026-05-06T20:29:23.527+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=57b76e80-6612-4ca6-86b2-e2ef2bb5386b peer=127.0.0.1:57536->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:23.535+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=64 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=07075718-a61f-4ebd-b70e-755652ad834e endpoint=127.0.0.1:57536->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:28.492+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37704 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37704->127.0.0.1:18789 conn=04e156fa…fdaa [39m
[90m2026-05-06T20:29:28.551+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=04e156fa-35f6-49c7-9500-4cb0bb95fdaa peer=127.0.0.1:37704->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:28.560+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=40 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=41b355b5-3c06-4aac-9a1f-9adcb08b1c36 endpoint=127.0.0.1:37704->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:28.986+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37710 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37710->127.0.0.1:18789 conn=71570d68…0129 [39m
[90m2026-05-06T20:29:29.038+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=71570d68-063d-4cea-8a39-6e17c0880129 peer=127.0.0.1:37710->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:29.046+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=40 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=99555b11-e553-4996-861e-10c744bd8d52 endpoint=127.0.0.1:37710->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:29.059+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:29:29.385+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37736 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37736->127.0.0.1:18789 conn=142d0f13…0a11 [39m
[90m2026-05-06T20:29:29.435+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=142d0f13-2160-4e91-9ad9-952f635d0a11 peer=127.0.0.1:37736->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:29.446+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=37 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=deacedee-e4de-4d96-9454-343b209d0cf4 endpoint=127.0.0.1:37736->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:30.029+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37740 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37740->127.0.0.1:18789 conn=20ab6e4c…15e7 [39m
[90m2026-05-06T20:29:30.105+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=20ab6e4c-25f8-42f4-8430-3f35e12415e7 peer=127.0.0.1:37740->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:30.120+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=46 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9a714aec-9d5f-44cb-8ff3-6a620f276b42 endpoint=127.0.0.1:37740->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:31.111+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37746 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37746->127.0.0.1:18789 conn=b6af96fe…5210 [39m
[90m2026-05-06T20:29:31.209+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b6af96fe-2bfa-4042-986f-675bdeb35210 peer=127.0.0.1:37746->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:31.223+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=76 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6971a862-bebe-42b0-bb8c-5957d52c7f57 endpoint=127.0.0.1:37746->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:32.925+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37750 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37750->127.0.0.1:18789 conn=5286e64e…7e9c [39m
[90m2026-05-06T20:29:33.019+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5286e64e-812c-41a7-bac5-aa68a6427e9c peer=127.0.0.1:37750->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:33.030+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=83 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=df6e99c8-4332-4029-80a7-2bcfbfcc85d9 endpoint=127.0.0.1:37750->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:35.943+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36624 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36624->127.0.0.1:18789 conn=7a7c6746…3a63 [39m
[90m2026-05-06T20:29:36.020+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7a7c6746-10a5-443b-8b4f-6e244f463a63 peer=127.0.0.1:36624->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:36.031+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=69 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bb423fac-069e-45d0-a07e-db38ac02131e endpoint=127.0.0.1:36624->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:40.990+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36632 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36632->127.0.0.1:18789 conn=7b29a449…1070 [39m
[90m2026-05-06T20:29:41.083+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7b29a449-79f2-47cd-8f00-2ec48c581070 peer=127.0.0.1:36632->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:41.097+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=64 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=aabbca0c-32ac-47ce-bc61-943dea03f103 endpoint=127.0.0.1:36632->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:49.074+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33076 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33076->127.0.0.1:18789 conn=82bcde3b…73b0 [39m
[90m2026-05-06T20:29:49.177+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=82bcde3b-fc07-4908-a1f6-422d897573b0 peer=127.0.0.1:33076->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:49.185+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=68 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=27406d83-587b-421e-a067-999386ae1a26 endpoint=127.0.0.1:33076->127.0.0.1:18789 [39m
[90m2026-05-06T20:29:59.765+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=31s eventLoopDelayP99Ms=53.2 eventLoopDelayMaxMs=6828.3 eventLoopUtilization=0.303 cpuCoreRatio=0.169 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:78ms,sidecars.session-locks:110ms,sidecars.main-session-recovery:374ms,post-ready.maintenance:4182ms [39m
[90m2026-05-06T20:29:59.768+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:29:59.778+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53442 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53442->127.0.0.1:18789 conn=9bb0b20f…3d4b [39m
[90m2026-05-06T20:29:59.846+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9bb0b20f-dd2a-4fa1-b7e8-ceed8d803d4b peer=127.0.0.1:53442->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:29:59.853+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=51 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c8fb5007-0009-4c38-a6d1-73bb3a1166ce endpoint=127.0.0.1:53442->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:07.877+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53120 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53120->127.0.0.1:18789 conn=36d702bc…ca22 [39m
[90m2026-05-06T20:30:08.008+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=36d702bc-d20f-4132-a6ba-0159601dca22 peer=127.0.0.1:53120->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:08.021+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=100 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2f09113e-74be-498d-a179-97dcddc7f3dd endpoint=127.0.0.1:53120->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:14.009+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48054 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48054->127.0.0.1:18789 conn=596342de…24f0 [39m
[90m2026-05-06T20:30:14.067+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=596342de-6837-426b-b13e-920e678824f0 peer=127.0.0.1:48054->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:14.074+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=66 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=093450ad-a33d-4f31-9d37-9f86fd75d9d9 endpoint=127.0.0.1:48054->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:14.382+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48056 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48056->127.0.0.1:18789 conn=6513b6d6…1786 [39m
[90m2026-05-06T20:30:14.426+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6513b6d6-265f-4ec6-aa35-209e5cb01786 peer=127.0.0.1:48056->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:14.432+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=18 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=19ac7f2c-37c2-4a3f-92c0-ca4ca85a9051 endpoint=127.0.0.1:48056->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:14.993+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48072 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48072->127.0.0.1:18789 conn=8f772cd4…6ad3 [39m
[90m2026-05-06T20:30:15.020+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8f772cd4-27d3-4aed-a514-011186426ad3 peer=127.0.0.1:48072->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:15.026+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=13 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7754f0ee-3470-4180-93af-4b080226be2e endpoint=127.0.0.1:48072->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:16.047+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48082 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48082->127.0.0.1:18789 conn=f4f6a298…f813 [39m
[90m2026-05-06T20:30:16.118+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f4f6a298-7098-49bf-867d-7c3a8813f813 peer=127.0.0.1:48082->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:16.129+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=46 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=806fb9bd-f57c-49f6-9ca8-693b9e86cf9c endpoint=127.0.0.1:48082->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:17.819+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48096 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48096->127.0.0.1:18789 conn=0d9e9b2a…70be [39m
[90m2026-05-06T20:30:17.876+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0d9e9b2a-bfc5-4f19-86e4-2a3f546870be peer=127.0.0.1:48096->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:17.883+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=38 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e958f4bf-f706-4519-b046-305df6515a98 endpoint=127.0.0.1:48096->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:20.798+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48098 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48098->127.0.0.1:18789 conn=45b1f40a…f778 [39m
[90m2026-05-06T20:30:20.903+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=45b1f40a-55a0-4321-81a0-965769a6f778 peer=127.0.0.1:48098->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:20.918+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=69 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c665a9d4-e49e-461c-aeea-e19ddb1d3ffb endpoint=127.0.0.1:48098->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:25.859+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38790 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38790->127.0.0.1:18789 conn=7df0e9bf…3cc5 [39m
[90m2026-05-06T20:30:25.959+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7df0e9bf-7fc2-4042-b4f9-0890c1503cc5 peer=127.0.0.1:38790->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:25.970+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=84 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=51912e91-d272-4fac-b1b4-cec033039e48 endpoint=127.0.0.1:38790->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:29.775+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:30:33.955+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53100 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53100->127.0.0.1:18789 conn=8b753985…ec13 [39m
[90m2026-05-06T20:30:34.057+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8b753985-8dc3-47a9-8a46-d717b35dec13 peer=127.0.0.1:53100->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:34.065+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=78 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bc3573c1-7972-4f0c-87f5-fc8d59fd75cb endpoint=127.0.0.1:53100->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:42.020+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53108 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53108->127.0.0.1:18789 conn=cd00c79f…7ff9 [39m
[90m2026-05-06T20:30:42.085+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=cd00c79f-0f3f-47ea-9600-2220763b7ff9 peer=127.0.0.1:53108->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:42.094+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=41 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c20c678f-9abf-489a-970d-944493272fc4 endpoint=127.0.0.1:53108->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:50.077+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46814 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46814->127.0.0.1:18789 conn=624bfe3f…3e83 [39m
[90m2026-05-06T20:30:50.170+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=624bfe3f-578f-4a85-ad86-bdec96e53e83 peer=127.0.0.1:46814->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:50.184+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=57 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a95dcf14-db09-4b14-af54-adc15ff7626a endpoint=127.0.0.1:46814->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:58.110+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52074 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52074->127.0.0.1:18789 conn=2b2e81a2…101e [39m
[90m2026-05-06T20:30:58.136+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2b2e81a2-eb63-464d-b696-75efeee1101e peer=127.0.0.1:52074->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:58.142+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=15 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c9b067f8-1b05-46f2-a7ff-d95b57d20646 endpoint=127.0.0.1:52074->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:59.059+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52076 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52076->127.0.0.1:18789 conn=3acf83d5…0fc7 [39m
[90m2026-05-06T20:30:59.115+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3acf83d5-17de-4a71-b65c-a788f9fd0fc7 peer=127.0.0.1:52076->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:59.123+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=61 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7fe5668e-78f7-446b-aac0-a593b0b5a197 endpoint=127.0.0.1:52076->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:59.472+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52080 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52080->127.0.0.1:18789 conn=7dd3aa1c…78bf [39m
[90m2026-05-06T20:30:59.550+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7dd3aa1c-8725-4d80-ab3c-304de51078bf peer=127.0.0.1:52080->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:30:59.570+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=50 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=8ff1b0f6-6912-40cb-8aeb-6e2d6b146c04 endpoint=127.0.0.1:52080->127.0.0.1:18789 [39m
[90m2026-05-06T20:30:59.772+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:31:00.122+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52102 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52102->127.0.0.1:18789 conn=a2359740…ce0f [39m
[90m2026-05-06T20:31:00.211+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a2359740-2cac-412d-bb78-4980e5c0ce0f peer=127.0.0.1:52102->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:00.228+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=53 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6a3ff3d5-4f73-44b5-803a-c36a69ad4b64 endpoint=127.0.0.1:52102->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:01.192+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52114 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52114->127.0.0.1:18789 conn=6e27abfc…06cf [39m
[90m2026-05-06T20:31:01.274+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6e27abfc-2ad3-4834-97cb-072c7abc06cf peer=127.0.0.1:52114->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:01.289+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=53 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1b2bd726-463c-42f7-9b26-e5965fbb9190 endpoint=127.0.0.1:52114->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:02.976+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52122 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52122->127.0.0.1:18789 conn=99c085ba…6d69 [39m
[90m2026-05-06T20:31:03.055+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=99c085ba-6b77-49da-bc16-1ec99b0f6d69 peer=127.0.0.1:52122->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:03.077+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=54 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ec760c9b-7363-4852-bd10-9c42895a204a endpoint=127.0.0.1:52122->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:05.965+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43944 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43944->127.0.0.1:18789 conn=e76393b0…284a [39m
[90m2026-05-06T20:31:06.037+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e76393b0-30e3-4f92-8d6a-fe524d59284a peer=127.0.0.1:43944->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:06.052+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=53 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e67049af-6ba5-4a6a-a578-731250278192 endpoint=127.0.0.1:43944->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:10.995+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43956 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43956->127.0.0.1:18789 conn=3a10a7bc…0454 [39m
[90m2026-05-06T20:31:11.072+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3a10a7bc-ca11-4882-9565-fe1a2fdf0454 peer=127.0.0.1:43956->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:11.090+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=61 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=171f8872-b3d8-4d10-b66d-e94af303e7a5 endpoint=127.0.0.1:43956->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:19.065+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34102 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34102->127.0.0.1:18789 conn=3088d7c0…cffe [39m
[90m2026-05-06T20:31:19.134+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3088d7c0-cda2-48f6-afb3-61aec40ccffe peer=127.0.0.1:34102->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:19.145+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=52 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c0aead0a-0928-4843-a9ad-f00ed0908c4e endpoint=127.0.0.1:34102->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:27.140+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42704 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42704->127.0.0.1:18789 conn=548c96d4…06bc [39m
[90m2026-05-06T20:31:27.239+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=548c96d4-c832-459f-ae2a-7f93cf5906bc peer=127.0.0.1:42704->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:27.249+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=73 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4718bfdf-0b64-460b-bf66-5db2cc69c74d endpoint=127.0.0.1:42704->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:29.774+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:31:35.227+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57434 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57434->127.0.0.1:18789 conn=b711c771…f448 [39m
[90m2026-05-06T20:31:35.314+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b711c771-a611-49a8-ab63-29c08204f448 peer=127.0.0.1:57434->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:35.325+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=66 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=02cad0ce-e232-4e72-9db1-ce7509d5a6cb endpoint=127.0.0.1:57434->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:43.291+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57444 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57444->127.0.0.1:18789 conn=8a8a5ed3…f946 [39m
[90m2026-05-06T20:31:43.381+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8a8a5ed3-0d8a-458f-9957-868b92eef946 peer=127.0.0.1:57444->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:43.402+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=46 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9832ba44-d95f-4983-a078-f83a0517302c endpoint=127.0.0.1:57444->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:44.047+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50218 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50218->127.0.0.1:18789 conn=517f0f86…a35a [39m
[90m2026-05-06T20:31:44.126+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=517f0f86-9e1e-4a77-a64b-3ff876c4a35a peer=127.0.0.1:50218->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:44.141+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=49 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=060c4b6d-f7e9-401c-8101-236b2ee52ee2 endpoint=127.0.0.1:50218->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:44.451+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50234 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50234->127.0.0.1:18789 conn=b5113e9c…7a3a [39m
[90m2026-05-06T20:31:44.536+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b5113e9c-2a4a-4430-9b69-469ffca37a3a peer=127.0.0.1:50234->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:44.558+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=54 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=99af24f8-2535-44d2-a45b-728603175fff endpoint=127.0.0.1:50234->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:45.089+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50250 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50250->127.0.0.1:18789 conn=6cd35f3a…fc47 [39m
[90m2026-05-06T20:31:45.143+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6cd35f3a-cfa3-499a-b239-9699307ffc47 peer=127.0.0.1:50250->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:45.152+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=41 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=39031e78-3cd1-481e-aeec-58a1c8e505db endpoint=127.0.0.1:50250->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:46.146+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50258 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50258->127.0.0.1:18789 conn=caa75444…de86 [39m
[90m2026-05-06T20:31:46.211+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=caa75444-8b46-43b4-b083-af24ecebde86 peer=127.0.0.1:50258->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:46.232+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=37 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2f005d2b-6bff-465f-8519-f3949f9934c7 endpoint=127.0.0.1:50258->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:47.904+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50262 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50262->127.0.0.1:18789 conn=79fbc9e7…77c1 [39m
[90m2026-05-06T20:31:47.962+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=79fbc9e7-ba83-4509-917f-933d119777c1 peer=127.0.0.1:50262->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:47.970+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=38 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=63d4d1a5-fe0a-443b-b2bb-1fae063c611c endpoint=127.0.0.1:50262->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:50.885+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50270 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50270->127.0.0.1:18789 conn=03175654…b4d8 [39m
[90m2026-05-06T20:31:50.949+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=03175654-a7a0-471d-8c96-68011520b4d8 peer=127.0.0.1:50270->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:50.957+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=56 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=07a46983-9f5c-4327-bd40-f4174a957244 endpoint=127.0.0.1:50270->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:59.612+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59456 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59456->127.0.0.1:18789 conn=a91ca529…1457 [39m
[90m2026-05-06T20:31:59.637+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a91ca529-0dec-47e7-ba08-454fa57e1457 peer=127.0.0.1:59456->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:31:59.643+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=15 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=212a4082-02c8-40b6-8c8d-40df8648ceda endpoint=127.0.0.1:59456->127.0.0.1:18789 [39m
[90m2026-05-06T20:31:59.768+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=58.1 eventLoopDelayMaxMs=4550.8 eventLoopUtilization=0.286 cpuCoreRatio=0.137 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:78ms,sidecars.session-locks:110ms,sidecars.main-session-recovery:374ms,post-ready.maintenance:4182ms [39m
[90m2026-05-06T20:31:59.769+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:32:07.671+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48802 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48802->127.0.0.1:18789 conn=33cfc48e…bd12 [39m
[90m2026-05-06T20:32:07.772+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=33cfc48e-cff9-432f-bcfd-99ff0908bd12 peer=127.0.0.1:48802->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:07.785+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=72 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7894a906-c731-4882-b3ec-4aabe3777677 endpoint=127.0.0.1:48802->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:15.752+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44798 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44798->127.0.0.1:18789 conn=73da3475…0e3d [39m
[90m2026-05-06T20:32:15.850+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=73da3475-e96e-4d06-b61b-3f2f55ce0e3d peer=127.0.0.1:44798->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:15.866+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=63 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=81b85ff1-aa92-49ff-9d81-2424623d6ba9 endpoint=127.0.0.1:44798->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:23.835+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42812 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42812->127.0.0.1:18789 conn=47259a09…26d0 [39m
[90m2026-05-06T20:32:23.944+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=47259a09-1c20-4b43-af2a-fb3882b826d0 peer=127.0.0.1:42812->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:23.961+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=75 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=95f399d6-e42e-415f-b6d4-64f5b11a1f99 endpoint=127.0.0.1:42812->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:29.069+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42818 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42818->127.0.0.1:18789 conn=4a34ec10…1d5b [39m
[90m2026-05-06T20:32:29.170+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=4a34ec10-407a-4332-9ffd-a1213c3c1d5b peer=127.0.0.1:42818->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:29.186+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=66 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=53800ccb-8377-4416-9e4c-95e17a4cd1ef endpoint=127.0.0.1:42818->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:29.485+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42828 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42828->127.0.0.1:18789 conn=f12ab19b…352c [39m
[90m2026-05-06T20:32:29.530+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f12ab19b-d503-4d57-a2c8-a1b9b01a352c peer=127.0.0.1:42828->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:29.536+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=44 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2fe37c29-60f4-4bd5-b599-c79ac0958180 endpoint=127.0.0.1:42828->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:29.767+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:32:30.110+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42840 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42840->127.0.0.1:18789 conn=9a9ffadc…e158 [39m
[90m2026-05-06T20:32:30.145+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9a9ffadc-c044-473a-a879-820e7d0ae158 peer=127.0.0.1:42840->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:30.152+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=17 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=16f56996-7fc3-4900-86c3-03febdc5ace2 endpoint=127.0.0.1:42840->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:31.174+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42846 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42846->127.0.0.1:18789 conn=91d0cbe3…96da [39m
[90m2026-05-06T20:32:31.262+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=91d0cbe3-67ab-4d41-94de-5086ed0196da peer=127.0.0.1:42846->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:31.282+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=54 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=31f0d838-6107-4810-920f-12c9d31eaab3 endpoint=127.0.0.1:42846->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:32.949+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42848 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42848->127.0.0.1:18789 conn=d2c6dd38…2e78 [39m
[90m2026-05-06T20:32:33.006+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d2c6dd38-7188-400f-bf07-a166c9202e78 peer=127.0.0.1:42848->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:33.016+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=43 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c5038028-3e6b-4088-9c07-32ad0e075776 endpoint=127.0.0.1:42848->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:35.929+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57762 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57762->127.0.0.1:18789 conn=f68fd735…f42a [39m
[90m2026-05-06T20:32:36.023+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f68fd735-5015-454e-8e0f-7e14820af42a peer=127.0.0.1:57762->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:36.047+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=57 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=567e2c2b-ec41-49db-9bf7-a5a40f724470 endpoint=127.0.0.1:57762->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:40.971+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57776 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57776->127.0.0.1:18789 conn=25456dd8…8b2d [39m
[90m2026-05-06T20:32:41.084+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=25456dd8-bf81-43d5-bb94-03448e728b2d peer=127.0.0.1:57776->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:41.108+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=62 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2015ebf6-7347-4a69-b8dd-f854a564aecc endpoint=127.0.0.1:57776->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:49.048+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45334 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45334->127.0.0.1:18789 conn=86184b8a…238b [39m
[90m2026-05-06T20:32:49.151+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=86184b8a-6c32-4ee2-9f89-0af4d06b238b peer=127.0.0.1:45334->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:49.176+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=71 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d86639ce-940a-4562-b652-f1a4e64e837d endpoint=127.0.0.1:45334->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:58.540+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48734 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48734->127.0.0.1:18789 conn=20d7b3d3…2a4a [39m
[90m2026-05-06T20:32:58.573+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=20d7b3d3-6810-4115-b142-189cc0bb2a4a peer=127.0.0.1:48734->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:32:58.581+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=20 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=cef24f79-ed31-4d57-9146-416aeb5f919b endpoint=127.0.0.1:48734->127.0.0.1:18789 [39m
[90m2026-05-06T20:32:59.779+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-06T20:33:06.599+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46688 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46688->127.0.0.1:18789 conn=c6c2a986…c168 [39m
[90m2026-05-06T20:33:06.687+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c6c2a986-98e8-4360-aa35-48641f99c168 peer=127.0.0.1:46688->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:06.698+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=64 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9bcfb19f-76b1-4ce4-8a19-fd208b328f0b endpoint=127.0.0.1:46688->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:14.069+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32888 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32888->127.0.0.1:18789 conn=dbac5f8a…263e [39m
[90m2026-05-06T20:33:14.173+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=dbac5f8a-b3d3-42fe-a6b5-ff24639d263e peer=127.0.0.1:32888->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:14.195+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=83 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=db3daa64-a8cf-4134-87ba-92682425bd0a endpoint=127.0.0.1:32888->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:14.488+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32890 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32890->127.0.0.1:18789 conn=d82111d0…3d49 [39m
[90m2026-05-06T20:33:14.565+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d82111d0-c3c6-42f0-8544-905b81213d49 peer=127.0.0.1:32890->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:14.578+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=48 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=196ce179-c33b-4410-9d39-c65637c702da endpoint=127.0.0.1:32890->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:15.163+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32896 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32896->127.0.0.1:18789 conn=53351efb…a596 [39m
[90m2026-05-06T20:33:15.278+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=53351efb-5666-4c43-afa1-977f6ff0a596 peer=127.0.0.1:32896->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:15.299+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=89 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e355f03f-4516-42fe-8d24-68450918f9b8 endpoint=127.0.0.1:32896->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:16.279+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32900 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32900->127.0.0.1:18789 conn=8a3ffeff…85e4 [39m
[90m2026-05-06T20:33:16.433+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8a3ffeff-365d-4866-b27c-89738df585e4 peer=127.0.0.1:32900->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:16.454+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=120 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=8754cdf4-7290-4894-8309-cfe6e129311b endpoint=127.0.0.1:32900->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:18.136+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32908 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32908->127.0.0.1:18789 conn=874b9b44…807a [39m
[90m2026-05-06T20:33:18.287+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=874b9b44-5e85-4f7b-83de-6eb3777b807a peer=127.0.0.1:32908->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:18.307+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=124 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2853c765-cd1d-4da6-a9c1-bb968766f8c8 endpoint=127.0.0.1:32908->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:21.205+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32922 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32922->127.0.0.1:18789 conn=b1f0a226…0cbb [39m
[90m2026-05-06T20:33:21.347+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b1f0a226-703b-4c99-b4ac-30ea81c70cbb peer=127.0.0.1:32922->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:21.362+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=120 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f8e7654f-9c30-48a5-a6e9-d3171001bec0 endpoint=127.0.0.1:32922->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:26.301+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52552 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52552->127.0.0.1:18789 conn=1f47fcfc…b0e9 [39m
[90m2026-05-06T20:33:26.437+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1f47fcfc-ccdc-4c96-ac2d-99e91a6db0e9 peer=127.0.0.1:52552->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:26.462+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=110 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=81d2527c-3281-4853-a946-ee7accfa2a3d endpoint=127.0.0.1:52552->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:29.777+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:31.393+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52588 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52588->127.0.0.1:18789 conn=9d25a955…08a1 [39m
[90m2026-05-06T20:33:31.517+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9d25a955-aa5d-4c1a-8009-13e3712008a1 peer=127.0.0.1:52588->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8fef478a-bfe4-4061-9356-24149cbaea6b) [39m
[90m2026-05-06T20:33:31.535+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8fef478a-bfe4-4061-9356-24149cbaea6b) durationMs=103 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=fb837b0c-a1b7-4ecf-9bc3-010346863049 endpoint=127.0.0.1:52588->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:31.886+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52590 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52590->127.0.0.1:18789 conn=ee8b95e6…4c29 [39m
[90m2026-05-06T20:33:32.163+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ee8b95e6-5bd1-4318-9204-1250d5144c29 peer=127.0.0.1:52590->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8fef478a-bfe4-4061-9356-24149cbaea6b) [39m
[90m2026-05-06T20:33:32.213+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8fef478a-bfe4-4061-9356-24149cbaea6b) durationMs=214 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a16bafdd-b1e6-43ff-a049-7852e0e18d50 endpoint=127.0.0.1:52590->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:32.734+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52602 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52602->127.0.0.1:18789 conn=6c462ed1…9e86 [39m
[90m2026-05-06T20:33:33.127+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6c462ed1-f04d-4c06-9945-6c6e4e249e86 peer=127.0.0.1:52602->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:33:33.159+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=342 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3c3ff1ae-076d-46f3-b4d7-d33d55717efe endpoint=127.0.0.1:52602->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:34.099+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38272 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38272->127.0.0.1:18789 conn=e7be706b…4f34 [39m
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:34.407+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e7be706b-ead7-4705-ab02-5d52af074f34 peer=127.0.0.1:38272->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:33:34.445+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=270 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f57ccc10-b652-4233-889e-18c35c539dc3 endpoint=127.0.0.1:38272->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:34.479+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38286 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38286->127.0.0.1:18789 conn=c695bdea…c131 [39m
[90m2026-05-06T20:33:34.584+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c695bdea-0e11-4ab9-b7e8-843cc90cc131 peer=127.0.0.1:38286->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:34.606+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=62 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3a10c6d3-464f-4085-982a-248bb5732d46 endpoint=127.0.0.1:38286->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:36.094+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38296 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38296->127.0.0.1:18789 conn=84007c2d…1f38 [39m
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:36.444+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=84007c2d-ecdd-4949-8f4c-4f6b47141f38 peer=127.0.0.1:38296->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:33:36.473+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=299 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=38e54d13-b235-4151-9540-c7f378065ad3 endpoint=127.0.0.1:38296->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:39.363+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38310 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38310->127.0.0.1:18789 conn=3d6bd36f…30fa [39m
[90m2026-05-06T20:33:39.665+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3d6bd36f-be1c-4865-b735-4c2f8b2030fa peer=127.0.0.1:38310->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:33:39.709+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=269 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e180ae5a-53b9-4585-9288-c5de73146f1d endpoint=127.0.0.1:38310->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:42.575+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38324 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38324->127.0.0.1:18789 conn=da808ee3…9a2b [39m
[90m2026-05-06T20:33:42.713+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=da808ee3-0b1c-4c98-83a4-86fcc9599a2b peer=127.0.0.1:38324->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:42.736+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=111 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6b932f15-8439-4e5e-9c11-10db92b37813 endpoint=127.0.0.1:38324->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:44.606+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58332 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58332->127.0.0.1:18789 conn=f98e3fb7…a5ea [39m
[90m2026-05-06T20:33:44.939+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f98e3fb7-4bc9-45ad-892c-3616d950a5ea peer=127.0.0.1:58332->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:33:44.982+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=280 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=24510056-a2e2-47cc-b5ea-800b8993851f endpoint=127.0.0.1:58332->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-06T20:33:46.316+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58346 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58346->127.0.0.1:18789 conn=82fcd5f3…1907 [39m
[90m2026-05-06T20:33:46.687+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=82fcd5f3-2610-47e1-964c-40306ff21907 peer=127.0.0.1:58346->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-06T20:33:46.722+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=316 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c5ac4e99-ad57-45ea-95a1-35649341f800 endpoint=127.0.0.1:58346->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:50.653+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58362 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58362->127.0.0.1:18789 conn=e9a1dcc9…be57 [39m
[90m2026-05-06T20:33:50.690+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e9a1dcc9-5bff-4b25-8c28-0b79ea74be57 peer=127.0.0.1:58362->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:50.698+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=15 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=00684918-1e1c-4e11-be44-53b15656ded0 endpoint=127.0.0.1:58362->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:51.871+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58366 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58366->127.0.0.1:18789 conn=9be1e4a8…06f7 [39m
[90m2026-05-06T20:33:51.965+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9be1e4a8-cb2d-4560-9230-c855f92006f7 peer=127.0.0.1:58366->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:51.970+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=58 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3da7a897-5ee5-4099-97da-b58ac74a9498 endpoint=127.0.0.1:58366->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:51.979+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58380 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58380->127.0.0.1:18789 conn=3711a207…d337 [39m
[90m2026-05-06T20:33:52.004+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3711a207-87a9-4afa-bf24-aa118ca8d337 peer=127.0.0.1:58380->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:52.010+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=15 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2842c7b7-9b9e-4b62-b2e2-5feea2922497 endpoint=127.0.0.1:58380->127.0.0.1:18789 [39m
[90m2026-05-06T20:33:52.361+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58384 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58384->127.0.0.1:18789 conn=bfe0f14f…f28a [39m
[90m2026-05-06T20:33:52.384+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bfe0f14f-40de-4186-a571-09567e53f28a peer=127.0.0.1:58384->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device identity mismatch [39m
[90m2026-05-06T20:33:52.389+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device identity mismatch durationMs=13 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=45bd9a69-482d-4d30-bd54-0eb58ff3aaac endpoint=127.0.0.1:58384->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected


















Is it the same error as last time?

I hope you see this?

Below are logs from the page > Devuce NODE > Node Capabitiles page > device logs section

[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...
[NODE] Challenge received, signing...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android deviceFamily=Android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: INVALID_REQUEST - device identity mismatch
[NODE] Disconnected, will retry...


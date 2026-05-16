Okay now we are close:::


- i see the web dashboard open as seen in scrrenshot. though websocket wont connect.. but good sign..

- the Device Node page shows a button to "Regenerate Auth Token" which goes away as it tries reconnecting

- All logs below starting with device node and then gateway logs (they only missing the initial logs i missed them)

ANALYZE EVERYTHING CLOSELY SUPER CLOSE


* I ALSO PROVIDED SCREENSHOTS

🦞 LOBSTER-1ea5...de77
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
[NODE] Pairing required (1008) — auto-approving device e1bdc213-4891-4c85-8174-7dd56c1ee151...
[NODE] Disconnected, will retry...
[NODE] Auto-approve failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayTransportError: gateway timeout after 10000ms
Gateway target: ws://127.0.0.1:18789
Source: local loopback
Config: /root/.openclaw/openclaw.json
Bind: loopback
    at createGatewayTimeoutTransportError (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:249:9)
    at Timeout.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:333:9)
    at listOnTimeout (node:internal/timers:588:17)
    at process.processTimers (node:internal/timers:523:7)
, null, null)
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — auto-approving device 33ea7293-cc10-4574-ab62-becf83da9ded...
[NODE] Disconnected, will retry...
[NODE] Auto-approve failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayTransportError: gateway timeout after 10000ms
Gateway target: ws://127.0.0.1:18789
Source: local loopback
Config: /root/.openclaw/openclaw.json
Bind: loopback
    at createGatewayTimeoutTransportError (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:249:9)
    at Timeout.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:333:9)
    at listOnTimeout (node:internal/timers:588:17)
    at process.processTimers (node:internal/timers:523:7)
, null, null)
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — auto-approving device 6f94399e-4b2f-47d2-bb70-9986a0e560cb...
[NODE] Disconnected, will retry...
[NODE] Auto-approve failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayTransportError: gateway timeout after 10000ms
Gateway target: ws://127.0.0.1:18789
Source: local loopback
Config: /root/.openclaw/openclaw.json
Bind: loopback
    at createGatewayTimeoutTransportError (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:249:9)
    at Timeout.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:333:9)
    at listOnTimeout (node:internal/timers:588:17)
    at process.processTimers (node:internal/timers:523:7)
, null, null)
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — auto-approving device f2acde23-3d3b-468e-86f9-2510cf6920e5...
[NODE] Disconnected, will retry...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Auto-approve failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Failed to start CLI: GatewayTransportError: gateway timeout after 10000ms
Gateway target: ws://127.0.0.1:18789
Source: local loopback
Config: /root/.openclaw/openclaw.json
Bind: loopback
    at createGatewayTimeoutTransportError (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:249:9)
    at Timeout.<anonymous> (file:///usr/local/lib/node_modules/openclaw/dist/call-DBcRF6-K.js:333:9)
    at listOnTimeout (node:internal/timers:588:17)
    at process.processTimers (node:internal/timers:523:7)
, null, null)
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:05.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Pairing required (1008) — auto-approving device 5b0885da-202b-4bd3-995f-7dc0b6369f31...
[NODE] Disconnected, will retry...















#########################################






Gateway logs 



[90m2026-05-14T00:54:30.276+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: cf173a37-1e83-41d4-bb03-f80644c4be00) durationMs=120 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=613ed35e-0c06-49ab-ab93-deb2df0829cc endpoint=127.0.0.1:49520->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T00:54:38.271+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49524 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49524->127.0.0.1:18789 conn=88eef2d6…0a63 [39m
[WARN] WebSocket disconnected
[90m2026-05-14T00:54:38.875+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=44.5 eventLoopDelayMaxMs=13321.1 eventLoopUtilization=0.499 cpuCoreRatio=0.235 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:203ms,sidecars.main-session-recovery:230ms,sidecars.session-locks:259ms,post-ready.maintenance:7052ms [39m
[90m2026-05-14T00:54:38.887+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T00:54:39.010+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=88eef2d6-82c0-41aa-b6ea-53a287300a63 peer=127.0.0.1:49524->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:54:39.023+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=703 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=095bd4a7-a295-45f6-916a-4f5cd3f17478 endpoint=127.0.0.1:49524->127.0.0.1:18789 [39m
[90m2026-05-14T00:54:43.693+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=324dd9ae-1d3d-485b-8fcc-5fa3130e6366 peer=127.0.0.1:58234->127.0.0.1:18789 remote=127.0.0.1 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:54:45.148+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41636 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41636->127.0.0.1:18789 conn=71aa41c1…dd0b [39m
[90m2026-05-14T00:54:45.333+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=71aa41c1-2f8c-41ca-837a-5c5f666fdd0b peer=127.0.0.1:41636->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:54:45.346+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=172 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a1153e34-7ae1-4c78-a0a3-b7b7bf2a981b endpoint=127.0.0.1:41636->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T00:54:53.362+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36778 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36778->127.0.0.1:18789 conn=dba25843…d141 [39m
[90m2026-05-14T00:54:53.573+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=dba25843-8762-41ce-9c68-13aae0eed141 peer=127.0.0.1:36778->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T00:54:53.586+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=199 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=421aa16a-d915-4e2c-92cb-b925786754fe endpoint=127.0.0.1:36778->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:55:00.136+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35870 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35870->127.0.0.1:18789 conn=315ca69b…a36c [39m
[90m2026-05-14T00:55:00.284+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=315ca69b-21b5-467a-bc16-8a76b638a36c peer=127.0.0.1:35870->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:55:00.295+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=142 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=057f37db-b06f-4420-b669-61e92b56d3bf endpoint=127.0.0.1:35870->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T00:55:08.323+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35878 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35878->127.0.0.1:18789 conn=d39b1342…52f9 [39m
[90m2026-05-14T00:55:08.571+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d39b1342-e6fb-4cdb-b33f-3308bbcd52f9 peer=127.0.0.1:35878->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:55:08.586+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=228 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5c7d0484-a2fe-42a3-809a-825bb49226bd endpoint=127.0.0.1:35878->127.0.0.1:18789 [39m
[90m2026-05-14T00:55:08.879+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T00:55:13.798+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=324dd9ae-1d3d-485b-8fcc-5fa3130e6366 peer=127.0.0.1:58234->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T00:55:13.842+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45062 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:58234->127.0.0.1:18789 conn=324dd9ae…6366 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:55:15.151+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37026 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37026->127.0.0.1:18789 conn=e6faef6c…34e6 [39m
[90m2026-05-14T00:55:15.294+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e6faef6c-c424-43bb-b073-3ebc252f34e6 peer=127.0.0.1:37026->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:55:15.306+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=133 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=19a33d2f-d575-4056-b5c9-bee95825fc21 endpoint=127.0.0.1:37026->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T00:55:28.603+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45584 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45584->127.0.0.1:18789 conn=33e51037…494a [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:55:30.142+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58246 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58246->127.0.0.1:18789 conn=45d8b375…f535 [39m
[90m2026-05-14T00:55:30.275+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=45d8b375-d4e7-491e-94d0-c6605404f535 peer=127.0.0.1:58246->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:55:30.283+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=135 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=401a5e6c-f933-473d-9156-2b5c8e09e558 endpoint=127.0.0.1:58246->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T00:55:38.322+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58262 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58262->127.0.0.1:18789 conn=2f97288c…3027 [39m
[90m2026-05-14T00:55:38.578+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2f97288c-81af-4bce-a4e1-43971f6e3027 peer=127.0.0.1:58262->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:55:38.594+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=234 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9c27437d-df40-4406-854b-8298a9163009 endpoint=127.0.0.1:58262->127.0.0.1:18789 [39m
[90m2026-05-14T00:55:38.882+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T00:55:43.657+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=33e51037-79c1-4fdf-a7f2-31340245494a peer=127.0.0.1:45584->127.0.0.1:18789 remote=127.0.0.1 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:55:45.118+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=32826 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:32826->127.0.0.1:18789 conn=31c05368…b4de [39m
[90m2026-05-14T00:55:45.286+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=31c05368-32c5-4fa9-a216-c3412486b4de peer=127.0.0.1:32826->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:55:45.302+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=150 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=455fd877-7ca4-4a35-963b-fd52cb3d592a endpoint=127.0.0.1:32826->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:56:00.106+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58016 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58016->127.0.0.1:18789 conn=e19070cb…b718 [39m
[90m2026-05-14T00:56:00.241+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e19070cb-ca85-4237-a158-59745bd2b718 peer=127.0.0.1:58016->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T00:56:00.251+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=121 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=10241a11-31dd-435f-8eb9-7a70721005cb endpoint=127.0.0.1:58016->127.0.0.1:18789 [39m
[90m2026-05-14T00:56:08.895+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T00:56:13.712+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=33e51037-79c1-4fdf-a7f2-31340245494a peer=127.0.0.1:45584->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-14T00:56:13.731+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=45074 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:45584->127.0.0.1:18789 conn=33e51037…494a [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:56:15.106+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51868 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51868->127.0.0.1:18789 conn=a950c958…cbc7 [39m
[90m2026-05-14T00:56:15.213+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a950c958-999c-440b-bd9d-c96ab9fecbc7 peer=127.0.0.1:51868->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:56:15.224+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=93 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=648c98de-1cb0-424f-8909-673f2d25d0e4 endpoint=127.0.0.1:51868->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:56:30.159+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48522 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48522->127.0.0.1:18789 conn=bc4c993c…4975 [39m
[90m2026-05-14T00:56:30.288+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bc4c993c-14b1-4f71-a6ac-f871e43e4975 peer=127.0.0.1:48522->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:56:30.299+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=122 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a152efda-4473-46ad-9dc9-2036a427af20 endpoint=127.0.0.1:48522->127.0.0.1:18789 [39m
[90m2026-05-14T00:56:44.497+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=36s eventLoopDelayP99Ms=32.2 eventLoopDelayMaxMs=11349.8 eventLoopUtilization=0.599 cpuCoreRatio=0.265 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:203ms,sidecars.main-session-recovery:230ms,sidecars.session-locks:259ms,post-ready.maintenance:7052ms [39m
[90m2026-05-14T00:56:44.502+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:56:45.122+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33272 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33272->127.0.0.1:18789 conn=d746940c…0358 [39m
[90m2026-05-14T00:56:45.262+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d746940c-166d-4e73-9fd1-034fd9ec0358 peer=127.0.0.1:33272->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:56:45.273+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=130 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=fbf8c7e6-6885-4c2a-81d5-4ea2eb44ead6 endpoint=127.0.0.1:33272->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:57:00.152+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50936 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50936->127.0.0.1:18789 conn=ca30c779…5001 [39m
[90m2026-05-14T00:57:00.310+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ca30c779-3f0a-4d37-ad8f-3a25493d5001 peer=127.0.0.1:50936->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:57:00.321+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=148 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=8ac56232-5424-46d9-9ad9-0e2b89eab854 endpoint=127.0.0.1:50936->127.0.0.1:18789 [39m
[90m2026-05-14T00:57:14.503+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:57:15.096+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38476 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38476->127.0.0.1:18789 conn=2ed16b48…6422 [39m
[90m2026-05-14T00:57:15.184+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2ed16b48-e93d-4770-8c1a-1243e8356422 peer=127.0.0.1:38476->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:57:15.192+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=84 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=cdce8f68-729d-49ef-a6cd-d5e9ed22bd81 endpoint=127.0.0.1:38476->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:57:30.141+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34404 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34404->127.0.0.1:18789 conn=549102db…d3ef [39m
[90m2026-05-14T00:57:30.256+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=549102db-44d0-443a-8fb8-863baf3dd3ef peer=127.0.0.1:34404->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:57:30.267+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=110 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bde7bc60-2b1d-461b-a82d-4e9b9483e38d endpoint=127.0.0.1:34404->127.0.0.1:18789 [39m
[90m2026-05-14T00:57:44.514+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:57:45.101+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52558 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52558->127.0.0.1:18789 conn=7d66b4a3…d91a [39m
[90m2026-05-14T00:57:45.196+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7d66b4a3-c388-4046-a332-1ce94711d91a peer=127.0.0.1:52558->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:57:45.204+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=88 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=037c9b95-762f-405d-ba27-fca6814ffc52 endpoint=127.0.0.1:52558->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:58:00.159+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59584 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59584->127.0.0.1:18789 conn=ca738416…dd9e [39m
[90m2026-05-14T00:58:00.321+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ca738416-7fbe-44c5-9528-bde5c923dd9e peer=127.0.0.1:59584->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:58:00.332+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=153 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=83802f7f-089f-40d6-b045-65b92a82d54d endpoint=127.0.0.1:59584->127.0.0.1:18789 [39m
[90m2026-05-14T00:58:14.518+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:58:15.113+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44932 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44932->127.0.0.1:18789 conn=8a1131e2…dec8 [39m
[90m2026-05-14T00:58:15.200+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8a1131e2-6c27-4dfb-b108-b4b8648cdec8 peer=127.0.0.1:44932->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:58:15.207+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=78 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b2b53090-ccfe-4950-87d2-eb89d9edbfc5 endpoint=127.0.0.1:44932->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:58:30.152+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34430 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34430->127.0.0.1:18789 conn=adcc2431…129e [39m
[90m2026-05-14T00:58:30.341+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=adcc2431-382f-4d73-a534-ecf4f746129e peer=127.0.0.1:34430->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:58:30.351+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=174 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=49476598-ddbd-4431-9358-ec4f5f1500fa endpoint=127.0.0.1:34430->127.0.0.1:18789 [39m
[90m2026-05-14T00:58:44.506+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=31.7 eventLoopDelayMaxMs=10812.9 eventLoopUtilization=0.41 cpuCoreRatio=0.183 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:203ms,sidecars.main-session-recovery:230ms,sidecars.session-locks:259ms,post-ready.maintenance:7052ms [39m
[90m2026-05-14T00:58:44.513+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:58:45.095+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55360 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55360->127.0.0.1:18789 conn=047051bd…e257 [39m
[90m2026-05-14T00:58:45.175+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=047051bd-76c0-4ff2-857f-a5a2c70be257 peer=127.0.0.1:55360->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:58:45.183+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=69 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5408fc64-7d6b-42fd-bf1b-527783302380 endpoint=127.0.0.1:55360->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:59:00.115+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50494 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50494->127.0.0.1:18789 conn=0f7848fb…488d [39m
[90m2026-05-14T00:59:00.221+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0f7848fb-f8f2-45d6-8391-0b6fe407488d peer=127.0.0.1:50494->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:59:00.228+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=105 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7ae7f9b3-bb6b-4053-9684-fb128dbcdab0 endpoint=127.0.0.1:50494->127.0.0.1:18789 [39m
[90m2026-05-14T00:59:14.513+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:59:15.128+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=47502 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:47502->127.0.0.1:18789 conn=cc9da074…07a0 [39m
[90m2026-05-14T00:59:15.299+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=cc9da074-54e5-4e4a-b5cd-86973b7a07a0 peer=127.0.0.1:47502->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) [39m
[90m2026-05-14T00:59:15.311+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e9ab4d03-ee23-490b-acdf-4b000102312a) durationMs=152 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=13edcde8-2835-437c-8a3b-6a27e9192a9f endpoint=127.0.0.1:47502->127.0.0.1:18789 [39m
[90m2026-05-14T00:59:44.507+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T00:59:45.116+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49036 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49036->127.0.0.1:18789 conn=fa317736…4006 [39m
[90m2026-05-14T00:59:45.709+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fa317736-6c4a-40bc-83df-84cc343b4006 peer=127.0.0.1:49036->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T00:59:45.723+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=549 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=52a52b6a-2455-4ba9-96c7-affe25f46d36 endpoint=127.0.0.1:49036->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:00:00.140+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41656 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41656->127.0.0.1:18789 conn=d23685ce…843e [39m
[90m2026-05-14T01:00:00.358+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d23685ce-fc1e-40c2-9f10-7b6eb7bb843e peer=127.0.0.1:41656->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:00:00.372+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=184 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ad903a24-7846-4c32-8168-b39738a313f8 endpoint=127.0.0.1:41656->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[90m2026-05-14T01:00:14.512+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:00:15.153+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51792 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51792->127.0.0.1:18789 conn=c598221a…0e60 [39m
[90m2026-05-14T01:00:15.277+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c598221a-99e6-437b-b012-60df5a710e60 peer=127.0.0.1:51792->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:00:15.289+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=123 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1bc9a5c2-a7bd-479e-993f-a695183f7218 endpoint=127.0.0.1:51792->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:00:30.144+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33282 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33282->127.0.0.1:18789 conn=bb6f90b9…438c [39m
[90m2026-05-14T01:00:30.348+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bb6f90b9-dcc2-4e0a-9d9f-6adca394438c peer=127.0.0.1:33282->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T01:00:30.360+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=184 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c11a5fee-417e-420f-b9d1-f69191626e9f endpoint=127.0.0.1:33282->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:00:44.510+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=24.3 eventLoopDelayMaxMs=10695.5 eventLoopUtilization=0.413 cpuCoreRatio=0.194 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:203ms,sidecars.main-session-recovery:230ms,sidecars.session-locks:259ms,post-ready.maintenance:7052ms [39m
[90m2026-05-14T01:00:44.519+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T01:00:45.136+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45958 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45958->127.0.0.1:18789 conn=273c9adf…5ea3 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:00:45.305+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=273c9adf-9642-4372-bea0-28c3ba2d5ea3 peer=127.0.0.1:45958->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:00:45.318+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=151 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4c52157a-1715-4970-b4a6-1fdf1e88c75a endpoint=127.0.0.1:45958->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:01:00.146+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37142 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37142->127.0.0.1:18789 conn=0e0f5c98…d476 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:01:00.437+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0e0f5c98-3dda-40be-94a4-7d7486f1d476 peer=127.0.0.1:37142->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:01:00.464+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=224 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b63ccd3a-495e-4f95-b567-082a2b64b451 endpoint=127.0.0.1:37142->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:01:14.523+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T01:01:15.135+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41054 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41054->127.0.0.1:18789 conn=9a11b700…a3ca [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:01:15.331+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9a11b700-0354-44e6-9d80-1d4be865a3ca peer=127.0.0.1:41054->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:01:15.344+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=187 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=26adbecd-3ab3-4619-9ded-1abafeb6ad07 endpoint=127.0.0.1:41054->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:01:30.138+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45360 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45360->127.0.0.1:18789 conn=7c031ac4…560d [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:01:30.456+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7c031ac4-cedb-463c-b07f-7b561553560d peer=127.0.0.1:45360->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:01:30.487+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=251 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1c496154-8c3f-42f7-901a-cf71730d0954 endpoint=127.0.0.1:45360->127.0.0.1:18789 [39m
[90m2026-05-14T01:01:50.999+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:02:00.144+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46416 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46416->127.0.0.1:18789 conn=b3a4f229…541e [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:02:00.356+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b3a4f229-504f-4949-a711-54b450cb541e peer=127.0.0.1:46416->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:02:00.369+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=195 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=75e7b08e-7a79-4386-a23a-ddad62becdb2 endpoint=127.0.0.1:46416->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:02:15.153+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44130 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44130->127.0.0.1:18789 conn=5be5643c…5e3c [39m
[90m2026-05-14T01:02:15.361+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5be5643c-b0b1-49b2-9a3e-bed2e2a85e3c peer=127.0.0.1:44130->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:02:15.379+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=182 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=fd86b90a-8464-417f-b700-bf5bb5f31422 endpoint=127.0.0.1:44130->127.0.0.1:18789 [39m
[90m2026-05-14T01:02:27.059+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:02:30.148+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48020 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48020->127.0.0.1:18789 conn=2372bbb6…1b1e [39m
[90m2026-05-14T01:02:30.365+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2372bbb6-7750-4b89-85fe-ca3437d01b1e peer=127.0.0.1:48020->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:02:30.378+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=187 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f5825211-0059-4372-817a-088c9f1295cb endpoint=127.0.0.1:48020->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:02:45.145+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46876 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46876->127.0.0.1:18789 conn=909a312e…d835 [39m
[90m2026-05-14T01:02:45.297+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=909a312e-b2e4-4415-b123-24cb8c6bd835 peer=127.0.0.1:46876->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:02:45.311+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=128 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=197cdd34-f9c6-4638-aa3b-4814b7ab96f2 endpoint=127.0.0.1:46876->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:03:00.157+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41848 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41848->127.0.0.1:18789 conn=ca75b670…9b66 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:03:00.536+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ca75b670-3c8d-4fae-a25e-f3b190f79b66 peer=127.0.0.1:41848->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:03:00.552+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=330 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e643c357-1afc-4834-88dd-bbe1f4c75617 endpoint=127.0.0.1:41848->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:03:15.153+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58230 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58230->127.0.0.1:18789 conn=e0c4c843…603d [39m
[90m2026-05-14T01:03:15.392+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e0c4c843-6943-498d-89dc-75de6768603d peer=127.0.0.1:58230->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:03:15.410+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=196 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2be2d644-86f2-426e-b7a5-93eff01bb05c endpoint=127.0.0.1:58230->127.0.0.1:18789 [39m
[90m2026-05-14T01:03:27.709+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=31s eventLoopDelayP99Ms=28.9 eventLoopDelayMaxMs=12297.7 eventLoopUtilization=0.472 cpuCoreRatio=0.261 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:203ms,sidecars.main-session-recovery:230ms,sidecars.session-locks:259ms,post-ready.maintenance:7052ms [39m
[90m2026-05-14T01:03:27.712+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:03:30.165+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46906 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46906->127.0.0.1:18789 conn=a5d5c7a1…f537 [39m
[90m2026-05-14T01:03:30.530+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a5d5c7a1-987b-430e-baa6-0f494037f537 peer=127.0.0.1:46906->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:03:30.560+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=289 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=636fd651-5954-40f7-a472-4f2004d7d710 endpoint=127.0.0.1:46906->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:03:45.138+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59036 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59036->127.0.0.1:18789 conn=ed4d18f8…b377 [39m
[90m2026-05-14T01:03:45.415+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ed4d18f8-704f-428d-b48b-31f67e99b377 peer=127.0.0.1:59036->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:03:45.439+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=216 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=19b4820f-81a1-4ff5-806d-4434401212b2 endpoint=127.0.0.1:59036->127.0.0.1:18789 [39m
[90m2026-05-14T01:03:57.728+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:04:00.160+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57612 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57612->127.0.0.1:18789 conn=04ad45e5…c0a3 [39m
[90m2026-05-14T01:04:00.404+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=04ad45e5-15e1-4693-92a3-f7fe7e7fc0a3 peer=127.0.0.1:57612->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:04:00.420+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=217 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0359333b-8856-49f8-9810-0c5d9ba3bcc1 endpoint=127.0.0.1:57612->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:04:15.160+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34678 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34678->127.0.0.1:18789 conn=9c02894b…abbe [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:04:27.711+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T01:04:27.740+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9c02894b-2e4c-4705-b904-ee832025abbe peer=127.0.0.1:34678->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:04:27.748+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=12588 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=14e162c8-f4f7-4e81-b342-1795873f9dc8 endpoint=127.0.0.1:34678->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:04:30.153+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44720 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44720->127.0.0.1:18789 conn=8dc54db8…374b [39m
[90m2026-05-14T01:04:30.456+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=8dc54db8-4884-4358-babf-186e376c374b peer=127.0.0.1:44720->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) [39m
[90m2026-05-14T01:04:30.472+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8880d1fd-14cf-44a0-b780-87e5daf9a9ff) durationMs=248 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9662aaab-9ba4-4e3d-9ed4-1fa18f028eac endpoint=127.0.0.1:44720->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T01:04:45.161+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54094 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54094->127.0.0.1:18789 conn=1edeabb7…b1d7 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:04:45.947+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1edeabb7-52c3-4c41-9854-785d2f43b1d7 peer=127.0.0.1:54094->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:04:45.964+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=738 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=bb36d08a-1c1a-45d1-97d8-4195df560107 endpoint=127.0.0.1:54094->127.0.0.1:18789 [39m
[90m2026-05-14T01:04:57.731+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:05:00.103+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59142 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59142->127.0.0.1:18789 conn=bf84a648…111f [39m
[90m2026-05-14T01:05:00.352+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bf84a648-f7e9-4bb8-a899-a55a092b111f peer=127.0.0.1:59142->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:05:00.369+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=195 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=8574606a-02e9-4145-a742-663c72cb31aa endpoint=127.0.0.1:59142->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:05:15.167+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=47030 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:47030->127.0.0.1:18789 conn=19765aa8…3c2c [39m
[90m2026-05-14T01:05:15.481+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=19765aa8-1e98-4325-bf13-a3ca9e483c2c peer=127.0.0.1:47030->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:05:15.513+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=236 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=39092988-1c55-45ce-b485-172f0ae7457d endpoint=127.0.0.1:47030->127.0.0.1:18789 [39m
[90m2026-05-14T01:05:27.730+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.5 eventLoopDelayMaxMs=12029.3 eventLoopUtilization=0.475 cpuCoreRatio=0.264 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:203ms,sidecars.main-session-recovery:230ms,sidecars.session-locks:259ms,post-ready.maintenance:7052ms [39m
[90m2026-05-14T01:05:27.743+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:05:30.146+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39288 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39288->127.0.0.1:18789 conn=bf9f6f23…8d09 [39m
[90m2026-05-14T01:05:30.451+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bf9f6f23-ba1a-4888-98f2-fccbcdb88d09 peer=127.0.0.1:39288->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:05:30.469+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=246 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=06d58122-4fa7-496a-a06d-e1bfbaf3af0c endpoint=127.0.0.1:39288->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:05:45.158+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36798 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36798->127.0.0.1:18789 conn=95cf2f51…f545 [39m
[90m2026-05-14T01:05:45.476+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=95cf2f51-bf29-4f25-bbc0-27cb6373f545 peer=127.0.0.1:36798->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:05:45.496+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=260 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b07a637a-a839-47f1-90b1-9903a94bc93a endpoint=127.0.0.1:36798->127.0.0.1:18789 [39m
[90m2026-05-14T01:05:57.736+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:06:00.149+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37806 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37806->127.0.0.1:18789 conn=2a652cc8…d32b [39m
[90m2026-05-14T01:06:00.440+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2a652cc8-3fe0-4d5b-b7c2-aa183b89d32b peer=127.0.0.1:37806->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:06:00.469+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=218 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5866502c-ec1e-49c3-8dee-93fa8dc5597e endpoint=127.0.0.1:37806->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:06:15.163+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50204 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50204->127.0.0.1:18789 conn=17b445fe…0077 [39m
[90m2026-05-14T01:06:15.404+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=17b445fe-1e2a-4c40-bba3-108760480077 peer=127.0.0.1:50204->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:06:15.423+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=203 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=66ad7675-10f2-47f4-874e-1447ae540f9b endpoint=127.0.0.1:50204->127.0.0.1:18789 [39m
[90m2026-05-14T01:06:27.898+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:06:30.148+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41926 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41926->127.0.0.1:18789 conn=5d64776b…a6c6 [39m
[90m2026-05-14T01:06:30.419+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5d64776b-8fd3-4100-a5be-f868c053a6c6 peer=127.0.0.1:41926->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:06:30.437+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=213 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=43909982-017a-4cdc-b3dd-1e023bc03dd7 endpoint=127.0.0.1:41926->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:06:45.140+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40708 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40708->127.0.0.1:18789 conn=df14e2ba…a727 [39m
[90m2026-05-14T01:06:45.427+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=df14e2ba-a9ac-4e71-8785-cf66ae17a727 peer=127.0.0.1:40708->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:06:45.449+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=230 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=672e7f05-4bf0-40b2-8b4f-59656f67e458 endpoint=127.0.0.1:40708->127.0.0.1:18789 [39m
[90m2026-05-14T01:06:57.917+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:07:00.147+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39906 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39906->127.0.0.1:18789 conn=6d21fb4b…04a8 [39m
[90m2026-05-14T01:07:00.339+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6d21fb4b-d979-46a2-9282-aa84432e04a8 peer=127.0.0.1:39906->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) [39m
[90m2026-05-14T01:07:00.354+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 44baa104-42a2-4cd0-a419-4de873a757f8) durationMs=155 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0b7f856e-76b5-4a56-8d66-63a9aaa59a1d endpoint=127.0.0.1:39906->127.0.0.1:18789 [39m
[90m2026-05-14T01:07:12.963+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59880 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59880->127.0.0.1:18789 conn=9f98654c…80fc [39m
[90m2026-05-14T01:07:13.181+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9f98654c-c713-4e12-9b50-a2b934cb80fc peer=127.0.0.1:59880->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: e1bdc213-4891-4c85-8174-7dd56c1ee151) [39m
[90m2026-05-14T01:07:13.201+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: e1bdc213-4891-4c85-8174-7dd56c1ee151) durationMs=217 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0734ded2-304f-4a40-b555-fb86a0aebca6 endpoint=127.0.0.1:59880->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:07:15.140+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59904 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59904->127.0.0.1:18789 conn=1ac3ac61…aadb [39m
[90m2026-05-14T01:07:15.239+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=1ac3ac61-e8b2-4730-984f-50f5aa47aadb peer=127.0.0.1:59904->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 507c8b18-603d-44bf-aa54-9b5dfef11b7e) [39m
[90m2026-05-14T01:07:15.258+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 507c8b18-603d-44bf-aa54-9b5dfef11b7e) durationMs=110 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2794750b-8219-4737-9d5c-d06483cd3fb5 endpoint=127.0.0.1:59904->127.0.0.1:18789 [39m
[90m2026-05-14T01:07:35.366+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=37s eventLoopDelayP99Ms=51.8 eventLoopDelayMaxMs=19864.2 eventLoopUtilization=0.58 cpuCoreRatio=0.278 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:203ms,sidecars.main-session-recovery:230ms,sidecars.session-locks:259ms,post-ready.maintenance:7052ms [39m
[90m2026-05-14T01:07:35.377+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T01:07:36.659+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39448 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39448->127.0.0.1:18789 conn=3706c04d…00d8 [39m
[90m2026-05-14T01:07:36.833+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=010a58aad243e413667397aedf2da0d5562d1ad61ce230491da8fe0fee9c092c role=operator [39m
[90m2026-05-14T01:07:36.871+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-14T01:07:36.887+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-14T01:07:52.507+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=18 [39m
[90m2026-05-14T01:07:52.537+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=15905 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=d0e6ebf6-5208-4cd1-aa42-b62c969795d1 endpoint=127.0.0.1:39448->127.0.0.1:18789 [39m
[90m2026-05-14T01:07:52.562+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37316 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37316->127.0.0.1:18789 conn=81574386…a3ff [39m
[90m2026-05-14T01:07:54.271+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 1752ms conn=3706c04d…00d8 id=d0e6ebf6…95d1 [39m
[90m2026-05-14T01:07:54.281+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.4 mode=cli clientId=cli platform=linux auth=token conn=81574386…a3ff [39m
[90m2026-05-14T01:07:54.290+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=1 stateVersion=1 [39m
[90m2026-05-14T01:08:05.951+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=1 healthVersion=19 [39m
[90m2026-05-14T01:08:05.959+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T01:08:05.969+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-14T01:08:05.984+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=13420 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=a4586a60-3cf7-478b-ac1f-9cb7a0d76438 endpoint=127.0.0.1:37316->127.0.0.1:18789 [39m
[90m2026-05-14T01:08:05.996+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51170 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51170->127.0.0.1:18789 conn=8e73710e…4a3d [39m
[90m2026-05-14T01:08:06.008+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48736 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48736->127.0.0.1:18789 conn=ab44add8…3827 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:08:15.146+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55148 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55148->127.0.0.1:18789 conn=45be3e94…f221 [39m
[90m2026-05-14T01:08:15.344+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=45be3e94-f3ce-4fb7-b3d9-3200885bf221 peer=127.0.0.1:55148->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T01:08:15.353+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=197 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=dbf899d8-3a5d-4af3-aa3e-35216ef4dd08 endpoint=127.0.0.1:55148->127.0.0.1:18789 [39m
[90m2026-05-14T01:08:28.611+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=8e73710e-062f-4933-93f2-d40fc4824a3d peer=127.0.0.1:51170->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T01:08:28.623+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=ab44add8-4b0a-4609-8e35-019fb1de3827 peer=127.0.0.1:48736->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T01:08:28.636+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55154 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55154->127.0.0.1:18789 conn=fab1c065…09a4 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T01:08:30.136+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35586 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35586->127.0.0.1:18789 conn=03926718…cf7a [39m
[90m2026-05-14T01:08:30.253+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=03926718-c371-4833-818e-bebfdf69cf7a peer=127.0.0.1:35586->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T01:08:30.262+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=107 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=79496fa2-33dc-461e-ac13-845c1697dc47 endpoint=127.0.0.1:35586->127.0.0.1:18789 [39m
[90m2026-05-14T01:08:32.780+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35592 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35592->127.0.0.1:18789 conn=f42c53f1…8ff0 [39m
[90m2026-05-14T01:08:32.869+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f42c53f1-f850-4923-9c78-1cddcfb38ff0 peer=127.0.0.1:35592->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 33ea7293-cc10-4574-ab62-becf83da9ded) [39m
[90m2026-05-14T01:08:32.878+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 33ea7293-cc10-4574-ab62-becf83da9ded) durationMs=84 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=39c76e9d-ffae-44df-a065-6c79d595d798 endpoint=127.0.0.1:35592->127.0.0.1:18789 [39m
[90m2026-05-14T01:08:35.962+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
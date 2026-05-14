
 
🦞 LOBSTER-cca6...b3a6
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:45.000000: Future not completed
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: HttpException: Connection reset by peer, uri = http://127.0.0.1:18789
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 45324
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 52866
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null
[NODE] Connect error: UNAVAILABLE - gateway starting; retry shortly
[NODE] Disconnected, will retry...
[NODE] Challenge received
[NODE] Disconnected, will retry...
[NODE] Challenge received
[NODE] Disconnected, will retry...
[NODE] Challenge received
[NODE] Disconnected, will retry...
[NODE] Challenge received
[NODE] Disconnected, will retry...
[NODE] Challenge received
[NODE] Disconnected, will retry...
[NODE] Challenge received


#========================================================================================

GATEWAY LOGS::

Gateway logs almost look like it worked then errors again
Inbox
Cosy <cosychiruka@gmail.com>
	
10:01 AM (4 hours ago)
	
	
to me
[90m2026-05-14T07:40:20.275+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34736 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34736->127.0.0.1:18789 conn=a93d3d2d…6900 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:40:20.516+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a93d3d2d-c799-4d43-9914-cd41a6606900 peer=127.0.0.1:34736->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 744a8a68-7f24-42fb-bd67-7ef969698762) [39m
[90m2026-05-14T07:40:20.529+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 744a8a68-7f24-42fb-bd67-7ef969698762) durationMs=202 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=21b4984f-bf74-4e2c-bcdd-6960671e343a endpoint=127.0.0.1:34736->127.0.0.1:18789 [39m
[90m2026-05-14T07:40:21.768+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:40:50.280+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45616 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45616->127.0.0.1:18789 conn=b7cdfbe3…3884 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:40:50.534+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b7cdfbe3-4ce5-4073-bb98-2d7d45e73884 peer=127.0.0.1:45616->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T07:40:50.551+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=198 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=580581ed-b956-4b7f-bb10-a002ba2cde90 endpoint=127.0.0.1:45616->127.0.0.1:18789 [39m
[90m2026-05-14T07:40:51.784+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=30.9 eventLoopDelayMaxMs=16022.2 eventLoopUtilization=0.584 cpuCoreRatio=0.281 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:40:51.802+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:41:05.285+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39848 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39848->127.0.0.1:18789 conn=a67fcc25…b1bd [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:41:06.076+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a67fcc25-802b-48d5-88c2-cbda9c74b1bd peer=127.0.0.1:39848->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:41:06.107+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=716 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7b2ed10f-9de4-493d-987b-ae54bc83ed38 endpoint=127.0.0.1:39848->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:41:20.283+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57196 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57196->127.0.0.1:18789 conn=aedad10f…c2bf [39m
[90m2026-05-14T07:41:20.431+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=aedad10f-33ff-4461-89d5-c4388d56c2bf peer=127.0.0.1:57196->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:41:20.443+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=121 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=41e151d6-a51b-4584-b13c-a990dfd04e78 endpoint=127.0.0.1:57196->127.0.0.1:18789 [39m
[90m2026-05-14T07:41:21.775+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:41:50.288+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37250 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37250->127.0.0.1:18789 conn=27250ac9…d87c [39m
[90m2026-05-14T07:41:50.513+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=27250ac9-fefa-44f5-86a2-c921ff7dd87c peer=127.0.0.1:37250->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:41:50.532+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=189 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=12fc4eae-e9b6-467c-a27f-7f7d46b42667 endpoint=127.0.0.1:37250->127.0.0.1:18789 [39m
[90m2026-05-14T07:41:51.782+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:42:05.292+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34888 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34888->127.0.0.1:18789 conn=f219826c…f06f [39m
[90m2026-05-14T07:42:05.471+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f219826c-12a4-4fc9-9216-9efc2e81f06f peer=127.0.0.1:34888->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:42:05.491+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=161 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=53ff2b9c-d912-4acf-a1c8-558314cc514f endpoint=127.0.0.1:34888->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:42:20.276+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57878 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57878->127.0.0.1:18789 conn=2f949e32…60ba [39m
[90m2026-05-14T07:42:20.492+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=2f949e32-deda-46fd-a0d7-85f67a3760ba peer=127.0.0.1:57878->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:42:20.508+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=179 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=18ca836f-f705-45a9-920d-0a36944a63f4 endpoint=127.0.0.1:57878->127.0.0.1:18789 [39m
[90m2026-05-14T07:42:21.788+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:42:50.277+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36296 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36296->127.0.0.1:18789 conn=4713c07f…835e [39m
[90m2026-05-14T07:42:50.508+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=4713c07f-af6e-492c-96d8-ad7060c0835e peer=127.0.0.1:36296->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:42:50.522+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=197 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=f25d2e35-abcb-4f56-801e-9b2bf805f971 endpoint=127.0.0.1:36296->127.0.0.1:18789 [39m
[90m2026-05-14T07:42:51.776+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.3 eventLoopDelayMaxMs=15862.9 eventLoopUtilization=0.578 cpuCoreRatio=0.277 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:42:51.781+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:43:05.282+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55594 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55594->127.0.0.1:18789 conn=005bfa3d…69d0 [39m
[90m2026-05-14T07:43:05.491+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=005bfa3d-f93d-4a2b-9e6b-f1d0aff669d0 peer=127.0.0.1:55594->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:43:05.505+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=183 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3e103494-da00-4fd9-b376-13fcc01850a9 endpoint=127.0.0.1:55594->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:43:20.280+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=37266 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:37266->127.0.0.1:18789 conn=02816b66…7415 [39m
[90m2026-05-14T07:43:20.571+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=02816b66-7299-4d20-bd5b-3fbbf1e87415 peer=127.0.0.1:37266->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:43:20.586+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=243 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=13316dba-a735-4704-ac33-a482194d988e endpoint=127.0.0.1:37266->127.0.0.1:18789 [39m
[90m2026-05-14T07:43:21.787+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:43:50.279+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=52100 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:52100->127.0.0.1:18789 conn=69c28060…7bcb [39m
[90m2026-05-14T07:43:50.588+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=69c28060-5e10-4b95-8f6e-ae0b39877bcb peer=127.0.0.1:52100->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:43:50.617+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=225 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ca2f5331-b6c2-4638-b8bc-e5923f4c8bd7 endpoint=127.0.0.1:52100->127.0.0.1:18789 [39m
[90m2026-05-14T07:43:51.789+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:44:05.278+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35926 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35926->127.0.0.1:18789 conn=f0bc95b9…c55a [39m
[90m2026-05-14T07:44:05.520+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f0bc95b9-5932-43c9-8ba0-33fccbd0c55a peer=127.0.0.1:35926->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:44:05.547+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=186 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=20924a1d-4150-4edf-abd3-01687b124fda endpoint=127.0.0.1:35926->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:44:20.289+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56680 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56680->127.0.0.1:18789 conn=0c26dec4…c474 [39m
[90m2026-05-14T07:44:20.581+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=0c26dec4-ba2b-4dae-9892-de000f69c474 peer=127.0.0.1:56680->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T07:44:20.609+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=250 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=237e1ec3-1142-4791-b0e0-d86d6c34092e endpoint=127.0.0.1:56680->127.0.0.1:18789 [39m
[90m2026-05-14T07:44:21.794+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T07:44:56.113+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=34s eventLoopDelayP99Ms=15560.9 eventLoopDelayMaxMs=15669.9 eventLoopUtilization=0.918 cpuCoreRatio=0.378 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:44:56.123+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:45:05.280+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44380 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44380->127.0.0.1:18789 conn=aa959fb7…818c [39m
[90m2026-05-14T07:45:05.500+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=aa959fb7-3e4e-47b8-b62c-ec520813818c peer=127.0.0.1:44380->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:45:05.511+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=192 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=cceffea0-504b-4c35-a239-abbbda5bd226 endpoint=127.0.0.1:44380->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:45:20.290+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57814 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57814->127.0.0.1:18789 conn=35b52339…e220 [39m
[90m2026-05-14T07:45:20.560+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=35b52339-6f57-42b7-8d97-8342ee86e220 peer=127.0.0.1:57814->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:45:20.577+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=222 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6304df63-a79b-4bc0-b710-2ddccf115d0b endpoint=127.0.0.1:57814->127.0.0.1:18789 [39m
[90m2026-05-14T07:45:45.017+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:45:50.264+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57044 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57044->127.0.0.1:18789 conn=c6b207fb…9676 [39m
[90m2026-05-14T07:45:50.479+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c6b207fb-59ac-4795-93b6-01f575c29676 peer=127.0.0.1:57044->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) [39m
[90m2026-05-14T07:45:50.495+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 216ac68e-28d2-48db-adb7-3d92daf9b16a) durationMs=165 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a07b5f44-01e9-4968-8746-41621f33e376 endpoint=127.0.0.1:57044->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:46:05.293+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44024 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44024->127.0.0.1:18789 conn=41344270…5c36 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:46:06.130+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=41344270-a553-46c2-be1d-a88b05c25c36 peer=127.0.0.1:44024->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:46:06.146+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=801 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a368c209-410e-4578-a3ba-7f313b35a36c endpoint=127.0.0.1:44024->127.0.0.1:18789 [39m
[90m2026-05-14T07:46:15.030+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:46:20.283+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48964 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48964->127.0.0.1:18789 conn=62742eb5…312f [39m
[90m2026-05-14T07:46:20.564+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=62742eb5-1690-47b5-903d-1fadfd7d312f peer=127.0.0.1:48964->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:46:20.590+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=213 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=9b8525b6-2585-4df4-a7ef-d092a89ce539 endpoint=127.0.0.1:48964->127.0.0.1:18789 [39m
[90m2026-05-14T07:46:45.035+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:46:50.284+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45984 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45984->127.0.0.1:18789 conn=009aff85…ca58 [39m
[90m2026-05-14T07:46:50.537+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=009aff85-b67b-4c39-b3be-b8bd1513ca58 peer=127.0.0.1:45984->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T07:46:50.553+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=199 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a6a00d62-3802-48ae-9fcb-b353defef100 endpoint=127.0.0.1:45984->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:47:05.285+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33304 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33304->127.0.0.1:18789 conn=b893b6ce…e04c [39m
[90m2026-05-14T07:47:05.558+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b893b6ce-c3d7-49b7-8f97-20f1b4e1e04c peer=127.0.0.1:33304->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:47:05.577+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=220 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=da4c0f20-3082-440b-96f3-e879bfec558c endpoint=127.0.0.1:33304->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:47:20.285+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51910 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51910->127.0.0.1:18789 conn=9e3d136a…14d8 [39m
[90m2026-05-14T07:47:20.572+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9e3d136a-0af2-44f6-ab7e-6ce29a2314d8 peer=127.0.0.1:51910->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:47:20.588+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=229 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1e50d9b1-23b6-4b70-8e35-66f13978a87f endpoint=127.0.0.1:51910->127.0.0.1:18789 [39m
[90m2026-05-14T07:47:45.038+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.3 eventLoopDelayMaxMs=15745.4 eventLoopUtilization=0.575 cpuCoreRatio=0.285 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:47:45.051+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:47:50.285+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56896 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56896->127.0.0.1:18789 conn=c591de7e…2560 [39m
[90m2026-05-14T07:47:50.507+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c591de7e-cfcb-4764-92b2-98fa08102560 peer=127.0.0.1:56896->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:47:50.528+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=183 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e27166a5-be74-41cf-be92-ffb4eb3b230b endpoint=127.0.0.1:56896->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:48:05.280+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48254 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48254->127.0.0.1:18789 conn=671aebc3…ff02 [39m
[90m2026-05-14T07:48:05.484+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=671aebc3-4740-4ac4-bf0b-93d898c7ff02 peer=127.0.0.1:48254->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:48:05.500+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=177 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1de87482-8e8a-4886-b75a-0baecf148750 endpoint=127.0.0.1:48254->127.0.0.1:18789 [39m
[90m2026-05-14T07:48:15.039+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:48:20.295+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=47138 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:47138->127.0.0.1:18789 conn=480d4a5e…9e85 [39m
[90m2026-05-14T07:48:20.538+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=480d4a5e-efda-4074-b742-37a4a8c39e85 peer=127.0.0.1:47138->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:48:20.559+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=219 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=cb2e9018-b5c6-402d-83ed-223cecfdc020 endpoint=127.0.0.1:47138->127.0.0.1:18789 [39m
[90m2026-05-14T07:48:45.041+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:48:50.279+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34770 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34770->127.0.0.1:18789 conn=443125f2…8561 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:48:50.512+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=443125f2-58f3-464e-a207-6280fa298561 peer=127.0.0.1:34770->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:48:50.529+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=188 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=7723ae37-9ad7-419a-9f77-990985da9264 endpoint=127.0.0.1:34770->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:49:05.291+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55450 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55450->127.0.0.1:18789 conn=cd7c1f49…0b0f [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:49:05.461+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=cd7c1f49-adff-44dc-8768-9db464ea0b0f peer=127.0.0.1:55450->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:49:05.489+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=152 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3bb6b60e-bd0a-4e12-9852-8929e28d22ff endpoint=127.0.0.1:55450->127.0.0.1:18789 [39m
[90m2026-05-14T07:49:15.045+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:49:20.298+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55744 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55744->127.0.0.1:18789 conn=3105ee4b…5d78 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:49:20.505+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3105ee4b-9c33-44bb-b6e7-b13786d95d78 peer=127.0.0.1:55744->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:49:20.519+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=184 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=66ed5356-02d0-4e81-b98f-afa50f32b179 endpoint=127.0.0.1:55744->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:49:52.644+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=38s eventLoopDelayP99Ms=60.1 eventLoopDelayMaxMs=16408.1 eventLoopUtilization=0.776 cpuCoreRatio=0.337 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:49:52.648+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T07:49:52.712+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35756 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35756->127.0.0.1:18789 conn=312dfd9c…f3cc [39m
[90m2026-05-14T07:49:52.912+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=312dfd9c-b97e-4c06-96d8-b030da76f3cc peer=127.0.0.1:35756->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:49:52.924+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=179 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=61f2ed2e-b0f4-4577-9b3c-fc917ab15f92 endpoint=127.0.0.1:35756->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:50:05.279+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56958 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56958->127.0.0.1:18789 conn=e2f22f3e…c3f1 [39m
[90m2026-05-14T07:50:05.453+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e2f22f3e-4bb2-470d-bfea-549f0571c3f1 peer=127.0.0.1:56958->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:50:05.468+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=158 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=1d7bfddc-17ea-4a5c-babb-55f9d1d8be72 endpoint=127.0.0.1:56958->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:50:20.282+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55560 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55560->127.0.0.1:18789 conn=d9e908b5…a9a8 [39m
[90m2026-05-14T07:50:20.468+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d9e908b5-c198-45ed-b76a-47e8a74fa9a8 peer=127.0.0.1:55560->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) [39m
[90m2026-05-14T07:50:20.480+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 8a326940-7ded-4208-8610-d10b2642dcb0) durationMs=167 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d0f2c72e-874d-4d9d-a319-9e9d9329254a endpoint=127.0.0.1:55560->127.0.0.1:18789 [39m
[90m2026-05-14T07:50:22.659+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:50:50.289+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49372 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49372->127.0.0.1:18789 conn=06bd2f38…ee31 [39m
[90m2026-05-14T07:50:50.531+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=06bd2f38-db9c-4f6d-8123-708a40d0ee31 peer=127.0.0.1:49372->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T07:50:50.545+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=211 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=26dea389-f1c9-4aec-a243-f5398860476b endpoint=127.0.0.1:49372->127.0.0.1:18789 [39m
[90m2026-05-14T07:50:52.660+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:51:05.304+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53910 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53910->127.0.0.1:18789 conn=03842fbd…8783 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:51:06.243+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=03842fbd-901a-4daf-83f8-d9f2afc58783 peer=127.0.0.1:53910->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:51:06.265+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=886 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d1085cba-8a50-4848-a8bd-4cd11b87b75c endpoint=127.0.0.1:53910->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:51:20.302+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46572 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46572->127.0.0.1:18789 conn=fbf73f59…a53d [39m
[90m2026-05-14T07:51:20.502+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fbf73f59-0777-4054-aa5b-ce363066a53d peer=127.0.0.1:46572->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:51:20.515+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=174 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6c6cc75b-1099-4e46-93e2-f927c7d28e36 endpoint=127.0.0.1:46572->127.0.0.1:18789 [39m
[90m2026-05-14T07:51:22.670+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:51:50.277+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57326 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57326->127.0.0.1:18789 conn=c998290a…d043 [39m
[90m2026-05-14T07:51:50.423+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c998290a-0333-4cb9-b6f7-0a25a705d043 peer=127.0.0.1:57326->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:51:50.436+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=138 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0e48ac72-1b35-4b1e-8880-5b425f36da60 endpoint=127.0.0.1:57326->127.0.0.1:18789 [39m
[90m2026-05-14T07:51:52.672+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.9 eventLoopDelayMaxMs=16483.6 eventLoopUtilization=0.597 cpuCoreRatio=0.294 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:51:52.694+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:52:05.288+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55796 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55796->127.0.0.1:18789 conn=dfb93544…a7ea [39m
[90m2026-05-14T07:52:05.427+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=dfb93544-2d25-4966-b532-b00c211fa7ea peer=127.0.0.1:55796->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:52:05.439+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=129 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e3def18e-0de2-4039-bac3-a0e6d13766b4 endpoint=127.0.0.1:55796->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:52:20.286+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=59938 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:59938->127.0.0.1:18789 conn=fffa410e…d396 [39m
[90m2026-05-14T07:52:20.497+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fffa410e-6e26-402b-a496-1cc5b2dad396 peer=127.0.0.1:59938->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:52:20.516+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=185 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=6874a233-35dd-4cf8-9c7d-854f891177ef endpoint=127.0.0.1:59938->127.0.0.1:18789 [39m
[90m2026-05-14T07:52:22.672+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:52:50.280+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40446 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40446->127.0.0.1:18789 conn=9039a7a9…9365 [39m
[90m2026-05-14T07:52:50.426+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9039a7a9-81ba-4aae-88cc-ec22261a9365 peer=127.0.0.1:40446->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:52:50.438+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=132 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=459a200a-b467-4563-8527-e25e0eb3a158 endpoint=127.0.0.1:40446->127.0.0.1:18789 [39m
[90m2026-05-14T07:52:52.661+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:53:05.299+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40046 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40046->127.0.0.1:18789 conn=ab827018…815c [39m
[90m2026-05-14T07:53:05.486+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ab827018-e86a-4945-b48b-5130bd36815c peer=127.0.0.1:40046->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:53:05.504+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=165 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=5bb5f039-ff9c-4674-94dd-c5b779598fb3 endpoint=127.0.0.1:40046->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:53:20.287+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48602 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48602->127.0.0.1:18789 conn=ec75ee17…113f [39m
[90m2026-05-14T07:53:20.523+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=ec75ee17-a64f-4c1b-855d-dc8215f2113f peer=127.0.0.1:48602->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:53:20.542+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=202 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0c4484a7-a1d2-492e-b635-91c5133e10d1 endpoint=127.0.0.1:48602->127.0.0.1:18789 [39m
[90m2026-05-14T07:53:22.676+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:53:50.292+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56412 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56412->127.0.0.1:18789 conn=44311d5c…cda8 [39m
[90m2026-05-14T07:53:50.496+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=44311d5c-d9e4-433b-999d-c5318dafcda8 peer=127.0.0.1:56412->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:53:50.508+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=182 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4eefa0bc-5783-4b54-92c2-ca0e3ff7b0db endpoint=127.0.0.1:56412->127.0.0.1:18789 [39m
[90m2026-05-14T07:53:52.677+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=57.8 eventLoopDelayMaxMs=24226.3 eventLoopUtilization=0.834 cpuCoreRatio=0.398 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:53:52.696+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:54:05.301+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41348 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41348->127.0.0.1:18789 conn=4be01e92…e249 [39m
[90m2026-05-14T07:54:05.504+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=4be01e92-a1e1-4ab9-b66f-c4916c84e249 peer=127.0.0.1:41348->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:54:05.521+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=185 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=e6b8d64e-cccf-49a5-9dd9-0e15245e9df9 endpoint=127.0.0.1:41348->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:54:20.271+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48766 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48766->127.0.0.1:18789 conn=c0cf6454…a4d2 [39m
[90m2026-05-14T07:54:20.495+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c0cf6454-8569-4177-83af-72d5eae5a4d2 peer=127.0.0.1:48766->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:54:20.508+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=182 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d74cb360-543c-4d2b-a96a-24ac9b870f4b endpoint=127.0.0.1:48766->127.0.0.1:18789 [39m
[90m2026-05-14T07:54:22.681+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:54:37.133+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36972 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36972->127.0.0.1:18789 conn=5be3e1e0…56c9 [39m
[90m2026-05-14T07:54:37.383+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=5be3e1e0-0763-45ee-bd12-06506e3e56c9 peer=127.0.0.1:36972->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:54:37.396+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=217 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=889d858a-75d7-4f20-8cea-52b66f3c84ab endpoint=127.0.0.1:36972->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:54:50.271+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33272 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33272->127.0.0.1:18789 conn=7ca8b82f…ddce [39m
[90m2026-05-14T07:54:50.414+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=7ca8b82f-fac7-43ea-af36-fd40cd5cddce peer=127.0.0.1:33272->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:54:50.424+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=122 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=48c94768-9217-4d97-a7a7-105d9f05b9dd endpoint=127.0.0.1:33272->127.0.0.1:18789 [39m
[90m2026-05-14T07:54:52.678+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:55:05.269+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45416 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45416->127.0.0.1:18789 conn=012c22ef…9887 [39m
[90m2026-05-14T07:55:05.450+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=012c22ef-083a-49ae-af8d-9d3ae7a19887 peer=127.0.0.1:45416->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:55:05.462+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=139 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4bed161f-4bfa-4f94-b6b4-4ef7a0cfc465 endpoint=127.0.0.1:45416->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:55:20.274+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40656 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40656->127.0.0.1:18789 conn=57bad12b…d2bb [39m
[90m2026-05-14T07:55:20.435+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=57bad12b-f2f2-4e0c-a04a-9201d3a9d2bb peer=127.0.0.1:40656->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:55:20.451+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=143 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c1b236e0-6726-4e7c-8d31-76390f987ab0 endpoint=127.0.0.1:40656->127.0.0.1:18789 [39m
[90m2026-05-14T07:55:22.683+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:55:50.262+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=33536 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:33536->127.0.0.1:18789 conn=606efd33…8bb8 [39m
[90m2026-05-14T07:55:50.365+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=606efd33-2296-4ab6-b683-26e937908bb8 peer=127.0.0.1:33536->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:55:50.377+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=98 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4672dac5-251e-40c8-89d0-e6ad6964456f endpoint=127.0.0.1:33536->127.0.0.1:18789 [39m
[90m2026-05-14T07:55:52.678+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=35.3 eventLoopDelayMaxMs=21089 eventLoopUtilization=0.724 cpuCoreRatio=0.274 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:229ms,sidecars.subagent-recovery:261ms,sidecars.session-locks:287ms,post-ready.maintenance:11644ms [39m
[90m2026-05-14T07:55:52.685+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:56:05.255+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=39804 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39804->127.0.0.1:18789 conn=fb09a26d…92ed [39m
[90m2026-05-14T07:56:05.485+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=fb09a26d-d049-43d7-86ea-8a99c93092ed peer=127.0.0.1:39804->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) [39m
[90m2026-05-14T07:56:05.504+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 1aa5e7cf-e3f7-499e-b8f1-3e757cf6a1a7) durationMs=185 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=4a89796a-6901-447f-9cb6-e950eb52a9ea endpoint=127.0.0.1:39804->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:56:21.272+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46480 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46480->127.0.0.1:18789 conn=7765c559…1b57 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:57:14.978+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-14T07:57:15.175+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-14T07:57:15.299+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-14T07:57:15.393+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-14T07:57:15.531+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-14T07:57:15.599+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-14T07:57:15.721+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-14T07:57:16.064+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1101.6ms [39m
[90m2026-05-14T07:57:49.520+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-14T07:57:49.529+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 19.2ms [39m
[90m2026-05-14T07:58:41.860+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-14T07:58:44.862+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-14T07:58:45.018+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-14T07:59:10.754+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-14T07:59:12.345+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-14T07:59:12.689+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-14T07:59:14.955+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-14T07:59:15.063+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-14T07:59:15.712+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-14T07:59:15.843+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-14T07:59:22.196+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-14T07:59:22.252+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-14T07:59:22.296+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 7354.9ms [39m
[90m2026-05-14T07:59:22.456+00:00 [39m [36m[gateway] [39m [36magent model: ollama/qwen2.5:0.5b (thinking=medium, fast=off) [39m
[90m2026-05-14T07:59:22.463+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 37.4s) [39m
[90m2026-05-14T07:59:22.473+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-14.log [39m
[90m2026-05-14T07:59:25.114+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-14T07:59:52.056+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-14T07:59:52.062+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=48s eventLoopDelayP99Ms=9537.8 eventLoopDelayMaxMs=24427.6 eventLoopUtilization=0.997 cpuCoreRatio=0.432 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:8ms,post-attach.update-check:60ms,sidecars.model-prewarm:26939ms [39m
[90m2026-05-14T07:59:52.066+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T07:59:52.229+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41176 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41176->127.0.0.1:18789 conn=70dbd8a7…0388 [39m
[90m2026-05-14T07:59:52.414+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56434 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56434->127.0.0.1:18789 conn=d77df737…501b [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T07:59:52.739+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=70dbd8a7-0aa1-4c2d-9432-3f8745c30388 peer=127.0.0.1:41176->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T07:59:52.749+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=498 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=00782e25-2cc1-4fe1-985d-060d56bcac83 endpoint=127.0.0.1:41176->127.0.0.1:18789 conn=70dbd8a7…0388 [39m
[90m2026-05-14T07:59:52.774+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d77df737-1a2d-4101-8897-b0185b3a501b peer=127.0.0.1:56434->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T07:59:52.782+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=345 cause=startup-sidecars-pending handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=b6b76483-ae7e-4750-9271-43834af4691d endpoint=127.0.0.1:56434->127.0.0.1:18789 conn=d77df737…501b [39m
[90m2026-05-14T07:59:53.556+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56440 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56440->127.0.0.1:18789 conn=a294ed0e…b6e7 [39m
[90m2026-05-14T07:59:58.035+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-14T07:59:58.100+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-14T07:59:58.122+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-14T07:59:58.396+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-14T08:00:09.932+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=a294ed0e-87fe-4995-879e-0b010957b6e7 peer=127.0.0.1:56440->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T08:00:09.967+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=a294ed0e-87fe-4995-879e-0b010957b6e7 peer=127.0.0.1:56440->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-05-14T08:00:09.974+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=16407 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:56440->127.0.0.1:18789 [39m
[90m2026-05-14T08:00:15.569+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57912 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57912->127.0.0.1:18789 conn=55d2153b…3922 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T08:00:20.268+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=47418 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:47418->127.0.0.1:18789 conn=12876150…9c04 [39m
[90m2026-05-14T08:00:20.467+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=12876150-5fb0-40f8-9395-27f27fff9c04 peer=127.0.0.1:47418->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T08:00:20.475+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=189 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=dd2b03e7-8025-4adf-ac40-8ff9dc71b4d5 endpoint=127.0.0.1:47418->127.0.0.1:18789 [39m
[90m2026-05-14T08:00:22.076+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-14T08:00:30.602+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=55d2153b-b112-4c7c-99ed-06adeb063922 peer=127.0.0.1:57912->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-14T08:00:30.662+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=55d2153b-b112-4c7c-99ed-06adeb063922 peer=127.0.0.1:57912->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-05-14T08:00:30.671+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=15062 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:57912->127.0.0.1:18789 conn=55d2153b…3922 [39m
[90m2026-05-14T08:00:31.672+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51648 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51648->127.0.0.1:18789 conn=02d43c75…bf78 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-14T08:00:35.312+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51670 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51670->127.0.0.1:18789 conn=329de00a…3f00 [39m
[90m2026-05-14T08:00:35.459+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=329de00a-0d47-4c82-b542-970aa1d03f00 peer=127.0.0.1:51670->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-14T08:00:35.467+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=124 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=422b37b5-7e6a-4a01-8de0-a9ce44379cd8 endpoint=127.0.0.1:51670->127.0.0.1:18789 [39m

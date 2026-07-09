Did gateway restart on canvas skill use?
Cosy <cosychiruka@gmail.com>	Tue, Jun 16, 2026 at 2:22 AM
To: Cosy <cosychiruka@gmail.com>
[native-stdio][startup] [2026-06-13T01:47:12.069Z] stdout: 2026-06-13T03:47:12.067+02:00 [gateway] startup trace: post-attach.update-check 11.9ms total=18272.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-13T01:47:12.093Z] stdout: 2026-06-13T03:47:12.091+02:00 [gateway] startup trace: sidecars.restart-sentinel 284.8ms total=18295.3ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-13T01:47:12.104Z] stdout: 2026-06-13T03:47:12.102+02:00 [gateway] startup trace: post-attach.update-sentinel 142.4ms total=18307.5ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-13T01:47:12.121Z] stdout: 2026-06-13T03:47:12.119+02:00 [gateway] startup trace: sidecars.session-locks 334.7ms total=18323.9ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-13T01:47:14.099Z] stdout: 2026-06-13T03:47:14.097+02:00 [gateway] startup trace: post-ready.maintenance 98.5ms total=20301.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-13T01:47:14.113Z] stdout: 2026-06-13T03:47:14.111+02:00 [gateway] startup trace: memory.post-ready rssMb=503.1 heapTotalMb=325.4 heapUsedMb=291.0 externalMb=5.4 arrayBuffersMb=1.7 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=3.0 activeRequestsCount=1.0 activeTimersCount=4.0
[native-stdio][startup] [2026-06-13T01:47:14.670Z] stderr: 2026-06-13T03:47:14.667+02:00 [gateway] startup model warmup timed out after 5000ms; continuing without waiting
[native-stdio][startup] [2026-06-13T01:47:14.683Z] stdout: 2026-06-13T03:47:14.681+02:00 [gateway] startup trace: sidecars.model-prewarm 6855.7ms total=20883.6ms eventLoopMax=0.0ms
[native-stdio][provider] [2026-06-13T01:47:41.180Z] stdout: 2026-06-13T03:47:41.177+02:00 [gateway] provider auth state pre-warmed in 26532ms eventLoopMax=201.3ms
[native-stdio][warn] [2026-06-13T02:19:24.387Z] stdout: 2026-06-13T04:19:24.331+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=22.9 eventLoopDelayMaxMs=1086.3 eventLoopUtilization=0.051 cpuCoreRatio=0.042 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:11ms,sidecars.restart-sentinel:284ms,post-attach.update-sentinel:142ms,sidecars.session-locks:334ms,post-ready.maintenance:94ms,sidecars.model-prewarm:6855ms
[native-stdio][gateway] [2026-06-13T02:19:24.404Z] stdout: 2026-06-13T04:19:24.400+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:19:54.296Z] stdout: 2026-06-13T04:19:54.289+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:20:24.296Z] stdout: 2026-06-13T04:20:24.291+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:20:54.304Z] stdout: 2026-06-13T04:20:54.294+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:21:24.306Z] stdout: 2026-06-13T04:21:24.299+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][warn] [2026-06-13T02:25:24.304Z] stdout: 2026-06-13T04:25:24.299+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=22.8 eventLoopDelayMaxMs=1310.7 eventLoopUtilization=0.053 cpuCoreRatio=0.04 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:11ms,sidecars.restart-sentinel:284ms,post-attach.update-sentinel:142ms,sidecars.session-locks:334ms,post-ready.maintenance:94ms,sidecars.model-prewarm:6855ms
[native-stdio][gateway] [2026-06-13T02:25:24.325Z] stdout: 2026-06-13T04:25:24.319+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:25:54.306Z] stdout: 2026-06-13T04:25:54.300+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:26:24.309Z] stdout: 2026-06-13T04:26:24.302+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:26:54.312Z] stdout: 2026-06-13T04:26:54.305+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-13T02:27:24.308Z] stdout: 2026-06-13T04:27:24.304+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native] log stream resumed after rotation or runtime restart
[native] log stream resumed after rotation or runtime restart
[native][runtime] 00:24:17.853 terminal library asset copy completed count=4 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/lib (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:18.069 prepared full OpenClaw bundle packageDir=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw launcher=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/openclaw.mjs extractedNow=false entries=30892 files=30892 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:18.081 starting embedded Node full OpenClaw Gateway bootstrap on 127.0.0.1:18789 canaryMode=full-gateway-bootstrap script=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full_gateway_bootstrap.mjs (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:18.097 bridge start result code=0 message=started (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:24.626 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:36.220 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:50.145 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:53.107 stop requested; terminating isolated native Node process activePort=18789 activeMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:24:53.134 service destroyed (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:02.877 start ignored; full Gateway bootstrap already starting or started activePort=18789 requestedPort=18789 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:08.961 skipped unsafe CLI-core asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.118 CLI-core asset copy completed count=6 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.132 skipped unsafe vision-media asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.445 vision-media asset copy completed count=2 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.463 skipped unsafe audio-runtime asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.581 audio-runtime asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/audio-runtime/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.738 python-debug wheel asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/python-debug/wheels (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.755 skipped unsafe terminal asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.795 terminal asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.810 skipped unsafe terminal library asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:11.847 terminal library asset copy completed count=4 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/lib (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:12.044 prepared full OpenClaw bundle packageDir=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw launcher=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/openclaw.mjs extractedNow=false entries=30892 files=30892 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:12.062 starting embedded Node full OpenClaw Gateway bootstrap on 127.0.0.1:18789 canaryMode=full-gateway-bootstrap script=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full_gateway_bootstrap.mjs (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:12.076 bridge start result code=0 message=started (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:16.178 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:29.419 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:25:43.214 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:26:00.863 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:26:08.471 start ignored; embedded Node already running activePort=18789 activeMode=full-gateway-bootstrap requestedPort=18789 requestedMode=full-gateway-bootstrap; duplicate start requests suppressed (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:27:24.460 stop requested; terminating isolated native Node process activePort=18789 activeMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:27:24.479 service destroyed (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:37:32.941 stop requested; terminating isolated native Node process activePort=18790 activeMode=embedded-smoke (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:37:32.963 service destroyed (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:10.362 skipped unsafe CLI-core asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.137 CLI-core asset copy completed count=6 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.151 skipped unsafe vision-media asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.428 vision-media asset copy completed count=2 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.440 skipped unsafe audio-runtime asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.539 audio-runtime asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/audio-runtime/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.658 python-debug wheel asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/python-debug/wheels (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.671 skipped unsafe terminal asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.702 terminal asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.716 skipped unsafe terminal library asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.755 terminal library asset copy completed count=4 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/lib (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.937 prepared full OpenClaw bundle packageDir=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw launcher=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/openclaw.mjs extractedNow=false entries=30892 files=30892 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.948 starting embedded Node full OpenClaw Gateway bootstrap on 127.0.0.1:18789 canaryMode=full-gateway-bootstrap script=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full_gateway_bootstrap.mjs (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 00:39:12.959 bridge start result code=0 message=started (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:18.183 stop requested; terminating isolated native Node process activePort=18790 activeMode=embedded-smoke (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:18.202 service destroyed (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:33.393 skipped unsafe CLI-core asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.040 CLI-core asset copy completed count=6 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.052 skipped unsafe vision-media asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.292 vision-media asset copy completed count=2 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.304 skipped unsafe audio-runtime asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.393 audio-runtime asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/audio-runtime/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.517 python-debug wheel asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/python-debug/wheels (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.532 skipped unsafe terminal asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.567 terminal asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.581 skipped unsafe terminal library asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.615 terminal library asset copy completed count=4 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/lib (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.801 prepared full OpenClaw bundle packageDir=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw launcher=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/openclaw.mjs extractedNow=false entries=30892 files=30892 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.811 starting embedded Node full OpenClaw Gateway bootstrap on 127.0.0.1:18789 canaryMode=full-gateway-bootstrap script=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full_gateway_bootstrap.mjs (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 03:46:35.822 bridge start result code=0 message=started (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:00.880 skipped unsafe CLI-core asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:02.543 CLI-core asset copy completed count=6 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:02.556 skipped unsafe vision-media asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:02.811 vision-media asset copy completed count=2 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:02.821 skipped unsafe audio-runtime asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:02.918 audio-runtime asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/audio-runtime/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.034 python-debug wheel asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/python-debug/wheels (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.046 skipped unsafe terminal asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.077 terminal asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.089 skipped unsafe terminal library asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.118 terminal library asset copy completed count=4 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/lib (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.264 prepared full OpenClaw bundle packageDir=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw launcher=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/openclaw.mjs extractedNow=false entries=30892 files=30892 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.273 starting embedded Node full OpenClaw Gateway bootstrap on 127.0.0.1:18789 canaryMode=full-gateway-bootstrap script=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full_gateway_bootstrap.mjs (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:05:03.284 bridge start result code=0 message=started (com.nxg.openclawproot:native_node_smoke)
[native-stdio][gateway] [2026-06-16T00:05:03.992Z] stderr: [NATIVE-NODE-FULL-GATEWAY] launching mobile-safe runCli gateway run on 127.0.0.1:18789
[native-stdio][startup] [2026-06-16T00:05:04.485Z] stderr: [gateway] startup trace: cli.main.argv 5.1ms total=5.1ms
[native-stdio][startup] [2026-06-16T00:05:05.586Z] stderr: [gateway] startup trace: cli.main.dotenv 1099.2ms total=1106.6ms
[native-stdio][gateway] [2026-06-16T00:05:11.906Z] stderr: Your OpenClaw config was written by version 2026.6.5, but this command is running 2026.5.28.
[native-stdio][gateway] Check: `openclaw --version`, `which openclaw`, and `openclaw gateway status --deep`.
[native-stdio][gateway] If unexpected, update PATH so `openclaw` points to the version you want, or reinstall the Gateway service from that same OpenClaw install.
[native-stdio][startup] [2026-06-16T00:05:12.988Z] stderr: [gateway] startup trace: cli.main.gateway-run-imports 199.0ms total=8508.0ms
[native-stdio][startup] [2026-06-16T00:05:13.485Z] stdout: [gateway] startup trace: cli.server-import 21.1ms total=21.4ms
[native-stdio][gateway] [2026-06-16T00:05:13.535Z] stdout: 2026-06-16T02:05:13.532+02:00 [gateway] loading configuration…
[native-stdio][startup] [2026-06-16T00:05:14.030Z] stdout: 2026-06-16T02:05:14.028+02:00 [gateway] startup trace: cli.config-snapshot 424.4ms total=743.4ms
[native-stdio][gateway] [2026-06-16T00:05:14.076Z] stdout: 2026-06-16T02:05:14.074+02:00 [gateway] resolving authentication…
[native-stdio][startup] [2026-06-16T00:05:14.186Z] stdout: 2026-06-16T02:05:14.182+02:00 [gateway] startup trace: cli.auth-resolve 3.8ms total=895.7ms
[native-stdio][gateway] [2026-06-16T00:05:14.258Z] stdout: 2026-06-16T02:05:14.255+02:00 [gateway] starting...
[native-stdio][startup] [2026-06-16T00:05:14.276Z] stdout: 2026-06-16T02:05:14.273+02:00 [gateway] startup trace: cli.gateway-loop 92.2ms total=987.9ms
[native-stdio][startup] [2026-06-16T00:05:21.784Z] stderr: [gateway] startup trace: gateway.server-impl-import 1109.7ms total=1109.7ms
[native-stdio][startup] [2026-06-16T00:05:22.169Z] stdout: 2026-06-16T02:05:22.167+02:00 [gateway] startup trace: config.snapshot.auto-enable 77.0ms total=281.6ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:22.206Z] stdout: 2026-06-16T02:05:22.203+02:00 [gateway] auto-enabled plugins for this runtime without writing config:
[native-stdio][provider] - openrouter/openai/gpt-oss-20b:free model configured, enabled automatically.
[native-stdio][startup] [2026-06-16T00:05:22.239Z] stdout: 2026-06-16T02:05:22.237+02:00 [gateway] startup trace: config.snapshot 172.1ms total=374.4ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.272Z] stdout: 2026-06-16T02:05:22.270+02:00 [gateway] startup trace: config.auth.snapshot-validate 1.4ms total=410.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.302Z] stdout: 2026-06-16T02:05:22.300+02:00 [gateway] startup trace: config.auth.runtime-overrides 2.0ms total=441.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.330Z] stdout: 2026-06-16T02:05:22.327+02:00 [gateway] startup trace: config.auth.startup-overrides 1.2ms total=469.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.372Z] stdout: 2026-06-16T02:05:22.369+02:00 [gateway] startup trace: config.auth.secret-surface 6.2ms total=502.5ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.445Z] stdout: 2026-06-16T02:05:22.419+02:00 [gateway] startup trace: config.auth.secret-preflight 1.9ms total=540.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.482Z] stdout: 2026-06-16T02:05:22.456+02:00 [gateway] startup trace: config.auth.preflight-override 1.3ms total=613.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.535Z] stdout: 2026-06-16T02:05:22.506+02:00 [gateway] startup trace: config.auth.ensure 4.6ms total=653.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:22.568Z] stdout: 2026-06-16T02:05:22.566+02:00 [gateway] startup trace: config.auth.runtime-startup-overrides 10.6ms total=713.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:23.011Z] stdout: 2026-06-16T02:05:23.008+02:00 [gateway] startup trace: config.auth.secrets-activate 405.8ms total=1165.4ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:23.025Z] stdout: 2026-06-16T02:05:23.022+02:00 [gateway] startup trace: config.auth 771.4ms total=1178.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:23.051Z] stdout: 2026-06-16T02:05:23.048+02:00 [gateway] startup trace: control-ui.seed 3.8ms total=1202.3ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:25.260Z] stdout: 2026-06-16T02:05:25.256+02:00 [gateway] startup trace: plugins.bootstrap 422.4ms total=3414.5ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:25.278Z] stdout: 2026-06-16T02:05:25.275+02:00 [gateway] startup trace: plugins.lookup-table registrySnapshotMs=2.3 manifestRegistryMs=125.0 startupPlanMs=286.9 ownerMapsMs=1.7 totalMs=424.3 indexPlugins=92 indexPluginCount=92.0 manifestPlugins=92 manifestPluginCount=92.0 startupPlugins=12 startupPluginCount=12.0 deferredChannelPlugins=0 deferredChannelPluginCount=0.0
[native-stdio][startup] [2026-06-16T00:05:25.346Z] stdout: 2026-06-16T02:05:25.343+02:00 [gateway] startup trace: runtime.config 54.7ms total=3500.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:25.367Z] stdout: 2026-06-16T02:05:25.366+02:00 [gateway] startup trace: control-ui.root 3.9ms total=3521.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:25.383Z] stdout: 2026-06-16T02:05:25.381+02:00 [gateway] startup trace: tls.runtime 1.8ms total=3537.0ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:05:25.676Z] stdout: 2026-06-16T02:05:25.673+02:00 [gateway] starting HTTP server...
[native-stdio][startup] [2026-06-16T00:05:25.704Z] stdout: 2026-06-16T02:05:25.702+02:00 [gateway] startup trace: runtime.state 14.0ms total=3856.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:25.776Z] stdout: 2026-06-16T02:05:25.773+02:00 [gateway] startup trace: runtime.early.discovery.machine-name 14.6ms total=3930.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:25.824Z] stdout: 2026-06-16T02:05:25.820+02:00 [gateway] startup trace: runtime.early.discovery.start 33.9ms total=3977.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:25.846Z] stdout: 2026-06-16T02:05:25.843+02:00 [gateway] startup trace: runtime.early.discovery 78.8ms total=3994.4ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.048Z] stdout: 2026-06-16T02:05:26.046+02:00 [gateway] startup trace: runtime.early.lazy-runtime-imports 190.0ms total=4202.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.146Z] stdout: 2026-06-16T02:05:26.143+02:00 [gateway] startup trace: runtime.early.skills-listener 44.7ms total=4300.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.157Z] stdout: 2026-06-16T02:05:26.156+02:00 [gateway] startup trace: runtime.early 409.8ms total=4313.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.209Z] stdout: 2026-06-16T02:05:26.206+02:00 [gateway] startup trace: runtime.post-early-imports 38.9ms total=4363.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.226Z] stdout: 2026-06-16T02:05:26.223+02:00 [gateway] startup trace: runtime.subscriptions 3.6ms total=4379.5ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.244Z] stdout: 2026-06-16T02:05:26.241+02:00 [health-monitor] started (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s)
[native-stdio][startup] [2026-06-16T00:05:26.264Z] stdout: 2026-06-16T02:05:26.260+02:00 [gateway] startup trace: runtime.services 20.3ms total=4413.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.653Z] stdout: 2026-06-16T02:05:26.651+02:00 [gateway] startup trace: gateway.handlers 373.8ms total=4804.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.694Z] stdout: 2026-06-16T02:05:26.691+02:00 [gateway] startup trace: gateway.request-context 13.3ms total=4844.3ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.842Z] stdout: 2026-06-16T02:05:26.839+02:00 [gateway] startup trace: gateway.ws-imports 128.4ms total=4991.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.865Z] stdout: 2026-06-16T02:05:26.863+02:00 [gateway] startup trace: gateway.ws-attach 5.2ms total=5014.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.892Z] stdout: 2026-06-16T02:05:26.888+02:00 [gateway] startup trace: http.listen 7.6ms total=5040.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:26.909Z] stdout: 2026-06-16T02:05:26.906+02:00 [gateway] startup trace: http.bound 20.2ms total=5060.3ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:27.160Z] stdout: 2026-06-16T02:05:27.156+02:00 [plugins] loading browser from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/browser/index.js
[native-stdio][plugins] [2026-06-16T00:05:27.975Z] stdout: 2026-06-16T02:05:27.973+02:00 [gateway] startup trace: plugins.gateway-load.plugin.browser loadMs=811.1 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.004Z] stdout: 2026-06-16T02:05:28.002+02:00 [gateway] startup trace: plugins.gateway-load.plugin.browser registerMs=6.6 loadAndRegisterMs=817.7 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.030Z] stdout: 2026-06-16T02:05:28.029+02:00 [plugins] loading canvas from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/canvas/index.js
[native-stdio][plugins] [2026-06-16T00:05:28.195Z] stdout: 2026-06-16T02:05:28.192+02:00 [gateway] startup trace: plugins.gateway-load.plugin.canvas loadMs=155.4 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.219Z] stdout: 2026-06-16T02:05:28.217+02:00 [gateway] startup trace: plugins.gateway-load.plugin.canvas registerMs=9.7 loadAndRegisterMs=165.1 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.239Z] stdout: 2026-06-16T02:05:28.237+02:00 [plugins] loading device-pair from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/device-pair/index.js
[native-stdio][plugins] [2026-06-16T00:05:28.297Z] stdout: 2026-06-16T02:05:28.295+02:00 [gateway] startup trace: plugins.gateway-load.plugin.device-pair loadMs=50.8 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.316Z] stdout: 2026-06-16T02:05:28.305+02:00 Registered plugin command: /pair (plugin: device-pair)
[native-stdio][plugins] [2026-06-16T00:05:28.326Z] stdout: 2026-06-16T02:05:28.324+02:00 [gateway] startup trace: plugins.gateway-load.plugin.device-pair registerMs=17.7 loadAndRegisterMs=68.4 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.351Z] stdout: 2026-06-16T02:05:28.349+02:00 [plugins] loading file-transfer from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js
[native-stdio][plugins] [2026-06-16T00:05:28.423Z] stdout: 2026-06-16T02:05:28.421+02:00 [gateway] startup trace: plugins.gateway-load.plugin.file-transfer loadMs=65.3 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.440Z] stdout: 2026-06-16T02:05:28.438+02:00 [gateway] startup trace: plugins.gateway-load.plugin.file-transfer registerMs=2.7 loadAndRegisterMs=68.0 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:28.452Z] stdout: 2026-06-16T02:05:28.450+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:05:31.224Z] stdout: 2026-06-16T02:05:31.222+02:00 [gateway] startup trace: plugins.gateway-load.plugin.google loadMs=2760.6 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:31.267Z] stdout: 2026-06-16T02:05:31.265+02:00 [gateway] startup trace: plugins.gateway-load.plugin.google registerMs=27.1 loadAndRegisterMs=2787.7 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:31.299Z] stdout: 2026-06-16T02:05:31.297+02:00 [plugins] loading memory-core from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/memory-core/index.js
[native-stdio][plugins] [2026-06-16T00:05:31.565Z] stdout: 2026-06-16T02:05:31.563+02:00 [gateway] startup trace: plugins.gateway-load.plugin.memory-core loadMs=256.8 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:31.585Z] stdout: 2026-06-16T02:05:31.575+02:00 Registered plugin command: /dreaming (plugin: memory-core)
[native-stdio][plugins] [2026-06-16T00:05:31.598Z] stdout: 2026-06-16T02:05:31.596+02:00 [gateway] startup trace: plugins.gateway-load.plugin.memory-core registerMs=18.1 loadAndRegisterMs=274.9 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:31.606Z] stdout: 2026-06-16T02:05:31.603+02:00 [plugins] loading microsoft from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft/index.js
[native-stdio][plugins] [2026-06-16T00:05:31.935Z] stdout: 2026-06-16T02:05:31.933+02:00 [gateway] startup trace: plugins.gateway-load.plugin.microsoft loadMs=321.0 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:31.949Z] stdout: 2026-06-16T02:05:31.947+02:00 [gateway] startup trace: plugins.gateway-load.plugin.microsoft registerMs=1.6 loadAndRegisterMs=322.6 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:31.963Z] stdout: 2026-06-16T02:05:31.961+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:05:33.064Z] stdout: 2026-06-16T02:05:33.063+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openai loadMs=1091.0 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.089Z] stdout: 2026-06-16T02:05:33.087+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openai registerMs=12.2 loadAndRegisterMs=1103.2 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.101Z] stdout: 2026-06-16T02:05:33.099+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:05:33.368Z] stdout: 2026-06-16T02:05:33.366+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openrouter loadMs=258.1 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.391Z] stdout: 2026-06-16T02:05:33.389+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openrouter registerMs=7.5 loadAndRegisterMs=265.5 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.400Z] stdout: 2026-06-16T02:05:33.398+02:00 [plugins] loading phone-control from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/phone-control/index.js
[native-stdio][plugins] [2026-06-16T00:05:33.475Z] stdout: 2026-06-16T02:05:33.473+02:00 [gateway] startup trace: plugins.gateway-load.plugin.phone-control loadMs=67.2 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.490Z] stdout: 2026-06-16T02:05:33.480+02:00 Registered plugin command: /phone (plugin: phone-control)
[native-stdio][plugins] [2026-06-16T00:05:33.502Z] stdout: 2026-06-16T02:05:33.500+02:00 [gateway] startup trace: plugins.gateway-load.plugin.phone-control registerMs=13.1 loadAndRegisterMs=80.4 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.509Z] stdout: 2026-06-16T02:05:33.507+02:00 [plugins] loading talk-voice from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js
[native-stdio][plugins] [2026-06-16T00:05:33.591Z] stdout: 2026-06-16T02:05:33.587+02:00 [gateway] startup trace: plugins.gateway-load.plugin.talk-voice loadMs=69.9 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.608Z] stdout: 2026-06-16T02:05:33.596+02:00 Registered plugin command: /voice (plugin: talk-voice)
[native-stdio][plugins] [2026-06-16T00:05:33.622Z] stdout: 2026-06-16T02:05:33.620+02:00 [gateway] startup trace: plugins.gateway-load.plugin.talk-voice registerMs=16.3 loadAndRegisterMs=86.2 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:33.645Z] stdout: 2026-06-16T02:05:33.642+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:05:37.872Z] stdout: 2026-06-16T02:05:37.870+02:00 [gateway] startup trace: plugins.gateway-load.plugin.xai loadMs=4222.3 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:37.896Z] stdout: 2026-06-16T02:05:37.893+02:00 [gateway] startup trace: plugins.gateway-load.plugin.xai registerMs=11.1 loadAndRegisterMs=4233.4 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:37.900Z] stdout: 2026-06-16T02:05:37.898+02:00 [plugins] loaded 12 plugin(s) (12 attempted) in 10762.0ms
[native-stdio][plugins] [2026-06-16T00:05:37.918Z] stdout: 2026-06-16T02:05:37.916+02:00 [gateway] startup trace: plugins.gateway-load autoEnableMs=0.0 resolvedConfigMs=0.1 pluginIdsMs=0.1 loadMs=10822.2 pluginIds=12 pluginCount=12.0 gatewayHandlers=1 gatewayHandlerCount=1.0 loaderCallsCount=12.0 loaderNativeHitsCount=12.0 loaderNativeMissesCount=0.0 loaderSourceTransformForcedCount=0.0 loaderSourceTransformFallbacksCount=0.0 loaderTopSourceTransformTargets=
[native-stdio][plugins] [2026-06-16T00:05:37.934Z] stdout: 2026-06-16T02:05:37.932+02:00 [gateway] startup trace: plugins.runtime-post-bind 10971.7ms total=16087.1ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:37.945Z] stdout: 2026-06-16T02:05:37.942+02:00 [gateway] startup trace: plugins.runtime-post-bind loadedPluginCount=12.0 gatewayMethodCount=177.0
[native-stdio][provider] [2026-06-16T00:05:38.031Z] stdout: 2026-06-16T02:05:38.029+02:00 [gateway] agent model: openrouter/openai/gpt-oss-20b:free (thinking=medium, fast=off)
[native-stdio][plugins] [2026-06-16T00:05:38.044Z] stdout: 2026-06-16T02:05:38.039+02:00 [gateway] http server listening (12 plugins: browser, canvas, device-pair, file-transfer, google, memory-core, microsoft, openai, openrouter, phone-control, talk-voice, xai; 23.7s)
[native-stdio][gateway] [2026-06-16T00:05:38.055Z] stdout: 2026-06-16T02:05:38.053+02:00 [gateway] log file: /data/user/0/com.nxg.openclawproot/files/native-node-embedded/tmp/openclaw/openclaw-2026-06-16.log
[native-stdio][startup] [2026-06-16T00:05:38.071Z] stdout: 2026-06-16T02:05:38.069+02:00 [gateway] startup trace: post-attach.log 107.0ms total=16225.3ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:05:38.097Z] stdout: 2026-06-16T02:05:38.095+02:00 [gateway] starting channels and sidecars...
[native-stdio][startup] [2026-06-16T00:05:38.114Z] stdout: 2026-06-16T02:05:38.111+02:00 [gateway] startup trace: sidecars.internal-hooks 1.1ms total=16267.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:38.151Z] stdout: 2026-06-16T02:05:38.148+02:00 [gateway] startup trace: sidecars.channel-start 9.3ms total=16301.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:38.167Z] stdout: 2026-06-16T02:05:38.165+02:00 [gateway] startup trace: sidecars.channels 36.7ms total=16318.0ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:38.231Z] stdout: 2026-06-16T02:05:38.229+02:00 [gateway] startup trace: sidecars.plugin-services.browser.browser-control 7.1ms total=16384.2ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:38.281Z] stdout: 2026-06-16T02:05:38.279+02:00 [gateway] startup trace: sidecars.plugin-services.canvas.canvas-host 27.4ms total=16436.0ms eventLoopMax=0.0ms
[INFO] Connecting WebSocket...
[native-stdio][ws] [2026-06-16T00:05:39.733Z] stdout: 2026-06-16T02:05:39.731+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=39550 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39550->127.0.0.1:18789 conn=00e386a5…26c9
[native-stdio][plugins] [2026-06-16T00:05:40.066Z] stdout: 2026-06-16T02:05:40.064+02:00 [gateway] startup trace: sidecars.plugin-services.device-pair.device-pair-notifier 1770.6ms total=18219.0ms eventLoopMax=490.2ms
[native-stdio][plugins] [2026-06-16T00:05:40.085Z] stdout: 2026-06-16T02:05:40.083+02:00 [gateway] startup trace: sidecars.plugin-services.phone-control.phone-control-expiry 4.4ms total=18238.1ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:40.097Z] stdout: 2026-06-16T02:05:40.095+02:00 [gateway] startup trace: sidecars.plugin-services.summary serviceCount=4.0 startedCount=4.0 failedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:40.108Z] stdout: 2026-06-16T02:05:40.105+02:00 [gateway] startup trace: sidecars.plugin-services 1928.4ms total=18264.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:40.135Z] stdout: 2026-06-16T02:05:40.133+02:00 [gateway] startup trace: sidecars.memory 1.9ms total=18287.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:40.147Z] stdout: 2026-06-16T02:05:40.145+02:00 [gateway] startup trace: sidecars.total 2039.7ms total=18303.8ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:40.159Z] stdout: 2026-06-16T02:05:40.157+02:00 [gateway] startup trace: sidecars.plugin-loader callsCount=0.0 nativeHitsCount=0.0 nativeMissesCount=0.0 sourceTransformForcedCount=0.0 sourceTransformFallbacksCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:40.182Z] stdout: 2026-06-16T02:05:40.180+02:00 [gateway] startup trace: sidecars.ready loadedPluginCount=12.0 postReadySidecarCount=1.0
[native-stdio][startup] [2026-06-16T00:05:40.192Z] stdout: 2026-06-16T02:05:40.190+02:00 [gateway] startup trace: sidecars.ready 44.8ms total=18348.7ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:05:40.206Z] stdout: 2026-06-16T02:05:40.203+02:00 [gateway] ready
[native-stdio][startup] [2026-06-16T00:05:40.259Z] stdout: 2026-06-16T02:05:40.256+02:00 [gateway] startup trace: runtime.post-attach 13336.0ms total=18412.3ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:40.273Z] stdout: 2026-06-16T02:05:40.271+02:00 [gateway] startup trace: memory.ready rssMb=446.4 heapTotalMb=278.0 heapUsedMb=221.0 externalMb=5.0 arrayBuffersMb=1.2 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=3.0 activeRequestsCount=2.0 activeTimersCount=1.0
[native-stdio][startup] [2026-06-16T00:05:40.285Z] stdout: 2026-06-16T02:05:40.283+02:00 [gateway] startup trace: ready 27.3ms total=18439.6ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:05:42.576Z] stdout: 2026-06-16T02:05:42.574+02:00 [heartbeat] started
[native-stdio][startup] [2026-06-16T00:05:42.829Z] stdout: 2026-06-16T02:05:42.825+02:00 [gateway] startup trace: sidecars.subagent-recovery 90.2ms total=20976.9ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:42.929Z] stdout: 2026-06-16T02:05:42.927+02:00 [gateway] startup trace: sidecars.main-session-recovery 56.1ms total=21086.7ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:42.947Z] stdout: 2026-06-16T02:05:42.945+02:00 [plugins] [hooks] running gateway_start (1 handlers)
[native-stdio][startup] [2026-06-16T00:05:43.069Z] stdout: 2026-06-16T02:05:43.067+02:00 [gateway] startup trace: post-attach.update-check 12.9ms total=21218.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.101Z] stdout: 2026-06-16T02:05:43.098+02:00 [gateway] startup trace: sidecars.restart-sentinel 367.5ms total=21252.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.116Z] stdout: 2026-06-16T02:05:43.114+02:00 [gateway] startup trace: post-attach.update-sentinel 172.9ms total=21268.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.194Z] stderr: 2026-06-16T02:05:43.191+02:00 [gateway] startup model warmup timed out after 5000ms; continuing without waiting
[native-stdio][startup] [2026-06-16T00:05:43.206Z] stdout: 2026-06-16T02:05:43.204+02:00 [gateway] startup trace: sidecars.model-prewarm 5078.6ms total=21361.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.223Z] stdout: 2026-06-16T02:05:43.221+02:00 [gateway] startup trace: sidecars.session-locks 520.1ms total=21377.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:46.024Z] stdout: 2026-06-16T02:05:46.021+02:00 [gateway] startup trace: post-ready.maintenance 94.4ms total=24178.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:46.038Z] stdout: 2026-06-16T02:05:46.036+02:00 [gateway] startup trace: memory.post-ready rssMb=457.8 heapTotalMb=296.2 heapUsedMb=272.3 externalMb=5.0 arrayBuffersMb=1.3 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=6.0 activeRequestsCount=3.0 activeTimersCount=5.0
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[INFO] Health RPC: ok=true
[native-stdio][gateway] [2026-06-16T00:05:47.601Z] stderr: 2026-06-16T02:05:47.599+02:00 [fetch-timeout] fetch timeout after 2500ms (elapsed 4147ms) timer delayed 1647ms, likely event-loop starvation operation=fetchWithTimeout url=https://registry.npmjs.org/openclaw/latest
[native-stdio][ws] [2026-06-16T00:05:47.682Z] stdout: 2026-06-16T02:05:47.679+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=ui clientId=openclaw-control-ui platform=android auth=token
[native-stdio][ws] [2026-06-16T00:05:47.703Z] stdout: 2026-06-16T02:05:47.701+02:00 [ws] → hello-ok methods=177 events=27 presence=2 stateVersion=2
[native-stdio][ws] [2026-06-16T00:05:48.454Z] stdout: 2026-06-16T02:05:48.452+02:00 [ws] ⇄ res ✓ health 473ms cached=true id=cc36ae9c…8b11
[INFO] Active skills: 1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli, browser-automation, camsnap, canvas, clawhub, coding-agent, device-node, diagram-maker, discord, eightctl, gemini, gestures, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya, imsg, mcporter, meme-maker, model-usage, nano-pdf, node-connect, node-inspect-debugger, notion, obsidian, openai-whisper, openai-whisper-api, openhue, oracle, ordercli, peekaboo, python-debugpy, sag, session-logs, sherpa-onnx-tts, skill-creator, slack, songsee, sonoscli, spike, spotify-player, stocks, summarize, taskflow, taskflow-inbox-triage, things-mac, tmux, trello, tts-voice, video-frames, voice-call, wacli, weather, xurl
[native-stdio][skills] [2026-06-16T00:05:50.302Z] stdout: 2026-06-16T02:05:50.300+02:00 [ws] ⇄ res ✓ skills.status 1571ms id=fa57aee7…4b75
[native-stdio][ws] [2026-06-16T00:05:50.481Z] stdout: 2026-06-16T02:05:50.478+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=34180 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34180->127.0.0.1:18789 conn=24074254…a6ad
[native-stdio][ws] [2026-06-16T00:05:51.341Z] stdout: 2026-06-16T02:05:51.337+02:00 [ws] → event node.pair.requested seq=per-client clients=1 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:05:51.384Z] stdout: 2026-06-16T02:05:51.378+02:00 [ws] ← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.28 mode=node clientId=node-host platform=android auth=token
[native-stdio][ws] [2026-06-16T00:05:51.465Z] stdout: 2026-06-16T02:05:51.455+02:00 [ws] → hello-ok methods=177 events=27 presence=3 stateVersion=3
[native-stdio][provider] [2026-06-16T00:06:12.840Z] stdout: 2026-06-16T02:06:12.837+02:00 [gateway] provider auth state pre-warmed in 26940ms eventLoopMax=1642.1ms
[native-stdio][warn] [2026-06-16T00:07:53.107Z] stdout: 2026-06-16T02:07:53.079+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=27.3 eventLoopDelayMaxMs=2070.9 eventLoopUtilization=0.087 cpuCoreRatio=0.051 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:07:53.127Z] stdout: 2026-06-16T02:07:53.121+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:08:23.046Z] stdout: 2026-06-16T02:08:23.042+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:08:53.048Z] stdout: 2026-06-16T02:08:53.043+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:09:23.043Z] stdout: 2026-06-16T02:09:23.040+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:09:53.054Z] stdout: 2026-06-16T02:09:53.049+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:12:23.053Z] stdout: 2026-06-16T02:12:23.050+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.7 eventLoopDelayMaxMs=1098.9 eventLoopUtilization=0.01 cpuCoreRatio=0.012 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:12:23.061Z] stdout: 2026-06-16T02:12:23.059+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:12:53.048Z] stdout: 2026-06-16T02:12:53.046+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:13:23.049Z] stdout: 2026-06-16T02:13:23.047+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:13:53.060Z] stdout: 2026-06-16T02:13:53.052+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:14:23.056Z] stdout: 2026-06-16T02:14:23.051+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:14:50.369Z] stdout: 2026-06-16T02:14:50.366+02:00 [ws] → event heartbeat seq=per-client clients=2 dropIfSlow=true
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:16:12.002Z] stdout: 2026-06-16T02:16:11.999+02:00 [ws] ⇄ res ✓ agents.list 339ms conn=00e386a5…26c9 id=4a3f15c7…4bca
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:16:25.440Z] stdout: 2026-06-16T02:16:25.438+02:00 [plugins] loading azure-speech from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/azure-speech/index.js
[native-stdio][plugins] [2026-06-16T00:16:25.639Z] stdout: 2026-06-16T02:16:25.637+02:00 [plugins] loading deepinfra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js
[native-stdio][plugins] [2026-06-16T00:16:25.984Z] stdout: 2026-06-16T02:16:25.983+02:00 [plugins] loading elevenlabs from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/elevenlabs/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:16:26.206Z] stdout: 2026-06-16T02:16:26.204+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:16:26.244Z] stdout: 2026-06-16T02:16:26.241+02:00 [plugins] loading gradium from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/gradium/index.js
[native-stdio][plugins] [2026-06-16T00:16:26.902Z] stdout: 2026-06-16T02:16:26.898+02:00 [plugins] loading inworld from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/inworld/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.090Z] stdout: 2026-06-16T02:16:27.088+02:00 [plugins] loading microsoft from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.130Z] stdout: 2026-06-16T02:16:27.128+02:00 [plugins] loading minimax from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/minimax/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.491Z] stdout: 2026-06-16T02:16:27.488+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.519Z] stdout: 2026-06-16T02:16:27.517+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.544Z] stdout: 2026-06-16T02:16:27.542+02:00 [plugins] loading tts-local-cli from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/tts-local-cli/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.651Z] stdout: 2026-06-16T02:16:27.649+02:00 [plugins] loading volcengine from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/volcengine/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.778Z] stdout: 2026-06-16T02:16:27.775+02:00 [plugins] loading vydra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vydra/index.js
[native-stdio][plugins] [2026-06-16T00:16:28.082Z] stdout: 2026-06-16T02:16:28.080+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:16:28.145Z] stdout: 2026-06-16T02:16:28.143+02:00 [plugins] loading xiaomi from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:16:28.308Z] stdout: 2026-06-16T02:16:28.305+02:00 [plugins] loaded 15 plugin(s) (15 attempted) in 2884.2ms
[native-stdio][provider] [2026-06-16T00:16:28.462Z] stdout: 2026-06-16T02:16:28.459+02:00 [ws] ⇄ res ✓ tts.providers 4252ms id=b2c38b3e…6a76
[native-stdio][ws] [2026-06-16T00:16:28.485Z] stdout: 2026-06-16T02:16:28.482+02:00 [ws] ⇄ res ✓ tts.personas 6ms id=f0ec7dfe…921b
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:16:30.339Z] stdout: 2026-06-16T02:16:30.337+02:00 [ws] ⇄ res ✓ talk.catalog 1828ms id=099dd8f5…7c84
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:16:38.126Z] stdout: 2026-06-16T02:16:38.115+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:16:43.105Z] stdout: 2026-06-16T02:16:43.101+02:00 [ws] ⇄ res ✓ talk.speak 5082ms id=e4466754…2e9e
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:16:53.090Z] stdout: 2026-06-16T02:16:53.084+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=43.5 eventLoopDelayMaxMs=4288.7 eventLoopUtilization=0.304 cpuCoreRatio=0.351 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:16:53.106Z] stdout: 2026-06-16T02:16:53.102+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[native-stdio][startup] [2026-06-16T00:05:38.071Z] stdout: 2026-06-16T02:05:38.069+02:00 [gateway] startup trace: post-attach.log 107.0ms total=16225.3ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:05:38.097Z] stdout: 2026-06-16T02:05:38.095+02:00 [gateway] starting channels and sidecars...
[native-stdio][startup] [2026-06-16T00:05:38.114Z] stdout: 2026-06-16T02:05:38.111+02:00 [gateway] startup trace: sidecars.internal-hooks 1.1ms total=16267.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:38.151Z] stdout: 2026-06-16T02:05:38.148+02:00 [gateway] startup trace: sidecars.channel-start 9.3ms total=16301.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:38.167Z] stdout: 2026-06-16T02:05:38.165+02:00 [gateway] startup trace: sidecars.channels 36.7ms total=16318.0ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:38.231Z] stdout: 2026-06-16T02:05:38.229+02:00 [gateway] startup trace: sidecars.plugin-services.browser.browser-control 7.1ms total=16384.2ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:38.281Z] stdout: 2026-06-16T02:05:38.279+02:00 [gateway] startup trace: sidecars.plugin-services.canvas.canvas-host 27.4ms total=16436.0ms eventLoopMax=0.0ms
[native-stdio][ws] [2026-06-16T00:05:39.733Z] stdout: 2026-06-16T02:05:39.731+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=39550 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39550->127.0.0.1:18789 conn=00e386a5…26c9
[native-stdio][plugins] [2026-06-16T00:05:40.066Z] stdout: 2026-06-16T02:05:40.064+02:00 [gateway] startup trace: sidecars.plugin-services.device-pair.device-pair-notifier 1770.6ms total=18219.0ms eventLoopMax=490.2ms
[native-stdio][plugins] [2026-06-16T00:05:40.085Z] stdout: 2026-06-16T02:05:40.083+02:00 [gateway] startup trace: sidecars.plugin-services.phone-control.phone-control-expiry 4.4ms total=18238.1ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:40.097Z] stdout: 2026-06-16T02:05:40.095+02:00 [gateway] startup trace: sidecars.plugin-services.summary serviceCount=4.0 startedCount=4.0 failedCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:40.108Z] stdout: 2026-06-16T02:05:40.105+02:00 [gateway] startup trace: sidecars.plugin-services 1928.4ms total=18264.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:40.135Z] stdout: 2026-06-16T02:05:40.133+02:00 [gateway] startup trace: sidecars.memory 1.9ms total=18287.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:40.147Z] stdout: 2026-06-16T02:05:40.145+02:00 [gateway] startup trace: sidecars.total 2039.7ms total=18303.8ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:40.159Z] stdout: 2026-06-16T02:05:40.157+02:00 [gateway] startup trace: sidecars.plugin-loader callsCount=0.0 nativeHitsCount=0.0 nativeMissesCount=0.0 sourceTransformForcedCount=0.0 sourceTransformFallbacksCount=0.0
[native-stdio][plugins] [2026-06-16T00:05:40.182Z] stdout: 2026-06-16T02:05:40.180+02:00 [gateway] startup trace: sidecars.ready loadedPluginCount=12.0 postReadySidecarCount=1.0
[native-stdio][startup] [2026-06-16T00:05:40.192Z] stdout: 2026-06-16T02:05:40.190+02:00 [gateway] startup trace: sidecars.ready 44.8ms total=18348.7ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:05:40.206Z] stdout: 2026-06-16T02:05:40.203+02:00 [gateway] ready
[native-stdio][startup] [2026-06-16T00:05:40.259Z] stdout: 2026-06-16T02:05:40.256+02:00 [gateway] startup trace: runtime.post-attach 13336.0ms total=18412.3ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:40.273Z] stdout: 2026-06-16T02:05:40.271+02:00 [gateway] startup trace: memory.ready rssMb=446.4 heapTotalMb=278.0 heapUsedMb=221.0 externalMb=5.0 arrayBuffersMb=1.2 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=3.0 activeRequestsCount=2.0 activeTimersCount=1.0
[native-stdio][startup] [2026-06-16T00:05:40.285Z] stdout: 2026-06-16T02:05:40.283+02:00 [gateway] startup trace: ready 27.3ms total=18439.6ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:05:42.576Z] stdout: 2026-06-16T02:05:42.574+02:00 [heartbeat] started
[native-stdio][startup] [2026-06-16T00:05:42.829Z] stdout: 2026-06-16T02:05:42.825+02:00 [gateway] startup trace: sidecars.subagent-recovery 90.2ms total=20976.9ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:42.929Z] stdout: 2026-06-16T02:05:42.927+02:00 [gateway] startup trace: sidecars.main-session-recovery 56.1ms total=21086.7ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:05:42.947Z] stdout: 2026-06-16T02:05:42.945+02:00 [plugins] [hooks] running gateway_start (1 handlers)
[native-stdio][startup] [2026-06-16T00:05:43.069Z] stdout: 2026-06-16T02:05:43.067+02:00 [gateway] startup trace: post-attach.update-check 12.9ms total=21218.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.101Z] stdout: 2026-06-16T02:05:43.098+02:00 [gateway] startup trace: sidecars.restart-sentinel 367.5ms total=21252.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.116Z] stdout: 2026-06-16T02:05:43.114+02:00 [gateway] startup trace: post-attach.update-sentinel 172.9ms total=21268.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.194Z] stderr: 2026-06-16T02:05:43.191+02:00 [gateway] startup model warmup timed out after 5000ms; continuing without waiting
[native-stdio][startup] [2026-06-16T00:05:43.206Z] stdout: 2026-06-16T02:05:43.204+02:00 [gateway] startup trace: sidecars.model-prewarm 5078.6ms total=21361.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:43.223Z] stdout: 2026-06-16T02:05:43.221+02:00 [gateway] startup trace: sidecars.session-locks 520.1ms total=21377.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:46.024Z] stdout: 2026-06-16T02:05:46.021+02:00 [gateway] startup trace: post-ready.maintenance 94.4ms total=24178.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:05:46.038Z] stdout: 2026-06-16T02:05:46.036+02:00 [gateway] startup trace: memory.post-ready rssMb=457.8 heapTotalMb=296.2 heapUsedMb=272.3 externalMb=5.0 arrayBuffersMb=1.3 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=6.0 activeRequestsCount=3.0 activeTimersCount=5.0
[native-stdio][gateway] [2026-06-16T00:05:47.601Z] stderr: 2026-06-16T02:05:47.599+02:00 [fetch-timeout] fetch timeout after 2500ms (elapsed 4147ms) timer delayed 1647ms, likely event-loop starvation operation=fetchWithTimeout url=https://registry.npmjs.org/openclaw/latest
[native-stdio][ws] [2026-06-16T00:05:47.682Z] stdout: 2026-06-16T02:05:47.679+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=ui clientId=openclaw-control-ui platform=android auth=token
[native-stdio][ws] [2026-06-16T00:05:47.703Z] stdout: 2026-06-16T02:05:47.701+02:00 [ws] → hello-ok methods=177 events=27 presence=2 stateVersion=2
[native-stdio][ws] [2026-06-16T00:05:48.454Z] stdout: 2026-06-16T02:05:48.452+02:00 [ws] ⇄ res ✓ health 473ms cached=true id=cc36ae9c…8b11
[native-stdio][skills] [2026-06-16T00:05:50.302Z] stdout: 2026-06-16T02:05:50.300+02:00 [ws] ⇄ res ✓ skills.status 1571ms id=fa57aee7…4b75
[native-stdio][ws] [2026-06-16T00:05:50.481Z] stdout: 2026-06-16T02:05:50.478+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=34180 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34180->127.0.0.1:18789 conn=24074254…a6ad
[native-stdio][ws] [2026-06-16T00:05:51.341Z] stdout: 2026-06-16T02:05:51.337+02:00 [ws] → event node.pair.requested seq=per-client clients=1 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:05:51.384Z] stdout: 2026-06-16T02:05:51.378+02:00 [ws] ← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.28 mode=node clientId=node-host platform=android auth=token
[native-stdio][ws] [2026-06-16T00:05:51.465Z] stdout: 2026-06-16T02:05:51.455+02:00 [ws] → hello-ok methods=177 events=27 presence=3 stateVersion=3
[native-stdio][provider] [2026-06-16T00:06:12.840Z] stdout: 2026-06-16T02:06:12.837+02:00 [gateway] provider auth state pre-warmed in 26940ms eventLoopMax=1642.1ms
[native-stdio][warn] [2026-06-16T00:07:53.107Z] stdout: 2026-06-16T02:07:53.079+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=27.3 eventLoopDelayMaxMs=2070.9 eventLoopUtilization=0.087 cpuCoreRatio=0.051 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:07:53.127Z] stdout: 2026-06-16T02:07:53.121+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:08:23.046Z] stdout: 2026-06-16T02:08:23.042+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:08:53.048Z] stdout: 2026-06-16T02:08:53.043+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:09:23.043Z] stdout: 2026-06-16T02:09:23.040+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:09:53.054Z] stdout: 2026-06-16T02:09:53.049+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][warn] [2026-06-16T00:12:23.053Z] stdout: 2026-06-16T02:12:23.050+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.7 eventLoopDelayMaxMs=1098.9 eventLoopUtilization=0.01 cpuCoreRatio=0.012 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:12:23.061Z] stdout: 2026-06-16T02:12:23.059+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:12:53.048Z] stdout: 2026-06-16T02:12:53.046+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:13:23.049Z] stdout: 2026-06-16T02:13:23.047+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:13:53.060Z] stdout: 2026-06-16T02:13:53.052+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:14:23.056Z] stdout: 2026-06-16T02:14:23.051+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:14:50.369Z] stdout: 2026-06-16T02:14:50.366+02:00 [ws] → event heartbeat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:16:12.002Z] stdout: 2026-06-16T02:16:11.999+02:00 [ws] ⇄ res ✓ agents.list 339ms conn=00e386a5…26c9 id=4a3f15c7…4bca
[native-stdio][plugins] [2026-06-16T00:16:25.440Z] stdout: 2026-06-16T02:16:25.438+02:00 [plugins] loading azure-speech from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/azure-speech/index.js
[native-stdio][plugins] [2026-06-16T00:16:25.639Z] stdout: 2026-06-16T02:16:25.637+02:00 [plugins] loading deepinfra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js
[native-stdio][plugins] [2026-06-16T00:16:25.984Z] stdout: 2026-06-16T02:16:25.983+02:00 [plugins] loading elevenlabs from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/elevenlabs/index.js
[native-stdio][plugins] [2026-06-16T00:16:26.206Z] stdout: 2026-06-16T02:16:26.204+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:16:26.244Z] stdout: 2026-06-16T02:16:26.241+02:00 [plugins] loading gradium from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/gradium/index.js
[native-stdio][plugins] [2026-06-16T00:16:26.902Z] stdout: 2026-06-16T02:16:26.898+02:00 [plugins] loading inworld from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/inworld/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.090Z] stdout: 2026-06-16T02:16:27.088+02:00 [plugins] loading microsoft from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.130Z] stdout: 2026-06-16T02:16:27.128+02:00 [plugins] loading minimax from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/minimax/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.491Z] stdout: 2026-06-16T02:16:27.488+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.519Z] stdout: 2026-06-16T02:16:27.517+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.544Z] stdout: 2026-06-16T02:16:27.542+02:00 [plugins] loading tts-local-cli from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/tts-local-cli/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.651Z] stdout: 2026-06-16T02:16:27.649+02:00 [plugins] loading volcengine from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/volcengine/index.js
[native-stdio][plugins] [2026-06-16T00:16:27.778Z] stdout: 2026-06-16T02:16:27.775+02:00 [plugins] loading vydra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vydra/index.js
[native-stdio][plugins] [2026-06-16T00:16:28.082Z] stdout: 2026-06-16T02:16:28.080+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:16:28.145Z] stdout: 2026-06-16T02:16:28.143+02:00 [plugins] loading xiaomi from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js
[native-stdio][plugins] [2026-06-16T00:16:28.308Z] stdout: 2026-06-16T02:16:28.305+02:00 [plugins] loaded 15 plugin(s) (15 attempted) in 2884.2ms
[native-stdio][provider] [2026-06-16T00:16:28.462Z] stdout: 2026-06-16T02:16:28.459+02:00 [ws] ⇄ res ✓ tts.providers 4252ms id=b2c38b3e…6a76
[native-stdio][ws] [2026-06-16T00:16:28.485Z] stdout: 2026-06-16T02:16:28.482+02:00 [ws] ⇄ res ✓ tts.personas 6ms id=f0ec7dfe…921b
[native-stdio][tts] [2026-06-16T00:16:30.339Z] stdout: 2026-06-16T02:16:30.337+02:00 [ws] ⇄ res ✓ talk.catalog 1828ms id=099dd8f5…7c84
[native-stdio][provider] [2026-06-16T00:16:38.126Z] stdout: 2026-06-16T02:16:38.115+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:16:43.105Z] stdout: 2026-06-16T02:16:43.101+02:00 [ws] ⇄ res ✓ talk.speak 5082ms id=e4466754…2e9e
[native-stdio][warn] [2026-06-16T00:16:53.090Z] stdout: 2026-06-16T02:16:53.084+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=43.5 eventLoopDelayMaxMs=4288.7 eventLoopUtilization=0.304 cpuCoreRatio=0.351 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:16:53.106Z] stdout: 2026-06-16T02:16:53.102+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][chat] [2026-06-16T00:17:14.059Z] stdout: 2026-06-16T02:17:14.056+02:00 [ws] ⇄ res ✓ chat.send 640ms runId=b4bf3ca4-c470-4c7f-8a0a-1430d58903be id=dc1194f2…c1db
[native-stdio][gateway] [2026-06-16T00:17:14.136Z] stdout: 2026-06-16T02:17:14.132+02:00 [diagnostic] message received: channel=webchat chatId=unknown messageId=b4bf3ca4-c470-4c7f-8a0a-1430d58903be sessionId=unknown sessionKey=agent:main:main source=dispatchInboundMessage
[native-stdio][plugins] [2026-06-16T00:17:15.162Z] stdout: 2026-06-16T02:17:15.159+02:00 [plugins] loading browser from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/browser/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:17:15.200Z] stdout: 2026-06-16T02:17:15.198+02:00 [plugins] loading canvas from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/canvas/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.218Z] stdout: 2026-06-16T02:17:15.217+02:00 [plugins] loading device-pair from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/device-pair/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.256Z] stdout: 2026-06-16T02:17:15.238+02:00 Registered plugin command: /pair (plugin: device-pair)
[native-stdio][plugins] [2026-06-16T00:17:15.268Z] stdout: 2026-06-16T02:17:15.266+02:00 [plugins] loading file-transfer from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.293Z] stdout: 2026-06-16T02:17:15.291+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.332Z] stdout: 2026-06-16T02:17:15.330+02:00 [plugins] loading memory-core from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/memory-core/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.362Z] stdout: 2026-06-16T02:17:15.351+02:00 Registered plugin command: /dreaming (plugin: memory-core)
[native-stdio][plugins] [2026-06-16T00:17:15.370Z] stdout: 2026-06-16T02:17:15.367+02:00 [plugins] loading microsoft from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.391Z] stdout: 2026-06-16T02:17:15.389+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.423Z] stdout: 2026-06-16T02:17:15.420+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.443Z] stdout: 2026-06-16T02:17:15.442+02:00 [plugins] loading phone-control from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/phone-control/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.469Z] stdout: 2026-06-16T02:17:15.458+02:00 Registered plugin command: /phone (plugin: phone-control)
[native-stdio][plugins] [2026-06-16T00:17:15.475Z] stdout: 2026-06-16T02:17:15.473+02:00 [plugins] loading talk-voice from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.508Z] stdout: 2026-06-16T02:17:15.494+02:00 Registered plugin command: /voice (plugin: talk-voice)
[native-stdio][plugins] [2026-06-16T00:17:15.519Z] stdout: 2026-06-16T02:17:15.516+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:17:15.546Z] stdout: 2026-06-16T02:17:15.543+02:00 [plugins] loaded 12 plugin(s) (12 attempted) in 388.1ms
[native-stdio][gateway] [2026-06-16T00:17:15.602Z] stdout: 2026-06-16T02:17:15.600+02:00 [diagnostic] message queued: sessionId=unknown sessionKey=agent:main:main source=dispatch queueDepth=1 sessionState=idle
[native-stdio][gateway] [2026-06-16T00:17:15.608Z] stdout: 2026-06-16T02:17:15.606+02:00 [diagnostic] session state: sessionId=unknown sessionKey=agent:main:main prev=idle new=processing reason="message_start" queueDepth=1
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:17:17.465Z] stdout: 2026-06-16T02:17:17.460+02:00 [diagnostic] message dispatch started: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:17:23.622Z] stdout: 2026-06-16T02:17:23.619+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:17:23.648Z] stdout: 2026-06-16T02:17:23.644+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 27.0ms
[native-stdio][plugins] [2026-06-16T00:17:25.391Z] stdout: 2026-06-16T02:17:25.388+02:00 [plugins] loading deepinfra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js
[native-stdio][plugins] [2026-06-16T00:17:25.415Z] stdout: 2026-06-16T02:17:25.412+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 26.5ms
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:17:42.198Z] stdout: 2026-06-16T02:17:42.196+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=49s eventLoopDelayP99Ms=28 eventLoopDelayMaxMs=20334 eventLoopUtilization=0.594 cpuCoreRatio=0.603 active=1 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms work=[active=agent:main:main(processing/embedded_run,q=1,age=27s last=embedded_run:started)]
[native-stdio][gateway] [2026-06-16T00:17:42.204Z] stdout: 2026-06-16T02:17:42.202+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native-stdio][plugins] [2026-06-16T00:17:42.739Z] stdout: 2026-06-16T02:17:42.736+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:17:42.768Z] stdout: 2026-06-16T02:17:42.766+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 32.0ms
[native-stdio][plugins] [2026-06-16T00:17:42.835Z] stdout: 2026-06-16T02:17:42.833+02:00 [plugins] loading anthropic from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/anthropic/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.094Z] stdout: 2026-06-16T02:17:43.093+02:00 [plugins] loading arcee from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/arcee/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.177Z] stdout: 2026-06-16T02:17:43.176+02:00 [plugins] loading byteplus from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/byteplus/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.288Z] stdout: 2026-06-16T02:17:43.286+02:00 [plugins] loading cerebras from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/cerebras/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.359Z] stdout: 2026-06-16T02:17:43.356+02:00 [plugins] loading chutes from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/chutes/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.488Z] stdout: 2026-06-16T02:17:43.486+02:00 [plugins] loading cloudflare-ai-gateway from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.612Z] stdout: 2026-06-16T02:17:43.610+02:00 [plugins] loading comfy from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/comfy/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.798Z] stdout: 2026-06-16T02:17:43.795+02:00 [plugins] loading copilot-proxy from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.866Z] stdout: 2026-06-16T02:17:43.863+02:00 [plugins] loading deepinfra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js
[native-stdio][plugins] [2026-06-16T00:17:43.913Z] stdout: 2026-06-16T02:17:43.910+02:00 [plugins] loading deepseek from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepseek/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:17:44.042Z] stdout: 2026-06-16T02:17:44.040+02:00 [plugins] loading fal from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/fal/index.js
[native-stdio][plugins] [2026-06-16T00:17:44.271Z] stdout: 2026-06-16T02:17:44.269+02:00 [plugins] loading fireworks from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/fireworks/index.js
[native-stdio][plugins] [2026-06-16T00:17:44.383Z] stdout: 2026-06-16T02:17:44.381+02:00 [plugins] loading github-copilot from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js
[native-stdio][plugins] [2026-06-16T00:17:44.586Z] stdout: 2026-06-16T02:17:44.583+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:17:44.615Z] stdout: 2026-06-16T02:17:44.613+02:00 [plugins] loading groq from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/groq/index.js
[native-stdio][plugins] [2026-06-16T00:17:44.969Z] stdout: 2026-06-16T02:17:44.966+02:00 [plugins] loading huggingface from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/huggingface/index.js
[native-stdio][plugins] [2026-06-16T00:17:45.222Z] stdout: 2026-06-16T02:17:45.219+02:00 [plugins] loading kilocode from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/kilocode/index.js
[native-stdio][plugins] [2026-06-16T00:17:45.336Z] stdout: 2026-06-16T02:17:45.334+02:00 [plugins] loading kimi from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js
[native-stdio][plugins] [2026-06-16T00:17:45.433Z] stdout: 2026-06-16T02:17:45.431+02:00 [plugins] loading litellm from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/litellm/index.js
[native-stdio][plugins] [2026-06-16T00:17:45.509Z] stdout: 2026-06-16T02:17:45.507+02:00 [plugins] loading lmstudio from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js
[native-stdio][plugins] [2026-06-16T00:17:45.686Z] stdout: 2026-06-16T02:17:45.684+02:00 [plugins] loading microsoft-foundry from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js
[native-stdio][plugins] [2026-06-16T00:17:45.857Z] stdout: 2026-06-16T02:17:45.855+02:00 [plugins] loading minimax from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/minimax/index.js
[native-stdio][plugins] [2026-06-16T00:17:45.885Z] stdout: 2026-06-16T02:17:45.883+02:00 [plugins] loading mistral from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/mistral/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:17:46.036Z] stdout: 2026-06-16T02:17:46.035+02:00 [plugins] loading moonshot from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/moonshot/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.154Z] stdout: 2026-06-16T02:17:46.152+02:00 [plugins] loading nvidia from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/nvidia/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.247Z] stdout: 2026-06-16T02:17:46.245+02:00 [plugins] loading ollama from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/ollama/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.639Z] stdout: 2026-06-16T02:17:46.637+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.661Z] stdout: 2026-06-16T02:17:46.659+02:00 [plugins] loading opencode from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/opencode/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.762Z] stdout: 2026-06-16T02:17:46.759+02:00 [plugins] loading opencode-go from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.902Z] stdout: 2026-06-16T02:17:46.899+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.923Z] stdout: 2026-06-16T02:17:46.921+02:00 [plugins] loading qianfan from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/qianfan/index.js
[native-stdio][plugins] [2026-06-16T00:17:46.994Z] stdout: 2026-06-16T02:17:46.992+02:00 [plugins] loading qwen from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/qwen/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.145Z] stdout: 2026-06-16T02:17:47.144+02:00 [plugins] loading sglang from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/sglang/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.221Z] stdout: 2026-06-16T02:17:47.218+02:00 [plugins] loading stepfun from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/stepfun/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.301Z] stdout: 2026-06-16T02:17:47.299+02:00 [plugins] loading synthetic from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/synthetic/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.370Z] stdout: 2026-06-16T02:17:47.368+02:00 [plugins] loading tencent from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/tencent/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.448Z] stdout: 2026-06-16T02:17:47.446+02:00 [plugins] loading together from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/together/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.565Z] stdout: 2026-06-16T02:17:47.562+02:00 [plugins] loading venice from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/venice/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.682Z] stdout: 2026-06-16T02:17:47.681+02:00 [plugins] loading vercel-ai-gateway from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.782Z] stdout: 2026-06-16T02:17:47.780+02:00 [plugins] loading vllm from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vllm/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.877Z] stdout: 2026-06-16T02:17:47.875+02:00 [plugins] loading volcengine from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/volcengine/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.901Z] stdout: 2026-06-16T02:17:47.899+02:00 [plugins] loading vydra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vydra/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.926Z] stdout: 2026-06-16T02:17:47.923+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.947Z] stdout: 2026-06-16T02:17:47.945+02:00 [plugins] loading xiaomi from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js
[native-stdio][plugins] [2026-06-16T00:17:47.978Z] stdout: 2026-06-16T02:17:47.976+02:00 [plugins] loading zai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/zai/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:17:48.088Z] stdout: 2026-06-16T02:17:48.087+02:00 [plugins] loaded 45 plugin(s) (45 attempted) in 5256.3ms
[native-stdio][plugins] [2026-06-16T00:17:49.497Z] stdout: 2026-06-16T02:17:49.495+02:00 [plugins] loading anthropic from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/anthropic/index.js
[native-stdio][plugins] [2026-06-16T00:17:49.516Z] stdout: 2026-06-16T02:17:49.513+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 20.5ms
[native-stdio][plugins] [2026-06-16T00:17:49.581Z] stdout: 2026-06-16T02:17:49.579+02:00 [plugins] [hooks] running before_agent_reply (1 handlers, first-claim wins)
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:17:52.138Z] stdout: 2026-06-16T02:17:52.126+02:00 preflightCompaction check: sessionKey=agent:main:main tokenCount=undefined contextWindow=131072 threshold=107072 serverCompactionThreshold=undefined isHeartbeat=false isCli=false persistedFresh=false transcriptPromptTokens=undefined promptTokensEst=4445 activeTranscriptBytes=undefined maxActiveTranscriptBytes=undefined sizeTrigger=false
[native-stdio][gateway] [2026-06-16T00:17:52.168Z] stdout: 2026-06-16T02:17:52.157+02:00 memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=131072 threshold=107072 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=4445 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:17:52.184Z] stdout: 2026-06-16T02:17:52.182+02:00 [diagnostic] session turn created: runId=b4bf3ca4-c470-4c7f-8a0a-1430d58903be sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main agentId=main channel=webchat trigger=user
[native-stdio][gateway] [2026-06-16T00:17:53.074Z] stdout: 2026-06-16T02:17:53.072+02:00 [diagnostic] lane enqueue: lane=session:agent:main:main queueSize=1
[native-stdio][gateway] [2026-06-16T00:17:53.083Z] stdout: 2026-06-16T02:17:53.079+02:00 [diagnostic] lane dequeue: lane=session:agent:main:main waitMs=8 queueSize=0
[native-stdio][gateway] [2026-06-16T00:17:53.101Z] stdout: 2026-06-16T02:17:53.099+02:00 [diagnostic] lane enqueue: lane=main queueSize=1
[native-stdio][gateway] [2026-06-16T00:17:53.105Z] stdout: 2026-06-16T02:17:53.103+02:00 [diagnostic] lane dequeue: lane=main waitMs=4 queueSize=0
[native-stdio][provider] [2026-06-16T00:17:53.486Z] stdout: 2026-06-16T02:17:53.483+02:00 [openrouter-model-capabilities] Loaded 338 OpenRouter models from disk cache
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:17:54.949Z] stdout: 2026-06-16T02:17:54.947+02:00 [agents/harness] agent harness selected
[native-stdio][provider] [2026-06-16T00:17:54.989Z] stdout: 2026-06-16T02:17:54.987+02:00 [agent/embedded] embedded run start: runId=b4bf3ca4-c470-4c7f-8a0a-1430d58903be sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter model=openai/gpt-oss-20b:free thinking=off messageChannel=webchat
[native-stdio][plugins] [2026-06-16T00:17:55.231Z] stdout: 2026-06-16T02:17:55.229+02:00 [plugins] loading browser from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/browser/index.js
[native-stdio][plugins] [2026-06-16T00:17:55.252Z] stdout: 2026-06-16T02:17:55.250+02:00 [plugins] loading canvas from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/canvas/index.js
[native-stdio][plugins] [2026-06-16T00:17:55.276Z] stdout: 2026-06-16T02:17:55.274+02:00 [plugins] loading file-transfer from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js
[native-stdio][plugins] [2026-06-16T00:17:55.299Z] stdout: 2026-06-16T02:17:55.297+02:00 [plugins] loading memory-core from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/memory-core/index.js
[native-stdio][plugins] [2026-06-16T00:17:55.322Z] stdout: 2026-06-16T02:17:55.320+02:00 [plugins] loaded 11 plugin(s) (4 attempted) in 93.9ms
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:17:56.772Z] stdout: 2026-06-16T02:17:56.768+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=processing reason="run_started" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:17:56.779Z] stdout: 2026-06-16T02:17:56.776+02:00 [diagnostic] run registered: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=1
[native-stdio][provider] [2026-06-16T00:17:56.833Z] stdout: 2026-06-16T02:17:56.830+02:00 [agent/embedded] embedded run prompt start: runId=b4bf3ca4-c470-4c7f-8a0a-1430d58903be sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:17:56.997Z] stdout: 2026-06-16T02:17:56.994+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=0 roleCounts=none historyTextChars=0 maxMessageTextChars=0 historyImageBlocks=0 systemPromptChars=34736 promptChars=17777 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:17:57.012Z] stdout: 2026-06-16T02:17:57.009+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=15784 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=0 unwindowedMessages=0 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:17:57.054Z] stdout: 2026-06-16T02:17:57.052+02:00 [agent/embedded] embedded run agent start: runId=b4bf3ca4-c470-4c7f-8a0a-1430d58903be
[native-stdio][ws] [2026-06-16T00:17:57.339Z] stdout: 2026-06-16T02:17:57.336+02:00 [ws] → event agent seq=per-client clients=2 run=b4bf3ca4…03be agent=main session=main stream=lifecycle aseq=1 phase=start
[native-stdio][provider] [2026-06-16T00:17:57.586Z] stdout: 2026-06-16T02:17:57.584+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:18:00.051Z] stdout: 2026-06-16T02:18:00.044+02:00 [provider-transport-fetch] [model-fetch] response prov8ider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2460 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:18:12.192Z] stdout: 2026-06-16T02:18:12.188+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0

Why is gateway restarting
Cosy <cosychiruka@gmail.com>	Tue, Jun 16, 2026 at 3:01 AM
To: Cosy <cosychiruka@gmail.com>
[native][runtime] 02:45:09.513 audio-runtime asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/audio-runtime/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.629 python-debug wheel asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/python-debug/wheels (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.642 skipped unsafe terminal asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.675 terminal asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.687 skipped unsafe terminal library asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.722 terminal library asset copy completed count=4 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/lib (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.870 prepared full OpenClaw bundle packageDir=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw launcher=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/openclaw.mjs extractedNow=false entries=30892 files=30892 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.882 starting embedded Node full OpenClaw Gateway bootstrap on 127.0.0.1:18789 canaryMode=full-gateway-bootstrap script=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full_gateway_bootstrap.mjs (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:09.891 bridge start result code=0 message=started (com.nxg.openclawproot:native_node_smoke)
[native-stdio][gateway] [2026-06-16T00:45:10.633Z] stderr: [NATIVE-NODE-FULL-GATEWAY] launching mobile-safe runCli gateway run on 127.0.0.1:18789
[native-stdio][startup] [2026-06-16T00:45:11.169Z] stderr: [gateway] startup trace: cli.main.argv 5.8ms total=5.8ms
[native-stdio][startup] [2026-06-16T00:45:12.395Z] stderr: [gateway] startup trace: cli.main.dotenv 1223.3ms total=1233.0ms
[WARN] WebSocket disconnected (closeCode=n/a reason=connect-failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 41666)
[native-stdio][gateway] [2026-06-16T00:45:19.926Z] stderr: Your OpenClaw config was written by version 2026.6.5, but this command is running 2026.5.28.
[native-stdio][gateway] Check: `openclaw --version`, `which openclaw`, and `openclaw gateway status --deep`.
[native-stdio][gateway] If unexpected, update PATH so `openclaw` points to the version you want, or reinstall the Gateway service from that same OpenClaw install.
[native-stdio][startup] [2026-06-16T00:45:21.195Z] stderr: [gateway] startup trace: cli.main.gateway-run-imports 262.2ms total=10032.9ms
[native-stdio][startup] [2026-06-16T00:45:21.621Z] stdout: [gateway] startup trace: cli.server-import 16.7ms total=16.8ms
[native-stdio][gateway] [2026-06-16T00:45:21.660Z] stdout: 2026-06-16T02:45:21.658+02:00 [gateway] loading configuration…
[native-stdio][startup] [2026-06-16T00:45:22.164Z] stdout: 2026-06-16T02:45:22.162+02:00 [gateway] startup trace: cli.config-snapshot 444.3ms total=699.8ms
[native-stdio][gateway] [2026-06-16T00:45:22.288Z] stdout: 2026-06-16T02:45:22.275+02:00 [gateway] resolving authentication…
[native-stdio][startup] [2026-06-16T00:45:22.438Z] stdout: 2026-06-16T02:45:22.435+02:00 [gateway] startup trace: cli.auth-resolve 4.6ms total=976.2ms
[native-stdio][gateway] [2026-06-16T00:45:22.481Z] stdout: 2026-06-16T02:45:22.479+02:00 [gateway] starting...
[native-stdio][startup] [2026-06-16T00:45:22.494Z] stdout: 2026-06-16T02:45:22.493+02:00 [gateway] startup trace: cli.gateway-loop 59.7ms total=1035.9ms
[native] log stream resumed after rotation or runtime restart
[native][runtime] 02:45:24.105 stop requested; terminating isolated native Node process activePort=18789 activeMode=full-gateway-bootstrap (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:24.117 service destroyed (com.nxg.openclawproot:native_node_smoke)
[WARN] WebSocket disconnected (closeCode=n/a reason=connect-failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 42752)
[HEALTH] WS dropped and gateway process is down.
[native] log stream resumed after rotation or runtime restart
[native][runtime] 02:45:36.186 skipped unsafe CLI-core asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:37.795 CLI-core asset copy completed count=6 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:37.806 skipped unsafe vision-media asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.023 vision-media asset copy completed count=2 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.036 skipped unsafe audio-runtime asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.124 audio-runtime asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/audio-runtime/bin (com.nxg.openclawproot:native_node_smoke)
[native] log stream resumed after rotation or runtime restart
[native][runtime] 02:45:38.233 python-debug wheel asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/python-debug/wheels (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.250 skipped unsafe terminal asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.283 terminal asset copy completed count=1 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/bin (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.296 skipped unsafe terminal library asset name=.gitkeep (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.326 terminal library asset copy completed count=4 target=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/provisioning/terminal/lib (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.467 prepared full OpenClaw bundle packageDir=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw launcher=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/openclaw.mjs extractedNow=false entries=30892 files=30892 (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.477 starting embedded Node full OpenClaw Gateway bootstrap on 127.0.0.1:18789 canaryMode=full-gateway-bootstrap script=/data/user/0/com.nxg.openclawproot/files/native-node-embedded/full_gateway_bootstrap.mjs (com.nxg.openclawproot:native_node_smoke)
[native][runtime] 02:45:38.488 bridge start result code=0 message=started (com.nxg.openclawproot:native_node_smoke)
[native-stdio][gateway] [2026-06-16T00:45:39.051Z] stderr: [NATIVE-NODE-FULL-GATEWAY] launching mobile-safe runCli gateway run on 127.0.0.1:18789
[native-stdio][startup] [2026-06-16T00:45:39.438Z] stderr: [gateway] startup trace: cli.main.argv 5.4ms total=5.4ms
[native-stdio][startup] [2026-06-16T00:45:40.376Z] stderr: [gateway] startup trace: cli.main.dotenv 934.3ms total=943.1ms
[WARN] WebSocket disconnected (closeCode=n/a reason=connect-failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 38820)
[native-stdio][gateway] [2026-06-16T00:45:46.902Z] stderr: Your OpenClaw config was written by version 2026.6.5, but this command is running 2026.5.28.
[native-stdio][startup] [2026-06-16T00:45:47.722Z] stderr: [gateway] startup trace: cli.main.gateway-run-imports 170.0ms total=8289.6ms
[native-stdio][startup] [2026-06-16T00:45:48.040Z] stdout: [gateway] startup trace: cli.server-import 11.7ms total=11.9ms
[native-stdio][gateway] [2026-06-16T00:45:48.081Z] stdout: 2026-06-16T02:45:48.078+02:00 [gateway] loading configuration…
[native-stdio][startup] [2026-06-16T00:45:48.627Z] stdout: 2026-06-16T02:45:48.624+02:00 [gateway] startup trace: cli.config-snapshot 478.4ms total=713.7ms
[native-stdio][gateway] [2026-06-16T00:45:48.665Z] stdout: 2026-06-16T02:45:48.663+02:00 [gateway] resolving authentication…
[native-stdio][startup] [2026-06-16T00:45:48.739Z] stdout: 2026-06-16T02:45:48.735+02:00 [gateway] startup trace: cli.auth-resolve 3.2ms total=825.3ms
[native-stdio][gateway] [2026-06-16T00:45:48.786Z] stdout: 2026-06-16T02:45:48.783+02:00 [gateway] starting...
[native-stdio][startup] [2026-06-16T00:45:48.813Z] stdout: 2026-06-16T02:45:48.809+02:00 [gateway] startup trace: cli.gateway-loop 65.4ms total=890.7ms
[native-stdio][startup] [2026-06-16T00:45:55.734Z] stderr: [gateway] startup trace: gateway.server-impl-import 770.2ms total=770.2ms
[native-stdio][startup] [2026-06-16T00:45:55.915Z] stdout: 2026-06-16T02:45:55.913+02:00 [gateway] startup trace: config.snapshot.auto-enable 29.5ms total=145.2ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:45:55.937Z] stdout: 2026-06-16T02:45:55.935+02:00 [gateway] auto-enabled plugins for this runtime without writing config:
[native-stdio][provider] - openrouter/openai/gpt-oss-20b:free model configured, enabled automatically.
[native-stdio][startup] [2026-06-16T00:45:55.952Z] stdout: 2026-06-16T02:45:55.950+02:00 [gateway] startup trace: config.snapshot 74.3ms total=188.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:55.968Z] stdout: 2026-06-16T02:45:55.966+02:00 [gateway] startup trace: config.auth.snapshot-validate 0.9ms total=204.5ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:55.982Z] stdout: 2026-06-16T02:45:55.980+02:00 [gateway] startup trace: config.auth.runtime-overrides 1.7ms total=218.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:55.997Z] stdout: 2026-06-16T02:45:55.995+02:00 [gateway] startup trace: config.auth.startup-overrides 1.4ms total=232.9ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.016Z] stdout: 2026-06-16T02:45:56.014+02:00 [gateway] startup trace: config.auth.secret-surface 5.6ms total=252.0ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.030Z] stdout: 2026-06-16T02:45:56.027+02:00 [gateway] startup trace: config.auth.secret-preflight 1.4ms total=266.5ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.044Z] stdout: 2026-06-16T02:45:56.041+02:00 [gateway] startup trace: config.auth.preflight-override 1.6ms total=280.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.062Z] stdout: 2026-06-16T02:45:56.060+02:00 [gateway] startup trace: config.auth.ensure 4.3ms total=297.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.077Z] stdout: 2026-06-16T02:45:56.074+02:00 [gateway] startup trace: config.auth.runtime-startup-overrides 1.3ms total=314.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.217Z] stdout: 2026-06-16T02:45:56.215+02:00 [gateway] startup trace: config.auth.secrets-activate 125.1ms total=451.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.231Z] stdout: 2026-06-16T02:45:56.229+02:00 [gateway] startup trace: config.auth 264.2ms total=466.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:56.258Z] stdout: 2026-06-16T02:45:56.255+02:00 [gateway] startup trace: control-ui.seed 5.9ms total=493.6ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:45:58.260Z] stdout: 2026-06-16T02:45:58.258+02:00 [gateway] startup trace: plugins.bootstrap 477.6ms total=2495.3ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:45:58.279Z] stdout: 2026-06-16T02:45:58.277+02:00 [gateway] startup trace: plugins.lookup-table registrySnapshotMs=2.4 manifestRegistryMs=141.8 startupPlanMs=347.2 ownerMapsMs=2.0 totalMs=504.8 indexPlugins=92 indexPluginCount=92.0 manifestPlugins=92 manifestPluginCount=92.0 startupPlugins=12 startupPluginCount=12.0 deferredChannelPlugins=0 deferredChannelPluginCount=0.0
[native-stdio][startup] [2026-06-16T00:45:58.340Z] stdout: 2026-06-16T02:45:58.339+02:00 [gateway] startup trace: runtime.config 49.9ms total=2579.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:58.364Z] stdout: 2026-06-16T02:45:58.361+02:00 [gateway] startup trace: control-ui.root 4.7ms total=2599.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:58.379Z] stdout: 2026-06-16T02:45:58.377+02:00 [gateway] startup trace: tls.runtime 1.7ms total=2616.0ms eventLoopMax=0.0ms
[WARN] WebSocket disconnected (closeCode=n/a reason=connect-failed: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 49564)
[HEALTH] WS dropped and gateway process is down.
[native-stdio][gateway] [2026-06-16T00:45:58.688Z] stdout: 2026-06-16T02:45:58.685+02:00 [gateway] starting HTTP server...
[native-stdio][startup] [2026-06-16T00:45:58.716Z] stdout: 2026-06-16T02:45:58.714+02:00 [gateway] startup trace: runtime.state 15.6ms total=2952.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:58.778Z] stdout: 2026-06-16T02:45:58.776+02:00 [gateway] startup trace: runtime.early.discovery.machine-name 10.1ms total=3016.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:58.816Z] stdout: 2026-06-16T02:45:58.815+02:00 [gateway] startup trace: runtime.early.discovery.start 25.7ms total=3052.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:58.831Z] stdout: 2026-06-16T02:45:58.830+02:00 [gateway] startup trace: runtime.early.discovery 62.5ms total=3068.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.070Z] stdout: 2026-06-16T02:45:59.068+02:00 [gateway] startup trace: runtime.early.lazy-runtime-imports 226.0ms total=3306.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.163Z] stdout: 2026-06-16T02:45:59.162+02:00 [gateway] startup trace: runtime.early.skills-listener 45.2ms total=3403.3ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.173Z] stdout: 2026-06-16T02:45:59.171+02:00 [gateway] startup trace: runtime.early 415.1ms total=3412.9ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.205Z] stdout: 2026-06-16T02:45:59.204+02:00 [gateway] startup trace: runtime.post-early-imports 23.4ms total=3445.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.215Z] stdout: 2026-06-16T02:45:59.214+02:00 [gateway] startup trace: runtime.subscriptions 1.6ms total=3455.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.225Z] stdout: 2026-06-16T02:45:59.224+02:00 [health-monitor] started (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s)
[native-stdio][startup] [2026-06-16T00:45:59.235Z] stdout: 2026-06-16T02:45:59.233+02:00 [gateway] startup trace: runtime.services 10.8ms total=3475.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.552Z] stdout: 2026-06-16T02:45:59.550+02:00 [gateway] startup trace: gateway.handlers 305.8ms total=3789.5ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.581Z] stdout: 2026-06-16T02:45:59.579+02:00 [gateway] startup trace: gateway.request-context 10.0ms total=3818.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.684Z] stdout: 2026-06-16T02:45:59.682+02:00 [gateway] startup trace: gateway.ws-imports 90.4ms total=3920.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.700Z] stdout: 2026-06-16T02:45:59.698+02:00 [gateway] startup trace: gateway.ws-attach 3.6ms total=3937.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.717Z] stdout: 2026-06-16T02:45:59.715+02:00 [gateway] startup trace: http.listen 5.2ms total=3954.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:45:59.729Z] stdout: 2026-06-16T02:45:59.727+02:00 [gateway] startup trace: http.bound 12.5ms total=3967.1ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:45:59.899Z] stdout: 2026-06-16T02:45:59.896+02:00 [plugins] loading browser from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/browser/index.js
[native-stdio][plugins] [2026-06-16T00:46:00.266Z] stdout: 2026-06-16T02:46:00.264+02:00 [gateway] startup trace: plugins.gateway-load.plugin.browser loadMs=356.2 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.300Z] stdout: 2026-06-16T02:46:00.298+02:00 [gateway] startup trace: plugins.gateway-load.plugin.browser registerMs=8.0 loadAndRegisterMs=364.3 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.323Z] stdout: 2026-06-16T02:46:00.321+02:00 [plugins] loading canvas from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/canvas/index.js
[native-stdio][plugins] [2026-06-16T00:46:00.493Z] stdout: 2026-06-16T02:46:00.490+02:00 [gateway] startup trace: plugins.gateway-load.plugin.canvas loadMs=159.7 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.518Z] stdout: 2026-06-16T02:46:00.516+02:00 [gateway] startup trace: plugins.gateway-load.plugin.canvas registerMs=11.8 loadAndRegisterMs=171.4 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.536Z] stdout: 2026-06-16T02:46:00.534+02:00 [plugins] loading device-pair from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/device-pair/index.js
[native-stdio][plugins] [2026-06-16T00:46:00.599Z] stdout: 2026-06-16T02:46:00.597+02:00 [gateway] startup trace: plugins.gateway-load.plugin.device-pair loadMs=54.6 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.623Z] stdout: 2026-06-16T02:46:00.611+02:00 Registered plugin command: /pair (plugin: device-pair)
[native-stdio][plugins] [2026-06-16T00:46:00.635Z] stdout: 2026-06-16T02:46:00.633+02:00 [gateway] startup trace: plugins.gateway-load.plugin.device-pair registerMs=21.7 loadAndRegisterMs=76.4 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.659Z] stdout: 2026-06-16T02:46:00.657+02:00 [plugins] loading file-transfer from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js
[native-stdio][plugins] [2026-06-16T00:46:00.738Z] stdout: 2026-06-16T02:46:00.735+02:00 [gateway] startup trace: plugins.gateway-load.plugin.file-transfer loadMs=65.3 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.754Z] stdout: 2026-06-16T02:46:00.752+02:00 [gateway] startup trace: plugins.gateway-load.plugin.file-transfer registerMs=2.7 loadAndRegisterMs=68.0 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:00.766Z] stdout: 2026-06-16T02:46:00.764+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:46:03.720Z] stdout: 2026-06-16T02:46:03.717+02:00 [gateway] startup trace: plugins.gateway-load.plugin.google loadMs=2944.2 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:03.757Z] stdout: 2026-06-16T02:46:03.755+02:00 [gateway] startup trace: plugins.gateway-load.plugin.google registerMs=24.6 loadAndRegisterMs=2968.7 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:03.784Z] stdout: 2026-06-16T02:46:03.782+02:00 [plugins] loading memory-core from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/memory-core/index.js
[native-stdio][plugins] [2026-06-16T00:46:04.067Z] stdout: 2026-06-16T02:46:04.065+02:00 [gateway] startup trace: plugins.gateway-load.plugin.memory-core loadMs=275.2 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:04.089Z] stdout: 2026-06-16T02:46:04.080+02:00 Registered plugin command: /dreaming (plugin: memory-core)
[native-stdio][plugins] [2026-06-16T00:46:04.101Z] stdout: 2026-06-16T02:46:04.100+02:00 [gateway] startup trace: plugins.gateway-load.plugin.memory-core registerMs=20.2 loadAndRegisterMs=295.4 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:04.107Z] stdout: 2026-06-16T02:46:04.105+02:00 [plugins] loading microsoft from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft/index.js
[native-stdio][plugins] [2026-06-16T00:46:04.505Z] stdout: 2026-06-16T02:46:04.503+02:00 [gateway] startup trace: plugins.gateway-load.plugin.microsoft loadMs=385.5 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:04.521Z] stdout: 2026-06-16T02:46:04.519+02:00 [gateway] startup trace: plugins.gateway-load.plugin.microsoft registerMs=1.3 loadAndRegisterMs=386.8 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:04.538Z] stdout: 2026-06-16T02:46:04.534+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:46:05.531Z] stdout: 2026-06-16T02:46:05.530+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openai loadMs=988.4 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:05.559Z] stdout: 2026-06-16T02:46:05.557+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openai registerMs=15.3 loadAndRegisterMs=1003.7 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:05.565Z] stdout: 2026-06-16T02:46:05.563+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:46:05.819Z] stdout: 2026-06-16T02:46:05.818+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openrouter loadMs=242.0 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:05.845Z] stdout: 2026-06-16T02:46:05.843+02:00 [gateway] startup trace: plugins.gateway-load.plugin.openrouter registerMs=7.5 loadAndRegisterMs=249.5 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:05.852Z] stdout: 2026-06-16T02:46:05.850+02:00 [plugins] loading phone-control from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/phone-control/index.js
[native-stdio][plugins] [2026-06-16T00:46:05.928Z] stdout: 2026-06-16T02:46:05.926+02:00 [gateway] startup trace: plugins.gateway-load.plugin.phone-control loadMs=64.1 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:05.947Z] stdout: 2026-06-16T02:46:05.934+02:00 Registered plugin command: /phone (plugin: phone-control)
[native-stdio][plugins] [2026-06-16T00:46:05.959Z] stdout: 2026-06-16T02:46:05.957+02:00 [gateway] startup trace: plugins.gateway-load.plugin.phone-control registerMs=17.0 loadAndRegisterMs=81.1 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:05.965Z] stdout: 2026-06-16T02:46:05.963+02:00 [plugins] loading talk-voice from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js
[native-stdio][plugins] [2026-06-16T00:46:06.045Z] stdout: 2026-06-16T02:46:06.042+02:00 [gateway] startup trace: plugins.gateway-load.plugin.talk-voice loadMs=71.1 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:06.063Z] stdout: 2026-06-16T02:46:06.051+02:00 Registered plugin command: /voice (plugin: talk-voice)
[native-stdio][plugins] [2026-06-16T00:46:06.073Z] stdout: 2026-06-16T02:46:06.071+02:00 [gateway] startup trace: plugins.gateway-load.plugin.talk-voice registerMs=16.4 loadAndRegisterMs=87.5 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:06.098Z] stdout: 2026-06-16T02:46:06.095+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:46:10.931Z] stdout: 2026-06-16T02:46:10.928+02:00 [gateway] startup trace: plugins.gateway-load.plugin.xai loadMs=4824.7 loadFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:10.962Z] stdout: 2026-06-16T02:46:10.958+02:00 [gateway] startup trace: plugins.gateway-load.plugin.xai registerMs=12.0 loadAndRegisterMs=4836.7 registerFailedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:10.967Z] stdout: 2026-06-16T02:46:10.964+02:00 [plugins] loaded 12 plugin(s) (12 attempted) in 11075.3ms
[native-stdio][plugins] [2026-06-16T00:46:10.995Z] stdout: 2026-06-16T02:46:10.991+02:00 [gateway] startup trace: plugins.gateway-load autoEnableMs=0.0 resolvedConfigMs=0.1 pluginIdsMs=0.1 loadMs=11132.3 pluginIds=12 pluginCount=12.0 gatewayHandlers=1 gatewayHandlerCount=1.0 loaderCallsCount=12.0 loaderNativeHitsCount=12.0 loaderNativeMissesCount=0.0 loaderSourceTransformForcedCount=0.0 loaderSourceTransformFallbacksCount=0.0 loaderTopSourceTransformTargets=
[native-stdio][plugins] [2026-06-16T00:46:11.019Z] stdout: 2026-06-16T02:46:11.016+02:00 [gateway] startup trace: plugins.runtime-post-bind 11243.4ms total=15249.2ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:11.035Z] stdout: 2026-06-16T02:46:11.033+02:00 [gateway] startup trace: plugins.runtime-post-bind loadedPluginCount=12.0 gatewayMethodCount=177.0
[native-stdio][provider] [2026-06-16T00:46:11.155Z] stdout: 2026-06-16T02:46:11.153+02:00 [gateway] agent model: openrouter/openai/gpt-oss-20b:free (thinking=medium, fast=off)
[native-stdio][plugins] [2026-06-16T00:46:11.171Z] stdout: 2026-06-16T02:46:11.167+02:00 [gateway] http server listening (12 plugins: browser, canvas, device-pair, file-transfer, google, memory-core, microsoft, openai, openrouter, phone-control, talk-voice, xai; 22.3s)
[native-stdio][gateway] [2026-06-16T00:46:11.189Z] stdout: 2026-06-16T02:46:11.186+02:00 [gateway] log file: /data/user/0/com.nxg.openclawproot/files/native-node-embedded/tmp/openclaw/openclaw-2026-06-16.log
[native-stdio][startup] [2026-06-16T00:46:11.212Z] stdout: 2026-06-16T02:46:11.208+02:00 [gateway] startup trace: post-attach.log 136.2ms total=15444.9ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:46:11.247Z] stdout: 2026-06-16T02:46:11.245+02:00 [gateway] starting channels and sidecars...
[native-stdio][startup] [2026-06-16T00:46:11.266Z] stdout: 2026-06-16T02:46:11.263+02:00 [gateway] startup trace: sidecars.internal-hooks 1.1ms total=15500.1ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:11.302Z] stdout: 2026-06-16T02:46:11.300+02:00 [gateway] startup trace: sidecars.channel-start 10.9ms total=15536.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:11.322Z] stdout: 2026-06-16T02:46:11.318+02:00 [gateway] startup trace: sidecars.channels 36.8ms total=15552.3ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:11.392Z] stdout: 2026-06-16T02:46:11.389+02:00 [gateway] startup trace: sidecars.plugin-services.browser.browser-control 10.9ms total=15629.1ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:11.456Z] stdout: 2026-06-16T02:46:11.453+02:00 [gateway] startup trace: sidecars.plugin-services.canvas.canvas-host 35.0ms total=15686.2ms eventLoopMax=0.0ms
[INFO] Connecting WebSocket...
[native-stdio][ws] [2026-06-16T00:46:13.059Z] stdout: 2026-06-16T02:46:13.057+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=45556 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45556->127.0.0.1:18789 conn=2baab379…d59d
[native-stdio][plugins] [2026-06-16T00:46:13.330Z] stdout: 2026-06-16T02:46:13.328+02:00 [gateway] startup trace: sidecars.plugin-services.device-pair.device-pair-notifier 1859.5ms total=17565.7ms eventLoopMax=371.5ms
[native-stdio][plugins] [2026-06-16T00:46:13.354Z] stdout: 2026-06-16T02:46:13.352+02:00 [gateway] startup trace: sidecars.plugin-services.phone-control.phone-control-expiry 6.0ms total=17585.8ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:13.368Z] stdout: 2026-06-16T02:46:13.367+02:00 [gateway] startup trace: sidecars.plugin-services.summary serviceCount=4.0 startedCount=4.0 failedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:13.385Z] stdout: 2026-06-16T02:46:13.382+02:00 [gateway] startup trace: sidecars.plugin-services 2046.0ms total=17618.4ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:13.409Z] stdout: 2026-06-16T02:46:13.407+02:00 [gateway] startup trace: sidecars.memory 1.8ms total=17646.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:13.425Z] stdout: 2026-06-16T02:46:13.422+02:00 [gateway] startup trace: sidecars.total 2163.7ms total=17660.2ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:13.441Z] stdout: 2026-06-16T02:46:13.438+02:00 [gateway] startup trace: sidecars.plugin-loader callsCount=0.0 nativeHitsCount=0.0 nativeMissesCount=0.0 sourceTransformForcedCount=0.0 sourceTransformFallbacksCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:13.460Z] stdout: 2026-06-16T02:46:13.457+02:00 [gateway] startup trace: sidecars.ready loadedPluginCount=12.0 postReadySidecarCount=1.0
[native-stdio][startup] [2026-06-16T00:46:13.475Z] stdout: 2026-06-16T02:46:13.473+02:00 [gateway] startup trace: sidecars.ready 48.8ms total=17709.1ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:46:13.488Z] stdout: 2026-06-16T02:46:13.485+02:00 [gateway] ready
[native-stdio][startup] [2026-06-16T00:46:13.554Z] stdout: 2026-06-16T02:46:13.549+02:00 [gateway] startup trace: runtime.post-attach 13803.0ms total=17781.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:13.571Z] stdout: 2026-06-16T02:46:13.569+02:00 [gateway] startup trace: memory.ready rssMb=425.4 heapTotalMb=278.2 heapUsedMb=252.4 externalMb=5.3 arrayBuffersMb=1.6 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=3.0 activeRequestsCount=2.0 activeTimersCount=1.0
[native-stdio][startup] [2026-06-16T00:46:13.584Z] stdout: 2026-06-16T02:46:13.581+02:00 [gateway] startup trace: ready 38.1ms total=17819.9ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:46:16.014Z] stdout: 2026-06-16T02:46:16.012+02:00 [heartbeat] started
[native-stdio][startup] [2026-06-16T00:46:16.220Z] stdout: 2026-06-16T02:46:16.218+02:00 [gateway] startup trace: sidecars.subagent-recovery 78.4ms total=20456.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.306Z] stdout: 2026-06-16T02:46:16.304+02:00 [gateway] startup trace: sidecars.main-session-recovery 42.3ms total=20543.9ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:16.331Z] stdout: 2026-06-16T02:46:16.329+02:00 [plugins] [hooks] running gateway_start (1 handlers)
[native-stdio][startup] [2026-06-16T00:46:16.452Z] stdout: 2026-06-16T02:46:16.450+02:00 [gateway] startup trace: post-attach.update-check 12.0ms total=20688.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.464Z] stderr: 2026-06-16T02:46:16.461+02:00 [gateway] startup model warmup timed out after 5000ms; continuing without waiting
[native-stdio][startup] [2026-06-16T00:46:16.475Z] stdout: 2026-06-16T02:46:16.473+02:00 [gateway] startup trace: sidecars.model-prewarm 5195.9ms total=20713.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.501Z] stdout: 2026-06-16T02:46:16.499+02:00 [gateway] startup trace: sidecars.restart-sentinel 361.6ms total=20737.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.513Z] stdout: 2026-06-16T02:46:16.511+02:00 [gateway] startup trace: post-attach.update-sentinel 194.0ms total=20750.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.591Z] stdout: 2026-06-16T02:46:16.589+02:00 [gateway] startup trace: sidecars.session-locks 473.6ms total=20827.3ms eventLoopMax=0.0ms
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[native-stdio][startup] [2026-06-16T00:46:18.838Z] stdout: 2026-06-16T02:46:18.836+02:00 [gateway] startup trace: post-ready.maintenance 109.5ms total=23075.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:18.851Z] stdout: 2026-06-16T02:46:18.849+02:00 [gateway] startup trace: memory.post-ready rssMb=472.0 heapTotalMb=331.4 heapUsedMb=302.2 externalMb=5.4 arrayBuffersMb=1.7 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=4.0 activeRequestsCount=2.0 activeTimersCount=5.0
[native-stdio][ws] [2026-06-16T00:46:20.468Z] stdout: 2026-06-16T02:46:20.466+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=ui clientId=openclaw-control-ui platform=android auth=token
[native-stdio][ws] [2026-06-16T00:46:20.503Z] stdout: 2026-06-16T02:46:20.500+02:00 [ws] → hello-ok methods=177 events=27 presence=2 stateVersion=2
[INFO] Health RPC: ok=true
[native-stdio][ws] [2026-06-16T00:46:21.201Z] stdout: 2026-06-16T02:46:21.200+02:00 [ws] ⇄ res ✓ health 415ms cached=true id=c564c99c…af39
[INFO] Active skills: 1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli, browser-automation, camsnap, canvas, clawhub, coding-agent, device-node, diagram-maker, discord, eightctl, gemini, gestures, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya, imsg, mcporter, meme-maker, model-usage, nano-pdf, node-connect, node-inspect-debugger, notion, obsidian, openai-whisper, openai-whisper-api, openhue, oracle, ordercli, peekaboo, python-debugpy, sag, session-logs, sherpa-onnx-tts, skill-creator, slack, songsee, sonoscli, spike, spotify-player, stocks, summarize, taskflow, taskflow-inbox-triage, things-mac, tmux, trello, tts-voice, video-frames, voice-call, wacli, weather, xurl
[native-stdio][skills] [2026-06-16T00:46:23.059Z] stdout: 2026-06-16T02:46:23.056+02:00 [ws] ⇄ res ✓ skills.status 1602ms id=5b127b80…89df
[native-stdio][ws] [2026-06-16T00:46:23.130Z] stdout: 2026-06-16T02:46:23.127+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=55200 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55200->127.0.0.1:18789 conn=b115adff…e320
[native-stdio][ws] [2026-06-16T00:46:23.817Z] stdout: 2026-06-16T02:46:23.814+02:00 [ws] → event node.pair.requested seq=per-client clients=1 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:46:23.843Z] stdout: 2026-06-16T02:46:23.840+02:00 [ws] ← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.28 mode=node clientId=node-host platform=android auth=token
[native-stdio][ws] [2026-06-16T00:46:23.876Z] stdout: 2026-06-16T02:46:23.873+02:00 [ws] → hello-ok methods=177 events=27 presence=3 stateVersion=3
[native-stdio][provider] [2026-06-16T00:46:43.805Z] stdout: 2026-06-16T02:46:43.802+02:00 [gateway] provider auth state pre-warmed in 24355ms eventLoopMax=1633.7ms
[native-stdio][ws] [2026-06-16T00:48:33.938Z] stdout: 2026-06-16T02:48:33.935+02:00 [ws] ⇄ res ✓ agents.list 209ms conn=2baab379…d59d id=7808924c…5883
[native-stdio][ws] [2026-06-16T00:48:41.066Z] stdout: 2026-06-16T02:48:41.063+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=42064 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42064->127.0.0.1:18789 conn=be9d0c8f…b4fa
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:48:41.261Z] stdout: 2026-06-16T02:48:41.259+02:00 [gateway] device pairing auto-approved device=ad2d40a460b8da96c61995431ff111512286a04b4328026d0f3cd9022eb618f3 role=operator
[native-stdio][tools] [2026-06-16T00:48:41.276Z] stdout: 2026-06-16T02:48:41.274+02:00 [ws] → event device.pair.resolved seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:48:41.318Z] stdout: 2026-06-16T02:48:41.316+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=webchat clientId=openclaw-control-ui platform=Linux aarch64 auth=token
[native-stdio][ws] [2026-06-16T00:48:41.329Z] stdout: 2026-06-16T02:48:41.327+02:00 [ws] webchat connected conn=be9d0c8f-bce9-4bb4-a7c9-3ccba7fab4fa remote=127.0.0.1 client=openclaw-control-ui webchat v2026.5.28
[native-stdio][ws] [2026-06-16T00:48:41.352Z] stdout: 2026-06-16T02:48:41.349+02:00 [ws] → hello-ok methods=177 events=27 presence=4 stateVersion=4
[native-stdio][ws] [2026-06-16T00:48:41.878Z] stdout: 2026-06-16T02:48:41.875+02:00 [ws] ⇄ res ✓ health 36ms cached=true id=fa63bf69…70c6
[native-stdio][ws] [2026-06-16T00:48:41.900Z] stdout: 2026-06-16T02:48:41.897+02:00 [ws] ⇄ res ✓ agents.list 61ms id=4013bac4…087a
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:48:43.905Z] stdout: 2026-06-16T02:48:43.903+02:00 [ws] ⇄ res ✓ sessions.subscribe 2071ms id=56003048…e672
[native-stdio][ws] [2026-06-16T00:48:43.930Z] stdout: 2026-06-16T02:48:43.928+02:00 [ws] ⇄ res ✓ sessions.messages.subscribe 2097ms id=66b243fa…24eb
[native-stdio][ws] [2026-06-16T00:48:43.949Z] stdout: 2026-06-16T02:48:43.947+02:00 [ws] ⇄ res ✓ agent.identity.get 2117ms id=3e653596…6d52
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:48:45.435Z] stdout: 2026-06-16T02:48:45.433+02:00 [ws] ⇄ res ✓ models.authStatus 1427ms id=abf96576…b9a7
[native-stdio][ws] [2026-06-16T00:48:46.290Z] stdout: 2026-06-16T02:48:46.287+02:00 [ws] ⇄ res ✓ commands.list 2281ms id=8cf2aad6…14a1
[native-stdio][gateway] [2026-06-16T00:48:46.375Z] stdout: 2026-06-16T02:48:46.373+02:00 [gateway] sessions.list continuing without model catalog after 750ms
[native-stdio][ws] [2026-06-16T00:48:46.419Z] stdout: 2026-06-16T02:48:46.416+02:00 [ws] ⇄ res ✓ sessions.list 2407ms id=187bacd0…813c
[native-stdio][ws] [2026-06-16T00:48:46.563Z] stdout: 2026-06-16T02:48:46.561+02:00 [ws] ⇄ res ✓ chat.history 2555ms id=e745a597…96c1
[native-stdio][ws] [2026-06-16T00:48:46.654Z] stdout: 2026-06-16T02:48:46.651+02:00 [ws] ⇄ res ✓ models.list 2644ms id=0d2785e2…9807
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:48:56.255Z] stdout: 2026-06-16T02:48:56.250+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=44.1 eventLoopDelayMaxMs=2382.4 eventLoopUtilization=0.224 cpuCoreRatio=0.26 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:11ms,sidecars.model-prewarm:5195ms,sidecars.restart-sentinel:361ms,post-attach.update-sentinel:193ms,sidecars.session-locks:473ms,post-ready.maintenance:104ms
[native-stdio][gateway] [2026-06-16T00:48:56.265Z] stdout: 2026-06-16T02:48:56.262+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:49:26.251Z] stdout: 2026-06-16T02:49:26.247+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:49:56.250Z] stdout: 2026-06-16T02:49:56.246+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:50:26.267Z] stdout: 2026-06-16T02:50:26.260+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:50:56.247Z] stdout: 2026-06-16T02:50:56.245+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:54:32.226Z] stdout: 2026-06-16T02:54:32.223+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=45716 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45716->127.0.0.1:18789 conn=abf533e3…84ab
[native-stdio][ws] [2026-06-16T00:54:32.345Z] stdout: 2026-06-16T02:54:32.343+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=webchat clientId=openclaw-control-ui platform=Linux aarch64 auth=token
[native-stdio][ws] [2026-06-16T00:54:32.355Z] stdout: 2026-06-16T02:54:32.353+02:00 [ws] webchat connected conn=abf533e3-53ab-422f-8312-fcbd160d84ab remote=127.0.0.1 client=openclaw-control-ui webchat v2026.5.28
[native-stdio][ws] [2026-06-16T00:54:32.382Z] stdout: 2026-06-16T02:54:32.380+02:00 [ws] → hello-ok methods=177 events=27 presence=2 stateVersion=5
[native-stdio][ws] [2026-06-16T00:54:32.800Z] stdout: 2026-06-16T02:54:32.797+02:00 [ws] ⇄ res ✓ sessions.subscribe 6ms id=edf08b9a…76f1
[native-stdio][ws] [2026-06-16T00:54:32.817Z] stdout: 2026-06-16T02:54:32.815+02:00 [ws] ⇄ res ✓ sessions.messages.subscribe 23ms id=e4eb647f…325d
[native-stdio][ws] [2026-06-16T00:54:32.832Z] stdout: 2026-06-16T02:54:32.830+02:00 [ws] ⇄ res ✓ agent.identity.get 37ms id=34bd56b4…3c66
[native-stdio][ws] [2026-06-16T00:54:32.852Z] stdout: 2026-06-16T02:54:32.849+02:00 [ws] ⇄ res ✓ health 51ms cached=true id=941df7fe…c8c3
[native-stdio][ws] [2026-06-16T00:54:32.877Z] stdout: 2026-06-16T02:54:32.874+02:00 [ws] ⇄ res ✓ agents.list 76ms id=64c7f47a…41a7
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:54:33.260Z] stdout: 2026-06-16T02:54:33.258+02:00 [ws] ⇄ res ✓ models.authStatus 33ms id=e6585292…ee83
[native-stdio][ws] [2026-06-16T00:54:33.896Z] stdout: 2026-06-16T02:54:33.893+02:00 [ws] ⇄ res ✓ commands.list 672ms id=bee7ada0…3017
[native-stdio][ws] [2026-06-16T00:54:33.923Z] stdout: 2026-06-16T02:54:33.920+02:00 [ws] ⇄ res ✓ sessions.list 701ms id=1a5021eb…fd8c
[native-stdio][ws] [2026-06-16T00:54:33.992Z] stdout: 2026-06-16T02:54:33.990+02:00 [ws] webchat disconnected code=1001 reason=n/a conn=be9d0c8f-bce9-4bb4-a7c9-3ccba7fab4fa
[native-stdio][ws] [2026-06-16T00:54:34.008Z] stdout: 2026-06-16T02:54:34.005+02:00 [ws] → event presence seq=per-client clients=4 dropIfSlow=true presenceVersion=6 healthVersion=14
[native-stdio][ws] [2026-06-16T00:54:34.026Z] stdout: 2026-06-16T02:54:34.023+02:00 [ws] → close code=1001 durationMs=352935 handshake=connected lastFrameType=req lastFrameMethod=commands.list lastFrameId=8cf2aad6-74ba-41ef-bc8f-6b66cf0014a1 endpoint=127.0.0.1:42064->127.0.0.1:18789 conn=be9d0c8f…b4fa
[native-stdio][ws] [2026-06-16T00:54:34.093Z] stdout: 2026-06-16T02:54:34.091+02:00 [ws] ⇄ res ✓ chat.history 872ms conn=abf533e3…84ab id=8bed53c0…9226
[native-stdio][ws] [2026-06-16T00:54:34.115Z] stdout: 2026-06-16T02:54:34.113+02:00 [ws] ⇄ res ✓ models.list 892ms id=4b789a03…9a6a
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:57:26.283Z] stdout: 2026-06-16T02:57:26.276+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=22.8 eventLoopDelayMaxMs=1292.9 eventLoopUtilization=0.059 cpuCoreRatio=0.048 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:11ms,sidecars.model-prewarm:5195ms,sidecars.restart-sentinel:361ms,post-attach.update-sentinel:193ms,sidecars.session-locks:473ms,post-ready.maintenance:104ms
[native-stdio][gateway] [2026-06-16T00:57:26.305Z] stdout: 2026-06-16T02:57:26.298+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:57:56.275Z] stdout: 2026-06-16T02:57:56.269+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:57:58.822Z] stdout: 2026-06-16T02:57:58.820+02:00 [ws] ⇄ res ✓ agents.list 25ms conn=2baab379…d59d id=7c83333a…00d5
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:57:59.569Z] stdout: 2026-06-16T02:57:59.566+02:00 [ws] webchat disconnected code=1001 reason=n/a conn=abf533e3-53ab-422f-8312-fcbd160d84ab
[native-stdio][ws] [2026-06-16T00:57:59.592Z] stdout: 2026-06-16T02:57:59.589+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=7 healthVersion=17
[native-stdio][ws] [2026-06-16T00:57:59.624Z] stdout: 2026-06-16T02:57:59.620+02:00 [ws] → close code=1001 durationMs=207346 handshake=connected lastFrameType=req lastFrameMethod=commands.list lastFrameId=bee7ada0-0059-46cb-9959-5b73b76e3017 endpoint=127.0.0.1:45716->127.0.0.1:18789 conn=abf533e3…84ab
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[native-stdio][plugins] [2026-06-16T00:46:13.368Z] stdout: 2026-06-16T02:46:13.367+02:00 [gateway] startup trace: sidecars.plugin-services.summary serviceCount=4.0 startedCount=4.0 failedCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:13.385Z] stdout: 2026-06-16T02:46:13.382+02:00 [gateway] startup trace: sidecars.plugin-services 2046.0ms total=17618.4ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:13.409Z] stdout: 2026-06-16T02:46:13.407+02:00 [gateway] startup trace: sidecars.memory 1.8ms total=17646.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:13.425Z] stdout: 2026-06-16T02:46:13.422+02:00 [gateway] startup trace: sidecars.total 2163.7ms total=17660.2ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:13.441Z] stdout: 2026-06-16T02:46:13.438+02:00 [gateway] startup trace: sidecars.plugin-loader callsCount=0.0 nativeHitsCount=0.0 nativeMissesCount=0.0 sourceTransformForcedCount=0.0 sourceTransformFallbacksCount=0.0
[native-stdio][plugins] [2026-06-16T00:46:13.460Z] stdout: 2026-06-16T02:46:13.457+02:00 [gateway] startup trace: sidecars.ready loadedPluginCount=12.0 postReadySidecarCount=1.0
[native-stdio][startup] [2026-06-16T00:46:13.475Z] stdout: 2026-06-16T02:46:13.473+02:00 [gateway] startup trace: sidecars.ready 48.8ms total=17709.1ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:46:13.488Z] stdout: 2026-06-16T02:46:13.485+02:00 [gateway] ready
[native-stdio][startup] [2026-06-16T00:46:13.554Z] stdout: 2026-06-16T02:46:13.549+02:00 [gateway] startup trace: runtime.post-attach 13803.0ms total=17781.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:13.571Z] stdout: 2026-06-16T02:46:13.569+02:00 [gateway] startup trace: memory.ready rssMb=425.4 heapTotalMb=278.2 heapUsedMb=252.4 externalMb=5.3 arrayBuffersMb=1.6 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=3.0 activeRequestsCount=2.0 activeTimersCount=1.0
[native-stdio][startup] [2026-06-16T00:46:13.584Z] stdout: 2026-06-16T02:46:13.581+02:00 [gateway] startup trace: ready 38.1ms total=17819.9ms eventLoopMax=0.0ms
[native-stdio][gateway] [2026-06-16T00:46:16.014Z] stdout: 2026-06-16T02:46:16.012+02:00 [heartbeat] started
[native-stdio][startup] [2026-06-16T00:46:16.220Z] stdout: 2026-06-16T02:46:16.218+02:00 [gateway] startup trace: sidecars.subagent-recovery 78.4ms total=20456.6ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.306Z] stdout: 2026-06-16T02:46:16.304+02:00 [gateway] startup trace: sidecars.main-session-recovery 42.3ms total=20543.9ms eventLoopMax=0.0ms
[native-stdio][plugins] [2026-06-16T00:46:16.331Z] stdout: 2026-06-16T02:46:16.329+02:00 [plugins] [hooks] running gateway_start (1 handlers)
[native-stdio][startup] [2026-06-16T00:46:16.452Z] stdout: 2026-06-16T02:46:16.450+02:00 [gateway] startup trace: post-attach.update-check 12.0ms total=20688.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.464Z] stderr: 2026-06-16T02:46:16.461+02:00 [gateway] startup model warmup timed out after 5000ms; continuing without waiting
[native-stdio][startup] [2026-06-16T00:46:16.475Z] stdout: 2026-06-16T02:46:16.473+02:00 [gateway] startup trace: sidecars.model-prewarm 5195.9ms total=20713.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.501Z] stdout: 2026-06-16T02:46:16.499+02:00 [gateway] startup trace: sidecars.restart-sentinel 361.6ms total=20737.2ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.513Z] stdout: 2026-06-16T02:46:16.511+02:00 [gateway] startup trace: post-attach.update-sentinel 194.0ms total=20750.8ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:16.591Z] stdout: 2026-06-16T02:46:16.589+02:00 [gateway] startup trace: sidecars.session-locks 473.6ms total=20827.3ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:18.838Z] stdout: 2026-06-16T02:46:18.836+02:00 [gateway] startup trace: post-ready.maintenance 109.5ms total=23075.7ms eventLoopMax=0.0ms
[native-stdio][startup] [2026-06-16T00:46:18.851Z] stdout: 2026-06-16T02:46:18.849+02:00 [gateway] startup trace: memory.post-ready rssMb=472.0 heapTotalMb=331.4 heapUsedMb=302.2 externalMb=5.4 arrayBuffersMb=1.7 processSigintListenersCount=2.0 processSigtermListenersCount=2.0 processSigusr1ListenersCount=1.0 activeHandlesCount=4.0 activeRequestsCount=2.0 activeTimersCount=5.0
[native-stdio][ws] [2026-06-16T00:46:20.468Z] stdout: 2026-06-16T02:46:20.466+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=ui clientId=openclaw-control-ui platform=android auth=token
[native-stdio][ws] [2026-06-16T00:46:20.503Z] stdout: 2026-06-16T02:46:20.500+02:00 [ws] → hello-ok methods=177 events=27 presence=2 stateVersion=2
[native-stdio][ws] [2026-06-16T00:46:21.201Z] stdout: 2026-06-16T02:46:21.200+02:00 [ws] ⇄ res ✓ health 415ms cached=true id=c564c99c…af39
[native-stdio][skills] [2026-06-16T00:46:23.059Z] stdout: 2026-06-16T02:46:23.056+02:00 [ws] ⇄ res ✓ skills.status 1602ms id=5b127b80…89df
[native-stdio][ws] [2026-06-16T00:46:23.130Z] stdout: 2026-06-16T02:46:23.127+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=55200 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55200->127.0.0.1:18789 conn=b115adff…e320
[native-stdio][ws] [2026-06-16T00:46:23.817Z] stdout: 2026-06-16T02:46:23.814+02:00 [ws] → event node.pair.requested seq=per-client clients=1 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:46:23.843Z] stdout: 2026-06-16T02:46:23.840+02:00 [ws] ← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.28 mode=node clientId=node-host platform=android auth=token
[native-stdio][ws] [2026-06-16T00:46:23.876Z] stdout: 2026-06-16T02:46:23.873+02:00 [ws] → hello-ok methods=177 events=27 presence=3 stateVersion=3
[native-stdio][provider] [2026-06-16T00:46:43.805Z] stdout: 2026-06-16T02:46:43.802+02:00 [gateway] provider auth state pre-warmed in 24355ms eventLoopMax=1633.7ms
[native-stdio][ws] [2026-06-16T00:48:33.938Z] stdout: 2026-06-16T02:48:33.935+02:00 [ws] ⇄ res ✓ agents.list 209ms conn=2baab379…d59d id=7808924c…5883
[native-stdio][ws] [2026-06-16T00:48:41.066Z] stdout: 2026-06-16T02:48:41.063+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=42064 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42064->127.0.0.1:18789 conn=be9d0c8f…b4fa
[native-stdio][tools] [2026-06-16T00:48:41.261Z] stdout: 2026-06-16T02:48:41.259+02:00 [gateway] device pairing auto-approved device=ad2d40a460b8da96c61995431ff111512286a04b4328026d0f3cd9022eb618f3 role=operator
[native-stdio][tools] [2026-06-16T00:48:41.276Z] stdout: 2026-06-16T02:48:41.274+02:00 [ws] → event device.pair.resolved seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:48:41.318Z] stdout: 2026-06-16T02:48:41.316+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=webchat clientId=openclaw-control-ui platform=Linux aarch64 auth=token
[native-stdio][ws] [2026-06-16T00:48:41.329Z] stdout: 2026-06-16T02:48:41.327+02:00 [ws] webchat connected conn=be9d0c8f-bce9-4bb4-a7c9-3ccba7fab4fa remote=127.0.0.1 client=openclaw-control-ui webchat v2026.5.28
[native-stdio][ws] [2026-06-16T00:48:41.352Z] stdout: 2026-06-16T02:48:41.349+02:00 [ws] → hello-ok methods=177 events=27 presence=4 stateVersion=4
[native-stdio][ws] [2026-06-16T00:48:41.878Z] stdout: 2026-06-16T02:48:41.875+02:00 [ws] ⇄ res ✓ health 36ms cached=true id=fa63bf69…70c6
[native-stdio][ws] [2026-06-16T00:48:41.900Z] stdout: 2026-06-16T02:48:41.897+02:00 [ws] ⇄ res ✓ agents.list 61ms id=4013bac4…087a
[native-stdio][ws] [2026-06-16T00:48:43.905Z] stdout: 2026-06-16T02:48:43.903+02:00 [ws] ⇄ res ✓ sessions.subscribe 2071ms id=56003048…e672
[native-stdio][ws] [2026-06-16T00:48:43.930Z] stdout: 2026-06-16T02:48:43.928+02:00 [ws] ⇄ res ✓ sessions.messages.subscribe 2097ms id=66b243fa…24eb
[native-stdio][ws] [2026-06-16T00:48:43.949Z] stdout: 2026-06-16T02:48:43.947+02:00 [ws] ⇄ res ✓ agent.identity.get 2117ms id=3e653596…6d52
[native-stdio][ws] [2026-06-16T00:48:45.435Z] stdout: 2026-06-16T02:48:45.433+02:00 [ws] ⇄ res ✓ models.authStatus 1427ms id=abf96576…b9a7
[native-stdio][ws] [2026-06-16T00:48:46.290Z] stdout: 2026-06-16T02:48:46.287+02:00 [ws] ⇄ res ✓ commands.list 2281ms id=8cf2aad6…14a1
[native-stdio][gateway] [2026-06-16T00:48:46.375Z] stdout: 2026-06-16T02:48:46.373+02:00 [gateway] sessions.list continuing without model catalog after 750ms
[native-stdio][ws] [2026-06-16T00:48:46.419Z] stdout: 2026-06-16T02:48:46.416+02:00 [ws] ⇄ res ✓ sessions.list 2407ms id=187bacd0…813c
[native-stdio][ws] [2026-06-16T00:48:46.563Z] stdout: 2026-06-16T02:48:46.561+02:00 [ws] ⇄ res ✓ chat.history 2555ms id=e745a597…96c1
[native-stdio][ws] [2026-06-16T00:48:46.654Z] stdout: 2026-06-16T02:48:46.651+02:00 [ws] ⇄ res ✓ models.list 2644ms id=0d2785e2…9807
[native-stdio][warn] [2026-06-16T00:48:56.255Z] stdout: 2026-06-16T02:48:56.250+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=44.1 eventLoopDelayMaxMs=2382.4 eventLoopUtilization=0.224 cpuCoreRatio=0.26 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:11ms,sidecars.model-prewarm:5195ms,sidecars.restart-sentinel:361ms,post-attach.update-sentinel:193ms,sidecars.session-locks:473ms,post-ready.maintenance:104ms
[native-stdio][gateway] [2026-06-16T00:48:56.265Z] stdout: 2026-06-16T02:48:56.262+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:49:26.251Z] stdout: 2026-06-16T02:49:26.247+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:49:56.250Z] stdout: 2026-06-16T02:49:56.246+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:50:26.267Z] stdout: 2026-06-16T02:50:26.260+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:50:56.247Z] stdout: 2026-06-16T02:50:56.245+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:54:32.226Z] stdout: 2026-06-16T02:54:32.223+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=45716 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45716->127.0.0.1:18789 conn=abf533e3…84ab
[native-stdio][ws] [2026-06-16T00:54:32.345Z] stdout: 2026-06-16T02:54:32.343+02:00 [ws] ← connect client=openclaw-control-ui version=2026.5.28 mode=webchat clientId=openclaw-control-ui platform=Linux aarch64 auth=token
[native-stdio][ws] [2026-06-16T00:54:32.355Z] stdout: 2026-06-16T02:54:32.353+02:00 [ws] webchat connected conn=abf533e3-53ab-422f-8312-fcbd160d84ab remote=127.0.0.1 client=openclaw-control-ui webchat v2026.5.28
[native-stdio][ws] [2026-06-16T00:54:32.382Z] stdout: 2026-06-16T02:54:32.380+02:00 [ws] → hello-ok methods=177 events=27 presence=2 stateVersion=5
[native-stdio][ws] [2026-06-16T00:54:32.800Z] stdout: 2026-06-16T02:54:32.797+02:00 [ws] ⇄ res ✓ sessions.subscribe 6ms id=edf08b9a…76f1
[native-stdio][ws] [2026-06-16T00:54:32.817Z] stdout: 2026-06-16T02:54:32.815+02:00 [ws] ⇄ res ✓ sessions.messages.subscribe 23ms id=e4eb647f…325d
[native-stdio][ws] [2026-06-16T00:54:32.832Z] stdout: 2026-06-16T02:54:32.830+02:00 [ws] ⇄ res ✓ agent.identity.get 37ms id=34bd56b4…3c66
[native-stdio][ws] [2026-06-16T00:54:32.852Z] stdout: 2026-06-16T02:54:32.849+02:00 [ws] ⇄ res ✓ health 51ms cached=true id=941df7fe…c8c3
[native-stdio][ws] [2026-06-16T00:54:32.877Z] stdout: 2026-06-16T02:54:32.874+02:00 [ws] ⇄ res ✓ agents.list 76ms id=64c7f47a…41a7
[native-stdio][ws] [2026-06-16T00:54:33.260Z] stdout: 2026-06-16T02:54:33.258+02:00 [ws] ⇄ res ✓ models.authStatus 33ms id=e6585292…ee83
[native-stdio][ws] [2026-06-16T00:54:33.896Z] stdout: 2026-06-16T02:54:33.893+02:00 [ws] ⇄ res ✓ commands.list 672ms id=bee7ada0…3017
[native-stdio][ws] [2026-06-16T00:54:33.923Z] stdout: 2026-06-16T02:54:33.920+02:00 [ws] ⇄ res ✓ sessions.list 701ms id=1a5021eb…fd8c
[native-stdio][ws] [2026-06-16T00:54:33.992Z] stdout: 2026-06-16T02:54:33.990+02:00 [ws] webchat disconnected code=1001 reason=n/a conn=be9d0c8f-bce9-4bb4-a7c9-3ccba7fab4fa
[native-stdio][ws] [2026-06-16T00:54:34.008Z] stdout: 2026-06-16T02:54:34.005+02:00 [ws] → event presence seq=per-client clients=4 dropIfSlow=true presenceVersion=6 healthVersion=14
[native-stdio][ws] [2026-06-16T00:54:34.026Z] stdout: 2026-06-16T02:54:34.023+02:00 [ws] → close code=1001 durationMs=352935 handshake=connected lastFrameType=req lastFrameMethod=commands.list lastFrameId=8cf2aad6-74ba-41ef-bc8f-6b66cf0014a1 endpoint=127.0.0.1:42064->127.0.0.1:18789 conn=be9d0c8f…b4fa
[native-stdio][ws] [2026-06-16T00:54:34.093Z] stdout: 2026-06-16T02:54:34.091+02:00 [ws] ⇄ res ✓ chat.history 872ms conn=abf533e3…84ab id=8bed53c0…9226
[native-stdio][ws] [2026-06-16T00:54:34.115Z] stdout: 2026-06-16T02:54:34.113+02:00 [ws] ⇄ res ✓ models.list 892ms id=4b789a03…9a6a
[native-stdio][warn] [2026-06-16T00:57:26.283Z] stdout: 2026-06-16T02:57:26.276+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=22.8 eventLoopDelayMaxMs=1292.9 eventLoopUtilization=0.059 cpuCoreRatio=0.048 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:11ms,sidecars.model-prewarm:5195ms,sidecars.restart-sentinel:361ms,post-attach.update-sentinel:193ms,sidecars.session-locks:473ms,post-ready.maintenance:104ms
[native-stdio][gateway] [2026-06-16T00:57:26.305Z] stdout: 2026-06-16T02:57:26.298+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:57:56.275Z] stdout: 2026-06-16T02:57:56.269+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:57:58.822Z] stdout: 2026-06-16T02:57:58.820+02:00 [ws] ⇄ res ✓ agents.list 25ms conn=2baab379…d59d id=7c83333a…00d5
[native-stdio][ws] [2026-06-16T00:57:59.569Z] stdout: 2026-06-16T02:57:59.566+02:00 [ws] webchat disconnected code=1001 reason=n/a conn=abf533e3-53ab-422f-8312-fcbd160d84ab
[native-stdio][ws] [2026-06-16T00:57:59.592Z] stdout: 2026-06-16T02:57:59.589+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=7 healthVersion=17
[native-stdio][ws] [2026-06-16T00:57:59.624Z] stdout: 2026-06-16T02:57:59.620+02:00 [ws] → close code=1001 durationMs=207346 handshake=connected lastFrameType=req lastFrameMethod=commands.list lastFrameId=bee7ada0-0059-46cb-9959-5b73b76e3017 endpoint=127.0.0.1:45716->127.0.0.1:18789 conn=abf533e3…84ab
[native] log stream resumed after rotation or runtime restart
[native-stdio][chat] [2026-06-16T00:58:15.779Z] stdout: 2026-06-16T02:58:15.776+02:00 [ws] ⇄ res ✓ chat.send 201ms runId=6b4283b6-f141-4063-b451-1c34d7fa4912 conn=2baab379…d59d id=c346fc87…5608
[native-stdio][gateway] [2026-06-16T00:58:15.846Z] stdout: 2026-06-16T02:58:15.842+02:00 [diagnostic] message received: channel=webchat chatId=unknown messageId=6b4283b6-f141-4063-b451-1c34d7fa4912 sessionId=unknown sessionKey=agent:main:main source=dispatchInboundMessage
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:58:17.191Z] stdout: 2026-06-16T02:58:17.188+02:00 [plugins] loading browser from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/browser/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.246Z] stdout: 2026-06-16T02:58:17.243+02:00 [plugins] loading canvas from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/canvas/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.285Z] stdout: 2026-06-16T02:58:17.282+02:00 [plugins] loading device-pair from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/device-pair/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.323Z] stdout: 2026-06-16T02:58:17.309+02:00 Registered plugin command: /pair (plugin: device-pair)
[native-stdio][plugins] [2026-06-16T00:58:17.334Z] stdout: 2026-06-16T02:58:17.331+02:00 [plugins] loading file-transfer from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.361Z] stdout: 2026-06-16T02:58:17.358+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.403Z] stdout: 2026-06-16T02:58:17.401+02:00 [plugins] loading memory-core from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/memory-core/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.435Z] stdout: 2026-06-16T02:58:17.426+02:00 Registered plugin command: /dreaming (plugin: memory-core)
[native-stdio][plugins] [2026-06-16T00:58:17.444Z] stdout: 2026-06-16T02:58:17.441+02:00 [plugins] loading microsoft from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.470Z] stdout: 2026-06-16T02:58:17.467+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.505Z] stdout: 2026-06-16T02:58:17.502+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.541Z] stdout: 2026-06-16T02:58:17.538+02:00 [plugins] loading phone-control from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/phone-control/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.579Z] stdout: 2026-06-16T02:58:17.566+02:00 Registered plugin command: /phone (plugin: phone-control)
[native-stdio][plugins] [2026-06-16T00:58:17.587Z] stdout: 2026-06-16T02:58:17.584+02:00 [plugins] loading talk-voice from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.630Z] stdout: 2026-06-16T02:58:17.613+02:00 Registered plugin command: /voice (plugin: talk-voice)
[native-stdio][plugins] [2026-06-16T00:58:17.640Z] stdout: 2026-06-16T02:58:17.636+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:58:17.663Z] stdout: 2026-06-16T02:58:17.661+02:00 [plugins] loaded 12 plugin(s) (12 attempted) in 479.3ms
[native-stdio][gateway] [2026-06-16T00:58:17.726Z] stdout: 2026-06-16T02:58:17.723+02:00 [diagnostic] message queued: sessionId=unknown sessionKey=agent:main:main source=dispatch queueDepth=1 sessionState=idle
[native-stdio][gateway] [2026-06-16T00:58:17.732Z] stdout: 2026-06-16T02:58:17.729+02:00 [diagnostic] session state: sessionId=unknown sessionKey=agent:main:main prev=idle new=processing reason="message_start" queueDepth=1
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:58:19.543Z] stdout: 2026-06-16T02:58:19.539+02:00 [diagnostic] message dispatch started: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:58:23.828Z] stdout: 2026-06-16T02:58:23.826+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:58:23.854Z] stdout: 2026-06-16T02:58:23.852+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 28.6ms
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:58:25.278Z] stdout: 2026-06-16T02:58:25.275+02:00 [plugins] loading deepinfra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js
[native-stdio][plugins] [2026-06-16T00:58:25.508Z] stdout: 2026-06-16T02:58:25.506+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 234.7ms
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:58:40.917Z] stdout: 2026-06-16T02:58:40.915+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=45s eventLoopDelayP99Ms=28.7 eventLoopDelayMaxMs=18807.3 eventLoopUtilization=0.579 cpuCoreRatio=0.606 active=1 waiting=0 queued=0 recentPhases=post-attach.update-check:11ms,sidecars.model-prewarm:5195ms,sidecars.restart-sentinel:361ms,post-attach.update-sentinel:193ms,sidecars.session-locks:473ms,post-ready.maintenance:104ms work=[active=agent:main:main(processing/embedded_run,q=1,age=23s last=embedded_run:started)]
[native-stdio][gateway] [2026-06-16T00:58:40.921Z] stdout: 2026-06-16T02:58:40.919+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native-stdio][plugins] [2026-06-16T00:58:41.414Z] stdout: 2026-06-16T02:58:41.411+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:58:41.431Z] stdout: 2026-06-16T02:58:41.428+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 19.9ms
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:58:41.495Z] stdout: 2026-06-16T02:58:41.493+02:00 [plugins] loading anthropic from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/anthropic/index.js
[native-stdio][plugins] [2026-06-16T00:58:41.827Z] stdout: 2026-06-16T02:58:41.825+02:00 [plugins] loading arcee from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/arcee/index.js
[native-stdio][plugins] [2026-06-16T00:58:41.904Z] stdout: 2026-06-16T02:58:41.902+02:00 [plugins] loading byteplus from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/byteplus/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.006Z] stdout: 2026-06-16T02:58:42.004+02:00 [plugins] loading cerebras from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/cerebras/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.077Z] stdout: 2026-06-16T02:58:42.074+02:00 [plugins] loading chutes from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/chutes/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.193Z] stdout: 2026-06-16T02:58:42.191+02:00 [plugins] loading cloudflare-ai-gateway from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.305Z] stdout: 2026-06-16T02:58:42.303+02:00 [plugins] loading comfy from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/comfy/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.445Z] stdout: 2026-06-16T02:58:42.441+02:00 [plugins] loading copilot-proxy from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.502Z] stdout: 2026-06-16T02:58:42.499+02:00 [plugins] loading deepinfra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.530Z] stdout: 2026-06-16T02:58:42.527+02:00 [plugins] loading deepseek from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/deepseek/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.616Z] stdout: 2026-06-16T02:58:42.613+02:00 [plugins] loading fal from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/fal/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.786Z] stdout: 2026-06-16T02:58:42.785+02:00 [plugins] loading fireworks from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/fireworks/index.js
[native-stdio][plugins] [2026-06-16T00:58:42.876Z] stdout: 2026-06-16T02:58:42.874+02:00 [plugins] loading github-copilot from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js
[native-stdio][plugins] [2026-06-16T00:58:43.062Z] stdout: 2026-06-16T02:58:43.059+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:58:43.082Z] stdout: 2026-06-16T02:58:43.080+02:00 [plugins] loading groq from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/groq/index.js
[native-stdio][plugins] [2026-06-16T00:58:43.133Z] stdout: 2026-06-16T02:58:43.132+02:00 [plugins] loading huggingface from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/huggingface/index.js
[native-stdio][plugins] [2026-06-16T00:58:43.213Z] stdout: 2026-06-16T02:58:43.210+02:00 [plugins] loading kilocode from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/kilocode/index.js
[native-stdio][plugins] [2026-06-16T00:58:43.307Z] stdout: 2026-06-16T02:58:43.305+02:00 [plugins] loading kimi from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js
[native-stdio][plugins] [2026-06-16T00:58:43.466Z] stdout: 2026-06-16T02:58:43.464+02:00 [plugins] loading litellm from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/litellm/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:58:43.589Z] stdout: 2026-06-16T02:58:43.587+02:00 [plugins] loading lmstudio from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js
[native-stdio][plugins] [2026-06-16T00:58:43.906Z] stdout: 2026-06-16T02:58:43.904+02:00 [plugins] loading microsoft-foundry from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js
[native-stdio][plugins] [2026-06-16T00:58:44.052Z] stdout: 2026-06-16T02:58:44.050+02:00 [plugins] loading minimax from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/minimax/index.js
[native-stdio][plugins] [2026-06-16T00:58:44.298Z] stdout: 2026-06-16T02:58:44.295+02:00 [plugins] loading mistral from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/mistral/index.js
[native-stdio][plugins] [2026-06-16T00:58:44.436Z] stdout: 2026-06-16T02:58:44.434+02:00 [plugins] loading moonshot from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/moonshot/index.js
[native-stdio][plugins] [2026-06-16T00:58:44.538Z] stdout: 2026-06-16T02:58:44.536+02:00 [plugins] loading nvidia from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/nvidia/index.js
[native-stdio][plugins] [2026-06-16T00:58:44.607Z] stdout: 2026-06-16T02:58:44.606+02:00 [plugins] loading ollama from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/ollama/index.js
[native-stdio][plugins] [2026-06-16T00:58:44.975Z] stdout: 2026-06-16T02:58:44.973+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:58:44.994Z] stdout: 2026-06-16T02:58:44.992+02:00 [plugins] loading opencode from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/opencode/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.084Z] stdout: 2026-06-16T02:58:45.082+02:00 [plugins] loading opencode-go from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.216Z] stdout: 2026-06-16T02:58:45.213+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.243Z] stdout: 2026-06-16T02:58:45.239+02:00 [plugins] loading qianfan from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/qianfan/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.341Z] stdout: 2026-06-16T02:58:45.338+02:00 [plugins] loading qwen from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/qwen/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.505Z] stdout: 2026-06-16T02:58:45.503+02:00 [plugins] loading sglang from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/sglang/index.js
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:58:45.582Z] stdout: 2026-06-16T02:58:45.579+02:00 [plugins] loading stepfun from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/stepfun/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.665Z] stdout: 2026-06-16T02:58:45.663+02:00 [plugins] loading synthetic from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/synthetic/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.741Z] stdout: 2026-06-16T02:58:45.739+02:00 [plugins] loading tencent from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/tencent/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.822Z] stdout: 2026-06-16T02:58:45.819+02:00 [plugins] loading together from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/together/index.js
[native-stdio][plugins] [2026-06-16T00:58:45.942Z] stdout: 2026-06-16T02:58:45.940+02:00 [plugins] loading venice from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/venice/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.062Z] stdout: 2026-06-16T02:58:46.059+02:00 [plugins] loading vercel-ai-gateway from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.162Z] stdout: 2026-06-16T02:58:46.158+02:00 [plugins] loading vllm from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vllm/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.270Z] stdout: 2026-06-16T02:58:46.268+02:00 [plugins] loading volcengine from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/volcengine/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.379Z] stdout: 2026-06-16T02:58:46.376+02:00 [plugins] loading vydra from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/vydra/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.530Z] stdout: 2026-06-16T02:58:46.526+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.554Z] stdout: 2026-06-16T02:58:46.552+02:00 [plugins] loading xiaomi from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.718Z] stdout: 2026-06-16T02:58:46.715+02:00 [plugins] loading zai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/zai/index.js
[native-stdio][plugins] [2026-06-16T00:58:46.841Z] stdout: 2026-06-16T02:58:46.839+02:00 [plugins] loaded 45 plugin(s) (45 attempted) in 5348.4ms
[native] log stream resumed after rotation or runtime restart
[native-stdio][plugins] [2026-06-16T00:58:48.214Z] stdout: 2026-06-16T02:58:48.211+02:00 [plugins] loading anthropic from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/anthropic/index.js
[native-stdio][plugins] [2026-06-16T00:58:48.233Z] stdout: 2026-06-16T02:58:48.230+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 21.4ms
[native-stdio][plugins] [2026-06-16T00:58:48.289Z] stdout: 2026-06-16T02:58:48.287+02:00 [plugins] [hooks] running before_agent_reply (1 handlers, first-claim wins)
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:58:50.310Z] stdout: 2026-06-16T02:58:50.293+02:00 preflightCompaction check: sessionKey=agent:main:main tokenCount=63071 contextWindow=131072 threshold=107072 serverCompactionThreshold=undefined isHeartbeat=false isCli=false persistedFresh=true transcriptPromptTokens=undefined promptTokensEst=5182 activeTranscriptBytes=undefined maxActiveTranscriptBytes=undefined sizeTrigger=false
[native-stdio][gateway] [2026-06-16T00:58:50.399Z] stdout: 2026-06-16T02:58:50.390+02:00 memoryFlush check: sessionKey=agent:main:main tokenCount=68253 contextWindow=131072 threshold=107072 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=63071 persistedFresh=true promptTokensEst=5182 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=68253 transcriptBytes=264853 forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[native-stdio][gateway] [2026-06-16T00:58:50.416Z] stdout: 2026-06-16T02:58:50.414+02:00 [diagnostic] session turn created: runId=6b4283b6-f141-4063-b451-1c34d7fa4912 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main agentId=main channel=webchat trigger=user
[native-stdio][gateway] [2026-06-16T00:58:51.098Z] stdout: 2026-06-16T02:58:51.093+02:00 [diagnostic] lane enqueue: lane=session:agent:main:main queueSize=1
[native-stdio][gateway] [2026-06-16T00:58:51.107Z] stdout: 2026-06-16T02:58:51.104+02:00 [diagnostic] lane dequeue: lane=session:agent:main:main waitMs=11 queueSize=0
[native-stdio][gateway] [2026-06-16T00:58:51.126Z] stdout: 2026-06-16T02:58:51.123+02:00 [diagnostic] lane enqueue: lane=main queueSize=1
[native-stdio][gateway] [2026-06-16T00:58:51.133Z] stdout: 2026-06-16T02:58:51.130+02:00 [diagnostic] lane dequeue: lane=main waitMs=6 queueSize=0
[native-stdio][provider] [2026-06-16T00:58:51.518Z] stdout: 2026-06-16T02:58:51.516+02:00 [openrouter-model-capabilities] Loaded 338 OpenRouter models from disk cache
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:58:53.063Z] stdout: 2026-06-16T02:58:53.061+02:00 [agents/harness] agent harness selected
[native-stdio][provider] [2026-06-16T00:58:53.116Z] stdout: 2026-06-16T02:58:53.113+02:00 [agent/embedded] embedded run start: runId=6b4283b6-f141-4063-b451-1c34d7fa4912 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter model=openai/gpt-oss-20b:free thinking=off messageChannel=webchat
[native-stdio][plugins] [2026-06-16T00:58:53.368Z] stdout: 2026-06-16T02:58:53.367+02:00 [plugins] loading browser from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/browser/index.js
[native-stdio][plugins] [2026-06-16T00:58:53.388Z] stdout: 2026-06-16T02:58:53.385+02:00 [plugins] loading canvas from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/canvas/index.js
[native-stdio][plugins] [2026-06-16T00:58:53.413Z] stdout: 2026-06-16T02:58:53.410+02:00 [plugins] loading file-transfer from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js
[native-stdio][plugins] [2026-06-16T00:58:53.438Z] stdout: 2026-06-16T02:58:53.435+02:00 [plugins] loading memory-core from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/memory-core/index.js
[native-stdio][plugins] [2026-06-16T00:58:53.459Z] stdout: 2026-06-16T02:58:53.457+02:00 [plugins] loaded 11 plugin(s) (4 attempted) in 92.3ms
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:58:54.788Z] stdout: 2026-06-16T02:58:54.786+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=processing reason="run_started" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:58:54.791Z] stdout: 2026-06-16T02:58:54.789+02:00 [diagnostic] run registered: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=1
[native-stdio][provider] [2026-06-16T00:58:54.826Z] stdout: 2026-06-16T02:58:54.823+02:00 [agent/embedded] embedded run prompt start: runId=6b4283b6-f141-4063-b451-1c34d7fa4912 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:58:55.044Z] stdout: 2026-06-16T02:58:55.042+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=39 roleCounts=assistant:20,toolResult:10,user:9 historyTextChars=186232 maxMessageTextChars=25309 historyImageBlocks=0 systemPromptChars=34736 promptChars=20725 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:58:55.060Z] stdout: 2026-06-16T02:58:55.057+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=91096 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=39 unwindowedMessages=39 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:58:55.184Z] stdout: 2026-06-16T02:58:55.181+02:00 [agent/embedded] embedded run agent start: runId=6b4283b6-f141-4063-b451-1c34d7fa4912
[native-stdio][ws] [2026-06-16T00:58:55.391Z] stdout: 2026-06-16T02:58:55.389+02:00 [ws] → event agent seq=per-client clients=2 run=6b4283b6…4912 agent=main session=main stream=lifecycle aseq=1 phase=start
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:58:55.723Z] stdout: 2026-06-16T02:58:55.721+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:58:58.469Z] stdout: 2026-06-16T02:58:58.467+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2747 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:59:01.523Z] stdout: 2026-06-16T02:59:01.521+02:00 [ws] → event agent seq=per-client clients=2 run=6b4283b6…4912 agent=main session=main stream=assistant aseq=2 text=I’ve asked the
[native-stdio][ws] [2026-06-16T00:59:01.539Z] stdout: 2026-06-16T02:59:01.537+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:59:01.674Z] stdout: 2026-06-16T02:59:01.672+02:00 [ws] → event agent seq=per-client clients=2 run=6b4283b6…4912 agent=main session=main stream=assistant aseq=10 text=I’ve asked the avatar to do the “sitting both
[native-stdio][ws] [2026-06-16T00:59:01.688Z] stdout: 2026-06-16T02:59:01.686+02:00 [ws] → event agent seq=per-client clients=2 run=6b4283b6…4912 agent=main session=main stream=assistant aseq=11 text=I’ve asked the avatar to do the “sitting both wave
[native-stdio][ws] [2026-06-16T00:59:01.705Z] stdout: 2026-06-16T02:59:01.703+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:59:01.823Z] stdout: 2026-06-16T02:59:01.821+02:00 [agent/embedded] embedded run agent end: runId=6b4283b6-f141-4063-b451-1c34d7fa4912 isError=false
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:59:01.831Z] stdout: 2026-06-16T02:59:01.828+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:59:01.834Z] stdout: 2026-06-16T02:59:01.833+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][ws] [2026-06-16T00:59:01.848Z] stdout: 2026-06-16T02:59:01.846+02:00 [ws] → event agent seq=per-client clients=2 run=6b4283b6…4912 agent=main session=main stream=assistant aseq=24 text=I’ve asked the avatar to do the “sitting both wave” gesture for you. Enjoy the duck‑themed pose!
[native-stdio][ws] [2026-06-16T00:59:01.861Z] stdout: 2026-06-16T02:59:01.859+02:00 [ws] → event agent seq=per-client clients=2 run=6b4283b6…4912 agent=main session=main stream=lifecycle aseq=25 phase=end
[native-stdio][ws] [2026-06-16T00:59:01.878Z] stdout: 2026-06-16T02:59:01.876+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:59:01.893Z] stdout: 2026-06-16T02:59:01.890+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:59:01.911Z] stdout: 2026-06-16T02:59:01.907+02:00 [agent/embedded] embedded run prompt end: runId=6b4283b6-f141-4063-b451-1c34d7fa4912 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=7112
[native-stdio][plugins] [2026-06-16T00:59:02.478Z] stdout: 2026-06-16T02:59:02.474+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:59:02.494Z] stdout: 2026-06-16T02:59:02.491+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 18.4ms
[native-stdio][plugins] [2026-06-16T00:59:02.846Z] stdout: 2026-06-16T02:59:02.843+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:59:02.865Z] stdout: 2026-06-16T02:59:02.862+02:00 [plugins] loaded 1 plugin(s) (1 attempted) in 20.0ms
[native-stdio][plugins] [2026-06-16T00:59:03.212Z] stdout: 2026-06-16T02:59:03.208+02:00 [plugins] loading google from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/google/index.js
[native-stdio][plugins] [2026-06-16T00:59:03.231Z] stdout: 2026-06-16T02:59:03.228+02:00 [plugins] loading microsoft from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/microsoft/index.js
[native-stdio][plugins] [2026-06-16T00:59:03.248Z] stdout: 2026-06-16T02:59:03.246+02:00 [plugins] loading openai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openai/index.js
[native-stdio][plugins] [2026-06-16T00:59:03.267Z] stdout: 2026-06-16T02:59:03.265+02:00 [plugins] loading openrouter from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/openrouter/index.js
[native-stdio][plugins] [2026-06-16T00:59:03.284Z] stdout: 2026-06-16T02:59:03.282+02:00 [plugins] loading xai from /data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/xai/index.js
[native-stdio][plugins] [2026-06-16T00:59:03.301Z] stdout: 2026-06-16T02:59:03.299+02:00 [plugins] loaded 5 plugin(s) (5 attempted) in 93.3ms
[native-stdio][provider] [2026-06-16T00:59:03.673Z] stdout: 2026-06-16T02:59:03.662+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:59:04.426Z] stdout: 2026-06-16T02:59:04.424+02:00 [agent/embedded] embedded run done: runId=6b4283b6-f141-4063-b451-1c34d7fa4912 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=13268 aborted=false
[native-stdio][gateway] [2026-06-16T00:59:04.623Z] stdout: 2026-06-16T02:59:04.620+02:00 [diagnostic] lane task done: lane=main durationMs=13483 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:59:04.630Z] stdout: 2026-06-16T02:59:04.626+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=13516 active=0 queued=0
[native-stdio][tts] [2026-06-16T00:59:05.773Z] stdout: 2026-06-16T02:59:05.771+02:00 [ws] ⇄ res ✓ talk.speak 3834ms id=7223a2c2…b4ca
[native-stdio][gateway] [2026-06-16T00:59:05.900Z] stdout: 2026-06-16T02:59:05.897+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=46358ms
[native-stdio][gateway] [2026-06-16T00:59:05.908Z] stdout: 2026-06-16T02:59:05.906+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=6b4283b6-f141-4063-b451-1c34d7fa4912 sessionId=unknown sessionKey=agent:main:main outcome=completed duration=50023ms
[native-stdio][gateway] [2026-06-16T00:59:05.915Z] stdout: 2026-06-16T02:59:05.912+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:59:11.073Z] stdout: 2026-06-16T02:59:11.066+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][gateway] [2026-06-16T00:59:11.096Z] stdout: 2026-06-16T02:59:11.093+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:59:12.632Z] stdout: 2026-06-16T02:59:12.630+02:00 [ws] ⇄ res ✓ talk.speak 1983ms id=5f99d296…b3bc
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:59:41.097Z] stdout: 2026-06-16T02:59:41.094+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T01:00:11.098Z] stdout: 2026-06-16T03:00:11.095+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T01:00:41.097Z] stdout: 2026-06-16T03:00:41.094+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0

2 attachments
		1000172562.jpg
1460K View Scan and download
		1000172563.jpg
1535K View Scan and download

IT JUST RESTARTED ON ITS OWN THIS IS A HUGE FAILURE...
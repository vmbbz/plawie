Gifgrep skills error says tool not exposed as part of Node
Cosy <cosychiruka@gmail.com>	Tue, Jun 16, 2026 at 2:41 AM
To: Cosy <cosychiruka@gmail.com>
[native-stdio][provider] [2026-06-16T00:31:28.650Z] stdout: 2026-06-16T02:31:28.647+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:31:30.748Z] stdout: 2026-06-16T02:31:30.743+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2096 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:31:37.860Z] stdout: 2026-06-16T02:31:37.856+02:00 [agent/embedded] embedded run tool start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=canvas toolCallId=chatcmpl-tool-8974b271de8e68ab
[native-stdio][ws] [2026-06-16T00:31:37.881Z] stdout: 2026-06-16T02:31:37.878+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=19
[native-stdio][ws] [2026-06-16T00:31:37.924Z] stdout: 2026-06-16T02:31:37.922+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=35798 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35798->127.0.0.1:18789 conn=7e03ecdb…ffbf
[native-stdio][ws] [2026-06-16T00:31:37.953Z] stdout: 2026-06-16T02:31:37.950+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:31:37.968Z] stdout: 2026-06-16T02:31:37.965+02:00 [ws] → hello-ok methods=177 events=27 presence=3 stateVersion=6
[native-stdio][ws] [2026-06-16T00:31:38.224Z] stdout: 2026-06-16T02:31:38.222+02:00 [ws] ⇄ res ✓ node.list 9ms id=9f6542a7…c2a0
[native-stdio][ws] [2026-06-16T00:31:38.251Z] stdout: 2026-06-16T02:31:38.248+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=7 healthVersion=31
[native-stdio][ws] [2026-06-16T00:31:38.264Z] stdout: 2026-06-16T02:31:38.262+02:00 [ws] → close code=1005 durationMs=327 handshake=connected lastFrameType=req lastFrameMethod=node.list lastFrameId=9f6542a7-b588-42df-ae55-8e652cdec2a0 endpoint=127.0.0.1:35798->127.0.0.1:18789
[native-stdio][ws] [2026-06-16T00:31:38.305Z] stdout: 2026-06-16T02:31:38.303+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=35804 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35804->127.0.0.1:18789 conn=1d19594b…2739
[native-stdio][ws] [2026-06-16T00:31:38.328Z] stdout: 2026-06-16T02:31:38.326+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:31:38.342Z] stdout: 2026-06-16T02:31:38.340+02:00 [ws] → hello-ok methods=177 events=27 presence=4 stateVersion=8
[native-stdio][ws] [2026-06-16T00:31:38.582Z] stdout: 2026-06-16T02:31:38.579+02:00 [ws] ⇄ res ✗ node.invoke 14ms errorCode=INVALID_REQUEST errorMessage=node command not allowed: "canvas.present" is not in the allowlist for platform "android" id=fc47a352…ddf2
[native-stdio][ws] [2026-06-16T00:31:38.608Z] stdout: 2026-06-16T02:31:38.606+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=9 healthVersion=32
[native-stdio][ws] [2026-06-16T00:31:38.625Z] stdout: 2026-06-16T02:31:38.623+02:00 [ws] → close code=1005 durationMs=303 handshake=connected lastFrameType=req lastFrameMethod=node.invoke lastFrameId=fc47a352-dfc2-4113-a9f5-ca880a3fddf2 endpoint=127.0.0.1:35804->127.0.0.1:18789
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:31:38.644Z] stdout: 2026-06-16T02:31:38.635+02:00 tools: canvas failed stack:
[native-stdio][gateway] GatewayClientRequestError: node command not allowed: "canvas.present" is not in the allowlist for platform "android"
[native-stdio][gateway] at GatewayClient$1.handleMessage (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/client-5XIBFtwk.js:928:24)
[native-stdio][gateway] at WebSocket.<anonymous> (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/client-5XIBFtwk.js:474:35)
[native-stdio][gateway] at WebSocket.emit (node:events:519:28)
[native-stdio][gateway] at Receiver.receiverOnMessage (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:1239:20)
[native-stdio][gateway] at Receiver.emit (node:events:519:28)
[native-stdio][gateway] at Receiver.dataMessage (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:650:14)
[native-stdio][gateway] at Receiver.getData (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:534:10)
[native-stdio][gateway] at Receiver.startLoop (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:189:16)
[native-stdio][gateway] at Receiver._write (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:116:10)
[native-stdio][gateway] at writeOrBuffer (node:internal/streams/writable:572:12)
[native-stdio][tools] [2026-06-16T00:31:38.651Z] stderr: 2026-06-16T02:31:38.645+02:00 [tools] canvas failed: node command not allowed: "canvas.present" is not in the allowlist for platform "android" raw_params={"action":"present","url":"/__openclaw__/canvas/solar_system.html","node":"OpenClaw Mobile"}
[native-stdio][tools] [2026-06-16T00:31:38.666Z] stdout: 2026-06-16T02:31:38.664+02:00 [agent/embedded] embedded run tool end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=canvas toolCallId=chatcmpl-tool-8974b271de8e68ab
[native-stdio][ws] [2026-06-16T00:31:38.677Z] stdout: 2026-06-16T02:31:38.675+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=21
[native-stdio][provider] [2026-06-16T00:31:38.749Z] stdout: 2026-06-16T02:31:38.744+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:31:40.945Z] stdout: 2026-06-16T02:31:40.942+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2197 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:31:44.049Z] stdout: 2026-06-16T02:31:44.042+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:31:58.386Z] stdout: 2026-06-16T02:31:58.381+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=22 text=I
[native-stdio][ws] [2026-06-16T00:31:58.405Z] stdout: 2026-06-16T02:31:58.401+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.531Z] stdout: 2026-06-16T02:31:58.528+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=29 text=I’ve added a simple Solar‑System
[native-stdio][ws] [2026-06-16T00:31:58.547Z] stdout: 2026-06-16T02:31:58.544+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=30 text=I’ve added a simple Solar‑System demo
[native-stdio][ws] [2026-06-16T00:31:58.569Z] stdout: 2026-06-16T02:31:58.564+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.686Z] stdout: 2026-06-16T02:31:58.683+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=36 text=I’ve added a simple Solar‑System demo to the workspace at `/
[native-stdio][ws] [2026-06-16T00:31:58.709Z] stdout: 2026-06-16T02:31:58.706+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=37 text=I’ve added a simple Solar‑System demo to the workspace at `/__
[native-stdio][ws] [2026-06-16T00:31:58.726Z] stdout: 2026-06-16T02:31:58.723+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.840Z] stdout: 2026-06-16T02:31:58.838+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=45 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system
[native-stdio][ws] [2026-06-16T00:31:58.865Z] stdout: 2026-06-16T02:31:58.861+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=46 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html
[native-stdio][ws] [2026-06-16T00:31:58.894Z] stdout: 2026-06-16T02:31:58.890+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.994Z] stdout: 2026-06-16T02:31:58.992+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=52 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on
[native-stdio][ws] [2026-06-16T00:31:59.015Z] stdout: 2026-06-16T02:31:59.012+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=53 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your
[native-stdio][ws] [2026-06-16T00:31:59.039Z] stdout: 2026-06-16T02:31:59.036+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:31:59.749Z] stdout: 2026-06-16T02:31:59.735+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:31:59.811Z] stdout: 2026-06-16T02:31:59.806+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=54 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone
[native-stdio][ws] [2026-06-16T00:31:59.843Z] stdout: 2026-06-16T02:31:59.838+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=55 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by
[native-stdio][ws] [2026-06-16T00:31:59.866Z] stdout: 2026-06-16T02:31:59.863+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:59.954Z] stdout: 2026-06-16T02:31:59.951+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=59 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in
[native-stdio][ws] [2026-06-16T00:31:59.975Z] stdout: 2026-06-16T02:31:59.972+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=60 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a
[native-stdio][ws] [2026-06-16T00:32:00.027Z] stdout: 2026-06-16T02:32:00.023+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.131Z] stdout: 2026-06-16T02:32:00.128+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=76 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.146Z] stdout: 2026-06-16T02:32:00.144+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=77 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.176Z] stdout: 2026-06-16T02:32:00.173+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.290Z] stdout: 2026-06-16T02:32:00.287+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=97 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.312Z] stdout: 2026-06-16T02:32:00.309+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=98 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.337Z] stdout: 2026-06-16T02:32:00.333+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.445Z] stdout: 2026-06-16T02:32:00.442+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=109 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.463Z] stdout: 2026-06-16T02:32:00.461+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=110 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.487Z] stdout: 2026-06-16T02:32:00.483+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:32:00.562Z] stdout: 2026-06-16T02:32:00.558+02:00 [agent/embedded] embedded run agent end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 isError=false
[native-stdio][gateway] [2026-06-16T00:32:00.569Z] stdout: 2026-06-16T02:32:00.565+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:32:00.576Z] stdout: 2026-06-16T02:32:00.573+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][ws] [2026-06-16T00:32:00.606Z] stdout: 2026-06-16T02:32:00.600+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=117 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.636Z] stdout: 2026-06-16T02:32:00.632+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=lifecycle aseq=118 phase=end
[native-stdio][ws] [2026-06-16T00:32:00.657Z] stdout: 2026-06-16T02:32:00.652+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.677Z] stdout: 2026-06-16T02:32:00.674+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:32:00.690Z] stdout: 2026-06-16T02:32:00.688+02:00 [agent/embedded] embedded run prompt end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=109989
[native-stdio][gateway] [2026-06-16T00:32:01.067Z] stdout: 2026-06-16T02:32:01.064+02:00 [agent/embedded] embedded run done: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=114056 aborted=false
[native-stdio][gateway] [2026-06-16T00:32:01.135Z] stdout: 2026-06-16T02:32:01.132+02:00 [diagnostic] lane task done: lane=main durationMs=114125 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:32:01.141Z] stdout: 2026-06-16T02:32:01.138+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=114137 active=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:32:01.703Z] stdout: 2026-06-16T02:32:01.700+02:00 [ws] ⇄ res ✓ talk.speak 2630ms conn=00e386a5…26c9 id=a0988e7d…1312
[native-stdio][gateway] [2026-06-16T00:32:01.840Z] stdout: 2026-06-16T02:32:01.837+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=116631ms
[native-stdio][gateway] [2026-06-16T00:32:01.849Z] stdout: 2026-06-16T02:32:01.845+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=unknown sessionKey=agent:main:main outcome=completed duration=116726ms
[native-stdio][gateway] [2026-06-16T00:32:01.863Z] stdout: 2026-06-16T02:32:01.853+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native-stdio][ws] [2026-06-16T00:32:01.907Z] stdout: 2026-06-16T02:32:01.903+02:00 [ws] → event chat seq=per-client clients=2
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:32:07.684Z] stdout: 2026-06-16T02:32:07.675+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:32:07.958Z] stdout: 2026-06-16T02:32:07.955+02:00 [ws] ⇄ res ✓ agents.list 6ms id=a4a98bcb…5760
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:32:10.369Z] stdout: 2026-06-16T02:32:10.366+02:00 [ws] ⇄ res ✓ talk.speak 3040ms id=82c88178…fb32
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:32:14.059Z] stdout: 2026-06-16T02:32:14.046+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:32:15.839Z] stdout: 2026-06-16T02:32:15.825+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:32:18.069Z] stdout: 2026-06-16T02:32:18.065+02:00 [ws] ⇄ res ✓ talk.speak 3182ms id=c125ff01…b43d
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:32:19.254Z] stdout: 2026-06-16T02:32:19.244+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:32:20.835Z] stdout: 2026-06-16T02:32:20.833+02:00 [ws] ⇄ res ✓ talk.speak 1947ms id=0ee104e9…0462
[native-stdio][provider] [2026-06-16T00:32:22.313Z] stdout: 2026-06-16T02:32:22.305+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:32:24.169Z] stdout: 2026-06-16T02:32:24.166+02:00 [ws] ⇄ res ✓ talk.speak 2391ms id=925f4133…7a0f
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:32:25.679Z] stdout: 2026-06-16T02:32:25.671+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:32:27.568Z] stdout: 2026-06-16T02:32:27.566+02:00 [ws] ⇄ res ✓ talk.speak 2269ms id=e7890b26…0e06
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:32:32.716Z] stdout: 2026-06-16T02:32:32.697+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:32:32.769Z] stdout: 2026-06-16T02:32:32.765+02:00 [ws] ⇄ res ✓ agents.list 10ms id=f103f64b…87f0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:32:34.636Z] stdout: 2026-06-16T02:32:34.632+02:00 [ws] ⇄ res ✓ talk.speak 2435ms id=08d30bf2…4e64
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[native-stdio][ws] [2026-06-16T00:31:38.625Z] stdout: 2026-06-16T02:31:38.623+02:00 [ws] → close code=1005 durationMs=303 handshake=connected lastFrameType=req lastFrameMethod=node.invoke lastFrameId=fc47a352-dfc2-4113-a9f5-ca880a3fddf2 endpoint=127.0.0.1:35804->127.0.0.1:18789
[native-stdio][tools] [2026-06-16T00:31:38.644Z] stdout: 2026-06-16T02:31:38.635+02:00 tools: canvas failed stack:
[native-stdio][gateway] GatewayClientRequestError: node command not allowed: "canvas.present" is not in the allowlist for platform "android"
[native-stdio][gateway] at GatewayClient$1.handleMessage (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/client-5XIBFtwk.js:928:24)
[native-stdio][gateway] at WebSocket.<anonymous> (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/client-5XIBFtwk.js:474:35)
[native-stdio][gateway] at WebSocket.emit (node:events:519:28)
[native-stdio][gateway] at Receiver.receiverOnMessage (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:1239:20)
[native-stdio][gateway] at Receiver.emit (node:events:519:28)
[native-stdio][gateway] at Receiver.dataMessage (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:650:14)
[native-stdio][gateway] at Receiver.getData (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:534:10)
[native-stdio][gateway] at Receiver.startLoop (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:189:16)
[native-stdio][gateway] at Receiver._write (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:116:10)
[native-stdio][gateway] at writeOrBuffer (node:internal/streams/writable:572:12)
[native-stdio][tools] [2026-06-16T00:31:38.651Z] stderr: 2026-06-16T02:31:38.645+02:00 [tools] canvas failed: node command not allowed: "canvas.present" is not in the allowlist for platform "android" raw_params={"action":"present","url":"/__openclaw__/canvas/solar_system.html","node":"OpenClaw Mobile"}
[native-stdio][tools] [2026-06-16T00:31:38.666Z] stdout: 2026-06-16T02:31:38.664+02:00 [agent/embedded] embedded run tool end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=canvas toolCallId=chatcmpl-tool-8974b271de8e68ab
[native-stdio][ws] [2026-06-16T00:31:38.677Z] stdout: 2026-06-16T02:31:38.675+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=21
[native-stdio][provider] [2026-06-16T00:31:38.749Z] stdout: 2026-06-16T02:31:38.744+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native-stdio][provider] [2026-06-16T00:31:40.945Z] stdout: 2026-06-16T02:31:40.942+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2197 contentType=text/event-stream
[native-stdio][gateway] [2026-06-16T00:31:44.049Z] stdout: 2026-06-16T02:31:44.042+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:31:58.386Z] stdout: 2026-06-16T02:31:58.381+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=22 text=I
[native-stdio][ws] [2026-06-16T00:31:58.405Z] stdout: 2026-06-16T02:31:58.401+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.531Z] stdout: 2026-06-16T02:31:58.528+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=29 text=I’ve added a simple Solar‑System
[native-stdio][ws] [2026-06-16T00:31:58.547Z] stdout: 2026-06-16T02:31:58.544+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=30 text=I’ve added a simple Solar‑System demo
[native-stdio][ws] [2026-06-16T00:31:58.569Z] stdout: 2026-06-16T02:31:58.564+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.686Z] stdout: 2026-06-16T02:31:58.683+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=36 text=I’ve added a simple Solar‑System demo to the workspace at `/
[native-stdio][ws] [2026-06-16T00:31:58.709Z] stdout: 2026-06-16T02:31:58.706+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=37 text=I’ve added a simple Solar‑System demo to the workspace at `/__
[native-stdio][ws] [2026-06-16T00:31:58.726Z] stdout: 2026-06-16T02:31:58.723+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.840Z] stdout: 2026-06-16T02:31:58.838+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=45 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system
[native-stdio][ws] [2026-06-16T00:31:58.865Z] stdout: 2026-06-16T02:31:58.861+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=46 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html
[native-stdio][ws] [2026-06-16T00:31:58.894Z] stdout: 2026-06-16T02:31:58.890+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:58.994Z] stdout: 2026-06-16T02:31:58.992+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=52 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on
[native-stdio][ws] [2026-06-16T00:31:59.015Z] stdout: 2026-06-16T02:31:59.012+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=53 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your
[native-stdio][ws] [2026-06-16T00:31:59.039Z] stdout: 2026-06-16T02:31:59.036+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][provider] [2026-06-16T00:31:59.749Z] stdout: 2026-06-16T02:31:59.735+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:31:59.811Z] stdout: 2026-06-16T02:31:59.806+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=54 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone
[native-stdio][ws] [2026-06-16T00:31:59.843Z] stdout: 2026-06-16T02:31:59.838+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=55 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by
[native-stdio][ws] [2026-06-16T00:31:59.866Z] stdout: 2026-06-16T02:31:59.863+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:31:59.954Z] stdout: 2026-06-16T02:31:59.951+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=59 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in
[native-stdio][ws] [2026-06-16T00:31:59.975Z] stdout: 2026-06-16T02:31:59.972+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=60 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a
[native-stdio][ws] [2026-06-16T00:32:00.027Z] stdout: 2026-06-16T02:32:00.023+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.131Z] stdout: 2026-06-16T02:32:00.128+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=76 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.146Z] stdout: 2026-06-16T02:32:00.144+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=77 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.176Z] stdout: 2026-06-16T02:32:00.173+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.290Z] stdout: 2026-06-16T02:32:00.287+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=97 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.312Z] stdout: 2026-06-16T02:32:00.309+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=98 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.337Z] stdout: 2026-06-16T02:32:00.333+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.445Z] stdout: 2026-06-16T02:32:00.442+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=109 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.463Z] stdout: 2026-06-16T02:32:00.461+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=110 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.487Z] stdout: 2026-06-16T02:32:00.483+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:32:00.562Z] stdout: 2026-06-16T02:32:00.558+02:00 [agent/embedded] embedded run agent end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 isError=false
[native-stdio][gateway] [2026-06-16T00:32:00.569Z] stdout: 2026-06-16T02:32:00.565+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:32:00.576Z] stdout: 2026-06-16T02:32:00.573+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][ws] [2026-06-16T00:32:00.606Z] stdout: 2026-06-16T02:32:00.600+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=assistant aseq=117 text=I’ve added a simple Solar‑System demo to the workspace at `/__openclaw__/canvas/solar_system.html`. You can view it on your phone by opening the URL in a brows…
[native-stdio][ws] [2026-06-16T00:32:00.636Z] stdout: 2026-06-16T02:32:00.632+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=lifecycle aseq=118 phase=end
[native-stdio][ws] [2026-06-16T00:32:00.657Z] stdout: 2026-06-16T02:32:00.652+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:32:00.677Z] stdout: 2026-06-16T02:32:00.674+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:32:00.690Z] stdout: 2026-06-16T02:32:00.688+02:00 [agent/embedded] embedded run prompt end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=109989
[native-stdio][gateway] [2026-06-16T00:32:01.067Z] stdout: 2026-06-16T02:32:01.064+02:00 [agent/embedded] embedded run done: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=114056 aborted=false
[native-stdio][gateway] [2026-06-16T00:32:01.135Z] stdout: 2026-06-16T02:32:01.132+02:00 [diagnostic] lane task done: lane=main durationMs=114125 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:32:01.141Z] stdout: 2026-06-16T02:32:01.138+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=114137 active=0 queued=0
[native-stdio][tts] [2026-06-16T00:32:01.703Z] stdout: 2026-06-16T02:32:01.700+02:00 [ws] ⇄ res ✓ talk.speak 2630ms conn=00e386a5…26c9 id=a0988e7d…1312
[native-stdio][gateway] [2026-06-16T00:32:01.840Z] stdout: 2026-06-16T02:32:01.837+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=116631ms
[native-stdio][gateway] [2026-06-16T00:32:01.849Z] stdout: 2026-06-16T02:32:01.845+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=unknown sessionKey=agent:main:main outcome=completed duration=116726ms
[native-stdio][gateway] [2026-06-16T00:32:01.863Z] stdout: 2026-06-16T02:32:01.853+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native-stdio][ws] [2026-06-16T00:32:01.907Z] stdout: 2026-06-16T02:32:01.903+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][provider] [2026-06-16T00:32:07.684Z] stdout: 2026-06-16T02:32:07.675+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:32:07.958Z] stdout: 2026-06-16T02:32:07.955+02:00 [ws] ⇄ res ✓ agents.list 6ms id=a4a98bcb…5760
[native-stdio][tts] [2026-06-16T00:32:10.369Z] stdout: 2026-06-16T02:32:10.366+02:00 [ws] ⇄ res ✓ talk.speak 3040ms id=82c88178…fb32
[native-stdio][gateway] [2026-06-16T00:32:14.059Z] stdout: 2026-06-16T02:32:14.046+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:32:15.839Z] stdout: 2026-06-16T02:32:15.825+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:32:18.069Z] stdout: 2026-06-16T02:32:18.065+02:00 [ws] ⇄ res ✓ talk.speak 3182ms id=c125ff01…b43d
[native-stdio][provider] [2026-06-16T00:32:19.254Z] stdout: 2026-06-16T02:32:19.244+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:32:20.835Z] stdout: 2026-06-16T02:32:20.833+02:00 [ws] ⇄ res ✓ talk.speak 1947ms id=0ee104e9…0462
[native-stdio][provider] [2026-06-16T00:32:22.313Z] stdout: 2026-06-16T02:32:22.305+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:32:24.169Z] stdout: 2026-06-16T02:32:24.166+02:00 [ws] ⇄ res ✓ talk.speak 2391ms id=925f4133…7a0f
[native-stdio][provider] [2026-06-16T00:32:25.679Z] stdout: 2026-06-16T02:32:25.671+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:32:27.568Z] stdout: 2026-06-16T02:32:27.566+02:00 [ws] ⇄ res ✓ talk.speak 2269ms id=e7890b26…0e06
[native-stdio][provider] [2026-06-16T00:32:32.716Z] stdout: 2026-06-16T02:32:32.697+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:32:32.769Z] stdout: 2026-06-16T02:32:32.765+02:00 [ws] ⇄ res ✓ agents.list 10ms id=f103f64b…87f0
[native-stdio][tts] [2026-06-16T00:32:34.636Z] stdout: 2026-06-16T02:32:34.632+02:00 [ws] ⇄ res ✓ talk.speak 2435ms id=08d30bf2…4e64
[native] log stream resumed after rotation or runtime restart
[native-stdio][chat] [2026-06-16T00:32:40.979Z] stdout: 2026-06-16T02:32:40.976+02:00 [ws] ⇄ res ✓ chat.send 47ms runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 id=27c7508a…eb64
[native-stdio][gateway] [2026-06-16T00:32:41.000Z] stdout: 2026-06-16T02:32:40.996+02:00 [diagnostic] message received: channel=webchat chatId=unknown messageId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=unknown sessionKey=agent:main:main source=dispatchInboundMessage
[native-stdio][gateway] [2026-06-16T00:32:41.027Z] stdout: 2026-06-16T02:32:41.025+02:00 [diagnostic] message queued: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main source=dispatch queueDepth=1 sessionState=idle
[native-stdio][gateway] [2026-06-16T00:32:41.032Z] stdout: 2026-06-16T02:32:41.029+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=processing reason="message_start" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:32:41.053Z] stdout: 2026-06-16T02:32:41.051+02:00 [diagnostic] message dispatch started: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver
[native-stdio][plugins] [2026-06-16T00:32:41.592Z] stdout: 2026-06-16T02:32:41.590+02:00 [plugins] [hooks] running before_agent_reply (1 handlers, first-claim wins)
[native-stdio][gateway] [2026-06-16T00:32:41.685Z] stdout: 2026-06-16T02:32:41.676+02:00 preflightCompaction check: sessionKey=agent:main:main tokenCount=44830 contextWindow=131072 threshold=107072 serverCompactionThreshold=undefined isHeartbeat=false isCli=false persistedFresh=true transcriptPromptTokens=undefined promptTokensEst=4430 activeTranscriptBytes=undefined maxActiveTranscriptBytes=undefined sizeTrigger=false
[native-stdio][gateway] [2026-06-16T00:32:41.709Z] stdout: 2026-06-16T02:32:41.697+02:00 memoryFlush check: sessionKey=agent:main:main tokenCount=49260 contextWindow=131072 threshold=107072 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=44830 persistedFresh=true promptTokensEst=4430 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=49260 transcriptBytes=163664 forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[native-stdio][gateway] [2026-06-16T00:32:41.715Z] stdout: 2026-06-16T02:32:41.713+02:00 [diagnostic] session turn created: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main agentId=main channel=webchat trigger=user
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:32:43.237Z] stdout: 2026-06-16T02:32:43.233+02:00 [diagnostic] lane enqueue: lane=session:agent:main:main queueSize=1
[native-stdio][gateway] [2026-06-16T00:32:43.242Z] stdout: 2026-06-16T02:32:43.239+02:00 [diagnostic] lane dequeue: lane=session:agent:main:main waitMs=7 queueSize=0
[native-stdio][gateway] [2026-06-16T00:32:43.248Z] stdout: 2026-06-16T02:32:43.245+02:00 [diagnostic] lane enqueue: lane=main queueSize=1
[native-stdio][gateway] [2026-06-16T00:32:43.253Z] stdout: 2026-06-16T02:32:43.250+02:00 [diagnostic] lane dequeue: lane=main waitMs=5 queueSize=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:32:45.718Z] stdout: 2026-06-16T02:32:45.714+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=32s eventLoopDelayP99Ms=44.2 eventLoopDelayMaxMs=4011.9 eventLoopUtilization=0.276 cpuCoreRatio=0.274 active=1 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms work=[active=agent:main:main(processing/embedded_run,q=1,age=5s last=embedded_run:started)]
[native-stdio][gateway] [2026-06-16T00:32:45.726Z] stdout: 2026-06-16T02:32:45.723+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:32:45.750Z] stdout: 2026-06-16T02:32:45.747+02:00 [agents/harness] agent harness selected
[native-stdio][provider] [2026-06-16T00:32:45.769Z] stdout: 2026-06-16T02:32:45.767+02:00 [agent/embedded] embedded run start: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter model=openai/gpt-oss-20b:free thinking=off messageChannel=webchat
[native-stdio][gateway] [2026-06-16T00:32:46.662Z] stdout: 2026-06-16T02:32:46.660+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=processing reason="run_started" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:32:46.666Z] stdout: 2026-06-16T02:32:46.664+02:00 [diagnostic] run registered: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=1
[native-stdio][provider] [2026-06-16T00:32:46.686Z] stdout: 2026-06-16T02:32:46.682+02:00 [agent/embedded] embedded run prompt start: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:32:46.863Z] stdout: 2026-06-16T02:32:46.859+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=23 roleCounts=assistant:12,toolResult:6,user:5 historyTextChars=110223 maxMessageTextChars=25309 historyImageBlocks=0 systemPromptChars=34736 promptChars=17719 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:32:46.873Z] stdout: 2026-06-16T02:32:46.871+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=62685 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=23 unwindowedMessages=23 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:32:46.958Z] stdout: 2026-06-16T02:32:46.955+02:00 [agent/embedded] embedded run agent start: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1
[native-stdio][ws] [2026-06-16T00:32:46.982Z] stdout: 2026-06-16T02:32:46.979+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=lifecycle aseq=1 phase=start
[native-stdio][provider] [2026-06-16T00:32:47.126Z] stdout: 2026-06-16T02:32:47.123+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:32:50.666Z] stdout: 2026-06-16T02:32:50.661+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=3538 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:33:08.325Z] stdout: 2026-06-16T02:33:08.322+02:00 [agent/embedded] embedded run tool start: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 tool=dir_list toolCallId=chatcmpl-tool-868889ea4c01d031
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:33:08.346Z] stdout: 2026-06-16T02:33:08.344+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=item aseq=3
[native-stdio][ws] [2026-06-16T00:33:08.655Z] stdout: 2026-06-16T02:33:08.652+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=55446 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55446->127.0.0.1:18789 conn=436265cb…ef0e
[native-stdio][ws] [2026-06-16T00:33:08.693Z] stdout: 2026-06-16T02:33:08.691+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:33:08.708Z] stdout: 2026-06-16T02:33:08.706+02:00 [ws] → hello-ok methods=177 events=27 presence=5 stateVersion=10
[native-stdio][ws] [2026-06-16T00:33:09.138Z] stdout: 2026-06-16T02:33:09.136+02:00 [ws] ⇄ res ✓ node.list 12ms id=580042ab…ddb3
[native-stdio][ws] [2026-06-16T00:33:09.157Z] stdout: 2026-06-16T02:33:09.156+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=11 healthVersion=35
[native-stdio][ws] [2026-06-16T00:33:09.170Z] stdout: 2026-06-16T02:33:09.168+02:00 [ws] → close code=1005 durationMs=505 handshake=connected lastFrameType=req lastFrameMethod=node.list lastFrameId=580042ab-9fab-45ab-9a03-e8b91adbddb3 endpoint=127.0.0.1:55446->127.0.0.1:18789
[native-stdio][ws] [2026-06-16T00:33:09.207Z] stdout: 2026-06-16T02:33:09.205+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=55460 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55460->127.0.0.1:18789 conn=a34f3887…5305
[native-stdio][ws] [2026-06-16T00:33:09.232Z] stdout: 2026-06-16T02:33:09.231+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:33:09.245Z] stdout: 2026-06-16T02:33:09.243+02:00 [ws] → hello-ok methods=177 events=27 presence=6 stateVersion=12
[native-stdio][ws] [2026-06-16T00:33:09.504Z] stdout: 2026-06-16T02:33:09.501+02:00 [ws] ⇄ res ✗ node.invoke 20ms errorCode=INVALID_REQUEST errorMessage=node command not allowed: "dir.list" is not in the allowlist for platform "android" id=936d9b5f…1149
[native-stdio][ws] [2026-06-16T00:33:09.531Z] stdout: 2026-06-16T02:33:09.529+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=13 healthVersion=36
[native-stdio][ws] [2026-06-16T00:33:09.543Z] stdout: 2026-06-16T02:33:09.541+02:00 [ws] → close code=1005 durationMs=324 handshake=connected lastFrameType=req lastFrameMethod=node.invoke lastFrameId=936d9b5f-d4c4-4e5f-8dbf-56379a511149 endpoint=127.0.0.1:55460->127.0.0.1:18789
[native-stdio][tools] [2026-06-16T00:33:09.560Z] stdout: 2026-06-16T02:33:09.551+02:00 tools: dir_list failed stack:
[native-stdio][gateway] GatewayClientRequestError: node command not allowed: "dir.list" is not in the allowlist for platform "android"
[native-stdio][tools] [2026-06-16T00:33:09.568Z] stderr: 2026-06-16T02:33:09.561+02:00 [tools] dir_list failed: node command not allowed: "dir.list" is not in the allowlist for platform "android" raw_params={"node":"OpenClaw Mobile","path":"/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw","maxEntries":10}
[native-stdio][tools] [2026-06-16T00:33:09.887Z] stdout: 2026-06-16T02:33:09.885+02:00 [agent/embedded] embedded run tool end: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 tool=dir_list toolCallId=chatcmpl-tool-868889ea4c01d031
[native-stdio][ws] [2026-06-16T00:33:09.899Z] stdout: 2026-06-16T02:33:09.897+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=item aseq=5
[native-stdio][provider] [2026-06-16T00:33:09.968Z] stdout: 2026-06-16T02:33:09.966+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:33:12.387Z] stdout: 2026-06-16T02:33:12.382+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2416 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:33:15.718Z] stdout: 2026-06-16T02:33:15.714+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:33:35.960Z] stdout: 2026-06-16T02:33:35.957+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=6 text=Here
[native-stdio][ws] [2026-06-16T00:33:35.975Z] stdout: 2026-06-16T02:33:35.972+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:36.138Z] stdout: 2026-06-16T02:33:36.135+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=13 text=Here’s the solar‑system animation.
[native-stdio][ws] [2026-06-16T00:33:36.157Z] stdout: 2026-06-16T02:33:36.154+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=14 text=Here’s the solar‑system animation. Click
[native-stdio][ws] [2026-06-16T00:33:36.172Z] stdout: 2026-06-16T02:33:36.169+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][provider] [2026-06-16T00:33:36.825Z] stdout: 2026-06-16T02:33:36.817+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:33:36.850Z] stdout: 2026-06-16T02:33:36.849+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=15 text=Here’s the solar‑system animation. Click or
[native-stdio][ws] [2026-06-16T00:33:36.864Z] stdout: 2026-06-16T02:33:36.861+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=16 text=Here’s the solar‑system animation. Click or tap
[native-stdio][ws] [2026-06-16T00:33:36.875Z] stdout: 2026-06-16T02:33:36.874+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:37.004Z] stdout: 2026-06-16T02:33:37.002+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=44 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__open
[native-stdio][ws] [2026-06-16T00:33:37.020Z] stdout: 2026-06-16T02:33:37.018+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=45 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__opencl
[native-stdio][ws] [2026-06-16T00:33:37.037Z] stdout: 2026-06-16T02:33:37.034+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:37.160Z] stdout: 2026-06-16T02:33:37.156+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=57 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__openclaw__/canvas/sola…
[native-stdio][ws] [2026-06-16T00:33:37.176Z] stdout: 2026-06-16T02:33:37.174+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=58 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__openclaw__/canvas/sola…
[native-stdio][ws] [2026-06-16T00:33:37.197Z] stdout: 2026-06-16T02:33:37.194+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:33:37.259Z] stdout: 2026-06-16T02:33:37.257+02:00 [agent/embedded] embedded run agent end: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 isError=false
[native-stdio][gateway] [2026-06-16T00:33:37.264Z] stdout: 2026-06-16T02:33:37.262+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:33:37.268Z] stdout: 2026-06-16T02:33:37.266+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][ws] [2026-06-16T00:33:37.281Z] stdout: 2026-06-16T02:33:37.279+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=65 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__openclaw__/canvas/sola…
[native-stdio][ws] [2026-06-16T00:33:37.301Z] stdout: 2026-06-16T02:33:37.298+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=lifecycle aseq=66 phase=end
[native-stdio][ws] [2026-06-16T00:33:37.315Z] stdout: 2026-06-16T02:33:37.313+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:37.329Z] stdout: 2026-06-16T02:33:37.326+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:33:37.352Z] stdout: 2026-06-16T02:33:37.350+02:00 [agent/embedded] embedded run prompt end: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=50682
[native-stdio][provider] [2026-06-16T00:33:37.410Z] stderr: 2026-06-16T02:33:37.406+02:00 [agent/embedded] [prompt-cache] cache read dropped 220512 -> 49056 for openrouter/openai/gpt-oss-20b:free via boundary-aware:openai-completions; no tracked cache input change
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:33:37.694Z] stdout: 2026-06-16T02:33:37.692+02:00 [agent/embedded] embedded run done: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=54437 aborted=false
[native-stdio][gateway] [2026-06-16T00:33:37.727Z] stdout: 2026-06-16T02:33:37.726+02:00 [diagnostic] lane task done: lane=main durationMs=54471 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:33:37.729Z] stdout: 2026-06-16T02:33:37.728+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=54484 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:33:38.170Z] stdout: 2026-06-16T02:33:38.168+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=57117ms
[native-stdio][gateway] [2026-06-16T00:33:38.173Z] stdout: 2026-06-16T02:33:38.172+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=unknown sessionKey=agent:main:main outcome=completed duration=57167ms
[native-stdio][gateway] [2026-06-16T00:33:38.177Z] stdout: 2026-06-16T02:33:38.175+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native-stdio][tts] [2026-06-16T00:33:38.809Z] stdout: 2026-06-16T02:33:38.805+02:00 [ws] ⇄ res ✓ talk.speak 2598ms conn=00e386a5…26c9 id=f8a282ce…b127
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:33:42.615Z] stdout: 2026-06-16T02:33:42.607+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:33:43.683Z] stdout: 2026-06-16T02:33:43.680+02:00 [ws] ⇄ res ✓ talk.speak 1413ms id=bade3d3e…cccd
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:33:45.723Z] stdout: 2026-06-16T02:33:45.719+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:33:48.457Z] stdout: 2026-06-16T02:33:48.448+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:33:49.710Z] stdout: 2026-06-16T02:33:49.708+02:00 [ws] ⇄ res ✓ agents.list 11ms id=79e2cda7…3872
[native-stdio][tts] [2026-06-16T00:33:50.137Z] stdout: 2026-06-16T02:33:50.135+02:00 [ws] ⇄ res ✓ talk.speak 2024ms id=a067eac1…0070
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:34:15.730Z] stdout: 2026-06-16T02:34:15.723+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:34:45.715Z] stdout: 2026-06-16T02:34:45.712+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:35:15.714Z] stdout: 2026-06-16T02:35:15.712+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:35:30.741Z] stdout: 2026-06-16T02:35:30.732+02:00 [ws] ⇄ res ✓ agents.list 9ms id=5659d213…b62b
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[native-stdio][provider] [2026-06-16T00:32:46.686Z] stdout: 2026-06-16T02:32:46.682+02:00 [agent/embedded] embedded run prompt start: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:32:46.863Z] stdout: 2026-06-16T02:32:46.859+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=23 roleCounts=assistant:12,toolResult:6,user:5 historyTextChars=110223 maxMessageTextChars=25309 historyImageBlocks=0 systemPromptChars=34736 promptChars=17719 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:32:46.873Z] stdout: 2026-06-16T02:32:46.871+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=62685 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=23 unwindowedMessages=23 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:32:46.958Z] stdout: 2026-06-16T02:32:46.955+02:00 [agent/embedded] embedded run agent start: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1
[native-stdio][ws] [2026-06-16T00:32:46.982Z] stdout: 2026-06-16T02:32:46.979+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=lifecycle aseq=1 phase=start
[native-stdio][provider] [2026-06-16T00:32:47.126Z] stdout: 2026-06-16T02:32:47.123+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native-stdio][provider] [2026-06-16T00:32:50.666Z] stdout: 2026-06-16T02:32:50.661+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=3538 contentType=text/event-stream
[native-stdio][tools] [2026-06-16T00:33:08.325Z] stdout: 2026-06-16T02:33:08.322+02:00 [agent/embedded] embedded run tool start: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 tool=dir_list toolCallId=chatcmpl-tool-868889ea4c01d031
[native-stdio][ws] [2026-06-16T00:33:08.346Z] stdout: 2026-06-16T02:33:08.344+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=item aseq=3
[native-stdio][ws] [2026-06-16T00:33:08.655Z] stdout: 2026-06-16T02:33:08.652+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=55446 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55446->127.0.0.1:18789 conn=436265cb…ef0e
[native-stdio][ws] [2026-06-16T00:33:08.693Z] stdout: 2026-06-16T02:33:08.691+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:33:08.708Z] stdout: 2026-06-16T02:33:08.706+02:00 [ws] → hello-ok methods=177 events=27 presence=5 stateVersion=10
[native-stdio][ws] [2026-06-16T00:33:09.138Z] stdout: 2026-06-16T02:33:09.136+02:00 [ws] ⇄ res ✓ node.list 12ms id=580042ab…ddb3
[native-stdio][ws] [2026-06-16T00:33:09.157Z] stdout: 2026-06-16T02:33:09.156+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=11 healthVersion=35
[native-stdio][ws] [2026-06-16T00:33:09.170Z] stdout: 2026-06-16T02:33:09.168+02:00 [ws] → close code=1005 durationMs=505 handshake=connected lastFrameType=req lastFrameMethod=node.list lastFrameId=580042ab-9fab-45ab-9a03-e8b91adbddb3 endpoint=127.0.0.1:55446->127.0.0.1:18789
[native-stdio][ws] [2026-06-16T00:33:09.207Z] stdout: 2026-06-16T02:33:09.205+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=55460 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55460->127.0.0.1:18789 conn=a34f3887…5305
[native-stdio][ws] [2026-06-16T00:33:09.232Z] stdout: 2026-06-16T02:33:09.231+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:33:09.245Z] stdout: 2026-06-16T02:33:09.243+02:00 [ws] → hello-ok methods=177 events=27 presence=6 stateVersion=12
[native-stdio][ws] [2026-06-16T00:33:09.504Z] stdout: 2026-06-16T02:33:09.501+02:00 [ws] ⇄ res ✗ node.invoke 20ms errorCode=INVALID_REQUEST errorMessage=node command not allowed: "dir.list" is not in the allowlist for platform "android" id=936d9b5f…1149
[native-stdio][ws] [2026-06-16T00:33:09.531Z] stdout: 2026-06-16T02:33:09.529+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=13 healthVersion=36
[native-stdio][ws] [2026-06-16T00:33:09.543Z] stdout: 2026-06-16T02:33:09.541+02:00 [ws] → close code=1005 durationMs=324 handshake=connected lastFrameType=req lastFrameMethod=node.invoke lastFrameId=936d9b5f-d4c4-4e5f-8dbf-56379a511149 endpoint=127.0.0.1:55460->127.0.0.1:18789
[native-stdio][tools] [2026-06-16T00:33:09.560Z] stdout: 2026-06-16T02:33:09.551+02:00 tools: dir_list failed stack:
[native-stdio][gateway] GatewayClientRequestError: node command not allowed: "dir.list" is not in the allowlist for platform "android"
[native-stdio][gateway] at GatewayClient$1.handleMessage (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/client-5XIBFtwk.js:928:24)
[native-stdio][gateway] at WebSocket.<anonymous> (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/client-5XIBFtwk.js:474:35)
[native-stdio][gateway] at WebSocket.emit (node:events:519:28)
[native-stdio][gateway] at Receiver.receiverOnMessage (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/websocket.js:1239:20)
[native-stdio][gateway] at Receiver.emit (node:events:519:28)
[native-stdio][gateway] at Receiver.dataMessage (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:650:14)
[native-stdio][gateway] at Receiver.getData (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:534:10)
[native-stdio][gateway] at Receiver.startLoop (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:189:16)
[native-stdio][gateway] at Receiver._write (/data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/node_modules/ws/lib/receiver.js:116:10)
[native-stdio][gateway] at writeOrBuffer (node:internal/streams/writable:572:12)
[native-stdio][tools] [2026-06-16T00:33:09.568Z] stderr: 2026-06-16T02:33:09.561+02:00 [tools] dir_list failed: node command not allowed: "dir.list" is not in the allowlist for platform "android" raw_params={"node":"OpenClaw Mobile","path":"/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw","maxEntries":10}
[native-stdio][tools] [2026-06-16T00:33:09.887Z] stdout: 2026-06-16T02:33:09.885+02:00 [agent/embedded] embedded run tool end: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 tool=dir_list toolCallId=chatcmpl-tool-868889ea4c01d031
[native-stdio][ws] [2026-06-16T00:33:09.899Z] stdout: 2026-06-16T02:33:09.897+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=item aseq=5
[native-stdio][provider] [2026-06-16T00:33:09.968Z] stdout: 2026-06-16T02:33:09.966+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native-stdio][provider] [2026-06-16T00:33:12.387Z] stdout: 2026-06-16T02:33:12.382+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2416 contentType=text/event-stream
[native-stdio][gateway] [2026-06-16T00:33:15.718Z] stdout: 2026-06-16T02:33:15.714+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:33:35.960Z] stdout: 2026-06-16T02:33:35.957+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=6 text=Here
[native-stdio][ws] [2026-06-16T00:33:35.975Z] stdout: 2026-06-16T02:33:35.972+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:36.138Z] stdout: 2026-06-16T02:33:36.135+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=13 text=Here’s the solar‑system animation.
[native-stdio][ws] [2026-06-16T00:33:36.157Z] stdout: 2026-06-16T02:33:36.154+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=14 text=Here’s the solar‑system animation. Click
[native-stdio][ws] [2026-06-16T00:33:36.172Z] stdout: 2026-06-16T02:33:36.169+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][provider] [2026-06-16T00:33:36.825Z] stdout: 2026-06-16T02:33:36.817+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:33:36.850Z] stdout: 2026-06-16T02:33:36.849+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=15 text=Here’s the solar‑system animation. Click or
[native-stdio][ws] [2026-06-16T00:33:36.864Z] stdout: 2026-06-16T02:33:36.861+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=16 text=Here’s the solar‑system animation. Click or tap
[native-stdio][ws] [2026-06-16T00:33:36.875Z] stdout: 2026-06-16T02:33:36.874+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:37.004Z] stdout: 2026-06-16T02:33:37.002+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=44 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__open
[native-stdio][ws] [2026-06-16T00:33:37.020Z] stdout: 2026-06-16T02:33:37.018+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=45 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__opencl
[native-stdio][ws] [2026-06-16T00:33:37.037Z] stdout: 2026-06-16T02:33:37.034+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:37.160Z] stdout: 2026-06-16T02:33:37.156+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=57 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__openclaw__/canvas/sola…
[native-stdio][ws] [2026-06-16T00:33:37.176Z] stdout: 2026-06-16T02:33:37.174+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=58 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__openclaw__/canvas/sola…
[native-stdio][ws] [2026-06-16T00:33:37.197Z] stdout: 2026-06-16T02:33:37.194+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:33:37.259Z] stdout: 2026-06-16T02:33:37.257+02:00 [agent/embedded] embedded run agent end: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 isError=false
[native-stdio][gateway] [2026-06-16T00:33:37.264Z] stdout: 2026-06-16T02:33:37.262+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:33:37.268Z] stdout: 2026-06-16T02:33:37.266+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][ws] [2026-06-16T00:33:37.281Z] stdout: 2026-06-16T02:33:37.279+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=assistant aseq=65 text=Here’s the solar‑system animation. Click or tap the link below to view it directly in your browser: [embed url="http://127.0.0.1:18789/__openclaw__/canvas/sola…
[native-stdio][ws] [2026-06-16T00:33:37.301Z] stdout: 2026-06-16T02:33:37.298+02:00 [ws] → event agent seq=per-client clients=2 run=79efc4eb…f7c1 agent=main session=main stream=lifecycle aseq=66 phase=end
[native-stdio][ws] [2026-06-16T00:33:37.315Z] stdout: 2026-06-16T02:33:37.313+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:33:37.329Z] stdout: 2026-06-16T02:33:37.326+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:33:37.352Z] stdout: 2026-06-16T02:33:37.350+02:00 [agent/embedded] embedded run prompt end: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=50682
[native-stdio][provider] [2026-06-16T00:33:37.410Z] stderr: 2026-06-16T02:33:37.406+02:00 [agent/embedded] [prompt-cache] cache read dropped 220512 -> 49056 for openrouter/openai/gpt-oss-20b:free via boundary-aware:openai-completions; no tracked cache input change
[native-stdio][gateway] [2026-06-16T00:33:37.694Z] stdout: 2026-06-16T02:33:37.692+02:00 [agent/embedded] embedded run done: runId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=54437 aborted=false
[native-stdio][gateway] [2026-06-16T00:33:37.727Z] stdout: 2026-06-16T02:33:37.726+02:00 [diagnostic] lane task done: lane=main durationMs=54471 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:33:37.729Z] stdout: 2026-06-16T02:33:37.728+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=54484 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:33:38.170Z] stdout: 2026-06-16T02:33:38.168+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=57117ms
[native-stdio][gateway] [2026-06-16T00:33:38.173Z] stdout: 2026-06-16T02:33:38.172+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=79efc4eb-b535-4a18-a68a-f642daa8f7c1 sessionId=unknown sessionKey=agent:main:main outcome=completed duration=57167ms
[native-stdio][gateway] [2026-06-16T00:33:38.177Z] stdout: 2026-06-16T02:33:38.175+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native-stdio][tts] [2026-06-16T00:33:38.809Z] stdout: 2026-06-16T02:33:38.805+02:00 [ws] ⇄ res ✓ talk.speak 2598ms conn=00e386a5…26c9 id=f8a282ce…b127
[native-stdio][provider] [2026-06-16T00:33:42.615Z] stdout: 2026-06-16T02:33:42.607+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:33:43.683Z] stdout: 2026-06-16T02:33:43.680+02:00 [ws] ⇄ res ✓ talk.speak 1413ms id=bade3d3e…cccd
[native-stdio][gateway] [2026-06-16T00:33:45.723Z] stdout: 2026-06-16T02:33:45.719+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:33:48.457Z] stdout: 2026-06-16T02:33:48.448+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:33:49.710Z] stdout: 2026-06-16T02:33:49.708+02:00 [ws] ⇄ res ✓ agents.list 11ms id=79e2cda7…3872
[native-stdio][tts] [2026-06-16T00:33:50.137Z] stdout: 2026-06-16T02:33:50.135+02:00 [ws] ⇄ res ✓ talk.speak 2024ms id=a067eac1…0070
[native-stdio][gateway] [2026-06-16T00:34:15.730Z] stdout: 2026-06-16T02:34:15.723+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:34:45.715Z] stdout: 2026-06-16T02:34:45.712+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:35:15.714Z] stdout: 2026-06-16T02:35:15.712+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:35:30.741Z] stdout: 2026-06-16T02:35:30.732+02:00 [ws] ⇄ res ✓ agents.list 9ms id=5659d213…b62b
[native] log stream resumed after rotation or runtime restart
[native-stdio][chat] [2026-06-16T00:36:58.384Z] stdout: 2026-06-16T02:36:58.382+02:00 [ws] ⇄ res ✓ chat.send 60ms runId=334881fc-3be9-42ca-82fb-a6b6740225b8 id=c87c69bd…96e4
[native-stdio][gateway] [2026-06-16T00:36:58.416Z] stdout: 2026-06-16T02:36:58.413+02:00 [diagnostic] message received: channel=webchat chatId=unknown messageId=334881fc-3be9-42ca-82fb-a6b6740225b8 sessionId=unknown sessionKey=agent:main:main source=dispatchInboundMessage
[native-stdio][gateway] [2026-06-16T00:36:58.482Z] stdout: 2026-06-16T02:36:58.479+02:00 [diagnostic] message queued: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main source=dispatch queueDepth=1 sessionState=idle
[native-stdio][gateway] [2026-06-16T00:36:58.488Z] stdout: 2026-06-16T02:36:58.485+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=processing reason="message_start" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:36:58.517Z] stdout: 2026-06-16T02:36:58.514+02:00 [diagnostic] message dispatch started: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver
[native-stdio][plugins] [2026-06-16T00:36:58.945Z] stdout: 2026-06-16T02:36:58.943+02:00 [plugins] [hooks] running before_agent_reply (1 handlers, first-claim wins)
[native-stdio][gateway] [2026-06-16T00:36:59.031Z] stdout: 2026-06-16T02:36:59.022+02:00 preflightCompaction check: sessionKey=agent:main:main tokenCount=49107 contextWindow=131072 threshold=107072 serverCompactionThreshold=undefined isHeartbeat=false isCli=false persistedFresh=true transcriptPromptTokens=undefined promptTokensEst=4436 activeTranscriptBytes=undefined maxActiveTranscriptBytes=undefined sizeTrigger=false
[native-stdio][gateway] [2026-06-16T00:36:59.052Z] stdout: 2026-06-16T02:36:59.041+02:00 memoryFlush check: sessionKey=agent:main:main tokenCount=53543 contextWindow=131072 threshold=107072 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=49107 persistedFresh=true promptTokensEst=4436 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=53543 transcriptBytes=193908 forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[native-stdio][gateway] [2026-06-16T00:36:59.056Z] stdout: 2026-06-16T02:36:59.054+02:00 [diagnostic] session turn created: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main agentId=main channel=webchat trigger=user
[native-stdio][gateway] [2026-06-16T00:36:59.743Z] stdout: 2026-06-16T02:36:59.741+02:00 [diagnostic] lane enqueue: lane=session:agent:main:main queueSize=1
[native-stdio][gateway] [2026-06-16T00:36:59.749Z] stdout: 2026-06-16T02:36:59.746+02:00 [diagnostic] lane dequeue: lane=session:agent:main:main waitMs=5 queueSize=0
[native-stdio][gateway] [2026-06-16T00:36:59.755Z] stdout: 2026-06-16T02:36:59.752+02:00 [diagnostic] lane enqueue: lane=main queueSize=1
[native-stdio][gateway] [2026-06-16T00:36:59.759Z] stdout: 2026-06-16T02:36:59.757+02:00 [diagnostic] lane dequeue: lane=main waitMs=5 queueSize=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:37:02.496Z] stdout: 2026-06-16T02:37:02.494+02:00 [agents/harness] agent harness selected
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:37:02.511Z] stdout: 2026-06-16T02:37:02.510+02:00 [agent/embedded] embedded run start: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter model=openai/gpt-oss-20b:free thinking=off messageChannel=webchat
[native-stdio][gateway] [2026-06-16T00:37:03.350Z] stdout: 2026-06-16T02:37:03.347+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=processing reason="run_started" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:37:03.355Z] stdout: 2026-06-16T02:37:03.352+02:00 [diagnostic] run registered: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=1
[native-stdio][provider] [2026-06-16T00:37:03.374Z] stdout: 2026-06-16T02:37:03.372+02:00 [agent/embedded] embedded run prompt start: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:37:03.548Z] stdout: 2026-06-16T02:37:03.545+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=27 roleCounts=assistant:14,toolResult:7,user:6 historyTextChars=128282 maxMessageTextChars=25309 historyImageBlocks=0 systemPromptChars=34736 promptChars=17744 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:37:03.559Z] stdout: 2026-06-16T02:37:03.555+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=71061 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=27 unwindowedMessages=27 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:37:03.645Z] stdout: 2026-06-16T02:37:03.642+02:00 [agent/embedded] embedded run agent start: runId=334881fc-3be9-42ca-82fb-a6b6740225b8
[native-stdio][ws] [2026-06-16T00:37:03.680Z] stdout: 2026-06-16T02:37:03.676+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=lifecycle aseq=1 phase=start
[native-stdio][provider] [2026-06-16T00:37:03.848Z] stdout: 2026-06-16T02:37:03.844+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:37:07.729Z] stdout: 2026-06-16T02:37:07.722+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=3877 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:37:10.725Z] stdout: 2026-06-16T02:37:10.722+02:00 [agent/embedded] embedded run tool start: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 tool=exec toolCallId=chatcmpl-tool-8992f0c215b3587a
[native-stdio][ws] [2026-06-16T00:37:10.754Z] stdout: 2026-06-16T02:37:10.751+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=3
[native-stdio][ws] [2026-06-16T00:37:10.767Z] stdout: 2026-06-16T02:37:10.765+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=4
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:37:11.659Z] stdout: 2026-06-16T02:37:11.656+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=6
[native-stdio][ws] [2026-06-16T00:37:11.672Z] stdout: 2026-06-16T02:37:11.670+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=7
[native-stdio][ws] [2026-06-16T00:37:11.685Z] stdout: 2026-06-16T02:37:11.683+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=command_output aseq=8
[native-stdio][tools] [2026-06-16T00:37:12.326Z] stdout: 2026-06-16T02:37:12.324+02:00 [agent/embedded] embedded run tool end: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 tool=exec toolCallId=chatcmpl-tool-8992f0c215b3587a
[native-stdio][ws] [2026-06-16T00:37:12.340Z] stdout: 2026-06-16T02:37:12.338+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=10
[native-stdio][ws] [2026-06-16T00:37:12.353Z] stdout: 2026-06-16T02:37:12.351+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=11
[native-stdio][ws] [2026-06-16T00:37:12.370Z] stdout: 2026-06-16T02:37:12.368+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=command_output aseq=12
[native-stdio][provider] [2026-06-16T00:37:12.463Z] stdout: 2026-06-16T02:37:12.461+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:37:14.513Z] stdout: 2026-06-16T02:37:14.508+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2046 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:37:15.728Z] stdout: 2026-06-16T02:37:15.726+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=120.1 eventLoopDelayMaxMs=3445.6 eventLoopUtilization=0.326 cpuCoreRatio=0.368 active=1 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms work=[active=agent:main:main(processing/model_call,q=1,age=12s last=model_call:stream_progress)]
[native-stdio][gateway] [2026-06-16T00:37:15.734Z] stdout: 2026-06-16T02:37:15.731+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:37:20.577Z] stdout: 2026-06-16T02:37:20.573+02:00 [agent/embedded] embedded run tool start: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 tool=exec toolCallId=chatcmpl-tool-9f4bb2e4669c7d6f
[native-stdio][ws] [2026-06-16T00:37:20.600Z] stdout: 2026-06-16T02:37:20.597+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=14
[native-stdio][ws] [2026-06-16T00:37:20.616Z] stdout: 2026-06-16T02:37:20.614+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=15
[native-stdio][tools] [2026-06-16T00:37:20.824Z] stdout: 2026-06-16T02:37:20.821+02:00 [agent/embedded] embedded run tool end: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 tool=exec toolCallId=chatcmpl-tool-9f4bb2e4669c7d6f
[native-stdio][ws] [2026-06-16T00:37:20.844Z] stdout: 2026-06-16T02:37:20.843+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=17
[native-stdio][ws] [2026-06-16T00:37:20.858Z] stdout: 2026-06-16T02:37:20.855+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=18
[native-stdio][ws] [2026-06-16T00:37:20.870Z] stdout: 2026-06-16T02:37:20.868+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=command_output aseq=19
[native-stdio][provider] [2026-06-16T00:37:20.957Z] stdout: 2026-06-16T02:37:20.954+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:37:23.566Z] stdout: 2026-06-16T02:37:23.561+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2605 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:37:32.359Z] stdout: 2026-06-16T02:37:32.356+02:00 [agent/embedded] embedded run tool start: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 tool=dir_list toolCallId=chatcmpl-tool-aac11443ebdf0ed5
[native-stdio][ws] [2026-06-16T00:37:32.375Z] stdout: 2026-06-16T02:37:32.373+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=21
[native-stdio][ws] [2026-06-16T00:37:32.430Z] stdout: 2026-06-16T02:37:32.428+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=39364 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:39364->127.0.0.1:18789 conn=c8a36d4e…a4a4
[native-stdio][ws] [2026-06-16T00:37:32.459Z] stdout: 2026-06-16T02:37:32.457+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:37:32.471Z] stdout: 2026-06-16T02:37:32.469+02:00 [ws] → hello-ok methods=177 events=27 presence=4 stateVersion=14
[native-stdio][ws] [2026-06-16T00:37:32.693Z] stdout: 2026-06-16T02:37:32.691+02:00 [ws] ⇄ res ✓ node.list 13ms id=e577f4d5…3a86
[native-stdio][ws] [2026-06-16T00:37:32.716Z] stdout: 2026-06-16T02:37:32.715+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=15 healthVersion=41
[native-stdio][ws] [2026-06-16T00:37:32.730Z] stdout: 2026-06-16T02:37:32.728+02:00 [ws] → close code=1005 durationMs=290 handshake=connected lastFrameType=req lastFrameMethod=node.list lastFrameId=e577f4d5-beb2-45c8-87c5-769e03183a86 endpoint=127.0.0.1:39364->127.0.0.1:18789
[native-stdio][ws] [2026-06-16T00:37:32.761Z] stdout: 2026-06-16T02:37:32.759+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=60652 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60652->127.0.0.1:18789 conn=798f1ecf…ff79
[native-stdio][ws] [2026-06-16T00:37:32.783Z] stdout: 2026-06-16T02:37:32.781+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:37:32.795Z] stdout: 2026-06-16T02:37:32.794+02:00 [ws] → hello-ok methods=177 events=27 presence=5 stateVersion=16
[native-stdio][ws] [2026-06-16T00:37:33.011Z] stdout: 2026-06-16T02:37:33.009+02:00 [ws] ⇄ res ✗ node.invoke 4ms errorCode=INVALID_REQUEST errorMessage=node command not allowed: "dir.list" is not in the allowlist for platform "android" id=67abfcf2…d732
[native-stdio][ws] [2026-06-16T00:37:33.030Z] stdout: 2026-06-16T02:37:33.028+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=17 healthVersion=42
[native-stdio][ws] [2026-06-16T00:37:33.045Z] stdout: 2026-06-16T02:37:33.043+02:00 [ws] → close code=1005 durationMs=269 handshake=connected lastFrameType=req lastFrameMethod=node.invoke lastFrameId=67abfcf2-a698-49f8-98cc-89cc8e0ad732 endpoint=127.0.0.1:60652->127.0.0.1:18789
[native-stdio][tools] [2026-06-16T00:37:33.063Z] stdout: 2026-06-16T02:37:33.051+02:00 tools: dir_list failed stack:
[native-stdio][tools] [2026-06-16T00:37:33.076Z] stderr: 2026-06-16T02:37:33.064+02:00 [tools] dir_list failed: node command not allowed: "dir.list" is not in the allowlist for platform "android" raw_params={"node":"OpenClaw Mobile","path":"/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/skills/gifgrep","maxEntries":10}
[native-stdio][tools] [2026-06-16T00:37:33.099Z] stdout: 2026-06-16T02:37:33.097+02:00 [agent/embedded] embedded run tool end: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 tool=dir_list toolCallId=chatcmpl-tool-aac11443ebdf0ed5
[native-stdio][ws] [2026-06-16T00:37:33.115Z] stdout: 2026-06-16T02:37:33.113+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=item aseq=23
[native-stdio][provider] [2026-06-16T00:37:33.193Z] stdout: 2026-06-16T02:37:33.189+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:37:35.337Z] stdout: 2026-06-16T02:37:35.334+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2144 contentType=text/event-stream
[native-stdio][ws] [2026-06-16T00:37:36.262Z] stdout: 2026-06-16T02:37:36.260+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=assistant aseq=24 text=I’m not able to run the `gifgrep` command directly
[native-stdio][ws] [2026-06-16T00:37:36.281Z] stdout: 2026-06-16T02:37:36.278+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:37:36.421Z] stdout: 2026-06-16T02:37:36.418+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=assistant aseq=68 text=I’m not able to run the `gifgrep` command directly from the Android node – the tool isn’t exposed in the allowed set of node actions. I can still help you find…
[native-stdio][tools] [2026-06-16T00:37:36.436Z] stdout: 2026-06-16T02:37:36.433+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=assistant aseq=69 text=I’m not able to run the `gifgrep` command directly from the Android node – the tool isn’t exposed in the allowed set of node actions. I can still help you find…
[native-stdio][ws] [2026-06-16T00:37:36.453Z] stdout: 2026-06-16T02:37:36.449+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][provider] [2026-06-16T00:37:36.965Z] stdout: 2026-06-16T02:37:36.954+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][gateway] [2026-06-16T00:37:37.015Z] stdout: 2026-06-16T02:37:37.013+02:00 [agent/embedded] embedded run agent end: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 isError=false
[native-stdio][gateway] [2026-06-16T00:37:37.019Z] stdout: 2026-06-16T02:37:37.017+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:37:37.023Z] stdout: 2026-06-16T02:37:37.021+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][tools] [2026-06-16T00:37:37.037Z] stdout: 2026-06-16T02:37:37.035+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=assistant aseq=71 text=I’m not able to run the `gifgrep` command directly from the Android node – the tool isn’t exposed in the allowed set of node actions. I can still help you find…
[native-stdio][ws] [2026-06-16T00:37:37.050Z] stdout: 2026-06-16T02:37:37.049+02:00 [ws] → event agent seq=per-client clients=2 run=334881fc…25b8 agent=main session=main stream=lifecycle aseq=72 phase=end
[native-stdio][ws] [2026-06-16T00:37:37.064Z] stdout: 2026-06-16T02:37:37.061+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:37:37.082Z] stdout: 2026-06-16T02:37:37.078+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:37:37.099Z] stdout: 2026-06-16T02:37:37.096+02:00 [agent/embedded] embedded run prompt end: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=33739
[native-stdio][gateway] [2026-06-16T00:37:37.576Z] stdout: 2026-06-16T02:37:37.573+02:00 [agent/embedded] embedded run done: runId=334881fc-3be9-42ca-82fb-a6b6740225b8 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=37812 aborted=false
[native-stdio][gateway] [2026-06-16T00:37:37.628Z] stdout: 2026-06-16T02:37:37.626+02:00 [diagnostic] lane task done: lane=main durationMs=37865 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:37:37.630Z] stdout: 2026-06-16T02:37:37.629+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=37878 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:37:37.997Z] stdout: 2026-06-16T02:37:37.995+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=39483ms
[native-stdio][gateway] [2026-06-16T00:37:38.002Z] stdout: 2026-06-16T02:37:38.000+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=334881fc-3be9-42ca-82fb-a6b6740225b8 sessionId=unknown sessionKey=agent:main:main outcome=completed duration=39577ms
[native-stdio][gateway] [2026-06-16T00:37:38.009Z] stdout: 2026-06-16T02:37:38.006+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:37:39.321Z] stdout: 2026-06-16T02:37:39.316+02:00 [ws] ⇄ res ✓ talk.speak 2810ms conn=00e386a5…26c9 id=e5ce0621…25ab
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:37:45.735Z] stdout: 2026-06-16T02:37:45.727+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:37:48.390Z] stdout: 2026-06-16T02:37:48.382+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:37:50.005Z] stdout: 2026-06-16T02:37:50.001+02:00 [ws] ⇄ res ✓ talk.speak 2009ms id=617f9b5b…1c9e
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:37:54.600Z] stdout: 2026-06-16T02:37:54.591+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:37:56.263Z] stdout: 2026-06-16T02:37:56.260+02:00 [ws] ⇄ res ✓ talk.speak 2070ms id=aa5c5f38…4692
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:38:15.729Z] stdout: 2026-06-16T02:38:15.725+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:38:45.730Z] stdout: 2026-06-16T02:38:45.726+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0






=====================================================


Node logs:




  🦞 LOBSTER-acb1...53b2
  =====================

[NODE] Node enabled; waiting for gateway readiness
[NODE] Gateway ready; auto-connect check running
[NODE] Auto-connect starting handshake
[NODE] Connect already in progress — skipping duplicate request
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from /data/user/0/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/openclaw.json
[NODE] Using cached node device token: OoCj2BXZ...
[NODE] Declaring 62 commands: [avatar.gesture, avatar.mode, avatar.model, avatar.sequence, avatar.status, avatar_gesture, avatar_mode, avatar_model, avatar_sequence, avatar_status, camera.clip, camera.list, camera.snap, camera_clip, camera_list, camera_snap, canvas.eval, canvas.navigate, canvas.snapshot, canvas_eval, canvas_navigate, canvas_snapshot, clawhub.info, clawhub.search, clawhub_info, clawhub_search, device.health, device.info, device.permissions, device.status, device_health, device_info, device_permissions, device_status, flash.off, flash.on, flash.status, flash.toggle, flash_off, flash_on, flash_status, flash_toggle, gesture.wave, gestures.wave, haptic.vibrate, haptic_vibrate, location.get, location_get, meme-maker.create, meme-maker_create, screen.record, screen_record, sensor.list, sensor.read, sensor_list, sensor_read, vibrate, wave, weather.current, weather.forecast, weather_current, weather_forecast]
[NODE] Connect frame protocol=v4 caps=[avatar, camera, canvas, clawhub, device, flash, gesture, gestures, haptic, location, meme-maker, screen, sensor, wave, weather] commands=[avatar.gesture, avatar.mode, avatar.model, avatar.sequence, avatar.status, avatar_gesture, avatar_mode, avatar_model, avatar_sequence, avatar_status, camera.clip, camera.list, camera.snap, camera_clip, camera_list, camera_snap, canvas.eval, canvas.navigate, canvas.snapshot, canvas_eval, canvas_navigate, canvas_snapshot, clawhub.info, clawhub.search, clawhub_info, clawhub_search, device.health, device.info, device.permissions, device.status, device_health, device_info, device_permissions, device_status, flash.off, flash.on, flash.status, flash.toggle, flash_off, flash_on, flash_status, flash_toggle, gesture.wave, gestures.wave, haptic.vibrate, haptic_vibrate, location.get, location_get, meme-maker.create, meme-maker_create, screen.record, screen_record, sensor.list, sensor.read, sensor_list, sensor_read, vibrate, wave, weather.current, weather.forecast, weather_current, weather_forecast]
[NODE] Connect frame platform=android
[NODE] Connect accepted (protocol=v4, methods=177, presence=3, token=OoCj2B...)
[NODE] Paired and connected

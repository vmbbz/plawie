Cosy <cosychiruka@gmail.com>
	
5:58 AM (3 minutes ago)
	
	
to me

DEVICE NODE LOGS FIRST......

  🦞 LOBSTER-c122...e1bb
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null error={code: NOT_PAIRED, message: pairing required: device is not approved yet, details: {code: PAIRING_REQUIRED, reason: not-paired, requestId: 4882e1b0-ee13-4b98-a796-528811a8ef43, remediationHint: Approve this device from the pending pairing requests., deviceId: c122a8259ab17c0739ef5a6f7d93953d67f200c895c3854d7c859ca4f51ee1bb, requestedRole: node, requestedScopes: []}}
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected (closeCode=1008 reason=pairing required: device is not approved yet (requestId: 4882e1b0-ee13-4b98-a796-528811a8ef43)); reconnect delegated to socket backoff/watchdog
[NODE] Pairing required (1008) — approving 4882e1b0-ee13-4b98-a796-528811a8ef43 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Device approved; received new node token (rreZwCLa...)
[NODE] WebSocket reconnected, completing handshake...
[NODE] Challenge received
[NODE] Using cached node device token: rreZwCLa...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=true payload={type: hello-ok, protocol: 4, server: {version: 2026.5.18, connId: 3fdc98c3-943c-40ee-950e-a9c4df9b3676}, features: {methods: [health, diagnostics.stability, doctor.memory.status, doctor.memory.dreamDiary, doctor.memory.backfillDreamDiary, doctor.memory.resetDreamDiary, doctor.memory.resetGroundedShortTerm, doctor.memory.repairDreamingArtifacts, doctor.memory.dedupeDreamDiary, doctor.memory.remHarness, logs.tail, channels.status, channels.start, channels.stop, channels.logout, status, usage.status, usage.cost, tts.status, tts.providers, tts.personas, tts.enable, tts.disable, tts.convert, tts.setProvider, tts.setPersona, config.get, config.set, config.apply, config.patch, config.schema, config.schema.lookup, exec.approvals.get, exec.approvals.set, exec.approvals.node.get, exec.approvals.node.set, exec.approval.get, exec.approval.list, exec.approval.request, exec.approval.waitDecision, exec.approval.resolve, plugin.approval.list, plugin.approval.request, plugin.approval.waitDecision, plugin.approval.resolve, plugins.uiDescriptors, plugins.sessionAction, wizard.start, wizard.next, wizard.cancel, wizard.status, talk.catalog, talk.config, talk.client.create, talk.client.toolCall, talk.session.create, talk.session.join, talk.session.appendAudio, talk.session.startTurn, talk.session.endTurn, talk.session.cancelTurn, talk.session.cancelOutput, talk.session.submitToolResult, talk.session.close, talk.speak, talk.mode, commands.list, models.list, models.authStatus, models.authLogout, tools.catalog, tools.effective, tools.invoke, tasks.list, tasks.get, tasks.cancel, environments.list, environments.status, agents.list, agents.create, agents.update, agents.delete, agents.files.list, agents.files.get, agents.files.set, artifacts.list, artifacts.get, artifacts.download, skills.status, skills.search, skills.detail, skills.bins, skills.upload.begin, skills.upload.chunk, skills.upload.commit, skills.install, skills.update, update.status, update.run, voicewake.get, voicewake.set, secrets.reload, secrets.resolve, voicewake.routing.get, voicewake.routing.set, sessions.list, sessions.subscribe, sessions.unsubscribe, sessions.messages.subscribe, sessions.messages.unsubscribe, sessions.preview, sessions.describe, sessions.compaction.list, sessions.compaction.get, sessions.compaction.branch, sessions.compaction.restore, sessions.create, sessions.send, sessions.abort, sessions.patch, sessions.pluginPatch, sessions.cleanup, sessions.reset, sessions.delete, sessions.compact, last-heartbeat, set-heartbeats, wake, node.pair.request, node.pair.list, node.pair.approve, node.pair.reject, node.pair.remove, node.pair.verify, device.pair.list, device.pair.approve, device.pair.reject, device.pair.remove, device.token.rotate, device.token.revoke, node.rename, node.list, node.describe, node.pluginSurface.refresh, node.pending.drain, node.pending.enqueue, node.invoke, node.pending.pull, node.pending.ack, node.invoke.result, node.event, cron.get, cron.list, cron.status, cron.add, cron.update, cron.remove, cron.run, cron.runs, gateway.identity.get, gateway.restart.preflight, gateway.restart.request, system-presence, system-event, message.action, send, agent, agent.identity.get, agent.wait, chat.history, chat.abort, chat.send], events: [connect.challenge, agent, chat, session.message, session.operation, session.tool, sessions.changed, presence, tick, talk.mode, talk.event, shutdown, health, heartbeat, cron, node.pair.requested, node.pair.resolved, node.invoke.request, device.pair.requested, device.pair.resolved, voicewake.changed, voicewake.routing.changed, exec.approval.requested, exec.approval.resolved, plugin.approval.requested, plugin.approval.resolved, update.available]}, snapshot: {presence: [{host: localhost, ip: 192.168.1.100, version: 2026.5.18, platform: linux 6.17.0-PRoot-Distro, deviceFamily: Linux, modelIdentifier: arm64, mode: gateway, reason: self, text: Gateway: localhost (192.168.1.100) · app 2026.5.18 · mode gateway · reason self, ts: 1779248800279}, {host: OpenClaw Mobile, version: 2026.5.18, platform: android, deviceFamily: Android, mode: node, deviceId: c122a8259ab17c0739ef5a6f7d93953d67f200c895c3854d7c859ca4f51ee1bb, roles: [node], instanceId: c122a8259ab17c0739ef5a6f7d93953d67f200c895c3854d7c859ca4f51ee1bb, reason: connect, ts: 1779248800275, text: Node: OpenClaw Mobile · mode node}], health: {ok: true, ts: 1779248797548, durationMs: 2898, eventLoop: {degraded: false, reasons: [], intervalMs: 8452, delayP99Ms: 24.7, delayMaxMs: 24.7, utilization: 0.996, cpuCoreRatio: 0.377}, plugins: {loaded: [alibaba, anthropic, arcee, azure-speech, browser, byteplus, canvas, cerebras, chutes, cloudflare-ai-gateway, comfy, copilot-proxy, deepgram, deepinfra, deepseek, device-pair, document-extract, elevenlabs, fal, file-transfer, fireworks, github-copilot, google, groq, huggingface, inworld, kilocode, kimi, litellm, lmstudio, memory-core, microsoft, microsoft-foundry, minimax, mistral, moonshot, nvidia, ollama, openai, opencode, opencode-go, openrouter, phone-control, qianfan, qwen, runway, senseaudio, sglang, stepfun, synthetic, talk-voice, tencent, together, tts-local-cli, venice, vercel-ai-gateway, vllm, volcengine, voyage, vydra, web-readability, xai, xiaomi, zai], errors: []}, modelPricing: {state: ok, sources: []}, channels: {}, channelOrder: [], channelLabels: {}, heartbeatSeconds: 1800, defaultAgentId: main, agents: [{agentId: main, isDefault: true, heartbeat: {enabled: true, every: 30m, everyMs: 1800000, prompt: Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK., target: none, ackMaxChars: 300}, sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1779248406883, age: 387767}]}}], sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1779248406883, age: 387767}]}}, stateVersion: {presence: 11, health: 48}, uptimeMs: 2355629, sessionDefaults: {defaultAgentId: main, mainKey: main, mainSessionKey: agent:main:main, scope: per-sender}}, auth: {role: node, scopes: [], deviceToken: rreZwCLaXOt1kTyBN06iZy1Xd8NODyLLeqGoK7MAg7I, issuedAtMs: 1779248797577}, policy: {maxPayload: 26214400, maxBufferedBytes: 52428800, tickIntervalMs: 30000}} error=null
[NODE] Paired and connected





============================================================

GATEWAY LOGS IN FULL BELOW, SOMETHING IS WRONG IN THERE SERIOUSLTY WRONG DUDE WTRF FIND IT MAN....



[90m2026-05-20T03:08:17.084+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-20T03:08:17.099+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-20T03:08:17.132+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-20T03:08:17.729+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-20T03:08:30.305+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-20T03:08:36.291+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (meta.lastTouchedAt) [39m
[90m2026-05-20T03:08:40.967+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (meta.lastTouchedAt) [39m
[90m2026-05-20T03:08:52.021+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (discovery.wideArea, gateway.nodes.allowCommands, gateway.nodes.denyCommands, gateway.http) [39m
[90m2026-05-20T03:08:52.037+00:00 [39m [34m[reload] [39m [33mconfig change requires gateway restart (discovery.wideArea, gateway.nodes.allowCommands, gateway.nodes.denyCommands, gateway.http) [39m
[90m2026-05-20T03:08:52.049+00:00 [39m [36m[gateway] [39m [36msignal SIGUSR1 received [39m
[90m2026-05-20T03:08:52.060+00:00 [39m [36m[gateway] [39m [36mreceived SIGUSR1; restarting [39m
[90m2026-05-20T03:08:52.062+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_stop (1 handlers) [39m
[90m2026-05-20T03:08:52.072+00:00 [39m [33m[shutdown] [39m [36mstarted: gateway restarting [39m
[90m2026-05-20T03:08:52.083+00:00 [39m [34m[gmail-watcher] [39m [36mgmail watcher stopped [39m
[90m2026-05-20T03:08:52.095+00:00 [39m [33m[shutdown] [39m [36mcompleted cleanly in 21ms [39m
[90m2026-05-20T03:08:52.115+00:00 [39m [36m[gateway] [39m [36mrestart mode: in-process restart (unmanaged: use in-process restart to keep custom supervisor PID tracking stable) [39m
[90m2026-05-20T03:08:54.465+00:00 [39m [36m[gateway] [39m [36mauto-enabled plugins for this runtime without writing config: [39m
[36m- ollama/qwen3-coder:480b-cloud model configured, enabled automatically. [39m
[90m2026-05-20T03:09:02.281+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-20T03:09:02.302+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-20T03:09:05.445+00:00 [39m [36m[gateway] [39m [36magent model: ollama/qwen3-coder:480b-cloud (thinking=medium, fast=off) [39m
[90m2026-05-20T03:09:05.470+00:00 [39m [36m[gateway] [39m [36mhttp server listening (1 plugin: memory-core; 13.3s) [39m
[90m2026-05-20T03:09:05.484+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-20.log [39m
[90m2026-05-20T03:09:06.026+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-20T03:09:06.549+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-20T03:09:06.579+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-20T03:09:07.129+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-20T03:09:17.362+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-20T03:10:24.486+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=22.4 eventLoopDelayMaxMs=5494.5 eventLoopUtilization=0.212 cpuCoreRatio=0.105 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:10:24.498+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:10:54.479+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:11:24.478+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:11:35.906+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41128 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41128->127.0.0.1:18789 conn=b10581e4…9fe0 [39m
[90m2026-05-20T03:11:36.134+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T03:11:36.150+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=2 [39m
[90m2026-05-20T03:11:40.431+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=7 [39m
[90m2026-05-20T03:11:40.492+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ status 46ms id=7a2808ac…4511 [39m
[90m2026-05-20T03:11:40.520+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=3 healthVersion=7 [39m
[90m2026-05-20T03:11:40.532+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4639 handshake=connected lastFrameType=req lastFrameMethod=status lastFrameId=7a2808ac-49c8-4f68-9062-9d34bfc94511 endpoint=127.0.0.1:41128->127.0.0.1:18789 [39m
[90m2026-05-20T03:11:47.641+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36530 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36530->127.0.0.1:18789 conn=c21e55b9…0562 [39m
[90m2026-05-20T03:11:47.673+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:channels.status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T03:11:47.694+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=3 stateVersion=4 [39m
[90m2026-05-20T03:11:51.443+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=4 healthVersion=8 [39m
[90m2026-05-20T03:11:56.141+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ channels.status 4684ms id=6a56a8c2…8e1c [39m
[90m2026-05-20T03:11:56.144+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:11:56.160+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=5 healthVersion=8 [39m
[90m2026-05-20T03:11:56.172+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=8546 handshake=connected lastFrameType=req lastFrameMethod=channels.status lastFrameId=6a56a8c2-41d9-4ed6-a89a-1d5d2bb08e1c endpoint=127.0.0.1:36530->127.0.0.1:18789 [39m
[90m2026-05-20T03:11:56.188+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=36544 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:36544->127.0.0.1:18789 conn=40c82dbe…2c29 [39m
[90m2026-05-20T03:11:56.219+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:doctor.memory.status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T03:11:56.231+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=4 stateVersion=6 [39m
[90m2026-05-20T03:11:59.990+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=6 healthVersion=9 [39m
[90m2026-05-20T03:12:00.334+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ doctor.memory.status 303ms id=7caf9818…d7f6 [39m
[90m2026-05-20T03:12:00.354+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=7 healthVersion=9 [39m
[90m2026-05-20T03:12:00.366+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4167 handshake=connected lastFrameType=req lastFrameMethod=doctor.memory.status lastFrameId=7caf9818-d3d0-4db7-9d22-8816d251d7f6 endpoint=127.0.0.1:36544->127.0.0.1:18789 [39m
[90m2026-05-20T03:12:26.151+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=22.7 eventLoopDelayMaxMs=6161.4 eventLoopUtilization=0.365 cpuCoreRatio=0.169 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:12:26.158+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:12:28.126+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38858 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38858->127.0.0.1:18789 conn=34c3141d…2392 [39m
[90m2026-05-20T03:12:28.150+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:device.pair.list version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T03:12:28.167+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=8 [39m
[90m2026-05-20T03:12:31.650+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=8 healthVersion=11 [39m
[90m2026-05-20T03:12:31.668+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 4ms id=747609bc…c37f [39m
[90m2026-05-20T03:12:31.683+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=9 healthVersion=11 [39m
[90m2026-05-20T03:12:31.693+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3590 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=747609bc-26ea-4da6-9190-f446e567c37f endpoint=127.0.0.1:38858->127.0.0.1:18789 [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[90m2026-05-20T03:12:44.852+00:00 [39m [34m[reload] [39m [36mskills snapshot invalidated by config change (skills.entries) [39m
[90m2026-05-20T03:12:44.866+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (meta.lastTouchedAt, skills.entries, wizard.lastRunAt, wizard.lastRunCommand, plugins) [39m
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[90m2026-05-20T03:12:49.279+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-20T03:12:49.292+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-20T03:12:49.309+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 44.1ms [39m
[90m2026-05-20T03:12:49.324+00:00 [39m [34m[reload] [39m [36mconfig hot reload applied (plugins) [39m
[90m2026-05-20T03:12:49.360+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=57460 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:57460->127.0.0.1:18789 conn=af7d45b1…1abe [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[90m2026-05-20T03:12:50.828+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=af7d45b1-e7a4-48fa-b288-a86ba2621abe peer=127.0.0.1:57460->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-20T03:12:50.840+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=1454 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=2c17821b-0048-40ea-87f0-c5069944c32f endpoint=127.0.0.1:57460->127.0.0.1:18789 [39m
[90m2026-05-20T03:12:56.155+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:13:07.790+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41990 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41990->127.0.0.1:18789 conn=163c9a81…1c92 [39m
[90m2026-05-20T03:13:07.987+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=d019c0ef60a05b7aa251f9d7113fb6ba31e56181425fadad9203a3836a6355c9 role=operator [39m
[90m2026-05-20T03:13:08.045+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T03:13:08.062+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-20T03:13:15.196+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=12 [39m
[90m2026-05-20T03:13:26.052+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=13 [39m
[90m2026-05-20T03:13:26.087+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=18327 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=6c3fb5c0-32db-4cbd-9da9-daf8a5499352 endpoint=127.0.0.1:41990->127.0.0.1:18789 [39m
[90m2026-05-20T03:13:26.131+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 43ms id=6c3fb5c0…9352 [39m
[90m2026-05-20T03:13:26.147+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:13:32.951+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54164 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54164->127.0.0.1:18789 conn=118e17d4…0bfd [39m
[90m2026-05-20T03:13:33.123+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T03:13:33.149+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-20T03:13:40.457+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=14 [39m
[90m2026-05-20T03:13:40.481+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 9ms id=0d65bc1d…4dfe [39m
[90m2026-05-20T03:13:40.504+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=7580 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=0d65bc1d-5943-4339-81de-78949f8a4dfe endpoint=127.0.0.1:54164->127.0.0.1:18789 [39m
[90m2026-05-20T03:13:40.550+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48188 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48188->127.0.0.1:18789 conn=47b8179f…88e8 [39m
[90m2026-05-20T03:13:40.595+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=d019c0ef60a05b7aa251f9d7113fb6ba31e56181425fadad9203a3836a6355c9 ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.approvals,operator.pairing,operator.read,operator.talk.secrets,operator.write client=cli conn=47b8179f-e975-4a43-a93a-320b25ae88e8 [39m
[90m2026-05-20T03:13:40.801+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=47b8179f-e975-4a43-a93a-320b25ae88e8 peer=127.0.0.1:48188->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=pairing required: device is asking for more scopes than currently approved (requestId: d371d4f2-0d38-44df-a238-c9c29b639 [39m
[90m2026-05-20T03:13:40.816+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is asking for more scopes than currently approved (requestId: d371d4f2-0d38-44df-a238-c9c29b639 durationMs=217 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d6732f1f-681a-409f-9f01-441bc8fb530d endpoint=127.0.0.1:48188->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[90m2026-05-20T03:13:43.629+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48196 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48196->127.0.0.1:18789 conn=fd6a7931…ee71 [39m
[90m2026-05-20T03:13:44.244+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=2026.5.18 mode=ui clientId=openclaw-control-ui platform=android auth=token [39m
[90m2026-05-20T03:13:44.256+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=6 stateVersion=10 [39m
[90m2026-05-20T03:13:52.745+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=15 [39m
[90m2026-05-20T03:13:58.732+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 5973ms cached=true id=f024f967…aede [39m
[90m2026-05-20T03:14:04.938+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ skills.status 12177ms id=53aa7f17…b4ad [39m
[90m2026-05-20T03:14:06.212+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=16 [39m
[90m2026-05-20T03:14:06.227+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:14:06.233+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:14:21.521+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=17 [39m
[90m2026-05-20T03:14:36.274+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:14:36.289+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=24.7 eventLoopDelayMaxMs=6337.6 eventLoopUtilization=0.416 cpuCoreRatio=0.164 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:14:36.297+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:15:06.260+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:15:06.292+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:15:22.440+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=18 [39m
[90m2026-05-20T03:15:36.279+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:15:36.293+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:16:06.236+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:16:06.295+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:16:36.474+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=19 [39m
[90m2026-05-20T03:16:36.492+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:16:36.497+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=32.2 eventLoopDelayMaxMs=20669.5 eventLoopUtilization=0.703 cpuCoreRatio=0.179 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:16:36.501+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:17:06.565+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:17:06.577+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:17:26.767+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=20 [39m
[90m2026-05-20T03:17:36.573+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:17:36.599+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:18:06.573+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:18:06.594+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:18:25.548+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=21 [39m
[90m2026-05-20T03:18:36.597+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:18:36.622+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=28.7 eventLoopDelayMaxMs=9739.2 eventLoopUtilization=0.384 cpuCoreRatio=0.221 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:18:36.634+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:19:23.058+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=22 [39m
[90m2026-05-20T03:19:23.072+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:19:23.076+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:19:53.159+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:19:53.182+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:20:29.410+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=23 [39m
[90m2026-05-20T03:20:29.425+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:20:29.432+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:20:59.501+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:21:34.314+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=24 [39m
[90m2026-05-20T03:21:34.329+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:21:34.334+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=35s eventLoopDelayP99Ms=25.3 eventLoopDelayMaxMs=17448.3 eventLoopUtilization=0.546 cpuCoreRatio=0.317 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:21:34.341+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:22:04.399+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:22:04.414+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:22:29.629+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=25 [39m
[90m2026-05-20T03:22:34.370+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:22:34.416+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:23:04.384+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:23:04.416+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:23:27.231+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=26 [39m
[90m2026-05-20T03:23:34.391+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:23:34.418+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=26.1 eventLoopDelayMaxMs=10351.5 eventLoopUtilization=0.416 cpuCoreRatio=0.28 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:23:34.429+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:24:04.396+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:24:04.417+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:24:25.611+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=27 [39m
[90m2026-05-20T03:24:34.386+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:24:34.421+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:25:04.423+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:25:04.441+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:25:30.151+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=28 [39m
[90m2026-05-20T03:25:34.420+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:25:34.443+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.3 eventLoopDelayMaxMs=10544.5 eventLoopUtilization=0.413 cpuCoreRatio=0.258 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:25:34.453+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:26:04.424+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:26:04.450+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:26:31.776+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=29 [39m
[90m2026-05-20T03:26:34.361+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:26:34.449+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:27:04.389+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:27:04.447+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:27:30.479+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=30 [39m
[90m2026-05-20T03:27:34.377+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:27:34.447+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.5 eventLoopDelayMaxMs=10863.2 eventLoopUtilization=0.408 cpuCoreRatio=0.18 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:27:34.455+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:28:04.397+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:28:04.454+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:28:28.379+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=31 [39m
[90m2026-05-20T03:28:34.638+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:28:34.653+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:29:04.630+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:29:04.646+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:29:26.358+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=32 [39m
[90m2026-05-20T03:29:34.608+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:29:34.647+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=29.4 eventLoopDelayMaxMs=6752.8 eventLoopUtilization=0.455 cpuCoreRatio=0.22 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:29:34.649+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:30:04.640+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:30:04.657+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:30:28.906+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=33 [39m
[90m2026-05-20T03:30:34.622+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:30:34.659+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:31:04.628+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:31:04.654+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:31:27.711+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=34 [39m
[90m2026-05-20T03:31:34.645+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:31:34.660+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=27.1 eventLoopDelayMaxMs=8090.8 eventLoopUtilization=0.308 cpuCoreRatio=0.124 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:31:34.663+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:32:04.635+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:32:04.662+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:32:28.014+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=35 [39m
[90m2026-05-20T03:32:34.630+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:32:34.667+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:33:04.596+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:33:04.662+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:33:28.646+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=36 [39m
[90m2026-05-20T03:33:34.617+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:33:34.661+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.3 eventLoopDelayMaxMs=9026.1 eventLoopUtilization=0.343 cpuCoreRatio=0.136 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:33:34.668+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:34:04.607+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:34:04.658+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:34:25.826+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=37 [39m
[90m2026-05-20T03:34:34.630+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:34:34.667+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:35:04.630+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:35:04.662+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:35:28.992+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=38 [39m
[90m2026-05-20T03:36:10.462+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-20T03:36:10.731+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T03:36:10.871+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T03:36:10.979+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T03:36:11.095+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T03:36:11.162+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T03:36:11.315+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-20T03:36:11.717+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1266.4ms [39m
[90m2026-05-20T03:36:42.784+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T03:36:42.790+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 16.0ms [39m
[90m2026-05-20T03:37:18.775+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T03:37:18.791+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 32.0ms [39m
[90m2026-05-20T03:37:56.923+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T03:37:56.926+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 13.1ms [39m
[90m2026-05-20T03:38:34.275+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T03:38:34.279+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 13.0ms [39m
[90m2026-05-20T03:39:06.423+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T03:39:06.430+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 16.4ms [39m
[90m2026-05-20T03:39:19.114+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:39:19.123+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=254s eventLoopDelayP99Ms=30.2 eventLoopDelayMaxMs=226022.7 eventLoopUtilization=0.936 cpuCoreRatio=0.402 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:39:19.130+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:39:24.974+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=39 [39m
[90m2026-05-20T03:39:56.480+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-20T03:39:56.499+00:00 [39m [35m[plugins] [39m [90mloading arcee from /usr/local/lib/node_modules/openclaw/dist/extensions/arcee/index.js [39m
[90m2026-05-20T03:39:56.591+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T03:39:56.609+00:00 [39m [35m[plugins] [39m [90mloading cerebras from /usr/local/lib/node_modules/openclaw/dist/extensions/cerebras/index.js [39m
[90m2026-05-20T03:39:56.689+00:00 [39m [35m[plugins] [39m [90mloading chutes from /usr/local/lib/node_modules/openclaw/dist/extensions/chutes/index.js [39m
[90m2026-05-20T03:39:56.833+00:00 [39m [35m[plugins] [39m [90mloading cloudflare-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js [39m
[90m2026-05-20T03:39:56.958+00:00 [39m [35m[plugins] [39m [90mloading comfy from /usr/local/lib/node_modules/openclaw/dist/extensions/comfy/index.js [39m
[90m2026-05-20T03:39:57.093+00:00 [39m [35m[plugins] [39m [90mloading copilot-proxy from /usr/local/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js [39m
[90m2026-05-20T03:39:57.133+00:00 [39m [35m[plugins] [39m [90mloading deepinfra from /usr/local/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js [39m
[90m2026-05-20T03:39:57.463+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T03:39:57.483+00:00 [39m [35m[plugins] [39m [90mloading fal from /usr/local/lib/node_modules/openclaw/dist/extensions/fal/index.js [39m
[90m2026-05-20T03:39:57.623+00:00 [39m [35m[plugins] [39m [90mloading fireworks from /usr/local/lib/node_modules/openclaw/dist/extensions/fireworks/index.js [39m
[90m2026-05-20T03:39:57.767+00:00 [39m [35m[plugins] [39m [90mloading github-copilot from /usr/local/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js [39m
[90m2026-05-20T03:39:57.977+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-20T03:39:58.304+00:00 [39m [35m[plugins] [39m [90mloading groq from /usr/local/lib/node_modules/openclaw/dist/extensions/groq/index.js [39m
[90m2026-05-20T03:39:58.348+00:00 [39m [35m[plugins] [39m [90mloading huggingface from /usr/local/lib/node_modules/openclaw/dist/extensions/huggingface/index.js [39m
[90m2026-05-20T03:39:58.420+00:00 [39m [35m[plugins] [39m [90mloading kilocode from /usr/local/lib/node_modules/openclaw/dist/extensions/kilocode/index.js [39m
[90m2026-05-20T03:39:58.500+00:00 [39m [35m[plugins] [39m [90mloading kimi from /usr/local/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js [39m
[90m2026-05-20T03:39:58.580+00:00 [39m [35m[plugins] [39m [90mloading litellm from /usr/local/lib/node_modules/openclaw/dist/extensions/litellm/index.js [39m
[90m2026-05-20T03:39:58.641+00:00 [39m [35m[plugins] [39m [90mloading lmstudio from /usr/local/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js [39m
[90m2026-05-20T03:39:58.772+00:00 [39m [35m[plugins] [39m [90mloading microsoft-foundry from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js [39m
[90m2026-05-20T03:39:58.904+00:00 [39m [35m[plugins] [39m [90mloading minimax from /usr/local/lib/node_modules/openclaw/dist/extensions/minimax/index.js [39m
[90m2026-05-20T03:39:59.230+00:00 [39m [35m[plugins] [39m [90mloading mistral from /usr/local/lib/node_modules/openclaw/dist/extensions/mistral/index.js [39m
[90m2026-05-20T03:39:59.380+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T03:39:59.393+00:00 [39m [35m[plugins] [39m [90mloading nvidia from /usr/local/lib/node_modules/openclaw/dist/extensions/nvidia/index.js [39m
[90m2026-05-20T03:39:59.430+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-20T03:39:59.729+00:00 [39m [35m[plugins] [39m [90mloading openai from /usr/local/lib/node_modules/openclaw/dist/extensions/openai/index.js [39m
[90m2026-05-20T03:40:00.193+00:00 [39m [35m[plugins] [39m [90mloading opencode from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode/index.js [39m
[90m2026-05-20T03:40:00.260+00:00 [39m [35m[plugins] [39m [90mloading opencode-go from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js [39m
[90m2026-05-20T03:40:00.917+00:00 [39m [35m[plugins] [39m [90mloading openrouter from /usr/local/lib/node_modules/openclaw/dist/extensions/openrouter/index.js [39m
[90m2026-05-20T03:40:01.106+00:00 [39m [35m[plugins] [39m [90mloading qianfan from /usr/local/lib/node_modules/openclaw/dist/extensions/qianfan/index.js [39m
[90m2026-05-20T03:40:01.155+00:00 [39m [35m[plugins] [39m [90mloading qwen from /usr/local/lib/node_modules/openclaw/dist/extensions/qwen/index.js [39m
[90m2026-05-20T03:40:01.314+00:00 [39m [35m[plugins] [39m [90mloading sglang from /usr/local/lib/node_modules/openclaw/dist/extensions/sglang/index.js [39m
[90m2026-05-20T03:40:01.359+00:00 [39m [35m[plugins] [39m [90mloading stepfun from /usr/local/lib/node_modules/openclaw/dist/extensions/stepfun/index.js [39m
[90m2026-05-20T03:40:01.420+00:00 [39m [35m[plugins] [39m [90mloading synthetic from /usr/local/lib/node_modules/openclaw/dist/extensions/synthetic/index.js [39m
[90m2026-05-20T03:40:01.477+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T03:40:01.497+00:00 [39m [35m[plugins] [39m [90mloading together from /usr/local/lib/node_modules/openclaw/dist/extensions/together/index.js [39m
[90m2026-05-20T03:40:01.580+00:00 [39m [35m[plugins] [39m [90mloading venice from /usr/local/lib/node_modules/openclaw/dist/extensions/venice/index.js [39m
[90m2026-05-20T03:40:01.661+00:00 [39m [35m[plugins] [39m [90mloading vercel-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js [39m
[90m2026-05-20T03:40:01.737+00:00 [39m [35m[plugins] [39m [90mloading vllm from /usr/local/lib/node_modules/openclaw/dist/extensions/vllm/index.js [39m
[90m2026-05-20T03:40:01.791+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T03:40:01.804+00:00 [39m [35m[plugins] [39m [90mloading vydra from /usr/local/lib/node_modules/openclaw/dist/extensions/vydra/index.js [39m
[90m2026-05-20T03:40:01.890+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-20T03:40:01.907+00:00 [39m [35m[plugins] [39m [90mloading xiaomi from /usr/local/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js [39m
[90m2026-05-20T03:40:02.006+00:00 [39m [35m[plugins] [39m [90mloading zai from /usr/local/lib/node_modules/openclaw/dist/extensions/zai/index.js [39m
[90m2026-05-20T03:40:02.069+00:00 [39m [35m[plugins] [39m [90mloaded 45 plugin(s) (45 attempted) in 5599.2ms [39m
[90m2026-05-20T03:40:02.103+00:00 [39m [35m[plugins] [39m [90m[hooks] running before_agent_reply (1 handlers, first-claim wins) [39m
[90m2026-05-20T03:40:06.912+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:40:06.915+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:40:39.323+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-20T03:40:39.325+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 14.1ms [39m
2026-05-20T03:40:44.178+00:00 memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=200000 threshold=176000 isHeartbeat=true isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=98 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[90m2026-05-20T03:40:45.039+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=session:agent:main:main queueSize=1 [39m
[90m2026-05-20T03:40:45.042+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=session:agent:main:main waitMs=5 queueSize=0 [39m
[90m2026-05-20T03:40:45.052+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=main queueSize=1 [39m
[90m2026-05-20T03:40:45.054+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=main waitMs=5 queueSize=0 [39m
[90m2026-05-20T03:40:46.523+00:00 [39m [35m[plugins] [39m [90mloading alibaba from /usr/local/lib/node_modules/openclaw/dist/extensions/alibaba/index.js [39m
[90m2026-05-20T03:40:46.569+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-20T03:40:46.581+00:00 [39m [35m[plugins] [39m [90mloading arcee from /usr/local/lib/node_modules/openclaw/dist/extensions/arcee/index.js [39m
[90m2026-05-20T03:40:46.600+00:00 [39m [35m[plugins] [39m [90mloading azure-speech from /usr/local/lib/node_modules/openclaw/dist/extensions/azure-speech/index.js [39m
[90m2026-05-20T03:40:46.660+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-20T03:40:46.722+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T03:40:46.741+00:00 [39m [35m[plugins] [39m [90mloading canvas from /usr/local/lib/node_modules/openclaw/dist/extensions/canvas/index.js [39m
[90m2026-05-20T03:40:46.793+00:00 [39m [35m[plugins] [39m [90mloading cerebras from /usr/local/lib/node_modules/openclaw/dist/extensions/cerebras/index.js [39m
[90m2026-05-20T03:40:46.808+00:00 [39m [35m[plugins] [39m [90mloading chutes from /usr/local/lib/node_modules/openclaw/dist/extensions/chutes/index.js [39m
[90m2026-05-20T03:40:46.836+00:00 [39m [35m[plugins] [39m [90mloading cloudflare-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js [39m
[90m2026-05-20T03:40:46.848+00:00 [39m [35m[plugins] [39m [90mloading comfy from /usr/local/lib/node_modules/openclaw/dist/extensions/comfy/index.js [39m
[90m2026-05-20T03:40:46.864+00:00 [39m [35m[plugins] [39m [90mloading copilot-proxy from /usr/local/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js [39m
[90m2026-05-20T03:40:46.878+00:00 [39m [35m[plugins] [39m [90mloading deepgram from /usr/local/lib/node_modules/openclaw/dist/extensions/deepgram/index.js [39m
[90m2026-05-20T03:40:46.937+00:00 [39m [35m[plugins] [39m [90mloading deepinfra from /usr/local/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js [39m
[90m2026-05-20T03:40:46.954+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T03:40:46.973+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
2026-05-20T03:40:47.007+00:00 Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-20T03:40:47.028+00:00 [39m [35m[plugins] [39m [90mloading document-extract from /usr/local/lib/node_modules/openclaw/dist/extensions/document-extract/index.js [39m
[90m2026-05-20T03:40:47.063+00:00 [39m [35m[plugins] [39m [90mloading elevenlabs from /usr/local/lib/node_modules/openclaw/dist/extensions/elevenlabs/index.js [39m
[90m2026-05-20T03:40:47.214+00:00 [39m [35m[plugins] [39m [90mloading fal from /usr/local/lib/node_modules/openclaw/dist/extensions/fal/index.js [39m
[90m2026-05-20T03:40:47.237+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-20T03:40:47.289+00:00 [39m [35m[plugins] [39m [90mloading fireworks from /usr/local/lib/node_modules/openclaw/dist/extensions/fireworks/index.js [39m
[90m2026-05-20T03:40:47.304+00:00 [39m [35m[plugins] [39m [90mloading github-copilot from /usr/local/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js [39m
[90m2026-05-20T03:40:47.321+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-20T03:40:47.344+00:00 [39m [35m[plugins] [39m [90mloading groq from /usr/local/lib/node_modules/openclaw/dist/extensions/groq/index.js [39m
[90m2026-05-20T03:40:47.357+00:00 [39m [35m[plugins] [39m [90mloading huggingface from /usr/local/lib/node_modules/openclaw/dist/extensions/huggingface/index.js [39m
[90m2026-05-20T03:40:47.385+00:00 [39m [35m[plugins] [39m [90mloading inworld from /usr/local/lib/node_modules/openclaw/dist/extensions/inworld/index.js [39m
[90m2026-05-20T03:40:47.442+00:00 [39m [35m[plugins] [39m [90mloading kilocode from /usr/local/lib/node_modules/openclaw/dist/extensions/kilocode/index.js [39m
[90m2026-05-20T03:40:47.458+00:00 [39m [35m[plugins] [39m [90mloading kimi from /usr/local/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js [39m
[90m2026-05-20T03:40:47.472+00:00 [39m [35m[plugins] [39m [90mloading litellm from /usr/local/lib/node_modules/openclaw/dist/extensions/litellm/index.js [39m
[90m2026-05-20T03:40:47.491+00:00 [39m [35m[plugins] [39m [90mloading lmstudio from /usr/local/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js [39m
[90m2026-05-20T03:40:47.521+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-20T03:40:47.529+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-20T03:40:47.555+00:00 [39m [35m[plugins] [39m [90mloading microsoft from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft/index.js [39m
[90m2026-05-20T03:40:47.660+00:00 [39m [35m[plugins] [39m [90mloading microsoft-foundry from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js [39m
[90m2026-05-20T03:40:47.691+00:00 [39m [35m[plugins] [39m [90mloading minimax from /usr/local/lib/node_modules/openclaw/dist/extensions/minimax/index.js [39m
[90m2026-05-20T03:40:47.707+00:00 [39m [35m[plugins] [39m [90mloading mistral from /usr/local/lib/node_modules/openclaw/dist/extensions/mistral/index.js [39m
[90m2026-05-20T03:40:47.722+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T03:40:47.738+00:00 [39m [35m[plugins] [39m [90mloading nvidia from /usr/local/lib/node_modules/openclaw/dist/extensions/nvidia/index.js [39m
[90m2026-05-20T03:40:47.762+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-20T03:40:47.784+00:00 [39m [35m[plugins] [39m [90mloading openai from /usr/local/lib/node_modules/openclaw/dist/extensions/openai/index.js [39m
[90m2026-05-20T03:40:47.797+00:00 [39m [35m[plugins] [39m [90mloading opencode from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode/index.js [39m
[90m2026-05-20T03:40:47.808+00:00 [39m [35m[plugins] [39m [90mloading opencode-go from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js [39m
[90m2026-05-20T03:40:47.821+00:00 [39m [35m[plugins] [39m [90mloading openrouter from /usr/local/lib/node_modules/openclaw/dist/extensions/openrouter/index.js [39m
[90m2026-05-20T03:40:47.838+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
2026-05-20T03:40:47.872+00:00 Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-20T03:40:47.891+00:00 [39m [35m[plugins] [39m [90mloading qianfan from /usr/local/lib/node_modules/openclaw/dist/extensions/qianfan/index.js [39m
[90m2026-05-20T03:40:47.905+00:00 [39m [35m[plugins] [39m [90mloading qwen from /usr/local/lib/node_modules/openclaw/dist/extensions/qwen/index.js [39m
[90m2026-05-20T03:40:47.919+00:00 [39m [35m[plugins] [39m [90mloading runway from /usr/local/lib/node_modules/openclaw/dist/extensions/runway/index.js [39m
[90m2026-05-20T03:40:47.967+00:00 [39m [35m[plugins] [39m [90mloading senseaudio from /usr/local/lib/node_modules/openclaw/dist/extensions/senseaudio/index.js [39m
[90m2026-05-20T03:40:48.000+00:00 [39m [35m[plugins] [39m [90mloading sglang from /usr/local/lib/node_modules/openclaw/dist/extensions/sglang/index.js [39m
[90m2026-05-20T03:40:48.029+00:00 [39m [35m[plugins] [39m [90mloading stepfun from /usr/local/lib/node_modules/openclaw/dist/extensions/stepfun/index.js [39m
[90m2026-05-20T03:40:48.043+00:00 [39m [35m[plugins] [39m [90mloading synthetic from /usr/local/lib/node_modules/openclaw/dist/extensions/synthetic/index.js [39m
[90m2026-05-20T03:40:48.057+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
2026-05-20T03:40:48.115+00:00 Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-20T03:40:48.159+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T03:40:48.183+00:00 [39m [35m[plugins] [39m [90mloading together from /usr/local/lib/node_modules/openclaw/dist/extensions/together/index.js [39m
[90m2026-05-20T03:40:48.206+00:00 [39m [35m[plugins] [39m [90mloading tts-local-cli from /usr/local/lib/node_modules/openclaw/dist/extensions/tts-local-cli/index.js [39m
[90m2026-05-20T03:40:48.255+00:00 [39m [35m[plugins] [39m [90mloading venice from /usr/local/lib/node_modules/openclaw/dist/extensions/venice/index.js [39m
[90m2026-05-20T03:40:48.271+00:00 [39m [35m[plugins] [39m [90mloading vercel-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js [39m
[90m2026-05-20T03:40:48.286+00:00 [39m [35m[plugins] [39m [90mloading vllm from /usr/local/lib/node_modules/openclaw/dist/extensions/vllm/index.js [39m
[90m2026-05-20T03:40:48.302+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T03:40:48.317+00:00 [39m [35m[plugins] [39m [90mloading voyage from /usr/local/lib/node_modules/openclaw/dist/extensions/voyage/index.js [39m
[90m2026-05-20T03:40:48.363+00:00 [39m [35m[plugins] [39m [90mloading vydra from /usr/local/lib/node_modules/openclaw/dist/extensions/vydra/index.js [39m
[90m2026-05-20T03:40:48.380+00:00 [39m [35m[plugins] [39m [90mloading web-readability from /usr/local/lib/node_modules/openclaw/dist/extensions/web-readability/index.js [39m
[90m2026-05-20T03:40:48.414+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-20T03:40:48.430+00:00 [39m [35m[plugins] [39m [90mloading xiaomi from /usr/local/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js [39m
[90m2026-05-20T03:40:48.445+00:00 [39m [35m[plugins] [39m [90mloading zai from /usr/local/lib/node_modules/openclaw/dist/extensions/zai/index.js [39m
[90m2026-05-20T03:40:48.448+00:00 [39m [35m[plugins] [39m [90mloaded 90 plugin(s) (64 attempted) in 1948.2ms [39m
[90m2026-05-20T03:40:56.992+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=40 [39m
[90m2026-05-20T03:40:57.006+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:40:57.010+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:41:10.173+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=main durationMs=25108 error="Error: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-20T03:41:10.191+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=session:agent:main:main durationMs=25137 error="Error: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-20T03:41:10.338+00:00 [39m [34m[model-fallback/decision] [39m [33mmodel fallback decision: decision=candidate_failed requested=ollama/qwen3-coder:480b-cloud candidate=ollama/qwen3-coder:480b-cloud reason=auth next=none detail=No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. [39m
2026-05-20T03:41:10.346+00:00 Embedded agent failed before reply: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. | No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir.
[90m2026-05-20T03:41:10.393+00:00 [39m [36m[ws] [39m [36m→ event heartbeat seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-20T03:41:27.090+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:41:27.106+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=35.2 eventLoopDelayMaxMs=13363.1 eventLoopUtilization=0.549 cpuCoreRatio=0.309 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:41:27.119+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:41:58.436+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=41 [39m
[90m2026-05-20T03:41:58.453+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:41:58.456+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:42:28.536+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:42:28.578+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:43:01.401+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=42 [39m
[90m2026-05-20T03:43:01.415+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:43:01.419+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:43:31.502+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:44:04.714+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=43 [39m
[90m2026-05-20T03:44:04.735+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:44:04.738+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=33s eventLoopDelayP99Ms=38.9 eventLoopDelayMaxMs=13631.5 eventLoopUtilization=0.489 cpuCoreRatio=0.206 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:44:04.740+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:44:34.768+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:44:34.781+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:44:57.190+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=44 [39m
[90m2026-05-20T03:45:04.776+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:45:04.801+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:45:34.776+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:45:34.801+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:45:47.607+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56280 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56280->127.0.0.1:18789 conn=6ea80e84…6250 [39m
[90m2026-05-20T03:45:49.082+00:00 [39m [36m[ws] [39m [36m→ event device.pair.requested seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-20T03:45:49.512+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=6ea80e84-ffc0-4077-b7b8-7199d8536250 peer=127.0.0.1:56280->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 4882e1b0-ee13-4b98-a796-528811a8ef43) [39m
[90m2026-05-20T03:45:49.524+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 4882e1b0-ee13-4b98-a796-528811a8ef43) durationMs=1903 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=ce8a2f0b-489e-4e8b-95c1-f6acf65ac07b endpoint=127.0.0.1:56280->127.0.0.1:18789 [39m
[90m2026-05-20T03:46:00.374+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=45 [39m
[90m2026-05-20T03:46:03.191+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58068 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58068->127.0.0.1:18789 conn=2dab5be0…8460 [39m
[90m2026-05-20T03:46:03.393+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T03:46:03.411+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=1 stateVersion=10 [39m
[90m2026-05-20T03:46:09.574+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=46 [39m
[90m2026-05-20T03:46:09.607+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:46:09.613+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=35s eventLoopDelayP99Ms=40.7 eventLoopDelayMaxMs=9277.8 eventLoopUtilization=0.502 cpuCoreRatio=0.2 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:46:09.617+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:46:09.698+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 44ms id=a6274e98…2980 [39m
[90m2026-05-20T03:46:09.726+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=6548 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=a6274e98-709b-4108-a9d9-74c8bb252980 endpoint=127.0.0.1:58068->127.0.0.1:18789 [39m
[90m2026-05-20T03:46:21.223+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38400 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38400->127.0.0.1:18789 conn=45852d47…e2f2 [39m
[90m2026-05-20T03:46:21.379+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T03:46:21.397+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=1 stateVersion=10 [39m
[90m2026-05-20T03:46:29.839+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=47 [39m
[90m2026-05-20T03:46:29.878+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 22ms id=27155434…7ed4 [39m
[90m2026-05-20T03:46:29.902+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=8705 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=27155434-f125-4e58-8b4b-242ff9d97ed4 endpoint=127.0.0.1:38400->127.0.0.1:18789 [39m
[90m2026-05-20T03:46:29.922+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56544 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56544->127.0.0.1:18789 conn=b58dcf13…c43c [39m
[90m2026-05-20T03:46:29.993+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T03:46:30.006+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=1 stateVersion=10 [39m
[90m2026-05-20T03:46:37.557+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=48 [39m
[90m2026-05-20T03:46:37.613+00:00 [39m [36m[gateway] [39m [36mdevice pairing approved device=c122a8259ab17c0739ef5a6f7d93953d67f200c895c3854d7c859ca4f51ee1bb role=node [39m
[90m2026-05-20T03:46:37.623+00:00 [39m [36m[ws] [39m [36m→ event device.pair.resolved seq=per-client clients=2 dropIfSlow=true [39m
[90m2026-05-20T03:46:37.633+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.approve 64ms id=02d008b4…d452 [39m
[90m2026-05-20T03:46:37.653+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=7729 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=02d008b4-24bd-4a05-893f-3d031f2fd452 endpoint=127.0.0.1:56544->127.0.0.1:18789 [39m
[90m2026-05-20T03:46:39.472+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=46122 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:46122->127.0.0.1:18789 conn=3fdc98c3…3676 [39m
[90m2026-05-20T03:46:39.619+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T03:46:39.628+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:46:40.248+00:00 [39m [36m[ws] [39m [36m→ event node.pair.requested seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-20T03:46:40.274+00:00 [39m [36m[ws] [39m [36m← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.18 mode=node clientId=node-host platform=android auth=token [39m
[90m2026-05-20T03:46:40.300+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=11 [39m
[90m2026-05-20T03:46:48.411+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=49 [39m
[90m2026-05-20T03:47:02.239+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=50 [39m
[90m2026-05-20T03:47:09.640+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:47:09.658+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:47:39.615+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:47:39.658+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:48:01.445+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=51 [39m
[90m2026-05-20T03:48:09.642+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:48:09.663+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=31.1 eventLoopDelayMaxMs=10334.8 eventLoopUtilization=0.413 cpuCoreRatio=0.129 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:48:09.674+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:48:39.660+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:48:39.673+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:48:58.100+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=52 [39m
[90m2026-05-20T03:49:09.648+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:49:09.686+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:49:39.650+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:49:39.684+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:49:55.696+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=53 [39m
[90m2026-05-20T03:50:09.662+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:50:09.686+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=31.3 eventLoopDelayMaxMs=4588.6 eventLoopUtilization=0.253 cpuCoreRatio=0.126 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:50:09.695+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:50:39.657+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:50:39.687+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:50:59.133+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=54 [39m
[90m2026-05-20T03:51:09.655+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:51:09.687+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:51:39.652+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:51:39.687+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:52:01.336+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=55 [39m
[90m2026-05-20T03:52:09.670+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:52:09.689+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=31.5 eventLoopDelayMaxMs=10217.3 eventLoopUtilization=0.422 cpuCoreRatio=0.17 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:52:09.699+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:52:39.664+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:52:39.693+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:53:00.762+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=56 [39m
[90m2026-05-20T03:53:09.668+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:53:09.696+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:53:39.654+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:53:39.695+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:54:01.596+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=57 [39m
[90m2026-05-20T03:54:09.657+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:54:09.715+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=33.1 eventLoopDelayMaxMs=10477.4 eventLoopUtilization=0.451 cpuCoreRatio=0.217 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:54:09.719+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:54:39.671+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:54:39.719+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:55:00.645+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=58 [39m
[90m2026-05-20T03:55:09.665+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:55:09.721+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:55:39.651+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:55:39.722+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:56:01.732+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=59 [39m
[90m2026-05-20T03:56:09.657+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:56:09.719+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=33.2 eventLoopDelayMaxMs=10628.4 eventLoopUtilization=0.437 cpuCoreRatio=0.195 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:2ms,sidecars.restart-sentinel:334ms,sidecars.session-locks:337ms,post-attach.update-sentinel:335ms,post-ready.maintenance:3635ms,sidecars.model-prewarm:11335ms [39m
[90m2026-05-20T03:56:09.729+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:56:39.663+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:56:39.723+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T03:57:03.033+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=60 [39m
[90m2026-05-20T03:57:09.662+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T03:57:09.725+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m

Fresh install last apk seemed better dude
Inbox
Cosy <cosychiruka@gmail.com>
	
4:22 AM (1 minute ago)
	
	
to me

 
🦞 LOBSTER-b864...751b
  =====================

[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=false payload=null error={code: NOT_PAIRED, message: pairing required: device is not approved yet, details: {code: PAIRING_REQUIRED, reason: not-paired, requestId: 70b33e1b-6946-4510-a7a1-a61279bded36, remediationHint: Approve this device from the pending pairing requests., deviceId: b86409732d8b2c19abdd3ff75187763b25080fc70eb9a738dfc020b628e7751b, requestedRole: node, requestedScopes: []}}
[NODE] Not paired or token invalid, gateway will close with 1008...
[NODE] Disconnected (closeCode=1008 reason=pairing required: device is not approved yet (requestId: 70b33e1b-6946-4510-a7a1-a61279bded36)); reconnect delegated to socket backoff/watchdog
[NODE] Pairing required (1008) — approving 70b33e1b-6946-4510-a7a1-a61279bded36 via OpenClaw CLI...
[NODE] Gateway token read from openclaw.json
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Explicit approval failed (PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Could not start the CLI.
[openclaw] Reason: gateway timeout after 10000ms
Gateway target: ws://127.0.0.1:18789
Source: cli --url
Config: /root/.openclaw/openclaw.json
[openclaw] Debug: set OPENCLAW_DEBUG=1 to include the stack trace.
[openclaw] Try: openclaw doctor
[openclaw] Help: openclaw --help
, null, null)); retrying with local CLI session...
[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)
[NODE] Pairing approval failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): [openclaw] Could not start the CLI.
[openclaw] Reason: gateway timeout after 10000ms
Gateway target: ws://127.0.0.1:18789
Source: local loopback
Config: /root/.openclaw/openclaw.json
Bind: loopback
[openclaw] Debug: set OPENCLAW_DEBUG=1 to include the stack trace.
[openclaw] Try: openclaw doctor
[openclaw] Help: openclaw --help
, null, null)
[NODE] Pairing will retry in 30s
[NODE] WebSocket reconnected, completing handshake...
[NODE] Challenge received
[NODE] No cached node device token — using first-time pairing path
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=true payload={type: hello-ok, protocol: 4, server: {version: 2026.5.18, connId: f5da7e5b-04f4-4086-9200-20298c11b10d}, features: {methods: [health, diagnostics.stability, doctor.memory.status, doctor.memory.dreamDiary, doctor.memory.backfillDreamDiary, doctor.memory.resetDreamDiary, doctor.memory.resetGroundedShortTerm, doctor.memory.repairDreamingArtifacts, doctor.memory.dedupeDreamDiary, doctor.memory.remHarness, logs.tail, channels.status, channels.start, channels.stop, channels.logout, status, usage.status, usage.cost, tts.status, tts.providers, tts.personas, tts.enable, tts.disable, tts.convert, tts.setProvider, tts.setPersona, config.get, config.set, config.apply, config.patch, config.schema, config.schema.lookup, exec.approvals.get, exec.approvals.set, exec.approvals.node.get, exec.approvals.node.set, exec.approval.get, exec.approval.list, exec.approval.request, exec.approval.waitDecision, exec.approval.resolve, plugin.approval.list, plugin.approval.request, plugin.approval.waitDecision, plugin.approval.resolve, plugins.uiDescriptors, plugins.sessionAction, wizard.start, wizard.next, wizard.cancel, wizard.status, talk.catalog, talk.config, talk.client.create, talk.client.toolCall, talk.session.create, talk.session.join, talk.session.appendAudio, talk.session.startTurn, talk.session.endTurn, talk.session.cancelTurn, talk.session.cancelOutput, talk.session.submitToolResult, talk.session.close, talk.speak, talk.mode, commands.list, models.list, models.authStatus, models.authLogout, tools.catalog, tools.effective, tools.invoke, tasks.list, tasks.get, tasks.cancel, environments.list, environments.status, agents.list, agents.create, agents.update, agents.delete, agents.files.list, agents.files.get, agents.files.set, artifacts.list, artifacts.get, artifacts.download, skills.status, skills.search, skills.detail, skills.bins, skills.upload.begin, skills.upload.chunk, skills.upload.commit, skills.install, skills.update, update.status, update.run, voicewake.get, voicewake.set, secrets.reload, secrets.resolve, voicewake.routing.get, voicewake.routing.set, sessions.list, sessions.subscribe, sessions.unsubscribe, sessions.messages.subscribe, sessions.messages.unsubscribe, sessions.preview, sessions.describe, sessions.compaction.list, sessions.compaction.get, sessions.compaction.branch, sessions.compaction.restore, sessions.create, sessions.send, sessions.abort, sessions.patch, sessions.pluginPatch, sessions.cleanup, sessions.reset, sessions.delete, sessions.compact, last-heartbeat, set-heartbeats, wake, node.pair.request, node.pair.list, node.pair.approve, node.pair.reject, node.pair.remove, node.pair.verify, device.pair.list, device.pair.approve, device.pair.reject, device.pair.remove, device.token.rotate, device.token.revoke, node.rename, node.list, node.describe, node.pluginSurface.refresh, node.pending.drain, node.pending.enqueue, node.invoke, node.pending.pull, node.pending.ack, node.invoke.result, node.event, cron.get, cron.list, cron.status, cron.add, cron.update, cron.remove, cron.run, cron.runs, gateway.identity.get, gateway.restart.preflight, gateway.restart.request, system-presence, system-event, message.action, send, agent, agent.identity.get, agent.wait, chat.history, chat.abort, chat.send], events: [connect.challenge, agent, chat, session.message, session.operation, session.tool, sessions.changed, presence, tick, talk.mode, talk.event, shutdown, health, heartbeat, cron, node.pair.requested, node.pair.resolved, node.invoke.request, device.pair.requested, device.pair.resolved, voicewake.changed, voicewake.routing.changed, exec.approval.requested, exec.approval.resolved, plugin.approval.requested, plugin.approval.resolved, update.available]}, snapshot: {presence: [{host: localhost, ip: 192.168.1.100, version: 2026.5.18, platform: linux 6.17.0-PRoot-Distro, deviceFamily: Linux, modelIdentifier: arm64, mode: gateway, reason: self, text: Gateway: localhost (192.168.1.100) · app 2026.5.18 · mode gateway · reason self, ts: 1779241896772}, {host: OpenClaw Mobile, version: 2026.5.18, platform: android, deviceFamily: Android, mode: node, deviceId: b86409732d8b2c19abdd3ff75187763b25080fc70eb9a738dfc020b628e7751b, roles: [node], instanceId: b86409732d8b2c19abdd3ff75187763b25080fc70eb9a738dfc020b628e7751b, reason: connect, ts: 1779241896767, text: Node: OpenClaw Mobile · mode node}], health: {ok: true, ts: 1779241868001, durationMs: 4815, eventLoop: {degraded: true, reasons: [event_loop_utilization], intervalMs: 9882, delayP99Ms: 27.9, delayMaxMs: 27.9, utilization: 0.995, cpuCoreRatio: 0.382}, plugins: {loaded: [memory-core], errors: []}, modelPricing: {state: ok, sources: []}, channels: {}, channelOrder: [], channelLabels: {}, heartbeatSeconds: 1800, defaultAgentId: main, agents: [{agentId: main, isDefault: true, heartbeat: {enabled: true, every: 30m, everyMs: 1800000, prompt: Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK., target: none, ackMaxChars: 300}, sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 0, recent: []}}], sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 0, recent: []}}, stateVersion: {presence: 11, health: 23}, uptimeMs: 586570, sessionDefaults: {defaultAgentId: main, mainKey: main, mainSessionKey: agent:main:main, scope: per-sender}}, auth: {role: node, scopes: [], deviceToken: Plh3z_WaVRvXr9RzkIKzgs2WSjJpWsZ_U5FJcJp2QJ8, issuedAtMs: 1779241827731}, policy: {maxPayload: 26214400, maxBufferedBytes: 52428800, tickIntervalMs: 30000}} error=null
[NODE] Paired and connected
[NODE] Disconnected
[NODE] Connecting to 127.0.0.1:18789...
[NODE] Connection failed: TimeoutException after 0:00:45.000000: Future not completed
[NODE] Disconnected (closeCode=n/a reason=connect-failed); reconnect delegated to socket backoff/watchdog
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Disconnected (closeCode=n/a reason=connect-failed); reconnect delegated to socket backoff/watchdog
[NODE] Using cached node device token: Plh3z_Wa...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connection failed: Bad state: WebSocket not connected
[NODE] WebSocket reconnected, completing handshake...
[NODE] Challenge received
[NODE] Using cached node device token: Plh3z_Wa...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Reconnect handshake failed: TimeoutException after 0:00:30.000000: Request timed out
[NODE] Disconnected (closeCode=1000 reason=socket-closed); reconnect delegated to socket backoff/watchdog
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Using cached node device token: Plh3z_Wa...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connection failed: Bad state: WebSocket not connected
[NODE] Disconnected (closeCode=n/a reason=connect-failed); reconnect delegated to socket backoff/watchdog
[NODE] WebSocket reconnected, completing handshake...
[NODE] Challenge received
[NODE] Using cached node device token: Plh3z_Wa...
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame protocol=v4 caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=true payload={type: hello-ok, protocol: 4, server: {version: 2026.5.18, connId: 591c347b-b301-48e5-aa1a-e018f41d80f8}, features: {methods: [health, diagnostics.stability, doctor.memory.status, doctor.memory.dreamDiary, doctor.memory.backfillDreamDiary, doctor.memory.resetDreamDiary, doctor.memory.resetGroundedShortTerm, doctor.memory.repairDreamingArtifacts, doctor.memory.dedupeDreamDiary, doctor.memory.remHarness, logs.tail, channels.status, channels.start, channels.stop, channels.logout, status, usage.status, usage.cost, tts.status, tts.providers, tts.personas, tts.enable, tts.disable, tts.convert, tts.setProvider, tts.setPersona, config.get, config.set, config.apply, config.patch, config.schema, config.schema.lookup, exec.approvals.get, exec.approvals.set, exec.approvals.node.get, exec.approvals.node.set, exec.approval.get, exec.approval.list, exec.approval.request, exec.approval.waitDecision, exec.approval.resolve, plugin.approval.list, plugin.approval.request, plugin.approval.waitDecision, plugin.approval.resolve, plugins.uiDescriptors, plugins.sessionAction, wizard.start, wizard.next, wizard.cancel, wizard.status, talk.catalog, talk.config, talk.client.create, talk.client.toolCall, talk.session.create, talk.session.join, talk.session.appendAudio, talk.session.startTurn, talk.session.endTurn, talk.session.cancelTurn, talk.session.cancelOutput, talk.session.submitToolResult, talk.session.close, talk.speak, talk.mode, commands.list, models.list, models.authStatus, models.authLogout, tools.catalog, tools.effective, tools.invoke, tasks.list, tasks.get, tasks.cancel, environments.list, environments.status, agents.list, agents.create, agents.update, agents.delete, agents.files.list, agents.files.get, agents.files.set, artifacts.list, artifacts.get, artifacts.download, skills.status, skills.search, skills.detail, skills.bins, skills.upload.begin, skills.upload.chunk, skills.upload.commit, skills.install, skills.update, update.status, update.run, voicewake.get, voicewake.set, secrets.reload, secrets.resolve, voicewake.routing.get, voicewake.routing.set, sessions.list, sessions.subscribe, sessions.unsubscribe, sessions.messages.subscribe, sessions.messages.unsubscribe, sessions.preview, sessions.describe, sessions.compaction.list, sessions.compaction.get, sessions.compaction.branch, sessions.compaction.restore, sessions.create, sessions.send, sessions.abort, sessions.patch, sessions.pluginPatch, sessions.cleanup, sessions.reset, sessions.delete, sessions.compact, last-heartbeat, set-heartbeats, wake, node.pair.request, node.pair.list, node.pair.approve, node.pair.reject, node.pair.remove, node.pair.verify, device.pair.list, device.pair.approve, device.pair.reject, device.pair.remove, device.token.rotate, device.token.revoke, node.rename, node.list, node.describe, node.pluginSurface.refresh, node.pending.drain, node.pending.enqueue, node.invoke, node.pending.pull, node.pending.ack, node.invoke.result, node.event, cron.get, cron.list, cron.status, cron.add, cron.update, cron.remove, cron.run, cron.runs, gateway.identity.get, gateway.restart.preflight, gateway.restart.request, system-presence, system-event, message.action, send, agent, agent.identity.get, agent.wait, chat.history, chat.abort, chat.send], events: [connect.challenge, agent, chat, session.message, session.operation, session.tool, sessions.changed, presence, tick, talk.mode, talk.event, shutdown, health, heartbeat, cron, node.pair.requested, node.pair.resolved, node.invoke.request, device.pair.requested, device.pair.resolved, voicewake.changed, voicewake.routing.changed, exec.approval.requested, exec.approval.resolved, plugin.approval.requested, plugin.approval.resolved, update.available]}, snapshot: {presence: [{host: localhost, ip: 192.168.1.100, version: 2026.5.18, platform: linux 6.17.0-PRoot-Distro, deviceFamily: Linux, modelIdentifier: arm64, mode: gateway, reason: self, text: Gateway: localhost (192.168.1.100) · app 2026.5.18 · mode gateway · reason self, ts: 1779242807298}, {host: OpenClaw Mobile, version: 2026.5.18, platform: android, deviceFamily: Android, mode: node, deviceId: b86409732d8b2c19abdd3ff75187763b25080fc70eb9a738dfc020b628e7751b, roles: [node], instanceId: b86409732d8b2c19abdd3ff75187763b25080fc70eb9a738dfc020b628e7751b, reason: connect, ts: 1779242807295, text: Node: OpenClaw Mobile · mode node}], health: {ok: true, ts: 1779242793417, durationMs: 3982, eventLoop: {degraded: true, reasons: [event_loop_delay, event_loop_utilization], intervalMs: 91315, delayP99Ms: 43587.2, delayMaxMs: 43587.2, utilization: 1, cpuCoreRatio: 0.424}, plugins: {loaded: [alibaba, anthropic, arcee, azure-speech, browser, byteplus, canvas, cerebras, chutes, cloudflare-ai-gateway, comfy, copilot-proxy, deepgram, deepinfra, deepseek, device-pair, document-extract, elevenlabs, fal, file-transfer, fireworks, github-copilot, google, groq, huggingface, inworld, kilocode, kimi, litellm, lmstudio, memory-core, microsoft, microsoft-foundry, minimax, mistral, moonshot, nvidia, ollama, openai, opencode, opencode-go, openrouter, phone-control, qianfan, qwen, runway, senseaudio, sglang, stepfun, synthetic, talk-voice, tencent, together, tts-local-cli, venice, vercel-ai-gateway, vllm, volcengine, voyage, vydra, web-readability, xai, xiaomi, zai], errors: []}, modelPricing: {state: ok, sources: []}, channels: {}, channelOrder: [], channelLabels: {}, heartbeatSeconds: 1800, defaultAgentId: main, agents: [{agentId: main, isDefault: true, heartbeat: {enabled: true, every: 30m, everyMs: 1800000, prompt: Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK., target: none, ackMaxChars: 300}, sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1779242743576, age: 45859}]}}], sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1779242743576, age: 45859}]}}, stateVersion: {presence: 13, health: 36}, uptimeMs: 1497096, sessionDefaults: {defaultAgentId: main, mainKey: main, mainSessionKey: agent:main:main, scope: per-sender}}, auth: {role: node, scopes: [], deviceToken: Plh3z_WaVRvXr9RzkIKzgs2WSjJpWsZ_U5FJcJp2QJ8, issuedAtMs: 1779241827731}, policy: {maxPayload: 26214400, maxBufferedBytes: 52428800, tickIntervalMs: 30000}} error=null
[NODE] Paired and connected






==========================================================================================






[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-05-20T01:41:55.245+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-20T01:41:55.351+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-20T01:41:55.430+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[90m2026-05-20T01:42:00.510+00:00 [39m [36m[gateway] [39m [36mauto-enabled plugins for this runtime without writing config: [39m
[36m- ollama/qwen3-coder:480b-cloud model configured, enabled automatically. [39m
[90m2026-05-20T01:42:06.814+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-20T01:42:08.372+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-20T01:42:22.906+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-20T01:42:23.421+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-20T01:42:23.436+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 636.4ms [39m
[90m2026-05-20T01:42:24.017+00:00 [39m [36m[gateway] [39m [36magent model: ollama/qwen3-coder:480b-cloud (thinking=medium, fast=off) [39m
[90m2026-05-20T01:42:24.029+00:00 [39m [36m[gateway] [39m [36mhttp server listening (1 plugin: memory-core; 28.6s) [39m
[90m2026-05-20T01:42:24.039+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-20.log [39m
[90m2026-05-20T01:42:24.375+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-20T01:42:24.533+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-20T01:42:24.568+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-20T01:42:25.465+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-20T01:42:35.581+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-20T01:42:40.755+00:00 [39m [36m[fetch-timeout] [39m [33mfetch timeout after 2500ms (elapsed 4537ms) timer delayed 2037ms, likely event-loop starvation operation=fetchWithTimeout url=https://registry.npmjs.org/openclaw/latest [39m
[90m2026-05-20T01:43:05.610+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=27.6 eventLoopDelayMaxMs=4211.1 eventLoopUtilization=0.218 cpuCoreRatio=0.12 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:43:05.631+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:43:35.591+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:43:57.987+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56344 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56344->127.0.0.1:18789 conn=8d0409cf…7653 [39m
[90m2026-05-20T01:43:58.251+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T01:43:58.271+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=2 [39m
[90m2026-05-20T01:44:02.550+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=4 [39m
[90m2026-05-20T01:44:02.630+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ status 49ms id=06690eea…fa96 [39m
[90m2026-05-20T01:44:02.660+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=3 healthVersion=4 [39m
[90m2026-05-20T01:44:02.672+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4701 handshake=connected lastFrameType=req lastFrameMethod=status lastFrameId=06690eea-dbf0-4d73-aa29-9600b297fa96 endpoint=127.0.0.1:56344->127.0.0.1:18789 [39m
[90m2026-05-20T01:44:05.595+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:44:09.163+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55836 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55836->127.0.0.1:18789 conn=dcfb6040…1572 [39m
[90m2026-05-20T01:44:09.228+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:channels.status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T01:44:09.253+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=3 stateVersion=4 [39m
[90m2026-05-20T01:44:13.406+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=4 healthVersion=5 [39m
[90m2026-05-20T01:44:13.424+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:44:18.901+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ channels.status 5461ms id=a92f3d1d…3dd4 [39m
[90m2026-05-20T01:44:18.917+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=5 healthVersion=5 [39m
[90m2026-05-20T01:44:18.930+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=9806 handshake=connected lastFrameType=req lastFrameMethod=channels.status lastFrameId=a92f3d1d-2292-4939-ad39-47da93513dd4 endpoint=127.0.0.1:55836->127.0.0.1:18789 [39m
[90m2026-05-20T01:44:18.949+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48396 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48396->127.0.0.1:18789 conn=065c0ea4…3196 [39m
[90m2026-05-20T01:44:18.973+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:doctor.memory.status version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T01:44:18.995+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=4 stateVersion=6 [39m
[90m2026-05-20T01:44:23.144+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=6 healthVersion=6 [39m
[90m2026-05-20T01:44:23.512+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ doctor.memory.status 337ms id=a25b0cc2…76b5 [39m
[90m2026-05-20T01:44:23.543+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=7 healthVersion=6 [39m
[90m2026-05-20T01:44:23.557+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4591 handshake=connected lastFrameType=req lastFrameMethod=doctor.memory.status lastFrameId=a25b0cc2-321f-4843-8a73-16f4044e76b5 endpoint=127.0.0.1:48396->127.0.0.1:18789 [39m
[90m2026-05-20T01:44:35.603+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:44:51.999+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=54474 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:54474->127.0.0.1:18789 conn=2513ef6d…6f47 [39m
[90m2026-05-20T01:44:52.059+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client clientDisplayName=gateway:device.pair.list version=2026.5.18 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-05-20T01:44:52.081+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=8 [39m
[90m2026-05-20T01:44:55.967+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=8 healthVersion=8 [39m
[90m2026-05-20T01:44:55.986+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 6ms id=4b817e35…bac4 [39m
[90m2026-05-20T01:44:56.001+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=1 dropIfSlow=true presenceVersion=9 healthVersion=8 [39m
[90m2026-05-20T01:44:56.016+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=4086 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=4b817e35-72c7-4e36-b65a-3e3b4386bac4 endpoint=127.0.0.1:54474->127.0.0.1:18789 [39m
[90m2026-05-20T01:45:05.603+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23 eventLoopDelayMaxMs=8933.9 eventLoopUtilization=0.466 cpuCoreRatio=0.269 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:45:05.618+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).
[90m2026-05-20T01:45:08.595+00:00 [39m [34m[reload] [39m [36mskills snapshot invalidated by config change (skills.entries) [39m
[90m2026-05-20T01:45:08.608+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (meta.lastTouchedAt, skills.entries, wizard.lastRunAt, wizard.lastRunCommand, plugins) [39m
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[90m2026-05-20T01:45:11.516+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-20T01:45:11.520+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-20T01:45:11.533+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 27.1ms [39m
[90m2026-05-20T01:45:11.563+00:00 [39m [34m[reload] [39m [36mconfig hot reload applied (plugins) [39m
[90m2026-05-20T01:45:11.587+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45682 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45682->127.0.0.1:18789 conn=37c4cae1…c163 [39m
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[90m2026-05-20T01:45:12.806+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=37c4cae1-c6af-47f8-a6d9-70b4df1ec163 peer=127.0.0.1:45682->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-20T01:45:12.817+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=1210 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=97ee39c2-1c9a-44c9-97a8-d00c644d911f endpoint=127.0.0.1:45682->127.0.0.1:18789 [39m
[90m2026-05-20T01:45:28.680+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=45830 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:45830->127.0.0.1:18789 conn=cbc53348…f4a7 [39m
[90m2026-05-20T01:45:29.070+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=d72c2bdc847050561a3490ca36d660375f08d49d5df7c9dcca721ddab5014ada role=operator [39m
[90m2026-05-20T01:45:29.163+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T01:45:29.184+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-20T01:45:37.953+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=9 [39m
[90m2026-05-20T01:45:37.961+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:45:44.970+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=10 [39m
[90m2026-05-20T01:45:44.989+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=16374 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=9250af8c-ba29-4d55-bb3c-321928b164bd endpoint=127.0.0.1:45830->127.0.0.1:18789 [39m
[90m2026-05-20T01:45:45.015+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 30ms id=9250af8c…64bd [39m
[90m2026-05-20T01:45:51.732+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56888 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56888->127.0.0.1:18789 conn=1e3cf38c…3eec [39m
[90m2026-05-20T01:45:52.077+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T01:45:52.129+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=5 stateVersion=9 [39m
[90m2026-05-20T01:46:01.056+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=9 healthVersion=11 [39m
[90m2026-05-20T01:46:01.088+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 17ms id=639d7891…f383 [39m
[90m2026-05-20T01:46:01.130+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=9469 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=639d7891-03c3-4dab-8ddd-45a8a49ff383 endpoint=127.0.0.1:56888->127.0.0.1:18789 [39m
[90m2026-05-20T01:46:01.183+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41034 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41034->127.0.0.1:18789 conn=142ffe67…cf96 [39m
[90m2026-05-20T01:46:01.229+00:00 [39m [36m[gateway] [39m [33msecurity audit: device access upgrade requested reason=scope-upgrade device=d72c2bdc847050561a3490ca36d660375f08d49d5df7c9dcca721ddab5014ada ip=unknown-ip auth=token roleFrom=operator roleTo=operator scopesFrom=operator.pairing scopesTo=operator.approvals,operator.pairing,operator.read,operator.talk.secrets,operator.write client=cli conn=142ffe67-0711-4b96-ab7c-b1f99075cf96 [39m
[90m2026-05-20T01:46:01.491+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=142ffe67-0711-4b96-ab7c-b1f99075cf96 peer=127.0.0.1:41034->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=pairing required: device is asking for more scopes than currently approved (requestId: 02360a42-3057-4b06-9fbd-342d72940 [39m
[90m2026-05-20T01:46:01.513+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is asking for more scopes than currently approved (requestId: 02360a42-3057-4b06-9fbd-342d72940 durationMs=252 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=86a7d014-6be0-4a70-a6ee-9295d5f65015 endpoint=127.0.0.1:41034->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[HEALTH] WS dropped but gateway process is alive (likely temporary overload/reload).
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[WARN] WebSocket disconnected (closeCode=n/a reason=unknown)
[90m2026-05-20T01:46:04.216+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=41046 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:41046->127.0.0.1:18789 conn=55072ea9…d887 [39m
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[90m2026-05-20T01:46:05.076+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=2026.5.18 mode=ui clientId=openclaw-control-ui platform=android auth=token [39m
[90m2026-05-20T01:46:05.116+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=6 stateVersion=10 [39m
[90m2026-05-20T01:46:13.850+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=12 [39m
[90m2026-05-20T01:46:13.855+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:46:18.654+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 4781ms cached=true id=2a9a5cc5…b3e8 [39m
[90m2026-05-20T01:46:24.648+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ skills.status 10778ms id=e46e2171…2286 [39m
[90m2026-05-20T01:46:25.814+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=13 [39m
[90m2026-05-20T01:46:25.835+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:46:47.885+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=14 [39m
[90m2026-05-20T01:46:47.892+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:46:55.902+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:47:17.907+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.4 eventLoopDelayMaxMs=9202.3 eventLoopUtilization=0.371 cpuCoreRatio=0.258 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:47:17.921+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:47:25.906+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:47:44.595+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=15 [39m
[90m2026-05-20T01:47:47.911+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:47:55.904+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:48:17.912+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:48:25.923+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:48:48.378+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=16 [39m
[90m2026-05-20T01:48:48.382+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:48:55.924+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:49:25.845+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T01:49:30.791+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=60796 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:60796->127.0.0.1:18789 conn=d7eb6998…492b [39m
[90m2026-05-20T01:49:31.536+00:00 [39m [36m[ws] [39m [36m→ event device.pair.requested seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-20T01:49:31.636+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=d7eb6998-efa1-42a4-99b0-3d386577492b peer=127.0.0.1:60796->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=pairing required: device is not approved yet (requestId: 70b33e1b-6946-4510-a7a1-a61279bded36) [39m
[90m2026-05-20T01:49:31.653+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=pairing required: device is not approved yet (requestId: 70b33e1b-6946-4510-a7a1-a61279bded36) durationMs=820 cause=pairing-required handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a767b10a-61d9-49b2-b415-a688b8721377 endpoint=127.0.0.1:60796->127.0.0.1:18789 [39m
[90m2026-05-20T01:49:48.419+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=17 [39m
[90m2026-05-20T01:49:48.425+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=34.4 eventLoopDelayMaxMs=10477.4 eventLoopUtilization=0.405 cpuCoreRatio=0.198 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:49:48.427+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:49:48.445+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=58674 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:58674->127.0.0.1:18789 conn=2cad1289…fc3d [39m
[90m2026-05-20T01:49:48.579+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T01:49:48.593+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=3 stateVersion=10 [39m
[90m2026-05-20T01:49:56.876+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=18 [39m
[90m2026-05-20T01:49:56.904+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:49:56.931+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=8473 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=fa043f88-6fe8-4363-baae-478d121adc2f endpoint=127.0.0.1:58674->127.0.0.1:18789 [39m
[90m2026-05-20T01:50:08.721+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38148 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38148->127.0.0.1:18789 conn=67cc932f…de4b [39m
[90m2026-05-20T01:50:09.001+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T01:50:09.045+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=10 [39m
[90m2026-05-20T01:50:17.704+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=19 [39m
[90m2026-05-20T01:50:17.728+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 11ms id=53ae63e0…f5f2 [39m
[90m2026-05-20T01:50:17.750+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=9079 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=53ae63e0-f8e0-45b0-85c4-636f8799f5f2 endpoint=127.0.0.1:38148->127.0.0.1:18789 [39m
[90m2026-05-20T01:50:17.775+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=35412 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:35412->127.0.0.1:18789 conn=dbe174d5…d100 [39m
[90m2026-05-20T01:50:17.913+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T01:50:17.931+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=10 [39m
[90m2026-05-20T01:50:27.674+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=20 [39m
[90m2026-05-20T01:50:27.680+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:50:27.693+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:50:27.766+00:00 [39m [36m[gateway] [39m [36mdevice pairing approved device=b86409732d8b2c19abdd3ff75187763b25080fc70eb9a738dfc020b628e7751b role=node [39m
[90m2026-05-20T01:50:27.778+00:00 [39m [36m[ws] [39m [36m→ event device.pair.resolved seq=per-client clients=2 dropIfSlow=true [39m
[90m2026-05-20T01:50:27.790+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.approve 82ms id=b34ac3c9…1c0d [39m
[90m2026-05-20T01:50:27.809+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=10027 handshake=connected lastFrameType=req lastFrameMethod=device.pair.approve lastFrameId=b34ac3c9-0025-4982-a45d-d84b1fb01c0d endpoint=127.0.0.1:35412->127.0.0.1:18789 [39m
[90m2026-05-20T01:50:48.420+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=10 healthVersion=21 [39m
[90m2026-05-20T01:50:48.435+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=34370 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:34370->127.0.0.1:18789 conn=53a4d265…c3b0 [39m
[90m2026-05-20T01:50:48.555+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token [39m
[90m2026-05-20T01:50:48.567+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=10 [39m
[90m2026-05-20T01:50:57.130+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=22 [39m
[90m2026-05-20T01:50:57.149+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=8715 handshake=connected lastFrameType=req lastFrameMethod=device.pair.list lastFrameId=fd0d9592-1453-48a2-810d-5af4c2745983 endpoint=127.0.0.1:34370->127.0.0.1:18789 [39m
[90m2026-05-20T01:50:57.176+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=48986 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:48986->127.0.0.1:18789 conn=0f3b7fce…590b [39m
[90m2026-05-20T01:50:57.196+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 50ms conn=53a4d265…c3b0 id=fd0d9592…5983 [39m
[90m2026-05-20T01:50:57.297+00:00 [39m [36m[ws] [39m [36m← connect client=cli version=2026.5.18 mode=cli clientId=cli platform=linux auth=token conn=0f3b7fce…590b [39m
[90m2026-05-20T01:50:57.311+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=10 [39m
[90m2026-05-20T01:51:08.012+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=10 healthVersion=23 [39m
[90m2026-05-20T01:51:08.017+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:51:08.029+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:51:08.055+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=10879 handshake=connected lastFrameType=req lastFrameMethod=connect lastFrameId=1146deb6-194d-4f7d-af4a-8b7f89edf603 endpoint=127.0.0.1:48986->127.0.0.1:18789 [39m
[90m2026-05-20T01:51:35.584+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53800 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53800->127.0.0.1:18789 conn=f5da7e5b…b10d [39m
[90m2026-05-20T01:51:36.750+00:00 [39m [36m[ws] [39m [36m→ event node.pair.requested seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-20T01:51:36.766+00:00 [39m [36m[ws] [39m [36m← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.18 mode=node clientId=node-host platform=android auth=token [39m
[90m2026-05-20T01:51:36.789+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=11 [39m
[90m2026-05-20T01:51:45.077+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=24 [39m
[90m2026-05-20T01:51:55.419+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=25 [39m
[90m2026-05-20T01:51:55.423+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=47s eventLoopDelayP99Ms=24.2 eventLoopDelayMaxMs=8346.7 eventLoopUtilization=0.43 cpuCoreRatio=0.188 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:51:55.426+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:51:55.438+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:52:25.440+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:52:25.497+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:52:52.765+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=26 [39m
[90m2026-05-20T01:52:55.435+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:52:55.518+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:53:25.435+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:53:25.531+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:53:56.816+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=27 [39m
[90m2026-05-20T01:53:56.828+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=31s eventLoopDelayP99Ms=23.2 eventLoopDelayMaxMs=11752.4 eventLoopUtilization=0.41 cpuCoreRatio=0.181 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:53:56.830+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:53:56.842+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:54:26.840+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:54:26.883+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:54:56.501+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=28 [39m
[90m2026-05-20T01:54:56.837+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:54:56.895+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:55:26.849+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:55:26.954+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:55:56.416+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=29 [39m
[90m2026-05-20T01:55:56.848+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=26.8 eventLoopDelayMaxMs=11349.8 eventLoopUtilization=0.432 cpuCoreRatio=0.243 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:55:56.862+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:55:56.920+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:56:26.852+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:56:26.926+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:56:54.757+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=30 [39m
[90m2026-05-20T01:56:56.860+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:56:56.950+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:57:26.861+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:57:26.968+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:57:52.744+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=31 [39m
[90m2026-05-20T01:57:56.862+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=25.4 eventLoopDelayMaxMs=7667.2 eventLoopUtilization=0.329 cpuCoreRatio=0.249 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T01:57:56.882+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:57:56.967+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:58:26.867+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:58:26.969+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:59:02.125+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=32 [39m
[90m2026-05-20T01:59:02.131+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:59:02.145+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T01:59:32.146+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T01:59:32.215+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:00:02.113+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=33 [39m
[90m2026-05-20T02:00:02.132+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=26.2 eventLoopDelayMaxMs=17045.7 eventLoopUtilization=0.613 cpuCoreRatio=0.346 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T02:00:02.136+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:00:02.177+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:00:32.147+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:00:32.240+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:01:01.994+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=34 [39m
[90m2026-05-20T02:01:02.139+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:01:02.203+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:01:59.906+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-20T02:02:00.142+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T02:02:00.300+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T02:02:00.388+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T02:02:00.527+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T02:02:00.591+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T02:02:00.765+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-20T02:02:01.211+00:00 [39m [35m[plugins] [39m [90mloaded 7 plugin(s) (7 attempted) in 1317.1ms [39m
[90m2026-05-20T02:02:27.935+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T02:02:27.939+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 13.0ms [39m
[90m2026-05-20T02:03:02.458+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T02:03:02.464+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.1ms [39m
[90m2026-05-20T02:03:34.340+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T02:03:34.343+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 12.4ms [39m
[90m2026-05-20T02:04:11.666+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T02:04:11.670+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.6ms [39m
[90m2026-05-20T02:04:42.994+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T02:04:42.999+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 15.0ms [39m
[90m2026-05-20T02:04:55.938+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=234s eventLoopDelayP99Ms=26.5 eventLoopDelayMaxMs=212064 eventLoopUtilization=0.923 cpuCoreRatio=0.448 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T02:04:55.948+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:04:56.011+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:05:02.129+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=11 healthVersion=35 [39m
[90m2026-05-20T02:05:07.289+00:00 [39m [36m[ws] [39m [36m→ event presence seq=per-client clients=2 dropIfSlow=true presenceVersion=12 healthVersion=35 [39m
[90m2026-05-20T02:05:07.300+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=811739 handshake=connected lastFrameType=ping lastFrameMethod=connect lastFrameId=73ba03b0-9202-42a6-8da4-ddb7a050f4c5 endpoint=127.0.0.1:53800->127.0.0.1:18789 [39m
[90m2026-05-20T02:05:07.384+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=55698 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:55698->127.0.0.1:18789 conn=beec7be0…34af [39m
[90m2026-05-20T02:05:07.446+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=40960 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:40960->127.0.0.1:18789 conn=f63328b9…edd6 [39m
[90m2026-05-20T02:05:07.497+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=38968 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:38968->127.0.0.1:18789 conn=189b552f…43bb [39m
[90m2026-05-20T02:05:33.027+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-20T02:05:33.043+00:00 [39m [35m[plugins] [39m [90mloading arcee from /usr/local/lib/node_modules/openclaw/dist/extensions/arcee/index.js [39m
[90m2026-05-20T02:05:33.110+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T02:05:33.129+00:00 [39m [35m[plugins] [39m [90mloading cerebras from /usr/local/lib/node_modules/openclaw/dist/extensions/cerebras/index.js [39m
[90m2026-05-20T02:05:33.180+00:00 [39m [35m[plugins] [39m [90mloading chutes from /usr/local/lib/node_modules/openclaw/dist/extensions/chutes/index.js [39m
[90m2026-05-20T02:05:33.267+00:00 [39m [35m[plugins] [39m [90mloading cloudflare-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js [39m
[90m2026-05-20T02:05:33.384+00:00 [39m [35m[plugins] [39m [90mloading comfy from /usr/local/lib/node_modules/openclaw/dist/extensions/comfy/index.js [39m
[90m2026-05-20T02:05:33.489+00:00 [39m [35m[plugins] [39m [90mloading copilot-proxy from /usr/local/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js [39m
[90m2026-05-20T02:05:33.540+00:00 [39m [35m[plugins] [39m [90mloading deepinfra from /usr/local/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js [39m
[90m2026-05-20T02:05:33.783+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T02:05:33.798+00:00 [39m [35m[plugins] [39m [90mloading fal from /usr/local/lib/node_modules/openclaw/dist/extensions/fal/index.js [39m
[90m2026-05-20T02:05:33.930+00:00 [39m [35m[plugins] [39m [90mloading fireworks from /usr/local/lib/node_modules/openclaw/dist/extensions/fireworks/index.js [39m
[90m2026-05-20T02:05:34.000+00:00 [39m [35m[plugins] [39m [90mloading github-copilot from /usr/local/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js [39m
[90m2026-05-20T02:05:34.160+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-20T02:05:34.404+00:00 [39m [35m[plugins] [39m [90mloading groq from /usr/local/lib/node_modules/openclaw/dist/extensions/groq/index.js [39m
[90m2026-05-20T02:05:34.471+00:00 [39m [35m[plugins] [39m [90mloading huggingface from /usr/local/lib/node_modules/openclaw/dist/extensions/huggingface/index.js [39m
[90m2026-05-20T02:05:34.531+00:00 [39m [35m[plugins] [39m [90mloading kilocode from /usr/local/lib/node_modules/openclaw/dist/extensions/kilocode/index.js [39m
[90m2026-05-20T02:05:34.602+00:00 [39m [35m[plugins] [39m [90mloading kimi from /usr/local/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js [39m
[90m2026-05-20T02:05:34.683+00:00 [39m [35m[plugins] [39m [90mloading litellm from /usr/local/lib/node_modules/openclaw/dist/extensions/litellm/index.js [39m
[90m2026-05-20T02:05:34.748+00:00 [39m [35m[plugins] [39m [90mloading lmstudio from /usr/local/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js [39m
[90m2026-05-20T02:05:34.860+00:00 [39m [35m[plugins] [39m [90mloading microsoft-foundry from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js [39m
[90m2026-05-20T02:05:34.981+00:00 [39m [35m[plugins] [39m [90mloading minimax from /usr/local/lib/node_modules/openclaw/dist/extensions/minimax/index.js [39m
[90m2026-05-20T02:05:35.281+00:00 [39m [35m[plugins] [39m [90mloading mistral from /usr/local/lib/node_modules/openclaw/dist/extensions/mistral/index.js [39m
[90m2026-05-20T02:05:35.412+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T02:05:35.426+00:00 [39m [35m[plugins] [39m [90mloading nvidia from /usr/local/lib/node_modules/openclaw/dist/extensions/nvidia/index.js [39m
[90m2026-05-20T02:05:35.471+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-20T02:05:35.757+00:00 [39m [35m[plugins] [39m [90mloading openai from /usr/local/lib/node_modules/openclaw/dist/extensions/openai/index.js [39m
[90m2026-05-20T02:05:36.191+00:00 [39m [35m[plugins] [39m [90mloading opencode from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode/index.js [39m
[90m2026-05-20T02:05:36.255+00:00 [39m [35m[plugins] [39m [90mloading opencode-go from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js [39m
[90m2026-05-20T02:05:36.911+00:00 [39m [35m[plugins] [39m [90mloading openrouter from /usr/local/lib/node_modules/openclaw/dist/extensions/openrouter/index.js [39m
[90m2026-05-20T02:05:37.153+00:00 [39m [35m[plugins] [39m [90mloading qianfan from /usr/local/lib/node_modules/openclaw/dist/extensions/qianfan/index.js [39m
[90m2026-05-20T02:05:37.217+00:00 [39m [35m[plugins] [39m [90mloading qwen from /usr/local/lib/node_modules/openclaw/dist/extensions/qwen/index.js [39m
[90m2026-05-20T02:05:37.332+00:00 [39m [35m[plugins] [39m [90mloading sglang from /usr/local/lib/node_modules/openclaw/dist/extensions/sglang/index.js [39m
[90m2026-05-20T02:05:37.389+00:00 [39m [35m[plugins] [39m [90mloading stepfun from /usr/local/lib/node_modules/openclaw/dist/extensions/stepfun/index.js [39m
[90m2026-05-20T02:05:37.461+00:00 [39m [35m[plugins] [39m [90mloading synthetic from /usr/local/lib/node_modules/openclaw/dist/extensions/synthetic/index.js [39m
[90m2026-05-20T02:05:37.516+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T02:05:37.533+00:00 [39m [35m[plugins] [39m [90mloading together from /usr/local/lib/node_modules/openclaw/dist/extensions/together/index.js [39m
[90m2026-05-20T02:05:37.629+00:00 [39m [35m[plugins] [39m [90mloading venice from /usr/local/lib/node_modules/openclaw/dist/extensions/venice/index.js [39m
[90m2026-05-20T02:05:37.731+00:00 [39m [35m[plugins] [39m [90mloading vercel-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js [39m
[90m2026-05-20T02:05:37.812+00:00 [39m [35m[plugins] [39m [90mloading vllm from /usr/local/lib/node_modules/openclaw/dist/extensions/vllm/index.js [39m
[90m2026-05-20T02:05:37.888+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T02:05:37.904+00:00 [39m [35m[plugins] [39m [90mloading vydra from /usr/local/lib/node_modules/openclaw/dist/extensions/vydra/index.js [39m
[90m2026-05-20T02:05:38.032+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-20T02:05:38.053+00:00 [39m [35m[plugins] [39m [90mloading xiaomi from /usr/local/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js [39m
[90m2026-05-20T02:05:38.153+00:00 [39m [35m[plugins] [39m [90mloading zai from /usr/local/lib/node_modules/openclaw/dist/extensions/zai/index.js [39m
[90m2026-05-20T02:05:38.223+00:00 [39m [35m[plugins] [39m [90mloaded 45 plugin(s) (45 attempted) in 5207.6ms [39m
[90m2026-05-20T02:05:38.289+00:00 [39m [35m[plugins] [39m [90m[hooks] running before_agent_reply (1 handlers, first-claim wins) [39m
[90m2026-05-20T02:05:43.596+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=beec7be0-be7a-4dd9-8b76-b203b5ad34af peer=127.0.0.1:55698->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-20T02:05:43.610+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=f63328b9-aadf-4c52-bc80-cb59f511edd6 peer=127.0.0.1:40960->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-20T02:05:43.625+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=189b552f-3dc7-42b9-beeb-ce74184943bb peer=127.0.0.1:38968->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-20T02:05:43.633+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:05:43.651+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T02:05:43.701+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=189b552f-3dc7-42b9-beeb-ce74184943bb peer=127.0.0.1:38968->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-05-20T02:05:43.713+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=36192 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:38968->127.0.0.1:18789 [39m
[90m2026-05-20T02:06:15.304+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-20T02:06:15.309+00:00 [39m [35m[plugins] [39m [90mloaded 1 plugin(s) (1 attempted) in 13.8ms [39m
2026-05-20T02:06:20.286+00:00 memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=200000 threshold=176000 isHeartbeat=true isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=98 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[90m2026-05-20T02:06:21.086+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=session:agent:main:main queueSize=1 [39m
[90m2026-05-20T02:06:21.089+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=session:agent:main:main waitMs=5 queueSize=0 [39m
[90m2026-05-20T02:06:21.095+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=main queueSize=1 [39m
[90m2026-05-20T02:06:21.097+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=main waitMs=3 queueSize=0 [39m
[90m2026-05-20T02:06:22.599+00:00 [39m [35m[plugins] [39m [90mloading alibaba from /usr/local/lib/node_modules/openclaw/dist/extensions/alibaba/index.js [39m
[90m2026-05-20T02:06:22.651+00:00 [39m [35m[plugins] [39m [90mloading anthropic from /usr/local/lib/node_modules/openclaw/dist/extensions/anthropic/index.js [39m
[90m2026-05-20T02:06:22.667+00:00 [39m [35m[plugins] [39m [90mloading arcee from /usr/local/lib/node_modules/openclaw/dist/extensions/arcee/index.js [39m
[90m2026-05-20T02:06:22.688+00:00 [39m [35m[plugins] [39m [90mloading azure-speech from /usr/local/lib/node_modules/openclaw/dist/extensions/azure-speech/index.js [39m
[90m2026-05-20T02:06:22.760+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-20T02:06:22.832+00:00 [39m [35m[plugins] [39m [90mloading byteplus from /usr/local/lib/node_modules/openclaw/dist/extensions/byteplus/index.js [39m
[90m2026-05-20T02:06:22.853+00:00 [39m [35m[plugins] [39m [90mloading canvas from /usr/local/lib/node_modules/openclaw/dist/extensions/canvas/index.js [39m
[90m2026-05-20T02:06:22.920+00:00 [39m [35m[plugins] [39m [90mloading cerebras from /usr/local/lib/node_modules/openclaw/dist/extensions/cerebras/index.js [39m
[90m2026-05-20T02:06:22.938+00:00 [39m [35m[plugins] [39m [90mloading chutes from /usr/local/lib/node_modules/openclaw/dist/extensions/chutes/index.js [39m
[90m2026-05-20T02:06:22.968+00:00 [39m [35m[plugins] [39m [90mloading cloudflare-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/cloudflare-ai-gateway/index.js [39m
[90m2026-05-20T02:06:22.984+00:00 [39m [35m[plugins] [39m [90mloading comfy from /usr/local/lib/node_modules/openclaw/dist/extensions/comfy/index.js [39m
[90m2026-05-20T02:06:22.997+00:00 [39m [35m[plugins] [39m [90mloading copilot-proxy from /usr/local/lib/node_modules/openclaw/dist/extensions/copilot-proxy/index.js [39m
[90m2026-05-20T02:06:23.010+00:00 [39m [35m[plugins] [39m [90mloading deepgram from /usr/local/lib/node_modules/openclaw/dist/extensions/deepgram/index.js [39m
[90m2026-05-20T02:06:23.099+00:00 [39m [35m[plugins] [39m [90mloading deepinfra from /usr/local/lib/node_modules/openclaw/dist/extensions/deepinfra/index.js [39m
[90m2026-05-20T02:06:23.121+00:00 [39m [35m[plugins] [39m [90mloading deepseek from /usr/local/lib/node_modules/openclaw/dist/extensions/deepseek/index.js [39m
[90m2026-05-20T02:06:23.146+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
2026-05-20T02:06:23.178+00:00 Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-20T02:06:23.200+00:00 [39m [35m[plugins] [39m [90mloading document-extract from /usr/local/lib/node_modules/openclaw/dist/extensions/document-extract/index.js [39m
[90m2026-05-20T02:06:23.242+00:00 [39m [35m[plugins] [39m [90mloading elevenlabs from /usr/local/lib/node_modules/openclaw/dist/extensions/elevenlabs/index.js [39m
[90m2026-05-20T02:06:23.378+00:00 [39m [35m[plugins] [39m [90mloading fal from /usr/local/lib/node_modules/openclaw/dist/extensions/fal/index.js [39m
[90m2026-05-20T02:06:23.398+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-20T02:06:23.452+00:00 [39m [35m[plugins] [39m [90mloading fireworks from /usr/local/lib/node_modules/openclaw/dist/extensions/fireworks/index.js [39m
[90m2026-05-20T02:06:23.468+00:00 [39m [35m[plugins] [39m [90mloading github-copilot from /usr/local/lib/node_modules/openclaw/dist/extensions/github-copilot/index.js [39m
[90m2026-05-20T02:06:23.484+00:00 [39m [35m[plugins] [39m [90mloading google from /usr/local/lib/node_modules/openclaw/dist/extensions/google/index.js [39m
[90m2026-05-20T02:06:23.506+00:00 [39m [35m[plugins] [39m [90mloading groq from /usr/local/lib/node_modules/openclaw/dist/extensions/groq/index.js [39m
[90m2026-05-20T02:06:23.519+00:00 [39m [35m[plugins] [39m [90mloading huggingface from /usr/local/lib/node_modules/openclaw/dist/extensions/huggingface/index.js [39m
[90m2026-05-20T02:06:23.545+00:00 [39m [35m[plugins] [39m [90mloading inworld from /usr/local/lib/node_modules/openclaw/dist/extensions/inworld/index.js [39m
[90m2026-05-20T02:06:23.612+00:00 [39m [35m[plugins] [39m [90mloading kilocode from /usr/local/lib/node_modules/openclaw/dist/extensions/kilocode/index.js [39m
[90m2026-05-20T02:06:23.625+00:00 [39m [35m[plugins] [39m [90mloading kimi from /usr/local/lib/node_modules/openclaw/dist/extensions/kimi-coding/index.js [39m
[90m2026-05-20T02:06:23.642+00:00 [39m [35m[plugins] [39m [90mloading litellm from /usr/local/lib/node_modules/openclaw/dist/extensions/litellm/index.js [39m
[90m2026-05-20T02:06:23.665+00:00 [39m [35m[plugins] [39m [90mloading lmstudio from /usr/local/lib/node_modules/openclaw/dist/extensions/lmstudio/index.js [39m
[90m2026-05-20T02:06:23.694+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
2026-05-20T02:06:23.702+00:00 Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-20T02:06:23.730+00:00 [39m [35m[plugins] [39m [90mloading microsoft from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft/index.js [39m
[90m2026-05-20T02:06:23.825+00:00 [39m [35m[plugins] [39m [90mloading microsoft-foundry from /usr/local/lib/node_modules/openclaw/dist/extensions/microsoft-foundry/index.js [39m
[90m2026-05-20T02:06:23.859+00:00 [39m [35m[plugins] [39m [90mloading minimax from /usr/local/lib/node_modules/openclaw/dist/extensions/minimax/index.js [39m
[90m2026-05-20T02:06:23.873+00:00 [39m [35m[plugins] [39m [90mloading mistral from /usr/local/lib/node_modules/openclaw/dist/extensions/mistral/index.js [39m
[90m2026-05-20T02:06:23.885+00:00 [39m [35m[plugins] [39m [90mloading moonshot from /usr/local/lib/node_modules/openclaw/dist/extensions/moonshot/index.js [39m
[90m2026-05-20T02:06:23.899+00:00 [39m [35m[plugins] [39m [90mloading nvidia from /usr/local/lib/node_modules/openclaw/dist/extensions/nvidia/index.js [39m
[90m2026-05-20T02:06:23.918+00:00 [39m [35m[plugins] [39m [90mloading ollama from /usr/local/lib/node_modules/openclaw/dist/extensions/ollama/index.js [39m
[90m2026-05-20T02:06:23.937+00:00 [39m [35m[plugins] [39m [90mloading openai from /usr/local/lib/node_modules/openclaw/dist/extensions/openai/index.js [39m
[90m2026-05-20T02:06:23.952+00:00 [39m [35m[plugins] [39m [90mloading opencode from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode/index.js [39m
[90m2026-05-20T02:06:23.966+00:00 [39m [35m[plugins] [39m [90mloading opencode-go from /usr/local/lib/node_modules/openclaw/dist/extensions/opencode-go/index.js [39m
[90m2026-05-20T02:06:23.980+00:00 [39m [35m[plugins] [39m [90mloading openrouter from /usr/local/lib/node_modules/openclaw/dist/extensions/openrouter/index.js [39m
[90m2026-05-20T02:06:24.007+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
2026-05-20T02:06:24.043+00:00 Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-20T02:06:24.063+00:00 [39m [35m[plugins] [39m [90mloading qianfan from /usr/local/lib/node_modules/openclaw/dist/extensions/qianfan/index.js [39m
[90m2026-05-20T02:06:24.077+00:00 [39m [35m[plugins] [39m [90mloading qwen from /usr/local/lib/node_modules/openclaw/dist/extensions/qwen/index.js [39m
[90m2026-05-20T02:06:24.091+00:00 [39m [35m[plugins] [39m [90mloading runway from /usr/local/lib/node_modules/openclaw/dist/extensions/runway/index.js [39m
[90m2026-05-20T02:06:24.150+00:00 [39m [35m[plugins] [39m [90mloading senseaudio from /usr/local/lib/node_modules/openclaw/dist/extensions/senseaudio/index.js [39m
[90m2026-05-20T02:06:24.194+00:00 [39m [35m[plugins] [39m [90mloading sglang from /usr/local/lib/node_modules/openclaw/dist/extensions/sglang/index.js [39m
[90m2026-05-20T02:06:24.243+00:00 [39m [35m[plugins] [39m [90mloading stepfun from /usr/local/lib/node_modules/openclaw/dist/extensions/stepfun/index.js [39m
[90m2026-05-20T02:06:24.260+00:00 [39m [35m[plugins] [39m [90mloading synthetic from /usr/local/lib/node_modules/openclaw/dist/extensions/synthetic/index.js [39m
[90m2026-05-20T02:06:24.276+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
2026-05-20T02:06:24.319+00:00 Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-20T02:06:24.362+00:00 [39m [35m[plugins] [39m [90mloading tencent from /usr/local/lib/node_modules/openclaw/dist/extensions/tencent/index.js [39m
[90m2026-05-20T02:06:24.384+00:00 [39m [35m[plugins] [39m [90mloading together from /usr/local/lib/node_modules/openclaw/dist/extensions/together/index.js [39m
[90m2026-05-20T02:06:24.408+00:00 [39m [35m[plugins] [39m [90mloading tts-local-cli from /usr/local/lib/node_modules/openclaw/dist/extensions/tts-local-cli/index.js [39m
[90m2026-05-20T02:06:24.479+00:00 [39m [35m[plugins] [39m [90mloading venice from /usr/local/lib/node_modules/openclaw/dist/extensions/venice/index.js [39m
[90m2026-05-20T02:06:24.493+00:00 [39m [35m[plugins] [39m [90mloading vercel-ai-gateway from /usr/local/lib/node_modules/openclaw/dist/extensions/vercel-ai-gateway/index.js [39m
[90m2026-05-20T02:06:24.509+00:00 [39m [35m[plugins] [39m [90mloading vllm from /usr/local/lib/node_modules/openclaw/dist/extensions/vllm/index.js [39m
[90m2026-05-20T02:06:24.525+00:00 [39m [35m[plugins] [39m [90mloading volcengine from /usr/local/lib/node_modules/openclaw/dist/extensions/volcengine/index.js [39m
[90m2026-05-20T02:06:24.540+00:00 [39m [35m[plugins] [39m [90mloading voyage from /usr/local/lib/node_modules/openclaw/dist/extensions/voyage/index.js [39m
[90m2026-05-20T02:06:24.581+00:00 [39m [35m[plugins] [39m [90mloading vydra from /usr/local/lib/node_modules/openclaw/dist/extensions/vydra/index.js [39m
[90m2026-05-20T02:06:24.594+00:00 [39m [35m[plugins] [39m [90mloading web-readability from /usr/local/lib/node_modules/openclaw/dist/extensions/web-readability/index.js [39m
[90m2026-05-20T02:06:24.639+00:00 [39m [35m[plugins] [39m [90mloading xai from /usr/local/lib/node_modules/openclaw/dist/extensions/xai/index.js [39m
[90m2026-05-20T02:06:24.654+00:00 [39m [35m[plugins] [39m [90mloading xiaomi from /usr/local/lib/node_modules/openclaw/dist/extensions/xiaomi/index.js [39m
[90m2026-05-20T02:06:24.669+00:00 [39m [35m[plugins] [39m [90mloading zai from /usr/local/lib/node_modules/openclaw/dist/extensions/zai/index.js [39m
[90m2026-05-20T02:06:24.673+00:00 [39m [35m[plugins] [39m [90mloaded 90 plugin(s) (64 attempted) in 2098.5ms [39m
[90m2026-05-20T02:06:33.428+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=12 healthVersion=36 [39m
[90m2026-05-20T02:06:33.433+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:06:33.444+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[90m2026-05-20T02:06:33.482+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=f63328b9-aadf-4c52-bc80-cb59f511edd6 peer=127.0.0.1:40960->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-20T02:06:33.492+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=86028 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:40960->127.0.0.1:18789 conn=f63328b9…edd6 [39m
[90m2026-05-20T02:06:33.514+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=beec7be0-be7a-4dd9-8b76-b203b5ad34af peer=127.0.0.1:55698->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-20T02:06:33.528+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=86121 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:55698->127.0.0.1:18789 conn=beec7be0…34af [39m
[90m2026-05-20T02:06:33.566+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=42666 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42666->127.0.0.1:18789 conn=dbc32a42…b5e4 [39m
[90m2026-05-20T02:06:46.137+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=main durationMs=25029 error="Error: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-20T02:06:46.146+00:00 [39m [31m[diagnostic] [39m [31mlane task error: lane=session:agent:main:main durationMs=25048 error="Error: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir." [39m
[90m2026-05-20T02:06:46.314+00:00 [39m [34m[model-fallback/decision] [39m [33mmodel fallback decision: decision=candidate_failed requested=ollama/qwen3-coder:480b-cloud candidate=ollama/qwen3-coder:480b-cloud reason=auth next=none detail=No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. [39m
2026-05-20T02:06:46.321+00:00 Embedded agent failed before reply: No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir. | No API key found for provider "ollama". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy only portable static auth profiles from the main agentDir.
[90m2026-05-20T02:06:46.357+00:00 [39m [36m[ws] [39m [36m→ event heartbeat seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-20T02:06:46.426+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=44840 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:44840->127.0.0.1:18789 conn=591c347b…80f8 [39m
[90m2026-05-20T02:06:47.281+00:00 [39m [36m[ws] [39m [36m→ event node.pair.requested seq=per-client clients=1 dropIfSlow=true [39m
[90m2026-05-20T02:06:47.294+00:00 [39m [36m[ws] [39m [36m← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.18 mode=node clientId=node-host platform=android auth=token [39m
[90m2026-05-20T02:06:47.318+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=172 events=27 presence=2 stateVersion=13 [39m
[90m2026-05-20T02:06:52.886+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=13 healthVersion=37 [39m
[90m2026-05-20T02:06:52.901+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=dbc32a42-dee7-4d9d-8c2e-df175f5ab5e4 peer=127.0.0.1:42666->127.0.0.1:18789 remote=127.0.0.1 [39m
[90m2026-05-20T02:07:03.449+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=34.4 eventLoopDelayMaxMs=12843 eventLoopUtilization=0.695 cpuCoreRatio=0.348 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T02:07:03.467+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:07:03.539+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:07:23.021+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=dbc32a42-dee7-4d9d-8c2e-df175f5ab5e4 peer=127.0.0.1:42666->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=http://127.0.0.1:18789 host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1006 reason=n/a [39m
[90m2026-05-20T02:07:23.050+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=49356 cause=handshake-timeout handshake=failed endpoint=127.0.0.1:42666->127.0.0.1:18789 conn=dbc32a42…b5e4 [39m
[90m2026-05-20T02:07:36.156+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=13 healthVersion=38 [39m
[90m2026-05-20T02:07:36.163+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:07:36.173+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:08:06.184+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:08:06.287+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:08:37.293+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=13 healthVersion=39 [39m
[90m2026-05-20T02:08:37.301+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:08:37.313+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:09:07.379+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:09:37.443+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=13 healthVersion=40 [39m
[90m2026-05-20T02:09:37.451+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=35.3 eventLoopDelayMaxMs=10141.8 eventLoopUtilization=0.452 cpuCoreRatio=0.26 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T02:09:37.454+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:09:37.465+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:10:15.132+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:10:15.146+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:10:34.385+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=13 healthVersion=41 [39m
[90m2026-05-20T02:10:45.153+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:10:45.231+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:11:15.151+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:11:15.252+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
[90m2026-05-20T02:11:35.419+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=2 presenceVersion=13 healthVersion=42 [39m
[90m2026-05-20T02:11:45.145+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=37.9 eventLoopDelayMaxMs=8128.6 eventLoopUtilization=0.371 cpuCoreRatio=0.148 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:10ms,sidecars.restart-sentinel:391ms,post-attach.update-sentinel:317ms,sidecars.session-locks:408ms,sidecars.model-prewarm:11184ms,post-ready.maintenance:2242ms [39m
[90m2026-05-20T02:11:45.154+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-20T02:11:45.222+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=2 [39m
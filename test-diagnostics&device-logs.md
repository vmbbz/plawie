  🦞 LOBSTER-fa07...2f45
  =====================

[NODE] Device ID: fa078b44323b...
[NODE] Connecting to 127.0.0.1:18789...
[NODE] WebSocket connected, awaiting challenge...
[NODE] Challenge received
[NODE] Gateway token read from openclaw.json
[NODE] Declaring 15 commands: [camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame caps=[camera, canvas, location, screen, flash, haptic, sensor] commands=[camera.snap, camera.clip, camera.list, canvas.navigate, canvas.eval, canvas.snapshot, location.get, screen.record, flash.on, flash.off, flash.toggle, flash.status, haptic.vibrate, sensor.read, sensor.list]
[NODE] Connect frame platform=android
[NODE] Connect response ok=true payload={type: hello-ok, protocol: 3, server: {version: 2026.5.4, connId: 19686d6d-690a-47b0-96f3-1d3f4a0e3f79}, features: {methods: [health, diagnostics.stability, doctor.memory.status, doctor.memory.dreamDiary, doctor.memory.backfillDreamDiary, doctor.memory.resetDreamDiary, doctor.memory.resetGroundedShortTerm, doctor.memory.repairDreamingArtifacts, doctor.memory.dedupeDreamDiary, doctor.memory.remHarness, logs.tail, channels.status, channels.start, channels.stop, channels.logout, status, usage.status, usage.cost, tts.status, tts.providers, tts.personas, tts.enable, tts.disable, tts.convert, tts.setProvider, tts.setPersona, config.get, config.set, config.apply, config.patch, config.schema, config.schema.lookup, exec.approvals.get, exec.approvals.set, exec.approvals.node.get, exec.approvals.node.set, exec.approval.get, exec.approval.list, exec.approval.request, exec.approval.waitDecision, exec.approval.resolve, plugin.approval.list, plugin.approval.request, plugin.approval.waitDecision, plugin.approval.resolve, plugins.uiDescriptors, wizard.start, wizard.next, wizard.cancel, wizard.status, talk.config, talk.realtime.session, talk.realtime.relayAudio, talk.realtime.relayMark, talk.realtime.relayStop, talk.realtime.relayToolResult, talk.speak, talk.mode, commands.list, models.list, models.authStatus, tools.catalog, tools.effective, tools.invoke, agents.list, agents.create, agents.update, agents.delete, agents.files.list, agents.files.get, agents.files.set, artifacts.list, artifacts.get, artifacts.download, skills.status, skills.search, skills.detail, skills.bins, skills.install, skills.update, update.status, update.run, voicewake.get, voicewake.set, secrets.reload, secrets.resolve, voicewake.routing.get, voicewake.routing.set, sessions.list, sessions.subscribe, sessions.unsubscribe, sessions.messages.subscribe, sessions.messages.unsubscribe, sessions.preview, sessions.describe, sessions.compaction.list, sessions.compaction.get, sessions.compaction.branch, sessions.compaction.restore, sessions.create, sessions.send, sessions.abort, sessions.patch, sessions.pluginPatch, sessions.cleanup, sessions.reset, sessions.delete, sessions.compact, last-heartbeat, set-heartbeats, wake, node.pair.request, node.pair.list, node.pair.approve, node.pair.reject, node.pair.remove, node.pair.verify, device.pair.list, device.pair.approve, device.pair.reject, device.pair.remove, device.token.rotate, device.token.revoke, node.rename, node.list, node.describe, node.pending.drain, node.pending.enqueue, node.invoke, node.pending.pull, node.pending.ack, node.invoke.result, node.event, node.canvas.capability.refresh, cron.list, cron.status, cron.add, cron.update, cron.remove, cron.run, cron.runs, gateway.identity.get, gateway.restart.preflight, gateway.restart.request, system-presence, system-event, message.action, send, agent, agent.identity.get, agent.wait, chat.history, chat.abort, chat.send, browser.request], events: [connect.challenge, agent, chat, session.message, session.tool, sessions.changed, presence, tick, talk.mode, shutdown, health, heartbeat, cron, node.pair.requested, node.pair.resolved, node.invoke.request, device.pair.requested, device.pair.resolved, voicewake.changed, voicewake.routing.changed, exec.approval.requested, exec.approval.resolved, plugin.approval.requested, plugin.approval.resolved, update.available]}, snapshot: {presence: [{host: localhost, ip: 192.168.1.100, version: 2026.5.4, platform: linux 6.17.0-PRoot-Distro, deviceFamily: Linux, modelIdentifier: arm64, mode: gateway, reason: self, text: Gateway: localhost (192.168.1.100) · app 2026.5.4 · mode gateway · reason self, ts: 1778535898451}, {host: OpenClaw Mobile, version: 2026.5.4, platform: android, deviceFamily: Android, mode: node, deviceId: fa078b44323ba365dc6e9a86a639a9dfb711a0eee4c29621785946b754622f45, roles: [node], scopes: [node.device], instanceId: fa078b44323ba365dc6e9a86a639a9dfb711a0eee4c29621785946b754622f45, reason: connect, ts: 1778535898445, text: Node: OpenClaw Mobile · mode node}], health: {ok: true, ts: 1778535857673, durationMs: 3637, eventLoop: {degraded: false, reasons: [], intervalMs: 54240, delayP99Ms: 24.3, delayMaxMs: 46.5, utilization: 0.178, cpuCoreRatio: 0.115}, plugins: {loaded: [browser, device-pair, file-transfer, memory-core, phone-control, talk-voice], errors: []}, channels: {}, channelOrder: [], channelLabels: {}, heartbeatSeconds: 1800, defaultAgentId: main, agents: [{agentId: main, isDefault: true, heartbeat: {enabled: true, every: 30m, everyMs: 1800000, prompt: Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK., target: none, ackMaxChars: 300}, sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1778533019152, age: 2834884}]}}], sessions: {path: /root/.openclaw/agents/main/sessions/sessions.json, count: 1, recent: [{key: agent:main:main, updatedAt: 1778533019152, age: 2834884}]}}, stateVersion: {presence: 2, health: 10}, uptimeMs: 583571, sessionDefaults: {defaultAgentId: main, mainKey: main, mainSessionKey: agent:main:main, scope: per-sender}}, canvasHostUrl: http://127.0.0.1:18789/__openclaw__/cap/TN2ioDKo70SuCO3CCEdFiMLf, auth: {role: node, scopes: [node.device], deviceToken: AC4pb1wyRldo1feOfvHQOeo20vXSuJjrlIvIdbfzL2k, issuedAtMs: 1778535898331}, policy: {maxPayload: 26214400, maxBufferedBytes: 52428800, tickIntervalMs: 30000}}
[NODE] Paired and connected









==========================================


GATEWAY LOGS IN FULL

Cosy <cosychiruka@gmail.com>
	
11:47 PM (2 minutes ago)
	
	
to me
[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[90m2026-05-11T21:35:21.671+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-11T21:35:22.639+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[90m2026-05-11T21:35:22.706+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
[INFO] Gateway auth token acquired from config.
[90m2026-05-11T21:35:38.671+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-11T21:35:39.677+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-11T21:35:39.882+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-11T21:35:41.678+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-11T21:35:41.766+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-11T21:35:42.054+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-11T21:35:42.126+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-11T21:35:46.988+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-11T21:35:47.028+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-11T21:35:47.072+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 5408.0ms [39m
[90m2026-05-11T21:35:47.201+00:00 [39m [36m[gateway] [39m [36magent model: ollama/qwen2.5:0.5b (thinking=medium, fast=off) [39m
[90m2026-05-11T21:35:47.209+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 24.5s) [39m
[90m2026-05-11T21:35:47.219+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-11.log [39m
[90m2026-05-11T21:35:48.007+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-11T21:36:04.109+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-11T21:36:04.116+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=30s eventLoopDelayP99Ms=7121.9 eventLoopDelayMaxMs=14235.5 eventLoopUtilization=0.996 cpuCoreRatio=0.489 active=0 waiting=0 queued=0 phase=sidecars.plugin-services recentPhases=sidecars.gmail-model:0ms,sidecars.internal-hooks:0ms,sidecars.channel-start:1ms,sidecars.channels:7ms,post-attach.update-check:71ms,sidecars.model-prewarm:16099ms [39m
[90m2026-05-11T21:36:04.118+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:36:07.712+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-11T21:36:07.782+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-11T21:36:07.804+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-11T21:36:08.021+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-11T21:36:34.135+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:37:04.129+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:37:34.127+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:38:04.118+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:38:34.127+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.9 eventLoopDelayMaxMs=8640.3 eventLoopUtilization=0.321 cpuCoreRatio=0.166 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:185ms,sidecars.subagent-recovery:217ms,sidecars.session-locks:247ms,post-ready.maintenance:3085ms [39m
[90m2026-05-11T21:38:34.143+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:39:04.132+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:39:34.125+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:40:04.139+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:40:34.131+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.8 eventLoopDelayMaxMs=6861.9 eventLoopUtilization=0.279 cpuCoreRatio=0.15 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:185ms,sidecars.subagent-recovery:217ms,sidecars.session-locks:247ms,post-ready.maintenance:3085ms [39m
[90m2026-05-11T21:40:34.140+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:41:04.142+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:41:34.132+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:42:04.136+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:42:34.138+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.6 eventLoopDelayMaxMs=10997.5 eventLoopUtilization=0.408 cpuCoreRatio=0.205 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:185ms,sidecars.subagent-recovery:217ms,sidecars.session-locks:247ms,post-ready.maintenance:3085ms [39m
[90m2026-05-11T21:42:34.153+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:43:04.137+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:43:34.140+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:44:04.134+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:44:34.138+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=27.5 eventLoopDelayMaxMs=7071.6 eventLoopUtilization=0.276 cpuCoreRatio=0.128 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.main-session-recovery:185ms,sidecars.subagent-recovery:217ms,sidecars.session-locks:247ms,post-ready.maintenance:3085ms [39m
[90m2026-05-11T21:44:34.156+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-11T21:44:57.689+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56592 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56592->127.0.0.1:18789 conn=b10e5ca1…a18e [39m
[90m2026-05-11T21:44:57.723+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56600 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56600->127.0.0.1:18789 conn=19686d6d…3f79 [39m
[90m2026-05-11T21:44:58.277+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=b10e5ca1-f759-4926-81a1-26fa1279a18e peer=127.0.0.1:56592->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-11T21:44:58.288+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=590 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3a03fc18-2d72-4092-9a68-13f1292c02c0 endpoint=127.0.0.1:56592->127.0.0.1:18789 conn=b10e5ca1…a18e [39m
[90m2026-05-11T21:44:58.371+00:00 [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=fa078b44323ba365dc6e9a86a639a9dfb711a0eee4c29621785946b754622f45 role=node [39m
[90m2026-05-11T21:44:58.444+00:00 [39m [36m[ws] [39m [36m← connect client=node-host clientDisplayName=OpenClaw Mobile version=2026.5.4 mode=node clientId=node-host platform=android auth=token conn=19686d6d…3f79 [39m
[90m2026-05-11T21:44:58.461+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=155 events=25 presence=2 stateVersion=2 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:04.777+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=11 [39m
[90m2026-05-11T21:45:04.782+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-11T21:45:04.795+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56616 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56616->127.0.0.1:18789 conn=532f4710…19eb [39m
[90m2026-05-11T21:45:04.818+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43032 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43032->127.0.0.1:18789 conn=9a04cdc8…6724 [39m
[90m2026-05-11T21:45:04.832+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=532f4710-91b9-4ebd-b02f-cafd1c9319eb peer=127.0.0.1:56616->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-11T21:45:04.839+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=32 handshake=pending endpoint=127.0.0.1:56616->127.0.0.1:18789 conn=532f4710…19eb [39m
[90m2026-05-11T21:45:04.861+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9a04cdc8-c72b-4861-b3bd-d4e4928f6724 peer=127.0.0.1:43032->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) [39m
[90m2026-05-11T21:45:04.869+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) durationMs=33 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=d250723e-35f3-4bd4-810b-849a9602fb74 endpoint=127.0.0.1:43032->127.0.0.1:18789 conn=9a04cdc8…6724 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:05.911+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43038 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43038->127.0.0.1:18789 conn=71d3105b…bc13 [39m
[90m2026-05-11T21:45:06.003+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=71d3105b-c40f-4907-ac1d-c5858f61bc13 peer=127.0.0.1:43038->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) [39m
[90m2026-05-11T21:45:06.014+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) durationMs=65 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c8a6a895-223c-48a8-a0d9-e82f3bc6fa12 endpoint=127.0.0.1:43038->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:07.707+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43044 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43044->127.0.0.1:18789 conn=bc6fc379…8462 [39m
[90m2026-05-11T21:45:07.775+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=bc6fc379-cf6c-486e-9f46-56d9d5af8462 peer=127.0.0.1:43044->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) [39m
[90m2026-05-11T21:45:07.785+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) durationMs=53 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=310a145b-b63e-421e-b47f-205e01d57e2b endpoint=127.0.0.1:43044->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:16.667+00:00 [39m [36m[ws] [39m [36m→ event health seq=per-client clients=1 presenceVersion=2 healthVersion=12 [39m
[90m2026-05-11T21:45:16.680+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43058 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43058->127.0.0.1:18789 conn=967cc964…8ea5 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:20.701+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=967cc964-a3a0-485b-8bb7-07d8f5bc8ea5 peer=127.0.0.1:43058->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-11T21:45:20.719+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=3972 handshake=pending endpoint=127.0.0.1:43058->127.0.0.1:18789 [39m
[90m2026-05-11T21:45:20.733+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=53660 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:53660->127.0.0.1:18789 conn=3d843505…cf14 [39m
[90m2026-05-11T21:45:20.778+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=3d843505-fd55-40c3-85fc-421e1373cf14 peer=127.0.0.1:53660->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) [39m
[90m2026-05-11T21:45:20.789+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) durationMs=22 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=642947f8-335a-4db1-9f70-bcbfa4281415 endpoint=127.0.0.1:53660->127.0.0.1:18789 [39m
[90m2026-05-11T21:45:25.504+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:27.641+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=49244 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:49244->127.0.0.1:18789 conn=69d40a91…2b61 [39m
[90m2026-05-11T21:45:27.690+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=69d40a91-f989-484c-b8c4-6777d8e82b61 peer=127.0.0.1:49244->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-11T21:45:27.701+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=46 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=24df9ce3-5195-478a-a88d-0ff9dfcce3bd endpoint=127.0.0.1:49244->127.0.0.1:18789 [39m
[90m2026-05-11T21:45:34.792+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:35.701+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43902 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43902->127.0.0.1:18789 conn=9c4e7d27…10b5 [39m
[90m2026-05-11T21:45:35.762+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9c4e7d27-7637-4bf4-9312-feff4f5010b5 peer=127.0.0.1:43902->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-11T21:45:35.773+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=50 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=c38e1b3e-3246-4dd3-9f2d-077570c01b8d endpoint=127.0.0.1:43902->127.0.0.1:18789 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:43.049+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=43924 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:43924->127.0.0.1:18789 conn=831c6a07…9666 [39m
[90m2026-05-11T21:45:43.086+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=831c6a07-2da8-40ab-9d89-849c2cf59666 peer=127.0.0.1:43924->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1005 reason=n/a [39m
[90m2026-05-11T21:45:43.095+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=20 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=eea8b8dc-55fd-40df-bbb9-e61a9b80cbdc endpoint=127.0.0.1:43924->127.0.0.1:18789 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:51.113+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=50804 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:50804->127.0.0.1:18789 conn=e0637e48…ecab [39m
[90m2026-05-11T21:45:51.214+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e0637e48-e2e2-4468-98ec-fb013e07ecab peer=127.0.0.1:50804->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) [39m
[90m2026-05-11T21:45:51.225+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) durationMs=51 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=3247b75a-a645-40dc-ba15-6978784667e3 endpoint=127.0.0.1:50804->127.0.0.1:18789 [39m
[90m2026-05-11T21:45:55.497+00:00 [39m [36m[ws] [39m [36m→ event tick seq=per-client clients=1 [39m
[INFO] Connecting WebSocket...
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket connect failed — will retry on next health tick
[WARN] WebSocket disconnected
[90m2026-05-11T21:45:57.624+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=56898 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:56898->127.0.0.1:18789 conn=15e03177…4322 [39m
[90m2026-05-11T21:45:57.663+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=15e03177-4afd-466e-a2b4-aea1e0da4322 peer=127.0.0.1:56898->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) [39m
[90m2026-05-11T21:45:57.674+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=origin not allowed (open the Control UI from the gateway host or allow it in gateway.controlUi.allowedOrigins) durationMs=43 cause=origin-mismatch handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=0230f2ae-aa54-47fd-8bbb-7359623f81f4 endpoint=127.0.0.1:56898->127.0.0.1:18789 [39m
[90m2026-05-11T21:46:04.793+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected
[WARN] WebSocket disconnected

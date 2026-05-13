INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[90m2026-05-13T15:38:09.981+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-13T15:38:10.797+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[INFO] Gateway auth token acquired from config.
[90m2026-05-13T15:38:10.848+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
Config overwrite: /root/.openclaw/openclaw.json (sha256 f3e1a8cd0f15d79203e025592ca2f79f4a344d64dbfa78331e9322bc5373673f -> 678d0e405b6927a7cead33e030a1938e56b81721088ce8cccdad26ede3e2b2a6, backup=/root/.openclaw/openclaw.json.bak)
[90m2026-05-13T15:38:25.291+00:00 [39m [36m[gateway] [39m [36mauth token was missing. Generated a new token and saved it to config (gateway.auth.token). [39m
[90m2026-05-13T15:38:29.482+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-13T15:38:30.403+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-13T15:38:30.548+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-13T15:38:31.279+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-13T15:38:31.351+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-13T15:38:31.617+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-13T15:38:31.678+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-13T15:38:35.915+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-13T15:38:35.947+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-13T15:38:35.976+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 4708.3ms [39m
[90m2026-05-13T15:38:36.088+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-13T15:38:36.096+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 25.2s) [39m
[90m2026-05-13T15:38:36.103+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-13.log [39m
[90m2026-05-13T15:38:36.781+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-13T15:38:44.728+00:00 [39m [36m[fetch-timeout] [39m [33mfetch timeout after 2500ms (elapsed 7604ms) timer delayed 5104ms, likely event-loop starvation operation=fetchWithTimeout url=https://registry.npmjs.org/openclaw/latest [39m
[90m2026-05-13T15:38:44.742+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-13T15:38:48.124+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-13T15:38:48.190+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-13T15:38:48.206+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-13T15:38:48.374+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-13T15:38:58.081+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=33s eventLoopDelayP99Ms=5385.5 eventLoopDelayMaxMs=6232.7 eventLoopUtilization=0.998 cpuCoreRatio=0.524 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:162ms,sidecars.main-session-recovery:179ms,sidecars.session-locks:195ms,post-ready.maintenance:2663ms [39m
[90m2026-05-13T15:38:58.083+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-13T15:39:28.092+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-13T15:39:33.753+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51618 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51618->127.0.0.1:18789 conn=c239e62d…e50f [39m
[90m2026-05-13T15:39:33.870+00:00 [39m [36m[ws] [39m [33munauthorized conn=c239e62d-2b9b-4478-a3e2-66e011cee50f peer=127.0.0.1:51618->127.0.0.1:18789 remote=127.0.0.1 client=gateway:status backend v2026.5.4 role=operator scopes=0 auth=token device=no platform=linux instance=78ef9738-4298-44be-aff4-d4cc93a44461 host=127.0.0.1:18789 origin=n/a ua=n/a reason=token_mismatch [39m
[90m2026-05-13T15:39:34.066+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c239e62d-2b9b-4478-a3e2-66e011cee50f peer=127.0.0.1:51618->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-13T15:39:34.080+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=156 cause=unauthorized handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=35e0c9d3-2fa4-4348-8248-19b2d8db479a endpoint=127.0.0.1:51618->127.0.0.1:18789 [39m
[90m2026-05-13T15:39:58.093+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-13T15:40:16.939+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (meta.lastTouchedAt, wizard.lastRunAt, gateway.auth.token) [39m
[90m2026-05-13T15:40:16.955+00:00 [39m [34m[reload] [39m [33mconfig change requires gateway restart (gateway.auth.token) [39m
[90m2026-05-13T15:40:16.962+00:00 [39m [36m[gateway] [39m [36msignal SIGUSR1 received [39m
[90m2026-05-13T15:40:17.023+00:00 [39m [36m[gateway] [39m [36mreceived SIGUSR1; restarting [39m
[90m2026-05-13T15:40:17.028+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_stop (1 handlers) [39m
[90m2026-05-13T15:40:17.165+00:00 [39m [33m[shutdown] [39m [36mstarted: gateway restarting [39m
[90m2026-05-13T15:40:18.058+00:00 [39m [34m[gmail-watcher] [39m [36mgmail watcher stopped [39m
[90m2026-05-13T15:40:18.094+00:00 [39m [33m[shutdown] [39m [36mcompleted cleanly in 907ms [39m
[90m2026-05-13T15:40:18.124+00:00 [39m [36m[gateway] [39m [36mrestart mode: full process restart (spawned pid 21824) [39m
[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
[90m2026-05-13T15:38:09.981+00:00 [39m [36m[gateway] [39m [36mloading configuration… [39m
[90m2026-05-13T15:38:10.797+00:00 [39m [36m[gateway] [39m [36mresolving authentication… [39m
[INFO] Gateway auth token acquired from config.
[90m2026-05-13T15:38:10.848+00:00 [39m [36m[gateway] [39m [36mstarting... [39m
Config overwrite: /root/.openclaw/openclaw.json (sha256 f3e1a8cd0f15d79203e025592ca2f79f4a344d64dbfa78331e9322bc5373673f -> 678d0e405b6927a7cead33e030a1938e56b81721088ce8cccdad26ede3e2b2a6, backup=/root/.openclaw/openclaw.json.bak)
[90m2026-05-13T15:38:25.291+00:00 [39m [36m[gateway] [39m [36mauth token was missing. Generated a new token and saved it to config (gateway.auth.token). [39m
[90m2026-05-13T15:38:29.482+00:00 [39m [36m[gateway] [39m [36mstarting HTTP server... [39m
[90m2026-05-13T15:38:30.403+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-05-13T15:38:30.548+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
[90m2026-05-13T15:38:31.279+00:00 [39m [35m[plugins] [39m [90mloading browser from /usr/local/lib/node_modules/openclaw/dist/extensions/browser/index.js [39m
[90m2026-05-13T15:38:31.351+00:00 [39m [35m[plugins] [39m [90mloading device-pair from /usr/local/lib/node_modules/openclaw/dist/extensions/device-pair/index.js [39m
Registered plugin command: /pair (plugin: device-pair)
[90m2026-05-13T15:38:31.617+00:00 [39m [35m[plugins] [39m [90mloading file-transfer from /usr/local/lib/node_modules/openclaw/dist/extensions/file-transfer/index.js [39m
[90m2026-05-13T15:38:31.678+00:00 [39m [35m[plugins] [39m [90mloading memory-core from /usr/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js [39m
Registered plugin command: /dreaming (plugin: memory-core)
[90m2026-05-13T15:38:35.915+00:00 [39m [35m[plugins] [39m [90mloading phone-control from /usr/local/lib/node_modules/openclaw/dist/extensions/phone-control/index.js [39m
Registered plugin command: /phone (plugin: phone-control)
[90m2026-05-13T15:38:35.947+00:00 [39m [35m[plugins] [39m [90mloading talk-voice from /usr/local/lib/node_modules/openclaw/dist/extensions/talk-voice/index.js [39m
Registered plugin command: /voice (plugin: talk-voice)
[90m2026-05-13T15:38:35.976+00:00 [39m [35m[plugins] [39m [90mloaded 6 plugin(s) (6 attempted) in 4708.3ms [39m
[90m2026-05-13T15:38:36.088+00:00 [39m [36m[gateway] [39m [36magent model: google/gemini-3.1-pro-preview (thinking=medium, fast=off) [39m
[90m2026-05-13T15:38:36.096+00:00 [39m [36m[gateway] [39m [36mhttp server listening (6 plugins: browser, device-pair, file-transfer, memory-core, phone-control, talk-voice; 25.2s) [39m
[90m2026-05-13T15:38:36.103+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-05-13.log [39m
[90m2026-05-13T15:38:36.781+00:00 [39m [36m[gateway] [39m [36mstarting channels and sidecars... [39m
[90m2026-05-13T15:38:44.728+00:00 [39m [36m[fetch-timeout] [39m [33mfetch timeout after 2500ms (elapsed 7604ms) timer delayed 5104ms, likely event-loop starvation operation=fetchWithTimeout url=https://registry.npmjs.org/openclaw/latest [39m
[90m2026-05-13T15:38:44.742+00:00 [39m [36m[gateway] [39m [33mstartup model warmup timed out after 5000ms; continuing without waiting [39m
[90m2026-05-13T15:38:48.124+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-05-13T15:38:48.190+00:00 [39m [36m[gateway] [39m [36mready [39m
[90m2026-05-13T15:38:48.206+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-05-13T15:38:48.374+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_start (1 handlers) [39m
[90m2026-05-13T15:38:58.081+00:00 [39m [31m[diagnostic] [39m [90mliveness warning: reasons=event_loop_delay,event_loop_utilization interval=33s eventLoopDelayP99Ms=5385.5 eventLoopDelayMaxMs=6232.7 eventLoopUtilization=0.998 cpuCoreRatio=0.524 active=0 waiting=0 queued=0 recentPhases=sidecars.restart-sentinel:1ms,post-attach.update-sentinel:1ms,sidecars.subagent-recovery:162ms,sidecars.main-session-recovery:179ms,sidecars.session-locks:195ms,post-ready.maintenance:2663ms [39m
[90m2026-05-13T15:38:58.083+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-13T15:39:28.092+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-13T15:39:33.753+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 remotePort=51618 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:51618->127.0.0.1:18789 conn=c239e62d…e50f [39m
[90m2026-05-13T15:39:33.870+00:00 [39m [36m[ws] [39m [33munauthorized conn=c239e62d-2b9b-4478-a3e2-66e011cee50f peer=127.0.0.1:51618->127.0.0.1:18789 remote=127.0.0.1 client=gateway:status backend v2026.5.4 role=operator scopes=0 auth=token device=no platform=linux instance=78ef9738-4298-44be-aff4-d4cc93a44461 host=127.0.0.1:18789 origin=n/a ua=n/a reason=token_mismatch [39m
[90m2026-05-13T15:39:34.066+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=c239e62d-2b9b-4478-a3e2-66e011cee50f peer=127.0.0.1:51618->127.0.0.1:18789 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=n/a code=1008 reason=connect failed [39m
[90m2026-05-13T15:39:34.080+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=connect failed durationMs=156 cause=unauthorized handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=35e0c9d3-2fa4-4348-8248-19b2d8db479a endpoint=127.0.0.1:51618->127.0.0.1:18789 [39m
[90m2026-05-13T15:39:58.093+00:00 [39m [31m[diagnostic] [39m [90mheartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0 [39m
[90m2026-05-13T15:40:16.939+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (meta.lastTouchedAt, wizard.lastRunAt, gateway.auth.token) [39m
[90m2026-05-13T15:40:16.955+00:00 [39m [34m[reload] [39m [33mconfig change requires gateway restart (gateway.auth.token) [39m
[90m2026-05-13T15:40:16.962+00:00 [39m [36m[gateway] [39m [36msignal SIGUSR1 received [39m
[90m2026-05-13T15:40:17.023+00:00 [39m [36m[gateway] [39m [36mreceived SIGUSR1; restarting [39m
[90m2026-05-13T15:40:17.028+00:00 [39m [35m[plugins] [39m [90m[hooks] running gateway_stop (1 handlers) [39m
[90m2026-05-13T15:40:17.165+00:00 [39m [33m[shutdown] [39m [36mstarted: gateway restarting [39m
[90m2026-05-13T15:40:18.058+00:00 [39m [34m[gmail-watcher] [39m [36mgmail watcher stopped [39m
[90m2026-05-13T15:40:18.094+00:00 [39m [33m[shutdown] [39m [36mcompleted cleanly in 907ms [39m
[90m2026-05-13T15:40:18.124+00:00 [39m [36m[gateway] [39m [36mrestart mode: full process restart (spawned pid 21824) [39m
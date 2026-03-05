Chat page > Chat "hello"
Assistant does not reply its blank....

[00:17:41.988020] LOG: [JS] Bridge Probe Successful
[00:17:42.167327] ERROR: Script error. @ :0:0
[00:18:43.589168] Sending message: hey
[00:18:44.186567] Generation completed. Total length: 0

Web Dashboard > Chat "hello again"
Returns error message::
⚠️ Agent failed before reply: No API key found for provider "anthropic". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir.
Logs: openclaw logs --follow

Yet we fixed the auth token issue for the gateway, Web Dashboard page, Node page. All those are no longer throwing auth token error except when I send hello message.... then it shows that in logs....

Full logs below. I also noticed some concerning things in logs. Auth token gets done twice and the 2nd time it fails handshake as result then eventually success. Is that normal? Checkbthe responsible code.

But main focus is analyzing all with full context of what I said above from start so we fix all issue....

[INFO] Starting gateway...
[INFO] Gateway process detected, reconnecting...
[DEBUG] Probing gateway config for auth token...
[WARN] CLI dashboard probe failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): SystemError [ERR_SYSTEM_ERROR]: A system error occurred: uv_interface_addresses returned Unknown system error 13 (Unknown system error 13)
, null, null)
2026-03-04T22:13:14.038+00:00 Config overwrite: /root/.openclaw/openclaw.json (sha256 4f9404d8b6f0322e4bb6cb75dae404cf9dc33488a1479b04022fb327be3c9cf2 -> a2552a1d42d06ccb1bd5d2699faf29b7a0042d0b32f75ef25fcee5ae374e8653, backup=/root/.openclaw/openclaw.json.bak)
2026-03-04T22:13:14.061+00:00 Config write anomaly: /root/.openclaw/openclaw.json (missing-meta-before-write)
[90m2026-03-04T22:13:14.078Z [39m [36m[gateway] [39m [36mauth token was missing. Generated a new token and saved it to config (gateway.auth.token). [39m
89, minimal=true)
[90m2026-03-04T22:17:32.806Z [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-03-04T22:17:32.816Z [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-03-04T22:17:32.826Z [39m [36m[gateway] [39m [36magent model: anthropic/claude-opus-4-6 [39m
[90m2026-03-04T22:17:32.835Z [39m [36m[gateway] [39m [36mlistening on ws://127.0.0.1:18789, ws://[::1]:18789 (PID 25262) [39m
[90m2026-03-04T22:17:32.844Z [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-03-04.log [39m
[90m2026-03-04T22:17:33.054Z [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[INFO] Gateway is healthy
[90m2026-03-04T22:18:43.973Z [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=9322944b…f89c [39m
[90m2026-03-04T22:18:44.180Z [39m [36m[ws] [39m [33minvalid handshake conn=9322944b-b5fc-4ee0-b5c1-5fc373b8f89c remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) [39m
[90m2026-03-04T22:18:44.202Z [39m [36m[ws] [39m [33mclosed before connect conn=9322944b-b5fc-4ee0-b5c1-5fc373b8f89c remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=invalid request frame [39m
[90m2026-03-04T22:18:44.216Z [39m [36m[ws] [39m [36m→ close code=1008 reason=invalid request frame durationMs=245 cause=invalid-handshake handshake=failed lastFrameMethod=chat.send lastFrameId=29c56b41-4476-4860-963a-af70a4b0d36b [39m
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[90m2026-03-04T22:19:34.560Z [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=46e42224…762e [39m
[90m2026-03-04T22:19:34.829Z [39m [36m[gateway] [39m [36mdevice pairing auto-approved device=e60017993112ee172a66f01dc5f2022f886f6127128f070387b587ecad586f38 role=operator [39m
[90m2026-03-04T22:19:34.860Z [39m [36m[ws] [39m [36m← connect client=openclaw-control-ui version=dev mode=webchat clientId=openclaw-control-ui platform=Linux aarch64 auth=token [39m
[90m2026-03-04T22:19:34.870Z [39m [36m[ws] [39m [36mwebchat connected conn=46e42224-010b-4127-a032-fc12f9f0762e remote=127.0.0.1 client=openclaw-control-ui webchat vdev [39m
[90m2026-03-04T22:19:34.887Z [39m [36m[ws] [39m [36m→ hello-ok methods=94 events=19 presence=2 stateVersion=2 [39m
[90m2026-03-04T22:19:34.902Z [39m [36m[ws] [39m [36m→ event health seq=1 clients=1 presenceVersion=2 healthVersion=5 [39m
[90m2026-03-04T22:19:34.925Z [39m [36m[ws] [39m [36m⇄ res ✓ agent.identity.get 5ms id=f09b5ec4…eb1a [39m
[90m2026-03-04T22:19:34.939Z [39m [36m[ws] [39m [36m⇄ res ✓ agents.list 4ms id=77467e11…0ab1 [39m
[90m2026-03-04T22:19:34.964Z [39m [36m[ws] [39m [36m⇄ res ✓ tools.catalog 10ms id=d961bf96…3624 [39m
[90m2026-03-04T22:19:35.002Z [39m [36m[ws] [39m [36m⇄ res ✓ sessions.list 6ms id=f592ee9a…22a6 [39m
[90m2026-03-04T22:19:35.036Z [39m [36m[ws] [39m [36m⇄ res ✓ chat.history 59ms id=56a4a8c4…0bd8 [39m
[90m2026-03-04T22:19:35.051Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 80ms id=71a2d60f…3c44 [39m
[90m2026-03-04T22:19:35.060Z [39m [36m[ws] [39m [36m⇄ res ✓ device.pair.list 86ms id=2bcd44ad…6503 [39m
[90m2026-03-04T22:19:39.033Z [39m [36m[ws] [39m [36m⇄ res ✓ system-presence 4ms id=e173dc7f…8ff4 [39m
[90m2026-03-04T22:19:39.563Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 14ms id=4f4611e2…0b04 [39m
[90m2026-03-04T22:19:44.565Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 18ms id=07dba6e1…3c89 [39m
[90m2026-03-04T22:19:48.617Z [39m [36m[ws] [39m [36m⇄ res ✓ sessions.list 14ms id=d4b55433…ce92 [39m
[90m2026-03-04T22:19:49.613Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 39ms id=854cc754…1e93 [39m
[90m2026-03-04T22:19:54.570Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 20ms id=6cdd66a9…44ac [39m
[90m2026-03-04T22:19:56.349Z [39m [36m[ws] [39m [36m⇄ res ✓ agents.list 7ms id=a38757df…1bf5 [39m
[90m2026-03-04T22:19:56.373Z [39m [36m[ws] [39m [36m⇄ res ✓ tools.catalog 4ms id=14d59338…45ea [39m
[90m2026-03-04T22:19:56.553Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets) [39m
[90m2026-03-04T22:19:56.555Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers) [39m
[90m2026-03-04T22:19:56.558Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*) [39m
[90m2026-03-04T22:19:56.562Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*) [39m
[90m2026-03-04T22:19:56.569Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.source) [39m
[90m2026-03-04T22:19:56.572Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.allowlist) [39m
[90m2026-03-04T22:19:56.576Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.allowlist[]) [39m
[90m2026-03-04T22:19:56.580Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*) [39m
[90m2026-03-04T22:19:56.582Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.source) [39m
[90m2026-03-04T22:19:56.584Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.path) [39m
[90m2026-03-04T22:19:56.586Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.mode) [39m
[90m2026-03-04T22:19:56.589Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.mode) [39m
[90m2026-03-04T22:19:56.592Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.mode) [39m
[90m2026-03-04T22:19:56.595Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.timeoutMs) [39m
[90m2026-03-04T22:19:56.597Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.maxBytes) [39m
[90m2026-03-04T22:19:56.599Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*) [39m
[90m2026-03-04T22:19:56.601Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.source) [39m
[90m2026-03-04T22:19:56.603Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.command) [39m
[90m2026-03-04T22:19:56.605Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.args) [39m
[90m2026-03-04T22:19:56.609Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.args[]) [39m
[90m2026-03-04T22:19:56.612Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.timeoutMs) [39m
[90m2026-03-04T22:19:56.615Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.noOutputTimeoutMs) [39m
[90m2026-03-04T22:19:56.617Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.maxOutputBytes) [39m
[90m2026-03-04T22:19:56.619Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.jsonOnly) [39m
[90m2026-03-04T22:19:56.622Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.env) [39m
[90m2026-03-04T22:19:56.626Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.env.*) [39m
[90m2026-03-04T22:19:56.629Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.passEnv) [39m
[90m2026-03-04T22:19:56.632Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.passEnv[]) [39m
[90m2026-03-04T22:19:56.634Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.trustedDirs) [39m
[90m2026-03-04T22:19:56.636Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.trustedDirs[]) [39m
[90m2026-03-04T22:19:56.639Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.allowInsecurePath) [39m
[90m2026-03-04T22:19:56.642Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.providers.*.allowSymlinkCommand) [39m
[90m2026-03-04T22:19:56.645Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.defaults) [39m
[90m2026-03-04T22:19:56.648Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.defaults.env) [39m
[90m2026-03-04T22:19:56.650Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.defaults.file) [39m
[90m2026-03-04T22:19:56.652Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.defaults.exec) [39m
[90m2026-03-04T22:19:56.655Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.resolution) [39m
[90m2026-03-04T22:19:56.658Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.resolution.maxProviderConcurrency) [39m
[90m2026-03-04T22:19:56.661Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.resolution.maxRefsPerProvider) [39m
[90m2026-03-04T22:19:56.664Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (secrets.resolution.maxBatchBytes) [39m
[90m2026-03-04T22:19:56.667Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.source) [39m
[90m2026-03-04T22:19:56.670Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.provider) [39m
[90m2026-03-04T22:19:56.672Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.id) [39m
[90m2026-03-04T22:19:56.676Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.source) [39m
[90m2026-03-04T22:19:56.678Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.provider) [39m
[90m2026-03-04T22:19:56.681Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.id) [39m
[90m2026-03-04T22:19:56.683Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.source) [39m
[90m2026-03-04T22:19:56.686Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.provider) [39m
[90m2026-03-04T22:19:56.688Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (models.providers.*.apiKey.id) [39m
[90m2026-03-04T22:19:56.702Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.source) [39m
[90m2026-03-04T22:19:56.704Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.provider) [39m
[90m2026-03-04T22:19:56.708Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.id) [39m
[90m2026-03-04T22:19:56.711Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.source) [39m
[90m2026-03-04T22:19:56.714Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.provider) [39m
[90m2026-03-04T22:19:56.717Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.id) [39m
[90m2026-03-04T22:19:56.719Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.source) [39m
[90m2026-03-04T22:19:56.721Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.provider) [39m
[90m2026-03-04T22:19:56.725Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.defaults.memorySearch.remote.apiKey.id) [39m
[90m2026-03-04T22:19:56.846Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.source) [39m
[90m2026-03-04T22:19:56.879Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.provider) [39m
[90m2026-03-04T22:19:56.911Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.id) [39m
[90m2026-03-04T22:19:56.978Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.source) [39m
[90m2026-03-04T22:19:57.041Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.provider) [39m
[90m2026-03-04T22:19:57.057Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.id) [39m
[90m2026-03-04T22:19:57.100Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.source) [39m
[90m2026-03-04T22:19:57.131Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.provider) [39m
[90m2026-03-04T22:19:57.153Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (agents.list[].memorySearch.remote.apiKey.id) [39m
[90m2026-03-04T22:20:04.340Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.source) [39m
[90m2026-03-04T22:20:04.367Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.provider) [39m
[90m2026-03-04T22:20:04.395Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.id) [39m
[90m2026-03-04T22:20:04.446Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.source) [39m
[90m2026-03-04T22:20:04.484Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.provider) [39m
[90m2026-03-04T22:20:04.509Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.id) [39m
[90m2026-03-04T22:20:04.555Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.source) [39m
[90m2026-03-04T22:20:04.588Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.provider) [39m
[90m2026-03-04T22:20:04.620Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.apiKey.id) [39m
[90m2026-03-04T22:20:04.873Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.source) [39m
[90m2026-03-04T22:20:04.901Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.provider) [39m
[90m2026-03-04T22:20:04.931Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.id) [39m
[90m2026-03-04T22:20:04.981Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.source) [39m
[90m2026-03-04T22:20:05.009Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.provider) [39m
[90m2026-03-04T22:20:05.037Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.id) [39m
[90m2026-03-04T22:20:05.108Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.source) [39m
[90m2026-03-04T22:20:05.138Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.provider) [39m
[90m2026-03-04T22:20:05.180Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.perplexity.apiKey.id) [39m
[90m2026-03-04T22:20:05.391Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.source) [39m
[90m2026-03-04T22:20:05.415Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.provider) [39m
[90m2026-03-04T22:20:05.438Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.id) [39m
[90m2026-03-04T22:20:05.488Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.source) [39m
[90m2026-03-04T22:20:05.517Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.provider) [39m
[90m2026-03-04T22:20:05.538Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.id) [39m
[90m2026-03-04T22:20:05.584Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.source) [39m
[90m2026-03-04T22:20:05.623Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.provider) [39m
[90m2026-03-04T22:20:05.659Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.grok.apiKey.id) [39m
[90m2026-03-04T22:20:05.850Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.source) [39m
[90m2026-03-04T22:20:06.042Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.provider) [39m
[90m2026-03-04T22:20:06.054Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.id) [39m
[90m2026-03-04T22:20:06.090Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.source) [39m
[90m2026-03-04T22:20:06.116Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.provider) [39m
[90m2026-03-04T22:20:06.135Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.id) [39m
[90m2026-03-04T22:20:06.173Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.source) [39m
[90m2026-03-04T22:20:06.194Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.provider) [39m
[90m2026-03-04T22:20:06.212Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.gemini.apiKey.id) [39m
[90m2026-03-04T22:20:06.355Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.source) [39m
[90m2026-03-04T22:20:06.375Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.provider) [39m
[90m2026-03-04T22:20:06.396Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.id) [39m
[90m2026-03-04T22:20:06.446Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.source) [39m
[90m2026-03-04T22:20:06.469Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.provider) [39m
[90m2026-03-04T22:20:06.491Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.id) [39m
[90m2026-03-04T22:20:06.543Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.source) [39m
[90m2026-03-04T22:20:06.574Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.provider) [39m
[90m2026-03-04T22:20:06.596Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (tools.web.search.kimi.apiKey.id) [39m
[90m2026-03-04T22:20:21.688Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:20:21.723Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:20:21.771Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:20:21.829Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:20:21.857Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:20:21.887Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:20:21.942Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:20:21.984Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:20:22.009Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:20:22.442Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:20:22.472Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:20:22.516Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:20:22.780Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:20:22.794Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:20:22.827Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:20:22.869Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:20:22.890Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:20:22.913Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (messages.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:20:41.331Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.source) [39m
[90m2026-03-04T22:20:41.354Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.provider) [39m
[90m2026-03-04T22:20:41.376Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.id) [39m
[90m2026-03-04T22:20:41.430Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.source) [39m
[90m2026-03-04T22:20:41.452Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.provider) [39m
[90m2026-03-04T22:20:41.481Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.id) [39m
[90m2026-03-04T22:20:41.524Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.source) [39m
[90m2026-03-04T22:20:41.545Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.provider) [39m
[90m2026-03-04T22:20:41.575Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.webhookSecret.id) [39m
[90m2026-03-04T22:20:46.611Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.source) [39m
[90m2026-03-04T22:20:46.636Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.provider) [39m
[90m2026-03-04T22:20:46.875Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.id) [39m
[90m2026-03-04T22:20:46.914Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.source) [39m
[90m2026-03-04T22:20:46.926Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.provider) [39m
[90m2026-03-04T22:20:46.950Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.id) [39m
[90m2026-03-04T22:20:46.985Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.source) [39m
[90m2026-03-04T22:20:47.002Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.provider) [39m
[90m2026-03-04T22:20:47.021Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.telegram.accounts.*.webhookSecret.id) [39m
[90m2026-03-04T22:20:53.413Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:20:53.441Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:20:53.471Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:20:53.552Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:20:53.583Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:20:53.614Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:20:53.674Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:20:53.719Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:20:53.751Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:20:54.310Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:20:54.338Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:20:54.374Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:20:54.426Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:20:54.464Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:20:54.494Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:20:54.550Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:20:54.578Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:20:54.610Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.voice.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:21:03.028Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:21:03.060Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:21:03.087Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:21:03.157Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:21:03.183Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:21:03.204Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:21:03.245Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.source) [39m
[90m2026-03-04T22:21:03.271Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.provider) [39m
[90m2026-03-04T22:21:03.302Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.elevenlabs.apiKey.id) [39m
[90m2026-03-04T22:21:03.684Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:21:03.708Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:21:03.745Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:21:03.791Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:21:03.814Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:21:03.840Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:21:03.897Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.source) [39m
[90m2026-03-04T22:21:03.921Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.provider) [39m
[90m2026-03-04T22:21:03.945Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.discord.accounts.*.voice.tts.openai.apiKey.id) [39m
[90m2026-03-04T22:21:05.817Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.source) [39m
[90m2026-03-04T22:21:05.863Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.provider) [39m
[90m2026-03-04T22:21:05.891Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.id) [39m
[90m2026-03-04T22:21:05.934Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.source) [39m
[90m2026-03-04T22:21:05.957Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.provider) [39m
[90m2026-03-04T22:21:05.978Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.id) [39m
[90m2026-03-04T22:21:06.031Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.source) [39m
[90m2026-03-04T22:21:06.049Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.provider) [39m
[90m2026-03-04T22:21:06.073Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.password.id) [39m
[90m2026-03-04T22:21:06.285Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.source) [39m
[90m2026-03-04T22:21:06.308Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.provider) [39m
[90m2026-03-04T22:21:06.343Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.id) [39m
[90m2026-03-04T22:21:06.387Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.source) [39m
[90m2026-03-04T22:21:06.408Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.provider) [39m
[90m2026-03-04T22:21:06.439Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.id) [39m
[90m2026-03-04T22:21:06.480Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.source) [39m
[90m2026-03-04T22:21:06.502Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.provider) [39m
[90m2026-03-04T22:21:06.525Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.nickserv.password.id) [39m
[90m2026-03-04T22:21:08.542Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.source) [39m
[90m2026-03-04T22:21:08.563Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.provider) [39m
[90m2026-03-04T22:21:08.588Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.id) [39m
[90m2026-03-04T22:21:08.629Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.source) [39m
[90m2026-03-04T22:21:08.648Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.provider) [39m
[90m2026-03-04T22:21:08.671Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.id) [39m
[90m2026-03-04T22:21:08.721Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.source) [39m
[90m2026-03-04T22:21:08.746Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.provider) [39m
[90m2026-03-04T22:21:08.769Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.password.id) [39m
[90m2026-03-04T22:21:08.997Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.source) [39m
[90m2026-03-04T22:21:09.022Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.provider) [39m
[90m2026-03-04T22:21:09.050Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.id) [39m
[90m2026-03-04T22:21:09.101Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.source) [39m
[90m2026-03-04T22:21:09.136Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.provider) [39m
[90m2026-03-04T22:21:09.158Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.id) [39m
[90m2026-03-04T22:21:09.201Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.source) [39m
[90m2026-03-04T22:21:09.227Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.provider) [39m
[90m2026-03-04T22:21:09.261Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.irc.accounts.*.nickserv.password.id) [39m
[90m2026-03-04T22:21:16.036Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.source) [39m
[90m2026-03-04T22:21:16.062Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.provider) [39m
[90m2026-03-04T22:21:16.085Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.id) [39m
[90m2026-03-04T22:21:16.136Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.source) [39m
[90m2026-03-04T22:21:16.164Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.provider) [39m
[90m2026-03-04T22:21:16.201Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.id) [39m
[90m2026-03-04T22:21:16.254Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.source) [39m
[90m2026-03-04T22:21:16.283Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.provider) [39m
[90m2026-03-04T22:21:16.306Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.signingSecret.id) [39m
[90m2026-03-04T22:21:21.531Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.source) [39m
[90m2026-03-04T22:21:21.555Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.provider) [39m
[90m2026-03-04T22:21:21.579Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.id) [39m
[90m2026-03-04T22:21:21.637Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.source) [39m
[90m2026-03-04T22:21:21.659Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.provider) [39m
[90m2026-03-04T22:21:21.683Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.id) [39m
[90m2026-03-04T22:21:21.730Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.source) [39m
[90m2026-03-04T22:21:21.766Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.provider) [39m
[90m2026-03-04T22:21:21.791Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.slack.accounts.*.signingSecret.id) [39m
[90m2026-03-04T22:21:34.243Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.source) [39m
[90m2026-03-04T22:21:34.275Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.provider) [39m
[90m2026-03-04T22:21:34.321Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.id) [39m
[90m2026-03-04T22:21:34.385Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.source) [39m
[90m2026-03-04T22:21:34.410Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.provider) [39m
[90m2026-03-04T22:21:34.437Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.id) [39m
[90m2026-03-04T22:21:34.511Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.source) [39m
[90m2026-03-04T22:21:34.537Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.provider) [39m
[90m2026-03-04T22:21:34.565Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.password.id) [39m
[90m2026-03-04T22:21:36.446Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.source) [39m
[90m2026-03-04T22:21:36.500Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.provider) [39m
[90m2026-03-04T22:21:36.532Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.id) [39m
[90m2026-03-04T22:21:36.614Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.source) [39m
[90m2026-03-04T22:21:36.650Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.provider) [39m
[90m2026-03-04T22:21:36.687Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.id) [39m
[90m2026-03-04T22:21:36.739Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.source) [39m
[90m2026-03-04T22:21:36.760Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.provider) [39m
[90m2026-03-04T22:21:36.783Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.bluebubbles.accounts.*.password.id) [39m
[90m2026-03-04T22:21:39.320Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.source) [39m
[90m2026-03-04T22:21:39.357Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.provider) [39m
[90m2026-03-04T22:21:39.383Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.id) [39m
[90m2026-03-04T22:21:39.438Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.source) [39m
[90m2026-03-04T22:21:39.471Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.provider) [39m
[90m2026-03-04T22:21:39.531Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.id) [39m
[90m2026-03-04T22:21:39.586Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.source) [39m
[90m2026-03-04T22:21:39.622Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.provider) [39m
[90m2026-03-04T22:21:39.666Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (channels.msteams.appPassword.id) [39m
[90m2026-03-04T22:21:42.478Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.source) [39m
[90m2026-03-04T22:21:42.504Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.provider) [39m
[90m2026-03-04T22:21:42.532Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.id) [39m
[90m2026-03-04T22:21:42.589Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.source) [39m
[90m2026-03-04T22:21:42.613Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.provider) [39m
[90m2026-03-04T22:21:42.640Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.id) [39m
[90m2026-03-04T22:21:42.682Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.source) [39m
[90m2026-03-04T22:21:42.717Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.provider) [39m
[90m2026-03-04T22:21:42.743Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.providers.*.apiKey.id) [39m
[90m2026-03-04T22:21:42.997Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.source) [39m
[90m2026-03-04T22:21:43.018Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.provider) [39m
[90m2026-03-04T22:21:43.054Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.id) [39m
[90m2026-03-04T22:21:43.105Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.source) [39m
[90m2026-03-04T22:21:43.146Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.provider) [39m
[90m2026-03-04T22:21:43.170Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.id) [39m
[90m2026-03-04T22:21:43.224Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.source) [39m
[90m2026-03-04T22:21:43.246Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.provider) [39m
[90m2026-03-04T22:21:43.269Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (talk.apiKey.id) [39m
[90m2026-03-04T22:21:44.019Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.source) [39m
[90m2026-03-04T22:21:44.044Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.provider) [39m
[90m2026-03-04T22:21:44.113Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.id) [39m
[90m2026-03-04T22:21:44.262Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.source) [39m
[90m2026-03-04T22:21:44.294Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.provider) [39m
[90m2026-03-04T22:21:44.308Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.id) [39m
[90m2026-03-04T22:21:44.352Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.source) [39m
[90m2026-03-04T22:21:44.371Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.provider) [39m
[90m2026-03-04T22:21:44.398Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.auth.password.id) [39m
[90m2026-03-04T22:21:45.424Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.source) [39m
[90m2026-03-04T22:21:45.448Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.provider) [39m
[90m2026-03-04T22:21:45.477Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.id) [39m
[90m2026-03-04T22:21:45.519Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.source) [39m
[90m2026-03-04T22:21:45.540Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.provider) [39m
[90m2026-03-04T22:21:45.577Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.id) [39m
[90m2026-03-04T22:21:45.628Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.source) [39m
[90m2026-03-04T22:21:45.650Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.provider) [39m
[90m2026-03-04T22:21:45.678Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (gateway.remote.password.id) [39m
[90m2026-03-04T22:21:49.573Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.source) [39m
[90m2026-03-04T22:21:49.609Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.provider) [39m
[90m2026-03-04T22:21:49.636Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.id) [39m
[90m2026-03-04T22:21:49.680Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.source) [39m
[90m2026-03-04T22:21:49.713Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.provider) [39m
[90m2026-03-04T22:21:49.736Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.id) [39m
[90m2026-03-04T22:21:49.783Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.source) [39m
[90m2026-03-04T22:21:49.810Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.provider) [39m
[90m2026-03-04T22:21:49.848Z [39m [36m[config/schema] [39m [90mpossibly sensitive key found: (skills.entries.*.apiKey.id) [39m
[90m2026-03-04T22:21:50.993Z [39m [36m[ws] [39m [36m⇄ res ✓ config.get 114587ms id=950c5316…e111 [39m
[90m2026-03-04T22:21:51.053Z [39m [36m[ws] [39m [36m→ event tick seq=2 clients=1 dropIfSlow=true [39m
[90m2026-03-04T22:21:51.075Z [39m [36m[ws] [39m [36m→ event health seq=3 clients=1 presenceVersion=2 healthVersion=6 [39m
[90m2026-03-04T22:21:51.114Z [39m [36m[ws] [39m [36m⇄ res ✓ channels.status 2ms id=ff7e9298…ef98 [39m
[90m2026-03-04T22:21:51.126Z [39m [36m[ws] [39m [36m⇄ res ✓ system-presence 2ms id=dbf307d8…000c [39m
[90m2026-03-04T22:21:51.139Z [39m [36m[ws] [39m [36m⇄ res ✓ sessions.list 5ms id=ecc15181…543e [39m
[90m2026-03-04T22:21:51.150Z [39m [36m[ws] [39m [36m⇄ res ✓ health 1ms cached=true id=309b2a65…d4dd [39m
[90m2026-03-04T22:21:51.160Z [39m [36m[ws] [39m [36m⇄ res ✓ last-heartbeat 1ms id=6602d9d8…0e09 [39m
[90m2026-03-04T22:21:51.176Z [39m [36m[ws] [39m [36m⇄ res ✓ chat.send 6ms runId=d482eff9-2df9-4a0f-a4c7-2956bde1acbe id=424d57b4…485f [39m
[90m2026-03-04T22:21:51.201Z [39m [36m[ws] [39m [36m⇄ res ✓ agent.identity.get 2ms id=1aea0e46…ab09 [39m
[90m2026-03-04T22:21:51.210Z [39m [36m[ws] [39m [36m→ event health seq=4 clients=1 presenceVersion=2 healthVersion=7 [39m
[90m2026-03-04T22:21:51.225Z [39m [36m[ws] [39m [36m⇄ res ✓ status 80ms id=01fd3754…69aa [39m
[90m2026-03-04T22:21:51.235Z [39m [36m[ws] [39m [36m⇄ res ✓ models.list 77ms id=a9440f50…49c7 [39m
[90m2026-03-04T22:21:51.242Z [39m [36m[ws] [39m [36m⇄ res ✓ chat.history 75ms id=b6f05b58…687c [39m
[90m2026-03-04T22:21:51.248Z [39m [36m[ws] [39m [36m⇄ res ✓ chat.history 41ms id=7218c765…6abf [39m
[90m2026-03-04T22:21:51.255Z [39m [36m[ws] [39m [36m⇄ res ✓ cron.status 109ms id=4f6f06ab…9d23 [39m
[90m2026-03-04T22:21:51.295Z [39m [36m[ws] [39m [36m⇄ res ✓ sessions.list 2ms id=157b8f17…fb10 [39m
[90m2026-03-04T22:21:51.304Z [39m [36m[ws] [39m [36m⇄ res ✓ chat.history 16ms id=34dc24c6…31f6 [39m
[90m2026-03-04T22:21:51.360Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 277ms id=bf14decf…985e [39m
[90m2026-03-04T22:21:51.393Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 305ms id=5d3516c5…b197 [39m
[90m2026-03-04T22:21:51.402Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 304ms id=3a36ca1b…f988 [39m
[90m2026-03-04T22:21:51.410Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 309ms id=d956e1fc…3fbc [39m
[90m2026-03-04T22:21:51.417Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 313ms id=e89f70e6…8bf3 [39m
2026-03-04T22:21:54.056+00:00 memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=200000 threshold=176000 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=35 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[90m2026-03-04T22:21:54.108Z [39m [31m[diagnostic] [39m [90mlane enqueue: lane=session:agent:main:main queueSize=1 [39m
[90m2026-03-04T22:21:54.112Z [39m [31m[diagnostic] [39m [90mlane dequeue: lane=session:agent:main:main waitMs=4 queueSize=0 [39m
[90m2026-03-04T22:21:54.117Z [39m [31m[diagnostic] [39m [90mlane enqueue: lane=main queueSize=1 [39m
[90m2026-03-04T22:21:54.121Z [39m [31m[diagnostic] [39m [90mlane dequeue: lane=main waitMs=4 queueSize=0 [39m
[90m2026-03-04T22:21:54.194Z [39m [31m[diagnostic] [39m [31mlane task error: lane=main durationMs=66 error="Error: No API key found for provider "anthropic". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir." [39m
[90m2026-03-04T22:21:54.203Z [39m [31m[diagnostic] [39m [31mlane task error: lane=session:agent:main:main durationMs=83 error="Error: No API key found for provider "anthropic". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir." [39m
2026-03-04T22:21:54.214+00:00 Embedded agent failed before reply: No API key found for provider "anthropic". Auth store: /root/.openclaw/agents/main/agent/auth-profiles.json (agentDir: /root/.openclaw/agents/main/agent). Configure auth for this agent (openclaw agents add <id>) or copy auth-profiles.json from the main agentDir.
[90m2026-03-04T22:21:54.248Z [39m [36m[ws] [39m [36m→ event chat seq=5 clients=1 [39m
[90m2026-03-04T22:21:54.571Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 21ms id=030d091a…2a2d [39m
[90m2026-03-04T22:21:59.559Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 15ms id=8dcfd83e…4f99 [39m
[90m2026-03-04T22:22:04.579Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 27ms id=35513fbd…fb99 [39m
[90m2026-03-04T22:22:09.571Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 24ms id=df86957a…f294 [39m
[90m2026-03-04T22:22:14.563Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 17ms id=6abf7bf2…f4cd [39m
[90m2026-03-04T22:22:19.602Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 40ms id=95d14aaa…d6d2 [39m
[90m2026-03-04T22:22:21.081Z [39m [36m[ws] [39m [36m→ event tick seq=6 clients=1 dropIfSlow=true [39m
[90m2026-03-04T22:22:24.567Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 16ms id=1f631042…bd27 [39m
[90m2026-03-04T22:22:29.583Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 23ms id=21785abe…289b [39m
[90m2026-03-04T22:22:34.579Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 21ms id=9b69f71f…1b1a [39m
[90m2026-03-04T22:22:39.556Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 16ms id=751cd343…47a5 [39m
[90m2026-03-04T22:22:44.581Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 21ms id=ee39171f…349f [39m
[90m2026-03-04T22:22:49.226Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 33ms id=76a9ce5d…4776 [39m
[90m2026-03-04T22:22:49.565Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 20ms id=19169b20…87b6 [39m
[90m2026-03-04T22:22:51.077Z [39m [36m[ws] [39m [36m→ event tick seq=7 clients=1 dropIfSlow=true [39m
[90m2026-03-04T22:22:51.112Z [39m [36m[ws] [39m [36m→ event health seq=8 clients=1 presenceVersion=2 healthVersion=8 [39m
[90m2026-03-04T22:22:51.214Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 30ms id=0e3bb7c9…3de8 [39m
[90m2026-03-04T22:22:53.260Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 34ms id=03c20fde…5b3e [39m
[90m2026-03-04T22:22:54.569Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 24ms id=cd9ba72b…2285 [39m
[90m2026-03-04T22:22:55.242Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 39ms id=7bd930dc…dcf1 [39m
[90m2026-03-04T22:22:57.231Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 30ms id=e4238aea…56f0 [39m
[90m2026-03-04T22:22:59.276Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 51ms id=02af857a…a183 [39m
[90m2026-03-04T22:22:59.579Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 26ms id=d994dcf6…8794 [39m
[90m2026-03-04T22:23:01.240Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 34ms id=cd457e78…5923 [39m
[90m2026-03-04T22:23:03.241Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 42ms id=b6943750…b3cd [39m
[90m2026-03-04T22:23:04.552Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 16ms id=210c5c9f…048b [39m
[90m2026-03-04T22:23:05.228Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 25ms id=3e7b6871…56de [39m
[90m2026-03-04T22:23:07.226Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 30ms id=9bb12961…cca9 [39m
[90m2026-03-04T22:23:09.244Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 41ms id=7e292cef…33cd [39m
[90m2026-03-04T22:23:09.559Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 22ms id=5b5a75bf…cdcd [39m
[90m2026-03-04T22:23:11.229Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 39ms id=da0ed1ea…f73e [39m
[90m2026-03-04T22:23:13.243Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 45ms id=7e22023d…7863 [39m
[90m2026-03-04T22:23:14.555Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 12ms id=cb27fd3d…db88 [39m
[90m2026-03-04T22:23:15.241Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 33ms id=33320e33…c8dd [39m
[90m2026-03-04T22:23:17.247Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 33ms id=0120c095…51cf [39m
[90m2026-03-04T22:23:19.230Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 28ms id=22242ffa…7f6b [39m
[90m2026-03-04T22:23:19.546Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 18ms id=6b4651fa…382d [39m
[90m2026-03-04T22:23:21.078Z [39m [36m[ws] [39m [36m→ event tick seq=9 clients=1 dropIfSlow=true [39m
[90m2026-03-04T22:23:21.240Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 43ms id=e667fd13…4c49 [39m
[90m2026-03-04T22:23:23.227Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 24ms id=d693bb34…33cf [39m
[90m2026-03-04T22:23:24.576Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 26ms id=150736be…de11 [39m
[90m2026-03-04T22:23:25.250Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 42ms id=8ea7b51d…0302 [39m
[90m2026-03-04T22:23:27.232Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 29ms id=9619892c…8b34 [39m
[90m2026-03-04T22:23:29.235Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 29ms id=423937c5…fe19 [39m
[90m2026-03-04T22:23:29.584Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 35ms id=b4dea5e5…878f [39m
[90m2026-03-04T22:23:31.257Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 39ms id=d2289d33…dbcb [39m
[90m2026-03-04T22:23:33.240Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 49ms id=d1a4aaf9…894f [39m
[90m2026-03-04T22:23:34.568Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 22ms id=99b69e0e…fb3f [39m
[90m2026-03-04T22:23:35.255Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 51ms id=919f2760…62eb [39m
[90m2026-03-04T22:23:37.241Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 50ms id=ef297b47…4adf [39m
[90m2026-03-04T22:23:39.266Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 55ms id=60a9a3ea…684b [39m
[90m2026-03-04T22:23:39.593Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 25ms id=b134e58a…5a66 [39m
[90m2026-03-04T22:23:41.211Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 23ms id=42e004e8…5365 [39m
[90m2026-03-04T22:23:43.210Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 22ms id=b1080925…c7c0 [39m
[90m2026-03-04T22:23:44.534Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 8ms id=def97880…fb0f [39m
[90m2026-03-04T22:23:45.215Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 22ms id=3a144d52…3248 [39m
[90m2026-03-04T22:23:47.207Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 17ms id=b08966e3…5eeb [39m
[90m2026-03-04T22:23:49.276Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 59ms id=5f003a10…d046 [39m
[90m2026-03-04T22:23:49.603Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 40ms id=d5323cde…4fe3 [39m
[90m2026-03-04T22:23:51.104Z [39m [36m[ws] [39m [36m→ event tick seq=10 clients=1 dropIfSlow=true [39m
[90m2026-03-04T22:23:51.154Z [39m [36m[ws] [39m [36m→ event health seq=11 clients=1 presenceVersion=2 healthVersion=9 [39m
[90m2026-03-04T22:23:51.207Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 17ms id=1cc2881f…ae69 [39m
[90m2026-03-04T22:23:53.267Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 39ms id=465e310a…709b [39m
[90m2026-03-04T22:23:54.591Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 20ms id=62a8f5c8…2ee7 [39m
[90m2026-03-04T22:23:55.269Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 59ms id=7a9c3181…7e44 [39m
[90m2026-03-04T22:23:57.286Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 58ms id=a2ad9505…d365 [39m
[90m2026-03-04T22:23:59.278Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 69ms id=9c178bdb…8e53 [39m
[90m2026-03-04T22:23:59.588Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 31ms id=3aa8771e…fe63 [39m
[90m2026-03-04T22:24:01.196Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 17ms id=66b787a8…9e61 [39m
[90m2026-03-04T22:24:03.231Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 31ms id=c066c30e…6da5 [39m
[90m2026-03-04T22:24:04.526Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 5ms id=bed02712…bbce [39m
[90m2026-03-04T22:24:05.187Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 5ms id=dd2ec9a6…d3d6 [39m
[90m2026-03-04T22:24:07.187Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 7ms id=43801271…a7fd [39m
[90m2026-03-04T22:24:09.207Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 18ms id=f5953ecc…98bc [39m
[90m2026-03-04T22:24:09.536Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 8ms id=ca4eed2d…57e7 [39m
[90m2026-03-04T22:24:11.210Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 22ms id=ecaffc8a…c3da [39m
[90m2026-03-04T22:24:13.207Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 20ms id=79ca2565…0bf7 [39m
[90m2026-03-04T22:24:14.563Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 18ms id=15f5c60e…5e7c [39m
[90m2026-03-04T22:24:15.239Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 29ms id=2bfb42b4…4a58 [39m
[90m2026-03-04T22:24:17.257Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 53ms id=e73ddae6…5472 [39m
[90m2026-03-04T22:24:19.282Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 73ms id=138ad8b8…a338 [39m
[90m2026-03-04T22:24:19.593Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 36ms id=716c03da…d6c6 [39m
[90m2026-03-04T22:24:21.115Z [39m [36m[ws] [39m [36m→ event tick seq=12 clients=1 dropIfSlow=true [39m
[90m2026-03-04T22:24:21.249Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 37ms id=f197c77a…59c1 [39m
[90m2026-03-04T22:24:23.265Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 61ms id=c5214c94…65d0 [39m
[90m2026-03-04T22:24:24.570Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 22ms id=9b755e16…4a8e [39m
[90m2026-03-04T22:24:25.225Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 35ms id=b53d4d72…9f31 [39m
[90m2026-03-04T22:24:27.249Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 38ms id=976961ef…1d9a [39m
[90m2026-03-04T22:24:29.228Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 29ms id=3c520451…af24 [39m
[90m2026-03-04T22:24:29.549Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 10ms id=315f648a…7526 [39m
[90m2026-03-04T22:24:31.214Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 27ms id=ce55cb5d…d5b7 [39m
[90m2026-03-04T22:24:33.191Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 9ms id=6e0ab901…e302 [39m
[90m2026-03-04T22:24:34.565Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 16ms id=b9c74c84…24db [39m
[90m2026-03-04T22:24:35.234Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 27ms id=71d34d68…7814 [39m
[90m2026-03-04T22:24:37.267Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 49ms id=b83406b0…dfb7 [39m
[90m2026-03-04T22:24:39.277Z [39m [36m[ws] [39m [36m⇄ res ✓ logs.tail 56ms id=47d27bb2…5206 [39m
[90m2026-03-04T22:24:39.597Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 32ms id=0242044a…0e96 [39m
[90m2026-03-04T22:24:40.781Z [39m [36m[ws] [39m [36m⇄ res ✓ chat.history 59ms id=49274417…e5a2 [39m
[90m2026-03-04T22:24:40.811Z [39m [36m[ws] [39m [36m⇄ res ✓ sessions.list 10ms id=37e5c754…2ac8 [39m
[90m2026-03-04T22:24:44.910Z [39m [36m[ws] [39m [36m⇄ res ✓ node.list 10ms id=5ddd97a9…5dd1 [39m
[90m2026-03-04T22:24:46.968Z [39m [36m[ws] [39m [36mwebchat disconnected code=1001 reason=n/a conn=46e42224-010b-4127-a032-fc12f9f0762e [39m
[90m2026-03-04T22:24:46.981Z [39m [36m[ws] [39m [36m→ event presence seq=13 clients=1 dropIfSlow=true presenceVersion=3 healthVersion=9 [39m
[90m2026-03-04T22:24:46.994Z [39m [36m[ws] [39m [36m→ close code=1001 durationMs=312428 handshake=connected lastFrameType=req lastFrameMethod=node.list lastFrameId=5ddd97a9-4323-4e75-bb65-5ccf02575dd1 [39m


Debugging Chat & Handshake Issues
I've confirmed that ANTHROPIC_API_KEY is the correct environment variable and identified that the 200ms delay in 

sendMessage
 is likely causing the handshake failure. I'm now drafting an implementation plan to refactor 

sendMessage
 to wait for the proper handshake event and to ensure API keys are correctly synchronized between the global config and the agent's auth store.

Files Edited
Progress Updates
1
Analyzing logs and code for token retrieval and handshake failures.

2
Auditing Onboarding and GatewayService for API key configuration.

3
Inspecting OpenClaw configuration files for API keys.

4
Reading NativeBridge to understand proot command execution.

5
Researching OpenClaw API key environment variables.

6
Creating an implementation plan for auth and handshake fixes.

I've analyzed the chat failures and handshake issues. The root cause is a missing API key for the "anthropic" provider in the agent's specific auth store, and a timing issue in the WebSocket handshake.

I have a plan to:

Refactor the handshake logic in sendMessage to wait for the proper server response instead of using a fixed delay.
Ensure API keys are correctly synchronized between the global configuration and the agent's auth store.
Please review the implementation plan.



The issues you experienced were caused by two main "sync" problems between the Flutter app and the OpenClaw backend:

1. WebSocket "Handshake" Race Condition
When the app connects to the OpenClaw gateway via WebSockets, the server expects a brief "handshake" where it says hello-ok before it will accept any commands like sending a message.

The Issue: The app was connecting and then immediately trying to send your "hello" message after a fixed 200ms delay. If the server took 201ms to send its handshake, your message would arrive "too early," causing the server to reject the connection with an "invalid handshake" error.
The Fix: I removed the guestimate delay and replaced it with a proper listener. The app now waits for the specific hello-ok event from the server before it ever attempts to send your message.
2. The Missing API Key (Auth Misalignment)
The OpenClaw agent is quite strict about where it looks for API keys. It has two "layers" of configuration:

Global Layer: openclaw.json (where we were saving the keys).
Agent Layer: auth-profiles.json (a private file inside the agent's folder).
The Issue: Your logs showed the agent was specifically looking for an "anthropic" key inside its private auth-profiles.json and finding it empty. Our app was only updating the Global layer. Additionally, the app was sending "claude" as the provider name, but the agent specifically required the name "anthropic".
The Fix: I updated the configuration logic to automatically map "Claude" to "Anthropic" and, more importantly, to write the key into both files at once. This ensures the "brain" of the assistant has direct access to the credentials it needs.
3. Redundant Probing
The Issue: Whenever a connection failed, the app would redundantly "probe" the system for a new token, which sometimes led to multiple simultaneous connection attempts that tripped over each other.
The Fix: I optimized the 

NodeService
 to be "quieter"—it now only probes for a token if it truly doesn't have one, rather than forcing a refresh on every retry.
In short: The app is now much more patient with the server and more thorough when saving your API keys.

I WILL ASK GROK TO VERIFY THIS... 



The issues you experienced were caused by two main "sync" problems between the Flutter app and the OpenClaw backend:

1. WebSocket "Handshake" Race Condition
When the app connects to the OpenClaw gateway via WebSockets, the server expects a brief "handshake" where it says hello-ok before it will accept any commands like sending a message.

The Issue: The app was connecting and then immediately trying to send your "hello" message after a fixed 200ms delay. If the server took 201ms to send its handshake, your message would arrive "too early," causing the server to reject the connection with an "invalid handshake" error.
The Fix: I removed the guestimate delay and replaced it with a proper listener. The app now waits for the specific hello-ok event from the server before it ever attempts to send your message.
2. The Missing API Key (Auth Misalignment)
The OpenClaw agent is quite strict about where it looks for API keys. It has two "layers" of configuration:

Global Layer: openclaw.json (where we were saving the keys).
Agent Layer: auth-profiles.json (a private file inside the agent's folder).
The Issue: Your logs showed the agent was specifically looking for an "anthropic" key inside its private auth-profiles.json and finding it empty. Our app was only updating the Global layer. Additionally, the app was sending "claude" as the provider name, but the agent specifically required the name "anthropic".
The Fix: I updated the configuration logic to automatically map "Claude" to "Anthropic" and, more importantly, to write the key into both files at once. This ensures the "brain" of the assistant has direct access to the credentials it needs.
3. Redundant Probing
The Issue: Whenever a connection failed, the app would redundantly "probe" the system for a new token, which sometimes led to multiple simultaneous connection attempts that tripped over each other.
The Fix: I optimized the 

NodeService
 to be "quieter"—it now only probes for a token if it truly doesn't have one, rather than forcing a refresh on every retry.
In short: The app is now much more patient with the server and more thorough when saving your API keys.

I WILL ASK GROK TO VERIFY THIS... 

MEANWHILE I WANT TO ASK, WHY IS THE openclaw bot when i go to > Web Dashboard > Agents. i see "primary model = default" in field and drop down too why is it not the model user chooses when onboarding, seems the bot is trying to use Anthropic claude api keys if u noticed that in those errors, as default, despite me choosing gemini for example.that i usually choosing when testing the app in the setup_flow..do u remember if the logs i shared earlier show when i onboard and save the model what happens?

learn from this regarding all my questions go read this repo and learn and do some research also online whsit at it if needed. in comparion to our implementation to find out what we are skipping/missing in setup/config compared to others. and also how others are using the openclaw integrations properly regarding the issues we are addressing

https://github.com/yuga-hashimoto/openclaw-assistant


---
## 🛠️ World-Class Config Fix Audit – March 5, 2026 09:45 UTC

### Root Cause: Configuration Mismatch
Detected that AI providers (like Google Gemini) were being incorrectly placed under `secrets.providers` in `openclaw.json`. Per upstream docs, this section is reserved for secret backends (Vault, etc.). AI providers must reside in `models.providers`.

### Precise Fixes Implemented:

#### 1. Onboarding Screen (`lib/screens/onboarding_screen.dart`)
- **Post-Run Validation**: Added `openclaw doctor --fix` immediately after configuration commands.
- **UI Feedback**: Implemented SnackBar alerts if a configuration remains invalid after an attempt to fix.
- **Pre-Service Check**: Added `openclaw config --validate` probe before starting the gateway.

#### 2. Gateway Service (`lib/services/gateway_service.dart`)
- **Corrected Config Logic**: Redesigned `configureApiKey` Node.js script to target `models.providers` instead of the erroneous `secrets.providers`.
- **Auto-Fix Probe**: Added `probeGateway()` method to automatically detect and repair schema violations using `openclaw doctor --fix`.
- **Startup Resilience**: Integrated auto-fix retry logic directly into the `start()` sequence.

#### 3. Documentation
- **README.md**: Added a dedicated "Adding New Providers" section with correct CLI usage and pathing information.
- **Continuation.md**: Logged this audit as the definitive state of configuration management.

### Status: ✅ FULL FIX APPLIED
All intricate code paths identified in the audit have been implemented and cross-verified.

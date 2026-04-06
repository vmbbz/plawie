KV Cache usage is now 300mb not 56mb

context limitsseem respected

full logs below...

I also committed all the latest updates go check the repo vmbbz (not cosychiruka)

BUT ITS NOT SENDING BACK ANY RESPONCE EVEN WHEN I LOOK INSIDE THE WEB DASHBOARD. THE SASSISTANT IS NOT THERE ONLY USER MESSAGES APPEAR. EVEN WHEN I SEND A MESSAGE DIRECTLY INSIDE WEBDASHBOARD.....

COMPARE WITH LAST COMMIT IF WE RUNIED THE PRMPT ENGINEERING

IN INTEGRATED AGENT HUB, THE LIVE LOGS/ACTIVITY SECTION SHOWS:


I HAVE 2.3GIG FREE MEMORY AS IT SAYS ITS STREAMING YET NOTHING COMES THRU:

- RUNNING 1 THREAD OR CORE IN SETTINGS

- RUNNING 0.5B QWEN INSTRUCT

LOCAL LLM PAGE > OLLAMA DIRECT DIAGNOSTC TEST WITH THE JOKE PRMPT WORKS FAST TO TELL ME A JOKE SHOWING THE OLLAMA SERVER IS RUNNING AND STREAMING....

THEN ANOTHER SMOKING GUN TO CHASE IS THE WEB DASHBOARD - WHY IS IT NEVER SHOWING THE ASSISTANT MESSAGE EVEN IN CLOUD??? AT LEAST I SHOULD SEE A INTRO RIGHT? EVEN WHEN API KEY IS EXPIRED. WHAT DO OTHER DEVELOPERS SEE ON THIS PAGE... IT MIGHT NOT BE A MEMORY CRUSH ONLY NOW BUT TIMEONE ISSUE I ALSO GOT A TIMEOUT AFTER 600 SECONDS IN ONE OF MY ATTEMPTS TO TEST IT..




load: special tokens cache size = 22
load: token to piece cache size = 0.9310 MB
print_info: arch = qwen2
print_info: vocab_only = 0
print_info: no_alloc = 0
print_info: n_ctx_train = 32768
print_info: n_embd = 896
print_info: n_embd_inp = 896
print_info: n_layer = 24
print_info: n_head = 14
print_info: n_head_kv = 2
print_info: n_rot = 64
print_info: n_swa = 0
print_info: is_swa_any = 0
print_info: n_embd_head_k = 64
print_info: n_embd_head_v = 64
print_info: n_gqa = 7
print_info: n_embd_k_gqa = 128
print_info: n_embd_v_gqa = 128
print_info: f_norm_eps = 0.0e+00
print_info: f_norm_rms_eps = 1.0e-06
print_info: f_clamp_kqv = 0.0e+00
print_info: f_max_alibi_bias = 0.0e+00
print_info: f_logit_scale = 0.0e+00
print_info: f_attn_scale = 0.0e+00
print_info: n_ff = 4864
print_info: n_expert = 0
print_info: n_expert_used = 0
print_info: n_expert_groups = 0
print_info: n_group_used = 0
print_info: causal attn = 1
print_info: pooling type = -1
print_info: rope type = 2
print_info: rope scaling = linear
print_info: freq_base_train = 1000000.0
print_info: freq_scale_train = 1
print_info: n_ctx_orig_yarn = 32768
print_info: rope_yarn_log_mul= 0.0000
print_info: rope_finetuned = unknown
print_info: model type = 1B
print_info: model params = 630.17 M
print_info: general.name = qwen2.5-0.5b-instruct
print_info: vocab type = BPE
print_info: n_vocab = 151936
print_info: n_merges = 151387
print_info: BOS token = 151643 '<|endoftext|>'
print_info: EOS token = 151645 '<|im_end|>'
print_info: EOT token = 151645 '<|im_end|>'
print_info: PAD token = 151643 '<|endoftext|>'
print_info: LF token = 198 'Ċ'
print_info: FIM PRE token = 151659 '<|fim_prefix|>'
print_info: FIM SUF token = 151661 '<|fim_suffix|>'
print_info: FIM MID token = 151660 '<|fim_middle|>'
print_info: FIM PAD token = 151662 '<|fim_pad|>'
print_info: FIM REP token = 151663 '<|repo_name|>'
print_info: FIM SEP token = 151664 '<|file_sep|>'
print_info: EOG token = 151643 '<|endoftext|>'
print_info: EOG token = 151645 '<|im_end|>'
print_info: EOG token = 151662 '<|fim_pad|>'
print_info: EOG token = 151663 '<|repo_name|>'
print_info: EOG token = 151664 '<|file_sep|>'
print_info: max token length = 256
load_tensors: loading model tensors, this can take a while... (mmap = false)
load_tensors: CPU model buffer size = 462.96 MiB
llama_context: constructing llama_context
llama_context: n_seq_max = 1
llama_context: n_ctx = 32768
llama_context: n_ctx_seq = 32768
llama_context: n_batch = 512
llama_context: n_ubatch = 512
llama_context: causal_attn = 1
llama_context: flash_attn = auto
llama_context: kv_unified = false
llama_context: freq_base = 1000000.0
llama_context: freq_scale = 1
llama_context: CPU output buffer size = 0.58 MiB
llama_kv_cache: CPU KV buffer size = 384.00 MiB
llama_kv_cache: size = 384.00 MiB ( 32768 cells, 24 layers, 1/1 seqs), K (f16): 192.00 MiB, V (f16): 192.00 MiB
llama_context: Flash Attention was auto, set to enabled
llama_context: CPU compute buffer size = 298.50 MiB
llama_context: graph nodes = 823
llama_context: graph splits = 1
time=2026-04-06T13:48:24.849Z level=INFO source=server.go:1390 msg="llama runner started in 2.69 seconds"
time=2026-04-06T13:48:24.849Z level=INFO source=sched.go:561 msg="loaded runners" count=1
time=2026-04-06T13:48:24.849Z level=INFO source=server.go:1352 msg="waiting for llama runner to start responding"
time=2026-04-06T13:48:24.850Z level=INFO source=server.go:1390 msg="llama runner started in 2.69 seconds"
[GIN] 2026/04/06 - 13:50:09 | 200 | 2.316992ms | 127.0.0.1 | HEAD "/"
[GIN] 2026/04/06 - 13:50:11 | 200 | 2.243789ms | 127.0.0.1 | POST "/api/blobs/sha256:6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"
[GIN] 2026/04/06 - 13:50:12 | 200 | 343.387539ms | 127.0.0.1 | POST "/api/create"
[GIN] 2026/04/06 - 13:50:12 | 200 | 51.211µs | 127.0.0.1 | HEAD "/"
[GIN] 2026/04/06 - 13:51:31 | 200 | 117.094883ms | 127.0.0.1 | GET "/api/tags"
[GIN] 2026/04/06 - 13:53:04 | 200 | 11.03461ms | 127.0.0.1 | GET "/api/ps"
[GIN] 2026/04/06 - 13:57:39 | 200 | 156.29332ms | 127.0.0.1 | GET "/api/tags"
[GIN] 2026/04/06 - 13:58:21 | 500 | 10m0s | 127.0.0.1 | POST "/api/chat"
[GIN] 2026/04/06 - 14:04:07 | 200 | 5.886836ms | 127.0.0.1 | GET "/api/ps"
[GIN] 2026/04/06 - 14:04:20 | 200 | 83.08125ms | 127.0.0.1 | GET "/api/tags"
[GIN] 2026/04/06 - 14:08:22 | 200 | 10m0s | 127.0.0.1 | POST "/api/chat"
[GIN] 2026/04/06 - 14:09:06 | 200 | 119.355274ms | 127.0.0.1 | GET "/api/tags"
[GIN] 2026/04/06 - 14:12:45 | 200 | 145.631993ms | 127.0.0.1 | GET "/api/tags"



See the log in screenshots: [VHAT] Gateway accepted (streaming....) even to this point is say so but not a single text output comes tk main Chat if you see other screenshot of main chat page. Until it timeout or it just shows a blank bubble. Blank bubble now in main page chat as I text this.


Let's also check if our context and token and memory optimizations worked, full gateway logs below:

[INFO] Gateway process detected, attaching...
[DEBUG] Probing gateway config for auth token...
2026-04-06T11:43:36.340+00:00 Registered plugin command: /pair (plugin: device-pair)
2026-04-06T11:43:36.414+00:00 Registered plugin command: /phone (plugin: phone-control)
2026-04-06T11:43:36.435+00:00 Registered plugin command: /voice (plugin: talk-voice)
[90m2026-04-06T11:43:36.499+00:00 [39m [35m[canvas] [39m [36mhost mounted at http://127.0.0.1:18789/__openclaw__/canvas/ (root /root/.openclaw/canvas) [39m
2026-04-06T11:43:36.974+00:00 bonjour: starting (hostname=openclaw, instance="localhost (OpenClaw)", gatewayPort=18789, minimal=true)
[90m2026-04-06T11:43:37.030+00:00 [39m [36m[heartbeat] [39m [36mstarted [39m
[90m2026-04-06T11:43:37.040+00:00 [39m [32m[health-monitor] [39m [36mstarted (interval: 300s, startup-grace: 60s, channel-connect-grace: 120s) [39m
[90m2026-04-06T11:43:37.051+00:00 [39m [36m[gateway] [39m [36magent model: ollama/qwen2.5-1.5b-instruct:q4_k_m [39m
[90m2026-04-06T11:43:37.058+00:00 [39m [36m[gateway] [39m [36mlistening on ws://127.0.0.1:18789, ws://[::1]:18789 (PID 4836) [39m
[90m2026-04-06T11:43:37.067+00:00 [39m [36m[gateway] [39m [36mlog file: /tmp/openclaw/openclaw-2026-04-06.log [39m
2026-04-06T11:43:37.113+00:00 Could not bind detected network interface: Error: Error binding socket on eth0: Error: addMembership ENODEV
    at Socket.addMembership (node:dgram:903:11)
    at Socket.<anonymous> (/usr/local/lib/node_modules/openclaw/node_modules/@homebridge/ciao/src/MDNSServer.ts:518:18)
    at Socket.onListening (node:dgram:286:7)
    at Socket.emit (node:events:524:28)
    at startListening (node:dgram:209:10)
    at node:dgram:404:7
    at processTicksAndRejections (node:internal/process/task_queues:91:21)
    at Socket.<anonymous> (/usr/local/lib/node_modules/openclaw/node_modules/@homebridge/ciao/src/MDNSServer.ts:536:18)
    at Socket.onListening (node:dgram:286:7)
    at Socket.emit (node:events:524:28)
    at startListening (node:dgram:209:10)
    at node:dgram:404:7
    at processTicksAndRejections (node:internal/process/task_queues:91:21)
[90m2026-04-06T11:43:37.205+00:00 [39m [36m[browser/server] [39m [36mBrowser control listening on http://127.0.0.1:18791/ (auth=token) [39m
[90m2026-04-06T11:43:37.823+00:00 [39m [36m[gateway] [39m [36mupdate available (latest): v2026.4.5 (current v2026.3.11). Run: openclaw update [39m
[90m2026-04-06T12:21:05.480+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=bfeaa4b3…0814 [39m
[90m2026-04-06T12:21:05.533+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-android version=1.0.0 mode=ui clientId=openclaw-android platform=android auth=token [39m
[90m2026-04-06T12:21:05.542+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=99 events=19 presence=2 stateVersion=2 [39m
[90m2026-04-06T12:21:05.555+00:00 [39m [36m[ws] [39m [36m→ event health seq=1 clients=1 presenceVersion=2 healthVersion=40 [39m
[90m2026-04-06T12:21:05.567+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 5ms cached=true id=8d364d76…1cc0 [39m
[90m2026-04-06T12:21:05.579+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ skills.list 1ms errorCode=INVALID_REQUEST errorMessage=unknown method: skills.list id=251d989e…d4f1 [39m
[90m2026-04-06T12:21:05.584+00:00 [39m [36m[ws] [39m [36m→ event health seq=2 clients=1 presenceVersion=2 healthVersion=41 [39m
[90m2026-04-06T12:21:05.597+00:00 [39m [36m[ws] [39m [36m⇄ res ✗ capabilities.list 0ms errorCode=INVALID_REQUEST errorMessage=unknown method: capabilities.list id=52b344d9…4446 [39m
[90m2026-04-06T12:21:06.059+00:00 [39m [34m[reload] [39m [33mconfig reload skipped (invalid config): models.providers.ollama: Unrecognized key: "contextWindow" [39m
[90m2026-04-06T12:21:06.669+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=e4d2b6a9…0231 [39m
[90m2026-04-06T12:21:06.695+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=9ef61c30…238d [39m
[90m2026-04-06T12:21:06.726+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=9ef61c30-fa30-46bb-9ee2-5f57e47d238d remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1008 reason=device nonce mismatch [39m
[90m2026-04-06T12:21:06.732+00:00 [39m [36m[ws] [39m [36m→ close code=1008 reason=device nonce mismatch durationMs=31 cause=device-auth-invalid handshake=failed lastFrameType=req lastFrameMethod=connect lastFrameId=a284a5bb-1491-445f-accb-e71ef26b0c22 [39m
[90m2026-04-06T12:21:07.085+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=b0dfb4aa…65a9 [39m
[90m2026-04-06T12:21:07.170+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-android clientDisplayName=OpenClaw Mobile version=1.0.0 mode=ui clientId=openclaw-android platform=android auth=token [39m
[90m2026-04-06T12:21:07.182+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=99 events=19 presence=3 stateVersion=3 [39m
[90m2026-04-06T12:21:07.196+00:00 [39m [36m[ws] [39m [36m→ event health seq=3 clients=2 presenceVersion=3 healthVersion=42 [39m
[90m2026-04-06T12:21:07.210+00:00 [39m [36m[ws] [39m [36m→ event tick seq=4 clients=2 dropIfSlow=true [39m
[90m2026-04-06T12:21:09.652+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ agents.list 10ms conn=bfeaa4b3…0814 id=14085f1a…1706 [39m
[90m2026-04-06T12:21:16.787+00:00 [39m [36m[ws] [39m [33mhandshake timeout conn=e4d2b6a9-4abe-42fc-b2d2-f41e674d0231 remote=127.0.0.1 [39m
[90m2026-04-06T12:21:16.840+00:00 [39m [36m[ws] [39m [33mclosed before connect conn=e4d2b6a9-4abe-42fc-b2d2-f41e674d0231 remote=127.0.0.1 fwd=n/a origin=n/a host=127.0.0.1:18789 ua=Dart/3.10 (dart:io) code=1000 reason=n/a [39m
[90m2026-04-06T12:21:16.857+00:00 [39m [36m[ws] [39m [36m→ close code=1000 durationMs=10172 cause=handshake-timeout handshake=failed conn=e4d2b6a9…0231 [39m
[90m2026-04-06T12:21:17.204+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=2a212d36…c6c7 [39m
[90m2026-04-06T12:21:17.326+00:00 [39m [36m[ws] [39m [36m← connect client=openclaw-android clientDisplayName=OpenClaw Mobile version=1.0.0 mode=ui clientId=openclaw-android platform=android auth=token [39m
[90m2026-04-06T12:21:17.342+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=99 events=19 presence=3 stateVersion=4 [39m
[90m2026-04-06T12:21:17.370+00:00 [39m [36m[ws] [39m [36m→ event health seq=5 clients=3 presenceVersion=4 healthVersion=43 [39m
[90m2026-04-06T12:21:33.861+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ chat.send 64ms runId=7d4f1348-e09d-4727-9cbb-d3372193a940 conn=bfeaa4b3…0814 id=1e069866…2b75 [39m
2026-04-06T12:21:36.430+00:00 memoryFlush check: sessionKey=agent:main:main tokenCount=undefined contextWindow=200000 threshold=176000 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=undefined persistedFresh=false promptTokensEst=36 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=undefined transcriptBytes=undefined forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[90m2026-04-06T12:21:36.514+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=session:agent:main:main queueSize=1 [39m
[90m2026-04-06T12:21:36.518+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=session:agent:main:main waitMs=5 queueSize=0 [39m
[90m2026-04-06T12:21:36.524+00:00 [39m [31m[diagnostic] [39m [90mlane enqueue: lane=main queueSize=1 [39m
[90m2026-04-06T12:21:36.528+00:00 [39m [31m[diagnostic] [39m [90mlane dequeue: lane=main waitMs=3 queueSize=0 [39m
[90m2026-04-06T12:21:36.569+00:00 [39m [33m[agent/embedded] [39m [90membedded run start: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d provider=ollama model=qwen2.5-1.5b-instruct:q4_k_m thinking=off messageChannel=webchat [39m
[90m2026-04-06T12:21:37.143+00:00 [39m [36m[ws] [39m [36m→ event health seq=6 clients=3 presenceVersion=4 healthVersion=44 [39m
[INFO] Gateway auth token acquired from config.
[90m2026-04-06T12:21:37.406+00:00 [39m [31m[diagnostic] [39m [90msession state: sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d sessionKey=agent:main:main prev=idle new=processing reason="run_started" queueDepth=0 [39m
[90m2026-04-06T12:21:37.412+00:00 [39m [31m[diagnostic] [39m [90mrun registered: sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d totalActive=1 [39m
[90m2026-04-06T12:21:37.420+00:00 [39m [33m[agent/embedded] [39m [90membedded run prompt start: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d [39m
[90m2026-04-06T12:21:37.434+00:00 [39m [33m[agent/embedded] [39m [90m[context-diag] pre-prompt: sessionKey=agent:main:main messages=0 roleCounts=none historyTextChars=0 maxMessageTextChars=0 historyImageBlocks=0 systemPromptChars=27434 promptChars=143 promptImages=0 provider=ollama/qwen2.5-1.5b-instruct:q4_k_m sessionFile=/root/.openclaw/agents/main/sessions/380b1b43-637d-4dd9-9813-6d55b5e38e9d.jsonl [39m
[90m2026-04-06T12:21:37.450+00:00 [39m [33m[agent/embedded] [39m [90membedded run agent start: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 [39m
[90m2026-04-06T12:21:37.468+00:00 [39m [36m[ws] [39m [36m→ event agent seq=7 clients=3 run=7d4f1348…a940 agent=main session=main stream=lifecycle aseq=1 phase=start [39m
[90m2026-04-06T12:21:37.516+00:00 [39m [36m[ws] [39m [36m→ event tick seq=8 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:21:42.704+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=8c390f29…63bd [39m
[90m2026-04-06T12:21:44.389+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client version=2026.3.11 mode=backend clientId=gateway-client platform=linux auth=token [39m
[90m2026-04-06T12:21:44.420+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=99 events=19 presence=4 stateVersion=5 [39m
[90m2026-04-06T12:21:44.469+00:00 [39m [36m[ws] [39m [36m→ event health seq=9 clients=4 presenceVersion=5 healthVersion=45 [39m
[90m2026-04-06T12:21:44.514+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ health 1ms cached=true id=86e8f7b9…1fab [39m
[90m2026-04-06T12:21:44.528+00:00 [39m [36m[ws] [39m [36m→ event health seq=10 clients=4 presenceVersion=5 healthVersion=46 [39m
[90m2026-04-06T12:21:44.647+00:00 [39m [36m[ws] [39m [36m← open remoteAddr=127.0.0.1 conn=1f6120b6…d98c [39m
[90m2026-04-06T12:21:44.668+00:00 [39m [36m[ws] [39m [36m→ event presence seq=11 clients=4 dropIfSlow=true presenceVersion=6 healthVersion=46 [39m
[90m2026-04-06T12:21:44.681+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=2068 handshake=connected lastFrameType=req lastFrameMethod=health lastFrameId=86e8f7b9-75f9-40b8-a0d8-8a9e6daf1fab conn=8c390f29…63bd [39m
[90m2026-04-06T12:21:44.745+00:00 [39m [36m[ws] [39m [36m← connect client=gateway-client version=2026.3.11 mode=backend clientId=gateway-client platform=linux auth=token conn=1f6120b6…d98c [39m
[90m2026-04-06T12:21:44.781+00:00 [39m [36m[ws] [39m [36m→ hello-ok methods=99 events=19 presence=4 stateVersion=7 [39m
[90m2026-04-06T12:21:44.837+00:00 [39m [36m[ws] [39m [36m→ event health seq=12 clients=4 presenceVersion=7 healthVersion=47 [39m
[90m2026-04-06T12:21:45.681+00:00 [39m [31m[memory] [39m [33mfts unavailable: no such module: fts5 [39m
[90m2026-04-06T12:21:45.806+00:00 [39m [31m[memory] [39m [90membeddings: batch start [39m
[90m2026-04-06T12:21:47.239+00:00 [39m [36m[ws] [39m [36m⇄ res ✓ doctor.memory.status 2364ms id=43c83305…3a2a [39m
[90m2026-04-06T12:21:47.304+00:00 [39m [36m[ws] [39m [36m→ event presence seq=13 clients=4 dropIfSlow=true presenceVersion=8 healthVersion=47 [39m
[90m2026-04-06T12:21:47.369+00:00 [39m [36m[ws] [39m [36m→ close code=1005 durationMs=2642 handshake=connected lastFrameType=req lastFrameMethod=doctor.memory.status lastFrameId=43c83305-949d-45d4-8939-2f3c0b663a2a [39m
[90m2026-04-06T12:21:48.088+00:00 [39m [34m[reload] [39m [36mconfig change detected; evaluating reload (meta.lastTouchedAt, wizard.lastRunAt) [39m
[90m2026-04-06T12:21:48.128+00:00 [39m [34m[reload] [39m [36mconfig change applied (dynamic reads: meta.lastTouchedAt, wizard.lastRunAt) [39m
[90m2026-04-06T12:22:07.549+00:00 [39m [36m[ws] [39m [36m→ event tick seq=14 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:22:37.207+00:00 [39m [36m[ws] [39m [36m→ event health seq=15 clients=3 presenceVersion=8 healthVersion=48 [39m
[90m2026-04-06T12:22:37.530+00:00 [39m [36m[ws] [39m [36m→ event tick seq=16 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:23:07.610+00:00 [39m [36m[ws] [39m [36m→ event tick seq=17 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:23:37.165+00:00 [39m [36m[ws] [39m [36m→ event health seq=18 clients=3 presenceVersion=8 healthVersion=49 [39m
[90m2026-04-06T12:23:37.538+00:00 [39m [36m[ws] [39m [36m→ event tick seq=19 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:24:07.536+00:00 [39m [36m[ws] [39m [36m→ event tick seq=20 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:24:29.047+00:00 [39m [34m[reload] [39m [33mconfig reload skipped (invalid config): models.providers.ollama: Unrecognized key: "contextWindow", agents.defaults: Unrecognized key: "systemPrompt" [39m
[90m2026-04-06T12:24:37.149+00:00 [39m [36m[ws] [39m [36m→ event health seq=21 clients=3 presenceVersion=8 healthVersion=50 [39m
[90m2026-04-06T12:24:37.539+00:00 [39m [36m[ws] [39m [36m→ event tick seq=22 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:25:07.545+00:00 [39m [36m[ws] [39m [36m→ event tick seq=23 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:25:37.132+00:00 [39m [36m[ws] [39m [36m→ event health seq=24 clients=3 presenceVersion=8 healthVersion=51 [39m
[90m2026-04-06T12:25:37.530+00:00 [39m [36m[ws] [39m [36m→ event tick seq=25 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:26:07.526+00:00 [39m [36m[ws] [39m [36m→ event tick seq=26 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:26:37.097+00:00 [39m [36m[ws] [39m [36m→ event health seq=27 clients=3 presenceVersion=8 healthVersion=52 [39m
[90m2026-04-06T12:26:37.525+00:00 [39m [36m[ws] [39m [36m→ event tick seq=28 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:27:07.528+00:00 [39m [36m[ws] [39m [36m→ event tick seq=29 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:27:37.140+00:00 [39m [36m[ws] [39m [36m→ event health seq=30 clients=3 presenceVersion=8 healthVersion=53 [39m
[90m2026-04-06T12:27:37.540+00:00 [39m [36m[ws] [39m [36m→ event tick seq=31 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:28:07.560+00:00 [39m [36m[ws] [39m [36m→ event tick seq=32 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:28:37.096+00:00 [39m [36m[ws] [39m [36m→ event health seq=33 clients=3 presenceVersion=8 healthVersion=54 [39m
[90m2026-04-06T12:28:37.538+00:00 [39m [36m[ws] [39m [36m→ event tick seq=34 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:29:07.548+00:00 [39m [36m[ws] [39m [36m→ event tick seq=35 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:29:37.195+00:00 [39m [36m[ws] [39m [36m→ event health seq=36 clients=3 presenceVersion=8 healthVersion=55 [39m
[90m2026-04-06T12:29:37.536+00:00 [39m [36m[ws] [39m [36m→ event tick seq=37 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:30:07.566+00:00 [39m [36m[ws] [39m [36m→ event tick seq=38 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:30:37.164+00:00 [39m [36m[ws] [39m [36m→ event health seq=39 clients=3 presenceVersion=8 healthVersion=56 [39m
[90m2026-04-06T12:30:37.547+00:00 [39m [36m[ws] [39m [36m→ event tick seq=40 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:31:07.553+00:00 [39m [36m[ws] [39m [36m→ event tick seq=41 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:31:37.137+00:00 [39m [36m[ws] [39m [36m→ event health seq=42 clients=3 presenceVersion=8 healthVersion=57 [39m
[90m2026-04-06T12:31:37.484+00:00 [39m [33m[agent/embedded] [39m [33membedded run timeout: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d timeoutMs=600000 [39m
[90m2026-04-06T12:31:37.566+00:00 [39m [33m[agent/embedded] [39m [90membedded run prompt end: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d durationMs=600143 [39m
[90m2026-04-06T12:31:37.588+00:00 [39m [33m[agent/embedded] [39m [90mcompaction wait aborted: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d [39m
[90m2026-04-06T12:31:37.594+00:00 [39m [33m[agent/embedded] [39m [90mrun cleanup: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d aborted=true timedOut=true [39m
[90m2026-04-06T12:31:37.604+00:00 [39m [31m[diagnostic] [39m [90msession state: sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0 [39m
[90m2026-04-06T12:31:37.611+00:00 [39m [31m[diagnostic] [39m [90mrun cleared: sessionId=380b1b43-637d-4dd9-9813-6d55b5e38e9d totalActive=0 [39m
[90m2026-04-06T12:31:37.654+00:00 [39m [36m[ws] [39m [36m→ event tick seq=43 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:31:37.684+00:00 [39m [33m[agent/embedded] [39m [33membedded run failover decision: runId=7d4f1348-e09d-4727-9cbb-d3372193a940 stage=assistant decision=surface_error reason=timeout provider=ollama/qwen2.5-1.5b-instruct:q4_k_m profile=- [39m
[90m2026-04-06T12:31:37.695+00:00 [39m [31m[diagnostic] [39m [90mlane task done: lane=main durationMs=601164 active=0 queued=0 [39m
[90m2026-04-06T12:31:37.705+00:00 [39m [31m[diagnostic] [39m [90mlane task done: lane=session:agent:main:main durationMs=601177 active=0 queued=0 [39m
[90m2026-04-06T12:32:07.674+00:00 [39m [36m[ws] [39m [36m→ event tick seq=44 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:32:37.162+00:00 [39m [36m[ws] [39m [36m→ event health seq=45 clients=3 presenceVersion=8 healthVersion=58 [39m
[90m2026-04-06T12:32:37.682+00:00 [39m [36m[ws] [39m [36m→ event tick seq=46 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:33:07.679+00:00 [39m [36m[ws] [39m [36m→ event tick seq=47 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:33:37.132+00:00 [39m [36m[ws] [39m [36m→ event health seq=48 clients=3 presenceVersion=8 healthVersion=59 [39m
[90m2026-04-06T12:33:37.674+00:00 [39m [36m[ws] [39m [36m→ event tick seq=49 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:34:07.677+00:00 [39m [36m[ws] [39m [36m→ event tick seq=50 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:34:37.158+00:00 [39m [36m[ws] [39m [36m→ event health seq=51 clients=3 presenceVersion=8 healthVersion=60 [39m
[90m2026-04-06T12:34:37.682+00:00 [39m [36m[ws] [39m [36m→ event tick seq=52 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:35:07.677+00:00 [39m [36m[ws] [39m [36m→ event tick seq=53 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:35:37.137+00:00 [39m [36m[ws] [39m [36m→ event health seq=54 clients=3 presenceVersion=8 healthVersion=61 [39m
[90m2026-04-06T12:35:37.673+00:00 [39m [36m[ws] [39m [36m→ event tick seq=55 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:36:07.703+00:00 [39m [36m[ws] [39m [36m→ event tick seq=56 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:36:37.127+00:00 [39m [36m[ws] [39m [36m→ event health seq=57 clients=3 presenceVersion=8 healthVersion=62 [39m
[90m2026-04-06T12:36:37.680+00:00 [39m [36m[ws] [39m [36m→ event tick seq=58 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:37:07.695+00:00 [39m [36m[ws] [39m [36m→ event tick seq=59 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:37:37.163+00:00 [39m [36m[ws] [39m [36m→ event health seq=60 clients=3 presenceVersion=8 healthVersion=63 [39m
[90m2026-04-06T12:37:37.683+00:00 [39m [36m[ws] [39m [36m→ event tick seq=61 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:38:07.715+00:00 [39m [36m[ws] [39m [36m→ event tick seq=62 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:38:37.157+00:00 [39m [36m[ws] [39m [36m→ event health seq=63 clients=3 presenceVersion=8 healthVersion=64 [39m
[90m2026-04-06T12:38:37.699+00:00 [39m [36m[ws] [39m [36m→ event tick seq=64 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:39:07.698+00:00 [39m [36m[ws] [39m [36m→ event tick seq=65 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:39:37.136+00:00 [39m [36m[ws] [39m [36m→ event health seq=66 clients=3 presenceVersion=8 healthVersion=65 [39m
[90m2026-04-06T12:39:37.694+00:00 [39m [36m[ws] [39m [36m→ event tick seq=67 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:40:07.697+00:00 [39m [36m[ws] [39m [36m→ event tick seq=68 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:40:37.146+00:00 [39m [36m[ws] [39m [36m→ event health seq=69 clients=3 presenceVersion=8 healthVersion=66 [39m
[90m2026-04-06T12:40:37.697+00:00 [39m [36m[ws] [39m [36m→ event tick seq=70 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:41:07.688+00:00 [39m [36m[ws] [39m [36m→ event tick seq=71 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:41:37.149+00:00 [39m [36m[ws] [39m [36m→ event health seq=72 clients=3 presenceVersion=8 healthVersion=67 [39m
[90m2026-04-06T12:41:37.687+00:00 [39m [36m[ws] [39m [36m→ event tick seq=73 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:42:07.682+00:00 [39m [36m[ws] [39m [36m→ event tick seq=74 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:42:37.148+00:00 [39m [36m[ws] [39m [36m→ event health seq=75 clients=3 presenceVersion=8 healthVersion=68 [39m
[90m2026-04-06T12:42:37.684+00:00 [39m [36m[ws] [39m [36m→ event tick seq=76 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:43:07.693+00:00 [39m [36m[ws] [39m [36m→ event tick seq=77 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:43:37.146+00:00 [39m [36m[ws] [39m [36m→ event health seq=78 clients=3 presenceVersion=8 healthVersion=69 [39m
[90m2026-04-06T12:43:37.193+00:00 [39m [36m[ws] [39m [36m→ event heartbeat seq=79 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:43:37.688+00:00 [39m [36m[ws] [39m [36m→ event tick seq=80 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:44:07.711+00:00 [39m [36m[ws] [39m [36m→ event tick seq=81 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:44:37.133+00:00 [39m [36m[ws] [39m [36m→ event health seq=82 clients=3 presenceVersion=8 healthVersion=70 [39m
[90m2026-04-06T12:44:37.728+00:00 [39m [36m[ws] [39m [36m→ event tick seq=83 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:45:07.716+00:00 [39m [36m[ws] [39m [36m→ event tick seq=84 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:45:37.147+00:00 [39m [36m[ws] [39m [36m→ event health seq=85 clients=3 presenceVersion=8 healthVersion=71 [39m
[90m2026-04-06T12:45:37.726+00:00 [39m [36m[ws] [39m [36m→ event tick seq=86 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:46:07.749+00:00 [39m [36m[ws] [39m [36m→ event tick seq=87 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:46:37.126+00:00 [39m [36m[ws] [39m [36m→ event health seq=88 clients=3 presenceVersion=8 healthVersion=72 [39m
[90m2026-04-06T12:46:37.713+00:00 [39m [36m[ws] [39m [36m→ event tick seq=89 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:47:07.709+00:00 [39m [36m[ws] [39m [36m→ event tick seq=90 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:47:37.156+00:00 [39m [36m[ws] [39m [36m→ event health seq=91 clients=3 presenceVersion=8 healthVersion=73 [39m
[90m2026-04-06T12:47:37.734+00:00 [39m [36m[ws] [39m [36m→ event tick seq=92 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:48:07.735+00:00 [39m [36m[ws] [39m [36m→ event tick seq=93 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:48:37.157+00:00 [39m [36m[ws] [39m [36m→ event health seq=94 clients=3 presenceVersion=8 healthVersion=74 [39m
[90m2026-04-06T12:48:37.730+00:00 [39m [36m[ws] [39m [36m→ event tick seq=95 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:49:07.731+00:00 [39m [36m[ws] [39m [36m→ event tick seq=96 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:49:37.183+00:00 [39m [36m[ws] [39m [36m→ event health seq=97 clients=3 presenceVersion=8 healthVersion=75 [39m
[90m2026-04-06T12:49:37.751+00:00 [39m [36m[ws] [39m [36m→ event tick seq=98 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:50:07.718+00:00 [39m [36m[ws] [39m [36m→ event tick seq=99 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:50:37.181+00:00 [39m [36m[ws] [39m [36m→ event health seq=100 clients=3 presenceVersion=8 healthVersion=76 [39m
[90m2026-04-06T12:50:37.747+00:00 [39m [36m[ws] [39m [36m→ event tick seq=101 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:51:07.725+00:00 [39m [36m[ws] [39m [36m→ event tick seq=102 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:51:37.163+00:00 [39m [36m[ws] [39m [36m→ event health seq=103 clients=3 presenceVersion=8 healthVersion=77 [39m
[90m2026-04-06T12:51:37.742+00:00 [39m [36m[ws] [39m [36m→ event tick seq=104 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:52:07.753+00:00 [39m [36m[ws] [39m [36m→ event tick seq=105 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:52:37.202+00:00 [39m [36m[ws] [39m [36m→ event health seq=106 clients=3 presenceVersion=8 healthVersion=78 [39m
[90m2026-04-06T12:52:37.768+00:00 [39m [36m[ws] [39m [36m→ event tick seq=107 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:53:07.760+00:00 [39m [36m[ws] [39m [36m→ event tick seq=108 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:53:37.201+00:00 [39m [36m[ws] [39m [36m→ event health seq=109 clients=3 presenceVersion=8 healthVersion=79 [39m
[90m2026-04-06T12:53:37.754+00:00 [39m [36m[ws] [39m [36m→ event tick seq=110 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:54:07.769+00:00 [39m [36m[ws] [39m [36m→ event tick seq=111 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:54:37.257+00:00 [39m [36m[ws] [39m [36m→ event health seq=112 clients=3 presenceVersion=8 healthVersion=80 [39m
[90m2026-04-06T12:54:37.764+00:00 [39m [36m[ws] [39m [36m→ event tick seq=113 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:55:07.762+00:00 [39m [36m[ws] [39m [36m→ event tick seq=114 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:55:37.152+00:00 [39m [36m[ws] [39m [36m→ event health seq=115 clients=3 presenceVersion=8 healthVersion=81 [39m
[90m2026-04-06T12:55:37.761+00:00 [39m [36m[ws] [39m [36m→ event tick seq=116 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:56:07.772+00:00 [39m [36m[ws] [39m [36m→ event tick seq=117 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:56:37.202+00:00 [39m [36m[ws] [39m [36m→ event health seq=118 clients=3 presenceVersion=8 healthVersion=82 [39m
[90m2026-04-06T12:56:37.765+00:00 [39m [36m[ws] [39m [36m→ event tick seq=119 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:57:07.776+00:00 [39m [36m[ws] [39m [36m→ event tick seq=120 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:57:37.197+00:00 [39m [36m[ws] [39m [36m→ event health seq=121 clients=3 presenceVersion=8 healthVersion=83 [39m
[90m2026-04-06T12:57:37.771+00:00 [39m [36m[ws] [39m [36m→ event tick seq=122 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:58:07.765+00:00 [39m [36m[ws] [39m [36m→ event tick seq=123 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:58:37.180+00:00 [39m [36m[ws] [39m [36m→ event health seq=124 clients=3 presenceVersion=8 healthVersion=84 [39m
[90m2026-04-06T12:58:37.768+00:00 [39m [36m[ws] [39m [36m→ event tick seq=125 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:59:07.777+00:00 [39m [36m[ws] [39m [36m→ event tick seq=126 clients=3 dropIfSlow=true [39m
[90m2026-04-06T12:59:37.188+00:00 [39m [36m[ws] [39m [36m→ event health seq=127 clients=3 presenceVersion=8 healthVersion=85 [39m
[90m2026-04-06T12:59:37.749+00:00 [39m [36m[ws] [39m [36m→ event tick seq=128 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:00:07.759+00:00 [39m [36m[ws] [39m [36m→ event tick seq=129 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:00:37.152+00:00 [39m [36m[ws] [39m [36m→ event health seq=130 clients=3 presenceVersion=8 healthVersion=86 [39m
[90m2026-04-06T13:00:37.752+00:00 [39m [36m[ws] [39m [36m→ event tick seq=131 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:01:07.764+00:00 [39m [36m[ws] [39m [36m→ event tick seq=132 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:01:37.209+00:00 [39m [36m[ws] [39m [36m→ event health seq=133 clients=3 presenceVersion=8 healthVersion=87 [39m
[90m2026-04-06T13:01:37.783+00:00 [39m [36m[ws] [39m [36m→ event tick seq=134 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:02:07.782+00:00 [39m [36m[ws] [39m [36m→ event tick seq=135 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:02:37.217+00:00 [39m [36m[ws] [39m [36m→ event health seq=136 clients=3 presenceVersion=8 healthVersion=88 [39m
[90m2026-04-06T13:02:37.798+00:00 [39m [36m[ws] [39m [36m→ event tick seq=137 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:03:07.787+00:00 [39m [36m[ws] [39m [36m→ event tick seq=138 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:03:37.210+00:00 [39m [36m[ws] [39m [36m→ event health seq=139 clients=3 presenceVersion=8 healthVersion=89 [39m
[90m2026-04-06T13:03:37.793+00:00 [39m [36m[ws] [39m [36m→ event tick seq=140 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:04:07.797+00:00 [39m [36m[ws] [39m [36m→ event tick seq=141 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:04:37.235+00:00 [39m [36m[ws] [39m [36m→ event health seq=142 clients=3 presenceVersion=8 healthVersion=90 [39m
[90m2026-04-06T13:04:37.808+00:00 [39m [36m[ws] [39m [36m→ event tick seq=143 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:05:07.806+00:00 [39m [36m[ws] [39m [36m→ event tick seq=144 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:05:37.152+00:00 [39m [36m[ws] [39m [36m→ event health seq=145 clients=3 presenceVersion=8 healthVersion=91 [39m
[90m2026-04-06T13:05:37.781+00:00 [39m [36m[ws] [39m [36m→ event tick seq=146 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:06:07.820+00:00 [39m [36m[ws] [39m [36m→ event tick seq=147 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:06:37.218+00:00 [39m [36m[ws] [39m [36m→ event health seq=148 clients=3 presenceVersion=8 healthVersion=92 [39m
[90m2026-04-06T13:06:37.815+00:00 [39m [36m[ws] [39m [36m→ event tick seq=149 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:07:07.806+00:00 [39m [36m[ws] [39m [36m→ event tick seq=150 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:07:37.213+00:00 [39m [36m[ws] [39m [36m→ event health seq=151 clients=3 presenceVersion=8 healthVersion=93 [39m
[90m2026-04-06T13:07:37.819+00:00 [39m [36m[ws] [39m [36m→ event tick seq=152 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:08:07.832+00:00 [39m [36m[ws] [39m [36m→ event tick seq=153 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:08:37.224+00:00 [39m [36m[ws] [39m [36m→ event health seq=154 clients=3 presenceVersion=8 healthVersion=94 [39m
[90m2026-04-06T13:08:37.837+00:00 [39m [36m[ws] [39m [36m→ event tick seq=155 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:09:07.842+00:00 [39m [36m[ws] [39m [36m→ event tick seq=156 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:09:37.234+00:00 [39m [36m[ws] [39m [36m→ event health seq=157 clients=3 presenceVersion=8 healthVersion=95 [39m
[90m2026-04-06T13:09:37.845+00:00 [39m [36m[ws] [39m [36m→ event tick seq=158 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:10:07.844+00:00 [39m [36m[ws] [39m [36m→ event tick seq=159 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:10:37.227+00:00 [39m [36m[ws] [39m [36m→ event health seq=160 clients=3 presenceVersion=8 healthVersion=96 [39m
[90m2026-04-06T13:10:37.846+00:00 [39m [36m[ws] [39m [36m→ event tick seq=161 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:11:07.853+00:00 [39m [36m[ws] [39m [36m→ event tick seq=162 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:11:37.232+00:00 [39m [36m[ws] [39m [36m→ event health seq=163 clients=3 presenceVersion=8 healthVersion=97 [39m
[90m2026-04-06T13:11:37.856+00:00 [39m [36m[ws] [39m [36m→ event tick seq=164 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:12:07.848+00:00 [39m [36m[ws] [39m [36m→ event tick seq=165 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:12:37.240+00:00 [39m [36m[ws] [39m [36m→ event health seq=166 clients=3 presenceVersion=8 healthVersion=98 [39m
[90m2026-04-06T13:12:37.856+00:00 [39m [36m[ws] [39m [36m→ event tick seq=167 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:13:07.844+00:00 [39m [36m[ws] [39m [36m→ event tick seq=168 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:13:37.237+00:00 [39m [36m[ws] [39m [36m→ event health seq=169 clients=3 presenceVersion=8 healthVersion=99 [39m
[90m2026-04-06T13:13:37.294+00:00 [39m [36m[ws] [39m [36m→ event heartbeat seq=170 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:13:37.857+00:00 [39m [36m[ws] [39m [36m→ event tick seq=171 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:14:07.855+00:00 [39m [36m[ws] [39m [36m→ event tick seq=172 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:14:37.196+00:00 [39m [36m[ws] [39m [36m→ event health seq=173 clients=3 presenceVersion=8 healthVersion=100 [39m
[90m2026-04-06T13:14:37.861+00:00 [39m [36m[ws] [39m [36m→ event tick seq=174 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:15:07.861+00:00 [39m [36m[ws] [39m [36m→ event tick seq=175 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:15:37.260+00:00 [39m [36m[ws] [39m [36m→ event health seq=176 clients=3 presenceVersion=8 healthVersion=101 [39m
[90m2026-04-06T13:15:37.847+00:00 [39m [36m[ws] [39m [36m→ event tick seq=177 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:16:07.865+00:00 [39m [36m[ws] [39m [36m→ event tick seq=178 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:16:37.255+00:00 [39m [36m[ws] [39m [36m→ event health seq=179 clients=3 presenceVersion=8 healthVersion=102 [39m
[90m2026-04-06T13:16:37.875+00:00 [39m [36m[ws] [39m [36m→ event tick seq=180 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:17:07.877+00:00 [39m [36m[ws] [39m [36m→ event tick seq=181 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:17:37.233+00:00 [39m [36m[ws] [39m [36m→ event health seq=182 clients=3 presenceVersion=8 healthVersion=103 [39m
[90m2026-04-06T13:17:37.880+00:00 [39m [36m[ws] [39m [36m→ event tick seq=183 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:18:07.884+00:00 [39m [36m[ws] [39m [36m→ event tick seq=184 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:18:37.260+00:00 [39m [36m[ws] [39m [36m→ event health seq=185 clients=3 presenceVersion=8 healthVersion=104 [39m
[90m2026-04-06T13:18:37.867+00:00 [39m [36m[ws] [39m [36m→ event tick seq=186 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:19:07.872+00:00 [39m [36m[ws] [39m [36m→ event tick seq=187 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:19:37.253+00:00 [39m [36m[ws] [39m [36m→ event health seq=188 clients=3 presenceVersion=8 healthVersion=105 [39m
[90m2026-04-06T13:19:37.886+00:00 [39m [36m[ws] [39m [36m→ event tick seq=189 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:20:07.879+00:00 [39m [36m[ws] [39m [36m→ event tick seq=190 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:20:37.271+00:00 [39m [36m[ws] [39m [36m→ event health seq=191 clients=3 presenceVersion=8 healthVersion=106 [39m
[90m2026-04-06T13:20:37.899+00:00 [39m [36m[ws] [39m [36m→ event tick seq=192 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:21:07.889+00:00 [39m [36m[ws] [39m [36m→ event tick seq=193 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:21:37.231+00:00 [39m [36m[ws] [39m [36m→ event health seq=194 clients=3 presenceVersion=8 healthVersion=107 [39m
[90m2026-04-06T13:21:37.886+00:00 [39m [36m[ws] [39m [36m→ event tick seq=195 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:22:07.891+00:00 [39m [36m[ws] [39m [36m→ event tick seq=196 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:22:37.261+00:00 [39m [36m[ws] [39m [36m→ event health seq=197 clients=3 presenceVersion=8 healthVersion=108 [39m
[90m2026-04-06T13:22:37.903+00:00 [39m [36m[ws] [39m [36m→ event tick seq=198 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:23:07.898+00:00 [39m [36m[ws] [39m [36m→ event tick seq=199 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:23:37.276+00:00 [39m [36m[ws] [39m [36m→ event health seq=200 clients=3 presenceVersion=8 healthVersion=109 [39m
[90m2026-04-06T13:23:37.908+00:00 [39m [36m[ws] [39m [36m→ event tick seq=201 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:24:07.903+00:00 [39m [36m[ws] [39m [36m→ event tick seq=202 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:24:37.274+00:00 [39m [36m[ws] [39m [36m→ event health seq=203 clients=3 presenceVersion=8 healthVersion=110 [39m
[90m2026-04-06T13:24:37.895+00:00 [39m [36m[ws] [39m [36m→ event tick seq=204 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:25:07.917+00:00 [39m [36m[ws] [39m [36m→ event tick seq=205 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:25:37.273+00:00 [39m [36m[ws] [39m [36m→ event health seq=206 clients=3 presenceVersion=8 healthVersion=111 [39m
[90m2026-04-06T13:25:37.910+00:00 [39m [36m[ws] [39m [36m→ event tick seq=207 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:26:07.909+00:00 [39m [36m[ws] [39m [36m→ event tick seq=208 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:26:37.265+00:00 [39m [36m[ws] [39m [36m→ event health seq=209 clients=3 presenceVersion=8 healthVersion=112 [39m
[90m2026-04-06T13:26:37.912+00:00 [39m [36m[ws] [39m [36m→ event tick seq=210 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:27:07.918+00:00 [39m [36m[ws] [39m [36m→ event tick seq=211 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:27:37.280+00:00 [39m [36m[ws] [39m [36m→ event health seq=212 clients=3 presenceVersion=8 healthVersion=113 [39m
[90m2026-04-06T13:27:37.916+00:00 [39m [36m[ws] [39m [36m→ event tick seq=213 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:28:07.920+00:00 [39m [36m[ws] [39m [36m→ event tick seq=214 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:28:37.273+00:00 [39m [36m[ws] [39m [36m→ event health seq=215 clients=3 presenceVersion=8 healthVersion=114 [39m
[90m2026-04-06T13:28:37.929+00:00 [39m [36m[ws] [39m [36m→ event tick seq=216 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:29:07.897+00:00 [39m [36m[ws] [39m [36m→ event tick seq=217 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:29:37.283+00:00 [39m [36m[ws] [39m [36m→ event health seq=218 clients=3 presenceVersion=8 healthVersion=115 [39m
[90m2026-04-06T13:29:37.893+00:00 [39m [36m[ws] [39m [36m→ event tick seq=219 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:30:07.931+00:00 [39m [36m[ws] [39m [36m→ event tick seq=220 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:30:37.235+00:00 [39m [36m[ws] [39m [36m→ event health seq=221 clients=3 presenceVersion=8 healthVersion=116 [39m
[90m2026-04-06T13:30:37.906+00:00 [39m [36m[ws] [39m [36m→ event tick seq=222 clients=3 dropIfSlow=true [39m
[90m2026-04-06T13:30:51.897+00:00 [39m [36m[ws] [39m [36m→ event presence seq=223 clients=3 dropIfSlow=true presenceVersion=9 healthVersion=116 [39m
[90m2026-04-06T13:30:51.919+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=4184802 handshake=connected lastFrameType=event lastFrameMethod=connect lastFrameId=81ebe7ea-a646-4582-ab7c-60907a27a76f conn=b0dfb4aa…65a9 [39m
[90m2026-04-06T13:30:51.929+00:00 [39m [36m[ws] [39m [36m→ event presence seq=224 clients=2 dropIfSlow=true presenceVersion=10 healthVersion=116 [39m
[90m2026-04-06T13:30:51.944+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=4186517 handshake=connected lastFrameType=ping lastFrameMethod=chat.send lastFrameId=077469f9-5f73-4343-ad8b-56b580089251 conn=bfeaa4b3…0814 [39m
[90m2026-04-06T13:30:51.952+00:00 [39m [36m[ws] [39m [36m→ event presence seq=225 clients=1 dropIfSlow=true presenceVersion=11 healthVersion=116 [39m
[90m2026-04-06T13:30:51.958+00:00 [39m [36m[ws] [39m [36m→ close code=1006 durationMs=4174758 handshake=connected lastFrameType=ping lastFrameMethod=connect lastFrameId=38ca9486-931e-4689-9a41-36b5dc29c5e3 conn=2a212d36…c6c7 [39m
[INFO] Gateway is healthy
[INFO] Connecting WebSocket...
[INFO] WebSocket handshake complete (session: agent:main:main)
[INFO] WebSocket connected (session: agent:main:main)
[INFO] Health RPC: ok=true
[INFO] Ollama Hub starting — waiting for ready signal...
[INFO] Ollama Hub ready — auto-syncing models...
[INFO] Ollama version: 0.19.0
[INFO] Scanning for local GGUF models...
[HUB] Refreshing qwen2.5-0.5b-instruct:q4_k_m params...
[HUB] Registering qwen2.5-0.5b-instruct:q4_k_m...
[DEBUG] model file check: GGUF_OK
[HUB] qwen2.5-0.5b-instruct:q4_k_m — success
[MEM] Pre-load available: 1538MB
[INFO] Ollama provider configured at http://127.0.0.1:11434
[INFO] Ollama Hub stopped.
[WARN] Could not test qwen2.5-0.5b-instruct:q4_k_m loading
[INFO] Registered qwen2.5-0.5b-instruct-q4_k_m as qwen2.5-0.5b-instruct:q4_k_m.
[HUB] Refreshing qwen2.5-1.5b-instruct:q4_k_m params...
[HUB] Registering qwen2.5-1.5b-instruct:q4_k_m...
[DEBUG] model file check: GGUF_OK
[DEBUG] ollama create failed: PlatformException(PROOT_ERROR, Command failed (exit code 1): Error: could not connect to ollama server, run 'ollama serve' to start it
, null, null)
[WARN] Hub rejected qwen2.5-1.5b-instruct:q4_k_m (catalog: qwen2.5-1.5b-instruct-q4_k_m).
[INFO] Hub Sync Done. 1 models available.
[INFO] Ollama provider configured at http://127.0.0.1:11434
[INFO] Ollama Hub starting — waiting for ready signal...
[INFO] Ollama Hub ready — auto-syncing models...
[INFO] Ollama version: 0.19.0
[INFO] Scanning for local GGUF models...
[HUB] Refreshing qwen2.5-0.5b-instruct:q4_k_m params...
[HUB] Registering qwen2.5-0.5b-instruct:q4_k_m...
[DEBUG] model file check: GGUF_OK
[HUB] qwen2.5-0.5b-instruct:q4_k_m — success
[MEM] Pre-load available: 1900MB
[WARN] qwen2.5-0.5b-instruct:q4_k_m failed load test (exit 124): unknown error
[INFO] Registered qwen2.5-0.5b-instruct-q4_k_m as qwen2.5-0.5b-instruct:q4_k_m.
[HUB] Refreshing qwen2.5-1.5b-instruct:q4_k_m params...
[HUB] Registering qwen2.5-1.5b-instruct:q4_k_m...
[DEBUG] model file check: GGUF_OK
[HUB] qwen2.5-1.5b-instruct:q4_k_m — success
[MEM] Pre-load available: 3102MB
[WARN] qwen2.5-1.5b-instruct:q4_k_m failed load test (exit 124): unknown error
[INFO] Registered qwen2.5-1.5b-instruct-q4_k_m as qwen2.5-1.5b-instruct:q4_k_m.
[INFO] Hub Sync Done. 2 models available.
[INFO] Ollama provider configured at http://127.0.0.1:11434
6-04-06T14:11:19.191+00:00 [39m [36m[ws] [39m [36m→ event tick seq=99 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:11:49.172+00:00 [39m [36m[ws] [39m [36m→ event health seq=100 clients=3 presenceVersion=10 healthVersion=37 [39m
[90m2026-04-06T14:11:49.315+00:00 [39m [36m[ws] [39m [36m→ event tick seq=101 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:12:19.339+00:00 [39m [36m[ws] [39m [36m→ event tick seq=102 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:12:49.178+00:00 [39m [36m[ws] [39m [36m→ event health seq=103 clients=3 presenceVersion=10 healthVersion=38 [39m
[90m2026-04-06T14:12:49.293+00:00 [39m [36m[ws] [39m [36m→ event tick seq=104 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:13:19.328+00:00 [39m [36m[ws] [39m [36m→ event tick seq=105 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:13:49.072+00:00 [39m [36m[ws] [39m [36m→ event health seq=106 clients=3 presenceVersion=10 healthVersion=39 [39m
[90m2026-04-06T14:13:49.289+00:00 [39m [36m[ws] [39m [36m→ event tick seq=107 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:14:19.297+00:00 [39m [36m[ws] [39m [36m→ event tick seq=108 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:14:49.187+00:00 [39m [36m[ws] [39m [36m→ event health seq=109 clients=3 presenceVersion=10 healthVersion=40 [39m
[90m2026-04-06T14:14:49.410+00:00 [39m [36m[ws] [39m [36m→ event tick seq=110 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:15:19.347+00:00 [39m [36m[ws] [39m [36m→ event tick seq=111 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:15:49.158+00:00 [39m [36m[ws] [39m [36m→ event health seq=112 clients=3 presenceVersion=10 healthVersion=41 [39m
[90m2026-04-06T14:15:49.309+00:00 [39m [36m[ws] [39m [36m→ event tick seq=113 clients=3 dropIfSlow=true [39m
[90m2026-04-06T14:16:19.475+00:00 [39m [36m[ws] [39m [36m→ event tick seq=114 clients=3 dropIfSlow=true [39m





 Progress confirmed: You are now on Qwen2.5-0.5B-Instruct-Q4_K_M (correct lighter model, 630 M params, 24 layers).
KV cache is now 384 MiB (down from 896 MiB on 1.5B) → this matches the math for the smaller model at full 32k ctx. With your reported 2.3 GB free, memory is no longer the crash cause.
Direct Ollama diagnostic (joke prompt) works perfectly → Ollama server + model + streaming is healthy.
The real problem now:
The OpenClaw gateway embedded agent run is timing out at 600 s with no tokens ever streamed back to the web dashboard or Flutter chat.
You see “streaming…” + blank assistant bubble because the gateway’s [agent/embedded] never emits any assistant message events. The POST /api/chat to Ollama either hangs or returns 500 after the 10-minute gateway timeout.Why this happens (line-by-line from your latest logs)Context is STILL NOT clamped (smoking gun #1) log
llama_context: n_ctx = 32768
llama_kv_cache: CPU KV buffer size = 384.00 MiB (32768 cells...)
Your Modelfile PARAMETER num_ctx hack is not being applied. The transient Modelfile created by the Ollama Hub still only contains FROM ... (no PARAMETER lines). This is why KV is 384 MiB instead of the ~56 MiB you expected at 2048 ctx.
Config is still invalid (smoking gun #2)
From the (mixed old/new) gateway logs you pasted: log
[reload] config reload skipped (invalid config): models.providers.ollama: Unrecognized key: "contextWindow"
[reload] config reload skipped (invalid config): models.providers.ollama: Unrecognized key: "contextWindow", agents.defaults: Unrecognized key: "systemPrompt"
The gateway is ignoring your custom context/systemPrompt settings and falling back to huge defaults. This is why systemPromptChars=27434 (the full 27k cloud prompt) is still being injected.
The agent prompt is still massive (smoking gun #3)
Old diagnostic log (still relevant): log
[context-diag] pre-prompt: ... systemPromptChars=27434 promptChars=143 ...
The 0.5B model is choking on the enormous system + tools + skills + memory injection that OpenClaw was designed for cloud models. The first-token latency becomes huge → gateway times out at 600 s → no assistant tokens ever reach the UI.
Prompt engineering comparison (latest vs previous plawie commit)
The full 27k system prompt + full tool schema is still present. The latest commit did not shorten the prompt for mobile/local Ollama. The gateway is still using the cloud-grade agent profile. That is why the direct simple joke prompt works but the real agent run does not.
Dashboard / UI symptom Blank assistant bubble = UI placeholder waiting for assistant delta events that never arrive.
Even cloud mode would show an intro message if the provider responded; local Ollama never does because the run aborts on timeout.
The 500 / 10m0s on /api/chat is the gateway’s internal call to Ollama failing silently.
Exact fixes you need to apply right now (step-by-step)Step 1: Force low context in the Modelfile (this will drop KV to ~56 MiB)
The Ollama Hub creates a transient Modelfile during registration. Edit the registration code (or the manual Modelfile it uses) and add:dockerfile
FROM "/root/.openclaw/models/qwen2.5-0.5b-instruct-q4_k_m.gguf"
PARAMETER num_ctx 1024 # or 2048 max on your phone
PARAMETER num_thread 1 # you already set 1 thread
PARAMETER num_batch 512
PARAMETER num_gpu 0
Restart the hub after this change. This is the only way llama_context: n_ctx becomes 1024.Step 2: Clean openclaw.json (remove the keys that break reload)
Delete or comment out these two lines (they are no longer valid in the current gateway version):json
"contextWindow": ... // remove entire key under ollama provider
"systemPrompt": "..." // remove or move under a valid agents.defaults section if the schema changed
After saving, the [reload] messages should disappear and your context settings will actually be read.Step 3: Shorten the agent system prompt for mobile (critical)
OpenClaw’s default system prompt is still 27k tokens. For 0.5B you must reduce it drastically. In the gateway config (or the agent profile JSON) set a minimal mobile system prompt:json
"agents": {
  "defaults": {
    "systemPrompt": "You are a helpful mobile assistant. Keep answers short. Use tools only when necessary."
  }
}
This alone will make the pre-prompt drop from 27k → ~800 tokens and let the 0.5B model actually start generating.Step 4: Increase gateway timeout temporarily (for testing)
In the gateway config raise the embedded run timeout to 1800 s (30 min) while you test:json
"agents": { "defaults": { "timeoutMs": 1800000 } }
Step 5: Update the gateway
Your logs still show v2026.3.11 and “update available v2026.4.5”. Run openclaw update inside PRoot — newer versions have better Ollama provider handling and mobile fixes.After these 5 changes:Restart gateway + hub.
Test with the diagnosis widget first (simple prompt).
Then test a real chat send.
You should see assistant tokens appear immediately instead of a 600 s blank bubble.
The 0.5B does work with OpenClaw once the prompt is reduced and context is actually clamped. The KV cache is already acceptable at 384 MiB; after the Modelfile fix it will be even lighter.Do the changes above and paste the new Ollama runner logs + the new gateway logs (after a fresh chat.send). I will confirm the context is now clamped and the assistant response is flowing.We are one config + prompt-size tweak away from a working local OpenClaw on your 8 GB phone.

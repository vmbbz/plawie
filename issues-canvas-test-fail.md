Solar system Convas test results
Cosy <cosychiruka@gmail.com>	Tue, Jun 16, 2026 at 2:34 AM
To: Cosy <cosychiruka@gmail.com>
[native-stdio][gateway] [2026-06-16T00:22:46.887Z] stdout: 2026-06-16T02:22:46.886+02:00 [diagnostic] lane enqueue: lane=main queueSize=1
[native-stdio][gateway] [2026-06-16T00:22:46.889Z] stdout: 2026-06-16T02:22:46.888+02:00 [diagnostic] lane dequeue: lane=main waitMs=3 queueSize=0
[native-stdio][gateway] [2026-06-16T00:22:49.081Z] stdout: 2026-06-16T02:22:49.076+02:00 [agents/harness] agent harness selected
[native-stdio][provider] [2026-06-16T00:22:49.097Z] stdout: 2026-06-16T02:22:49.094+02:00 [agent/embedded] embedded run start: runId=3b8c0df4-6e19-49ac-8f48-1a2bd782986f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter model=openai/gpt-oss-20b:free thinking=off messageChannel=webchat
[native-stdio][gateway] [2026-06-16T00:22:49.898Z] stdout: 2026-06-16T02:22:49.895+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=processing reason="run_started" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:22:49.903Z] stdout: 2026-06-16T02:22:49.900+02:00 [diagnostic] run registered: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=1
[native-stdio][provider] [2026-06-16T00:22:49.923Z] stdout: 2026-06-16T02:22:49.920+02:00 [agent/embedded] embedded run prompt start: runId=3b8c0df4-6e19-49ac-8f48-1a2bd782986f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:22:50.075Z] stdout: 2026-06-16T02:22:50.071+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=8 roleCounts=assistant:4,toolResult:2,user:2 historyTextChars=38270 maxMessageTextChars=17748 historyImageBlocks=0 systemPromptChars=34736 promptChars=20658 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:22:50.088Z] stdout: 2026-06-16T02:22:50.084+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=32555 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=8 unwindowedMessages=8 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:22:50.130Z] stdout: 2026-06-16T02:22:50.126+02:00 [agent/embedded] embedded run agent start: runId=3b8c0df4-6e19-49ac-8f48-1a2bd782986f
[native-stdio][ws] [2026-06-16T00:22:50.151Z] stdout: 2026-06-16T02:22:50.148+02:00 [ws] → event agent seq=per-client clients=2 run=3b8c0df4…986f agent=main session=main stream=lifecycle aseq=1 phase=start
[native-stdio][provider] [2026-06-16T00:22:50.281Z] stdout: 2026-06-16T02:22:50.278+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native-stdio][provider] [2026-06-16T00:22:52.166Z] stdout: 2026-06-16T02:22:52.163+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=1885 contentType=text/event-stream
[native-stdio][ws] [2026-06-16T00:22:58.296Z] stdout: 2026-06-16T02:22:58.295+02:00 [ws] → event agent seq=per-client clients=2 run=3b8c0df4…986f agent=main session=main stream=assistant aseq=2 text=Done
[native-stdio][ws] [2026-06-16T00:22:58.310Z] stdout: 2026-06-16T02:22:58.308+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:22:58.461Z] stdout: 2026-06-16T02:22:58.459+02:00 [ws] → event agent seq=per-client clients=2 run=3b8c0df4…986f agent=main session=main stream=assistant aseq=9 text=Done. I started the bowing 01
[native-stdio][ws] [2026-06-16T00:22:58.483Z] stdout: 2026-06-16T02:22:58.479+02:00 [ws] → event agent seq=per-client clients=2 run=3b8c0df4…986f agent=main session=main stream=assistant aseq=10 text=Done. I started the bowing 01 avatar
[native-stdio][ws] [2026-06-16T00:22:58.498Z] stdout: 2026-06-16T02:22:58.496+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][provider] [2026-06-16T00:22:59.301Z] stdout: 2026-06-16T02:22:59.290+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:22:59.348Z] stdout: 2026-06-16T02:22:59.344+02:00 [ws] → event agent seq=per-client clients=2 run=3b8c0df4…986f agent=main session=main stream=assistant aseq=11 text=Done. I started the bowing 01 avatar gesture
[native-stdio][ws] [2026-06-16T00:22:59.368Z] stdout: 2026-06-16T02:22:59.366+02:00 [ws] → event agent seq=per-client clients=2 run=3b8c0df4…986f agent=main session=main stream=assistant aseq=12 text=Done. I started the bowing 01 avatar gesture.
[native-stdio][ws] [2026-06-16T00:22:59.391Z] stdout: 2026-06-16T02:22:59.386+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:22:59.476Z] stdout: 2026-06-16T02:22:59.474+02:00 [agent/embedded] embedded run agent end: runId=3b8c0df4-6e19-49ac-8f48-1a2bd782986f isError=false
[native-stdio][gateway] [2026-06-16T00:22:59.481Z] stdout: 2026-06-16T02:22:59.479+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:22:59.485Z] stdout: 2026-06-16T02:22:59.483+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][ws] [2026-06-16T00:22:59.503Z] stdout: 2026-06-16T02:22:59.500+02:00 [ws] → event agent seq=per-client clients=2 run=3b8c0df4…986f agent=main session=main stream=lifecycle aseq=13 phase=end
[native-stdio][ws] [2026-06-16T00:22:59.523Z] stdout: 2026-06-16T02:22:59.520+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:22:59.535Z] stdout: 2026-06-16T02:22:59.533+02:00 [agent/embedded] embedded run prompt end: runId=3b8c0df4-6e19-49ac-8f48-1a2bd782986f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=9628
[native-stdio][provider] [2026-06-16T00:22:59.626Z] stderr: 2026-06-16T02:22:59.624+02:00 [agent/embedded] [prompt-cache] cache read dropped 17376 -> 64 for openrouter/openai/gpt-oss-20b:free via boundary-aware:openai-completions; no tracked cache input change
[native-stdio][gateway] [2026-06-16T00:22:59.794Z] stdout: 2026-06-16T02:22:59.792+02:00 [agent/embedded] embedded run done: runId=3b8c0df4-6e19-49ac-8f48-1a2bd782986f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=12901 aborted=false
[native-stdio][gateway] [2026-06-16T00:22:59.923Z] stdout: 2026-06-16T02:22:59.920+02:00 [diagnostic] lane task done: lane=main durationMs=13023 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:22:59.928Z] stdout: 2026-06-16T02:22:59.925+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=13039 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:23:00.766Z] stdout: 2026-06-16T02:23:00.764+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=15857ms
[native-stdio][gateway] [2026-06-16T00:23:00.772Z] stdout: 2026-06-16T02:23:00.770+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=3b8c0df4-6e19-49ac-8f48-1a2bd782986f sessionId=unknown sessionKey=agent:main:main outcome=completed duration=15921ms
[native-stdio][gateway] [2026-06-16T00:23:00.778Z] stdout: 2026-06-16T02:23:00.776+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native-stdio][tts] [2026-06-16T00:23:00.985Z] stdout: 2026-06-16T02:23:00.983+02:00 [ws] ⇄ res ✓ talk.speak 2459ms id=575aef5d…67c0
[native-stdio][provider] [2026-06-16T00:23:03.157Z] stdout: 2026-06-16T02:23:03.146+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:23:04.916Z] stdout: 2026-06-16T02:23:04.912+02:00 [ws] ⇄ res ✓ talk.speak 2231ms id=159f862e…7c60
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:23:14.040Z] stdout: 2026-06-16T02:23:14.035+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][chat] [2026-06-16T00:23:14.890Z] stdout: 2026-06-16T02:23:14.888+02:00 [ws] ⇄ res ✓ chat.send 35ms runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f id=b5906b03…8a45
[native-stdio][gateway] [2026-06-16T00:23:14.907Z] stdout: 2026-06-16T02:23:14.904+02:00 [diagnostic] message received: channel=webchat chatId=unknown messageId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=unknown sessionKey=agent:main:main source=dispatchInboundMessage
[native-stdio][gateway] [2026-06-16T00:23:14.931Z] stdout: 2026-06-16T02:23:14.928+02:00 [diagnostic] message queued: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main source=dispatch queueDepth=1 sessionState=idle
[native-stdio][gateway] [2026-06-16T00:23:14.936Z] stdout: 2026-06-16T02:23:14.933+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=processing reason="message_start" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:23:14.952Z] stdout: 2026-06-16T02:23:14.950+02:00 [diagnostic] message dispatch started: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver
[native-stdio][plugins] [2026-06-16T00:23:15.384Z] stdout: 2026-06-16T02:23:15.382+02:00 [plugins] [hooks] running before_agent_reply (1 handlers, first-claim wins)
[native-stdio][gateway] [2026-06-16T00:23:15.448Z] stdout: 2026-06-16T02:23:15.439+02:00 preflightCompaction check: sessionKey=agent:main:main tokenCount=31493 contextWindow=131072 threshold=107072 serverCompactionThreshold=undefined isHeartbeat=false isCli=false persistedFresh=true transcriptPromptTokens=undefined promptTokensEst=6276 activeTranscriptBytes=undefined maxActiveTranscriptBytes=undefined sizeTrigger=false
[native-stdio][gateway] [2026-06-16T00:23:15.467Z] stdout: 2026-06-16T02:23:15.458+02:00 memoryFlush check: sessionKey=agent:main:main tokenCount=37769 contextWindow=131072 threshold=107072 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=31493 persistedFresh=true promptTokensEst=6276 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=37769 transcriptBytes=79650 forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[native-stdio][gateway] [2026-06-16T00:23:15.472Z] stdout: 2026-06-16T02:23:15.469+02:00 [diagnostic] session turn created: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main agentId=main channel=webchat trigger=user
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:23:16.230Z] stdout: 2026-06-16T02:23:16.227+02:00 [diagnostic] lane enqueue: lane=session:agent:main:main queueSize=1
[native-stdio][gateway] [2026-06-16T00:23:16.235Z] stdout: 2026-06-16T02:23:16.233+02:00 [diagnostic] lane dequeue: lane=session:agent:main:main waitMs=6 queueSize=0
[native-stdio][gateway] [2026-06-16T00:23:16.242Z] stdout: 2026-06-16T02:23:16.238+02:00 [diagnostic] lane enqueue: lane=main queueSize=1
[native-stdio][gateway] [2026-06-16T00:23:16.248Z] stdout: 2026-06-16T02:23:16.244+02:00 [diagnostic] lane dequeue: lane=main waitMs=6 queueSize=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:23:19.000Z] stdout: 2026-06-16T02:23:18.998+02:00 [agents/harness] agent harness selected
[native-stdio][provider] [2026-06-16T00:23:19.011Z] stdout: 2026-06-16T02:23:19.008+02:00 [agent/embedded] embedded run start: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter model=openai/gpt-oss-20b:free thinking=off messageChannel=webchat
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:23:19.744Z] stdout: 2026-06-16T02:23:19.742+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=processing reason="run_started" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:23:19.748Z] stdout: 2026-06-16T02:23:19.746+02:00 [diagnostic] run registered: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=1
[native-stdio][provider] [2026-06-16T00:23:19.759Z] stdout: 2026-06-16T02:23:19.756+02:00 [agent/embedded] embedded run prompt start: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:23:19.889Z] stdout: 2026-06-16T02:23:19.886+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=10 roleCounts=assistant:5,toolResult:2,user:3 historyTextChars=58944 maxMessageTextChars=20629 historyImageBlocks=0 systemPromptChars=34736 promptChars=25103 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:23:19.898Z] stdout: 2026-06-16T02:23:19.895+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=40544 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=10 unwindowedMessages=10 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:23:19.948Z] stdout: 2026-06-16T02:23:19.944+02:00 [agent/embedded] embedded run agent start: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f
[native-stdio][ws] [2026-06-16T00:23:19.974Z] stdout: 2026-06-16T02:23:19.971+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=lifecycle aseq=1 phase=start
[native-stdio][provider] [2026-06-16T00:23:20.085Z] stdout: 2026-06-16T02:23:20.082+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:23:22.449Z] stdout: 2026-06-16T02:23:22.445+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2362 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:23:36.836Z] stdout: 2026-06-16T02:23:36.832+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=2 text=The
[native-stdio][ws] [2026-06-16T00:23:36.857Z] stdout: 2026-06-16T02:23:36.854+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:36.975Z] stdout: 2026-06-16T02:23:36.973+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=31 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/
[native-stdio][error] [2026-06-16T00:23:36.989Z] stdout: 2026-06-16T02:23:36.987+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=32 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/cha
[native-stdio][ws] [2026-06-16T00:23:37.005Z] stdout: 2026-06-16T02:23:37.003+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:37.129Z] stdout: 2026-06-16T02:23:37.126+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=56 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:37.144Z] stdout: 2026-06-16T02:23:37.141+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=57 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:37.159Z] stdout: 2026-06-16T02:23:37.157+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:37.280Z] stdout: 2026-06-16T02:23:37.278+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=83 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:37.294Z] stdout: 2026-06-16T02:23:37.292+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=84 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:37.307Z] stdout: 2026-06-16T02:23:37.305+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][provider] [2026-06-16T00:23:38.031Z] stdout: 2026-06-16T02:23:38.022+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][error] [2026-06-16T00:23:38.068Z] stdout: 2026-06-16T02:23:38.065+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=96 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:38.086Z] stdout: 2026-06-16T02:23:38.083+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=97 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:38.103Z] stdout: 2026-06-16T02:23:38.101+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:38.223Z] stdout: 2026-06-16T02:23:38.221+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=112 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:38.243Z] stdout: 2026-06-16T02:23:38.240+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=113 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:38.258Z] stdout: 2026-06-16T02:23:38.255+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:38.378Z] stdout: 2026-06-16T02:23:38.375+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=152 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:38.394Z] stdout: 2026-06-16T02:23:38.392+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=153 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:38.411Z] stdout: 2026-06-16T02:23:38.408+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native] log stream resumed after rotation or runtime restart
[native-stdio][error] [2026-06-16T00:23:38.534Z] stdout: 2026-06-16T02:23:38.530+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=188 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:38.562Z] stdout: 2026-06-16T02:23:38.558+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=189 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:38.594Z] stdout: 2026-06-16T02:23:38.590+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:38.679Z] stdout: 2026-06-16T02:23:38.677+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=200 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:38.699Z] stdout: 2026-06-16T02:23:38.696+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=201 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:38.732Z] stdout: 2026-06-16T02:23:38.730+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:38.833Z] stdout: 2026-06-16T02:23:38.831+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=237 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:38.851Z] stdout: 2026-06-16T02:23:38.849+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=238 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:38.880Z] stdout: 2026-06-16T02:23:38.877+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:38.985Z] stdout: 2026-06-16T02:23:38.983+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=271 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:39.005Z] stdout: 2026-06-16T02:23:39.002+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=272 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:39.035Z] stdout: 2026-06-16T02:23:39.032+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][error] [2026-06-16T00:23:39.145Z] stdout: 2026-06-16T02:23:39.141+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=288 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:39.172Z] stdout: 2026-06-16T02:23:39.170+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=289 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:39.187Z] stdout: 2026-06-16T02:23:39.185+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:23:39.258Z] stdout: 2026-06-16T02:23:39.255+02:00 [agent/embedded] embedded run agent end: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f isError=false
[native-stdio][gateway] [2026-06-16T00:23:39.262Z] stdout: 2026-06-16T02:23:39.260+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:23:39.267Z] stdout: 2026-06-16T02:23:39.264+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][error] [2026-06-16T00:23:39.281Z] stdout: 2026-06-16T02:23:39.279+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=291 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:39.301Z] stdout: 2026-06-16T02:23:39.299+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=lifecycle aseq=292 phase=end
[native-stdio][ws] [2026-06-16T00:23:39.316Z] stdout: 2026-06-16T02:23:39.314+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:23:39.328Z] stdout: 2026-06-16T02:23:39.326+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:23:39.337Z] stdout: 2026-06-16T02:23:39.335+02:00 [agent/embedded] embedded run prompt end: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=19585
[native-stdio][gateway] [2026-06-16T00:23:39.555Z] stdout: 2026-06-16T02:23:39.553+02:00 [agent/embedded] embedded run done: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=23302 aborted=false
[native-stdio][gateway] [2026-06-16T00:23:39.605Z] stdout: 2026-06-16T02:23:39.603+02:00 [diagnostic] lane task done: lane=main durationMs=23354 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:23:39.608Z] stdout: 2026-06-16T02:23:39.606+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=23369 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:23:39.949Z] stdout: 2026-06-16T02:23:39.944+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=24995ms
[native-stdio][gateway] [2026-06-16T00:23:39.954Z] stdout: 2026-06-16T02:23:39.952+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=unknown sessionKey=agent:main:main outcome=completed duration=25040ms
[native-stdio][gateway] [2026-06-16T00:23:39.956Z] stdout: 2026-06-16T02:23:39.955+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:23:40.565Z] stdout: 2026-06-16T02:23:40.560+02:00 [ws] ⇄ res ✓ talk.speak 3180ms id=bdbdaecf…c993
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:23:44.038Z] stdout: 2026-06-16T02:23:44.032+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=97.8 eventLoopDelayMaxMs=3531.6 eventLoopUtilization=0.356 cpuCoreRatio=0.386 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:23:44.052Z] stdout: 2026-06-16T02:23:44.047+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:23:46.959Z] stdout: 2026-06-16T02:23:46.952+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:23:49.138Z] stdout: 2026-06-16T02:23:49.134+02:00 [ws] ⇄ res ✓ talk.speak 2554ms id=71edcdad…cb7c
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:01.063Z] stdout: 2026-06-16T02:24:01.055+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:24:03.273Z] stdout: 2026-06-16T02:24:03.271+02:00 [ws] ⇄ res ✓ talk.speak 2574ms id=9b4f8be9…d653
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:07.098Z] stdout: 2026-06-16T02:24:07.088+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:24:08.561Z] stdout: 2026-06-16T02:24:08.558+02:00 [ws] ⇄ res ✓ talk.speak 1914ms id=dc61df3f…7134
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:11.172Z] stdout: 2026-06-16T02:24:11.162+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:24:12.733Z] stdout: 2026-06-16T02:24:12.731+02:00 [ws] ⇄ res ✓ talk.speak 1987ms id=783691fa…950a
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:24:14.035Z] stdout: 2026-06-16T02:24:14.031+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:16.738Z] stdout: 2026-06-16T02:24:16.729+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:18.072Z] stdout: 2026-06-16T02:24:18.062+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:18.098Z] stdout: 2026-06-16T02:24:18.095+02:00 [ws] ⇄ res ✗ talk.speak 1756ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=3f1c5780…f1f0
[native-stdio][provider] [2026-06-16T00:24:18.488Z] stdout: 2026-06-16T02:24:18.480+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:19.301Z] stdout: 2026-06-16T02:24:19.298+02:00 [ws] ⇄ res ✓ talk.speak 1176ms id=4b5f5bc8…17bb
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:22.049Z] stdout: 2026-06-16T02:24:22.040+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][provider] [2026-06-16T00:24:23.474Z] stdout: 2026-06-16T02:24:23.453+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:23.496Z] stdout: 2026-06-16T02:24:23.492+02:00 [ws] ⇄ res ✗ talk.speak 1814ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=9a493ffd…04ed
[native-stdio][provider] [2026-06-16T00:24:23.857Z] stdout: 2026-06-16T02:24:23.849+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:24:25.442Z] stdout: 2026-06-16T02:24:25.439+02:00 [ws] ⇄ res ✓ talk.speak 1919ms id=b3b9a44e…8a24
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:28.952Z] stdout: 2026-06-16T02:24:28.945+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:30.137Z] stdout: 2026-06-16T02:24:30.112+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:30.159Z] stdout: 2026-06-16T02:24:30.156+02:00 [ws] ⇄ res ✗ talk.speak 1556ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=33ad9b4c…ec7f
[native-stdio][provider] [2026-06-16T00:24:30.568Z] stdout: 2026-06-16T02:24:30.561+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:24:32.300Z] stdout: 2026-06-16T02:24:32.297+02:00 [ws] ⇄ res ✓ talk.speak 2111ms id=6e253c57…f12b
[native-stdio][provider] [2026-06-16T00:24:33.271Z] stdout: 2026-06-16T02:24:33.264+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][provider] [2026-06-16T00:24:34.230Z] stdout: 2026-06-16T02:24:34.220+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:34.244Z] stdout: 2026-06-16T02:24:34.241+02:00 [ws] ⇄ res ✗ talk.speak 1319ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=599e8ec3…7f8b
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:34.616Z] stdout: 2026-06-16T02:24:34.608+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:35.418Z] stdout: 2026-06-16T02:24:35.415+02:00 [ws] ⇄ res ✓ talk.speak 1144ms id=fd94da91…6bc9
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:38.285Z] stdout: 2026-06-16T02:24:38.277+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:24:40.149Z] stdout: 2026-06-16T02:24:40.144+02:00 [ws] ⇄ res ✓ talk.speak 2204ms id=7e232dac…72bf
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:24:44.043Z] stdout: 2026-06-16T02:24:44.034+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:24:45.812Z] stdout: 2026-06-16T02:24:45.798+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:24:47.673Z] stdout: 2026-06-16T02:24:47.671+02:00 [ws] ⇄ res ✓ talk.speak 2301ms id=8509673a…2112
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:25:02.591Z] stdout: 2026-06-16T02:25:02.581+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:25:04.426Z] stdout: 2026-06-16T02:25:04.418+02:00 [ws] ⇄ res ✓ talk.speak 2272ms id=d80b1e11…e6ce
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:25:09.099Z] stdout: 2026-06-16T02:25:09.085+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:25:11.777Z] stdout: 2026-06-16T02:25:11.771+02:00 [ws] ⇄ res ✓ talk.speak 3246ms id=b7dcfda5…6a47
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:25:14.047Z] stdout: 2026-06-16T02:25:14.044+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:25:27.658Z] stdout: 2026-06-16T02:25:27.648+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:25:30.151Z] stdout: 2026-06-16T02:25:30.149+02:00 [ws] ⇄ res ✓ talk.speak 3087ms id=eeb1cff3…1496
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:25:35.422Z] stdout: 2026-06-16T02:25:35.412+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:25:36.350Z] stdout: 2026-06-16T02:25:36.344+02:00 [ws] ⇄ res ✓ talk.speak 1562ms id=f0884e70…0f7d
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:25:39.479Z] stdout: 2026-06-16T02:25:39.472+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:25:40.270Z] stdout: 2026-06-16T02:25:40.268+02:00 [ws] ⇄ res ✓ agents.list 17ms id=eb5b47b2…fd06
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:25:41.253Z] stdout: 2026-06-16T02:25:41.247+02:00 [ws] ⇄ res ✓ talk.speak 2365ms id=1c265a95…128a
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:25:44.034Z] stdout: 2026-06-16T02:25:44.031+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:25:48.489Z] stdout: 2026-06-16T02:25:48.477+02:00 TTS: starting with provider openrouter, fallbacks: none
[native] log stream resumed after rotation or runtime restart
[native-stdio][tts] [2026-06-16T00:25:49.844Z] stdout: 2026-06-16T02:25:49.825+02:00 [ws] ⇄ res ✓ talk.speak 2303ms id=8428f404…d335
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:26:14.040Z] stdout: 2026-06-16T02:26:14.035+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=24.3 eventLoopDelayMaxMs=1014.5 eventLoopUtilization=0.062 cpuCoreRatio=0.07 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:26:14.050Z] stdout: 2026-06-16T02:26:14.046+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:26:44.056Z] stdout: 2026-06-16T02:26:44.048+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:27:14.032Z] stdout: 2026-06-16T02:27:14.030+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:27:23.623Z] stdout: 2026-06-16T02:27:23.622+02:00 [ws] ⇄ res ✓ agents.list 6ms id=6b6a41fc…a568
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:27:44.040Z] stdout: 2026-06-16T02:27:44.035+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:28:14.078Z] stdout: 2026-06-16T02:28:14.052+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:29:14.049Z] stdout: 2026-06-16T02:29:14.044+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.6 eventLoopDelayMaxMs=1836.1 eventLoopUtilization=0.077 cpuCoreRatio=0.054 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:29:14.066Z] stdout: 2026-06-16T02:29:14.061+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:29:41.473Z] stdout: 2026-06-16T02:29:41.471+02:00 [ws] ⇄ res ✓ agents.list 26ms id=d9b8c45d…ecc3
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:29:44.039Z] stdout: 2026-06-16T02:29:44.036+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[DEBUG] Probing gateway config for auth token...
[INFO] Gateway auth token acquired from config.
[native-stdio][error] [2026-06-16T00:23:39.145Z] stdout: 2026-06-16T02:23:39.141+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=288 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][error] [2026-06-16T00:23:39.172Z] stdout: 2026-06-16T02:23:39.170+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=289 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:39.187Z] stdout: 2026-06-16T02:23:39.185+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][gateway] [2026-06-16T00:23:39.258Z] stdout: 2026-06-16T02:23:39.255+02:00 [agent/embedded] embedded run agent end: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f isError=false
[native-stdio][gateway] [2026-06-16T00:23:39.262Z] stdout: 2026-06-16T02:23:39.260+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=idle reason="run_completed" queueDepth=0
[native-stdio][gateway] [2026-06-16T00:23:39.267Z] stdout: 2026-06-16T02:23:39.264+02:00 [diagnostic] run cleared: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=0
[native-stdio][error] [2026-06-16T00:23:39.281Z] stdout: 2026-06-16T02:23:39.279+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=assistant aseq=291 text=The stocks skill ran but failed: Traceback (most recent call last): File "/data/data/com.nxg.openclawproot/files/chaquopy/AssetFinder/app/openclaw_python_runne…
[native-stdio][ws] [2026-06-16T00:23:39.301Z] stdout: 2026-06-16T02:23:39.299+02:00 [ws] → event agent seq=per-client clients=2 run=f6d5d18a…ad9f agent=main session=main stream=lifecycle aseq=292 phase=end
[native-stdio][ws] [2026-06-16T00:23:39.316Z] stdout: 2026-06-16T02:23:39.314+02:00 [ws] → event chat seq=per-client clients=2 dropIfSlow=true
[native-stdio][ws] [2026-06-16T00:23:39.328Z] stdout: 2026-06-16T02:23:39.326+02:00 [ws] → event chat seq=per-client clients=2
[native-stdio][gateway] [2026-06-16T00:23:39.337Z] stdout: 2026-06-16T02:23:39.335+02:00 [agent/embedded] embedded run prompt end: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=19585
[native-stdio][gateway] [2026-06-16T00:23:39.555Z] stdout: 2026-06-16T02:23:39.553+02:00 [agent/embedded] embedded run done: runId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 durationMs=23302 aborted=false
[native-stdio][gateway] [2026-06-16T00:23:39.605Z] stdout: 2026-06-16T02:23:39.603+02:00 [diagnostic] lane task done: lane=main durationMs=23354 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:23:39.608Z] stdout: 2026-06-16T02:23:39.606+02:00 [diagnostic] lane task done: lane=session:agent:main:main durationMs=23369 active=0 queued=0
[native-stdio][gateway] [2026-06-16T00:23:39.949Z] stdout: 2026-06-16T02:23:39.944+02:00 [diagnostic] message dispatch completed: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver outcome=completed duration=24995ms
[native-stdio][gateway] [2026-06-16T00:23:39.954Z] stdout: 2026-06-16T02:23:39.952+02:00 [diagnostic] message processed: channel=webchat chatId=unknown messageId=f6d5d18a-54b2-426b-8aab-262bd94ead9f sessionId=unknown sessionKey=agent:main:main outcome=completed duration=25040ms
[native-stdio][gateway] [2026-06-16T00:23:39.956Z] stdout: 2026-06-16T02:23:39.955+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=idle reason="message_completed" queueDepth=0
[native-stdio][tts] [2026-06-16T00:23:40.565Z] stdout: 2026-06-16T02:23:40.560+02:00 [ws] ⇄ res ✓ talk.speak 3180ms id=bdbdaecf…c993
[native-stdio][warn] [2026-06-16T00:23:44.038Z] stdout: 2026-06-16T02:23:44.032+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=97.8 eventLoopDelayMaxMs=3531.6 eventLoopUtilization=0.356 cpuCoreRatio=0.386 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:23:44.052Z] stdout: 2026-06-16T02:23:44.047+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:23:46.959Z] stdout: 2026-06-16T02:23:46.952+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:23:49.138Z] stdout: 2026-06-16T02:23:49.134+02:00 [ws] ⇄ res ✓ talk.speak 2554ms id=71edcdad…cb7c
[native-stdio][provider] [2026-06-16T00:24:01.063Z] stdout: 2026-06-16T02:24:01.055+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:03.273Z] stdout: 2026-06-16T02:24:03.271+02:00 [ws] ⇄ res ✓ talk.speak 2574ms id=9b4f8be9…d653
[native-stdio][provider] [2026-06-16T00:24:07.098Z] stdout: 2026-06-16T02:24:07.088+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:08.561Z] stdout: 2026-06-16T02:24:08.558+02:00 [ws] ⇄ res ✓ talk.speak 1914ms id=dc61df3f…7134
[native-stdio][provider] [2026-06-16T00:24:11.172Z] stdout: 2026-06-16T02:24:11.162+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:12.733Z] stdout: 2026-06-16T02:24:12.731+02:00 [ws] ⇄ res ✓ talk.speak 1987ms id=783691fa…950a
[native-stdio][gateway] [2026-06-16T00:24:14.035Z] stdout: 2026-06-16T02:24:14.031+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:24:16.738Z] stdout: 2026-06-16T02:24:16.729+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][provider] [2026-06-16T00:24:18.072Z] stdout: 2026-06-16T02:24:18.062+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:18.098Z] stdout: 2026-06-16T02:24:18.095+02:00 [ws] ⇄ res ✗ talk.speak 1756ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=3f1c5780…f1f0
[native-stdio][provider] [2026-06-16T00:24:18.488Z] stdout: 2026-06-16T02:24:18.480+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:19.301Z] stdout: 2026-06-16T02:24:19.298+02:00 [ws] ⇄ res ✓ talk.speak 1176ms id=4b5f5bc8…17bb
[native-stdio][provider] [2026-06-16T00:24:22.049Z] stdout: 2026-06-16T02:24:22.040+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][provider] [2026-06-16T00:24:23.474Z] stdout: 2026-06-16T02:24:23.453+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:23.496Z] stdout: 2026-06-16T02:24:23.492+02:00 [ws] ⇄ res ✗ talk.speak 1814ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=9a493ffd…04ed
[native-stdio][provider] [2026-06-16T00:24:23.857Z] stdout: 2026-06-16T02:24:23.849+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:25.442Z] stdout: 2026-06-16T02:24:25.439+02:00 [ws] ⇄ res ✓ talk.speak 1919ms id=b3b9a44e…8a24
[native-stdio][provider] [2026-06-16T00:24:28.952Z] stdout: 2026-06-16T02:24:28.945+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][provider] [2026-06-16T00:24:30.137Z] stdout: 2026-06-16T02:24:30.112+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:30.159Z] stdout: 2026-06-16T02:24:30.156+02:00 [ws] ⇄ res ✗ talk.speak 1556ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=33ad9b4c…ec7f
[native-stdio][provider] [2026-06-16T00:24:30.568Z] stdout: 2026-06-16T02:24:30.561+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:32.300Z] stdout: 2026-06-16T02:24:32.297+02:00 [ws] ⇄ res ✓ talk.speak 2111ms id=6e253c57…f12b
[native-stdio][provider] [2026-06-16T00:24:33.271Z] stdout: 2026-06-16T02:24:33.264+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][provider] [2026-06-16T00:24:34.230Z] stdout: 2026-06-16T02:24:34.220+02:00 TTS: primary provider openrouter failed (OpenRouter TTS API error: malformed audio response); no fallback providers configured.
[native-stdio][provider] [2026-06-16T00:24:34.244Z] stdout: 2026-06-16T02:24:34.241+02:00 [ws] ⇄ res ✗ talk.speak 1319ms errorCode=UNAVAILABLE errorMessage=TTS conversion failed: openrouter: OpenRouter TTS API error: malformed audio response id=599e8ec3…7f8b
[native-stdio][provider] [2026-06-16T00:24:34.616Z] stdout: 2026-06-16T02:24:34.608+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:35.418Z] stdout: 2026-06-16T02:24:35.415+02:00 [ws] ⇄ res ✓ talk.speak 1144ms id=fd94da91…6bc9
[native-stdio][provider] [2026-06-16T00:24:38.285Z] stdout: 2026-06-16T02:24:38.277+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:40.149Z] stdout: 2026-06-16T02:24:40.144+02:00 [ws] ⇄ res ✓ talk.speak 2204ms id=7e232dac…72bf
[native-stdio][gateway] [2026-06-16T00:24:44.043Z] stdout: 2026-06-16T02:24:44.034+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:24:45.812Z] stdout: 2026-06-16T02:24:45.798+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:24:47.673Z] stdout: 2026-06-16T02:24:47.671+02:00 [ws] ⇄ res ✓ talk.speak 2301ms id=8509673a…2112
[native-stdio][provider] [2026-06-16T00:25:02.591Z] stdout: 2026-06-16T02:25:02.581+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:25:04.426Z] stdout: 2026-06-16T02:25:04.418+02:00 [ws] ⇄ res ✓ talk.speak 2272ms id=d80b1e11…e6ce
[native-stdio][provider] [2026-06-16T00:25:09.099Z] stdout: 2026-06-16T02:25:09.085+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:25:11.777Z] stdout: 2026-06-16T02:25:11.771+02:00 [ws] ⇄ res ✓ talk.speak 3246ms id=b7dcfda5…6a47
[native-stdio][gateway] [2026-06-16T00:25:14.047Z] stdout: 2026-06-16T02:25:14.044+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:25:27.658Z] stdout: 2026-06-16T02:25:27.648+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:25:30.151Z] stdout: 2026-06-16T02:25:30.149+02:00 [ws] ⇄ res ✓ talk.speak 3087ms id=eeb1cff3…1496
[native-stdio][provider] [2026-06-16T00:25:35.422Z] stdout: 2026-06-16T02:25:35.412+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:25:36.350Z] stdout: 2026-06-16T02:25:36.344+02:00 [ws] ⇄ res ✓ talk.speak 1562ms id=f0884e70…0f7d
[native-stdio][provider] [2026-06-16T00:25:39.479Z] stdout: 2026-06-16T02:25:39.472+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][ws] [2026-06-16T00:25:40.270Z] stdout: 2026-06-16T02:25:40.268+02:00 [ws] ⇄ res ✓ agents.list 17ms id=eb5b47b2…fd06
[native-stdio][tts] [2026-06-16T00:25:41.253Z] stdout: 2026-06-16T02:25:41.247+02:00 [ws] ⇄ res ✓ talk.speak 2365ms id=1c265a95…128a
[native-stdio][gateway] [2026-06-16T00:25:44.034Z] stdout: 2026-06-16T02:25:44.031+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:25:48.489Z] stdout: 2026-06-16T02:25:48.477+02:00 TTS: starting with provider openrouter, fallbacks: none
[native-stdio][tts] [2026-06-16T00:25:49.844Z] stdout: 2026-06-16T02:25:49.825+02:00 [ws] ⇄ res ✓ talk.speak 2303ms id=8428f404…d335
[native-stdio][warn] [2026-06-16T00:26:14.040Z] stdout: 2026-06-16T02:26:14.035+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=24.3 eventLoopDelayMaxMs=1014.5 eventLoopUtilization=0.062 cpuCoreRatio=0.07 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:26:14.050Z] stdout: 2026-06-16T02:26:14.046+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:26:44.056Z] stdout: 2026-06-16T02:26:44.048+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:27:14.032Z] stdout: 2026-06-16T02:27:14.030+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:27:23.623Z] stdout: 2026-06-16T02:27:23.622+02:00 [ws] ⇄ res ✓ agents.list 6ms id=6b6a41fc…a568
[native-stdio][gateway] [2026-06-16T00:27:44.040Z] stdout: 2026-06-16T02:27:44.035+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][gateway] [2026-06-16T00:28:14.078Z] stdout: 2026-06-16T02:28:14.052+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][warn] [2026-06-16T00:29:14.049Z] stdout: 2026-06-16T02:29:14.044+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=23.6 eventLoopDelayMaxMs=1836.1 eventLoopUtilization=0.077 cpuCoreRatio=0.054 active=0 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms
[native-stdio][gateway] [2026-06-16T00:29:14.066Z] stdout: 2026-06-16T02:29:14.061+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native-stdio][ws] [2026-06-16T00:29:41.473Z] stdout: 2026-06-16T02:29:41.471+02:00 [ws] ⇄ res ✓ agents.list 26ms id=d9b8c45d…ecc3
[native-stdio][gateway] [2026-06-16T00:29:44.039Z] stdout: 2026-06-16T02:29:44.036+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=0 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][chat] [2026-06-16T00:30:05.086Z] stdout: 2026-06-16T02:30:05.082+02:00 [ws] ⇄ res ✓ chat.send 62ms runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 id=9ecd5e77…4633
[native-stdio][gateway] [2026-06-16T00:30:05.113Z] stdout: 2026-06-16T02:30:05.110+02:00 [diagnostic] message received: channel=webchat chatId=unknown messageId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=unknown sessionKey=agent:main:main source=dispatchInboundMessage
[native-stdio][gateway] [2026-06-16T00:30:05.177Z] stdout: 2026-06-16T02:30:05.175+02:00 [diagnostic] message queued: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main source=dispatch queueDepth=1 sessionState=idle
[native-stdio][gateway] [2026-06-16T00:30:05.184Z] stdout: 2026-06-16T02:30:05.180+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=idle new=processing reason="message_start" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:30:05.207Z] stdout: 2026-06-16T02:30:05.205+02:00 [diagnostic] message dispatch started: channel=webchat sessionId=unknown sessionKey=agent:main:main source=replyResolver
[native-stdio][plugins] [2026-06-16T00:30:05.723Z] stdout: 2026-06-16T02:30:05.721+02:00 [plugins] [hooks] running before_agent_reply (1 handlers, first-claim wins)
[native-stdio][gateway] [2026-06-16T00:30:05.846Z] stdout: 2026-06-16T02:30:05.833+02:00 preflightCompaction check: sessionKey=agent:main:main tokenCount=37572 contextWindow=131072 threshold=107072 serverCompactionThreshold=undefined isHeartbeat=false isCli=false persistedFresh=true transcriptPromptTokens=undefined promptTokensEst=4442 activeTranscriptBytes=undefined maxActiveTranscriptBytes=undefined sizeTrigger=false
[native-stdio][gateway] [2026-06-16T00:30:05.874Z] stdout: 2026-06-16T02:30:05.861+02:00 memoryFlush check: sessionKey=agent:main:main tokenCount=42014 contextWindow=131072 threshold=107072 isHeartbeat=false isCli=false memoryFlushWritable=true compactionCount=0 memoryFlushCompactionCount=undefined persistedPromptTokens=37572 persistedFresh=true promptTokensEst=4442 transcriptPromptTokens=undefined transcriptOutputTokens=undefined projectedTokenCount=42014 transcriptBytes=111026 forceFlushTranscriptBytes=2097152 forceFlushByTranscriptSize=false
[native-stdio][gateway] [2026-06-16T00:30:05.885Z] stdout: 2026-06-16T02:30:05.881+02:00 [diagnostic] session turn created: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main agentId=main channel=webchat trigger=user
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:30:06.994Z] stdout: 2026-06-16T02:30:06.992+02:00 [diagnostic] lane enqueue: lane=session:agent:main:main queueSize=1
[native-stdio][gateway] [2026-06-16T00:30:06.999Z] stdout: 2026-06-16T02:30:06.997+02:00 [diagnostic] lane dequeue: lane=session:agent:main:main waitMs=5 queueSize=0
[native-stdio][gateway] [2026-06-16T00:30:07.004Z] stdout: 2026-06-16T02:30:07.002+02:00 [diagnostic] lane enqueue: lane=main queueSize=1
[native-stdio][gateway] [2026-06-16T00:30:07.006Z] stdout: 2026-06-16T02:30:07.005+02:00 [diagnostic] lane dequeue: lane=main waitMs=2 queueSize=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:30:09.758Z] stdout: 2026-06-16T02:30:09.756+02:00 [agents/harness] agent harness selected
[native-stdio][provider] [2026-06-16T00:30:09.778Z] stdout: 2026-06-16T02:30:09.775+02:00 [agent/embedded] embedded run start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter model=openai/gpt-oss-20b:free thinking=off messageChannel=webchat
[native-stdio][gateway] [2026-06-16T00:30:10.691Z] stdout: 2026-06-16T02:30:10.688+02:00 [diagnostic] session state: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 sessionKey=agent:main:main prev=processing new=processing reason="run_started" queueDepth=1
[native-stdio][gateway] [2026-06-16T00:30:10.696Z] stdout: 2026-06-16T02:30:10.694+02:00 [diagnostic] run registered: sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 totalActive=1
[native-stdio][provider] [2026-06-16T00:30:10.735Z] stdout: 2026-06-16T02:30:10.731+02:00 [agent/embedded] embedded run prompt start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 sessionId=cd8e7de7-589f-4530-a40f-e1cf0d7c9a53 provider=openrouter api=openai-completions endpoint=custom route=proxy-like policy=none
[native-stdio][provider] [2026-06-16T00:30:10.914Z] stdout: 2026-06-16T02:30:10.910+02:00 [agent/embedded] [context-diag] pre-prompt: sessionKey=agent:main:main messages=12 roleCounts=assistant:6,toolResult:2,user:4 historyTextChars=85421 maxMessageTextChars=25309 historyImageBlocks=0 systemPromptChars=34736 promptChars=17767 promptImages=0 provider=openrouter/openai/gpt-oss-20b:free sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][provider] [2026-06-16T00:30:10.923Z] stdout: 2026-06-16T02:30:10.920+02:00 [agent/embedded] [context-overflow-precheck] pre-prompt check sessionKey=agent:main:main provider=openrouter/openai/gpt-oss-20b:free route=fits estimatedPromptTokens=47178 pressureSource=transcript_estimate promptBudgetBeforeReserve=111072 overflowTokens=0 toolResultReducibleChars=0 reserveTokens=20000 effectiveReserveTokens=20000 contextTokenBudget=131072 messages=12 unwindowedMessages=12 sessionFile=/data/data/com.nxg.openclawproot/files/native-node-embedded/native-home/.openclaw/agents/main/sessions/cd8e7de7-589f-4530-a40f-e1cf0d7c9a53.jsonl
[native-stdio][gateway] [2026-06-16T00:30:10.990Z] stdout: 2026-06-16T02:30:10.987+02:00 [agent/embedded] embedded run agent start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255
[native-stdio][ws] [2026-06-16T00:30:11.020Z] stdout: 2026-06-16T02:30:11.016+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=lifecycle aseq=1 phase=start
[native-stdio][provider] [2026-06-16T00:30:11.180Z] stdout: 2026-06-16T02:30:11.176+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][warn] [2026-06-16T00:30:14.041Z] stdout: 2026-06-16T02:30:14.038+02:00 [diagnostic] liveness warning: reasons=event_loop_delay interval=30s eventLoopDelayP99Ms=35.8 eventLoopDelayMaxMs=3886 eventLoopUtilization=0.235 cpuCoreRatio=0.262 active=1 waiting=0 queued=0 recentPhases=post-attach.update-check:12ms,sidecars.restart-sentinel:367ms,post-attach.update-sentinel:172ms,sidecars.model-prewarm:5078ms,sidecars.session-locks:519ms,post-ready.maintenance:89ms work=[active=agent:main:main(processing/model_call,q=1,age=3s last=model_call:started)]
[native-stdio][gateway] [2026-06-16T00:30:14.050Z] stdout: 2026-06-16T02:30:14.045+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native-stdio][provider] [2026-06-16T00:30:14.139Z] stdout: 2026-06-16T02:30:14.136+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2960 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:30:28.125Z] stdout: 2026-06-16T02:30:28.122+02:00 [agent/embedded] embedded run tool start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=read toolCallId=chatcmpl-tool-88590522fc62bd9e
[native-stdio][ws] [2026-06-16T00:30:28.141Z] stdout: 2026-06-16T02:30:28.140+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=3
[native-stdio][tools] [2026-06-16T00:30:28.535Z] stdout: 2026-06-16T02:30:28.533+02:00 [agent/embedded] embedded run tool end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=read toolCallId=chatcmpl-tool-88590522fc62bd9e
[native-stdio][ws] [2026-06-16T00:30:28.548Z] stdout: 2026-06-16T02:30:28.546+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=5
[native-stdio][provider] [2026-06-16T00:30:28.604Z] stdout: 2026-06-16T02:30:28.602+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:30:30.827Z] stdout: 2026-06-16T02:30:30.824+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=2222 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:30:44.043Z] stdout: 2026-06-16T02:30:44.037+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:31:05.494Z] stdout: 2026-06-16T02:31:05.492+02:00 [agent/embedded] embedded run tool start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=write toolCallId=chatcmpl-tool-870a61fa0e384e15
[native-stdio][ws] [2026-06-16T00:31:05.517Z] stdout: 2026-06-16T02:31:05.515+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=7
[native-stdio][tools] [2026-06-16T00:31:05.564Z] stdout: 2026-06-16T02:31:05.561+02:00 [agent/embedded] embedded run tool end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=write toolCallId=chatcmpl-tool-870a61fa0e384e15
[native-stdio][ws] [2026-06-16T00:31:05.579Z] stdout: 2026-06-16T02:31:05.577+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=9
[native-stdio][provider] [2026-06-16T00:31:05.673Z] stdout: 2026-06-16T02:31:05.671+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:31:07.613Z] stdout: 2026-06-16T02:31:07.609+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=1938 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][gateway] [2026-06-16T00:31:14.042Z] stdout: 2026-06-16T02:31:14.038+02:00 [diagnostic] heartbeat: webhooks=0/0/0 active=1 waiting=0 queued=0
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:31:17.485Z] stdout: 2026-06-16T02:31:17.482+02:00 [agent/embedded] embedded run tool start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=canvas toolCallId=chatcmpl-tool-9bff322eb32c312f
[native-stdio][ws] [2026-06-16T00:31:17.506Z] stdout: 2026-06-16T02:31:17.505+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=11
[native] log stream resumed after rotation or runtime restart
[native-stdio][ws] [2026-06-16T00:31:17.916Z] stdout: 2026-06-16T02:31:17.915+02:00 [ws] ← open remoteAddr=127.0.0.1 remotePort=42332 localAddr=127.0.0.1 localPort=18789 endpoint=127.0.0.1:42332->127.0.0.1:18789 conn=5125f469…3788
[native-stdio][ws] [2026-06-16T00:31:17.979Z] stdout: 2026-06-16T02:31:17.977+02:00 [ws] ← connect client=gateway-client clientDisplayName=agent version=2026.5.28 mode=backend clientId=gateway-client platform=android auth=token
[native-stdio][ws] [2026-06-16T00:31:18.010Z] stdout: 2026-06-16T02:31:18.007+02:00 [ws] → hello-ok methods=177 events=27 presence=2 stateVersion=4
[native-stdio][ws] [2026-06-16T00:31:18.548Z] stdout: 2026-06-16T02:31:18.546+02:00 [ws] ⇄ res ✓ node.list 223ms id=8e589097…1ea3
[native-stdio][ws] [2026-06-16T00:31:18.592Z] stdout: 2026-06-16T02:31:18.589+02:00 [ws] → event presence seq=per-client clients=3 dropIfSlow=true presenceVersion=5 healthVersion=30
[native-stdio][ws] [2026-06-16T00:31:18.606Z] stdout: 2026-06-16T02:31:18.605+02:00 [ws] → close code=1005 durationMs=673 handshake=connected lastFrameType=req lastFrameMethod=node.list lastFrameId=8e589097-7b89-4f2a-a1f3-0244ae1d1ea3 endpoint=127.0.0.1:42332->127.0.0.1:18789
[native-stdio][tools] [2026-06-16T00:31:18.626Z] stdout: 2026-06-16T02:31:18.616+02:00 tools: canvas failed stack:
[native-stdio][gateway] Error: node required
[native-stdio][gateway] at resolveNodeIdFromNodeList (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/node-resolve-BfsbnGsO.js:87:9)
[native-stdio][gateway] at resolveNodeIdFromList (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/nodes-utils-B2gggsbD.js:70:9)
[native-stdio][tools] at resolveNodeId (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/tool-BskFNSIW.js:23:9)
[native-stdio][tools] at async Object.execute (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/tool-BskFNSIW.js:65:19)
[native-stdio][gateway] at async Object.execute (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/extensions/canvas/index.js:30:31)
[native-stdio][tools] at async execute (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/agent-tools.before-tool-call-CcOZYWx4.js:1142:20)
[native-stdio][tools] at async Object.execute (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/agent-tools-DkIWbsdu.js:87:11)
[native-stdio][tools] at async Object.execute (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/tool-split-CGOn6jBW.js:221:15)
[native-stdio][tools] at async executePreparedToolCall (file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/proxy-r0kl0JEO.js:524:18)
[native-stdio][gateway] at async file:///data/data/com.nxg.openclawproot/files/native-node-embedded/full-openclaw/lib/node_modules/openclaw/dist/proxy-r0kl0JEO.js:445:100
[native-stdio][tools] [2026-06-16T00:31:18.637Z] stderr: 2026-06-16T02:31:18.628+02:00 [tools] canvas failed: node required raw_params={"action":"present","url":"/__openclaw__/canvas/solar_system.html"}
[native-stdio][tools] [2026-06-16T00:31:18.662Z] stdout: 2026-06-16T02:31:18.660+02:00 [agent/embedded] embedded run tool end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=canvas toolCallId=chatcmpl-tool-9bff322eb32c312f
[native-stdio][ws] [2026-06-16T00:31:18.676Z] stdout: 2026-06-16T02:31:18.675+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=13
[native-stdio][provider] [2026-06-16T00:31:18.750Z] stdout: 2026-06-16T02:31:18.748+02:00 [provider-transport-fetch] [model-fetch] start provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free method=POST url=https://openrouter.ai/api/v1/chat/completions timeoutMs=120000 proxy=none policy=custom
[native] log stream resumed after rotation or runtime restart
[native-stdio][provider] [2026-06-16T00:31:21.763Z] stdout: 2026-06-16T02:31:21.760+02:00 [provider-transport-fetch] [model-fetch] response provider=openrouter api=openai-completions model=openai/gpt-oss-20b:free status=200 elapsedMs=3012 contentType=text/event-stream
[native] log stream resumed after rotation or runtime restart
[native-stdio][tools] [2026-06-16T00:31:28.540Z] stdout: 2026-06-16T02:31:28.535+02:00 [agent/embedded] embedded run tool start: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=search toolCallId=chatcmpl-tool-a842019753dd501b
[native-stdio][ws] [2026-06-16T00:31:28.559Z] stdout: 2026-06-16T02:31:28.558+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=15
[native-stdio][tools] [2026-06-16T00:31:28.570Z] stdout: 2026-06-16T02:31:28.568+02:00 [agent/embedded] embedded run tool end: runId=64674d4a-8ebe-473e-aeb4-8864d1aa8255 tool=search toolCallId=chatcmpl-tool-a842019753dd501b
[native-stdio][ws] [2026-06-16T00:31:28.583Z] stdout: 2026-06-16T02:31:28.581+02:00 [ws] → event agent seq=per-client clients=2 run=64674d4a…8255 agent=main session=main stream=item aseq=17
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

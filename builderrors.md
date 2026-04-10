LAST WEEK DISCUSSION WITH GROK::


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

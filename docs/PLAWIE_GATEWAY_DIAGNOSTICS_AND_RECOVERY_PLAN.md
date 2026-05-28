# Plawie Gateway Diagnostics And Recovery Plan

Last updated: 2026-05-28

This document is the current working map for Gateway, provider, session, tool,
and local-model diagnostics.

## What We Know

- OpenClaw Gateway can start, load default skills, pair the Android node, and
  accept chat messages.
- Cloud models should stay on the Gateway lane by default so OpenClaw tools,
  skills, node routing, Talk, dashboard, and diagnostics remain available.
- Direct local NDK chat is a private/offline lane and bypasses Gateway by design.
- The manual NDK bridge uses Gateway as the tool executor but compacts prompts
  before forwarding to fllama.
- Flutter persists visible chat sessions locally.
- Current mobile Gateway chat intentionally uses the proven default session lane;
  arbitrary per-chat Gateway session keys remain disabled until upstream session
  dispatch is stable.

## Current Concern Map

| Area | Symptom | Likely meaning | Action |
| --- | --- | --- | --- |
| Provider context | Error says maximum context exceeded and output tokens are huge | Provider config requested too many output tokens | Fix catalog `maxTokens`/provider config, not the user's model choice first |
| Provider rate limits | OpenRouter free returns 429, or Groq returns 413/TPM | External quota or provider-tier token-per-minute ceiling | Surface provider-specific wording and avoid retry storms |
| Chat timing | UI times out while Gateway later replies | Provider/session prep can outlast UI stream timeout | Capture first-token timing and Gateway run logs |
| Session health | `stale_session_state`, `file lock stale`, `queued_work_without_active_run` | Gateway session lane can wedge | Keep default lane; do not re-enable arbitrary mobile session keys |
| Tool allowlist | Unknown `tools.allow` entries | Config mixed skill/device names into primitive allowlist | Restore bounded mobile policy |
| Tool routing | Model says node/tool missing | Node context, provider tool support, or tool policy issue | Verify paired node id, command declarations, and actual tool schema |
| Talk/TTS | `talk.speak unavailable` | Talk provider not configured | Treat Talk as separate provider setup |
| NDK bridge | Bridge text works but tools do not | Local model may not emit valid tool calls | Check bridge SSE for `tool_calls` before blaming Gateway |
| Memory pressure | Gateway health stalls during local inference | NDK/Gateway contention | Test direct NDK separately from Gateway stability |

## Kimi / OpenRouter Context Lesson

Do not classify a cloud model as "too small" based only on a maximum-context
error. The useful diagnostic is the breakdown:

```text
input tokens + tool tokens + requested output tokens > context window
```

If requested output tokens are near the full context window, the bug is usually
provider config. The current mitigation is catalog-owned safe `maxTokens` values
written into Gateway provider config for every exposed model.

For Groq, also check the provider-tier TPM number. A request can fit the
131,072-token context window but still exceed a 12,000 TPM on-demand org limit
after the full Gateway system prompt and tool schemas are counted.

## Implemented Diagnostics

- `GatewayService` publishes a human-readable `chatActivityStream`.
- Chat mirrors filtered Gateway activity into diagnostics UI.
- Diagnostics filter for chat, node, session, skills, TTS, model, health,
  rate-limit, stale-lock, tools, WebSocket, and liveness events.
- Obvious token/API-key strings are redacted before display.
- ADB watcher scripts can capture device, app/process, screenshot, UI dump,
  raw logcat, filtered logcat, and best-effort Gateway log tails.

## Testing Protocol

Start with Gateway healthy and Android node paired.

1. Send `reply exactly READY`.
   Expected: accepted, first token received, UI gets `READY`.
2. Send `List the phone tools you can use right now. Do not invent tools.`
   Expected: answer reflects available Android node/Gateway tools.
3. Send `Vibrate the phone once briefly.`
   Expected: tool call/result or precise provider/model limitation.
4. Send `Take one photo with the camera and attach it to this chat.`
   Expected: `camera.snap` path or precise permission/tool error.
5. Test Gateway Voice.
   Expected: configured Talk provider speaks, or one clear Talk config error.
6. Test direct local NDK.
   Expected: no Gateway dependency.
7. Test NDK bridge.
   Expected: text works; tool requests round trip only if local model emits
   valid OpenAI tool calls.

## Do Not Do

- Do not route cloud models through direct HTTP by default.
- Do not write device capability slugs or npm skill IDs into `tools.allow`.
- Do not re-enable arbitrary per-chat Gateway sessions until upstream behavior
  is proven stable.
- Do not restart Gateway first for every chat timeout.
- Do not assume chat provider configuration also configures Talk.
- Do not reintroduce Ollama or PRoot `llama-server` for local inference.

## Next Fix Order

1. Verify provider output caps and context breakdowns.
2. Verify Gateway first-token timing with diagnostics and ADB logs.
3. Fix tool routing only after the exact tool schema/error is visible.
4. Fix Talk provider configuration as its own module.
5. Test NDK bridge tools by inspecting whether `tool_calls` were emitted.
6. Only then adjust avatar/chat visuals in small file-scoped patches.

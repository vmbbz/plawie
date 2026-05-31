# Native Owner Chat Loop Tool Continuation Canary

This gate proves embedded native Node can briefly own the production Gateway
port (`18789`), complete one real provider tool loop, and expose the final
provider text as the chat-visible response while PRoot is restored.

It is still diagnostics-only. The full OpenClaw skill/tool universe remains a
promotion blocker: native must preserve the production `~/.openclaw/skills`
registry and Gateway tool policy before it can replace PRoot as the default
runtime.

## Runtime Flow

1. Verify PRoot is healthy on `18789`.
2. Stop PRoot and wait for `18789` to release.
3. Start embedded native Node on `18789`.
4. Accept a production-shaped `chat.send` frame.
5. Force one live OpenRouter `haptic_vibrate` tool call.
6. Execute only the bounded `haptic.vibrate` Dart bridge allowlist.
7. Send the tool result back to OpenRouter.
8. Receive final streamed assistant text.
9. Emit a chat-response frame from native with that final text.
10. Stop native, release `18789`, restart PRoot, and restore native smoke.

## Diagnostic API

```http
POST /api/native-gateway/production-chat-loop-continuation-canary
```

Example:

```json
{
  "model": "openrouter/openai/gpt-oss-20b:free",
  "prompt": "native production chat loop continuation canary: vibrate once and answer"
}
```

## Hidden Chat Commands

```text
/native-chat-loop-owner
/native-chat-loop-continuation-owner
/native-production-chat-loop
/native-chat-tool-loop-owner
/native-tool-chat-loop-owner
native-chat-loop-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-native-chat-loop-tool-continuation-canary
mode: native-production-port-chat-loop-tool-continuation-with-rollback
nativeChatLoopContinuationCanaryOk: true
chatLoopOk: true
chatResponseFrameOk: true
liveToolContinuationCanaryOk: true
continuationOk: true
routeStatus: native_chat_loop_tool_continuation_canary_complete
finishReason: native_chat_loop_tool_continuation_canary_complete
command: haptic.vibrate
resultStatus: vibrated
uiResponseTextChars: >0
chatResponseFrameTextChars: >0
executeParityOk: true
validationOk: true
rollbackHealthOk: true
```

## Skill And Tool Due Diligence

This gate only proves the bounded chat-loop skeleton. It does not claim that
native has promoted all production skills/tools. The known inventory marker is
still the read-only production skill registry from phase 22, where native
inspects the real PRoot `~/.openclaw/skills` tree with `skillCount >= 50`.

Next gate: full production skill/tool inventory parity before native promotion.

# Native Owner Chat Response UI Canary

This gate proves native Node can briefly own the production Gateway port
(`18789`), complete one provider-backed chat stream, and surface the native
provider text as the chat-visible canary response while PRoot is restored.

It builds directly on the provider-backed chat canary. The stricter addition is
that the streamed native deltas must be captured into a response payload that
the hidden chat command can display first, before diagnostics metadata.

## Runtime Flow

1. Diagnostics stop native smoke on `18790`.
2. PRoot must be current runtime and healthy on `18789`.
3. Diagnostics stop PRoot and wait for `18789` to release.
4. Native starts on `18789` in production-port canary mode.
5. Native accepts a production-shaped `chat.send` frame at
   `/gateway/chat-provider-live-canary-stream`.
6. Native performs one bounded OpenRouter stream request with no tool schemas.
7. Dart captures the native delta text as the chat-visible canary response.
8. Tool execution remains disabled.
9. Native stops, the port is released, PRoot restarts, and native smoke is
   restored.

## Diagnostic API

```http
POST /api/native-gateway/production-chat-response-ui-canary
```

Example:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production chat response UI canary with PRoot rollback"
}
```

## Hidden Chat Commands

```text
/native-chat-ui-owner
/native-production-chat-ui
/native-ui-chat-owner
/native-chat-response-owner
native-chat-ui-owner
```

The hidden chat command returns the native provider text first. In the expected
green path that visible text is:

```text
native-ok
```

## Expected Green Signal

```text
phase: hidden-production-port-chat-response-ui-canary
mode: native-production-port-chat-response-ui-canary-with-proot-rollback
chatUiCanaryOk: true
uiResponseVisibleOk: true
uiResponseMatchedExpectedText: true
providerBackedChatOk: true
toolExecutionDisabledOk: true
requestHasToolSchemas: false
statusCode: 200
deltaCount: >0
uiResponseTextChars: >0
postLiveGuardOk: true
rollbackHealthOk: true
nativeSmokeRestored: true
```

## Why This Matters

The previous gate proved native can answer. This gate proves that answer can be
handed back through the app's chat-facing response path without promoting
native to default routing and without enabling tools. It is the bridge between
"native can call a provider" and "native can become a real chat runtime."

Next gate: production-port native chat route selection canary with provider
fallback.

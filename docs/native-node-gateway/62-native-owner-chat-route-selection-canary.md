# Native Owner Chat Route Selection Canary

This gate proves the app can make an explicit native chat route decision while
PRoot remains the fallback owner.

The canary does not promote native as the default runtime. It evaluates a
single model/provider request, confirms the request is eligible for the bounded
native production-port canary route, runs that route, and verifies fallback
ownership returns to PRoot afterward.

## Runtime Flow

1. Resolve the requested model and OpenRouter provider config.
2. Build a route decision:
   - selected runtime: `native-node-production-port-canary`
   - selected route: `native-provider-backed-chat-ui-canary`
   - fallback runtime: `proot`
   - fallback route: `proot-provider-chat`
3. Run the production-port chat response UI canary on `18789`.
4. Require visible native response text, no tool schemas, and tool execution
   disabled.
5. Stop native, release `18789`, restart PRoot, and restore native smoke.

## Diagnostic API

```http
POST /api/native-gateway/production-chat-route-selection-canary
```

Example:

```json
{
  "model": "openrouter/auto",
  "prompt": "native production chat route selection canary with provider fallback"
}
```

## Hidden Chat Commands

```text
/native-chat-route-owner
/native-production-chat-route
/native-route-select-owner
/native-chat-route-select-owner
native-chat-route-owner
```

## Expected Green Signal

```text
phase: hidden-production-port-native-chat-route-selection-canary
mode: native-production-port-chat-route-selection-with-proot-fallback
nativeEligible: true
routeSelectionPolicyOk: true
selectedRuntimeId: native-node-production-port-canary
selectedRoute: native-provider-backed-chat-ui-canary
fallbackRuntimeId: proot
fallbackRoute: proot-provider-chat
nativeRouteExecutedOk: true
fallbackAfterCanaryOk: true
executionStillLockedOk: true
chatUiCanaryOk: true
uiResponseVisibleOk: true
providerBackedChatOk: true
toolExecutionDisabledOk: true
requestHasToolSchemas: false
rollbackHealthOk: true
nativeSmokeRestored: true
```

## Why This Matters

The previous gate proved native provider text can be surfaced to chat. This
gate proves the app can choose that native lane deliberately and still keep
PRoot as the post-turn owner and fallback. It is the first promotion-shaped
decision point without changing the default runtime.

Next gate: production-port native provider tool-plan to allowlisted execution
canary.

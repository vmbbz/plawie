# Local NDK Gateway Route Hardening Loose End

Date: 2026-06-02

## Status

Loose end for later production hardening.

This is not a blocker for the native `libnode.so` Gateway cutover. It is a
specific issue in the optional Gateway-to-local-model route:

```text
plawie_ndk/local-llm
```

## What Passed

The latest installed-device test proved:

- native `libnode.so` owns production Gateway port `18789`;
- Qwen 2.5 1.5B starts from the Local LLM page;
- the Dart NDK bridge starts on `127.0.0.1:11435`;
- bridge health returns ready;
- direct OpenAI-compatible HTTP request to the bridge returns `OK`;
- native `openclaw.json` no longer contains stale PRoot `/root/...` paths.

## What Failed

Gateway chat routed to:

```text
plawie_ndk/local-llm
```

reached the bridge (`requestCount` advanced) but the Chat UI timed out after 90
seconds without assistant text.

Because the direct bridge HTTP request returned `OK`, this is not a broken
local model and not a broken fllama runtime. The likely fault class is one of:

- Gateway request shape too heavy for the bridge path despite compacting;
- stream/non-stream mismatch between OpenClaw provider adapter and bridge;
- session/run state waiting for a provider event that the bridge does not emit;
- Chat/Gateway first-token watchdog closing before the bridge response is
  surfaced;
- stale Gateway WebSocket lane after a bridge/provider config transition.

## Production Decision

Do not claim `plawie_ndk/local-llm` Gateway chat is production-ready yet.

Do claim:

- `local-llm/...` direct local NDK inference remains supported;
- native `libnode.so` Gateway is still the intended production owner;
- PRoot removal/default-cutover work can continue;
- NDK bridge-chat stays experimental until this loose end is closed.

## Acceptance Gates

Before promoting `plawie_ndk/local-llm`:

- direct bridge HTTP request returns assistant text;
- Gateway chat request reaches bridge and returns assistant text in Chat;
- streaming and non-streaming bridge requests both complete or one mode is
  explicitly disabled;
- repeated bridge turns do not enter a stale Gateway queue;
- cancellation does not leave the bridge or Gateway session wedged;
- local bridge startup/restart state is visible to users;
- docs say clearly when Local LLM direct mode is different from Gateway bridge
  mode.

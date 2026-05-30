# Native Provider Live Canary

Date: 2026-05-30

Status: explicit diagnostics canary

## Purpose

This phase allows embedded Node to make one tiny OpenRouter chat-completions
request from the native runtime. It is the first phase where the native lane may
touch a provider network.

The production PRoot Gateway remains primary on `127.0.0.1:18789`. Embedded
Node remains isolated on `127.0.0.1:18790`.

## Canary Entry Point

Flutter exposes a hidden chat prefix:

```text
/native-live <message>
```

That prefix sends a production-shaped `chat.send` frame directly to embedded
Node:

```text
POST /gateway/chat-provider-live-canary-stream
```

The request is allowed only when all of these are true:

- Native diagnostics are enabled in the debug build.
- The selected route resolves to OpenRouter.
- The app config has an OpenRouter API key.
- The resolved endpoint is `https://openrouter.ai/.../chat/completions`.

## Cost Guardrails

The live canary intentionally does not attach Plawie's full mobile tool context.
It sends only the hidden-command message text, compacted to 280 characters, and
uses:

```text
stream: true
max_tokens: 32
temperature: 0
```

The canary prompt asks the model to answer exactly `native-ok`. When the UI is
on `openrouter/auto`, the canary uses the catalog's known OpenRouter free
fallback model instead of `auto` so the test validates native token parsing, not
OpenRouter's router choice.

## Stream Contract

The native endpoint emits:

| Event | Meaning |
| --- | --- |
| `ack` | Native parsed the `chat.send` frame and accepted the explicit live canary |
| `provider_request` | Redacted provider request shape and hashes |
| `provider_gate` | Canary blocked before fetch if config/endpoint/provider is invalid |
| `provider_call_started` | Fetch is starting and the provider billing surface may be reached |
| `provider_response` | Provider status and first-byte timing |
| `delta` | Provider text chunks parsed by native Node |
| `provider_error` | Raw provider error body forwarded without generic replacement |
| `provider_parse_warning` | Non-fatal provider chunk parsing warning |
| `end` | Live canary completed |
| `error` | Native stream error frame |

## Pass Condition

A `/native-live` turn passes when:

- The ACK hash matches the local redacted Dart frame hash.
- Logs show `[NATIVE-PROVIDER-LIVE]` activity.
- The request is capped at `maxTokens: 32`.
- Provider response events arrive from embedded Node.
- A successful provider response streams at least one `delta` and ends cleanly.
- Provider errors, if any, surface the raw provider payload in the chat UI.
- No Android/OpenClaw tool execution runs.

## Device Result

Verified on the diagnostics APK:

```text
provider: openrouter
providerModel: openai/gpt-oss-20b:free
statusCode: 200
firstTokenMs: 2603
text: native-ok
finishReason: stop
textChars: 9
```

## Next Gate

The next phase is stream parser parity: compare native provider chunk parsing,
errors, cancellation, timeout, and retry behavior against the production PRoot
Gateway stream behavior before allowing native to handle anything beyond this
explicit canary.

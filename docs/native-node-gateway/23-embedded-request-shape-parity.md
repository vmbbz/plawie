# Embedded Request Shape Parity

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Result

The embedded Node lane can now parse an OpenAI/OpenClaw-style
`/v1/chat/completions` request envelope without routing chat, calling a
provider, or executing tools.

This is still a probe. Production chat remains on the PRoot Gateway.

## Runtime Contract

Safe request flow:

```text
POST /v1/chat/completions on 127.0.0.1:18790
  -> parse JSON body with a bounded body size
  -> summarize model/messages/tools/context shape
  -> return 409 chat_disabled with requestShape metadata
```

The same parser is also exposed at `POST /gateway/request-shape`, which returns
`200` for diagnostics that need a pure shape endpoint.

## What Is Verified

The probe summarizes:

- selected model id;
- streaming flag;
- message count and role counts;
- total/system/user/assistant/tool text characters;
- multimodal image-part count;
- assistant tool-call message count;
- OpenAI `tools` count, names, and schema size;
- whether the system prompt looks like a large Gateway prompt;
- hard safety flags: `acceptedForRouting: false`,
  `providerCallsEnabled: false`, and `executionEnabled: false`.

## What Is Not Enabled

- No provider/model call.
- No native tool execution.
- No Gateway session mutation.
- No production port bind.
- No replacement of PRoot chat routing.

## Device Verification

The diagnostic build posts a realistic canary chat payload to
`/v1/chat/completions` with:

- three messages: `system`, `user`, and `assistant`;
- two tools: `get_battery` and `vibrate`;
- `stream: true`;
- `tool_choice: auto`.

The expected response is `409 chat_disabled` with a valid `requestShape` object.

## Why This Gate Matters

This proves the embedded lane can understand the shape of traffic the real
Gateway receives before it is trusted to do any work. It gives us a measurable
boundary between "can parse the request" and "can safely own the request".

The follow-up gate is documented in
`24-embedded-ws-chat-frame-parity.md`: parse Plawie's actual production
WebSocket `chat.send` frame shape, still without executing native tools or
calling providers.

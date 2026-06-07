# Tools, Skills, And Gateway Intelligence Architecture

Last updated: 2026-06-07

Engineers touching `gateway_service.dart`, `openclaw_service.dart`,
`model_provider_catalog.dart`, `local_llm_service.dart`, or the Skills Manager
screen should read this before changing tool behavior.

## The Four Tool Layers

| Layer | Owner | Purpose | Config / transport |
| --- | --- | --- | --- |
| Gateway primitives | OpenClaw Gateway | Built-in tool groups such as web/files/runtime/nodes | `tools.profile`, `tools.allow`, `tools.deny` |
| OpenClaw/npm skills | OpenClaw skills runtime | Installed skills and Gateway-managed capabilities | Gateway skill loading |
| Android node capabilities | Plawie node / capability bridge | Camera, canvas, xurl HTTP requests, weather, ClawHub metadata, meme image creation, haptics, sensors, flashlight, screen, avatar/TTS actions | `gateway.nodes.allowCommands`, port `8765` |
| Direct local tools | Dart local NDK loop | Lightweight local actions when using `local-llm/...` | `LocalLlmService` native fllama tools |

Do not mix these layers. A string that is valid as an Android node command is
not automatically valid in `tools.allow`.

## Gateway Plugins Are Not The Same As Device Capabilities

Current on-device logs show the same 12 startup Gateway plugins loading under
both PRoot and embedded native Node:

```text
browser
canvas
device-pair
file-transfer
google
memory-core
microsoft
openai
openrouter
phone-control
talk-voice
xai
```

Those plugins are OpenClaw runtime extensions. They are not the same as the
Android node command list and they are not the same as the Skills Manager tool
schemas. Native provider/catalog expansion later loaded 45 provider/catalog
plugins and exposed 177 Gateway methods, but startup plugins, provider plugins,
skill tools, and phone bridge commands remain separate release contracts.

Read the surfaces this way:

| Surface | Where to inspect | Meaning |
| --- | --- | --- |
| Gateway plugins | Gateway log `[plugins] loading ...` lines | OpenClaw extensions loaded by the runtime |
| Skills/tools catalog | Bot Management > Skills > Tools, or `GET /api/tools` on the phone node host | Tool schemas exposed by Plawie's skills service |
| Android node capabilities | Node Device Page, `gateway.nodes.allowCommands` | Concrete phone bridge commands allowed through `AgentSkillServer` |

The current phone-side `/api/tools` catalog contains:

```text
avatar-control
tts-voice
device-node
avatar_overlay
base-chain
twilio-voice
agent-card
molt-launch
valeo-sentinel
moonpay
blogwatcher
session-logs
camsnap
summarize
xurl
```

The current Android node command allowlist contains avatar, camera, canvas,
weather, ClawHub metadata, flashlight/torch, location, screen recording, sensor,
simple meme image creation, blogwatcher RSS/Atom feed checks, camsnap camera
capture, app-owned session log queries, provided-text summarization, xurl HTTP
requests, and haptic commands.
It does not currently prove a generic third-party app launcher or a safe
WhatsApp message-sending command.

`blogwatcher` is a named app-native RSS/Atom adapter for small public feeds. It
uses GET-only HTTP, blocks non-HTTP, loopback, private, and link-local targets,
caps response size, and returns bounded item previews. It is not a persistent
scheduler or notification system.

`session-logs` is a named app-native adapter for app-owned chat sessions. It
lists sessions, reads the active or selected session, and searches bounded
message previews through `session-logs.query`. It does not expose arbitrary log
directories, raw gateway session keys, raw image payloads, full reasoning
blocks, or full tool result payloads.

`xurl.request` is a generic HTTP adapter with a release safety boundary:
absolute `http`/`https` URLs only, bounded response previews, and no loopback
POSTs. GET/HEAD can still read local diagnostics for smoke tests, but POSTs to
local app control endpoints are blocked across `127.*`, `localhost`, `::1`, and
IPv4-mapped loopback aliases, including legacy decimal/octal/hex IPv4 numeric
forms.

`camsnap` is a named skill/tool over the same Android camera capability used by
`device-node`. It preserves visible skill identity for Gateway tool calls while
delegating capture to `camera.snap`. AgentSkillServer omits raw `base64` from
HTTP JSON responses and returns bounded media metadata instead; the chat UI can
attach the captured image through the existing media event bus.

`summarize` is a named app-native extractive adapter for text supplied directly
in the tool input. It is intentionally bounded and deterministic. It does not
replace provider-backed URL, file, or long-document summarization; those should
remain separate provider/config or pack lanes.

## Gateway `tools.allow`

`tools.allow` is a strict Gateway allowlist. OpenClaw applies `tools.profile`
first, then narrows with `allow` and `deny`.

Plawie's current mobile default:

```text
profile: full
allow:
  group:nodes
  group:runtime
  group:sessions
  group:automation
  group:messaging
  group:fs
  group:web
  image
```

Why this shape:

- `minimal` exposes too little for the mobile agent lane.
- An unrestricted/full wildcard can add too much provider context on phones.
- Guessed skill slugs can cause Gateway warnings and hide the tools we need.

## IDs That Must Not Go Into `tools.allow`

| ID family | Correct home |
| --- | --- |
| `twilio`, `crypto`, `base`, `calculator`, `calendar` | OpenClaw skill install/load path |
| `blogwatcher.check`, `session-logs.query`, `camera`, `camsnap`, `canvas`, `weather.current`, `weather.forecast`, `clawhub.search`, `clawhub.info`, `meme-maker.create`, `summarize.text`, `xurl.request`, `flash`, `torch`, `location`, `screen`, `haptic`, `sensor` | Android node command declarations / `gateway.nodes.allowCommands` |
| local NDK helper names | `LocalLlmService` direct local tool schemas |

If Gateway logs `tools.allow allowlist contains unknown entries`, treat the
config as poisoned and let the hardener restore the bounded mobile policy.

## Android Node Commands

Device capabilities belong in node command policy, for example:

```json
{
  "gateway": {
    "nodes": {
      "allowCommands": [
        "camera.snap",
        "camera.clip",
        "camera.list",
        "camsnap",
        "blogwatcher.check",
        "session-logs.query",
        "clawhub.search",
        "clawhub.info",
        "meme-maker.create",
        "canvas.navigate",
        "canvas.eval",
        "canvas.snapshot",
        "flash.on",
        "flash.off",
        "flash.toggle",
        "flash.status",
        "torch.on",
        "torch.off",
        "torch.toggle",
        "torch.status",
        "location.get",
        "screen.record",
        "sensor.read",
        "sensor.list",
        "summarize.text",
        "weather.current",
        "weather.forecast",
        "xurl.request",
        "haptic.vibrate",
        "vibrate"
      ]
    }
  }
}
```

Node command declarations and Gateway tool allowlists are separate contracts.

## Phone-Control Release Boundary

`phone-control` being loaded means the Gateway extension is present. It does
not by itself guarantee that every Android phone action is available.

For an agent request such as opening WhatsApp and sending a message, release-safe
support requires a specific Android bridge command and policy. The safe first
version should be "compose/open with the message prepared, then require user
confirmation." Silent third-party messaging should not be claimed or enabled
without explicit consent, permission review, and a tested rollback-safe command
path.

Until such a command exists in `gateway.nodes.allowCommands` and is backed by
`AgentSkillServer`, the correct behavior is to report the action as unsupported
or to open a user-confirmed compose flow if one is implemented.

## Required Tool Continuation

Some user requests are explicit enough that the app must not wait for a model to
guess the tool. Examples include stocks/ticker prompts and obvious Android phone
commands. These required intents may pre-execute after the Gateway WebSocket
lane is available, but they must still continue through `chat.send`.

Flow:

```text
User prompt
  -> required intent parser selects exact tool
  -> app executes the tool
  -> UI receives TOOL_USE and TOOL_RESULT chunks
  -> app builds bounded continuation context from the tool result
  -> Gateway chat.send receives that context
  -> model returns the final user-facing answer
```

The direct visible tool result is an emergency fallback only. It is returned
when Gateway/model continuation produces no assistant text, not as the normal
success path.

## Direct Local NDK Tools

For `local-llm/...`, Gateway is bypassed. `LocalLlmService` attaches native
fllama tools for selected local actions. If fllama returns `tool_calls`, Dart
executes local tools and recurses with a depth limit of 3.

This path is private and lightweight, but it does not expose the full OpenClaw
Gateway skill universe.

## NDK Gateway Bridge Tool Transport

For `plawie_ndk/local-llm`, Gateway remains the tool owner.

Flow:

```text
Gateway sends tools array
  -> NdkGatewayBridgeService converts to fllama Tool objects
  -> LocalLlmService.chat(..., yieldToolCalls: true)
  -> fllama emits tool_calls
  -> bridge returns OpenAI tool_calls chunk
  -> Gateway executes the tool
  -> Gateway sends tool result back in next request
  -> bridge preserves tool result and asks model to answer
```

The bridge does not execute Gateway tools. It only preserves the OpenAI tool
protocol while shrinking context for the local model.

## Model Policy And Tool Expectations

`ModelProviderCatalog` labels models as `FULL TOOLS`, `VARIABLE TOOLS`, or
`CHAT ONLY`. This controls user expectations and routing. It does not guarantee
the model will make good tool decisions.

Use these rules:

- Cloud known tool-capable models can use the full Gateway lane.
- Router/free routes should be `VARIABLE TOOLS` or `CHAT ONLY` unless the exact
  selected upstream model is known.
- Groq routes are `VARIABLE TOOLS`: they can execute through Gateway, but
  low-tier TPM limits may reject the full system prompt and tool schema payload.
- The NDK bridge is `VARIABLE TOOLS`.
- Direct local NDK is `ON DEVICE`, not full Gateway.

## Regression History To Remember

Two classes of regressions have broken tool access before:

- Writing skill slugs or device names into `tools.allow`, causing Gateway to
  warn about unknown entries and expose zero usable tools.
- Registering device-native skills in a way that overwrote or narrowed the
  Gateway's broader tool context.

The invariant is simple: sanitize config writes, keep layers separate, and test
with a real tool-call prompt after every tool-policy change.

## Required Smoke Tests

1. Cloud model: "List the phone tools you can use right now. Do not invent tools."
2. Cloud model: "Vibrate the phone once briefly."
3. Cloud model: "Open https://example.com in canvas and report the title."
4. Cloud model or direct node smoke: "What is the weather in Johannesburg?"
5. Direct node smoke: search ClawHub for `weather`.
6. Direct node smoke: create a simple meme with top/bottom text.
7. Direct local NDK: "Explain what you can and cannot do in offline mode."
8. NDK bridge: "Try to vibrate the phone once, then answer from the tool result."

For bridge failures, record whether the local model produced valid `tool_calls`
before blaming Gateway.

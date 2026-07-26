# Tools, Skills, And Gateway Intelligence Architecture

Last updated: 2026-07-26

Engineers touching `gateway_service.dart`, `openclaw_service.dart`,
`model_provider_catalog.dart`, `local_llm_service.dart`, or the Skills Manager
screen should read this before changing tool behavior.

## The Four Tool Layers

| Layer | Owner | Purpose | Config / transport |
| --- | --- | --- | --- |
| Gateway primitives | OpenClaw Gateway | Built-in tool groups such as web/files/runtime/nodes | `tools.profile`, `tools.allow`, `tools.deny` |
| OpenClaw/npm skills | OpenClaw skills runtime | Installed skills and Gateway-managed capabilities | Gateway skill loading |
| Android node capabilities | Plawie node / capability bridge | Camera, canvas, xurl HTTP requests, config-gated REST adapters such as GitHub, Google Places, MCPorter, Notion, OpenAI transcription, Discord, Trello, and Slack, weather, ClawHub metadata, meme image creation, haptics, sensors, flashlight, screen, avatar/TTS actions | `gateway.nodes.allowCommands`, port `8765` |
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

The current app-side `/api/tools` catalog definition contains:

```text
avatar-control
tts-voice
device-node
blogwatcher
discord
slack
session-logs
nano-pdf
camsnap
github
gh-issues
goplaces
mcporter
notion
openai-whisper-api
avatar_overlay
base-chain
twilio-voice
agent-card
molt-launch
valeo-sentinel
moonpay
xurl
summarize
trello
```

The current Android node command allowlist contains avatar, camera, canvas,
weather, ClawHub metadata, flashlight/torch, location, screen recording, sensor,
simple meme image creation, blogwatcher RSS/Atom feed checks, camsnap camera
capture, app-owned session log queries, small text-PDF byte extraction,
provided-text summarization, GitHub profile/issue REST adapters, Google Places
Text Search, MCPorter health, Notion search, OpenAI transcription, Discord bot
status, Trello board summaries, Slack bot status/message posting, xurl HTTP
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

`nano-pdf` is a named app-native adapter for small text-based PDFs supplied as
base64 bytes. It extracts bounded text-layer strings through
`nano-pdf.extract`. It does not expose arbitrary file paths and does not claim
OCR, scanned PDFs, encrypted PDFs, complex font/CMap extraction, or full parser
parity.

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

`github` and `gh-issues` are config-gated app-native REST adapters. They remain
`needs_config` until `GITHUB_TOKEN` is present in the Native environment, then
run through `github.user` and `gh-issues.list` without a GitHub CLI binary. The
token is read from Native `.env`, never accepted as tool input, and never
returned in tool results or visible chat chunks.

`goplaces` is a config-gated app-native Google Places Text Search adapter. It
remains `needs_config` until `GOOGLE_PLACES_API_KEY` is present in the Native
environment, then runs through `goplaces.search` without a CLI binary. It uses
an explicit response field mask, bounded result count, and returns only compact
place metadata.

`mcporter` is a config-gated app-native MCPorter REST adapter. It remains
`needs_config` until `MCPORTER_ENDPOINT` and `MCPORTER_TOKEN` are present in the
Native environment, then runs through `mcporter.health` without a CLI binary. It
only checks the configured health endpoint, requires an absolute `http`/`https`
endpoint without userinfo, and never accepts or returns the token.

`notion` is a config-gated app-native Notion search adapter. It remains
`needs_config` until `NOTION_TOKEN` is present in the Native environment, then
runs through `notion.search` without a CLI binary. It returns bounded workspace
metadata and never exposes the token in tool input, tool output, or chat chunks.

`openai-whisper-api` is a config-gated app-native OpenAI transcription adapter.
It remains `needs_config` until `OPENAI_API_KEY` is present in the Native
environment, then runs through `openai-whisper-api.transcribe` without a local
Whisper runtime pack. Tool input is base64 audio bytes plus optional filename,
model, language, and prompt. The adapter caps decoded audio at 25 MB and returns
bounded transcript metadata only.

`discord` is a config-gated app-native Discord REST adapter. It remains
`needs_config` until `DISCORD_BOT_TOKEN` is present in the Native environment,
then runs through `discord.me` without a CLI binary. It reads bounded bot
identity/status metadata and never accepts or returns the bot token.

`trello` is a config-gated app-native Trello REST adapter. It remains
`needs_config` until `TRELLO_API_KEY` and `TRELLO_TOKEN` are present in the
Native environment, then runs through `trello.boards` without a CLI binary. It
returns bounded board summaries only.

`slack` is a config-gated app-native Slack REST adapter. It remains
`needs_config` until `SLACK_BOT_TOKEN` is present in Native `.env` and
`channels.slack` is present in Native `openclaw.json`. It runs through
`slack.me` for bot/workspace identity and `slack.post` for bounded channel
messages using the configured default channel unless an explicit channel is
provided. Tokens and configured channel values are not accepted as secret tool
inputs and are not returned in visible chunks.

`summarize` is a named app-native extractive adapter for text supplied directly
in the tool input. It is intentionally bounded and deterministic. It does not
replace provider-backed URL, file, or long-document summarization; those should
remain separate provider/config or pack lanes.

## Dependency Pack Safety

Android dependency packs are not trusted just because a manifest lists them.
`SkillProvisioningService` validates each pack manifest record through
`DependencyPackManifestEntry` before it can become a selection or install
candidate.

Required manifest fields include:

```text
id
abi / abis
version
source
sizeBytes
sha256
files
smokeCommand
rollback
```

Remote packs must be hash-verified. Remote executable packs also need a
complete signature block. Unsupported ABIs, unsafe install paths, unsafe file
paths, missing file hashes/sizes, missing smoke commands, and missing rollback
plans are rejected before install.

For non-Python executable packs, `smokeCommand` is an executed gate, not a
decorative manifest field. Provisioning resolves the command only inside the
managed Native `.openclaw/bin` directory, requires that command to be advertised
by `provides.bins`, starts it with `runInShell: false`, bounds stdout/stderr,
uses a timeout, and accepts the pack only on exit code `0`. Failed command
smoke removes installed pack files and prevents the dependency receipt from
being written. Python package packs keep the Native Python bridge/import smoke
path instead of trying to execute the shell `python3` shim directly.

Pack selection covers runtimes, Python packages, and managed binaries. Current
native executable packs are remote, signed release artifacts. Setup downloads
only the six required pack IDs, verifies the cached manifest signature and
archive/file hashes, runs native smoke, installs into app-private
`.openclaw/bin` and `.openclaw/lib`, and writes a durable receipt. A receipt is
invalid if its version, archive integrity, smoke result, or required managed
files no longer match.

The current signed lanes are:

```text
android-whisper-runtime: whisper
android-tts-runtime: sherpa-onnx
android-cli-core-pack: blu, eightctl, himalaya, openhue, sonos, wacli
android-vision-media-pack: ffmpeg, gifgrep
android-audio-runtime-pack: songsee
android-terminal-pack: tmux plus required shared libraries
```

Pack filenames follow executable requirements from official `SKILL.md` files,
not necessarily skill IDs: `blucli` requires `blu`, `sonoscli` requires
`sonos`, and `video-frames` requires `ffmpeg`. One advertised executable must
never satisfy an unrelated gate: `songsee` does not satisfy `spotify-player`,
whose real binary gate remains `spogo` or `spotify_player`.

When a known CLI-core executable is required but no validated pack advertises
it, provisioning emits an `android-cli-core-pack:<bin>`
missing-pack action. Android readiness copies this into `/device/health` as
`dependencyGateStatus`, `missingPacks`, `missingBins`, and
`dependencyGateMessage`, so the Skills page can explain the exact missing
payload without pretending the skill is runnable.

The same missing-pack behavior applies to known vision-media executables. If
`video-frames` requires `ffmpeg` or `gifgrep` requires `gifgrep` and no exact
payload is present, provisioning emits an
`android-vision-media-pack:<bin>` remediation that identifies the signed
arm64-v8a dependency pack.

The same missing-pack behavior applies to known audio-runtime executables. If
`songsee` requires `songsee` and no payload is present, provisioning emits
`android-audio-runtime-pack:songsee` with signed-pack remediation. The resolver
intentionally advertises only validated payloads, so installing `songsee` does
not move `spotify-player`.

The readiness scorecard distinguishes static taxonomy from unresolved gates.
`countsByClass.needs_pack` remains the number of manifest entries whose product
class depends on a pack, even after a validated payload satisfies some of
those entries. The Skills page therefore displays `PACK BLOCKERS` from
unready `needs_pack` entries, not the raw taxonomy total. The same rule applies
to `CONFIG BLOCKERS` for unready `needs_config` entries.

The audit layer must prefer structured requirements over noisy examples. When a
skill declares `metadata.openclaw.requires.bins`, the body scanner does not add
extra binary gates from cleanup snippets or tutorial commands. When a skill
declares `metadata.openclaw.requires.anyBins`, the alternatives are enforced as
a group and exposed in `/device/health` as `requiredAnyBins` so the UI can say
"install one of these" instead of pretending one arbitrary binary is the whole
requirement. High-confidence Python command examples such as
`python3 -m debugpy` and `python3 -c "import debugpy"` create Python package
gates; a Python bridge alone is not enough to mark `python-debugpy` ready.

Current remote CLI-core payloads are `openhue`, built from OpenHue CLI commit
`08e940a9cd1c49c2da0a714dc8bb07ee60e9cd21`; `eightctl`, built from
`steipete/eightctl` commit `2f2c73f0a529e9138707a237135fcaadfe56617e`;
`himalaya`, built from `pimalaya/himalaya` commit
`1b70c4e0eaa72dee48353f0211e6cc0f0776fe98`; `sonos`, built from
`steipete/sonoscli` commit
`87f409ab218a19a03cad630458258b291c365d8b`; and `blu`, built from
`steipete/blucli` commit `b5ba7d004448f945acff8ea56034cfe4138be5b6`; and
`wacli`, built from `openclaw/wacli` commit
`be2d22fe9d8ca99bf4c027708ae494e9035fe489`. `openhue`, `eightctl`, `sonos`,
and `blu` are built for `GOOS=android GOARCH=arm64 CGO_ENABLED=0`. `wacli` is
built for `GOOS=android GOARCH=arm64 CGO_ENABLED=1` with the Android NDK C
compiler and `sqlite_fts5` enabled. `himalaya` is built for Rust target
`aarch64-linux-android` with Rust `1.93.0` and the Android NDK C compiler.
Their provenance and deterministic rebuild commands are recorded in
`docs/CLI_CORE_OPENHUE_ANDROID_PAYLOAD.md`,
`docs/CLI_CORE_EIGHTCTL_ANDROID_PAYLOAD.md`,
`docs/CLI_CORE_HIMALAYA_ANDROID_PAYLOAD.md`,
`docs/CLI_CORE_SONOS_ANDROID_PAYLOAD.md`, and
`docs/CLI_CORE_BLU_ANDROID_PAYLOAD.md`, and
`docs/CLI_CORE_WACLI_ANDROID_PAYLOAD.md`. The audited executable set ships in
the signed `android-cli-core-pack` release artifact; future CLI-core tools stay
pack-gated until real Android arm64 binaries are produced and verified.

Current remote vision-media payloads:

```text
ffmpeg: Android arm64 ELF, FFmpeg 8.1.1, LGPL-only build
payload sha256: 5359bcf9ee6b0deff2c9352ab28fde51602bbac75325f3f8b41781a7a4d0a09e
provenance: docs/ANDROID_VISION_MEDIA_FFMPEG_PAYLOAD.md
notice: docs/THIRD_PARTY_NOTICES_FFMPEG.md

gifgrep: Android arm64 ELF, built from steipete/gifgrep
source commit: 72e2cf8fe685e7baa0535c04c3cf2e238ebfd0bc
payload sha256: 431e81de8d46d6fad4b0ca1dbd76e7ce2efb8ca5dd6a9b495be303c60f937098
provenance: docs/ANDROID_VISION_MEDIA_GIFGREP_PAYLOAD.md
notice: docs/THIRD_PARTY_NOTICES_GIFGREP.md
```

The `android-vision-media-pack` release lane and resolver have a real
device-proven FFmpeg payload. The app verifies the signed pack, provisions
`ffmpeg` into managed `.openclaw/bin`, runs `ffmpeg -version`, and reports
`video-frames` ready through `/device/health`.

The same lane has a real device-proven Gifgrep payload. Its version and local
GIF rendering smokes must pass before the receipt is written. Provider search
keys remain mode-specific config and are not hard gates for local GIF
processing.

Current remote audio-runtime payload:

```text
songsee: Android arm64 ELF, built from steipete/songsee
source commit: 41d27ea22771ba447bdfb8b6adac2e6599601634
payload sha256: 98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab
provenance: docs/ANDROID_AUDIO_RUNTIME_SONGSEE_PAYLOAD.md
notice: docs/THIRD_PARTY_NOTICES_SONGSEE.md
```

The signed `android-audio-runtime-pack` lane has a device-proven Songsee
payload. Setup provisions it into managed `.openclaw/bin`, runs native smoke,
and reports `songsee` ready through `/device/health`. `spotify-player` remains
blocked; it is not satisfied by `songsee`.

Current APK-local Python debug payloads:

```text
debugpy: Python wheel, debugpy 1.8.21
payload sha256: b1e37d333663c8851516a47364ef473da127f9caebe4417e6df6f5825a7e9a92
provenance: docs/ANDROID_PYTHON_DEBUG_RUNTIME_PAYLOAD.md
```

The `android-python-debug-runtime` resolver is device-proven. It advertises the
pack only when the APK-copied provisioning roots contain a compatible `debugpy`
wheel, then installs the real wheel into
`.openclaw/runtimes/python/site-packages` and writes both dependency-pack and
wheel receipts. On the 2026-06-09 debug APK smoke, the installed app copied the
`debugpy 1.8.21` wheel into `provisioning/python-debug/wheels`, installed it
into Native Python site-packages, imported it through `/api/python/exec` via the
Chaquopy bridge, and reported `python-debugpy` ready through `/device/health`.

Current remote terminal payload lane:

```text
managed install roots:
  .openclaw/bin
  .openclaw/lib
signed pack:
  android-terminal-pack, tmux only
status:
  device-proven tmux payload
pack version:
  terminal-v1-2026
libraries:
  libandroid-glob.so
  libandroid-support.so
  libevent_core-2.1.so
  libncursesw.so.6
managed smoke:
  LD_LIBRARY_PATH=.openclaw/lib .openclaw/bin/tmux -V -> tmux 3.6a
```

The terminal lane is separate from CLI-core because terminal tools can require
shared libraries. Provisioning copies terminal libraries into managed
`.openclaw/lib`, and dependency-pack smoke commands receive
`OPENCLAW_NATIVE_LIB` plus an `LD_LIBRARY_PATH` that includes that directory.
`tmux` is now backed by pinned Termux aarch64 package artifacts documented in
`docs/ANDROID_TERMINAL_TMUX_PAYLOAD.md` and is ready only after signed-pack
verification installs the binary/libs into `.openclaw` and `tmux -V` passes on
device.

Node-family pack gates are split by runnable artifact, not by ecosystem label.
A future standalone `node` executable belongs to
`android-node-executable-pack` and can only satisfy `node-inspect-debugger`.
`gemini` remains behind `android-gemini-cli-pack` because it needs a real
Gemini CLI and auth/config truth. `coding-agent` remains behind
`android-agent-cli-pack` because it needs a verified Android-safe agent CLI
such as `claude`, `codex`, `opencode`, or `pi`, plus auth/config truth. The
embedded `libnode.so` Native Gateway lane is architecturally valuable, but it
is not a managed shell `node` binary and does not satisfy those pack gates.

### 2026-07-26 remote-pack native verification

The OpenClaw core and Plawie dependency packs are separate delivery lanes.
Fresh setup resolves and verifies the latest stable core from the official
`openclaw/openclaw` release. Plawie releases carry only signed Android
dependency packs; they are not Gateway mirrors.

Live app-sandbox probes verified the release-matching `wacli`, `ffmpeg`,
`songsee`, Whisper, Sherpa executable runtime, and `tmux` payloads as native
Android arm64 binaries when invoked through Android's trusted
`/system/bin/linker64`. Direct app-data `execve` is blocked by SELinux. Both
the Flutter bridge and Gateway `child_process` wrappers apply the linker
invocation; dynamic pack launchers inherit `.openclaw/lib` through
`LD_LIBRARY_PATH`. The signed terminal manifest's `tmux --help` smoke is
normalized to `tmux -V`, because tmux prints help but exits 1 for the former.

Native setup installs the six verified Whisper, TTS-runtime, CLI-core,
vision-media, audio-runtime, and terminal packs. SHA-256/Ed25519 verification,
per-file checks, native smoke, and a durable receipt form one transaction.
Retries skip valid receipts instead of spending data twice. Verified archives
survive a failed smoke for a no-redownload retry and are deleted after success.

Three cards must remain honest native gaps:

- `coding-agent`: the published executable currently writes to Android's
  read-only `/tmp` and fails before its CLI can start;
- `node-inspect-debugger`: requires a standalone `node` executable pack;
- `sherpa-onnx-tts`: the Sherpa executable is native, but the official skill
  also requires the same standalone `node` host.

`skill-creator` is instruction-only and has no executable dependency.
`python-debugpy` uses the bundled Chaquopy/debugpy native bridge and is not
blocked by a standalone Python shell executable.

The `android-audio-runtime-pack` release lane is currently `songsee` only.
Phase 5I audited the remaining blockers and chose `songsee` because it can be
proven offline with a tiny local audio fixture and does not require user
account auth, provider API keys, a large ML model, or standalone Node. The audio
runtime resolver advertises only bins from accepted signed catalog entries.
The `songsee` payload must not satisfy `spotify-player`; Spotify remains
blocked until either `spogo` cookies or `spotify_player` auth/config are
represented truthfully in the UI and runtime audit.

## Gateway `tools.allow`

`tools.allow` is a strict Gateway allowlist. OpenClaw applies `tools.profile`
first, then narrows with `allow` and `deny`.

Plawie's current native-mobile default:

```text
profile: full
allow:
  "*"
```

Why this shape:

- `minimal` exposes too little for the mobile agent lane.
- Group-only allowlists can remove the callable `nodes` tool even while the
  Android node is paired and its commands are healthy.
- The Android command security boundary remains
  `gateway.nodes.allowCommands`; wildcard Gateway tools do not bypass it.
- Guessed skill slugs still do not belong in `tools.allow`.

The wildcard is a deliberate compatibility contract, not an unmeasured
fallback. On 2026-07-26 the installed official OpenClaw `2026.7.1` request was
captured and replayed against OpenRouter with its full system prompt, all 39
real Gateway tool schemas (including `nodes`), `tool_choice: auto`, streaming
usage, and the full configured output budget. The 101 KB request returned HTTP
200. A bounded-group policy must therefore not replace wildcard as a generic
response to a provider 4xx. First replay the exact wildcard request and isolate
the rejected envelope field or model/provider route.

The observed 39-tool surface was:

```text
agents_list, apply_patch, browser, canvas, create_goal, cron, dir_fetch,
dir_list, edit, exec, file_fetch, file_write, gateway, get_goal, image,
image_generate, memory_get, memory_search, message, music_generate, nodes,
pdf, process, read, session_status, sessions_history, sessions_list,
sessions_send, sessions_spawn, sessions_yield, skill_workshop, subagents,
tts, update_goal, update_plan, video_generate, web_fetch, web_search, write
```

## IDs That Must Not Go Into `tools.allow`

| ID family | Correct home |
| --- | --- |
| `twilio`, `crypto`, `base`, `calculator`, `calendar` | OpenClaw skill install/load path |
| `blogwatcher.check`, `session-logs.query`, `nano-pdf.extract`, `github.user`, `gh-issues.list`, `goplaces.search`, `mcporter.health`, `notion.search`, `openai-whisper-api.transcribe`, `discord.me`, `trello.boards`, `slack.me`, `slack.post`, `camera`, `camsnap`, `canvas`, `weather.current`, `weather.forecast`, `clawhub.search`, `clawhub.info`, `meme-maker.create`, `summarize.text`, `xurl.request`, `flash`, `torch`, `location`, `screen`, `haptic`, `sensor` | Android node command declarations / `gateway.nodes.allowCommands` |
| local NDK helper names | `LocalLlmService` direct local tool schemas |

If Gateway logs `tools.allow allowlist contains unknown entries`, treat the
config as poisoned and let the hardener restore the wildcard native-mobile
policy. Do not replace it with guessed skill IDs or group-only entries.

## Live Model Switching

The user-selected model is authoritative. Plawie must not silently replace
OpenRouter router IDs such as `openrouter/openrouter/free` or
`openrouter/auto` with a fixed model.

Persist the canonical model under `agents.defaults.model.primary`, then patch
the active session with:

```json
{
  "method": "sessions.patch",
  "params": {
    "key": "main",
    "model": "openrouter/openrouter/free"
  }
}
```

OpenClaw `2026.7.1` rejects `primaryModel` in `sessions.patch`. The app must
wait for the patch response and must not tear down a healthy WebSocket merely
to apply the supported live-session field.

## Device Health Cost And Freshness

`device.health` includes filesystem skill parity and dependency-pack planning,
so an uncached call is intentionally more expensive than `device.status`.
Plawie coalesces concurrent health calls and caches successful results for 15
seconds. The response includes `healthCache.hit`, `generatedAt`, `ageMs`, and
`ttlMs`.

Callers that have just changed skills, configuration, or dependency packs can
request a fresh audit with `{"refresh": true}`. The loopback HTTP equivalent is
`GET /device/health?refresh=true`. A forced refresh bypasses the cache; ordinary
polling must use the cache to avoid repeatedly rescanning the native runtime.

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
        "nano-pdf.extract",
        "github.user",
        "gh-issues.list",
        "goplaces.search",
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

For host inspection of the phone-owned `AgentSkillServer` bridge on port
`8765`, use:

```powershell
adb -s <device-id> forward tcp:8765 tcp:8765
```

Do not use `adb reverse` for this bridge. Reverse creates a shell-owned listener
on the device side and can prevent `AgentSkillServer` from binding to
`127.0.0.1:8765`.

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
9. After a real vision-media payload is added: managed-bin `ffmpeg -version`
   and a `video-frames` extraction smoke against a tiny fixture.

For bridge failures, record whether the local model produced valid `tool_calls`
before blaming Gateway.

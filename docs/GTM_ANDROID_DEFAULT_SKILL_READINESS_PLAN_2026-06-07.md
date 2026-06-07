# GTM Android Default Skill Readiness Plan

Date: 2026-06-07

This is the operating plan for taking OpenClaw Android from "the launch gate
passes" to "fresh users can understand and use the maximum honest skill set."

The target is not a tiny 1-3 skill pilot. The target is every default OpenClaw
skill that can honestly run on Android, with unsupported desktop/macOS and
manual-compatibility skills removed from the release promise.

## Executive Decision

Native Android remains the default GTM runtime.

PRoot remains explicit compatibility mode only. It is useful for advanced Linux
shell workflows, diagnostics, and rollback, but it must not silently rescue a
Native failure or inflate Android readiness counts.

The release promise is:

```text
Classify every default skill.
Run every Android-viable skill through the Gateway/agent tool loop.
Show exact user gates for config and packs.
Hide or demote skills that are not Android-release safe.
```

## Current Device Truth

Live device health on 2026-06-07 after the Phase 4 milestone install reported:

```text
Classified default manifest: 61
Installed Native workspace skills: 65

Launch-required ready: 13/13
Ready within Android default manifest: 22

ready_required: 13
ready_optional: 6
needs_config: 14
needs_pack: 18
unsupported_on_android: 6
manual_proot_compat: 2
hidden_desktop_only: 2
unexpected_missing_dependency: 0

Release gate: PASS
```

Phase 4 adapter movement now proven on device through `/api/tools` and
`/api/tools/execute`:

```text
blogwatcher: needs_pack -> ready_optional
camsnap: needs_pack -> ready_optional
nano-pdf: needs_pack -> ready_optional
session-logs: needs_config -> ready_optional
summarize: needs_config -> ready_optional
direct execute: summarize, session-logs, nano-pdf, xurl, camsnap, blogwatcher
product-class counts: ready_optional 6, needs_config 14, needs_pack 18
```

The `/api/debug/app-native-chat-tool-smoke` endpoint remains unreliable for
final-response proof. During the milestone smoke it timed out once and then
returned a stale visible response on the next prompt. Do not count that endpoint
as chat proof. The direct registered tool execution path is device-proven, and
the explicit chat tool-use/tool-result chunk route is covered by focused tests.

Read this carefully:

- `61` is the classified default skill manifest.
- `13/13` is the current launch-required pass gate.
- `22 ready` means 13 launch-ready plus 6 app-native ready-optional adapters,
  plus `diagram-maker`, `spotify-player`, and `node-connect` on the current
  device.
- `xurl`, `camsnap`, `summarize`, `blogwatcher`, `session-logs`, and
  `nano-pdf` are now app-native ready optional: usable through
  Gateway-visible tool execution, but not part of the launch-critical gate.
- `node-connect` is manual PRoot compatibility, so it must not count as a
  Native fresh-user Android promise.
- The honest Android-release-relevant ceiling today is:

```text
61 classified
- 6 unsupported_on_android
- 2 manual_proot_compat
- 2 hidden_desktop_only
= 51 Android-release-relevant skills
```

So the real ceiling push is not 13. It is `51/51`, with the understanding that
many of those 51 require user credentials or signed dependency packs before
they can be usable for a fresh user.

## Skill Classes

### Class A: Ready Required

These must work for every fresh Android user without API keys, dependency
packs, or PRoot:

```text
avatar_forge
battery
canvas
clawhub
healthcheck
meme-maker
sensors
skill-creator
spike
taskflow
taskflow-inbox-triage
vibrate
weather
```

Class A acceptance:

- The user can ask from chat.
- The Gateway/agent lane is used.
- Tool-use and tool-result evidence appears in the chat UI for actions.
- No web fallback replaces an explicitly requested skill.
- No automatic PRoot fallback is used.

### Class A2: Ready Optional

These are Android-relevant and usable now, but intentionally not part of the
fresh-user launch-critical gate:

```text
blogwatcher
camsnap
nano-pdf
session-logs
summarize
xurl
```

`blogwatcher` now runs as a bounded app-native RSS/Atom feed checker. It is
exposed as a real `blogwatcher` tool in the native `/api/tools` catalog, routes
`/api/tools/execute` through `AgentSkillServer`, supports explicit prompts like
`blogwatcher https://example.com/feed.xml limit 3`, and blocks non-HTTP,
loopback, private, and link-local feed URLs. It does not claim persistent
watching, notifications, multi-feed state, or full parity with any original CLI
watcher semantics.

`camsnap` now runs as a named app-native camera adapter over the existing
Android `CameraCapability`. It is exposed as a real `camsnap` tool in the
native `/api/tools` catalog, routes `/api/tools/execute` through
`AgentSkillServer`, and keeps explicit chat prompts visible as
`TOOL_USE:camsnap` / `TOOL_RESULT:camsnap` while delegating the actual phone
action to `camera.snap`. It is optional, not launch-required, because camera
permission prompts and user comfort should not block fresh-app launch.

`nano-pdf` now runs as a narrow app-native adapter for small text-based PDFs
supplied as base64 bytes. It is exposed as a real `nano-pdf` tool in the native
`/api/tools` catalog, routes `/api/tools/execute` through `AgentSkillServer`,
and supports explicit test prompts like `nano-pdf base64 <PDF_BASE64>`. It
does not claim OCR, scanned PDFs, encrypted PDFs, arbitrary file paths, complex
font/CMap extraction, or full CLI/parser parity. Those remain verified
pack/OCR lanes.

`session-logs` now runs as a named app-native adapter over app-owned chat
session persistence. It is exposed as a real `session-logs` tool in the native
`/api/tools` catalog, routes `/api/tools/execute` through `AgentSkillServer`,
and supports explicit prompts like `session-logs list`, `session-logs read`,
and `session-logs search gateway limit 5`. It returns bounded metadata and
message previews only. It does not expose arbitrary filesystem roots, raw
gateway session keys, raw image payloads, full reasoning blocks, or the old
`SESSION_LOGS_ROOT` directory-summarization behavior.

`summarize` now runs as a bounded app-native extractive text summarizer for
provided text. It is exposed as a real `summarize` tool in the native
`/api/tools` catalog, routes `/api/tools/execute` through `AgentSkillServer`,
and keeps explicit chat prompts visible as `TOOL_USE:summarize` /
`TOOL_RESULT:summarize`. This does not claim provider-backed URL, file, or
long-document summarization; those can remain future provider/pack lanes.

`xurl` now runs as an app-native Dart HTTP adapter. It is exposed through the
Gateway-visible tool catalog, validates absolute `http`/`https` URLs, supports
`GET`, `HEAD`, and `POST`, emits tool evidence for explicit chat requests, and
returns bounded response metadata instead of requiring `android-cli-core-pack`.
Local loopback POSTs are blocked, including shorthand, IPv4-mapped, and legacy
decimal/octal/hex numeric loopback aliases, so the generic HTTP adapter cannot
POST back into app control endpoints such as `/api/tools/execute`.

### Class B: Needs Config

These are Android-relevant, but require an account, API key, provider, or local
path before use:

```text
1password: OP_SERVICE_ACCOUNT_TOKEN
discord: DISCORD_BOT_TOKEN
gh-issues: GITHUB_TOKEN
github: GITHUB_TOKEN
gog: GOG_ACCOUNT_TOKEN
goplaces: GOOGLE_PLACES_API_KEY
mcporter: MCPORTER_ENDPOINT, MCPORTER_TOKEN
notion: NOTION_TOKEN
openai-whisper-api: OPENAI_API_KEY
ordercli: ORDERCLI_API_KEY
sag: SAG_API_KEY
slack: SLACK_BOT_TOKEN, channels.slack
trello: TRELLO_API_KEY, TRELLO_TOKEN
voice-call: VOICE_CALL_PROVIDER, VOICE_CALL_ACCOUNT
```

Important correction: `needs_config` is a product class, not always the first
runtime gate. On the current device, several Class B skills also report
`missing_native_bin`. For example, a user cannot fix `github` only by entering
`GITHUB_TOKEN` if the Native binary/adapter path is missing.

Therefore the app must show layered gates:

```text
Skill: github
Product class: Needs config
User config: GITHUB_TOKEN
Runtime gate: missing_native_bin
Next action: install verified pack or use app-native adapter
```

### Class C: Needs Pack

These are Android-relevant, but need verified runtime/binary/media packs:

```text
blucli: android-cli-core-pack
coding-agent: android-node-debug-pack
diagram-maker: android-cli-core-pack
eightctl: android-cli-core-pack
gemini: android-node-debug-pack
gifgrep: android-vision-media-runtime
himalaya: android-cli-core-pack
node-inspect-debugger: android-node-debug-pack
openai-whisper: android-whisper-runtime
openhue: android-cli-core-pack
python-debugpy: android-python-debug-runtime
sherpa-onnx-tts: android-tts-runtime
songsee: android-audio-runtime
sonoscli: android-cli-core-pack
spotify-player: android-audio-runtime
tmux: android-terminal-pack
video-frames: android-vision-media-runtime
wacli: android-cli-core-pack
```

Class C acceptance:

- Pack ID is exact.
- Pack source is trusted.
- Pack contents are signed or hash-verified.
- APK/Play policy is respected.
- Install outcome re-runs parity/provisioning.
- Smoke proves the skill through Gateway chat or the registered Gateway tool
  path.

Some Class C skills can be converted into app-native adapters instead of
shipping shell-style binaries. That is preferred when the adapter is smaller,
safer, and easier to test.

### Class D: Unsupported On Android

These should not be counted as Android release failures:

```text
apple-notes
apple-reminders
bear-notes
imsg
peekaboo
things-mac
```

They rely on macOS apps, iMessage, desktop automation, or platform APIs that do
not exist in normal Android app permissions.

### Class E: Manual PRoot Compatibility

These belong behind an explicit compatibility-mode label:

```text
node-connect
oracle
```

They can remain visible to advanced users, but they must not be presented as
Native Android default readiness.

### Class F: Hidden Desktop/Remote

These are not Android GTM gates:

```text
model-usage
obsidian
```

They can return later as remote-host or desktop-connected workflows.

## Gateway-First Execution Contract

This is non-negotiable for GTM:

```text
User prompt
  -> Gateway chat.send / Gateway tool registry
  -> model selects or required router narrows exact tool
  -> tool_use frame is surfaced
  -> app/gateway executes tool
  -> tool_result frame is surfaced
  -> result returns to the agent/model
  -> final answer is synthesized from the actual result
```

The deterministic stocks route proves execution and now continues through the
agent loop. It emits `TOOL_USE:stocks` and `TOOL_RESULT:stocks`, converts the
pre-executed tool result into bounded continuation context, then sends the
normal `chat.send` turn so the model synthesizes the final answer. The direct
visible result remains a rescue path only when Gateway/model continuation
produces no assistant text.

Correct stocks target:

```text
finance prompt
  -> required tool selection: stocks
  -> execute stocks
  -> emit tool evidence
  -> continue Gateway/model turn with tool result
  -> final answer summarizes actual prices
```

Required phone actions should follow the same shape.

## In-App User Experience Contract

The Skills page must tell users the truth without making them read logs.

Minimum GTM surface:

```text
Android Default Skills
Ready now by product class: 19/51 Native Android-relevant
Launch gate: 13/13 pass
Ready optional: 6
Needs config: 14
Needs pack: 18
Unsupported Android: 6
Manual PRoot: 2
Desktop/remote: 2
```

The live device-health "ready within manifest" number can be higher or lower
because it includes current-device runtime evidence. The product-class count
above is the source promise after the current adapter batch is installed.

Each skill row/card should show:

- Product class: ready, config, pack, unsupported, PRoot, desktop.
- Runtime status: ready, missing binary, missing config, disabled, etc.
- Required keys or packs.
- One next action.

Examples:

```text
discord
Needs config
Required: DISCORD_BOT_TOKEN
Runtime: missing Native config
Action: Configure

blogwatcher
Ready optional
Runtime: app-native RSS/Atom feed adapter
Action: Use through Gateway-visible blogwatcher

xurl
Ready optional
Runtime: app-native HTTP adapter
Action: Use through Gateway-visible xurl.request

camsnap
Ready optional
Runtime: app-native camera adapter
Action: Use through Gateway-visible camsnap

summarize
Ready optional
Runtime: app-native extractive text adapter
Action: Use through Gateway-visible summarize

nano-pdf
Ready optional
Runtime: app-native text-PDF byte adapter
Action: Use through Gateway-visible nano-pdf

session-logs
Ready optional
Runtime: app-native app-chat session log adapter
Action: Use through Gateway-visible session-logs

apple-notes
Unsupported on Android
Reason: requires macOS Apple Notes automation
Action: Hidden from Android launch gate
```

The existing YAML skill editor is not enough. It edits skill prompt/override
files. The config UX must write credentials and config through the provisioning
service, then re-audit.

## Industry Standard Alignment

The plan follows normal agent/tool infrastructure practice:

- MCP tools have exact names and input schemas, and clients should show exposed
  tools plus visible invocation indicators.
- OpenAI function calling is a loop: provide tools, receive tool call, execute
  application code, send tool output back, then receive the final model answer.
- Anthropic tool guidance emphasizes clear descriptions, JSON schemas,
  namespacing, consolidated operations, and high-signal tool responses.
- Android and Google Play policy discourage remote executable-code loading.
  Dependency packs must be packaged, verified, or otherwise policy-safe.

Sources:

- https://modelcontextprotocol.io/specification/2024-11-05/server/tools
- https://platform.openai.com/docs/guides/function-calling
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
- https://developer.android.com/privacy-and-security/risks/dynamic-code-loading
- https://support.google.com/googleplay/android-developer/answer/16559646

## Phased Execution Plan

### Phase 0: Stop The Test Excuses

Goal: host tests must run for service/UI logic.

Current blocker:

```text
flutter test ... fails before test discovery because fllama native-assets tries
to build Windows host assets and this machine lacks VS C++/CMake resolution.
```

Plan:

- Keep Android fllama native-assets builds intact.
- Skip the non-linking Windows host asset build used by Flutter tests.
- Prove `flutter test test/android_skill_support_manifest_test.dart --no-pub`
  can reach and pass test discovery.
- Keep `flutter build apk --debug` passing.

### Phase 1: Make The App Explain The Truth

Goal: the Skills page should clearly show launch readiness, Android-relevant
ceiling, and top gate categories.

Work:

- Upgrade the Android readiness panel.
- Compute Android-release-relevant total:

```text
manifest total - unsupported - manual PRoot - hidden desktop
```

- Show ready-now within that relevant set.
- Show short lists of blocked `needs_config` and `needs_pack` examples.
- Explain that config and pack are different gates.

### Phase 2: Config Wizard

Goal: users can satisfy Class B gates from the app.

Work:

- Build a guided credential/config sheet.
- Pull required keys from `androidDefaultReadiness.skills`.
- Write values through `SkillProvisioningService.auditAndProvision`.
- Re-audit and refresh Gateway state.
- Show "still blocked by pack/binary" when config alone is not enough.

Implemented in-app path:

- `AndroidSkillConfigFormModel` parses readiness JSON into env credentials and
  dotted OpenClaw config keys.
- Skills page config-gate chips open `AndroidSkillConfigSheet`.
- The sheet writes values through
  `GatewayProvider.configureAndroidDefaultSkill`, which delegates to
  `SkillProvisioningService.auditAndProvision`.
- If provisioning recommends reload, the active Gateway owner applies the config
  change; RPC discovery is refreshed after the write.

Remaining proof:

- Device smoke with real or dummy-safe values for representative config gates.
- Verify that skills with a binary/pack gate still display the remaining gate
  after config is saved.

### Phase 3: Gateway-First Tool Continuation

Goal: required tool intents no longer bypass the agent final-answer loop.

Work:

- Change stocks and required mobile actions from early return to
  tool-result continuation.
- Keep direct visible fallback only when Gateway/model continuation is
  unavailable.
- Add tests for `TOOL_USE`, `TOOL_RESULT`, and continuation prompt/result
  wiring.

Implemented path:

- `sendMessage` pre-executes required native/mobile tools only after the
  Gateway WebSocket lane is available.
- It yields `TOOL_USE` and `TOOL_RESULT` chunks for the UI, then sends a
  bounded required-tool continuation prompt through `chat.send`.
- If the continuation closes or errors without assistant text, the direct
  visible tool result is returned with a diagnostic activity line.

Device proof from `RZCX30KA9AW` after reinstall:

```text
Prompt: Use the stocks skill to get current NVDA price. No web fallback.
Endpoint: /api/debug/app-native-chat-tool-smoke
success: true
toolUseSeen: true
toolResultSeen: true
timedOut: true
Native result: NVDA current price $205.10
Log: [TOOLS] Required stocks result will continue through Gateway chat.send.
```

Interpretation: Native stocks execution and Gateway continuation handoff were
proven on device. The debug endpoint did not observe final assistant text inside
its 20-second stream window, so longer/manual chat UI smoke remains useful for
final-response polish.

### Phase 4: Fast Adapter Wins

Goal: raise ready count without bloated binary packs.

Preferred adapter candidates:

```text
blogwatcher
nano-pdf
session-logs
summarize
stocks
camsnap
```

Acceptance:

- App-native or Gateway-registered adapter exists.
- User can call it through chat.
- Tool evidence appears.
- Health/readiness reclassifies it from pack/config blocked to ready or
  config-only.

First adapter landed:

```text
xurl
status: ready_optional
runtime: app-native Dart HTTP adapter
Gateway tool: xurl
command: xurl.request
methods: GET, HEAD, POST
POST guard: local loopback POST blocked
manifest movement: needs_pack -> ready_optional
```

This is the template for the remaining fast adapter wins: keep the agent/tool
loop visible, expose a schema in `/api/tools`, execute through
`AgentSkillServer`, then reclassify readiness only after tests and device smoke.

Device proof from `RZCX30KA9AW` after reinstall:

```text
/device/health:
releaseGatePass: true
ready_required: 13
ready_optional: 1
needs_pack: 21
xurl runtimeStatus: app_native_ready

/api/tools:
toolCount: 11
xurl schema: url required, method GET/HEAD/POST

/api/tools/execute:
name: xurl
url: http://127.0.0.1:8765/device/status
success: true
runtime: app-native-http
statusCode: 200
bytes: 319
elapsedMs: 15

/api/tools/execute guard:
name: xurl
method: POST
url: http://2130706433:8765/api/tools/execute
statusCode: 400
error: LOCAL_POST_BLOCKED
```

Debug note: `/api/debug/app-native-chat-tool-smoke` with an explicit `xurl GET`
prompt did not return within a 90-second host timeout during this round. Do not
use that endpoint result as chat-final-response proof. The adapter itself is
device-proven through the registered `/api/tools/execute` path, and the
chat-router tool-use/tool-result path is covered by focused unit tests. A longer
manual chat UI smoke remains useful before calling the user-facing chat wording
fully polished.

Second adapter landed and device-smoked:

```text
camsnap
status: ready_optional
runtime: app-native CameraCapability adapter
Gateway tool: camsnap
command underneath: camera.snap
manifest movement: needs_pack -> ready_optional
HTTP result hardening: raw base64 omitted from AgentSkillServer JSON responses
```

Local proof:

```text
flutter test test/android_skill_support_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/gateway_required_mobile_route_test.dart \
  test/xurl_app_native_adapter_test.dart \
  test/camsnap_app_native_adapter_test.dart --no-pub

Result: 25/25 passing
```

Device proof after Phase 4 milestone install:

```text
/api/tools: camsnap schema present
/api/tools/execute name=camsnap: success true
base64Omitted: true
```

Third adapter landed and device-smoked:

```text
summarize
status: ready_optional
runtime: app-native extractive text adapter
Gateway tool: summarize
command underneath: summarize.text
manifest movement: needs_config -> ready_optional
scope: provided text only, no provider-backed URL/file summarization claim
```

Local proof:

```text
flutter test test/summarize_app_native_adapter_test.dart --no-pub

Result: 6/6 passing
```

Device proof after Phase 4 milestone install:

```text
/api/tools: summarize schema present
/api/tools/execute name=summarize: success true
runtime: app-native-extractive-summary
```

Fourth adapter landed and device-smoked:

```text
blogwatcher
status: ready_optional
runtime: app-native RSS/Atom feed adapter
Gateway tool: blogwatcher
command underneath: blogwatcher.check
manifest movement: needs_pack -> ready_optional
scope: bounded feed check only, no persistent watcher/notification claim
safety: non-HTTP, loopback, private, and link-local URLs blocked
```

Local proof:

```text
flutter test test/blogwatcher_app_native_adapter_test.dart --no-pub

Result: 6/6 passing
```

Device proof after Phase 4 milestone install:

```text
/api/tools: blogwatcher schema present
/api/tools/execute name=blogwatcher
url: https://www.w3.org/blog/news/feed/
success: true
runtime: app-native-feed-check
feedTitle: W3C - News
itemCount: 1
statusCode: 200
```

Fifth adapter landed and device-smoked:

```text
session-logs
status: ready_optional
runtime: app-native app-chat session log adapter
Gateway tool: session-logs
command underneath: session-logs.query
manifest movement: needs_config -> ready_optional
scope: app-owned chat sessions only, no arbitrary log root
safety: gateway session keys, raw image payloads, full reasoning blocks, and
full tool payloads are not returned
```

Local proof:

```text
flutter test test/session_logs_app_native_adapter_test.dart --no-pub

Result: 9/9 passing
```

Device proof after Phase 4 milestone install:

```text
/api/tools: session-logs schema present
/api/tools/execute name=session-logs
action: list
success: true
runtime: app-native-session-logs
returnedSessionCount: 3
```

Sixth adapter landed and device-smoked:

```text
nano-pdf
status: ready_optional
runtime: app-native text-PDF byte adapter
Gateway tool: nano-pdf
command underneath: nano-pdf.extract
manifest movement: needs_pack -> ready_optional
scope: small text-based PDF bytes only
safety: encrypted PDFs, invalid bytes, arbitrary file paths, OCR/scanned PDFs,
and full parser parity are not claimed
```

Local proof:

```text
flutter test test/nano_pdf_app_native_adapter_test.dart --no-pub

Result: 7/7 passing
```

Device proof after Phase 4 milestone install:

```text
/api/tools: nano-pdf schema present
/api/tools/execute name=nano-pdf
success: true
runtime: app-native-pdf-text
chars: 35
```

### Phase 5: Verified Dependency Packs

Goal: solve the remaining binary/runtime skills safely.

Pack lanes:

```text
android-cli-core-pack
android-node-debug-pack
android-vision-media-runtime
android-whisper-runtime
android-python-debug-runtime
android-tts-runtime
android-audio-runtime
android-terminal-pack
```

Each pack needs:

- ABI.
- source.
- exact files.
- version.
- hash/signature.
- expected size.
- smoke command.
- rollback behavior.
- Play policy review.

First Phase 5 safety slice landed locally:

```text
DependencyPackManifestEntry
DependencyPackManifestPolicy
DependencyPackManifestValidation
```

The provisioning loader now validates dependency-pack manifests before pack
selection or install. Invalid records are rejected and never become install
candidates. Current gates reject:

```text
missing top-level SHA-256 for remote packs
unsupported Android ABI
unsigned remote executable packs
unsafe install paths
unsafe file paths
missing file hashes/sizes
missing smoke command
missing rollback plan
```

Local proof:

```text
flutter test test/dependency_pack_manifest_test.dart \
  test/skill_provisioning_service_test.dart --no-pub

Result: 13/13 passing
```

This is only the manifest safety gate. It does not yet mean
`android-cli-core-pack` is built, hosted, signed by a production key, or safe to
install for users.

### Phase 6: Fresh-User Proof

Goal: prove the release promise on clean app data.

Work:

- Uninstall or clear data only with explicit approval because this destroys
  app data.
- Install APK fresh.
- Query `/device/health`.
- Run Class A chat smokes.
- Run selected Class B/C smokes after config/pack setup.
- Record final counts in this doc.

## Immediate Working Targets

Round 1 target:

```text
Host tests unblocked.
GTM doc rewritten.
Skills page explains launch gate vs Android ceiling.
Commit made.
```

Round 2 target:

```text
Config wizard MVP.
At least discord/slack/voice-call config gates actionable.
Values flow through SkillProvisioningService, not ad hoc file writes.
Commit made.
```

Round 3 target:

```text
Stocks and required mobile actions continue through the agent loop.
Commit made.
```

Round 4 target:

```text
First adapter batch raises Android ready count above 20.
Commit made.
```

Round 5 target:

```text
Dependency-pack manifest and first verified pack lane.
Commit made.
```

## Success Definition

The release is not "13 skills." The release is a truthful, expanding Android
skill platform.

GTM is acceptable when:

- Native Gateway starts by default.
- Class A is 100 percent ready on fresh install.
- The app shows the full 61-skill classification.
- Android-relevant progress is visible against the 51-skill ceiling.
- Config-gated skills have exact setup UI.
- Pack-gated skills have exact pack IDs and policy-safe install plans.
- Unsupported/manual/desktop skills are not counted as Android failures.
- Tool execution is visible and runs through Gateway/agent infrastructure.
- Tests and device smokes are not optional theater.

The long-term push is `51/51` Android-release-relevant skills either ready,
user-configurable, or verified-pack-installable. The short-term GTM push is to
make the product honest, understandable, and measurably improving every round.

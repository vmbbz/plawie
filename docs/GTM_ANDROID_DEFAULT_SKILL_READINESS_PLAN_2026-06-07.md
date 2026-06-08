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

Live device health on 2026-06-07 after the Phase 5 `diagram-maker`
classification install reported:

```text
Classified default manifest: 61
Installed Native workspace skills: 65

Launch-required ready: 13/13
Ready within Android default manifest: 22

ready_required: 13
ready_optional: 7
needs_config: 14
needs_pack: 17
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
diagram-maker: needs_pack -> ready_optional
direct execute: summarize, session-logs, nano-pdf, xurl, camsnap, blogwatcher
product-class counts: ready_optional 7, needs_config 14, needs_pack 17
```

Additional Phase 4 config-gated adapter movement:

```text
github: needs_config + stale missing_native_bin -> needs_config app-native config-only
gh-issues: needs_config + stale missing_native_bin -> needs_config app-native config-only
goplaces: needs_config + stale missing_native_bin -> needs_config app-native config-only
notion: needs_config + stale missing_native_bin -> needs_config app-native config-only
discord: needs_config + stale missing_native_bin -> needs_config app-native config-only
trello: needs_config + stale missing_native_bin -> needs_config app-native config-only
slack: needs_config -> needs_config app-native config-only
mcporter: needs_config -> needs_config app-native config-only
openai-whisper-api: needs_config -> needs_config app-native config-only

/api/tools after install:
toolCount: 25
github present: true
gh-issues present: true
goplaces present: true
notion present: true
discord present: true
trello present: true
slack present: true
slack actions: me,status,post
mcporter present: true
openai-whisper-api present: true

/device/health after install:
releaseGatePass: true
ready_required: 13/13
classified default manifest: 61
installed Native workspace skills: 65

github: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
gh-issues: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
goplaces: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
notion: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
discord: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
trello: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
slack: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
mcporter: runtimeStatus needs_config, provisioningStatus needs_user_config,
primaryGate absent, gates absent
openai-whisper-api: runtimeStatus needs_config,
provisioningStatus needs_user_config, primaryGate absent, gates absent

/api/tools/execute missing-config proof:
github: HTTP 400 MISSING_GITHUB_TOKEN, no secret leak
gh-issues: HTTP 400 MISSING_GITHUB_TOKEN, no secret leak
goplaces: HTTP 400 MISSING_GOOGLE_PLACES_API_KEY, no secret leak
notion: HTTP 400 MISSING_NOTION_TOKEN, no secret value leak
discord: HTTP 400 MISSING_DISCORD_BOT_TOKEN, no secret value leak
trello: HTTP 400 MISSING_TRELLO_CONFIG, no secret value leak
slack: HTTP 400 MISSING_SLACK_CONFIG, no secret value leak
mcporter: HTTP 400 MISSING_MCPORTER_CONFIG, no secret value leak
openai-whisper-api: HTTP 400 MISSING_OPENAI_API_KEY, no secret value leak
```

The Notion, Discord, Trello, Slack, MCPorter, and OpenAI Whisper API adapters
are installed on `RZCX30KA9AW`. The installed app exposes 25 tools through
`/api/tools`; the config adapters show `needs_config` with no stale
`primaryGate` or `gates`.

The `/api/debug/app-native-chat-tool-smoke` endpoint remains unreliable for
final-response proof. During the milestone smoke it timed out once and then
returned a stale visible response on the next prompt. Do not count that endpoint
as chat proof. The direct registered tool execution path is device-proven, and
the explicit chat tool-use/tool-result chunk route is covered by focused tests.

## Config Wizard Milestone

Phase 2 config UX is now implemented and locally verified.

What changed:

```text
All 14 current Class B needs_config skills get actionable in-app fields.
Known services get service-aware labels, groups, input kinds, and helpers.
Unknown required config keys still render through safe fallback metadata.
Slack now has in-app fields for SLACK_BOT_TOKEN and channels.slack.
Voice-call provider renders as a provider choice field.
MCPORTER_ENDPOINT validates as a URL field.
Secret-like env keys and secret-like dotted config keys are masked.
Save remains GatewayProvider -> SkillProvisioningService.
Tool execution remains through the gateway/agent tool loop.
```

Hardening added after review:

```text
Config-only/app-native saves no longer silently no-op when a skill has no
native execution-matrix entry. Supplied safe env/config values are written to
Native .env / openclaw.json and return a non-empty satisfied provisioning
result.

The sheet fails closed on an empty provisioning report instead of saying saved.
Provider/provisioning exceptions show a generic error and do not echo raw
exception text while secrets are being handled.
```

Local proof:

```text
flutter test \
  test/android_skill_config_form_model_test.dart \
  test/android_skill_config_sheet_test.dart \
  test/android_skill_readiness_view_model_test.dart \
  test/skill_provisioning_service_test.dart \
  --no-pub

Result: 27/27 passing

flutter analyze \
  lib/services/android_skill_config_form_model.dart \
  lib/screens/management/skills/android_skill_config_sheet.dart \
  lib/services/skill_provisioning_service.dart \
  test/android_skill_config_form_model_test.dart \
  test/android_skill_config_sheet_test.dart \
  test/skill_provisioning_service_test.dart \
  test/android_skill_readiness_view_model_test.dart

Result: No issues found

flutter build apk --debug

Result: built build/app/outputs/flutter-apk/app-debug.apk
```

Device proof status:

```text
Historical note: this proof was captured before the Slack app-native adapter
landed. Current Slack adapter proof is recorded later in this document.

Target device: RZCX30KA9AW
Date: 2026-06-08
ADB state: device
Install command: adb install -r build/app/outputs/flutter-apk/app-debug.apk
Install result: Success
Forward command: adb forward tcp:8765 tcp:8765
Forward result: tcp:8765

/device/health:
releaseGatePass: true
ready_required: 13/13
classified default manifest: 61
installed Native workspace skills: 65
counts: ready_required 13, ready_optional 7, needs_config 14,
        needs_pack 17, unsupported_on_android 6,
        manual_proot_compat 2, hidden_desktop_only 2

/api/tools after install:
registered tools: 22
github present: true
discord present: true
notion present: true
trello present: true
slack present: false
```

The hardened config wizard APK is now installed and live on `RZCX30KA9AW`.
The Slack config UI behavior is covered by widget tests. A dummy-token device
save was not performed because it would write fake Slack values into the live
Native `.env` / `openclaw.json`; use real credentials or a cleared app profile
for that proof.

Device UI smoke checklist remains:

```text
Slack config chip opens service-aware fields.
Bot token is masked.
Default Slack channel appears under Workspace.
Save & Check routes through provisioning.
```

After the MCPorter/OpenAI Whisper API milestone, `ordercli` and `sag` remain
blocked for app-native conversion until real local API contracts exist. They
currently have config keys only, not endpoints, commands, auth shape, response
shape, safe bounds, or privacy behavior.

Read this carefully:

- `61` is the classified default skill manifest.
- `13/13` is the current launch-required pass gate.
- `22 ready` means 13 launch-ready plus 7 ready-optional skills
  (`diagram-maker` plus the 6 app-native optional adapters), plus
  `spotify-player` and `node-connect` on the current device.
- `xurl`, `camsnap`, `summarize`, `blogwatcher`, `session-logs`, and
  `nano-pdf` are now app-native ready optional: usable through
  Gateway-visible tool execution, but not part of the launch-critical gate.
- `github`, `gh-issues`, `goplaces`, `notion`, `discord`, `trello`, `slack`,
  `mcporter`, and `openai-whisper-api` are
  still needs-config skills, but no longer depend on Native CLI binaries once
  their env keys are present. They use bounded app-native REST adapters through
  the same Gateway-visible tool path.
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
diagram-maker
nano-pdf
session-logs
summarize
xurl
```

`diagram-maker` is an instruction-only OpenClaw skill, not a CLI renderer pack.
Its bundled `SKILL.md` has no binary/runtime requirement, so Android should let
the Gateway/agent skill loop use the instructions to create diagram artifacts
instead of blocking it behind `android-cli-core-pack`. It stays optional because
a richer app-native renderer/export adapter can still improve the UX later.

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
`missing_native_bin`.

Important second correction: app-native config-gated adapters must not keep
stale OpenClaw binary gates. `github`, `gh-issues`, `goplaces`, `notion`,
`discord`, `trello`, `slack`, `mcporter`, and `openai-whisper-api` are adapter
cases: until their env/config keys exist they show `needs_config`; after the
keys exist they become app-native ready without requiring CLI binaries.

Therefore the app must show config gates that are actionable without implying a
missing binary:

```text
Skill: slack
Product class: Needs config
User config: SLACK_BOT_TOKEN, channels.slack
Runtime gate before config: needs_config
Runtime gate after config: app_native_ready
Next action: configure SLACK_BOT_TOKEN and channels.slack in the Skills page

Skill: mcporter
Product class: Needs config
User config: MCPORTER_ENDPOINT, MCPORTER_TOKEN
Runtime gate before config: needs_config
Runtime gate after config: app_native_ready
Next action: configure MCPORTER_ENDPOINT and MCPORTER_TOKEN in the Skills page

Skill: openai-whisper-api
Product class: Needs config
User config: OPENAI_API_KEY
Runtime gate before key: needs_config
Runtime gate after key: app_native_ready
Next action: configure OPENAI_API_KEY in the Skills page
```

For app-native config adapters the app-facing gates are:

```text
Skill: github / gh-issues
Product class: Needs config
User config: GITHUB_TOKEN
Runtime gate before token: needs_config
Runtime gate after token: app_native_ready
Next action: configure GITHUB_TOKEN in the Skills page

Skill: goplaces
Product class: Needs config
User config: GOOGLE_PLACES_API_KEY
Runtime gate before key: needs_config
Runtime gate after key: app_native_ready
Next action: configure GOOGLE_PLACES_API_KEY in the Skills page

Skill: notion
Product class: Needs config
User config: NOTION_TOKEN
Runtime gate before token: needs_config
Runtime gate after token: app_native_ready
Next action: configure NOTION_TOKEN in the Skills page

Skill: discord
Product class: Needs config
User config: DISCORD_BOT_TOKEN
Runtime gate before token: needs_config
Runtime gate after token: app_native_ready
Next action: configure DISCORD_BOT_TOKEN in the Skills page

Skill: trello
Product class: Needs config
User config: TRELLO_API_KEY, TRELLO_TOKEN
Runtime gate before credentials: needs_config
Runtime gate after credentials: app_native_ready
Next action: configure TRELLO_API_KEY and TRELLO_TOKEN in the Skills page

Skill: slack
Product class: Needs config
User config: SLACK_BOT_TOKEN, channels.slack
Runtime gate before config: needs_config
Runtime gate after config: app_native_ready
Next action: configure SLACK_BOT_TOKEN and channels.slack in the Skills page
```

`github` reads bounded authenticated profile metadata through `github.user`.
`gh-issues` lists bounded repository issue metadata through `gh-issues.list`.
`goplaces` performs bounded Google Places Text Search through `goplaces.search`
using an explicit response field mask.
`notion` performs bounded Notion workspace search metadata through
`notion.search`.
`discord` reads bounded Discord bot status metadata through `discord.me`.
`trello` reads bounded Trello board summaries through `trello.boards`.
`slack` reads Slack bot identity through `slack.me` and posts bounded channel
messages through `slack.post`.
`mcporter` reads bounded configured endpoint health through `mcporter.health`.
`openai-whisper-api` transcribes supplied base64 audio bytes through
`openai-whisper-api.transcribe`.
All nine are exposed in `/api/tools`, route `/api/tools/execute` through
`AgentSkillServer`, and keep tokens/API keys out of tool input, result
payloads, and visible chat chunks.

`ordercli` and `sag` are deliberately not app-native adapters yet. Local
inspection found only API-key config placeholders, with no safe endpoint or
command contract. Shipping guessed APIs here would make the Skills page look
more capable than the product actually is.

### Class C: Needs Pack

These are Android-relevant, but need verified runtime/binary/media packs:

```text
blucli: android-cli-core-pack
coding-agent: android-node-debug-pack
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
- Pack-provided binary names match `SKILL.md` requirements, not guessed skill
  slugs.
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
ceiling, and gate categories.

Work:

- Upgrade the Android readiness panel.
- Compute Android-release-relevant total:

```text
manifest total - unsupported - manual PRoot - hidden desktop
```

- Show ready-now within that relevant set.
- Show the full blocked `needs_config` and `needs_pack` lists, not a teaser.
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
- Skills page gate previews now keep every blocked config and pack item visible
  from readiness JSON, so fresh users can see the whole remaining path without
  reading device logs.
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
github
gh-issues
goplaces
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

Seventh adapter landed:

```text
github / gh-issues
status: needs_config
runtime after config: app-native GitHub REST adapter
Gateway tools: github, gh-issues
commands underneath: github.user, gh-issues.list
manifest movement: stale missing_native_bin -> app-native config-only
scope: authenticated profile metadata and bounded issue lists only
safety: token is read from Native .env, never accepted in tool input, and never
returned in payloads or chat chunks
```

Local proof:

```text
flutter test test/android_skill_readiness_service_test.dart \
  test/github_app_native_adapter_test.dart \
  test/android_skill_support_manifest_test.dart --no-pub

Result: 19/19 passing
```

Build proof:

```text
flutter build apk --debug

Result: built build/app/outputs/flutter-apk/app-debug.apk
```

This does not change the fresh-user ready count because `GITHUB_TOKEN` is still
required. It does raise the honest ceiling: once the user configures that token
from the Skills page, both skills can run without a GitHub CLI binary or
dependency pack.

Device proof after corrected install:

```text
/api/tools: github and gh-issues schemas present
/device/health:
  github runtimeStatus: needs_config
  github provisioningStatus: needs_user_config
  github primaryGate/gates: absent
  gh-issues runtimeStatus: needs_config
  gh-issues provisioningStatus: needs_user_config
  gh-issues primaryGate/gates: absent
/api/tools/execute name=github:
  HTTP 400 MISSING_GITHUB_TOKEN, no secret leak
/api/tools/execute name=gh-issues:
  HTTP 400 MISSING_GITHUB_TOKEN, no secret leak
```

Eighth adapter landed:

```text
goplaces
status: needs_config
runtime after config: app-native Google Places REST adapter
Gateway tool: goplaces
command underneath: goplaces.search
manifest movement: stale missing_native_bin -> app-native config-only
scope: Places Text Search only, bounded result previews
safety: GOOGLE_PLACES_API_KEY is read from Native .env, never accepted in tool
input, and never returned in payloads or chat chunks
```

Local proof:

```text
flutter test test/goplaces_app_native_adapter_test.dart --no-pub

Result: 6/6 passing
```

Combined build proof:

```text
flutter build apk --debug

Result: built build/app/outputs/flutter-apk/app-debug.apk
```

This also does not change the fresh-user ready count because
`GOOGLE_PLACES_API_KEY` is still required. It clears the binary/pack ceiling for
configured users and follows the current Google Places Text Search pattern:
POST `/v1/places:searchText` with explicit `X-Goog-FieldMask`, no wildcard
field mask, and a bounded `pageSize`.

Device proof after corrected install:

```text
/api/tools: goplaces schema present
/device/health:
  goplaces runtimeStatus: needs_config
  goplaces provisioningStatus: needs_user_config
  goplaces primaryGate/gates: absent
/api/tools/execute name=goplaces:
  HTTP 400 MISSING_GOOGLE_PLACES_API_KEY, no secret leak
```

Ninth adapter landed:

```text
notion
status: needs_config
runtime after config: app-native Notion REST adapter
Gateway tool: notion
command underneath: notion.search
manifest movement: stale missing_native_bin -> app-native config-only
scope: Notion workspace search metadata only, bounded result previews
safety: NOTION_TOKEN is read from Native .env, never accepted in tool input,
and never returned in payloads or chat chunks
```

Local proof:

```text
flutter test test/notion_app_native_adapter_test.dart --no-pub

Result: 6/6 passing
```

Combined local proof after formatting:

```text
flutter test test/android_skill_readiness_service_test.dart \
  test/github_app_native_adapter_test.dart \
  test/goplaces_app_native_adapter_test.dart \
  test/notion_app_native_adapter_test.dart \
  test/android_skill_support_manifest_test.dart --no-pub

Result: 31/31 passing
```

Analyzer proof:

```text
flutter analyze lib/services/capabilities/notion_capability.dart \
  lib/services/app_native_chat_tool_router.dart \
  lib/services/agent_skill_server.dart \
  lib/services/gateway_tool_catalog.dart \
  lib/services/android_skill_support_manifest.dart \
  lib/services/skills_service.dart \
  test/notion_app_native_adapter_test.dart

Result: No issues found
```

Build proof:

```text
flutter build apk --debug

Result: built build/app/outputs/flutter-apk/app-debug.apk
```

Combined device proof after Trello install:

```text
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb forward tcp:8765 tcp:8765

/api/tools:
  toolCount: 22
  notion schema present
  discord schema present
  trello schema present

/device/health:
  releaseGatePass: true
  ready_required: 13/13
  classified default manifest: 61
  installed Native workspace skills: 65
  notion runtimeStatus: needs_config
  notion provisioningStatus: needs_user_config
  notion primaryGate/gates: absent
  discord runtimeStatus: needs_config
  discord provisioningStatus: needs_user_config
  discord primaryGate/gates: absent
  trello runtimeStatus: needs_config
  trello provisioningStatus: needs_user_config
  trello primaryGate/gates: absent

/api/tools/execute name=notion:
  HTTP 400 MISSING_NOTION_TOKEN, no secret value leak
/api/tools/execute name=discord:
  HTTP 400 MISSING_DISCORD_BOT_TOKEN, no secret value leak
/api/tools/execute name=trello:
  HTTP 400 MISSING_TRELLO_CONFIG, no secret value leak
```

Tenth adapter landed:

```text
discord
status: needs_config
runtime after config: app-native Discord REST adapter
Gateway tool: discord
command underneath: discord.me
manifest movement: stale missing_native_bin -> app-native config-only
scope: Discord bot status metadata only
safety: DISCORD_BOT_TOKEN is read from Native .env, never accepted in tool
input, and never returned in payloads or chat chunks
```

Local proof:

```text
flutter test test/discord_app_native_adapter_test.dart --no-pub

Result: 6/6 passing
```

Combined local proof after formatting:

```text
flutter test test/android_skill_readiness_service_test.dart \
  test/discord_app_native_adapter_test.dart \
  test/github_app_native_adapter_test.dart \
  test/goplaces_app_native_adapter_test.dart \
  test/notion_app_native_adapter_test.dart \
  test/android_skill_support_manifest_test.dart --no-pub

Result: 37/37 passing
```

Analyzer proof:

```text
flutter analyze lib/services/capabilities/discord_capability.dart \
  lib/services/app_native_chat_tool_router.dart \
  lib/services/agent_skill_server.dart \
  lib/services/gateway_tool_catalog.dart \
  lib/services/android_skill_support_manifest.dart \
  lib/services/skills_service.dart \
  test/discord_app_native_adapter_test.dart

Result: No issues found
```

Build proof:

```text
flutter build apk --debug

Result: built build/app/outputs/flutter-apk/app-debug.apk
```

Device proof for this Discord round:

```text
Covered by the combined installed proof above.
```

Eleventh adapter landed:

```text
trello
status: needs_config
runtime after config: app-native Trello REST adapter
Gateway tool: trello
command underneath: trello.boards
manifest movement: stale missing_native_bin -> app-native config-only
scope: Trello board summaries only, bounded result previews
safety: TRELLO_API_KEY and TRELLO_TOKEN are read from Native .env, never
accepted in tool input, and never returned in payloads or chat chunks
```

Local proof:

```text
flutter test test/trello_app_native_adapter_test.dart --no-pub

Result: 6/6 passing
```

Combined local proof after formatting:

```text
flutter test test/android_skill_readiness_service_test.dart \
  test/discord_app_native_adapter_test.dart \
  test/github_app_native_adapter_test.dart \
  test/goplaces_app_native_adapter_test.dart \
  test/notion_app_native_adapter_test.dart \
  test/trello_app_native_adapter_test.dart \
  test/android_skill_support_manifest_test.dart --no-pub

Result: 43/43 passing
```

Analyzer proof:

```text
flutter analyze lib/services/capabilities/trello_capability.dart \
  lib/services/app_native_chat_tool_router.dart \
  lib/services/agent_skill_server.dart \
  lib/services/gateway_tool_catalog.dart \
  lib/services/android_skill_support_manifest.dart \
  lib/services/skills_service.dart \
  test/trello_app_native_adapter_test.dart

Result: No issues found
```

Build proof:

```text
flutter build apk --debug

Result: built build/app/outputs/flutter-apk/app-debug.apk
```

Twelfth adapter landed:

```text
slack
status: needs_config
runtime after config: app-native Slack REST adapter
Gateway tool: slack
commands underneath: slack.me, slack.post
manifest movement: generic needs_config -> app-native config-only
scope: bot identity/status plus bounded channel message post
safety: SLACK_BOT_TOKEN is read from Native .env and channels.slack is read
from Native openclaw.json; neither is accepted in tool input or returned in
payloads/chat chunks
```

Local proof:

```text
flutter test test/slack_app_native_adapter_test.dart --no-pub

Result: 8/8 passing
```

Combined local proof:

```text
flutter test test/slack_app_native_adapter_test.dart \
  test/discord_app_native_adapter_test.dart \
  test/trello_app_native_adapter_test.dart \
  test/android_skill_support_manifest_test.dart \
  test/android_skill_config_form_model_test.dart \
  test/android_skill_config_sheet_test.dart \
  test/skill_provisioning_service_test.dart \
  --no-pub

Result: 48/48 passing
```

Analyzer proof:

```text
flutter analyze lib/services/capabilities/slack_capability.dart \
  lib/services/app_native_chat_tool_router.dart \
  lib/services/agent_skill_server.dart \
  lib/services/skills_service.dart \
  lib/services/android_skill_support_manifest.dart \
  lib/services/gateway_tool_catalog.dart \
  test/slack_app_native_adapter_test.dart

Result: No issues found
```

Device proof after Slack install:

```text
Target device: RZCX30KA9AW
Date: 2026-06-08
Install result: Success
releaseGatePass: true
ready_required: 13/13
counts: ready_required 13, ready_optional 7, needs_config 14,
        needs_pack 17, unsupported_on_android 6,
        manual_proot_compat 2, hidden_desktop_only 2
classified default manifest: 61
installed Native workspace skills: 65
/api/tools: toolCount 23, slack present true, actions me/status/post
/api/tools/execute name=slack action=me:
  HTTP 400 MISSING_SLACK_CONFIG on an unconfigured device, no secret leak
```

Thirteenth and fourteenth adapters landed:

```text
mcporter
status: needs_config
runtime after config: app-native MCPorter REST adapter
Gateway tool: mcporter
command underneath: mcporter.health
manifest movement: generic needs_config -> app-native config-only
scope: configured endpoint health/status only
safety: MCPORTER_ENDPOINT and MCPORTER_TOKEN are read from Native .env;
endpoint must be absolute http/https without userinfo; token is never accepted
in tool input or returned in payloads/chat chunks

openai-whisper-api
status: needs_config
runtime after config: app-native OpenAI transcription REST adapter
Gateway tool: openai-whisper-api
command underneath: openai-whisper-api.transcribe
manifest movement: generic needs_config -> app-native config-only
scope: base64 audio transcription only, 25 MB decoded app limit
safety: OPENAI_API_KEY is read from Native .env; audio bytes and API key are
not returned in payloads/chat chunks; response text is bounded
```

Local proof:

```text
flutter test test/mcporter_app_native_adapter_test.dart \
  test/openai_whisper_api_app_native_adapter_test.dart \
  --no-pub

Result: 12/12 passing
```

Combined local proof:

```text
flutter test test/mcporter_app_native_adapter_test.dart \
  test/openai_whisper_api_app_native_adapter_test.dart \
  test/slack_app_native_adapter_test.dart \
  test/android_skill_support_manifest_test.dart \
  test/android_skill_config_form_model_test.dart \
  test/android_skill_config_sheet_test.dart \
  test/skill_provisioning_service_test.dart \
  --no-pub

Result: 48/48 passing
```

Analyzer proof:

```text
flutter analyze lib/services/capabilities/mcporter_capability.dart \
  lib/services/capabilities/openai_whisper_api_capability.dart \
  lib/services/app_native_chat_tool_router.dart \
  lib/services/agent_skill_server.dart \
  lib/services/skills_service.dart \
  lib/services/android_skill_support_manifest.dart \
  lib/services/gateway_tool_catalog.dart \
  test/mcporter_app_native_adapter_test.dart \
  test/openai_whisper_api_app_native_adapter_test.dart

Result: No issues found
```

Device proof after MCPorter/OpenAI Whisper API install:

```text
Target device: RZCX30KA9AW
Date: 2026-06-08
Install result: Success
releaseGatePass: true
ready_required: 13/13
counts: ready_required 13, ready_optional 7, needs_config 14,
        needs_pack 17, unsupported_on_android 6,
        manual_proot_compat 2, hidden_desktop_only 2
classified default manifest: 61
installed Native workspace skills: 65
/api/tools: toolCount 25
mcporter: present true, required action
openai-whisper-api: present true, required audioBase64
/api/tools/execute name=mcporter action=health:
  HTTP 400 MISSING_MCPORTER_CONFIG on an unconfigured device, no secret leak
/api/tools/execute name=openai-whisper-api:
  HTTP 400 MISSING_OPENAI_API_KEY on an unconfigured device, no secret leak
```

Blocked after sanity inspection:

```text
ordercli: NOT SANE for app-native adapter yet
sag: NOT SANE for app-native adapter yet
reason: config keys exist, but local code/docs do not define endpoints,
commands, auth scheme, request params, response shape, safety bounds, or
privacy behavior
```

Host inspection note: for the phone-owned `AgentSkillServer` bridge on port
`8765`, use `adb forward tcp:8765 tcp:8765`. Do not use `adb reverse`; reverse
creates a shell-owned listener on the device side and can block
`AgentSkillServer` from binding.

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

Phase 5 safety/resolver slice landed locally:

```text
DependencyPackManifestEntry
DependencyPackManifestPolicy
DependencyPackManifestValidation
APK-provided android-cli-core-pack resolver
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

The first resolver is deliberately APK-local only. `android-cli-core-pack` is
advertised only when the installed APK already has matching bundled binaries in
the Native provisioning roots. Provisioning can now select dependency packs by
`provides.bins`, install those binaries into `.openclaw/bin`, write a pack
receipt, and refuse stale receipts when a managed binary is missing. This makes
the binary pack lane real without enabling unsigned or unhosted remote
executable downloads.

Important executable-name correction:

```text
skill id: blucli     required binary: blu
skill id: sonoscli   required binary: sonos
skill id: eightctl   required binary: eightctl
skill id: himalaya   required binary: himalaya
skill id: openhue    required binary: openhue
skill id: wacli      required binary: wacli
```

The resolver must advertise and copy `blu` and `sonos`, not `blucli` and
`sonoscli`. Otherwise the APK pack can contain valid binaries yet still fail to
satisfy the audited skill requirements.

APK payload lane follow-up:

```text
assets/openclaw/cli-core/bin/
NativeNodeEmbeddedService.copyCliCoreBinAssets(...)
target: filesDir/native-node-embedded/provisioning/bin
```

The debug APK now carries the CLI-core asset directory and the native bootstrap
copies any non-dot files from that directory into the provisioning bin with
executable permissions. Current APK payload audit still shows no real CLI-core
binary names (`blu`, `eightctl`, `himalaya`, `openhue`, `sonos`, `wacli`).
`diagram-maker` was removed from this pack lane after its `SKILL.md`
audit proved it is instruction-only. That means the payload lane prepares
installation for true CLI binaries but does not invent a renderer binary.

CLI-core missing-payload diagnostics now landed:

```text
dependencyGateStatus: missing_pack
missingPacks: android-cli-core-pack
missingBins: exact executable name, for example openhue
dependencyGateMessage: asset path or signed dependency-pack route
```

If a pack-gated skill needs a known CLI-core executable but the APK has no real
payload file, provisioning now emits an explicit `android-cli-core-pack:<bin>`
missing-pack action before the generic missing-binary action. Android readiness
copies that into `/device/health`, and the Skills page pack-gate tooltips prefer
the concrete message. This is a product-truth improvement only; it does not mark
any CLI skill ready until the actual binary is bundled or supplied by a signed,
validated pack.

Earlier local proof:

```text
flutter analyze lib/services/dependency_pack_manifest.dart \
  lib/services/skill_provisioning_service.dart \
  test/dependency_pack_manifest_test.dart \
  test/skill_provisioning_service_test.dart

flutter test test/dependency_pack_manifest_test.dart \
  test/skill_provisioning_service_test.dart --no-pub

flutter test test/android_cli_core_payload_packaging_test.dart \
  test/skill_provisioning_service_test.dart --no-pub

flutter test test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart

flutter build apk --debug

Result: analyzer clean; dependency-manifest/provisioning suite 14/14 passing;
payload/provisioning suite 11/11 passing; debug APK built; APK contains
`assets/openclaw/cli-core/bin/.gitkeep` only.
```

Latest host proof after the CLI-core diagnostics slice:

```text
flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart
Result: 20/20 passing

flutter test test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 13/13 passing
```

This does not yet mean a remote `android-cli-core-pack` is built, hosted,
signed by a production key, or safe to install for users. It means APK-provided
CLI-core binaries can now be discovered, selected as a dependency pack, copied
into managed Native state, receipted, and reinstalled if the managed file
disappears.

Classification correction landed after the CLI SKILL audit:

```text
diagram-maker
from: needs_pack / android-cli-core-pack
to: ready_optional / openclawSkill / instructionOnly
reason: bundled SKILL.md has no requires.bins or runtime dependency
device proof: ready true, runtimeStatus ready, provisioningStatus ready
```

This did not raise the raw "ready within manifest" count because
`diagram-maker` was already runtime-ready on the current device. It did improve
the product truth: fresh users should no longer see it as blocked by a pack it
does not need.

CLI-core build priority from source audit:

```text
1. openhue: exact binary name, Go build, best first candidate.
2. eightctl: exact binary name, Go build, auth needed only for functional smoke.
3. sonoscli/sonos: strong Go candidate after the bin-name correction, but
   local-network discovery needs Android multicast/network review.
4. blucli/blu: same bin-name correction done; device discovery and target config
   are the main smoke blockers.
```

This machine currently has no `go` on PATH, so producing real APK payloads
requires a builder/toolchain setup before the next binary-pack milestone.

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

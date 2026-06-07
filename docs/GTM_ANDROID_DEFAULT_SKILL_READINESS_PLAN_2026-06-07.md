# GTM Android Default Skill Readiness Plan

Date: 2026-06-07

Purpose: correct the Native Skill Execution war path into a launch-focused plan.
The target is not a tiny 1-3 skill pilot. The target is every default OpenClaw
skill that can honestly run on Android, with unsupported skills filtered out by
clear policy instead of left as noisy `missing_dependency` failures.

## Decision

The earlier "1-3 ClawHub proof skills" framing is too narrow for GTM. It is
useful only as an engineering smoke-test slice, not as the product readiness
bar.

The better GTM rule is:

```text
Keep every default skill that can run on Android through Native Gateway,
Android bridge adapters, app-owned HTTP adapters, verified runtime packs, or
user config.

Filter out only skills that are not Android-supported by design, unsafe for
public mobile release, or impossible without a future signed dependency pack.
```

Healthcheck must therefore stop reporting the full desktop/server skill universe
as if every default skill is supposed to be immediately executable on Android.
It should report Android launch readiness by class:

- `ready`
- `needs_config`
- `needs_pack`
- `unsupported_on_android`
- `manual_proot_compat`
- `hidden_desktop_only`

`missing_dependency` should remain a diagnostic state, but it should not be the
user-facing GTM summary for skills that are deliberately desktop-only,
credential-gated, or waiting for a known Android pack.

## Why This Is Smarter Than A Tiny Pilot

A 1-3 skill launch scope is too defensive. It would prove that the runtime can
work, but it would leave the product looking underpowered even when many bundled
skills are actually supportable on Android.

The right scope is class-based, not count-based:

- If a skill is mobile-safe and has no unsupported dependency, make it work.
- If a skill needs an API key or account link, show `needs_config`.
- If a skill needs a known binary/runtime pack, show `needs_pack` and install it
  only from a verified pack.
- If a skill is macOS/desktop-only, hide it from Android readiness or show
  `unsupported_on_android`.
- If a skill is Linux-shell compatible only through PRoot, keep it as explicit
  `manual_proot_compat`, not a Native failure.

This gives a broad GTM surface without promising that Android can execute every
desktop, macOS, Homebrew, apt, native npm, or arbitrary CLI dependency.

## What Would Happen In PRoot?

PRoot would probably make more Linux-style default skills runnable than Native
does today, especially skills that expect:

- Linux shell commands.
- `curl`, `tmux`, `python`, `node`, or common CLI tools.
- apt-installable packages.
- traditional filesystem paths under a Linux-like home.

But PRoot would not make all default skills work.

PRoot still would not automatically solve:

- macOS-only skills such as Apple Notes, Apple Reminders, iMessage, Things, Bear
  Notes, or Peekaboo-style macOS automation.
- missing API keys, OAuth, account links, or service-specific config.
- skills whose docs assume Homebrew formulas that are not present or not
  Android/Ubuntu-compatible.
- Android hardware control unless the Android node bridge is connected and
  permissioned.
- native packages that need incompatible CPU/OS builds.
- Play Store, startup, memory, and reliability concerns from running a full
  Linux userland on phones.

So Native is not a mistake. Native is the right default for GTM if the product
is Android-first:

- faster startup path;
- less process/runtime indirection;
- cleaner app-owned state;
- better mobile bridge integration;
- less dependence on phone-specific PRoot behavior;
- easier release story for Play Store and ordinary users.

PRoot remains valuable as explicit compatibility mode for advanced Linux-shell
skills and emergency rollback. It should not be the default path just because it
can paper over more CLI assumptions.

## Industry Alignment

The industry pattern is not "prompt the model harder and hope tools run." The
pattern is explicit tool contracts:

- MCP exposes tools through discovery and calls them by exact name with
  `inputSchema`; tool invocation should be visible and human-controllable.
  Source: https://modelcontextprotocol.io/specification/2024-11-05/server/tools
- OpenAI function calling uses JSON-schema tool definitions; the application
  executes model-requested tool calls and returns tool outputs. It also advises
  keeping the up-front tool surface small or deferred for accuracy and cost.
  Source: https://developers.openai.com/api/docs/guides/function-calling
- Anthropic tool-use guidance recommends clear tool descriptions, consolidated
  operations, namespacing, high-signal responses, and forced tool choice when a
  tool must be used.
  Source: https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools
- Android guidance strongly discourages dynamic code loading, especially remote
  code, and Google Play restricts downloading executable code outside Play.
  Sources:
  https://developer.android.com/privacy-and-security/risks/dynamic-code-loading
  https://support.google.com/googleplay/android-developer/answer/16559646

For OpenClaw Android, that means:

1. classify skills deterministically;
2. expose only real callable tools;
3. install only verified packs;
4. keep user-visible gates honest;
5. preserve PRoot as explicit compatibility fallback.

## Current Default Skill Inventory

The bundled OpenClaw archive currently contains these default skill docs:

```text
1password, apple-notes, apple-reminders, bear-notes, blogwatcher, blucli,
camsnap, canvas, clawhub, coding-agent, diagram-maker, discord, eightctl,
gemini, gh-issues, gifgrep, github, gog, goplaces, healthcheck, himalaya,
imsg, mcporter, meme-maker, model-usage, nano-pdf, node-connect,
node-inspect-debugger, notion, obsidian, openai-whisper, openai-whisper-api,
openhue, oracle, ordercli, peekaboo, python-debugpy, sag, session-logs,
sherpa-onnx-tts, skill-creator, slack, songsee, sonoscli, spike,
spotify-player, summarize, taskflow, taskflow-inbox-triage, things-mac, tmux,
trello, video-frames, voice-call, wacli, weather, xurl
```

The Android app also bundles mobile bridge skill docs:

```text
avatar_forge, battery, sensors, vibrate
```

The GTM plan should cover this whole inventory by classification, not only a
small proof subset.

## Android Readiness Classes

### Class A: Android-Ready Required

These must be ready on a fresh GTM install because they are core mobile
experience or can run through existing app/Gateway infrastructure without a
desktop dependency.

Examples:

- Android bridge skills: `battery`, `sensors`, `vibrate`, `avatar_forge`.
- App-native capabilities surfaced as tools: healthcheck, device status,
  permissions, camera list/snap, location, flashlight, haptics, avatar
  gestures.
- Gateway/runtime instruction skills that do not need external binaries:
  `canvas`, `taskflow`, `taskflow-inbox-triage`, `skill-creator`, `spike`.
- Mobile-safe local Node/script skills once Node is present and smoke-tested:
  `meme-maker`, `diagram-maker` if its renderer path is pure JS or bundled.
- Mobile-safe HTTP/network skills once adapter-backed: `weather`.

Release rule:

```text
Class A skills must not appear as missing_dependency in GTM healthcheck.
They must be ready or fail the release gate.
```

### Class B: Android-Ready After User Config

These are valid Android skills, but they require credentials, account linking,
channel IDs, or service config. They should stay visible, but their correct
state is `needs_config`, not `missing_dependency`.

Examples:

- `slack`
- `discord`
- `github`
- `gh-issues`
- `notion`
- `trello`
- `1password`
- `voice-call`
- `goplaces`
- `gog`
- `ordercli`
- `sag`
- `mcporter`
- `openai-whisper-api`
- `summarize` when provider/API config is required

Release rule:

```text
Class B skills pass GTM if they show exact missing config and become ready
after config is supplied.
```

### Class C: Android Pack Required

These are not impossible on Android, but they require a verified Android pack,
not on-device package building. They should not block GTM unless selected as
launch-critical.

Examples:

- `openai-whisper`
- `sherpa-onnx-tts`
- `video-frames`
- `camsnap`
- `gifgrep`
- `himalaya`
- `spotify-player`
- `tmux`
- `wacli`
- `xurl`
- `python-debugpy`
- CLI-heavy helpers such as `blucli`, `eightctl`, `nano-pdf`, `sonoscli`,
  depending on their actual binary/runtime path

Release rule:

```text
Class C skills show needs_pack with pack id, ABI, size, and smoke status.
They must not show vague missing_binary in the user-facing health summary.
```

### Class D: Unsupported On Android By Design

These should not be treated as failed Native skills. They are desktop/macOS app
automation skills or otherwise not Android-release targets unless a separate
remote-host connector is built.

Examples:

- `apple-notes`
- `apple-reminders`
- `bear-notes`
- `imsg`
- `things-mac`
- `peekaboo`
- desktop-only portions of `obsidian`, `oracle`, or `model-usage` if their
  usage depends on local desktop apps or macOS shell tools

Release rule:

```text
Class D skills are hidden from Android readiness or shown as
unsupported_on_android. They do not count against GTM readiness.
```

### Class E: Manual PRoot Compatibility

These are allowed to run only in explicit compatibility mode when the user or
operator selects PRoot. They should not be part of normal Native readiness.

Examples:

- Linux shell workflows that need a broader Ubuntu userland.
- CLI chains that are too expensive or risky to package natively for GTM.
- debugging/operator tools that assume a shell session.

Release rule:

```text
Class E skills show manual_proot_compat with a clear "switch to compatibility
mode" action. They never silently start PRoot.
```

## Corrected Healthcheck Contract

Healthcheck should separate total installed skill inventory from Android launch
readiness.

Bad GTM output:

```text
native skills: 65; skill gates: 91; readiness:
{"missing_dependency":32,"needs_config":20,"ready":13}
```

Better GTM output:

```text
Android default readiness:
ready_required: 18/18
needs_config: 14
needs_pack: 11
unsupported_on_android: 8
manual_proot_compat: 6
unexpected_missing_dependency: 0

Release gate: PASS
```

The important number is `unexpected_missing_dependency`. It must be zero for
the Android launch set.

### Implemented Health Payload

Implemented on 2026-06-07 in `device.health` as:

```text
androidDefaultReadiness.totalManifestSkills
androidDefaultReadiness.installedNativeSkills
androidDefaultReadiness.readyRequired.ready
androidDefaultReadiness.readyRequired.total
androidDefaultReadiness.countsByClass
androidDefaultReadiness.unexpectedMissingDependency
androidDefaultReadiness.unexpectedMissingDependencySkillIds
androidDefaultReadiness.releaseGatePass
androidDefaultReadiness.skills
```

Raw diagnostics remain present as separate fields:

```text
skillReadiness
skillProvisioning
skillGateCount
nativeSkillCount
prootSkillCount
```

Device smoke on 2026-06-07 installed the freshly built debug APK on
`RZCX30KA9AW`, launched `com.nxg.openclawproot`, forwarded phone port `8765`,
and read `http://127.0.0.1:28765/device/health`.

Observed Android default readiness:

```text
totalManifestSkills: 61
installedNativeSkills: 65
readyRequired: 9/13
countsByClass:
  ready_required: 13
  needs_config: 16
  needs_pack: 22
  unsupported_on_android: 6
  manual_proot_compat: 2
  hidden_desktop_only: 2
unexpectedMissingDependency: 4
unexpectedMissingDependencySkillIds:
  canvas
  clawhub
  meme-maker
  weather
releaseGatePass: false
```

This is the desired contract shape: app-native Android bridge skills such as
`avatar_forge`, `battery`, `sensors`, and `vibrate` now report
`app_native_ready` instead of pretending they are missing OpenClaw skill
folders, while the remaining launch blockers are named exactly.

### Progress Check: Skills Manager Surface

Round 5 on 2026-06-07 exposed the readiness contract into app state and the
Skills Manager:

- `GatewayState` now carries `skillProvisioning` and
  `androidDefaultReadiness`.
- `GatewayService` updates both fields after the finalized parity/provisioning
  snapshot.
- `GatewayProvider` exposes both summaries for UI consumers.
- Skills Manager now shows an Android default readiness panel and dependency
  status chips for installed skills.

Verification for this round:

- `dart analyze lib/models/gateway_state.dart lib/services/gateway_service.dart
  lib/screens/management/skills_manager.dart lib/providers/gateway_provider.dart`
  returned no issues.
- `flutter build apk --debug` produced
  `build\app\outputs\flutter-apk\app-debug.apk`.
- The fresh debug APK was installed on `RZCX30KA9AW`, launched, and
  `/device/health` still reported the Android readiness payload with
  `readyRequired: 9/13` and blockers `canvas`, `clawhub`, `meme-maker`, and
  `weather`.

### Progress Check: Canvas And Weather Promotion

Round 6 on 2026-06-07 reduced the Android launch blockers without adding a
desktop dependency pack:

- `canvas` is now classified as an app-native Android capability because the
  app already registers `canvas.navigate`, `canvas.eval`, and
  `canvas.snapshot` through the node bridge.
- `weather` now has an app-native HTTPS adapter backed by Open-Meteo, exposed as
  `weather.current` and `weather.forecast`.
- Android-owned manifest entries now report `app_native_ready` even when the
  raw OpenClaw skill matrix still has stale desktop missing-binary diagnostics.
  Those diagnostics remain visible in raw `skillProvisioning`; they no longer
  block the Android launch gate for app-owned commands.

Verification for this round:

- Targeted `dart analyze` across the changed services and tests returned no
  issues.
- `flutter build apk --debug` produced a fresh debug APK.
- The fresh debug APK was installed on `RZCX30KA9AW`, launched, and
  `/device/health` reported `readyRequired: 11/13`,
  `unexpectedMissingDependency: 2`, blockers `clawhub` and `meme-maker`, and
  `app_native_ready` for both `canvas` and `weather`.
- `POST /api/device/control` with
  `{"action":"weather_current","city":"Johannesburg"}` returned an Open-Meteo
  weather summary from the device.

## Golden Android Runtime And Adapter Pack

The shorter reliable path is not a tiny pilot and not a universal builder. It
is a curated Android runtime plus adapters:

1. Native Gateway and bundled OpenClaw package.
2. Android node bridge for phone hardware and avatar actions.
3. Native Node for pure JS scripts and Gateway runtime.
4. Native Python for selected Android-compatible Python packages.
5. HTTP adapter for skills whose docs use `curl` against local or public HTTP.
6. Verified dependency packs for known heavy skills.
7. Strict manifest gates for every default skill.

The phone should:

- read manifest;
- download only trusted packs when needed;
- verify hash/signature;
- extract to app-owned storage;
- smoke test;
- mark ready or blocked with exact reason.

The phone should not:

- run Homebrew;
- run apt as a normal GTM install path;
- run `node-gyp`, `make`, or arbitrary native builds on-device;
- silently execute downloaded native binaries;
- silently fall back to web or PRoot.

## PRoot Positioning

PRoot is not wrong. It is just not the right default product story for Android
GTM.

Use PRoot for:

- explicit compatibility mode;
- emergency rollback;
- operator/developer shell workflows;
- Linux CLI skills that are not launch-critical;
- cases where the user knowingly trades startup/runtime cost for compatibility.

Do not use PRoot for:

- normal fresh-install startup;
- hiding Native readiness failures;
- silently satisfying skill dependencies;
- claiming Android-native readiness when the skill only works in a Linux
  compatibility shell.

## Implementation Plan

### Phase 1: Build The Android Skill Support Manifest

Create a product manifest that classifies every default skill:

```json
{
  "skillId": "weather",
  "androidSupport": "ready_required",
  "ownerLayer": "openclaw_skill",
  "executionMode": "http_adapter",
  "requiredPacks": [],
  "requiredConfig": [],
  "unsupportedReason": null,
  "smokePrompt": "Use weather for Johannesburg with no web fallback."
}
```

Allowed `androidSupport` values:

- `ready_required`
- `needs_config`
- `needs_pack`
- `unsupported_on_android`
- `manual_proot_compat`
- `hidden_desktop_only`

This manifest should be generated from skill metadata when possible, then
overridden by curated product policy where the metadata is desktop-biased.

### Phase 2: Reclassify Existing Health Gates

Change healthcheck from raw gate totals to class-aware release status:

- total installed skills;
- Android launch skills;
- ready required count;
- needs config count;
- needs pack count;
- unsupported count;
- unexpected missing dependency count;
- exact failing skills if unexpected count is nonzero.

### Phase 3: Make All Class A Skills Ready

Device-test every Class A skill through the actual chat/tool path.

Acceptance:

- tool/result chips appear where action is taken;
- direct Gateway/app adapter evidence exists in logs;
- no model-only claims;
- no web fallback for explicit skill requests;
- no automatic PRoot fallback.

### Phase 4: Make Class B Config UX Exact

For every config-gated skill:

- show exact key/account needed;
- do not call the skill until configured;
- re-audit after config save;
- run smoke after config is supplied.

### Phase 5: Create Pack Roadmap For Class C

For every pack-required skill:

- define pack id;
- ABI;
- size;
- source;
- hash/signature;
- smoke command;
- whether it is launch-critical.

Only launch-critical Class C packs block GTM.

### Phase 6: Hide Or Demote Class D

Desktop/macOS-only skills should not pollute Android healthcheck. They can stay
in an "Available on desktop/remote host" section if useful, but not in Android
readiness.

### Phase 7: Keep PRoot As Explicit Compatibility

Add a compatibility mode narrative:

- "Native Android mode" is default and recommended.
- "PRoot compatibility mode" is optional for Linux-shell skills.
- Switching modes is explicit and visible.
- Healthcheck shows which skills would need PRoot, but does not count them as
  Native failures.

## Release Gate

GTM passes when:

1. Native Gateway starts by default.
2. Android node bridge is linked and declares expected commands.
3. Every `ready_required` skill is ready and smoke-tested.
4. Every `needs_config` skill has exact config UI/status.
5. Every `needs_pack` skill has an exact pack id or is marked non-launch.
6. Every desktop/macOS-only skill is classified as unsupported, hidden, or
   remote-host-only.
7. Healthcheck reports `unexpected_missing_dependency: 0` for the Android launch
   set.
8. PRoot is manual compatibility only.
9. Tool/result UI appears for action-taking skills.
10. Device smoke proves the release set from chat, not just direct endpoints.

## Bottom Line

The right plan is broader than 1-3 skills but narrower than "make Android run
every desktop/server skill."

Launch with every Android-viable default skill classified and either working,
config-gated, pack-gated, or unsupported-by-design. Keep Native as the default
mobile runtime. Keep PRoot as explicit compatibility. Make healthcheck report
Android product truth instead of raw desktop inventory pain.

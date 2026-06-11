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

## Current Scorecard

Current host/APK and installed-device truth on 2026-06-11 after the Phase 6G
config coverage closeout and Phase 6H live installed-APK truth check:

```text
Classified default manifest: 61

Static manifest taxonomy:
ready_required: 13
ready_optional: 7
needs_config: 14
needs_pack: 17
unsupported_on_android: 6
manual_proot_compat: 2
hidden_desktop_only: 2

Android-relevant denominator:
61 - unsupported_on_android 6 - manual_proot_compat 2 - hidden_desktop_only 2
= 51

Release gate:
ready_required: 13/13
unexpected_missing_dependency: 0
releaseGatePass: true

Current APK-local android-cli-core payloads:
blu, eightctl, himalaya, openhue, sonos, wacli

Remaining android-cli-core payload gaps:
none

Current APK-local android-vision-media-runtime payloads:
ffmpeg and gifgrep are now host-built and APK-local:

```text
binary: assets/openclaw/vision-media/bin/ffmpeg
source: FFmpeg 8.1.1 official release tarball
source sha256: b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3
payload sha256: 5359bcf9ee6b0deff2c9352ab28fde51602bbac75325f3f8b41781a7a4d0a09e
license mode: LGPL-only, --disable-gpl, --disable-nonfree, no external libs

binary: assets/openclaw/vision-media/bin/gifgrep
source: https://github.com/steipete/gifgrep
source commit: 72e2cf8fe685e7baa0535c04c3cf2e238ebfd0bc
payload sha256: 431e81de8d46d6fad4b0ca1dbd76e7ce2efb8ca5dd6a9b495be303c60f937098
license: MIT License
```

The release count moved after the payload was installed from the APK, copied
into Native managed bin, smoked with `ffmpeg -version`, `gifgrep --version`,
and proven by tiny media-to-image extraction on device.

Current APK-local android-python-debug-runtime payloads:
debugpy is device-proven and APK-local. The release count moved after the
installed APK copied the wheel, provisioned it into Native Python site-packages,
smoked `import debugpy` through the Chaquopy bridge, and reported
`python-debugpy` ready through `/device/health`:

```text
asset: assets/openclaw/python-debug-runtime/wheels/debugpy-1.8.21-py2.py3-none-any.whl
payload sha256: b1e37d333663c8851516a47364ef473da127f9caebe4417e6df6f5825a7e9a92
pack id: android-python-debug-runtime
provided package: debugpy
install target: .openclaw/runtimes/python/site-packages
provenance: docs/ANDROID_PYTHON_DEBUG_RUNTIME_PAYLOAD.md
```

Device proof passed on 2026-06-09 on `RZCX30KA9AW` / Samsung SM-A556E:

```text
install: adb install -r -d build/app/outputs/flutter-apk/app-debug.apk -> Success
wheel: files/native-node-embedded/provisioning/python-debug/wheels/debugpy-1.8.21-py2.py3-none-any.whl
site-packages: .openclaw/runtimes/python/site-packages/debugpy
pack receipt: dependencies/receipts/android-python-debug-runtime.json
wheel receipt: dependencies/receipts/python-wheels/debugpy.json, smokePassed true
/api/python/exec: import debugpy -> 1.8.21, runtime chaquopy-python-bridge
/device/health: python-debugpy ready true, runtimeStatus ready, provisioningStatus ready
```

Current APK-local android-terminal-pack payloads:
tmux is device-proven and APK-local. The release count moved after the
installed APK copied the `tmux` executable and four required shared libraries,
provisioned them into managed `.openclaw/bin` and `.openclaw/lib`, and reported
`tmux` ready through `/device/health`:

```text
asset roots:
  assets/openclaw/terminal/bin/
  assets/openclaw/terminal/lib/
copy targets:
  filesDir/native-node-embedded/provisioning/terminal/bin/
  filesDir/native-node-embedded/provisioning/terminal/lib/
managed install targets:
  .openclaw/bin
  .openclaw/lib
pack id: android-terminal-pack
pack version: termux-tmux-3.6b-apk-v1
payload: assets/openclaw/terminal/bin/tmux
payload sha256: 9db38fdb4178abd13d19a32f40d265b61473694487e5c6ffc60e43ba11f1ca96
Termux package version: 3.6b
runtime-reported version: tmux 3.6a
managed smoke: LD_LIBRARY_PATH=.openclaw/lib .openclaw/bin/tmux -V -> tmux 3.6a
provenance: docs/ANDROID_TERMINAL_TMUX_PAYLOAD.md
```

Clean host/APK fresh-user floor after APK install/provisioning:
Android ready floor: 30/51
  = 13 ready_required
  + 7 ready_optional
  + 10 bundled pack skills that need no extra config today
    (blucli, gifgrep, himalaya, openhue, python-debugpy, songsee,
     sonoscli, tmux, video-frames, wacli)

Installed-device Android-relevant ready now: 30/51
Raw ready rows in /device/health: 31
  = Android-relevant ready 30
  + node-connect manual_proot_compat, which is not part of the Android
    release denominator

Installed-device delta from the audit slice:
spotify-player is no longer false-ready; it correctly exposes the
spogo-or-spotify_player alternative-bin blocker.
python-debugpy is now clean fresh-user ready because debugpy 1.8.21 is supplied
by the APK-local android-python-debug-runtime pack and installed as a real
wheel, not a fake marker. Installed-device headline count did not move because
this phone already had debugpy ready before the APK-local proof; the clean APK
floor is what moved.
songsee is now clean fresh-user ready because the APK-local
android-audio-runtime pack supplies a real Android arm64 `songsee` executable,
provisions it into managed `.openclaw/bin`, and passes version plus tiny
WAV-to-PNG device smoke. spotify-player remains blocked because the pack
advertises only `songsee`, not `spogo` or `spotify_player`.
gifgrep is now clean fresh-user ready because the APK-local
android-vision-media-runtime pack supplies a real Android arm64 `gifgrep`
executable, provisions it into managed `.openclaw/bin`, and passes version,
help, local GIF still, and local GIF sheet PNG smokes. Provider search remains
mode-specific config for `GIPHY_API_KEY` or `KLIPY_API_KEY`, not a hard launch
gate for local GIF processing.
sonoscli is ready in the live installed-device truth because the APK-local
CLI-core `sonos` payload satisfies its binary gate. eightctl remains
pack-satisfied but config-gated.

Static needs_config taxonomy entries: 14
Current config-gated rows users can act on in UI after Phase 6H device proof: 15
  = 14 static needs_config entries
  + eightctl, whose APK-local binary pack is satisfied but whose live runtime
    gate remains needs_config until EIGHTCTL_PASSWORD account config exists

Unready needs_pack taxonomy entries: 7
  = 17 needs_pack taxonomy entries - 10 ready needs_pack skills

True binary-pack blockers inside needs_pack: 6
  = coding-agent, gemini, node-inspect-debugger, openai-whisper,
    sherpa-onnx-tts, spotify-player

Sherpa TTS truth after installed-device health: `sherpa-onnx-tts` is not a
simple TTS model/runtime pack blocker in the current skill shape. It also needs
a standalone `node` execution host unless we replace that skill path with an
app-native/JNI bridge.

Pack-satisfied but still needs user/device config:
eightctl

Ready needs_pack skills:
  = 6 bundled CLI-core payload consumers
    - 2 bundled vision-media payload consumers
    - 1 bundled python-debug payload
    - 1 bundled terminal payload
    - 1 bundled audio-runtime payload
```

The release gate is not supposed to inflate above `13/13`; it stays the
launch-critical fresh-user boot promise. The ceiling moves through
the Android-relevant ready count and the unresolved blocker counts. The Skills
page now shows current gates, not just static taxonomy: `CONFIG BLOCKERS`
includes rows whose live `runtimeStatus` or `provisioningStatus` says user
config is needed, and `PACK BLOCKERS` keeps only true missing artifact lanes.
That means a pack-class row such as `eightctl` moves to the config affordance
after its binary payload is installed, without pretending it is ready. Mixed
pack-plus-config rows stay in `PACK BLOCKERS` until missing artifact evidence
is gone.

Device proof caveat: APK extraction, provisioning, `/device/health`,
no-secret version execution, tiny media extraction, and Python debug import are now
installed-device-proven for all six CLI-core payloads plus the FFmpeg
vision-media payload plus the debugpy Python payload plus the tmux terminal
payload plus the Songsee audio-runtime payload plus the Gifgrep vision-media
payload. Account, LAN, and real-service workflow smokes are still pending where
a skill requires credentials, devices, local network discovery, or a real
external service.

## Latest Installed Device Truth

Live device health on 2026-06-11 after Phase 6H refreshed the already-installed
APK without rebuilding or reinstalling:

```text
Runner:
  scripts/android/run_phase_6d_release_rehearsal.ps1

Mode:
  -SkipBuild -SkipInstall -SkipChatSmokes

Artifact:
  .tmp/phase-6h-live-ui-truth.json

Target device:
  RZCX30KA9AW / Samsung SM-A556E

Strict release proof:
  releaseGatePass: true
  ready_required: 13/13
  classified default manifest: 61
  installed Native package/workspace skills: 60
  unexpected_missing_dependency: 0
  required tool smokes: 9/9

Live Skills page model:
  Android-relevant ready: 30/51
  raw ready rows: 31
  excluded ready row: node-connect manual_proot_compat

Current actionable config gates: 15
  live connection checks: 9
  setup-status checks: 1
  pure save-only gates: 1
    eightctl
  mixed runtime gates: 4
    1password, gog, ordercli, sag

Static taxonomy:
  needs_config: 14
  needs_pack: 17

Current pack-gate truth:
  unready needs_pack taxonomy rows: 7
  true missing artifact lanes shown in PACK GATES: 6
    coding-agent, gemini, node-inspect-debugger, openai-whisper,
    sherpa-onnx-tts, spotify-player
  pack-class row moved to CONFIG GATES: eightctl
    reason: android-cli-core pack is satisfied; remaining gate is
    EIGHTCTL_PASSWORD user/device config, with no missing bin/pack evidence

Repo asset audit:
  present APK-local payload lanes:
    android-cli-core-pack
    android-vision-media-runtime
    android-python-debug-runtime
    android-terminal-pack
    android-audio-runtime for songsee only
  absent payload lanes:
    android-agent-cli-pack
    android-gemini-cli-pack
    android-node-executable-pack
    android-whisper-runtime
    android-tts-runtime
    spotify spogo/spotify_player binary lane

Phase 6H decision:
  no production code change is justified by this proof. The app and docs agree
  on release gate, Android-relevant ready count, config/mixed gate split, and
  true pack blockers. Do not inflate readiness with placeholder binaries or
  schema-only payloads.

Next smart phase:
  Phase 6I should choose the next ceiling move only if a real Android artifact
  path is credible enough to ship with provenance, hash, license, APK install,
  managed provisioning, and device smoke. Standalone Node remains a high-effort
  +1 unless it is deliberately promoted as a platform investment. Whisper and
  Sherpa are credible but require runtime/model policy and size decisions.
```

Previous live device health on 2026-06-10 after the Phase 5K Gifgrep
vision-media runtime install/provisioning smoke and the Phase 5L config-unlock
bridge reinstall reported:

```text
Target device: RZCX30KA9AW / Samsung SM-A556E
Install result: Success, debug reinstall with data preserved
releaseGatePass: true
ready_required: 13/13
classified default manifest: 61
installed Native workspace skills: 65

Android-relevant ready: 30/51
Raw ready rows: 31
manual ready row excluded from Android denominator: node-connect

Parser/audit truth:
coding-agent: requiredAnyBins [claude, codex, opencode, pi],
              still missing an Android-safe agent CLI and config
spotify-player: requiredAnyBins [spogo, spotify_player],
                runtimeStatus missing_dependency,
                provisioningStatus missing_binary
python-debugpy: runtimeStatus ready, provisioningStatus ready,
                android-python-debug-runtime receipt exists,
                debugpy 1.8.21 import smoke passed through
                /api/python/exec / chaquopy-python-bridge
songsee: runtimeStatus ready, provisioningStatus ready,
         android-audio-runtime receipt advertises only songsee,
         managed .openclaw/bin/songsee sha256 matches APK payload,
         tiny WAV-to-PNG smoke produced a PNG image
gifgrep: runtimeStatus ready, provisioningStatus ready,
         android-vision-media-runtime receipt advertises gifgrep,
         managed .openclaw/bin/gifgrep sha256 matches APK payload,
         local GIF still and sheet smokes produced PNG images
tmux: runtimeStatus ready, provisioningStatus ready,
      android-terminal-pack receipt version termux-tmux-3.6b-apk-v1,
      managed .openclaw/bin/tmux -V -> tmux 3.6a
node-inspect-debugger: missing standalone node binary;
                       embedded libnode is not counted as a shell node bin
gemini: missing real gemini CLI
video-frames: runtimeStatus ready, provisioningStatus ready,
              managed ffmpeg sha256
              5359bcf9ee6b0deff2c9352ab28fde51602bbac75325f3f8b41781a7a4d0a09e
sonoscli: runtimeStatus ready, provisioningStatus ready,
          APK-local sonos payload satisfies the binary gate
eightctl: runtimeStatus needs_config, provisioningStatus needs_user_config,
          APK-local eightctl payload exists, requiredEnv EIGHTCTL_PASSWORD,
          no missing pack/bin evidence, belongs in CONFIG GATES
spotify-player: runtimeStatus missing_dependency,
                provisioningStatus missing_binary,
                requiredAnyBins [spogo, spotify_player],
                missingBins [spogo], stays in PACK GATES
openai-whisper: runtimeStatus missing_dependency,
                provisioningStatus missing_binary,
                missingBins [whisper], stays in PACK GATES
sherpa-onnx-tts: runtimeStatus needs_config/missing_dependency evidence
                 includes missing standalone node plus
                 SHERPA_ONNX_MODEL_DIR and SHERPA_ONNX_RUNTIME_DIR env;
                 stays in PACK GATES as android-tts-runtime plus
                 android-node-executable-pack

Phase 5L current gate split:
CONFIG GATES: 15
  1password, discord, eightctl, gh-issues, github, gog, goplaces,
  mcporter, notion, openai-whisper-api, ordercli, sag, slack, trello,
  voice-call
PACK GATES: 6
  coding-agent, gemini, node-inspect-debugger, openai-whisper,
  sherpa-onnx-tts, spotify-player

Python debug runtime proof:
provisioning/python-debug/wheels/debugpy-1.8.21-py2.py3-none-any.whl
site-packages/debugpy and debugpy-1.8.21.dist-info exist
pack receipt: dependencies/receipts/android-python-debug-runtime.json
wheel receipt: dependencies/receipts/python-wheels/debugpy.json,
               smokePassed true
/api/python/exec import debugpy -> stdout {"version":"1.8.21", ...}

CLI-core pack status:
blucli: ready true, runtimeStatus ready, provisioningStatus ready
eightctl: ready false, runtimeStatus needs_config,
          provisioningStatus needs_user_config, no missing pack/bin
himalaya: ready true, runtimeStatus ready, provisioningStatus ready
openhue: ready true, runtimeStatus ready, provisioningStatus ready
sonoscli: ready true, runtimeStatus ready, provisioningStatus ready,
          APK-local sonos payload satisfies the binary gate
wacli: ready true, runtimeStatus ready, provisioningStatus ready

No-secret managed-bin version smokes:
blu --version -> v0.1.4
eightctl version -> 2f2c73f
himalaya --version -> himalaya v1.2.0 +maildir +wizard +smtp
                      +pgp-commands +sendmail +imap
openhue version -> 0.24-1-g08e940a
sonos --version -> sonos 0.3.1
wacli version -> v0.11.0-10-gbe2d22f
ffmpeg -version -> FFmpeg 8.1.1, exit 0

Vision-media device smoke:
provisioning/bin/ffmpeg bytes -> 3287176
managed .openclaw/bin/ffmpeg bytes -> 3287176
tiny mpeg4 MP4 -> frame_001.jpg 1740 bytes
JPEG header -> ff d8 ff

Vision-media pack status at the FFmpeg-only checkpoint:
video-frames became ready on installed device after APK provisioning and frame
extraction proof.
gifgrep remained blocked at that checkpoint because ffmpeg alone must not
satisfy it. Phase 5K later added a separate real gifgrep payload.
```

Previous installed-device truth before Phase 5D was `25/51`. The earlier
pre-audit `25/51` was partly wrong because `spotify-player` was counted ready
before `anyBins` was enforced. At that point, `26/51` was composed of real
app-native/required/optional/CLI-core readiness, the FFmpeg-backed
`video-frames` movement, and the APK-local `python-debugpy` package state.
Phase 5E moved the fresh-user floor to `26/51`, not the already-warm
installed-device headline. Phase 5G later moved the floor to `27/51`.
Phase 5J moved it to `28/51` with the APK-local Songsee audio-runtime payload.
Phase 5K's installed-device checkpoint now reports `30/51`.

## Last Installed Device Truth

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

That `22` is historical installed-device truth, not the current APK ceiling
after the later `eightctl`, `sonos`, and `blu` payload commits.

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
voice-call: VOICE_CALL_PROVIDER, VOICE_CALL_ACCOUNT,
            plugins.entries.voice-call.enabled
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
coding-agent: android-agent-cli-pack
eightctl: android-cli-core-pack
gemini: android-gemini-cli-pack
gifgrep: android-vision-media-runtime
himalaya: android-cli-core-pack
node-inspect-debugger: android-node-executable-pack
openai-whisper: android-whisper-runtime
openhue: android-cli-core-pack
python-debugpy: android-python-debug-runtime
sherpa-onnx-tts: android-tts-runtime + android-node-executable-pack
songsee: android-audio-runtime
sonoscli: android-cli-core-pack
spotify-player: android-audio-runtime
tmux: android-terminal-pack
video-frames: android-vision-media-runtime
wacli: android-cli-core-pack
```

Current APK-local pack satisfaction:

```text
android-cli-core-pack satisfied by bundled APK payload:
blucli -> blu
eightctl -> eightctl
himalaya -> himalaya
openhue -> openhue
sonoscli -> sonos
wacli -> wacli

android-cli-core-pack still missing APK payload:
none

Node/Gemini/agent pack taxonomy correction:
the old broad `android-node-debug-pack` planning bucket is no longer used for
default-readiness truth. A standalone `node` executable can only move
`node-inspect-debugger`. `gemini` needs a real Gemini CLI plus auth/config
truth. `coding-agent` needs a verified Android-safe agent CLI such as `claude`,
`codex`, `opencode`, or `pi`, plus its auth/config truth.

android-vision-media-runtime APK resolver:
ffmpeg and gifgrep are backed by bundled Android arm64 payloads at
assets/openclaw/vision-media/bin/. ffmpeg satisfies video-frames after APK
install, Native provisioning copy, no-secret `ffmpeg -version`, and tiny
video-to-JPEG device proof. gifgrep satisfies local GIF processing after APK
install, Native provisioning copy, `gifgrep --version`, and local GIF still/sheet
PNG proof. One binary must not satisfy another binary's gate.

android-audio-runtime APK resolver:
songsee only, backed by the bundled Android arm64 Songsee payload at
assets/openclaw/audio-runtime/bin/songsee. This can satisfy songsee after APK
install, Native provisioning copy, `songsee --version`, and tiny WAV-to-image
device proof. It must not satisfy spotify-player, which remains blocked until
`spogo` or `spotify_player` plus real account/auth behavior exists.

Installed-device proof on 2026-06-10:
songsee is ready through `/device/health`; managed `.openclaw/bin/songsee`
reports `v0.1.1-10-g41d27ea`; both provisioning and managed binaries match
sha256 `98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab`;
tiny WAV-to-PNG smoke produced a 35894-byte PNG with header
`89 50 4e 47 0d 0a 1a 0a`; spotify-player remains blocked on missing `spogo`.
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
Android now: 30/51 Native Android-relevant ready on the current device
Launch gate: 13/13 pass
Ready optional taxonomy: 7
Config blockers: 15 = 14 needs_config + eightctl live config gate
Config checks: 9 live connection + 1 provider setup status / 15
Pure save-only config: 1 = eightctl
Mixed runtime config gates: 4 = 1password, gog, ordercli, sag
Pack blockers: 6 true binary/runtime lanes after moving eightctl to config
Needs config taxonomy: 14
Needs pack taxonomy: 17
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
- Config check support: LIVE, SETUP, or SAVE for config-gated rows.
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
android-node-executable-pack
android-gemini-cli-pack
android-agent-cli-pack
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
non-Python dependency-pack command smoke executor
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

Phase 5A command-smoke verifier landed next. Non-Python binary packs no longer
become receipted just because a validated manifest and archive exist. The
installer now preserves each pack's `smokeCommand`, file list, and rollback
strategy, applies executable permissions from the manifest, runs the command
from managed `.openclaw/bin` with `runInShell: false`, bounded output, and a
timeout, and writes the receipt only after exit code `0`. Failed command smokes
roll back installed pack files and leave the skill blocked. This is the shared
release gate for executable packs such as `android-node-executable-pack`,
`android-vision-media-runtime`, `android-terminal-pack`,
`android-gemini-cli-pack`, and `android-agent-cli-pack`; payload work for
standalone `node`, `ffmpeg`, `tmux`, Gemini CLI, or agent CLIs can now build on
the same verifier instead of inventing one-off smoke paths.

Phase 5B reality check landed as a decision record:

```text
docs/ANDROID_NODE_RUNTIME_PHASE_5B_REALITY_CHECK_2026-06-09.md
```

Result: do not spend the next GTM implementation round trying to ship a strict
standalone Android arm64 `node` executable. The direct Node 22 executable build
attempt previously reached target `libnode.a` but did not produce
`out/Release/node`; the blocker is a real Node/V8 host/target cross-build
issue, documented in `docs/native-node-gateway/13-node-22-android-build-attempt.md`.
The embedded `libnode.so` lane is proven and architecturally valuable, but it
is not a shell `node` binary in `.openclaw/bin`, so it must not be used to mark
shell-binary-gated skills ready.

Honest movement from a true standalone `node` pack would be only:

```text
node-inspect-debugger: needs_pack -> ready
fresh Android floor: 24/51 -> 25/51
installed-device Android-relevant ready: 25/51 -> 26/51
```

Do not count `gemini`, `coding-agent`, or `node-connect` as moved by `node`
alone. `gemini` still needs a real Gemini CLI and auth/config truth.
`coding-agent` still needs one of `claude`, `codex`, `opencode`, or `pi`, plus
config/auth truth. `node-connect` remains manual PRoot compatibility.

Phase 5B implementation pivot:

```text
next binary payload lane: android-vision-media-runtime
first honest target: ffmpeg -> video-frames
kept blocked until real binary: gifgrep
parked research lane: android-node-executable-pack, expected +1 only
```

Phase 5H taxonomy correction landed after the terminal payload proof:

```text
removed stale planning bucket: android-node-debug-pack
node-inspect-debugger: android-node-executable-pack, standalone node only
gemini: android-gemini-cli-pack, real Gemini CLI plus auth/config truth
coding-agent: android-agent-cli-pack, one verified Android-safe agent CLI plus
              auth/config truth
ready floor impact: none until a real payload and device smoke land
```

Skills page follow-up:

```text
Pack-gate previews keep raw pack IDs in structured health data, but display
user-readable labels such as Standalone Node executable pack, Android Gemini CLI
pack, and Android agent CLI pack.
```

Phase 5I blocker audit landed as a decision record:

```text
docs/ANDROID_PACK_BLOCKER_PHASE_5I_AUDIT_2026-06-10.md
```

Result: the next payload lane should be `android-audio-runtime` for `songsee`
only. It is the cleanest remaining `+1`: local audio input, image output, no
account auth, no provider API key, and no ML model bundle. `gifgrep` is
technically plausible but not first because its provider-search promise needs
API-key/config truth unless Android narrows the promise to local GIF
processing. `sherpa-onnx-tts` and local Whisper are credible but heavier model
runtime lanes; Sherpa also remains coupled to standalone `node` in the current
skill path. Node, Gemini, coding-agent, and Spotify remain parked because they
carry standalone-Node, auth, sandbox, account, or mixed pack/config risk.

Phase 5I score impact:

```text
Android ready floor: unchanged at 27/51
unresolved pack blockers: unchanged at 8
release gate: unchanged at 13/13
```

Phase 5J audio-runtime plumbing landed:

```text
APK asset lane: assets/openclaw/audio-runtime/bin/
Native bootstrap copy target:
  filesDir/native-node-embedded/provisioning/audio-runtime/bin
provisioning resolver: android-audio-runtime, songsee only
truth rule: advertise the pack only when songsee exists in the bundled
            audio-runtime bin root
blocked by design: spotify-player
```

This checkpoint intentionally does not raise the Android-ready floor. It only
creates the safe lane for a future real `songsee` Android arm64 payload. A
bundled `songsee` executable can move `songsee`; it must not satisfy
`spotify-player`, whose real gates are `spogo` or `spotify_player` plus
account/auth setup.

Phase 5J real Songsee payload landed on host:

```text
asset: assets/openclaw/audio-runtime/bin/songsee
source: https://github.com/steipete/songsee
source commit: 41d27ea22771ba447bdfb8b6adac2e6599601634
source describe: v0.1.1-10-g41d27ea
toolchain: go1.25.4 windows/amd64
payload sha256: 98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab
provenance: docs/ANDROID_AUDIO_RUNTIME_SONGSEE_PAYLOAD.md
third-party notice: docs/THIRD_PARTY_NOTICES_SONGSEE.md
host packaging proof: test/android_cli_core_payload_packaging_test.dart
debug APK entry:
  assets/flutter_assets/assets/openclaw/audio-runtime/bin/songsee
```

Installed-device proof landed on 2026-06-10:

```text
device: RZCX30KA9AW / Samsung SM-A556E
install: adb install -r -d build/app/outputs/flutter-apk/app-debug.apk -> Success
/device/health releaseGatePass: true
/device/health ready_required: 13/13
/device/health Android-relevant ready: 28/51
/device/health raw ready rows: 29
songsee: runtimeStatus ready, provisioningStatus ready, ready true
spotify-player: ready false, missing spogo, dependencyGateStatus missing_pack
managed songsee --version: v0.1.1-10-g41d27ea
managed songsee --help: Usage: songsee <input> [flags]
managed/provisioning songsee sha256:
  98ba6bbd89e69f515192300e0fbbecb607e3e1aba7697e138431ccfd86cf2cab
tiny WAV-to-PNG smoke:
  output bytes: 35894
  PNG header: 89 50 4e 47 0d 0a 1a 0a
```

This raises the Android-ready floor from `27/51` to `28/51` and drops the
unresolved pack blocker floor from `8` to `7`. It still does not move
`spotify-player`, whose real gates are `spogo` or `spotify_player` plus account
and auth setup.

Phase 5K Gifgrep vision-media payload landed:

```text
scanner truth fix:
  provider-specific prose such as GIPHY_API_KEY required for --source giphy
  no longer becomes a hard env gate for local GIF processing

asset: assets/openclaw/vision-media/bin/gifgrep
source: https://github.com/steipete/gifgrep
source commit: 72e2cf8fe685e7baa0535c04c3cf2e238ebfd0bc
upstream version: 0.3.0
toolchain: go1.25.5 windows/amd64
payload sha256: 431e81de8d46d6fad4b0ca1dbd76e7ce2efb8ca5dd6a9b495be303c60f937098
provenance: docs/ANDROID_VISION_MEDIA_GIFGREP_PAYLOAD.md
third-party notice: docs/THIRD_PARTY_NOTICES_GIFGREP.md
host packaging proof: test/android_cli_core_payload_packaging_test.dart
debug APK entry:
  assets/flutter_assets/assets/openclaw/vision-media/bin/gifgrep
```

Installed-device proof landed on 2026-06-10:

```text
device: RZCX30KA9AW / Samsung SM-A556E
install: adb install -r -d build/app/outputs/flutter-apk/app-debug.apk -> Success
Native bootstrap manifest: visionMediaBinCount 2
/device/health releaseGatePass: true
/device/health ready_required: 13/13
/device/health Android-relevant ready: 30/51
/device/health raw ready rows: 31
gifgrep: runtimeStatus ready, provisioningStatus ready, ready true
video-frames: ready true
managed/provisioning gifgrep sha256:
  431e81de8d46d6fad4b0ca1dbd76e7ce2efb8ca5dd6a9b495be303c60f937098
managed gifgrep --version: gifgrep 0.3.0
managed gifgrep --help: exposes still and sheet local GIF commands
local GIF smoke:
  input bytes: 2145
  gifgrep still --at=0s -> still.png, 772 bytes
  gifgrep sheet --frames=4 --cols=2 -> sheet.png, 2573 bytes
  PNG header for both outputs: 89 50 4e 47 0d 0a 1a 0a
```

This installed-device checkpoint raises the documented Android-ready floor from
`28/51` to `30/51`. The visible delta is `gifgrep` becoming ready and the live
planner now correctly reporting `sonoscli` as ready through the existing
APK-local `sonos` payload. `eightctl` remains a `needs_user_config` case. True
remaining binary-pack blockers inside `needs_pack` are now `coding-agent`,
`gemini`, `node-inspect-debugger`, `openai-whisper`, `sherpa-onnx-tts`, and
`spotify-player`.

Phase 5L config-unlock bridge landed:

```text
readiness JSON:
  merges live matrix requiredEnv into each skill row
  merges manifest requiredConfig with live matrix requiredConfig

Skills page:
  CONFIG GATES now follows live runtimeStatus/provisioningStatus
  PACK GATES now excludes pack-class rows whose only current blocker is config
  AndroidSkillConfigSheet now opens for runtime needs_config rows even when the
  static taxonomy is needs_pack
```

This is not score inflation. It does not change:

```text
release gate: 13/13
Android ready floor: 30/51
true binary-pack blockers: 6
```

It changes the user's unlock path. A row such as `eightctl` remains unready
until account/device configuration exists, but once the APK-local binary has
been installed and the live audit says the remaining gate is config, the row
belongs in the interactive config path rather than the missing-pack path.
If a row still has missing binary, missing pack, or dependency-gate evidence,
it stays in the pack path even when it also has user config fields.

Phase 5M Sherpa blocker truth correction:

```text
sherpa-onnx-tts required packs:
  android-tts-runtime
  android-node-executable-pack

Why:
  installed-device health showed Sherpa still needs standalone node in the
  current skill execution path, plus SHERPA_ONNX_MODEL_DIR and
  SHERPA_ONNX_RUNTIME_DIR. A TTS runtime/model pack alone would not honestly
  move the skill to ready.

Readiness impact:
  release gate unchanged at 13/13
  Android ready floor unchanged at 30/51
  true binary-pack blockers unchanged at 6
```

Phase 5N six-blocker reality check:

```text
audited remaining true PACK GATES:
  coding-agent
  gemini
  node-inspect-debugger
  openai-whisper
  sherpa-onnx-tts
  spotify-player

decision:
  none is the next industrial GTM implementation lane

why:
  node-inspect-debugger is technically coherent only after a real standalone
  Android node executable, but it is high effort for a low-product-value +1
  gemini is behind standalone node plus Google auth/config truth
  coding-agent is a product/security/runtime lane, not a generic binary pack
  openai-whisper needs a real local runtime, model policy, size/license review,
  and device latency proof; the OpenAI API adapter already covers the practical
  configured transcription path
  sherpa-onnx-tts needs TTS runtime/model assets plus standalone node or an
  app-native/JNI replacement path
  spotify-player needs a backend/auth decision before binary packaging; songsee
  in android-audio-runtime must not satisfy Spotify

mainline pivot:
  Phase 6A config-unlock quality
```

Host-side proof:

```text
flutter test test/android_skill_readiness_service_test.dart
flutter test test/android_skill_config_form_model_test.dart
flutter test test/android_skill_readiness_view_model_test.dart
```

All three targeted suites pass after adding regression coverage for:

```text
needs_pack + runtimeStatus needs_config exposes requiredEnv/requiredConfig
pack-class config gates appear in AndroidSkillConfigFormModel.allFromReadiness
pack-class config gates move from PACK GATES to CONFIG GATES in the view model
```

Parallel blocker audits on 2026-06-10 support the same strategy:

```text
openai-whisper: keep blocked unless a real whisper.cpp Android runtime/model
                pack is built and latency/size/licensing are proven
sherpa-onnx-tts: viable later, but currently mixed-gated by
                  android-tts-runtime plus android-node-executable-pack; it
                  needs real native libs, model layout, espeak data, hashes,
                  licenses, standalone node or an app-native/JNI replacement
                  path, and synthesis smoke before readiness moves
node-inspect-debugger: keep parked; a standalone node executable is high effort
                       for +1 and libnode.so does not satisfy the shell binary
gemini: keep parked behind standalone node plus explicit auth/config truth
coding-agent: keep parked until exactly one Android-safe agent CLI plus auth,
              sandbox, provenance, and workspace policy is chosen
spotify-player: keep parked until backend/auth choice is explicit; songsee does
                not satisfy spogo or spotify_player
```

Phase 5C Android vision-media runtime lane landed as plumbing:

```text
APK asset lane: assets/openclaw/vision-media/bin/
Native bootstrap copy target: filesDir/native-node-embedded/provisioning/bin
provisioning resolver: android-vision-media-runtime, per-binary exact payloads
truth rule: advertise only binaries that exist in the bundled bin root
current binaries: ffmpeg, gifgrep
```

This intentionally does not raise the ready count yet. It turns the next
ffmpeg payload round into a straightforward, testable artifact drop plus smoke:
bundle real Android arm64 ffmpeg, provision video-frames through Gateway/health,
run a no-secret ffmpeg smoke, then run the video frame extraction smoke on
device before changing scorecard numbers.

Phase 5D FFmpeg payload lane is device-proven:

```text
payload: assets/openclaw/vision-media/bin/ffmpeg
source: FFmpeg 8.1.1 official release tarball
source sha256: b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3
payload sha256: 5359bcf9ee6b0deff2c9352ab28fde51602bbac75325f3f8b41781a7a4d0a09e
runtime path: Native managed bin only, no shell, bounded MethodChannel runner
provenance: docs/ANDROID_VISION_MEDIA_FFMPEG_PAYLOAD.md
third-party notice: docs/THIRD_PARTY_NOTICES_FFMPEG.md
```

Installed-device proof passed on 2026-06-09. `/device/health` reports
`video-frames` ready and provisioned, and a real tiny MP4 extraction returned a
JPEG frame from managed FFmpeg. `gifgrep` stays blocked by design.

Phase 5E Python debug runtime lane is device-proven:

```text
payload: assets/openclaw/python-debug-runtime/wheels/debugpy-1.8.21-py2.py3-none-any.whl
package: debugpy 1.8.21
payload sha256: b1e37d333663c8851516a47364ef473da127f9caebe4417e6df6f5825a7e9a92
runtime path: Native Python site-packages via verified APK-local wheel install
provenance: docs/ANDROID_PYTHON_DEBUG_RUNTIME_PAYLOAD.md
```

Device proof passed on 2026-06-09 after reinstalling the debug APK on
`RZCX30KA9AW` / Samsung SM-A556E:

```text
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk -> Success
provisioning/python-debug/wheels/debugpy-1.8.21-py2.py3-none-any.whl exists
.openclaw/runtimes/python/site-packages/debugpy exists
.openclaw/runtimes/python/site-packages/debugpy-1.8.21.dist-info exists
android-python-debug-runtime.json receipt exists
python-wheels/debugpy.json receipt exists with smokePassed true
/api/python/exec import debugpy -> 1.8.21
/device/health python-debugpy ready true
```

Count movement: clean fresh-user floor is now `26/51`. Installed-device
Android-relevant ready remains `26/51` because this phone already counted
`python-debugpy` before Phase 5E; Phase 5E removes the prior-state caveat by
proving the APK-local pack path.

Audit truth slice now landed:

```text
structured bins suppress noisy prose/example command scans
metadata.openclaw.requires.anyBins is enforced as alternatives
requiredAnyBins is exposed through /device/health for the Skills page
python3 -m debugpy / python3 -c "import debugpy" creates a real debugpy
  Python package gate
```

This corrected two important readiness mistakes. `spotify-player` is no longer
ready unless either `spogo` or `spotify_player` exists. `python-debugpy` is not
considered solved by a Python bridge alone; it needs `debugpy` present and
verified. `python-debugpy` now belongs in the clean fresh-user floor because
`android-python-debug-runtime` installs real wheel contents from the APK and
smokes the import through the Native Python bridge.

Phase 5F Android terminal pack lane landed as plumbing:

```text
APK asset lanes:
  assets/openclaw/terminal/bin/
  assets/openclaw/terminal/lib/
Native bootstrap copy targets:
  filesDir/native-node-embedded/provisioning/terminal/bin
  filesDir/native-node-embedded/provisioning/terminal/lib
provisioning resolver:
  android-terminal-pack, tmux only
managed install targets:
  .openclaw/bin for tmux
  .openclaw/lib for terminal shared libraries
smoke env:
  OPENCLAW_NATIVE_LIB and LD_LIBRARY_PATH include .openclaw/lib
Phase 5F blocked until payload:
  tmux
```

This Phase 5F plumbing-only checkpoint intentionally did not raise the ready
count. It made the next tmux round an artifact/provenance/device-smoke round
instead of mixing payload work with installer architecture. Phase 5G below is
the payload proof that moved `tmux` from `needs_pack` to ready.

Installed-device proof on 2026-06-09 confirmed the Phase 5F plumbing without
moving counts:

```text
device: RZCX30KA9AW / Samsung SM-A556E / aarch64
install: adb install -r -d app-debug.apk -> Success
/device/health:
  totalManifestSkills: 61
  installedNativeSkills: 65
  readyRequired: 13/13
  releaseGatePass: true
  unexpectedMissingDependency: 0
  raw ready rows: 27
  tmux: needs_pack, missing android-terminal-pack, missing tmux
Native bootstrap full_gateway_manifest.json:
  terminalBinAssetDir: flutter_assets/assets/openclaw/terminal/bin
  terminalBinCount: 0
  terminalLibAssetDir: flutter_assets/assets/openclaw/terminal/lib
  terminalLibCount: 0
Native bootstrap log:
  skipped unsafe terminal asset name=.gitkeep
  terminal asset copy completed count=0
  skipped unsafe terminal library asset name=.gitkeep
  terminal library asset copy completed count=0
```

Interpretation: the APK-local terminal bin/lib lane exists and runs on device,
but it contains no real Android arm64 terminal payload yet. `tmux` therefore
correctly remains pack-blocked and non-release-blocking.

Phase 5G Android terminal payload lane is device-proven:

```text
payloads:
  assets/openclaw/terminal/bin/tmux
  assets/openclaw/terminal/lib/libandroid-glob.so
  assets/openclaw/terminal/lib/libandroid-support.so
  assets/openclaw/terminal/lib/libevent_core-2.1.so
  assets/openclaw/terminal/lib/libncursesw.so.6
source:
  Termux official aarch64 apt packages
Termux package version:
  tmux 3.6b
runtime-reported version:
  tmux 3.6a
pack id/version:
  android-terminal-pack / termux-tmux-3.6b-apk-v1
managed smoke:
  LD_LIBRARY_PATH=.openclaw/lib .openclaw/bin/tmux -V -> tmux 3.6a
/device/health:
  tmux runtimeStatus ready, provisioningStatus ready, ready true
```

This raises the clean Android-ready floor from `26/51` to `27/51` and drops the
unresolved pack blocker floor from `9` to `8`. The release gate remains
`13/13`; tmux is useful ceiling movement, not a launch-critical boot gate.

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
executable permissions. `diagram-maker` was removed from this pack lane after
its `SKILL.md` audit proved it is instruction-only. That means the payload lane
prepares installation for true CLI binaries but does not invent renderer
binaries.

Real CLI-core APK payloads landed:

```text
skill id: openhue
asset: assets/openclaw/cli-core/bin/openhue
source: https://github.com/openhue/openhue-cli
source commit: 08e940a9cd1c49c2da0a714dc8bb07ee60e9cd21
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
verified format: ELF64 little-endian AArch64
payload bytes: 11206952
payload sha256: 281cf0c17f593a32fe83571db7f467c956cd92a1b4bded26f6c8a8408f0ba3f9
rebuild script: scripts/cli_core/build_openhue_android_arm64.ps1 -InstallAsset
provenance: docs/CLI_CORE_OPENHUE_ANDROID_PAYLOAD.md

skill id: eightctl
asset: assets/openclaw/cli-core/bin/eightctl
source: https://github.com/steipete/eightctl
source commit: 2f2c73f0a529e9138707a237135fcaadfe56617e
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
verified format: ELF64 little-endian AArch64
payload bytes: 10158376
payload sha256: 8242e7624b6c0e3c9bd1fa932b515f8d589c47be09940da9032230f75d88d755
rebuild script: scripts/cli_core/build_eightctl_android_arm64.ps1 -InstallAsset
provenance: docs/CLI_CORE_EIGHTCTL_ANDROID_PAYLOAD.md

skill id: himalaya
asset: assets/openclaw/cli-core/bin/himalaya
source: https://github.com/pimalaya/himalaya
source commit: 1b70c4e0eaa72dee48353f0211e6cc0f0776fe98
build target: aarch64-linux-android
rust toolchain: 1.93.0
android ndk: 29.0.14206865
verified format: ELF64 little-endian AArch64
payload bytes: 28958664
payload sha256: 83c900e58ff0ab931187fea7c49a36a29343e291ea8179b876c37bfbb34d572b
rebuild script: scripts/cli_core/build_himalaya_android_arm64.ps1 -InstallAsset
provenance: docs/CLI_CORE_HIMALAYA_ANDROID_PAYLOAD.md

skill id: sonoscli
asset: assets/openclaw/cli-core/bin/sonos
source: https://github.com/steipete/sonoscli
source commit: 87f409ab218a19a03cad630458258b291c365d8b
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
verified format: ELF64 little-endian AArch64
payload bytes: 10813736
payload sha256: 411713ad1cd0e6841db7f5a6583d9d2f1767c1ef8c5f1cf143a666d5717ee8b5
rebuild script: scripts/cli_core/build_sonos_android_arm64.ps1 -InstallAsset
provenance: docs/CLI_CORE_SONOS_ANDROID_PAYLOAD.md

skill id: blucli
asset: assets/openclaw/cli-core/bin/blu
source: https://github.com/steipete/blucli
source commit: b5ba7d004448f945acff8ea56034cfe4138be5b6
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=0
verified format: ELF64 little-endian AArch64
payload bytes: 8257832
payload sha256: 9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442
rebuild script: scripts/cli_core/build_blu_android_arm64.ps1 -InstallAsset
provenance: docs/CLI_CORE_BLU_ANDROID_PAYLOAD.md

skill id: wacli
asset: assets/openclaw/cli-core/bin/wacli
source: https://github.com/openclaw/wacli
source commit: be2d22fe9d8ca99bf4c027708ae494e9035fe489
build target: GOOS=android GOARCH=arm64 CGO_ENABLED=1
c compiler: Android NDK aarch64-linux-android29-clang.cmd
go build tags: sqlite_fts5
verified format: ELF64 little-endian AArch64
payload bytes: 21713936
payload sha256: 63d36f54e82d8a2e76b2ef9ae44fe41b3c0bc0474ea19b9f31aae39ab9b43453
rebuild script: scripts/cli_core/build_wacli_android_arm64.ps1 -InstallAsset
provenance: docs/CLI_CORE_WACLI_ANDROID_PAYLOAD.md
```

All audited `android-cli-core-pack` binaries are now present as APK-local
Android arm64 payloads. No placeholder payloads are allowed; future CLI-core
expansion still needs the same source, hash, script, APK, and device proof.

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
payload/provisioning suite 11/11 passing; debug APK built; APK contained
`assets/openclaw/cli-core/bin/.gitkeep` only at that earlier checkpoint.
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

.\scripts\cli_core\build_openhue_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
281cf0c17f593a32fe83571db7f467c956cd92a1b4bded26f6c8a8408f0ba3f9

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 35/35 passing

flutter analyze touched Dart files
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/openhue
length 11206952, sha256
281cf0c17f593a32fe83571db7f467c956cd92a1b4bded26f6c8a8408f0ba3f9
```

Device proof after installing the debug APK on Samsung SM-A556E:

```text
/device/health:
releaseGatePass: true
readyRequired: 13/13
androidRelevantReady: 22/51
openhue.ready: true
openhue.runtimeStatus: ready
openhue.provisioningStatus: ready
openhue missing pack/bin fields: none

adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/openhue version

#  Version      0.24-1-g08e940a
#   Commit      https://github.com/openhue/openhue-cli/commit/08e940a9cd1c49c2da0a714dc8bb07ee60e9cd21
# Built at      2026-06-08T00:00:00Z
```

This does not yet mean a remote `android-cli-core-pack` is built, hosted,
signed by a production key, or safe to install for users. It also does not yet
mean the OpenHue bridge pairing/local-network smoke passed against an actual Hue
bridge. It means APK-provided CLI-core binaries can now be discovered, selected
as a dependency pack, copied into managed Native state, receipted, executed, and
reinstalled if the managed file disappears; `openhue` is now the first real
payload in that lane.

Latest host/APK proof after the Eightctl payload slice:

```text
.\scripts\cli_core\build_eightctl_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
8242e7624b6c0e3c9bd1fa932b515f8d589c47be09940da9032230f75d88d755

flutter test test/android_cli_core_payload_packaging_test.dart
Result: 6/6 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 37/37 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/eightctl
length 10158376, sha256
8242e7624b6c0e3c9bd1fa932b515f8d589c47be09940da9032230f75d88d755
```

Eightctl installed-device proof now confirms managed-bin execution:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/eightctl version

2f2c73f
```

`/device/health` reports no missing pack/bin fields for `eightctl`, but the
skill remains `needs_config` until Eight Sleep account/device config exists.

Latest host/APK proof after the Sonos payload slice:

```text
.\scripts\cli_core\build_sonos_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
411713ad1cd0e6841db7f5a6583d9d2f1767c1ef8c5f1cf143a666d5717ee8b5

flutter test test/android_cli_core_payload_packaging_test.dart
Result: 8/8 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 39/39 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/sonos
length 10813736, sha256
411713ad1cd0e6841db7f5a6583d9d2f1767c1ef8c5f1cf143a666d5717ee8b5
```

Sonos installed-device proof now confirms managed-bin execution:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/sonos --version

sonos 0.3.1
```

`/device/health` reports no missing pack/bin fields for `sonoscli`, but the
skill remains `needs_config` until Sonos target/device setup exists. Do not
treat `sonoscli` as LAN-smoked until bounded discovery/control smoke is
verified on a real network.

Latest host/APK proof after the Blu payload slice:

```text
.\scripts\cli_core\build_blu_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442

flutter test test/android_cli_core_payload_packaging_test.dart
Result: 10/10 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart
Result: 41/41 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/blu
length 8257832, sha256
9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442
```

Blu installed-device proof now confirms `/device/health` readiness and
managed-bin execution:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/blu --version

v0.1.4
```

Do not treat `blucli` as BluOS-smoked until bounded discovery/control smoke is
verified on a real network/player.

Latest host/APK proof after the Wacli payload slice:

```text
.\scripts\cli_core\build_wacli_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
63d36f54e82d8a2e76b2ef9ae44fe41b3c0bc0474ea19b9f31aae39ab9b43453

flutter test test/android_cli_core_payload_packaging_test.dart --no-pub
Result: 12/12 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart --no-pub
Result: 43/43 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/wacli
length 21713936, sha256
63d36f54e82d8a2e76b2ef9ae44fe41b3c0bc0474ea19b9f31aae39ab9b43453
```

Wacli installed-device proof now confirms `/device/health` readiness and
managed-bin execution:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/wacli version

v0.11.0-10-gbe2d22f
```

Do not treat `wacli` as account-smoked until `wacli auth status`, QR pairing,
and a bounded account workflow are verified against a real account.

Latest host/APK proof after the Himalaya payload slice:

```text
.\scripts\cli_core\build_himalaya_android_arm64.ps1 -InstallAsset
Result: deterministic rebuild/install PASS twice; output and asset SHA both
83c900e58ff0ab931187fea7c49a36a29343e291ea8179b876c37bfbb34d572b

flutter test test/android_cli_core_payload_packaging_test.dart --no-pub
Result: 14/14 passing

flutter test test/skill_provisioning_service_test.dart \
  test/android_cli_core_payload_packaging_test.dart \
  test/dependency_pack_manifest_test.dart \
  test/android_skill_readiness_service_test.dart \
  test/android_skill_readiness_view_model_test.dart --no-pub
Result: 45/45 passing

flutter analyze test/android_cli_core_payload_packaging_test.dart
Result: no issues

flutter build apk --debug
Result: PASS, APK includes
assets/flutter_assets/assets/openclaw/cli-core/bin/himalaya
length 28958664, sha256
83c900e58ff0ab931187fea7c49a36a29343e291ea8179b876c37bfbb34d572b
```

Himalaya installed-device proof confirms `/device/health` readiness and
managed-bin execution:

```text
adb shell run-as com.nxg.openclawproot \
  files/native-node-embedded/native-home/.openclaw/bin/himalaya --version

himalaya v1.2.0 +maildir +wizard +smtp +pgp-commands +sendmail +imap
build: android  aarch64
git: v1.2.0, rev 1b70c4e0eaa72dee48353f0211e6cc0f0776fe98
```

Do not treat `himalaya` as mail-account-smoked until account discovery and a
configured IMAP/SMTP workflow are verified against real user mail config.

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
1. openhue: built and bundled as an APK-local Android arm64 payload; bridge
   pairing/local-network smoke still pending.
2. eightctl: built and bundled as an APK-local Android arm64 payload; Eight
   Sleep credentials and real account/device smoke still pending.
3. himalaya: built and bundled as an APK-local Android arm64 Rust payload;
   configured mail account discovery and IMAP/SMTP workflow smoke are still
   pending.
4. sonoscli/sonos: built and bundled as an APK-local Android arm64 payload;
   local-network discovery needs Android multicast/network review.
5. blucli/blu: built and bundled as an APK-local Android arm64 payload; BluOS
   mDNS/LSDP discovery, player control, and target config are the main smoke
   blockers.
6. wacli: built and bundled as an APK-local Android arm64 cgo payload; WhatsApp
   QR pairing, account auth persistence, and device workflow smoke are still
   pending.
```

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

Round 5C target:

```text
android-vision-media-runtime APK-local lane exists.
ffmpeg is the only advertised vision-media binary at this plumbing checkpoint.
video-frames remains blocked until real ffmpeg payload + smoke/device proof.
gifgrep remains blocked at this checkpoint.
Commit made.
```

Round 5D target:

```text
Real Android arm64 FFmpeg payload is built from pinned official source.
video-frames extraction uses Native managed-bin ffmpeg, not PRoot.
Payload provenance, LGPL notice, host ELF/hash tests, and Android build pass.
Scorecard numbers move only after installed-device video proof.
Commit made.
```

Round 5E target:

```text
Real debugpy wheel payload is bundled from pinned PyPI wheel.
android-python-debug-runtime installs real wheel contents, not fake markers.
Host tests and Android debug build pass.
Scorecard numbers move only after installed-device Python import proof.
Commit made.
```

Round 5F target:

```text
android-terminal-pack APK-local bin/lib lane exists.
tmux is the only advertised terminal binary.
Terminal shared libraries install into managed .openclaw/lib.
Dependency-pack smoke env exposes OPENCLAW_NATIVE_LIB and LD_LIBRARY_PATH.
tmux remains blocked at this plumbing-only checkpoint.
Commit made.
```

Round 5G target:

```text
Real Android arm64 tmux payload is bundled from pinned Termux aarch64 packages.
Required shared libraries install into managed .openclaw/lib.
Host ELF/hash/provenance tests, Android debug build, and installed-device smoke pass.
tmux moves from needs_pack to ready after .openclaw/bin/tmux -V proof.
Commit made.
```

Round 5H target:

```text
Stale android-node-debug-pack planning bucket is removed from active manifest truth.
node-inspect-debugger is parked behind android-node-executable-pack only.
gemini is parked behind android-gemini-cli-pack plus auth/config truth.
coding-agent is parked behind android-agent-cli-pack plus auth/config truth.
Skills page pack-gate previews display user-readable pack labels.
Ready count stays 27/51 until a real payload and installed-device smoke land.
Commit made.
```

Round 5I target:

```text
Audit all eight remaining pack blockers against current code and real Android
artifact paths.
Choose songsee as the next payload lane.
Keep gifgrep, Node, Gemini, coding-agent, Whisper, Sherpa TTS, and Spotify
blocked until their real runtime, standalone-node, and config risks are solved.
Ready count stays 27/51 because this is a decision round, not payload proof.
Commit made.
```

Round 5J plumbing target:

```text
android-audio-runtime APK-local bin lane exists.
songsee is the only advertised audio-runtime binary.
spotify-player remains blocked when only songsee exists.
Ready count stays 27/51 until a real songsee payload and installed-device smoke
land.
Commit made.
```

Round 5J payload target:

```text
real Android arm64 songsee ELF is bundled in assets/openclaw/audio-runtime/bin
rebuild script verifies Go archive, source commit, Android target, and ELF
payload provenance and MIT notice are documented
packaging tests prove the payload and provenance
installed-device proof shows songsee ready and spotify-player still blocked
tiny WAV-to-PNG smoke passes on RZCX30KA9AW
Ready count moves 27/51 -> 28/51.
Commit made.
```

Round 5K payload target:

```text
real Android arm64 gifgrep ELF is bundled in assets/openclaw/vision-media/bin
gifgrep local still/sheet commands are smoked against a tiny local GIF fixture
provider search remains a separate API-key/config promise
installed-device proof shows gifgrep ready through android-vision-media-runtime
sonoscli stale planner truth is corrected to ready through the existing sonos
APK payload
Ready count moves 28/51 -> 30/51.
Commit made.
```

Round 5L config-unlock target:

```text
readiness JSON merges live requiredEnv with manifest requiredConfig
Skills page CONFIG GATES follows live runtimeStatus/provisioningStatus
pack-satisfied config blockers such as eightctl move to user setup affordances
mixed missing-pack-plus-config blockers stay in PACK GATES
release gate remains 13/13
Android ready floor remains 30/51
Commit made.
```

Round 5M truth-correction target:

```text
sherpa-onnx-tts is corrected from TTS-runtime-only to mixed gated:
  android-tts-runtime
  android-node-executable-pack
A TTS model/runtime pack alone must not move Sherpa ready in the current skill
path.
release gate remains 13/13
Android ready floor remains 30/51
Commit made.
```

Round 5N reality-check target:

```text
reality-check the remaining six true pack blockers after the Sherpa correction:
  coding-agent
  gemini
  node-inspect-debugger
  openai-whisper
  sherpa-onnx-tts
  spotify-player

decision:
  no remaining pack lane clears the GTM bar today

parked:
  node/gemini/coding-agent until standalone node, auth, sandbox, and product
  security truth exist
  openai-whisper/sherpa until runtime, model, size, license, and device-smoke
  truth exist
  spotify-player until backend/auth setup is explicit

mainline pivot:
  Phase 6A config-unlock quality

Commit made.
```

Round 6D-A target:

```text
Non-destructive release rehearsal runner exists.
Debug APK builds and installs over existing data.
/device/health release gate and taxonomy counts are verified after launch.
Safe headless Class A tool routes are smoked through AgentSkillServer.
Interactive chat/UI-only lanes are recorded separately instead of being faked.
Commit made.
```

Phase 6A target:

```text
Improve the 15 CONFIG GATES so fresh users can enter, save, and verify service
setup without guessing.

First implementation slice:
  define a small AndroidSkillConfigTestPlan model that maps configured skills
  to safe Gateway/agent tool checks
  expose Test Connection after Save & Check for app-native service adapters
  keep secrets out of visible payloads, snackbars, logs, and docs
  route checks through Gateway/AgentSkillServer tool execution, not ad hoc UI
  HTTP calls to service APIs

Release impact:
  no readiness score inflation by itself
  higher conversion from needs_config to ready for users who supply real keys
  clearer support path for Slack, GitHub, Notion, Discord, Trello, MCPorter,
  Google Places, OpenAI Whisper API, and later config-only services
```

Phase 6A first slice landed:

```text
AndroidSkillConfigTestPlan maps supported config-gated skills to local
AgentSkillServer /api/tools/execute checks:
  discord -> discord
  github / gh-issues -> github
  goplaces -> goplaces with query=OpenClaw limit=1
  mcporter -> mcporter
  notion -> notion with query=OpenClaw limit=1
  openai-whisper-api -> openai-whisper-api with a tiny generated WAV fixture
  slack -> slack
  trello -> trello with limit=1

AndroidSkillConfigTestService posts only to the local AgentSkillServer bridge
and sanitizes UI-visible summaries. The Skills config sheet now keeps supported
service-adapter flows open after Save & Check and reveals Test Connection.

Readiness impact:
  release gate unchanged at 13/13
  Android ready floor unchanged at 30/51
  CONFIG GATES are easier for users to unlock, but scores move only after real
  user config and live service checks pass on device
```

Phase 6A device proof and schema correction landed:

```text
Device: RZCX30KA9AW / Samsung SM-A556E
Build/install: debug APK installed over existing app data

/device/health after corrected install:
releaseGatePass: true
ready_required: 13/13
classified default manifest: 61
installed Native workspace skills: 65
ready_optional: 7
needs_config: 14
needs_pack: 17
unsupported_on_android: 6
manual_proot_compat: 2
hidden_desktop_only: 2
unexpected_missing_dependency: 0

Root-cause catch from device proof:
the first Phase 6A plan used bridge-tolerated aliases for several service
checks, but some payloads did not include the same `action` fields advertised
by `/api/tools`. GTM-quality config tests should match the published tool
schema, not rely on forgiving handler aliases.

Corrected config-test payloads now include:
discord action=me
github action=user
gh-issues owner=openai repo=codex state=open limit=1
mcporter action=health
slack action=me
trello action=boards limit=1
goplaces query=OpenClaw limit=1
notion query=OpenClaw limit=1
openai-whisper-api tiny WAV fixture, gpt-4o-mini-transcribe

Live missing-config proof after corrected install:
discord -> HTTP 400 MISSING_DISCORD_BOT_TOKEN
github -> HTTP 400 MISSING_GITHUB_TOKEN
gh-issues -> HTTP 400 MISSING_GITHUB_TOKEN
goplaces -> HTTP 400 MISSING_GOOGLE_PLACES_API_KEY
mcporter -> HTTP 400 MISSING_MCPORTER_CONFIG
notion -> HTTP 400 MISSING_NOTION_TOKEN
openai-whisper-api -> HTTP 400 MISSING_OPENAI_API_KEY
slack -> HTTP 400 MISSING_SLACK_CONFIG
trello -> HTTP 400 MISSING_TRELLO_CONFIG

Readiness impact:
release gate unchanged at 13/13
Android ready floor unchanged at 30/51
The connection-test UI is now aligned with the live AgentSkillServer tool
schema for supported service adapters. The nine app-native config services have
connection-test plans; the six remaining config gates are save-only until a
real production service/test surface exists.
```

Phase 6B risk-aware UX landed:

```text
Risk-aware connection-test UX.

Safe-read checks such as Slack, GitHub, GitHub Issues, Discord, Trello, and
MCPorter run directly after Save & Check. Query-read checks such as Notion and
Google Places show the exact bounded query before execution. Billable checks
such as OpenAI Whisper API require explicit confirmation before posting to
AgentSkillServer /api/tools/execute.

Save-only config gates are explicit in the sheet: 1Password, eightctl, GOG,
ordercli, SAG, and voice-call can save env/config through the same provisioning
path, but the app does not pretend they have live connection tests yet.

Coverage:
connection tests: 9/15 live config gates
save-only config UX: 6/15 live config gates
release gate: unchanged at 13/13
Android ready floor: unchanged at 30/51

Device proof after Phase 6B install:
releaseGatePass: true
ready_required: 13/13
classified default manifest: 61
installed Native workspace skills: 65
gh-issues schema-shaped execute -> HTTP 400 MISSING_GITHUB_TOKEN
```

Phase 6C provider-aware setup truth landed:

```text
The config sheet now builds connection/setup plans from the saved field values,
not just from the skill ID. This matters for generic skills whose production
tool surface only exists for one provider.

voice-call:
  VOICE_CALL_PROVIDER=twilio now reveals a Gateway-routed setup-status check:
    tool: twilio-voice
    input: { source: android-skill-config-test, method: get_status }
    risk: safe read
    button: Check Setup Status
  VOICE_CALL_PROVIDER=telnyx/custom remains save-only until real provider
  adapters exist.

The setup-status check is deliberately stricter than HTTP success:
  configured:false, connected:false, ready:false, CONFIG_REQUIRED, MISSING,
  ERROR, FAILED, or DISCONNECTED are treated as failed checks even if the
  bridge returns HTTP 200 or success:true.

eightctl:
  remains save-only for live account/device validation.
  UI now labels the setup as Eight Sleep, with an Eight Sleep password field.
  The sheet tells users the APK-local eightctl binary is tracked by device
  health, but live Eight Sleep account/device validation is not available yet.

Freshness / stale-state hardening:
  editing a saved field clears the saved/test state until the user saves again.

Coverage after Phase 6C:
  connection tests: 9/15 live config gates
  conditional setup-status checks: 1/15 live config gates
  save-only/mixed config UX: 5 gates plus non-Twilio voice-call providers
    pure save-only: eightctl
    mixed runtime: 1Password, GOG, ordercli, SAG
  release gate: unchanged at 13/13
  Android ready floor: unchanged at 30/51

Phase 6C expansion / no-fake-readiness audit:
  We rechecked every remaining config-gated Android default skill against the
  actual Gateway, AgentSkillServer, app-native adapter, and bundled-payload
  surfaces. No additional production-safe live adapter exists yet for
  1Password, GOG, ordercli, SAG, or eightctl live account/device validation.
  Those lanes stay save-only by design until a real Android execution surface
  exists.

  Skills page production UX now exposes this ceiling directly:
    LIVE TESTS: app-native service adapters with a real bounded live check
    SETUP CHECKS: provider-aware setup status checks such as Twilio voice-call
    SAVE ONLY: user config can be saved, but no live Android adapter is present
    CONFIG CLASS / PACK CLASS: static taxonomy counts from the Android default
      manifest, shown beside current blocker counts so users can see why
      pack-class rows such as eightctl can move into config gates after their
      binary/runtime pack is satisfied

  Config-gated rows now carry LIVE / SETUP / SAVE badges, and save-only sheets
  name the missing Gateway/AgentSkillServer adapter boundary instead of showing
  a generic "no test yet" message. This raises user clarity without raising the
  readiness count falsely.

Phase 6C second-pass UI count sweep:
  Skills page cards now show both current actionable blocker counts and static
  manifest taxonomy counts:
    CONFIG BLOCKERS: 15 current gates users can act on now
    CONFIG CLASS: 14 static needs_config manifest rows
    PACK BLOCKERS: 6 remaining true missing artifact lanes
    PACK CLASS: 17 static needs_pack manifest rows
  The coverage note explains that current blocker cards can differ from
  taxonomy when a pack-class skill is now only waiting on user config. This is
  intentional product truth, not count drift.

Device proof after Phase 6C install:
  releaseGatePass: true
  ready_required: 13/13
  classified default manifest: 61
  installed Native workspace skills: 65
  unexpected_missing_dependency: 0
  eightctl requiredEnv: EIGHTCTL_PASSWORD
  eightctl requiredConfig: none
  voice-call requiredConfig:
    VOICE_CALL_PROVIDER
    VOICE_CALL_ACCOUNT
    plugins.entries.voice-call.enabled
  twilio-voice get_status:
    HTTP 200, configured:false, connected:false, status: CONFIG_REQUIRED
  UI/service interpretation:
    failed setup-status check, not ready, no readiness inflation

Device proof after Phase 6C expansion install:
  releaseGatePass: true
  ready_required: 13/13
  classified default manifest: 61
  installed Native workspace skills: 65
  unexpected_missing_dependency: 0
  ready_optional taxonomy: 7
  needs_config taxonomy: 14
  needs_pack taxonomy: 17
  unsupported_on_android taxonomy: 6
  manual_proot_compat taxonomy: 2
  hidden_desktop_only taxonomy: 2
  UI coverage model:
    live connection checks: 9
    conditional setup-status checks: 1
    pure save-only config gates: 1
    mixed runtime config gates: 4
```

Phase 6D-A non-destructive release rehearsal landed:

```text
Runner:
  scripts/android/run_phase_6d_release_rehearsal.ps1

Mode:
  non-destructive; no app data clear and no uninstall

Device:
  RZCX30KA9AW / Samsung SM-A556E

Build/install:
  flutter build apk --debug: PASS
  flutter install -d RZCX30KA9AW --debug: PASS
  later proof reruns used -SkipBuild -SkipInstall against that installed APK

Strict release proof:
  releaseGatePass: true
  ready_required: 13/13
  classified default manifest: 61
  installed Native workspace skills: 65
  unexpected_missing_dependency: 0
  /api/tools catalog count: 25

Required headless tool smokes through AgentSkillServer:
  device-health: PASS
  device-status: PASS
  battery: PASS
  sensors: PASS
  weather: PASS
  clawhub: PASS
  meme-maker: PASS
  vibrate: PASS
  avatar-status: PASS
  total: 9/9

Optional chat-smoke probe:
  haptic prompt: TOOL_USE and TOOL_RESULT observed; final assistant text timed
    out inside the smoke endpoint, so the tool lane passed but the model
    continuation is not yet a clean final-answer proof.
  device-health prompt: host request timed out before the endpoint returned.

Interpretation:
  Phase 6D-A proves the installed APK's release gate and concrete local
  app-native tool routes without destroying user data. It does not yet replace
  the true clean-data proof and it does not claim headless proof for
  instruction-only or UI-stateful Class A lanes such as skill-creator, spike,
  taskflow, taskflow-inbox-triage, and canvas.

Next gate:
  Phase 6D-B clean-data proof requires explicit approval to clear app data or
  uninstall/reinstall because it destroys local app state.
```

Phase 6D-B clean-install proof landed:

```text
Date:
  2026-06-11

Mode:
  destructive uninstall/reinstall was explicitly approved for this phase
  user manually completed first-run provider setup with OpenRouter
  patched APK was installed over that clean setup state without clearing data
  again

Fresh-run blocker found:
  Setup reached Gateway verification, then timed out with:
  ws=true, interactive=false, health=false, skills=0

Root cause:
  The fresh install had the default OpenClaw package skills inside the bundled
  package roots, but the Android release gate only scanned mutable .openclaw
  workspace skill roots. Warm prior installs hid this because older workspace
  copies already existed.

Missing launch-required skill IDs before the fix:
  skill-creator
  spike
  taskflow
  taskflow-inbox-triage

Fix:
  Skill parity, OpenClaw skill listing, skill markdown lookup, and Native smoke
  scanning now include the bundled OpenClaw package roots:
    native-node-embedded/full-openclaw/lib/node_modules/openclaw/skills
    rootfs/ubuntu/usr/local/lib/node_modules/openclaw/skills
  Splash routing now resumes SetupWizard when credentials were already saved
  but bootstrap did not complete.
  Gateway startup can accept a bounded Android release-gate pass while RPC
  discovery warms, instead of failing a valid fresh setup.

Regression proof:
  flutter test test/skill_parity_audit_service_test.dart: PASS
  flutter test test/android_skill_readiness_service_test.dart: PASS
  flutter test test/skill_provisioning_service_test.dart: PASS
  flutter test test/skill_parity_audit_service_test.dart
    test/android_skill_readiness_service_test.dart: PASS
  flutter analyze: PASS
  flutter build apk --debug: PASS

Device result after patched retry:
  setup completed
  dashboard opened
  Gateway LIVE

Runner:
  scripts/android/run_phase_6d_release_rehearsal.ps1
  .tmp/phase-6d-b-clean-install-rehearsal.json

Strict release proof:
  releaseGatePass: true
  ready_required: 13/13
  classified default manifest: 61
  installed Native package/workspace skills: 60
  unexpected_missing_dependency: 0
  /api/tools catalog count: 25

Required headless tool smokes through AgentSkillServer:
  device-health: PASS
  device-status: PASS
  battery: PASS
  sensors: PASS
  weather: PASS
  clawhub: PASS
  meme-maker: PASS
  vibrate: PASS
  avatar-status: PASS
  total: 9/9

Interpretation:
  Phase 6D-B is the first real clean-install GTM proof. The correct clean
  installedNativeSkills number is 60 because that field counts file-backed
  OpenClaw package/workspace skill directories. It must not be inflated to 61:
  app-native manifest capabilities are real release capabilities, but they are
  not all file-backed skill directories. The release gate remains the hard
  launch promise, and it is green at 13/13 with zero unexpected missing
  dependencies.
```

Phase 6E UI truth audit landed:

```text
Scope:
  device UI audit against live /device/health and /api/tools after the Phase
  6D-B clean-install path

Pages checked:
  Dashboard
  Management dashboard
  Skills readiness panel
  Skills config sheets for Slack, voice-call, and 1Password
  Skills Tools tab

Expected readiness truth remains:
  releaseGatePass: true
  ready_required: 13/13
  Android ready ceiling: 30/51
  current config blockers: 15
  current pack blockers: 6
  config coverage: 9 live + 1 setup / 15
  pure save-only config gates: 1
  mixed runtime config gates: 4
  /api/tools catalog count: 25

Fixes:
  Dashboard now displays the gateway URL without exposing the auth token, while
  copy/open actions still use the authenticated URL.
  Management dashboard TOOLS now reads the app-native AgentSkillServer catalog
  from SkillsService instead of a stale hardcoded 19 count.
  Skills grid label now says DEFAULT & SERVICE SKILLS because it contains
  installed/default workspace skills plus service catalog cards, not only
  premium partner tiles.
  Android readiness badge overrides now classify unsupported/manual
  PRoot/desktop-only rows as OUTSIDE GTM, MANUAL PROOT, or DESKTOP ONLY instead
  of letting provisioning status present them as Android missing dependency
  failures.
  Dashboard Terminal card now says Manual rollback shell so PRoot remains
  framed as a fallback lane, not the primary Android runtime.

Regression tests:
  gateway URL display sanitization
  Android readiness badge override classification
```

Phase 6F config round-trip UX hardening landed:

```text
Scope:
  Skills config sheets after Save & Check

Product fix:
  The sheet now keeps the last provisioning result in durable UI state instead
  of relying only on a transient snackbar. Users can see whether config was
  saved, whether Gateway refresh was requested, and whether a native/runtime
  gate remains.

Safety:
  The persistent status uses provisioning status, gate, changed, and reload
  flags only. It does not render typed secret values.
  Editing any saved field clears the saved/provisioning/test state so users
  are not shown stale readiness.

GTM interpretation:
  This does not inflate readiness counts. It makes the existing Gateway-backed
  configure -> provision -> refresh -> optional test flow visible enough for a
  fresh user to trust what happened.

Regression tests:
  successful save shows sanitized Gateway refresh status
  editing saved values clears provisioning status
  full config-sheet suite: PASS

Verification:
  flutter test test/android_skill_config_sheet_test.dart
    test/android_skill_config_form_model_test.dart
    test/android_skill_config_test_plan_test.dart
    test/skill_provisioning_service_test.dart: PASS
  flutter analyze: PASS
  flutter build apk --debug: PASS
  flutter install -d RZCX30KA9AW --debug: PASS
  non-destructive Phase 6D release rehearsal after install:
    releaseGatePass: true
    ready_required: 13/13
    classified default manifest: 61
    installed Native package/workspace skills: 60
    unexpected_missing_dependency: 0
    required tool smokes: 9/9
```

Phase 6G config coverage closeout landed:

```text
Scope:
  Fresh-user config coverage truth for Android default skills.

Fixes:
  App-native config gates now treat the static Android manifest as the
  canonical config contract. Stale/internal OpenClaw matrix keys such as
  NEXT_PAGE_TOKEN or alternate provider token names no longer pollute
  /device/health requiredEnv/requiredConfig for app-native service adapters.

  Mixed env+config app-native services such as Slack now project satisfied
  provisioning consistently:
    ready: true
    runtimeStatus: app_native_ready
    provisioningStatus: app_native_config_ready
  This keeps the Skills page, config sheet, and health JSON aligned after a
  user saves real config.

  voice-call static manifest now includes the enabled toggle alongside provider
  and account:
    VOICE_CALL_PROVIDER
    VOICE_CALL_ACCOUNT
    plugins.entries.voice-call.enabled

  Connection-test summaries redact broader provider token formats, including
  OpenAI sk/sk-proj, GitHub ghp/github_pat, Notion secret_, Discord mfa/JWT-ish
  token shapes, Bearer tokens, labelled token/api-key strings, Slack xox, and
  Twilio IDs.

  Skills page config metrics now split pure SAVE ONLY config gates from MIXED
  GATES that can save user config but still need native runtime/artifact work.
  This prevents 1Password/GOG/ordercli/SAG-style lanes from being presented as
  simple save-only adapters when they still have runtime blockers.

Regression tests:
  app-native mixed env/config gates use satisfied provisioning status
  app-native config gates ignore stale matrix-only required keys
  all static needs-config manifest keys have user-facing form metadata
  voice-call manifest includes full config contract
  redacts common provider token formats from scalar summaries
  separates pure save-only config from mixed runtime gates

Verification:
  flutter test test/android_skill_readiness_service_test.dart
    test/android_skill_readiness_view_model_test.dart
    test/android_skill_support_manifest_test.dart
    test/android_skill_config_form_model_test.dart
    test/android_skill_config_test_plan_test.dart
    test/android_skill_config_test_service_test.dart
    test/android_skill_config_sheet_test.dart
    test/skill_provisioning_service_test.dart: PASS
  flutter analyze: PASS
  flutter build apk --debug: PASS
  flutter install -d RZCX30KA9AW --debug: PASS
  non-destructive Phase 6D release rehearsal after install:
    releaseGatePass: true
    ready_required: 13/13
    classified default manifest: 61
    installed Native package/workspace skills: 60
    unexpected_missing_dependency: 0
    required tool smokes: 9/9
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

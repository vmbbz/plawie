# Native Android skill test checklist

This is the persistent checklist for the Skills page's top-to-bottom order.
`contract-pass` means the native adapter/readiness contract is covered by
automated tests; it does not claim a live provider call has completed.
`device-pass` means a real Android bridge, managed binary, or app-native
adapter was exercised on the phone. It is not a UI/user-flow pass. `ui-pass`
requires opening the relevant Skills card, resolving any dependency/config
gate in the app, invoking the skill from its intended user surface, and
verifying the rendered result. No row receives `ui-pass` from an HTTP bridge
probe alone.

Legend: `[ ]` pending, `[x]` passed, `[~]` blocked or partial, `[-]` skipped by
Android GTM policy (configuration, desktop/PC, unsupported, or explicit
PRoot-only mode).

Next device smoke: none in the current eligible set. The next phase is UI/user
flow verification for the device-pass rows, plus fixture/config completion for
the partial rows (`songsee`, `video-frames`, `openai-whisper`). The Android bridge smokes for `avatar_forge` and
`battery` are complete. `browser-automation` is explicitly outside the native
catalog; continue with the next eligible UI row after it.

| # | Skill | State | Evidence / next action |
|---:|---|---|---|
| 1 | 1password | [-] config | Requires Connect host/token |
| 2 | apple-notes | [-] outside GTM | macOS integration |
| 3 | apple-reminders | [-] outside GTM | macOS integration |
| 4 | avatar_forge | [x] device-pass / UI pending | Native `avatar-control` set the avatar emotion to `happy` through `/api/tools/execute`; user-surface verification remains pending. |
| 5 | battery | [x] device-pass / UI pending | Native `device-node` returned level 66 and `isCharging: true`; user-surface verification remains pending. |
| 6 | bear-notes | [-] outside GTM | macOS/iOS integration |
| 7 | blogwatcher | [x] device-pass / UI-pass | Skills card was READY; chat request for `https://github.blog/feed/` rendered five parsed feed items, including GitHub security and Copilot entries, without a Go/binary/config error. |
| 8 | blucli | [x] device-pass / UI pending | Verified `android-cli-core-pack` receipt and `blu --help`/`--version` on ARM64; `blu --json devices` returned an empty list, so no BluOS player was available for network control smoke. |
| 9 | camsnap | [x] device-pass / UI-pass | Skills card was READY; chat request rendered the green `Result camsnap` panel and confirmed a successful back-camera snapshot. The earlier native JPEG was 480x720, 159,460 bytes. |
| 10 | canvas | [~] partial / UI blocked | Skills page is READY through the Android app-native path. A fresh chat request (`Use canvas to show a simple red circle with the title Test Canvas`) completed with only the malformed assistant fragment `<g`; no canvas surface rendered, so close-button sizing/centering could not be re-verified. Investigate the live agent/tool response path before marking UI-pass. |
| 11 | clawhub | [x] contract-pass | Native ClawHub adapter tests |
| 12 | coding-agent | [-] native gap | Released pack quarantined until `/tmp` issue is fixed |
| 13 | diagram-maker | [x] contract-pass / READY | Skills page shows READY with “Instruction-only skill ready”; no executable dependency is required. |
| 14 | discord | [-] config | Requires bot token |
| 15 | eightctl | [-] config | Requires CLI pack plus credentials |
| 16 | gemini | [-] config | Requires API key |
| 17 | gh-issues | [-] config | Requires GitHub token |
| 18 | gifgrep | [~] device-pass / UI config-gate | Skills card/detail showed READY/ACTIVE. A real chat request for a cat GIF opened the intended “Configure gifgrep search” sheet with GIPHY and KLIPY fields; the sheet correctly states that online search needs a provider key while local still/contact-sheet operations remain key-free. Search cannot be marked live without a provider key; local still/sheet remains fixture-pending. |
| 19 | github | [-] config | Requires GitHub token |
| 20 | gog | [-] outside GTM | Desktop/Google Workspace workflow |
| 21 | goplaces | [-] config | Requires Places API key |
| 22 | healthcheck | [x] contract-pass | Android readiness tests |
| 23 | himalaya | [x] device-pass / config gate / UI pending | Verified CLI-core receipt and ARM64 `himalaya --version`/`--help`; account discovery reached the expected missing-config gate without a TTY or credentials. |
| 24 | imsg | [-] outside GTM | macOS Messages integration |
| 25 | mcporter | [-] config | Requires endpoint/token |
| 26 | meme-maker | [x] contract-pass | Native renderer tests |
| 27 | model-usage | [-] outside GTM | Desktop accounting |
| 28 | nano-pdf | [x] contract-pass | Native PDF adapter tests |
| 29 | node-connect | [-] PRoot-only | Manual compatibility mode |
| 30 | node-inspect-debugger | [-] native gap | Node executable pack not production-ready |
| 31 | notion | [-] config | Requires Notion token |
| 32 | obsidian | [-] outside GTM | Desktop vault workflow |
| 33 | openai-whisper | [~] pack-pass / transcription pending | Verified `android-whisper-runtime` receipt and managed launcher smoke; direct shell execution without the managed `LD_LIBRARY_PATH` correctly fails to load `libomp.so`. A real local transcription fixture is still required before full live-pass. |
| 34 | openai-whisper-api | [-] config | Requires OpenAI API key |
| 35 | openhue | [~] pack-pass / config gate | Verified the shared CLI-core receipt and ARM64 binary launch; `openhue` correctly stopped at its required first-run `setup` configuration gate. |
| 36 | oracle | [-] PRoot-only | Manual compatibility mode |
| 37 | ordercli | [-] outside GTM | Desktop/browser-heavy login |
| 38 | peekaboo | [-] outside GTM | macOS screen automation |
| 39 | python-debugpy | [x] device-pass / UI pending | Current device has `android-python-debug-runtime.json` and `python-wheels/debugpy.json`, both `smokePassed: true`; the Skills page no longer lists it as a download gate. The APK-local pack remains separate from GitHub dependency-packs-v4. |
| 40 | sag | [-] config | Requires ElevenLabs API key |
| 41 | sensors | [x] device-pass / UI pending | Native `device-node` listed accelerometer, gyroscope, magnetometer, and barometer; an accelerometer read returned valid x/y/z values and accuracy 3. |
| 42 | session-logs | [x] contract-pass | App-native session adapter tests |
| 43 | sherpa-onnx-tts | [-] native gap | Runtime/model and standalone Node host pending |
| 44 | skill-creator | [x] contract-pass | Instruction-only adapter tests |
| 45 | slack | [-] config | Requires token and channel config |
| 46 | songsee | [~] pack-pass / audio fixture pending | Verified audio-runtime receipt and ARM64 `songsee --version`/`--help`; no app-owned WAV/MP3 fixture was present for the output-image smoke. |
| 47 | sonoscli | [~] device-pass / UI blocked | Skills page showed READY and the v4 CLI-core receipt contains an executable `sonos` binary. A fresh chat request reached the skill, but the agent reported that Android does not support the `sonos discover` command directly; this is a command-policy/routing gap, not a missing dependency. |
| 48 | spike | [x] contract-pass | Instruction-only adapter tests |
| 49 | spotify-player | [-] config | Requires Spotify token |
| 50 | stocks | [x] device-pass / UI pending / badge repair | Native `Tools().get_stock_price("AAPL")` returned a live quote; embedded inventory prevents redundant downloads; Stocks is now explicitly classified in the Android readiness manifest |
| 51 | summarize | [x] contract-pass | App-native adapter tests |
| 52 | taskflow | [x] contract-pass | Instruction-only adapter tests |
| 53 | taskflow-inbox-triage | [x] contract-pass | Instruction-only adapter tests |
| 54 | things-mac | [-] outside GTM | macOS Things integration |
| 55 | tmux | [x] device-pass / managed smoke / UI pending | Verified `android-terminal-pack` receipt; the app-managed pack smoke passed. Raw shell execution without the managed library path is intentionally not the app execution path. |
| 56 | trello | [-] config | Requires Trello credentials |
| 57 | vibrate | [x] device-pass / UI pending | Native `device-node` vibrated for 100 ms and returned success; battery bridge remained healthy at level 77 while charging. |
| 58 | video-frames | [~] pack-pass / video fixture pending | Verified the shared vision-media receipt and ARM64 FFmpeg 8.1.1 `-version`; no app-owned MP4/MOV fixture was present for a frame-extraction smoke. |
| 59 | voice-call | [-] config | Requires provider/account/plugin config |
| 60 | wacli | [x] device-pass / auth gate / UI pending | Verified CLI-core receipt, ARM64 v0.11.0 help/version, and read-only `wacli doctor --json`; it correctly reports `authenticated:false` and the absent local store without attempting WhatsApp auth or sync. |
| 61 | weather | [x] contract-pass | Native HTTP adapter tests |
| 62 | xurl | [x] contract-pass | Native HTTP adapter tests |
| 63 | browser-automation | [~] native unavailable | Explicit `/api/tools/execute` probe returned HTTP 400 because the native AgentSkillServer catalog does not register this tool; requires the separate browser/desktop lane and is skipped in the native UI sequence. |

## Evidence baseline

- Ordered native adapter/readiness suite: 152 automated tests passed on
  2026-08-03.
- 2026-08-04 live Skills page truth: `31/50 ready now`, `14/14 launch gate`,
  `15 needs config`, `4 needs download`, and `12 outside GTM`. The four live
  pack gates are `coding-agent`, `node-inspect-debugger`, `sherpa-onnx-tts`, and
  `wacli`; this is not a 21-item missing-dependency list. `diagram-maker`,
  `canvas`, `gifgrep`, and `python-debugpy` were visibly ready on the page.
- Stocks was installed from the Skills page and verified in the native
  workspace.
- Device smokes must record the prompt, output, and relevant dependency receipt
  before a row is marked device-pass; a separate UI/user-flow trace is required
  before marking a row ui-pass.
- 2026-08-03 device evidence: `avatar-control` set `happy`, `device-node`
  returned battery level 66 while charging, and `camsnap` returned a real
  JPEG. `blogwatcher` returned two parsed items each from GitHub releases and
  Hacker News after the device reconnected. The OpenAI feed was correctly
  rejected by the 200 KB response guard. `browser-automation` is not
  registered in the native Android tool catalog. A follow-up natural-language
  blogwatcher prompt exposed a routing gap: it fell through to the upstream
  Go-based skill. The parser now recognizes `blogwatcher` plus an HTTP(S) feed
  URL in natural wording, and the app-local adapter does not require a paired
  Android node or a native Go compiler.
- `blogwatcher` UI evidence: the Skills card was READY and a natural chat
  request for `https://github.blog/feed/` rendered five parsed items in the
  chat surface. The response stayed on the app-native feed adapter.
- `blucli` device evidence: receipt `android-cli-core-pack.json` reports
  `smokePassed: true`; the installed `blu` digest is
  `9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442`, and
  read-only command discovery returned the expected v0.1.4 command catalog.
- `gifgrep` device evidence: receipt `android-vision-media-pack.json` reports
  `smokePassed: true`; the generic native catalog now declares bounded
  `status/search/still/sheet` actions, live status returned v0.3.0, and search
  returned `GIFGREP_PROVIDER_CONFIG_REQUIRED` with `runtimeReady: true` and
  `installationRequired: false` when no provider key was configured.
- `gifgrep` UI evidence: the READY/ACTIVE card was opened and a natural chat
  request for a cat GIF opened the “Configure gifgrep search” sheet. The sheet
  exposed GIPHY/KLIPY fields and explicitly explained that local still frames
  and contact sheets do not need a provider key. No key was entered or saved.
- `himalaya` device evidence: the shared `android-cli-core-pack.json` receipt
  reports `smokePassed: true`; ARM64 version output was v1.2.0 with IMAP/SMTP
  support, and `account list` reached the expected missing
  `~/.config/himalaya/config.toml` gate because no mail account was configured.
- `openai-whisper` device evidence: `android-whisper-runtime.json` reports
  `smokePassed: true` and includes `libomp.so`; the managed native launcher owns
  the library path, while a raw shell launch is intentionally not a valid app
  smoke. No audio/model fixture was available for a transcription proof, so the
  row remains partial rather than being overstated as fully live.
- `python-debugpy` device evidence: the current device has
  `android-python-debug-runtime.json` and `python-wheels/debugpy.json`, both
  with `smokePassed: true`; the installed package is debugpy 1.8.21. This is
  an APK-local lane, not a GitHub v4 release asset.
- `sonoscli` UI evidence: the Skills page reported READY, the shared
  `android-cli-core-pack.json` receipt lists `sonos`, and both managed copies
  were executable. A fresh natural chat request reached the skill, but the
  rendered answer said Android does not support `sonos discover` directly.
  Keep this as a UI-blocked command-policy result until the native executor is
  wired to the allowed discovery path; do not relabel it as missing deps.
- `camsnap` UI evidence: the Skills page reported READY and a fresh natural
  chat request rendered the green `Result camsnap` panel with “Your snapshot
  was taken successfully” from the back camera.
- `canvas` UI evidence: a fresh chat request reached completion without an
  explicit gateway error, but rendered only the literal fragment `<g` and did
  not show the canvas WebView. This is a UI-blocked result, not a successful
  canvas smoke; the live tool/agent response path still needs investigation.
- `songsee` device evidence: `android-audio-runtime-pack.json` reports
  `smokePassed: true`; ARM64 version output was `v0.1.1-10-g41d27ea` and help
  output exposed the bounded audio-to-image command. No audio fixture was
  available for a non-destructive image-generation smoke.
- `tmux` device evidence: `android-terminal-pack.json` reports
  `smokePassed: true`; the pack contains the verified ARM64 binary and its
  shared libraries, which are loaded through the app-managed native launcher.
- `vibrate` device evidence: `/api/tools/execute` returned
  `{"success":true,"status":"vibrated"}` for a bounded 100 ms haptic and the
  follow-up battery read returned level 77 while charging.
- `openhue` device evidence: the shared `android-cli-core-pack.json` receipt
  reports `smokePassed: true`; the ARM64 binary launched and returned its
  non-secret first-run configuration message instead of a missing-binary error.
- `sensors` device evidence: `/api/tools/execute` listed four Android sensors;
  the accelerometer read returned x=0.263, y=-0.141, z=9.857 and accuracy 3.
- `video-frames` device evidence: `android-vision-media-pack.json` reports
  `smokePassed: true`; managed `ffmpeg -version` reports FFmpeg 8.1.1 with the
  bounded file-only video demux/decode configuration. No video fixture was
  available for a non-destructive JPEG-frame proof.
- `wacli` device evidence: the shared `android-cli-core-pack.json` receipt
  reports `smokePassed: true`; ARM64 version output was v0.11.0 and
  `wacli doctor --read-only --json` returned a clean disconnected/unauthenticated
  state with no local database, without starting QR auth or sync.

## Dependency repair UI

Installed skills with a repairable Native dependency gate expose **Resolve
native dependencies** from the skill detail sheet. The action opens a live
progress panel backed by `SkillProvisioningProgressEvent` events and shows:

- the exact dependency pack being audited or downloaded;
- download progress where the source provides a content length;
- file verification and smoke-test stages; and
- whether an existing or newly written receipt is verified.

Verified receipts remain idempotent: a current receipt is shown as verified and
the payload is skipped. Manual PRoot, desktop-only, unsupported, and Native-gap
states do not expose this action. The repair panel must be captured as part of
the live evidence when a pending CLI, Python, audio, vision, or terminal skill
is advanced to a live smoke.

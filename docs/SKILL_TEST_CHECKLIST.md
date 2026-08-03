# Native Android skill test checklist

This is the persistent checklist for the Skills page's top-to-bottom order.
`contract-pass` means the native adapter/readiness contract is covered by
automated tests; it does not claim a live provider call has completed. Live
rows are updated only after an actual device smoke through the app.

Legend: `[ ]` pending, `[x]` passed, `[~]` blocked or partial, `[-]` skipped by
Android GTM policy (configuration, desktop/PC, unsupported, or explicit
PRoot-only mode).

Next live smoke: #46 `songsee`. The Android bridge smokes for `avatar_forge` and
`battery` are complete; continue with the next pending native skill.

| # | Skill | State | Evidence / next action |
|---:|---|---|---|
| 1 | 1password | [-] config | Requires Connect host/token |
| 2 | apple-notes | [-] outside GTM | macOS integration |
| 3 | apple-reminders | [-] outside GTM | macOS integration |
| 4 | avatar_forge | [x] live-pass | Native `avatar-control` set the avatar emotion to `happy` through `/api/tools/execute`. |
| 5 | battery | [x] live-pass | Native `device-node` returned level 66 and `isCharging: true`. |
| 6 | bear-notes | [-] outside GTM | macOS/iOS integration |
| 7 | blogwatcher | [x] live-pass | Native feed checks returned two parsed items from GitHub releases and Hacker News; natural chat wording now stays on the native adapter instead of falling through to the Go CLI. |
| 8 | blucli | [x] live-pass | Verified `android-cli-core-pack` receipt and `blu --help`/`--version` on ARM64; `blu --json devices` returned an empty list, so no BluOS player was available for network control smoke. |
| 9 | camsnap | [x] live-pass | `/api/tools/execute` captured a real back-camera JPEG on-device: 480x720, 159,460 bytes. |
| 10 | canvas | [~] partial | Layout tests pass; live agent tool call blocked upstream |
| 11 | clawhub | [x] contract-pass | Native ClawHub adapter tests |
| 12 | coding-agent | [-] native gap | Released pack quarantined until `/tmp` issue is fixed |
| 13 | diagram-maker | [x] contract-pass | Instruction-only adapter tests |
| 14 | discord | [-] config | Requires bot token |
| 15 | eightctl | [-] config | Requires CLI pack plus credentials |
| 16 | gemini | [-] config | Requires API key |
| 17 | gh-issues | [-] config | Requires GitHub token |
| 18 | gifgrep | [x] live-pass | Verified vision-media receipt and live `gifgrep` status (v0.3.0) through the generic native executor; provider-backed search returned the expected key/config gate without claiming reinstall. |
| 19 | github | [-] config | Requires GitHub token |
| 20 | gog | [-] outside GTM | Desktop/Google Workspace workflow |
| 21 | goplaces | [-] config | Requires Places API key |
| 22 | healthcheck | [x] contract-pass | Android readiness tests |
| 23 | himalaya | [x] live-pass / config gate | Verified CLI-core receipt and ARM64 `himalaya --version`/`--help`; account discovery reached the expected missing-config gate without a TTY or credentials. |
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
| 39 | python-debugpy | [~] not installed | No current user skill/card or `android-python-debug-runtime` receipt exists on this fresh app state; the native bridge correctly returned `ModuleNotFoundError` for a direct import probe. |
| 40 | sag | [-] config | Requires ElevenLabs API key |
| 41 | sensors | [x] live-pass | Native `device-node` listed accelerometer, gyroscope, magnetometer, and barometer; an accelerometer read returned valid x/y/z values and accuracy 3. |
| 42 | session-logs | [x] contract-pass | App-native session adapter tests |
| 43 | sherpa-onnx-tts | [-] native gap | Runtime/model and standalone Node host pending |
| 44 | skill-creator | [x] contract-pass | Instruction-only adapter tests |
| 45 | slack | [-] config | Requires token and channel config |
| 46 | songsee | [~] pack-pass / audio fixture pending | Verified audio-runtime receipt and ARM64 `songsee --version`/`--help`; no app-owned WAV/MP3 fixture was present for the output-image smoke. |
| 47 | sonoscli | [ ] pending | CLI-core pack smoke |
| 48 | spike | [x] contract-pass | Instruction-only adapter tests |
| 49 | spotify-player | [-] config | Requires Spotify token |
| 50 | stocks | [x] live-pass / badge repair | Native `Tools().get_stock_price("AAPL")` returned a live quote; embedded inventory prevents redundant downloads; Stocks is now explicitly classified in the Android readiness manifest |
| 51 | summarize | [x] contract-pass | App-native adapter tests |
| 52 | taskflow | [x] contract-pass | Instruction-only adapter tests |
| 53 | taskflow-inbox-triage | [x] contract-pass | Instruction-only adapter tests |
| 54 | things-mac | [-] outside GTM | macOS Things integration |
| 55 | tmux | [x] live-pass / managed smoke | Verified `android-terminal-pack` receipt; the app-managed pack smoke passed. Raw shell execution without the managed library path is intentionally not the app execution path. |
| 56 | trello | [-] config | Requires Trello credentials |
| 57 | vibrate | [x] live-pass | Native `device-node` vibrated for 100 ms and returned success; battery bridge remained healthy at level 77 while charging. |
| 58 | video-frames | [ ] pending | Vision-media pack smoke |
| 59 | voice-call | [-] config | Requires provider/account/plugin config |
| 60 | wacli | [ ] pending | CLI-core pack smoke |
| 61 | weather | [x] contract-pass | Native HTTP adapter tests |
| 62 | xurl | [x] contract-pass | Native HTTP adapter tests |
| 63 | browser-automation | [~] native unavailable | Explicit `/api/tools/execute` probe returned HTTP 400 because the native AgentSkillServer catalog does not register this tool; requires the separate browser/desktop lane. |

## Evidence baseline

- Ordered native adapter/readiness suite: 152 automated tests passed on
  2026-08-03.
- Stocks was installed from the Skills page and verified in the native
  workspace.
- Live device smokes must record the prompt, output, and relevant dependency
  receipt before a row is marked live-pass.
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
- `blucli` device evidence: receipt `android-cli-core-pack.json` reports
  `smokePassed: true`; the installed `blu` digest is
  `9b8fa1dc19a94113badafeec2ddfa074e100fb0ae78ac5a79543a06b7725e442`, and
  read-only command discovery returned the expected v0.1.4 command catalog.
- `gifgrep` device evidence: receipt `android-vision-media-pack.json` reports
  `smokePassed: true`; the generic native catalog now declares bounded
  `status/search/still/sheet` actions, live status returned v0.3.0, and search
  returned `GIFGREP_PROVIDER_CONFIG_REQUIRED` with `runtimeReady: true` and
  `installationRequired: false` when no provider key was configured.
- `himalaya` device evidence: the shared `android-cli-core-pack.json` receipt
  reports `smokePassed: true`; ARM64 version output was v1.2.0 with IMAP/SMTP
  support, and `account list` reached the expected missing
  `~/.config/himalaya/config.toml` gate because no mail account was configured.
- `openai-whisper` device evidence: `android-whisper-runtime.json` reports
  `smokePassed: true` and includes `libomp.so`; the managed native launcher owns
  the library path, while a raw shell launch is intentionally not a valid app
  smoke. No audio/model fixture was available for a transcription proof, so the
  row remains partial rather than being overstated as fully live.
- `python-debugpy` remains pending because it is not installed as a current
  user skill/card and no `android-python-debug-runtime` or `debugpy` wheel
  receipt exists on this fresh app state; the native Python bridge returned the
  expected `ModuleNotFoundError` when probed.
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

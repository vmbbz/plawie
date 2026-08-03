# Native Android skill test checklist

This is the persistent checklist for the Skills page's top-to-bottom order.
`contract-pass` means the native adapter/readiness contract is covered by
automated tests; it does not claim a live provider call has completed. Live
rows are updated only after an actual device smoke through the app.

Legend: `[ ]` pending, `[x]` passed, `[~]` blocked or partial, `[-]` skipped by
Android GTM policy (configuration, desktop/PC, unsupported, or explicit
PRoot-only mode).

Next live smoke: #4 `avatar_forge`. Prompt: `Use avatar_forge to set a simple
happy expression.` Record the tool result and the relevant gateway log before
advancing to #5 `battery`.

| # | Skill | State | Evidence / next action |
|---:|---|---|---|
| 1 | 1password | [-] config | Requires Connect host/token |
| 2 | apple-notes | [-] outside GTM | macOS integration |
| 3 | apple-reminders | [-] outside GTM | macOS integration |
| 4 | avatar_forge | [ ] pending | Android bridge smoke |
| 5 | battery | [ ] pending | Android bridge smoke |
| 6 | bear-notes | [-] outside GTM | macOS/iOS integration |
| 7 | blogwatcher | [x] contract-pass | App-native HTTP adapter tests |
| 8 | blucli | [ ] pending | CLI-core pack smoke |
| 9 | camsnap | [x] contract-pass | App-native camera adapter tests |
| 10 | canvas | [~] partial | Layout tests pass; live agent tool call blocked upstream |
| 11 | clawhub | [x] contract-pass | Native ClawHub adapter tests |
| 12 | coding-agent | [-] native gap | Released pack quarantined until `/tmp` issue is fixed |
| 13 | diagram-maker | [x] contract-pass | Instruction-only adapter tests |
| 14 | discord | [-] config | Requires bot token |
| 15 | eightctl | [-] config | Requires CLI pack plus credentials |
| 16 | gemini | [-] config | Requires API key |
| 17 | gh-issues | [-] config | Requires GitHub token |
| 18 | gifgrep | [ ] pending | Vision-media pack smoke |
| 19 | github | [-] config | Requires GitHub token |
| 20 | gog | [-] outside GTM | Desktop/Google Workspace workflow |
| 21 | goplaces | [-] config | Requires Places API key |
| 22 | healthcheck | [x] contract-pass | Android readiness tests |
| 23 | himalaya | [ ] pending | CLI-core pack smoke |
| 24 | imsg | [-] outside GTM | macOS Messages integration |
| 25 | mcporter | [-] config | Requires endpoint/token |
| 26 | meme-maker | [x] contract-pass | Native renderer tests |
| 27 | model-usage | [-] outside GTM | Desktop accounting |
| 28 | nano-pdf | [x] contract-pass | Native PDF adapter tests |
| 29 | node-connect | [-] PRoot-only | Manual compatibility mode |
| 30 | node-inspect-debugger | [-] native gap | Node executable pack not production-ready |
| 31 | notion | [-] config | Requires Notion token |
| 32 | obsidian | [-] outside GTM | Desktop vault workflow |
| 33 | openai-whisper | [ ] pending | Whisper pack smoke |
| 34 | openai-whisper-api | [-] config | Requires OpenAI API key |
| 35 | openhue | [ ] pending | CLI-core pack smoke |
| 36 | oracle | [-] PRoot-only | Manual compatibility mode |
| 37 | ordercli | [-] outside GTM | Desktop/browser-heavy login |
| 38 | peekaboo | [-] outside GTM | macOS screen automation |
| 39 | python-debugpy | [ ] pending | Bundled debugpy smoke |
| 40 | sag | [-] config | Requires ElevenLabs API key |
| 41 | sensors | [ ] pending | Android bridge smoke |
| 42 | session-logs | [x] contract-pass | App-native session adapter tests |
| 43 | sherpa-onnx-tts | [-] native gap | Runtime/model and standalone Node host pending |
| 44 | skill-creator | [x] contract-pass | Instruction-only adapter tests |
| 45 | slack | [-] config | Requires token and channel config |
| 46 | songsee | [ ] pending | Audio pack smoke |
| 47 | sonoscli | [ ] pending | CLI-core pack smoke |
| 48 | spike | [x] contract-pass | Instruction-only adapter tests |
| 49 | spotify-player | [-] config | Requires Spotify token |
| 50 | stocks | [x] live-pass / badge repair | Native `Tools().get_stock_price("AAPL")` returned a live quote; embedded inventory prevents redundant downloads; Stocks is now explicitly classified in the Android readiness manifest |
| 51 | summarize | [x] contract-pass | App-native adapter tests |
| 52 | taskflow | [x] contract-pass | Instruction-only adapter tests |
| 53 | taskflow-inbox-triage | [x] contract-pass | Instruction-only adapter tests |
| 54 | things-mac | [-] outside GTM | macOS Things integration |
| 55 | tmux | [ ] pending | Terminal pack smoke |
| 56 | trello | [-] config | Requires Trello credentials |
| 57 | vibrate | [ ] pending | Android bridge smoke |
| 58 | video-frames | [ ] pending | Vision-media pack smoke |
| 59 | voice-call | [-] config | Requires provider/account/plugin config |
| 60 | wacli | [ ] pending | CLI-core pack smoke |
| 61 | weather | [x] contract-pass | Native HTTP adapter tests |
| 62 | xurl | [x] contract-pass | Native HTTP adapter tests |

## Evidence baseline

- Ordered native adapter/readiness suite: 152 automated tests passed on
  2026-08-03.
- Stocks was installed from the Skills page and verified in the native
  workspace.
- Live device smokes must record the prompt, output, and relevant dependency
  receipt before a row is marked live-pass.

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

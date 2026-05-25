# Plawie Gateway Diagnostics And Recovery Plan

Last updated: 2026-05-25

This document is the current working map for the release-readiness issues we
are seeing while OpenRouter is rate-limited. It exists so we do not lose the
thread again.

## What We Know

- OpenClaw Gateway can start, load default skills, pair the Android node, and
  accept chat messages.
- The app should keep the Gateway lane as the default for all cloud models so
  OpenClaw tools, skills, node routing, and Talk remain available.
- Local NDK chat is a manual offline mode. It bypasses Gateway by design and
  therefore should not be expected to use OpenClaw skills, Gateway Talk, or
  cloud model routing.
- Flutter persists visible chat sessions locally. Gateway session binding is
  currently disabled for mobile chat because arbitrary mobile session keys can
  be accepted but later stall as `queued_work_without_active_run`.
- The current stable Gateway session lane is `main` / `agent:main:main`.
- The assistant replying `READY` during the last live test proves Gateway chat
  can complete, but it does not by itself prove the newest lane edits caused
  the success because the response landed while edits/testing were in progress.

## Current Concerns

| Area | Symptom | Likely Meaning | Action |
| --- | --- | --- | --- |
| Chat timing | UI times out while Gateway later replies | Flutter stream timeout/close logic and Gateway run lifecycle can drift when provider or session prep is slow | Keep longer Gateway timeout, live-log first token, track run id, retest after rate-limit cooldown |
| Session health | `stale_session_state`, `file lock stale`, `queued_work_without_active_run` | Gateway session lane or file-lock cleanup can wedge after slow/aborted runs | Keep default session lane, avoid per-chat Gateway lanes until upstream proves fixed |
| Provider rate limits | OpenRouter free returns 429 | External provider quota, not app crash | Surface clearly and avoid retry storms |
| Tool routing | Skills load but tool calls say missing node / node required | Model sees skills but lacks exact paired Android node context or provider/tool policy rejects node tool | Keep mobile node context injection, verify node id at send time, test haptic/camera/flash/sensors separately |
| Tool allowlist | `tools.allow contains unknown entries` | Config has invalid skill/capability names in primitive allowlist | Sanitize config writes; never write npm skill IDs or device capability slugs to `tools.allow` |
| Talk/TTS | `talk.speak unavailable: talk provider not configured` | Gateway Talk provider is not configured even though chat provider is configured | Treat Talk as separate config path; do not assume OpenRouter chat key configures Talk |
| Duplicate text | Same assistant sentence appears many times in one paragraph/log stream | Could be upstream duplicate WebChat body issue, cumulative stream de-dupe issue, or replayed event frames | Keep assistant snapshot de-dupe; retest on latest Gateway because 2026.5.22 notes mention duplicate reply fixes |
| WebSocket churn | Handshake timeouts/1006 around slow runs | Gateway event loop and Flutter/node clients contend while provider/plugin prep is slow | Capture live logs with timestamps and correlate with prompt sends |
| UI stability | Avatar/chat/home regressions from broad restore/revert attempts | Unrelated visual files were touched while debugging gateway | No broad UI restores. Only manual, file-scoped changes with screenshots/tests |

## Official Diagnostics Direction

OpenClaw has an official `openclaw logs` command for Gateway log tailing. It
supports following logs, JSON output, URL/token targeting, and reconnect/fallback
behavior. Plawie should eventually use the same Gateway log RPC path instead of
scraping local files.

References:

- OpenClaw CLI logs documentation: https://docs.openclaw.ai/cli/logs
- OpenClaw Talk contract: https://docs.openclaw.ai/nodes/talk
- OpenClaw release notes for 2026.5.22: https://github.com/openclaw/openclaw/releases/tag/v2026.5.22
- Android assistant reference pattern: https://github.com/yuga-hashimoto/openclaw-assistant

## Implemented Now

- `GatewayService` already publishes a human-readable `chatActivityStream`.
- `ChatScreen` now subscribes to that stream and mirrors filtered Gateway
  activity into the existing diagnostics panel.
- The diagnostics feed filters for chat, node, session, skills, TTS, model,
  health, rate-limit, stale-lock, tools, WebSocket, and liveness events.
- Obvious token/API-key strings are redacted before display.
- `scripts/watch_plawie_gateway.ps1` captures:
  - ADB device snapshot.
  - App/process snapshot.
  - Screenshot and UI dump.
  - Raw logcat.
  - Filtered logcat focused on Gateway/chat/tool/TTS/session events.
  - Best-effort Gateway log tail through `run-as` for debug builds.

## Testing Protocol After OpenRouter Cooldown

1. Start with Gateway already healthy and Android node paired.
2. Open Chat and enable diagnostics from the menu.
3. Send `reply exactly READY`.
4. Expected:
   - `GW [CHAT] -> Sending to ...`
   - `GW [CHAT] <- Gateway accepted`
   - `GW [CHAT] First token received`
   - UI receives `READY` before timeout.
5. Send `List the phone tools you can use right now. Do not invent tools.`
6. Expected:
   - Mobile node context is attached.
   - The answer mentions available Android node tools without claiming the node
     is missing.
7. Send `Vibrate the phone once briefly.`
8. Expected:
   - A `tool_use` event appears.
   - Haptic tool succeeds or returns a precise node/provider error.
9. Send `Take one photo with the camera and attach it to this chat.`
10. Expected:
    - `camera_snap` tool call includes the paired node id.
    - Image appears in chat.
11. Open Gateway Voice and press test.
12. Expected:
    - If Talk is configured, audio streams.
    - If Talk is not configured, the app surfaces a single clear Talk config
      error and does not spam `talk.speak` retries.

## Do Not Do

- Do not re-enable arbitrary per-chat Gateway session keys until a clean test on
  the latest Gateway proves the lane no longer stalls.
- Do not route cloud models through direct HTTP fast lane by default; it bypasses
  OpenClaw tools and node context.
- Do not write device capability slugs or npm skill IDs into `tools.allow`.
- Do not use app-wide UI reverts to fix gateway behavior.
- Do not assume chat provider configuration also configures Gateway Talk.

## Next Fix Order

1. Verify chat completion and first-token timing with the in-app diagnostics
   overlay and ADB watcher.
2. Fix any remaining duplicate-stream issue with run-id and snapshot de-dupe
   evidence.
3. Fix node/tool routing only after a prompt shows the exact tool schema/error.
4. Fix Talk provider configuration as its own module.
5. Only then polish avatar/chat visuals in small manual patches.

# Native Release Heavy Fix Round - 2026-06-03

## Purpose

This round closes the practical release blockers that appeared after the native
`libnode.so` Gateway became the intended default with PRoot retained as rollback.
The focus is not another tiny canary series; it is making the normal user
experience coherent under either owner.

## Findings Addressed

- Gateway startup reports active skills, including `stocks`, but chat turns only
  received tool/device context. The agent could therefore confuse device
  capabilities with installed skills and claim an installed skill was missing.
- Partner skill pages still assumed the optional `skills.execute` RPC existed.
  Current native Gateway builds expose installed skills to chat, but do not
  advertise that direct page execution method.
- Discover/detail install UI could still try to install an already-active skill,
  creating the misleading "already installed, use update" failure path.
- Chat TTS failures from `talk.speak` were only written to diagnostics. Billing,
  quota, or provider errors were not visible enough to the user.
- Native logs exposed the Android wrapper lifecycle more than OpenClaw Gateway
  stdout/stderr, so they did not read like the richer PRoot logs.

## Changes In This Round

- Chat messages now include private runtime inventory context that separates:
  active OpenClaw skills, primitive tools, and Android device capabilities.
- Skill page execution now checks whether `skills.execute` is advertised before
  calling it. If unavailable, the UI receives a clear adapter-unavailable
  message instead of an unknown-method exception.
- Skills install flows now check live Gateway active skills and installed skill
  records before opening an install sheet. Already-active skills are treated as
  successful no-ops.
- Dedicated skill cards use `Install` for installation. `Connect` remains a
  separate concept for account/device linking inside the skill page.
- TTS playback now tracks Gateway voice health and surfaces Talk/TTS provider
  errors in chat with visual state on the voice orb.
- The native log reader now combines wrapper lifecycle logs with the native
  OpenClaw bootstrap stdio log and formats both into a readable feed.
- Repeated native startup ignore messages are coalesced into a single log plus
  summary instead of flooding diagnostics.
- `NodeService` native-owner state reads now use only the native `.openclaw`
  store. PRoot state is no longer consulted while native owns the runtime.
- Local NDK/fllama chat now returns explicit readiness messages for idle,
  downloading, starting, and failed states instead of a generic not-ready error.

## Device-Control Boundary

The Android node can expose real mobile actions only when the matching bridge,
permission, and tool schema exist. Current production-safe actions are camera,
location, sensor reads, haptics, flashlight, canvas, device status, and avatar
gestures.

Examples like "send a WhatsApp message" or "send an email with Gmail" should be
treated as user-confirmed Android intent flows unless a future privileged or
accessibility-based bridge is explicitly implemented and permissioned. The agent
must not claim silent background control of third-party apps unless that bridge
is actually available.

## Validation Completed

- `flutter analyze` passed after the full heavy-fix patch set.
- Public rollback release APK built successfully with:
  `PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=public-rollback` and
  `PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS=true`.
- Final APK installed over USB on `RZCX30KA9AW`.
- Native owner reached `/health` on `18789` with
  `{"ok":true,"status":"live"}`.
- Process ownership while native owns showed only the app process and
  `:native_node_smoke`; no `proot` PID was present.
- Fresh chat probe: "what skills do you have and is stocks installed" returned
  a visible answer that `stocks` is active and part of the installed skill set.
- Gateway Logs UI now shows native OpenClaw stdio entries such as message
  dispatch, processed message, session state, websocket health/tick, and
  heartbeat events instead of only wrapper lifecycle JSON.
- Rollback UX test passed on the same final APK:
  `/native-default-owner-rollback` restored PRoot, stopped native, released the
  production port, and returned PRoot `/health` as live.
- PRoot fallback chat passed after waiting for readiness: a normal chat turn
  produced a visible assistant response.
- Re-enable UX test passed: `/native-default-owner-enable` restored native as
  the persisted production owner, reported native health live, and reconnected
  WebSocket.
- Process ownership after re-enable showed only the app process and
  `:native_node_smoke`; no `proot`/`libproot.so` process was present while
  native owned `18789`.
- Post-reenable native chat passed: a normal chat turn produced visible
  assistant text on native after the full rollback/re-enable cycle.

## Remaining Gates

- Run final RC soak and release notes pass.
- TTS provider-error UI now has both snackbar feedback and voice-orb alert
  pulsing, but still needs one forced failing `talk.speak` turn after a
  depleted/invalid TTS provider is selected to verify the exact visual state on
  device.
- Avatar limb gestures are present in the APK asset tree. The follow-up polish
  found a code alias bug: `wave` and `wave right` were mapped to
  `animations/limbs/*.vrma`, then overwritten back to
  `animations/gesture_greeting.vrma`. The alias now preserves the converted
  limb VRMA files, while explicit `greeting wave`/`hello wave` aliases keep the
  legacy greeting clip available.
- Chat voice selection now merges voice lists from both `tts.providers` and
  `talk.catalog`, matching the richer Web Dashboard-style catalog instead of
  collapsing to only the currently active provider's voice list.
- Native log reading now filters noisy websocket tick/health heartbeats and
  tags stdio entries by category: startup, plugins, skills, chat, provider,
  tools, TTS, health, websocket, warning, and error.
- Gateway Logs UI now uses tighter top spacing, smaller monospaced rows,
  category colors, and row dividers so native logs are readable on phone.

## Release Boundary Notes Added During Polish

- Dreaming mode is an OpenClaw dashboard/autonomy surface (`/dreaming`) with
  light/deep/REM-style controls. It is not yet a chat-page feature. To promote
  it into chat, the app should first discover the advertised dreaming RPCs, add
  a visible chat control/toggle, and show state/permission failures instead of
  silently sending dashboard-only commands.
- The failed `hello_and_location` cron job is a release-hardening item, not a
  native runtime proof failure by itself. Scheduled jobs must run only after the
  selected owner is ready and must have a live Android node/tool bridge for
  device actions such as `location.get`. Until that is hardened, cron jobs that
  need phone state should show a clear "device bridge unavailable at run time"
  failure.
- The Web Dashboard `Instances` permission-denied page is a dashboard capability
  mismatch/permission issue. Chat does not require it for normal turns. For
  public release, the dashboard should either hide/disable that entry when the
  Gateway does not advertise or permit it, or show a plain unavailable message.
- The `phone-control` plugin being loaded does not equal silent third-party app
  automation. WhatsApp/Gmail/contact/file actions must be exposed as explicit
  tool schemas with permissions and user confirmation. Current release-safe
  posture is Android intents/confirmation for third-party apps, not background
  sending.
- Public builds should continue redacting or truncating raw prompt/output logs.
  Internal diagnostics can show richer message exchange when explicitly enabled.

## Validation To Run

- `flutter analyze`
- Native default startup with readable plugin/skill/log feed.
- Chat: "what skills do you have?" must list skills separately from tools and
  device capabilities.
- Chat: a stock/ticker prompt must not claim the active `stocks` skill is absent.
- Discover/detail: active skills must not show an install action or already
  installed error.
- MoltLaunch/Agent Work must no longer show `unknown method: skills.execute`.
- TTS account/billing failure must be visible in chat and reflected by the voice
  orb state.
- Rollback to PRoot must still wait for readiness before chat is accepted.

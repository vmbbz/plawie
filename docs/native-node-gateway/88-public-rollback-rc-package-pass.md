# Public Rollback RC Package Pass

Date: 2026-06-02

## Purpose

Prove the intended public release-candidate package shape after the native
Gateway promotion work:

- native Node owns the production Gateway port by default;
- PRoot is still packaged, but only as emergency rollback;
- broad diagnostics/canary sidecar does not autostart;
- normal chat still reaches a provider and renders in the chat UI;
- rollback and re-enable both work from the public owner-switch commands.

## Build Shape

```powershell
flutter build apk --release `
  --dart-define=PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=public-rollback `
  --dart-define=PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS=true
```

APK inspected:

- `lib/arm64-v8a/libnode.so` present;
- `lib/arm64-v8a/libplawie_node_bridge.so` present;
- `assets/flutter_assets/assets/openclaw-node-modules.tar.gz` present;
- PRoot rollback libraries still present:
  `libproot.so`, `libprootloader.so`, `libprootloader32.so`, and
  `libtalloc.so` for packaged rollback ABIs.

## Installed-Device Result

Device: `SM-A556E` over USB via `RZCX30KA9AW`.

Install:

```powershell
adb -s RZCX30KA9AW install -r build\app\outputs\flutter-apk\app-release.apk
```

Cold launch:

- production health reached `{"ok":true,"status":"live"}` on `18789`;
- process state while native owned production was:
  - `com.nxg.openclawproot`;
  - `com.nxg.openclawproot:native_node_smoke`;
- no live PRoot `libproot.so` process while native owned production;
- no live PRoot `openclaw` process while native owned production;
- `18790` diagnostics sidecar returned no health response.

Chat smoke:

- UI provider: `OpenRouter Free Router`;
- prompt: `rc patched native provider reply OK`;
- assistant response rendered visible text: `OK`;
- production health remained live after the provider-backed chat.

Rollback:

- command: `/native-default-owner-rollback`;
- owner changed from `native-node-full-gateway-production` to `proot`;
- native stopped;
- native production port was released;
- PRoot started and returned health-live.

Re-enable:

- command: `/native-default-owner-enable`;
- owner changed back to `native-node-full-gateway-production`;
- PRoot stopped;
- native production port returned health-live;
- fresh report showed `nativeRunning: true` and `nativeHealthOk: true`;
- `18790` diagnostics sidecar remained closed.

## Patch Included In This Gate

This pass includes the release-polish fixes needed to make the public rollback
shape testable from logs instead of from optimistic UI state:

- The owner-enable report previously allowed an internally inconsistent
  display: `nativeHealthOk: true` with `nativeRunning: false`. A live production
  health response now also marks `nativeRunning: true`.
- Native runtime log polling now feeds the same Gateway activity path as PRoot
  log streaming, so native startup/plugin/health evidence is visible in-app.
- Rollback now logs each owner handoff step: selector restore, native stop,
  native port release, PRoot start, and PRoot health recovery.
- Rollback fails fast if native does not release production port `18789` before
  PRoot is started.
- Native isolated process stop now has a bounded force-stop fallback.
- Chat sending waits for both WebSocket connection and Gateway RPC/chat
  readiness after owner transitions. Health-live alone is not treated as enough
  for normal chat.
- A missed runtime process probe no longer marks native stopped when production
  health is live.

## Final Rebuilt RC Evidence

The rebuilt public rollback APK was installed again on the USB-connected device
and the owner-switch path was rechecked from real chat/logs.

Baseline after relaunch:

- persisted owner was `proot`, which is correct after a sticky rollback state;
- processes were the app process, `libproot.so`, and PRoot `openclaw`;
- native `:native_node_smoke` was absent;
- production `/health` returned `{"ok":true,"status":"live"}`;
- PRoot logs reached `Gateway RPC discovery complete` and
  `Gateway ready; auto-connect check running`.

PRoot chat after readiness:

- prompt: `Say only proot_rc_chat_ok_4`;
- logs showed `Mobile node tool context attached (OpenClaw Mobile)`;
- logs showed `Gateway accepted`, `First token received`, and `Complete`;
- this proves sticky rollback can still serve normal chat once the Gateway
  chat/RPC lane is ready.

Native re-enable:

- command: `/native-default-owner-enable`;
- report showed `selectorSetOk: true`, `prootStopped: true`,
  `portReleased: true`, `nativeStarted: true`, `nativeRunning: true`,
  `nativeHealthOk: true`, and `wsConnected: true`;
- process table showed the app process plus `:native_node_smoke`;
- PRoot `libproot.so` and PRoot `openclaw` were absent.

Rollback from native:

- command: `/native-default-owner-rollback`;
- logs showed selector restored to `proot`;
- logs showed native stop returned, native stopped, native port released,
  PRoot start returned, and PRoot health returned live;
- PRoot then reached `Gateway RPC discovery complete`.

Post-rollback timing note:

- one test message was sent too early, after HTTP health was live but before
  PRoot RPC/chat readiness was complete;
- logs showed the early turn was accepted at `10:46:30`, while
  `Gateway RPC discovery complete` arrived only at `10:48:21`;
- the 90 second no-first-token guard correctly paused the chat lane instead of
  allowing retries into a stale queue;
- the next retry waited for Gateway settle, then sent at `10:51:01`, received
  first token at `10:51:18`, and completed at `10:51:18`.

Classification: rollback is healthy. The remaining polish is to make the
post-recovery wait feel less opaque to the user, not to reclassify PRoot
rollback as broken.

## Release Classification

Passed.

This is the intended public rollback release shape:

```text
Native Node Gateway is the default production owner.
PRoot remains packaged as emergency rollback.
Owner-switch commands remain available.
Broad diagnostics stay internal-only.
The 18790 diagnostics sidecar does not autostart.
Local NDK LLM support remains available, with Gateway bridge-chat hardening
tracked separately.
```

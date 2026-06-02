# Plawie Native Node Gateway Release Boundary

Date: 2026-06-02

## Summary

This release boundary moves Plawie's OpenClaw Gateway from PRoot to embedded
Android native Node `libnode.so` as the intended production runtime.

PRoot remains packaged only as emergency rollback for the first native-default
release.

## Runtime Changes

- Native Android arm64 Node `libnode.so` owns production Gateway port
  `127.0.0.1:18789` by default.
- PRoot is demoted to rollback owner.
- `/native-default-owner-enable` restores native ownership after sticky
  rollback.
- `/native-default-owner-rollback` restores PRoot.
- Public release builds should not autostart the diagnostics sidecar on
  `127.0.0.1:18790`.

## Verified In The Latest Installed-Device Run

- Debug APK built and installed over USB.
- Native production `/health` returned `{"ok":true,"status":"live"}`.
- Native ownership showed app process plus `:native_node_smoke`, with no PRoot
  `openclaw` or `libproot.so` process.
- Normal provider-backed native chat had already returned visible assistant
  text in the release gate.
- Native config mirror rewrote PRoot-only `/root/...` paths into app-private
  native paths.
- Rollback restored PRoot, released native, and returned health-live.
- Native was re-enabled after rollback.
- Force-stop/relaunch cold-started into native default and returned
  health-live after warmup.
- Qwen 2.5 1.5B local NDK model started from the Local LLM page.
- Direct OpenAI-compatible NDK bridge request returned `OK`.

## Known Boundary

`plawie_ndk/local-llm` Gateway chat reached the local NDK bridge, but the Chat UI
timed out after 90 seconds without assistant text in the latest installed run.
Direct bridge HTTP inference works, so this is a Gateway-to-bridge
stream/session hardening item.

Release claim:

- Direct `local-llm/...` local inference remains supported.
- `plawie_ndk/local-llm` bridge-chat remains experimental until hardened.

## Packaging Rule

Ship:

- `libnode.so`
- `libplawie_node_bridge.so`
- `assets/openclaw-node-modules.tar.gz`
- PRoot rollback payload for the first public native-default release
- Local LLM/fllama runtime
- native/rollback docs

Do not ship public claims that:

- PRoot has been removed from the APK;
- every Android app can be controlled;
- WhatsApp messages can be silently sent;
- `plawie_ndk/local-llm` Gateway chat is production-ready;
- native Gateway has no memory cost.

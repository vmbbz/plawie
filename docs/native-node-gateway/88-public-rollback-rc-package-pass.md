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

The owner-enable report previously allowed an internally inconsistent display:
`nativeHealthOk: true` with `nativeRunning: false`. The runtime itself was
healthy, but the report sampled process state before the health probe proved
the native Gateway was live.

This pass normalizes the report so a live production health response also marks
`nativeRunning: true`. That keeps the public rollback command output aligned
with actual process and health evidence.

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

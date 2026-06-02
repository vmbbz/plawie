# Release Diagnostics And Package Boundary

Date: 2026-06-02

Status: current build-variant decision for native-default release packaging.

## Goal

Ship native `libnode.so` as the intended OpenClaw Gateway runtime while keeping
PRoot only as documented emergency rollback.

The release boundary separates three things that were easy to mix together:

```text
production owner selection
diagnostics/canary commands
diagnostics sidecar autostart on 18790
```

## Variant Matrix

| Variant | Intended audience | Native default | PRoot packaged | `/native-default-owner-enable` | `/native-default-owner-rollback` | Broad canaries | `18790` autostart |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Debug/internal diagnostics | Engineering | Yes unless sticky rollback | Yes | Yes | Yes | Yes | Optional |
| Public native-default rollback | Users | Yes unless sticky rollback | Yes | Yes | Yes | No | No |
| Internal no-PRoot | Engineering | Yes | No | Yes | Native repair only | Selected native diagnostics | No |
| Public no-PRoot | Users | Yes | No | Not needed | Native repair/reset only | No | No |

## Dart Defines

Owner switch command:

```text
PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS
```

Default: `true`

This controls `/native-default-owner-enable`. It is separate from the broad
diagnostics gates so a public rollback build can recover from sticky PRoot
rollback without exposing all native canaries.

Rollback command:

```text
/native-default-owner-rollback
```

This remains available without a diagnostics define while PRoot is packaged.

Broad smoke/canary diagnostics:

```text
PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
PLAWIE_NATIVE_GATEWAY_PRIMARY_CANARY_DIAGNOSTICS=true
PLAWIE_NATIVE_GATEWAY_SHADOW_PARITY_DIAGNOSTICS=true
PLAWIE_NATIVE_GATEWAY_DIRECT_CANARY_DIAGNOSTICS=true
```

These are for debug/internal builds only.

Sidecar autostart diagnostics:

```text
PLAWIE_NATIVE_GATEWAY_SMOKE_AUTOSTART_DIAGNOSTICS=true
```

This must not be set in public release builds. It can start diagnostics on
`127.0.0.1:18790`.

Optional label for build scripts and release notes:

```text
PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=debug-internal
PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=public-rollback
PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=internal-no-proot
PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=public-no-proot
```

The label is documentation/build-script metadata. Runtime safety is controlled
by the explicit booleans above.

## Recommended Build Shapes

Debug/internal diagnostics:

```powershell
flutter build apk --debug `
  --dart-define=PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=debug-internal `
  --dart-define=PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS=true `
  --dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true `
  --dart-define=PLAWIE_NATIVE_GATEWAY_PRIMARY_CANARY_DIAGNOSTICS=true
```

Public native-default rollback:

```powershell
flutter build apk --release `
  --dart-define=PLAWIE_NATIVE_GATEWAY_RELEASE_VARIANT=public-rollback `
  --dart-define=PLAWIE_NATIVE_GATEWAY_OWNER_SWITCH_COMMANDS=true
```

Do not set broad diagnostics or sidecar autostart for the public rollback
build.

## Package Boundary For First Native-Default Release

Include:

- `libnode.so`;
- `libplawie_node_bridge.so`;
- `assets/openclaw-node-modules.tar.gz`;
- PRoot runtime/rootfs only as emergency rollback;
- Local LLM/fllama NDK runtime;
- NDK Gateway bridge on `11435`;
- Android node host on `8765`;
- docs and release notes explaining native default + PRoot rollback.

Exclude from public release behavior:

- broad native canary commands;
- automatic `18790` sidecar startup;
- claims that PRoot has been removed;
- claims that every phone app can be controlled;
- silent third-party app messaging.

## Verification Checklist

Before packaging:

- build without broad native diagnostics;
- confirm fresh or eligible install defaults to native owner;
- confirm sticky rollback can return to native with `/native-default-owner-enable`;
- confirm rollback can restore PRoot with `/native-default-owner-rollback`;
- confirm native cold-start reaches `{"ok":true,"status":"live"}` on `18789`;
- confirm PRoot `openclaw` and `libproot.so` are absent while native owns
  production;
- confirm `18790` is absent unless sidecar autostart diagnostics are enabled;
- confirm native config mirror contains no `/root` paths;
- confirm direct `local-llm/...` still bypasses Gateway;
- confirm the NDK bridge server on `11435` can answer a direct
  OpenAI-compatible request;
- do not claim `plawie_ndk/local-llm` Gateway chat is production-ready until the
  Gateway-to-bridge stream/session timeout is fixed;
- confirm no generated build reports are committed.

Latest installed-device evidence:

- debug APK rebuild and install passed;
- native default owner served production health on `18789`;
- rollback restored PRoot and health-live;
- native was re-enabled and survived force-stop/relaunch as selected default;
- direct NDK bridge request returned `OK`;
- Gateway chat to the NDK bridge reached the bridge but timed out in Chat, so
  bridge-chat remains experimental.

## Current Decision

Proceed with the public native-default rollback package boundary:

```text
Native Gateway is default.
PRoot is packaged only as emergency rollback.
Owner switch commands are available.
Broad canaries are internal-only.
18790 sidecar does not autostart publicly.
Local NDK LLM remains available.
Gateway-to-NDK bridge chat remains experimental until its timeout is hardened.
```

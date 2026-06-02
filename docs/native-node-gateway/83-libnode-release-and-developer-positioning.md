# Native Node libnode.so Release And Developer Positioning

Date: 2026-06-02

Status: release positioning draft for the embedded Android Node `libnode.so`
runtime.

## What We Built

Plawie now carries a custom Android arm64 embedded Node runtime:

```text
Node: v22.22.3
Runtime: embedded libnode.so
Android ABI: arm64-v8a
Gateway payload: OpenClaw 2026.5.28 package
Production port: 127.0.0.1:18789
Rollback runtime: PRoot
```

The value is not just "a Node shared library exists." The value is the full
Android production integration:

- Android-native `libnode.so` loads in an isolated app process.
- OpenClaw runs from the embedded package instead of a PRoot Ubuntu userland.
- The production Gateway still speaks the same HTTP/WebSocket contract.
- Normal provider-backed chat returns visible assistant text.
- Gateway plugin loading, method exposure, node-host pairing, and tool/skill
  boundaries are preserved.
- PRoot rollback remains one operator action away.

## Why This Is Valuable

The public off-the-shelf path is thin.

Verified public references:

- `nodejs-mobile` describes itself as the Node.js-for-mobile integration
  toolkit and points Android/iOS binaries to its releases page:
  <https://github.com/nodejs-mobile/nodejs-mobile/tree/update22-9-0>
- The current public `nodejs-mobile` releases page lists latest release
  `v18.20.4`, with Android builds for `armeabi-v7a`, `arm64-v8a`, and `x86_64`:
  <https://github.com/nodejs-mobile/nodejs-mobile/releases>
- The `update22-9-0` branch exists publicly, but it is a source branch, not a
  ready-made production distribution of Node `22.22.3` `libnode.so`:
  <https://github.com/nodejs-mobile/nodejs-mobile/tree/update22-9-0>
- Upstream Node carries an Android `trap-handler.h.patch`, showing that Android
  support still has platform-specific build concerns:
  <https://github.com/nodejs/node/blob/main/android-patches/trap-handler.h.patch>

The market-safe claim:

```text
We did not find an official, ready-made, production-integrated Android
arm64 Node >=22.19 libnode.so artifact suitable for embedding a full OpenClaw
Gateway in a Flutter app. Plawie's native runtime fills that gap for this
mobile Gateway use case.
```

Avoid claiming "world first" unless a separate market/legal review verifies it.
The credible claim is already strong: this is a hard-to-build runtime and we
now have a working, tested, app-integrated one.

## What Can Be Offered To Developers

Possible developer-facing packages:

| Offering | Contents | Audience |
| --- | --- | --- |
| Runtime binary kit | `libnode.so`, JNI bridge, license bundle, sample loader | Android/Flutter developers needing embedded Node 22 |
| OpenClaw mobile Gateway kit | Runtime binary kit plus OpenClaw extraction/bootstrap patterns | Agent app developers |
| Migration service | PRoot/Termux/Linux sidecar to native Node migration consulting | Teams with mobile agent runtimes |
| Diagnostics kit | Health endpoint, process owner selector, rollback harness, smoke tests | Teams shipping risky native runtimes |

## What Must Ship With The Binary

Minimum responsible distribution bundle:

- `libnode.so` for each supported ABI.
- JNI/FFI bridge source or binary.
- exact Node version and build flags.
- NDK version and build environment notes.
- OpenSSL/ICU/Intl configuration notes.
- license texts for Node.js and third-party dependencies.
- crash/health/rollback guidance.
- unsupported-feature list.
- clear statement that Android app/package messaging automation is not included
  unless explicitly implemented by the host app.

Node.js licensing is permissive for redistribution, but the license text and
third-party dependency notices must be included:
<https://github.com/nodejs/node/blob/main/LICENSE>

## Stability Story

The release story should emphasize the production gates, not only the binary:

- native can own `18789`;
- PRoot is absent during native ownership;
- PRoot rollback restores service;
- native and PRoot load the same 12 startup Gateway plugins;
- native exposes 177 Gateway methods and 27 events;
- native provider/catalog expansion loaded 45 provider/catalog plugins;
- native provider-backed chat returned visible assistant text;
- node-host bridge still exposes the Android tool catalog;
- diagnostics sidecar remains disabled unless explicitly enabled.

## Efficiency Story

Native `libnode.so` still runs a full Gateway. It is not a miniature model
runtime and it is not free memory-wise.

The efficiency win is cutting the active PRoot layer:

- no PRoot process while native owns production;
- no Ubuntu shell wrapper for the active Gateway;
- fewer bind mounts and path translations;
- fewer PRoot-specific filesystem/process quirks;
- simpler app-private state layout;
- lower startup indirection.

PRoot files can remain on disk for rollback. Disk is not RAM. The release rule
is process ownership: if native owns `18789`, PRoot must not keep running in the
background.

## Developer Positioning Copy

Short:

```text
Embedded Node 22 for Android agents, without PRoot.
```

Medium:

```text
Plawie replaces its PRoot-hosted OpenClaw Gateway with a custom Android arm64
Node 22 libnode.so runtime, preserving provider chat, Gateway plugins, skills,
device bridges, and one-action rollback.
```

Technical:

```text
We built and integrated a Node v22.22.3 Android arm64 libnode.so runtime that
boots the full OpenClaw 2026.5.28 Gateway on 127.0.0.1:18789 inside the app,
loads the same startup Gateway plugins as PRoot, preserves WebSocket chat/tool
contracts, and keeps PRoot available only as an emergency rollback owner.
```

Hard boundary:

```text
This is a Gateway runtime replacement. It does not automatically grant silent
control over third-party Android apps. App launch, WhatsApp compose/send, and
similar phone-control actions require explicit Android bridge commands,
permissions, and user-confirmation policy.
```

## Release Readiness Claims

Allowed:

- "Native Node is the intended default Gateway runtime."
- "PRoot is retained as emergency rollback."
- "Native production Gateway has passed provider-backed chat and rollback
  gates."
- "The current device may still show PRoot if sticky rollback was invoked."
- "Gateway plugin parity is verified for the 12 startup plugins observed in
  logs."
- "Broader provider/catalog plugin expansion is verified from native logs."

Not allowed yet:

- "PRoot has been removed from the APK."
- "Every Android app can be controlled."
- "WhatsApp messages can be silently sent."
- "No memory cost."
- "World first" without external market review.

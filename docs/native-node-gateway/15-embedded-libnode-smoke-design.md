# Embedded Libnode Smoke Design

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Purpose

This document defines the safe implementation shape for a future embedded
`libnode.so` smoke runtime.

It exists because the `nodejs-mobile` Android path produces a shared library,
while Plawie's current native smoke slot expects a standalone executable.
Those are different runtime shapes and must stay visibly separate.

## Current Android Build Reality

The app currently has:

- Kotlin Android application code;
- `jniLibs` packaging for prebuilt native assets;
- no app-owned `externalNativeBuild` / CMake bridge;
- no app-owned JNI wrapper for `node::Start`;
- an executable-style smoke slot:
  `NativeNodeSmokeProcess -> ProcessBuilder(libplawie_node.so, server.mjs)`.

The current `jniLibs` setup is enough to package an already-built executable or
shared library, but not enough to call C++ Node APIs from Kotlin.

## Artifact Names

Keep artifact names strict:

| Runtime lane | Artifact | Meaning |
| --- | --- | --- |
| executable process | `libplawie_node.so` | Android arm64 Node executable launched with `ProcessBuilder` |
| embedded libnode | `libnode.so` | Android arm64 shared library loaded through JNI |
| embedded bridge | `libplawie_node_bridge.so` | Small app-owned JNI wrapper linked against `libnode.so` |

Do not feed `libnode.so` into `package_native_node_candidate.ps1`.

## Recommended Runner Shape

The embedded lane should be a new diagnostic-only runtime:

```text
NativeEmbeddedNodeSmokeRuntime
  -> isolated Android service/process
  -> System.loadLibrary("node")
  -> System.loadLibrary("plawie_node_bridge")
  -> plawieStartNode(argc, argv)
  -> files/embedded-node-smoke/server.mjs
  -> http://127.0.0.1:18790/health
```

The bridge should follow the proven mobile pattern:

```cpp
namespace node {
  extern int Start(int argc, char* argv[]);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_nxg_openclawproot_EmbeddedNodeBridge_startNode(
    JNIEnv* env,
    jobject,
    jobjectArray args);
```

The bridge must copy Java strings into contiguous native memory before calling
`node::Start`, because libuv/Node expects stable argv memory.

## Isolation Rule

For first smoke only, embedded Node may run in the app process if that is the
smallest possible proof.

Before any OpenClaw boot attempt, embedded Node must move to an isolated Android
process, for example:

```xml
<service
    android:name=".EmbeddedNodeSmokeService"
    android:exported="false"
    android:process=":native_node_smoke" />
```

Reason: an embedded runtime crash can otherwise take down Flutter, chat, TTS,
and the visible app. A native runtime that can crash the UI is not acceptable
for canary Gateway traffic.

## Diagnostics Contract

The embedded `/health` response should differ from the executable lane:

```json
{
  "ok": true,
  "runtime": "native-node-embedded",
  "node": "v22.x",
  "platform": "android",
  "arch": "arm64",
  "host": "127.0.0.1",
  "port": 18790,
  "productionGatewayPort": 18789,
  "openclawStarted": false
}
```

This avoids confusing:

- placeholder native HTTP smoke: `native-gateway-smoke`;
- executable Node smoke: `native-node`;
- embedded libnode smoke: `native-node-embedded`.

## CMake Introduction Gate

Do not add `externalNativeBuild` until all are true:

- a candidate `libnode.so` is available locally;
- the bridge source is tiny and app-owned;
- Gradle debug build still passes without `libnode.so` present;
- release builds do not accidentally require native Node artifacts;
- all native Node artifacts remain ignored unless provenance is approved.

This keeps normal APK builds stable while the native runtime is still research.

## Build Order

1. Produce or rebase Android `libnode.so` at Node `>=22.19.0`.
2. Package `libnode.so` locally under `jniLibs/arm64-v8a/`.
3. Add `libplawie_node_bridge.so` source via CMake.
4. Add an isolated Android service that calls the bridge.
5. Add Dart diagnostics methods distinct from the executable process slot.
6. Run `/health` smoke with
   `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`.
7. Prove repeated start/stop/restart and app-process crash containment.

## Non-Goals

- Do not boot OpenClaw in this lane yet.
- Do not bind `18789`.
- Do not share the PRoot `node_modules` tree.
- Do not move chat, tools, TTS, dashboard, or node pairing to this lane.
- Do not compile or download native Node artifacts during normal Flutter build.

## Exit Gate

This design is ready for code only when:

- the chosen embedded Node source is Node `>=22.19.0`;
- the bridge can be built without disturbing existing native libraries;
- a missing `libnode.so` produces a clean diagnostic skip;
- `flutter analyze` and debug APK build stay green without the artifact.

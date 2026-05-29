# Embedded Libnode Smoke Design

Last updated: 2026-05-30

Branch: `native-node-gateway-research`

## Purpose

This document defines the safe implementation shape for the embedded
`libnode.so` smoke runtime.

It exists because the `nodejs-mobile` Android path produces a shared library,
while Plawie's current native smoke slot expects a standalone executable.
Those are different runtime shapes and must stay visibly separate.

## Current Android Build Reality

The app currently has:

- Kotlin Android application code;
- `jniLibs` packaging for prebuilt native assets;
- app-owned `externalNativeBuild` / CMake for the bridge;
- app-owned JNI wrapper for `node::Start`;
- an embedded smoke slot:
  `NativeNodeSmokeProcess -> NativeNodeEmbeddedService -> NativeNodeBridge`.

The current `jniLibs` setup packages the already-built `libnode.so`, while
CMake builds `libplawie_node_bridge.so` against that local artifact. The bridge
also depends on `libplawie_cpufeatures.so`, built from the Android NDK
cpufeatures source, because the Node 22.22.3 shared library references
`android_getCpuFeatures`.

## Artifact Names

Keep artifact names strict:

| Runtime lane | Artifact | Meaning |
| --- | --- | --- |
| executable process | `libplawie_node.so` | Android arm64 Node executable launched with `ProcessBuilder` |
| embedded libnode | `libnode.so` | Android arm64 shared library loaded through JNI |
| embedded bridge | `libplawie_node_bridge.so` | Small app-owned JNI wrapper linked against `libnode.so` |
| embedded cpufeatures | `libplawie_cpufeatures.so` | NDK cpufeatures provider needed by the Android Node build |

Do not feed `libnode.so` into `package_native_node_candidate.ps1`.

## Recommended Runner Shape

The embedded lane is a diagnostic-only runtime:

```text
NativeNodeSmokeProcess
  -> isolated Android service/process
  -> System.loadLibrary("plawie_node_bridge")
  -> Android loads libnode.so and libplawie_cpufeatures.so as bridge dependencies
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

Embedded Node is isolated before any OpenClaw boot attempt:

```xml
<service
    android:name=".NativeNodeEmbeddedService"
    android:exported="false"
    android:process=":native_node_smoke" />
```

Reason: an embedded runtime crash can otherwise take down Flutter, chat, TTS,
and the visible app. A native runtime that can crash the UI is not acceptable
for canary Gateway traffic.

The stop path must be generation-aware. Diagnostics may issue a stop followed
immediately by a start, and Android can deliver both commands to the same
isolated process. A delayed kill from the older stop must not terminate the
newer Node start.

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

`externalNativeBuild` is now allowed on this branch because all are true:

- a candidate `libnode.so` is available locally;
- the bridge source is tiny and app-owned;
- the bridge links `libnode.so` and `libplawie_cpufeatures.so` in one Android
  linker dependency group;
- Gradle debug build passes with the local artifact packaged;
- the bridge degrades to a diagnostic load failure if `libnode.so` is absent;
- all native Node artifacts remain ignored unless provenance is approved.

This keeps normal APK builds stable while the native runtime is still research.

## Build Order

1. Produce Android `libnode.so` at Node `>=22.19.0`. Done for `22.22.3`.
2. Package `libnode.so` locally under `jniLibs/arm64-v8a/`. Done via
   `scripts/native_node/package_libnode_candidate.ps1`.
3. Add `libplawie_node_bridge.so` source via CMake. Done.
4. Add `libplawie_cpufeatures.so` from the Android NDK source tree. Done.
5. Add an isolated Android service that calls the bridge. Done.
6. Add Dart diagnostics methods distinct from the placeholder HTTP smoke slot.
   Done by preserving the native Node smoke runtime boundary.
7. Run `/health` smoke with
   `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`.
8. Prove repeated start/stop/restart and app-process crash containment.

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

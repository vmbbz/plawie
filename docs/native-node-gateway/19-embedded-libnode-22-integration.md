# Embedded Libnode 22 Integration

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Result

Plawie now has a Phase 1 embedded Node diagnostic lane for a locally built
Android arm64 Node `22.22.3` `libnode.so`.

This is not the production Gateway runtime and does not replace PRoot.

## Built Artifact

Local source artifact:

```text
/home/cosyc/plawie-native-node-build/v22.22.3-arm64/output/libnode-v22.22.3-android-arm64.so
```

SHA256:

```text
8ec6cc3738387d16c287aa18fd9b97bc980e9676ed3edbcdfe501e42d40b573f
```

ELF checks:

- `ELF64`
- `AArch64`
- shared object
- SONAME `libnode.so`
- Android dependencies include `libm`, `libdl`, `liblog`, `libc++_shared`,
  and `libc`

## Packaging

Local packaging command:

```powershell
.\scripts\native_node\package_libnode_candidate.ps1 `
  -CandidatePath "\\wsl.localhost\Ubuntu\home\cosyc\plawie-native-node-build\v22.22.3-arm64\output\libnode-v22.22.3-android-arm64.so" `
  -ExpectedSha256 "8ec6cc3738387d16c287aa18fd9b97bc980e9676ed3edbcdfe501e42d40b573f" `
  -DeclaredNodeVersion "22.22.3" `
  -Force
```

Packaged files:

```text
android/app/src/main/jniLibs/arm64-v8a/libnode.so
android/app/src/main/jniLibs/arm64-v8a/libnode.so.manifest.json
```

Both files are intentionally ignored by git.

## App Integration

The embedded lane consists of:

- `android/app/src/main/cpp/plawie_node_bridge.cpp`
- `android/app/src/main/cpp/CMakeLists.txt`
- `NativeNodeBridge.kt`
- `NativeNodeEmbeddedService.kt`
- `NativeNodeSmokeProcess.kt`
- `NativeGatewaySmokeService.runNativeNodeProcessSmokeTest()`

Runtime shape:

```text
Flutter diagnostics
  -> NativeBridge.startNativeNodeSmokeRuntime()
  -> MainActivity
  -> NativeNodeSmokeProcess
  -> NativeNodeEmbeddedService in :native_node_smoke
  -> System.loadLibrary("node")
  -> System.loadLibrary("plawie_node_bridge")
  -> node::Start("plawie-native-node", server.mjs)
  -> http://127.0.0.1:18790/health
```

The isolated service is declared as:

```xml
<service
    android:name=".NativeNodeEmbeddedService"
    android:exported="false"
    android:process=":native_node_smoke" />
```

This lets the first stop path kill only the isolated native process, not the
Flutter UI or production PRoot Gateway.

## Health Payload

Expected diagnostic response:

```json
{
  "ok": true,
  "runtime": "native-node-embedded",
  "node": "v22.22.3",
  "platform": "android",
  "arch": "arm64",
  "host": "127.0.0.1",
  "port": 18790,
  "productionGatewayPort": 18789,
  "openclawStarted": false
}
```

## Verification

Completed:

- `flutter analyze`
- offline debug APK build:
  `.\gradlew.bat :app:clean :app:assembleDebug --offline --no-daemon`
- APK contains:
  - `lib/arm64-v8a/libnode.so`
  - `lib/arm64-v8a/libplawie_node_bridge.so`
  - `lib/arm64-v8a/libc++_shared.so`
- no extra ABI copies of `libplawie_node_bridge.so` remain in the APK

Not completed:

- device runtime `/health` test, because `adb devices` showed no connected
  Android device during this phase.

## Next Gate

Install the debug APK on a connected arm64 Android device and run diagnostics
with:

```text
PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
```

Pass criteria:

- embedded Node starts in `:native_node_smoke`;
- `/health` returns `runtime: native-node-embedded`;
- stop terminates the isolated process;
- the Flutter UI process remains alive;
- PRoot Gateway startup still works afterwards.

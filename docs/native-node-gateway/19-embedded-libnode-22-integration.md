# Embedded Libnode 22 Integration

Last updated: 2026-05-30

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
  -> System.loadLibrary("plawie_node_bridge")
  -> Android loads bridge dependencies:
       libnode.so
       libplawie_cpufeatures.so
       libc++_shared.so
  -> node::Start("plawie-native-node", server.mjs)
  -> http://127.0.0.1:18790/health
```

`libplawie_cpufeatures.so` is built from the Android NDK cpufeatures source.
It is required because the Node 22.22.3 Android shared library references
`android_getCpuFeatures`. Loading it as a direct bridge dependency keeps symbol
resolution in one Android linker group; preloading it separately was not enough
on the tested device.

The isolated service is declared as:

```xml
<service
    android:name=".NativeNodeEmbeddedService"
    android:exported="false"
    android:process=":native_node_smoke" />
```

This lets the stop path kill only the isolated native process, not the Flutter
UI or production PRoot Gateway. The service uses a lifecycle generation guard so
the diagnostic "stop then start" sequence cannot let an older delayed stop kill
a newer embedded Node start.

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
  - `lib/arm64-v8a/libplawie_cpufeatures.so`
  - `lib/arm64-v8a/libplawie_node_bridge.so`
  - `lib/arm64-v8a/libc++_shared.so`
- no extra ABI copies of `libplawie_node_bridge.so` remain in the APK
- device runtime diagnostic on Samsung SM-A556E / Android 14:
  - native Android placeholder smoke passed;
  - embedded Node answered `/health`;
  - health payload reported `node: v22.22.3`, `platform: android`,
    `arch: arm64`;
  - isolated `:native_node_smoke` process stopped after the smoke run;
  - Flutter UI process remained alive;
  - PRoot Gateway startup continued afterwards.

Diagnostic build flag:

```text
PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
```

## Next Gate

The next phase can replace the health-only script with a minimal OpenClaw
bootstrap probe that still binds to `18790`, does not touch production `18789`,
and continues to fall back to PRoot for the real Gateway lane.

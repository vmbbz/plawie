# Native Node Binary Gate

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## What This Phase Means

The app now has a production-safe place to plug in a real Android Node runtime,
but it does not yet ship one.

Current production remains:

```text
GatewayService -> ProotGatewayRuntime -> OpenClaw on 127.0.0.1:18789
```

The research lane is:

```text
NativeNodeSmokeProcess
  -> nativeLibraryDir/libplawie_node.so
  -> files/native-node-smoke/server.mjs
  -> http://127.0.0.1:18790/health
```

That means the app can already manage a second runtime lifecycle without
touching the real Gateway. It can start, stop, log, and probe the native lane,
and it fails closed when the Node binary is absent.

## Source-Backed Findings

- The latest Node 22 LTS metadata checked on 2026-05-29 was `v22.22.3`.
  Its official distribution files include Linux, macOS, Windows, AIX, headers,
  and source packages, but no Android binary package.
- Node's official `BUILDING.md` includes Android build instructions, but states
  Android is not a supported platform and is not tested in Node's current CI.
- `nodejs-mobile` proves Node-in-Android is a real integration pattern, but the
  latest release checked here is `v18.20.4`, which is below OpenClaw's
  `>=22.19.0` engine requirement.

Sources:

- https://nodejs.org/dist/index.json
- https://github.com/nodejs/node/blob/main/BUILDING.md#android
- https://github.com/nodejs-mobile/nodejs-mobile/releases

## Decision

Do not download or commit an arbitrary Android Node binary.

For Plawie, the native Node runtime must be one of:

1. A reproducible custom Bionic-native Node `>=22.19.0` arm64 build.
2. A trusted upstream/mobile fork that is already at Node `>=22.19.0`.
3. A deliberately marked local-only spike binary with hash/provenance recorded,
   never promoted to production.

## Packaging Contract

The native process slot expects:

```text
android/app/src/main/jniLibs/arm64-v8a/libplawie_node.so
```

The file name uses the Android `jniLibs` packaging convention so Gradle places
the binary in `nativeLibraryDir`. It is treated as an executable by
`NativeNodeSmokeProcess`, not as a loaded JNI library.

The local packaging helper is:

```powershell
.\scripts\native_node\package_native_node_candidate.ps1 `
  -CandidatePath C:\path\to\android-arm64-node `
  -ExpectedSha256 <sha256> `
  -DeclaredNodeVersion v22.22.3
```

For local-only throwaway experiments, the script requires an explicit escape
hatch:

```powershell
.\scripts\native_node\package_native_node_candidate.ps1 `
  -CandidatePath C:\path\to\android-arm64-node `
  -AllowUnpinned `
  -DeclaredNodeVersion v22.x-local
```

The script:

- rejects directories;
- rejects suspiciously tiny files;
- verifies SHA-256 when supplied;
- copies the candidate into the `arm64-v8a` `jniLibs` slot;
- writes a local manifest beside the binary;
- leaves the binary and manifest ignored by git.

## Diagnostic Gate

After packaging a candidate:

```powershell
flutter build apk --debug --dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Expected diagnostic result:

```json
{
  "ok": true,
  "runtime": "native-node",
  "node": "v22.x",
  "platform": "android",
  "arch": "arm64",
  "productionGatewayPort": 18789,
  "openclawStarted": false
}
```

Required checks:

- Native Node responds on `127.0.0.1:18790`.
- Start, stop, and restart leave no orphan process.
- PRoot Gateway still starts afterward on `127.0.0.1:18789`.
- Android node still pairs with the PRoot Gateway.
- No chat, tools, skills, TTS, dashboard, or model route is moved to native.

## Promotion Rule

A Node binary that passes this gate is still not a Gateway runtime.

It only graduates to the next phase when it can run a curated OpenClaw command,
starting with:

```text
openclaw --version
```

Only after that works should we try native OpenClaw Gateway boot on the shadow
port.

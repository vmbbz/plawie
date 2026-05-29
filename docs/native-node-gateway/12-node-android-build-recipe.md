# Node Android Build Recipe

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Purpose

This document turns the binary gate into an actionable build path. Because
official Node 22 releases do not include an Android runtime artifact, Plawie's
first trustworthy candidate should come from a verified source build rather
than an opaque downloaded binary.

## Current Pin

| Field | Value |
| --- | --- |
| Node version | `v22.22.3` |
| Source artifact | `https://nodejs.org/dist/v22.22.3/node-v22.22.3.tar.xz` |
| Source SHA-256 | `f3e6a578db1ab335a4a72785c1e87ad18a2cf6d2fc25747a1d741fb34af0bd0f` |
| Android target | `arm64` / `arm64-v8a` |
| Android SDK passed to Node | `29` |
| App NDK currently configured | `28.2.13676358` |

The source hash comes from Node's official
`https://nodejs.org/dist/v22.22.3/SHASUMS256.txt`.

## Build Host

Use Linux or WSL. A plain PowerShell session is not the intended host for this
script because Node's Android path uses Unix shell tooling, `make`, and the
Android NDK.

Expected tools:

- `curl`
- `tar` with xz support
- `sha256sum`
- `make`
- a Python version accepted by Node's `android-configure`
- Linux-host Android NDK
- Linux host compilers `gcc` and `g++`

Important: if the NDK was installed from Windows Android Studio, it may contain
only `toolchains/llvm/prebuilt/windows-x86_64`. WSL needs
`toolchains/llvm/prebuilt/linux-x86_64`.

## Prepare Linux NDK

The app currently pins Gradle to NDK `28.2.13676358`, which maps to NDK `r28c`.
Android's unsupported downloads wiki lists the Linux package as:

| Field | Value |
| --- | --- |
| File | `android-ndk-r28c-linux.zip` |
| Size | `722261334` bytes |
| SHA-1 | `a7b54a5de87fecd125a17d54f73c446199e72a64` |
| Source | `https://github.com/android/ndk/wiki/Unsupported-Downloads` |

From WSL:

```bash
./scripts/native_node/prepare_android_ndk_linux.sh
export ANDROID_NDK_HOME="$HOME/.plawie/android/android-ndk-r28c"
```

## Command

From the repo root inside Linux/WSL:

```bash
export ANDROID_NDK_HOME="$HOME/.plawie/android/android-ndk-r28c"
WORK_DIR="$HOME/plawie-native-node-build/v22.22.3-arm64" \
  JOBS=4 ./scripts/native_node/build_node_android_arm64.sh
```

The helper:

- downloads the official source tarball if missing;
- verifies the pinned source SHA-256 before extraction;
- runs Node's `android-configure` for Android arm64;
- forces host build tools through Linux `gcc/g++` while target code uses the
  Android NDK compiler;
- removes Android arm64-only flags from generated `*.host.mk` files;
- runs `make`;
- copies the built candidate to `build/native-node/.../output`;
- writes a SHA-256 file for the candidate;
- prints the PowerShell packaging command for the APK slot.

The `WORK_DIR` example intentionally uses the WSL filesystem instead of the
Windows-mounted repo path. The current Windows drive may have limited free
space, and native compilation is faster away from `/mnt/c`.

If host objects were previously compiled with the wrong compiler, force a
host-object rebuild once:

```bash
CLEAN_HOST_OBJECTS=1 \
  WORK_DIR="$HOME/plawie-native-node-build/v22.22.3-arm64" \
  JOBS=4 ./scripts/native_node/build_node_android_arm64.sh
```

Leave `CLEAN_HOST_OBJECTS` unset for normal resume attempts.

## Package And Smoke

After a successful build, package the local candidate from PowerShell:

```powershell
.\scripts\native_node\package_native_node_candidate.ps1 `
  -CandidatePath .\build\native-node\v22.22.3-arm64\output\node-v22.22.3-android-arm64 `
  -ExpectedSha256 <candidate-sha256> `
  -DeclaredNodeVersion v22.22.3 `
  -Force
```

Then run the diagnostics build:

```powershell
flutter build apk --debug --dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

The expected first win is only:

```text
Native Node starts -> /health responds on 127.0.0.1:18790 -> process stops cleanly
```

It is not yet expected to run OpenClaw.

## Failure Notes

If the build fails, capture:

- exact Node version;
- NDK version;
- NDK host tag, especially whether `linux-x86_64` exists;
- whether `CC.host`/`CXX.host` were Linux host compilers or Android target
  compilers;
- whether generated host makefiles still contain target-only flags such as
  `-mbranch-protection=standard`;
- whether V8 host makefiles are compiling target-architecture assembly such as
  `deps/v8/src/heap/base/asm/arm64/push_registers_asm`.
- Android SDK version passed to `android-configure`;
- host OS/WSL distro;
- first compiler or linker error;
- whether `out/Release/node` was produced.

This determines whether the next move is a Node patch, a lower-risk embedded
runtime path, or a fork from `nodejs-mobile` rebased to Node 22.

## Production Boundary

This recipe cannot alter production behavior by itself. It writes only under
`build/native-node/`, and the packaging step writes a git-ignored local
candidate into `jniLibs`. `GatewayRuntimeRegistry.current` remains PRoot.

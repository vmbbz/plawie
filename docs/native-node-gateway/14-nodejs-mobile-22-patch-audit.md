# Nodejs-Mobile 22 Android Patch Audit

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Why This Audit Exists

The direct upstream Node `v22.22.3` Android build path reached real artifacts
but failed before producing an executable. The next decision is whether Plawie
should keep patching upstream `nodejs/node` directly, or pivot toward the
Android-specific approach used by `nodejs-mobile`.

This audit compares the current mobile branch against upstream Node and records
what it means for Plawie's native Gateway plan.

## Sources Inspected

| Source | Value |
| --- | --- |
| mobile repo | `https://github.com/nodejs-mobile/nodejs-mobile.git` |
| branch | `update22-9-0` |
| inspected commit | `106c51f95d55d1010de56a2ffd09bfb4ba819a47` |
| upstream comparison tag | `nodejs/node v22.9.0` |
| mobile branch Node version | `22.9.0` |
| Plawie/OpenClaw engine floor | `>=22.19.0` |

## Immediate Finding

The mobile branch is useful, but it is not a final Plawie runtime candidate.

Reasons:

- it is Node `22.9.0`, below OpenClaw's `>=22.19.0` requirement;
- it builds an embedded `libnode.so`, not a standalone CLI-style `node`
  executable;
- its Android configure path uses `--with-intl=none`, which may be too small
  for OpenClaw/provider behavior unless proven safe;
- it carries broad mobile patches that need to be reviewed, rebased, and tested
  rather than copied blindly.

## Mobile Build Shape

The branch adds `tools/android_build.sh`. Its Android path:

1. runs `make clean`;
2. runs `./android-configure <ndk> <sdk> <arch>`;
3. builds with `make`;
4. copies `out/Release/lib.target/libnode.so` or
   `out/Release/obj.target/libnode.so` into `out_android/<abi>/libnode.so`;
5. copies Node headers into `out_android/libnode/include`.

Its CI uses:

| Field | Value |
| --- | --- |
| host | Ubuntu 22.04 |
| NDK | `r26d` |
| Android target SDK | `24` |
| Android targets | `arm`, `arm64`, `x86_64` |
| artifact | `nodejs-mobile-android` containing `bin/<abi>/libnode.so` and headers |

## Core Patch Themes

The branch differs from upstream Node `v22.9.0` in many files, but the Android
runtime-relevant themes are:

| Area | Observed change | Plawie implication |
| --- | --- | --- |
| Android configure | Adds host `CC_host`/`CXX_host`; adds `android_ndk_sysroot`; configures with `--shared`, `--with-intl=none`, and `--openssl-no-asm` | This directly addresses part of the host/target leakage we hit, but outputs an embedded library rather than an executable |
| Android artifact | Builds and packages `libnode.so` per ABI | Plawie needs an embedded runtime runner for this path; the existing `NativeNodeSmokeProcess` executable slot cannot invoke a shared library as a process |
| Native module loading | Links Android loadable modules against the ABI-specific `libnode.so` | Useful for Android-native addons later, but does not make Linux/glibc `.node` files usable |
| Tests/build targets | Skips `cctest` while building Android shared Node | Reduces host/target build friction and avoids non-runtime test binaries |
| V8 trap handler | Disables trap handler support via Android patch | Potentially important for Android stability; must be carried deliberately if rebasing |
| Headers | Adds `copy_libnode_headers.sh` for Android/iOS | Required if Plawie ever builds native addons against the embedded runtime |
| Mobile JNI proof | Includes Android test app that calls `node::Start(argc, argv)` from JNI and redirects stdout/stderr to logcat | Confirms the embedded runner shape we would need inside Plawie |

## Why This Matters

Our current Android code has two native-runtime shapes now:

```text
Executable process shape
  NativeNodeSmokeProcess
  -> nativeLibraryDir/libplawie_node.so
  -> ProcessBuilder(...)
  -> JS smoke server on 127.0.0.1:18790

Embedded library shape
  Android/Kotlin or JNI runner
  -> System.loadLibrary("node")
  -> native startNodeWithArguments(...)
  -> node::Start(argc, argv)
  -> JS smoke server on 127.0.0.1:18790
```

The first shape preserves crash isolation better. The second shape is closer to
what `nodejs-mobile` already proves on Android.

## Decision From This Audit

Keep both research paths, but change priority:

1. Keep the direct executable build path as a tracked research path because it
   best matches the current `NativeNodeSmokeProcess` contract and isolates
   crashes better.
2. Start a parallel embedded `libnode.so` proof path because the mobile branch
   already carries Android build-system patches and a JNI runner pattern.
3. Do not promote either path until a Node `>=22.19.0` candidate exists.
4. Do not feed `nodejs-mobile`'s current `22.9.0` `libnode.so` into the
   executable packaging helper. It is the wrong artifact shape and below the
   OpenClaw engine floor.

## Rebase Probe Result

The first live probe disproved the optimistic "small rebase" assumption.

`scripts/native_node/probe_nodejs_mobile_rebase.sh` attempted to rebase
`nodejs-mobile/update22-9-0` directly onto upstream Node `v22.22.3`.
It stopped at commit `2/148` with `11589` conflicted files. That path is too
wide for Plawie's production-risk posture.

`scripts/native_node/probe_nodejs_mobile_core_patch.sh` then extracted only the
Android/core build patch surface from mobile Node `22.9.0` and applied it to
clean upstream Node `v22.22.3`. That narrowed the real patch work:

- generated patch size: `718` lines across `8` files;
- `android_configure.py` applied cleanly;
- `deps/v8/src/trap-handler/trap-handler.h` applied cleanly;
- `common.gypi` and `node.gyp` need manual porting.

The right next step is not broad rebase conflict resolution. It is a deliberate
manual port of those build-system changes, then an NDK arm64 build attempt.

Follow-up reject inspection narrowed the port further:

- `git apply --reject` applied most hunks to a disposable Node `v22.22.3`
  checkout;
- only `common.gypi.rej` and `node.gyp.rej` remained;
- the Android shared-Node `cctest` skip already applied;
- the remaining `node.gyp` rejects are mostly iOS/static-library carry-over or
  secondary cleanup;
- the `common.gypi` reject is a compiler-warning flag whose context drifted
  because upstream added `openharmony`.

This means the next candidate should be Android-first. Avoid carrying iOS-only
patches into Plawie unless a build error proves they are coupled to Android.

## Next Implementation Slice

The next safe slice remains hidden embedded smoke work, but the artifact source
must first be made real:

1. Apply the mobile Android/core patch to upstream Node `v22.22.3` with
   rejects in a disposable worktree.
2. Reconcile the Android-first rejects instead of importing every iOS mobile
   hunk.
3. Build an Android arm64 `libnode.so` candidate with explicit NDK and Intl
   settings.
4. Record the candidate version, build inputs, output path, and SHA-256.
5. Add a separate Android-side runner contract for embedded `libnode.so`.
6. Keep it disabled unless
   `PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`.
7. Load only a smoke script that serves `/health` on `127.0.0.1:18790`.
8. Capture stdout/stderr into Android logs.
9. Prove start/stop/restart behavior.

## Risks Added By The Embedded Path

| Risk | Why it matters | Required mitigation |
| --- | --- | --- |
| Flutter process crash | Embedded Node crash can kill the app process | Run in a separate Android process before any user-facing canary |
| Stop semantics | `node::Start` is not the same as killing a child process | Use smoke-only scripts first; design explicit shutdown |
| Duplicate Node runtimes | Executable and embedded paths can be confused | Keep separate docs, artifact names, and diagnostics |
| Intl disabled | Mobile branch config disables Intl | Re-enable or prove OpenClaw does not need it before Gateway boot |
| Node version lag | Current inspected branch is `22.9.0` | Rebase to `>=22.19.0` or wait for matching mobile branch |
| Native addon ABI | Android `.node` addons must link against Android `libnode.so` | Never reuse Linux/glibc addon packages |

## Current Call

Proceed with an embedded `libnode.so` smoke lane as the next experiment, while
leaving production Gateway and the executable-process lane untouched.

The native Gateway should still not run real OpenClaw until:

- a Node `>=22.19.0` Android runtime exists;
- `/health` smoke passes on device;
- lifecycle and crash behavior are understood;
- the curated OpenClaw bundle has removed or replaced Linux-only dependencies.

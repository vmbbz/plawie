# Node 22 Android Build Attempt

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Goal

Build a trustworthy Android arm64 Node `>=22.19.0` candidate from verified
Node source, then feed it into the existing `NativeNodeSmokeProcess` slot.

## Environment

| Field | Value |
| --- | --- |
| Host | WSL Ubuntu `24.04.2 LTS` |
| Node source | `v22.22.3` |
| Node source SHA-256 | `f3e6a578db1ab335a4a72785c1e87ad18a2cf6d2fc25747a1d741fb34af0bd0f` |
| Android NDK | `r28c` / `28.2.13676358` Linux package |
| NDK package SHA-1 | `a7b54a5de87fecd125a17d54f73c446199e72a64` |
| Android API | `29` |
| Target | `arm64` / `arm64-v8a` |
| Work dir | `/home/cosyc/plawie-native-node-build/v22.22.3-arm64` |

## What Worked

- WSL could see and run the repo build helpers.
- The Windows Android Studio NDK was correctly rejected because it only
  contained `prebuilt/windows-x86_64`.
- The Linux NDK `r28c` package downloaded successfully and matched the
  published SHA-1.
- The custom extractor now preserves NDK symlinks, including
  `clang -> clang-19`.
- Node `android-configure` completed for Android arm64.
- The build generated host tools including `node_js2c`, `torque`, `genccode`,
  `icupkg`, and V8 bytecode helpers.
- The build produced target `out/Release/obj.target/libnode.a`.

## Fixes Added During Attempt

- `prepare_android_ndk_linux.sh`
  - downloads the matching Linux-host NDK;
  - verifies package size and SHA-1;
  - preserves symlinks during extraction;
  - repairs executable bits.
- `build_node_android_arm64.sh`
  - rejects non-Linux NDK host toolchains;
  - uses Linux `gcc/g++` for `CC.host`, `CXX.host`, and `LINK.host`;
  - removes Android-only `-mbranch-protection=standard` from generated
    `*.host.mk` files;
  - only cleans `obj.host` when `CLEAN_HOST_OBJECTS=1`.

## Current Blocker

The direct upstream `android-configure` path still mixes host and target V8
rules.

After the host compiler fixes, the build fails when an x86_64 host assembler
tries to assemble ARM64 code from:

```text
deps/v8/src/heap/base/asm/arm64/push_registers_asm
```

Observed final errors include rejected ARM64 instructions such as:

```text
stp
blr
ldp
```

This means the next fix is not another environment tweak. It is a Node/V8
cross-build configuration issue.

## Result

No `out/Release/node` executable was produced.

The native process smoke slot remains ready, but there is not yet a packaged
Android Node candidate to test.

## Next Decision

Two paths remain credible:

1. Patch the upstream Node/V8 gyp host/target split enough to build Node 22
   directly.
2. Use a `nodejs-mobile` style fork/build system and rebase the mobile Android
   patches to Node 22.

The second path may be more realistic if the direct `nodejs/node`
`android-configure` route keeps leaking target architecture files into host
toolsets.

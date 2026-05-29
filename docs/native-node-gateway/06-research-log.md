# Research Log

Last updated: 2026-05-29

This log records source-backed facts used by the native Gateway track.

## Source-Backed Facts

### PRoot

PRoot is a user-space implementation of Linux filesystem/process environment
features such as `chroot`, bind mounts, and related behavior without requiring
root privileges. That is why it is useful on Android, but also why it is not a
zero-cost native runtime.

Source: https://proot-me.github.io/

### Node.js On Android

The Node.js source tree contains Android build-related guidance, but Android is
not treated like the normal officially distributed desktop/server platforms.
For Plawie this means native Node is possible but should be treated as our own
supported runtime target, with pinned versions and device testing.

Source: https://github.com/nodejs/node/blob/main/BUILDING.md

Current check: Node's BUILDING.md still states Android is not a supported
platform. That does not block a custom runtime, but it means Plawie owns the
runtime QA burden rather than inheriting normal nodejs.org binary support.

2026-05-29 binary check: the latest Node 22 LTS metadata returned `v22.22.3`
with official files for AIX, Linux, macOS, Windows, headers, and source, but no
Android runtime artifact. `nodejs-mobile` latest release metadata returned
`v18.20.4`, which is useful integration evidence but below OpenClaw's
`>=22.19.0` engine floor.

Sources:

- https://nodejs.org/dist/index.json
- https://github.com/nodejs-mobile/nodejs-mobile/releases

### Android Native Runtime

Android NDK applications use Android native runtime assumptions, including
Bionic/libc++ behavior rather than a standard glibc Linux userspace. This is why
a Bionic-native runtime is preferred over a glibc compatibility strategy for a
production mobile app.

Sources:

- https://developer.android.com/ndk/guides/cpp-support
- https://android.googlesource.com/platform/bionic/

### Embedded Node Proof

`nodejs-mobile` demonstrates that running Node.js inside Android apps is a
practical pattern. It is not automatically a drop-in for OpenClaw Gateway, but
it is strong evidence that the runtime shape is feasible.

Source: https://nodejs-mobile.github.io/docs/guide/guide-android/getting-started/

### Installed OpenClaw Package Inventory

The device inventory on `RZCX30KA9AW` found:

- `openclaw` version `2026.5.20`
- Node engine requirement `>=22.19.0`
- ESM package with `openclaw.mjs` as the CLI bin
- 50 direct dependencies, 2 optional dependencies, and 251 discovered
  `package.json` files under `node_modules` at depth 2
- installed package size: about `668M`, with about `551M` in `node_modules`
- native addon files for Linux/glibc or Linux/musl packages, including canvas,
  sharp, node-pty, tree-sitter-bash, koffi, and clipboard packages

Implication: native Android cannot safely reuse the installed PRoot
`node_modules` tree as-is.

### Native Node Process Slot

The repo now has the Android/Dart lifecycle slot for a future real Node binary:

- Android runner: `NativeNodeSmokeProcess`
- expected executable: `nativeLibraryDir/libplawie_node.so`
- generated script: `files/native-node-smoke/server.mjs`
- health URL: `http://127.0.0.1:18790/health`

The slot currently reports a clean skip because no Android-native Node
executable is packaged yet.

A local packaging helper now exists at
`scripts/native_node/package_native_node_candidate.ps1`. It is intentionally
hash-first and local-only so a research binary cannot be silently promoted.

The first reproducible build scaffold now exists at
`scripts/native_node/build_node_android_arm64.sh`. It downloads Node
`v22.22.3` source from nodejs.org, verifies the official source SHA-256
`f3e6a578db1ab335a4a72785c1e87ad18a2cf6d2fc25747a1d741fb34af0bd0f`, and runs
Node's Android configure path for arm64.

Local preflight on 2026-05-29 found WSL Ubuntu `24.04.2 LTS` and the app's
Windows NDK at `C:\Users\cosyc\AppData\Local\Android\Sdk\ndk\28.2.13676358`.
That NDK contains only `toolchains/llvm/prebuilt/windows-x86_64`, so it is not
usable from WSL. Added
`scripts/native_node/prepare_android_ndk_linux.sh` to fetch the matching Linux
NDK `r28c` package from Google's Android repository and verify the SHA-1 listed
by the Android NDK wiki.

Source:

- https://github.com/android/ndk/wiki/Unsupported-Downloads

First Node build attempt on 2026-05-29:

- Node configure completed for Android arm64.
- NDK `r28c` initially extracted with Python's default zip path, which lost
  symlinks such as `clang -> clang-19`. The prep helper now preserves symlinks.
- After fixing the NDK extraction, the build reached V8 host objects but failed
  because `CC.host` and `CXX.host` were still the Android target compilers. The
  helper now forces `CC.host=gcc`, `CXX.host=g++`, and `LINK.host=g++` during
  `make`.
- With Linux host compilers, the next blocker was Android arm64-only
  `-mbranch-protection=standard` leaking into `*.host.mk`. The helper now
  removes that flag from host makefiles after `android-configure`.
- After that, the build produced host generator tools (`node_js2c`, `torque`,
  ICU tools) and target `libnode.a`, but final executable build did not
  complete. The next hard blocker is V8 host makefiles compiling ARM64 assembly
  (`deps/v8/src/heap/base/asm/arm64/push_registers_asm`) with the x86_64 host
  assembler, producing errors for ARM64 instructions such as `stp`, `blr`, and
  `ldp`.

Implication: upstream Node 22 Android cross-build is close enough to configure
and produce major artifacts, but the V8 host/target split is not clean under
this direct `android-configure` path. The next fix likely requires a V8/Node
build-configuration patch, not more shell setup.

Nodejs-mobile branch audit on 2026-05-29:

- `nodejs-mobile/nodejs-mobile` has an `update22-9-0` branch at commit
  `106c51f95d55d1010de56a2ffd09bfb4ba819a47`.
- The branch reports Node `22.9.0`, which is below OpenClaw's `>=22.19.0`
  engine floor.
- Compared with upstream Node `v22.9.0`, the mobile branch adds Android
  build-system patches that produce `out_android/<abi>/libnode.so`.
- Its Android build path configures Node with `--shared`, `--with-intl=none`,
  and `--openssl-no-asm`, sets host compiler variables, and includes an Android
  JNI test app that calls `node::Start(argc, argv)`.
- This is a strong embedded-runtime proof, but not a drop-in candidate for the
  current `NativeNodeSmokeProcess` executable slot.

Implication: Plawie should keep the direct executable path alive, but the next
practical experiment is a separate embedded `libnode.so` smoke lane that can be
rebased to Node `>=22.19.0`.

Nodejs-mobile rebase advice captured on 2026-05-29:

- External research suggested rebasing `nodejs-mobile` `update22-9-0` onto
  upstream Node `v22.22.3`, building Android arm64 with the repo's Android
  helper, and testing NDK r24/r26-style toolchains before r28.
- Treat this as a hypothesis. The actual work must record conflicts, NDK
  version, Intl configuration, output path, reported Node version, and SHA-256.
- The result, if any, is embedded `libnode.so`; it belongs to the embedded
  smoke lane and still needs an app-owned JNI bridge.

Implication: create a controlled rebase experiment before adding any native
artifact to Plawie. Do not copy generated binaries into git or production
`jniLibs`.

AVF repository audit on 2026-05-29:

- `https://github.com/justforfun-2025/androidclaw` has a public `main` branch
  at `da863001763003030d29ea2808ddba3a6cccdea2`.
- Its root README documents the current AVF/Debian VM architecture with Node
  `22.22.0`, OpenClaw `2026.2.9`, Playwright + Chromium, and VM Gateway port
  `18790` on the AVF bridge address `192.168.0.2`.
- The same repo keeps an archived `app-nodejs-mobile` directory. Its README
  says the embedded Node 18 path worked for basic chat but was abandoned
  because Playwright/Chromium, native modules, ICU, and lifecycle behavior were
  too constrained.
- The `app-proxy` directory documents a VM-to-Android control proxy, but it
  requires privileged/system-app installation as shell UID. That is useful
  research evidence, not a normal-user Plawie shipping path.

Implication: AVF is the strongest known full-fidelity OpenClaw path on devices
that support it. It should become a gated runtime lane alongside PRoot and
embedded Node, not a universal replacement.

First AVF eligibility probe on 2026-05-29:

- Connected device: `RZCX30KA9AW`
- Manufacturer/model: Samsung `SM-A556E`
- Android release/API: Android `14`, SDK `34`
- Hypervisor support props inspected by the script were empty.
- `com.android.virtualmachine.res` was present, but no Terminal/VM Gateway was
  reachable at `192.168.0.2:18790`.

Implication: the current test phone should be treated as a non-AVF or
not-yet-AVF-ready device for Plawie runtime work. AVF remains a high-end /
eligible-device lane, while PRoot and embedded Node remain necessary for broad
support.

AndyClaw repository audit on 2026-05-29:

- `https://github.com/EthereumPhone/AndyClaw` has a public `main` branch at
  commit `55c490890a129ed3e52358caab04ca0e2159941a`.
- Its README describes an Android APK assistant with open stock-Android mode,
  privileged ethOS mode, local Qwen 1.5B, OpenRouter/Tinfoil providers,
  skills, heartbeat, Termux integration, and extensions.
- `NodeRuntime.kt` is an Android/Kotlin assistant runtime for skills,
  heartbeat, and agent loops. It is not a Node.js runtime.
- `TermuxSkill.kt` and `TermuxCommandRunner.kt` show an optional Termux
  sidecar pattern using the Termux `RUN_COMMAND` service and callback result
  intents.
- `GatewayDiscovery.kt` and `GatewaySession.kt` show Android-side OpenClaw
  Gateway discovery, WebSocket connect/auth, reconnect, request/response,
  `node.event`, and `node.invoke.request` handling.
- The shared `AndyClaw/src/main/java/.../skills` package mirrors SKILL.md
  frontmatter, skill registry, execution metadata, and command specs in
  Kotlin.
- `ExtensionExample/README.md` documents APK extension discovery through
  manifest metadata and IPC bridge options.
- `AGENT_DISPLAY_API.md` and `AGENT_VIRTUAL_DISPLAY.md` document virtual
  display and screen-control patterns.
- The repository is GPL-3.0 licensed, so implementation copying requires
  license review.

Implication: AndyClaw is valuable as a reference for Android-side capabilities,
Termux, extension, Gateway client, and virtual-display design. It is not a
Node `>=22.19.0` Gateway runtime source and should not be classified as a
PRoot replacement.

## Working Assumptions

- OpenClaw Gateway can eventually run from a bundled JavaScript asset tree if
  its runtime dependencies are pure JS or Android-compatible.
- The biggest unknown is not "can Node start on Android"; it is whether the
  OpenClaw dependency graph assumes GNU/Linux behavior in ways that matter.
- A native runtime is only worth promoting if it improves startup, memory,
  lifecycle control, and timeout behavior without damaging Gateway semantics.
- The first Phase 2 smoke target should validate native lifecycle and loopback
  health without bundling a Node binary yet. That keeps production Gateway
  untouched while we prepare the real Node packaging step.

## Open Questions

1. Which exact Node major version should be pinned for native Android?
2. Does OpenClaw depend on native npm modules in the current mobile bundle?
3. Does OpenClaw call shell utilities during normal Gateway boot or only during
   install/repair workflows?
4. Can the native runtime be isolated in a separate Android process?
5. What is the smallest bundle that supports Gateway, dashboard, Talk, tools,
   sessions, and node pairing?
6. Can the native runtime share the current app-owned config writer without
   any runtime-side writes during boot?
7. Which devices/ABIs should be in the minimum native runtime test matrix?
8. Should the first Node `>=22.19.0` candidate be built directly from
   `nodejs/node`, forked from `nodejs-mobile`, or produced by a dedicated
   Android runtime build repo?
9. Does upstream Node `v22.22.3` build cleanly with Android NDK
   `28.2.13676358` for arm64, or do we need a patch/fork?
10. Does Node 22 build successfully with NDK r28c on WSL once the Linux-host
    NDK is installed?
11. Should the next attempt patch Node/V8 gyp host rules, or pivot to a
    `nodejs-mobile` style fork that already carries Android build-system
    patches?
12. Can the `nodejs-mobile` Android patches be rebased cleanly onto Node
    `v22.22.3` without disabling Intl?
13. Should embedded Node run in the main app process for smoke only, then move
    to an isolated Android process before any OpenClaw boot attempt?
14. Which Plawie target devices expose Android Terminal/AVF VM support?
15. Can Plawie start/stop the AVF VM programmatically, or must setup remain a
    manual/user-driven beta flow?
16. Can Android node/device capabilities connect to a VM Gateway without a
    privileged proxy app?
17. Should Plawie expose Termux as an optional sidecar capability, and what
    setup/error UX keeps it from being confused with core Gateway runtime?
18. Which Android capability metadata should become shared across PRoot, AVF,
    embedded Node, and local-only model lanes?
19. Can VM-to-app `node.invoke` be implemented entirely through Plawie's normal
    app permissions and current node bridge?

## Immediate Research Tasks

- Produce a dependency inventory for the OpenClaw Gateway package currently
  installed in PRoot. Initial pass complete; keep expanding it as the bundle is
  narrowed.
- Identify all GatewayService calls into `NativeBridge` that assume PRoot.
- Measure current PRoot cold start, returning attach, memory, and first-token
  baseline before implementing native prototypes.
- Replace the Phase 2 Android smoke endpoint with a real native/embedded Node
  health endpoint on the same non-production port.
- Produce or obtain a trustworthy Node `>=22.19.0` Android arm64 executable and
  run it through the binary gate.
- Run the source-build helper on Linux/WSL with the Android NDK and record the
  first build result.
- Build or rebase a Node `>=22.19.0` embedded `libnode.so` candidate and add a
  hidden embedded smoke runner that is distinct from the executable process
  slot.
- Run `scripts/avf/check_avf_eligibility.ps1` when a device is connected and
  record the first AVF eligibility snapshot.
- Produce an Android capability bridge design that uses AndyClaw only as a
  reference and keeps Termux/extensions disabled by default.

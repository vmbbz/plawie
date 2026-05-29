# Runtime Options

Last updated: 2026-05-29

This compares practical ways to run OpenClaw Gateway on Android.

## Option A: Keep PRoot

### Summary

Continue running OpenClaw in the current Ubuntu-like PRoot userland.

### Pros

- Proven in the current app.
- Highest compatibility with existing Linux-oriented OpenClaw assumptions.
- Supports shell tools and file layout that expect GNU/Linux behavior.
- Lowest near-term regression risk.
- Already integrated with install, repair, logs, dashboard, pairing, and config.

### Cons

- Slow startup and attach compared with a native process.
- Extra disk and memory overhead.
- User-space syscall/path emulation can be costly.
- More fragile around process lifecycle, file locks, permissions, and timeouts.
- Harder to make the app feel instant and mobile-native.

### Best Use

Production default and fallback until native runtime has full parity.

## Option B: Bionic-Native Node Runtime

### Summary

Package a Node runtime built for Android/Bionic and launch OpenClaw Gateway as a
native Android-managed process or embedded runtime.

### Pros

- Best long-term performance target.
- Removes PRoot userland overhead.
- Cleaner Android lifecycle integration.
- Lower disk footprint if OpenClaw can be bundled/pruned correctly.
- Better path to foreground-service supervision and faster health checks.

### Cons

- Node.js does not treat Android as a normal supported release platform.
- Native npm modules may require Android-specific rebuilds or replacement.
- OpenClaw dependencies may assume Linux tools, filesystem layout, or shell
  behavior not present in Android app storage.
- Crash/debug story moves into native/JNI/logcat territory.
- Packaging must handle ABI splits and app-store size constraints.

### Best Use

Long-term target behind a `NativeNodeGatewayRuntime` implementation.

## Option C: glibc Compatibility Layer

### Summary

Try to run Linux/glibc Node or Gateway artifacts through a glibc compatibility
environment on Android.

### Pros

- May preserve more Linux binary compatibility than pure Bionic.
- Could reduce some PRoot overhead if process execution is simpler.
- May let existing native modules run with fewer source changes in narrow cases.

### Cons

- Android is Bionic-based; glibc layers are inherently a compatibility trick.
- Loader/libc mismatch bugs can be subtle and expensive.
- Still leaves Linux assumptions in the app.
- Likely hard to support across devices, ABIs, and OS versions.
- Risk profile is worse than native Bionic for a production app.

### Best Use

Research fallback only. Not preferred as the main architecture.

## Option D: Embedded Node Library

### Summary

Embed Node as a library and start it from the Android app process or a managed
native thread. `nodejs-mobile` is the known proof that this style can work on
Android.

### Pros

- Strong lifecycle control from Android.
- Avoids a separate PRoot shell process.
- Can expose native-to-Node bridge hooks.
- May simplify bundling app-local JavaScript assets.

### Cons

- Coupling Node to the app process raises crash blast radius.
- Long-running Gateway workload may compete with Flutter/NDK memory pressure.
- Requires careful threading, logging, shutdown, and restart boundaries.
- Still inherits the Android Node support/dependency issues.

### Best Use

Prototype candidate. Prefer an isolated process if feasible so Gateway crashes
do not take down Flutter.

## Recommendation

Use a runtime abstraction and pursue Bionic-native Node first:

```text
GatewayService
  -> GatewayRuntime
       -> ProotGatewayRuntime        production default
       -> NativeNodeGatewayRuntime   hidden experimental runtime
```

PRoot remains default until native runtime passes the validation matrix.
glibc compatibility stays a research note, not the north-star.

## Option E: Termux Sidecar

### Summary

Use the user-installed Termux app as an optional Linux command sidecar through
Android intents. AndyClaw demonstrates this as a skills capability: the app
checks whether Termux is installed, asks the user to grant the RUN_COMMAND
permission, sends commands to Termux, and receives results through callbacks.

### Pros

- Works on more stock Android devices than AVF.
- Gives access to a persistent Linux-like package environment.
- Useful for optional CLI skills, diagnostics, and user-installed tools.
- Does not require bundling a large Linux rootfs inside Plawie.

### Cons

- Requires separate Termux installation and user setup.
- Can hang or time out during package installs or interactive prompts.
- Harder to guarantee provenance and repeatability.
- Not app-owned enough for core Gateway startup.
- Still does not provide a bundled OpenClaw Gateway runtime.

### Best Use

Optional capability/tool lane, not Gateway runtime replacement.

## Option F: Android Capability Bridge

### Summary

Keep OpenClaw Gateway where it belongs for each runtime lane, but expose Android
capabilities through a clean app-native bridge. AndyClaw is a useful reference
for this layer: Gateway WebSocket sessions, `node.invoke` callbacks,
permission-aware skills, extension manifests, and virtual-display tools.

### Pros

- Directly improves the tool/skills side of Plawie.
- Complements PRoot, AVF, and embedded Node instead of competing with them.
- Helps a VM-hosted Gateway call back into app-native camera, avatar, TTS,
  screen, haptics, and device capabilities.
- Lets Plawie keep privileged or risky functionality behind explicit gates.

### Cons

- It is not a Node runtime.
- Requires careful permission, safety, and persistence design.
- Cross-app extension loading increases security review scope.
- Privileged screen/input control patterns are not shippable for normal users
  without special device support.

### Best Use

Shared Android node/capability architecture for all runtime lanes.

## Updated Direction: AVF As Full-Fidelity Lane

After auditing `justforfun-2025/androidclaw`, AVF should be treated as a
separate full-fidelity runtime lane, not as a replacement for embedded Node.

The product strategy becomes:

| Runtime | Best for | Tradeoff |
| --- | --- | --- |
| PRoot | Universal support and current production stability | Existing overhead and lifecycle complexity |
| AVF Linux VM | Full upstream OpenClaw, Node 22, native modules, Playwright | Limited device support, higher resource use, separate VM lifecycle |
| Embedded `libnode.so` | Broad-device lightweight native runtime | Requires Node 22 rebase and cannot automatically support Linux desktop modules |
| Termux sidecar | Optional Linux CLI capability on stock Android | User-installed, setup-heavy, not a core Gateway runtime |
| Android capability bridge | Shared app-native tools for PRoot/AVF/native lanes | Requires permission and security polish |

AVF is the fastest route to full OpenClaw parity on eligible devices. Embedded
Node remains the likely broad-device route if AVF is unavailable.

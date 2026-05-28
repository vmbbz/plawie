# Runtime Options

Last updated: 2026-05-28

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


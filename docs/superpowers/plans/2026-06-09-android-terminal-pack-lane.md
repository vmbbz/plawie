# Android Terminal Pack Lane Plan

Date: 2026-06-09

Goal: prepare a safe APK-local `android-terminal-pack` lane for `tmux` without
pretending a real Android `tmux` payload exists yet.

## Design

The terminal pack is different from CLI-core because `tmux` usually depends on
shared libraries such as libevent and ncurses. The APK lane therefore needs two
asset roots:

```text
assets/openclaw/terminal/bin/
assets/openclaw/terminal/lib/
```

The Android bootstrap copies those into:

```text
filesDir/native-node-embedded/provisioning/terminal/bin/
filesDir/native-node-embedded/provisioning/terminal/lib/
```

`SkillProvisioningService` advertises `android-terminal-pack` only when a
bundled `tmux` binary exists. Provisioning installs terminal binaries into
`.openclaw/bin`, terminal shared libraries into `.openclaw/lib`, writes a pack
receipt, and keeps smoke-command environments ready for dynamic libraries via
`LD_LIBRARY_PATH`.

## Scope

- [x] Add Flutter asset lanes for terminal bin/lib roots.
- [x] Add Android bootstrap copy helpers and manifest counts.
- [x] Add APK resolver for `android-terminal-pack`.
- [x] Install terminal shared libraries into managed `.openclaw/lib`.
- [x] Include `.openclaw/lib` in dependency-pack smoke command env.
- [x] Add host tests for packaging and provisioning plumbing.
- [x] Install debug APK and prove the terminal bin/lib lane appears in
  `/device/health` plus native bootstrap manifest/logs on SM-A556E.
- [ ] Add real Android arm64 `tmux` payload with source/version/SHA/license.
- [ ] Run `tmux -V` on device from managed `.openclaw/bin`.
- [ ] Move fresh-user floor only after payload and device proof.

## Count Rule

This lane does not move the scorecard by itself. Count movement requires a real
Android arm64 `tmux` binary, required shared libraries, host provenance tests,
Android build proof, and installed-device smoke proof.

## Installed-Device Proof

2026-06-09, Samsung SM-A556E / aarch64:

```text
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk -> Success
/device/health:
  totalManifestSkills: 61
  installedNativeSkills: 65
  readyRequired: 13/13
  releaseGatePass: true
  unexpectedMissingDependency: 0
  tmux: needs_pack, missing android-terminal-pack, missing tmux
full_gateway_manifest.json:
  terminalBinCount: 0
  terminalLibCount: 0
terminal provisioning dirs:
  files/native-node-embedded/provisioning/terminal/bin exists and is empty
  files/native-node-embedded/provisioning/terminal/lib exists and is empty
```

The zero counts are expected for this round because `.gitkeep` is intentionally
rejected as an unsafe terminal payload name. This proves the lane, not `tmux`
runtime readiness.

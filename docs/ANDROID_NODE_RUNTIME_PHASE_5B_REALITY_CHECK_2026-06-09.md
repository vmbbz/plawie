# Android Node Runtime Phase 5B Reality Check

Date: 2026-06-09

Status: decision record for GTM Android default skill readiness.

## Decision

Do not spend the next GTM implementation round trying to ship a strict
standalone Android arm64 `node` executable pack.

The direct Node 22 executable path is technically possible, but it is not
Phase-5B-ready in this repo. The previous source-build attempt reached target
`libnode.a` but did not produce `out/Release/node`; the blocker was a real
Node/V8 cross-build host/target split, not a missing environment variable.

The proven Android Node path in this repo is the embedded `libnode.so` lane.
That lane is valuable for the Native Gateway architecture, but it is not the
same thing as a shell `node` binary in `.openclaw/bin`, so it must not be used
to mark shell/CLI-gated skills ready.

## What A Real Standalone Node Pack Would Move

Honest default-skill movement from a true `.openclaw/bin/node` executable:

```text
node-inspect-debugger: needs_pack -> ready, after pack install and smoke
```

Expected score movement if a real executable pack were built, bundled, and
device-proven:

```text
fresh Android floor: 24/51 -> 25/51
installed-device Android-relevant ready: 25/51 -> 26/51
launch-required gate: unchanged at 13/13
```

This is a useful win, but it is only `+1`. It does not justify pretending the
embedded `libnode.so` runtime is a shell `node` executable.

## What Node Alone Does Not Move

Do not claim these as fixed by a standalone `node` pack:

```text
gemini:
  still needs a real gemini CLI and auth/config truth.

coding-agent:
  still needs one of claude, codex, opencode, or pi, plus config/auth truth.

node-connect:
  remains manual_proot_compat and excluded from the Android default denominator.
```

Those skills belong in later CLI/config-specific lanes, not in a generic Node
runtime pack.

## Feasibility Findings

The strict executable route has two credible long paths:

1. Patch upstream Node/V8 build configuration enough to produce Android arm64
   `out/Release/node` from Node 22 source.
2. Use a `nodejs-mobile`-style Android build system and rebase the necessary
   mobile patches to a Node version compatible with OpenClaw.

Both are legitimate engineering projects. Neither is the next small GTM move.

The embedded runtime route already has proof:

```text
artifact: libnode-v22.22.3-android-arm64.so
runtime shape: Android service -> plawie_node_bridge -> libnode.so
device proof: /health returned node v22.22.3 on Android arm64
```

That proof supports the Native Gateway architecture, not the `.openclaw/bin`
binary requirement used by shell-style skills.

## Next Move

For GTM readiness, move Phase 5B to the next highest-value binary lane:

```text
android-vision-media-runtime, starting with ffmpeg -> video-frames
```

Reasons:

- It has clearer user-facing value than terminal/tmux.
- It avoids the Node/V8 build tarpit.
- It uses the Phase 5A command-smoke verifier directly.
- It can be kept honest as a narrow `video-frames` win; `gifgrep` remains
  blocked until a real `gifgrep` binary exists.

The standalone Node executable lane should remain documented as:

```text
android-node-executable-pack: research / later
expected honest movement: +1 only
primary blocker: Node 22 Android executable build
```

## Required If Node Lane Is Resumed

Before claiming progress on `android-node-executable-pack`, require:

- real Android arm64 executable named `node`;
- exact Node version and source commit/tag;
- full SHA-256 provenance;
- license and third-party notice bundle;
- dynamic dependency inventory;
- manifest `smokeCommand: node --version`;
- Phase 5A command-smoke pass on device;
- test proving `node-inspect-debugger` moves;
- tests proving `gemini` and `coding-agent` do not move from `node` alone.

## Code Path If Resumed

The Phase 5A verifier can already test a local `file://` dependency pack that
installs to `.openclaw/bin` and declares:

```json
{
  "installPath": "bin",
  "provides": {
    "runtimes": ["node"],
    "bins": ["node"]
  },
  "smokeCommand": {
    "command": "node",
    "args": ["--version"]
  }
}
```

That makes a local proof possible without APK asset work. An APK-local
`android-node-executable-pack` would still need a new bundled asset lane rather
than reusing the existing native-node diagnostic scripts:

```text
lib/services/skill_provisioning_service.dart
  add android-node-executable-pack catalog resolver
  advertise node only when copied bundled node exists

android/app/src/main/kotlin/.../NativeNodeEmbeddedService.kt
  copy assets/openclaw/node-debug/bin/node into provisioning/bin

pubspec.yaml
  include assets/openclaw/node-debug/bin/

scripts/native_node/
  add a dependency-pack packaging helper, not the jniLibs diagnostic packer

tests
  success node --version pack smoke
  node-inspect-debugger moves with real node
  gemini/coding-agent stay blocked with node alone
```

Actual Node module skill execution is a separate runner concern. Today the
Native node skill runner starts the embedded `libnode.so` path; a standalone
`.openclaw/bin/node` only satisfies readiness gates until a runner explicitly
chooses that executable.

# Release Variants And PRoot Removal Plan

Date: 2026-06-02

Status: next strategic release-boundary phase after native default and rollback
proof.

## Decision

This branch is now the native Gateway branch.

`main` can continue carrying the mature PRoot build. This branch should move
toward removing PRoot entirely, but not by deleting rollback before the native
runtime has had one public/native-default cycle.

The migration target is:

```text
OpenClaw Gateway runtime: embedded Android native Node libnode.so
Local/offline inference: fllama NDK
PRoot: removed after a staged rollback sunset
```

Local NDK LLM is not being removed.

## Release Variants

| Variant | Gateway default | PRoot included | Diagnostics | User story |
| --- | --- | --- | --- | --- |
| Debug/internal diagnostics | Native unless sticky rollback | Yes | Broad native canaries enabled | Engineering validates edge cases |
| Public native-default rollback build | Native | Yes | Broad canaries disabled, rollback retained | Users get native Gateway with emergency rollback |
| Internal no-PRoot build | Native | No | Native repair/reset diagnostics | Team validates no PRoot dependency remains |
| Public no-PRoot build | Native | No | User-safe repair/reset only | Final simplified native app |

## What Stays

These are not PRoot and must remain:

- Local LLM page.
- GGUF model downloads.
- `LocalLlmService`.
- fllama / llama.cpp NDK runtime.
- direct `local-llm/...` route.
- manual `plawie_ndk/local-llm` Gateway bridge on `127.0.0.1:11435`.
- Android node host on `127.0.0.1:8765`.

## What Goes Away Later

When the no-PRoot stage is reached, remove:

- Ubuntu rootfs payload.
- PRoot binary/service wrapper.
- PRoot OpenClaw install/repair paths.
- PRoot-only bionic bypass files.
- PRoot CLI reload calls.
- PRoot rootfs model/server remnants.
- user-facing text that implies PRoot is a normal runtime.

## Current Code Boundary

Current code still keeps PRoot available as rollback. It also now mirrors
Gateway config and auth profile writes into the native OpenClaw home when that
native home exists. That is an intentional step toward making the native
`.openclaw` directory canonical.

Known remaining PRoot-state dependencies before final removal:

- some config reads still use the PRoot `.openclaw/openclaw.json` source;
- some credential checks still prefer the PRoot tree first;
- bootstrap/repair code still installs and repairs the PRoot runtime;
- PRoot rollback command still depends on the PRoot runtime being packaged;
- native bootstrap currently hydrates selected state from the PRoot tree.

## Required Gates Before Public Native-Default Rollback Build

1. Build variant audit:
   broad diagnostics off for public; rollback still available.
2. Fresh install smoke:
   native owns `18789`; PRoot absent; provider chat works.
3. Upgrade smoke:
   existing PRoot owner migrates once to native if not sticky rollback.
4. Sticky rollback smoke:
   rollback restores PRoot and survives relaunch.
5. Local direct smoke:
   `local-llm/...` responds without Gateway, PRoot, or cloud.
6. NDK bridge smoke:
   `plawie_ndk/local-llm` routes through native Gateway to `11435`.
7. Node host smoke:
   `AgentSkillServer` pairs and exposes device tools/capabilities.
8. Error smoke:
   provider/account errors show raw useful details.
9. Memory/process smoke:
   native owner means no live PRoot process; PRoot owner means no live native
   production process.

## Required Gates Before No-PRoot Internal Build

Package proof switch:

```powershell
.\gradlew :app:assembleRelease `
  -PplawieInternalNoProotProof=true
```

That proof APK excludes PRoot native libraries but does not change the public
native-default rollback build.

1. Native `.openclaw` home becomes canonical for config/auth/session reads.
2. PRoot hydration is replaced with native state migration.
3. PRoot repair/setup flows are removed or isolated behind a legacy branch.
4. Rollback becomes native repair/reset rather than PRoot restore.
5. Local direct LLM and NDK bridge pass with PRoot files absent.
6. Android node host pairing passes with PRoot files absent.
7. Release build starts, chats, changes model, changes provider key, and
   restarts without touching rootfs paths.

## Required Gates Before Public No-PRoot Build

1. Internal no-PRoot build soaks across repeated launches and network changes.
2. All user-facing PRoot fallback text is removed or changed to native repair.
3. Disk cleanup migration safely removes old PRoot rootfs without touching
   provider keys, skills, sessions, local models, avatars, or media.
4. Crash recovery path restarts native Gateway or offers native repair.
5. No stale `runInProot` call is reachable from normal runtime, model, key,
   Local LLM, node pairing, or chat flows.

## Release Message

First native-default build:

```text
Plawie now runs OpenClaw Gateway through embedded native Node libnode.so by
default. PRoot remains packaged only as an emergency rollback path.
```

No-PRoot build:

```text
Plawie now ships without PRoot. OpenClaw Gateway runs through embedded native
Node libnode.so, while on-device local models continue through fllama NDK.
```

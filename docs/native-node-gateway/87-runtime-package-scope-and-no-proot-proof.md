# Runtime Package Scope And Internal No-PRoot Proof

Date: 2026-06-02

Status: release polish for the native-default rollback package boundary.

## Decision

The native `libnode.so` Gateway does not require user-downloadable Linux
packages to run.

Required runtime pieces for native Gateway are bundled or app-owned:

- `libnode.so`;
- `libplawie_node_bridge.so`;
- `assets/openclaw-node-modules.tar.gz`;
- app-owned native OpenClaw home/config mirror;
- Android node host on `127.0.0.1:8765`;
- local fllama/NDK runtime for direct `local-llm/...` inference.

Go and Homebrew are PRoot rollback shell extras only. They are not native
Gateway prerequisites.

Twilio and Calls are partner skill surfaces. They require service credentials
and Gateway skill configuration, but they are not Linux runtime packages and
are not required for native `libnode.so` startup.

## UI Scope

Packages UI now separates:

| UI group | Meaning |
| --- | --- |
| PRoot rollback extras | Optional tools installed into the rollback Ubuntu rootfs |
| Partner skills | Skills managed from Bot Management > Skills, not native packages |

Settings now labels PRoot path/rootfs/Node/OpenClaw/Go/Homebrew as rollback
state, not native requirements.

Setup copy now makes clear that native Node is built into the app while setup
prepares OpenClaw state and the emergency PRoot rollback environment.

## Plugin Versus Tool Versus Package

Do not conflate these:

- Gateway startup plugins: loaded by OpenClaw at Gateway startup.
- Skills/tools catalog: OpenClaw and mobile tool schemas visible to the agent.
- Android node capabilities: concrete phone bridge commands allowed by the
  paired node host.
- Optional packages: PRoot rollback shell extras or partner skill entries.

Observed startup plugins do not include a separate Twilio or Calls startup
plugin. Twilio/Calls remain partner skills/integrations, not native runtime
dependencies.

## Internal No-PRoot Package Proof

The public native-default rollback APK still includes PRoot rollback.

For an internal proof package only, Gradle now supports:

```powershell
.\gradlew :app:assembleRelease `
  -PplawieInternalNoProotProof=true
```

That property excludes the PRoot native libraries from the APK:

- `libproot.so`;
- `libprootloader.so`;
- `libprootloader32.so`;
- `libproot_wrapper.sh`;
- `libtalloc.so`.

This does not change normal debug/release builds. It is only a packaging proof
that native Gateway startup can be tested without shipping PRoot native libs in
that internal artifact.

## Proof Rules

Internal no-PRoot proof must pass:

- install;
- native default health on `18789`;
- normal provider-backed chat;
- direct `local-llm/...` smoke;
- Android node host/device capability smoke;
- no live PRoot process and no packaged PRoot native libraries in the APK.

Expected limitation:

- `/native-default-owner-rollback` cannot restore PRoot in the no-PRoot proof
  artifact because the PRoot native libraries are intentionally absent.

For the current release train, keep the public artifact as:

```text
native default + PRoot emergency rollback
```

The no-PRoot proof is evidence for the later cleanup branch, not the current
public rollback release.

# Nodejs-Mobile Rebase Experiment

Last updated: 2026-05-29

Branch: `native-node-gateway-research`

## Decision Summary

The next embedded Node experiment should be a controlled `nodejs-mobile` rebase
attempt from its current Node `22.9.0` Android branch to a Plawie-compliant Node
`>=22.19.0` tag.

This is an experiment, not a runtime decision. It must not touch production
Gateway startup, PRoot, chat, tools, skills, dashboard, or model routing.

## Why This Path Is Worth Trying

The direct upstream Node `v22.22.3` Android executable build reached major
artifacts but failed in the V8 host/target split. The `nodejs-mobile`
`update22-9-0` branch already contains Android-specific build and embedding
work that directly addresses some of those host/target problems.

The tradeoff is that it produces embedded `libnode.so`, not a standalone Node
process. That means this path belongs to the embedded smoke lane, not the
existing executable-process smoke slot.

## Source Inputs

Use these as the factual base:

| Input | Value |
| --- | --- |
| mobile repo | `https://github.com/nodejs-mobile/nodejs-mobile.git` |
| known Android branch | `update22-9-0` |
| inspected mobile commit | `106c51f95d55d1010de56a2ffd09bfb4ba819a47` |
| known mobile Node version | `22.9.0` |
| target Node tag | Start with `v22.22.3`; fall back to `v22.19.0` only if needed |
| artifact shape | `out_android/<abi>/libnode.so` or equivalent |
| target ABI | `arm64-v8a` |
| smoke port | `127.0.0.1:18790` |

## Claims To Verify

External advice says the rebase may be small and that NDK r24 may be easier
than newer NDKs. Treat those as hypotheses, not facts.

Verify:

- whether `git rebase upstream/v22.22.3` is actually low-conflict;
- whether Android patches still apply cleanly;
- whether the trap-handler patch is still necessary and sufficient;
- whether `--with-intl=small-icu` or `--with-intl=full-icu` works;
- whether NDK r24, r26d, or r28c is the best build target;
- whether the resulting library reports Node `>=22.19.0`;
- whether the embedded library can start a tiny `/health` server on device.

## Recommended Experiment Order

Run this outside the production app build:

1. Clone `nodejs-mobile`.
2. Check out `update22-9-0`.
3. Create a local experiment branch.
4. Add upstream `nodejs/node`.
5. Rebase onto `v22.22.3`.
6. Resolve conflicts by preserving Android-specific configure/build patches.
7. Build only Android arm64.
8. Record NDK version, Node version, output path, and SHA-256.
9. Do not copy the artifact into the app until the provenance and smoke plan
   are documented.

If `v22.22.3` fails for reasons unrelated to Android patches, retry `v22.19.0`
because that is the minimum OpenClaw engine floor.

## NDK Strategy

Keep NDK testing explicit:

| NDK | Why test it | Expected risk |
| --- | --- | --- |
| r24 | Suggested by external research and older mobile build assumptions | May be too old for newer Node/V8 or app toolchain expectations |
| r26d | Known `nodejs-mobile` CI-era candidate and less aggressive than r28 | Best first serious candidate |
| r28c | Matches the existing app-side Android SDK install attempt | Already exposed direct upstream Node build issues |

Do not claim any NDK winner until a build result is recorded.

## Intl Policy

OpenClaw and model-provider code should not be forced into an Intl-less Node
runtime unless proven safe.

Target order:

1. `--with-intl=small-icu`
2. `--with-intl=full-icu`
3. `--with-intl=none` only for a temporary build-system smoke, never for a
   Gateway parity claim

## Integration Boundary

If the rebase produces `libnode.so`, the app integration must follow
[15-embedded-libnode-smoke-design.md](15-embedded-libnode-smoke-design.md):

```text
isolated Android service/process
  -> System.loadLibrary("node")
  -> app-owned JNI bridge
  -> node::Start(argc, argv)
  -> files/embedded-node-smoke/server.mjs
  -> http://127.0.0.1:18790/health
```

Do not place `libnode.so` into the executable packaging helper. It is the wrong
artifact type.

## What Success Means

A successful rebase build means:

- Plawie has a plausible embedded Node `>=22.19.0` artifact source.
- The next code task becomes a tiny app-owned JNI bridge and isolated smoke
  service.
- OpenClaw Gateway still does not boot in this lane until dependency and
  lifecycle gates pass.

## What Failure Means

A failed rebase is not a dead end. It tells us which patch surface is real:

- V8 host/target build split;
- Android NDK version mismatch;
- trap-handler or signal handling;
- Intl/ICU configuration;
- shared-library packaging;
- JNI start semantics.

The fallback remains:

```text
PRoot default
AVF for eligible full-fidelity devices
direct upstream/executable Node research
embedded libnode rebase research
```

## Non-Negotiables

- Do not import the generated library into git.
- Do not run this from normal Flutter/Gradle builds.
- Do not change `GatewayRuntimeRegistry.current`.
- Do not bind `18789`.
- Do not confuse a `libnode.so` result with a standalone Node executable.
- Do not route user chat through this lane until `/health`, crash isolation,
  restart, and Gateway parity gates pass.

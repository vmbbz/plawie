# Phased Migration Plan

Last updated: 2026-05-29

This plan is intentionally conservative. Each phase should leave the app
shippable with PRoot as the default runtime.

## Phase 0: Documentation And Branch Setup

Status: in progress

Goals:

- Create `native-node-gateway-research` branch.
- Define current Gateway contract and regression alarms.
- Document runtime options, risks, validation matrix, and source-backed facts.

Exit gate:

- Docs committed and pushed.
- No runtime code changes.

## Phase 1: Runtime Interface Extraction

Status: smoke passed with observation

Implemented in this phase so far:

- Added `GatewayRuntime`.
- Added production `ProotGatewayRuntime`.
- Routed `GatewayService` process lifecycle checks through the runtime:
  `start`, `stop`, `isRunning`, process log stream, and raw log retrieval.

Still intentionally not extracted:

- `runInProot(...)` OpenClaw CLI calls.
- PRoot bootstrap/install/repair workflows.
- Native bridge file-directory and rootfs helpers.
- Node service lifecycle.

Those stay untouched until the OpenClaw command/dependency inventory is done.

Goals:

- Introduce `GatewayRuntime` interface.
- Move current PRoot process operations behind `ProotGatewayRuntime`.
- Keep public `GatewayService` behavior identical.
- Add runtime diagnostics that identify which runtime is active.

Constraints:

- PRoot remains default.
- No native Node code.
- No changes to config schema or model/tool policy.
- Existing boot logs should remain semantically identical.

Exit gate:

- Fresh install and returning-user startup match `docs/OPENCLAW_BOOT_SEQUENCE.md`.
- Gateway starts, dashboard opens, operator WebSocket connects, node pairs, and
  chat/tool calls work exactly as before.

Smoke result:

- Debug APK installed on device `RZCX30KA9AW`.
- Runtime diagnostic reported `PRoot Gateway Runtime`.
- Gateway started, RPC discovery completed, and node pairing declared 42
  commands.
- A transient node reconnect timeout recovered on the next backoff cycle and
  paired again. Track this during Phase 2, but it is not a runtime abstraction
  blocker.

## Phase 2: Native Node Smoke Runtime

Status: isolated smoke endpoint passed

Implemented in this phase so far:

- Added `NativeNodeGatewayRuntime` as a hidden, non-production runtime object.
- Added Android `NativeGatewaySmokeServer` on `127.0.0.1:18790`.
- Added MethodChannel start/stop/is-running/log hooks.
- Added Dart self-test gated by
  `--dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true`.

Important scope note:

- This is not yet a bundled Node binary and does not run OpenClaw. It is a
  native Android lifecycle/HTTP/logging smoke endpoint that reserves the shape
  real native Node must satisfy.

Goals:

- Add hidden `NativeNodeGatewayRuntime` behind a developer flag.
- Start a minimal native Node process or embedded Node runtime.
- Serve a simple local health endpoint on a non-production port.
- Capture stdout/stderr/logcat diagnostics.

Constraints:

- Must not bind `18789`.
- Must not run OpenClaw yet.
- Must not change production Gateway state.

Exit gate:

- Native runtime can start, report health, stop, and restart without affecting
  PRoot Gateway.
- PRoot fallback still works after native runtime failure.

Smoke result:

- Diagnostics build started the smoke endpoint on port `18790`.
- `/health` returned `runtime=native-gateway-smoke`,
  `productionGatewayPort=18789`, `openclawStarted=false`, and
  `nodeStarted=false`.
- The self-test stopped, restarted, and stopped the smoke endpoint cleanly.
- The production PRoot Gateway then reached RPC discovery and node pairing.

## Phase 3: OpenClaw Bundle Feasibility

Status: inventory, binary gate, build scaffold, and mobile patch audit started

Implemented in this phase so far:

- Read-only inventory of the installed OpenClaw package from the debug device.
- Documented package size, Node version requirement, dependency counts, native
  addon risk, and host-tool assumptions.
- Defined a native Node packaging strategy that starts with a curated
  non-production bundle instead of the full PRoot `node_modules` tree.
- Added a native Node process slot that will execute a future Android arm64
  Node binary packaged as `libplawie_node.so`, run a JS health server on
  `127.0.0.1:18790`, capture stdout/stderr, and fail clearly while the binary
  is absent.
- Added a local-only packaging helper for candidate Node binaries. It records
  SHA-256, refuses unpinned candidates unless explicitly allowed, and keeps the
  binary ignored by git until provenance and licensing are reviewed.
- Added a Linux/WSL source-build helper pinned to Node `v22.22.3` and the
  official source tarball SHA-256, so the first Android arm64 candidate can be
  produced from verified source rather than an opaque binary.
- Audited the `nodejs-mobile` `update22-9-0` branch against upstream Node
  `v22.9.0`. It proves an embedded Android `libnode.so` runtime shape, but is
  below OpenClaw's `>=22.19.0` engine floor and is not interchangeable with the
  current executable-process smoke slot.

Goals:

- Package OpenClaw JavaScript assets for native runtime.
- Audit dependencies for native modules, shell calls, filesystem assumptions,
  dynamic downloads, and Linux-only behavior.
- Identify required replacements or shims.

Constraints:

- Native runtime may run OpenClaw only on an alternate port.
- No app UI should route user chat to native runtime.

Exit gate:

- Native OpenClaw can boot to HTTP health on an alternate port.
- Missing dependencies are documented with owner/mitigation.

Current blocker:

- The installed OpenClaw tree contains Linux/glibc native addons and code paths
  that spawn Linux host tools. A native Android runtime must either rebuild,
  replace, disable, or route around those surfaces before OpenClaw can be
  treated as portable.
- The repo does not yet contain a packaged Android-native Node executable.
- Official Node 22 distribution metadata does not provide an Android binary, so
  this phase requires a custom Bionic-native build or a trusted mobile fork at
  Node `>=22.19.0`.
- The `nodejs-mobile` path likely requires a separate embedded-runtime smoke
  runner, because its Android artifact is `libnode.so` loaded through JNI, not
  an executable process launched through `ProcessBuilder`.

## Phase 4: Shadow Gateway Parity

Goals:

- Run native OpenClaw in shadow mode.
- Compare health, config load, dashboard token creation, RPC discovery, skills
  status, and logs against PRoot.

Constraints:

- Shadow runtime does not accept user chat by default.
- Node pairing remains with PRoot.
- PRoot remains the only production Gateway.

Exit gate:

- Shadow native runtime passes repeated boot/stop/restart cycles.
- No cross-talk with PRoot port, config, sessions, or node pairing.

## Phase 5: Hidden Canary Runtime

Goals:

- Allow developer-only runtime selection.
- Let native runtime bind production port only when PRoot is stopped.
- Run full Gateway startup sequence through `GatewayService`.

Constraints:

- Runtime switch requires explicit developer action.
- PRoot fallback must be one tap/action away.
- Runtime selection must not rewrite provider/model/tool config.

Exit gate:

- Cloud chat streams.
- Dashboard opens.
- Operator WebSocket works.
- Android node pairs with full command snapshot.
- Camera, avatar gesture, haptic, screen/canvas, and TTS tests pass.

## Phase 6: User-Facing Beta

Goals:

- Offer native runtime as an experimental setting.
- Keep PRoot as default and fallback.
- Collect structured diagnostics and performance data.

Exit gate:

- Native runtime shows materially better startup/latency/resource behavior.
- Failure rate is lower than or comparable to PRoot.
- No known data loss, config corruption, or pairing regression remains.

## Phase 7: Default Candidate

Goals:

- Make native runtime default only for devices/ABIs that pass eligibility checks.
- Keep PRoot installation path as compatibility fallback.

Exit gate:

- Multiple device classes pass validation.
- Upgrade/rollback path is tested.
- Release notes clearly explain runtime selection and fallback behavior.

## Always-On Rollback Rule

At every phase:

```text
If native runtime fails, stop native runtime, restore PRoot runtime selection,
attach/start PRoot Gateway, and continue with existing Gateway sequence.
```

# Native Node Gateway Research Track

Last updated: 2026-05-31

Branch: `native-node-gateway-research`

## Purpose

This track researches and stages a possible replacement for the current PRoot
Gateway runtime with a native Android Node.js runtime. The work is deliberately
separate from the production Gateway sequence.

The production rule is unchanged:

> Gateway stability comes first. Native Node work must not disturb the current
> PRoot startup, config hardening, pairing, dashboard, chat, tools, skills, or
> node-capability flow until every gate in this track is passed.

## Current Direction

The preferred long-term direction is a Bionic-native Node runtime behind a
`GatewayRuntime` abstraction, not a glibc compatibility layer and not an
immediate PRoot replacement.

The migration should keep this contract stable:

```text
Flutter UI
  -> GatewayService
  -> GatewayRuntime implementation
  -> OpenClaw Gateway on 127.0.0.1:18789
  -> operator WebSocket / RPC / node / tools / skills
```

`ProotGatewayRuntime` remains the production implementation until
`NativeNodeGatewayRuntime` passes the validation matrix.

## Current Branch Status

Phase 3 inventory proved that the installed Gateway tree includes Linux/glibc
native addons and host-tool assumptions. Native migration therefore remains a
curated-runtime effort, not a blind reuse of the PRoot `node_modules` tree.

The executable-style native Node process slot has been superseded for the
current branch by an embedded `libnode.so` diagnostic lane. The app can now
package a locally built Android arm64 Node `22.22.3` `libnode.so`, build a tiny
`libplawie_node_bridge.so` JNI wrapper, and start a `/health` server on
`127.0.0.1:18790` inside an isolated `:native_node_smoke` Android process.
That lane now also runs a mobile OpenClaw preflight, Gateway bootstrap probe,
read-only production skill inventory, HTTP request-shape parity, WebSocket
`chat.send` frame-shape parity, and diagnostics-only Dart shadow parity: it
copies curated OpenClaw assets, loads Android bridge tooling, counts bundled
canary skills, scans the real PRoot `~/.openclaw/skills` tree, parses realistic
OpenAI/OpenClaw chat request envelopes, recognizes Plawie's production
`chat.send` frame fields, compares redacted Dart sender metadata with embedded
Node parser metadata, keeps a diagnostics-only native dry-run session/queue
model for mirrored real turns, accepts a hidden direct native canary dry-run
copy of real turns, accepts an explicit UI-driven native primary canary dry-run
turn, can stream a synthetic native-owned dry-run response back to the chat UI,
can build a diagnostics-only native routing skeleton with route-plan,
cancellation, provider-gate, tool-gate, and error-frame events,
can build a diagnostics-only provider/model adapter envelope with outbound
network disabled,
can normalize a diagnostics-only provider request builder contract with
transport invocation disabled,
can construct a diagnostics-only provider transport shim that aborts locally
before DNS/TLS/socket/provider billing,
can run an explicit `/native-live` OpenRouter live-provider canary with a tiny
max-token request from embedded Node,
can run an explicit `/native-stream-parity` canary that checks native provider
chunk parsing, raw provider errors, timeout normalization, cancellation
contracts, and one tiny live provider stream,
can run an explicit `/native-tool-plan` canary that attaches native-safe mobile
tool schemas and captures streamed provider tool-call plans with tool execution
disabled,
can run an explicit `/native-tool-dispatch` canary that maps a captured native
tool plan to synthetic `tool_use` and `tool_result` frames while keeping real
execution disabled,
can run an explicit `/native-dart-bridge` canary that sends a native synthetic
dispatch request across the Dart loopback bridge and receives a dry-run ACK
without executing the capability,
can run an explicit `/native-dart-bridge-order` canary that sends ordered
native bridge dry-runs and records a cancellation-shaped dry-run ACK without
executing the capability,
can run an explicit `/native-dart-bridge-haptic` canary that executes one
bounded allowlisted `haptic.vibrate` call through native Node -> Dart while
keeping provider calls and general tool routing disabled,
can run an explicit `/native-dart-bridge-readonly` canary that executes
allowlisted `flash.status` and `sensor.list` read-only bridge calls in order
while keeping provider calls and general tool routing disabled,
can run an explicit `/native-dart-bridge-avatar` canary that executes one
protected allowlisted `avatar.gesture` call and suppresses auto gesture
interjections during the visible canary window,
can run an explicit `/native-runtime-select` canary that verifies PRoot remains
the active production runtime while embedded native Node is selectable only as
an isolated side-by-side canary on `18790`,
can run an explicit `/native-port-bind-canary` that stops PRoot, lets embedded
native Node bind the real production port `18789` with routing/providers/tools
still disabled, then stops native and rolls back to PRoot,
can run an explicit `/native-port-bind-soak` that repeats the guarded `18789`
handoff and rollback cycle with bounded diagnostics,
can run an explicit `/native-runtime-owner` canary that lets embedded native
Node own `18789` for a bounded guarded diagnostics window before automatically
rolling back to PRoot,
can run an explicit `/native-route-owner` dry-run that lets embedded native
Node own `18789`, accept a production-shaped `chat.send`, build a route plan,
block provider/tool execution, and roll back to PRoot,
can run an explicit `/native-provider-owner` dry-run that lets embedded native
Node own `18789`, build a redacted provider envelope with outbound network
disabled, prove raw provider error forwarding contract, and roll back to PRoot,
can run an explicit `/native-builder-owner` dry-run that lets embedded native
Node own `18789`, normalize provider headers/body/request hashes, prove
transport invocation remains disabled, and roll back to PRoot,
verifies Node built-ins and Intl, exposes harmless
Gateway-shaped probe endpoints on `127.0.0.1:18790`, and reports readiness
without starting OpenClaw. Production Gateway startup still remains PRoot.

The first direct Node 22 Android build attempt proved the official source path
can configure and produce major artifacts. The follow-up offline build produced
a real Android arm64 `libnode.so` from Node `22.22.3`. The broad
`nodejs-mobile` rebase remains non-viable as a blanket strategy, but the
embedded-runtime lane is now proven at the packaging and debug-build level.

An AVF/Debian VM lane is now tracked as a third option. It is the most
promising full-fidelity OpenClaw path on eligible Android devices, but it is
not universal and must be gated separately from PRoot and embedded Node.

AndyClaw has also been audited as a reference architecture. It does not provide
a Node `>=22.19.0` Gateway runtime, but it is valuable for Android-side skills,
Termux sidecar execution, Gateway WebSocket client behavior, extension
discovery, and virtual-display agent controls.

PRoot command execution and bootstrap/repair are still direct native bridge
calls by design, because those need a dependency/CLI inventory before they can
be safely generalized.

## Documents

| Document | Role |
| --- | --- |
| [01-current-contract.md](01-current-contract.md) | Non-negotiable production Gateway invariants |
| [02-runtime-options.md](02-runtime-options.md) | PRoot, native Node, glibc, and embedded Node tradeoffs |
| [03-phased-migration-plan.md](03-phased-migration-plan.md) | Phase plan, gates, rollback rules, and work order |
| [04-risk-register.md](04-risk-register.md) | Risks, severity, mitigations, and exit gates |
| [05-validation-matrix.md](05-validation-matrix.md) | Required parity tests before promoting native runtime |
| [06-research-log.md](06-research-log.md) | Source-backed research notes and open questions |
| [07-phase-1-smoke-test.md](07-phase-1-smoke-test.md) | Debug APK smoke result for the runtime abstraction |
| [08-phase-2-native-smoke.md](08-phase-2-native-smoke.md) | Isolated native smoke endpoint and test result |
| [09-openclaw-bundle-inventory.md](09-openclaw-bundle-inventory.md) | Read-only inventory of the installed OpenClaw package |
| [10-native-node-packaging-plan.md](10-native-node-packaging-plan.md) | Native Node packaging strategy and gates |
| [11-native-node-binary-gate.md](11-native-node-binary-gate.md) | Node binary sourcing, packaging, and diagnostic gate |
| [12-node-android-build-recipe.md](12-node-android-build-recipe.md) | Verified source-build recipe for the first Node Android candidate |
| [13-node-22-android-build-attempt.md](13-node-22-android-build-attempt.md) | Local Node 22 Android build result and current blocker |
| [14-nodejs-mobile-22-patch-audit.md](14-nodejs-mobile-22-patch-audit.md) | Nodejs-mobile Node 22 Android patch audit and embedded-runtime decision |
| [15-embedded-libnode-smoke-design.md](15-embedded-libnode-smoke-design.md) | Separate embedded `libnode.so` smoke runner design |
| [16-avf-linux-vm-runtime-option.md](16-avf-linux-vm-runtime-option.md) | AVF/Debian VM lane, eligibility, and integration plan |
| [17-andyclaw-reference-audit.md](17-andyclaw-reference-audit.md) | AndyClaw skills, Termux, extension, and Android control reference audit |
| [18-nodejs-mobile-rebase-experiment.md](18-nodejs-mobile-rebase-experiment.md) | Controlled Node `>=22.19.0` embedded `libnode.so` rebase experiment |
| [19-embedded-libnode-22-integration.md](19-embedded-libnode-22-integration.md) | Node `22.22.3` `libnode.so` packaging, JNI bridge, isolated service, and build result |
| [20-embedded-openclaw-preflight.md](20-embedded-openclaw-preflight.md) | Embedded Node mobile OpenClaw preflight contract and device result |
| [21-embedded-gateway-bootstrap-probe.md](21-embedded-gateway-bootstrap-probe.md) | Canary Gateway-shaped HTTP endpoints on embedded Node without chat routing |
| [22-embedded-skill-registry-inventory.md](22-embedded-skill-registry-inventory.md) | Read-only scan of the production PRoot skill registry from embedded Node |
| [23-embedded-request-shape-parity.md](23-embedded-request-shape-parity.md) | Probe-only parsing of OpenAI/OpenClaw chat request envelopes without execution |
| [24-embedded-ws-chat-frame-parity.md](24-embedded-ws-chat-frame-parity.md) | Probe-only parsing of Plawie's production WebSocket `chat.send` frame shape |
| [25-dart-shadow-parity-collector.md](25-dart-shadow-parity-collector.md) | Diagnostics-only redacted comparison between PRoot sender metadata and native parser output |
| [26-native-dry-run-session-queue.md](26-native-dry-run-session-queue.md) | Diagnostics-only native session and queue ACKs for mirrored real `chat.send` frames |
| [27-direct-canary-dry-run.md](27-direct-canary-dry-run.md) | Hidden direct native canary dry-run for real `chat.send` frames while PRoot remains primary |
| [28-native-primary-canary.md](28-native-primary-canary.md) | Explicit `/native-canary` UI turns sent directly to embedded Node with routing disabled |
| [29-native-stream-canary.md](29-native-stream-canary.md) | Explicit `/native-stream` UI turns consuming a native-owned synthetic response stream |
| [30-native-routing-skeleton.md](30-native-routing-skeleton.md) | Explicit `/native-route` UI turns exercising native route lifecycle gates without execution |
| [31-native-provider-shell.md](31-native-provider-shell.md) | Explicit `/native-provider` UI turns building a redacted provider envelope without network |
| [32-native-provider-request-builder.md](32-native-provider-request-builder.md) | Explicit `/native-provider-build` UI turns normalizing a redacted provider request without transport |
| [33-native-transport-shim.md](33-native-transport-shim.md) | Explicit `/native-transport` UI turns constructing provider transport and aborting before network |
| [34-native-provider-live-canary.md](34-native-provider-live-canary.md) | Explicit `/native-live` UI turns making one tiny OpenRouter provider call from embedded Node |
| [35-native-provider-stream-parser-parity.md](35-native-provider-stream-parser-parity.md) | Explicit `/native-stream-parity` UI turns validating provider chunk/error/timeout/cancel parsing |
| [36-native-provider-tool-plan-canary.md](36-native-provider-tool-plan-canary.md) | Explicit `/native-tool-plan` UI turns capturing provider tool-call plans without execution |
| [37-native-tool-dispatch-dry-run.md](37-native-tool-dispatch-dry-run.md) | Explicit `/native-tool-dispatch` UI turns emitting synthetic tool-use/result frames without execution |
| [38-native-dart-bridge-dry-run.md](38-native-dart-bridge-dry-run.md) | Explicit `/native-dart-bridge` UI turns proving native-to-Dart dispatch ACKs without execution |
| [39-native-dart-bridge-ordering-cancel.md](39-native-dart-bridge-ordering-cancel.md) | Explicit `/native-dart-bridge-order` UI turns proving bridge ordering and cancellation dry-run parity |
| [40-native-dart-bridge-haptic-canary.md](40-native-dart-bridge-haptic-canary.md) | Explicit `/native-dart-bridge-haptic` UI turns executing one bounded haptic bridge canary |
| [41-native-dart-bridge-readonly-canary.md](41-native-dart-bridge-readonly-canary.md) | Explicit `/native-dart-bridge-readonly` UI turns executing ordered read-only bridge canaries |
| [42-native-dart-bridge-avatar-canary.md](42-native-dart-bridge-avatar-canary.md) | Explicit `/native-dart-bridge-avatar` UI turns executing one protected visible avatar gesture canary |
| [43-native-runtime-selection-canary.md](43-native-runtime-selection-canary.md) | Explicit `/native-runtime-select` UI turns proving side-by-side runtime selection guards |
| [44-native-production-port-bind-canary.md](44-native-production-port-bind-canary.md) | Explicit `/native-port-bind-canary` UI turns proving native can bind `18789` only after PRoot stop and rollback |
| [45-native-production-port-bind-soak.md](45-native-production-port-bind-soak.md) | Explicit `/native-port-bind-soak` diagnostics proving repeatable guarded `18789` handoff and rollback |
| [46-native-runtime-owner-canary.md](46-native-runtime-owner-canary.md) | Explicit `/native-runtime-owner` diagnostics proving bounded native ownership of `18789` with automatic PRoot rollback |
| [47-native-route-owner-dry-run.md](47-native-route-owner-dry-run.md) | Explicit `/native-route-owner` diagnostics proving native accepts route dry-runs on `18789` and rolls back to PRoot |
| [48-native-provider-owner-envelope.md](48-native-provider-owner-envelope.md) | Explicit `/native-provider-owner` diagnostics proving native builds provider envelopes on `18789` while outbound network remains disabled |
| [49-native-provider-owner-builder.md](49-native-provider-owner-builder.md) | Explicit `/native-builder-owner` diagnostics proving native normalizes provider requests on `18789` before transport invocation |

## Work Rules

- Keep PRoot as the default and fallback during research.
- Do not change `GatewayService.start()` behavior until a runtime interface is
  introduced and PRoot parity is proven.
- Do not change port `18789`, auth token semantics, dashboard URL behavior, or
  operator WebSocket handshake.
- Do not change model routing, tool policy, node pairing, or skills
  registration as part of native runtime plumbing.
- Every phase must be reversible by switching runtime preference back to PRoot.
- Native runtime failures must surface as diagnostics, not as silent fallback
  corruption or Gateway config churn.

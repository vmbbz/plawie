# Native Node Gateway Research Track

Last updated: 2026-05-30

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

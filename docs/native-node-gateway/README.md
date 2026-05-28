# Native Node Gateway Research Track

Last updated: 2026-05-28

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

Phase 1 has a passing debug smoke test for the extracted process lifecycle
path. The first code extraction covers Gateway process lifecycle and logs only.
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

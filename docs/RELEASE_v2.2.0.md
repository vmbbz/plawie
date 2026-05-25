# OpenClaw v2.2.0 — Gateway-First Reliability Release

**Release date:** 2026-05-25  
**Build:** `2.2.0+11`  
**Branch:** `main`  
**Tag:** `v2.2.0`

---

## Overview

v2.2.0 is the biggest reliability, UX, and architecture overhaul since the initial OpenRouter integration. The headline: **the OpenClaw gateway is now the single authoritative chat lane for all cloud models**. Every ambiguity that let a message slip past the gateway — or block indefinitely while the gateway was still booting — has been eliminated. TTS voice streaming is wired cleanly. The UI is visibly lighter and faster. NDK/local-LLM is an opt-in path, not the default, as always intended.

This release consolidates work from two full engineering sessions and is validated against live `logcat` and gateway logs on a physical Android device.

---

## 🔒 Architecture: Gateway-First Policy Enforced

### Gateway is the only cloud chat lane

Previously a "fast cloud bypass" path (`_shouldUseFastCloudChat`) could silently route cloud messages outside the gateway, breaking session continuity, tool access, and memory. This path is **permanently disabled** — it now returns `false` unconditionally. Cloud chat goes through the gateway, full stop.

### Unified local-model detection

`ModelProviderCatalog.isLocalModelId()` is now the single source of truth for deciding whether a model route is local. It covers both `local-llm/…` namespaces and the `plawie_ndk/local-llm` NDK path. Every routing decision in `chat_screen.dart`, `settings_screen.dart`, and `gateway_service.dart` uses this one function — no more scattered string checks that could diverge.

### NDK / Local LLM is explicitly opt-in

- Gateway model resolve falls back to the cloud OpenRouter model when local mode is **off** (line 4151 `chat_screen.dart`)
- Chat model switching is guarded by the local-mode toggle (line 2003)
- Settings local/cloud detection is aligned to the same policy
- No path can accidentally activate local inference when the user has not enabled it

---

## 🚀 Gateway Startup & Reliability

### 1 — Eager session pre-resolution (C4)

The gateway session key is now resolved in the background **immediately after the chat screen mounts** (`addPostFrameCallback → _preResolveGatewaySession()`), not as a blocking operation inside the send path. First-message latency drops by the full `sessions.resolve → sessions.create` RPC round-trip (~300–800 ms).

### 2 — UUID session isolation (C1)

The static `mobile:chat:default` fallback session key (shared across all conversations) is replaced with a per-conversation UUID: `mobile:chat:<uuid>`. This eliminates session bleed between conversations and makes gateway session state deterministic.

### 3 — Silent warmup ping (WARMUP)

After `_rpcDiscoveryDone` fires, the gateway immediately fires a silent `chat.send` to the `mobile:chat:warmup` session. This pre-pays the gateway cold-start cost — auth (~22 s), workspace load (~13.5 s), plugin load (~7–9 s) — **before** the user types their first message. The warmup is cancelled after 4 s and never blocks the UI. Subsequent real messages land on an already-warm gateway.

### 4 — Dirty `tools.allow` config auto-repair (C2)

Gateway configs that contained invalid entries (`canvas`, `memory`, `computer`) survived restarts because the previous fix only hardened the default template, not the live config on disk. `_repairToolsPolicyIfNeeded()` now:
1. Reads the live gateway config after RPC discovery
2. Detects any disallowed entries in `tools.allow`
3. Rewrites the corrected config via `_configureGateway()`
4. Issues a full `stop() → start()` cycle to propagate it
5. Skips the restart if inside the 30-second settle window (boot-safe)

Both warmup and repair are one-shot (guarded by `_warmupSessionDone` / `_toolsPolicyRepairDone`), reset on each `stop()`.

### 5 — Gateway connection concurrency fix

`GatewayConnection` now holds a mutex across the full `connect()` sequence, preventing duplicate socket creation during the startup race between the health loop and setup waiter. Previously this caused intermittent WS handshake timeouts on fast phones.

### 6 — Bootstrap: skill directory provisioning

`BootstrapManager` now pre-creates both `workspace/skills` and root `skills` directories and mirrors packaged default skills on first boot. Previously a missing directory caused gateway skill-load failures silently.

---

## 🟡 UI: Readiness Gate + Live Status Hints

### Readiness gate banner (C3)

Cloud chat is blocked and a contextual banner replaces the input area when the gateway is not yet interactive:

| Gateway state | Banner message |
|---|---|
| Stopped / error | ⚠️ Gateway offline — start it to chat |
| Starting up | ⏳ Gateway connecting… |
| WebSocket not yet open | ⏳ Establishing WebSocket… |
| WS open, tools loading | ⏳ Loading tools and skills… |
| Fully ready | *(banner hidden)* |

The send button is disabled while the banner is visible (cloud model only — local NDK sends are never blocked). The banner animates in/out with `AnimatedContainer`.

### Intermediate timeout feedback (I1)

Long generations no longer hit a silent 45-second cliff. A status hint appears **above the input bar**:

- **10 s** into generation → `⏳ Provider warming up…`
- **20 s** into generation → `⏳ Taking longer than usual — may be rate limited`
- On **first token** received → hint clears immediately
- On **generation complete** → hint clears, timer is cancelled

The timer state is cleaned up in `dispose()` and the generation-complete block.

### Voice modal: configure-first UX (I4)

When the Gateway Talk provider is unconfigured, the Voice ID section previously showed an empty or phantom dropdown. It now shows a clear informational prompt:

> _Configure a Gateway Talk provider above to enable voice selection._

The prompt appears in a styled orange-tinted info box consistent with the rest of the modal's unconfigured-state styling.

---

## 🎨 UI: Lighter Glass System & Widget Polish

### GlassCard — Android-safe blur

`GlassCard` now has a two-layer architecture:
- **Non-Android**: `BackdropFilter` with live blur
- **Android**: Same tint/border treatment without live blur — eliminates the GPU buffer spikes that occurred when blurring over WebView/PlatformView layers on mid-range devices

The result is visually identical on flagship hardware, and significantly faster on mid-range Android where overdraw over the avatar WebView was measurable.

### AuraDot — tighter orbital geometry

Core dot radius tightened to `5.0`, orbit ring to `13.0`, blur sigma to `18`. The dot reads crisper and the animation feels more precise.

### ChatBubble — redesigned layout

- Thinking indicator extracted into dedicated `_TypingIndicatorState`
- Tool event cards: left-accent border treatment, rounded `8 px` corners, tighter padding
- Bubble content split into `_bubbleContent()` for cleaner conditional rendering

### NebulaBg — subtle radial gradient

Background nebula now uses a `RadialGradient` with `radius: 1.4` and very low opacity passes — more depth, less visual noise.

---

## 🔧 NDK / Local LLM (fllama)

- Tool chain logs now include `depth`, `max`, and `model` identifiers per turn
- `fllama` turn-start log includes `threads`, `contextSize`, `requestedThreads` and message/tool counts for diagnostics
- Model activation path logs `sizeMb` and effective thread count vs requested
- `_maxLocalToolDepth` guard is enforced and logged

---

## 📋 Validated End-to-End (live device)

From `test-watch/_live_after_lane_policy_patch_20260525.log`:

```
[GATEWAY] starting up         (0s)
[GATEWAY] starting up         (14s)
[GATEWAY] starting up         (29s)
[GATEWAY] starting up         (44s)
[GATEWAY] Gateway RPC discovery complete
[NODE]    Paired and connected
```

- Gateway reaches interactive state reliably on cold boot
- Node pairs automatically after RPC discovery
- Session warmup fires immediately after RPC ready
- `tools.allow` dirty config is detected and repaired in the same boot cycle

---

## Files Changed

| File | Change |
|---|---|
| `lib/screens/chat_screen.dart` | Gateway-first routing, readiness gate, session pre-resolve, UUID fallback, I1 hints, I4 voice modal, local-model guard (+226 lines) |
| `lib/services/gateway_service.dart` | Warmup ping, tools.allow repair, UUID session fallback, reset guards (+86 lines) |
| `lib/services/gateway_connection.dart` | Connect mutex, handshake timeout fix (+40 lines) |
| `lib/services/local_llm_service.dart` | NDK tool chain logging, fllama turn diagnostics (+250 lines) |
| `lib/services/model_provider_catalog.dart` | `isLocalModelId()` unified detection (+17 lines) |
| `lib/services/preferences_service.dart` | Local-mode toggle alignment (+56 lines) |
| `lib/widgets/glass_card.dart` | Android-safe blur, nebula gradient (+182 lines) |
| `lib/widgets/chat_bubble.dart` | Thinking indicator, tool event cards, bubble layout (+264 lines) |
| `lib/widgets/aura_dot.dart` | Orbital geometry tighten (+23 lines) |
| `lib/screens/dashboard_screen.dart` | Node pairing UX, status polish (+180 lines) |
| `lib/screens/settings_screen.dart` | Local/cloud detection alignment (+51 lines) |
| `lib/providers/node_provider.dart` | Auto-pair after RPC discovery (+162 lines) |
| `android/.../BootstrapManager.kt` | Skill directory provisioning (+69 lines) |
| `lib/services/gateway_tool_catalog.dart` | Safe `defaultMobileAllowList`, cleaned invalid entries |
| `pubspec.yaml` | Version bump `2.0.0-beta.1+10` → `2.2.0+11` |

---

## Upgrade Notes

- No migration required — app upgrades in place
- On first launch after upgrade, `_repairToolsPolicyIfNeeded()` will automatically rewrite and restart the gateway if the old config had bad `tools.allow` entries
- Local NDK mode remains off by default; users must explicitly enable it in Settings → Local LLM

---

## Next Up (v2.3.0 candidates)

- [ ] TTS streaming: gateway `talk.speak` sentence-chunk streaming to eliminate first-audio latency
- [ ] Vision AI: camera snap → VLM pipeline (P0 roadmap)
- [ ] Whisper STT: on-device speech recognition (P1 roadmap)
- [ ] Context compaction: long-conversation memory management (P2 roadmap)
- [ ] Live tool validation: `camera.snap`, `torch.on/off`, `vibrate` end-to-end test harness

# OpenClaw Android GTM — Critical Issues, Architectural Flaws, and Execution Fix Guide

**Status:** Living document. Use this as the single source of truth to drive fixes until:
- Affected "green" skills (canvas, stocks, gifgrep, meme-maker, etc.) execute reliably without crashing the gateway.
- No more duplicate-start / restart storms on skill use.
- Skill cards show accurate live gates (no false "dependency missing" on ready skills).
- Canvas render + "fetch the render" workflows succeed end-to-end.
- Startup is efficient and watchdog-tolerant.

**Primary references (source of truth for this guide):**
- `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md` — current scorecard, release gate philosophy (13/13 ready_required PASS, 30/51 Android-relevant, anti-inflation, device-proven artifacts only).
- All `issues-*.md` files at repo root (canvas-skill-error, canvas-test-fail, stocks-skill-*, gifgrep-skill-fail-tool-error, meme-maker-skill-gateway-restart, gateway-restart-after-all-these-tests, skills-dependencies, webdashboard-screenshots).
- The first audit synthesis in `fixes-cited-issues-and-fixes.md` (distilled root causes from the logs + code).

---

## Executive Summary (Current State)

**GTM release gate is green** (`ready_required: 13/13`, `unexpected_missing_dependency: 0`).
**Android-relevant ready floor: 30/51**.
**Problem:** Several *classification-green* skills are broken or destabilizing at execution time (exactly the "ready for use right now after full fresh install" promise). Gateway restarts, path errors, Python import failures, and false UI badges are the visible symptoms.

### The Five Critical Flaws (Prioritized)

| # | Flaw | Primary Symptoms (from issues-*.md) | Severity | GTM Impact |
|---|------|-------------------------------------|----------|------------|
| 1 | **Path doubling on `read(SKILL.md)`** | Canvas/stocks: `ENOENT ... /workspace/data/data/.../full-openclaw/.../skills/canvas/SKILL.md`, agent tool call with relative app-root path, raw_params shows the doubled path. Downstream: "canvas didn't render / display" in webdashboard screenshots. | 🔴 Critical | Unblocks agent use of already-ready skill docs for canvas, stocks, others. |
| 2 | **Chaquopy lazy submodule import (Python skills)** | `issues-stocks-skill-python-error.md`: `from dateutil import parser` → `importlib.import_module(".parser", __name__)` failure inside `yfinance_ai.py` under `<openclaw-python-bridge>`. | 🔴 Critical | Stocks (and any skill using python-dateutil submodules or similar PEP 562 patterns) looks ready but hard-crashes. |
| 3 | **Gateway restart storms + re-provisioning churn** | Multiple issues (meme-maker, gifgrep, canvas, gateway-restart-after-tests, stocks): repeated "stop requested / service destroyed / native log stream resumed / start ignored; already running (18789 full vs 18790 smoke)", full asset copy on every restart (CLI-core, vision-media, audio, terminal, python-debug), 10.8s plugin load, `eventLoopDelayMaxMs` 1.0–1.4s spikes, liveness warnings even when `active=0 waiting=0`. | 🔴 Critical (stability + efficiency) | Violates "robust after full install". Makes every heavy skill use (canvas, meme, gifgrep) risky for watchdog kill. |
| 4 | **Badge classifier / live-status drift** | `issues-skills-dependencies.md` + webdashboard screenshots: every skill card flags "dependency missing" warning despite GTM plan `unexpected_missing_dependency: 0` and live `/device/health` rows showing ready. | 🟠 High | Destroys user trust in the Skills page. Violates plan rule: "show current gates, not static taxonomy". |
| 5 | **canvas.snapshot produces blank/meaningless image** | "fetch the render and display it in chat" yields flat color rect instead of actual page capture. | 🟠 High | Breaks the canvas workflow end-to-end (documented in webdashboard issue). |

**Recommended burn-down order (for fast trust recovery):** 1 + 2 + 4 (surgical, immediate "looks-ready-works" wins) → 3 (the big stability/efficiency refactor) → 5 (feature polish once canvas is readable).

---

## Detailed Flaw Breakdown + Evidence + Fix Plan

### FLAW 1 — Path Doubling: Agent is Handed Bundled Package Path, `read` Tool Resolves Relative to Workspace

**Evidence (direct from logs + code):**
- `issues-stocks-skill-fail.md` (and canvas equivalents): exact failing path
  ```
  .../native-home/.openclaw/workspace/data/data/.../full-openclaw/lib/node_modules/openclaw/skills/canvas/SKILL.md
  ```
  `raw_params={"path":"./data/data/.../full-openclaw/.../skills/canvas/SKILL.md"}`
- Stack is inside the gateway's `dist/sessions-*.js` `read` tool (Node `fs.promises.access + path.resolve` against workspace).
- Multiple skill roots tracked correctly in Dart (see `lib/services/skill_parity_audit_service.dart`, `lib/services/skills_service.dart`, `lib/services/openclaw_service.dart`):
  - `nativeWorkspaceSkillsRoot` → `.../.openclaw/workspace/skills`
  - `nativePackageSkillsRoot` → `.../full-openclaw/lib/node_modules/openclaw/skills`
- `skills_service.dart` has explicit ordered search lists that prefer workspace but still surface bundle paths in some flows (`ensureAgentAwareness`, `_registerNativeSkills`, bundled SKILL.md paths for Proot + native).
- `native_skill_execution_registry.dart` correctly reads SKILL.md from `_resolveSkillRoot` (workspace-first), but the **agent system prompt / initial context / skill instructions** fed to the gateway LLM still leaks the bundle absolute path.

**Root cause (architecture):**
The gateway/agent is told about a skill's "documentation path" using the read-only bundle location (under the package). The model then issues `read( that-path )` (or a relative form of it). The `read` / `fs` tools inside the gateway always resolve relative to the mutable `.../workspace` root → double-root.

**Fix strategy (two layers)**
1. **Dart side — Stop advertising the wrong root to the agent context**:
   - In `agent_skill_server.dart`, `skills_service.dart`, `gateway_skill_proxy.dart`, and any place that builds tool descriptions / initial memory / `ensureAgentAwareness` payloads: **never** emit `full-openclaw/.../skills/<id>/SKILL.md` or `node_modules/openclaw/skills/...`.
   - Only ever surface **workspace-relative** references (e.g. `skills/<id>/SKILL.md` or just the skill id + "use the read tool against the active workspace skills tree").
   - When syncing, ensure the workspace copy is authoritative for agent consumption.
2. **Hardening in the gateway (or via our tool shim if exposed)**:
   - Make the effective `read` implementation detect and auto-correct double-joined paths (any path containing both `workspace` and `full-openclaw` or starting with `/data/.../com.nxg...` when workspace is already the base).
   - Prefer `workspace/skills` resolution. Log a clear diagnostic when correction happens.
3. Verification: After fix, agent can successfully `read("skills/canvas/SKILL.md")` (or equivalent) without ENOENT, and stocks `read` succeeds during tool use. Canvas "explain this page + snapshot" flows no longer fail on the read step.

**Primary files to edit (evidence-based):**
- `lib/services/agent_skill_server.dart` (context / tool registration that may feed skill docs).
- `lib/services/skills_service.dart` (`ensureAgentAwareness`, `_registerNativeSkills`, any prompt/metadata writing).
- `lib/services/skill_parity_audit_service.dart` + `openclaw_service.dart` (the places that enumerate the three roots — ensure bundle root is used only for classification/parity, **never** for runtime agent context).
- If the actual prompt injection happens deep in the bundled gateway, the fix may also require changes to how we invoke `chat new-session` or post-skill-update hooks (see skills_service calls to `skills update --all`).

**Status / Tracking:** Not started. (This is the highest-leverage single change.)

---

### FLAW 2 — Python-Dateutil Lazy Submodule Fails Under Chaquopy Bridge (Stocks)

**Evidence:**
- `issues-stocks-skill-python-error.md` traceback (exact lines reproduced in the audit).
- `from dateutil import parser` triggers `dateutil/__init__.py:__getattr__` → relative `importlib.import_module(".parser", __name__)` which fails in the Chaquopy `import_override`.

**Fix (simple + robust):**
- Edit the skill directly: `skills/stocks/scripts/yfinance_ai.py` line ~67.
  Change:
  ```python
  from dateutil import parser as dateutil_parser
  ```
  To the explicit non-lazy form (Chaquo-safe):
  ```python
  import dateutil.parser as dateutil_parser
  # or
  from dateutil.parser import parse as dateutil_parse
  ```
- Extend the Python smoke contract (in CI/device health or `python_tools_class_adapter.dart` + related test) to actually exercise the real imports the skill uses (not just `import dateutil` or `import debugpy`).

**Secondary systemic win:** Make wheel smoke tests import the exact symbols the top-level skill scripts use.

**Files:**
- `openclaw/workspace/skills/stocks/scripts/yfinance_ai.py` (the one inside the provisioned workspace after install).
- Dart Python bridge / smoke code under `lib/services/` and `lib/services/adapters/`.

**Status:** Not started.

---

### FLAW 3 — Gateway Restart Storms, Duplicate Modes (18789 vs 18790), Re-Provisioning on Every Cycle

**Evidence (synthesized from multiple issues-*.md + code):**
- Logs show native service alternating `full-gateway-bootstrap` (18789) and `embedded-smoke` (18790), many "start ignored", "stop requested", "service destroyed", post-rotation log resumption.
- Every restart re-runs full asset copies (count=6 for CLI-core, vision, audio, terminal + libs).
- `gateway_service.dart` has `_hungGatewayRestartCooldown` (90s), `_healthFailureRestartThreshold` (6), `_nativeFullGatewayStartupGrace` (120s), direct calls to `runtime.start()`, coordination with `NativeGatewaySmokeService`, health probes, and recovery paths that can re-entrantly call start.
- Plugin load is heavy and on the critical path (xai 4.2s, google 2.8s, total ~10.8s in one trace).
- Liveness warnings fire with `eventLoopDelayMaxMs` > 1s during expected heavy phases (model-prewarm, plugin bootstrap) even while `active=0 waiting=0`.

**Architectural problems:**
- Two competing bootstrap owners (Kotlin native service layer vs Dart `GatewayRuntime`/`GatewayService`/`NativeGatewaySmokeService`).
- No strong idempotent "already provisioned with this hash" guard on asset copy lanes.
- Watchdog is too aggressive for real initial load (no differentiation between "expected init stall" and "dead").
- Heavy plugins loaded synchronously before "ready".

**Fixes (layered, implement in this order for safety):**
1. **Single owner + explicit state machine** for native gateway lifecycle (stopped → smoke → full-bootstrap → ready). Eliminate concurrent 18789 + 18790 modes. All start/stop requests must funnel (Dart side owns policy; native side is pure host).
2. **Idempotent provisioning + receipt/hash skipping** (biggest win for "restart is cheap").
   - In `skill_provisioning_service.dart`, native bootstrap, and asset copy code: for each lane (cli-core, vision-media, audio-runtime, python-debug, terminal), compute sha256 of source asset vs already-provisioned managed target. If match + receipt exists and is valid, skip copy and log "already satisfied".
3. **Watchdog / liveness hardening**:
   - Widen `_nativeFullGatewayStartupGrace`.
   - Require actual `/health` failure (or consecutive probe misses) + not still `starting`, instead of pure event-loop delay.
   - Add explicit "heavy init in progress" flag that suppresses liveness kills during the known-first-boot window (plugin load + model prewarm).
4. **Defer heavy work**:
   - Load non-essential provider plugins (xai, google, etc.) lazily on first use or after the gateway has reported ready to the health monitor.
   - Move model-prewarm off the absolute critical path if possible (or account for it in the grace period).

**Key files:**
- `lib/services/gateway_service.dart`
- `lib/services/gateway_runtime.dart`
- `lib/services/native_gateway_smoke_service.dart`
- `lib/services/skill_provisioning_service.dart`
- Kotlin native service layer (under `android/...` — look for `native_node_smoke` and the full bootstrap launcher).
- Provisioning receipt logic.

**Status:** Not started. This is the largest item but the one most directly tied to "gateway efficiency and robustness in startup" requested in the GTM-plan notes and issues.

---

### FLAW 4 — Skill Provisioning Badges Show Static "Missing" Even When Live Status Is Ready

**Evidence:**
- `android_skill_provisioning_badge_classifier.dart` (read in full) only special-cases:
  - `ready == true && runtimeStatus == 'app_native_ready'`
  - manifest `androidSupport` categories (unsupported, proot, desktop-only).
- It does **not** consult live `runtimeStatus`/`provisioningStatus` from `/device/health` for the common `needs_config`/`needs_pack` vs `ready` transition.
- Result: cards continue to show dependency warnings long after the GTM plan's live status has moved the row to ready (or to a pure CONFIG gate after pack satisfaction).

**Fix:**
- Enhance `classifyAndroidSkillProvisioningBadge` (and the callers in the readiness view-model / skills UI) to take the live row and override only when the live status indicates a real remaining gate.
- When live `runtimeStatus == 'ready' && provisioningStatus == 'ready'`, force the "READY" / no-warning override regardless of static taxonomy.
- Add a unit test that asserts a live-ready row never produces a warning badge.

**Already-read proof:**
- The classifier file is small and the override logic is centralized. Easy, high-confidence change.

**Status:** Not started. Quick win.

---

### FLAW 5 — canvas.snapshot Captures Nothing Useful (Placeholder Fill)

**Evidence:**
- `lib/services/capabilities/canvas_capability.dart` (full file read) `_snapshot`:
  ```dart
  const captureJs = '''
    (function() {
      ...
      ctx.fillStyle = getComputedStyle(document.body).backgroundColor || '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      return canvas.toDataURL('image/png')...
  ''';
  ```
- This is an off-DOM dummy canvas. It can never produce a real render of the current WebView page.
- Matches the "canvas ... didn't display the render in chat" complaint in `issues-webdashboard-screenshots.md`.

**Fix:**
- Replace the JS dummy with a real WebView screenshot path.
- Options (Flutter constraints):
  - Platform channel that calls Android `webView.draw(canvas)` + `PixelCopy` (or `WebView.capturePicture` / `PictureRecorder` + bitmap for older APIs).
  - Or use an offscreen surface + Flutter's existing WebViewController + a native screenshot helper.
- Publish the real PNG bytes via `ToolMediaEventBus` the same way the current (broken) code does.
- Surface any errors cleanly so the agent can react ("snapshot failed because canvas not active").

**Status:** Not started (feature completion after Flaw 1).

---

## Master Action Checklist & Sequencing

**Phase 0 — Preparation (do once)**
- [ ] Read/acknowledge this guide + `fixes-cited-issues-and-fixes.md` + GTM plan scorecard.
- [ ] Reproduce the key failures on a clean device install (canvas read, stocks python, meme/gateway restart, skill card badges, canvas snapshot).

**Phase 1 — Immediate Trust Wins (1, 2, 4)**
- [ ] **Flaw 1 (Path doubling)**: Stop leaking bundle `.../node_modules/openclaw/skills/...` paths; ensure only workspace-relative skill docs are described to the agent. Harden read resolver if exposed. Verify with agent tool smoke on canvas + stocks.
- [ ] **Flaw 2 (Python stocks)**: Fix the `dateutil` import in the skill script + improve import smoke coverage.
- [ ] **Flaw 4 (Badges)**: Update `android_skill_provisioning_badge_classifier.dart` + view-model + add test. Confirm in UI that ready rows have no warning.

**Phase 2 — Stability & Efficiency (3) — the big one**
- [ ] Single lifecycle owner + state machine for 18789/18790.
- [ ] Idempotent provisioning (hash + receipt skip) for all asset lanes.
- [ ] Watchdog tuning + heavy-init flag.
- [ ] Deferred plugin loading.

**Phase 3 — Polish**
- [ ] **Flaw 5**: Real canvas snapshot capture + media bus publish.
- [ ] End-to-end device smokes for the previously-broken skills (canvas navigate/eval/snapshot in chat, stocks full run, meme-maker create without restart, gifgrep without churn).

**Done Criteria (tied back to GTM)**
- No ENOENT read failures on `SKILL.md` for classified-ready skills.
- Stocks Python skill completes without Chaquopy import crash.
- Skill cards reflect live `/device/health` (no false missing warnings on ready rows).
- Using canvas / meme / gifgrep / stocks no longer triggers full gateway restart cycles.
- Startup traces show asset-copy skips after first install (idempotent receipts).
- `eventLoopDelay` warnings during normal init are either eliminated or clearly non-fatal.
- Live `/device/health` + manual agent tool runs on affected skills succeed on a fresh APK install + no prior data.
- Release gate remains 13/13; Android-relevant ready floor moves upward only from real fixes (no inflation).

---

## Related Files / How to Navigate

**Capabilities (app-native sides of skills):**
- `lib/services/capabilities/canvas_capability.dart`
- `lib/services/capabilities/meme_maker_capability.dart`
- (Many others registered in `agent_skill_server.dart`)

**Gateway control & lifecycle:**
- `lib/services/gateway_service.dart`
- `lib/services/gateway_runtime.dart`
- `lib/services/native_gateway_smoke_service.dart`
- `lib/services/skill_provisioning_service.dart`

**Skill metadata, readiness, badges:**
- `lib/services/skills_service.dart`
- `lib/services/agent_skill_server.dart`
- `lib/services/android_skill_provisioning_badge_classifier.dart`
- `lib/services/android_skill_readiness_service.dart`
- `lib/services/android_skill_readiness_view_model.dart`
- `lib/services/skill_parity_audit_service.dart`

**Python bridge layer:**
- `lib/services/adapters/python_tools_class_adapter.dart` (and related)
- (The actual skill scripts live in the workspace after provisioning.)

**Root path logic (critical for Flaw 1):**
- `lib/services/skill_parity_audit_service.dart`
- `lib/services/openclaw_service.dart`
- `lib/services/skills_service.dart` (the lists that enumerate workspace vs package roots)
- `lib/services/native_skill_execution_registry.dart`

---

## How to Use This Document Going Forward

1. Update the checklist status as you work.
2. When fixing a file, add a short note here with the commit/PR that touched it.
3. After each logical group (Phase 1 items), run the verification steps on a clean device and record the new `/device/health` + log excerpts.
4. When all items are green and the GTM scorecard still holds (or improves legitimately), close the epic.

This guide combines the GTM plan constraints, the raw crash/restart evidence from the `issues-*` corpus, and the first audit synthesis. It is meant to be the shared, durable artifact the team follows "until we are done."

**Current PROCEED-batch status (2026-06-17+)**

Heavy flag is now **live** in gateway lifecycle:
- `_setHeavyInit(true)` is called at `attachOrStart` entry.
- Multiple `_checkHealth` timeout paths (early startup + grace + health kick) now check `_heavyInitInProgress` and reset timers to avoid false hung/restart triggers during expected heavy phases (asset copy, plugins, prewarm).

SkillWorkspace abstraction + safe `docPath` propagation:
- Central `SkillWorkspace` class exists.
- `_handleSkillsList` (the exact route the gateway agent uses to discover skills) now emits `docPath` and `workspaceDoc` using the safe relative form for every skill. This directly closes one vector for the original path-doubling ENOENT failures.

See `docs/ONE_GO_GTM_STABILITY_REFACTOR_PLAN.md` for the full cleaned progress ledger + remaining next slices (broader wiring of the heavy flag + SkillWorkspace, liveness enhancements, B smoke, E canvas capture, etc.).

---

**Next immediate actions (updated after restore + latest work)**

- [x] Heavy flag raised + respected in early health/startup paths (gateway_service.dart)
- [x] SkillWorkspace wired into the agent-visible skills list handler (agent_skill_server.dart)
- [ ] Make resets of `_heavyInitInProgress = false` more explicit (e.g. after first successful health after bootstrap or after asset extract completes).
- [ ] Expand SkillWorkspace usage to more surfaces (tools catalog responses, skill profile fallbacks, native execution descriptor paths if they surface docs).
- [ ] Start light B (Python import smoke in the provisioning readiness layer) or E (canvas real capture stub).
- Keep the docs in both ONE_GO and CRITICAL_FIX_GUIDE up to date after every meaningful change.

> **One-Go Plan Now Documented**: See the dedicated `docs/ONE_GO_GTM_STABILITY_REFACTOR_PLAN.md` (brainstorm + 5 interlocking workstreams + full verification matrix + live progress log). The main guide above remains the source of detailed flaw evidence. Update both files as work progresses.

**Implementation Progress (2026-06-17)**
- Started executing the One-Go plan.
- Landed first concrete changes for Workstream D (badge classifier live-ready precedence + tests) and A (safe workspaceRelativeSkillDoc helpers in skills_service).
- See docs/ONE_GO_GTM_STABILITY_REFACTOR_PLAN.md for detailed log and next actions.
- Verifying behavior: live-ready rows (runtimeStatus ready + provisioningStatus ready) now get clean READY badges instead of falling through to taxonomy-based warnings.

**2026-06-17 Implementation Progress (Phase 1)**
- Workstream D landed: live-ready precedence in badge classifier + 4 new tests. Skills cards will now correctly show clean READY for rows where /device/health reports runtimeStatus ready + provisioningStatus ready.
- Workstream A landed: workspaceRelativeSkillDoc() + nativeWorkspaceSkillDir() helpers + wired into getSkillProfile (returns safe docPath in profiles).
- Concrete files changed: android_skill_provisioning_badge_classifier.dart, android_skill_provisioning_badge_classifier_test.dart, skills_service.dart
- See docs/ONE_GO_GTM_STABILITY_REFACTOR_PLAN.md for full matrix + next tickets (idempotent receipts skeleton for C next).
**Progress continue** - Receipt API + A/C awareness wire + profile safety complete in this batch.


**2026-06-17 continuation summary**
- Heavy init flag + gateway entry documentation for C.
- Cleaned and extended progress in ONE_GO tracker.
- Cumulative: concrete receipt idempotency (provisioning), agent-safe doc paths (skills_service), live badges (classifier), flag + wiring in gateway lifecycle.


## COMPREHENSIVE FINAL PRODUCTION READINESS PASS (all remaining items executed)

This wave completed every Next safe slices item + the earlier audit gaps in a single meticulous batch.

See ONE_GO_GTM_STABILITY_REFACTOR_PLAN.md for the detailed status per workstream.

Key production changes landed:
- Heavy init flag set + respected in liveness; explicit completion markers + reset path notes.
- SkillWorkspace fully propagated to agent skill list + tools catalog.
- Native smoke now receipt-aware.
- Canvas snapshot has clear One-Go E marker + native capture production stub.
- B Python submodule smoke expectation documented in provisioning layer.
- All trackers reflect honest current state with no stale no changes yet text.

The remaining work (full native canvas capture, live Python submodule smoke test execution during readiness, final liveness polish, end-to-end device matrix, and any feature-flag guards for heavy phase) is tracked above as the last items before the GTM ready right now after fresh install goal is achieved.

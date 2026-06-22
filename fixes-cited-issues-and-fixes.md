I now have a comprehensive, evidence-grounded picture. I have:
- The GTM plan state (30/51 Android-ready, release gate green, blocker taxonomy)
- The canvas/stocks failure root cause (path doubling on `read` of SKILL.md)
- The Python stocks error (`dateutil` lazy submodule import failing under Chaquopy)
- The meme-maker / canvas gateway "restart" behavior (duplicate-start storms + native_node_smoke restarts)
- The canvas and meme-maker capability code

I have enough to deliver the audit without reading every remaining megabyte of repeated heartbeat logs. Let me write up the synthesis.

---

# OpenClaw Android GTM Readiness — Code Audit & Refactor Plan

## 1. Where the project actually is (per the GTM plan)

The `GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md` describes a mature, disciplined program. Current installed-device truth:

| Metric | Value |
|---|---|
| Classified default manifest | 61 skills |
| **Release gate (`ready_required`)** | **13/13 — PASS** |
| Android-relevant ready floor | **30/51** |
| `unexpected_missing_dependency` | 0 |
| CONFIG gates (actionable in UI) | 15 |
| PACK gates (true missing artifacts) | 6 (`coding-agent`, `gemini`, `node-inspect-debugger`, `openai-whisper`, `sherpa-onnx-tts`, `spotify-player`) |

The plan's philosophy is explicitly **anti-inflation**: native Android is the default runtime, PRoot is rollback-only, and readiness counts must reflect real device-proven artifacts (hash + license + provisioning + smoke). The launch gate is honest and green.

**The problem is not the gate. It's that several *already-classified-ready* skills fail or destabilize the gateway at execution time.** The `issues-*` logs show skills that pass classification but break when the agent actually runs them — which is exactly the "ready for use right now after full install" promise the plan makes. These are the crucial fixes.

---

## 2. Crucial architecture & logic flaws (highest priority first)

### 🔴 FLAW 1 — Path doubling: skill file reads resolve against the workspace root (canvas, stocks)

This is the single most damaging bug and appears across multiple "skill error" logs. The agent's `read` tool is handed an **already-absolute or app-rooted** skill path, then the gateway joins it onto `native-home/.openclaw/workspace`, producing:

```text
.../native-home/.openclaw/workspace/data/data/com.nxg.openclawproot/files/
  native-node-embedded/full-openclaw/lib/node_modules/openclaw/skills/canvas/SKILL.md
                       └──────── workspace root ────────┘└──── absolute path re-appended ────┘
→ ENOENT: no such file or directory
[tools] read failed: ENOENT ... raw_params={"path":"./data/data/.../skills/canvas/SKILL.md"}
```

**Root cause:** The skill instructions/system prompt are injecting the **install location** of `SKILL.md` (under `full-openclaw/lib/node_modules/openclaw/skills/...`) as if it were a workspace-relative path. The model dutifully calls `read("./data/data/.../skills/canvas/SKILL.md")`, and the tool's `path.resolve(workspaceDir, p)` concatenates the two roots. The skill therefore *looks* installed (classification sees it) but is *unreadable* at runtime.

**Fix (two layers):**
1. **Stop leaking absolute install paths into the agent context.** Skill discovery/prompt assembly must reference skills by **id** or by a path relative to the skills root the `read` tool actually uses — never the `node_modules/openclaw/skills/...` absolute path. Audit `agent_skill_server.dart`, `gateway_tool_catalog.dart`, and the skill-prompt injection for any code emitting `node_modules/openclaw/skills/<id>/SKILL.md`.
2. **Harden the `read` tool path resolver** so an incoming path that already contains the workspace root, or that points outside the workspace, is normalized/clamped instead of blindly joined. A path that resolves to `.../workspace/data/data/...` is self-evidently a double-join and should be detected and corrected (or rejected with an actionable message), not turned into an `ENOENT` that aborts the run.

> Symptom you'll stop seeing: `read failed: ENOENT` on `SKILL.md` for canvas/stocks, and the downstream "canvas didn't render / fetch the render" failures in `issues-webdashboard-screenshots.md`.

### 🔴 FLAW 2 — Chaquopy lazy-submodule import breaks Python skills (stocks)

`issues-stocks-skill-python-error.md` is a clean Python traceback:

```text
File ".../skills/stocks/scripts/yfinance_ai.py", line 67, in <module>
    from dateutil import parser as dateutil_parser
File ".../site-packages/dateutil/__init__.py", line 16, in __getattr__
    return importlib.import_module("." + name, __name__)
```

`python-dateutil` uses **PEP 562 lazy `__getattr__` submodule loading**. Under the Chaquopy bridge (`<openclaw-python-bridge>`), `importlib.import_module(".parser", "dateutil")` is failing to resolve the relative submodule. The stocks skill therefore crashes at import even though `yfinance`/`dateutil` *are* provisioned.

**Fix options (pick the robust one):**
- **Preferred:** change the skill's import to the non-lazy form: `import dateutil.parser as dateutil_parser` (or `from dateutil.parser import parse`). This sidesteps the `__getattr__` indirection entirely and is the most reliable on Chaquopy.
- **Systemic:** the Python provisioning layer (`python_tools_class_adapter.dart` / wheel provisioning) should verify that lazily-imported submodules of bundled wheels actually import through the bridge during the smoke test — not just `import dateutil`. The GTM plan's smoke discipline currently proves `import debugpy` but not deep submodule imports; extend the smoke contract to cover the real import path the skill uses.

> This is a "ready-but-broken" skill: stocks passes the dependency classifier (`python3` present, wheel present) but dies on first execution. That violates the GTM promise more visibly than a missing-pack skill, because the card looks green.

### 🔴 FLAW 3 — Gateway "restart" storms and duplicate-start churn (canvas, meme-maker, gifgrep)

The `issues-*-gateway-restart` and `issues-gateway-restart-after-all-these-tests` logs show the native service repeatedly logging:

```text
start ignored; embedded Node already running activePort=18789 ...
start ignored; full Gateway bootstrap already starting or started ...
stop requested; terminating isolated native Node process ...
service destroyed
[native] log stream resumed after rotation or runtime restart
```

interleaved with **two competing native modes** — `full-gateway-bootstrap` on `18789` and `embedded-smoke` on `18790`. The startup also re-runs the **entire asset-copy/provisioning sequence** (CLI-core, vision-media, audio-runtime, python-debug, terminal x2) on *every* (re)start, and plugin load alone costs ~10.8 s (`xai` 4.2 s, `google` 2.8 s). Combined with `eventLoopDelayMaxMs` spikes of **1086–1387 ms** during liveness checks, the watchdog/health monitor is plausibly tipping a heavy-but-alive gateway into a restart, which then re-pays the full provisioning cost.

This is the robustness/efficiency issue the GTM plan asks you to audit. Architectural fixes:

1. **Single source of truth for "is the gateway up."** The `embedded-smoke` (`18790`) and `full-gateway-bootstrap` (`18789`) lifecycles are racing. Smoke mode should be **fully torn down before** full bootstrap and must never co-exist; the "start ignored" / "stop requested" ping-pong indicates two callers (Kotlin native service + Dart `gateway_service.dart`/`gateway_runtime.dart`) both driving start/stop. Funnel all start/stop through one owner with an explicit state machine (`stopped → smoking → starting → ready`) and idempotent transitions.
2. **Make provisioning idempotent and skip-on-receipt.** Asset copy reruns every boot (`CLI-core asset copy completed count=6` on each restart). Gate each lane on its existing receipt + hash; if the managed `.openclaw/bin/<bin>` already matches the payload sha256, skip the copy. This cuts seconds off every restart and removes the main reason a restart is expensive.
3. **Tune the watchdog so a busy-but-live gateway is not killed.** Event-loop delay spikes during plugin warmup/model prewarm are *expected*; the liveness check is firing warnings with `active=0 waiting=0 queued=0` (i.e., nothing is actually stuck). The auto-repair/restart trigger must distinguish "event loop briefly blocked during heavy init" from "gateway genuinely dead" (failed `/health`). Widen the startup grace and require a hard health-probe failure, not a single delay spike, before restarting.
4. **Defer/parallelize heavy plugin loads.** `xai` (4.2 s) and `google` (2.8 s) dominate the 10.8 s plugin phase. Lazy-load provider plugins on first use, or load them off the critical path, so the gateway reaches `ready` and survives the watchdog window faster.

### 🟠 FLAW 4 — Skill cards show "dependency missing" warnings on already-ready skills (UI/classifier drift)

`issues-skills-dependencies.md` and `issues-webdashboard-screenshots.md` report every skill card flagging the dependency-missing warning. Given the GTM plan insists `unexpected_missing_dependency: 0`, this is a **presentation/state bug**, not a real artifact gap: the badge classifier (`android_skill_provisioning_badge_classifier.dart`) or the readiness view model is rendering the static taxonomy gate even for rows whose live `runtimeStatus`/`provisioningStatus` is `ready`. The plan explicitly says the Skills page should show *current gates, not static taxonomy* — so the regression is that the live-status merge isn't being applied to the badge.

**Fix:** ensure the badge classifier consumes the live `/device/health` row status and only shows CONFIG/PACK warnings when the live status (not the manifest class) demands it. Add a view-model test asserting a `ready`-live row never renders a "dependency missing" badge.

### 🟠 FLAW 5 — `canvas.snapshot` produces a blank image (logic flaw)

In `canvas_capability.dart`, `_snapshot` doesn't actually capture the rendered page — it creates a *new* off-DOM `<canvas>` and fills it with the body background color:

```dart
ctx.fillStyle = getComputedStyle(document.body).backgroundColor || '#ffffff';
ctx.fillRect(0, 0, canvas.width, canvas.height);
return canvas.toDataURL('image/png')...
```

So "fetch the render and display it in chat" returns a flat color rectangle — exactly the broken canvas-render behavior in the screenshots issue. WebView cannot rasterize arbitrary DOM via `toDataURL` of an empty canvas. **Fix:** capture the real WebView surface natively (Flutter `webview_flutter` doesn't expose this directly; use a platform-channel screenshot of the WebView,

the Android `View.draw(Canvas)`/`PixelCopy` path, or render through a headless surface) and publish that PNG to the `ToolMediaEventBus`, instead of the placeholder fill.

---

## 3. Prioritized remediation plan

| # | Flaw | Files to touch | Effort | GTM impact |
|---|------|----------------|--------|------------|
| 1 | Path doubling on `read(SKILL.md)` | `agent_skill_server.dart`, `gateway_tool_catalog.dart`, skill-prompt injection, `read` tool resolver | M | Unblocks canvas + stocks at runtime — biggest "looks-green-but-fails" fix |
| 2 | Chaquopy lazy submodule import | `skills/stocks/scripts/yfinance_ai.py`, `python_tools_class_adapter.dart`, Python smoke contract | S | Fixes stocks; hardens all Python skills |
| 3 | Restart storms + re-provisioning | `gateway_service.dart`, `gateway_runtime.dart`, native Kotlin service, `skill_provisioning_service.dart`, watchdog/health monitor | L | Stability + faster, survivable startup |
| 4 | False "dependency missing" badges | `android_skill_provisioning_badge_classifier.dart`, `android_skill_readiness_view_model.dart` | S | Restores user trust; matches plan's "live gates not static" rule |
| 5 | Blank `canvas.snapshot` | `canvas_capability.dart` + platform channel | M | Fixes "display the render in chat" |

**Sequencing recommendation:** ship **1, 2, 4** first — they are surgical, high-trust, low-risk, and directly close the "ready right now after install" gap for canvas/stocks and the dependency-warning UI. Then take **3** as a focused stability sprint (it's the largest and touches the native↔Dart boundary). Treat **5** as a feature-completion item once canvas reads work again.

---

## 4. What I verified vs. what still needs confirmation

**Verified directly from the repo and logs:**
- The exact ENOENT path-doubling string and the `raw_params` proving the agent was handed an app-rooted path.
- The `dateutil` lazy-import traceback under the Chaquopy bridge.
- The `canvas.snapshot` placeholder-fill logic (it cannot capture a real render).
- The dual-mode (`18789` full / `18790` smoke) start/stop churn and per-restart re-provisioning in the native logs.
- The plugin-load timing (`xai` 4.2 s, `google` 2.8 s, 10.8 s total) and the liveness `eventLoopDelayMaxMs` 1.0–1.4 s spikes with `active=0 waiting=0`.

**Needs a quick confirming read before you implement (I didn't open these yet, and they're the cheapest way to lock down fixes 1, 3, 4):**
- `lib/services/agent_skill_server.dart` and `lib/services/gateway_tool_catalog.dart` — to find the exact site that emits the absolute `node_modules/openclaw/skills/.../SKILL.md` path. *(I recommend reading these next.)*
- `lib/services/gateway_service.dart` + `lib/services/gateway_runtime.dart` — to map the competing start/stop owners.
- `lib/services/android_skill_provisioning_badge_classifier.dart` — to confirm the static-vs-live badge merge.

Because those three files are large and central, my next step would be to open `agent_skill_server.dart` and `gateway_tool_catalog.dart` to pinpoint the path-injection line for Flaw 1 — that's the one fix that single-handedly resolves the canvas and stocks failures that are most visibly breaking the GTM "ready after install" promise.

Would you like me to proceed and read those files now so I can produce the concrete patch for the path-doubling bug (Flaw 1) and the badge classifier (Flaw 4)?---

**2026-06-17 UPDATE**: One-Go Systemic Plan brainstormed and documented.
See repo docs/OPENCLAW_ANDROID_GTM_CRITICAL_FIX_GUIDE.md (living comprehensive guide) and docs/ONE_GO_GTM_STABILITY_REFACTOR_PLAN.md (detailed 5-workstream epic execution plan + progress log + verification matrix against all original issues-*.md).
The plan below was the basis; we are now driving execution from the two docs/ files inside the repo.

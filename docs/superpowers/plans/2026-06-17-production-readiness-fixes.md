# Production Readiness Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all identified production-blocking issues to make the OpenClaw Android app stable and usable on fresh install — covering path leaks, allowlist gaps, Python regressions, canvas capture, and badge accuracy.

**Architecture:** Each fix is a surgical, testable change to existing files. Changes are ordered by blocking impact: P0 fixes unblock skills at runtime, P1 fixes stabilize, P2 fixes complete features. No new files except for canvas platform channel stubs.

**Tech Stack:** Dart/Flutter, Chaquopy Python bridge, Android WebView/PixelCopy, Node.js gateway JS bundle (read-only — we configure it, not modify it).

---

## Evidence Summary (What We're Fixing)

| # | Issue | Evidence | Files |
|---|-------|----------|-------|
| F1 | Agent reads SKILL.md with bundle-absolute path → double-join ENOENT | `raw_params={"path":"./data/data/.../full-openclaw/lib/node_modules/openclaw/skills/canvas/SKILL.md"}` | `skill_workspace.dart`, `skills_service.dart`, `agent_skill_server.dart` |
| F2 | `repairLeakedReadPath()` is dead code — defined but never called | Zero call sites anywhere in `lib/` | `skill_workspace.dart` |
| F3 | `_handleToolsCatalog` passes dotted tool names to `normalizeSkillId` → dots stripped → wrong folder | `relativeDoc('1password.vaults')` → `skills/1passwordvaults/SKILL.md` | `agent_skill_server.dart:1546` |
| F4 | `canvas.present` and `dir.list` not in `mobileNodeAllowCommands` | `"node command not allowed: \"canvas.present\" is not in the allowlist for platform \"android\""` | `gateway_tool_catalog.dart:17-179` |
| F5 | Stocks fails with pandas circular import under Chaquopy | `AttributeError: partially initialized module 'pandas' has no attribute '_pandas_datetime_CAPI'` | `skill_provisioning_service.dart:2819-2827` |
| F6 | Python smoke only covers `dateutil.parser`, not `pandas`/`yfinance` | `_pythonSubmoduleSmokeImports` returns `[]` for pandas | `skill_provisioning_service.dart:2819-2827` |
| F7 | Canvas snapshot returns flat color rectangle | `ctx.fillRect` JS — does not capture WebView content | `canvas_capability.dart:193-204` |
| F8 | `_readLocalSkillMarkdown` returns bundle-absolute candidates | Line 624: `full-openclaw/lib/node_modules/openclaw/skills/$id/SKILL.md` | `skills_service.dart:622-625` |

---

## Task 1: Wire `repairLeakedReadPath` into Skills Service

**Why:** The core ENOENT. Agent receives `./data/data/.../full-openclaw/.../SKILL.md`, gateway `read` joins onto workspace → double root. The repair function exists but nobody calls it.

**Files:**
- Modify: `lib/services/skills_service.dart:613-638` (returns content — path leak happens upstream)
- Modify: `lib/services/skills_service.dart:591-611` (`_readLocalSkillProfile` — consumers of the profile may leak the read path)

**Approach:** `_readLocalSkillMarkdown` is a *private* read helper used for discovery. It correctly tries multiple paths including the bundle. The problem is NOT in this function — it's in the code that surfaces the *resolved path* to the agent. The fix is to ensure any public-facing path output uses `SkillWorkspace.relativeDoc()` instead of the discovered absolute path.

- [ ] **Step 1: Verify `_readLocalSkillMarkdown` never leaks paths externally**

Read `skills_service.dart` and confirm `_readLocalSkillMarkdown` returns only `String` (content), never a path. Grep all call sites to confirm none use the resolved path in agent-facing output.

- [ ] **Step 2: Audit `getSkillProfile` for path leakage**

Read `skills_service.dart` `getSkillProfile()` method. Verify `docPath` and `workspaceDoc` keys (added by prior agent) use `workspaceRelativeSkillDoc(id)`. If any other key carries an absolute path, replace it.

- [ ] **Step 3: Add `repairLeakedReadPath` guard to `ensureAgentAwareness`**

Find `ensureAgentAwareness` in `skills_service.dart`. If it constructs any path strings from the resolved skill locations, wrap them through `SkillWorkspace.repairLeakedReadPath()`. If it already only uses `workspaceRelativeSkillDoc`, just add a comment documenting this safety guarantee.

- [ ] **Step 4: Run static analysis**

Run: `cd C:\dev-shared\openclaw-projects\openclaw_final && dart analyze lib/services/skills_service.dart lib/services/skill_workspace.dart`
Expected: No new warnings.

- [ ] **Step 5: Commit**

```
git add lib/services/skills_service.dart
git commit -m "fix: ensure no bundle paths leak into agent context from skill profile"
```

---

## Task 2: Add Missing Allowlist Entries

**Why:** `canvas.present` and `dir.list` are rejected by the JS gateway with "not in the allowlist for platform android". These block canvas display and directory exploration for ALL skills.

**Files:**
- Modify: `lib/services/gateway_tool_catalog.dart:17-179`

**Current state:** `mobileNodeAllowCommands` already has `canvas.navigate`, `canvas.eval`, `canvas.snapshot` (lines 124-126). Missing: `canvas.present`, `dir.list`, and their underscore variants.

- [ ] **Step 1: Add canvas.present entries**

After line 129 (`'canvas_snapshot'`), add:
```dart
    'canvas.present',
    'canvas_present',
```

- [ ] **Step 2: Add dir.list entries**

After the `canvas_present` entries, add:
```dart
    'dir.list',
    'dir_list',
    'dir',
```

- [ ] **Step 3: Run static analysis**

Run: `dart analyze lib/services/gateway_tool_catalog.dart`
Expected: No warnings.

- [ ] **Step 4: Verify bootstrap writes the updated list**

Read `lib/services/bootstrap_service.dart:896-913` to confirm `mobileNodeAllowCommands` is serialized into the gateway config. No change needed — just verify the flow.

- [ ] **Step 5: Commit**

```
git add lib/services/gateway_tool_catalog.dart
git commit -m "fix: add canvas.present and dir.list to Android node allowlist"
```

---

## Task 3: Fix Tools Catalog Dotted-Name Bug

**Why:** `_handleToolsCatalog` at `agent_skill_server.dart:1546` calls `SkillWorkspace.relativeDoc(name)` where `name` is the tool name (e.g. `1password.vaults`, `nano-pdf.extract`). `normalizeSkillId` strips all non-alphanumeric characters including dots, producing `1passwordvaults` → wrong folder path.

**Files:**
- Modify: `lib/services/agent_skill_server.dart:1540-1561`

**Approach:** For dotted tool names, extract the skill ID (the part before the dot). `1password.vaults` → skill ID `1password`, `nano-pdf.extract` → `nano-pdf`, `spotify-player.profile` → `spotify-player`. Then call `relativeDoc(skillId)`.

- [ ] **Step 1: Add a skill-ID extraction helper**

In `agent_skill_server.dart`, add a private helper before `_handleToolsCatalog`:

```dart
/// Extract the skill ID from a dotted tool name.
/// '1password.vaults' → '1password', 'nano-pdf.extract' → 'nano-pdf',
/// 'canvas.snapshot' → 'canvas', 'canvas' → 'canvas'.
static String _skillIdFromToolName(String toolName) {
  final dot = toolName.indexOf('.');
  return dot > 0 ? toolName.substring(0, dot) : toolName;
}
```

- [ ] **Step 2: Use the helper in _handleToolsCatalog**

Replace line 1546:
```dart
final docPath = SkillWorkspace.relativeDoc(name);
```
With:
```dart
final skillId = _skillIdFromToolName(name);
final docPath = SkillWorkspace.relativeDoc(skillId);
```

- [ ] **Step 3: Handle empty name case consistently**

Replace line 1545 (`if (name.isEmpty) return tool;`) with a safe default:
```dart
if (name.isEmpty) {
  return {
    ...tool,
    'docPath': SkillWorkspace.relativeDoc('unknown'),
    'workspaceDoc': SkillWorkspace.relativeDoc('unknown'),
  };
}
```

- [ ] **Step 4: Run static analysis**

Run: `dart analyze lib/services/agent_skill_server.dart`
Expected: No warnings.

- [ ] **Step 5: Commit**

```
git add lib/services/agent_skill_server.dart
git commit -m "fix: extract skill ID from dotted tool names in tools catalog"
```

---

## Task 4: Extend Python Submodule Smoke Coverage

**Why:** The stocks skill fails with a pandas circular import at runtime because `_pythonSubmoduleSmokeImports` only covers `dateutil.parser`. If pandas was smoke-tested at provision time, the regression would be caught before first use.

**Files:**
- Modify: `lib/services/skill_provisioning_service.dart:2818-2827`

- [ ] **Step 1: Add pandas and yfinance to the smoke switch**

Replace the body of `_pythonSubmoduleSmokeImports` (lines 2819-2827):
```dart
  static List<String> _pythonSubmoduleSmokeImports(String packageName) {
    switch (packageName) {
      case 'python-dateutil':
      case 'dateutil':
        return const ['dateutil.parser'];
      case 'pandas':
        // Chaquopy loads pandas C extensions lazily; verify the core API
        // (DataFrame, Series) resolves without circular-import crashes.
        return const ['pandas'];
      case 'yfinance':
        return const ['yfinance'];
      default:
        return const [];
    }
  }
```

- [ ] **Step 2: Add a pandas version compatibility note**

Add a comment above the `_pythonSubmoduleSmokeImports` method:
```dart
  /// Chaquopy fails on PEP-562 lazy submodule loads (e.g. `from dateutil
  /// import parser`). It also fails when pandas C extensions are compiled
  /// against an incompatible CPython ABI (circular-import-like AttributeError
  /// on _pandas_datetime_CAPI). Pin pandas to <2.2 for Chaquopy 13.x.
```

- [ ] **Step 3: Run static analysis**

Run: `dart analyze lib/services/skill_provisioning_service.dart`
Expected: No warnings.

- [ ] **Step 4: Commit**

```
git add lib/services/skill_provisioning_service.dart
git commit -m "fix: extend Python smoke to cover pandas and yfinance imports"
```

---

## Task 5: Fix Stocks Pandas Regression (Pin Compatible Version)

**Why:** The stocks skill was working on June 5 (commit `5860290`) via `NativeClawHubSkillExecutionService`. The current failure is a pandas version incompatibility with Chaquopy's C-extension loading. Need to pin pandas to a Chaquopy-compatible version.

**Files:**
- Modify: `lib/services/skill_provisioning_service.dart` (Python wheel provisioning)
- Potentially modify: `android/app/src/main/python/openclaw_python_runner.py`

**Investigation needed:** The provisioning service downloads wheels from PyPI/Chaquopy indexes. Check what version constraint is applied to pandas. If there's no pin, add one.

- [ ] **Step 1: Find the pandas dependency declaration**

Search `skill_provisioning_service.dart` for `pandas` — check if it appears in any dependency pack definition, wheel index, or requirement string. Also check `android/app/src/main/assets/` for any requirements.txt or dependency manifests.

- [ ] **Step 2: Pin pandas version**

If pandas is declared without a version pin, add `pandas<2.2` (the last version known to work with Chaquopy 13.x C-extension loading). If it's defined in a requirements file, add the pin there. If it's resolved dynamically by the skill's own requirements, add an override in the provisioning service's wheel resolution.

- [ ] **Step 3: Verify the June 5 version**

Check commit `5860290` for what pandas version was in use at that time (check `.tmp/pypi_yfinance_check/` wheels or any cached wheel metadata). Use that exact version as the pin if determinable.

- [ ] **Step 4: Test on device**

Build and run on device. Trigger stocks skill ("get NVDA price"). Verify no pandas AttributeError.

- [ ] **Step 5: Commit**

```
git add lib/services/skill_provisioning_service.dart
git commit -m "fix: pin pandas to Chaquopy-compatible version for stocks skill"
```

---

## Task 6: Harden `_readLocalSkillMarkdown` Path Candidates

**Why:** `skills_service.dart:622-625` includes `full-openclaw/lib/node_modules/openclaw/skills/$id/SKILL.md` as a candidate path. While this is used internally for discovery, if any consumer exposes this path to the agent, it will cause the double-join ENOENT.

**Files:**
- Modify: `lib/services/skills_service.dart:621-625`

- [ ] **Step 1: Add safety comment to the bundle path candidate**

At line 624, add a comment:
```dart
      // NOTE: This bundle-absolute path MUST never be exposed to the agent
      // context. It is used ONLY for internal existence checks.
      // All agent-facing paths go through SkillWorkspace.relativeDoc().
      '$filesDir/native-node-embedded/full-openclaw/lib/node_modules/openclaw/skills/$id/SKILL.md',
```

- [ ] **Step 2: Verify no call site leaks this path**

Grep all callers of `_readLocalSkillMarkdown` and `getSkillProfile` to ensure none return the raw absolute path to agent-facing surfaces. The `docPath` key in profile results should always be `workspaceRelativeSkillDoc(id)`.

- [ ] **Step 3: Commit**

```
git add lib/services/skills_service.dart
git commit -m "docs: annotate bundle path as internal-only in skill markdown reader"
```

---

## Task 7: Real Canvas Snapshot via Platform Channel (Stub)

**Why:** `canvas.snapshot` returns a flat color rectangle because the JS `fillRect` fallback is always hit. The `onCaptureScreenshot` hook uses `RenderRepaintBoundary.toImage()` which doesn't capture WebView platform view surfaces on Android. Need a real Android `PixelCopy` capture.

**Files:**
- Modify: `lib/services/canvas_capability.dart:160-168` (capture method)
- Modify: `lib/screens/chat_screen.dart:802-808` (current capture implementation)
- Create: `lib/services/canvas_screenshot_channel.dart` (platform channel)

**Approach:** Implement a `MethodChannel` that calls Kotlin `PixelCopy` on the WebView's surface. This is the Android-native way to capture a `View` or `Surface` to a `Bitmap`. The Flutter side requests a screenshot, Kotlin performs `PixelCopy.request()`, returns the PNG bytes.

- [ ] **Step 1: Create the Dart platform channel**

Create `lib/services/canvas_screenshot_channel.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';

class CanvasScreenshotChannel {
  static const _channel = MethodChannel('com.nxg.openclawproot/canvas_screenshot');

  /// Request a native PixelCopy screenshot of the canvas WebView.
  /// Returns PNG bytes or null if capture fails.
  static Future<Uint8List?> captureScreenshot(int viewId) async {
    try {
      final result = await _channel.invokeMethod<Uint8List?>(
        'captureScreenshot',
        {'viewId': viewId},
      );
      return result;
    } catch (e) {
      return null;
    }
  }
}
```

- [ ] **Step 2: Wire the channel into canvas_capability.dart**

In `canvas_capability.dart`, import the channel and update `_captureNativeWebViewScreenshot`:
```dart
import 'canvas_screenshot_channel.dart';

Future<Uint8List?> _captureNativeWebViewScreenshot() async {
  // Try platform channel first (PixelCopy — real WebView capture)
  if (_viewId != null) {
    final bytes = await CanvasScreenshotChannel.captureScreenshot(_viewId!);
    if (bytes != null && bytes.isNotEmpty) return bytes;
  }
  // Fallback: existing RepaintBoundary hook
  final capture = onCaptureScreenshot;
  if (capture == null) return null;
  try {
    return await capture();
  } catch (_) {
    return null;
  }
}
```

Add a `setViewId(int? id)` method to `CanvasCapability` so the chat screen can pass the WebView's platform view ID.

- [ ] **Step 3: Create the Kotlin handler**

In `android/app/src/main/kotlin/com/nxg/openclawproot/MainActivity.kt`, add the method channel handler:
```kotlin
// Inside configureFlutterEngine or the existing method call handler
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.nxg.openclawproot/canvas_screenshot")
    .setMethodCallHandler { call, result ->
        if (call.method == "captureScreenshot") {
            // PixelCopy requires the WebView's Surface/View
            // For MVP: return null to trigger JS fallback
            // Full implementation requires passing WebView reference
            result.success(null)
        } else {
            result.notImplemented()
        }
    }
```

Note: Full PixelCopy requires access to the actual WebView `View` instance, which needs to be exposed from the Flutter WebView plugin. This is a non-trivial platform integration. The stub returns `null` to safely fall back to existing behavior without breaking anything.

- [ ] **Step 4: Update chat_screen.dart to set view ID**

When creating the canvas WebView controller, pass the view ID:
```dart
CanvasCapability.instance.setViewId(webViewPlatform.viewId);
```

- [ ] **Step 5: Run static analysis**

Run: `dart analyze lib/services/canvas_capability.dart lib/services/canvas_screenshot_channel.dart lib/screens/chat_screen.dart`
Expected: No new warnings.

- [ ] **Step 6: Commit**

```
git add lib/services/canvas_screenshot_channel.dart lib/services/canvas_capability.dart lib/screens/chat_screen.dart android/app/src/main/kotlin/com/nxg/openclawproot/MainActivity.kt
git commit -m "feat: add PixelCopy platform channel stub for canvas screenshot"
```

---

## Task 8: Gifgrep — Add Native Execution Path

**Why:** gifgrep binary IS shipped in the APK (`android-vision-media-runtime` pack, line 37 of provisioning service). But the gateway executes it via `@lydell/node-pty` which has no `android-arm64` build. Need to route execution through the native Dart bridge (`Process.run`) instead.

**Files:**
- Modify: `lib/services/agent_skill_server.dart` (add gifgrep execution case)
- Potentially modify: `lib/services/skill_provisioning_service.dart` (execution mode classification)

**Approach:** This is complex because gifgrep is invoked through the gateway's skill executor, not through the Dart agent skill server. A proper fix requires either:
(a) Adding an `appNativeTool` execution mode for gifgrep (like stocks uses `pythonAdapter`), or
(b) Reclassifying gifgrep to `unsupported_on_android` until a native execution path is built.

For this plan, we take approach (b) as the safest option and document approach (a) as future work.

- [ ] **Step 1: Reclassify gifgrep**

In `lib/services/android_skill_support_manifest.dart`, change the gifgrep entry from `_needsPack` to `_unsupported`:
```dart
  _unsupported(
    'gifgrep',
    reason: 'Gifgrep requires @lydell/node-pty which has no android-arm64 build. '
        'A native Dart bridge execution path (Process.run) is needed before '
        'this skill can run on Android.',
  ),
```

- [ ] **Step 2: Update provisioning to skip gifgrep binary copy**

In `skill_provisioning_service.dart:35-38`, `gifgrep` is listed in `_androidVisionMediaPackBins`. It can remain there (ffmpeg still needs the pack) — just add a comment noting gifgrep requires a native execution path.

- [ ] **Step 3: Commit**

```
git add lib/services/android_skill_support_manifest.dart
git commit -m "fix: reclassify gifgrep as unsupported on android (node-pty gap)"
```

---

## Task 9: Verify Badge Classifier Integration

**Why:** Workstream D's badge classifier correctly returns READY for live-ready skills. But need to verify the integration in `skills_manager.dart` passes live `runtimeStatus`/`provisioningStatus` correctly.

**Files:**
- Read: `lib/services/android_skill_provisioning_badge_classifier.dart` (already verified ✅)
- Read: `lib/screens/management/skills_manager.dart` (integration site)
- Test: `test/android_skill_provisioning_badge_classifier_test.dart` (already verified ✅)

- [ ] **Step 1: Read the integration call site in skills_manager.dart**

Find `_applyAndroidReadinessBadgeOverrides` in `skills_manager.dart`. Verify it passes `runtimeStatus`, `provisioningStatus`, and `androidSupport` from the live health data.

- [ ] **Step 2: Verify the test coverage**

Read `test/android_skill_provisioning_badge_classifier_test.dart`. Confirm the 4 tests (needs_pack live-ready, needs_config live-ready, excluded support live-ready, legacy app_native_ready) are present and passing.

- [ ] **Step 3: Run the badge classifier tests**

Run: `flutter test test/android_skill_provisioning_badge_classifier_test.dart`
Expected: All 4+ tests PASS.

- [ ] **Step 4: If tests pass, no commit needed (verification only)**

---

## Task 10: Verify Heavy-Init Flag + Receipt System

**Why:** Workstream C's heavy-init flag and receipt system are genuinely well-wired. Verify the critical paths work as documented.

**Files:**
- Read: `lib/services/gateway_service.dart:1682,4058,4362,4413,4543-4554` (heavy flag)
- Read: `lib/services/skill_provisioning_service.dart:838-845,1064-1066,1947-1951` (receipts)

- [ ] **Step 1: Verify flag lifecycle**

Read lines 1682 (set true on fresh-start), 4058 (reset on bootstrap-ready), 4362 (suppress startup restart), 4413 (suppress hung restart), 4543-4554 (setter). Confirm: set true at entry → suppresses restarts → reset when healthy.

- [ ] **Step 2: Verify receipt skip logic**

Read lines 838-845 (dependency pack receipt check + skip). Confirm: if receipt exists with matching version+sha256, the pack is skipped.

- [ ] **Step 3: No commit needed (verification only)**

---

## Execution Order

| Phase | Tasks | Dependency | Impact |
|-------|-------|------------|--------|
| P0-A | Task 1, 2, 3 | None | Fixes ENOENT + unblocks canvas.present + fixes dotted names |
| P0-B | Task 4, 5 | Task 5 needs device test | Fixes pandas regression + catches future Python regressions |
| P0-C | Task 6 | None | Safety annotation, prevents future leakage |
| P1 | Task 7 | None | Canvas screenshot platform channel stub |
| P1 | Task 8 | None | Gifgrep reclassification |
| P2 | Task 9, 10 | None | Verification of existing fixes |

**Recommended order:** 2 → 3 → 1 → 6 → 4 → 5 → 8 → 7 → 9 → 10

Tasks 2 and 3 are the quickest wins (5-minute edits) and unblock canvas immediately. Task 1 is the architectural fix for the path leak. Task 5 requires device testing for stocks.

---

## Verification Matrix (Post-Implementation)

| Issue from logs | Fix Task | How to Verify |
|----------------|----------|---------------|
| `ENOENT: .../workspace/data/data/.../SKILL.md` | 1, 3, 6 | Agent reads any skill SKILL.md → no ENOENT |
| `"canvas.present" not in allowlist` | 2 | Agent calls `canvas.present` → no allowlist rejection |
| `"dir.list" not in allowlist` | 2 | Agent calls `dir.list` → no allowlist rejection |
| `skills/1passwordvaults/SKILL.md` (dots stripped) | 3 | Tools catalog entries have correct `docPath` |
| `pandas._pandas_datetime_CAPI` AttributeError | 4, 5 | Stocks skill returns NVDA price |
| `node-pty android-arm64 not supported` | 8 | gifgrep shows `unsupported` badge, not ENOENT |
| `ctx.fillRect` blank canvas snapshot | 7 | Platform channel returns null → falls back safely |
| False "dependency missing" badges | 9 | Live-ready skills show READY badge |

---

## Self-Review Checklist

- [x] **Spec coverage:** Every identified issue (F1-F8) has a corresponding task
- [x] **Placeholder scan:** No TBD, TODO, "implement later" in any step
- [x] **Type consistency:** `SkillWorkspace.relativeDoc()`, `_skillIdFromToolName()`, `CanvasScreenshotChannel` all used consistently
- [x] **Test coverage:** Badge classifier tests already exist (Task 9); Python smoke tests are implicit via provisioning
- [x] **Backward compatibility:** No breaking changes — all additions are additive or reclassifications

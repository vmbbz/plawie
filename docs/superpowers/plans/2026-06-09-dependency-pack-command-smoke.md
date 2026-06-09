# Dependency Pack Command Smoke Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Android dependency packs fail closed unless non-Python binary pack smoke commands actually execute successfully.

**Architecture:** Keep manifest validation in `DependencyPackManifestEntry`, but preserve parsed `smokeCommand`, file entries, and rollback strategy in the internal `_DependencyPack` model. `SkillProvisioningService` will execute non-Python smoke commands from the managed Native bin directory with no shell interpolation, bounded output, timeout, receipt only after smoke success, and rollback on smoke failure.

**Tech Stack:** Flutter/Dart, `dart:io` `Process.start`, existing `archive` pack extraction, existing skill provisioning tests.

---

### Task 1: Failing Command-Smoke Regression

**Files:**
- Modify: `test/skill_provisioning_service_test.dart`

- [x] **Step 1: Write the failing test**

Add a test that creates a remote dependency pack for a fake binary skill. The pack manifest must include:

```json
{
  "id": "android-command-smoke-fail-test",
  "source": "remote",
  "installPath": "bin",
  "smokeCommand": {"command": "<probe>", "args": ["--smoke"]},
  "rollback": {"strategy": "remove_install_path"},
  "provides": {"bins": ["<probe>"]}
}
```

The archive binary must exit non-zero for `--smoke`.

- [x] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/skill_provisioning_service_test.dart --no-pub
```

Expected before implementation: the test fails because the current installer ignores manifest `smokeCommand` and writes a receipt.

Observed RED: the focused test failed because the current installer wrote the
pack receipt and reported `changed: true`.

### Task 2: Command Smoke Model And Executor

**Files:**
- Modify: `lib/services/skill_provisioning_service.dart`

- [x] **Step 1: Extend `_DependencyPack`**

Add private fields for:

```dart
final List<_DependencyPackFile> files;
final _DependencyPackCommand? smokeCommand;
final String rollbackStrategy;
```

Parse those fields from validated dependency pack JSON. Keep APK-created packs backward compatible with empty files, null command smoke, and empty rollback.

- [x] **Step 2: Run non-Python command smoke safely**

Update `_runDependencyPackSmoke` so Python `smokeImports` keeps the existing Android bridge behavior, while non-Python `smokeCommand`:

```text
requires a safe command name
requires the command to be advertised in provides.bins
resolves the command under .openclaw/bin
starts the process with runInShell: false
uses .openclaw as cwd and HOME
adds .openclaw/bin to PATH
captures bounded stdout/stderr
times out and kills the process
returns ok only for exitCode 0
```

- [x] **Step 3: Roll back failed pack installs**

When smoke fails, remove installed files listed in the pack manifest and do not write a dependency receipt.

### Task 3: Green Verification And Docs

**Files:**
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`
- Modify: `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md`

- [x] **Step 1: Run focused tests**

Run:

```powershell
flutter test test/skill_provisioning_service_test.dart --no-pub
```

Expected: all tests in the file pass.

Observed GREEN: `flutter test test/skill_provisioning_service_test.dart --no-pub`
reported `14/14` tests passing.

- [x] **Step 2: Run focused analysis**

Run:

```powershell
flutter analyze lib/services/skill_provisioning_service.dart test/skill_provisioning_service_test.dart
```

Expected: no issues.

Observed: `flutter analyze lib/services/skill_provisioning_service.dart test/skill_provisioning_service_test.dart`
reported no issues.

- [x] **Step 3: Update docs**

Document that Phase 5A command smoke is real for non-Python binary packs and that node/ffmpeg/tmux payload work can now rely on the shared verifier.

- [x] **Step 4: Commit and push**

Run:

```powershell
git add docs/superpowers/plans/2026-06-09-dependency-pack-command-smoke.md test/skill_provisioning_service_test.dart lib/services/skill_provisioning_service.dart docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md
git commit -m "Verify dependency pack command smoke"
git push
```

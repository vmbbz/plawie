# Android Default Skill Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a class-aware Android default skill readiness gate so GTM measures every Android-viable default skill honestly instead of treating desktop-only, config-gated, pack-gated, and PRoot-only skills as generic Native failures.

**Architecture:** Add a curated Android support manifest above the existing parity/provisioning services, then add a readiness summarizer that combines product policy with raw runtime evidence. Keep `SkillParityAuditService` and `SkillProvisioningService` as low-level diagnostics; expose the Android launch summary through device health and the existing skills management UI after the product-policy layer is tested.

**Tech Stack:** Flutter/Dart, existing `SkillParityAuditService`, existing `SkillProvisioningService`, Flutter unit tests, Android device smoke through Gateway health/chat.

---

## Operating Rules For This Session

- Work in the current checkout because the IDE/device setup is already pointed here.
- Preserve unrelated dirty files: `android/build/reports/problems/problems-report.html`, `.tmp/`, `docs/REFRESH_YOUR_MEMORY_ASSHOLE.MD`, and `gateway_logs.md`.
- Stage commits by exact file path so pre-existing work is not swept into this implementation.
- Commit after each significant round.
- Avoid tiny ceremonial checkpoints; batch related code, tests, docs, and verification into coherent rounds.
- Run host verification for each committed code round.
- Run device smoke after the first round that changes device health or user-visible behavior, then again after the UI/status round.
- Do not push APKs, generated reports, `.tmp`, or log dumps.

## File Structure

- Create `lib/services/android_skill_support_manifest.dart`: product policy for every bundled OpenClaw default skill and Android bridge skill.
- Create `test/android_skill_support_manifest_test.dart`: coverage, classification, lookup, and JSON-contract tests for the manifest.
- Create `lib/services/android_skill_readiness_service.dart`: combines manifest policy with parity/provisioning evidence into a GTM summary.
- Create `test/android_skill_readiness_service_test.dart`: class-aware release gate tests using small in-memory snapshots/reports.
- Modify `lib/services/capabilities/device_capability.dart`: add `androidDefaultReadiness` to `device.health` payload while preserving raw `skillReadiness` and `skillProvisioning`.
- Modify `lib/models/gateway_state.dart` only after reading the current dirty diff and keeping existing changes intact.
- Modify `lib/screens/management/skills_manager.dart` only after reading the current dirty diff and keeping existing changes intact.
- Modify `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md` when the concrete health contract is implemented.

## Inventory Policy

The manifest must cover these IDs exactly once:

```text
1password, apple-notes, apple-reminders, avatar_forge, battery, bear-notes,
blogwatcher, blucli, camsnap, canvas, clawhub, coding-agent, diagram-maker,
discord, eightctl, gemini, gh-issues, gifgrep, github, gog, goplaces,
healthcheck, himalaya, imsg, mcporter, meme-maker, model-usage, nano-pdf,
node-connect, node-inspect-debugger, notion, obsidian, openai-whisper,
openai-whisper-api, openhue, oracle, ordercli, peekaboo, python-debugpy, sag,
sensors, session-logs, sherpa-onnx-tts, skill-creator, slack, songsee,
sonoscli, spike, spotify-player, summarize, taskflow, taskflow-inbox-triage,
things-mac, tmux, trello, vibrate, video-frames, voice-call, wacli, weather,
xurl
```

Initial policy buckets:

- `ready_required`: `avatar_forge`, `battery`, `canvas`, `clawhub`, `healthcheck`, `meme-maker`, `sensors`, `skill-creator`, `spike`, `taskflow`, `taskflow-inbox-triage`, `vibrate`, `weather`
- `ready_optional`: `diagram-maker`
- `needs_config`: `1password`, `discord`, `gh-issues`, `github`, `gog`, `goplaces`, `mcporter`, `notion`, `openai-whisper-api`, `ordercli`, `sag`, `session-logs`, `slack`, `summarize`, `trello`, `voice-call`
- `needs_pack`: `blogwatcher`, `blucli`, `camsnap`, `coding-agent`, `eightctl`, `gemini`, `gifgrep`, `himalaya`, `nano-pdf`, `node-inspect-debugger`, `openai-whisper`, `openhue`, `python-debugpy`, `sherpa-onnx-tts`, `songsee`, `sonoscli`, `spotify-player`, `tmux`, `video-frames`, `wacli`, `xurl`
- `unsupported_on_android`: `apple-notes`, `apple-reminders`, `bear-notes`, `imsg`, `peekaboo`, `things-mac`
- `manual_proot_compat`: `node-connect`, `oracle`
- `hidden_desktop_only`: `model-usage`, `obsidian`

Current correction after the later Phase 5 audit: `diagram-maker` is not a
pack-gated CLI skill. Its bundled `SKILL.md` has no binary/runtime requirement,
so the active manifest class is `ready_optional` with `instructionOnly`
execution. Do not put it back into `android-cli-core-pack`.

## Task 1: Android Support Manifest

**Files:**
- Create: `test/android_skill_support_manifest_test.dart`
- Create: `lib/services/android_skill_support_manifest.dart`

- [ ] **Step 1: Write the failing manifest test**

Use this exact test shape so coverage and product semantics fail until the manifest exists:

```dart
import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest covers every bundled default and Android bridge skill once', () {
    const expectedIds = <String>{
      '1password',
      'apple-notes',
      'apple-reminders',
      'avatar_forge',
      'battery',
      'bear-notes',
      'blogwatcher',
      'blucli',
      'camsnap',
      'canvas',
      'clawhub',
      'coding-agent',
      'diagram-maker',
      'discord',
      'eightctl',
      'gemini',
      'gh-issues',
      'gifgrep',
      'github',
      'gog',
      'goplaces',
      'healthcheck',
      'himalaya',
      'imsg',
      'mcporter',
      'meme-maker',
      'model-usage',
      'nano-pdf',
      'node-connect',
      'node-inspect-debugger',
      'notion',
      'obsidian',
      'openai-whisper',
      'openai-whisper-api',
      'openhue',
      'oracle',
      'ordercli',
      'peekaboo',
      'python-debugpy',
      'sag',
      'sensors',
      'session-logs',
      'sherpa-onnx-tts',
      'skill-creator',
      'slack',
      'songsee',
      'sonoscli',
      'spike',
      'spotify-player',
      'summarize',
      'taskflow',
      'taskflow-inbox-triage',
      'things-mac',
      'tmux',
      'trello',
      'vibrate',
      'video-frames',
      'voice-call',
      'wacli',
      'weather',
      'xurl',
    };

    final manifest = AndroidSkillSupportManifest.instance;
    expect(manifest.skillIds.toSet(), expectedIds);
    expect(manifest.skillIds.length, expectedIds.length);
    expect(manifest.duplicateSkillIds, isEmpty);
    expect(manifest.unclassifiedSkillIds(expectedIds), isEmpty);
  });

  test('manifest separates Android launch skills from config pack and desktop gates', () {
    final manifest = AndroidSkillSupportManifest.instance;

    expect(
      manifest.entriesForStatus(AndroidSkillSupportStatus.readyRequired)
          .map((entry) => entry.skillId),
      containsAll(['battery', 'sensors', 'vibrate', 'weather', 'taskflow']),
    );
    expect(manifest.entryFor('github')!.status, AndroidSkillSupportStatus.needsConfig);
    expect(manifest.entryFor('openai-whisper')!.status, AndroidSkillSupportStatus.needsPack);
    expect(
      manifest.entryFor('apple-notes')!.status,
      AndroidSkillSupportStatus.unsupportedOnAndroid,
    );
    expect(
      manifest.entryFor('node-connect')!.status,
      AndroidSkillSupportStatus.manualProotCompat,
    );
  });

  test('manifest emits stable health JSON for launch diagnostics', () {
    final weather = AndroidSkillSupportManifest.instance.entryFor('weather')!;
    final github = AndroidSkillSupportManifest.instance.entryFor('github')!;
    final whisper = AndroidSkillSupportManifest.instance.entryFor('openai-whisper')!;

    expect(weather.toJson()['androidSupport'], 'ready_required');
    expect(weather.toJson()['launchCritical'], isTrue);
    expect(github.toJson()['requiredConfig'], isNotEmpty);
    expect(whisper.toJson()['requiredPacks'], contains('android-whisper-runtime'));
  });
}
```

- [ ] **Step 2: Run the test and confirm the expected red state**

Run:

```powershell
flutter test test/android_skill_support_manifest_test.dart
```

Expected: fail because `package:clawa/services/android_skill_support_manifest.dart` does not exist.

- [ ] **Step 3: Add the manifest implementation**

Create `lib/services/android_skill_support_manifest.dart` with:

```dart
enum AndroidSkillSupportStatus {
  readyRequired,
  needsConfig,
  needsPack,
  unsupportedOnAndroid,
  manualProotCompat,
  hiddenDesktopOnly,
}

extension AndroidSkillSupportStatusWireName on AndroidSkillSupportStatus {
  String get wireName {
    return switch (this) {
      AndroidSkillSupportStatus.readyRequired => 'ready_required',
      AndroidSkillSupportStatus.needsConfig => 'needs_config',
      AndroidSkillSupportStatus.needsPack => 'needs_pack',
      AndroidSkillSupportStatus.unsupportedOnAndroid => 'unsupported_on_android',
      AndroidSkillSupportStatus.manualProotCompat => 'manual_proot_compat',
      AndroidSkillSupportStatus.hiddenDesktopOnly => 'hidden_desktop_only',
    };
  }
}

enum AndroidSkillOwnerLayer {
  openclawSkill,
  androidBridge,
  appNativeCapability,
  gatewayRuntime,
  clawhubSkill,
}

enum AndroidSkillExecutionMode {
  androidBridge,
  appNativeTool,
  gatewayTool,
  httpAdapter,
  nodeScript,
  pythonAdapter,
  instructionOnly,
  dependencyPack,
  prootCompat,
  unsupported,
}

class AndroidSkillSupportEntry {
  final String skillId;
  final AndroidSkillSupportStatus status;
  final AndroidSkillOwnerLayer ownerLayer;
  final AndroidSkillExecutionMode executionMode;
  final List<String> requiredPacks;
  final List<String> requiredConfig;
  final String? unsupportedReason;
  final String smokePrompt;
  final bool launchCritical;

  const AndroidSkillSupportEntry({
    required this.skillId,
    required this.status,
    required this.ownerLayer,
    required this.executionMode,
    this.requiredPacks = const <String>[],
    this.requiredConfig = const <String>[],
    this.unsupportedReason,
    required this.smokePrompt,
    this.launchCritical = false,
  });

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'androidSupport': status.wireName,
        'ownerLayer': ownerLayer.name,
        'executionMode': executionMode.name,
        'launchCritical': launchCritical,
        if (requiredPacks.isNotEmpty) 'requiredPacks': requiredPacks,
        if (requiredConfig.isNotEmpty) 'requiredConfig': requiredConfig,
        if (unsupportedReason != null && unsupportedReason!.isNotEmpty)
          'unsupportedReason': unsupportedReason,
        if (smokePrompt.isNotEmpty) 'smokePrompt': smokePrompt,
      };
}

class AndroidSkillSupportManifest {
  AndroidSkillSupportManifest._(this.entries);

  static final AndroidSkillSupportManifest instance =
      AndroidSkillSupportManifest._(_entries);

  final List<AndroidSkillSupportEntry> entries;

  List<String> get skillIds => entries.map((entry) => entry.skillId).toList();

  List<String> get duplicateSkillIds {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final id in skillIds) {
      if (!seen.add(id)) duplicates.add(id);
    }
    return duplicates.toList()..sort();
  }

  AndroidSkillSupportEntry? entryFor(String skillId) {
    final normalized = _normalizeSkillId(skillId);
    for (final entry in entries) {
      if (_normalizeSkillId(entry.skillId) == normalized) return entry;
    }
    return null;
  }

  List<AndroidSkillSupportEntry> entriesForStatus(
    AndroidSkillSupportStatus status,
  ) {
    return entries.where((entry) => entry.status == status).toList();
  }

  List<String> unclassifiedSkillIds(Set<String> expectedIds) {
    final classified = skillIds.toSet();
    final missing = expectedIds.difference(classified).toList()..sort();
    return missing;
  }

  static String _normalizeSkillId(String value) => value.trim().toLowerCase();
}
```

Fill `_entries` with the inventory policy above, using exact pack IDs and config keys:

```text
android-whisper-runtime, android-vision-media-runtime, android-python-debug-runtime,
android-cli-core-pack, android-node-executable-pack, android-gemini-cli-pack,
android-agent-cli-pack, android-audio-runtime, android-tts-runtime,
android-terminal-pack
```

- [ ] **Step 4: Run the manifest test and format the new files**

Run:

```powershell
dart format lib/services/android_skill_support_manifest.dart test/android_skill_support_manifest_test.dart
flutter test test/android_skill_support_manifest_test.dart
```

Expected: formatter exits `0`, manifest test exits `0`.

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git add lib/services/android_skill_support_manifest.dart test/android_skill_support_manifest_test.dart
git commit -m "Add Android skill support manifest"
```

Expected: commit includes only the manifest and its test.

## Task 2: Android Readiness Summary Service

**Files:**
- Create: `test/android_skill_readiness_service_test.dart`
- Create: `lib/services/android_skill_readiness_service.dart`

- [ ] **Step 1: Write failing readiness tests**

The tests must build minimal `SkillParitySnapshot` and `SkillProvisioningReport` objects directly. Cover these behaviors:

```dart
test('release gate passes when all ready-required skills are runtime ready', () {
  final summary = AndroidSkillReadinessService.instance.summarize(
    snapshot: snapshotWith([
      readyEntry('battery'),
      readyEntry('sensors'),
      readyEntry('vibrate'),
      readyEntry('weather'),
      readyEntry('taskflow'),
    ]),
    provisioning: provisioningWith([
      readyResult('battery'),
      readyResult('sensors'),
      readyResult('vibrate'),
      readyResult('weather'),
      readyResult('taskflow'),
    ]),
    manifest: AndroidSkillSupportManifest.forTesting([
      readyManifestEntry('battery'),
      readyManifestEntry('sensors'),
      readyManifestEntry('vibrate'),
      readyManifestEntry('weather'),
      readyManifestEntry('taskflow'),
      configManifestEntry('github', ['GITHUB_TOKEN']),
      packManifestEntry('openai-whisper', ['android-whisper-runtime']),
      unsupportedManifestEntry('apple-notes'),
      prootManifestEntry('node-connect'),
    ]),
  );

  expect(summary.readyRequiredTotal, 5);
  expect(summary.readyRequiredReady, 5);
  expect(summary.unexpectedMissingDependency, 0);
  expect(summary.releaseGatePass, isTrue);
  expect(summary.countsByClass['needs_config'], 1);
  expect(summary.countsByClass['needs_pack'], 1);
});

test('release gate fails only for ready-required skills with unexpected missing dependencies', () {
  final summary = AndroidSkillReadinessService.instance.summarize(
    snapshot: snapshotWith([
      missingEntry('weather', 'missing_native_bin'),
      readyEntry('battery'),
      missingEntry('github', 'missing_native_env'),
      missingEntry('openai-whisper', 'missing_native_bin'),
      missingEntry('apple-notes', 'missing_native_bin'),
    ]),
    provisioning: provisioningWith([
      missingBinaryResult('weather'),
      readyResult('battery'),
      needsConfigResult('github'),
      missingBinaryResult('openai-whisper'),
      unsupportedResult('apple-notes'),
    ]),
    manifest: AndroidSkillSupportManifest.forTesting([
      readyManifestEntry('weather'),
      readyManifestEntry('battery'),
      configManifestEntry('github', ['GITHUB_TOKEN']),
      packManifestEntry('openai-whisper', ['android-whisper-runtime']),
      unsupportedManifestEntry('apple-notes'),
    ]),
  );

  expect(summary.readyRequiredTotal, 2);
  expect(summary.readyRequiredReady, 1);
  expect(summary.unexpectedMissingDependency, 1);
  expect(summary.unexpectedMissingDependencySkillIds, ['weather']);
  expect(summary.releaseGatePass, isFalse);
});
```

- [ ] **Step 2: Run the test and confirm the expected red state**

Run:

```powershell
flutter test test/android_skill_readiness_service_test.dart
```

Expected: fail because `AndroidSkillReadinessService` does not exist.

- [ ] **Step 3: Add the readiness service**

Create these public types:

```dart
class AndroidSkillReadinessService {
  AndroidSkillReadinessService._();
  static final AndroidSkillReadinessService instance =
      AndroidSkillReadinessService._();

  AndroidSkillReadinessSummary summarize({
    required SkillParitySnapshot snapshot,
    required SkillProvisioningReport provisioning,
    AndroidSkillSupportManifest? manifest,
  }) {
    // Map runtime entries by normalized skill ID.
    // Treat only ready_required skills as release-blocking.
    // Preserve config, pack, unsupported, hidden, and PRoot counts as product classes.
  }
}

class AndroidSkillReadinessSummary {
  final int totalManifestSkills;
  final int installedNativeSkills;
  final int readyRequiredTotal;
  final int readyRequiredReady;
  final int unexpectedMissingDependency;
  final bool releaseGatePass;
  final Map<String, int> countsByClass;
  final List<String> unexpectedMissingDependencySkillIds;
  final List<Map<String, dynamic>> skills;

  const AndroidSkillReadinessSummary({
    required this.totalManifestSkills,
    required this.installedNativeSkills,
    required this.readyRequiredTotal,
    required this.readyRequiredReady,
    required this.unexpectedMissingDependency,
    required this.releaseGatePass,
    required this.countsByClass,
    required this.unexpectedMissingDependencySkillIds,
    required this.skills,
  });

  Map<String, dynamic> toHealthJson() => {
        'totalManifestSkills': totalManifestSkills,
        'installedNativeSkills': installedNativeSkills,
        'readyRequired': {
          'ready': readyRequiredReady,
          'total': readyRequiredTotal,
        },
        'countsByClass': countsByClass,
        'unexpectedMissingDependency': unexpectedMissingDependency,
        'unexpectedMissingDependencySkillIds': unexpectedMissingDependencySkillIds,
        'releaseGatePass': releaseGatePass,
        'skills': skills,
      };
}
```

`releaseGatePass` is true only when every `ready_required` manifest entry is runtime ready and `unexpectedMissingDependency` is zero. Config, pack, unsupported, hidden, and manual PRoot classes do not block the release gate.

- [ ] **Step 4: Run readiness tests and format files**

Run:

```powershell
dart format lib/services/android_skill_readiness_service.dart test/android_skill_readiness_service_test.dart
flutter test test/android_skill_support_manifest_test.dart test/android_skill_readiness_service_test.dart
```

Expected: formatter exits `0`, both targeted tests exit `0`.

- [ ] **Step 5: Commit Task 2**

Run:

```powershell
git add lib/services/android_skill_readiness_service.dart test/android_skill_readiness_service_test.dart
git commit -m "Add Android skill readiness summary"
```

Expected: commit includes only the readiness service and its test.

## Task 3: Device Health Integration

**Files:**
- Modify: `lib/services/capabilities/device_capability.dart`
- Test: `test/android_skill_readiness_service_test.dart`

- [ ] **Step 1: Extend the readiness service test for health JSON shape**

Add an assertion to the green readiness test:

```dart
final health = summary.toHealthJson();
expect(health['readyRequired'], {'ready': 5, 'total': 5});
expect(health['unexpectedMissingDependency'], 0);
expect(health['releaseGatePass'], isTrue);
```

- [ ] **Step 2: Run the targeted test before integration**

Run:

```powershell
flutter test test/android_skill_readiness_service_test.dart
```

Expected: exits `0`; this confirms the JSON contract before wiring.

- [ ] **Step 3: Wire device health**

Modify `DeviceCapability._health()`:

```dart
final androidReadiness =
    AndroidSkillReadinessService.instance.summarize(
  snapshot: parity,
  provisioning: provisioning,
);

return NodeFrame.response('', payload: {
  'status': status.payload,
  'permissions': permissions.payload,
  'androidDefaultReadiness': androidReadiness.toHealthJson(),
  'skillReadiness': parity.readinessCounts,
  'skillProvisioning': provisioning.toHealthJson(maxResults: 12),
  'skillGateCount': parity.gates.length,
  'toolsAllowParity': parity.toolsAllowParity,
  'nativeSkillCount': parity.nativeSkillCount,
  'prootSkillCount': parity.prootSkillCount,
  'timestamp': DateTime.now().toIso8601String(),
});
```

Add the import:

```dart
import '../android_skill_readiness_service.dart';
```

- [ ] **Step 4: Run host verification**

Run:

```powershell
dart format lib/services/capabilities/device_capability.dart
flutter test test/android_skill_support_manifest_test.dart test/android_skill_readiness_service_test.dart
flutter analyze
```

Expected: targeted tests exit `0`; analyze exits `0` or reports only pre-existing issues that are unrelated to the touched files and are copied into the progress check.

- [ ] **Step 5: Run device smoke for the new health contract**

Run the existing Android device workflow used in this repo. Minimum proof:

```powershell
adb devices
flutter build apk --debug
flutter install
adb shell am force-stop com.nxg.openclawproot
adb shell monkey -p com.nxg.openclawproot 1
```

Then trigger `device.health` through the app/Gateway path and confirm:

```text
androidDefaultReadiness.readyRequired.total is present
androidDefaultReadiness.unexpectedMissingDependency is present
androidDefaultReadiness.releaseGatePass is present
skillReadiness and skillProvisioning are still present
no automatic PRoot fallback appears in logs
```

- [ ] **Step 6: Commit Task 3**

Run:

```powershell
git add lib/services/capabilities/device_capability.dart
git commit -m "Expose Android default skill readiness in device health"
```

Expected: commit includes only the device health integration unless the readiness test changed in this task.

## Task 4: Skills Management UI Status

**Files:**
- Modify after inspecting dirty diff: `lib/models/gateway_state.dart`
- Modify after inspecting dirty diff: `lib/screens/management/skills_manager.dart`

- [ ] **Step 1: Inspect current dirty work before editing**

Run:

```powershell
git diff -- lib/models/gateway_state.dart lib/screens/management/skills_manager.dart
```

Expected: understand current changes and preserve them.

- [ ] **Step 2: Add model parsing for `androidDefaultReadiness`**

Add fields matching the health JSON contract:

```dart
final Map<String, dynamic> androidDefaultReadiness;
```

Parse from the Gateway health payload without removing existing health fields. If the dirty model already added related fields, extend those fields instead of replacing them.

- [ ] **Step 3: Add UI labels that match the product classes**

In the skills manager, show:

```text
Android default readiness
ready_required: ready/total
needs_config
needs_pack
unsupported_on_android
manual_proot_compat
hidden_desktop_only
unexpected_missing_dependency
Release gate: PASS or BLOCKED
```

Keep raw `missing_dependency` visible as diagnostics, not as the headline launch status.

- [ ] **Step 4: Run host verification**

Run:

```powershell
dart format lib/models/gateway_state.dart lib/screens/management/skills_manager.dart
flutter analyze
```

Expected: formatter exits `0`; analyze exits `0` or reports only pre-existing unrelated issues copied into the progress check.

- [ ] **Step 5: Run device UI smoke**

On the installed app, open the skills management surface and confirm:

```text
Android default readiness is visible
raw skill provisioning diagnostics are still visible
desktop-only/config/pack/PRoot statuses are not presented as launch failures
```

- [ ] **Step 6: Commit Task 4**

Run:

```powershell
git add lib/models/gateway_state.dart lib/screens/management/skills_manager.dart
git commit -m "Show Android skill readiness in skills manager"
```

Expected: commit includes only intentional model/UI changes. If those files contain pre-existing user changes, review the staged diff with `git diff --cached` before committing.

## Task 5: Documentation Progress Check

**Files:**
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`
- Modify if useful: `docs/NATIVE_SKILL_EXECUTION_WAR_PATH_2026-06-05.md`

- [ ] **Step 1: Update GTM docs with the implemented health contract**

Add the concrete payload keys:

```text
androidDefaultReadiness.readyRequired.ready
androidDefaultReadiness.readyRequired.total
androidDefaultReadiness.countsByClass
androidDefaultReadiness.unexpectedMissingDependency
androidDefaultReadiness.unexpectedMissingDependencySkillIds
androidDefaultReadiness.releaseGatePass
```

- [ ] **Step 2: Run docs sanity checks**

Run:

```powershell
rg -n "T[B]D|T[O]DO|F[I]XME|implement l[a]ter|fill i[n]" docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md docs/NATIVE_SKILL_EXECUTION_WAR_PATH_2026-06-05.md docs/superpowers/plans/2026-06-07-android-default-skill-readiness-implementation.md
git diff -- docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md docs/NATIVE_SKILL_EXECUTION_WAR_PATH_2026-06-05.md
```

Expected: no vague markers in touched docs; diff only documents implemented behavior.

- [ ] **Step 3: Commit Task 5**

Run:

```powershell
git add docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md docs/NATIVE_SKILL_EXECUTION_WAR_PATH_2026-06-05.md
git commit -m "Document Android skill readiness health contract"
```

Expected: commit includes only documentation changes.

## Final Verification

- [ ] Run targeted tests:

```powershell
flutter test test/android_skill_support_manifest_test.dart test/android_skill_readiness_service_test.dart
```

- [ ] Run full static analysis:

```powershell
flutter analyze
```

- [ ] Run final device smoke:

```text
OpenClaw app starts in Native mode.
Gateway health includes androidDefaultReadiness.
Ready-required skills report ready or named failures.
unexpectedMissingDependency is zero for the launch set before GTM claim.
PRoot is not automatically started as fallback.
Skills manager shows Android readiness separate from raw diagnostics.
```

- [ ] Confirm git state:

```powershell
git status --short
git log --oneline -8
```

Expected: only pre-existing unrelated dirty files remain, and the new commits are visible at the top of the log.

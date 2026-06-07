# Android Skill GTM Ceiling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise OpenClaw Android from a 13-skill launch gate to the maximum honest Android-relevant default skill ceiling, with clear UI gates and Gateway-first execution.

**Architecture:** Keep Native Android as the default runtime, keep PRoot explicit/manual, and route production skills through Gateway-visible tool-use/tool-result flows. Use `androidDefaultReadiness.skills` as the app-facing truth source, with `SkillProvisioningService` handling config and dependency gates.

**Tech Stack:** Flutter/Dart, OpenClaw Gateway WebSocket `chat.send`, `AgentSkillServer`, `SkillProvisioningService`, `SkillParityAuditService`, Android native Node runtime, fllama native-assets hook.

---

### Task 1: Test Lane And GTM Truth Surface

**Files:**
- Modify: `fllama/hook/build.dart`
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`
- Create: `lib/services/android_skill_readiness_view_model.dart`
- Create: `test/android_skill_readiness_view_model_test.dart`
- Modify: `lib/screens/management/skills_manager.dart`

- [x] **Step 1: Reproduce host test blocker**

Run:

```powershell
flutter test test/android_skill_support_manifest_test.dart --no-pub
```

Expected before fix: FAIL before test discovery with fllama Windows host native-assets CMake/MSVC resolution.

- [x] **Step 2: Skip only the Windows non-linking fllama host asset lane**

Implementation:

```dart
if (targetOS == OS.windows && !input.config.linkingEnabled) {
  logger.info(
    'Skipping fllama Windows host native asset build for non-linking '
    'Flutter test discovery. Android target builds still compile fllama.',
  );
  return;
}
```

- [x] **Step 3: Verify focused manifest tests execute**

Run:

```powershell
flutter test test/android_skill_support_manifest_test.dart --no-pub
```

Expected: PASS, with the fllama Windows test-discovery skip message.

- [x] **Step 4: Add Android readiness view-model test**

Test file:

```dart
final model = AndroidSkillReadinessViewModel.fromReadiness({
  'totalManifestSkills': 61,
  'readyRequired': {'ready': 13, 'total': 13},
  'countsByClass': {
    'ready_required': 13,
    'needs_config': 16,
    'needs_pack': 22,
    'unsupported_on_android': 6,
    'manual_proot_compat': 2,
    'hidden_desktop_only': 2,
  },
  'skills': [
    {'skillId': 'weather', 'androidSupport': 'ready_required', 'ready': true},
    {'skillId': 'github', 'androidSupport': 'needs_config', 'requiredConfig': ['GITHUB_TOKEN'], 'primaryGate': 'missing_native_bin', 'ready': false},
  ],
});
expect(model.androidRelevantTotal, 51);
```

- [x] **Step 5: Implement view model and Skills Manager panel**

The panel must show launch gate, Android-relevant ceiling, excluded/outside-GTM count, config gates, and pack gates.

Later correction: gate previews must not truncate the remaining work to four
items. The view model now exposes every blocked config and pack gate from the
readiness JSON so the Skills page can show the full user-facing release path.

- [x] **Step 6: Verify and commit**

Run:

```powershell
flutter test test/android_skill_support_manifest_test.dart test/android_skill_readiness_view_model_test.dart --no-pub
dart analyze fllama/hook/build.dart lib/services/android_skill_readiness_view_model.dart lib/screens/management/skills_manager.dart
flutter build apk --debug
git diff --check
git add fllama/hook/build.dart docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md docs/superpowers/plans/2026-06-07-android-skill-gtm-ceiling.md lib/services/android_skill_readiness_view_model.dart lib/screens/management/skills_manager.dart test/android_skill_readiness_view_model_test.dart
git commit -m "Clarify Android skill GTM ceiling"
```

Expected: tests pass, analyze passes, APK builds, whitespace check passes, commit created.

### Task 2: Config Wizard MVP

**Files:**
- Create: `lib/services/android_skill_config_form_model.dart`
- Create: `test/android_skill_config_form_model_test.dart`
- Create: `lib/screens/management/skills/android_skill_config_sheet.dart`
- Modify: `lib/screens/management/skills_manager.dart`
- Modify: `lib/providers/gateway_provider.dart`
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`

- [x] **Step 1: Add form model test**

The test must prove `discord` exposes `DISCORD_BOT_TOKEN`, `slack` exposes both `SLACK_BOT_TOKEN` and `channels.slack`, and a skill with `primaryGate=missing_native_bin` reports that config alone is insufficient.

Run:

```powershell
flutter test test/android_skill_config_form_model_test.dart --no-pub
```

Expected before implementation: FAIL because the form model does not exist.

- [x] **Step 2: Implement config form model**

Create a pure Dart parser from `androidDefaultReadiness.skills` that returns:

```dart
class AndroidSkillConfigFormModel {
  final String skillId;
  final List<String> envKeys;
  final List<String> configKeys;
  final String? runtimeGate;
  final bool configOnlyCanSatisfy;
}
```

Keys with uppercase env style go to `envKeys`; dotted keys such as `channels.slack` go to `configKeys`.

- [x] **Step 3: Add guided config sheet**

The sheet must collect values, call a provider method that delegates to `SkillProvisioningService.auditAndProvision(skillId: ..., envValues: ..., configValues: ...)`, then refresh Gateway health.

- [x] **Step 4: Verify and commit**

Run focused tests, analyzer, and `flutter build apk --debug`, then commit:

```powershell
git commit -m "Add Android skill config wizard"
```

### Task 3: Gateway-First Required Tool Continuation

**Files:**
- Modify: `lib/services/gateway_service.dart`
- Modify: `lib/services/app_native_chat_tool_router.dart`
- Modify: `lib/services/agent_skill_server.dart`
- Modify: `test/gateway_service_required_skill_intent_test.dart`
- Modify: `test/gateway_required_mobile_route_test.dart`
- Create: `test/gateway_service_tool_continuation_test.dart`
- Modify: `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md`
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`

- [x] **Step 1: Add continuation test**

The test must prove a required stocks intent emits `TOOL_USE` and `TOOL_RESULT`, then continues into the Gateway/model answer path instead of returning immediately.

- [x] **Step 2: Implement continuation hook**

Replace early return with a bounded continuation payload that includes the tool result as private context for the model turn.

- [x] **Step 3: Keep emergency fallback**

If Gateway continuation is unavailable, return the direct visible result with a diagnostic activity line.

- [x] **Step 4: Verify and commit**

Run focused tests, analyzer, APK build, device chat smoke, then commit:

Device smoke note: `/api/debug/app-native-chat-tool-smoke` proved stocks
`TOOL_USE` and `TOOL_RESULT` plus Gateway continuation handoff on device. The
debug stream timed out before final assistant text, so final UI wording remains
a manual smoke item.

```powershell
git commit -m "Continue required skill results through agent loop"
```

### Task 4: Fast Adapter Batch

**Files:**
- Modify: `lib/services/app_native_chat_tool_router.dart`
- Modify: `lib/services/agent_skill_server.dart`
- Modify: `lib/services/android_skill_support_manifest.dart`
- Modify: `lib/services/android_skill_readiness_service.dart`
- Create focused capability tests under `test/`
- Modify GTM docs

- [x] **Step 1: Pick first adapter**

Start with `xurl` because it maps cleanly to Dart HTTP and can avoid a CLI pack.

- [x] **Step 2: Test app-native adapter routing**

Add tests that explicit `xurl` prompts route to a Gateway-visible tool, validate URL input, and return status/body metadata.

- [x] **Step 3: Implement adapter**

Expose the tool through the Gateway/AgentSkillServer path, not a hidden local return.

- [x] **Step 4: Reclassify manifest**

Move `xurl` from `needs_pack` to `ready_required` or a new ready non-launch class only after device smoke passes.

Implemented as `ready_optional`, not `ready_required`, so the 13/13 launch gate
stays focused on fresh-user boot-critical skills. Device proof used
`/api/tools/execute` against `http://127.0.0.1:8765/device/status`; direct
execution returned `success: true`, `runtime: app-native-http`, and
`statusCode: 200`. The chat-smoke debug endpoint timed out during this round, so
manual chat UI final-response polish remains a follow-up.

- [x] **Step 5: Repeat for `blogwatcher`, `nano-pdf`, `session-logs`, `summarize`, `stocks`, `camsnap`**

Each default-manifest adapter got a focused test and direct device smoke before
or immediately after reclassification. `stocks` is not in the Android default
manifest; keep it in the required Native ClawHub route/provisioning lane.

`camsnap` local adapter is implemented as a ready-optional named tool over
Android `CameraCapability`. It keeps `TOOL_USE:camsnap` identity for explicit
prompts, advertises a `/api/tools` schema, routes `/api/tools/execute` through
`AgentSkillServer`, and omits raw `base64` from HTTP JSON responses. Device
smoke after the Phase 4 milestone install returned `success: true` and
`base64Omitted: true`.

`summarize` local adapter is implemented as a ready-optional named tool for
provided text. It uses a bounded deterministic extractive adapter, keeps
`TOOL_USE:summarize` identity for explicit `summarize: <text>` prompts,
advertises a `/api/tools` schema, and routes `/api/tools/execute` through
`AgentSkillServer`. It does not claim provider-backed URL/file/long-document
summarization. Device smoke after the Phase 4 milestone install returned
`success: true` and `runtime: app-native-extractive-summary`.

`blogwatcher` local adapter is implemented as a ready-optional named tool for
small public RSS/Atom feeds. It keeps `TOOL_USE:blogwatcher` identity for
explicit `blogwatcher <url> limit N` prompts, advertises a `/api/tools` schema,
routes `/api/tools/execute` through `AgentSkillServer`, and blocks non-HTTP,
loopback, private, and link-local feed targets. It does not claim persistent
watching, notifications, or full CLI parity. Device smoke after the Phase 4
milestone install returned `success: true`, `runtime: app-native-feed-check`,
and `feedTitle: W3C - News`.

`session-logs` local adapter is implemented as a ready-optional named tool for
app-owned chat sessions. It keeps `TOOL_USE:session-logs` identity for explicit
`session-logs list/read/search` prompts, advertises a `/api/tools` schema, and
routes `/api/tools/execute` through `AgentSkillServer`. It returns bounded
session metadata and message previews only; it does not expose arbitrary
`SESSION_LOGS_ROOT` directories, raw gateway session keys, raw image payloads,
full reasoning blocks, or full tool result payloads. Device smoke after the
Phase 4 milestone install returned `success: true`,
`runtime: app-native-session-logs`, and `returnedSessionCount: 3`.

`nano-pdf` local adapter is implemented as a ready-optional named tool for
small text-based PDF bytes. It keeps `TOOL_USE:nano-pdf` identity for explicit
`nano-pdf base64 <PDF_BASE64>` prompts, advertises a `/api/tools` schema, and
routes `/api/tools/execute` through `AgentSkillServer`. It rejects missing,
invalid, and encrypted PDFs, returns bounded text-layer output, and does not
claim OCR/scanned PDF support, arbitrary file paths, complex font/CMap
extraction, or full parser parity. Device smoke after the Phase 4 milestone
install returned `success: true`, `runtime: app-native-pdf-text`, and
`chars: 35`.

`github` and `gh-issues` are implemented as config-gated app-native REST
adapters, not ready-optional fresh-user tools. They keep `needs_config` until
`GITHUB_TOKEN` is present, expose `github` and `gh-issues` schemas through
`/api/tools`, route `/api/tools/execute` through `AgentSkillServer`, and clear
the stale `missing_native_bin` gate once Native env config is present. The token
is read from Native `.env`; it is not accepted in tool input and is not returned
in payloads or visible chat chunks.

Focused proof:

```powershell
flutter test test/android_skill_readiness_service_test.dart test/github_app_native_adapter_test.dart test/android_skill_support_manifest_test.dart --no-pub
flutter analyze lib/services/android_skill_readiness_service.dart lib/services/android_skill_support_manifest.dart lib/services/capabilities/github_capability.dart lib/services/app_native_chat_tool_router.dart lib/services/agent_skill_server.dart lib/services/gateway_tool_catalog.dart lib/services/skills_service.dart test/android_skill_readiness_service_test.dart test/github_app_native_adapter_test.dart
```

Result: 19/19 tests passed; analyzer clean.

`goplaces` is implemented as a config-gated app-native Google Places Text
Search adapter. It keeps `needs_config` until `GOOGLE_PLACES_API_KEY` is
present, exposes a `goplaces` schema through `/api/tools`, routes
`/api/tools/execute` through `AgentSkillServer`, and clears stale CLI/binary
gates once Native env config is present. It uses the Places Text Search
endpoint with an explicit `X-Goog-FieldMask`, bounded `pageSize`, and compact
place previews only.

Focused proof:

```powershell
flutter test test/goplaces_app_native_adapter_test.dart --no-pub
```

Result: 6/6 tests passed.

### Task 5: Verified Pack Lane

**Files:**
- Modify: `lib/services/skill_provisioning_service.dart`
- Add pack manifests under a policy-safe asset or metadata directory
- Add focused provisioning tests under `test/`
- Modify GTM docs

- [x] **Step 1: Define pack manifest schema**

Each pack record must include `id`, `abi`, `version`, `sizeBytes`, `sha256`, `source`, `files`, `smokeCommand`, and `rollback`.

- [x] **Step 2: Add tests for pack validation**

Tests must reject missing hashes, wrong ABI, and unsigned remote executable packs.

Implemented `DependencyPackManifestEntry`, `DependencyPackManifestPolicy`, and
`DependencyPackManifestValidation`. `SkillProvisioningService` now validates
manifest records before pack selection/install and skips invalid records.
Focused tests cover missing remote SHA-256, unsupported ABI, unsigned remote
executable packs, unsafe paths, and a provisioning integration where an unsafe
pack is rejected before install.

- [x] **Step 3: Implement first pack resolver**

Start with `android-cli-core-pack` only after policy review.

Implemented the first resolver as APK-provided only. `android-cli-core-pack`
is advertised when bundled CLI-core binaries are actually present in APK
provisioning roots. Pack selection now scores `provides.bins`; install copies
pack-provided binaries into `.openclaw/bin`; receipts are ignored if a managed
binary is missing.

- [x] **Step 4: Verify and commit**

Run provisioning tests, analyzer, APK build, then commit.

Focused proof:

```powershell
flutter analyze lib/services/dependency_pack_manifest.dart lib/services/skill_provisioning_service.dart test/dependency_pack_manifest_test.dart test/skill_provisioning_service_test.dart
flutter test test/dependency_pack_manifest_test.dart test/skill_provisioning_service_test.dart --no-pub
flutter build apk --debug
```

Result: analyzer clean; 14/14 tests passed; debug APK built.

- [x] **Step 5: Add APK CLI-core payload lane**

Declared `assets/openclaw/cli-core/bin/` in `pubspec.yaml` and taught
`NativeNodeEmbeddedService` to copy any non-dot files from that asset directory
into `filesDir/native-node-embedded/provisioning/bin` with executable
permissions. The committed lane intentionally includes no fake CLI executable
payload; the debug APK currently contains only `.gitkeep` under the CLI-core
bin asset directory.

Focused proof:

```powershell
flutter analyze lib/services/skill_provisioning_service.dart test/android_cli_core_payload_packaging_test.dart test/skill_provisioning_service_test.dart
flutter test test/android_cli_core_payload_packaging_test.dart test/skill_provisioning_service_test.dart --no-pub
flutter build apk --debug
```

Result: analyzer clean; 11/11 tests passed; debug APK built; APK payload audit
shows no real CLI-core binary names yet.

- [x] **Step 6: Correct diagram-maker classification**

Audited the bundled `diagram-maker/SKILL.md` and confirmed it has no
`requirements.bins` or runtime dependency. Reclassified it from
`needs_pack/android-cli-core-pack` to `ready_optional/instructionOnly` and
removed it from the APK-provided CLI-core binary resolver.

Focused proof:

```powershell
flutter analyze lib/services/android_skill_support_manifest.dart lib/services/skill_provisioning_service.dart test/android_skill_support_manifest_test.dart test/android_skill_readiness_view_model_test.dart test/skill_provisioning_service_test.dart
flutter test test/android_skill_support_manifest_test.dart test/android_skill_readiness_view_model_test.dart test/skill_provisioning_service_test.dart --no-pub
flutter build apk --debug
adb -s RZCX30KA9AW install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s RZCX30KA9AW forward tcp:8765 tcp:8765
Invoke-RestMethod http://127.0.0.1:8765/device/health
```

Result: analyzer clean; 14/14 focused tests passed; debug APK built and
installed over existing app data; device health reported releaseGatePass true,
ready_required 13, ready_optional 7, needs_config 14, needs_pack 17, and
`diagram-maker` ready with `runtimeStatus: ready`.

- [x] **Step 7: Correct CLI-core executable names**

Audited bundled `blucli/SKILL.md` and `sonoscli/SKILL.md`. Their skill IDs do
not match their required executable names:

```text
blucli -> blu
sonoscli -> sonos
```

Updated the APK-provided CLI-core resolver to advertise `blu` and `sonos`, and
updated smoke wording so the manifest names the executable users/devices will
actually run.

Focused proof:

```powershell
flutter test test/skill_provisioning_service_test.dart --no-pub
```

Result: 11/11 provisioning tests passed, including APK pack satisfaction for
`blucli` through `blu` and `sonoscli` through `sonos`.

### Task 6: Fresh-User Proof

**Files:**
- Modify docs only unless code gaps appear.

- [ ] **Step 1: Request explicit approval to clear app data**

Do not run destructive app-data clearing without user approval.

- [ ] **Step 2: Fresh install**

Run:

```powershell
adb -s RZCX30KA9AW uninstall com.nxg.openclawproot
flutter build apk --debug
adb -s RZCX30KA9AW install build\app\outputs\flutter-apk\app-debug.apk
```

- [ ] **Step 3: Record health**

Forward `8765`, query `/device/health`, and record `androidDefaultReadiness`.

- [ ] **Step 4: Device smoke**

Run Class A chat smokes and selected Class B/C smokes after config/pack setup.

- [ ] **Step 5: Commit proof update**

Commit the recorded counts and outcomes.

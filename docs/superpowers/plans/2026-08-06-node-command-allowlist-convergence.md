# Native Node Command Allowlist Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the eight bounded payment and bridge Android node commands so official OpenClaw persists the complete 82-command snapshot and Plawie stops re-pairing every watchdog interval.

**Architecture:** Keep `GatewayToolCatalog.mobileNodeAllowCommands` as the reviewed source of truth and use the existing native config migration before Gateway startup. Add only the commands already emitted by `AiPaymentsCapability` and `NodeProvider`; do not weaken pairing verification or introduce signing, payment execution, bridge execution, PRoot, or wildcard command approval.

**Tech Stack:** Flutter/Dart, `flutter_test`, official OpenClaw 2026.7.1 native Gateway, Android/ADB, Git.

---

## File Structure

- Modify `test/node_pairing_command_snapshot_test.dart`: derive the payment and
  bridge command surface using the same alias rules as `NodeProvider`, then
  enforce central allowlist coverage and reject mutation commands.
- Modify `lib/services/gateway_tool_catalog.dart`: add the exact eight reviewed
  entries to the existing central mobile node command allowlist.
- Modify `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md`: document the read-only
  payment/bridge node commands and their human-approval boundary.
- Do not modify `lib/services/node_service.dart`: its strict persisted-snapshot
  verification is correct once the allowlist and declaration agree.
- Do not modify the official downloaded OpenClaw package or on-device JSON
  directly; `GatewayService._ensureNodeAllowCommands()` owns migration.

### Task 1: Test and Repair the Central Command Contract

**Files:**
- Modify: `test/node_pairing_command_snapshot_test.dart`
- Modify: `lib/services/gateway_tool_catalog.dart`

- [ ] **Step 1: Write the failing command-contract test**

Add the capability import:

```dart
import 'package:clawa/services/capabilities/ai_payments_capability.dart';
```

Add this test after the existing avatar command test:

```dart
  test('payment and bridge node commands are explicitly allowlisted', () {
    final capability = AiPaymentsCapability();
    final declaredCommands = <String>{};

    for (final command in capability.commands) {
      if (command.contains('.')) {
        declaredCommands.add(command);
      } else {
        declaredCommands.add('${capability.name}.$command');
        declaredCommands.add('${capability.name}_$command');
      }
    }

    expect(
      declaredCommands,
      equals(const <String>{
        'payments.capabilities',
        'payments.status',
        'payments.receipts',
        'payments_capabilities',
        'payments_status',
        'payments_receipts',
        'bridge.capabilities',
        'bridge.quote',
      }),
    );
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      containsAll(declaredCommands),
    );
    for (final forbiddenCommand in const <String>[
      'payments.approve',
      'payments.sign',
      'payments.submit',
      'bridge.execute',
    ]) {
      expect(
        GatewayToolCatalog.mobileNodeAllowCommands,
        isNot(contains(forbiddenCommand)),
      );
    }
  });
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/node_pairing_command_snapshot_test.dart --no-pub
```

Expected: FAIL because `GatewayToolCatalog.mobileNodeAllowCommands` does not
contain the eight derived payment/bridge commands.

- [ ] **Step 3: Add the minimal reviewed allowlist entries**

Add the following entries together in
`GatewayToolCatalog.mobileNodeAllowCommands`, adjacent to the other bounded
mobile capabilities:

```dart
    'payments.capabilities',
    'payments.status',
    'payments.receipts',
    'payments_capabilities',
    'payments_status',
    'payments_receipts',
    'bridge.capabilities',
    'bridge.quote',
```

Do not add approval, unlock, signing, transaction submission, broadcast, or
bridge execution commands.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run:

```powershell
flutter test test/node_pairing_command_snapshot_test.dart test/ai_payments_capability_test.dart test/bridge_app_native_adapter_test.dart test/bootstrap_release_contract_test.dart --no-pub
```

Expected: all focused tests PASS, including the new test that failed in Step 2.

- [ ] **Step 5: Commit the tested production fix**

```powershell
git add -- test/node_pairing_command_snapshot_test.dart lib/services/gateway_tool_catalog.dart
git diff --cached --check
git commit -m "fix: allow bounded payment node commands"
```

Expected: the commit contains only the test and central allowlist change.

### Task 2: Document the Security and Migration Boundary

**Files:**
- Modify: `docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md`

- [ ] **Step 1: Extend the Android node command example**

Add these entries to the `gateway.nodes.allowCommands` JSON example:

```json
"payments.capabilities",
"payments.status",
"payments.receipts",
"bridge.capabilities",
"bridge.quote"
```

- [ ] **Step 2: Document aliases and the human-approval boundary**

Add this paragraph after the command example:

```markdown
Payment and inbound bridge commands are read-only Android node surfaces. The
canonical commands are `payments.capabilities`, `payments.status`,
`payments.receipts`, `bridge.capabilities`, and `bridge.quote`; payment
commands also retain the underscore aliases emitted by `NodeProvider` for
mobile compatibility. None of these commands can approve, unlock, sign,
submit, broadcast, or execute a bridge. Every spending action remains in the
visible Base-page approval flow with a fresh Android device authentication.

`GatewayToolCatalog.mobileNodeAllowCommands` is the reviewed source of truth.
`GatewayService._ensureNodeAllowCommands()` writes that exact set into the
active native config before startup, allowing official OpenClaw to persist the
same command surface that the Android node declares. Pairing verification must
remain strict; a missing command is a policy/config defect, not a reason to
weaken the stored-snapshot check.
```

- [ ] **Step 3: Verify documentation and focused contracts**

Run:

```powershell
git diff --check -- docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md
flutter test test/node_pairing_command_snapshot_test.dart test/bridge_app_native_adapter_test.dart --no-pub
```

Expected: no whitespace errors and all focused tests PASS.

- [ ] **Step 4: Commit the architecture documentation**

```powershell
git add -- docs/TOOLS_SKILLS_GATEWAY_ARCHITECTURE.md
git diff --cached --check
git commit -m "docs: define payment node command boundary"
```

Expected: the commit contains only the architecture documentation update.

### Task 3: Verify, Install, and Prove On-Device Convergence

**Files:**
- Verify: `lib/services/gateway_tool_catalog.dart`
- Verify: `lib/services/gateway_service.dart`
- Verify: `lib/services/node_service.dart`
- Artifact only: `build/app/outputs/flutter-apk/app-debug.apk` (never commit)

- [ ] **Step 1: Run static and complete automated verification**

Run:

```powershell
flutter analyze lib/services/gateway_tool_catalog.dart lib/services/gateway_service.dart lib/services/node_service.dart
flutter test --no-pub
```

Expected: analysis exits 0 and the complete Flutter suite passes with no test
failures.

- [ ] **Step 2: Build and inspect the debug APK**

Run:

```powershell
flutter build apk --debug
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --verbose build/app/outputs/flutter-apk/app-debug.apk
```

Expected: the native-runtime packaging gate passes, the APK builds, and APK
Signature Scheme v2 verifies. The artifact remains ignored and unstaged.

- [ ] **Step 3: Install in place and launch exactly once**

Run:

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -c
adb shell am force-stop com.openclaw.plawie
adb shell monkey -p com.openclaw.plawie -c android.intent.category.LAUNCHER 1
```

Expected: install succeeds without uninstalling or clearing app data; one cold
launch begins. Do not issue additional start/stop commands while startup is in
progress.

- [ ] **Step 4: Verify native Gateway readiness and the approved snapshot**

After the Gateway reports RPC-ready, inspect only redacted command metadata:

```powershell
adb logcat -d -v threadtime flutter:I NativeNodeEmbedded:I NativeNodeSmoke:I '*:S' |
  Select-String 'Gateway RPC discovery complete|Gateway ready|Connect accepted|Approved node command snapshot|command snapshot is still missing|refreshing gateway pairing snapshot'
```

Parse `files/native-node-embedded/native-home/.openclaw/nodes/paired.json`
through `run-as` and print only the command count and command names. Never print
the node token:

```powershell
$deviceId = '8d9ed10244ded3fd6f24c2bece7d9dee85bee85b1c067c064a9164b2e77be261'
$raw = adb shell run-as com.openclaw.plawie cat files/native-node-embedded/native-home/.openclaw/nodes/paired.json
$paired = $raw | ConvertFrom-Json -AsHashtable
$record = $paired[$deviceId]
$commands = @($record['commands']) | Sort-Object
"commandCount=$($commands.Count)"
$commands
```

Expected: Gateway RPC is ready, pairing is accepted, and the persisted record
contains 82 commands including all eight payment/bridge entries.

- [ ] **Step 5: Observe two watchdog intervals without another repair**

Capture two later log snapshots without restarting the app. Communicate an
intermediate status update between the two 35-second observations so the user
is not left waiting:

```powershell
Start-Sleep -Seconds 35
adb logcat -d -v threadtime flutter:I '*:S' |
  Select-String 'Pairing required|command snapshot is still missing|refreshing gateway pairing snapshot'
```

After the intermediate user update, run:

```powershell
Start-Sleep -Seconds 35
adb logcat -d -v threadtime flutter:I '*:S' |
  Select-String 'Pairing required|command snapshot is still missing|refreshing gateway pairing snapshot'
adb shell ps -A | Select-String 'com.openclaw.plawie|proot'
```

Expected after the successful approval timestamp:

```text
zero occurrences: command snapshot is still missing
zero occurrences: refreshing gateway pairing snapshot
zero additional occurrences: Pairing required
```

The dashboard must report `GATEWAY LIVE`; `ps -A` must show the app and
`:native_node_smoke` processes, with no PRoot process started by this flow.

- [ ] **Step 6: Review repository cleanliness and record verification**

Run:

```powershell
git status --short
git log --oneline -5
```

Expected: no APK, `libnode.so`, provenance manifest, Gradle report, temporary
log, or device JSON is staged. Preserve unrelated pre-existing wallet/build
changes for their own verified commit round.
